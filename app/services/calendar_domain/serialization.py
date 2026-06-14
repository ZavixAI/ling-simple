"""Provider-neutral calendar serialization helpers."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from utils.time import format_datetime


def build_serialized_event_payload(
    *,
    event_id: str,
    user_id: str,
    title: str,
    subtitle: str | None,
    category: str,
    time_shape: str,
    start_at: datetime,
    end_at: datetime,
    timezone: str,
    location: str | None,
    meeting_url: str | None,
    attendees: list[Any],
    status: str,
    focus_mode_enabled: bool,
    metadata: dict[str, Any],
    sync_state: str,
    apple_link: dict[str, Any] | None,
    source: str,
    provider: str,
    is_mutable: bool,
    is_deletable: bool,
    is_recurring: bool,
    series_id: str,
    occurrence_start_at: datetime | None,
    is_occurrence_override: bool,
    recurrence: dict[str, Any] | None,
    created_at: datetime | None = None,
    updated_at: datetime | None = None,
) -> dict[str, Any]:
    return {
        "event_id": event_id,
        "user_id": user_id,
        "title": title,
        "subtitle": subtitle,
        "category": category,
        "time_shape": time_shape,
        "start_at": format_datetime(start_at),
        "end_at": format_datetime(end_at),
        "timezone": timezone,
        "location": location,
        "meeting_url": meeting_url,
        "attendees": attendees,
        "status": status,
        "focus_mode_enabled": focus_mode_enabled,
        "metadata": metadata,
        "sync_state": sync_state,
        "apple_link": apple_link,
        "source": source,
        "provider": provider,
        "is_mutable": is_mutable,
        "is_deletable": is_deletable,
        "is_recurring": is_recurring,
        "series_id": series_id,
        "occurrence_start_at": None
        if occurrence_start_at is None
        else format_datetime(occurrence_start_at),
        "is_occurrence_override": is_occurrence_override,
        "recurrence": recurrence,
        "created_at": None if created_at is None else format_datetime(created_at),
        "updated_at": None if updated_at is None else format_datetime(updated_at),
    }


def public_metadata(event: Any) -> dict[str, Any]:
    return {
        key: value
        for key, value in (getattr(event, "extra_data", None) or {}).items()
        if not str(key).startswith("_") and key != "schedule_insights_error"
    }


def sort_serialized_events(
    events: list[dict[str, Any]],
    *,
    parse_datetime: Any,
) -> list[dict[str, Any]]:
    return sorted(events, key=lambda item: parse_datetime(item["start_at"]))
