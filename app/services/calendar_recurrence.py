"""日历重复规则：与多端同步兼容的结构化 recurrence、RRULE 解析/序列化及窗口展开。

约束在「sync-safe」子集内（日/周/月/年等），非法组合在 normalize 阶段即报错。
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from typing import Any

from core.http.exceptions import AppHTTPException

WEEKDAY_CODES = ("MO", "TU", "WE", "TH", "FR", "SA", "SU")
_WEEKDAY_TO_INDEX = {code: index for index, code in enumerate(WEEKDAY_CODES)}
_SUPPORTED_FREQUENCIES = {"daily", "weekly", "monthly", "yearly"}


def normalize_recurrence_payload(payload: Any) -> tuple[dict[str, Any] | None, str | None]:
    if payload is None:
        return None, None
    if isinstance(payload, str):
        payload = {"raw_rrule": payload}
    if not isinstance(payload, dict):
        raise AppHTTPException(status_code=422, detail="recurrence must be an object")

    raw_rrule = _clean_string(payload.get("raw_rrule") or payload.get("rrule"))
    parsed_from_rrule = parse_raw_rrule(raw_rrule) if raw_rrule else {}

    frequency = _clean_string(payload.get("frequency") or payload.get("freq")) or parsed_from_rrule.get(
        "frequency"
    )
    if not frequency:
        return None, None
    frequency = frequency.lower()
    if frequency not in _SUPPORTED_FREQUENCIES:
        raise AppHTTPException(status_code=422, detail="Unsupported recurrence frequency")

    interval = _normalize_positive_int(payload.get("interval"), default=parsed_from_rrule.get("interval", 1))
    count = _normalize_optional_positive_int(payload.get("count"), default=parsed_from_rrule.get("count"))
    until = _normalize_optional_datetime(payload.get("until"), default=parsed_from_rrule.get("until"))
    by_weekday = _normalize_weekdays(payload.get("by_weekday"), default=parsed_from_rrule.get("by_weekday"))
    by_month_day = _normalize_int_list(
        payload.get("by_month_day"),
        default=parsed_from_rrule.get("by_month_day"),
        minimum=1,
        maximum=31,
        field_name="by_month_day",
    )
    by_month = _normalize_int_list(
        payload.get("by_month"),
        default=parsed_from_rrule.get("by_month"),
        minimum=1,
        maximum=12,
        field_name="by_month",
    )

    recurrence = {
        "frequency": frequency,
        "interval": interval,
        "count": count,
        "until": None if until is None else until.isoformat(),
        "by_weekday": by_weekday,
        "by_month_day": by_month_day,
        "by_month": by_month,
    }
    normalized = {key: value for key, value in recurrence.items() if value not in (None, [], "")}
    if raw_rrule is None:
        raw_rrule = serialize_rrule(normalized)
    return normalized, raw_rrule


def serialize_rrule(recurrence: dict[str, Any] | None) -> str | None:
    if not recurrence:
        return None

    frequency = _clean_string(recurrence.get("frequency"))
    if not frequency:
        return None

    parts = [f"FREQ={frequency.upper()}"]
    interval = int(recurrence.get("interval") or 1)
    if interval > 1:
        parts.append(f"INTERVAL={interval}")

    count = recurrence.get("count")
    if count is not None:
        parts.append(f"COUNT={int(count)}")

    until = recurrence.get("until")
    if until:
        until_dt = _normalize_optional_datetime(until)
        if until_dt is None:
            raise AppHTTPException(status_code=422, detail="Invalid recurrence until")
        parts.append(f"UNTIL={until_dt.astimezone(UTC).strftime('%Y%m%dT%H%M%SZ')}")

    by_weekday = recurrence.get("by_weekday") or []
    if by_weekday:
        parts.append("BYDAY=" + ",".join(_normalize_weekdays(by_weekday)))

    by_month_day = recurrence.get("by_month_day") or []
    if by_month_day:
        parts.append("BYMONTHDAY=" + ",".join(str(int(item)) for item in by_month_day))

    by_month = recurrence.get("by_month") or []
    if by_month:
        parts.append("BYMONTH=" + ",".join(str(int(item)) for item in by_month))

    return ";".join(parts)


def parse_raw_rrule(raw_rrule: str | None) -> dict[str, Any]:
    if not raw_rrule:
        return {}

    result: dict[str, Any] = {}
    for part in raw_rrule.split(";"):
        key, _, raw_value = part.partition("=")
        key = key.strip().upper()
        value = raw_value.strip()
        if not key or not value:
            continue
        if key == "FREQ":
            result["frequency"] = value.lower()
        elif key == "INTERVAL":
            result["interval"] = _normalize_positive_int(value, default=1)
        elif key == "COUNT":
            result["count"] = _normalize_optional_positive_int(value)
        elif key == "UNTIL":
            result["until"] = _parse_rrule_until(value)
        elif key == "BYDAY":
            result["by_weekday"] = [item.strip().upper() for item in value.split(",") if item.strip()]
        elif key == "BYMONTHDAY":
            result["by_month_day"] = [int(item) for item in value.split(",") if item.strip()]
        elif key == "BYMONTH":
            result["by_month"] = [int(item) for item in value.split(",") if item.strip()]
    return result


def expand_recurrence_window(
    *,
    series_start_local: datetime,
    series_end_local: datetime,
    recurrence: dict[str, Any],
    window_start_local: datetime,
    window_end_local: datetime,
) -> list[tuple[datetime, datetime]]:
    if window_end_local <= window_start_local:
        return []

    series_start_date = series_start_local.date()
    current_date = series_start_date
    duration = series_end_local - series_start_local
    until_local = _normalize_optional_datetime(recurrence.get("until"))
    limit_date = window_end_local.date()
    if until_local is not None:
        limit_date = min(limit_date, until_local.astimezone(series_start_local.tzinfo).date())

    count_limit = int(recurrence.get("count") or 0)
    occurrences_seen = 0
    results: list[tuple[datetime, datetime]] = []

    while current_date <= limit_date:
        if _matches_recurrence_date(current_date, series_start_date, recurrence):
            occurrence_start_local = datetime.combine(
                current_date,
                series_start_local.timetz(),
                tzinfo=series_start_local.tzinfo,
            )
            if until_local is not None and occurrence_start_local > until_local.astimezone(series_start_local.tzinfo):
                break
            occurrence_end_local = occurrence_start_local + duration
            occurrences_seen += 1
            if duration == timedelta(0):
                overlaps_window = (
                    occurrence_start_local >= window_start_local
                    and occurrence_start_local < window_end_local
                )
            else:
                overlaps_window = (
                    occurrence_end_local > window_start_local
                    and occurrence_start_local < window_end_local
                )
            if overlaps_window:
                results.append((occurrence_start_local, occurrence_end_local))
            if count_limit and occurrences_seen >= count_limit:
                break
        current_date += timedelta(days=1)

    return results


def recurrence_has_supported_shape(recurrence: dict[str, Any] | None) -> bool:
    try:
        validate_supported_recurrence_shape(recurrence)
    except AppHTTPException:
        return False
    return True


def validate_supported_recurrence_shape(recurrence: dict[str, Any] | None) -> None:
    if not recurrence:
        return

    frequency = str(recurrence.get("frequency") or "").strip().lower()
    by_weekday = recurrence.get("by_weekday") or []
    by_month_day = recurrence.get("by_month_day") or []
    by_month = recurrence.get("by_month") or []

    for item in by_weekday:
        if item not in _WEEKDAY_TO_INDEX:
            raise AppHTTPException(status_code=422, detail="recurrence by_weekday contains an invalid weekday code")

    if frequency == "daily":
        if by_weekday:
            raise AppHTTPException(status_code=422, detail="daily recurrence does not support by_weekday")
        if by_month_day:
            raise AppHTTPException(status_code=422, detail="daily recurrence does not support by_month_day")
        if by_month:
            raise AppHTTPException(status_code=422, detail="daily recurrence does not support by_month")
        return

    if frequency == "weekly":
        if by_month_day:
            raise AppHTTPException(status_code=422, detail="weekly recurrence does not support by_month_day")
        if by_month:
            raise AppHTTPException(status_code=422, detail="weekly recurrence does not support by_month")
        return

    if frequency == "monthly":
        if by_weekday:
            raise AppHTTPException(status_code=422, detail="monthly recurrence does not support by_weekday")
        if by_month:
            raise AppHTTPException(status_code=422, detail="monthly recurrence does not support by_month")
        if not by_month_day:
            raise AppHTTPException(
                status_code=422,
                detail="monthly recurrence requires by_month_day when using cross-provider sync-safe mode",
            )
        return

    if frequency == "yearly":
        if by_weekday:
            raise AppHTTPException(status_code=422, detail="yearly recurrence does not support by_weekday")
        if not by_month:
            raise AppHTTPException(
                status_code=422,
                detail="yearly recurrence requires by_month when using cross-provider sync-safe mode",
            )
        if not by_month_day:
            raise AppHTTPException(
                status_code=422,
                detail="yearly recurrence requires by_month_day when using cross-provider sync-safe mode",
            )
        return


def _matches_recurrence_date(
    current_date: date,
    series_start_date: date,
    recurrence: dict[str, Any],
) -> bool:
    frequency = recurrence["frequency"]
    interval = int(recurrence.get("interval") or 1)
    by_weekday = recurrence.get("by_weekday") or []
    by_month_day = recurrence.get("by_month_day") or []
    by_month = recurrence.get("by_month") or []

    if by_weekday:
        normalized_weekday = []
        for item in by_weekday:
            if item not in _WEEKDAY_TO_INDEX:
                return False
            normalized_weekday.append(item)
        if WEEKDAY_CODES[current_date.weekday()] not in normalized_weekday:
            return False

    if frequency == "daily":
        delta_days = (current_date - series_start_date).days
        return delta_days >= 0 and delta_days % interval == 0

    if frequency == "weekly":
        start_week = series_start_date - timedelta(days=series_start_date.weekday())
        current_week = current_date - timedelta(days=current_date.weekday())
        week_delta = (current_week - start_week).days // 7
        if week_delta < 0 or week_delta % interval != 0:
            return False
        if not by_weekday:
            return current_date.weekday() == series_start_date.weekday()
        return True

    if frequency == "monthly":
        month_delta = (current_date.year - series_start_date.year) * 12 + (
            current_date.month - series_start_date.month
        )
        if month_delta < 0 or month_delta % interval != 0:
            return False
        if by_month_day and current_date.day not in {int(item) for item in by_month_day}:
            return False
        if not by_month_day and not by_weekday and current_date.day != series_start_date.day:
            return False
        return True

    if frequency == "yearly":
        year_delta = current_date.year - series_start_date.year
        if year_delta < 0 or year_delta % interval != 0:
            return False
        if by_month and current_date.month not in {int(item) for item in by_month}:
            return False
        if not by_month and current_date.month != series_start_date.month:
            return False
        if by_month_day and current_date.day not in {int(item) for item in by_month_day}:
            return False
        if not by_month_day and not by_weekday and current_date.day != series_start_date.day:
            return False
        return True

    return False


def _clean_string(value: Any) -> str | None:
    normalized = str(value or "").strip()
    return normalized or None


def _normalize_positive_int(value: Any, *, default: int) -> int:
    if value in (None, ""):
        return default
    try:
        resolved = int(value)
    except (TypeError, ValueError) as exc:
        raise AppHTTPException(status_code=422, detail="Invalid recurrence interval") from exc
    if resolved <= 0:
        raise AppHTTPException(status_code=422, detail="recurrence interval must be positive")
    return resolved


def _normalize_optional_positive_int(value: Any, *, default: Any = None) -> int | None:
    candidate = default if value in (None, "") else value
    if candidate in (None, ""):
        return None
    try:
        resolved = int(candidate)
    except (TypeError, ValueError) as exc:
        raise AppHTTPException(status_code=422, detail="Invalid recurrence count") from exc
    if resolved <= 0:
        raise AppHTTPException(status_code=422, detail="recurrence count must be positive")
    return resolved


def _normalize_optional_datetime(value: Any, *, default: Any = None) -> datetime | None:
    candidate = default if value in (None, "") else value
    if candidate in (None, ""):
        return None
    if isinstance(candidate, datetime):
        parsed = candidate
    else:
        try:
            parsed = datetime.fromisoformat(str(candidate).replace("Z", "+00:00"))
        except ValueError as exc:
            raise AppHTTPException(status_code=422, detail="Invalid recurrence until") from exc
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise AppHTTPException(
            status_code=422,
            detail="recurrence until must include timezone offset",
        )
    return parsed


def _normalize_weekdays(value: Any, *, default: Any = None) -> list[str]:
    candidate = default if value in (None, "") else value
    if candidate in (None, ""):
        return []
    if isinstance(candidate, str):
        items = [item.strip().upper() for item in candidate.split(",") if item.strip()]
    elif isinstance(candidate, list):
        items = [str(item).strip().upper() for item in candidate if str(item).strip()]
    else:
        raise AppHTTPException(status_code=422, detail="by_weekday must be a list of weekday codes")

    normalized: list[str] = []
    for item in items:
        if item not in _WEEKDAY_TO_INDEX:
            raise AppHTTPException(status_code=422, detail="Unsupported BYDAY value")
        if item not in normalized:
            normalized.append(item)
    return normalized


def _normalize_int_list(
    value: Any,
    *,
    default: Any = None,
    minimum: int,
    maximum: int,
    field_name: str,
) -> list[int]:
    candidate = default if value in (None, "") else value
    if candidate in (None, ""):
        return []
    if isinstance(candidate, str):
        items = [item.strip() for item in candidate.split(",") if item.strip()]
    elif isinstance(candidate, list):
        items = candidate
    else:
        raise AppHTTPException(status_code=422, detail=f"{field_name} must be a list of integers")

    normalized: list[int] = []
    for item in items:
        try:
            resolved = int(item)
        except (TypeError, ValueError) as exc:
            raise AppHTTPException(status_code=422, detail=f"Invalid {field_name} value") from exc
        if resolved < minimum or resolved > maximum:
            raise AppHTTPException(status_code=422, detail=f"{field_name} is out of range")
        if resolved not in normalized:
            normalized.append(resolved)
    return normalized


def _parse_rrule_until(value: str) -> str:
    value = value.strip()
    if not value:
        raise AppHTTPException(status_code=422, detail="Invalid recurrence until")

    for pattern in ("%Y%m%dT%H%M%SZ", "%Y%m%dT%H%M%S", "%Y%m%d"):
        try:
            parsed = datetime.strptime(value, pattern)
        except ValueError:
            continue
        if pattern.endswith("Z"):
            return parsed.replace(tzinfo=UTC).isoformat()
        if pattern == "%Y%m%d":
            return parsed.replace(tzinfo=UTC).isoformat()
        return parsed.replace(tzinfo=UTC).isoformat()

    raise AppHTTPException(status_code=422, detail="Invalid recurrence until")
