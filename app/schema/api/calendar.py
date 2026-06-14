"""Calendar API payload schemas."""

from __future__ import annotations

from typing import Annotated, Literal

from config import constants
from pydantic import BaseModel, Field, field_validator

RecurrenceFrequency = Literal["daily", "weekly", "monthly", "yearly"]
RecurrenceWeekday = Literal["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
MonthDayValue = Annotated[int, Field(ge=-31, le=31)]
MonthValue = Annotated[int, Field(ge=1, le=12)]


class RecurrencePayload(BaseModel):
    frequency: RecurrenceFrequency
    interval: int = Field(default=1, ge=1)
    count: int | None = Field(default=None, ge=1)
    until: str | None = None
    by_weekday: list[RecurrenceWeekday] = Field(default_factory=list)
    by_month_day: list[MonthDayValue] = Field(default_factory=list)
    by_month: list[MonthValue] = Field(default_factory=list)
    raw_rrule: str | None = None

    @field_validator("by_month_day")
    @classmethod
    def _validate_by_month_day(cls, value: list[int]) -> list[int]:
        if any(item == 0 for item in value):
            raise ValueError("by_month_day cannot contain 0")
        return value


class CalendarEventPayload(BaseModel):
    source: str = constants.CALENDAR_SOURCE_LING
    title: str
    subtitle: str | None = None
    category: str = constants.DEFAULT_CALENDAR_CATEGORY
    time_shape: Literal[constants.CALENDAR_TIME_SHAPE_SPAN, constants.CALENDAR_TIME_SHAPE_POINT] = (
        constants.CALENDAR_TIME_SHAPE_SPAN
    )
    start_at: str
    end_at: str
    timezone: str = constants.UTC_TIMEZONE_NAME
    location: str | None = None
    meeting_url: str | None = None
    attendees: list[dict] = Field(default_factory=list)
    status: str = constants.CALENDAR_STATUS_SCHEDULED
    focus_mode_enabled: bool = False
    metadata: dict = Field(default_factory=dict)
    recurrence: RecurrencePayload | None = None


class CalendarEventUpdatePayload(BaseModel):
    title: str | None = None
    subtitle: str | None = None
    category: str | None = None
    time_shape: Literal[constants.CALENDAR_TIME_SHAPE_SPAN, constants.CALENDAR_TIME_SHAPE_POINT] | None = None
    start_at: str | None = None
    end_at: str | None = None
    timezone: str | None = None
    location: str | None = None
    meeting_url: str | None = None
    attendees: list[dict] | None = None
    status: str | None = None
    focus_mode_enabled: bool | None = None
    metadata: dict | None = None
    recurrence: RecurrencePayload | None = None
    scope: str = "series"
    occurrence_start_time: str | None = None


__all__ = [
    "CalendarEventPayload",
    "CalendarEventUpdatePayload",
    "MonthDayValue",
    "MonthValue",
    "RecurrenceFrequency",
    "RecurrencePayload",
    "RecurrenceWeekday",
]
