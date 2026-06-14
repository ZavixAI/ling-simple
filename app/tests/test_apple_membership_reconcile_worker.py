import unittest
from datetime import datetime
from unittest.mock import AsyncMock

from config import constants
from config.settings import AppConfig
from modules.membership.models import MembershipSubscription
from services.apple_membership_reconcile import AppleMembershipReconcileWorker


class AppleMembershipReconcileWorkerTests(unittest.IsolatedAsyncioTestCase):
    async def test_start_skips_without_app_store_server_api_credentials(self) -> None:
        worker = AppleMembershipReconcileWorker(AppConfig())

        worker.start()

        self.assertIsNone(worker._task)

    async def test_tick_reconciles_latest_apple_transactions(self) -> None:
        worker = AppleMembershipReconcileWorker(
            AppConfig(
                apple_app_store_server_api_issuer_id="issuer",
                apple_app_store_server_api_key_id="key",
                apple_app_store_server_api_private_key="private",
            )
        )
        subscription = MembershipSubscription(
            subscription_id="sub-1",
            user_id="user-1",
            internal_product_code="pro_month_recurring",
            provider=constants.PAYMENT_PROVIDER_APPLE,
            provider_subscription_id="original-txn-1",
            started_at=datetime(2026, 6, 1),
            current_period_start_at=datetime(2026, 6, 1),
            current_period_end_at=datetime(2026, 7, 1),
            extra_data={"latest_transaction_id": "txn-1"},
        )
        worker._subscription_dao.list_provider_subscriptions = AsyncMock(
            return_value=[subscription]
        )
        worker._membership_service.reconcile_apple_transaction = AsyncMock(
            return_value={}
        )

        reconciled = await worker.tick()

        self.assertEqual(reconciled, 1)
        worker._membership_service.reconcile_apple_transaction.assert_awaited_once_with(
            "txn-1"
        )
