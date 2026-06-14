from __future__ import annotations

import unittest
from contextlib import asynccontextmanager
from datetime import timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from config import constants
from core.http.exceptions import AppHTTPException
from core.infra.apns import ApnsSendResult
from models.base import get_local_now
from models.calendar import AppleCalendarContext, CalendarEvent
from models.push import UserPushDevice
from schema.api.auth import PushDeviceUpsertRequest
from services.push.service import PushNotificationService, apns_preview_body_from_markdown


@asynccontextmanager
async def _fake_lock(*_args, **_kwargs):
    yield True


class PushNotificationServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_delete_device_clears_apple_calendar_context_and_imported_events(self) -> None:
        service = PushNotificationService()
        service.device_dao.delete_user_device = AsyncMock(return_value=None)
        service.calendar_context_dao.delete_where = AsyncMock(return_value=None)
        service.calendar_event_dao.delete_where = AsyncMock(return_value=None)
        service._delete_access_sessions_for_device = AsyncMock(return_value=None)

        payload = await service.delete_device(user_id="user-1", device_id=" device-1 ")

        self.assertEqual(payload, {"device_id": "device-1", "removed": True})
        service.device_dao.delete_user_device.assert_awaited_once_with(
            "user-1",
            "device-1",
        )
        service._delete_access_sessions_for_device.assert_awaited_once_with(
            user_id="user-1",
            device_id="device-1",
        )
        service.calendar_context_dao.delete_where.assert_awaited_once()
        context_args = service.calendar_context_dao.delete_where.await_args.args
        self.assertIs(context_args[0], AppleCalendarContext)
        self.assertEqual(len(context_args[1]), 2)
        service.calendar_event_dao.delete_where.assert_awaited_once()
        event_args = service.calendar_event_dao.delete_where.await_args.args
        self.assertIs(event_args[0], CalendarEvent)
        self.assertEqual(len(event_args[1]), 3)

    async def test_update_device_context_by_credentials_updates_timezone_and_location(self) -> None:
        service = PushNotificationService()
        device = UserPushDevice(
            device_id="device-1",
            user_id="user-1",
            platform="ios",
            transport="apns",
            push_token="token-1",
            timezone="UTC",
        )
        service.device_dao.get_device_by_id = AsyncMock(return_value=device)
        service.device_dao.save = AsyncMock(return_value=True)

        payload = await service.update_device_context_by_credentials(
            device_id="device-1",
            push_token="token-1",
            timezone=constants.DEFAULT_TIMEZONE,
            device_model="iPhone16,2",
            formatted_address="1 Market St, Shanghai, CN",
            name="Market",
            thoroughfare="Market St",
            sub_thoroughfare="1",
            sub_locality="Huangpu",
            locality="Shanghai",
            sub_administrative_area="Shanghai",
            city="Shanghai",
            administrative_area="Shanghai",
            postal_code="200000",
            country="CN",
            iso_country_code="CN",
            areas_of_interest=["Bund"],
            latitude=31.2,
            longitude=121.5,
            accuracy_meters=42,
            captured_at="2026-05-30T10:00:00Z",
        )

        self.assertEqual(device.timezone, constants.DEFAULT_TIMEZONE)
        self.assertEqual(device.device_model, "iPhone16,2")
        self.assertEqual(device.location_data["formatted_address"], "1 Market St, Shanghai, CN")
        self.assertEqual(device.location_data["name"], "Market")
        self.assertEqual(device.location_data["thoroughfare"], "Market St")
        self.assertEqual(device.location_data["sub_thoroughfare"], "1")
        self.assertEqual(device.location_data["sub_locality"], "Huangpu")
        self.assertEqual(device.location_data["locality"], "Shanghai")
        self.assertEqual(device.location_data["sub_administrative_area"], "Shanghai")
        self.assertEqual(device.location_data["city"], "Shanghai")
        self.assertEqual(device.location_data["postal_code"], "200000")
        self.assertEqual(device.location_data["iso_country_code"], "CN")
        self.assertEqual(device.location_data["areas_of_interest"], ["Bund"])
        self.assertEqual(device.location_data["latitude"], 31.2)
        self.assertEqual(device.location_data["captured_at"], "2026-05-30T10:00:00Z")
        self.assertIsNotNone(device.location_updated_at)
        self.assertEqual(payload["timezone"], constants.DEFAULT_TIMEZONE)
        self.assertEqual(payload["device_model"], "iPhone16,2")
        self.assertEqual(payload["formatted_address"], "1 Market St, Shanghai, CN")
        self.assertEqual(payload["captured_at"], "2026-05-30T10:00:00Z")
        service.device_dao.save.assert_awaited_once_with(device)

    async def test_update_device_context_by_credentials_rejects_fixed_offset_timezone(self) -> None:
        service = PushNotificationService()

        with self.assertRaises(AppHTTPException) as ctx:
            await service.update_device_context_by_credentials(
                device_id="device-1",
                push_token="token-1",
                timezone="UTC+08:00",
            )

        self.assertEqual(ctx.exception.status_code, 422)
        self.assertEqual(ctx.exception.detail, "Invalid timezone")

    async def test_update_device_context_by_credentials_updates_device_model_without_location_timestamp(self) -> None:
        service = PushNotificationService()
        device = UserPushDevice(
            device_id="device-1",
            user_id="user-1",
            platform="ios",
            transport="apns",
            push_token="token-1",
            timezone=constants.DEFAULT_TIMEZONE,
        )
        service.device_dao.get_device_by_id = AsyncMock(return_value=device)
        service.device_dao.save = AsyncMock(return_value=True)

        payload = await service.update_device_context_by_credentials(
            device_id="device-1",
            push_token="token-1",
            device_model="iPhone16,2",
        )

        self.assertEqual(device.device_model, "iPhone16,2")
        self.assertIsNone(device.location_data)
        self.assertIsNone(device.location_updated_at)
        self.assertEqual(payload["device_model"], "iPhone16,2")
        service.device_dao.save.assert_awaited_once_with(device)

    async def test_register_device_reassigns_device_to_new_user_and_only_clears_apple_data(self) -> None:
        service = PushNotificationService()
        existing = UserPushDevice(
            device_id="device-1",
            user_id="user-a",
            platform="ios",
            transport="apns",
            push_token="old-token",
            timezone="UTC",
        )
        service.device_dao.get_user_device = AsyncMock(return_value=None)
        service.device_dao.get_device_by_id = AsyncMock(return_value=existing)
        service.device_dao.save = AsyncMock(return_value=True)
        service.device_dao.delete_user_devices_except = AsyncMock(return_value=None)
        service.calendar_context_dao.delete_where = AsyncMock(return_value=None)
        service.calendar_event_dao.delete_where = AsyncMock(return_value=None)
        service._delete_access_sessions_except_device = AsyncMock(return_value=None)
        service._delete_access_sessions_for_user = AsyncMock(return_value=None)

        payload = await service.register_device(
            user_id="user-b",
            device_id="device-1",
            platform="ios",
            transport="apns",
            push_token="new-token",
            apns_environment="development",
            timezone=constants.DEFAULT_TIMEZONE,
            device_model="iPhone16,2",
            notifications_enabled=True,
        )

        self.assertEqual(existing.user_id, "user-b")
        self.assertEqual(existing.push_token, "new-token")
        self.assertEqual(existing.apns_environment, constants.APNS_ENVIRONMENT_DEVELOPMENT)
        self.assertEqual(existing.timezone, constants.DEFAULT_TIMEZONE)
        self.assertEqual(existing.device_model, "iPhone16,2")
        self.assertEqual(payload["user_id"], "user-b")
        service.calendar_context_dao.delete_where.assert_awaited_once()
        context_args = service.calendar_context_dao.delete_where.await_args.args
        self.assertIs(context_args[0], AppleCalendarContext)
        self.assertEqual(len(context_args[1]), 2)
        service.calendar_event_dao.delete_where.assert_awaited_once()
        event_args = service.calendar_event_dao.delete_where.await_args.args
        self.assertIs(event_args[0], CalendarEvent)
        self.assertEqual(len(event_args[1]), 3)
        self.assertIn("source", str(event_args[1][1]))
        service.device_dao.save.assert_awaited_once_with(existing)
        service.device_dao.delete_user_devices_except.assert_awaited_once_with(
            "user-b",
            keep_device_id="device-1",
            platform="ios",
            transport="apns",
        )
        service._delete_access_sessions_for_user.assert_awaited_once_with("user-a")
        service._delete_access_sessions_except_device.assert_awaited_once_with(
            user_id="user-b",
            keep_device_id="device-1",
        )

    async def test_register_device_replaces_existing_push_token_with_new_device_id(self) -> None:
        service = PushNotificationService()
        existing = UserPushDevice(
            device_id="old-device",
            user_id="user-1",
            platform="ios",
            transport="apns",
            push_token="token-1",
            timezone="UTC",
        )
        service.device_dao.get_user_device = AsyncMock(return_value=None)
        service.device_dao.get_device_by_id = AsyncMock(return_value=None)
        service.device_dao.get_device_by_push_token = AsyncMock(return_value=existing)
        service.device_dao.delete_device_by_id = AsyncMock(return_value=None)
        service.device_dao.save = AsyncMock(return_value=True)
        service.device_dao.delete_user_devices_except = AsyncMock(return_value=None)
        service.calendar_context_dao.delete_where = AsyncMock(return_value=None)
        service.calendar_event_dao.delete_where = AsyncMock(return_value=None)
        service._delete_access_sessions_except_device = AsyncMock(return_value=None)
        service._delete_access_sessions_for_user = AsyncMock(return_value=None)

        payload = await service.register_device(
            user_id="user-1",
            device_id="new-device",
            platform="ios",
            transport="apns",
            push_token="token-1",
            timezone=constants.DEFAULT_TIMEZONE,
            notifications_enabled=True,
        )

        self.assertEqual(payload["device_id"], "new-device")
        self.assertEqual(payload["push_token"], "token-1")
        service.device_dao.delete_device_by_id.assert_awaited_once_with("old-device")
        service.calendar_context_dao.delete_where.assert_awaited_once()
        service.calendar_event_dao.delete_where.assert_awaited_once()
        saved_device = service.device_dao.save.await_args.args[0]
        self.assertEqual(saved_device.device_id, "new-device")
        self.assertEqual(saved_device.user_id, "user-1")
        service.device_dao.delete_user_devices_except.assert_awaited_once_with(
            "user-1",
            keep_device_id="new-device",
            platform="ios",
            transport="apns",
        )
        service._delete_access_sessions_except_device.assert_awaited_once_with(
            user_id="user-1",
            keep_device_id="new-device",
        )
        service._delete_access_sessions_for_user.assert_not_awaited()

    async def test_register_device_prunes_other_user_apns_devices(self) -> None:
        service = PushNotificationService()
        service.device_dao.get_user_device = AsyncMock(return_value=None)
        service.device_dao.get_device_by_id = AsyncMock(return_value=None)
        service.device_dao.get_device_by_push_token = AsyncMock(return_value=None)
        service.device_dao.save = AsyncMock(return_value=True)
        service.device_dao.delete_user_devices_except = AsyncMock(return_value=None)
        service._delete_access_sessions_except_device = AsyncMock(return_value=None)

        await service.register_device(
            user_id="user-1",
            device_id="device-1",
            platform="ios",
            transport="apns",
            push_token="token-1",
            notifications_enabled=True,
        )

        service.device_dao.delete_user_devices_except.assert_awaited_once_with(
            "user-1",
            keep_device_id="device-1",
            platform="ios",
            transport="apns",
        )
        service._delete_access_sessions_except_device.assert_awaited_once_with(
            user_id="user-1",
            keep_device_id="device-1",
        )

    async def test_register_device_accepts_harmony_push_device(self) -> None:
        service = PushNotificationService()
        service.device_dao.get_user_device = AsyncMock(return_value=None)
        service.device_dao.get_device_by_id = AsyncMock(return_value=None)
        service.device_dao.get_device_by_push_token = AsyncMock(return_value=None)
        service.device_dao.save = AsyncMock(return_value=True)
        service.device_dao.delete_user_devices_except = AsyncMock(return_value=None)
        service._delete_access_sessions_except_device = AsyncMock(return_value=None)

        payload = await service.register_device(
            user_id="user-1",
            device_id="device-1",
            platform=constants.PLATFORM_OHOS,
            transport=constants.PUSH_TRANSPORT_HARMONY,
            push_token="token-1",
            notifications_enabled=True,
        )

        self.assertEqual(payload["platform"], constants.PLATFORM_OHOS)
        self.assertEqual(payload["transport"], constants.PUSH_TRANSPORT_HARMONY)
        service.device_dao.delete_user_devices_except.assert_awaited_once_with(
            "user-1",
            keep_device_id="device-1",
            platform=constants.PLATFORM_OHOS,
            transport=constants.PUSH_TRANSPORT_HARMONY,
        )

    def test_push_device_schema_rejects_platform_transport_mismatch(self) -> None:
        PushDeviceUpsertRequest(
            device_id="device-1",
            platform=constants.PLATFORM_IOS,
            transport=constants.PUSH_TRANSPORT_APNS,
            push_token="token-1",
        )
        PushDeviceUpsertRequest(
            device_id="device-2",
            platform=constants.PLATFORM_OHOS,
            transport=constants.PUSH_TRANSPORT_HARMONY,
            push_token="token-2",
        )

        with self.assertRaises(ValueError):
            PushDeviceUpsertRequest(
                device_id="device-3",
                platform=constants.PLATFORM_OHOS,
                transport=constants.PUSH_TRANSPORT_APNS,
                push_token="token-3",
            )

    async def test_prepare_devices_collapses_duplicate_active_apns_devices(self) -> None:
        service = PushNotificationService()
        latest = UserPushDevice(
            device_id="device-new",
            user_id="user-1",
            platform="ios",
            transport="apns",
            push_token="token-new",
        )
        old_a = UserPushDevice(
            device_id="device-old-a",
            user_id="user-1",
            platform="ios",
            transport="apns",
            push_token="token-old-a",
        )
        old_b = UserPushDevice(
            device_id="device-old-b",
            user_id="user-1",
            platform="ios",
            transport="apns",
            push_token="token-old-b",
        )
        service.device_dao.list_active_devices = AsyncMock(
            return_value=[latest, old_a, old_b]
        )
        service.device_dao.delete_user_devices_except = AsyncMock(return_value=None)

        devices = await service._prepare_devices_for_notification(
            "user-1",
            trigger="notification:test",
            refresh_device_context=False,
        )

        self.assertEqual(devices, [latest])
        service.device_dao.delete_user_devices_except.assert_awaited_once_with(
            "user-1",
            keep_device_id="device-new",
            platform="ios",
            transport="apns",
        )

    async def test_register_device_rejects_fixed_offset_timezone(self) -> None:
        service = PushNotificationService()

        with self.assertRaises(AppHTTPException) as ctx:
            await service.register_device(
                user_id="user-b",
                device_id="device-1",
                platform="ios",
                transport="apns",
                push_token="new-token",
                timezone="UTC+08:00",
                notifications_enabled=True,
            )

        self.assertEqual(ctx.exception.status_code, 422)
        self.assertEqual(ctx.exception.detail, "Invalid timezone")

    async def test_send_agent_completion_notification_refreshes_context_before_alert(self) -> None:
        service = PushNotificationService()
        device = UserPushDevice(
            device_id="device-1",
            user_id="user-1",
            platform="ios",
            transport="apns",
            push_token="token-1",
            app_bundle_id="com.ling.app",
            apns_environment=constants.APNS_ENVIRONMENT_DEVELOPMENT,
            locale="zh-Hans",
        )
        fresh_device = UserPushDevice(
            device_id="device-1",
            user_id="user-1",
            platform="ios",
            transport="apns",
            push_token="token-1",
            app_bundle_id="com.ling.app",
            apns_environment=constants.APNS_ENVIRONMENT_DEVELOPMENT,
            locale="zh-Hans",
        )
        fresh_device.location_updated_at = get_local_now() + timedelta(seconds=1)

        service.device_dao.list_active_devices = AsyncMock(
            side_effect=[
                [device],
                [fresh_device],
                [fresh_device],
            ]
        )
        service.apns = SimpleNamespace(
            is_configured=True,
            send_background_update=AsyncMock(
                return_value=ApnsSendResult(success=True, status_code=200)
            ),
            send_alert=AsyncMock(
                return_value=ApnsSendResult(success=True, status_code=200)
            ),
        )
        service.notification_dao.insert = AsyncMock(return_value=None)
        service.notification_dao.get_latest_by_dedupe_key = AsyncMock(
            return_value=None
        )
        service.notification_dao.save = AsyncMock(return_value=True)
        service.badge_service.get_user_badge_count = AsyncMock(
            return_value=SimpleNamespace(total=1)
        )

        with patch("services.push.service.redis.lock", _fake_lock):
            await service.send_agent_completion_notification(
                user_id="user-1",
                session_id="session-1",
                content_dedupe_basis="帮我整理今天的待办",
                assistant_preview_text="已整理好：\n- 买牛奶\n- 19:00 处理邮件",
            )

        expected_dedupe_key = service._agent_completion_dedupe_key(
            content_dedupe_basis="帮我整理今天的待办",
            assistant_preview_text="已整理好：\n- 买牛奶\n- 19:00 处理邮件",
        )
        service.apns.send_background_update.assert_awaited_once()
        self.assertEqual(
            service.apns.send_background_update.await_args.kwargs["apns_environment"],
            constants.APNS_ENVIRONMENT_DEVELOPMENT,
        )
        service.apns.send_alert.assert_awaited_once()
        send_alert_kwargs = service.apns.send_alert.await_args.kwargs
        self.assertEqual(send_alert_kwargs["badge"], 1)
        self.assertEqual(
            send_alert_kwargs["body"],
            "已整理好： 买牛奶 19:00 处理邮件",
        )
        self.assertEqual(
            send_alert_kwargs["apns_environment"],
            constants.APNS_ENVIRONMENT_DEVELOPMENT,
        )
        self.assertEqual(send_alert_kwargs["payload"]["kind"], "agent_completion")
        self.assertTrue(send_alert_kwargs["payload"]["notification_id"].startswith("ntf_"))
        self.assertNotIn("target", send_alert_kwargs["payload"])
        service.notification_dao.get_latest_by_dedupe_key.assert_awaited_once_with(
            "user-1",
            expected_dedupe_key,
        )
        service.notification_dao.insert.assert_awaited_once()
        inserted_notification = service.notification_dao.insert.await_args.args[0]
        self.assertEqual(inserted_notification.dedupe_key, expected_dedupe_key)
        self.assertEqual(
            inserted_notification.status,
            constants.NOTIFICATION_STATUS_SENT,
        )
        self.assertEqual(
            inserted_notification.body,
            "已整理好： 买牛奶 19:00 处理邮件",
        )
        self.assertIsNone(inserted_notification.dispatch_claimed_at)
        service.notification_dao.save.assert_awaited_once()

    async def test_create_agent_completion_notification_starts_as_dispatching(self) -> None:
        service = PushNotificationService()
        service.notification_dao.insert = AsyncMock(return_value=None)

        notification = await service._create_agent_completion_notification(
            user_id="user-1",
            dedupe_key="agent_completion:content:abc",
            assistant_preview_text="这里是最后回答的缩略内容",
        )

        self.assertEqual(
            notification.category,
            constants.NOTIFICATION_CATEGORY_AGENT_COMPLETION,
        )
        self.assertEqual(
            notification.status,
            constants.NOTIFICATION_STATUS_DISPATCHING,
        )
        self.assertEqual(
            notification.body,
            "这里是最后回答的缩略内容",
        )
        self.assertIsNotNone(notification.dispatch_claimed_at)
        service.notification_dao.insert.assert_awaited_once_with(notification)

    async def test_send_agent_completion_notification_skips_existing_dedupe_key(self) -> None:
        service = PushNotificationService()
        service.apns = SimpleNamespace(
            is_configured=True,
            send_background_update=AsyncMock(),
            send_alert=AsyncMock(),
        )
        service.notification_dao.get_latest_by_dedupe_key = AsyncMock(
            return_value=SimpleNamespace(
                notification_id="ntf_existing",
                status="sent",
            )
        )
        service.notification_dao.insert = AsyncMock(return_value=None)
        service.notification_dao.save = AsyncMock(return_value=True)
        service.device_dao.list_active_devices = AsyncMock(return_value=[])

        with patch("services.push.service.redis.lock", _fake_lock):
            await service.send_agent_completion_notification(
                user_id="user-1",
                session_id="session-1",
                content_dedupe_basis="帮我整理今天的待办",
            )

        expected_dedupe_key = service._agent_completion_dedupe_key(
            content_dedupe_basis="帮我整理今天的待办",
        )
        service.notification_dao.get_latest_by_dedupe_key.assert_awaited_once_with(
            "user-1",
            expected_dedupe_key,
        )
        service.device_dao.list_active_devices.assert_not_awaited()
        service.apns.send_background_update.assert_not_awaited()
        service.apns.send_alert.assert_not_awaited()
        service.notification_dao.insert.assert_not_awaited()
        service.notification_dao.save.assert_not_awaited()

    async def test_agent_completion_dedupe_key_uses_content_not_session(self) -> None:
        service = PushNotificationService()

        first = service._agent_completion_dedupe_key(
            content_dedupe_basis="帮我整理今天的待办",
        )
        second = service._agent_completion_dedupe_key(
            content_dedupe_basis="总结一下今天会议",
        )
        same_content = service._agent_completion_dedupe_key(
            content_dedupe_basis=" 帮我整理今天的待办 ",
        )

        self.assertNotIn("session", first)
        self.assertNotEqual(first, second)
        self.assertEqual(first, same_content)

    async def test_send_app_notification_includes_badge(self) -> None:
        service = PushNotificationService()
        device = UserPushDevice(
            device_id="device-1",
            user_id="user-1",
            platform="ios",
            transport="apns",
            push_token="token-1",
            app_bundle_id="com.ling.app",
        )
        notification = SimpleNamespace(
            notification_id="ntf_1",
            user_id="user-1",
            title="Title",
            body="Body",
            category="general",
            silent=False,
            target_type=None,
            target_id=None,
            target_action=None,
        )
        service.device_dao.list_active_devices = AsyncMock(return_value=[device])
        service.device_dao.delete_user_devices_except = AsyncMock(return_value=None)
        service.badge_service.get_user_badge_count = AsyncMock(
            return_value=SimpleNamespace(total=4)
        )
        service.apns = SimpleNamespace(
            is_configured=True,
            send_alert=AsyncMock(
                return_value=ApnsSendResult(success=True, status_code=200)
            ),
        )

        result = await service.send_app_notification(notification=notification)

        self.assertEqual(result, {"success": 1, "failed": 0, "skipped": 0})
        send_alert_kwargs = service.apns.send_alert.await_args.kwargs
        self.assertEqual(send_alert_kwargs["badge"], 4)
        self.assertEqual(send_alert_kwargs["apns_environment"], constants.APNS_ENVIRONMENT_PRODUCTION)
        self.assertEqual(
            send_alert_kwargs["payload"]["notification_id"],
            "ntf_1",
        )

    async def test_send_app_notification_sanitizes_markdown_body_for_apns(self) -> None:
        service = PushNotificationService()
        device = UserPushDevice(
            device_id="device-1",
            user_id="user-1",
            platform="ios",
            transport="apns",
            push_token="token-1",
            app_bundle_id="com.ling.app",
        )
        original_body = (
            "材料已整理好：[会议材料](file:///app/agents/user-1/report.md)\n"
            "也可以看[普通链接](https://example.com)。\n"
            "<ling-action label=\"打开材料\" prompt=\"打开材料\" />"
        )
        notification = SimpleNamespace(
            notification_id="ntf_1",
            user_id="user-1",
            title="Title",
            body=original_body,
            category="general",
            silent=False,
            target_type=None,
            target_id=None,
            target_action=None,
        )
        service.device_dao.list_active_devices = AsyncMock(return_value=[device])
        service.device_dao.delete_user_devices_except = AsyncMock(return_value=None)
        service.badge_service.get_user_badge_count = AsyncMock(
            return_value=SimpleNamespace(total=4)
        )
        service.apns = SimpleNamespace(
            is_configured=True,
            send_alert=AsyncMock(
                return_value=ApnsSendResult(success=True, status_code=200)
            ),
        )

        await service.send_app_notification(notification=notification)

        send_alert_kwargs = service.apns.send_alert.await_args.kwargs
        self.assertEqual(notification.body, original_body)
        self.assertEqual(send_alert_kwargs["body"], "材料已整理好：会议材料 也可以看普通链接。")
        self.assertNotIn("file://", send_alert_kwargs["body"])
        self.assertNotIn("/app/", send_alert_kwargs["body"])
        self.assertNotIn("https://", send_alert_kwargs["body"])
        self.assertNotIn("ling-action", send_alert_kwargs["body"])

    async def test_send_app_notification_dispatches_harmony_push(self) -> None:
        service = PushNotificationService()
        device = UserPushDevice(
            device_id="device-1",
            user_id="user-1",
            platform=constants.PLATFORM_OHOS,
            transport=constants.PUSH_TRANSPORT_HARMONY,
            push_token="token-1",
        )
        notification = SimpleNamespace(
            notification_id="ntf_1",
            user_id="user-1",
            title="Title",
            body="Body",
            category="general",
            silent=False,
            target_type=None,
            target_id=None,
            target_action=None,
        )
        service.device_dao.list_active_devices = AsyncMock(return_value=[device])
        service.badge_service.get_user_badge_count = AsyncMock(
            return_value=SimpleNamespace(total=2)
        )
        service.apns = SimpleNamespace(is_configured=False, send_alert=AsyncMock())
        service.harmony_push = SimpleNamespace(
            is_configured=True,
            send_alert=AsyncMock(
                return_value=ApnsSendResult(success=True, status_code=200)
            ),
        )

        result = await service.send_app_notification(notification=notification)

        self.assertEqual(result, {"success": 1, "failed": 0, "skipped": 0})
        service.apns.send_alert.assert_not_awaited()
        service.harmony_push.send_alert.assert_awaited_once()
        send_alert_kwargs = service.harmony_push.send_alert.await_args.kwargs
        self.assertEqual(send_alert_kwargs["device_token"], "token-1")
        self.assertEqual(send_alert_kwargs["badge"], 2)
        self.assertEqual(send_alert_kwargs["payload"]["kind"], "app_notification")

    def test_apns_preview_body_removes_raw_links_and_paths(self) -> None:
        preview = apns_preview_body_from_markdown(
            "请看 /app/agents/user-1/report.md 和 file:///app/agents/user-1/notes.md"
        )

        self.assertEqual(preview, "请看 和")

    async def test_send_app_notification_reports_skipped_when_apns_not_configured(self) -> None:
        service = PushNotificationService()
        notification = SimpleNamespace(
            notification_id="ntf_1",
            user_id="user-1",
            title="Title",
            body="Body",
            category="general",
            silent=False,
            target_type=None,
            target_id=None,
            target_action=None,
        )
        service.apns = SimpleNamespace(is_configured=False)

        result = await service.send_app_notification(notification=notification)

        self.assertEqual(result, {"success": 0, "failed": 0, "skipped": 1})


if __name__ == "__main__":
    unittest.main()
