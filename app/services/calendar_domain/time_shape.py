"""Calendar event time-shape policy.

This module keeps the durable event shape rules out of CalendarService so the
same span/point semantics can be reused by creation, updates, recurrence, and
import paths without growing the service class further.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from config import constants
from core.http.exceptions import AppHTTPException
from utils.time import ensure_utc


def normalize_time_shape(value: Any) -> str:
    normalized = str(value or constants.CALENDAR_TIME_SHAPE_SPAN).strip().lower()
    if normalized in {
        constants.CALENDAR_TIME_SHAPE_SPAN,
        constants.CALENDAR_TIME_SHAPE_POINT,
    }:
        return normalized
    raise AppHTTPException(status_code=422, detail="time_shape must be span or point")


def event_time_shape(event: Any) -> str:
    return normalize_time_shape(
        getattr(event, "time_shape", constants.CALENDAR_TIME_SHAPE_SPAN)
    )


def validate_time_shape_window(
    time_shape: str,
    start_at: datetime,
    end_at: datetime,
) -> None:
    if normalize_time_shape(time_shape) == constants.CALENDAR_TIME_SHAPE_POINT:
        if ensure_utc(start_at) != ensure_utc(end_at):
            raise AppHTTPException(
                status_code=422,
                detail="point event requires start_at to equal end_at",
            )
        return
    if ensure_utc(end_at) <= ensure_utc(start_at):
        raise AppHTTPException(status_code=422, detail="end_at must be after start_at")


def event_window_overlaps(
    *,
    start_at: datetime,
    end_at: datetime,
    window_start: datetime,
    window_end: datetime,
    time_shape: str,
) -> bool:
    start_utc = ensure_utc(start_at)
    if normalize_time_shape(time_shape) == constants.CALENDAR_TIME_SHAPE_POINT:
        return start_utc >= ensure_utc(window_start) and start_utc < ensure_utc(window_end)
    return ensure_utc(end_at) > ensure_utc(window_start) and start_utc < ensure_utc(window_end)
