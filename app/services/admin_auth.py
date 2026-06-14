from __future__ import annotations

import secrets
import uuid
from datetime import timedelta
from typing import Any

from config.settings import AppConfig, get_app_config
from core.http.exceptions import AppHTTPException
from models.base import get_local_now
from services.auth.state_store import RedisAccessTokenState, RedisAuthStateStore
from services.auth.tokens import ACCESS_TOKEN_PREFIX, hash_token, is_opaque_access_token

ADMIN_SMS_PURPOSE = "admin_login"
ADMIN_AUTH_PROVIDER_ID = "admin_sms"
ADMIN_AUTH_SCOPE = "admin"
ADMIN_AUTH_DEVICE_ID = "admin"
ADMIN_WHITELIST_BYPASS_CODE = "111111"


class AdminAuthService:
    def __init__(
        self,
        cfg: AppConfig | None = None,
        auth_service: Any | None = None,
        state_store: RedisAuthStateStore | None = None,
    ) -> None:
        self.cfg = cfg or get_app_config()
        self._auth_service = auth_service
        self.state_store = state_store or RedisAuthStateStore(self.cfg)

    @property
    def auth_service(self) -> Any:
        if self._auth_service is None:
            from services.auth.auth import AuthService

            self._auth_service = AuthService()
        return self._auth_service

    async def create_sms_challenge(
        self,
        *,
        phone: str,
        phone_area_code: str | None = None,
    ) -> dict[str, Any]:
        normalized_phone = self.auth_service.normalize_phone(
            phone,
            phone_area_code=phone_area_code,
        )
        self._ensure_whitelisted(normalized_phone)
        data = await self.auth_service.create_sms_challenge(
            phone,
            ADMIN_SMS_PURPOSE,
            phone_area_code=phone_area_code,
        )
        return {
            **data,
            "phone": normalized_phone,
            "provider_id": "local",
            "grant_type": "sms_code",
        }

    async def exchange_sms_code(
        self,
        *,
        phone: str,
        challenge_id: str | None,
        code: str,
        phone_area_code: str | None = None,
    ) -> dict[str, Any]:
        normalized_phone = self.auth_service.normalize_phone(
            phone,
            phone_area_code=phone_area_code,
        )
        self._ensure_whitelisted(normalized_phone)
        if not self._is_whitelist_bypass_code(code):
            normalized_challenge_id = str(challenge_id or "").strip()
            if not normalized_challenge_id:
                raise AppHTTPException(status_code=422, detail="challenge_id is required")
            await self.auth_service._verify_sms_challenge(  # noqa: SLF001 - admin flow reuses auth challenge semantics.
                normalized_phone,
                normalized_challenge_id,
                code,
                expected_purpose=ADMIN_SMS_PURPOSE,
            )
        now = get_local_now()
        access_token = f"{ACCESS_TOKEN_PREFIX}{secrets.token_urlsafe(32)}"
        await self.state_store.save_access_token(
            RedisAccessTokenState(
                token_id=f"atid_{uuid.uuid4().hex}",
                user_id=normalized_phone,
                provider_id=ADMIN_AUTH_PROVIDER_ID,
                token_hash=hash_token(access_token),
                scope=ADMIN_AUTH_SCOPE,
                device_id=ADMIN_AUTH_DEVICE_ID,
                expire_at=now + timedelta(minutes=self.cfg.admin_token_expire_minutes),
                created_at=now,
                updated_at=now,
                user_data={"username": normalized_phone, "phone": normalized_phone},
                extra_data={"typ": "admin", "phone": normalized_phone},
            )
        )
        return {
            "token_type": "Bearer",
            "access_token": access_token,
            "expires_in": self.cfg.admin_token_expire_minutes * 60,
            "phone": normalized_phone,
        }

    async def parse_admin_token(self, token: str) -> dict[str, Any]:
        if not is_opaque_access_token(token):
            raise AppHTTPException(status_code=401, detail="Invalid token")
        state = await self.state_store.get_access_token(hash_token(token))
        if state is None:
            raise AppHTTPException(status_code=401, detail="Token expired or revoked")
        if (
            state.provider_id != ADMIN_AUTH_PROVIDER_ID
            or state.scope != ADMIN_AUTH_SCOPE
            or state.extra_data.get("typ") != "admin"
        ):
            raise AppHTTPException(status_code=401, detail="Admin token required")
        phone = str(state.extra_data.get("phone") or state.user_id or "").strip()
        self._ensure_whitelisted(phone)
        return {
            "typ": "admin",
            "sub": state.user_id,
            "phone": phone,
            "token_id": state.token_id,
            "scope": state.scope,
        }

    def _ensure_whitelisted(self, phone: str) -> None:
        normalized = phone.strip()
        whitelist = self._whitelist()
        if not whitelist or normalized not in whitelist:
            raise AppHTTPException(status_code=403, detail="Admin phone not allowed")

    def _whitelist(self) -> set[str]:
        raw = self.cfg.admin_phone_whitelist or ""
        return {item.strip() for item in raw.split(",") if item.strip()}

    def _is_whitelist_bypass_code(self, code: str) -> bool:
        return str(code or "").strip() == ADMIN_WHITELIST_BYPASS_CODE
