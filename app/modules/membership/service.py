from __future__ import annotations

import asyncio
import calendar
import uuid
from dataclasses import dataclass
from datetime import datetime
from typing import Any

from config import constants
from core.http.exceptions import AppHTTPException
from core.infra.db import transaction_scope
from core.infra.redis import redis
from modules.membership.analytics import MembershipAnalyticsSink
from modules.membership.entitlements import (
    BASIC_FEATURE_ENTITLEMENTS,
    FREE_DAILY_CHAT_LIMIT,
    MembershipEntitlementSnapshot,
    PRO_FEATURE_ENTITLEMENTS,
    entitlement_snapshot_for_tier,
)
from modules.membership.models import (
    MembershipDailyUsageDao,
    MembershipPeriod,
    MembershipPeriodDao,
    MembershipProduct,
    MembershipProductChannel,
    MembershipProductChannelDao,
    MembershipProductDao,
    MembershipState,
    MembershipStateDao,
    MembershipSubscription,
    MembershipSubscriptionDao,
    PaymentOrder,
    PaymentOrderDao,
    PaymentTransaction,
    PaymentTransactionDao,
    PointsAccount,
    PointsAccountDao,
)
from modules.membership.providers import MembershipProviderEvent
from modules.membership.providers.apple import (
    AppleAppStoreServerClient,
    AppleJWSVerifier,
    AppleTransactionInfo,
)
from schema.api.membership import (
    MembershipCatalogChannelPayload,
    MembershipCatalogProductPayload,
    MembershipSummaryPayload,
)
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from utils.time import (
    UTC,
    ensure_utc,
    format_datetime,
    parse_timezone,
    to_storage_utc,
    utc_now_naive,
)

BUSINESS_TIMEZONE = constants.DEFAULT_TIMEZONE
FREE_TIER_CODE = constants.MEMBERSHIP_TIER_FREE
PRO_TIER_CODE = constants.MEMBERSHIP_TIER_PRO
RENEWAL_RECURRING = constants.MEMBERSHIP_RENEWAL_RECURRING
MEMBERSHIP_ERROR_CODE_QUOTA_EXHAUSTED = "membership_quota_exhausted"
MEMBERSHIP_ERROR_CODE_ENTITLEMENT_REQUIRED = "membership_entitlement_required"
MEMBERSHIP_ERROR_CODE_APPLE_SUBSCRIPTION_LINKED = (
    "apple_subscription_linked_to_another_account"
)
ENTITLEMENT_CHAT_DAILY_LIMIT = "chat_daily_limit"
ENTITLEMENT_MEMBER_CORE = "member_core"
ENTITLEMENT_MEMBER_ADVANCED = "member_advanced"

_CATALOG_LOCK = asyncio.Lock()
_ENTITLEMENT_CACHE_TTL_SECONDS = 5 * 60
_ENTITLEMENT_CACHE_SCHEMA_VERSION = 1


def _state_value_changed(state: MembershipState, values: dict[str, Any]) -> bool:
    return any(getattr(state, key) != value for key, value in values.items())


async def _save_state_if_changed(
    dao: MembershipStateDao,
    state: MembershipState,
    values: dict[str, Any],
    *,
    is_new: bool,
    session: AsyncSession | None,
) -> MembershipState:
    if is_new or _state_value_changed(state, values):
        for key, value in values.items():
            setattr(state, key, value)
        await dao.save(state, session=session)
    return state


def _string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item) for item in value]


def _entitlement_snapshot_to_cache(
    *,
    state: MembershipState,
    snapshot: MembershipEntitlementSnapshot,
) -> dict[str, Any]:
    return {
        "schema_version": _ENTITLEMENT_CACHE_SCHEMA_VERSION,
        "tier_code": state.tier_code,
        "access_state": state.access_state,
        "feature_entitlements": list(snapshot.feature_entitlements),
        "daily_chat_limit": snapshot.daily_chat_limit,
        "limits": dict(snapshot.limits),
    }


def _entitlement_snapshot_from_cache(
    payload: Any,
) -> MembershipEntitlementSnapshot | None:
    if not isinstance(payload, dict):
        return None
    if payload.get("schema_version") != _ENTITLEMENT_CACHE_SCHEMA_VERSION:
        return None
    tier_code = str(payload.get("tier_code") or "")
    access_state = str(payload.get("access_state") or "")
    if not tier_code or not access_state:
        return None
    return MembershipEntitlementSnapshot(
        is_pro=(
            tier_code == constants.MEMBERSHIP_TIER_PRO
            and access_state == constants.MEMBERSHIP_ACCESS_ACTIVE
        ),
        daily_chat_limit=payload.get("daily_chat_limit"),
        feature_entitlements=_string_list(payload.get("feature_entitlements")),
        limits=dict(payload.get("limits") or {}),
    )


def _catalog_seed_rows() -> list[dict[str, Any]]:
    definitions = []
    entries = [
        ("pro_month_recurring", PRO_TIER_CODE, "month", RENEWAL_RECURRING, 1, "Pro 连续包月", "全部功能 + 不限对话", None, None, 29800, 0),
    ]
    for (
        internal_product_code,
        tier_code,
        period_code,
        renewal_type,
        duration_months,
        display_name,
        display_subtitle,
        marketing_label,
        daily_chat_limit,
        amount_minor,
        sort_order,
    ) in entries:
        definitions.append(
            {
                "internal_product_code": internal_product_code,
                "tier_code": tier_code,
                "period_code": period_code,
                "renewal_type": renewal_type,
                "duration_months": duration_months,
                "display_name": display_name,
                "display_subtitle": display_subtitle,
                "marketing_label": marketing_label,
                "daily_chat_limit": daily_chat_limit,
                "entitlements": [
                    ENTITLEMENT_MEMBER_CORE,
                    ENTITLEMENT_MEMBER_ADVANCED,
                ],
                "metadata": {
                    "recommended": bool(marketing_label in {"推荐", "旗舰"}),
                    "feature_entitlements": list(PRO_FEATURE_ENTITLEMENTS),
                    "free_feature_entitlements": list(BASIC_FEATURE_ENTITLEMENTS),
                    "subscription_sheet": {
                        "tier_cards": [
                            {
                                "tier_code": FREE_TIER_CODE,
                                "title": "Free",
                                "price_label_zh": "免费",
                                "price_label_en": "Free",
                                "features_zh": [
                                    "基础日程管理",
                                    "基础想法管理",
                                    "每日 50 次文字/图片对话",
                                ],
                                "features_en": [
                                    "Basic scheduling",
                                    "Basic idea management",
                                    "50 text/image chats per day",
                                ],
                            },
                            {
                                "tier_code": PRO_TIER_CODE,
                                "title": "Pro",
                                "features_zh": [
                                    "不限文字/图片对话",
                                    "图片输入与理解",
                                    "全部可用工具",
                                    "记忆整理与分享素材能力",
                                    "新能力优先开放",
                                ],
                                "features_en": [
                                    "Unlimited text/image chats",
                                    "Image input and understanding",
                                    "All available tools",
                                    "Memory work and share materials",
                                    "Early access to new capabilities",
                                ],
                            },
                        ]
                    },
                    "entitlement_sections": [
                        {
                            "title_zh": "页面功能点",
                            "title_en": "Page features",
                            "free_items_zh": [
                                "聊天基础能力",
                                "日程/想法基础查看与创建",
                                "设置与账号绑定",
                                "基础提醒配置",
                            ],
                            "free_items_en": [
                                "Basic chat",
                                "Basic schedule and idea views",
                                "Settings and account linking",
                                "Basic reminder settings",
                            ],
                            "pro_items_zh": [
                                "图片输入与理解",
                                "全部工具与能力",
                                "关注复看类能力",
                                "动态素材机会",
                            ],
                            "pro_items_en": [
                                "Image input and understanding",
                                "All tools and capabilities",
                                "Watch review workflows",
                                "Share material opportunities",
                            ],
                        },
                        {
                            "title_zh": "对话次数",
                            "title_en": "Chat quota",
                            "free_items_zh": [f"每日 {FREE_DAILY_CHAT_LIMIT} 次对话"],
                            "free_items_en": [f"{FREE_DAILY_CHAT_LIMIT} chats per day"],
                            "pro_items_zh": ["每日不限对话"],
                            "pro_items_en": ["Unlimited chats per day"],
                        },
                    ],
                },
                "sort_order": sort_order,
                "is_active": True,
                "channels": [
                    {
                        "provider": constants.PAYMENT_PROVIDER_APPLE,
                        "platform": constants.PLATFORM_IOS,
                        "provider_product_id": f"ling.{internal_product_code}",
                        "currency_code": constants.DEFAULT_CURRENCY_CODE,
                        "amount_minor": amount_minor,
                        "marketing_label": marketing_label,
                    },
                    {
                        "provider": constants.PAYMENT_PROVIDER_ALIPAY,
                        "platform": constants.PLATFORM_ALL,
                        "provider_product_id": f"alipay.{internal_product_code}",
                        "currency_code": constants.DEFAULT_CURRENCY_CODE,
                        "amount_minor": amount_minor,
                        "marketing_label": marketing_label,
                    },
                    {
                        "provider": constants.PAYMENT_PROVIDER_WECHAT,
                        "platform": constants.PLATFORM_ALL,
                        "provider_product_id": f"wechat.{internal_product_code}",
                        "currency_code": constants.DEFAULT_CURRENCY_CODE,
                        "amount_minor": amount_minor,
                        "marketing_label": marketing_label,
                    },
                ],
            }
        )
    return definitions


def _current_utc() -> datetime:
    return utc_now_naive().replace(tzinfo=UTC)


def _uuid_pk(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex}"


def _normalize_optional(value: str | None) -> str | None:
    normalized = (value or "").strip()
    return normalized or None


def _language_code(locale: str | None) -> str:
    normalized = (locale or "").strip().lower()
    if normalized.startswith("zh"):
        return "zh"
    return "en"


def _localized_text(values: dict[str, str], locale: str | None) -> str:
    language = _language_code(locale)
    return values.get(language) or values["en"]


def _localized_catalog_metadata(
    metadata: dict[str, Any],
    locale: str | None,
) -> dict[str, Any]:
    result = dict(metadata)
    sheet = result.get("subscription_sheet")
    if not isinstance(sheet, dict):
        return result

    localized_cards: list[dict[str, Any]] = []
    for raw_card in sheet.get("tier_cards") or []:
        if not isinstance(raw_card, dict):
            continue
        card = dict(raw_card)
        card["price_label"] = _localized_text_from_card(card, "price_label", locale)
        card["features"] = _localized_list_from_card(card, "features", locale)
        for key in (
            "price_label_zh",
            "price_label_en",
            "features_zh",
            "features_en",
        ):
            card.pop(key, None)
        localized_cards.append(card)

    result["subscription_sheet"] = {
        **sheet,
        "tier_cards": localized_cards,
    }
    return result


def _localized_text_from_card(
    card: dict[str, Any],
    key: str,
    locale: str | None,
) -> str:
    language = _language_code(locale)
    localized = str(card.get(f"{key}_{language}") or "").strip()
    if localized:
        return localized
    fallback = str(card.get(key) or "").strip()
    if fallback:
        return fallback
    return str(card.get(f"{key}_en") or card.get(f"{key}_zh") or "").strip()


def _localized_list_from_card(
    card: dict[str, Any],
    key: str,
    locale: str | None,
) -> list[str]:
    language = _language_code(locale)
    raw = card.get(f"{key}_{language}") or card.get(key) or card.get(f"{key}_en")
    if not isinstance(raw, list):
        raw = card.get(f"{key}_zh")
    if not isinstance(raw, list):
        return []
    return [str(item).strip() for item in raw if str(item).strip()]


def _parse_optional_datetime(value: str | None) -> datetime | None:
    normalized = _normalize_optional(value)
    if normalized is None:
        return None
    return ensure_utc(datetime.fromisoformat(normalized))


def _business_timezone():
    return parse_timezone(BUSINESS_TIMEZONE)


def current_business_now() -> datetime:
    return _current_utc().astimezone(_business_timezone())


def current_business_date_key() -> str:
    return current_business_now().date().isoformat()


def add_months(value: datetime, months: int) -> datetime:
    source = ensure_utc(value)
    month_index = (source.month - 1) + months
    year = source.year + month_index // 12
    month = (month_index % 12) + 1
    day = min(source.day, calendar.monthrange(year, month)[1])
    return source.replace(year=year, month=month, day=day)


@dataclass(slots=True)
class MembershipPeriodWindow:
    started_at: datetime
    paid_through_at: datetime


class MembershipService:
    def __init__(self) -> None:
        self.analytics = MembershipAnalyticsSink()
        self.product_dao = MembershipProductDao()
        self.channel_dao = MembershipProductChannelDao()
        self.order_dao = PaymentOrderDao()
        self.transaction_dao = PaymentTransactionDao()
        self.subscription_dao = MembershipSubscriptionDao()
        self.period_dao = MembershipPeriodDao()
        self.state_dao = MembershipStateDao()
        self.daily_usage_dao = MembershipDailyUsageDao()
        self.points_account_dao = PointsAccountDao()
        self.apple_verifier = AppleJWSVerifier()

    def _entitlement_cache_key(self, user_id: str) -> str:
        return redis.key("membership", "entitlement", user_id)

    async def invalidate_entitlement_snapshot(self, user_id: str) -> None:
        await redis.delete(self._entitlement_cache_key(user_id))

    async def entitlement_snapshot_for_user(
        self,
        user_id: str,
    ) -> MembershipEntitlementSnapshot:
        cached = await redis.get_json(
            self._entitlement_cache_key(user_id),
            default=None,
        )
        snapshot = _entitlement_snapshot_from_cache(cached)
        if snapshot is not None:
            return snapshot

        state = await self.refresh_membership_state(user_id)
        snapshot = entitlement_snapshot_for_tier(state.tier_code, state.access_state)
        await redis.set_json(
            self._entitlement_cache_key(user_id),
            _entitlement_snapshot_to_cache(
                state=state,
                snapshot=snapshot,
            ),
            ex=_ENTITLEMENT_CACHE_TTL_SECONDS,
        )
        return snapshot

    async def ensure_catalog_seeded(
        self,
        *,
        session: AsyncSession | None = None,
    ) -> None:
        async with _CATALOG_LOCK:
            for definition in _catalog_seed_rows():
                existing = await self.product_dao.get_product(
                    definition["internal_product_code"],
                    session=session,
                )
                if existing is None:
                    existing = MembershipProduct(
                        internal_product_code=definition["internal_product_code"],
                        tier_code=definition["tier_code"],
                        period_code=definition["period_code"],
                        renewal_type=definition["renewal_type"],
                        duration_months=definition["duration_months"],
                        display_name=definition["display_name"],
                        display_subtitle=definition["display_subtitle"],
                        marketing_label=definition["marketing_label"],
                        daily_chat_limit=definition["daily_chat_limit"],
                        entitlements=list(definition["entitlements"]),
                        metadata=dict(definition["metadata"]),
                        sort_order=definition["sort_order"],
                        is_active=definition["is_active"],
                    )
                else:
                    existing.tier_code = definition["tier_code"]
                    existing.period_code = definition["period_code"]
                    existing.renewal_type = definition["renewal_type"]
                    existing.duration_months = definition["duration_months"]
                    existing.display_name = definition["display_name"]
                    existing.display_subtitle = definition["display_subtitle"]
                    existing.marketing_label = definition["marketing_label"]
                    existing.daily_chat_limit = definition["daily_chat_limit"]
                    existing.entitlements = list(definition["entitlements"])
                    existing.metadata_json = dict(definition["metadata"])
                    existing.sort_order = definition["sort_order"]
                    existing.is_active = definition["is_active"]
                await self.product_dao.save(existing, session=session)

                for channel_definition in definition["channels"]:
                    channel = await self.channel_dao.get_channel(
                        definition["internal_product_code"],
                        channel_definition["provider"],
                        session=session,
                    )
                    if channel is None:
                        channel = MembershipProductChannel(
                            channel_id=_uuid_pk("mpc"),
                            internal_product_code=definition["internal_product_code"],
                            provider=channel_definition["provider"],
                            platform=channel_definition["platform"],
                            provider_product_id=channel_definition["provider_product_id"],
                            currency_code=channel_definition["currency_code"],
                            amount_minor=channel_definition["amount_minor"],
                            marketing_label=channel_definition["marketing_label"],
                            metadata={},
                            is_active=True,
                        )
                    else:
                        channel.platform = channel_definition["platform"]
                        channel.provider_product_id = channel_definition["provider_product_id"]
                        channel.currency_code = channel_definition["currency_code"]
                        channel.amount_minor = channel_definition["amount_minor"]
                        channel.marketing_label = channel_definition["marketing_label"]
                        channel.metadata_json = {}
                        channel.is_active = True
                    await self.channel_dao.save(channel, session=session)

    async def get_catalog(
        self,
        *,
        locale: str | None = None,
    ) -> list[MembershipCatalogProductPayload]:
        await self.ensure_catalog_seeded()
        products = await self.product_dao.list_active_products()
        result: list[MembershipCatalogProductPayload] = []
        for product in products:
            channels = await self.channel_dao.list_channels_for_product(
                product.internal_product_code
            )
            result.append(
                MembershipCatalogProductPayload(
                    internal_product_code=product.internal_product_code,
                    tier_code=product.tier_code,
                    period_code=product.period_code,
                    renewal_type=product.renewal_type,
                    duration_months=product.duration_months,
                    display_name=product.display_name,
                    display_subtitle=product.display_subtitle,
                    marketing_label=product.marketing_label,
                    daily_chat_limit=product.daily_chat_limit,
                    entitlements=list(product.entitlements or []),
                    metadata=_localized_catalog_metadata(
                        dict(product.metadata_json or {}),
                        locale,
                    ),
                    channels=[
                        MembershipCatalogChannelPayload(
                            provider=channel.provider,
                            platform=channel.platform,
                            provider_product_id=channel.provider_product_id,
                            currency_code=channel.currency_code,
                            amount_minor=channel.amount_minor,
                            marketing_label=channel.marketing_label,
                            metadata=dict(channel.metadata_json or {}),
                        )
                        for channel in channels
                        if channel.is_active
                    ],
                )
            )
        return result

    async def ensure_points_account(
        self,
        user_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> PointsAccount:
        existing = await self.points_account_dao.get_by_user_id(
            user_id,
            session=session,
        )
        if existing is not None:
            return existing
        account = PointsAccount(account_id=_uuid_pk("pac"), user_id=user_id, balance=0)
        await self.points_account_dao.save(account, session=session)
        return account

    async def build_summary(
        self,
        user_id: str,
        *,
        locale: str | None = None,
        session: AsyncSession | None = None,
    ) -> MembershipSummaryPayload:
        account = await self.ensure_points_account(user_id, session=session)
        state = await self.refresh_membership_state(
            user_id,
            session=session,
        )
        usage = await self.daily_usage_dao.get_user_business_day_usage(
            user_id,
            current_business_date_key(),
            session=session,
        )
        entitlement_snapshot = entitlement_snapshot_for_tier(
            state.tier_code,
            state.access_state,
        )
        daily_chat_limit = entitlement_snapshot.daily_chat_limit
        daily_chat_used = usage.chat_used if usage is not None else 0
        daily_chat_remaining = None
        if daily_chat_limit is not None:
            daily_chat_remaining = max(0, daily_chat_limit - daily_chat_used)
        return MembershipSummaryPayload(
            tier_code=state.tier_code,
            access_state=state.access_state,
            renewal_type=state.renewal_type,
            provider=state.provider,
            started_at=format_datetime(state.started_at.replace(tzinfo=UTC) if state.started_at else None),
            paid_through_at=format_datetime(state.paid_through_at.replace(tzinfo=UTC) if state.paid_through_at else None),
            cancel_at_period_end=bool(state.cancel_at_period_end),
            daily_chat_limit=daily_chat_limit,
            daily_chat_used=daily_chat_used,
            daily_chat_remaining=daily_chat_remaining,
            business_timezone=BUSINESS_TIMEZONE,
            server_now=format_datetime(_current_utc()),
            entitlements=list(state.entitlements or []),
            feature_entitlements=list(entitlement_snapshot.feature_entitlements),
            limits=dict(entitlement_snapshot.limits),
            points_balance=account.balance,
            active_product_code=None,
            display={
                "membership_state_card": self._membership_state_card_display(
                    state,
                    locale=locale,
                )
            },
        )

    def _membership_state_card_display(
        self,
        state: MembershipState,
        *,
        locale: str | None = None,
    ) -> dict[str, str]:
        if state.access_state == "active" and state.tier_code == PRO_TIER_CODE:
            return {
                "title": _localized_text(
                    {
                        "zh": "Pro 会员",
                        "en": "Pro Membership",
                    },
                    locale,
                ),
                "subtitle": _localized_text(
                    {
                        "zh": "已解锁全部 Pro 能力。",
                        "en": "All Pro capabilities are unlocked.",
                    },
                    locale,
                ),
            }
        return {
            "title": _localized_text(
                {
                    "zh": "未开通",
                    "en": "Not active",
                },
                locale,
            ),
            "subtitle": _localized_text(
                {
                    "zh": "查看适合你的 Ling 会员方案。",
                    "en": "View Ling membership options available to you.",
                },
                locale,
            ),
        }

    async def refresh_membership_state(
        self,
        user_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> MembershipState:
        now = _current_utc().replace(tzinfo=None)
        active_period = await self.period_dao.get_latest_active_period(
            user_id,
            now,
            session=session,
        )
        existing_state = await self.state_dao.get_state(
            user_id,
            session=session,
        )
        if active_period is None:
            tier_code = FREE_TIER_CODE
            access_state = constants.MEMBERSHIP_ACCESS_INACTIVE
            entitlements = [ENTITLEMENT_CHAT_DAILY_LIMIT]
            entitlement_snapshot = entitlement_snapshot_for_tier(
                tier_code,
                access_state,
            )
            default_values = {
                "tier_code": tier_code,
                "access_state": access_state,
                "active_period_id": None,
                "renewal_type": None,
                "provider": None,
                "subscription_id": None,
                "started_at": None,
                "paid_through_at": None,
                "cancel_at_period_end": False,
                "entitlements": entitlements,
                "daily_chat_limit": entitlement_snapshot.daily_chat_limit,
                "business_timezone": BUSINESS_TIMEZONE,
            }
            default_state = existing_state or MembershipState(user_id=user_id)
            state_changed = existing_state is None or _state_value_changed(
                default_state,
                default_values,
            )
            state = await _save_state_if_changed(
                self.state_dao,
                default_state,
                default_values,
                is_new=existing_state is None,
                session=session,
            )
            if state_changed:
                await self.invalidate_entitlement_snapshot(user_id)
            return state

        cancel_at_period_end = False
        subscription_id = active_period.source_subscription_id
        if subscription_id:
            subscription = await self.subscription_dao.get_subscription(
                subscription_id,
                session=session,
            )
            if subscription is not None:
                cancel_at_period_end = bool(subscription.cancel_at_period_end)

        product = await self.product_dao.get_product(
            active_period.internal_product_code,
            session=session,
        )
        entitlement_snapshot = entitlement_snapshot_for_tier(
            active_period.tier_code,
            constants.MEMBERSHIP_ACCESS_ACTIVE,
        )
        active_values = {
            "tier_code": active_period.tier_code,
            "access_state": constants.MEMBERSHIP_ACCESS_ACTIVE,
            "active_period_id": active_period.period_id,
            "renewal_type": active_period.renewal_type,
            "provider": active_period.provider,
            "subscription_id": subscription_id,
            "started_at": active_period.started_at,
            "paid_through_at": active_period.paid_through_at,
            "cancel_at_period_end": cancel_at_period_end,
            "entitlements": list(active_period.entitlements or []),
            "daily_chat_limit": (
                product.daily_chat_limit
                if product is not None and product.daily_chat_limit is not None
                else entitlement_snapshot.daily_chat_limit
            ),
            "business_timezone": BUSINESS_TIMEZONE,
        }
        state = existing_state or MembershipState(user_id=user_id)
        state_changed = existing_state is None or _state_value_changed(
            state,
            active_values,
        )
        state = await _save_state_if_changed(
            self.state_dao,
            state,
            active_values,
            is_new=existing_state is None,
            session=session,
        )
        if state_changed:
            await self.invalidate_entitlement_snapshot(user_id)
        return state

    async def prepare_checkout(
        self,
        user_id: str,
        *,
        internal_product_code: str,
        provider: str,
        platform: str,
    ) -> dict[str, Any]:
        await self.ensure_catalog_seeded()
        product = await self.product_dao.get_product(internal_product_code)
        if product is None or not product.is_active:
            raise AppHTTPException(status_code=404, detail="Membership product not found")
        channel = await self.channel_dao.get_channel(internal_product_code, provider)
        if channel is None or not channel.is_active:
            raise AppHTTPException(status_code=422, detail="Payment provider channel unavailable")

        order_no = _uuid_pk("ord")
        app_account_token = str(uuid.uuid5(uuid.NAMESPACE_URL, f"ling:{user_id}:{order_no}"))
        order = PaymentOrder(
            order_no=order_no,
            user_id=user_id,
            internal_product_code=internal_product_code,
            provider=provider,
            platform=platform,
            renewal_type=product.renewal_type,
            status=constants.MEMBERSHIP_STATUS_PENDING,
            currency_code=channel.currency_code,
            amount_minor=channel.amount_minor,
            provider_reference=app_account_token,
            checkout_payload={
                "provider_product_id": channel.provider_product_id,
                "app_account_token": app_account_token,
            },
        )
        await self.order_dao.save(order)
        self.analytics.emit(
            "checkout_start",
            user_id=user_id,
            payload={
                "order_no": order_no,
                "provider": provider,
                "internal_product_code": internal_product_code,
            },
        )
        return {
            "order_no": order_no,
            "provider": provider,
            "checkout_payload": {
                "provider_product_id": channel.provider_product_id,
                "currency_code": channel.currency_code,
                "amount_minor": channel.amount_minor,
                "app_account_token": app_account_token,
                "platform": platform,
            },
        }

    async def confirm_apple_purchase(
        self,
        user_id: str,
        payload: dict[str, Any],
        *,
        locale: str | None = None,
    ) -> MembershipSummaryPayload:
        signed_transaction_info = _normalize_optional(
            payload.get("signed_transaction_info")
            or payload.get("signedTransactionInfo")
            or payload.get("raw_payload", {}).get("signed_transaction_info")
            or payload.get("raw_payload", {}).get("signedTransactionInfo")
        )
        if signed_transaction_info is None:
            raise AppHTTPException(
                status_code=422,
                detail="signed_transaction_info is required",
            )
        verified = self.apple_verifier.decode_transaction(signed_transaction_info)
        transaction_id = verified.transaction_id

        existing_transaction = await self.transaction_dao.get_by_provider_external_transaction(
            constants.PAYMENT_PROVIDER_APPLE,
            transaction_id,
        )
        if existing_transaction is not None:
            return await self._recover_existing_apple_transaction_delivery(
                user_id=user_id,
                existing_transaction=existing_transaction,
                transaction=verified,
                locale=locale,
            )

        try:
            async with transaction_scope() as session:
                provider_product_id = verified.product_id
                channel = None
                if provider_product_id is not None:
                    channel = await self.channel_dao.get_by_provider_product(
                        constants.PAYMENT_PROVIDER_APPLE,
                        provider_product_id,
                        session=session,
                    )
                order = None
                order_no = _normalize_optional(payload.get("order_no"))
                if order_no is not None:
                    order = await self.order_dao.get_order(order_no, session=session)
                    if order is not None and order.user_id != user_id:
                        raise AppHTTPException(status_code=403, detail="Payment order does not belong to current user")
                    if channel is None and order is not None:
                        channel = await self.channel_dao.get_channel(
                            order.internal_product_code,
                            constants.PAYMENT_PROVIDER_APPLE,
                            session=session,
                        )

                if channel is None:
                    raise AppHTTPException(status_code=422, detail="Apple product mapping not found")
                product = await self.product_dao.get_product(
                    channel.internal_product_code,
                    session=session,
                )
                if product is None:
                    raise AppHTTPException(status_code=422, detail="Membership product mapping not found")

                purchase_at = verified.purchase_date or _current_utc()
                expiration_at = verified.expiration_date
                provider_subscription_id = (
                    verified.original_transaction_id
                    or transaction_id
                ) if product.renewal_type == RENEWAL_RECURRING else verified.original_transaction_id

                pending_transaction = PaymentTransaction(
                    transaction_id=_uuid_pk("txn"),
                    order_no=order.order_no if order is not None else order_no,
                    user_id=user_id,
                    internal_product_code=product.internal_product_code,
                    provider=constants.PAYMENT_PROVIDER_APPLE,
                    external_transaction_id=transaction_id,
                    external_subscription_id=provider_subscription_id,
                    transaction_type=(
                        constants.PAYMENT_TRANSACTION_TYPE_RESTORE
                        if payload.get("is_restore")
                        else constants.PAYMENT_TRANSACTION_TYPE_PURCHASE
                    ),
                    status=constants.PAYMENT_TRANSACTION_STATUS_SUCCEEDED,
                    occurred_at=to_storage_utc(purchase_at) or utc_now_naive(),
                    raw_payload={
                        **dict(payload),
                        "verified_transaction": dict(verified.raw_claims),
                    },
                )
                await self.transaction_dao.insert(pending_transaction, session=session)
                await session.flush()

                period = await self.apply_confirmed_purchase(
                    user_id=user_id,
                    product=product,
                    provider=constants.PAYMENT_PROVIDER_APPLE,
                    confirmed_at=purchase_at,
                    order_no=order.order_no if order is not None else order_no,
                    external_subscription_id=provider_subscription_id,
                    explicit_period_end=expiration_at,
                    session=session,
                )

                subscription = None
                if product.renewal_type == RENEWAL_RECURRING and provider_subscription_id is not None:
                    subscription = await self.subscription_dao.get_by_provider_subscription(
                        constants.PAYMENT_PROVIDER_APPLE,
                        provider_subscription_id,
                        session=session,
                    )
                    subscription.status = constants.MEMBERSHIP_STATUS_ACTIVE
                    subscription.cancel_at_period_end = False
                    subscription.current_period_start_at = period.started_at
                    subscription.current_period_end_at = period.paid_through_at
                    subscription.last_confirmed_at = to_storage_utc(purchase_at)
                    subscription.extra_data = {
                        **dict(subscription.extra_data or {}),
                        "latest_transaction_id": transaction_id,
                        "provider_product_id": channel.provider_product_id,
                        "environment": verified.environment,
                    }
                    await self.subscription_dao.save(subscription, session=session)

                if order is not None:
                    order.status = constants.PAYMENT_ORDER_STATUS_PAID
                    order.provider_order_id = transaction_id
                    order.provider_reference = channel.provider_product_id
                    order.subscription_id = subscription.subscription_id if subscription is not None else None
                    order.confirmed_at = to_storage_utc(purchase_at)
                    order.raw_payload = {
                        **dict(payload),
                        "verified_transaction": dict(verified.raw_claims),
                    }
                    await self.order_dao.save(order, session=session)

                summary = await self.build_summary(
                    user_id,
                    locale=locale,
                    session=session,
                )
        except IntegrityError as exc:
            detail = str(exc)
            if "external_transaction_id" in detail or "ux_payment_transactions_provider_external" in detail:
                return await self.build_summary(user_id, locale=locale)
            raise

        await self.invalidate_entitlement_snapshot(user_id)
        self.analytics.emit(
            "checkout_success",
            user_id=user_id,
            payload={
                "provider": constants.PAYMENT_PROVIDER_APPLE,
                "internal_product_code": product.internal_product_code,
                "transaction_id": transaction_id,
            },
        )
        return summary

    async def _recover_existing_apple_transaction_delivery(
        self,
        *,
        user_id: str,
        existing_transaction: PaymentTransaction,
        transaction: AppleTransactionInfo,
        locale: str | None = None,
    ) -> MembershipSummaryPayload:
        if existing_transaction.user_id != user_id:
            raise AppHTTPException(
                status_code=409,
                detail="Apple transaction is already linked to another account",
                error_code=MEMBERSHIP_ERROR_CODE_APPLE_SUBSCRIPTION_LINKED,
            )

        now = _current_utc()
        if transaction.expiration_date is not None and ensure_utc(
            transaction.expiration_date
        ) <= now:
            return await self.build_summary(user_id, locale=locale)

        async with transaction_scope() as session:
            summary = await self.build_summary(
                user_id,
                locale=locale,
                session=session,
            )
            if (
                summary.tier_code == PRO_TIER_CODE
                and summary.access_state == constants.MEMBERSHIP_ACCESS_ACTIVE
            ):
                return summary
            await session.flush()

            product = None
            if existing_transaction.internal_product_code:
                product = await self.product_dao.get_product(
                    existing_transaction.internal_product_code,
                    session=session,
                )
            channel = await self.channel_dao.get_by_provider_product(
                constants.PAYMENT_PROVIDER_APPLE,
                transaction.product_id,
                session=session,
            )
            if product is None and channel is not None:
                product = await self.product_dao.get_product(
                    channel.internal_product_code,
                    session=session,
                )
            if product is None:
                raise AppHTTPException(
                    status_code=422,
                    detail="Membership product mapping not found",
                )

            provider_subscription_id = existing_transaction.external_subscription_id
            if product.renewal_type == RENEWAL_RECURRING:
                provider_subscription_id = provider_subscription_id or (
                    transaction.original_transaction_id or transaction.transaction_id
                )

            period = await self.apply_confirmed_purchase(
                user_id=user_id,
                product=product,
                provider=constants.PAYMENT_PROVIDER_APPLE,
                confirmed_at=transaction.purchase_date
                or existing_transaction.occurred_at.replace(tzinfo=UTC),
                order_no=existing_transaction.order_no,
                external_subscription_id=provider_subscription_id,
                explicit_period_end=transaction.expiration_date,
                session=session,
            )

            subscription = None
            if product.renewal_type == RENEWAL_RECURRING and provider_subscription_id:
                subscription = await self.subscription_dao.get_by_provider_subscription(
                    constants.PAYMENT_PROVIDER_APPLE,
                    provider_subscription_id,
                    session=session,
                )
                if subscription is not None:
                    subscription.status = constants.MEMBERSHIP_STATUS_ACTIVE
                    subscription.cancel_at_period_end = False
                    subscription.current_period_start_at = period.started_at
                    subscription.current_period_end_at = period.paid_through_at
                    subscription.last_confirmed_at = to_storage_utc(
                        transaction.purchase_date or _current_utc()
                    )
                    subscription.extra_data = {
                        **dict(subscription.extra_data or {}),
                        "latest_transaction_id": transaction.transaction_id,
                        "provider_product_id": transaction.product_id,
                        "environment": transaction.environment,
                    }
                    await self.subscription_dao.save(subscription, session=session)

            if existing_transaction.order_no:
                order = await self.order_dao.get_order(
                    existing_transaction.order_no,
                    session=session,
                )
                if order is not None and order.user_id == user_id:
                    order.status = constants.PAYMENT_ORDER_STATUS_PAID
                    order.provider_order_id = transaction.transaction_id
                    order.subscription_id = (
                        subscription.subscription_id
                        if subscription is not None
                        else order.subscription_id
                    )
                    order.confirmed_at = to_storage_utc(
                        transaction.purchase_date or _current_utc()
                    )
                    order.raw_payload = {
                        **dict(order.raw_payload or {}),
                        "verified_transaction": dict(transaction.raw_claims),
                    }
                    await self.order_dao.save(order, session=session)

            summary = await self.build_summary(
                user_id,
                locale=locale,
                session=session,
            )

        await self.invalidate_entitlement_snapshot(user_id)
        return summary

    async def apply_apple_server_notification(
        self,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        signed_payload = _normalize_optional(payload.get("signed_payload") or payload.get("signedPayload"))
        if signed_payload is None:
            raise AppHTTPException(status_code=422, detail="signed_payload is required")
        notification = self.apple_verifier.decode_notification(signed_payload)
        if notification.signed_transaction_info is None:
            return {
                "provider": constants.PAYMENT_PROVIDER_APPLE,
                "event_type": notification.notification_type,
                "status": constants.PAYMENT_NOTIFICATION_STATUS_RECEIVED,
                "ignored": True,
                "reason": "missing signedTransactionInfo",
            }
        transaction = self.apple_verifier.decode_transaction(
            notification.signed_transaction_info
        )
        user_id = await self._resolve_apple_transaction_user_id(transaction)
        if user_id is None:
            return {
                "provider": constants.PAYMENT_PROVIDER_APPLE,
                "event_type": notification.notification_type,
                "status": constants.PAYMENT_NOTIFICATION_STATUS_RECEIVED,
                "ignored": True,
                "reason": "user_not_resolved",
                "transaction_id": transaction.transaction_id,
            }

        event_type = notification.notification_type.upper()
        if event_type in {"SUBSCRIBED", "DID_RENEW", "OFFER_REDEEMED"}:
            return await self._apply_apple_purchase_event(
                user_id=user_id,
                transaction=transaction,
                notification_payload=notification.raw_claims,
                event_type=(
                    constants.PAYMENT_EVENT_TYPE_RENEWAL
                    if event_type == "DID_RENEW"
                    else constants.PAYMENT_TRANSACTION_TYPE_PURCHASE
                ),
            )
        if event_type == "DID_FAIL_TO_RENEW":
            summary = await self.mark_subscription_payment_failed(
                provider=constants.PAYMENT_PROVIDER_APPLE,
                user_id=user_id,
                external_subscription_id=(
                    transaction.original_transaction_id or transaction.transaction_id
                ),
                occurred_at=_current_utc(),
                payload=notification.raw_claims,
            )
            return self._apple_notification_response(notification, summary)
        if event_type in {"EXPIRED", "REFUND", "REVOKE"}:
            status = (
                constants.MEMBERSHIP_STATUS_REVOKED
                if event_type in {"REFUND", "REVOKE"}
                else constants.MEMBERSHIP_STATUS_EXPIRED
            )
            summary = await self.mark_subscription_ended(
                provider=constants.PAYMENT_PROVIDER_APPLE,
                user_id=user_id,
                external_subscription_id=(
                    transaction.original_transaction_id or transaction.transaction_id
                ),
                status=status,
                occurred_at=_current_utc(),
                payload=notification.raw_claims,
            )
            return self._apple_notification_response(notification, summary)
        if event_type in {"DID_CHANGE_RENEWAL_STATUS", "DID_CHANGE_RENEWAL_PREF"}:
            summary = await self.cancel_provider_subscription_by_external_id(
                provider=constants.PAYMENT_PROVIDER_APPLE,
                user_id=user_id,
                external_subscription_id=(
                    transaction.original_transaction_id or transaction.transaction_id
                ),
            )
            return self._apple_notification_response(notification, summary)

        summary = await self.build_summary(user_id)
        return self._apple_notification_response(notification, summary)

    async def reconcile_apple_transaction(
        self,
        transaction_id: str,
        *,
        environment: str | None = None,
    ) -> MembershipSummaryPayload:
        payload = await AppleAppStoreServerClient().get_transaction_info(
            transaction_id,
            environment=environment,
        )
        signed_transaction_info = _normalize_optional(payload.get("signedTransactionInfo"))
        if signed_transaction_info is None:
            raise AppHTTPException(
                status_code=502,
                detail="Apple transaction info missing signedTransactionInfo",
            )
        transaction = self.apple_verifier.decode_transaction(signed_transaction_info)
        user_id = await self._resolve_apple_transaction_user_id(transaction)
        if user_id is None:
            raise AppHTTPException(
                status_code=404,
                detail="Apple transaction user not resolved",
            )
        result = await self._apply_apple_purchase_event(
            user_id=user_id,
            transaction=transaction,
            notification_payload=payload,
            event_type=constants.PAYMENT_EVENT_TYPE_RENEWAL,
        )
        summary = result.get("summary")
        if isinstance(summary, dict):
            return MembershipSummaryPayload(**summary)
        return await self.build_summary(user_id)

    async def _apply_apple_purchase_event(
        self,
        *,
        user_id: str,
        transaction: AppleTransactionInfo,
        notification_payload: dict[str, Any],
        event_type: str,
    ) -> dict[str, Any]:
        existing_transaction = await self.transaction_dao.get_by_provider_external_transaction(
            constants.PAYMENT_PROVIDER_APPLE,
            transaction.transaction_id,
        )
        if existing_transaction is not None:
            summary = await self._recover_existing_apple_transaction_delivery(
                user_id=user_id,
                existing_transaction=existing_transaction,
                transaction=transaction,
            )
            return {
                "provider": constants.PAYMENT_PROVIDER_APPLE,
                "event_type": event_type,
                "status": constants.PAYMENT_NOTIFICATION_STATUS_RECEIVED,
                "summary": summary.model_dump(),
            }

        async with transaction_scope() as session:
            channel = await self.channel_dao.get_by_provider_product(
                constants.PAYMENT_PROVIDER_APPLE,
                transaction.product_id,
                session=session,
            )
            if channel is None:
                raise AppHTTPException(status_code=422, detail="Apple product mapping not found")
            product = await self.product_dao.get_product(
                channel.internal_product_code,
                session=session,
            )
            if product is None:
                raise AppHTTPException(status_code=422, detail="Membership product mapping not found")

            provider_subscription_id = (
                transaction.original_transaction_id or transaction.transaction_id
            ) if product.renewal_type == RENEWAL_RECURRING else transaction.original_transaction_id
            pending_transaction = PaymentTransaction(
                transaction_id=_uuid_pk("txn"),
                order_no=None,
                user_id=user_id,
                internal_product_code=product.internal_product_code,
                provider=constants.PAYMENT_PROVIDER_APPLE,
                external_transaction_id=transaction.transaction_id,
                external_subscription_id=provider_subscription_id,
                transaction_type=event_type,
                status=constants.PAYMENT_TRANSACTION_STATUS_SUCCEEDED,
                occurred_at=to_storage_utc(transaction.purchase_date or _current_utc())
                or utc_now_naive(),
                raw_payload={
                    "notification": dict(notification_payload),
                    "verified_transaction": dict(transaction.raw_claims),
                },
            )
            await self.transaction_dao.insert(pending_transaction, session=session)
            await session.flush()

            period = await self.apply_confirmed_purchase(
                user_id=user_id,
                product=product,
                provider=constants.PAYMENT_PROVIDER_APPLE,
                confirmed_at=transaction.purchase_date or _current_utc(),
                order_no=None,
                external_subscription_id=provider_subscription_id,
                explicit_period_end=transaction.expiration_date,
                session=session,
            )
            if product.renewal_type == RENEWAL_RECURRING and provider_subscription_id:
                subscription = await self.subscription_dao.get_by_provider_subscription(
                    constants.PAYMENT_PROVIDER_APPLE,
                    provider_subscription_id,
                    session=session,
                )
                if subscription is not None:
                    subscription.status = constants.MEMBERSHIP_STATUS_ACTIVE
                    subscription.cancel_at_period_end = False
                    subscription.current_period_start_at = period.started_at
                    subscription.current_period_end_at = period.paid_through_at
                    subscription.last_confirmed_at = to_storage_utc(
                        transaction.purchase_date or _current_utc()
                    )
                    subscription.extra_data = {
                        **dict(subscription.extra_data or {}),
                        "latest_transaction_id": transaction.transaction_id,
                        "provider_product_id": channel.provider_product_id,
                        "environment": transaction.environment,
                    }
                    await self.subscription_dao.save(subscription, session=session)
            summary = await self.build_summary(user_id, session=session)
        await self.invalidate_entitlement_snapshot(user_id)
        return {
            "provider": constants.PAYMENT_PROVIDER_APPLE,
            "event_type": event_type,
            "status": constants.PAYMENT_NOTIFICATION_STATUS_RECEIVED,
            "summary": summary.model_dump(),
        }

    async def _resolve_apple_transaction_user_id(
        self,
        transaction: AppleTransactionInfo,
    ) -> str | None:
        if transaction.original_transaction_id:
            subscription = await self.subscription_dao.get_by_provider_subscription(
                constants.PAYMENT_PROVIDER_APPLE,
                transaction.original_transaction_id,
            )
            if subscription is not None:
                return subscription.user_id
        existing = await self.transaction_dao.get_by_provider_external_transaction(
            constants.PAYMENT_PROVIDER_APPLE,
            transaction.transaction_id,
        )
        if existing is not None:
            return existing.user_id
        if transaction.app_account_token:
            order = await self.order_dao.get_by_app_account_token(
                transaction.app_account_token,
            )
            if order is not None:
                return order.user_id
        return None

    @staticmethod
    def _apple_notification_response(
        notification,
        summary: MembershipSummaryPayload,
    ) -> dict[str, Any]:
        return {
            "provider": constants.PAYMENT_PROVIDER_APPLE,
            "event_type": notification.notification_type,
            "subtype": notification.subtype,
            "notification_uuid": notification.notification_uuid,
            "status": constants.PAYMENT_NOTIFICATION_STATUS_RECEIVED,
            "summary": summary.model_dump(),
        }

    async def apply_provider_notification(
        self,
        provider: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        event = self._normalize_provider_event(provider, payload)
        if event.user_id.strip() == "":
            raise AppHTTPException(status_code=422, detail="provider notification user_id is required")
        if event.external_transaction_id:
            existing_transaction = await self.transaction_dao.get_by_provider_external_transaction(
                provider,
                event.external_transaction_id,
            )
            if existing_transaction is not None:
                summary = await self.build_summary(event.user_id)
                return {
                    "provider": provider,
                    "event_type": event.event_type,
                    "status": constants.PAYMENT_NOTIFICATION_STATUS_RECEIVED,
                    "summary": summary.model_dump(),
                }

        try:
            async with transaction_scope() as session:
                if event.event_type in {
                    constants.PAYMENT_TRANSACTION_TYPE_PURCHASE,
                    constants.PAYMENT_EVENT_TYPE_RENEWAL,
                }:
                    if not event.internal_product_code:
                        if not event.provider_product_id:
                            raise AppHTTPException(
                                status_code=422,
                                detail="provider notification missing product mapping",
                            )
                        channel = await self.channel_dao.get_by_provider_product(
                            provider,
                            event.provider_product_id,
                            session=session,
                        )
                        if channel is None:
                            raise AppHTTPException(status_code=422, detail="provider notification channel not found")
                        event.internal_product_code = channel.internal_product_code
                    product = await self.product_dao.get_product(
                        event.internal_product_code,
                        session=session,
                    )
                    if product is None:
                        raise AppHTTPException(status_code=422, detail="provider notification product not found")
                else:
                    product = None

                if event.external_transaction_id:
                    pending_transaction = PaymentTransaction(
                        transaction_id=_uuid_pk("txn"),
                        order_no=event.order_no,
                        user_id=event.user_id,
                        internal_product_code=event.internal_product_code,
                        provider=provider,
                        external_transaction_id=event.external_transaction_id,
                        external_subscription_id=event.external_subscription_id,
                        transaction_type=event.event_type,
                        status=event.status,
                        occurred_at=to_storage_utc(event.occurred_at or _current_utc())
                        or utc_now_naive(),
                        raw_payload=dict(event.payload),
                    )
                    await self.transaction_dao.insert(pending_transaction, session=session)
                    await session.flush()

                if event.event_type in {
                    constants.PAYMENT_TRANSACTION_TYPE_PURCHASE,
                    constants.PAYMENT_EVENT_TYPE_RENEWAL,
                }:
                    assert product is not None
                    period = await self.apply_confirmed_purchase(
                        user_id=event.user_id,
                        product=product,
                        provider=provider,
                        confirmed_at=event.occurred_at or _current_utc(),
                        order_no=event.order_no,
                        external_subscription_id=event.external_subscription_id,
                        explicit_period_end=event.expiration_at,
                        session=session,
                    )
                    if product.renewal_type == RENEWAL_RECURRING and event.external_subscription_id:
                        subscription = await self.subscription_dao.get_by_provider_subscription(
                            provider,
                            event.external_subscription_id,
                            session=session,
                        )
                        if subscription is None:
                            subscription = MembershipSubscription(
                                subscription_id=_uuid_pk("sub"),
                                user_id=event.user_id,
                                internal_product_code=product.internal_product_code,
                                provider=provider,
                                provider_subscription_id=event.external_subscription_id,
                                status=constants.MEMBERSHIP_STATUS_ACTIVE,
                                cancel_at_period_end=event.cancel_at_period_end,
                                started_at=period.started_at,
                                current_period_start_at=period.started_at,
                                current_period_end_at=period.paid_through_at,
                                last_confirmed_at=to_storage_utc(event.occurred_at or _current_utc()),
                                extra_data=dict(event.payload),
                            )
                        else:
                            subscription.status = (
                                constants.MEMBERSHIP_STATUS_CANCEL_SCHEDULED
                                if event.cancel_at_period_end
                                else constants.MEMBERSHIP_STATUS_ACTIVE
                            )
                            subscription.cancel_at_period_end = event.cancel_at_period_end
                            subscription.current_period_start_at = period.started_at
                            subscription.current_period_end_at = period.paid_through_at
                            subscription.last_confirmed_at = to_storage_utc(event.occurred_at or _current_utc())
                            subscription.extra_data = dict(event.payload)
                        await self.subscription_dao.save(subscription, session=session)
                    summary = await self.build_summary(event.user_id, session=session)
                elif event.event_type == "payment_failed":
                    summary = await self.mark_subscription_payment_failed(
                        provider=provider,
                        user_id=event.user_id,
                        external_subscription_id=event.external_subscription_id,
                        occurred_at=event.occurred_at or _current_utc(),
                        payload=event.payload,
                        session=session,
                    )
                elif event.event_type == "cancel_scheduled":
                    summary = await self.cancel_provider_subscription_by_external_id(
                        provider=provider,
                        user_id=event.user_id,
                        external_subscription_id=event.external_subscription_id,
                        session=session,
                    )
                else:
                    summary = await self.build_summary(event.user_id, session=session)
        except IntegrityError as exc:
            detail = str(exc)
            if event.external_transaction_id and (
                "external_transaction_id" in detail
                or "ux_payment_transactions_provider_external" in detail
            ):
                summary = await self.build_summary(event.user_id)
                return {
                    "provider": provider,
                    "event_type": event.event_type,
                    "status": constants.PAYMENT_NOTIFICATION_STATUS_RECEIVED,
                    "summary": summary.model_dump(),
                }
            raise

        await self.invalidate_entitlement_snapshot(event.user_id)
        self.analytics.emit(
            "provider_callback_result",
            user_id=event.user_id,
            payload={
                "provider": provider,
                "event_type": event.event_type,
                "status": event.status,
            },
        )
        return {
            "provider": provider,
            "event_type": event.event_type,
            "status": constants.PAYMENT_NOTIFICATION_STATUS_RECEIVED,
            "summary": summary.model_dump(),
        }

    async def cancel_provider_subscription(
        self,
        provider: str | None,
        user_id: str,
        subscription_id: str,
    ) -> dict[str, Any]:
        subscription = await self.subscription_dao.get_subscription(subscription_id)
        if subscription is None or subscription.user_id != user_id:
            raise AppHTTPException(status_code=404, detail="Subscription not found")
        resolved_provider = _normalize_optional(provider) or subscription.provider
        if resolved_provider == constants.PAYMENT_PROVIDER_APPLE:
            raise AppHTTPException(status_code=422, detail="Apple subscriptions must be managed in system settings")
        subscription.cancel_at_period_end = True
        subscription.status = constants.MEMBERSHIP_STATUS_CANCEL_SCHEDULED
        await self.subscription_dao.save(subscription)
        await self.refresh_membership_state(user_id)
        await self.invalidate_entitlement_snapshot(user_id)
        self.analytics.emit(
            "subscription_status_changed",
            user_id=user_id,
            payload={
                "provider": resolved_provider,
                "subscription_id": subscription.subscription_id,
                "status": subscription.status,
            },
        )
        return {
            "subscription_id": subscription.subscription_id,
            "cancel_at_period_end": True,
            "provider": resolved_provider,
            "status": subscription.status,
        }

    async def cancel_provider_subscription_by_external_id(
        self,
        *,
        provider: str,
        user_id: str,
        external_subscription_id: str | None,
        session: AsyncSession | None = None,
    ) -> MembershipSummaryPayload:
        normalized = _normalize_optional(external_subscription_id)
        if normalized is None:
            return await self.build_summary(user_id, session=session)
        subscription = await self.subscription_dao.get_by_provider_subscription(
            provider,
            normalized,
            session=session,
        )
        if subscription is None:
            return await self.build_summary(user_id, session=session)
        subscription.cancel_at_period_end = True
        subscription.status = constants.MEMBERSHIP_STATUS_CANCEL_SCHEDULED
        await self.subscription_dao.save(subscription, session=session)
        summary = await self.build_summary(user_id, session=session)
        await self.invalidate_entitlement_snapshot(user_id)
        return summary

    async def mark_subscription_payment_failed(
        self,
        *,
        provider: str,
        user_id: str,
        external_subscription_id: str | None,
        occurred_at: datetime,
        payload: dict[str, Any],
        session: AsyncSession | None = None,
    ) -> MembershipSummaryPayload:
        normalized = _normalize_optional(external_subscription_id)
        if normalized is None:
            return await self.build_summary(user_id, session=session)
        subscription = await self.subscription_dao.get_by_provider_subscription(
            provider,
            normalized,
            session=session,
        )
        if subscription is None:
            return await self.build_summary(user_id, session=session)
        subscription.status = constants.MEMBERSHIP_STATUS_PAYMENT_FAILED
        subscription.ended_at = to_storage_utc(occurred_at)
        subscription.extra_data = {
            **dict(subscription.extra_data or {}),
            "payment_failed_payload": dict(payload),
        }
        await self.subscription_dao.save(subscription, session=session)
        summary = await self.build_summary(user_id, session=session)
        await self.invalidate_entitlement_snapshot(user_id)
        return summary

    async def mark_subscription_ended(
        self,
        *,
        provider: str,
        user_id: str,
        external_subscription_id: str | None,
        status: str,
        occurred_at: datetime,
        payload: dict[str, Any],
        session: AsyncSession | None = None,
    ) -> MembershipSummaryPayload:
        normalized = _normalize_optional(external_subscription_id)
        if normalized is None:
            return await self.build_summary(user_id, session=session)
        subscription = await self.subscription_dao.get_by_provider_subscription(
            provider,
            normalized,
            session=session,
        )
        if subscription is None:
            return await self.build_summary(user_id, session=session)
        subscription.status = status
        subscription.cancel_at_period_end = False
        subscription.ended_at = to_storage_utc(occurred_at)
        subscription.extra_data = {
            **dict(subscription.extra_data or {}),
            "ended_payload": dict(payload),
            "ended_status": status,
        }
        await self.subscription_dao.save(subscription, session=session)
        periods = await self.period_dao.list_by_subscription_id(
            subscription.subscription_id,
            session=session,
        )
        for period in periods:
            period.status = status
            period.extra_data = {
                **dict(period.extra_data or {}),
                "ended_status": status,
            }
            await self.period_dao.save(period, session=session)
        summary = await self.build_summary(user_id, session=session)
        await self.invalidate_entitlement_snapshot(user_id)
        return summary

    async def apply_confirmed_purchase(
        self,
        *,
        user_id: str,
        product: MembershipProduct,
        provider: str,
        confirmed_at: datetime,
        order_no: str | None = None,
        external_subscription_id: str | None = None,
        explicit_period_end: datetime | None = None,
        session: AsyncSession | None = None,
    ) -> MembershipPeriod:
        window = await self.resolve_membership_period_window(
            user_id=user_id,
            duration_months=product.duration_months,
            confirmed_at=confirmed_at,
            explicit_period_end=explicit_period_end,
            session=session,
        )
        source_subscription_id = None
        if product.renewal_type == RENEWAL_RECURRING and external_subscription_id:
            source_subscription_id = await self._resolve_or_create_subscription_id(
                user_id=user_id,
                provider=provider,
                internal_product_code=product.internal_product_code,
                external_subscription_id=external_subscription_id,
                started_at=window.started_at,
                paid_through_at=window.paid_through_at,
                session=session,
            )

        period = MembershipPeriod(
            period_id=_uuid_pk("mpr"),
            user_id=user_id,
            tier_code=product.tier_code,
            internal_product_code=product.internal_product_code,
            renewal_type=product.renewal_type,
            provider=provider,
            source_order_no=order_no,
            source_subscription_id=source_subscription_id,
            started_at=to_storage_utc(window.started_at) or utc_now_naive(),
            paid_through_at=to_storage_utc(window.paid_through_at) or utc_now_naive(),
            status=constants.MEMBERSHIP_STATUS_ACTIVE,
            entitlements=list(product.entitlements or []),
            extra_data={
                "daily_chat_limit": product.daily_chat_limit,
                "external_subscription_id": external_subscription_id,
            },
        )
        await self.period_dao.save(period, session=session)
        if session is not None:
            await session.flush()

        await self.refresh_membership_state(user_id, session=session)
        await self.invalidate_entitlement_snapshot(user_id)
        return period

    async def resolve_membership_period_window(
        self,
        *,
        user_id: str,
        duration_months: int,
        confirmed_at: datetime,
        explicit_period_end: datetime | None = None,
        session: AsyncSession | None = None,
    ) -> MembershipPeriodWindow:
        confirmed_utc = ensure_utc(confirmed_at)
        latest_state = await self.refresh_membership_state(
            user_id,
            session=session,
        )
        current_paid_through = (
            latest_state.paid_through_at.replace(tzinfo=UTC)
            if latest_state.paid_through_at is not None
            else None
        )
        if current_paid_through is not None and current_paid_through > confirmed_utc:
            started_at = current_paid_through
        else:
            started_at = confirmed_utc
        paid_through_at = explicit_period_end or add_months(started_at, duration_months)
        return MembershipPeriodWindow(started_at=started_at, paid_through_at=paid_through_at)

    async def ensure_entitlement(
        self,
        user_id: str,
        entitlement_code: str,
    ) -> MembershipSummaryPayload:
        summary = await self.build_summary(user_id)
        if entitlement_code in summary.entitlements:
            return summary
        self.analytics.emit(
            "feature_gate_hit",
            user_id=user_id,
            payload={"entitlement_code": entitlement_code},
        )
        raise AppHTTPException(
            status_code=403,
            detail="Membership entitlement required",
            error_code=MEMBERSHIP_ERROR_CODE_ENTITLEMENT_REQUIRED,
            error_detail={
                "entitlement_code": entitlement_code,
                "summary": summary.model_dump(),
            },
        )

    async def ensure_feature(
        self,
        user_id: str,
        feature_code: str,
    ) -> None:
        snapshot = await self.entitlement_snapshot_for_user(user_id)
        if feature_code in snapshot.feature_entitlements:
            return
        summary = await self.build_summary(user_id)
        self.analytics.emit(
            "feature_gate_hit",
            user_id=user_id,
            payload={"feature_code": feature_code},
        )
        raise AppHTTPException(
            status_code=403,
            detail="Membership feature required",
            error_code=MEMBERSHIP_ERROR_CODE_ENTITLEMENT_REQUIRED,
            error_detail={
                "feature_code": feature_code,
                "summary": summary.model_dump(),
            },
        )

    async def can_use_feature(
        self,
        user_id: str,
        feature_code: str,
    ) -> bool:
        snapshot = await self.entitlement_snapshot_for_user(user_id)
        return feature_code in snapshot.feature_entitlements

    async def _resolve_or_create_subscription_id(
        self,
        *,
        user_id: str,
        provider: str,
        internal_product_code: str,
        external_subscription_id: str,
        started_at: datetime,
        paid_through_at: datetime,
        session: AsyncSession | None = None,
    ) -> str:
        existing = await self.subscription_dao.get_by_provider_subscription(
            provider,
            external_subscription_id,
            session=session,
        )
        if existing is not None:
            if existing.user_id != user_id:
                raise AppHTTPException(
                    status_code=409,
                    detail="Apple subscription is already linked to another account",
                    error_code=(
                        MEMBERSHIP_ERROR_CODE_APPLE_SUBSCRIPTION_LINKED
                        if provider == constants.PAYMENT_PROVIDER_APPLE
                        else "subscription_linked_to_another_account"
                    ),
                )
            return existing.subscription_id
        subscription = MembershipSubscription(
            subscription_id=_uuid_pk("sub"),
            user_id=user_id,
            internal_product_code=internal_product_code,
            provider=provider,
            provider_subscription_id=external_subscription_id,
            status=constants.MEMBERSHIP_STATUS_ACTIVE,
            cancel_at_period_end=False,
            started_at=to_storage_utc(started_at) or utc_now_naive(),
            current_period_start_at=to_storage_utc(started_at) or utc_now_naive(),
            current_period_end_at=to_storage_utc(paid_through_at) or utc_now_naive(),
            last_confirmed_at=utc_now_naive(),
            extra_data={},
        )
        await self.subscription_dao.save(subscription, session=session)
        return subscription.subscription_id

    def _normalize_provider_event(
        self,
        provider: str,
        payload: dict[str, Any],
    ) -> MembershipProviderEvent:
        data = dict(payload or {})
        occurred_at = _parse_optional_datetime(
            data.get("occurred_at")
            or data.get("confirmed_at")
            or data.get("purchase_date")
        ) or _current_utc()
        expiration_at = _parse_optional_datetime(
            data.get("expiration_at") or data.get("expiration_date")
        )
        event_type = _normalize_optional(data.get("event_type")) or constants.PAYMENT_TRANSACTION_TYPE_PURCHASE
        status = _normalize_optional(data.get("status")) or constants.PAYMENT_TRANSACTION_STATUS_SUCCEEDED
        return MembershipProviderEvent(
            provider=provider,
            user_id=f"{data.get('user_id') or ''}",
            internal_product_code=_normalize_optional(data.get("internal_product_code")),
            provider_product_id=_normalize_optional(data.get("provider_product_id")),
            external_transaction_id=_normalize_optional(
                data.get("external_transaction_id")
                or data.get("transaction_id")
                or data.get("trade_no")
            ),
            external_subscription_id=_normalize_optional(
                data.get("external_subscription_id")
                or data.get("provider_subscription_id")
                or data.get("agreement_no")
                or data.get("plan_id")
            ),
            order_no=_normalize_optional(data.get("order_no") or data.get("out_trade_no")),
            event_type=event_type,
            status=status,
            occurred_at=occurred_at,
            expiration_at=expiration_at,
            cancel_at_period_end=bool(data.get("cancel_at_period_end", False)),
            payload=data,
        )
