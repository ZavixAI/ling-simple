import unittest
from datetime import datetime, timezone

from services.calendar_domain.serialization import (
    build_serialized_event_payload,
    public_metadata,
    sort_serialized_events,
)


class CalendarSerializationTests(unittest.TestCase):
    def test_build_serialized_event_payload_formats_datetime_fields(self) -> None:
        occurrence_start_at = datetime(2026, 4, 5, 9, 30, tzinfo=timezone.utc)
        payload = build_serialized_event_payload(
            event_id="evt_1",
            user_id="user_1",
            title="晨会",
            subtitle=None,
            category="work",
            time_shape="span",
            start_at=datetime(2026, 4, 5, 9, tzinfo=timezone.utc),
            end_at=datetime(2026, 4, 5, 10, tzinfo=timezone.utc),
            timezone="UTC",
            location=None,
            meeting_url=None,
            attendees=[],
            status="scheduled",
            focus_mode_enabled=False,
            metadata={"source": "test"},
            sync_state="pending",
            apple_link=None,
            source="ling",
            provider="ling",
            is_mutable=True,
            is_deletable=True,
            is_recurring=False,
            series_id="evt_1",
            occurrence_start_at=occurrence_start_at,
            is_occurrence_override=False,
            recurrence=None,
        )

        self.assertEqual(payload["start_at"], "2026-04-05T09:00:00+00:00")
        self.assertEqual(payload["end_at"], "2026-04-05T10:00:00+00:00")
        self.assertEqual(payload["occurrence_start_at"], "2026-04-05T09:30:00+00:00")

    def test_build_serialized_event_payload_keeps_missing_occurrence_start_null(
        self,
    ) -> None:
        payload = build_serialized_event_payload(
            event_id="evt_1",
            user_id="user_1",
            title="晨会",
            subtitle=None,
            category="work",
            time_shape="span",
            start_at=datetime(2026, 4, 5, 9, tzinfo=timezone.utc),
            end_at=datetime(2026, 4, 5, 10, tzinfo=timezone.utc),
            timezone="UTC",
            location=None,
            meeting_url=None,
            attendees=[],
            status="scheduled",
            focus_mode_enabled=False,
            metadata={},
            sync_state="pending",
            apple_link=None,
            source="ling",
            provider="ling",
            is_mutable=True,
            is_deletable=True,
            is_recurring=False,
            series_id="evt_1",
            occurrence_start_at=None,
            is_occurrence_override=False,
            recurrence=None,
        )

        self.assertIsNone(payload["occurrence_start_at"])

    def test_public_metadata_hides_internal_fields(self) -> None:
        event = type(
            "Event",
            (),
            {
                "extra_data": {
                    "source": "user",
                    "_override_fields": ["title"],
                    "_apple_recurrence": {"frequency": "daily"},
                    "_private": True,
                    "schedule_insights_error": {"message": "internal failure"},
                }
            },
        )()

        self.assertEqual(public_metadata(event), {"source": "user"})

    def test_sort_serialized_events_uses_start_at_parser(self) -> None:
        events = [
            {"event_id": "late", "start_at": "2026-04-05T10:00:00+00:00"},
            {"event_id": "early", "start_at": "2026-04-05T09:00:00+00:00"},
        ]

        sorted_events = sort_serialized_events(
            events,
            parse_datetime=lambda value: datetime.fromisoformat(value),
        )

        self.assertEqual([item["event_id"] for item in sorted_events], ["early", "late"])
