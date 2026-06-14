from __future__ import annotations

import hashlib
from datetime import datetime
from typing import Any

from config import constants
from core.http.exceptions import AppHTTPException
from core.infra.db import transaction_scope
from models.user import UserDao
from modules.membership.models import (
    MembershipPeriod,
    MembershipSubscription,
    PaymentOrder,
    PaymentTransaction,
)
from modules.membership.service import MembershipService
from sqlalchemy import desc, func, or_, select
from utils.time import utc_now_naive


class AdminMembershipService:
    def __init__(self, membership_service: MembershipService | None = None) -> None:
        self.membership_service = membership_service or MembershipService()
        self.user_dao = UserDao()

    async def list_orders(
        self,
        *,
        page: int,
        page_size: int,
        query: str | None = None,
        provider: str | None = None,
        status: str | None = None,
        user_id: str | None = None,
    ) -> dict[str, Any]:
        async with self.membership_service.order_dao._session_scope() as session:
            stmt = select(PaymentOrder)
            stmt = _apply_common_filters(
                stmt,
                provider=provider,
                status=status,
                user_id=user_id,
                provider_column=PaymentOrder.provider,
                status_column=PaymentOrder.status,
                user_column=PaymentOrder.user_id,
            )
            normalized_query = _normalize_optional(query)
            if normalized_query is not None:
                pattern = f"%{normalized_query}%"
                stmt = stmt.where(
                    or_(
                        PaymentOrder.order_no.like(pattern),
                        PaymentOrder.user_id.like(pattern),
                        PaymentOrder.internal_product_code.like(pattern),
                        PaymentOrder.provider_order_id.like(pattern),
                        PaymentOrder.provider_reference.like(pattern),
                        PaymentOrder.subscription_id.like(pattern),
                    )
                )
            total = await _count(session, stmt)
            rows = list(
                (
                    await session.execute(
                        stmt.order_by(
                            desc(PaymentOrder.created_at),
                            desc(PaymentOrder.updated_at),
                        )
                        .offset((page - 1) * page_size)
                        .limit(page_size)
                    )
                )
                .scalars()
                .all()
            )
        return {
            "items": [_order_payload(row) for row in rows],
            "page": page,
            "page_size": page_size,
            "total": total,
        }

    async def list_subscriptions(
        self,
        *,
        page: int,
        page_size: int,
        query: str | None = None,
        provider: str | None = None,
        status: str | None = None,
        user_id: str | None = None,
    ) -> dict[str, Any]:
        async with self.membership_service.subscription_dao._session_scope() as session:
            stmt = select(MembershipSubscription)
            stmt = _apply_common_filters(
                stmt,
                provider=provider,
                status=status,
                user_id=user_id,
                provider_column=MembershipSubscription.provider,
                status_column=MembershipSubscription.status,
                user_column=MembershipSubscription.user_id,
            )
            normalized_query = _normalize_optional(query)
            if normalized_query is not None:
                pattern = f"%{normalized_query}%"
                stmt = stmt.where(
                    or_(
                        MembershipSubscription.subscription_id.like(pattern),
                        MembershipSubscription.user_id.like(pattern),
                        MembershipSubscription.internal_product_code.like(pattern),
                        MembershipSubscription.provider_subscription_id.like(pattern),
                    )
                )
            total = await _count(session, stmt)
            rows = list(
                (
                    await session.execute(
                        stmt.order_by(
                            desc(MembershipSubscription.updated_at),
                            desc(MembershipSubscription.created_at),
                        )
                        .offset((page - 1) * page_size)
                        .limit(page_size)
                    )
                )
                .scalars()
                .all()
            )
        return {
            "items": [_subscription_payload(row) for row in rows],
            "page": page,
            "page_size": page_size,
            "total": total,
        }

    async def get_subscription_detail(self, subscription_id: str) -> dict[str, Any]:
        subscription = await self.membership_service.subscription_dao.get_subscription(
            subscription_id
        )
        if subscription is None:
            raise AppHTTPException(status_code=404, detail="Subscription not found")
        async with self.membership_service.subscription_dao._session_scope() as session:
            periods = list(
                (
                    await session.execute(
                        select(MembershipPeriod)
                        .where(MembershipPeriod.source_subscription_id == subscription_id)
                        .order_by(desc(MembershipPeriod.paid_through_at))
                    )
                )
                .scalars()
                .all()
            )
            transactions = await self._list_subscription_transactions(
                subscription,
                session=session,
            )
            orders = list(
                (
                    await session.execute(
                        select(PaymentOrder)
                        .where(PaymentOrder.subscription_id == subscription_id)
                        .order_by(desc(PaymentOrder.created_at))
                    )
                )
                .scalars()
                .all()
            )
        return {
            "subscription": _subscription_payload(subscription),
            "periods": [_period_payload(row) for row in periods],
            "transactions": [_transaction_payload(row) for row in transactions],
            "orders": [_order_payload(row) for row in orders],
        }

    async def release_apple_subscription_binding(
        self,
        *,
        subscription_id: str,
        admin: dict[str, Any],
        reason: str,
        expected_provider_subscription_id: str | None = None,
        allow_production: bool = False,
    ) -> dict[str, Any]:
        normalized_reason = _require_reason(reason)
        async with transaction_scope() as session:
            subscription = await self.membership_service.subscription_dao.get_subscription(
                subscription_id,
                session=session,
            )
            if subscription is None:
                raise AppHTTPException(status_code=404, detail="Subscription not found")
            self._ensure_apple_subscription(subscription)
            self._ensure_expected_provider_subscription(
                subscription,
                expected_provider_subscription_id,
            )
            transactions = await self._list_subscription_transactions(
                subscription,
                session=session,
            )
            environment = _resolve_environment(subscription, transactions)
            _ensure_environment_allowed(environment, allow_production=allow_production)

            now = utc_now_naive()
            old_user_id = subscription.user_id
            old_provider_subscription_id = subscription.provider_subscription_id
            archived_provider_subscription_id = _archived_identifier(
                "released_sub",
                subscription.subscription_id,
                old_provider_subscription_id,
            )
            audit = _admin_audit_payload(
                admin=admin,
                action="release_apple_subscription_binding",
                reason=normalized_reason,
                occurred_at=now,
                extra={
                    "old_user_id": old_user_id,
                    "old_provider_subscription_id": old_provider_subscription_id,
                    "archived_provider_subscription_id": archived_provider_subscription_id,
                    "environment": environment,
                },
            )

            subscription.provider_subscription_id = archived_provider_subscription_id
            subscription.status = constants.MEMBERSHIP_STATUS_REVOKED
            subscription.cancel_at_period_end = True
            subscription.ended_at = now
            subscription.extra_data = {
                **dict(subscription.extra_data or {}),
                "admin_release": audit,
            }
            await self.membership_service.subscription_dao.save(
                subscription,
                session=session,
            )

            periods = await self.membership_service.period_dao.list_by_subscription_id(
                subscription.subscription_id,
                session=session,
            )
            for period in periods:
                period.status = constants.MEMBERSHIP_STATUS_REVOKED
                period.extra_data = {
                    **dict(period.extra_data or {}),
                    "admin_release": audit,
                }
                await self.membership_service.period_dao.save(period, session=session)

            for transaction in transactions:
                old_transaction_id = transaction.external_transaction_id
                transaction.external_transaction_id = _archived_identifier(
                    "released_txn",
                    transaction.transaction_id,
                    old_transaction_id,
                )
                transaction.external_subscription_id = archived_provider_subscription_id
                transaction.raw_payload = {
                    **dict(transaction.raw_payload or {}),
                    "admin_release": {
                        **audit,
                        "old_external_transaction_id": old_transaction_id,
                    },
                }
                await self.membership_service.transaction_dao.save(
                    transaction,
                    session=session,
                )

            await self._refresh_user_if_present(old_user_id, session=session)

        return {
            "subscription_id": subscription_id,
            "provider": constants.PAYMENT_PROVIDER_APPLE,
            "action": "released",
            "environment": environment,
            "old_user_id": old_user_id,
            "old_provider_subscription_id": old_provider_subscription_id,
            "archived_provider_subscription_id": archived_provider_subscription_id,
            "periods_revoked": len(periods),
            "transactions_archived": len(transactions),
        }

    async def transfer_apple_subscription_binding(
        self,
        *,
        subscription_id: str,
        target_user_id: str,
        admin: dict[str, Any],
        reason: str,
        expected_provider_subscription_id: str | None = None,
        allow_production: bool = False,
        move_periods: bool = True,
    ) -> dict[str, Any]:
        normalized_target_user_id = _normalize_optional(target_user_id)
        if normalized_target_user_id is None:
            raise AppHTTPException(status_code=422, detail="target_user_id is required")
        normalized_reason = _require_reason(reason)
        async with transaction_scope() as session:
            subscription = await self.membership_service.subscription_dao.get_subscription(
                subscription_id,
                session=session,
            )
            if subscription is None:
                raise AppHTTPException(status_code=404, detail="Subscription not found")
            self._ensure_apple_subscription(subscription)
            self._ensure_expected_provider_subscription(
                subscription,
                expected_provider_subscription_id,
            )
            target_user = await self.user_dao.get_by_id(
                normalized_target_user_id,
                session=session,
            )
            if target_user is None:
                raise AppHTTPException(status_code=404, detail="Target user not found")
            if subscription.user_id == normalized_target_user_id:
                raise AppHTTPException(
                    status_code=409,
                    detail="Subscription already belongs to target user",
                )
            transactions = await self._list_subscription_transactions(
                subscription,
                session=session,
            )
            environment = _resolve_environment(subscription, transactions)
            _ensure_environment_allowed(environment, allow_production=allow_production)

            now = utc_now_naive()
            old_user_id = subscription.user_id
            audit = _admin_audit_payload(
                admin=admin,
                action="transfer_apple_subscription_binding",
                reason=normalized_reason,
                occurred_at=now,
                extra={
                    "old_user_id": old_user_id,
                    "target_user_id": normalized_target_user_id,
                    "provider_subscription_id": subscription.provider_subscription_id,
                    "environment": environment,
                    "move_periods": move_periods,
                },
            )

            subscription.user_id = normalized_target_user_id
            subscription.extra_data = {
                **dict(subscription.extra_data or {}),
                "admin_transfer": audit,
            }
            await self.membership_service.subscription_dao.save(
                subscription,
                session=session,
            )

            for transaction in transactions:
                transaction.user_id = normalized_target_user_id
                transaction.raw_payload = {
                    **dict(transaction.raw_payload or {}),
                    "admin_transfer": audit,
                }
                await self.membership_service.transaction_dao.save(
                    transaction,
                    session=session,
                )

            orders = await self._list_subscription_orders(
                subscription_id,
                session=session,
            )
            for order in orders:
                order.user_id = normalized_target_user_id
                order.raw_payload = {
                    **dict(order.raw_payload or {}),
                    "admin_transfer": audit,
                }
                await self.membership_service.order_dao.save(order, session=session)

            periods = await self.membership_service.period_dao.list_by_subscription_id(
                subscription.subscription_id,
                session=session,
            )
            moved_periods = 0
            if move_periods:
                for period in periods:
                    period.user_id = normalized_target_user_id
                    period.extra_data = {
                        **dict(period.extra_data or {}),
                        "admin_transfer": audit,
                    }
                    await self.membership_service.period_dao.save(period, session=session)
                    moved_periods += 1

            await self._refresh_user_if_present(old_user_id, session=session)
            await self.membership_service.refresh_membership_state(
                normalized_target_user_id,
                session=session,
            )

        return {
            "subscription_id": subscription_id,
            "provider": constants.PAYMENT_PROVIDER_APPLE,
            "action": "transferred",
            "environment": environment,
            "old_user_id": old_user_id,
            "target_user_id": normalized_target_user_id,
            "transactions_transferred": len(transactions),
            "orders_transferred": len(orders),
            "periods_transferred": moved_periods,
        }

    async def _list_subscription_transactions(
        self,
        subscription: MembershipSubscription,
        *,
        session,
    ) -> list[PaymentTransaction]:
        rows = (
            await session.execute(
                select(PaymentTransaction)
                .where(
                    PaymentTransaction.provider == subscription.provider,
                    PaymentTransaction.external_subscription_id
                    == subscription.provider_subscription_id,
                )
                .order_by(desc(PaymentTransaction.occurred_at))
            )
        ).scalars()
        return list(rows.all())

    async def _list_subscription_orders(
        self,
        subscription_id: str,
        *,
        session,
    ) -> list[PaymentOrder]:
        rows = (
            await session.execute(
                select(PaymentOrder)
                .where(PaymentOrder.subscription_id == subscription_id)
                .order_by(desc(PaymentOrder.created_at))
            )
        ).scalars()
        return list(rows.all())

    async def _refresh_user_if_present(self, user_id: str, *, session) -> None:
        user = await self.user_dao.get_by_id(user_id, session=session)
        if user is None:
            return
        await self.membership_service.refresh_membership_state(user_id, session=session)

    def _ensure_apple_subscription(self, subscription: MembershipSubscription) -> None:
        if subscription.provider != constants.PAYMENT_PROVIDER_APPLE:
            raise AppHTTPException(
                status_code=422,
                detail="Only Apple subscriptions can be handled by this operation",
            )

    def _ensure_expected_provider_subscription(
        self,
        subscription: MembershipSubscription,
        expected_provider_subscription_id: str | None,
    ) -> None:
        expected = _normalize_optional(expected_provider_subscription_id)
        if expected is not None and expected != subscription.provider_subscription_id:
            raise AppHTTPException(
                status_code=409,
                detail="Provider subscription id changed; reload before retrying",
            )


def _apply_common_filters(
    stmt,
    *,
    provider: str | None,
    status: str | None,
    user_id: str | None,
    provider_column,
    status_column,
    user_column,
):
    normalized_provider = _normalize_optional(provider)
    if normalized_provider is not None:
        stmt = stmt.where(provider_column == normalized_provider)
    normalized_status = _normalize_optional(status)
    if normalized_status is not None:
        stmt = stmt.where(status_column == normalized_status)
    normalized_user_id = _normalize_optional(user_id)
    if normalized_user_id is not None:
        stmt = stmt.where(user_column == normalized_user_id)
    return stmt


async def _count(session, stmt) -> int:
    result = await session.execute(select(func.count()).select_from(stmt.subquery()))
    return int(result.scalar() or 0)


def _normalize_optional(value: Any) -> str | None:
    text = str(value or "").strip()
    return text or None


def _require_reason(reason: str) -> str:
    normalized = _normalize_optional(reason)
    if normalized is None:
        raise AppHTTPException(status_code=422, detail="reason is required")
    return normalized


def _resolve_environment(
    subscription: MembershipSubscription,
    transactions: list[PaymentTransaction],
) -> str | None:
    extra = dict(subscription.extra_data or {})
    environment = _normalize_optional(extra.get("environment"))
    if environment is not None:
        return environment
    for transaction in transactions:
        raw_payload = dict(transaction.raw_payload or {})
        verified = raw_payload.get("verified_transaction")
        if isinstance(verified, dict):
            environment = _normalize_optional(verified.get("environment"))
            if environment is not None:
                return environment
        environment = _normalize_optional(raw_payload.get("environment"))
        if environment is not None:
            return environment
    return None


def _ensure_environment_allowed(
    environment: str | None,
    *,
    allow_production: bool,
) -> None:
    if allow_production:
        return
    if _normalize_optional(environment) == "Sandbox":
        return
    raise AppHTTPException(
        status_code=422,
        detail="Production Apple subscription operations require allow_production=true",
    )


def _archived_identifier(prefix: str, stable_id: str, old_identifier: str) -> str:
    digest = hashlib.sha256(old_identifier.encode("utf-8")).hexdigest()[:16]
    return f"{prefix}:{stable_id}:{digest}"[:255]


def _admin_audit_payload(
    *,
    admin: dict[str, Any],
    action: str,
    reason: str,
    occurred_at: datetime,
    extra: dict[str, Any],
) -> dict[str, Any]:
    return {
        "action": action,
        "reason": reason,
        "admin_phone": admin.get("phone"),
        "admin_subject": admin.get("sub"),
        "occurred_at": occurred_at.isoformat(),
        **extra,
    }


def _subscription_payload(subscription: MembershipSubscription) -> dict[str, Any]:
    return {
        "subscription_id": subscription.subscription_id,
        "user_id": subscription.user_id,
        "internal_product_code": subscription.internal_product_code,
        "provider": subscription.provider,
        "provider_subscription_id": subscription.provider_subscription_id,
        "status": subscription.status,
        "cancel_at_period_end": subscription.cancel_at_period_end,
        "started_at": _dt(subscription.started_at),
        "current_period_start_at": _dt(subscription.current_period_start_at),
        "current_period_end_at": _dt(subscription.current_period_end_at),
        "last_confirmed_at": _dt(subscription.last_confirmed_at),
        "ended_at": _dt(subscription.ended_at),
        "environment": _normalize_optional(
            dict(subscription.extra_data or {}).get("environment")
        ),
        "extra_data": dict(subscription.extra_data or {}),
        "created_at": _dt(subscription.created_at),
        "updated_at": _dt(subscription.updated_at),
    }


def _order_payload(order: PaymentOrder) -> dict[str, Any]:
    return {
        "order_no": order.order_no,
        "user_id": order.user_id,
        "internal_product_code": order.internal_product_code,
        "provider": order.provider,
        "platform": order.platform,
        "renewal_type": order.renewal_type,
        "status": order.status,
        "currency_code": order.currency_code,
        "amount_minor": order.amount_minor,
        "provider_order_id": order.provider_order_id,
        "provider_reference": order.provider_reference,
        "subscription_id": order.subscription_id,
        "confirmed_at": _dt(order.confirmed_at),
        "created_at": _dt(order.created_at),
        "updated_at": _dt(order.updated_at),
    }


def _transaction_payload(transaction: PaymentTransaction) -> dict[str, Any]:
    return {
        "transaction_id": transaction.transaction_id,
        "order_no": transaction.order_no,
        "user_id": transaction.user_id,
        "internal_product_code": transaction.internal_product_code,
        "provider": transaction.provider,
        "external_transaction_id": transaction.external_transaction_id,
        "external_subscription_id": transaction.external_subscription_id,
        "transaction_type": transaction.transaction_type,
        "status": transaction.status,
        "occurred_at": _dt(transaction.occurred_at),
        "environment": _resolve_transaction_environment(transaction),
        "created_at": _dt(transaction.created_at),
        "updated_at": _dt(transaction.updated_at),
    }


def _period_payload(period: MembershipPeriod) -> dict[str, Any]:
    return {
        "period_id": period.period_id,
        "user_id": period.user_id,
        "tier_code": period.tier_code,
        "internal_product_code": period.internal_product_code,
        "renewal_type": period.renewal_type,
        "provider": period.provider,
        "source_order_no": period.source_order_no,
        "source_subscription_id": period.source_subscription_id,
        "started_at": _dt(period.started_at),
        "paid_through_at": _dt(period.paid_through_at),
        "status": period.status,
        "entitlements": list(period.entitlements or []),
        "created_at": _dt(period.created_at),
        "updated_at": _dt(period.updated_at),
    }


def _resolve_transaction_environment(transaction: PaymentTransaction) -> str | None:
    raw_payload = dict(transaction.raw_payload or {})
    verified = raw_payload.get("verified_transaction")
    if isinstance(verified, dict):
        environment = _normalize_optional(verified.get("environment"))
        if environment is not None:
            return environment
    return _normalize_optional(raw_payload.get("environment"))


def _dt(value: datetime | None) -> str | None:
    return value.isoformat() if value is not None else None
