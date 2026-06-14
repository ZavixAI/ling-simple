"""Configurable HarmonyOS push client.

The concrete Harmony push gateway is supplied through configuration so the
backend can be wired to the production Push Kit endpoint without changing the
service dispatch code.
"""

from __future__ import annotations

from typing import Any

import httpx
from config import constants
from config.settings import get_app_config
from core.infra.apns import ApnsSendResult
from loguru import logger

HARMONY_PUSH_TIMEOUT_SECONDS = 15


class HarmonyPushClient:
    def __init__(self) -> None:
        self.cfg = get_app_config()

    @property
    def is_configured(self) -> bool:
        return bool(
            self.cfg.harmony_push_client_id
            and self.cfg.harmony_push_client_secret
            and self.cfg.harmony_push_app_id
            and self.cfg.harmony_push_endpoint
        )

    async def send_alert(
        self,
        *,
        device_token: str,
        title: str,
        body: str,
        payload: dict[str, Any] | None = None,
        sound_enabled: bool = True,
        badge: int | None = None,
    ) -> ApnsSendResult:
        return await self._send_notification(
            device_token=device_token,
            request_payload={
                "type": "alert",
                "title": title,
                "body": body,
                "sound_enabled": sound_enabled,
                **({"badge": max(0, int(badge))} if badge is not None else {}),
                "data": payload or {},
            },
        )

    async def send_background_update(
        self,
        *,
        device_token: str,
        payload: dict[str, Any] | None = None,
    ) -> ApnsSendResult:
        return await self._send_notification(
            device_token=device_token,
            request_payload={
                "type": "background",
                "data": payload or {},
            },
        )

    async def _send_notification(
        self,
        *,
        device_token: str,
        request_payload: dict[str, Any],
    ) -> ApnsSendResult:
        if not self.is_configured:
            return ApnsSendResult(
                success=False,
                status_code=0,
                reason="missing_harmony_push_credentials",
            )

        request_body = {
            "app_id": self.cfg.harmony_push_app_id,
            "client_id": self.cfg.harmony_push_client_id,
            "token": device_token,
            "provider": constants.HARMONY_PUSH_PROVIDER,
            **request_payload,
        }
        headers = {
            "accept": "application/json",
            "content-type": "application/json; charset=utf-8",
            "authorization": f"Bearer {self.cfg.harmony_push_client_secret}",
        }

        try:
            async with httpx.AsyncClient(
                timeout=HARMONY_PUSH_TIMEOUT_SECONDS,
            ) as client:
                response = await client.post(
                    self.cfg.harmony_push_endpoint or "",
                    json=request_body,
                    headers=headers,
                )
        except Exception as exc:
            logger.warning(f"[HarmonyPush] 发送通知失败：{exc}")
            return ApnsSendResult(success=False, status_code=0, reason=str(exc))

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

        reason = None
        if response_data is not None:
            reason = (
                response_data.get("reason")
                or response_data.get("error")
                or response_data.get("message")
            )
        return ApnsSendResult(
            success=False,
            status_code=response.status_code,
            reason=str(reason or response.text.strip() or ""),
            response_data=response_data,
        )
