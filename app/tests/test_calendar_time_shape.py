import unittest
from datetime import datetime, timedelta, timezone

from core.http.exceptions import AppHTTPException
from services.calendar_domain.time_shape import (
    event_window_overlaps,
    normalize_time_shape,
    validate_time_shape_window,
)


class CalendarTimeShapeTests(unittest.TestCase):
    def test_normalize_time_shape_defaults_to_span(self) -> None:
        self.assertEqual(normalize_time_shape(None), "span")
        self.assertEqual(normalize_time_shape(" POINT "), "point")

    def test_normalize_time_shape_rejects_unknown_values(self) -> None:
        with self.assertRaises(AppHTTPException):
            normalize_time_shape("deadline")

    def test_validate_span_requires_positive_window(self) -> None:
        start = datetime(2026, 4, 5, 9, tzinfo=timezone.utc)
        validate_time_shape_window("span", start, start + timedelta(minutes=1))

        with self.assertRaises(AppHTTPException):
            validate_time_shape_window("span", start, start)

        with self.assertRaises(AppHTTPException):
            validate_time_shape_window("span", start, start - timedelta(minutes=1))

    def test_validate_point_requires_equal_window(self) -> None:
        start = datetime(2026, 4, 5, 9, tzinfo=timezone.utc)
        validate_time_shape_window("point", start, start)

        with self.assertRaises(AppHTTPException):
            validate_time_shape_window("point", start, start + timedelta(minutes=1))

    def test_point_overlap_uses_start_in_window(self) -> None:
        start = datetime(2026, 4, 5, 9, tzinfo=timezone.utc)
        window_start = datetime(2026, 4, 5, 8, tzinfo=timezone.utc)
        window_end = datetime(2026, 4, 5, 10, tzinfo=timezone.utc)

        self.assertTrue(
            event_window_overlaps(
                start_at=start,
                end_at=start,
                window_start=window_start,
                window_end=window_end,
                time_shape="point",
            )
        )
        self.assertFalse(
            event_window_overlaps(
                start_at=window_end,
                end_at=window_end,
                window_start=window_start,
                window_end=window_end,
                time_shape="point",
            )
        )

    def test_span_overlap_uses_half_open_interval(self) -> None:
        window_start = datetime(2026, 4, 5, 8, tzinfo=timezone.utc)
        window_end = datetime(2026, 4, 5, 10, tzinfo=timezone.utc)

        self.assertTrue(
            event_window_overlaps(
                start_at=datetime(2026, 4, 5, 7, 30, tzinfo=timezone.utc),
                end_at=datetime(2026, 4, 5, 8, 1, tzinfo=timezone.utc),
                window_start=window_start,
                window_end=window_end,
                time_shape="span",
            )
        )
        self.assertFalse(
            event_window_overlaps(
                start_at=datetime(2026, 4, 5, 7, 0, tzinfo=timezone.utc),
                end_at=window_start,
                window_start=window_start,
                window_end=window_end,
                time_shape="span",
            )
        )
        self.assertFalse(
            event_window_overlaps(
                start_at=window_end,
                end_at=datetime(2026, 4, 5, 10, 30, tzinfo=timezone.utc),
                window_start=window_start,
                window_end=window_end,
                time_shape="span",
            )
        )
