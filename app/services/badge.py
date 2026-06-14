"""App Icon Badge domain service."""

from __future__ import annotations

from dataclasses import dataclass

from models.notification import NotificationDao


@dataclass(frozen=True)
class BadgeCount:
    total: int
    unread_notification_count: int
    cap: int

    def to_dict(self) -> dict[str, int]:
        return {
            "total": self.total,
            "unread_notification_count": self.unread_notification_count,
            "cap": self.cap,
        }


class BadgeService:
    """Calculates and clears App Icon Badge counts for a user."""

    _CAP = 99

    def __init__(
        self,
        *,
        notification_dao: NotificationDao | None = None,
    ) -> None:
        self.notification_dao = notification_dao or NotificationDao()

    async def get_user_badge_count(
        self,
        user_id: str,
        *,
        extra_unread_notification_count: int = 0,
    ) -> BadgeCount:
        unread_notifications = (
            await self.notification_dao.count_unread_sent_notifications(user_id)
        ) + max(0, extra_unread_notification_count)
        raw_total = unread_notifications
        return BadgeCount(
            total=min(self._CAP, raw_total),
            unread_notification_count=unread_notifications,
            cap=self._CAP,
        )

    async def mark_all_badge_items_viewed(self, user_id: str) -> BadgeCount:
        await self.notification_dao.mark_unread_sent_notifications_opened(user_id)
        return await self.get_user_badge_count(user_id)

    async def mark_all_notifications_read(self, user_id: str) -> BadgeCount:
        return await self.mark_all_badge_items_viewed(user_id)

    async def mark_notification_opened(
        self,
        user_id: str,
        notification_id: str,
    ) -> BadgeCount:
        updated = await self.notification_dao.mark_user_notification_opened(
            user_id,
            notification_id,
        )
        if not updated:
            from core.http.exceptions import AppHTTPException

            raise AppHTTPException(status_code=404, detail="Notification not found")
        return await self.get_user_badge_count(user_id)
