from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone, tzinfo
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from config import constants

UTC = timezone.utc
_FIXED_OFFSET_RE = re.compile(r"(?:UTC|GMT)([+-])(\d{2})(?::?(\d{2}))$")


def utc_now_naive() -> datetime:
    """Return the current UTC time without tzinfo for DB storage."""
    return datetime.now(UTC).replace(tzinfo=None)


def ensure_utc(value: datetime) -> datetime:
    """Interpret naive values as UTC and normalize aware values to UTC."""
    if value.tzinfo is None or value.utcoffset() is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def to_storage_utc(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    return ensure_utc(value).replace(tzinfo=None)


def to_timezone(value: datetime, zone: tzinfo) -> datetime:
    return ensure_utc(value).astimezone(zone)


def format_datetime(value: datetime | None) -> str | None:
    if value is None:
        return None
    if value.tzinfo is None or value.utcoffset() is None:
        return value.replace(tzinfo=UTC).isoformat()
    return value.isoformat()


def parse_timezone(value: str | None) -> tzinfo:
    normalized = (value or constants.UTC_TIMEZONE_NAME).strip()
    fixed_offset_match = _FIXED_OFFSET_RE.fullmatch(normalized)
    if fixed_offset_match:
        sign = 1 if fixed_offset_match.group(1) == "+" else -1
        hours = int(fixed_offset_match.group(2))
        minutes = int(fixed_offset_match.group(3) or "00")
        if hours > 23 or minutes > 59:
            raise ValueError("Invalid timezone")
        return timezone(sign * timedelta(hours=hours, minutes=minutes))
    return ZoneInfo(normalized)


def is_fixed_offset_timezone_name(value: str | None) -> bool:
    normalized = (value or "").strip()
    if not normalized:
        return False
    return _FIXED_OFFSET_RE.fullmatch(normalized) is not None


def normalize_persisted_timezone(value: str | None, *, allow_empty: bool = False) -> str | None:
    normalized = (value or "").strip()
    if not normalized:
        if allow_empty:
            return None
        raise ValueError("Timezone is required")
    if is_fixed_offset_timezone_name(normalized):
        raise ValueError("Timezone must be an IANA timezone")
    try:
        ZoneInfo(normalized)
    except ZoneInfoNotFoundError as exc:
        raise ValueError("Invalid timezone") from exc
    return normalized
