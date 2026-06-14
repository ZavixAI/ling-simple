from __future__ import annotations

from typing import Any

from core.http.exceptions import AppHTTPException
from core.infra.db import get_global_db
from core.infra.redis import redis
from modules.membership.models import MembershipDailyUsage
from modules.membership.service import (
    MEMBERSHIP_ERROR_CODE_QUOTA_EXHAUSTED,
    MembershipService,
    current_business_date_key,
)
from sqlalchemy import select, text
from utils.time import utc_now_naive


class MembershipQuotaService:
    def __init__(self) -> None:
        self.membership_service = MembershipService()

    async def consume_daily_chat_quota(self, user_id: str) -> dict[str, Any]:
        summary = await self.membership_service.build_summary(user_id)
        limit = summary.daily_chat_limit
        if limit is None:
            return summary.model_dump()

        business_date = current_business_date_key()
        lock_key = f"{user_id}:{business_date}"
        async with redis.lock_or_raise(
            f"membership:quota:{lock_key}",
            error=AppHTTPException(
                status_code=409,
                detail="Membership quota is busy",
            ),
            ttl_seconds=15,
            wait_timeout_seconds=5,
        ):
            db = await get_global_db()
            quota_exhausted = False
            async with db.get_session() as session:
                await session.execute(
                    text(
                        """
                        INSERT IGNORE INTO membership_daily_usage
                        (usage_id, user_id, business_date, chat_limit, chat_used, last_consumed_at, created_at, updated_at)
                        VALUES
                        (:usage_id, :user_id, :business_date, :chat_limit, 0, NULL, UTC_TIMESTAMP(), UTC_TIMESTAMP())
                        """
                    ),
                    {
                        "usage_id": f"mdu:{user_id}:{business_date}",
                        "user_id": user_id,
                        "business_date": business_date,
                        "chat_limit": limit,
                    },
                )
                result = await session.execute(
                    select(MembershipDailyUsage)
                    .where(
                        MembershipDailyUsage.user_id == user_id,
                        MembershipDailyUsage.business_date == business_date,
                    )
                    .with_for_update()
                )
                usage = result.scalars().first()
                if usage is None:
                    raise AppHTTPException(status_code=500, detail="Membership daily usage row missing")
                usage.chat_limit = limit
                if usage.chat_used >= limit:
                    quota_exhausted = True
                else:
                    usage.chat_used += 1
                    usage.last_consumed_at = utc_now_naive()
            if quota_exhausted:
                refreshed = await self.membership_service.build_summary(user_id)
                raise AppHTTPException(
                    status_code=402,
                    detail="Daily chat quota exhausted",
                    error_code=MEMBERSHIP_ERROR_CODE_QUOTA_EXHAUSTED,
                    error_detail={
                        "reason": "daily_limit_reached",
                        "summary": refreshed.model_dump(),
                    },
                )
            return (await self.membership_service.build_summary(user_id)).model_dump()
