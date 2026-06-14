from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from config import constants
from modules.membership.models import MembershipStateDao

FEATURE_CHAT_BASIC = "feature.chat.basic"
FEATURE_CALENDAR_BASIC = "feature.calendar.basic"
FEATURE_SETTINGS_ACCOUNT = "feature.settings.account"
FEATURE_BASIC_REMINDERS = "feature.reminders.basic"
FEATURE_ALL_TOOLS = "feature.tools.all"

FREE_DAILY_CHAT_LIMIT = 50

BASIC_FEATURE_ENTITLEMENTS = [
    FEATURE_CHAT_BASIC,
    FEATURE_CALENDAR_BASIC,
    FEATURE_SETTINGS_ACCOUNT,
    FEATURE_BASIC_REMINDERS,
]

PRO_FEATURE_ENTITLEMENTS = [
    *BASIC_FEATURE_ENTITLEMENTS,
    FEATURE_ALL_TOOLS,
]


@dataclass(frozen=True, slots=True)
class MembershipEntitlementSnapshot:
    is_pro: bool
    daily_chat_limit: int | None
    feature_entitlements: list[str]
    limits: dict[str, Any]


def entitlement_snapshot_for_tier(
    tier_code: str,
    access_state: str,
) -> MembershipEntitlementSnapshot:
    is_pro = (
        tier_code == constants.MEMBERSHIP_TIER_PRO
        and access_state == constants.MEMBERSHIP_ACCESS_ACTIVE
    )
    return MembershipEntitlementSnapshot(
        is_pro=is_pro,
        daily_chat_limit=None if is_pro else FREE_DAILY_CHAT_LIMIT,
        feature_entitlements=list(
            PRO_FEATURE_ENTITLEMENTS if is_pro else BASIC_FEATURE_ENTITLEMENTS
        ),
        limits={
            "daily_chat_limit": None if is_pro else FREE_DAILY_CHAT_LIMIT,
        },
    )


class MembershipEntitlementService:
    def __init__(self) -> None:
        self.state_dao = MembershipStateDao()

    async def snapshot_for_user(self, user_id: str) -> MembershipEntitlementSnapshot:
        from modules.membership.service import MembershipService

        return await MembershipService().entitlement_snapshot_for_user(user_id)

    async def is_pro_user(self, user_id: str) -> bool:
        return (await self.snapshot_for_user(user_id)).is_pro

    async def can_use_feature(self, user_id: str, feature_code: str) -> bool:
        snapshot = await self.snapshot_for_user(user_id)
        return feature_code in snapshot.feature_entitlements

    async def chat_limit_for(self, user_id: str) -> int | None:
        return (await self.snapshot_for_user(user_id)).daily_chat_limit
