"""应用内通知：创建、去重、查询与投递（队列状态 + APNs）。

dedupe_key 存在时同键更新为最新标题正文并重新排队；投递侧用 Redis 锁避免重复发送。
"""

from __future__ import annotations

import time
import uuid
from datetime import datetime, timedelta
from typing import Any

from config import constants
from config.settings import AppConfig, get_app_config
from core.http.exceptions import AppHTTPException
from core.infra.background_tasks import background_tasks
from core.infra.redis import redis
from core.metrics import metrics
from loguru import logger
from models.base import get_local_now
from models.notification import Notification, NotificationDao
from services.calendar import CalendarService
from services.push.service import PushNotificationService
from utils.concurrency import run_with_concurrency_limit_ordered
from utils.time import format_datetime, to_storage_utc


class NotificationService:
    """通知领域服务：持久化 + 批量 dispatch_due_notifications 供后台调度器调用。"""

    _DEFAULT_DISPATCH_CLAIM_TIMEOUT_SECONDS = 5 * 60
    _DEFAULT_DISPATCH_MAX_CONCURRENCY = 4
    _IMMEDIATE_DISPATCH_RUNNER = background_tasks.runner(
        "notification-immediate-dispatch",
        max_concurrency=4,
        max_pending=128,
    )

    def __init__(self, config: AppConfig | None = None) -> None:
        self._config = config or get_app_config()
        self.notification_dao = NotificationDao()
        self.calendar_service = CalendarService()
        self.push_service = PushNotificationService()

    async def create_notification(
        self,
        user_id: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        target = payload.get("target") or {}
        send_time = self._parse_optional_datetime(payload.get("send_time"))
        dedupe_key = payload.get("dedupe_key")

        deduplicated = False
        notification: Notification
        if dedupe_key:
            lock_name = f"notification:dedupe:{user_id}:{dedupe_key}"
            async with redis.lock_or_raise(
                lock_name,
                error=AppHTTPException(
                    status_code=409,
                    detail="Notification dedupe is busy",
                ),
                ttl_seconds=15,
                wait_timeout_seconds=2,
            ):
                existing = await self.notification_dao.get_latest_by_dedupe_key(
                    user_id,
                    dedupe_key,
                )
                if existing is not None:
                    deduplicated = True
                    existing.title = payload["title"]
                    existing.body = payload["body"]
                    existing.category = payload.get(
                        "category", constants.DEFAULT_NOTIFICATION_CATEGORY
                    )
                    existing.priority = payload.get(
                        "priority", constants.DEFAULT_NOTIFICATION_PRIORITY
                    )
                    existing.silent = bool(payload.get("silent", False))
                    existing.send_time = send_time
                    existing.target_type = target.get("type")
                    existing.target_id = target.get("id")
                    existing.target_action = target.get("action", "open")
                    existing.status = constants.NOTIFICATION_STATUS_QUEUED
                    existing.status_detail = "Pending delivery provider integration"
                    existing.opened_at = None
                    existing.dismissed_at = None
                    existing.failed_at = None
                    await self.notification_dao.save(existing)
                    notification = existing
                else:
                    notification = self._build_notification(user_id, payload, send_time)
                    try:
                        await self.notification_dao.insert(notification)
                    except Exception:
                        existing = await self.notification_dao.get_latest_by_dedupe_key(
                            user_id,
                            dedupe_key,
                        )
                        if existing is None:
                            raise
                        deduplicated = True
                        notification = existing
        else:
            notification = self._build_notification(user_id, payload, send_time)
            await self.notification_dao.insert(notification)

        result = self.serialize_notification(notification)
        result["deduplicated"] = deduplicated
        return result

    async def dispatch_notification_by_id(
        self,
        notification_id: str,
    ) -> dict[str, Any] | None:
        notification = await self.notification_dao.get_by_id(Notification, notification_id)
        if notification is None:
            return None
        if not self._is_due(notification):
            return self.serialize_notification(notification)
        await self._dispatch_notification(notification)
        refreshed = await self.notification_dao.get_by_id(Notification, notification_id)
        return None if refreshed is None else self.serialize_notification(refreshed)

    def submit_immediate_dispatch(self, notification_id: str) -> bool:
        """Start best-effort immediate delivery without blocking the caller."""
        normalized_id = str(notification_id or "").strip()
        if not normalized_id:
            return False
        return self._IMMEDIATE_DISPATCH_RUNNER.submit_call(
            self.dispatch_notification_by_id,
            normalized_id,
            task_name="dispatch_notification_by_id",
            dedupe_key=normalized_id,
        )

    async def dispatch_due_notifications(
        self,
        *,
        limit: int = 20,
    ) -> int:
        started_at = time.perf_counter()
        now = get_local_now()
        dispatch_claim_timeout_seconds = self._resolved_dispatch_claim_timeout_seconds()
        due = await self.notification_dao.list_due_notifications(
            now=now,
            stale_dispatching_before=now - timedelta(seconds=dispatch_claim_timeout_seconds),
            limit=limit,
        )
        metrics.set_gauge("ling_notification_due_batch_size", len(due))
        if not due:
            return 0

        dispatch_max_concurrency = min(
            self._resolved_dispatch_max_concurrency(),
            len(due),
        )
        logger.info(
            "[NotificationService] 正在投递到期通知 "
            f"count={len(due)} concurrency={dispatch_max_concurrency} limit={limit}"
        )
        async def _dispatch_one(notification: Notification) -> int:
            return 1 if await self._dispatch_notification(notification) else 0

        results = await run_with_concurrency_limit_ordered(
            dispatch_max_concurrency,
            [lambda item=item: _dispatch_one(item) for item in due],
        )
        dispatched = sum(results)
        metrics.inc_counter("ling_notification_dispatch_total", dispatched)
        metrics.observe(
            "ling_notification_dispatch_duration_ms",
            round((time.perf_counter() - started_at) * 1000, 2),
        )
        return dispatched

    async def list_notifications(
        self,
        user_id: str,
        *,
        start_time: datetime | None = None,
        end_time: datetime | None = None,
        statuses: list[str] | None = None,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        notifications = await self.notification_dao.list_user_notifications(
            user_id,
            start_time=to_storage_utc(start_time),
            end_time=to_storage_utc(end_time),
            statuses=statuses,
            limit=limit,
        )
        return [self.serialize_notification(item) for item in notifications]

    def serialize_notification(self, notification: Notification) -> dict[str, Any]:
        return {
            "notification_id": notification.notification_id,
            "user_id": notification.user_id,
            "title": notification.title,
            "body": notification.body,
            "category": notification.category,
            "priority": notification.priority,
            "silent": notification.silent,
            "dedupe_key": notification.dedupe_key,
            "target": None
            if not notification.target_type or not notification.target_id
            else {
                "type": notification.target_type,
                "id": notification.target_id,
                "action": notification.target_action or "open",
            },
            "send_time": format_datetime(notification.send_time),
            "status": notification.status,
            "status_detail": notification.status_detail,
            "delivered_at": format_datetime(notification.delivered_at),
            "opened_at": format_datetime(notification.opened_at),
            "dismissed_at": format_datetime(notification.dismissed_at),
            "failed_at": format_datetime(notification.failed_at),
            "created_at": format_datetime(notification.created_at),
            "updated_at": format_datetime(notification.updated_at),
        }

    def _build_notification(
        self,
        user_id: str,
        payload: dict[str, Any],
        send_time: datetime | None,
    ) -> Notification:
        target = payload.get("target") or {}
        return Notification(
            notification_id=f"ntf_{uuid.uuid4().hex}",
            user_id=user_id,
            title=payload["title"],
            body=payload["body"],
            category=payload.get("category", constants.DEFAULT_NOTIFICATION_CATEGORY),
            priority=payload.get("priority", constants.DEFAULT_NOTIFICATION_PRIORITY),
            silent=bool(payload.get("silent", False)),
            dedupe_key=payload.get("dedupe_key"),
            target_type=target.get("type"),
            target_id=target.get("id"),
            target_action=target.get("action", "open"),
            send_time=send_time,
            status=constants.NOTIFICATION_STATUS_QUEUED,
            status_detail="Pending delivery provider integration",
        )

    async def _dispatch_notification(self, notification: Notification) -> bool:
        async with redis.lock(
            f"notification:dispatch:{notification.notification_id}",
            ttl_seconds=60,
            wait_timeout_seconds=0,
        ) as acquired:
            if not acquired:
                return False
            current = await self.notification_dao.get_by_id(
                Notification,
                notification.notification_id,
            )
            if current is None:
                return False
            if self._is_agent_completion_notification(current):
                logger.debug(
                    "[NotificationService] 跳过 Agent 完成控制通知的通用投递 "
                    f"notification={current.notification_id} user={current.user_id}"
                )
                return False
            if not self._can_claim_dispatch(current):
                return False
            if await self._is_user_conversation_active(current.user_id):
                current.status = constants.NOTIFICATION_STATUS_QUEUED
                current.dispatch_claimed_at = None
                current.status_detail = "Waiting for active conversation to finish"
                await self.notification_dao.save(current)
                notification.status = current.status
                notification.status_detail = current.status_detail
                return False
            current.status = constants.NOTIFICATION_STATUS_DISPATCHING
            current.dispatch_claimed_at = get_local_now()
            current.status_detail = "Dispatch in progress"
            await self.notification_dao.save(current)
            device_counts = await self.push_service.send_app_notification(
                notification=current,
            )
        success = device_counts[constants.PUSH_RESULT_KEY_SUCCESS]
        failed = device_counts[constants.PUSH_RESULT_KEY_FAILED]
        skipped = device_counts[constants.PUSH_RESULT_KEY_SKIPPED]
        now = get_local_now()
        if success > 0:
            current.status = constants.NOTIFICATION_STATUS_SENT
            current.dispatch_claimed_at = None
            current.status_detail = (
                f"Accepted by APNs for {success} device(s)"
                + (f"; {failed} failed" if failed > 0 else "")
            )
            current.delivered_at = now
            current.failed_at = None
        else:
            current.status = constants.NOTIFICATION_STATUS_FAILED
            current.dispatch_claimed_at = None
            current.failed_at = now
            metrics.inc_counter("ling_notification_dispatch_failed_total")
            if skipped > 0 and failed == 0:
                current.status_detail = "APNs is not configured"
            elif failed == 0:
                current.status_detail = "No active push device"
            else:
                current.status_detail = f"Push delivery failed for {failed} device(s)"
        await self.notification_dao.save(current)
        notification.status = current.status
        notification.status_detail = current.status_detail
        notification.delivered_at = current.delivered_at
        notification.failed_at = current.failed_at
        return True

    async def _is_user_conversation_active(self, user_id: str) -> bool:
        """Return True when the user's daily chat session currently has an active run."""
        try:
            from models.push import UserPushDeviceDao
            from models.user import UserConfigDao
            from services.agent.runtime import get_agent_run_manager
            from services.agent.service import build_daily_session_id
            from utils.time import normalize_persisted_timezone

            session_timezone = constants.UTC_TIMEZONE_NAME
            device = await UserPushDeviceDao().get_latest_device(user_id)
            if device is not None and device.timezone:
                session_timezone = (
                    normalize_persisted_timezone(device.timezone)
                    or constants.UTC_TIMEZONE_NAME
                )
            if session_timezone == constants.UTC_TIMEZONE_NAME:
                config = await UserConfigDao().get_config(user_id)
                configured_timezone = str(config.get("timezone") or "").strip()
                if configured_timezone:
                    session_timezone = (
                        normalize_persisted_timezone(configured_timezone)
                        or constants.UTC_TIMEZONE_NAME
                    )
            session_id = build_daily_session_id(user_id, session_timezone)
            return await get_agent_run_manager().is_session_active(session_id)
        except Exception:
            logger.debug(
                "[NotificationService] active conversation check failed "
                f"user_id={user_id}",
                exc_info=True,
            )
            return False

    def _parse_optional_datetime(self, value: str | None) -> datetime | None:
        if value in (None, ""):
            return None
        return to_storage_utc(self.calendar_service.parse_datetime(value))

    def _is_due(self, notification: Notification) -> bool:
        return notification.send_time is None or notification.send_time <= get_local_now()

    def _is_agent_completion_notification(self, notification: Notification) -> bool:
        return (
            getattr(notification, "category", None)
            == constants.NOTIFICATION_CATEGORY_AGENT_COMPLETION
        )

    def _can_claim_dispatch(self, notification: Notification) -> bool:
        if not self._is_due(notification):
            return False
        if notification.status == constants.NOTIFICATION_STATUS_QUEUED:
            return True
        if notification.status != constants.NOTIFICATION_STATUS_DISPATCHING:
            return False
        if notification.dispatch_claimed_at is None:
            return True
        stale_before = get_local_now() - timedelta(
            seconds=self._resolved_dispatch_claim_timeout_seconds()
        )
        return notification.dispatch_claimed_at <= stale_before

    def _resolved_dispatch_claim_timeout_seconds(self) -> int:
        value = getattr(self._config, "notification_dispatch_claim_timeout_seconds", None)
        if isinstance(value, int) and value > 0:
            return value
        return self._DEFAULT_DISPATCH_CLAIM_TIMEOUT_SECONDS

    def _resolved_dispatch_max_concurrency(self) -> int:
        value = getattr(self._config, "notification_dispatch_max_concurrency", None)
        if isinstance(value, int) and value > 0:
            return value
        return self._DEFAULT_DISPATCH_MAX_CONCURRENCY
