from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from config import constants
from models.base import Base, BaseDao, get_local_now
from sqlalchemy import JSON, Boolean, Index, Integer, String, Text, UniqueConstraint, desc, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column


class MembershipProduct(Base):
    __tablename__ = "membership_products"
    __table_args__ = (
        Index("ix_membership_products_tier_sort", "tier_code", "sort_order"),
    )

    internal_product_code: Mapped[str] = mapped_column(String(128), primary_key=True)
    tier_code: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    period_code: Mapped[str] = mapped_column(String(32), nullable=False)
    renewal_type: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    duration_months: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    display_name: Mapped[str] = mapped_column(String(255), nullable=False)
    display_subtitle: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    marketing_label: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    daily_chat_limit: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    entitlements: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=[])
    metadata_json: Mapped[dict[str, Any]] = mapped_column(
        "metadata",
        JSON,
        nullable=False,
        default={},
    )
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        internal_product_code: str,
        tier_code: str,
        period_code: str,
        renewal_type: str,
        duration_months: int,
        display_name: str,
        display_subtitle: Optional[str] = None,
        marketing_label: Optional[str] = None,
        daily_chat_limit: Optional[int] = None,
        entitlements: Optional[list[str]] = None,
        metadata: Optional[dict[str, Any]] = None,
        sort_order: int = 0,
        is_active: bool = True,
    ) -> None:
        now = get_local_now()
        self.internal_product_code = internal_product_code
        self.tier_code = tier_code
        self.period_code = period_code
        self.renewal_type = renewal_type
        self.duration_months = duration_months
        self.display_name = display_name
        self.display_subtitle = display_subtitle
        self.marketing_label = marketing_label
        self.daily_chat_limit = daily_chat_limit
        self.entitlements = entitlements or []
        self.metadata_json = metadata or {}
        self.sort_order = sort_order
        self.is_active = is_active
        self.created_at = now
        self.updated_at = now


class MembershipProductChannel(Base):
    __tablename__ = "membership_product_channels"
    __table_args__ = (
        UniqueConstraint(
            "provider",
            "provider_product_id",
            name="ux_membership_product_channels_provider_product",
        ),
        Index(
            "ix_membership_product_channels_internal_provider",
            "internal_product_code",
            "provider",
        ),
    )

    channel_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    internal_product_code: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    provider: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    platform: Mapped[str] = mapped_column(
        String(32), nullable=False, default=constants.PLATFORM_ALL
    )
    provider_product_id: Mapped[str] = mapped_column(String(255), nullable=False)
    currency_code: Mapped[str] = mapped_column(
        String(16), nullable=False, default=constants.DEFAULT_CURRENCY_CODE
    )
    amount_minor: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    marketing_label: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    metadata_json: Mapped[dict[str, Any]] = mapped_column(
        "metadata",
        JSON,
        nullable=False,
        default={},
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        channel_id: str,
        internal_product_code: str,
        provider: str,
        platform: str,
        provider_product_id: str,
        currency_code: str = "CNY",
        amount_minor: int = 0,
        marketing_label: Optional[str] = None,
        metadata: Optional[dict[str, Any]] = None,
        is_active: bool = True,
    ) -> None:
        now = get_local_now()
        self.channel_id = channel_id
        self.internal_product_code = internal_product_code
        self.provider = provider
        self.platform = platform
        self.provider_product_id = provider_product_id
        self.currency_code = currency_code
        self.amount_minor = amount_minor
        self.marketing_label = marketing_label
        self.metadata_json = metadata or {}
        self.is_active = is_active
        self.created_at = now
        self.updated_at = now


class PaymentOrder(Base):
    __tablename__ = "payment_orders"
    __table_args__ = (
        Index("ix_payment_orders_user_status", "user_id", "status"),
    )

    order_no: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    internal_product_code: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    provider: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    platform: Mapped[str] = mapped_column(
        String(32), nullable=False, default=constants.PLATFORM_UNKNOWN
    )
    renewal_type: Mapped[str] = mapped_column(String(32), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default=constants.MEMBERSHIP_STATUS_PENDING)
    currency_code: Mapped[str] = mapped_column(
        String(16), nullable=False, default=constants.DEFAULT_CURRENCY_CODE
    )
    amount_minor: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    provider_order_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    provider_reference: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    subscription_id: Mapped[Optional[str]] = mapped_column(String(128), nullable=True, index=True)
    checkout_payload: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False, default={})
    raw_payload: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False, default={})
    confirmed_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        order_no: str,
        user_id: str,
        internal_product_code: str,
        provider: str,
        platform: str,
        renewal_type: str,
        status: str = constants.MEMBERSHIP_STATUS_PENDING,
        currency_code: str = "CNY",
        amount_minor: int = 0,
        provider_order_id: Optional[str] = None,
        provider_reference: Optional[str] = None,
        subscription_id: Optional[str] = None,
        checkout_payload: Optional[dict[str, Any]] = None,
        raw_payload: Optional[dict[str, Any]] = None,
        confirmed_at: Optional[datetime] = None,
    ) -> None:
        now = get_local_now()
        self.order_no = order_no
        self.user_id = user_id
        self.internal_product_code = internal_product_code
        self.provider = provider
        self.platform = platform
        self.renewal_type = renewal_type
        self.status = status
        self.currency_code = currency_code
        self.amount_minor = amount_minor
        self.provider_order_id = provider_order_id
        self.provider_reference = provider_reference
        self.subscription_id = subscription_id
        self.checkout_payload = checkout_payload or {}
        self.raw_payload = raw_payload or {}
        self.confirmed_at = confirmed_at
        self.created_at = now
        self.updated_at = now


class PaymentTransaction(Base):
    __tablename__ = "payment_transactions"
    __table_args__ = (
        UniqueConstraint(
            "provider",
            "external_transaction_id",
            name="ux_payment_transactions_provider_external",
        ),
        Index("ix_payment_transactions_user_provider", "user_id", "provider"),
    )

    transaction_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    order_no: Mapped[Optional[str]] = mapped_column(String(128), nullable=True, index=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    internal_product_code: Mapped[Optional[str]] = mapped_column(String(128), nullable=True, index=True)
    provider: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    external_transaction_id: Mapped[str] = mapped_column(String(255), nullable=False)
    external_subscription_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    transaction_type: Mapped[str] = mapped_column(
        String(32), nullable=False, default=constants.PAYMENT_TRANSACTION_TYPE_PURCHASE
    )
    status: Mapped[str] = mapped_column(
        String(32), nullable=False, default=constants.PAYMENT_TRANSACTION_STATUS_SUCCEEDED
    )
    occurred_at: Mapped[datetime] = mapped_column(nullable=False)
    raw_payload: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False, default={})
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        transaction_id: str,
        user_id: str,
        provider: str,
        external_transaction_id: str,
        occurred_at: datetime,
        order_no: Optional[str] = None,
        internal_product_code: Optional[str] = None,
        external_subscription_id: Optional[str] = None,
        transaction_type: str = constants.PAYMENT_TRANSACTION_TYPE_PURCHASE,
        status: str = constants.PAYMENT_TRANSACTION_STATUS_SUCCEEDED,
        raw_payload: Optional[dict[str, Any]] = None,
    ) -> None:
        now = get_local_now()
        self.transaction_id = transaction_id
        self.order_no = order_no
        self.user_id = user_id
        self.internal_product_code = internal_product_code
        self.provider = provider
        self.external_transaction_id = external_transaction_id
        self.external_subscription_id = external_subscription_id
        self.transaction_type = transaction_type
        self.status = status
        self.occurred_at = occurred_at
        self.raw_payload = raw_payload or {}
        self.created_at = now
        self.updated_at = now


class MembershipSubscription(Base):
    __tablename__ = "membership_subscriptions"
    __table_args__ = (
        UniqueConstraint(
            "provider",
            "provider_subscription_id",
            name="ux_membership_subscriptions_provider_external",
        ),
        Index("ix_membership_subscriptions_user_status", "user_id", "status"),
    )

    subscription_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    internal_product_code: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    provider: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    provider_subscription_id: Mapped[str] = mapped_column(String(255), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default=constants.MEMBERSHIP_STATUS_ACTIVE)
    cancel_at_period_end: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    started_at: Mapped[datetime] = mapped_column(nullable=False)
    current_period_start_at: Mapped[datetime] = mapped_column(nullable=False)
    current_period_end_at: Mapped[datetime] = mapped_column(nullable=False)
    last_confirmed_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    ended_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    extra_data: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False, default={})
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        subscription_id: str,
        user_id: str,
        internal_product_code: str,
        provider: str,
        provider_subscription_id: str,
        started_at: datetime,
        current_period_start_at: datetime,
        current_period_end_at: datetime,
        status: str = constants.MEMBERSHIP_STATUS_ACTIVE,
        cancel_at_period_end: bool = False,
        last_confirmed_at: Optional[datetime] = None,
        ended_at: Optional[datetime] = None,
        extra_data: Optional[dict[str, Any]] = None,
    ) -> None:
        now = get_local_now()
        self.subscription_id = subscription_id
        self.user_id = user_id
        self.internal_product_code = internal_product_code
        self.provider = provider
        self.provider_subscription_id = provider_subscription_id
        self.status = status
        self.cancel_at_period_end = cancel_at_period_end
        self.started_at = started_at
        self.current_period_start_at = current_period_start_at
        self.current_period_end_at = current_period_end_at
        self.last_confirmed_at = last_confirmed_at
        self.ended_at = ended_at
        self.extra_data = extra_data or {}
        self.created_at = now
        self.updated_at = now


class MembershipPeriod(Base):
    __tablename__ = "membership_periods"
    __table_args__ = (
        Index("ix_membership_periods_user_paid_through", "user_id", "paid_through_at"),
    )

    period_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    tier_code: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    internal_product_code: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    renewal_type: Mapped[str] = mapped_column(String(32), nullable=False)
    provider: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    source_order_no: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    source_subscription_id: Mapped[Optional[str]] = mapped_column(String(128), nullable=True, index=True)
    started_at: Mapped[datetime] = mapped_column(nullable=False)
    paid_through_at: Mapped[datetime] = mapped_column(nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default=constants.MEMBERSHIP_STATUS_ACTIVE)
    entitlements: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=[])
    extra_data: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False, default={})
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        period_id: str,
        user_id: str,
        tier_code: str,
        internal_product_code: str,
        renewal_type: str,
        provider: str,
        started_at: datetime,
        paid_through_at: datetime,
        source_order_no: Optional[str] = None,
        source_subscription_id: Optional[str] = None,
        status: str = constants.MEMBERSHIP_STATUS_ACTIVE,
        entitlements: Optional[list[str]] = None,
        extra_data: Optional[dict[str, Any]] = None,
    ) -> None:
        now = get_local_now()
        self.period_id = period_id
        self.user_id = user_id
        self.tier_code = tier_code
        self.internal_product_code = internal_product_code
        self.renewal_type = renewal_type
        self.provider = provider
        self.source_order_no = source_order_no
        self.source_subscription_id = source_subscription_id
        self.started_at = started_at
        self.paid_through_at = paid_through_at
        self.status = status
        self.entitlements = entitlements or []
        self.extra_data = extra_data or {}
        self.created_at = now
        self.updated_at = now


class MembershipState(Base):
    __tablename__ = "membership_states"

    user_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    tier_code: Mapped[str] = mapped_column(String(32), nullable=False, default=constants.MEMBERSHIP_TIER_FREE)
    access_state: Mapped[str] = mapped_column(String(32), nullable=False, default=constants.MEMBERSHIP_ACCESS_INACTIVE)
    active_period_id: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    renewal_type: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    provider: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    subscription_id: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    started_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    paid_through_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    cancel_at_period_end: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    entitlements: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=[])
    daily_chat_limit: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    business_timezone: Mapped[str] = mapped_column(String(64), nullable=False, default=constants.DEFAULT_TIMEZONE)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        user_id: str,
        tier_code: str = constants.MEMBERSHIP_TIER_FREE,
        access_state: str = constants.MEMBERSHIP_ACCESS_INACTIVE,
        active_period_id: Optional[str] = None,
        renewal_type: Optional[str] = None,
        provider: Optional[str] = None,
        subscription_id: Optional[str] = None,
        started_at: Optional[datetime] = None,
        paid_through_at: Optional[datetime] = None,
        cancel_at_period_end: bool = False,
        entitlements: Optional[list[str]] = None,
        daily_chat_limit: Optional[int] = None,
        business_timezone: str = constants.DEFAULT_TIMEZONE,
    ) -> None:
        self.user_id = user_id
        self.tier_code = tier_code
        self.access_state = access_state
        self.active_period_id = active_period_id
        self.renewal_type = renewal_type
        self.provider = provider
        self.subscription_id = subscription_id
        self.started_at = started_at
        self.paid_through_at = paid_through_at
        self.cancel_at_period_end = cancel_at_period_end
        self.entitlements = entitlements or []
        self.daily_chat_limit = daily_chat_limit
        self.business_timezone = business_timezone
        self.updated_at = get_local_now()


class MembershipDailyUsage(Base):
    __tablename__ = "membership_daily_usage"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "business_date",
            name="ux_membership_daily_usage_user_day",
        ),
    )

    usage_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    business_date: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    chat_limit: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    chat_used: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    last_consumed_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        usage_id: str,
        user_id: str,
        business_date: str,
        chat_limit: Optional[int] = None,
        chat_used: int = 0,
        last_consumed_at: Optional[datetime] = None,
    ) -> None:
        now = get_local_now()
        self.usage_id = usage_id
        self.user_id = user_id
        self.business_date = business_date
        self.chat_limit = chat_limit
        self.chat_used = chat_used
        self.last_consumed_at = last_consumed_at
        self.created_at = now
        self.updated_at = now


class PointsAccount(Base):
    __tablename__ = "points_accounts"

    account_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, unique=True, index=True)
    balance: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(self, account_id: str, user_id: str, balance: int = 0) -> None:
        now = get_local_now()
        self.account_id = account_id
        self.user_id = user_id
        self.balance = balance
        self.created_at = now
        self.updated_at = now


class PointsLedger(Base):
    __tablename__ = "points_ledger"
    __table_args__ = (
        Index("ix_points_ledger_user_created", "user_id", "created_at"),
    )

    ledger_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    account_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    change_type: Mapped[str] = mapped_column(String(32), nullable=False)
    amount: Mapped[int] = mapped_column(Integer, nullable=False)
    balance_after: Mapped[int] = mapped_column(Integer, nullable=False)
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[dict[str, Any]] = mapped_column(
        "metadata",
        JSON,
        nullable=False,
        default={},
    )
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        ledger_id: str,
        account_id: str,
        user_id: str,
        change_type: str,
        amount: int,
        balance_after: int,
        note: Optional[str] = None,
        metadata: Optional[dict[str, Any]] = None,
    ) -> None:
        now = get_local_now()
        self.ledger_id = ledger_id
        self.account_id = account_id
        self.user_id = user_id
        self.change_type = change_type
        self.amount = amount
        self.balance_after = balance_after
        self.note = note
        self.metadata_json = metadata or {}
        self.created_at = now
        self.updated_at = now


class MembershipProductDao(BaseDao):
    async def get_product(
        self,
        internal_product_code: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[MembershipProduct]:
        return await BaseDao.get_by_id(
            self,
            MembershipProduct,
            internal_product_code,
            session=session,
        )

    async def list_active_products(
        self,
        *,
        session: AsyncSession | None = None,
    ) -> list[MembershipProduct]:
        return await BaseDao.get_list(
            self,
            MembershipProduct,
            where=[MembershipProduct.is_active.is_(True)],
            order_by=MembershipProduct.sort_order.asc(),
            session=session,
        )

    async def count_products(
        self,
        *,
        session: AsyncSession | None = None,
    ) -> int:
        return await BaseDao.count(
            self,
            MembershipProduct,
            session=session,
        )

    async def save(
        self,
        product: MembershipProduct,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        product.updated_at = get_local_now()
        return await BaseDao.save(self, product, session=session)


class MembershipProductChannelDao(BaseDao):
    async def list_active_channels(
        self,
        *,
        session: AsyncSession | None = None,
    ) -> list[MembershipProductChannel]:
        return await BaseDao.get_list(
            self,
            MembershipProductChannel,
            where=[MembershipProductChannel.is_active.is_(True)],
            order_by=MembershipProductChannel.provider_product_id.asc(),
            session=session,
        )

    async def list_channels_for_product(
        self,
        internal_product_code: str,
        *,
        session: AsyncSession | None = None,
    ) -> list[MembershipProductChannel]:
        return await BaseDao.get_list(
            self,
            MembershipProductChannel,
            where=[MembershipProductChannel.internal_product_code == internal_product_code],
            order_by=MembershipProductChannel.provider.asc(),
            session=session,
        )

    async def get_channel(
        self,
        internal_product_code: str,
        provider: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[MembershipProductChannel]:
        return await BaseDao.get_first(
            self,
            MembershipProductChannel,
            where=[
                MembershipProductChannel.internal_product_code == internal_product_code,
                MembershipProductChannel.provider == provider,
            ],
            session=session,
        )

    async def get_by_provider_product(
        self,
        provider: str,
        provider_product_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[MembershipProductChannel]:
        return await BaseDao.get_first(
            self,
            MembershipProductChannel,
            where=[
                MembershipProductChannel.provider == provider,
                MembershipProductChannel.provider_product_id == provider_product_id,
            ],
            session=session,
        )

    async def save(
        self,
        channel: MembershipProductChannel,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        channel.updated_at = get_local_now()
        return await BaseDao.save(self, channel, session=session)


class PaymentOrderDao(BaseDao):
    async def get_order(
        self,
        order_no: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[PaymentOrder]:
        return await BaseDao.get_by_id(
            self,
            PaymentOrder,
            order_no,
            session=session,
        )

    async def list_pending_orders(
        self,
        limit: int = 50,
        *,
        session: AsyncSession | None = None,
    ) -> list[PaymentOrder]:
        return await BaseDao.get_list(
            self,
            PaymentOrder,
            where=[PaymentOrder.status == constants.MEMBERSHIP_STATUS_PENDING],
            order_by=desc(PaymentOrder.created_at),
            limit=limit,
            session=session,
        )

    async def get_by_app_account_token(
        self,
        app_account_token: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[PaymentOrder]:
        return await BaseDao.get_first(
            self,
            PaymentOrder,
            where=[PaymentOrder.provider_reference == app_account_token],
            session=session,
        )

    async def save(
        self,
        order: PaymentOrder,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        order.updated_at = get_local_now()
        return await BaseDao.save(self, order, session=session)


class PaymentTransactionDao(BaseDao):
    async def get_by_provider_external_transaction(
        self,
        provider: str,
        external_transaction_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[PaymentTransaction]:
        return await BaseDao.get_first(
            self,
            PaymentTransaction,
            where=[
                PaymentTransaction.provider == provider,
                PaymentTransaction.external_transaction_id == external_transaction_id,
            ],
            session=session,
        )

    async def save(
        self,
        payment_transaction: PaymentTransaction,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        payment_transaction.updated_at = get_local_now()
        return await BaseDao.save(
            self,
            payment_transaction,
            session=session,
        )


class MembershipSubscriptionDao(BaseDao):
    async def get_subscription(
        self,
        subscription_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[MembershipSubscription]:
        return await BaseDao.get_by_id(
            self,
            MembershipSubscription,
            subscription_id,
            session=session,
        )

    async def get_by_provider_subscription(
        self,
        provider: str,
        provider_subscription_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[MembershipSubscription]:
        return await BaseDao.get_first(
            self,
            MembershipSubscription,
            where=[
                MembershipSubscription.provider == provider,
                MembershipSubscription.provider_subscription_id == provider_subscription_id,
            ],
            session=session,
        )

    async def list_provider_subscriptions(
        self,
        provider: str,
        *,
        statuses: list[str] | None = None,
        limit: int = 50,
        session: AsyncSession | None = None,
    ) -> list[MembershipSubscription]:
        where = [MembershipSubscription.provider == provider]
        if statuses:
            where.append(MembershipSubscription.status.in_(statuses))
        return await BaseDao.get_list(
            self,
            MembershipSubscription,
            where=where,
            order_by=desc(MembershipSubscription.updated_at),
            limit=limit,
            session=session,
        )

    async def save(
        self,
        subscription: MembershipSubscription,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        subscription.updated_at = get_local_now()
        return await BaseDao.save(self, subscription, session=session)


class MembershipPeriodDao(BaseDao):
    async def get_period(
        self,
        period_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[MembershipPeriod]:
        return await BaseDao.get_by_id(
            self,
            MembershipPeriod,
            period_id,
            session=session,
        )

    async def list_user_periods(
        self,
        user_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> list[MembershipPeriod]:
        return await BaseDao.get_list(
            self,
            MembershipPeriod,
            where=[MembershipPeriod.user_id == user_id],
            order_by=desc(MembershipPeriod.paid_through_at),
            session=session,
        )

    async def get_latest_active_period(
        self,
        user_id: str,
        active_after: datetime,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[MembershipPeriod]:
        async with self._session_scope(session=session) as session:
            stmt = (
                select(MembershipPeriod)
                .where(
                    MembershipPeriod.user_id == user_id,
                    MembershipPeriod.status == constants.MEMBERSHIP_STATUS_ACTIVE,
                    MembershipPeriod.paid_through_at > active_after,
                )
                .order_by(
                    MembershipPeriod.paid_through_at.desc(),
                    MembershipPeriod.created_at.desc(),
                )
                .limit(1)
            )
            res = await session.execute(stmt)
            return res.scalars().first()

    async def save(
        self,
        period: MembershipPeriod,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        period.updated_at = get_local_now()
        return await BaseDao.save(self, period, session=session)

    async def list_by_subscription_id(
        self,
        subscription_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> list[MembershipPeriod]:
        return await BaseDao.get_list(
            self,
            MembershipPeriod,
            where=[MembershipPeriod.source_subscription_id == subscription_id],
            order_by=desc(MembershipPeriod.paid_through_at),
            session=session,
        )


class MembershipStateDao(BaseDao):
    async def get_state(
        self,
        user_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[MembershipState]:
        return await BaseDao.get_by_id(
            self,
            MembershipState,
            user_id,
            session=session,
        )

    async def save(
        self,
        state: MembershipState,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        state.updated_at = get_local_now()
        return await BaseDao.save(self, state, session=session)


class MembershipDailyUsageDao(BaseDao):
    async def get_user_business_day_usage(
        self,
        user_id: str,
        business_date: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[MembershipDailyUsage]:
        return await BaseDao.get_first(
            self,
            MembershipDailyUsage,
            where=[
                MembershipDailyUsage.user_id == user_id,
                MembershipDailyUsage.business_date == business_date,
            ],
            session=session,
        )

    async def save(
        self,
        usage: MembershipDailyUsage,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        usage.updated_at = get_local_now()
        return await BaseDao.save(self, usage, session=session)


class PointsAccountDao(BaseDao):
    async def get_by_user_id(
        self,
        user_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[PointsAccount]:
        return await BaseDao.get_first(
            self,
            PointsAccount,
            where=[PointsAccount.user_id == user_id],
            session=session,
        )

    async def save(
        self,
        account: PointsAccount,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        account.updated_at = get_local_now()
        return await BaseDao.save(self, account, session=session)


class PointsLedgerDao(BaseDao):
    async def save(
        self,
        ledger: PointsLedger,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        ledger.updated_at = get_local_now()
        return await BaseDao.save(self, ledger, session=session)
