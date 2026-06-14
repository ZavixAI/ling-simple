"""认证与账号编排：多因子登录、token、用户/身份/配置及注销级联清理。

依赖 RedisAuthStateStore 存短信 challenge 与 refresh token；外部身份走 ExternalAuthProviderService。
"""

from __future__ import annotations

import asyncio
import re
import secrets
import time
import uuid
from datetime import timedelta
from typing import Any

from config import constants
from config.settings import get_app_config
from core.http.exceptions import AppHTTPException
from core.infra.db import transaction_scope
from core.infra.redis import redis
from core.infra.s3 import s3
from models.agent import AgentMessage, AgentMessageDao, AgentSession, AgentSessionDao
from models.calendar import (
    AppleCalendarContext,
    AppleCalendarContextDao,
    CalendarEvent,
    CalendarEventDao,
    CalendarEventLink,
    CalendarEventLinkDao,
)
from models.calendar_provider import (
    CalendarProviderConnection,
    CalendarProviderConnectionDao,
)
from models.push import UserPushDevice, UserPushDeviceDao
from models.user import (
    User,
    UserConfig,
    UserConfigDao,
    UserDao,
    UserExternalIdentity,
    UserExternalIdentityDao,
)
from services.agent.sage import SageClient
from services.auth.email_verification import (
    normalize_email,
    send_register_email_code,
    validate_register_email,
    verify_register_email_code,
)
from services.auth.external_providers import (
    ExternalAuthProviderService,
    ExternalIdentityPayload,
)
from services.auth.sms_verification import send_sms_challenge_code
from services.auth.state_store import (
    RedisAccessTokenState,
    RedisAuthStateStore,
    RedisRefreshTokenState,
)
from services.auth.tokens import ACCESS_TOKEN_PREFIX, REFRESH_TOKEN_PREFIX, hash_token
from services.push.service import PushNotificationService
from sqlalchemy.ext.asyncio import AsyncSession
from utils.logging import logger
from utils.time import format_datetime


class AuthService:
    """对外统一入口：登录、刷新、资料修改、绑定与账号删除。"""

    _KNOWN_PHONE_AREA_CODES = (
        "+886",
        "+852",
        "+86",
        "+82",
        "+81",
        "+65",
        "+44",
        "+1",
    )
    ADMIN_WHITELIST_BYPASS_CODE = "111111"

    def __init__(self) -> None:
        self.cfg = get_app_config()
        self.user_dao = UserDao()
        self.user_config_dao = UserConfigDao()
        self.identity_dao = UserExternalIdentityDao()
        self.state_store = RedisAuthStateStore(self.cfg)
        self.external_auth_service = ExternalAuthProviderService(self.cfg)
        self.calendar_event_dao = CalendarEventDao()
        self.calendar_link_dao = CalendarEventLinkDao()
        self.calendar_context_dao = AppleCalendarContextDao()
        self.calendar_provider_connection_dao = CalendarProviderConnectionDao()
        self.agent_session_dao = AgentSessionDao()
        self.agent_message_dao = AgentMessageDao()
        self.push_device_dao = UserPushDeviceDao()
        self.sage_client = SageClient()

    def list_providers(self) -> dict[str, Any]:
        return {
            "items": [
                {
                    "provider_id": constants.AUTH_PROVIDER_LOCAL,
                    "provider_name": "Local Verification",
                    "enabled": True,
                    "grant_types": [
                        "sms_code",
                        "email_code",
                        "aliyun_one_click",
                        "refresh_token",
                    ],
                },
                {
                    "provider_id": constants.AUTH_PROVIDER_APPLE,
                    "provider_name": "Sign in with Apple",
                    "enabled": True,
                    "grant_types": ["apple_identity_token"],
                },
                {
                    "provider_id": constants.AUTH_PROVIDER_WECHAT,
                    "provider_name": "WeChat",
                    "enabled": bool((self.cfg.wechat_app_id or "").strip())
                    and bool((self.cfg.wechat_app_secret or "").strip()),
                    "grant_types": ["wechat_auth_code"],
                }
            ]
        }

    def normalize_phone_area_code(
        self,
        phone_area_code: str | None,
        *,
        default: str = "+86",
    ) -> str:
        normalized = re.sub(r"[^\d+]", "", (phone_area_code or "").strip())
        if not normalized:
            normalized = default
        if normalized.startswith("00"):
            normalized = f"+{normalized[2:]}"
        if not normalized.startswith("+"):
            normalized = f"+{normalized}"
        digits = normalized[1:]
        if not digits.isdigit() or not (1 <= len(digits) <= 4):
            raise AppHTTPException(status_code=422, detail="Invalid phone area code")
        return f"+{digits}"

    def normalize_phone(
        self,
        phone: str,
        *,
        phone_area_code: str | None = None,
        default_area_code: str = "+86",
    ) -> str:
        normalized_phone, _, _ = self._split_phone_parts(
            phone,
            phone_area_code=phone_area_code,
            default_area_code=default_area_code,
        )
        return normalized_phone

    def _split_phone_parts(
        self,
        phone: str,
        *,
        phone_area_code: str | None = None,
        default_area_code: str = "+86",
    ) -> tuple[str, str, str]:
        cleaned = re.sub(r"[^\d+]", "", (phone or "").strip())
        if cleaned.startswith("00"):
            cleaned = f"+{cleaned[2:]}"

        explicit_area_code = (
            self.normalize_phone_area_code(phone_area_code, default=default_area_code)
            if phone_area_code is not None
            else None
        )
        default_code = self.normalize_phone_area_code(None, default=default_area_code)

        if not cleaned:
            raise AppHTTPException(status_code=422, detail="请输入手机号")

        if cleaned.startswith("+"):
            digits = cleaned[1:]
            if not digits.isdigit() or not (7 <= len(digits) <= 15):
                raise AppHTTPException(status_code=422, detail="Invalid phone number")

            area_code = explicit_area_code
            if area_code is None:
                for candidate in self._KNOWN_PHONE_AREA_CODES:
                    code_digits = candidate[1:]
                    if digits.startswith(code_digits) and len(digits) > len(code_digits):
                        area_code = candidate
                        break
            if area_code is None:
                area_code = default_code

            area_digits = area_code[1:]
            if digits.startswith(area_digits) and len(digits) > len(area_digits):
                local_phone = digits[len(area_digits) :]
                normalized_phone = f"+{digits}"
            else:
                local_phone = digits
                normalized_phone = f"{area_code}{local_phone}"
        else:
            digits = cleaned
            if not digits.isdigit():
                raise AppHTTPException(status_code=422, detail="Invalid phone number")
            area_code = explicit_area_code or default_code
            area_digits = area_code[1:]
            if digits.startswith(area_digits) and len(digits) > len(area_digits):
                local_phone = digits[len(area_digits) :]
            else:
                local_phone = digits
            normalized_phone = f"{area_code}{local_phone}"

        normalized_digits = normalized_phone[1:] if normalized_phone.startswith("+") else normalized_phone
        if not (7 <= len(normalized_digits) <= 15):
            raise AppHTTPException(status_code=422, detail="Invalid phone number")
        if not local_phone.isdigit():
            raise AppHTTPException(status_code=422, detail="Invalid phone number")

        return normalized_phone, area_code, local_phone

    def _compose_e164_phone(self, local_phone: str, phone_area_code: str) -> str:
        digits = re.sub(r"\D", "", (local_phone or "").strip())
        if not digits:
            raise AppHTTPException(status_code=422, detail="Invalid phone number")
        normalized_area_code = self.normalize_phone_area_code(phone_area_code)
        normalized_phone = f"{normalized_area_code}{digits}"
        normalized_digits = normalized_phone[1:]
        if not (7 <= len(normalized_digits) <= 15):
            raise AppHTTPException(status_code=422, detail="Invalid phone number")
        return normalized_phone

    def _is_admin_whitelist_bypass(self, phone: str, code: str) -> bool:
        if str(code or "").strip() != self.ADMIN_WHITELIST_BYPASS_CODE:
            return False
        whitelist = {
            item.strip()
            for item in (self.cfg.admin_phone_whitelist or "").split(",")
            if item.strip()
        }
        return str(phone or "").strip() in whitelist

    async def create_sms_challenge(
        self,
        phone: str,
        purpose: str,
        phone_area_code: str | None = None,
    ) -> dict[str, Any]:
        normalized_phone, _, _ = self._split_phone_parts(
            phone,
            phone_area_code=phone_area_code,
        )
        challenge, _ = await send_sms_challenge_code(
            normalized_phone,
            purpose,
        )

        payload: dict[str, Any] = {
            "challenge_id": challenge.challenge_id,
            "expire_at": self._to_iso(challenge.expire_at),
            "resend_after_seconds": self.cfg.sms_challenge_resend_seconds,
        }
        return payload

    async def create_email_challenge(self, email: str) -> dict[str, Any]:
        normalized_email = validate_register_email(email)
        ttl_seconds, resend_after_seconds = await send_register_email_code(
            normalized_email
        )
        expire_at = self._now() + timedelta(seconds=ttl_seconds)
        return {
            "email": normalized_email,
            "expire_at": self._to_iso(expire_at),
            "resend_after_seconds": resend_after_seconds,
            "provider_id": constants.AUTH_PROVIDER_LOCAL,
            "grant_type": "email_code",
        }

    async def exchange_sms_code(
        self,
        phone: str,
        challenge_id: str | None,
        code: str,
        scope: str,
        phone_area_code: str | None = None,
        push_device: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        normalized_phone, normalized_area_code, local_phone = self._split_phone_parts(
            phone,
            phone_area_code=phone_area_code,
        )
        if self._is_admin_whitelist_bypass(normalized_phone, code):
            login_type = "admin_whitelist_code"
        else:
            normalized_challenge_id = str(challenge_id or "").strip()
            if not normalized_challenge_id:
                raise AppHTTPException(status_code=422, detail="challenge_id is required")
            await self._verify_sms_challenge(
                normalized_phone,
                normalized_challenge_id,
                code,
                expected_purpose="login",
            )
            login_type = "sms_code"
        user, is_new_user = await self._get_or_create_local_user(
            local_phone,
            phone_area_code=normalized_area_code,
            login_type=login_type,
        )
        return await self._build_auth_payload(
            user,
            scope=scope or self._default_scope(),
            is_new_user=is_new_user,
            provider_id=constants.AUTH_PROVIDER_LOCAL,
            push_device=push_device,
        )

    async def exchange_email_code(
        self,
        email: str,
        code: str,
        scope: str,
        push_device: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        normalized_email = validate_register_email(email)
        await verify_register_email_code(normalized_email, code)

        user, is_new_user = await self._get_or_create_local_user_by_email(
            normalized_email
        )
        return await self._build_auth_payload(
            user,
            scope=scope or self._default_scope(),
            is_new_user=is_new_user,
            provider_id=constants.AUTH_PROVIDER_LOCAL,
            push_device=push_device,
        )

    async def exchange_aliyun_one_click_token(
        self,
        one_click_token: str,
        scope: str,
        push_device: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        pns_data = await self.external_auth_service.resolve_aliyun_mobile_number(
            one_click_token
        )
        normalized_phone, normalized_area_code, local_phone = self._split_phone_parts(
            str(pns_data.get("phone") or ""),
            default_area_code="+86",
        )
        user, is_new_user = await self._get_or_create_local_user(
            local_phone,
            phone_area_code=normalized_area_code,
            login_type="aliyun_one_click",
        )
        payload = await self._build_auth_payload(
            user,
            scope=scope or self._default_scope(),
            is_new_user=is_new_user,
            provider_id=constants.AUTH_PROVIDER_LOCAL,
            push_device=push_device,
        )
        payload["phone_auth"] = {
            "phone": local_phone,
            "phone_area_code": normalized_area_code,
            "phone_e164": normalized_phone,
            "carrier": pns_data.get("carrier"),
            "request_id": pns_data.get("request_id"),
        }
        return payload

    async def exchange_apple_identity_token(
        self,
        identity_token: str,
        scope: str,
        *,
        authorization_code: str | None = None,
        full_name: dict[str, Any] | None = None,
        push_device: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        identity = await self.external_auth_service.verify_apple_identity_token(
            identity_token,
            authorization_code=authorization_code,
            full_name=full_name,
        )
        user, is_new_user = await self._get_or_create_external_user(identity)
        return await self._build_auth_payload(
            user,
            scope=scope or self._default_scope(),
            is_new_user=is_new_user,
            provider_id=identity.provider_id,
            push_device=push_device,
        )

    async def exchange_wechat_auth_code(
        self,
        auth_code: str,
        scope: str,
        push_device: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        identity = await self.external_auth_service.exchange_wechat_auth_code(
            auth_code
        )
        user, is_new_user = await self._get_or_create_external_user(identity)
        return await self._build_auth_payload(
            user,
            scope=scope or self._default_scope(),
            is_new_user=is_new_user,
            provider_id=identity.provider_id,
            push_device=push_device,
        )

    async def bind_phone(
        self,
        user: User,
        phone: str,
        challenge_id: str,
        code: str,
        phone_area_code: str | None = None,
    ) -> dict[str, Any]:
        normalized_phone, normalized_area_code, local_phone = self._split_phone_parts(
            phone,
            phone_area_code=phone_area_code,
        )
        previous_subject = None
        if user.phonenum:
            previous_subject = self._compose_e164_phone(
                user.phonenum,
                user.phone_area_code or normalized_area_code,
            )
        await self._verify_sms_challenge(
            normalized_phone,
            challenge_id,
            code,
            expected_purpose="bind_phone",
        )
        await self._ensure_phone_available(
            local_phone,
            normalized_area_code,
            user.user_id,
            normalized_phone=normalized_phone,
        )

        async with transaction_scope() as session:
            user.phonenum = local_phone
            user.phone_area_code = normalized_area_code
            await self.user_dao.save(user, session=session)
            await self._replace_local_identity_subject(
                user=user,
                previous_subject=previous_subject,
                next_subject=normalized_phone,
                next_username=normalized_phone,
                next_email=None,
                profile_updates={"login_type": "sms_code", "bind_method": "settings"},
                session=session,
            )
        await self._invalidate_auth_sessions_for_user(user.user_id)
        return await self.get_account_bundle(user)

    async def bind_email(
        self,
        user: User,
        email: str,
        code: str,
    ) -> dict[str, Any]:
        normalized_email = validate_register_email(email)
        previous_subject = normalize_email(user.email) if user.email else None
        await verify_register_email_code(normalized_email, code)
        await self._ensure_email_available(normalized_email, user.user_id)

        async with transaction_scope() as session:
            user.email = normalized_email
            if not user.nickname:
                user.nickname = normalized_email.split("@", 1)[0]
            await self.user_dao.save(user, session=session)
            await self._replace_local_identity_subject(
                user=user,
                previous_subject=previous_subject,
                next_subject=normalized_email,
                next_username=normalized_email,
                next_email=normalized_email,
                profile_updates={"login_type": "email_code", "bind_method": "settings"},
                session=session,
            )
        await self._invalidate_auth_sessions_for_user(user.user_id)
        return await self.get_account_bundle(user)

    async def bind_identity(
        self,
        user: User,
        *,
        provider_id: str,
        apple_identity_token: str | None = None,
        apple_authorization_code: str | None = None,
        apple_full_name: dict[str, Any] | None = None,
        wechat_auth_code: str | None = None,
    ) -> dict[str, Any]:
        if provider_id == constants.AUTH_PROVIDER_APPLE:
            identity = await self.external_auth_service.verify_apple_identity_token(
                apple_identity_token or "",
                authorization_code=apple_authorization_code,
                full_name=apple_full_name,
            )
            return await self._bind_external_identity(user, identity)

        if provider_id == constants.AUTH_PROVIDER_WECHAT:
            identity = await self.external_auth_service.exchange_wechat_auth_code(
                wechat_auth_code or ""
            )
            return await self._bind_external_identity(user, identity)

        raise AppHTTPException(status_code=422, detail="Unsupported provider")

    async def delete_account(
        self,
        user: User,
    ) -> dict[str, Any]:
        user_id = user.user_id
        started_at = time.perf_counter()

        async with transaction_scope() as session:
            await self.identity_dao.delete_where(
                UserExternalIdentity,
                [UserExternalIdentity.user_id == user_id],
                session=session,
            )
            await self.user_config_dao.delete_where(
                UserConfig,
                [UserConfig.user_id == user_id],
                session=session,
            )
            await self.calendar_link_dao.delete_where(
                CalendarEventLink,
                [CalendarEventLink.user_id == user_id],
                session=session,
            )
            await self.calendar_context_dao.delete_where(
                AppleCalendarContext,
                [AppleCalendarContext.user_id == user_id],
                session=session,
            )
            await self.calendar_provider_connection_dao.delete_where(
                CalendarProviderConnection,
                [CalendarProviderConnection.user_id == user_id],
                session=session,
            )
            await self.calendar_event_dao.delete_where(
                CalendarEvent,
                [CalendarEvent.user_id == user_id],
                session=session,
            )
            await self.push_device_dao.delete_where(
                UserPushDevice,
                [UserPushDevice.user_id == user_id],
                session=session,
            )
            await self.agent_message_dao.delete_where(
                AgentMessage,
                [AgentMessage.user_id == user_id],
                session=session,
            )
            await self.agent_session_dao.delete_where(
                AgentSession,
                [AgentSession.user_id == user_id],
                session=session,
            )
            deleted_at = self._now()
            user.username = f"deleted_{user_id}"
            user.nickname = None
            user.email = None
            user.phonenum = None
            user.phone_area_code = None
            user.avatar_url = None
            user.password_hash = f"!deleted-{secrets.token_urlsafe(24)}!"
            user.status = constants.USER_STATUS_DELETED
            user.deleted_at = deleted_at
            await self.user_dao.save(user, session=session)
        db_elapsed_ms = int((time.perf_counter() - started_at) * 1000)

        await self.state_store.delete_refresh_tokens_by_user(user_id)
        await self.state_store.delete_access_tokens_by_user(user_id)
        await self._invalidate_auth_sessions_for_user(user_id)
        await redis.delete(redis.key("membership", "entitlement", user_id))
        redis_elapsed_ms = int((time.perf_counter() - started_at) * 1000)
        self._schedule_user_uploads_cleanup(user_id=user_id)
        cleanup_schedule_elapsed_ms = int((time.perf_counter() - started_at) * 1000)
        self._schedule_sage_workspace_cleanup(
            user_id=user_id,
        )
        total_elapsed_ms = int((time.perf_counter() - started_at) * 1000)
        logger.info(
            "[AuthService] 账户注销完成 "
            f"user_id={user_id} db_ms={db_elapsed_ms} "
            f"redis_ms={redis_elapsed_ms - db_elapsed_ms} "
            f"cleanup_schedule_ms={cleanup_schedule_elapsed_ms - redis_elapsed_ms} "
            f"total_ms={total_elapsed_ms}"
        )

        return {"deleted": True, "user_id": user_id}

    def _schedule_user_uploads_cleanup(
        self,
        *,
        user_id: str,
    ) -> None:
        async def _run() -> None:
            started_at = time.perf_counter()
            deleted_count = await self._delete_user_uploads(user_id)
            elapsed_ms = int((time.perf_counter() - started_at) * 1000)
            logger.info(
                f"[AuthService] 用户上传文件清理完成 user_id={user_id} "
                f"deleted_count={deleted_count} elapsed_ms={elapsed_ms}"
            )

        task_coro = _run()
        try:
            asyncio.create_task(task_coro)
        except Exception as exc:
            task_coro.close()
            logger.warning(
                f"[AuthService] 安排用户上传文件清理失败 user_id={user_id} "
                f"reason={exc}"
            )

    def _schedule_sage_workspace_cleanup(
        self,
        *,
        user_id: str,
    ) -> None:
        async def _run() -> None:
            try:
                await self.sage_client.delete_workspace(
                    user_id=user_id,
                    agent_id=self.cfg.sage_agent_id,
                )
            except Exception:
                logger.exception(
                    "[AuthService] 清理 Sage workspace 失败。"
                    f"user_id={user_id} agent_id={self.cfg.sage_agent_id}"
                )

        task_coro = _run()
        try:
            asyncio.create_task(task_coro)
        except Exception as exc:
            task_coro.close()
            logger.warning(
                "[AuthService] 安排 Sage workspace 清理失败。"
                f"user_id={user_id} agent_id={self.cfg.sage_agent_id} reason={exc}"
            )

    async def get_account_bundle(self, user: User) -> dict[str, Any]:
        fresh_user = await self.user_dao.get_by_id(user.user_id)
        if fresh_user is None:
            raise AppHTTPException(status_code=404, detail="User not found")
        return {
            "profile": await self.get_profile_bundle(fresh_user),
            "identities": await self.list_identities(fresh_user.user_id),
        }

    async def refresh_access_token(self, refresh_token: str) -> dict[str, Any]:
        token_hash = self._hash_token(refresh_token)
        async with redis.lock_or_raise(
            f"auth:refresh:{token_hash}",
            error=AppHTTPException(
                status_code=409,
                detail="Refresh token is busy",
            ),
            ttl_seconds=15,
            wait_timeout_seconds=5,
        ):

            token_obj = await self.state_store.get_refresh_token(token_hash)
            if token_obj is None:
                raise AppHTTPException(status_code=401, detail="Invalid refresh token")

            now = self._now()
            if token_obj.revoked_at is not None:
                raise AppHTTPException(status_code=401, detail="Refresh token revoked")
            if token_obj.expire_at < now:
                raise AppHTTPException(status_code=401, detail="Refresh token expired")

            user = await self.user_dao.get_by_id(token_obj.user_id)
            if user is None:
                raise AppHTTPException(status_code=401, detail="User not found")
            device_id = str((token_obj.extra_data or {}).get("device_id") or "").strip()
            await self._require_active_push_device(
                user_id=user.user_id,
                device_id=device_id,
            )

            token_obj.revoked_at = now
            token_obj.last_used_at = now
            token_obj.updated_at = now
            await self.state_store.save_refresh_token(token_obj)
            await self.state_store.delete_access_tokens_by_device(
                user.user_id,
                device_id,
            )

            tokens = await self._issue_tokens(
                user,
                scope=token_obj.scope,
                provider_id=token_obj.provider_id,
                device_id=device_id,
            )
            return {
                **tokens,
                "user": await self.get_profile_bundle(user),
                "identities": [
                    self.serialize_identity(item)
                    for item in await self.identity_dao.list_by_user_id(user.user_id)
                ],
            }

    async def revoke_refresh_token(self, refresh_token: str) -> dict[str, Any]:
        token_hash = self._hash_token(refresh_token)
        async with redis.lock(
            f"auth:refresh:{token_hash}",
            ttl_seconds=15,
            wait_timeout_seconds=1,
        ) as acquired:
            if not acquired:
                return {"revoked": True}
            token_obj = await self.state_store.get_refresh_token(token_hash)
            if token_obj:
                now = self._now()
                token_obj.revoked_at = now
                token_obj.updated_at = now
                await self.state_store.save_refresh_token(token_obj)
        return {"revoked": True}

    async def get_profile_bundle(self, user: User) -> dict[str, Any]:
        config = await self.user_config_dao.get_config(user.user_id)
        from models.user import (
            DEFAULT_QUIET_HOURS_END,
            DEFAULT_QUIET_HOURS_START,
            coerce_preferred_input_mode_stored,
        )
        preferences = dict(config)
        preferences.setdefault(
            "quiet_hours_start", DEFAULT_QUIET_HOURS_START,
        )
        preferences.setdefault(
            "quiet_hours_end", DEFAULT_QUIET_HOURS_END,
        )
        preferences["preferred_input_mode"] = coerce_preferred_input_mode_stored(
            preferences.get("preferred_input_mode"),
        )
        return {
            **self.serialize_user(user),
            "preferences": preferences,
        }

    async def list_identities(self, user_id: str) -> list[dict[str, Any]]:
        identities = await self.identity_dao.list_by_user_id(user_id)
        return [self.serialize_identity(item) for item in identities]

    def serialize_user(self, user: User) -> dict[str, Any]:
        return {
            "user_id": user.user_id,
            "username": user.username,
            "nickname": user.nickname,
            "email": user.email,
            "phonenum": user.phonenum,
            "phone_area_code": user.phone_area_code,
            "role": user.role,
            "avatar_url": user.avatar_url,
        }

    def serialize_identity(self, identity: UserExternalIdentity) -> dict[str, Any]:
        return {
            "identity_id": identity.identity_id,
            "user_id": identity.user_id,
            "provider_id": identity.provider_id,
            "provider_subject": identity.provider_subject,
            "provider_username": identity.provider_username,
            "provider_email": identity.provider_email,
            "profile": identity.profile,
        }

    async def _build_auth_payload(
        self,
        user: User,
        *,
        scope: str,
        is_new_user: bool,
        provider_id: str,
        push_device: dict[str, Any] | None,
    ) -> dict[str, Any]:
        if push_device is None:
            raise AppHTTPException(status_code=422, detail="push_device is required")

        async with redis.lock_or_raise(
            f"auth:login:user:{user.user_id}",
            error=AppHTTPException(
                status_code=409,
                detail="Login is busy",
            ),
            ttl_seconds=15,
            wait_timeout_seconds=5,
        ):
            registered_device = await self._register_login_push_device(
                user_id=user.user_id,
                push_device=push_device,
            )
            device_id = str(registered_device.get("device_id") or "").strip()
            if not device_id:
                raise AppHTTPException(status_code=422, detail="push_device is required")
            await self.state_store.delete_refresh_tokens_by_user(user.user_id)
            await self.state_store.delete_access_tokens_by_user(user.user_id)
            identities = await self.identity_dao.list_by_user_id(user.user_id)
            tokens = await self._issue_tokens(
                user,
                scope=scope,
                provider_id=provider_id,
                device_id=device_id,
            )
        return {
            **tokens,
            "user": await self.get_profile_bundle(user),
            "identities": [self.serialize_identity(item) for item in identities],
            "is_new_user": is_new_user,
        }

    async def _register_login_push_device(
        self,
        *,
        user_id: str,
        push_device: dict[str, Any],
    ) -> dict[str, Any]:
        return await PushNotificationService().register_device(
            user_id=user_id,
            device_id=str(push_device.get("device_id") or ""),
            platform=str(push_device.get("platform") or constants.PLATFORM_IOS),
            transport=str(push_device.get("transport") or constants.PUSH_TRANSPORT_APNS),
            push_token=str(push_device.get("push_token") or ""),
            app_bundle_id=push_device.get("app_bundle_id"),
            apns_environment=push_device.get("apns_environment"),
            locale=push_device.get("locale"),
            timezone=push_device.get("timezone"),
            device_model=push_device.get("device_model"),
            formatted_address=push_device.get("formatted_address"),
            name=push_device.get("name"),
            thoroughfare=push_device.get("thoroughfare"),
            sub_thoroughfare=push_device.get("sub_thoroughfare"),
            sub_locality=push_device.get("sub_locality"),
            locality=push_device.get("locality"),
            sub_administrative_area=push_device.get("sub_administrative_area"),
            city=push_device.get("city"),
            administrative_area=push_device.get("administrative_area"),
            postal_code=push_device.get("postal_code"),
            country=push_device.get("country"),
            iso_country_code=push_device.get("iso_country_code"),
            areas_of_interest=push_device.get("areas_of_interest"),
            latitude=push_device.get("latitude"),
            longitude=push_device.get("longitude"),
            accuracy_meters=push_device.get("accuracy_meters"),
            captured_at=push_device.get("captured_at"),
            notifications_enabled=bool(push_device.get("notifications_enabled", True)),
        )

    async def _require_active_push_device(
        self,
        *,
        user_id: str,
        device_id: str,
    ) -> UserPushDevice:
        normalized_device_id = (device_id or "").strip()
        if not normalized_device_id:
            raise AppHTTPException(status_code=401, detail="Device session required")
        device = await self.push_device_dao.get_user_device(
            user_id,
            normalized_device_id,
        )
        if device is None:
            raise AppHTTPException(status_code=401, detail="Device session revoked")
        return device

    async def _verify_sms_challenge(
        self,
        phone: str,
        challenge_id: str,
        code: str,
        *,
        expected_purpose: str,
    ) -> None:
        challenge = await self.state_store.get_sms_challenge(challenge_id)
        if challenge is None or challenge.provider_id != constants.AUTH_PROVIDER_LOCAL:
            raise AppHTTPException(status_code=400, detail="Invalid challenge")
        if challenge.phone != phone:
            raise AppHTTPException(status_code=400, detail="Phone mismatch")
        if challenge.purpose != expected_purpose:
            raise AppHTTPException(status_code=400, detail="Challenge purpose mismatch")
        if challenge.status != constants.AUTH_CHALLENGE_STATUS_PENDING:
            raise AppHTTPException(status_code=400, detail="Challenge already used")

        now = self._now()
        if challenge.expire_at < now:
            challenge.status = constants.AUTH_CHALLENGE_STATUS_EXPIRED
            challenge.updated_at = now
            await self.state_store.save_sms_challenge(challenge)
            raise AppHTTPException(status_code=400, detail="Challenge expired")
        if challenge.attempt_count >= challenge.max_attempts:
            challenge.status = constants.AUTH_CHALLENGE_STATUS_FAILED
            challenge.updated_at = now
            await self.state_store.save_sms_challenge(challenge)
            raise AppHTTPException(status_code=400, detail="Challenge exceeded attempts")

        challenge.attempt_count += 1
        challenge.updated_at = now
        if challenge.code_hash != self._hash_token(code):
            await self.state_store.save_sms_challenge(challenge)
            raise AppHTTPException(status_code=400, detail="Invalid verification code")

        challenge.status = constants.AUTH_CHALLENGE_STATUS_VERIFIED
        challenge.consumed_at = now
        await self.state_store.save_sms_challenge(challenge)

    async def _ensure_phone_available(
        self,
        phone: str,
        phone_area_code: str,
        current_user_id: str,
        *,
        normalized_phone: str | None = None,
    ) -> None:
        existing_user = await self.user_dao.get_by_phone(phone, phone_area_code)
        if existing_user and existing_user.user_id != current_user_id:
            raise AppHTTPException(
                status_code=409,
                detail="Phone already bound by another user",
                error_code="phone_already_exists",
            )

        provider_subject = normalized_phone or self._compose_e164_phone(phone, phone_area_code)
        existing_identity = await self.identity_dao.get_by_provider_subject(
            constants.AUTH_PROVIDER_LOCAL,
            provider_subject,
        )
        if existing_identity and existing_identity.user_id != current_user_id:
            raise AppHTTPException(
                status_code=409,
                detail="Phone already bound by another user",
                error_code="phone_already_exists",
            )

    async def _ensure_email_available(self, email: str, current_user_id: str) -> None:
        existing_user = await self.user_dao.get_by_email(email)
        if existing_user and existing_user.user_id != current_user_id:
            raise AppHTTPException(
                status_code=409,
                detail="Email already bound by another user",
                error_code="email_already_exists",
            )

        existing_identity = await self.identity_dao.get_by_provider_subject(constants.AUTH_PROVIDER_LOCAL, email)
        if existing_identity and existing_identity.user_id != current_user_id:
            raise AppHTTPException(
                status_code=409,
                detail="Email already bound by another user",
                error_code="email_already_exists",
            )

    async def _create_default_user_config(
        self,
        user_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> None:
        await self.user_config_dao.insert(
            UserConfig(
                user_id=user_id,
                config={
                    "timezone": constants.DEFAULT_TIMEZONE,
                    "locale": constants.DEFAULT_LOCALE,
                    "default_calendar_provider": constants.DEFAULT_CALENDAR_PROVIDER,
                },
            ),
            session=session,
        )

    async def _upsert_local_identity(
        self,
        *,
        user: User,
        provider_subject: str,
        provider_username: str | None,
        provider_email: str | None,
        profile_updates: dict[str, Any],
        session: AsyncSession | None = None,
    ) -> None:
        await self._upsert_identity(
            user=user,
            provider_id=constants.AUTH_PROVIDER_LOCAL,
            provider_subject=provider_subject,
            provider_username=provider_username,
            provider_email=provider_email,
            profile_updates=profile_updates,
            session=session,
        )

    async def _replace_local_identity_subject(
        self,
        *,
        user: User,
        previous_subject: str | None,
        next_subject: str,
        next_username: str | None,
        next_email: str | None,
        profile_updates: dict[str, Any],
        session: AsyncSession | None = None,
    ) -> None:
        target_identity = await self.identity_dao.get_by_provider_subject(
            constants.AUTH_PROVIDER_LOCAL,
            next_subject,
            session=session,
        )
        if target_identity and target_identity.user_id != user.user_id:
            raise AppHTTPException(
                status_code=409,
                detail="Identity already linked to another user",
                error_code="identity_already_exists",
            )

        previous_identity = None
        if previous_subject:
            previous_identity = await self.identity_dao.get_by_provider_subject(
                constants.AUTH_PROVIDER_LOCAL,
                previous_subject,
                session=session,
            )

        if target_identity and target_identity.user_id == user.user_id:
            profile = dict(target_identity.profile or {})
            profile.update(profile_updates)
            target_identity.profile = profile
            target_identity.provider_username = next_username
            target_identity.provider_email = next_email
            await self.identity_dao.save(target_identity, session=session)
            if (
                previous_identity
                and previous_identity.identity_id != target_identity.identity_id
                and previous_identity.user_id == user.user_id
            ):
                await self.identity_dao.delete_by_id(
                    UserExternalIdentity,
                    previous_identity.identity_id,
                    session=session,
                )
            return

        if previous_identity and previous_identity.user_id == user.user_id:
            profile = dict(previous_identity.profile or {})
            profile.update(profile_updates)
            previous_identity.provider_subject = next_subject
            previous_identity.provider_username = next_username
            previous_identity.provider_email = next_email
            previous_identity.profile = profile
            await self.identity_dao.save(
                previous_identity,
                session=session,
            )
            return

        await self._upsert_local_identity(
            user=user,
            provider_subject=next_subject,
            provider_username=next_username,
            provider_email=next_email,
            profile_updates=profile_updates,
            session=session,
        )

    async def _upsert_identity(
        self,
        *,
        user: User,
        provider_id: str,
        provider_subject: str,
        provider_username: str | None,
        provider_email: str | None,
        profile_updates: dict[str, Any],
        session: AsyncSession | None = None,
    ) -> None:
        identity = await self.identity_dao.get_by_provider_subject(
            provider_id,
            provider_subject,
            session=session,
        )
        if identity:
            if identity.user_id != user.user_id:
                raise AppHTTPException(
                    status_code=409,
                    detail="Identity already linked to another user",
                    error_code="identity_already_exists",
                )
            profile = dict(identity.profile or {})
            profile.update(profile_updates)
            identity.profile = profile
            identity.provider_username = provider_username
            identity.provider_email = provider_email
            await self.identity_dao.save(identity, session=session)
            return

        await self.identity_dao.insert(
            UserExternalIdentity(
                identity_id=f"ident_{uuid.uuid4().hex}",
                user_id=user.user_id,
                provider_id=provider_id,
                provider_subject=provider_subject,
                provider_username=provider_username,
                provider_email=provider_email,
                profile=profile_updates,
            ),
            session=session,
        )

    async def _bind_external_identity(
        self,
        user: User,
        identity: ExternalIdentityPayload,
        *,
        session: AsyncSession | None = None,
    ) -> dict[str, Any]:
        async with transaction_scope(session) as active_session:
            existing = await self.identity_dao.get_by_provider_subject(
                identity.provider_id,
                identity.provider_subject,
                session=active_session,
            )
            if existing and existing.user_id != user.user_id:
                raise AppHTTPException(
                    status_code=409,
                    detail="Identity already linked to another user",
                    error_code="identity_already_exists",
                )

            await self._upsert_identity(
                user=user,
                provider_id=identity.provider_id,
                provider_subject=identity.provider_subject,
                provider_username=identity.provider_username,
                provider_email=identity.provider_email,
                profile_updates=identity.profile,
                session=active_session,
            )
            if await self._apply_external_profile_to_user(user, identity):
                await self.user_dao.save(user, session=active_session)
        await self._invalidate_auth_sessions_for_user(user.user_id)
        return await self.get_account_bundle(user)

    async def _invalidate_auth_sessions_for_user(self, user_id: str) -> None:
        try:
            await self.state_store.delete_access_tokens_by_user(user_id)
        except Exception as exc:
            logger.warning(
                f"[AuthService] 清理用户 access token 失败 user_id={user_id}: {exc}"
            )

    async def _delete_user_uploads(self, user_id: str) -> int:
        object_prefix = s3.object_key(
            "agent_images",
            user_id,
        )
        try:
            return await s3.delete_prefix(object_prefix, cfg=self.cfg)
        except Exception:
            logger.warning(f"[AuthService] 删除对象存储上传文件失败 user_id={user_id}")
            return 0

    async def _get_or_create_local_user(
        self,
        phone: str,
        *,
        phone_area_code: str,
        login_type: str,
        session: AsyncSession | None = None,
    ) -> tuple[User, bool]:
        normalized_phone = self._compose_e164_phone(phone, phone_area_code)
        async with transaction_scope(session) as active_session:
            identity = await self.identity_dao.get_by_provider_subject(
                constants.AUTH_PROVIDER_LOCAL,
                normalized_phone,
                session=active_session,
            )
            if identity:
                user = await self.user_dao.get_by_id(
                    identity.user_id,
                    session=active_session,
                )
                if user is None:
                    raise AppHTTPException(status_code=500, detail="Linked user missing")
                if (
                    user.phonenum != phone
                    or user.phone_area_code != phone_area_code
                ):
                    user.phonenum = phone
                    user.phone_area_code = phone_area_code
                    await self.user_dao.save(user, session=active_session)
                return user, False

            user = await self.user_dao.get_by_phone(
                phone,
                phone_area_code,
                session=active_session,
            )
            created = False
            if user is None:
                created = True
                user = User(
                    user_id=f"u_{uuid.uuid4().hex}",
                    username=await self._build_unique_username_from_phone(
                        phone,
                        phone_area_code=phone_area_code,
                    ),
                    password_hash="!sms-login!",
                    phonenum=phone,
                    phone_area_code=phone_area_code,
                )
                await self.user_dao.insert(user, session=active_session)
                await self._create_default_user_config(
                    user.user_id,
                    session=active_session,
                )
            elif (
                user.phonenum != phone
                or user.phone_area_code != phone_area_code
            ):
                user.phonenum = phone
                user.phone_area_code = phone_area_code
                await self.user_dao.save(user, session=active_session)

            await self._upsert_local_identity(
                user=user,
                provider_subject=normalized_phone,
                provider_username=normalized_phone,
                provider_email=None,
                profile_updates={"login_type": login_type},
                session=active_session,
            )
            return user, created

    async def _get_or_create_local_user_by_email(
        self,
        email: str,
        *,
        session: AsyncSession | None = None,
    ) -> tuple[User, bool]:
        normalized_email = normalize_email(email)
        async with transaction_scope(session) as active_session:
            identity = await self.identity_dao.get_by_provider_subject(
                constants.AUTH_PROVIDER_LOCAL,
                normalized_email,
                session=active_session,
            )
            if identity:
                user = await self.user_dao.get_by_id(
                    identity.user_id,
                    session=active_session,
                )
                if user is None:
                    raise AppHTTPException(status_code=500, detail="Linked user missing")
                return user, False

            user = await self.user_dao.get_by_email(
                normalized_email,
                session=active_session,
            )
            created = False
            if user is None:
                created = True
                user = User(
                    user_id=f"u_{uuid.uuid4().hex}",
                    username=await self._build_unique_username_from_email(normalized_email),
                    password_hash="!email-login!",
                    email=normalized_email,
                    nickname=normalized_email.split("@", 1)[0],
                )
                await self.user_dao.insert(user, session=active_session)
                await self._create_default_user_config(
                    user.user_id,
                    session=active_session,
                )
            elif not user.email:
                user.email = normalized_email
                await self.user_dao.save(user, session=active_session)

            await self._upsert_local_identity(
                user=user,
                provider_subject=normalized_email,
                provider_username=normalized_email,
                provider_email=normalized_email,
                profile_updates={"login_type": "email_code"},
                session=active_session,
            )
            return user, created

    async def _get_or_create_external_user(
        self,
        identity_payload: ExternalIdentityPayload,
        *,
        session: AsyncSession | None = None,
    ) -> tuple[User, bool]:
        async with transaction_scope(session) as active_session:
            identity = await self.identity_dao.get_by_provider_subject(
                identity_payload.provider_id,
                identity_payload.provider_subject,
                session=active_session,
            )
            if identity:
                user = await self.user_dao.get_by_id(
                    identity.user_id,
                    session=active_session,
                )
                if user is None:
                    raise AppHTTPException(status_code=500, detail="Linked user missing")
                await self._upsert_identity(
                    user=user,
                    provider_id=identity_payload.provider_id,
                    provider_subject=identity_payload.provider_subject,
                    provider_username=identity_payload.provider_username,
                    provider_email=identity_payload.provider_email,
                    profile_updates=identity_payload.profile,
                    session=active_session,
                )
                if await self._apply_external_profile_to_user(user, identity_payload):
                    await self.user_dao.save(user, session=active_session)
                return user, False

            user = User(
                user_id=f"u_{uuid.uuid4().hex}",
                username=await self._build_unique_username_from_external_identity(
                    identity_payload
                ),
                password_hash=f"!{identity_payload.provider_id}-login!",
                nickname=identity_payload.nickname,
                avatar_url=identity_payload.avatar_url,
            )
            await self.user_dao.insert(user, session=active_session)
            await self._create_default_user_config(
                user.user_id,
                session=active_session,
            )
            await self._upsert_identity(
                user=user,
                provider_id=identity_payload.provider_id,
                provider_subject=identity_payload.provider_subject,
                provider_username=identity_payload.provider_username,
                provider_email=identity_payload.provider_email,
                profile_updates=identity_payload.profile,
                session=active_session,
            )
            return user, True

    async def _apply_external_profile_to_user(
        self,
        user: User,
        identity_payload: ExternalIdentityPayload,
    ) -> bool:
        changed = False
        if not (user.nickname or "").strip() and (identity_payload.nickname or "").strip():
            user.nickname = identity_payload.nickname
            changed = True
        if not (user.avatar_url or "").strip() and (identity_payload.avatar_url or "").strip():
            user.avatar_url = identity_payload.avatar_url
            changed = True
        return changed

    async def _build_unique_username_from_phone(
        self,
        phone: str,
        *,
        phone_area_code: str,
    ) -> str:
        area_digits = re.sub(r"\D", "", phone_area_code)
        phone_digits = re.sub(r"\D", "", phone)
        return await self._build_unique_username_candidate(
            f"u{area_digits}{phone_digits}",
        )

    async def _build_unique_username_from_email(self, email: str) -> str:
        local_part = (email or "").split("@", 1)[0]
        return await self._build_unique_username_candidate(local_part)

    async def _build_unique_username_from_external_identity(
        self,
        identity_payload: ExternalIdentityPayload,
    ) -> str:
        preferred = (
            identity_payload.nickname
            or identity_payload.provider_email
            or identity_payload.provider_username
            or f"{identity_payload.provider_id}_{identity_payload.provider_subject[-8:]}"
        )
        return await self._build_unique_username_candidate(
            f"{identity_payload.provider_id}_{preferred}",
        )

    async def _build_unique_username_candidate(self, base: str) -> str:
        cleaned = re.sub(r"[^a-zA-Z0-9_.-]", "_", (base or "").strip())
        cleaned = cleaned.strip("._-") or "user"
        max_length = 64
        primary = cleaned[:max_length]
        if await self.user_dao.get_by_username(primary) is None:
            return primary

        for index in range(1, 10000):
            suffix = f"_{index}"
            candidate = f"{cleaned[: max_length - len(suffix)]}{suffix}"
            if await self.user_dao.get_by_username(candidate) is None:
                return candidate
        raise AppHTTPException(status_code=500, detail="Failed to build username")

    async def _issue_tokens(
        self,
        user: User,
        scope: str,
        *,
        provider_id: str,
        device_id: str,
    ) -> dict[str, Any]:
        normalized_device_id = (device_id or "").strip()
        if not normalized_device_id:
            raise AppHTTPException(status_code=401, detail="Device session required")
        now = self._now()
        access_token = f"{ACCESS_TOKEN_PREFIX}{secrets.token_urlsafe(32)}"
        access_token_obj = RedisAccessTokenState(
            token_id=f"atid_{uuid.uuid4().hex}",
            user_id=user.user_id,
            provider_id=provider_id,
            token_hash=self._hash_token(access_token),
            scope=scope,
            device_id=normalized_device_id,
            expire_at=now + timedelta(minutes=self.cfg.access_token_expire_minutes),
            created_at=now,
            updated_at=now,
            user_data=self.serialize_user(user),
            extra_data={},
        )
        await self.state_store.save_access_token(access_token_obj)

        refresh_token = f"{REFRESH_TOKEN_PREFIX}{secrets.token_urlsafe(32)}"
        token_obj = RedisRefreshTokenState(
            token_id=f"rtid_{uuid.uuid4().hex}",
            user_id=user.user_id,
            provider_id=provider_id,
            token_hash=self._hash_token(refresh_token),
            scope=scope,
            expire_at=now + timedelta(days=self.cfg.refresh_token_expire_days),
            revoked_at=None,
            last_used_at=None,
            created_at=now,
            updated_at=now,
            extra_data={"device_id": normalized_device_id},
        )
        await self.state_store.save_refresh_token(token_obj)
        return {
            "token_type": "Bearer",
            "access_token": access_token,
            "expires_in": self.cfg.access_token_expire_minutes * 60,
            "refresh_token": refresh_token,
            "scope": scope,
            "device_id": normalized_device_id,
        }

    def _hash_token(self, value: str) -> str:
        return hash_token(value)

    def _default_scope(self) -> str:
        return "openid profile calendar agent offline_access"

    def _now(self):
        from models.base import get_local_now

        return get_local_now()

    def _to_iso(self, value) -> str:
        return format_datetime(value) or ""
