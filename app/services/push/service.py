"""iOS APNs 推送与用户设备注册：token 管理、无效 token 清理、静默刷新日历上下文等。

与 UserPushDevice、ApnsClient 协作；部分重逻辑通过 BackgroundTaskRunner 限流。
"""

from __future__ import annotations

import asyncio
import hashlib
import html
import json
import math
import re
import uuid
from typing import Any

from config import constants
from core.http.exceptions import AppHTTPException
from core.infra.apns import ApnsClient, ApnsSendResult
from core.infra.background_tasks import background_tasks
from core.infra.harmony_push import HarmonyPushClient
from core.infra.redis import redis
from loguru import logger
from models.base import get_local_now
from models.calendar import (
    AppleCalendarContext,
    AppleCalendarContextDao,
    CalendarEvent,
    CalendarEventDao,
)
from models.notification import Notification, NotificationDao
from models.push import UserPushDevice, UserPushDeviceDao
from services.auth.state_store import RedisAuthStateStore
from services.badge import BadgeService
from utils.concurrency import run_with_concurrency_limit_ordered
from utils.time import format_datetime, normalize_persisted_timezone

_LING_ACTION_TAG_PATTERN = re.compile(
    r"<ling-action\b[^>]*?(?:/>\s*|>\s*</ling-action\s*>)",
    re.IGNORECASE | re.DOTALL,
)
_MARKDOWN_IMAGE_PATTERN = re.compile(r"!\[([^\]]*)\]\(([^)]*)\)")
_MARKDOWN_LINK_PATTERN = re.compile(r"\[([^\]]+)\]\(([^)]*)\)")
_HTML_TAG_PATTERN = re.compile(r"<[^>\n]+>")
_RAW_LINK_PATTERN = re.compile(r"(?<!\S)(?:https?://|file://)\S+", re.IGNORECASE)
_RAW_ABSOLUTE_PATH_PATTERN = re.compile(
    r"(?<!\S)/(?:app|Users|private|sage-workspace|agent|reports?)[^\s,，。；;]*"
)
_AGENT_COMPLETION_PREVIEW_MAX_CHARS = 120


def apns_preview_body_from_markdown(markdown: str) -> str:
    """Convert Ling message Markdown into notification-center friendly text."""
    text = html.unescape(str(markdown or ""))
    text = _LING_ACTION_TAG_PATTERN.sub("", text)
    text = _MARKDOWN_IMAGE_PATTERN.sub(lambda match: match.group(1).strip(), text)
    text = _MARKDOWN_LINK_PATTERN.sub(lambda match: match.group(1).strip(), text)
    text = _RAW_LINK_PATTERN.sub("", text)
    text = _RAW_ABSOLUTE_PATH_PATTERN.sub("", text)
    text = _HTML_TAG_PATTERN.sub("", text)
    text = re.sub(r"```(?:\w+)?", "", text)
    text = text.replace("```", "")
    text = re.sub(r"`([^`]*)`", r"\1", text)
    text = re.sub(r"^[ \t]{0,3}#{1,6}\s*", "", text, flags=re.MULTILINE)
    text = re.sub(r"^[ \t]*[-*+]\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"^[ \t]*>\s?", "", text, flags=re.MULTILINE)
    text = re.sub(r"[*_~]{1,3}", "", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\s*\n\s*", " ", text)
    return text.strip()


def agent_completion_body(
    *,
    locale: str | None = None,
    assistant_preview_text: str = "",
) -> str:
    preview = _agent_completion_preview_text(assistant_preview_text)
    if preview:
        return preview
    if (locale or "").lower().startswith("zh"):
        return "Ling已经完成了您的请求"
    return "Ling has completed your request"


def _agent_completion_preview_text(text: str) -> str:
    preview = apns_preview_body_from_markdown(text)
    if len(preview) <= _AGENT_COMPLETION_PREVIEW_MAX_CHARS:
        return preview
    return preview[: _AGENT_COMPLETION_PREVIEW_MAX_CHARS - 3].rstrip() + "..."


class PushNotificationService:
    """设备注册、payload 构造、向 APNs 发送应用通知及上下文衍生查询。"""

    _INVALID_TOKEN_REASONS = {
        "BadDeviceToken",
        "DeviceTokenNotForTopic",
        "Unregistered",
        "InvalidToken",
        "invalid_token",
    }
    _DEVICE_CONTEXT_REFRESH_TIMEOUT_SECONDS = 6.0
    _DEVICE_CONTEXT_REFRESH_POLL_SECONDS = 0.5
    _AGENT_COMPLETION_PUSH_LOCK_TTL_SECONDS = 60.0
    _BACKGROUND_REFRESH_RUNNER = background_tasks.runner(
        "push-context-refresh",
        max_concurrency=2,
        max_pending=16,
    )

    def __init__(self) -> None:
        self.device_dao = UserPushDeviceDao()
        self.calendar_context_dao = AppleCalendarContextDao()
        self.calendar_event_dao = CalendarEventDao()
        self.notification_dao = NotificationDao()
        self.badge_service = BadgeService(notification_dao=self.notification_dao)
        self.apns = ApnsClient()
        self.harmony_push = HarmonyPushClient()
        self.auth_state_store = RedisAuthStateStore()

    async def register_device(
        self,
        *,
        user_id: str,
        device_id: str,
        platform: str,
        transport: str,
        push_token: str,
        app_bundle_id: str | None = None,
        apns_environment: str | None = None,
        locale: str | None = None,
        timezone: str | None = None,
        device_model: str | None = None,
        formatted_address: str | None = None,
        name: str | None = None,
        thoroughfare: str | None = None,
        sub_thoroughfare: str | None = None,
        sub_locality: str | None = None,
        locality: str | None = None,
        sub_administrative_area: str | None = None,
        city: str | None = None,
        administrative_area: str | None = None,
        postal_code: str | None = None,
        country: str | None = None,
        iso_country_code: str | None = None,
        areas_of_interest: list[str] | None = None,
        latitude: float | None = None,
        longitude: float | None = None,
        accuracy_meters: float | None = None,
        captured_at: str | None = None,
        notifications_enabled: bool = True,
    ) -> dict[str, Any]:
        normalized_device_id = device_id.strip()
        normalized_platform = platform.strip().lower()
        normalized_transport = transport.strip().lower()
        normalized_push_token = push_token.strip()
        normalized_bundle_id = (app_bundle_id or "").strip() or None
        normalized_apns_environment = self._normalize_apns_environment(
            apns_environment
        )
        normalized_locale = (locale or "").strip() or None
        timezone_provided = timezone is not None
        normalized_timezone = self._normalize_device_timezone(timezone)
        device_model_provided = device_model is not None
        normalized_device_model = self._normalize_optional_string(device_model)
        normalized_formatted_address = self._normalize_optional_string(formatted_address)
        normalized_name = self._normalize_optional_string(name)
        normalized_thoroughfare = self._normalize_optional_string(thoroughfare)
        normalized_sub_thoroughfare = self._normalize_optional_string(sub_thoroughfare)
        normalized_sub_locality = self._normalize_optional_string(sub_locality)
        normalized_locality = self._normalize_optional_string(locality)
        normalized_sub_administrative_area = self._normalize_optional_string(
            sub_administrative_area
        )
        normalized_city = (city or "").strip() or None
        normalized_administrative_area = (administrative_area or "").strip() or None
        normalized_postal_code = self._normalize_optional_string(postal_code)
        normalized_country = (country or "").strip() or None
        normalized_iso_country_code = self._normalize_optional_string(iso_country_code)
        normalized_areas_of_interest = self._normalize_string_list(areas_of_interest)
        normalized_captured_at = self._normalize_optional_string(captured_at)
        location_provided = any(
            value is not None
            for value in (
                formatted_address,
                name,
                thoroughfare,
                sub_thoroughfare,
                sub_locality,
                locality,
                sub_administrative_area,
                city,
                administrative_area,
                postal_code,
                country,
                iso_country_code,
                areas_of_interest,
                latitude,
                longitude,
                accuracy_meters,
                captured_at,
            )
        )

        if not normalized_device_id or not normalized_push_token:
            raise AppHTTPException(
                status_code=422,
                detail="device_id and push_token are required",
            )
        if not self._is_supported_platform_transport(
            normalized_platform,
            normalized_transport,
        ):
            raise AppHTTPException(
                status_code=422,
                detail="Unsupported push device platform or transport",
            )
        normalized_latitude = self._normalize_latitude(latitude)
        normalized_longitude = self._normalize_longitude(longitude)
        normalized_accuracy = self._normalize_accuracy_meters(accuracy_meters)
        if (normalized_latitude is None) != (normalized_longitude is None):
            raise AppHTTPException(
                status_code=422,
                detail="latitude and longitude must be provided together",
            )
        normalized_location_data = self._build_location_data(
            formatted_address=normalized_formatted_address,
            name=normalized_name,
            thoroughfare=normalized_thoroughfare,
            sub_thoroughfare=normalized_sub_thoroughfare,
            sub_locality=normalized_sub_locality,
            locality=normalized_locality,
            sub_administrative_area=normalized_sub_administrative_area,
            city=normalized_city,
            administrative_area=normalized_administrative_area,
            postal_code=normalized_postal_code,
            country=normalized_country,
            iso_country_code=normalized_iso_country_code,
            areas_of_interest=normalized_areas_of_interest,
            latitude=normalized_latitude,
            longitude=normalized_longitude,
            accuracy_meters=normalized_accuracy,
            captured_at=normalized_captured_at,
        )

        affected_user_ids = {user_id}
        device = await self.device_dao.get_user_device(user_id, normalized_device_id)
        if device is None:
            existing_device = await self.device_dao.get_device_by_id(normalized_device_id)
            if existing_device is not None:
                affected_user_ids.add(existing_device.user_id)
                if existing_device.user_id != user_id:
                    await self._clear_device_scoped_calendar_data(
                        user_id=existing_device.user_id,
                        device_id=normalized_device_id,
                    )
                device = existing_device
        if device is None:
            existing_token_device = await self.device_dao.get_device_by_push_token(
                push_token=normalized_push_token,
                platform=normalized_platform,
                transport=normalized_transport,
            )
            if existing_token_device is not None:
                affected_user_ids.add(existing_token_device.user_id)
                await self._clear_device_scoped_calendar_data(
                    user_id=existing_token_device.user_id,
                    device_id=existing_token_device.device_id,
                )
                await self.device_dao.delete_device_by_id(existing_token_device.device_id)
                logger.info(
                    "[PushNotificationService] 正在替换推送设备注册 "
                    f"user={user_id} previous_user={existing_token_device.user_id} "
                    f"previous_device={existing_token_device.device_id} "
                    f"next_device={normalized_device_id}"
                )
        if device is None:
            device = UserPushDevice(
                device_id=normalized_device_id,
                user_id=user_id,
                platform=normalized_platform,
                transport=normalized_transport,
                push_token=normalized_push_token,
                app_bundle_id=normalized_bundle_id,
                apns_environment=normalized_apns_environment,
                locale=normalized_locale,
                timezone=normalized_timezone,
                device_model=normalized_device_model,
                location_data=normalized_location_data,
                notifications_enabled=notifications_enabled,
            )
        else:
            now = get_local_now()
            device.user_id = user_id
            device.platform = normalized_platform
            device.transport = normalized_transport
            device.push_token = normalized_push_token
            device.app_bundle_id = normalized_bundle_id
            device.apns_environment = normalized_apns_environment
            device.locale = normalized_locale
            if device_model_provided:
                device.device_model = normalized_device_model
            if timezone_provided and normalized_timezone != device.timezone:
                device.timezone = normalized_timezone
                device.timezone_updated_at = now if normalized_timezone else None
            if location_provided:
                device.location_data = normalized_location_data
                device.location_updated_at = now
            device.notifications_enabled = notifications_enabled
            device.last_registered_at = now
            device.last_seen_at = now

        await self.device_dao.save(device)
        await self._prune_other_user_push_devices(
            user_id=user_id,
            keep_device_id=normalized_device_id,
            platform=normalized_platform,
            transport=normalized_transport,
            reason="register_device",
        )
        for affected_user_id in affected_user_ids:
            if affected_user_id == user_id:
                await self._delete_access_sessions_except_device(
                    user_id=affected_user_id,
                    keep_device_id=normalized_device_id,
                )
            else:
                await self._delete_access_sessions_for_user(affected_user_id)
        return self.serialize_device(device)

    async def update_device_context_by_credentials(
        self,
        *,
        device_id: str,
        push_token: str,
        timezone: str | None = None,
        device_model: str | None = None,
        formatted_address: str | None = None,
        name: str | None = None,
        thoroughfare: str | None = None,
        sub_thoroughfare: str | None = None,
        sub_locality: str | None = None,
        locality: str | None = None,
        sub_administrative_area: str | None = None,
        city: str | None = None,
        administrative_area: str | None = None,
        postal_code: str | None = None,
        country: str | None = None,
        iso_country_code: str | None = None,
        areas_of_interest: list[str] | None = None,
        latitude: float | None = None,
        longitude: float | None = None,
        accuracy_meters: float | None = None,
        captured_at: str | None = None,
    ) -> dict[str, Any]:
        normalized_device_id = device_id.strip()
        normalized_push_token = push_token.strip()
        timezone_provided = timezone is not None
        normalized_timezone = self._normalize_device_timezone(timezone)
        device_model_provided = device_model is not None
        normalized_device_model = self._normalize_optional_string(device_model)
        normalized_formatted_address = self._normalize_optional_string(formatted_address)
        normalized_name = self._normalize_optional_string(name)
        normalized_thoroughfare = self._normalize_optional_string(thoroughfare)
        normalized_sub_thoroughfare = self._normalize_optional_string(sub_thoroughfare)
        normalized_sub_locality = self._normalize_optional_string(sub_locality)
        normalized_locality = self._normalize_optional_string(locality)
        normalized_sub_administrative_area = self._normalize_optional_string(
            sub_administrative_area
        )
        normalized_city = (city or "").strip() or None
        normalized_administrative_area = (administrative_area or "").strip() or None
        normalized_postal_code = self._normalize_optional_string(postal_code)
        normalized_country = (country or "").strip() or None
        normalized_iso_country_code = self._normalize_optional_string(iso_country_code)
        normalized_areas_of_interest = self._normalize_string_list(areas_of_interest)
        normalized_captured_at = self._normalize_optional_string(captured_at)
        location_provided = any(
            value is not None
            for value in (
                formatted_address,
                name,
                thoroughfare,
                sub_thoroughfare,
                sub_locality,
                locality,
                sub_administrative_area,
                city,
                administrative_area,
                postal_code,
                country,
                iso_country_code,
                areas_of_interest,
                latitude,
                longitude,
                accuracy_meters,
                captured_at,
            )
        )

        if not normalized_device_id or not normalized_push_token:
            raise AppHTTPException(
                status_code=422,
                detail="device_id and push_token are required",
            )
        device = await self.device_dao.get_device_by_id(normalized_device_id)
        if device is None or device.push_token != normalized_push_token:
            raise AppHTTPException(status_code=404, detail="Push device not found")

        normalized_latitude = self._normalize_latitude(latitude)
        normalized_longitude = self._normalize_longitude(longitude)
        normalized_accuracy = self._normalize_accuracy_meters(accuracy_meters)
        if (normalized_latitude is None) != (normalized_longitude is None):
            raise AppHTTPException(
                status_code=422,
                detail="latitude and longitude must be provided together",
            )

        now = get_local_now()
        if timezone_provided and normalized_timezone != device.timezone:
            device.timezone = normalized_timezone
            device.timezone_updated_at = now if normalized_timezone else None
        if device_model_provided:
            device.device_model = normalized_device_model
        if location_provided:
            device.location_data = self._build_location_data(
                formatted_address=normalized_formatted_address,
                name=normalized_name,
                thoroughfare=normalized_thoroughfare,
                sub_thoroughfare=normalized_sub_thoroughfare,
                sub_locality=normalized_sub_locality,
                locality=normalized_locality,
                sub_administrative_area=normalized_sub_administrative_area,
                city=normalized_city,
                administrative_area=normalized_administrative_area,
                postal_code=normalized_postal_code,
                country=normalized_country,
                iso_country_code=normalized_iso_country_code,
                areas_of_interest=normalized_areas_of_interest,
                latitude=normalized_latitude,
                longitude=normalized_longitude,
                accuracy_meters=normalized_accuracy,
                captured_at=normalized_captured_at,
            )
            device.location_updated_at = now
        device.last_seen_at = now
        await self.device_dao.save(device)
        return self.serialize_device(device)

    async def delete_device(self, *, user_id: str, device_id: str) -> dict[str, Any]:
        normalized_device_id = device_id.strip()
        await self.device_dao.delete_user_device(user_id, normalized_device_id)
        await self._delete_access_sessions_for_device(
            user_id=user_id,
            device_id=normalized_device_id,
        )
        await self._clear_device_scoped_calendar_data(
            user_id=user_id,
            device_id=normalized_device_id,
        )
        return {"device_id": normalized_device_id, "removed": True}

    async def _clear_device_scoped_calendar_data(
        self,
        *,
        user_id: str,
        device_id: str,
    ) -> None:
        await self.calendar_context_dao.delete_where(
            AppleCalendarContext,
            [
                AppleCalendarContext.user_id == user_id,
                AppleCalendarContext.device_id == device_id,
            ],
        )
        await self.calendar_event_dao.delete_where(
            CalendarEvent,
            [
                CalendarEvent.user_id == user_id,
                CalendarEvent.source == constants.CALENDAR_SOURCE_APPLE,
                CalendarEvent.source_device_id == device_id,
            ],
        )

    async def _prune_other_user_push_devices(
        self,
        *,
        user_id: str,
        keep_device_id: str,
        platform: str,
        transport: str,
        reason: str,
    ) -> None:
        logger.info(
            "[PushNotificationService] 清理同账号其它推送设备 "
            f"user={user_id} keep_device={keep_device_id} reason={reason}"
        )
        await self.device_dao.delete_user_devices_except(
            user_id,
            keep_device_id=keep_device_id,
            platform=platform,
            transport=transport,
        )

    async def _prune_other_user_apns_devices(
        self,
        *,
        user_id: str,
        keep_device_id: str,
        reason: str,
    ) -> None:
        await self._prune_other_user_push_devices(
            user_id=user_id,
            keep_device_id=keep_device_id,
            platform=constants.PLATFORM_IOS,
            transport=constants.PUSH_TRANSPORT_APNS,
            reason=reason,
        )

    async def _delete_device_for_invalid_token(self, device: UserPushDevice) -> None:
        await self.device_dao.delete_user_device(device.user_id, device.device_id)
        await self._delete_access_sessions_for_device(
            user_id=device.user_id,
            device_id=device.device_id,
        )

    async def _delete_access_sessions_for_user(self, user_id: str) -> None:
        try:
            await self.auth_state_store.delete_access_tokens_by_user(user_id)
        except Exception as exc:
            logger.warning(
                "[PushNotificationService] 清理用户 access token 失败 "
                f"user={user_id}: {exc}"
            )

    async def _delete_access_sessions_for_device(
        self,
        *,
        user_id: str,
        device_id: str,
    ) -> None:
        try:
            await self.auth_state_store.delete_access_tokens_by_device(
                user_id,
                device_id,
            )
        except Exception as exc:
            logger.warning(
                "[PushNotificationService] 清理设备 access token 失败 "
                f"user={user_id} device={device_id}: {exc}"
            )

    async def _delete_access_sessions_except_device(
        self,
        *,
        user_id: str,
        keep_device_id: str,
    ) -> None:
        try:
            await self.auth_state_store.delete_access_tokens_by_user_except_device(
                user_id,
                keep_device_id,
            )
        except Exception as exc:
            logger.warning(
                "[PushNotificationService] 清理旧设备 access token 失败 "
                f"user={user_id} keep_device={keep_device_id}: {exc}"
            )

    def _normalize_device_timezone(self, timezone: str | None) -> str | None:
        try:
            return normalize_persisted_timezone(timezone, allow_empty=True)
        except ValueError as exc:
            raise AppHTTPException(
                status_code=422,
                detail="Invalid timezone",
            ) from exc

    async def send_agent_completion_notification(
        self,
        *,
        user_id: str,
        session_id: str,
        content_dedupe_basis: str = "",
        assistant_preview_text: str = "",
    ) -> None:
        logger.info(
            "[PushNotificationService] 正在准备 Agent 完成推送 "
            f"user={user_id} session={session_id}"
        )
        if not self._has_any_push_client_configured():
            logger.info("[PushNotificationService] 推送客户端未配置，跳过推送发送。")
            return
        dedupe_key = self._agent_completion_dedupe_key(
            content_dedupe_basis=content_dedupe_basis,
            assistant_preview_text=assistant_preview_text,
        )
        lock_name = f"push:{dedupe_key}"
        async with redis.lock(
            lock_name,
            ttl_seconds=self._AGENT_COMPLETION_PUSH_LOCK_TTL_SECONDS,
            wait_timeout_seconds=0,
        ) as acquired:
            if not acquired:
                logger.info(
                    "[PushNotificationService] 跳过重复的 Agent 完成推送 "
                    f"user={user_id} session={session_id} reason=lock_busy"
                )
                return
            await self._send_agent_completion_notification_once(
                user_id=user_id,
                session_id=session_id,
                dedupe_key=dedupe_key,
                assistant_preview_text=assistant_preview_text,
            )

    async def _send_agent_completion_notification_once(
        self,
        *,
        user_id: str,
        session_id: str,
        dedupe_key: str,
        assistant_preview_text: str,
    ) -> None:
        existing = await self.notification_dao.get_latest_by_dedupe_key(
            user_id,
            dedupe_key,
        )
        if existing is not None:
            logger.info(
                "[PushNotificationService] 跳过已记录的 Agent 完成推送 "
                f"user={user_id} session={session_id} "
                f"notification={existing.notification_id} status={existing.status}"
            )
            return

        devices = await self._prepare_devices_for_notification(
            user_id,
            trigger="agent_completion",
            refresh_device_context=True,
        )
        if not devices:
            logger.info(
                "[PushNotificationService] 跳过 Agent 完成推送 "
                f"user={user_id} session={session_id} reason=no_active_devices"
            )
            return
        logger.info(
            "[PushNotificationService] 正在发送 Agent 完成推送 "
            f"user={user_id} session={session_id} device_count={len(devices)}"
        )
        notification = await self._create_agent_completion_notification(
            user_id=user_id,
            dedupe_key=dedupe_key,
            assistant_preview_text=assistant_preview_text,
        )
        badge = (
            await self.badge_service.get_user_badge_count(
                user_id,
                extra_unread_notification_count=1,
            )
        ).total
        results = await run_with_concurrency_limit_ordered(
            len(devices),
            [
                lambda device=device: self._send_agent_completion_to_device(
                    device,
                    session_id=session_id,
                    notification_id=notification.notification_id,
                    badge=badge,
                    assistant_preview_text=assistant_preview_text,
                )
                for device in devices
            ],
            return_exceptions=True,
        )
        success = 0
        failed = 0
        errored = 0
        for device, result in zip(devices, results, strict=False):
            if result is True:
                success += 1
                continue
            if result is False:
                failed += 1
                continue
            errored += 1
            logger.opt(exception=result).error(
                "[PushNotificationService] 发送 Agent 完成推送时发生异常 "
                f"user={device.user_id} device={device.device_id} session={session_id}"
            )
        now = get_local_now()
        if success > 0:
            notification.status = constants.NOTIFICATION_STATUS_SENT
            notification.status_detail = (
                f"Accepted by push service for {success} device(s)"
                + (f"; {failed} failed" if failed > 0 else "")
            )
            notification.delivered_at = now
            notification.dispatch_claimed_at = None
            notification.failed_at = None
        else:
            notification.status = constants.NOTIFICATION_STATUS_FAILED
            notification.status_detail = (
                "Push delivery failed"
                + (f"; {failed} failed" if failed > 0 else "")
                + (f"; {errored} errored" if errored > 0 else "")
            )
            notification.dispatch_claimed_at = None
            notification.failed_at = now
        await self.notification_dao.save(notification)
        logger.info(
            "[PushNotificationService] Agent 完成推送结果 "
            f"user={user_id} session={session_id} "
            f"success={success} failed={failed} errored={errored}"
        )

    async def _create_agent_completion_notification(
        self,
        *,
        user_id: str,
        dedupe_key: str,
        assistant_preview_text: str = "",
    ) -> Notification:
        notification = Notification(
            notification_id=f"ntf_{uuid.uuid4().hex}",
            user_id=user_id,
            title="Ling",
            body=agent_completion_body(
                assistant_preview_text=assistant_preview_text,
            ),
            category=constants.NOTIFICATION_CATEGORY_AGENT_COMPLETION,
            priority="normal",
            silent=False,
            dedupe_key=dedupe_key,
            status=constants.NOTIFICATION_STATUS_DISPATCHING,
            status_detail="Direct push delivery in progress",
        )
        notification.dispatch_claimed_at = get_local_now()
        await self.notification_dao.insert(notification)
        return notification

    def _agent_completion_dedupe_key(
        self,
        *,
        content_dedupe_basis: str,
        assistant_preview_text: str = "",
    ) -> str:
        normalized_content = " ".join(content_dedupe_basis.split())
        payload = {
            "body": agent_completion_body(
                assistant_preview_text=assistant_preview_text,
            ),
            "content": normalized_content,
            "title": "Ling",
        }
        digest = hashlib.sha256(
            json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
        ).hexdigest()[:32]
        return f"agent_completion:content:{digest}"

    async def _send_agent_completion_to_device(
        self,
        device: UserPushDevice,
        *,
        session_id: str,
        notification_id: str,
        badge: int,
        assistant_preview_text: str,
    ) -> bool:
        locale = (device.locale or "").lower()
        title = "Ling"
        body = agent_completion_body(
            locale=locale,
            assistant_preview_text=assistant_preview_text,
        )
        result = await self._send_alert_to_device(
            device,
            title=title,
            body=body,
            payload={
                "session_id": session_id,
                "kind": "agent_completion",
                "notification_id": notification_id,
            },
            badge=badge,
        )
        if result.success:
            return True

        logger.warning(
            "[PushNotificationService] 发送推送失败 "
            f"user={device.user_id} device={device.device_id} "
            f"transport={device.transport} topic={device.app_bundle_id or 'default'} "
            f"apns_environment={device.apns_environment}: "
            f"status={result.status_code} reason={result.reason}"
        )
        if (result.reason or "") in self._INVALID_TOKEN_REASONS:
            await self._delete_device_for_invalid_token(device)
        return False


    async def send_app_notification(
        self,
        *,
        notification: Notification,
    ) -> dict[str, int]:
        if not self._has_any_push_client_configured():
            logger.info("[PushNotificationService] 推送客户端未配置，跳过应用通知推送发送。")
            return {
                constants.PUSH_RESULT_KEY_SUCCESS: 0,
                constants.PUSH_RESULT_KEY_FAILED: 0,
                constants.PUSH_RESULT_KEY_SKIPPED: 1,
            }
        devices = await self._prepare_devices_for_notification(
            notification.user_id,
            trigger=f"notification:{notification.notification_id}",
            refresh_device_context=False,
        )
        if not devices:
            return {
                constants.PUSH_RESULT_KEY_SUCCESS: 0,
                constants.PUSH_RESULT_KEY_FAILED: 0,
                constants.PUSH_RESULT_KEY_SKIPPED: 0,
            }
        badge = (
            await self.badge_service.get_user_badge_count(
                notification.user_id,
                extra_unread_notification_count=1,
            )
        ).total

        results = await run_with_concurrency_limit_ordered(
            len(devices),
            [
                lambda device=device: self._send_app_notification_to_device(
                    device,
                    notification=notification,
                    badge=badge,
                )
                for device in devices
            ],
            return_exceptions=True,
        )
        success = 0
        failed = 0
        skipped = 0
        for item in results:
            if item is True:
                success += 1
            elif item is False:
                failed += 1
            else:
                skipped += 1
        return {
            constants.PUSH_RESULT_KEY_SUCCESS: success,
            constants.PUSH_RESULT_KEY_FAILED: failed,
            constants.PUSH_RESULT_KEY_SKIPPED: skipped,
        }

    async def _send_app_notification_to_device(
        self,
        device: UserPushDevice,
        *,
        notification: Notification,
        badge: int,
    ) -> bool:
        mode = "silent" if notification.silent else "banner_sound"
        payload = {
            "kind": "app_notification",
            "notification_id": notification.notification_id,
            "category": notification.category,
            "mode": mode,
        }
        if notification.target_type and notification.target_id:
            payload["target"] = {
                "type": notification.target_type,
                "id": notification.target_id,
                "action": notification.target_action or "open",
            }
        result = await self._send_alert_to_device(
            device,
            title=notification.title,
            body=apns_preview_body_from_markdown(notification.body)
            or notification.title,
            payload=payload,
            sound_enabled=not notification.silent,
            badge=badge,
        )
        if result.success:
            return True

        logger.warning(
            "[PushNotificationService] 发送通知推送失败 "
            f"user={device.user_id} device={device.device_id} "
            f"notification={notification.notification_id}: "
            f"transport={device.transport} topic={device.app_bundle_id or 'default'} "
            f"apns_environment={device.apns_environment} "
            f"status={result.status_code} reason={result.reason}"
        )
        if (result.reason or "") in self._INVALID_TOKEN_REASONS:
            await self._delete_device_for_invalid_token(device)
        return False

    def _has_any_push_client_configured(self) -> bool:
        return self.apns.is_configured or self.harmony_push.is_configured

    async def _send_alert_to_device(
        self,
        device: UserPushDevice,
        *,
        title: str,
        body: str,
        payload: dict[str, Any] | None = None,
        sound_enabled: bool = True,
        badge: int | None = None,
    ) -> ApnsSendResult:
        if device.transport == constants.PUSH_TRANSPORT_APNS:
            return await self.apns.send_alert(
                device_token=device.push_token,
                title=title,
                body=body,
                topic=device.app_bundle_id,
                apns_environment=device.apns_environment,
                payload=payload,
                sound_enabled=sound_enabled,
                badge=badge,
            )
        if device.transport == constants.PUSH_TRANSPORT_HARMONY:
            return await self.harmony_push.send_alert(
                device_token=device.push_token,
                title=title,
                body=body,
                payload=payload,
                sound_enabled=sound_enabled,
                badge=badge,
            )
        return ApnsSendResult(
            success=False,
            status_code=0,
            reason="unsupported_push_transport",
        )


    async def _prepare_devices_for_notification(
        self,
        user_id: str,
        *,
        trigger: str,
        refresh_device_context: bool,
    ) -> list[UserPushDevice]:
        devices = await self.device_dao.list_active_devices(user_id)
        devices = [
            device
            for device in devices
            if self._is_supported_platform_transport(
                device.platform,
                device.transport,
            )
        ]
        if not devices:
            logger.info(
                "[PushNotificationService] 没有活跃推送设备 "
                f"user={user_id} trigger={trigger}"
            )
            return []
        devices = await self._collapse_active_push_devices(
            user_id=user_id,
            devices=devices,
            trigger=trigger,
        )
        logger.info(
            "[PushNotificationService] 已加载活跃推送设备 "
            f"user={user_id} trigger={trigger} count={len(devices)}"
        )
        if not refresh_device_context:
            return devices
        await self._refresh_device_context_before_notification(
            devices,
            trigger=trigger,
        )
        refreshed_devices = await self.device_dao.list_active_devices(user_id)
        refreshed_devices = [
            device
            for device in refreshed_devices
            if self._is_supported_platform_transport(
                device.platform,
                device.transport,
            )
        ]
        if not refreshed_devices:
            return devices
        return await self._collapse_active_push_devices(
            user_id=user_id,
            devices=refreshed_devices,
            trigger=trigger,
        )

    async def _collapse_active_push_devices(
        self,
        *,
        user_id: str,
        devices: list[UserPushDevice],
        trigger: str,
    ) -> list[UserPushDevice]:
        if len(devices) <= 1:
            return devices
        grouped: dict[tuple[str, str], list[UserPushDevice]] = {}
        for device in devices:
            grouped.setdefault((device.platform, device.transport), []).append(device)

        collapsed: list[UserPushDevice] = []
        for (platform, transport), group in grouped.items():
            latest_device = group[0]
            collapsed.append(latest_device)
            if len(group) <= 1:
                continue
            await self._prune_other_user_push_devices(
                user_id=user_id,
                keep_device_id=latest_device.device_id,
                platform=platform,
                transport=transport,
                reason=f"collapse_active_push_devices:{trigger}",
            )
            logger.warning(
                "[PushNotificationService] 已合并重复的活跃推送设备 "
                f"user={user_id} trigger={trigger} platform={platform} "
                f"transport={transport} kept={latest_device.device_id} "
                f"removed={len(group) - 1}"
            )
        return collapsed

    async def _collapse_active_apns_devices(
        self,
        *,
        user_id: str,
        devices: list[UserPushDevice],
        trigger: str,
    ) -> list[UserPushDevice]:
        return await self._collapse_active_push_devices(
            user_id=user_id,
            devices=devices,
            trigger=trigger,
        )

    def _schedule_device_context_refresh(
        self,
        devices: list[UserPushDevice],
        *,
        trigger: str,
    ) -> None:
        if not devices:
            return
        user_id = str(devices[0].user_id or "").strip()
        if not user_id:
            return

        async def _run() -> None:
            await self._refresh_device_context_before_notification(
                devices,
                trigger=trigger,
            )

        self._BACKGROUND_REFRESH_RUNNER.submit(
            task_name="refresh-device-context",
            coro_factory=_run,
            dedupe_key=f"{user_id}:{trigger}",
        )

    async def _refresh_device_context_before_notification(
        self,
        devices: list[UserPushDevice],
        *,
        trigger: str,
    ) -> None:
        started_at = get_local_now()
        refresh_context_id = uuid.uuid4().hex
        results = await run_with_concurrency_limit_ordered(
            len(devices),
            [
                lambda device=device: self._send_device_context_refresh_to_device(
                    device,
                    refresh_context_id=refresh_context_id,
                    trigger=trigger,
                )
                for device in devices
            ],
            return_exceptions=True,
        )
        pending_device_ids = {
            device.device_id
            for device, result in zip(devices, results, strict=False)
            if result is True
        }
        if not pending_device_ids:
            return
        await self._wait_for_device_context_update(
            user_id=devices[0].user_id,
            device_ids=pending_device_ids,
            updated_after=started_at,
        )

    async def _send_device_context_refresh_to_device(
        self,
        device: UserPushDevice,
        *,
        refresh_context_id: str,
        trigger: str,
    ) -> bool:
        result = await self._send_background_update_to_device(
            device,
            payload={
                "kind": "refresh_device_context",
                "refresh_context_id": refresh_context_id,
                "trigger": trigger,
            },
        )
        if result.success:
            return True

        logger.warning(
            "[PushNotificationService] 发送设备上下文刷新失败 "
            f"user={device.user_id} device={device.device_id}: "
            f"status={result.status_code} reason={result.reason}"
        )
        if (result.reason or "") in self._INVALID_TOKEN_REASONS:
            await self._delete_device_for_invalid_token(device)
        return False

    async def _send_background_update_to_device(
        self,
        device: UserPushDevice,
        *,
        payload: dict[str, Any] | None = None,
    ) -> ApnsSendResult:
        if device.transport == constants.PUSH_TRANSPORT_APNS:
            return await self.apns.send_background_update(
                device_token=device.push_token,
                topic=device.app_bundle_id,
                apns_environment=device.apns_environment,
                payload=payload,
            )
        if device.transport == constants.PUSH_TRANSPORT_HARMONY:
            return await self.harmony_push.send_background_update(
                device_token=device.push_token,
                payload=payload,
            )
        return ApnsSendResult(
            success=False,
            status_code=0,
            reason="unsupported_push_transport",
        )

    async def _wait_for_device_context_update(
        self,
        *,
        user_id: str,
        device_ids: set[str],
        updated_after,
    ) -> None:
        if not device_ids:
            return

        loop = asyncio.get_running_loop()
        deadline = loop.time() + self._DEVICE_CONTEXT_REFRESH_TIMEOUT_SECONDS
        pending_device_ids = set(device_ids)
        while pending_device_ids and loop.time() < deadline:
            devices = await self.device_dao.list_active_devices(user_id)
            devices_by_id = {device.device_id: device for device in devices}
            for device_id in tuple(pending_device_ids):
                device = devices_by_id.get(device_id)
                if device is None:
                    pending_device_ids.discard(device_id)
                    continue
                if self._has_fresh_device_context(device, updated_after=updated_after):
                    pending_device_ids.discard(device_id)
            if pending_device_ids:
                await asyncio.sleep(self._DEVICE_CONTEXT_REFRESH_POLL_SECONDS)

    def _has_fresh_device_context(
        self,
        device: UserPushDevice,
        *,
        updated_after,
    ) -> bool:
        return any(
            value is not None and value >= updated_after
            for value in (device.location_updated_at, device.timezone_updated_at)
        )

    def _is_supported_platform_transport(self, platform: str, transport: str) -> bool:
        return (platform, transport) in {
            (constants.PLATFORM_IOS, constants.PUSH_TRANSPORT_APNS),
            (constants.PLATFORM_OHOS, constants.PUSH_TRANSPORT_HARMONY),
        }

    def serialize_device(self, device: UserPushDevice) -> dict[str, Any]:
        location_data = device.location_data or {}
        return {
            "device_id": device.device_id,
            "user_id": device.user_id,
            "platform": device.platform,
            "transport": device.transport,
            "push_token": device.push_token,
            "app_bundle_id": device.app_bundle_id,
            "apns_environment": device.apns_environment,
            "locale": device.locale,
            "timezone": device.timezone,
            "device_model": device.device_model,
            "formatted_address": location_data.get("formatted_address"),
            "name": location_data.get("name"),
            "thoroughfare": location_data.get("thoroughfare"),
            "sub_thoroughfare": location_data.get("sub_thoroughfare"),
            "sub_locality": location_data.get("sub_locality"),
            "locality": location_data.get("locality"),
            "sub_administrative_area": location_data.get("sub_administrative_area"),
            "city": location_data.get("city"),
            "administrative_area": location_data.get("administrative_area"),
            "postal_code": location_data.get("postal_code"),
            "country": location_data.get("country"),
            "iso_country_code": location_data.get("iso_country_code"),
            "areas_of_interest": location_data.get("areas_of_interest"),
            "latitude": location_data.get("latitude"),
            "longitude": location_data.get("longitude"),
            "accuracy_meters": location_data.get("accuracy_meters"),
            "captured_at": location_data.get("captured_at"),
            "notifications_enabled": device.notifications_enabled,
            "timezone_updated_at": format_datetime(device.timezone_updated_at),
            "location_updated_at": format_datetime(device.location_updated_at),
            "last_registered_at": format_datetime(device.last_registered_at),
            "last_seen_at": format_datetime(device.last_seen_at),
            "created_at": format_datetime(device.created_at),
            "updated_at": format_datetime(device.updated_at),
        }

    def _build_location_data(
        self,
        *,
        formatted_address: str | None,
        name: str | None,
        thoroughfare: str | None,
        sub_thoroughfare: str | None,
        sub_locality: str | None,
        locality: str | None,
        sub_administrative_area: str | None,
        city: str | None,
        administrative_area: str | None,
        postal_code: str | None,
        country: str | None,
        iso_country_code: str | None,
        areas_of_interest: list[str] | None,
        latitude: float | None,
        longitude: float | None,
        accuracy_meters: float | None,
        captured_at: str | None,
    ) -> dict[str, Any] | None:
        payload = {
            "formatted_address": formatted_address,
            "name": name,
            "thoroughfare": thoroughfare,
            "sub_thoroughfare": sub_thoroughfare,
            "sub_locality": sub_locality,
            "locality": locality,
            "sub_administrative_area": sub_administrative_area,
            "city": city,
            "administrative_area": administrative_area,
            "postal_code": postal_code,
            "country": country,
            "iso_country_code": iso_country_code,
            "areas_of_interest": areas_of_interest,
            "latitude": latitude,
            "longitude": longitude,
            "accuracy_meters": accuracy_meters,
            "captured_at": captured_at,
        }
        normalized = {key: value for key, value in payload.items() if value is not None}
        return normalized or None

    def _normalize_optional_string(self, value: str | None) -> str | None:
        normalized = (value or "").strip()
        return normalized or None

    def _normalize_string_list(self, values: list[str] | None) -> list[str] | None:
        if not values:
            return None
        normalized: list[str] = []
        for value in values:
            text = str(value or "").strip()
            if text and text not in normalized:
                normalized.append(text)
        return normalized or None

    def _normalize_apns_environment(self, value: str | None) -> str:
        normalized = str(value or "").strip().lower()
        if normalized in {"development", "developer", "sandbox"}:
            return constants.APNS_ENVIRONMENT_DEVELOPMENT
        if normalized in {"production", "prod", "release"}:
            return constants.APNS_ENVIRONMENT_PRODUCTION
        if normalized == constants.APNS_ENVIRONMENT_UNKNOWN:
            return constants.APNS_ENVIRONMENT_UNKNOWN
        return constants.APNS_ENVIRONMENT_PRODUCTION

    def _normalize_latitude(self, value: float | None) -> float | None:
        if value is None:
            return None
        normalized = float(value)
        if not math.isfinite(normalized) or normalized < -90 or normalized > 90:
            raise AppHTTPException(status_code=422, detail="Invalid latitude")
        return normalized

    def _normalize_longitude(self, value: float | None) -> float | None:
        if value is None:
            return None
        normalized = float(value)
        if not math.isfinite(normalized) or normalized < -180 or normalized > 180:
            raise AppHTTPException(status_code=422, detail="Invalid longitude")
        return normalized

    def _normalize_accuracy_meters(self, value: float | None) -> float | None:
        if value is None:
            return None
        normalized = float(value)
        if not math.isfinite(normalized) or normalized < 0:
            raise AppHTTPException(status_code=422, detail="Invalid accuracy_meters")
        return normalized
