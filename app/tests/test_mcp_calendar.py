from __future__ import annotations

import importlib.util
import sys
import unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import AsyncMock, patch
from config import constants
from services.mcp_next_actions import calendar_next_actions

_MCP_SPEC = importlib.util.spec_from_file_location(
    "ling_mcp_test_module",
    Path(__file__).resolve().parents[1] / "api" / "mcp.py",
)
assert _MCP_SPEC is not None and _MCP_SPEC.loader is not None
_MCP_MODULE = importlib.util.module_from_spec(_MCP_SPEC)
sys.modules[_MCP_SPEC.name] = _MCP_MODULE
_MCP_SPEC.loader.exec_module(_MCP_MODULE)

calendar_create_event = _MCP_MODULE.calendar_create_event
calendar_complete_event = _MCP_MODULE.calendar_complete_event
calendar_delete_event = _MCP_MODULE.calendar_delete_event
calendar_list_events = _MCP_MODULE.calendar_list_events
calendar_update_event = _MCP_MODULE.calendar_update_event
CalendarService = _MCP_MODULE.CalendarService


async def _call_tool(tool, **kwargs):
    handler = getattr(tool, "fn", tool)
    return await handler(**kwargs)


def _dtline(name: str, value: str, timezone: str = constants.DEFAULT_TIMEZONE) -> str:
    parsed = datetime.strptime(value[:8], "%Y%m%d")
    weekday = ("MO", "TU", "WE", "TH", "FR", "SA", "SU")[parsed.weekday()]
    return f"{name};TZID={timezone};X-LING-WEEKDAY={weekday}:{value}\n"


class CalendarMcpTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self._now_patcher = patch.object(
            _MCP_MODULE._calendar,
            "_calendar_current_local_time",
            return_value=datetime(
                2026,
                4,
                1,
                8,
                0,
                0,
                tzinfo=_MCP_MODULE.parse_timezone(constants.DEFAULT_TIMEZONE),
            ),
        )
        self._now_patcher.start()

    def tearDown(self) -> None:
        self._now_patcher.stop()

    async def test_calendar_list_events_returns_unified_ling_and_apple_rows(self) -> None:
        service = CalendarService()
        service.list_events_between = AsyncMock(
            return_value=[
                {
                    "event_id": "evt_1",
                    "title": "Ling event",
                    "start_at": "2026-04-06T09:00:00+08:00",
                    "source": "ling",
                },
                {
                    "event_id": "apple:item-1:2026-04-06",
                    "title": "Apple import",
                    "start_at": "2026-04-06T11:00:00+08:00",
                    "source": "apple",
                },
            ]
        )
        service.list_imported_apple_events_between = AsyncMock(
            return_value={
                "events": [],
                "coverage_start": "2026-04-01T00:00:00+00:00",
                "coverage_end": "2026-04-20T00:00:00+00:00",
                "coverage_complete": False,
                "permission_state": "granted",
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_list_events,
                user_id="user-1",
                start_time="2026-04-06T00:00:00+08:00",
                end_time="2026-04-07T00:00:00+08:00",
            )

        self.assertTrue(result["ok"])
        self.assertEqual(result["data"]["count"], 2)
        self.assertEqual([item["source"] for item in result["data"]["events"]], ["ling", "apple"])
        self.assertEqual(result["warnings"][0]["code"], "APPLE_IMPORT_WINDOW_LIMITED")

    async def test_calendar_list_events_supports_exact_event_id(self) -> None:
        service = CalendarService()
        service.get_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "客户拜访",
                "start_at": "2026-04-06T15:00:00+08:00",
            }
        )
        service.list_events_between = AsyncMock()
        service.list_imported_apple_events_between = AsyncMock()

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(
                calendar_list_events,
                user_id="user-1",
                event_id="evt_1",
            )

        self.assertTrue(result["ok"])
        self.assertEqual(result["data"]["count"], 1)
        self.assertEqual(result["data"]["events"][0]["event_id"], "evt_1")
        service.get_event.assert_awaited_once_with("user-1", "evt_1")
        service.list_events_between.assert_not_awaited()

    async def test_calendar_create_event_accepts_recurring_vevent(self) -> None:
        service = CalendarService()
        service.find_conflicts = AsyncMock(return_value=[])
        service.create_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "Recurring standup",
                "recurrence": {"frequency": "daily", "interval": 1},
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_create_event,
                user_id="user-1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Recurring standup\n"
                    + _dtline("DTSTART", "20260406T090000")
                    + _dtline("DTEND", "20260406T093000")
                    + "RRULE:FREQ=DAILY\n"
                    "END:VEVENT"
                ),
            )

        self.assertTrue(result["ok"])
        create_payload = service.create_event.await_args.args[1]
        self.assertEqual(create_payload["source"], "ling")
        self.assertEqual(create_payload["title"], "Recurring standup")
        self.assertEqual(create_payload["start_at"], "2026-04-06T09:00:00+08:00")
        self.assertEqual(create_payload["end_at"], "2026-04-06T09:30:00+08:00")
        self.assertEqual(create_payload["timezone"], constants.DEFAULT_TIMEZONE)
        self.assertEqual(create_payload["recurrence"], "FREQ=DAILY")
        self.assertEqual(create_payload["time_shape"], "span")
        self.assertEqual(result["next_actions"][0]["label"], "补充地点")

    async def test_calendar_create_event_accepts_weekly_rrule_until(self) -> None:
        service = CalendarService()
        service.find_conflicts = AsyncMock(return_value=[])
        service.create_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "movo 产品站会",
                "recurrence": {
                    "frequency": "weekly",
                    "by_weekday": ["MO", "TU", "WE", "TH", "FR"],
                    "until": "2026-06-30T21:00:00+00:00",
                },
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(
                calendar_create_event,
                user_id="user-1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:movo 产品站会\n"
                    "DTSTART;TZID=Asia/Shanghai;X-LING-WEEKDAY=FR:20260529T210000\n"
                    "DTEND;TZID=Asia/Shanghai;X-LING-WEEKDAY=FR:20260529T213000\n"
                    "RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;UNTIL=20260630T210000\n"
                    "DESCRIPTION:movo 产品工作日站会\n"
                    "CATEGORIES=work,meeting\n"
                    "END:VEVENT"
                ),
                check_conflicts=False,
                force=True,
            )

        self.assertTrue(result["ok"])
        create_payload = service.create_event.await_args.args[1]
        self.assertEqual(create_payload["title"], "movo 产品站会")
        self.assertEqual(create_payload["start_at"], "2026-05-29T21:00:00+08:00")
        self.assertEqual(create_payload["end_at"], "2026-05-29T21:30:00+08:00")
        self.assertEqual(create_payload["category"], "work")
        self.assertEqual(
            create_payload["recurrence"],
            "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;UNTIL=20260630T210000",
        )

    def test_calendar_next_actions_do_not_infer_meeting_from_text(self) -> None:
        actions = calendar_next_actions(
            "calendar_create_event",
            {
                "event_id": "evt_1",
                "title": "产品评审会议",
                "time_shape": constants.CALENDAR_TIME_SHAPE_SPAN,
                "location": "咖啡馆",
            },
        )

        self.assertEqual([item["label"] for item in actions], ["补充说明"])

    def test_calendar_next_actions_use_structured_meeting_category(self) -> None:
        actions = calendar_next_actions(
            "calendar_create_event",
            {
                "event_id": "evt_1",
                "title": "产品评审",
                "time_shape": constants.CALENDAR_TIME_SHAPE_SPAN,
                "category": "meeting",
                "location": "会议室 A",
            },
        )

        self.assertEqual(
            [item["label"] for item in actions],
            ["补充会议链接", "补充参会人", "补充会议议题"],
        )

    def test_calendar_next_actions_use_structured_travel_category(self) -> None:
        actions = calendar_next_actions(
            "calendar_create_event",
            {
                "event_id": "evt_1",
                "title": "出差",
                "time_shape": constants.CALENDAR_TIME_SHAPE_SPAN,
                "category": "travel",
                "location": "上海虹桥",
                "subtitle": "带身份证",
            },
        )

        self.assertEqual([item["label"] for item in actions], ["整理出行准备"])

    async def test_calendar_create_event_accepts_structured_meeting_category(self) -> None:
        service = CalendarService()
        service.find_conflicts = AsyncMock(return_value=[])
        service.create_event = AsyncMock(
            return_value={
                "event_id": "evt_meeting",
                "title": "产品评审",
                "category": "meeting",
                "time_shape": "span",
                "location": "会议室 A",
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(
                calendar_create_event,
                user_id="user-1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:产品评审\n"
                    + _dtline("DTSTART", "20260406T090000")
                    + _dtline("DTEND", "20260406T093000")
                    + "CATEGORIES:meeting\n"
                    "LOCATION:会议室 A\n"
                    "END:VEVENT"
                ),
            )

        self.assertTrue(result["ok"])
        create_payload = service.create_event.await_args.args[1]
        self.assertEqual(create_payload["category"], "meeting")
        self.assertEqual(result["next_actions"][0]["label"], "补充会议链接")

    async def test_calendar_create_event_rejects_past_start_without_force(self) -> None:
        service = CalendarService()
        service.find_conflicts = AsyncMock(return_value=[])
        service.create_event = AsyncMock()

        with (
            patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service),
            patch.object(
                _MCP_MODULE._calendar,
                "_calendar_current_local_time",
                return_value=datetime(
                    2026,
                    5,
                    26,
                    11,
                    52,
                    0,
                    tzinfo=_MCP_MODULE.parse_timezone(constants.DEFAULT_TIMEZONE),
                ),
            ),
        ):
            result = await _call_tool(
                calendar_create_event,
                user_id="user-1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:完成报告\n"
                    + _dtline("DTSTART", "20260526T100000")
                    + _dtline("DTEND", "20260526T113000")
                    + "END:VEVENT"
                ),
            )

        self.assertFalse(result["ok"])
        self.assertEqual(result["error"]["error_code"], "CALENDAR_PAST_TIME")
        self.assertTrue(result["error"]["error_detail"]["force_available"])
        self.assertIn("future time", result["error"]["next_action"])
        service.find_conflicts.assert_not_awaited()
        service.create_event.assert_not_awaited()

    async def test_calendar_create_event_allows_past_start_with_force_warning(self) -> None:
        service = CalendarService()
        service.find_conflicts = AsyncMock(return_value=[])
        service.create_event = AsyncMock(
            return_value={
                "event_id": "evt_backfill",
                "title": "补记完成报告",
                "start_at": "2026-05-26T10:00:00+08:00",
                "end_at": "2026-05-26T11:30:00+08:00",
            }
        )

        with (
            patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service),
            patch.object(
                _MCP_MODULE._calendar,
                "_calendar_current_local_time",
                return_value=datetime(
                    2026,
                    5,
                    26,
                    11,
                    52,
                    0,
                    tzinfo=_MCP_MODULE.parse_timezone(constants.DEFAULT_TIMEZONE),
                ),
            ),
        ):
            result = await _call_tool(
                calendar_create_event,
                user_id="user-1",
                force=True,
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:补记完成报告\n"
                    + _dtline("DTSTART", "20260526T100000")
                    + _dtline("DTEND", "20260526T113000")
                    + "END:VEVENT"
                ),
            )

        self.assertTrue(result["ok"])
        self.assertEqual(result["warnings"][0]["code"], "CALENDAR_PAST_TIME_FORCED")
        create_payload = service.create_event.await_args.args[1]
        self.assertEqual(create_payload["start_at"], "2026-05-26T10:00:00+08:00")

    async def test_calendar_create_event_accepts_point_reminder_vevent(self) -> None:
        service = CalendarService()
        service.find_conflicts = AsyncMock(return_value=[{"event_id": "evt_busy"}])
        service.create_event = AsyncMock(
            return_value={
                "event_id": "evt_point",
                "title": "Call parents",
                "time_shape": "point",
                "start_at": "2026-04-06T20:00:00+08:00",
                "end_at": "2026-04-06T20:00:00+08:00",
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_create_event,
                user_id="user-1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Call parents\n"
                    + _dtline("DTSTART", "20260406T200000")
                    + "END:VEVENT"
                ),
            )

        self.assertTrue(result["ok"])
        service.find_conflicts.assert_not_awaited()
        create_payload = service.create_event.await_args.args[1]
        self.assertEqual(create_payload["time_shape"], "point")
        self.assertEqual(create_payload["start_at"], create_payload["end_at"])

    async def test_calendar_create_event_accepts_recurring_point_reminder(self) -> None:
        service = CalendarService()
        service.find_conflicts = AsyncMock(return_value=[])
        service.create_event = AsyncMock(
            return_value={
                "event_id": "evt_point_daily",
                "title": "Drink water",
                "time_shape": "point",
                "recurrence": {"frequency": "daily"},
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_create_event,
                user_id="user-1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Drink water\n"
                    + _dtline("DTSTART", "20260406T090000")
                    + "RRULE:FREQ=DAILY\n"
                    "END:VEVENT"
                ),
            )

        self.assertTrue(result["ok"])
        create_payload = service.create_event.await_args.args[1]
        self.assertEqual(create_payload["time_shape"], "point")
        self.assertEqual(create_payload["recurrence"], "FREQ=DAILY")

    async def test_calendar_create_event_parses_vevent_timezone(self) -> None:
        service = CalendarService()
        service.find_conflicts = AsyncMock(return_value=[])
        service.create_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "Morning sync",
                "timezone": constants.DEFAULT_TIMEZONE,
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_create_event,
                user_id="user-1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Morning sync\n"
                    + _dtline("DTSTART", "20260406T090000")
                    + _dtline("DTEND", "20260406T093000")
                    + "END:VEVENT"
                ),
            )

        self.assertTrue(result["ok"])
        create_payload = service.create_event.await_args.args[1]
        self.assertEqual(create_payload["timezone"], constants.DEFAULT_TIMEZONE)

    async def test_calendar_create_event_omits_advanced_fields(self) -> None:
        service = CalendarService()
        service.find_conflicts = AsyncMock(return_value=[])
        service.create_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "Interview",
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_create_event,
                user_id="user-1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Interview\n"
                    + _dtline("DTSTART", "20260512T140000")
                    + _dtline("DTEND", "20260512T150000")
                    + "END:VEVENT"
                ),
            )

        self.assertTrue(result["ok"])
        create_payload = service.create_event.await_args.args[1]
        self.assertEqual(create_payload["attendees"], [])
        self.assertEqual(create_payload["metadata"], {})
        self.assertIsNone(create_payload["recurrence"])

    async def test_calendar_create_event_rejects_invalid_tzid(self) -> None:
        service = CalendarService()

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_create_event,
                user_id="user-1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Offset only\n"
                    "DTSTART;TZID=UTC+08:00:20260406T090000\n"
                    "DTEND;TZID=UTC+08:00:20260406T093000\n"
                    "END:VEVENT"
                ),
            )

        self.assertFalse(result["ok"])
        self.assertEqual(result["error"]["status_code"], 422)
        self.assertEqual(result["error"]["error_code"], "INVALID_ICALENDAR_EVENT")

    async def test_calendar_create_event_rejects_floating_datetime(self) -> None:
        service = CalendarService()

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_create_event,
                user_id="user-1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Floating time\n"
                    "DTSTART:20260406T090000\n"
                    "DTEND:20260406T093000\n"
                    "END:VEVENT"
                ),
            )

        self.assertFalse(result["ok"])
        self.assertEqual(result["error"]["status_code"], 422)
        self.assertEqual(result["error"]["error_code"], "INVALID_ICALENDAR_EVENT")

    async def test_calendar_create_event_rejects_missing_weekday_param(self) -> None:
        service = CalendarService()

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(
                calendar_create_event,
                user_id="user-1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Missing weekday\n"
                    f"DTSTART;TZID={constants.DEFAULT_TIMEZONE}:20260406T090000\n"
                    + _dtline("DTEND", "20260406T093000")
                    + "END:VEVENT"
                ),
            )

        self.assertFalse(result["ok"])
        self.assertEqual(result["error"]["status_code"], 422)
        self.assertEqual(result["error"]["error_code"], "INVALID_ICALENDAR_WEEKDAY")
        self.assertEqual(result["error"]["error_detail"]["property"], "DTSTART")
        self.assertEqual(result["error"]["error_detail"]["actual_weekday"], "MO")

    async def test_calendar_create_event_rejects_weekday_mismatch(self) -> None:
        service = CalendarService()

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(
                calendar_create_event,
                user_id="user-1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Wrong weekday\n"
                    f"DTSTART;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=FR:20260406T090000\n"
                    + _dtline("DTEND", "20260406T093000")
                    + "END:VEVENT"
                ),
            )

        self.assertFalse(result["ok"])
        self.assertEqual(result["error"]["status_code"], 422)
        self.assertEqual(result["error"]["error_code"], "INVALID_ICALENDAR_WEEKDAY")
        detail = result["error"]["error_detail"]
        self.assertEqual(detail["property"], "DTSTART")
        self.assertEqual(detail["expected_weekday"], "FR")
        self.assertEqual(detail["actual_date"], "2026-04-06")
        self.assertEqual(detail["actual_weekday"], "MO")

    async def test_calendar_create_event_ignores_unsupported_vevent_fields(self) -> None:
        service = CalendarService()
        service.find_conflicts = AsyncMock(return_value=[])
        service.create_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "Morning sync",
                "timezone": constants.DEFAULT_TIMEZONE,
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_create_event,
                user_id="user-1",
                vevent=(
                    "BEGIN:VCALENDAR\n"
                    "VERSION:2.0\n"
                    "BEGIN:VEVENT\n"
                    "UID\n"
                    "SUMMARY:Morning sync\n"
                    + _dtline("DTSTART", "20260406T090000")
                    + _dtline("DTEND", "20260406T093000")
                    + "ATTENDEE\n"
                    "END:VEVENT\n"
                    "END:VCALENDAR"
                ),
            )

        self.assertTrue(result["ok"])
        create_payload = service.create_event.await_args.args[1]
        self.assertEqual(create_payload["title"], "Morning sync")

    async def test_calendar_update_event_returns_client_action_for_apple_row(self) -> None:
        service = CalendarService()
        event = type(
            "AppleEventRow",
            (),
            {
                "start_at": datetime(2026, 4, 6, 1, 0, 0),
                "end_at": datetime(2026, 4, 6, 2, 0, 0),
                "timezone": constants.DEFAULT_TIMEZONE,
            },
        )()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.serialize_event = AsyncMock(
            return_value={
                "event_id": "apple:item-1:2026-04-06",
                "title": "Apple sync",
                "subtitle": "original",
                "category": "external",
                "start_at": "2026-04-06T09:00:00+08:00",
                "end_at": "2026-04-06T10:00:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "location": "Shanghai",
                "attendees": [],
                "status": "scheduled",
                "focus_mode_enabled": False,
                "metadata": {},
                "apple_link": {
                    "event_identifier": "event-1",
                    "calendar_item_identifier": "item-1",
                },
                "source": "apple",
                "provider": "apple_local",
            }
        )
        service.find_conflicts = AsyncMock(return_value=[])

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_update_event,
                user_id="user-1",
                event_id="apple:item-1:2026-04-06",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Updated title\n"
                    + _dtline("DTSTART", "20260406T090000")
                    + _dtline("DTEND", "20260406T100000")
                    + "LOCATION:Shanghai\n"
                    "END:VEVENT"
                ),
            )

        self.assertTrue(result["ok"])
        payload = result["data"]
        self.assertEqual(payload["source"], "apple")
        self.assertEqual(payload["execution_status"], "pending_client")
        self.assertEqual(payload["client_action"]["operation"], "update")
        self.assertEqual(payload["client_action"]["mutation_options"]["eventIdentifier"], "event-1")

    async def test_calendar_update_event_updates_ling_event_from_vevent(self) -> None:
        service = CalendarService()
        event = type(
            "LingEventRow",
            (),
            {
                "start_at": datetime(2026, 4, 18, 0, 0, 0),
                "end_at": datetime(2026, 4, 18, 8, 0, 0),
                "timezone": constants.DEFAULT_TIMEZONE,
            },
        )()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.serialize_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "Trip",
                "start_at": "2026-04-18T08:00:00+08:00",
                "end_at": "2026-04-18T16:00:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "source": "ling",
                "provider": "ling",
            }
        )
        service.find_conflicts = AsyncMock(return_value=[])
        service.update_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "Trip",
                "start_at": "2026-04-18T08:00:00+08:00",
                "end_at": "2026-04-19T16:00:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "source": "ling",
                "provider": "ling",
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_update_event,
                user_id="user-1",
                event_id="evt_1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Trip\n"
                    + _dtline("DTSTART", "20260418T080000")
                    + _dtline("DTEND", "20260419T160000")
                    + "END:VEVENT"
                ),
            )

        self.assertTrue(result["ok"])
        update_payload = service.update_event.await_args.args[2]
        self.assertEqual(update_payload["title"], "Trip")
        self.assertEqual(update_payload["start_at"], "2026-04-18T08:00:00+08:00")
        self.assertEqual(update_payload["end_at"], "2026-04-19T16:00:00+08:00")
        self.assertEqual(update_payload["timezone"], constants.DEFAULT_TIMEZONE)
        self.assertEqual(result["data"]["end_at"], "2026-04-19T16:00:00+08:00")

    async def test_calendar_update_event_rejects_weekday_mismatch(self) -> None:
        service = CalendarService()
        event = type(
            "LingEventRow",
            (),
            {
                "start_at": datetime(2026, 4, 18, 0, 0, 0),
                "end_at": datetime(2026, 4, 18, 8, 0, 0),
                "timezone": constants.DEFAULT_TIMEZONE,
            },
        )()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.serialize_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "Trip",
                "start_at": "2026-04-18T08:00:00+08:00",
                "end_at": "2026-04-18T16:00:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "source": "ling",
                "provider": "ling",
            }
        )
        service.find_conflicts = AsyncMock(return_value=[])
        service.update_event = AsyncMock()

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(
                calendar_update_event,
                user_id="user-1",
                event_id="evt_1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Trip\n"
                    f"DTSTART;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=FR:20260418T080000\n"
                    + _dtline("DTEND", "20260418T090000")
                    + "END:VEVENT"
                ),
            )

        self.assertFalse(result["ok"])
        self.assertEqual(result["error"]["error_code"], "INVALID_ICALENDAR_WEEKDAY")
        self.assertEqual(result["error"]["error_detail"]["property"], "DTSTART")
        service.find_conflicts.assert_not_awaited()
        service.update_event.assert_not_awaited()

    async def test_calendar_update_event_accepts_raw_multiline_description(self) -> None:
        service = CalendarService()
        event = type(
            "LingEventRow",
            (),
            {
                "start_at": datetime(2026, 5, 26, 9, 0, 0),
                "end_at": datetime(2026, 5, 26, 9, 0, 0),
                "timezone": constants.DEFAULT_TIMEZONE,
            },
        )()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.serialize_event = AsyncMock(
            return_value={
                "event_id": "evt_plate",
                "title": "查看北京车牌摇号结果",
                "start_at": "2026-05-26T17:00:00+08:00",
                "end_at": "2026-05-26T17:00:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "source": "ling",
                "provider": "ling",
            }
        )
        service.update_event = AsyncMock(
            return_value={
                "event_id": "evt_plate",
                "title": "查看北京车牌摇号结果",
                "subtitle": (
                    "🚗 北京车牌摇号结果查询\n\n"
                    "家庭积分核心规则：主申请人 2 分。\n"
                    "查询入口：https://xkczb.jtw.beijing.gov.cn/"
                ),
                "category": "personal",
                "location": "北京交通订阅号",
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(
                calendar_update_event,
                user_id="user-1",
                event_id="evt_plate",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:查看北京车牌摇号结果\n"
                    + _dtline("DTSTART", "20260526T170000")
                    + "DESCRIPTION:🚗 北京车牌摇号结果查询\n"
                    "\n"
                    "家庭积分核心规则：主申请人 2 分。\n"
                    "查询入口：https://xkczb.jtw.beijing.gov.cn/\n"
                    "LOCATION:北京交通订阅号\n"
                    "CATEGORIES:personal\n"
                    "END:VEVENT"
                ),
            )

        self.assertTrue(result["ok"])
        update_payload = service.update_event.await_args.args[2]
        self.assertEqual(
            update_payload["subtitle"],
            "🚗 北京车牌摇号结果查询\n\n"
            "家庭积分核心规则：主申请人 2 分。\n"
            "查询入口：https://xkczb.jtw.beijing.gov.cn/",
        )
        self.assertEqual(update_payload["location"], "北京交通订阅号")
        self.assertEqual(update_payload["category"], "personal")
        self.assertNotIn("LOCATION", update_payload["subtitle"])
        self.assertNotIn("CATEGORIES", update_payload["subtitle"])

    async def test_calendar_update_event_does_not_append_unknown_vevent_properties_to_description(self) -> None:
        service = CalendarService()
        event = type(
            "LingEventRow",
            (),
            {
                "start_at": datetime(2026, 5, 26, 9, 0, 0),
                "end_at": datetime(2026, 5, 26, 9, 0, 0),
                "timezone": constants.DEFAULT_TIMEZONE,
            },
        )()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.serialize_event = AsyncMock(
            return_value={
                "event_id": "evt_meeting",
                "title": "Meeting",
                "start_at": "2026-05-26T17:00:00+08:00",
                "end_at": "2026-05-26T17:00:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "source": "ling",
                "provider": "ling",
            }
        )
        service.update_event = AsyncMock(return_value={"event_id": "evt_meeting"})

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(
                calendar_update_event,
                user_id="user-1",
                event_id="evt_meeting",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Meeting\n"
                    + _dtline("DTSTART", "20260526T170000")
                    + "DESCRIPTION:Bring notes\n"
                    "DTSTAMP:20260526T010000Z\n"
                    "UID:event-123\n"
                    "ATTENDEE;CN=Eric:mailto:eric@example.com\n"
                    "END:VEVENT"
                ),
            )

        self.assertTrue(result["ok"])
        update_payload = service.update_event.await_args.args[2]
        self.assertEqual(update_payload["subtitle"], "Bring notes")
        self.assertNotIn("DTSTAMP", update_payload["subtitle"])
        self.assertNotIn("UID", update_payload["subtitle"])
        self.assertNotIn("ATTENDEE", update_payload["subtitle"])

    async def test_calendar_update_event_preserves_escaped_description_newlines(self) -> None:
        service = CalendarService()
        event = type(
            "LingEventRow",
            (),
            {
                "start_at": datetime(2026, 5, 26, 9, 0, 0),
                "end_at": datetime(2026, 5, 26, 9, 0, 0),
                "timezone": constants.DEFAULT_TIMEZONE,
            },
        )()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.serialize_event = AsyncMock(
            return_value={
                "event_id": "evt_note",
                "title": "Note",
                "start_at": "2026-05-26T17:00:00+08:00",
                "end_at": "2026-05-26T17:00:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "source": "ling",
                "provider": "ling",
            }
        )
        service.update_event = AsyncMock(
            return_value={
                "event_id": "evt_note",
                "title": "Note",
                "subtitle": "第一行\n第二行",
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(
                calendar_update_event,
                user_id="user-1",
                event_id="evt_note",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Note\n"
                    + _dtline("DTSTART", "20260526T170000")
                    + "DESCRIPTION:第一行\\n第二行\n"
                    "END:VEVENT"
                ),
            )

        self.assertTrue(result["ok"])
        update_payload = service.update_event.await_args.args[2]
        self.assertEqual(update_payload["subtitle"], "第一行\n第二行")

    async def test_calendar_update_event_rejects_past_start_without_force(self) -> None:
        service = CalendarService()
        event = type(
            "LingEventRow",
            (),
            {
                "start_at": datetime(2026, 5, 26, 9, 0, 0),
                "end_at": datetime(2026, 5, 26, 10, 0, 0),
                "timezone": constants.DEFAULT_TIMEZONE,
            },
        )()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.serialize_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "报告",
                "start_at": "2026-05-26T13:00:00+08:00",
                "end_at": "2026-05-26T14:00:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "source": "ling",
                "provider": "ling",
            }
        )
        service.find_conflicts = AsyncMock(return_value=[])
        service.update_event = AsyncMock()

        with (
            patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service),
            patch.object(
                _MCP_MODULE._calendar,
                "_calendar_current_local_time",
                return_value=datetime(
                    2026,
                    5,
                    26,
                    11,
                    52,
                    0,
                    tzinfo=_MCP_MODULE.parse_timezone(constants.DEFAULT_TIMEZONE),
                ),
            ),
        ):
            result = await _call_tool(
                calendar_update_event,
                user_id="user-1",
                event_id="evt_1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:报告\n"
                    + _dtline("DTSTART", "20260526T100000")
                    + _dtline("DTEND", "20260526T113000")
                    + "END:VEVENT"
                ),
            )

        self.assertFalse(result["ok"])
        self.assertEqual(result["error"]["error_code"], "CALENDAR_PAST_TIME")
        self.assertTrue(result["error"]["error_detail"]["force_available"])
        service.find_conflicts.assert_not_awaited()
        service.update_event.assert_not_awaited()

    async def test_calendar_update_event_metadata_only_skips_past_start_guard(self) -> None:
        service = CalendarService()
        event = type(
            "LingEventRow",
            (),
            {
                "start_at": datetime(2026, 5, 26, 9, 0, 0),
                "end_at": datetime(2026, 5, 26, 10, 0, 0),
                "timezone": constants.DEFAULT_TIMEZONE,
            },
        )()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.serialize_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "报告",
                "start_at": "2026-05-26T10:00:00+08:00",
                "end_at": "2026-05-26T11:30:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "source": "ling",
                "provider": "ling",
                "metadata": {},
            }
        )
        service.update_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "报告",
                "metadata": {"markdown": "已完成"},
            }
        )

        with (
            patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service),
            patch.object(
                _MCP_MODULE._calendar,
                "_calendar_current_local_time",
                return_value=datetime(
                    2026,
                    5,
                    26,
                    11,
                    52,
                    0,
                    tzinfo=_MCP_MODULE.parse_timezone(constants.DEFAULT_TIMEZONE),
                ),
            ),
        ):
            result = await _call_tool(
                calendar_update_event,
                user_id="user-1",
                event_id="evt_1",
                metadata="已完成",
            )

        self.assertTrue(result["ok"])
        update_payload = service.update_event.await_args.args[2]
        self.assertEqual(update_payload["metadata"]["markdown"], "已完成")

    async def test_calendar_update_event_rejects_deleted_event_before_update(self) -> None:
        service = CalendarService()
        event = type(
            "DeletedLingEventRow",
            (),
            {
                "event_id": "evt_deleted",
                "status": constants.CALENDAR_STATUS_CANCELLED,
                "is_active": False,
            },
        )()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.serialize_event = AsyncMock()
        service.find_conflicts = AsyncMock()
        service.update_event = AsyncMock()

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_update_event,
                user_id="user-1",
                event_id="evt_deleted",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Trip\n"
                    + _dtline("DTSTART", "20260418T080000")
                    + _dtline("DTEND", "20260418T090000")
                    + "END:VEVENT"
                ),
            )

        self.assertFalse(result["ok"])
        self.assertEqual(result["error"]["status_code"], 410)
        self.assertEqual(result["error"]["error_code"], "CALENDAR_EVENT_DELETED")
        self.assertIn("Confirm the target ID", result["error"]["next_action"])
        self.assertNotIn("force=true", result["error"]["next_action"])
        service.serialize_event.assert_not_awaited()
        service.update_event.assert_not_awaited()

    async def test_calendar_update_event_updates_series_rrule_from_vevent(self) -> None:
        service = CalendarService()
        event = type(
            "LingEventRow",
            (),
            {
                "start_at": datetime(2026, 4, 18, 0, 0, 0),
                "end_at": datetime(2026, 4, 18, 8, 0, 0),
                "timezone": constants.DEFAULT_TIMEZONE,
            },
        )()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.serialize_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "Standup",
                "start_at": "2026-04-18T08:00:00+08:00",
                "end_at": "2026-04-18T08:30:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "source": "ling",
                "provider": "ling",
            }
        )
        service.find_conflicts = AsyncMock(return_value=[])
        service.update_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "Standup",
                "recurrence": {"raw_rrule": "FREQ=WEEKLY;BYDAY=TU"},
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_update_event,
                user_id="user-1",
                event_id="evt_1",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Standup\n"
                    + _dtline("DTSTART", "20260418T080000")
                    + _dtline("DTEND", "20260418T083000")
                    + "RRULE:FREQ=WEEKLY;BYDAY=TU\n"
                    "END:VEVENT"
                ),
            )

        self.assertTrue(result["ok"])
        update_payload = service.update_event.await_args.args[2]
        self.assertEqual(update_payload["scope"], "series")
        self.assertEqual(update_payload["recurrence"], "FREQ=WEEKLY;BYDAY=TU")

    async def test_calendar_update_event_rejects_rrule_for_occurrence_scope(self) -> None:
        service = CalendarService()
        event = type(
            "LingEventRow",
            (),
            {
                "start_at": datetime(2026, 4, 18, 0, 0, 0),
                "end_at": datetime(2026, 4, 18, 8, 0, 0),
                "timezone": constants.DEFAULT_TIMEZONE,
            },
        )()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.serialize_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "Standup",
                "start_at": "2026-04-18T08:00:00+08:00",
                "end_at": "2026-04-18T08:30:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "source": "ling",
                "provider": "ling",
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_update_event,
                user_id="user-1",
                event_id="evt_1",
                scope="occurrence",
                occurrence_start_time="2026-04-18T08:00:00+08:00",
                vevent=(
                    "BEGIN:VEVENT\n"
                    "SUMMARY:Standup\n"
                    + _dtline("DTSTART", "20260418T080000")
                    + _dtline("DTEND", "20260418T083000")
                    + "RRULE:FREQ=WEEKLY;BYDAY=TU\n"
                    "END:VEVENT"
                ),
            )

        self.assertFalse(result["ok"])
        self.assertEqual(result["error"]["error_code"], "RECURRENCE_UPDATE_REQUIRES_SERIES_SCOPE")

    async def test_calendar_update_event_updates_metadata_without_vevent(self) -> None:
        service = CalendarService()
        event = type(
            "LingEventRow",
            (),
            {
                "start_at": datetime(2026, 4, 18, 0, 0, 0),
                "end_at": datetime(2026, 4, 18, 8, 0, 0),
                "timezone": constants.DEFAULT_TIMEZONE,
            },
        )()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.serialize_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "Interview",
                "start_at": "2026-04-18T08:00:00+08:00",
                "end_at": "2026-04-18T16:00:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "source": "ling",
                "provider": "ling",
                "metadata": {
                    "markdown": "旧备注会被整段替换",
                },
            }
        )
        service.update_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "Interview",
                "metadata": {
                    "markdown": "- **note**: Bring portfolio\n"
                    "- **tags**:\n"
                    "  - hiring\n"
                    "- **priority**: high",
                },
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_update_event,
                user_id="user-1",
                event_id="evt_1",
                metadata={
                    "note": "Bring portfolio",
                    "tags": ["hiring"],
                    "priority": "high",
                },
            )

        self.assertTrue(result["ok"])
        update_payload = service.update_event.await_args.args[2]
        self.assertEqual(
            update_payload["metadata"],
            {
                "markdown": "- **note**: Bring portfolio\n"
                "- **tags**:\n"
                "  - hiring\n"
                "- **priority**: high",
            },
        )

    async def test_calendar_update_event_updates_preparation_without_vevent(self) -> None:
        service = CalendarService()
        event = type(
            "LingEventRow",
            (),
            {
                "start_at": datetime(2026, 4, 18, 0, 0, 0),
                "end_at": datetime(2026, 4, 18, 8, 0, 0),
                "timezone": constants.DEFAULT_TIMEZONE,
            },
        )()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.serialize_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "Interview",
                "start_at": "2026-04-18T08:00:00+08:00",
                "end_at": "2026-04-18T16:00:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "source": "ling",
                "provider": "ling",
                "metadata": {
                    "markdown": "旧备注保留",
                },
            }
        )
        service.update_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "Interview",
                "metadata": {
                    "markdown": "旧备注保留",
                    "schedule_preparation": [
                        {
                            "title": "会议准备文档",
                            "path": "/app/agents/user-1/agent-1/reports/prep.md",
                        }
                    ],
                },
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(
                calendar_update_event,
                user_id="user-1",
                event_id="evt_1",
                preparation=[
                    {
                        "title": "会议准备文档",
                        "path": "/app/agents/user-1/agent-1/reports/prep.md",
                    }
                ],
            )

        self.assertTrue(result["ok"])
        update_payload = service.update_event.await_args.args[2]
        self.assertEqual(
            update_payload["metadata"],
            {
                "markdown": "旧备注保留",
                "schedule_preparation": [
                    {
                        "title": "会议准备文档",
                        "path": "/app/agents/user-1/agent-1/reports/prep.md",
                    }
                ],
            },
        )

    async def test_calendar_update_event_allows_empty_preparation_to_clear_materials(self) -> None:
        service = CalendarService()
        event = type(
            "LingEventRow",
            (),
            {
                "start_at": datetime(2026, 4, 18, 0, 0, 0),
                "end_at": datetime(2026, 4, 18, 8, 0, 0),
                "timezone": constants.DEFAULT_TIMEZONE,
            },
        )()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.serialize_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "title": "Interview",
                "start_at": "2026-04-18T08:00:00+08:00",
                "end_at": "2026-04-18T16:00:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "source": "ling",
                "provider": "ling",
                "metadata": {
                    "markdown": "旧备注保留",
                    "schedule_preparation": [
                        {
                            "title": "旧材料",
                            "path": "/app/agents/user-1/agent-1/reports/old.md",
                        }
                    ],
                },
            }
        )
        service.update_event = AsyncMock(return_value={"event_id": "evt_1"})

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(
                calendar_update_event,
                user_id="user-1",
                event_id="evt_1",
                preparation=[],
            )

        self.assertTrue(result["ok"])
        update_payload = service.update_event.await_args.args[2]
        self.assertEqual(
            update_payload["metadata"],
            {
                "markdown": "旧备注保留",
                "schedule_preparation": [],
            },
        )

    async def test_calendar_complete_event_marks_ling_event_done(self) -> None:
        service = CalendarService()
        service.parse_datetime = _MCP_MODULE.CalendarService().parse_datetime
        service.complete_event = AsyncMock(
            return_value={
                "event_id": "evt_1",
                "status": "completed",
                "metadata": {
                    "completed_at": "2026-04-18T17:00:00+08:00",
                    "completed_by": "agent",
                    "outcome": "done",
                    "result_summary": "聊完了，结果不错",
                },
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_complete_event,
                user_id="user-1",
                event_id="evt_1",
                completed_at="2026-04-18T17:00:00+08:00",
                outcome="done",
                result_summary="聊完了，结果不错",
            )

        self.assertTrue(result["ok"])
        service.complete_event.assert_awaited_once()
        kwargs = service.complete_event.await_args.kwargs
        self.assertEqual(kwargs["completed_at"], "2026-04-18T17:00:00+08:00")
        self.assertEqual(kwargs["result_summary"], "聊完了，结果不错")

    async def test_calendar_delete_event_returns_client_action_for_apple_row(self) -> None:
        service = CalendarService()
        event = object()
        service.event_dao.get_user_event = AsyncMock(return_value=event)
        service.serialize_event = AsyncMock(
            return_value={
                "event_id": "apple:item-1:2026-04-06",
                "title": "Apple sync",
                "start_at": "2026-04-06T09:00:00+08:00",
                "end_at": "2026-04-06T10:00:00+08:00",
                "timezone": constants.DEFAULT_TIMEZONE,
                "apple_link": {
                    "event_identifier": "event-1",
                    "calendar_item_identifier": "item-1",
                },
                "source": "apple",
                "provider": "apple_local",
            }
        )

        with patch.object(_MCP_MODULE._calendar, "CalendarService", return_value=service):
            result = await _call_tool(calendar_delete_event,
                user_id="user-1",
                event_id="apple:item-1:2026-04-06",
            )

        self.assertTrue(result["ok"])
        payload = result["data"]
        self.assertEqual(payload["source"], "apple")
        self.assertEqual(payload["execution_status"], "pending_client")
        self.assertEqual(payload["client_action"]["operation"], "delete")
        self.assertEqual(payload["client_action"]["mutation_options"]["eventIdentifier"], "event-1")


if __name__ == "__main__":
    unittest.main()
