from __future__ import annotations

import asyncio
import unittest
from contextlib import asynccontextmanager
from datetime import UTC, date, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch
from config import constants

import services.calendar as calendar_module
from core.http.exceptions import AppHTTPException
from models.calendar import AppleCalendarContext, CalendarEvent, CalendarEventLink
from services.calendar import CalendarService
from services.calendar_domain.recurrence import serialize_recurrence
from services.calendar_recurrence import (
    normalize_recurrence_payload,
    validate_supported_recurrence_shape,
)


@asynccontextmanager
async def _fake_transaction_session(session=None):
    yield session or object()


class CalendarServiceTimezoneTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self._original_transaction_scope = calendar_module.transaction_scope
        calendar_module.transaction_scope = _fake_transaction_session

    def tearDown(self) -> None:
        calendar_module.transaction_scope = self._original_transaction_scope

    async def test_list_events_for_date_includes_cross_day_overlap(self) -> None:
        service = CalendarService()
        service._list_occurrence_views = AsyncMock(
            return_value=[
                {
                    "event_id": "evt_trip",
                    "title": "Trip",
                    "start_at": "2026-04-18T08:00:00+08:00",
                    "end_at": "2026-04-19T21:00:00+08:00",
                    "timezone": constants.DEFAULT_TIMEZONE,
                    "source": "ling",
                    "provider": "ling",
                }
            ]
        )

        events = await service.list_events_for_date(
            "user-1",
            date(2026, 4, 19),
            constants.DEFAULT_TIMEZONE,
        )

        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["event_id"], "evt_trip")

    async def test_find_conflicts_ignores_holiday_kind_events(self) -> None:
        service = CalendarService()
        service._list_occurrence_views = AsyncMock(
            return_value=[
                {
                    "event_id": "apple_holiday",
                    "title": "清明节",
                    "time_shape": constants.CALENDAR_TIME_SHAPE_SPAN,
                    "start_at": "2026-04-06T00:00:00+08:00",
                    "end_at": "2026-04-07T00:00:00+08:00",
                    "timezone": constants.DEFAULT_TIMEZONE,
                    "source": "apple",
                    "provider": "apple_local",
                    "metadata": {
                        "is_all_day": True,
                        "kind": "holiday",
                        "calendar_title": "中国大陆节假日",
                    },
                },
                {
                    "event_id": "evt_busy",
                    "title": "客户会议",
                    "time_shape": constants.CALENDAR_TIME_SHAPE_SPAN,
                    "start_at": "2026-04-06T14:30:00+08:00",
                    "end_at": "2026-04-06T15:30:00+08:00",
                    "timezone": constants.DEFAULT_TIMEZONE,
                    "source": "ling",
                    "provider": "ling",
                    "metadata": {},
                },
            ]
        )

        conflicts = await service.find_conflicts(
            "user-1",
            datetime(2026, 4, 6, 7, 0, tzinfo=UTC),
            datetime(2026, 4, 6, 8, 0, tzinfo=UTC),
            constants.DEFAULT_TIMEZONE,
        )

        self.assertEqual([item["event_id"] for item in conflicts], ["evt_busy"])

    async def test_find_conflicts_keeps_all_day_events_without_holiday_kind(self) -> None:
        service = CalendarService()
        service._list_occurrence_views = AsyncMock(
            return_value=[
                {
                    "event_id": "evt_trip",
                    "title": "全天出差",
                    "time_shape": constants.CALENDAR_TIME_SHAPE_SPAN,
                    "start_at": "2026-04-06T00:00:00+08:00",
                    "end_at": "2026-04-07T00:00:00+08:00",
                    "timezone": constants.DEFAULT_TIMEZONE,
                    "source": "ling",
                    "provider": "ling",
                    "metadata": {"is_all_day": True},
                },
                {
                    "event_id": "apple_regular_all_day",
                    "title": "公司全天活动",
                    "time_shape": constants.CALENDAR_TIME_SHAPE_SPAN,
                    "start_at": "2026-04-06T00:00:00+08:00",
                    "end_at": "2026-04-07T00:00:00+08:00",
                    "timezone": constants.DEFAULT_TIMEZONE,
                    "source": "apple",
                    "provider": "apple_local",
                    "metadata": {"is_all_day": True, "kind": "event"},
                }
            ]
        )

        conflicts = await service.find_conflicts(
            "user-1",
            datetime(2026, 4, 6, 7, 0, tzinfo=UTC),
            datetime(2026, 4, 6, 8, 0, tzinfo=UTC),
            constants.DEFAULT_TIMEZONE,
        )

        self.assertEqual(
            [item["event_id"] for item in conflicts],
            ["evt_trip", "apple_regular_all_day"],
        )

    async def test_find_conflicts_ignores_holiday_kind_even_when_not_all_day(self) -> None:
        service = CalendarService()
        service._list_occurrence_views = AsyncMock(
            return_value=[
                {
                    "event_id": "apple_solar_term",
                    "title": "立春",
                    "time_shape": constants.CALENDAR_TIME_SHAPE_SPAN,
                    "start_at": "2026-02-04T00:00:00+08:00",
                    "end_at": "2026-02-05T00:00:00+08:00",
                    "timezone": constants.DEFAULT_TIMEZONE,
                    "source": "apple",
                    "provider": "apple_local",
                    "metadata": {"kind": "holiday"},
                }
            ]
        )

        conflicts = await service.find_conflicts(
            "user-1",
            datetime(2026, 2, 4, 2, 0, tzinfo=UTC),
            datetime(2026, 2, 4, 3, 0, tzinfo=UTC),
            constants.DEFAULT_TIMEZONE,
        )

        self.assertEqual(conflicts, [])

    async def test_get_next_recurring_occurrence_after_returns_next_instance(self) -> None:
        service = CalendarService()
        service.event_dao.get_user_event = AsyncMock(
            return_value=SimpleNamespace(
                event_id="evt_series",
                recurrence_rule={"frequency": "daily"},
                recurrence_rrule="FREQ=DAILY",
            )
        )
        service._list_occurrence_views = AsyncMock(
            return_value=[
                {
                    "event_id": "evt_other",
                    "is_recurring": True,
                    "occurrence_start_at": "2026-04-07T08:00:00+08:00",
                },
                {
                    "event_id": "evt_series",
                    "is_recurring": True,
                    "occurrence_start_at": "2026-04-08T08:00:00+08:00",
                },
                {
                    "event_id": "evt_series",
                    "is_recurring": True,
                    "occurrence_start_at": "2026-04-07T08:00:00+08:00",
                },
            ]
        )

        occurrence = await service.get_next_recurring_occurrence_after(
            "user-1",
            "evt_series",
            datetime(2026, 4, 6, 0, 0, tzinfo=UTC),
        )

        self.assertEqual(occurrence["occurrence_start_at"], "2026-04-07T08:00:00+08:00")

    async def test_get_next_recurring_occurrence_after_ignores_non_recurring_event(self) -> None:
        service = CalendarService()
        service.event_dao.get_user_event = AsyncMock(
            return_value=SimpleNamespace(
                event_id="evt_once",
                recurrence_rule=None,
                recurrence_rrule=None,
            )
        )
        service._list_occurrence_views = AsyncMock()

        occurrence = await service.get_next_recurring_occurrence_after(
            "user-1",
            "evt_once",
            datetime(2026, 4, 6, 0, 0, tzinfo=UTC),
        )

        self.assertIsNone(occurrence)
        service._list_occurrence_views.assert_not_awaited()

    async def test_create_event_stores_utc_but_returns_event_timezone(self) -> None:
        service = CalendarService()
        service.event_dao.insert = AsyncMock()
        service.link_dao.get_by_event_id = AsyncMock(return_value=None)

        payload = {
            "title": "前往上海出行",
            "subtitle": "出行安排",
            "category": "travel",
            "start_at": "2026-04-06T15:00:00+08:00",
            "end_at": "2026-04-06T18:00:00+08:00",
            "timezone": constants.DEFAULT_TIMEZONE,
            "location": "上海",
        }

        event = await service.create_event("user-1", payload)

        stored = service.event_dao.insert.await_args.args[0]
        self.assertEqual(stored.start_at, datetime(2026, 4, 6, 7, 0, 0))
        self.assertEqual(stored.end_at, datetime(2026, 4, 6, 10, 0, 0))
        self.assertEqual(stored.timezone, constants.DEFAULT_TIMEZONE)

        self.assertEqual(event["start_at"], "2026-04-06T15:00:00+08:00")
        self.assertEqual(event["end_at"], "2026-04-06T18:00:00+08:00")
        self.assertEqual(event["timezone"], constants.DEFAULT_TIMEZONE)

    async def test_create_point_event_allows_equal_start_and_end(self) -> None:
        service = CalendarService()
        service.event_dao.insert = AsyncMock()
        service.link_dao.get_by_event_id = AsyncMock(return_value=None)

        event = await service.create_event(
            "user-1",
            {
                "title": "提醒给爸妈打电话",
                "time_shape": "point",
                "start_at": "2026-04-06T20:00:00+08:00",
                "end_at": "2026-04-06T20:00:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
            },
        )

        stored = service.event_dao.insert.await_args.args[0]
        self.assertEqual(stored.time_shape, "point")
        self.assertEqual(stored.start_at, stored.end_at)
        self.assertEqual(event["time_shape"], "point")
        self.assertEqual(event["start_at"], event["end_at"])

    async def test_serialize_event_rehydrates_local_time_from_utc_storage(self) -> None:
        service = CalendarService()
        service.link_dao.get_by_event_id = AsyncMock(return_value=None)

        class Event:
            event_id = "evt_1"
            user_id = "user-1"
            title = "晨会"
            subtitle = None
            category = "work"
            start_at = datetime(2026, 4, 6, 1, 30, 0)
            end_at = datetime(2026, 4, 6, 2, 0, 0)
            timezone = constants.DEFAULT_TIMEZONE
            location = None
            meeting_url = None
            attendees = []
            status = "scheduled"
            focus_mode_enabled = False
            extra_data = {}
            created_at = None
            updated_at = None

        serialized = await service.serialize_event(Event())

        self.assertEqual(serialized["start_at"], "2026-04-06T09:30:00+08:00")
        self.assertEqual(serialized["end_at"], "2026-04-06T10:00:00+08:00")
        self.assertEqual(serialized["timezone"], constants.DEFAULT_TIMEZONE)

    async def test_list_events_between_includes_point_event_at_window_start(self) -> None:
        service = CalendarService()
        event = CalendarEvent(
            event_id="evt_point",
            user_id="user-1",
            title="提醒",
            time_shape="point",
            start_at=datetime(2026, 4, 6, 12, 0, 0),
            end_at=datetime(2026, 4, 6, 12, 0, 0),
            timezone="UTC",
        )
        service.event_dao.list_user_events = AsyncMock(return_value=[event])
        service.link_dao.list_user_links = AsyncMock(return_value=[])
        service.context_dao.list_user_contexts = AsyncMock(return_value=[])

        events = await service.list_events_between(
            "user-1",
            datetime(2026, 4, 6, 12, 0, 0, tzinfo=UTC),
            datetime(2026, 4, 6, 13, 0, 0, tzinfo=UTC),
            "UTC",
        )

        self.assertEqual([item["event_id"] for item in events], ["evt_point"])
        self.assertEqual(events[0]["time_shape"], "point")

    async def test_list_events_between_hides_inactive_ling_events(self) -> None:
        service = CalendarService()
        active = CalendarEvent(
            event_id="evt_active",
            user_id="user-1",
            title="Active",
            start_at=datetime(2026, 4, 6, 12, 0, 0),
            end_at=datetime(2026, 4, 6, 13, 0, 0),
            timezone="UTC",
        )
        deleted = CalendarEvent(
            event_id="evt_deleted",
            user_id="user-1",
            title="Deleted",
            start_at=datetime(2026, 4, 6, 14, 0, 0),
            end_at=datetime(2026, 4, 6, 15, 0, 0),
            timezone="UTC",
            status="cancelled",
            is_active=False,
        )
        service.event_dao.list_user_events = AsyncMock(return_value=[active, deleted])
        service.link_dao.list_user_links = AsyncMock(return_value=[])
        service.context_dao.list_user_contexts = AsyncMock(return_value=[])

        events = await service.list_events_between(
            "user-1",
            datetime(2026, 4, 6, 0, 0, 0, tzinfo=UTC),
            datetime(2026, 4, 7, 0, 0, 0, tzinfo=UTC),
            "UTC",
        )

        self.assertEqual([item["event_id"] for item in events], ["evt_active"])

    async def test_delete_event_soft_deletes_ling_event(self) -> None:
        service = CalendarService()
        event = CalendarEvent(
            event_id="evt_1",
            user_id="user-1",
            title="Dinner",
            start_at=datetime(2026, 4, 6, 12, 0, 0),
            end_at=datetime(2026, 4, 6, 13, 0, 0),
            timezone="UTC",
            metadata={"markdown": "旧备注"},
        )
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.event_dao.save = AsyncMock()
        service.link_dao.get_by_event_id = AsyncMock(return_value=None)

        deleted = await service.delete_event(
            "user-1",
            event.event_id,
            delete_reason="不去了",
            metadata={"markdown": "用户取消"},
        )

        self.assertTrue(deleted["deleted"])
        self.assertEqual(deleted["event_id"], "evt_1")
        self.assertEqual(deleted["title"], "Dinner")
        self.assertEqual(deleted["start_at"], "2026-04-06T12:00:00+00:00")
        self.assertEqual(deleted["end_at"], "2026-04-06T13:00:00+00:00")
        self.assertEqual(deleted["status"], "cancelled")
        self.assertEqual(event.status, "cancelled")
        self.assertFalse(event.is_active)
        self.assertEqual(event.extra_data["delete_reason"], "不去了")
        self.assertEqual(event.extra_data["markdown"], "用户取消")
        self.assertIn("deleted_at", event.extra_data)
        service.event_dao.save.assert_awaited_once_with(event)

    async def test_update_event_rejects_deleted_ling_event(self) -> None:
        service = CalendarService()
        event = CalendarEvent(
            event_id="evt_deleted",
            user_id="user-1",
            title="Dinner",
            start_at=datetime(2026, 4, 6, 12, 0, 0),
            end_at=datetime(2026, 4, 6, 13, 0, 0),
            timezone="UTC",
            status=constants.CALENDAR_STATUS_CANCELLED,
            is_active=False,
        )
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.event_dao.save = AsyncMock()

        with self.assertRaises(AppHTTPException) as ctx:
            await service.update_event("user-1", event.event_id, {"title": "New title"})

        self.assertEqual(ctx.exception.status_code, 410)
        self.assertEqual(ctx.exception.error_code, "CALENDAR_EVENT_DELETED")
        service.event_dao.save.assert_not_awaited()

    async def test_complete_event_rejects_deleted_ling_event(self) -> None:
        service = CalendarService()
        event = CalendarEvent(
            event_id="evt_deleted",
            user_id="user-1",
            title="Dinner",
            start_at=datetime(2026, 4, 6, 12, 0, 0),
            end_at=datetime(2026, 4, 6, 13, 0, 0),
            timezone="UTC",
            status=constants.CALENDAR_STATUS_CANCELLED,
            is_active=False,
        )
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.event_dao.save = AsyncMock()

        with self.assertRaises(AppHTTPException) as ctx:
            await service.complete_event("user-1", event.event_id)

        self.assertEqual(ctx.exception.status_code, 410)
        self.assertEqual(ctx.exception.error_code, "CALENDAR_EVENT_DELETED")
        service.event_dao.save.assert_not_awaited()

    async def test_delete_event_rejects_already_deleted_ling_event(self) -> None:
        service = CalendarService()
        event = CalendarEvent(
            event_id="evt_deleted",
            user_id="user-1",
            title="Dinner",
            start_at=datetime(2026, 4, 6, 12, 0, 0),
            end_at=datetime(2026, 4, 6, 13, 0, 0),
            timezone="UTC",
            status=constants.CALENDAR_STATUS_CANCELLED,
            is_active=False,
        )
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.event_dao.save = AsyncMock()

        with self.assertRaises(AppHTTPException) as ctx:
            await service.delete_event("user-1", event.event_id)

        self.assertEqual(ctx.exception.status_code, 410)
        self.assertEqual(ctx.exception.error_code, "CALENDAR_EVENT_DELETED")
        service.event_dao.save.assert_not_awaited()

    async def test_complete_event_marks_event_completed_with_metadata(self) -> None:
        service = CalendarService()
        event = CalendarEvent(
            event_id="evt_1",
            user_id="user-1",
            title="Interview",
            start_at=datetime(2026, 4, 6, 12, 0, 0),
            end_at=datetime(2026, 4, 6, 13, 0, 0),
            timezone="UTC",
            metadata={"markdown": "旧备注"},
        )
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.event_dao.save = AsyncMock()
        service.link_dao.get_by_event_id = AsyncMock(return_value=None)

        completed = await service.complete_event(
            "user-1",
            event.event_id,
            completed_at="2026-04-06T21:00:00+08:00",
            result_summary="结果不错",
        )

        self.assertEqual(completed["status"], "completed")
        self.assertEqual(event.status, "completed")
        self.assertTrue(event.is_active)
        self.assertEqual(event.extra_data["completed_at"], "2026-04-06T21:00:00+08:00")
        self.assertEqual(event.extra_data["completed_by"], "agent")
        self.assertEqual(event.extra_data["outcome"], "done")
        self.assertEqual(event.extra_data["result_summary"], "结果不错")

    async def test_complete_event_occurrence_scope_only_overrides_one_occurrence(self) -> None:
        service = CalendarService()
        master = _daily_recurring_event()
        service.event_dao.get_user_event = AsyncMock(return_value=master)
        service.event_dao.get_occurrence_override = AsyncMock(return_value=None)
        service.event_dao.insert = AsyncMock()
        service.event_dao.save = AsyncMock()
        service.event_dao.list_user_events = AsyncMock(return_value=[master])
        service.link_dao.get_by_event_id = AsyncMock(return_value=None)
        service.link_dao.list_user_links = AsyncMock(return_value=[])
        service.context_dao.list_user_contexts = AsyncMock(return_value=[])

        completed = await service.complete_event(
            "user-1",
            master.event_id,
            scope="occurrence",
            occurrence_start_time="2026-04-06T09:00:00+08:00",
            result_summary="这次已完成",
        )

        override = service.event_dao.insert.await_args.args[0]
        self.assertEqual(master.status, "scheduled")
        self.assertEqual(override.status, "completed")
        self.assertEqual(override.extra_data["result_summary"], "这次已完成")
        self.assertIn("metadata", override.extra_data["_override_fields"])
        self.assertIn("status", override.extra_data["_override_fields"])
        self.assertEqual(completed["status"], "completed")


class CalendarServiceRecurringTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self._original_transaction_scope = calendar_module.transaction_scope
        calendar_module.transaction_scope = _fake_transaction_session

    def tearDown(self) -> None:
        calendar_module.transaction_scope = self._original_transaction_scope

    async def test_create_event_persists_recurrence_metadata(self) -> None:
        service = CalendarService()
        service.event_dao.insert = AsyncMock()
        service.link_dao.get_by_event_id = AsyncMock(return_value=None)

        event = await service.create_event(
            "user-1",
            {
                "title": "每日站会",
                "start_at": "2026-04-05T09:00:00+08:00",
                "end_at": "2026-04-05T09:30:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "recurrence": {
                    "frequency": "daily",
                    "interval": 1,
                    "raw_rrule": "FREQ=DAILY",
                },
            },
        )

        stored = service.event_dao.insert.await_args.args[0]
        self.assertEqual(stored.recurrence_rule, {"frequency": "daily", "interval": 1})
        self.assertEqual(stored.recurrence_rrule, "FREQ=DAILY")
        self.assertEqual(stored.series_id, stored.event_id)
        self.assertTrue(event["is_recurring"])
        self.assertEqual(event["recurrence"]["frequency"], "daily")
        self.assertEqual(event["recurrence"]["raw_rrule"], "FREQ=DAILY")

    async def test_create_event_rejects_daily_by_weekday_recurrence(self) -> None:
        service = CalendarService()
        service.event_dao.insert = AsyncMock()
        service.link_dao.get_by_event_id = AsyncMock(return_value=None)

        with self.assertRaises(AppHTTPException) as ctx:
            await service.create_event(
                "user-1",
                {
                    "title": "工作日站会",
                    "start_at": "2026-04-21T09:00:00+08:00",
                    "end_at": "2026-04-21T09:30:00+08:00",
                    "timezone": constants.DEFAULT_TIMEZONE,
                    "recurrence": {
                        "frequency": "daily",
                        "interval": 1,
                        "count": 5,
                        "by_weekday": ["TU", "WE", "TH", "FR"],
                    },
                },
            )

        self.assertEqual(ctx.exception.status_code, 422)
        self.assertEqual(ctx.exception.detail, "daily recurrence does not support by_weekday")

    async def test_update_event_rejects_daily_by_weekday_recurrence(self) -> None:
        service = CalendarService()
        event = _daily_recurring_event()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.event_dao.list_user_events = AsyncMock(return_value=[])
        service.event_dao.save = AsyncMock()

        with self.assertRaises(AppHTTPException) as ctx:
            await service.update_event(
                "user-1",
                event.event_id,
                {
                    "recurrence": {
                        "frequency": "daily",
                        "interval": 1,
                        "by_weekday": ["MO", "WE"],
                    }
                },
            )

        self.assertEqual(ctx.exception.status_code, 422)
        self.assertEqual(ctx.exception.detail, "daily recurrence does not support by_weekday")

    async def test_update_event_metadata_only_updates_metadata(self) -> None:
        service = CalendarService()
        event = CalendarEvent(
            event_id="evt_1",
            user_id="user-1",
            title="Interview",
            start_at=datetime(2026, 4, 6, 12, 0, 0),
            end_at=datetime(2026, 4, 6, 13, 0, 0),
            timezone="UTC",
            metadata={"markdown": "旧备注"},
        )
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.event_dao.list_user_events = AsyncMock(return_value=[])
        service.event_dao.save = AsyncMock()
        service.link_dao.get_by_event_id = AsyncMock(return_value=None)

        updated = await service.update_event(
            "user-1",
            event.event_id,
            {
                "metadata": {
                    "markdown": "旧备注",
                    "schedule_preparation": [
                        {
                            "title": "会议准备文档",
                            "path": "/app/agents/user-1/agent-1/reports/prep.md",
                        }
                    ],
                },
            },
        )

        self.assertEqual(
            updated["metadata"]["schedule_preparation"][0]["title"],
            "会议准备文档",
        )

    def test_sync_safe_recurrence_whitelist_round_trips_rrule(self) -> None:
        cases = [
            (
                {"frequency": "daily", "interval": 1, "count": 4},
                "FREQ=DAILY;COUNT=4",
            ),
            (
                {"frequency": "weekly", "interval": 1, "by_weekday": ["TU", "TH"]},
                "FREQ=WEEKLY;BYDAY=TU,TH",
            ),
            (
                {"frequency": "monthly", "interval": 1, "by_month_day": [15]},
                "FREQ=MONTHLY;BYMONTHDAY=15",
            ),
            (
                {"frequency": "yearly", "interval": 1, "by_month": [7], "by_month_day": [9]},
                "FREQ=YEARLY;BYMONTHDAY=9;BYMONTH=7",
            ),
        ]

        for payload, expected_rrule in cases:
            normalized, raw_rrule = normalize_recurrence_payload(payload)
            validate_supported_recurrence_shape(normalized)
            reparsed_normalized, reparsed_rrule = normalize_recurrence_payload(
                {"raw_rrule": raw_rrule}
            )

            self.assertEqual(raw_rrule, expected_rrule)
            self.assertEqual(reparsed_rrule, expected_rrule)
            self.assertEqual(reparsed_normalized, normalized)

    def test_serialize_recurrence_fills_missing_weekdays_from_rrule(self) -> None:
        service = CalendarService()
        event = CalendarEvent(
            event_id="evt_weekly",
            user_id="user-1",
            title="不吃早餐提醒",
            start_at=datetime(2026, 5, 10, 16, 0, 0),
            end_at=datetime(2026, 5, 10, 16, 15, 0),
            timezone=constants.DEFAULT_TIMEZONE,
            recurrence_rule={"frequency": "weekly", "interval": 1},
            recurrence_rrule="FREQ=WEEKLY;BYDAY=MO,WE,FR",
            series_id="evt_weekly",
        )

        recurrence = serialize_recurrence(
            event,
            get_zone=service._get_zone,
            to_local=service._to_local,
        )

        self.assertEqual(recurrence["frequency"], "weekly")
        self.assertEqual(recurrence["interval"], 1)
        self.assertEqual(recurrence["by_weekday"], ["MO", "WE", "FR"])
        self.assertEqual(recurrence["raw_rrule"], "FREQ=WEEKLY;BYDAY=MO,WE,FR")

    async def test_update_event_occurrence_scope_creates_override(self) -> None:
        service = CalendarService()
        master = _daily_recurring_event()
        service.event_dao.get_user_event = AsyncMock(return_value=master)
        service.event_dao.get_occurrence_override = AsyncMock(side_effect=[None, None])
        service.event_dao.insert = AsyncMock()
        service.event_dao.save = AsyncMock()
        service.event_dao.list_user_events = AsyncMock(return_value=[master])
        service.link_dao.get_by_event_id = AsyncMock(return_value=None)
        service.link_dao.list_user_links = AsyncMock(return_value=[])
        service.context_dao.list_user_contexts = AsyncMock(return_value=[])

        updated = await service.update_event(
            "user-1",
            master.event_id,
            {
                "scope": "occurrence",
                "occurrence_start_time": "2026-04-06T09:00:00+08:00",
                "title": "改期站会",
                "start_at": "2026-04-06T10:00:00+08:00",
                "end_at": "2026-04-06T11:00:00+08:00",
            },
        )

        override = service.event_dao.insert.await_args.args[0]
        self.assertEqual(override.recurrence_parent_event_id, master.event_id)
        self.assertEqual(override.occurrence_start_at, datetime(2026, 4, 6, 1, 0, 0))
        self.assertIn("2026-04-06T01:00:00+00:00", master.recurrence_exdates)
        self.assertEqual(updated["title"], "改期站会")
        self.assertEqual(updated["start_at"], "2026-04-06T10:00:00+08:00")
        self.assertEqual(updated["occurrence_start_at"], "2026-04-06T09:00:00+08:00")
        self.assertTrue(updated["is_occurrence_override"])

    async def test_update_recurring_series_reschedules_nearest_upcoming_occurrence(self) -> None:
        service = CalendarService()
        master = _daily_recurring_event()
        service.event_dao.get_user_event = AsyncMock(return_value=master)
        service.event_dao.list_user_events = AsyncMock(return_value=[master])
        service.event_dao.save = AsyncMock()
        service.link_dao.get_by_event_id = AsyncMock(return_value=None)
        service.link_dao.list_user_links = AsyncMock(return_value=[])
        service.context_dao.list_user_contexts = AsyncMock(return_value=[])

        with (
            patch(
                "services.calendar.get_local_now",
                return_value=datetime(2026, 4, 7, 0, 0, 0, tzinfo=UTC),
            )
        ):
            updated = await service.update_event(
                "user-1",
                master.event_id,
                {"title": "新的每日站会"},
            )

        self.assertEqual(updated["event_id"], master.event_id)
        self.assertEqual(updated["title"], "新的每日站会")

    async def test_delete_event_occurrence_scope_adds_exdate_and_removes_override(self) -> None:
        service = CalendarService()
        master = _daily_recurring_event()
        override = CalendarEvent(
            event_id="evt_override",
            user_id="user-1",
            title="改期站会",
            start_at=datetime(2026, 4, 6, 2, 0, 0),
            end_at=datetime(2026, 4, 6, 3, 0, 0),
            timezone=constants.DEFAULT_TIMEZONE,
            series_id=master.event_id,
            recurrence_parent_event_id=master.event_id,
            occurrence_start_at=datetime(2026, 4, 6, 1, 0, 0),
            is_occurrence_override=True,
            metadata={"_override_fields": ["title", "start_at", "end_at"]},
        )
        service.event_dao.get_user_event = AsyncMock(return_value=master)
        service.event_dao.get_occurrence_override = AsyncMock(return_value=override)
        service.event_dao.save = AsyncMock()
        service.event_dao.delete_by_id = AsyncMock()
        service.event_dao.list_user_events = AsyncMock(return_value=[master])
        service.link_dao.list_user_links = AsyncMock(return_value=[])
        service.context_dao.list_user_contexts = AsyncMock(return_value=[])

        deleted = await service.delete_event(
            "user-1",
            master.event_id,
            scope="occurrence",
            occurrence_start_time="2026-04-06T09:00:00+08:00",
        )

        self.assertTrue(deleted["deleted"])
        self.assertEqual(deleted["scope"], "occurrence")
        self.assertEqual(deleted["title"], "改期站会")
        self.assertEqual(deleted["start_at"], "2026-04-06T10:00:00+08:00")
        self.assertEqual(deleted["end_at"], "2026-04-06T11:00:00+08:00")
        self.assertEqual(deleted["status"], "cancelled")
        self.assertIn("2026-04-06T01:00:00+00:00", master.recurrence_exdates)
        service.event_dao.delete_by_id.assert_awaited_once_with(
            CalendarEvent,
            override.event_id,
        )

    async def test_delete_recurring_occurrence_reschedules_next_existing_occurrence(self) -> None:
        service = CalendarService()
        master = _daily_recurring_event()
        service.event_dao.get_user_event = AsyncMock(return_value=master)
        service.event_dao.get_occurrence_override = AsyncMock(return_value=None)
        service.event_dao.save = AsyncMock()
        service.event_dao.delete_by_id = AsyncMock()
        service.event_dao.list_user_events = AsyncMock(return_value=[master])
        service.link_dao.list_user_links = AsyncMock(return_value=[])
        service.context_dao.list_user_contexts = AsyncMock(return_value=[])

        with (
            patch(
                "services.calendar.get_local_now",
                return_value=datetime(2026, 4, 6, 0, 0, 0, tzinfo=UTC),
            )
        ):
            deleted = await service.delete_event(
                "user-1",
                master.event_id,
                scope="occurrence",
                occurrence_start_time="2026-04-06T09:00:00+08:00",
            )

        self.assertTrue(deleted["deleted"])
        self.assertEqual(deleted["event_id"], master.event_id)


class CalendarServiceAppleImportTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self._original_transaction_scope = calendar_module.transaction_scope
        calendar_module.transaction_scope = _fake_transaction_session

    def tearDown(self) -> None:
        calendar_module.transaction_scope = self._original_transaction_scope

    async def test_normalize_imported_apple_event_does_not_mark_non_recurring_event_as_recurring(
        self,
    ) -> None:
        service = CalendarService()

        normalized = service._normalize_imported_apple_event(
            user_id="user-1",
            raw={
                "identifier": "apple-single-1",
                "calendarIdentifier": "calendar-1",
                "calendarItemIdentifier": "item-single-1",
                "title": "One-off Apple Event",
                "startAt": "2026-04-19T09:00:00+08:00",
                "endAt": "2026-04-19T10:00:00+08:00",
            },
            timezone=constants.DEFAULT_TIMEZONE,
            device_id="device-a",
        )

        assert normalized is not None
        self.assertFalse(normalized["is_recurring"])
        self.assertIsNone(normalized["recurrence"])

    async def test_imported_apple_event_fixed_offset_timezone_uses_context_timezone(
        self,
    ) -> None:
        service = CalendarService()

        normalized = service._normalize_calendar_context_events(
            user_id="user-1",
            events=[
                {
                    **_apple_import_event("apple-1"),
                    "timezone": "GMT+0800",
                    "startAt": "2026-04-06T09:00:00+08:00",
                    "endAt": "2026-04-06T09:30:00+08:00",
                    "occurrenceDate": "2026-04-06T09:00:00+08:00",
                }
            ],
            timezone=constants.DEFAULT_TIMEZONE,
            device_id="device-a",
        )

        self.assertEqual(len(normalized), 1)
        self.assertEqual(normalized[0]["timezone"], constants.DEFAULT_TIMEZONE)
        self.assertEqual(normalized[0]["start_at"], "2026-04-06T09:00:00+08:00")

    async def test_imported_apple_event_id_is_derived_from_storage_payload(
        self,
    ) -> None:
        service = CalendarService()

        first = _apple_storage_payload(
            service,
            user_id="user-a",
            raw={
                **_apple_import_event("apple-1"),
                "calendarItemIdentifier": "item-1",
            },
        )
        same = _apple_storage_payload(
            service,
            user_id="user-a",
            raw={
                **_apple_import_event("apple-1"),
                "calendarItemIdentifier": "item-1",
            },
        )
        other_user = _apple_storage_payload(
            service,
            user_id="user-b",
            raw={
                **_apple_import_event("apple-1"),
                "calendarItemIdentifier": "item-1",
            },
        )

        self.assertEqual(first["event_id"], same["event_id"])
        self.assertNotEqual(first["event_id"], other_user["event_id"])
        self.assertLessEqual(len(first["event_id"]), 128)

    async def test_imported_apple_recurring_occurrence_does_not_persist_as_recurrence_master(
        self,
    ) -> None:
        service = CalendarService()

        payload = _apple_storage_payload(
            service,
            user_id="user-1",
            raw={
                **_apple_import_event("apple-1"),
                "calendarItemIdentifier": "item-1",
            },
        )

        self.assertIsNone(payload["recurrence_rule"])
        self.assertIsNone(payload["recurrence_rrule"])
        self.assertEqual(
            payload["metadata"]["_apple_recurrence"]["frequency"],
            "daily",
        )
        self.assertEqual(payload["metadata"]["_apple_recurrence_rrule"], "FREQ=DAILY")

    async def test_imported_apple_event_id_uses_actual_instance_start(
        self,
    ) -> None:
        service = CalendarService()

        first = _apple_storage_payload(
            service,
            user_id="user-1",
            raw={
                **_apple_import_event("apple-1"),
                "startAt": "2026-04-30T00:00:00Z",
                "endAt": "2026-04-30T00:30:00Z",
                "occurrenceDate": "2026-04-30T00:00:00Z",
            },
        )
        later = _apple_storage_payload(
            service,
            user_id="user-1",
            raw={
                **_apple_import_event("apple-1"),
                "startAt": "2026-06-20T00:00:00Z",
                "endAt": "2026-06-20T00:30:00Z",
                "occurrenceDate": "2026-04-30T00:00:00Z",
            },
        )

        self.assertNotEqual(first["event_id"], later["event_id"])
        self.assertTrue(later["event_id"].endswith("2026-06-20T00:00:00+00:00"))
        self.assertEqual(later["occurrence_start_at"], datetime(2026, 6, 20, 0, 0, 0))

    async def test_imported_apple_event_id_includes_item_identity(
        self,
    ) -> None:
        service = CalendarService()

        first = _apple_storage_payload(
            service,
            user_id="user-1",
            raw={
                **_apple_import_event("apple-1"),
                "calendarItemIdentifier": "item-1",
            },
        )
        second = _apple_storage_payload(
            service,
            user_id="user-1",
            raw={
                **_apple_import_event("apple-2"),
                "calendarItemIdentifier": "item-2",
            },
        )

        self.assertNotEqual(first["event_id"], second["event_id"])

    async def test_imported_apple_event_id_ignores_mutable_event_fields(
        self,
    ) -> None:
        service = CalendarService()

        original = _apple_storage_payload(
            service,
            user_id="user-1",
            raw={
                **_apple_import_event("apple-1"),
                "title": "Original Title",
                "endAt": "2026-04-06T01:30:00Z",
            },
        )
        changed = _apple_storage_payload(
            service,
            user_id="user-1",
            raw={
                **_apple_import_event("apple-1"),
                "title": "Renamed Title",
                "endAt": "2026-04-06T02:00:00Z",
                "location": "Office",
            },
        )

        self.assertEqual(original["event_id"], changed["event_id"])

    async def test_upsert_apple_recurring_instances_uses_actual_start_identity(
        self,
    ) -> None:
        service = CalendarService()
        stored_events: list[CalendarEvent] = []

        async def _list_user_source_events(
            _user_id: str,
            source: str,
            **kwargs,
        ) -> list[CalendarEvent]:
            return [
                event
                for event in stored_events
                if getattr(event, "source", "ling") == source
            ]

        async def _insert_event(event: CalendarEvent, **kwargs) -> None:
            stored_events.append(event)

        service.event_dao.list_user_source_events = AsyncMock(
            side_effect=_list_user_source_events,
        )
        service.event_dao.insert = AsyncMock(side_effect=_insert_event)
        service.event_dao.save = AsyncMock(return_value=True)
        service.link_dao.list_user_links = AsyncMock(return_value=[])

        normalized = service._normalize_calendar_context_events(
            user_id="user-1",
            events=[
                {
                    **_apple_import_event("apple-1"),
                    "startAt": "2026-04-30T00:00:00Z",
                    "endAt": "2026-04-30T00:30:00Z",
                    "occurrenceDate": "2026-04-30T00:00:00Z",
                },
                {
                    **_apple_import_event("apple-1"),
                    "startAt": "2026-06-20T00:00:00Z",
                    "endAt": "2026-06-20T00:30:00Z",
                    "occurrenceDate": "2026-04-30T00:00:00Z",
                },
            ],
            timezone="UTC",
            device_id="device-a",
        )

        await service._upsert_apple_events_from_context(
            user_id="user-1",
            device_id="device-a",
            window_start=datetime(2026, 4, 1, 0, 0, 0),
            window_end=datetime(2026, 7, 1, 0, 0, 0),
            events=normalized,
        )

        self.assertEqual(len(stored_events), 2)
        self.assertEqual(
            {event.occurrence_start_at for event in stored_events},
            {
                datetime(2026, 4, 30, 0, 0, 0),
                datetime(2026, 6, 20, 0, 0, 0),
            },
        )
        self.assertEqual(len({event.event_id for event in stored_events}), 2)

    async def test_imported_apple_event_without_iana_timezone_is_skipped(
        self,
    ) -> None:
        service = CalendarService()

        normalized = service._normalize_calendar_context_events(
            user_id="user-1",
            events=[
                {
                    **_apple_import_event("apple-1"),
                    "timezone": "GMT+0800",
                    "startAt": "2026-04-06T09:00:00+08:00",
                    "endAt": "2026-04-06T09:30:00+08:00",
                }
            ],
            timezone=None,
            device_id="device-a",
        )

        self.assertEqual(normalized, [])

    async def test_list_imported_apple_events_between_reads_imported_rows(self) -> None:
        service = CalendarService()
        stored_events: list[CalendarEvent] = []

        async def _list_user_events(_user_id: str) -> list[CalendarEvent]:
            return list(stored_events)

        async def _list_user_source_events(
            _user_id: str,
            source: str,
            **kwargs,
        ) -> list[CalendarEvent]:
            return [
                event
                for event in stored_events
                if getattr(event, "source", "ling") == source
            ]

        async def _insert_event(event: CalendarEvent, **kwargs) -> None:
            stored_events.append(event)

        async def _save_event(_event: CalendarEvent, **kwargs) -> bool:
            return True

        service.event_dao.list_user_events = AsyncMock(side_effect=_list_user_events)
        service.event_dao.list_user_source_events = AsyncMock(side_effect=_list_user_source_events)
        service.event_dao.insert = AsyncMock(side_effect=_insert_event)
        service.event_dao.save = AsyncMock(side_effect=_save_event)
        service.link_dao.list_user_links = AsyncMock(return_value=[])
        service.context_dao.list_user_contexts = AsyncMock(
            return_value=[
                AppleCalendarContext(
                    context_id="ctx_1",
                    user_id="user-1",
                    device_id="device-a",
                    permission_state="granted",
                    window_start=datetime(2026, 4, 1, 0, 0, 0),
                    window_end=datetime(2026, 5, 1, 0, 0, 0),
                    events=[],
                ),
            ]
        )
        normalized_events = service._normalize_calendar_context_events(
            user_id="user-1",
            events=[_apple_import_event("apple-1")],
            timezone="UTC",
            device_id="device-a",
        )
        await service._upsert_apple_events_from_context(
            user_id="user-1",
            device_id="device-a",
            window_start=datetime(2026, 4, 1, 0, 0, 0),
            window_end=datetime(2026, 5, 1, 0, 0, 0),
            events=normalized_events,
        )

        imported = await service.list_imported_apple_events_between(
            "user-1",
            datetime(2026, 4, 6, 0, 0, 0, tzinfo=UTC),
            datetime(2026, 4, 7, 0, 0, 0, tzinfo=UTC),
            timezone="UTC",
        )

        self.assertEqual(len(imported["events"]), 1)
        event = imported["events"][0]
        self.assertEqual(event["source"], "apple")
        self.assertEqual(event["provider"], "apple_local")
        self.assertFalse(event["is_mutable"])
        self.assertTrue(event["is_recurring"])
        self.assertEqual(event["series_id"], "item-1")
        self.assertEqual(event["recurrence"]["frequency"], "daily")
        self.assertEqual(event["recurrence"]["raw_rrules"], ["FREQ=DAILY"])
        self.assertTrue(imported["coverage_complete"])

    async def test_save_calendar_context_for_new_user_does_not_touch_other_users_ling_events(
        self,
    ) -> None:
        service = CalendarService()
        user_a_ling_event = CalendarEvent(
            event_id="evt_ling_a",
            user_id="user-a",
            title="User A Ling Event",
            start_at=datetime(2026, 4, 6, 1, 0, 0),
            end_at=datetime(2026, 4, 6, 2, 0, 0),
            timezone=constants.DEFAULT_TIMEZONE,
            source="ling",
            series_id="evt_ling_a",
        )
        user_b_events: list[CalendarEvent] = []
        saved_contexts: list[AppleCalendarContext] = []

        async def _list_user_source_events(
            user_id: str,
            source: str,
            **kwargs,
        ) -> list[CalendarEvent]:
            if user_id == "user-b" and source == "apple":
                return [event for event in user_b_events if event.source == "apple"]
            return []

        async def _insert_event(event: CalendarEvent, **kwargs) -> None:
            user_b_events.append(event)

        async def _save_event(_event: CalendarEvent, **kwargs) -> bool:
            return True

        async def _insert_context(context: AppleCalendarContext, **kwargs) -> None:
            saved_contexts.append(context)

        service.event_dao.list_user_source_events = AsyncMock(
            side_effect=_list_user_source_events,
        )
        service.event_dao.insert = AsyncMock(side_effect=_insert_event)
        service.event_dao.save = AsyncMock(side_effect=_save_event)
        service.link_dao.list_user_links = AsyncMock(return_value=[])
        service.context_dao.get_latest_by_device = AsyncMock(return_value=None)
        service.context_dao.insert = AsyncMock(side_effect=_insert_context)
        service._cleanup_synced_calendar_reminders_for_user = AsyncMock()
        calendar_module.transaction_scope = _fake_transaction_session

        payload = await service.save_calendar_context(
            "user-b",
            {
                "device_id": "device-1",
                "window_start": "2026-04-01T00:00:00Z",
                "window_end": "2026-05-01T00:00:00Z",
                "timezone": "UTC",
                "permission_state": "granted",
                "events": [_apple_import_event("apple-1")],
            },
        )

        self.assertEqual(payload["context_id"], saved_contexts[0].context_id)
        self.assertEqual(user_a_ling_event.user_id, "user-a")
        self.assertEqual(user_a_ling_event.source, "ling")
        self.assertEqual(len(user_b_events), 1)
        self.assertEqual(user_b_events[0].user_id, "user-b")
        self.assertEqual(user_b_events[0].source, "apple")
        self.assertEqual(user_b_events[0].source_device_id, "device-1")
        self.assertEqual(user_b_events[0].title, "Apple Daily Standup")
        self.assertEqual(saved_contexts[0].user_id, "user-b")
        service._cleanup_synced_calendar_reminders_for_user.assert_awaited_once_with(
            "user-b",
        )

    async def test_save_calendar_context_serializes_same_device_imports(
        self,
    ) -> None:
        service = CalendarService()
        active_upserts = 0
        max_active_upserts = 0

        async def _upsert_apple_events_from_context(**kwargs) -> dict[str, object]:
            nonlocal active_upserts, max_active_upserts
            active_upserts += 1
            max_active_upserts = max(max_active_upserts, active_upserts)
            await asyncio.sleep(0.01)
            active_upserts -= 1
            return {
                "did_mutate_events": False,
                "inserted_count": 0,
                "updated_count": 0,
                "deactivated_count": 0,
            }

        service._upsert_apple_events_from_context = AsyncMock(
            side_effect=_upsert_apple_events_from_context,
        )
        service.context_dao.get_latest_by_device = AsyncMock(return_value=None)
        service.context_dao.insert = AsyncMock(return_value=None)
        service._cleanup_synced_calendar_reminders_for_user = AsyncMock()

        payload = {
            "device_id": "device-1",
            "window_start": "2026-04-01T00:00:00Z",
            "window_end": "2026-05-01T00:00:00Z",
            "timezone": "UTC",
            "permission_state": "granted",
            "events": [],
        }

        await asyncio.gather(
            service.save_calendar_context("user-1", payload),
            service.save_calendar_context("user-1", payload),
        )

        self.assertEqual(service._upsert_apple_events_from_context.await_count, 2)
        self.assertEqual(max_active_upserts, 1)

    async def test_upsert_event_link_keeps_ling_synced_reminders(self) -> None:
        service = CalendarService()
        service.link_dao.get_by_event_id = AsyncMock(return_value=None)
        service.link_dao.insert = AsyncMock()
        service._deactivate_linked_apple_rows = AsyncMock()
        service._cleanup_synced_calendar_reminders_for_event = AsyncMock()

        result = await service.upsert_event_link(
            "user-1",
            {
                "event_id": "evt_ling_1",
                "device_id": "device-1",
                "calendar_identifier": "calendar-1",
                "event_identifier": "apple-event-1",
                "sync_state": "linked",
                "metadata": {
                    "calendar_item_identifier": "apple-item-1",
                },
            },
        )

        self.assertEqual(result["event_id"], "evt_ling_1")
        service.link_dao.insert.assert_awaited_once()
        service._deactivate_linked_apple_rows.assert_awaited_once()
        service._cleanup_synced_calendar_reminders_for_event.assert_not_awaited()

    async def test_list_managed_apple_links_only_returns_ling_links_for_device(self) -> None:
        service = CalendarService()
        ling_event = CalendarEvent(
            event_id="evt_ling_1",
            user_id="user-1",
            title="Ling Event",
            start_at=datetime(2026, 4, 6, 1, 0, 0),
            end_at=datetime(2026, 4, 6, 2, 0, 0),
            timezone=constants.DEFAULT_TIMEZONE,
            source="ling",
            series_id="evt_ling_1",
            recurrence_rule={"frequency": "daily", "interval": 1},
            recurrence_rrule="FREQ=DAILY",
        )
        imported_event = CalendarEvent(
            event_id="apple:item-1:2026-04-06",
            user_id="user-1",
            title="Imported Apple Event",
            start_at=datetime(2026, 4, 6, 1, 0, 0),
            end_at=datetime(2026, 4, 6, 2, 0, 0),
            timezone=constants.DEFAULT_TIMEZONE,
            source="apple",
            series_id="apple:item-1",
        )
        ling_link = CalendarEventLink(
            link_id="clink_1",
            event_id="evt_ling_1",
            user_id="user-1",
            device_id="device-1",
            calendar_identifier="calendar-1",
            event_identifier="event-1",
            metadata={"calendar_item_identifier": "item-1"},
        )
        imported_link = CalendarEventLink(
            link_id="clink_2",
            event_id="apple:item-1:2026-04-06",
            user_id="user-1",
            device_id="device-1",
            calendar_identifier="calendar-1",
            event_identifier="event-2",
        )
        service.link_dao.list_user_device_links = AsyncMock(
            return_value=[ling_link, imported_link],
        )
        service.event_dao.list_user_events = AsyncMock(
            return_value=[ling_event, imported_event],
        )

        payload = await service.list_managed_apple_links("user-1", "device-1")

        self.assertEqual(payload["device_id"], "device-1")
        self.assertEqual(len(payload["items"]), 1)
        self.assertEqual(payload["items"][0]["event_id"], "evt_ling_1")
        self.assertTrue(payload["items"][0]["is_recurring"])
        self.assertEqual(payload["items"][0]["calendar_item_identifier"], "item-1")



def _daily_recurring_event() -> CalendarEvent:
    return CalendarEvent(
        event_id="evt_series",
        user_id="user-1",
        title="每日站会",
        start_at=datetime(2026, 4, 5, 1, 0, 0),
        end_at=datetime(2026, 4, 5, 1, 30, 0),
        timezone=constants.DEFAULT_TIMEZONE,
        series_id="evt_series",
        recurrence_rule={"frequency": "daily", "interval": 1},
        recurrence_rrule="FREQ=DAILY",
    )


def _apple_import_event(identifier: str) -> dict[str, object]:
    return {
        "identifier": identifier,
        "calendarIdentifier": "calendar-1",
        "calendarItemIdentifier": "item-1",
        "title": "Apple Daily Standup",
        "startAt": "2026-04-06T01:00:00Z",
        "endAt": "2026-04-06T01:30:00Z",
        "occurrenceDate": "2026-04-06T01:00:00Z",
        "isRecurring": True,
        "recurrence": {"frequency": "daily", "interval": 1},
        "rawRRules": ["FREQ=DAILY"],
    }


def _apple_storage_payload(
    service: CalendarService,
    *,
    user_id: str,
    raw: dict[str, object],
    device_id: str = "device-a",
) -> dict[str, object]:
    normalized = service._normalize_imported_apple_event(
        user_id=user_id,
        raw=raw,
        timezone="UTC",
        device_id=device_id,
    )
    assert normalized is not None
    return service._build_apple_event_storage_payload(
        normalized,
        user_id=user_id,
        device_id=device_id,
    )


if __name__ == "__main__":
    unittest.main()
