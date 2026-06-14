from __future__ import annotations

from datetime import datetime
from typing import Optional

from config import constants
from sqlalchemy import String, or_
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base, BaseDao, get_local_now


class Notification(Base):
    __tablename__ = "notifications"

    notification_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    body: Mapped[str] = mapped_column(String(2048), nullable=False)
    category: Mapped[str] = mapped_column(String(64), nullable=False, default=constants.DEFAULT_NOTIFICATION_CATEGORY)
    priority: Mapped[str] = mapped_column(String(32), nullable=False, default=constants.DEFAULT_NOTIFICATION_PRIORITY)
    silent: Mapped[bool] = mapped_column(nullable=False, default=False)
    dedupe_key: Mapped[Optional[str]] = mapped_column(String(255), nullable=True, index=True)

    target_type: Mapped[Optional[str]] = mapped_column(String(64), nullable=True, index=True)
    target_id: Mapped[Optional[str]] = mapped_column(String(128), nullable=True, index=True)
    target_action: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)

    send_time: Mapped[Optional[datetime]] = mapped_column(nullable=True, index=True)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default=constants.NOTIFICATION_STATUS_QUEUED, index=True)
    dispatch_claimed_at: Mapped[Optional[datetime]] = mapped_column(nullable=True, index=True)
    status_detail: Mapped[Optional[str]] = mapped_column(String(1024), nullable=True)
    delivered_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    opened_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    dismissed_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    failed_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    created_at: Mapped[datetime] = mapped_column(nullable=False, index=True)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        notification_id: str,
        user_id: str,
        title: str,
        body: str,
        category: str = constants.DEFAULT_NOTIFICATION_CATEGORY,
        priority: str = constants.DEFAULT_NOTIFICATION_PRIORITY,
        silent: bool = False,
        dedupe_key: Optional[str] = None,
        target_type: Optional[str] = None,
        target_id: Optional[str] = None,
        target_action: Optional[str] = None,
        send_time: Optional[datetime] = None,
        status: str = constants.NOTIFICATION_STATUS_QUEUED,
        status_detail: Optional[str] = None,
    ):
        now = get_local_now()
        self.notification_id = notification_id
        self.user_id = user_id
        self.title = title
        self.body = body
        self.category = category
        self.priority = priority
        self.silent = silent
        self.dedupe_key = dedupe_key
        self.target_type = target_type
        self.target_id = target_id
        self.target_action = target_action
        self.send_time = send_time
        self.status = status
        self.dispatch_claimed_at = None
        self.status_detail = status_detail
        self.delivered_at = None
        self.opened_at = None
        self.dismissed_at = None
        self.failed_at = None
        self.created_at = now
        self.updated_at = now


class NotificationDao(BaseDao):
    async def save(self, notification: Notification) -> bool:
        notification.updated_at = get_local_now()
        return await BaseDao.save(self, notification)

    async def get_latest_by_dedupe_key(
        self,
        user_id: str,
        dedupe_key: str,
    ) -> Optional[Notification]:
        return await BaseDao.get_first(
            self,
            Notification,
            where=[
                Notification.user_id == user_id,
                Notification.dedupe_key == dedupe_key,
            ],
            order_by=Notification.updated_at.desc(),
        )

    async def list_user_notifications(
        self,
        user_id: str,
        *,
        start_time: datetime | None = None,
        end_time: datetime | None = None,
        statuses: list[str] | None = None,
        limit: int = 50,
    ) -> list[Notification]:
        where = [Notification.user_id == user_id]
        if start_time is not None:
            where.append(Notification.created_at >= start_time)
        if end_time is not None:
            where.append(Notification.created_at < end_time)
        if statuses:
            where.append(Notification.status.in_(statuses))
        return await BaseDao.get_list(
            self,
            Notification,
            where=where,
            order_by=Notification.created_at.desc(),
            limit=max(1, limit),
        )

    async def count_unread_sent_notifications(self, user_id: str) -> int:
        return await BaseDao.count(
            self,
            Notification,
            where=[
                Notification.user_id == user_id,
                Notification.status == constants.NOTIFICATION_STATUS_SENT,
                Notification.opened_at.is_(None),
                Notification.dismissed_at.is_(None),
            ],
        )

    async def mark_unread_sent_notifications_opened(self, user_id: str) -> None:
        now = get_local_now()
        await BaseDao.update_where(
            self,
            Notification,
            where=[
                Notification.user_id == user_id,
                Notification.status == constants.NOTIFICATION_STATUS_SENT,
                Notification.opened_at.is_(None),
                Notification.dismissed_at.is_(None),
            ],
            values={"opened_at": now, "updated_at": now},
        )

    async def mark_user_notification_opened(
        self,
        user_id: str,
        notification_id: str,
    ) -> bool:
        notification = await BaseDao.get_first(
            self,
            Notification,
            where=[
                Notification.user_id == user_id,
                Notification.notification_id == notification_id,
            ],
        )
        if notification is None:
            return False
        notification.opened_at = notification.opened_at or get_local_now()
        await self.save(notification)
        return True

    async def list_due_notifications(
        self,
        *,
        now: datetime,
        stale_dispatching_before: datetime | None = None,
        limit: int = 20,
    ) -> list[Notification]:
        due_where = [
            or_(
                Notification.send_time.is_(None),
                Notification.send_time <= now,
            ),
            Notification.category != constants.NOTIFICATION_CATEGORY_AGENT_COMPLETION,
            or_(
                Notification.status == constants.NOTIFICATION_STATUS_QUEUED,
                *(
                    [
                        (
                            (Notification.status == constants.NOTIFICATION_STATUS_DISPATCHING)
                            & Notification.dispatch_claimed_at.is_not(None)
                            & (Notification.dispatch_claimed_at <= stale_dispatching_before)
                        )
                    ]
                    if stale_dispatching_before is not None
                    else []
                ),
            ),
        ]
        return await BaseDao.get_list(
            self,
            Notification,
            where=due_where,
            order_by=Notification.created_at.asc(),
            limit=max(1, limit),
        )
