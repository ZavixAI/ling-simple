"""Integration API payload schemas."""

from __future__ import annotations

from pydantic import BaseModel, Field


class AppleEventLinkPayload(BaseModel):
    event_id: str
    device_id: str
    calendar_identifier: str
    event_identifier: str
    sync_state: str = "linked"
    metadata: dict = Field(default_factory=dict)


class AppleCalendarContextPayload(BaseModel):
    device_id: str
    window_start: str
    window_end: str
    timezone: str | None = None
    permission_state: str = "granted"
    events: list[dict] = Field(default_factory=list)


class CalendarOAuthCompletePayload(BaseModel):
    callback_url: str


class CalendarProviderPathPayload(BaseModel):
    provider: str


__all__ = [
    "AppleCalendarContextPayload",
    "AppleEventLinkPayload",
    "CalendarOAuthCompletePayload",
    "CalendarProviderPathPayload",
]

