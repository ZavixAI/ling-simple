import unittest
from datetime import datetime

from config import constants
from models.calendar import CalendarEvent
from services.calendar import CalendarService
from services.calendar_domain.recurrence import (
    effective_recurrence,
    serialize_imported_apple_recurrence,
    serialize_recurrence,
)
from services.calendar_recurrence import normalize_recurrence_payload, serialize_rrule


class CalendarRecurrenceDomainTests(unittest.TestCase):
    def test_normalize_rrule_accepts_weekly_until_without_datetime_utc_error(self) -> None:
        recurrence, raw_rrule = normalize_recurrence_payload(
            "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;UNTIL=20260630T210000"
        )

        self.assertEqual(
            recurrence,
            {
                "frequency": "weekly",
                "interval": 1,
                "until": "2026-06-30T21:00:00+00:00",
                "by_weekday": ["MO", "TU", "WE", "TH", "FR"],
            },
        )
        self.assertEqual(raw_rrule, "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;UNTIL=20260630T210000")

    def test_serialize_rrule_writes_until_in_utc(self) -> None:
        raw_rrule = serialize_rrule(
            {
                "frequency": "weekly",
                "by_weekday": ["MO", "TU", "WE", "TH", "FR"],
                "until": "2026-06-30T21:00:00+08:00",
            }
        )

        self.assertEqual(
            raw_rrule,
            "FREQ=WEEKLY;UNTIL=20260630T130000Z;BYDAY=MO,TU,WE,TH,FR",
        )

    def test_effective_recurrence_fills_missing_fields_from_raw_rrule(self) -> None:
        event = CalendarEvent(
            event_id="evt_weekly",
            user_id="user-1",
            title="提醒",
            start_at=datetime(2026, 5, 10, 16, 0, 0),
            end_at=datetime(2026, 5, 10, 16, 15, 0),
            timezone=constants.DEFAULT_TIMEZONE,
            recurrence_rule={"frequency": "weekly", "interval": 1},
            recurrence_rrule="FREQ=WEEKLY;BYDAY=MO,WE,FR",
            series_id="evt_weekly",
        )

        recurrence = effective_recurrence(event)

        self.assertEqual(recurrence["frequency"], "weekly")
        self.assertEqual(recurrence["interval"], 1)
        self.assertEqual(recurrence["by_weekday"], ["MO", "WE", "FR"])

    def test_effective_recurrence_returns_none_without_recurrence_data(self) -> None:
        event = CalendarEvent(
            event_id="evt_plain",
            user_id="user-1",
            title="提醒",
            start_at=datetime(2026, 5, 10, 16, 0, 0),
            end_at=datetime(2026, 5, 10, 16, 15, 0),
            timezone=constants.DEFAULT_TIMEZONE,
        )

        self.assertIsNone(effective_recurrence(event))

    def test_serialize_recurrence_adds_anchor_times(self) -> None:
        service = CalendarService()
        event = CalendarEvent(
            event_id="evt_daily",
            user_id="user-1",
            title="提醒",
            start_at=datetime(2026, 5, 10, 16, 0, 0),
            end_at=datetime(2026, 5, 10, 16, 15, 0),
            timezone=constants.DEFAULT_TIMEZONE,
            recurrence_rule={"frequency": "daily", "interval": 1},
            series_id="evt_daily",
        )

        recurrence = serialize_recurrence(
            event,
            get_zone=service._get_zone,
            to_local=service._to_local,
        )

        self.assertEqual(recurrence["frequency"], "daily")
        self.assertEqual(recurrence["anchor_start_at"], "2026-05-11T00:00:00+08:00")
        self.assertEqual(recurrence["anchor_end_at"], "2026-05-11T00:15:00+08:00")

    def test_serialize_imported_apple_recurrence_uses_metadata_payload(self) -> None:
        service = CalendarService()
        event = CalendarEvent(
            event_id="evt_apple",
            user_id="user-1",
            title="提醒",
            start_at=datetime(2026, 5, 10, 16, 0, 0),
            end_at=datetime(2026, 5, 10, 16, 15, 0),
            timezone=constants.DEFAULT_TIMEZONE,
            metadata={
                "_apple_recurrence": {"frequency": "weekly", "interval": 2},
                "raw_rrules": "FREQ=WEEKLY;INTERVAL=2",
            },
        )

        recurrence = serialize_imported_apple_recurrence(
            event,
            get_zone=service._get_zone,
            to_local=service._to_local,
        )

        self.assertEqual(recurrence["frequency"], "weekly")
        self.assertEqual(recurrence["interval"], 2)
        self.assertEqual(recurrence["raw_rrules"], ["FREQ=WEEKLY;INTERVAL=2"])
        self.assertEqual(recurrence["raw_rrule"], "FREQ=WEEKLY;INTERVAL=2")

    def test_serialize_imported_apple_recurrence_prefers_internal_rrule(self) -> None:
        service = CalendarService()
        event = CalendarEvent(
            event_id="evt_apple",
            user_id="user-1",
            title="提醒",
            start_at=datetime(2026, 5, 10, 16, 0, 0),
            end_at=datetime(2026, 5, 10, 16, 15, 0),
            timezone=constants.DEFAULT_TIMEZONE,
            metadata={
                "_apple_recurrence": {"frequency": "daily"},
                "_apple_recurrence_rrule": "FREQ=DAILY;COUNT=3",
                "raw_rrules": [" ", "FREQ=DAILY"],
            },
        )

        recurrence = serialize_imported_apple_recurrence(
            event,
            get_zone=service._get_zone,
            to_local=service._to_local,
        )

        self.assertEqual(recurrence["raw_rrules"], ["FREQ=DAILY"])
        self.assertEqual(recurrence["raw_rrule"], "FREQ=DAILY;COUNT=3")
