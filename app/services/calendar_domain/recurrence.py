"""Calendar recurrence serialization helpers."""

from __future__ import annotations

from datetime import datetime
from typing import Any, Callable

from services.calendar_recurrence import parse_raw_rrule
from utils.time import format_datetime


def effective_recurrence(event: Any) -> dict[str, Any] | None:
    structured = dict(getattr(event, "recurrence_rule", None) or {})
    recurrence_rrule = getattr(event, "recurrence_rrule", None)
    if recurrence_rrule:
        parsed = parse_raw_rrule(recurrence_rrule)
        for key, value in parsed.items():
            if structured.get(key) in (None, [], ""):
                structured[key] = value
    return structured or None


def serialize_recurrence(
    event: Any,
    *,
    get_zone: Callable[[str], Any],
    to_local: Callable[[datetime, Any], datetime],
) -> dict[str, Any] | None:
    recurrence = effective_recurrence(event)
    if not recurrence:
        return None
    recurrence = {
        key: value for key, value in recurrence.items() if value not in (None, [], "")
    }
    recurrence_rrule = getattr(event, "recurrence_rrule", None)
    if recurrence_rrule:
        recurrence["raw_rrule"] = recurrence_rrule
    zone = get_zone(event.timezone)
    recurrence["anchor_start_at"] = format_datetime(to_local(event.start_at, zone))
    recurrence["anchor_end_at"] = format_datetime(to_local(event.end_at, zone))
    return recurrence


def serialize_imported_apple_recurrence(
    event: Any,
    *,
    get_zone: Callable[[str], Any],
    to_local: Callable[[datetime, Any], datetime],
) -> dict[str, Any] | None:
    metadata = dict(getattr(event, "extra_data", None) or {})
    recurrence = metadata.get("_apple_recurrence")
    recurrence = dict(recurrence) if isinstance(recurrence, dict) else None
    if not recurrence:
        recurrence = serialize_recurrence(event, get_zone=get_zone, to_local=to_local)
    if not recurrence:
        return None

    raw_rrules = metadata.get("raw_rrules") or recurrence.get("raw_rrules") or []
    if isinstance(raw_rrules, str):
        raw_rrules = [raw_rrules]
    raw_rrules = [str(item).strip() for item in raw_rrules if str(item).strip()]
    if raw_rrules:
        recurrence["raw_rrules"] = raw_rrules

    recurrence_rrule = (
        str(metadata.get("_apple_recurrence_rrule") or "").strip()
        or str(recurrence.get("raw_rrule") or "").strip()
        or (raw_rrules[0] if raw_rrules else "")
    )
    if recurrence_rrule:
        recurrence["raw_rrule"] = recurrence_rrule
    return {key: value for key, value in recurrence.items() if value not in (None, [], "")}
