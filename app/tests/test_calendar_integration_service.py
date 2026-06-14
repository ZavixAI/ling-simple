from __future__ import annotations

import unittest
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, patch

from models.calendar import CalendarEvent
from models.calendar_provider import CalendarProviderConnection
from services.calendar_integrations.service import (
    CalendarConnectionService,
    CalendarOAuthService,
    ExternalCalendarSyncService,
    FeishuWebhookService,
)
from services.calendar_integrations.state_store import RedisCalendarOAuthState
from services.calendar_integrations.stream import DingTalkCalendarEventRouter


class CalendarIntegrationServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_complete_oauth_creates_connection_and_runs_initial_sync(self) -> None:
        state_store = AsyncMock()
        connection_dao = AsyncMock()
        sync_service = AsyncMock()
        state_store.get.return_value = RedisCalendarOAuthState(
            state="state-1",
            provider_id="feishu",
            user_id="user-1",
            redirect_uri="ling-oauth://calendar-auth/feishu",
            callback_scheme="ling-oauth",
            created_at=datetime.now(),
            expire_at=datetime.now() + timedelta(minutes=5),
        )
        connection_dao.get_by_user_provider.return_value = None
        fake_provider = AsyncMock()
        fake_provider.exchange_code.return_value = type(
            "ExchangeResult",
            (),
            {
                "provider_id": "feishu",
                "external_user_id": "ou_1",
                "external_user_name": "Ling User",
                "external_email": "ling@example.com",
                "external_tenant_id": "tenant-1",
                "external_tenant_name": "Tenant",
                "access_token": "access-token",
                "refresh_token": "refresh-token",
                "access_token_expires_at": datetime.now(UTC) + timedelta(hours=1),
                "refresh_token_expires_at": datetime.now(UTC) + timedelta(days=30),
                "primary_calendar_id": "cal_1",
                "metadata": {"source": "test"},
            },
        )()
        sync_service.run_initial_sync.return_value = {"event_count": 3}

        with patch(
            "services.calendar_integrations.service.build_provider_client",
            return_value=fake_provider,
        ):
            service = CalendarOAuthService(
                state_store=state_store,
                connection_dao=connection_dao,
                sync_service=sync_service,
            )
            result = await service.complete_oauth(
                "feishu",
                "user-1",
                "ling-oauth://calendar-auth/feishu?code=code-1&state=state-1",
            )

        self.assertEqual(result["provider_id"], "feishu")
        connection_dao.insert.assert_awaited_once()
        sync_service.run_initial_sync.assert_awaited_once()
        state_store.delete.assert_awaited_once_with("state-1")

    async def test_disconnect_marks_imported_events_inactive(self) -> None:
        connection = CalendarProviderConnection(
            connection_id="cconn_1",
            user_id="user-1",
            provider_id="dingtalk",
            status="connected",
        )
        active_event = CalendarEvent(
            event_id="dingtalk:cconn_1:event_1",
            user_id="user-1",
            title="Imported",
            start_at=datetime.now(),
            end_at=datetime.now() + timedelta(hours=1),
            timezone="UTC",
            source="dingtalk",
        )
        active_event.source_device_id = "cconn_1"
        active_event.is_active = True

        connection_dao = AsyncMock()
        event_dao = AsyncMock()
        connection_dao.get_by_user_provider.return_value = connection
        event_dao.list_user_source_events.return_value = [active_event]

        service = CalendarConnectionService(
            connection_dao=connection_dao,
            event_dao=event_dao,
            sync_service=AsyncMock(),
        )
        result = await service.disconnect("user-1", "dingtalk")

        self.assertTrue(result["disconnected"])
        self.assertFalse(active_event.is_active)
        self.assertEqual(active_event.status, "cancelled")
        event_dao.save.assert_awaited_once_with(active_event)
        connection_dao.delete_by_id.assert_awaited_once()

    async def test_feishu_webhook_deduplicates_replayed_events(self) -> None:
        connection_dao = AsyncMock()
        sync_service = AsyncMock()
        trigger_store = AsyncMock()
        trigger_store.reserve.side_effect = [True, False]

        service = FeishuWebhookService(
            connection_dao=connection_dao,
            sync_service=sync_service,
            trigger_store=trigger_store,
        )
        payload = {
            "header": {
                "event_type": "calendar.calendar.event.changed_v4",
                "tenant_key": "tenant-1",
                "event_id": "evt-1",
            },
            "event": {"calendar_id": "cal-1"},
        }

        first = await service.handle_webhook(payload)
        second = await service.handle_webhook(payload)

        self.assertTrue(first["accepted"])
        self.assertTrue(second["duplicate"])
        sync_service.run_delta_sync.assert_not_awaited()

    async def test_dingtalk_stream_routes_calendar_change_to_matching_connection(self) -> None:
        connection = CalendarProviderConnection(
            connection_id="cconn_1",
            user_id="user-1",
            provider_id="dingtalk",
            status="connected",
            external_user_id="union-1",
            external_tenant_id="corp-1",
            primary_calendar_id="cal-1",
        )
        connection_dao = AsyncMock()
        connection_dao.list_by_provider_tenant.return_value = [connection]
        sync_service = AsyncMock()
        trigger_store = AsyncMock()
        trigger_store.reserve.return_value = True

        router = DingTalkCalendarEventRouter(
            connection_dao=connection_dao,
            sync_service=sync_service,
            trigger_store=trigger_store,
        )
        headers = type(
            "Headers",
            (),
            {
                "event_type": "calendar_event_change",
                "event_corp_id": "corp-1",
                "event_id": "stream-1",
            },
        )()

        result = await router.process(
            headers=headers,
            data={
                "corpId": "corp-1",
                "calendarId": "cal-1",
                "calendarEventId": "evt-1",
                "unionIdList": ["union-1"],
            },
        )

        self.assertTrue(result["accepted"])
        self.assertEqual(result["matched_connections"], 1)
        sync_service.run_delta_sync.assert_awaited_once_with(
            "cconn_1",
            trigger="dingtalk_stream:stream-1",
        )

    async def test_upsert_imported_events_queries_only_connection_scoped_external_ids(self) -> None:
        connection = CalendarProviderConnection(
            connection_id="cconn_1",
            user_id="user-1",
            provider_id="feishu",
            status="connected",
            external_user_id="ou_1",
            external_tenant_id="tenant-1",
            primary_calendar_id="cal-1",
        )
        existing_event = CalendarEvent(
            event_id="feishu:cconn_1:evt_1",
            user_id="user-1",
            title="Imported",
            start_at=datetime.now(),
            end_at=datetime.now() + timedelta(hours=1),
            timezone="UTC",
            source="feishu",
            source_device_id="cconn_1",
            external_event_identifier="evt_1",
        )
        event_dao = AsyncMock()
        event_dao.list_connection_source_events.return_value = [existing_event]
        event_dao.save = AsyncMock(return_value=True)
        service = ExternalCalendarSyncService(connection_dao=AsyncMock(), event_dao=event_dao)

        touched = await service.upsert_imported_events(
            connection,
            [
                {
                    "event_id": "evt_1",
                    "title": "Updated",
                    "start_at": "2026-04-17T12:00:00Z",
                    "end_at": "2026-04-17T13:00:00Z",
                    "timezone": "UTC",
                    "status": "scheduled",
                }
            ],
        )

        self.assertEqual(touched, 1)
        event_dao.list_connection_source_events.assert_awaited_once_with(
            "user-1",
            "feishu",
            "cconn_1",
            external_event_identifiers={"evt_1"},
        )
        event_dao.save.assert_awaited_once_with(existing_event)

    async def test_deactivate_deleted_events_queries_only_deleted_external_ids(self) -> None:
        connection = CalendarProviderConnection(
            connection_id="cconn_1",
            user_id="user-1",
            provider_id="dingtalk",
            status="connected",
            primary_calendar_id="cal-1",
        )
        existing_event = CalendarEvent(
            event_id="dingtalk:cconn_1:evt_1",
            user_id="user-1",
            title="Imported",
            start_at=datetime.now(),
            end_at=datetime.now() + timedelta(hours=1),
            timezone="UTC",
            source="dingtalk",
            source_device_id="cconn_1",
            external_event_identifier="evt_1",
        )
        event_dao = AsyncMock()
        event_dao.list_connection_source_events.return_value = [existing_event]
        event_dao.save = AsyncMock(return_value=True)
        service = ExternalCalendarSyncService(connection_dao=AsyncMock(), event_dao=event_dao)

        count = await service.deactivate_deleted_events(connection, {"evt_1"})

        self.assertEqual(count, 1)
        event_dao.list_connection_source_events.assert_awaited_once_with(
            "user-1",
            "dingtalk",
            "cconn_1",
            external_event_identifiers={"evt_1"},
        )
        event_dao.save.assert_awaited_once_with(existing_event)


class ExternalCalendarSyncImportedEventsTests(unittest.IsolatedAsyncioTestCase):
    """外部同步会插入、更新和停用导入的日历事件。"""

    def _make_connection(self, provider: str = "feishu") -> CalendarProviderConnection:
        return CalendarProviderConnection(
            connection_id="cconn_1",
            user_id="user-1",
            provider_id=provider,
            status="connected",
            external_user_id="ou_1",
            external_tenant_id="tenant-1",
            primary_calendar_id="cal-1",
        )

    async def test_upsert_inserts_new_active_event(self) -> None:
        connection = self._make_connection()
        event_dao = AsyncMock()
        event_dao.list_connection_source_events.return_value = []
        service = ExternalCalendarSyncService(connection_dao=AsyncMock(), event_dao=event_dao)

        touched = await service.upsert_imported_events(
            connection,
            [
                {
                    "event_id": "evt_new",
                    "title": "New",
                    "start_at": "2026-04-30T10:00:00Z",
                    "end_at": "2026-04-30T11:00:00Z",
                    "timezone": "UTC",
                    "status": "scheduled",
                }
            ],
        )

        self.assertEqual(touched, 1)
        event_dao.insert.assert_awaited_once()

    async def test_upsert_updates_existing_active_event(self) -> None:
        connection = self._make_connection()
        existing_event = CalendarEvent(
            event_id="feishu:cconn_1:evt_1",
            user_id="user-1",
            title="Imported",
            start_at=datetime.now(),
            end_at=datetime.now() + timedelta(hours=1),
            timezone="UTC",
            source="feishu",
            source_device_id="cconn_1",
            external_event_identifier="evt_1",
        )
        event_dao = AsyncMock()
        event_dao.list_connection_source_events.return_value = [existing_event]
        service = ExternalCalendarSyncService(connection_dao=AsyncMock(), event_dao=event_dao)

        await service.upsert_imported_events(
            connection,
            [
                {
                    "event_id": "evt_1",
                    "title": "Updated",
                    "start_at": "2026-04-30T12:00:00Z",
                    "end_at": "2026-04-30T13:00:00Z",
                    "timezone": "UTC",
                    "status": "scheduled",
                }
            ],
        )

        event_dao.save.assert_awaited_once_with(existing_event)
        self.assertEqual(existing_event.title, "Updated")

    async def test_upsert_marks_event_inactive_when_status_cancelled(self) -> None:
        connection = self._make_connection()
        existing_event = CalendarEvent(
            event_id="feishu:cconn_1:evt_1",
            user_id="user-1",
            title="Imported",
            start_at=datetime.now(),
            end_at=datetime.now() + timedelta(hours=1),
            timezone="UTC",
            source="feishu",
            source_device_id="cconn_1",
            external_event_identifier="evt_1",
        )
        event_dao = AsyncMock()
        event_dao.list_connection_source_events.return_value = [existing_event]
        service = ExternalCalendarSyncService(connection_dao=AsyncMock(), event_dao=event_dao)

        await service.upsert_imported_events(
            connection,
            [
                {
                    "event_id": "evt_1",
                    "status": "cancelled",
                }
            ],
        )

        event_dao.save.assert_awaited_once_with(existing_event)
        self.assertFalse(existing_event.is_active)

    async def test_deactivate_deleted_events_marks_event_inactive(self) -> None:
        connection = self._make_connection(provider="dingtalk")
        existing_event = CalendarEvent(
            event_id="dingtalk:cconn_1:evt_1",
            user_id="user-1",
            title="Imported",
            start_at=datetime.now(),
            end_at=datetime.now() + timedelta(hours=1),
            timezone="UTC",
            source="dingtalk",
            source_device_id="cconn_1",
            external_event_identifier="evt_1",
        )
        existing_event.is_active = True
        event_dao = AsyncMock()
        event_dao.list_connection_source_events.return_value = [existing_event]
        service = ExternalCalendarSyncService(connection_dao=AsyncMock(), event_dao=event_dao)

        await service.deactivate_deleted_events(connection, {"evt_1"})

        event_dao.save.assert_awaited_once_with(existing_event)
        self.assertFalse(existing_event.is_active)


if __name__ == "__main__":
    unittest.main()
