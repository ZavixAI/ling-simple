from __future__ import annotations

import unittest
from datetime import date
from unittest.mock import AsyncMock
from config import constants

from services.calendar import CalendarService


class CalendarMonthViewTests(unittest.IsolatedAsyncioTestCase):
    async def test_build_month_view_counts_cross_day_event_on_each_day(self) -> None:
        service = CalendarService()
        service._list_occurrence_views = AsyncMock(
            return_value=[
                {
                    "event_id": "evt_trip",
                    "title": "Trip",
                    "start_at": "2026-04-18T08:00:00+08:00",
                    "end_at": "2026-04-19T21:00:00+08:00",
                    "source": "ling",
                }
            ]
        )
        service.list_events_for_date = AsyncMock(return_value=[])

        result = await service.build_month_view(
            user_id="user-1",
            month_value="2026-04",
            timezone=constants.DEFAULT_TIMEZONE,
            selected_date=date(2026, 4, 18),
        )

        day_map = {item["date"]: item for item in result["days"]}
        self.assertEqual(day_map["2026-04-18"]["event_count"], 1)
        self.assertEqual(day_map["2026-04-19"]["event_count"], 1)


if __name__ == "__main__":
    unittest.main()
