"""钉钉日历事件流：Router 解析回调事件，StreamConsumer 在进程内跑 asyncio 长任务。

由 lifecycle 启动 DingTalkCalendarStreamConsumer，与 ExternalCalendarSyncService 联动。
"""

from __future__ import annotations

import asyncio
import json
from typing import Any
from urllib.parse import quote_plus

from config.settings import AppConfig, get_app_config
from loguru import logger
from models.calendar_provider import CalendarProviderConnectionDao
from services.calendar_integrations.providers import PROVIDER_DINGTALK
from services.calendar_integrations.service import ExternalCalendarSyncService
from services.calendar_integrations.state_store import CalendarSyncTriggerStore
from utils.time import utc_now_naive


class DingTalkCalendarEventRouter:
    """将钉钉 HTTP 回调解析为「需同步的连接」，再委托 ExternalCalendarSyncService。"""

    def __init__(
        self,
        cfg: AppConfig | None = None,
        *,
        connection_dao: CalendarProviderConnectionDao | None = None,
        sync_service: ExternalCalendarSyncService | None = None,
        trigger_store: CalendarSyncTriggerStore | None = None,
    ) -> None:
        self.cfg = cfg or get_app_config()
        self.connection_dao = connection_dao or CalendarProviderConnectionDao()
        self.sync_service = sync_service or ExternalCalendarSyncService(
            self.cfg,
            connection_dao=self.connection_dao,
        )
        self.trigger_store = trigger_store or CalendarSyncTriggerStore(self.cfg)

    async def process(
        self,
        *,
        headers: Any,
        data: dict[str, Any],
    ) -> dict[str, Any]:
        event_type = str(
            getattr(headers, "event_type", None)
            or data.get("EventType")
            or data.get("eventType")
            or data.get("callBackTag")
            or ""
        ).strip()
        if event_type != "calendar_event_change":
            return {"accepted": True, "event_type": event_type or "unknown", "matched_connections": 0}

        corp_id = str(
            data.get("corpId")
            or data.get("CorpId")
            or getattr(headers, "event_corp_id", None)
            or ""
        ).strip() or None
        calendar_id = str(data.get("calendarId") or data.get("CalendarId") or "").strip()
        calendar_event_id = str(
            data.get("calendarEventId")
            or data.get("CalendarEventId")
            or data.get("eventId")
            or data.get("EventId")
            or ""
        ).strip()
        stream_event_id = str(
            getattr(headers, "event_id", None)
            or data.get("bizId")
            or data.get("BizId")
            or ""
        ).strip()
        fingerprint = ":".join(
            part
            for part in (
                corp_id or "unknown-corp",
                calendar_id or "unknown-calendar",
                calendar_event_id or "unknown-calendar-event",
                stream_event_id or "unknown-stream-event",
            )
            if part
        )
        reserved = await self.trigger_store.reserve(
            PROVIDER_DINGTALK,
            fingerprint,
            ttl_seconds=7 * 24 * 60 * 60,
        )
        if not reserved:
            return {"accepted": True, "duplicate": True, "matched_connections": 0}

        connections = await self.connection_dao.list_by_provider_tenant(
            provider_id=PROVIDER_DINGTALK,
            external_tenant_id=corp_id,
        )
        union_ids = {
            str(item).strip()
            for item in (
                data.get("unionIdList")
                or data.get("unionIds")
                or data.get("userUnionIds")
                or []
            )
            if str(item).strip()
        }
        matched = 0
        for connection in connections:
            if calendar_id and str(connection.primary_calendar_id or "").strip() not in {"", calendar_id}:
                continue
            if union_ids and str(connection.external_user_id or "").strip() not in union_ids:
                continue
            connection.last_webhook_at = utc_now_naive()
            await self.connection_dao.save(connection)
            await self.sync_service.run_delta_sync(
                connection.connection_id,
                trigger=f"dingtalk_stream:{stream_event_id or calendar_event_id or 'event'}",
            )
            matched += 1
        return {"accepted": True, "matched_connections": matched}


def _build_dingtalk_stream_handler(router: DingTalkCalendarEventRouter):
    import dingtalk_stream

    class CalendarEventHandler(dingtalk_stream.EventHandler):
        async def process(self, event):  # type: ignore[override]
            await router.process(headers=event.headers, data=event.data or {})
            return dingtalk_stream.AckMessage.STATUS_OK, "OK"

    return CalendarEventHandler()


class DingTalkCalendarStreamConsumer:
    """封装钉钉官方流式 SDK 的启动/停止，把事件交给 CalendarEventHandler → Router。"""

    def __init__(
        self,
        cfg: AppConfig | None = None,
        *,
        connection_dao: CalendarProviderConnectionDao | None = None,
        sync_service: ExternalCalendarSyncService | None = None,
        trigger_store: CalendarSyncTriggerStore | None = None,
    ) -> None:
        self.cfg = cfg or get_app_config()
        self.router = DingTalkCalendarEventRouter(
            self.cfg,
            connection_dao=connection_dao,
            sync_service=sync_service,
            trigger_store=trigger_store,
        )
        self._task: asyncio.Task[None] | None = None
        self._stopped = asyncio.Event()

    def start(self) -> None:
        if not self._is_configured():
            logger.warning("[DingTalkStream] 缺少客户端凭据，跳过启动")
            return
        if self._task is not None:
            return
        self._stopped.clear()
        self._task = asyncio.create_task(self._run(), name="dingtalk-calendar-stream")

    async def stop(self) -> None:
        self._stopped.set()
        if self._task is None:
            return
        self._task.cancel()
        try:
            await self._task
        except asyncio.CancelledError:
            pass
        self._task = None

    async def _run(self) -> None:
        try:
            import dingtalk_stream
            import websockets
        except ImportError:
            logger.exception(
                "[DingTalkStream] 缺少 dingtalk-stream 依赖；"
                "启用 consumer 前请先安装后端依赖"
            )
            await self._stopped.wait()
            return

        credential = dingtalk_stream.Credential(
            self.cfg.dingtalk_client_id,
            self.cfg.dingtalk_client_secret,
        )
        client = dingtalk_stream.DingTalkStreamClient(credential)
        client.register_all_event_handler(_build_dingtalk_stream_handler(self.router))
        client.pre_start()

        while not self._stopped.is_set():
            try:
                connection = await asyncio.to_thread(client.open_connection)
                if not connection:
                    await self._sleep_or_stop(10)
                    continue
                endpoint = str(connection.get("endpoint") or "").strip()
                ticket = str(connection.get("ticket") or "").strip()
                if not endpoint or not ticket:
                    logger.error("[DingTalkStream] open_connection 返回了无效 payload")
                    await self._sleep_or_stop(10)
                    continue
                uri = f"{endpoint}?ticket={quote_plus(ticket)}"
                logger.info("[DingTalkStream] 已连接")
                async with websockets.connect(uri) as websocket:
                    client.websocket = websocket
                    keepalive_task = asyncio.create_task(
                        client.keepalive(websocket),
                        name="dingtalk-calendar-stream-keepalive",
                    )
                    try:
                        while not self._stopped.is_set():
                            try:
                                raw_message = await asyncio.wait_for(websocket.recv(), timeout=5)
                            except asyncio.TimeoutError:
                                continue
                            json_message = json.loads(raw_message)
                            await client.background_task(json_message)
                    finally:
                        keepalive_task.cancel()
                        try:
                            await keepalive_task
                        except asyncio.CancelledError:
                            pass
            except asyncio.CancelledError:
                raise
            except Exception as exc:
                logger.exception("[DingTalkStream] 连接循环失败：{}", exc)
                await self._sleep_or_stop(10)

    def _is_configured(self) -> bool:
        return bool((self.cfg.dingtalk_client_id or "").strip()) and bool(
            (self.cfg.dingtalk_client_secret or "").strip()
        )

    async def _sleep_or_stop(self, seconds: int) -> None:
        try:
            await asyncio.wait_for(self._stopped.wait(), timeout=max(1, seconds))
        except asyncio.TimeoutError:
            return
