"""Minimal APNs client using token-based authentication."""

from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass
from typing import Any

import httpx
import jwt
from config import constants
from config.settings import get_app_config
from loguru import logger

APNS_PRODUCTION_HOST = "https://api.push.apple.com"
APNS_SANDBOX_HOST = "https://api.sandbox.push.apple.com"
APNS_TIMEOUT_SECONDS = 15
APNS_TOPIC = "top.withling.ling"


@dataclass(frozen=True)
class ApnsSendResult:
    success: bool
    status_code: int
    reason: str | None = None
    response_data: dict[str, Any] | None = None


class ApnsClient:
    def __init__(self) -> None:
        self.cfg = get_app_config()
        self._token_lock = asyncio.Lock()
        self._cached_bearer_token: str | None = None
        self._cached_bearer_expires_at: float = 0

    @property
    def is_configured(self) -> bool:
        return bool(
            self.cfg.apns_team_id
            and self.cfg.apns_key_id
            and self._load_private_key()
        )

    async def send_alert(
        self,
        *,
        device_token: str,
        title: str,
        body: str,
        topic: str | None = None,
        apns_environment: str | None = None,
        payload: dict[str, Any] | None = None,
        sound_enabled: bool = True,
        badge: int | None = None,
    ) -> ApnsSendResult:
        request_payload = {
            "aps": {
                "alert": {"title": title, "body": body},
                **({"sound": "default"} if sound_enabled else {}),
                **({"badge": max(0, int(badge))} if badge is not None else {}),
            },
            **(payload or {}),
        }
        return await self._send_notification(
            device_token=device_token,
            topic=topic,
            apns_environment=apns_environment,
            request_payload=request_payload,
            push_type=constants.APNS_PUSH_TYPE_ALERT,
            priority=constants.APNS_PRIORITY_ALERT,
        )

    async def send_background_update(
        self,
        *,
        device_token: str,
        topic: str | None = None,
        apns_environment: str | None = None,
        payload: dict[str, Any] | None = None,
    ) -> ApnsSendResult:
        request_payload = {
            "aps": {"content-available": 1},
            **(payload or {}),
        }
        return await self._send_notification(
            device_token=device_token,
            topic=topic,
            apns_environment=apns_environment,
            request_payload=request_payload,
            push_type=constants.APNS_PUSH_TYPE_BACKGROUND,
            priority=constants.APNS_PRIORITY_BACKGROUND,
        )

    async def _send_notification(
        self,
        *,
        device_token: str,
        topic: str | None,
        apns_environment: str | None,
        request_payload: dict[str, Any],
        push_type: str,
        priority: str,
    ) -> ApnsSendResult:
        normalized_topic = (topic or APNS_TOPIC).strip()
        if not normalized_topic:
            return ApnsSendResult(
                success=False,
                status_code=0,
                reason="missing_apns_topic",
            )

        bearer_token = await self._get_bearer_token()
        if not bearer_token:
            return ApnsSendResult(
                success=False,
                status_code=0,
                reason="missing_apns_credentials",
            )

        url = f"{self._host_for_environment(apns_environment)}/3/device/{device_token}"
        headers = {
            "authorization": f"bearer {bearer_token}",
            "apns-topic": normalized_topic,
            "apns-push-type": push_type,
            "apns-priority": priority,
        }

        try:
            async with httpx.AsyncClient(
                http2=True,
                timeout=APNS_TIMEOUT_SECONDS,
            ) as client:
                response = await client.post(
                    url,
                    json=request_payload,
                    headers=headers,
                )
        except Exception as exc:
            logger.warning(f"[APNs] 发送通知失败：{exc}")
            return ApnsSendResult(
                success=False,
                status_code=0,
                reason=str(exc),
            )

        response_data: dict[str, Any] | None = None
        try:
            decoded = response.json()
            if isinstance(decoded, dict):
                response_data = decoded
        except Exception:
            response_data = None

        if 200 <= response.status_code < 300:
            return ApnsSendResult(
                success=True,
                status_code=response.status_code,
                response_data=response_data,
            )

        return ApnsSendResult(
            success=False,
            status_code=response.status_code,
            reason=(response_data or {}).get("reason")
            if response_data is not None
            else response.text.strip() or None,
            response_data=response_data,
        )

    def _host_for_environment(self, apns_environment: str | None) -> str:
        normalized = str(apns_environment or "").strip().lower()
        if normalized in {"development", "sandbox"}:
            return APNS_SANDBOX_HOST
        return APNS_PRODUCTION_HOST

    async def _get_bearer_token(self) -> str | None:
        now = time.time()
        if self._cached_bearer_token and now < self._cached_bearer_expires_at:
            return self._cached_bearer_token

        async with self._token_lock:
            now = time.time()
            if self._cached_bearer_token and now < self._cached_bearer_expires_at:
                return self._cached_bearer_token

            private_key = self._load_private_key()
            if not private_key:
                return None

            token = jwt.encode(
                {"iss": self.cfg.apns_team_id, "iat": int(now)},
                private_key,
                algorithm="ES256",
                headers={"kid": self.cfg.apns_key_id},
            )
            self._cached_bearer_token = token
            # APNs provider tokens are valid for up to 60 minutes.
            self._cached_bearer_expires_at = now + 50 * 60
            return token

    def _load_private_key(self) -> str | None:
        inline = (self.cfg.apns_auth_key or "").strip()
        if inline:
            return inline.replace("\\n", "\n")
        return None
