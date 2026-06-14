from __future__ import annotations

import unittest
from datetime import datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import jwt
from config import constants
from config.settings import AppConfig
from core.http.exceptions import AppHTTPException
from modules.membership.entitlements import (
    FEATURE_ALL_TOOLS,
    FREE_DAILY_CHAT_LIMIT,
    MembershipEntitlementService,
    entitlement_snapshot_for_tier,
)
from modules.membership.models import MembershipState
from modules.membership.providers.apple import AppleJWSVerifier
from modules.membership.service import (
    BUSINESS_TIMEZONE,
    ENTITLEMENT_CHAT_DAILY_LIMIT,
    ENTITLEMENT_MEMBER_ADVANCED,
    ENTITLEMENT_MEMBER_CORE,
    FREE_TIER_CODE,
    PRO_TIER_CODE,
    MembershipService,
    _catalog_seed_rows,
)
from schema.api.membership import MembershipSummaryPayload
from utils.time import UTC


class _FakeRedis:
    def __init__(self, store: dict[str, object] | None = None) -> None:
        self.store = dict(store or {})
        self.expirations: dict[str, int | None] = {}
        self.deleted: list[str] = []

    def key(self, *parts: str) -> str:
        return ":".join(part.strip(":") for part in parts if part.strip(":"))

    async def get_json(self, key: str, *, default=None):
        return self.store.get(key, default)

    async def set_json(self, key: str, value, *, ex: int | None = None) -> bool:
        self.store[key] = value
        self.expirations[key] = ex
        return True

    async def delete(self, *keys: str) -> int:
        deleted = 0
        for key in keys:
            self.deleted.append(key)
            deleted += int(key in self.store)
            self.store.pop(key, None)
        return deleted


class MembershipServicePeriodWindowTests(unittest.IsolatedAsyncioTestCase):
    async def test_resolve_period_window_extends_from_current_paid_through(
        self,
    ) -> None:
        service = MembershipService()
        service.refresh_membership_state = AsyncMock(
            return_value=SimpleNamespace(
                paid_through_at=datetime(2026, 4, 20, 8, 0, 0),
            )
        )

        window = await service.resolve_membership_period_window(
            user_id="user-1",
            duration_months=1,
            confirmed_at=datetime(2026, 4, 12, 9, 0, 0, tzinfo=UTC),
        )

        self.assertEqual(
            window.started_at,
            datetime(2026, 4, 20, 8, 0, 0, tzinfo=UTC),
        )
        self.assertEqual(
            window.paid_through_at,
            datetime(2026, 5, 20, 8, 0, 0, tzinfo=UTC),
        )

    async def test_resolve_period_window_restarts_from_confirmed_time_when_expired(
        self,
    ) -> None:
        service = MembershipService()
        service.refresh_membership_state = AsyncMock(
            return_value=SimpleNamespace(
                paid_through_at=datetime(2026, 4, 10, 8, 0, 0),
            )
        )

        window = await service.resolve_membership_period_window(
            user_id="user-2",
            duration_months=3,
            confirmed_at=datetime(2026, 4, 12, 9, 0, 0, tzinfo=UTC),
        )

        self.assertEqual(
            window.started_at,
            datetime(2026, 4, 12, 9, 0, 0, tzinfo=UTC),
        )
        self.assertEqual(
            window.paid_through_at,
            datetime(2026, 7, 12, 9, 0, 0, tzinfo=UTC),
        )


class MembershipServiceEntitlementTests(unittest.IsolatedAsyncioTestCase):
    def test_catalog_seed_keeps_image_chat_inside_free_chat_quota(self) -> None:
        rows = _catalog_seed_rows()
        tier_cards = rows[0]["metadata"]["subscription_sheet"]["tier_cards"]
        free_card = next(
            card for card in tier_cards if card["tier_code"] == FREE_TIER_CODE
        )
        pro_card = next(
            card for card in tier_cards if card["tier_code"] == PRO_TIER_CODE
        )

        self.assertIn("每日 50 次文字/图片对话", free_card["features_zh"])
        self.assertIn("50 text/image chats per day", free_card["features_en"])
        self.assertIn("Ling Workbench 完整视图", pro_card["features_zh"])
        self.assertIn("Full Ling Workbench", pro_card["features_en"])
        self.assertNotIn("图片输入与理解", pro_card["features_zh"])
        self.assertNotIn("Image input & understanding", pro_card["features_en"])

    async def test_refresh_membership_state_can_build_real_free_state(
        self,
    ) -> None:
        service = MembershipService()
        service.ensure_catalog_seeded = AsyncMock()
        service.period_dao.get_latest_active_period = AsyncMock(return_value=None)
        service.state_dao.get_state = AsyncMock(return_value=None)
        service.state_dao.save = AsyncMock()
        service.invalidate_entitlement_snapshot = AsyncMock()

        state = await service.refresh_membership_state("user-free")

        self.assertEqual(state.tier_code, FREE_TIER_CODE)
        self.assertEqual(state.access_state, "inactive")
        self.assertEqual(state.entitlements, [ENTITLEMENT_CHAT_DAILY_LIMIT])
        self.assertEqual(state.daily_chat_limit, 50)
        service.ensure_catalog_seeded.assert_not_awaited()
        service.state_dao.save.assert_awaited_once()
        service.invalidate_entitlement_snapshot.assert_awaited_once_with("user-free")

    async def test_build_summary_uses_state_refresh_without_catalog_seed(self) -> None:
        service = MembershipService()
        service.ensure_catalog_seeded = AsyncMock()
        service.ensure_points_account = AsyncMock(return_value=SimpleNamespace(balance=0))
        service.refresh_membership_state = AsyncMock(
            return_value=SimpleNamespace(
                tier_code=PRO_TIER_CODE,
                access_state="active",
                renewal_type=None,
                provider=None,
                started_at=None,
                paid_through_at=None,
                cancel_at_period_end=False,
                daily_chat_limit=None,
                entitlements=[ENTITLEMENT_MEMBER_CORE, ENTITLEMENT_MEMBER_ADVANCED],
            )
        )
        service.daily_usage_dao.get_user_business_day_usage = AsyncMock(
            return_value=None
        )

        summary = await service.build_summary("user-1", locale="en-US")

        self.assertEqual(summary.tier_code, PRO_TIER_CODE)
        self.assertEqual(
            summary.display["membership_state_card"]["title"],
            "Pro Membership",
        )
        self.assertEqual(
            summary.display["membership_state_card"]["subtitle"],
            "All Pro capabilities are unlocked.",
        )
        service.ensure_catalog_seeded.assert_not_awaited()
        service.refresh_membership_state.assert_awaited_once()

    async def test_refresh_membership_state_defaults_to_free_when_no_active_period(
        self,
    ) -> None:
        service = MembershipService()
        existing_state = MembershipState(
            user_id="user-1",
            tier_code=PRO_TIER_CODE,
            access_state="active",
            entitlements=[ENTITLEMENT_MEMBER_CORE, ENTITLEMENT_MEMBER_ADVANCED],
            daily_chat_limit=None,
            business_timezone=BUSINESS_TIMEZONE,
        )
        service.ensure_catalog_seeded = AsyncMock()
        service.period_dao.get_latest_active_period = AsyncMock(return_value=None)
        service.state_dao.get_state = AsyncMock(return_value=existing_state)
        service.state_dao.save = AsyncMock()
        service.invalidate_entitlement_snapshot = AsyncMock()

        state = await service.refresh_membership_state("user-1")

        self.assertEqual(state.tier_code, "free")
        self.assertEqual(state.access_state, "inactive")
        self.assertEqual(state.daily_chat_limit, FREE_DAILY_CHAT_LIMIT)
        service.ensure_catalog_seeded.assert_not_awaited()
        service.state_dao.save.assert_awaited_once()
        service.invalidate_entitlement_snapshot.assert_awaited_once_with("user-1")

    async def test_ensure_catalog_seeded_creates_missing_product_channels(self) -> None:
        service = MembershipService()
        service.product_dao.count_products = AsyncMock(return_value=0)
        service.product_dao.get_product = AsyncMock(return_value=None)
        service.product_dao.save = AsyncMock()
        service.channel_dao.get_channel = AsyncMock(return_value=None)
        service.channel_dao.save = AsyncMock()

        await service.ensure_catalog_seeded()

        self.assertGreater(service.channel_dao.save.await_count, 0)
        first_channel = service.channel_dao.save.await_args_list[0].args[0]
        self.assertEqual(first_channel.provider, "apple")
        self.assertTrue(first_channel.provider_product_id.startswith("ling."))

    async def test_ensure_catalog_seeded_updates_existing_product_metadata(self) -> None:
        service = MembershipService()
        existing_product = SimpleNamespace(
            internal_product_code="pro_month_recurring",
            metadata_json={},
        )
        existing_channel = SimpleNamespace(metadata_json={})
        service.product_dao.get_product = AsyncMock(return_value=existing_product)
        service.product_dao.save = AsyncMock()
        service.channel_dao.get_channel = AsyncMock(return_value=existing_channel)
        service.channel_dao.save = AsyncMock()

        await service.ensure_catalog_seeded()

        self.assertIn("subscription_sheet", existing_product.metadata_json)
        self.assertIn("entitlement_sections", existing_product.metadata_json)
        service.product_dao.save.assert_awaited()

    async def test_ensure_entitlement_raises_typed_exception(self) -> None:
        service = MembershipService()
        service.build_summary = AsyncMock(
            return_value=MembershipSummaryPayload(
                tier_code="free",
                access_state="inactive",
                daily_chat_limit=5,
                daily_chat_used=5,
                daily_chat_remaining=0,
                business_timezone=BUSINESS_TIMEZONE,
                server_now="2026-04-12T10:00:00+00:00",
                entitlements=[ENTITLEMENT_CHAT_DAILY_LIMIT],
                points_balance=0,
            )
        )

        with self.assertRaises(AppHTTPException) as ctx:
            await service.ensure_entitlement("user-3", ENTITLEMENT_MEMBER_CORE)

        self.assertEqual(ctx.exception.status_code, 403)
        self.assertEqual(
            ctx.exception.error_code,
            "membership_entitlement_required",
        )
        self.assertEqual(
            ctx.exception.error_detail["entitlement_code"],
            ENTITLEMENT_MEMBER_CORE,
        )

    async def test_ensure_feature_raises_typed_exception(self) -> None:
        service = MembershipService()
        service.entitlement_snapshot_for_user = AsyncMock(
            return_value=SimpleNamespace(feature_entitlements=[])
        )
        service.build_summary = AsyncMock(
            return_value=MembershipSummaryPayload(
                tier_code="free",
                access_state="inactive",
                daily_chat_limit=5,
                daily_chat_used=5,
                daily_chat_remaining=0,
                business_timezone=BUSINESS_TIMEZONE,
                server_now="2026-04-12T10:00:00+00:00",
                feature_entitlements=[],
                points_balance=0,
            )
        )

        with self.assertRaises(AppHTTPException) as ctx:
            await service.ensure_feature("user-3", FEATURE_ALL_TOOLS)

        self.assertEqual(ctx.exception.status_code, 403)
        self.assertEqual(
            ctx.exception.error_code,
            "membership_entitlement_required",
        )
        self.assertEqual(
            ctx.exception.error_detail["feature_code"],
            FEATURE_ALL_TOOLS,
        )
        service.build_summary.assert_awaited_once()

    async def test_ensure_feature_success_uses_lightweight_snapshot(self) -> None:
        service = MembershipService()
        service.entitlement_snapshot_for_user = AsyncMock(
            return_value=SimpleNamespace(
                feature_entitlements=[FEATURE_ALL_TOOLS]
            )
        )
        service.build_summary = AsyncMock()

        await service.ensure_feature("user-pro", FEATURE_ALL_TOOLS)

        service.entitlement_snapshot_for_user.assert_awaited_once_with("user-pro")
        service.build_summary.assert_not_awaited()

    async def test_entitlement_snapshot_reads_redis_cache(self) -> None:
        service = MembershipService()
        service.refresh_membership_state = AsyncMock()
        fake_redis = _FakeRedis(
            {
                "membership:entitlement:user-pro": {
                    "schema_version": 1,
                    "tier_code": PRO_TIER_CODE,
                    "access_state": "active",
                    "feature_entitlements": [FEATURE_ALL_TOOLS],
                    "daily_chat_limit": None,
                    "limits": {},
                }
            }
        )

        with patch("modules.membership.service.redis", fake_redis):
            snapshot = await service.entitlement_snapshot_for_user("user-pro")

        self.assertTrue(snapshot.is_pro)
        self.assertIn(FEATURE_ALL_TOOLS, snapshot.feature_entitlements)
        service.refresh_membership_state.assert_not_awaited()

    async def test_entitlement_snapshot_writes_redis_on_cache_miss(self) -> None:
        service = MembershipService()
        service.refresh_membership_state = AsyncMock(
            return_value=MembershipState(
                user_id="user-pro",
                tier_code=PRO_TIER_CODE,
                access_state="active",
            )
        )
        fake_redis = _FakeRedis()

        with patch("modules.membership.service.redis", fake_redis):
            snapshot = await service.entitlement_snapshot_for_user("user-pro")

        self.assertTrue(snapshot.is_pro)
        payload = fake_redis.store["membership:entitlement:user-pro"]
        self.assertEqual(payload["tier_code"], PRO_TIER_CODE)
        self.assertIn(FEATURE_ALL_TOOLS, payload["feature_entitlements"])
        self.assertEqual(fake_redis.expirations["membership:entitlement:user-pro"], 300)


class MembershipServiceCancellationTests(unittest.IsolatedAsyncioTestCase):
    async def test_cancel_provider_subscription_uses_subscription_provider_when_missing(
        self,
    ) -> None:
        service = MembershipService()
        subscription = SimpleNamespace(
            subscription_id="sub_1",
            user_id="user-4",
            provider="wechat",
            cancel_at_period_end=False,
            status="active",
        )
        service.subscription_dao.get_subscription = AsyncMock(
            return_value=subscription
        )
        service.subscription_dao.save = AsyncMock()
        service.refresh_membership_state = AsyncMock()
        service.invalidate_entitlement_snapshot = AsyncMock()

        result = await service.cancel_provider_subscription(
            provider=None,
            user_id="user-4",
            subscription_id="sub_1",
        )

        self.assertTrue(subscription.cancel_at_period_end)
        self.assertEqual(subscription.status, "cancel_scheduled")
        self.assertEqual(result["provider"], "wechat")
        service.subscription_dao.save.assert_awaited_once_with(subscription)
        service.invalidate_entitlement_snapshot.assert_awaited_once_with("user-4")

    async def test_cancel_provider_subscription_rejects_apple_management(
        self,
    ) -> None:
        service = MembershipService()
        service.subscription_dao.get_subscription = AsyncMock(
            return_value=SimpleNamespace(
                subscription_id="sub_2",
                user_id="user-5",
                provider="apple",
                cancel_at_period_end=False,
                status="active",
            )
        )

        with self.assertRaises(AppHTTPException) as ctx:
            await service.cancel_provider_subscription(
                provider=None,
                user_id="user-5",
                subscription_id="sub_2",
            )

        self.assertEqual(ctx.exception.status_code, 422)


class MembershipEntitlementServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_free_user_keeps_daily_chat_limit(self) -> None:
        service = MembershipEntitlementService()
        with patch(
            "modules.membership.service.MembershipService.entitlement_snapshot_for_user",
            new=AsyncMock(
                return_value=entitlement_snapshot_for_tier(
                    FREE_TIER_CODE,
                    "inactive",
                )
            ),
        ):
            self.assertFalse(await service.can_use_feature("user-free", FEATURE_ALL_TOOLS))
            self.assertEqual(
                await service.chat_limit_for("user-free"),
                FREE_DAILY_CHAT_LIMIT,
            )

    async def test_pro_user_gets_tool_entitlement(self) -> None:
        service = MembershipEntitlementService()
        with patch(
            "modules.membership.service.MembershipService.entitlement_snapshot_for_user",
            new=AsyncMock(
                return_value=entitlement_snapshot_for_tier(
                    PRO_TIER_CODE,
                    "active",
                )
            ),
        ):
            self.assertTrue(await service.can_use_feature("user-pro", FEATURE_ALL_TOOLS))
            self.assertIsNone(await service.chat_limit_for("user-pro"))


class AppleJWSVerifierTests(unittest.TestCase):
    def test_decode_transaction_requires_expected_bundle(self) -> None:
        token = jwt.encode(
            {
                "transactionId": "1000001",
                "originalTransactionId": "1000000",
                "productId": "ling.pro_month_recurring",
                "bundleId": "top.withling.ling",
                "purchaseDate": 1_775_520_000_000,
                "expiresDate": 1_778_112_000_000,
                "appAccountToken": "68a74f5b-957b-51fc-b6c1-5aee1fdca38d",
                "environment": "Sandbox",
            },
            key="",
            algorithm="none",
        )

        verifier = AppleJWSVerifier(AppConfig(apple_iap_verify_signature=False))
        decoded = verifier.decode_transaction(token)

        self.assertEqual(decoded.transaction_id, "1000001")
        self.assertEqual(decoded.original_transaction_id, "1000000")
        self.assertEqual(decoded.product_id, "ling.pro_month_recurring")
        self.assertEqual(
            decoded.app_account_token,
            "68a74f5b-957b-51fc-b6c1-5aee1fdca38d",
        )

    def test_decode_transaction_rejects_bundle_mismatch(self) -> None:
        token = jwt.encode(
            {
                "transactionId": "1000001",
                "productId": "ling.pro_month_recurring",
                "bundleId": "com.example.other",
            },
            key="",
            algorithm="none",
        )
        verifier = AppleJWSVerifier(AppConfig(apple_iap_verify_signature=False))

        with self.assertRaises(AppHTTPException) as ctx:
            verifier.decode_transaction(token)

        self.assertEqual(ctx.exception.status_code, 401)
