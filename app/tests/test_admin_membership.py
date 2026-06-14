from __future__ import annotations

import unittest
from contextlib import asynccontextmanager
from datetime import datetime
from unittest.mock import AsyncMock

import core.infra.db as db_module
import modules.membership.models  # noqa: F401
from config import constants
from core.http.exceptions import AppHTTPException
from models.base import Base
from models.user import User
from modules.membership.models import (
    MembershipPeriod,
    MembershipSubscription,
    PaymentOrder,
    PaymentTransaction,
)
from modules.membership.service import MembershipService
from services.admin_membership import AdminMembershipService
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine


class _TestSessionManager:
    def __init__(self, session_factory: async_sessionmaker):
        self._session_factory = session_factory

    @asynccontextmanager
    async def get_session(self, autocommit: bool = True):
        session = self._session_factory()
        try:
            yield session
            if autocommit:
                await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()

    @asynccontextmanager
    async def transaction(self):
        session = self._session_factory()
        try:
            async with session.begin():
                yield session
        finally:
            await session.close()


def _bind_db(service: AdminMembershipService, manager: _TestSessionManager) -> None:
    service.user_dao.db = manager
    membership_service = service.membership_service
    for attr in [
        "order_dao",
        "transaction_dao",
        "subscription_dao",
        "period_dao",
        "state_dao",
        "product_dao",
    ]:
        getattr(membership_service, attr).db = manager


def _admin() -> dict:
    return {"phone": "+8613800000000", "sub": "+8613800000000"}


class AdminMembershipServiceTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.engine = create_async_engine("sqlite+aiosqlite:///:memory:", future=True)
        async with self.engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        self.session_factory = async_sessionmaker(
            bind=self.engine,
            autoflush=False,
            autocommit=False,
            expire_on_commit=False,
        )
        self.manager = _TestSessionManager(self.session_factory)
        db_module.DB_MANAGER = self.manager
        membership_service = MembershipService()
        membership_service.refresh_membership_state = AsyncMock()
        self.service = AdminMembershipService(membership_service=membership_service)
        _bind_db(self.service, self.manager)

    async def asyncTearDown(self) -> None:
        db_module.DB_MANAGER = None
        await self.engine.dispose()

    async def test_release_sandbox_subscription_archives_binding_and_transactions(self) -> None:
        await self._seed_subscription_bundle(environment="Sandbox")

        result = await self.service.release_apple_subscription_binding(
            subscription_id="sub_apple",
            admin=_admin(),
            reason="sandbox tester needs to restore again",
            expected_provider_subscription_id="orig-apple-1",
        )

        self.assertEqual(result["action"], "released")
        self.assertEqual(result["environment"], "Sandbox")
        self.assertEqual(result["periods_revoked"], 1)
        self.assertEqual(result["transactions_archived"], 1)

        subscription = await self.service.membership_service.subscription_dao.get_subscription(
            "sub_apple"
        )
        self.assertIsNotNone(subscription)
        assert subscription is not None
        self.assertEqual(subscription.status, constants.MEMBERSHIP_STATUS_REVOKED)
        self.assertTrue(subscription.cancel_at_period_end)
        self.assertNotEqual(subscription.provider_subscription_id, "orig-apple-1")
        self.assertTrue(subscription.provider_subscription_id.startswith("released_sub:"))
        self.assertEqual(
            subscription.extra_data["admin_release"]["old_provider_subscription_id"],
            "orig-apple-1",
        )

        detail = await self.service.get_subscription_detail("sub_apple")
        transaction = detail["transactions"][0]
        self.assertTrue(transaction["external_transaction_id"].startswith("released_txn:"))
        self.assertEqual(
            transaction["external_subscription_id"],
            subscription.provider_subscription_id,
        )
        self.assertEqual(detail["periods"][0]["status"], constants.MEMBERSHIP_STATUS_REVOKED)
        self.service.membership_service.refresh_membership_state.assert_awaited_once_with(
            "user-old",
            session=unittest.mock.ANY,
        )

    async def test_release_production_subscription_requires_explicit_override(self) -> None:
        await self._seed_subscription_bundle(environment="Production")

        with self.assertRaises(AppHTTPException) as ctx:
            await self.service.release_apple_subscription_binding(
                subscription_id="sub_apple",
                admin=_admin(),
                reason="operator clicked wrong row",
            )

        self.assertEqual(ctx.exception.status_code, 422)
        subscription = await self.service.membership_service.subscription_dao.get_subscription(
            "sub_apple"
        )
        self.assertIsNotNone(subscription)
        assert subscription is not None
        self.assertEqual(subscription.provider_subscription_id, "orig-apple-1")
        self.assertEqual(subscription.status, constants.MEMBERSHIP_STATUS_ACTIVE)

    async def test_transfer_subscription_moves_related_rows_to_target_user(self) -> None:
        await self._seed_subscription_bundle(environment="Sandbox", include_target=True)

        result = await self.service.transfer_apple_subscription_binding(
            subscription_id="sub_apple",
            target_user_id="user-new",
            admin=_admin(),
            reason="customer migrated account",
            expected_provider_subscription_id="orig-apple-1",
        )

        self.assertEqual(result["action"], "transferred")
        self.assertEqual(result["target_user_id"], "user-new")
        self.assertEqual(result["transactions_transferred"], 1)
        self.assertEqual(result["orders_transferred"], 1)
        self.assertEqual(result["periods_transferred"], 1)

        detail = await self.service.get_subscription_detail("sub_apple")
        self.assertEqual(detail["subscription"]["user_id"], "user-new")
        self.assertEqual(detail["transactions"][0]["user_id"], "user-new")
        self.assertEqual(detail["orders"][0]["user_id"], "user-new")
        self.assertEqual(detail["periods"][0]["user_id"], "user-new")
        self.assertEqual(
            self.service.membership_service.refresh_membership_state.await_args_list[0].args,
            ("user-old",),
        )
        self.assertEqual(
            self.service.membership_service.refresh_membership_state.await_args_list[1].args,
            ("user-new",),
        )

    async def _seed_subscription_bundle(
        self,
        *,
        environment: str,
        include_target: bool = False,
    ) -> None:
        async with self.manager.transaction() as session:
            session.add(User(user_id="user-old", username="old", password_hash="hash"))
            if include_target:
                session.add(User(user_id="user-new", username="new", password_hash="hash"))
            session.add(
                MembershipSubscription(
                    subscription_id="sub_apple",
                    user_id="user-old",
                    internal_product_code="pro_month_recurring",
                    provider=constants.PAYMENT_PROVIDER_APPLE,
                    provider_subscription_id="orig-apple-1",
                    status=constants.MEMBERSHIP_STATUS_ACTIVE,
                    started_at=datetime(2026, 4, 12, 9, 0, 0),
                    current_period_start_at=datetime(2026, 4, 12, 9, 0, 0),
                    current_period_end_at=datetime(2099, 12, 31, 9, 0, 0),
                    extra_data={"environment": environment},
                )
            )
            session.add(
                MembershipPeriod(
                    period_id="mpr_apple",
                    user_id="user-old",
                    tier_code=constants.MEMBERSHIP_TIER_PRO,
                    internal_product_code="pro_month_recurring",
                    renewal_type=constants.MEMBERSHIP_RENEWAL_RECURRING,
                    provider=constants.PAYMENT_PROVIDER_APPLE,
                    source_order_no="ord_apple",
                    source_subscription_id="sub_apple",
                    started_at=datetime(2026, 4, 12, 9, 0, 0),
                    paid_through_at=datetime(2099, 12, 31, 9, 0, 0),
                    status=constants.MEMBERSHIP_STATUS_ACTIVE,
                    entitlements=["member_core", "member_advanced"],
                )
            )
            session.add(
                PaymentTransaction(
                    transaction_id="txn_apple",
                    order_no="ord_apple",
                    user_id="user-old",
                    internal_product_code="pro_month_recurring",
                    provider=constants.PAYMENT_PROVIDER_APPLE,
                    external_transaction_id="apple-txn-1",
                    external_subscription_id="orig-apple-1",
                    transaction_type=constants.PAYMENT_TRANSACTION_TYPE_PURCHASE,
                    status=constants.PAYMENT_TRANSACTION_STATUS_SUCCEEDED,
                    occurred_at=datetime(2026, 4, 12, 9, 0, 0),
                    raw_payload={"verified_transaction": {"environment": environment}},
                )
            )
            session.add(
                PaymentOrder(
                    order_no="ord_apple",
                    user_id="user-old",
                    internal_product_code="pro_month_recurring",
                    provider=constants.PAYMENT_PROVIDER_APPLE,
                    platform="ios",
                    renewal_type=constants.MEMBERSHIP_RENEWAL_RECURRING,
                    status=constants.PAYMENT_ORDER_STATUS_PAID,
                    subscription_id="sub_apple",
                )
            )
