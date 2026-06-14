from __future__ import annotations

from typing import Any

from utils.logging import logger


class MembershipAnalyticsSink:
    """Default membership analytics sink backed by structured logs."""

    def emit(
        self,
        event_name: str,
        *,
        user_id: str | None = None,
        payload: dict[str, Any] | None = None,
    ) -> None:
        logger.bind(
            membership_event=event_name,
            membership_user_id=user_id,
            membership_payload=payload or {},
        ).info("[MembershipAnalytics] 会员分析事件 {}", event_name)
