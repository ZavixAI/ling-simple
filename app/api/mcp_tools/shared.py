# ruff: noqa: F401,I001
"""Shared MCP runtime, schemas, and helper functions."""

from __future__ import annotations

import hashlib
import json
import re
import uuid
from datetime import datetime, time as dt_time, timedelta
from datetime import timezone as dt_timezone
from time import perf_counter
from typing import Annotated, Any, Literal, Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from config import constants, get_app_config
from core.http.exceptions import AppHTTPException
from fastmcp import FastMCP
from loguru import logger
from modules.membership.entitlements import (
    FEATURE_ALL_TOOLS,
)
from modules.membership.service import MembershipService
from pydantic import (
    BaseModel,
    BeforeValidator,
    ConfigDict,
    Field,
    ValidationError,
    field_validator,
    model_validator,
)
from pydantic.json_schema import SkipJsonSchema
from services.amap import AmapWebService
from services.calendar import CalendarService
from services.calendar_domain.source import (
    normalize_source as normalize_calendar_source,
)
from services.calendar_domain.source import (
    provider_for_source,
)
from services.calendar_recurrence import (
    normalize_recurrence_payload,
    validate_supported_recurrence_shape,
)
from services.mcp_next_actions import calendar_next_actions, next_actions_for_tool_result
from utils.time import (
    format_datetime,
    normalize_persisted_timezone,
    parse_timezone,
    to_storage_utc,
    to_timezone,
)

ling_mcp = FastMCP(name="LING MCP ")
ling_mcp_http = ling_mcp.http_app("/mcp")

CalendarCategory = Literal[
    "personal",
    "work",
    "meeting",
    "travel",
    "health",
    "family",
    "other",
]
METADATA_MARKDOWN_REQUIREMENTS = (
    "Metadata must be one complete Markdown document, not JSON. "
    "Write it richly enough for the user to understand later. "
    "Include these sections when applicable: "
    "## 背景/原文, ## 关键信息, ## 判断与结论, ## 后续动作, ## 记录来源. "
    "If a section is not applicable, write 无. "
    "When the user's message includes image or file attachment references, preserve useful ones in Markdown with their Ling agent workspace links, including image syntax such as ![title](file:///app/agents/.../upload_files/...). "
    "Metadata updates are full replacements for the Markdown note, so include any existing useful note content that should be kept."
)

_CARD_RENDERED_NEXT_TIP_BY_ACTION: dict[str, str] = {
    "travel_flight_search": "Review the flight options and ask which one the user wants to keep. Do not repeat every option in full unless the user asks.",
    "travel_hotel_search": "Review the hotel options and ask which one the user wants to keep. Do not repeat every option in full unless the user asks.",
}


def _empty_string_to_none(value: Any) -> Any:
    if value == "":
        return None
    return value


async def _ensure_membership_feature(user_id: str, feature_code: str) -> None:
    await MembershipService().ensure_feature(user_id, feature_code)


async def _ensure_all_tools_feature(user_id: str) -> None:
    await _ensure_membership_feature(user_id, FEATURE_ALL_TOOLS)


_MCP_USER_TIMEZONE_DATETIME_KEYS = {
    "scheduled_at",
    "send_time",
    "delivered_at",
    "opened_at",
    "dismissed_at",
    "failed_at",
    "earliest_start_at",
    "latest_end_at",
    "resolved_at",
    "range_start",
    "range_end",
    "created_at",
    "updated_at",
    "next_check_at",
    "last_checked_at",
    "last_notification_at",
}

class EventUpdates(BaseModel):
    event_title: Annotated[str | SkipJsonSchema[None], Field(description="Updated calendar event title.")] = None
    subtitle: Annotated[str | SkipJsonSchema[None], Field(description="Updated event subtitle or summary.")] = None
    category: Annotated[CalendarCategory | SkipJsonSchema[None], Field(description="Updated category.")] = None
    start_time: Annotated[str | SkipJsonSchema[None], Field(description="Updated ISO8601 start time including timezone offset.")] = None
    end_time: Annotated[str | SkipJsonSchema[None], Field(description="Updated ISO8601 end time including timezone offset.")] = None
    timezone: Annotated[str | SkipJsonSchema[None], Field(description=f"Updated IANA timezone name, for example {constants.DEFAULT_TIMEZONE}.")] = None
    location: Annotated[str | SkipJsonSchema[None], Field(description="Updated physical location.")] = None
    meeting_url: Annotated[str | SkipJsonSchema[None], Field(description="Updated online meeting URL.")] = None
    scope: Annotated[
        Literal["series", "occurrence"] | SkipJsonSchema[None],
        Field(description="Mutation scope for recurring events: series or occurrence."),
    ] = None
    occurrence_start_time: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Original ISO8601 occurrence start including timezone offset. Required when scope=occurrence."),
    ] = None


def _normalize_string_list(value: Any, *, field_name: str) -> list[str] | None:
    if value is None:
        return None
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return []
        try:
            parsed = json.loads(stripped)
        except json.JSONDecodeError:
            return [item.strip() for item in stripped.split(",") if item.strip()]
        if isinstance(parsed, list):
            return [str(item).strip() for item in parsed if str(item).strip()]
        if isinstance(parsed, str):
            parsed = parsed.strip()
            return [parsed] if parsed else []
    raise ValueError(f"{field_name} must be a JSON array")


def _normalize_update_object(value: Any, *, field_name: str) -> dict[str, Any]:
    normalized = _normalize_structured_object(
        value,
        field_name=field_name,
        raw_key="raw_update",
    )
    if normalized is None:
        return {}
    if "raw_update" in normalized:
        raise ValueError(f"{field_name} must be a JSON object with update fields")
    return normalized

def _inline_partial_update_schema(model: type[BaseModel]) -> dict[str, Any]:
    schema = _inline_json_schema_refs(model.model_json_schema(mode="validation"))
    return {
        "type": "object",
        "properties": schema.get("properties", {}),
        "additionalProperties": True,
    }


SUPPORTED_RRULE_DETAIL = {
    "supported_syntax": (
        "VEVENT must include SUMMARY and DTSTART. DTEND is required for span events and omitted for point reminders. RRULE is optional. "
        "Supported RRULE subset: FREQ=DAILY|WEEKLY|MONTHLY|YEARLY; optional INTERVAL, COUNT, UNTIL, BYDAY, BYMONTHDAY, BYMONTH. "
        "Daily supports INTERVAL/COUNT/UNTIL only. Weekly may use BYDAY. Monthly must use BYMONTHDAY when repeating by month. "
        "Yearly must use BYMONTH and BYMONTHDAY. DTSTART and DTEND must include X-LING-WEEKDAY=MO|TU|WE|TH|FR|SA|SU."
    ),
    "examples": [
        f"BEGIN:VEVENT\nSUMMARY:Morning sync\nDTSTART;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=TU:20260512T090000\nDTEND;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=TU:20260512T093000\nEND:VEVENT",
        f"BEGIN:VEVENT\nSUMMARY:Call parents\nDTSTART;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=TU:20260512T200000\nEND:VEVENT",
        f"BEGIN:VEVENT\nSUMMARY:Weekly standup\nDTSTART;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=TU:20260512T090000\nDTEND;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=TU:20260512T093000\nRRULE:FREQ=WEEKLY;BYDAY=TU;COUNT=8\nEND:VEVENT",
        f"BEGIN:VEVENT\nSUMMARY:Monthly review\nDTSTART;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=FR:20260515T140000\nDTEND;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=FR:20260515T150000\nRRULE:FREQ=MONTHLY;BYMONTHDAY=15\nEND:VEVENT",
    ],
}

_ICAL_WEEKDAY_PARAM = "X-LING-WEEKDAY"
_ICAL_WEEKDAY_CODES = ("MO", "TU", "WE", "TH", "FR", "SA", "SU")


def _inline_json_schema_refs(schema: dict[str, Any]) -> dict[str, Any]:
    defs = schema.get("$defs", {})

    def resolve(node: Any) -> Any:
        if isinstance(node, list):
            return [resolve(item) for item in node]
        if not isinstance(node, dict):
            return node

        if "$ref" in node:
            ref = str(node["$ref"])
            if ref.startswith("#/$defs/"):
                ref_name = ref.rsplit("/", 1)[-1]
                resolved_ref = resolve(defs.get(ref_name, {}))
                merged = {
                    key: resolve(value)
                    for key, value in node.items()
                    if key not in {"$ref", "$defs"}
                }
                if isinstance(resolved_ref, dict):
                    return {**resolved_ref, **merged}
                return resolved_ref

        return {
            key: resolve(value)
            for key, value in node.items()
            if key != "$defs"
        }

    return resolve(schema)


def _success(
    action: str,
    data: Any,
    *,
    warnings: Optional[list[dict[str, Any]]] = None,
    next_actions: Optional[list[dict[str, Any]]] = None,
    next_tip: Optional[str] = None,
) -> dict[str, Any]:
    result = {
        "ok": True,
        "action": action,
        "data": data,
        "warnings": warnings or [],
    }
    normalized_tip = (
        next_tip or _CARD_RENDERED_NEXT_TIP_BY_ACTION.get(action) or ""
    ).strip()
    if normalized_tip:
        result["next_tip"] = normalized_tip
    if next_actions is None:
        next_actions = next_actions_for_tool_result(
            action,
            data if isinstance(data, dict) else {},
        )
    normalized_actions = [
        item
        for item in (next_actions or [])
        if item.get("label") and item.get("prompt")
    ]
    if normalized_actions:
        result["next_actions"] = normalized_actions[:3]
    return result


def _mcp_log_ref(value: Any) -> str:
    return hashlib.sha256(str(value).encode("utf-8")).hexdigest()[:10]


async def _resolve_mcp_user_timezone(user_id: str) -> str:
    from models.push import UserPushDeviceDao
    from models.user import UserConfigDao

    try:
        device = await UserPushDeviceDao().get_latest_device(user_id)
    except Exception:
        device = None
    if device is not None and device.timezone:
        try:
            parse_timezone(device.timezone)
            return device.timezone
        except Exception:
            pass

    try:
        config = await UserConfigDao().get_config(user_id)
    except Exception:
        config = {}
    configured_timezone = str(config.get("timezone") or "").strip()
    if configured_timezone:
        try:
            parse_timezone(configured_timezone)
            return configured_timezone
        except Exception:
            pass
    return constants.DEFAULT_TIMEZONE


def _format_mcp_datetime_for_user_timezone(value: Any, timezone_name: str) -> Any:
    if value is None:
        return None
    try:
        zone = parse_timezone(timezone_name)
    except Exception:
        zone = parse_timezone(constants.DEFAULT_TIMEZONE)
    try:
        if isinstance(value, datetime):
            return format_datetime(to_timezone(value, zone))
        if isinstance(value, str):
            stripped = value.strip()
            if not stripped:
                return value
            parsed = datetime.fromisoformat(stripped.replace("Z", "+00:00"))
            return format_datetime(to_timezone(parsed, zone))
    except ValueError:
        return value
    return value


def _localize_mcp_user_datetime_fields(value: Any, timezone_name: str) -> Any:
    if isinstance(value, dict):
        localized = {
            key: (
                _format_mcp_datetime_for_user_timezone(item, timezone_name)
                if key in _MCP_USER_TIMEZONE_DATETIME_KEYS
                else _localize_mcp_user_datetime_fields(item, timezone_name)
            )
            for key, item in value.items()
        }
        if (
            "resolved_at" in localized
            and "timezone" in localized
            and ("raw_text" in localized or "kind" in localized)
        ):
            localized["timezone"] = timezone_name
        return localized
    if isinstance(value, list):
        return [_localize_mcp_user_datetime_fields(item, timezone_name) for item in value]
    if isinstance(value, tuple):
        return [_localize_mcp_user_datetime_fields(item, timezone_name) for item in value]
    return value


def _error(
    action: str,
    exc: Exception,
    *,
    fallback_message: str = "Tool execution failed",
) -> dict[str, Any]:
    if isinstance(exc, ValidationError):
        validation_errors = _validation_errors(exc)
        return {
            "ok": False,
            "action": action,
            "error": {
                "message": "Input validation failed.",
                "status_code": 422,
                "error_code": "INPUT_VALIDATION_ERROR",
                "error_detail": validation_errors,
                "next_action": _validation_next_action(exc),
                "fix_suggestions": _validation_fix_suggestions(validation_errors),
            },
        }
    if isinstance(exc, ValueError):
        return {
            "ok": False,
            "action": action,
            "error": {
                "message": str(exc) or "Input validation failed.",
                "status_code": 422,
                "error_code": "INPUT_VALIDATION_ERROR",
                "error_detail": str(exc),
                "next_action": (
                    "Fix the tool arguments and call the same tool again. "
                    "For object/list fields, pass real JSON objects or arrays instead of escaped strings."
                ),
                "fix_suggestions": [],
            },
        }
    if isinstance(exc, AppHTTPException):
        return {
            "ok": False,
            "action": action,
            "error": {
                "message": exc.detail,
                "status_code": exc.status_code,
                "error_code": exc.error_code,
                "error_detail": exc.error_detail,
                "next_action": _http_next_action(exc),
            },
        }
    return {
        "ok": False,
        "action": action,
        "error": {
            "message": fallback_message,
            "status_code": 500,
            "error_code": "TOOL_EXECUTION_FAILED",
            "error_detail": str(exc),
            "next_action": "Inspect the error_detail, fix the arguments if needed, and retry only when the failure is recoverable.",
        },
    }


def _validation_next_action(exc: ValidationError) -> str:
    return (
        "Fix the tool arguments and call the same tool again. "
        "Use the field paths in fix_suggestions/error_detail. "
        "Pass object fields as JSON objects, list fields as JSON arrays, and datetime fields as ISO8601 strings with timezone offsets."
    )


def _validation_errors(exc: ValidationError) -> list[dict[str, Any]]:
    sanitized: list[dict[str, Any]] = []
    for error in exc.errors(include_url=False):
        item = dict(error)
        ctx = item.get("ctx")
        if isinstance(ctx, dict):
            item["ctx"] = {key: str(value) for key, value in ctx.items()}
        sanitized.append(item)
    return sanitized


def _validation_fix_suggestions(errors: list[dict[str, Any]]) -> list[dict[str, Any]]:
    suggestions: list[dict[str, Any]] = []
    for error in errors:
        loc = ".".join(str(part) for part in error.get("loc", ())) or "input"
        error_type = str(error.get("type") or "")
        message = str(error.get("msg") or "")
        suggestion = "Correct this field and retry."
        if "dict" in error_type or "model_type" in error_type:
            suggestion = "Pass a JSON object for this field, not an escaped JSON string or plain text."
        elif "list" in error_type:
            suggestion = "Pass a JSON array for this field. A comma-separated string is accepted only where explicitly documented."
        elif "literal_error" in error_type:
            suggestion = "Use one of the enum values shown in the schema/error context."
        elif "datetime" in error_type:
            suggestion = "Pass an ISO8601 datetime string with timezone offset, for example 2026-05-11T20:30:00+08:00."
        elif "missing" in error_type:
            suggestion = "Add this required field."
        suggestions.append(
            {
                "field": loc,
                "error_type": error_type,
                "message": message,
                "suggestion": suggestion,
            }
        )
    return suggestions


def _http_next_action(exc: AppHTTPException) -> str:
    code = str(exc.error_code or "").strip()
    detail = str(exc.detail or "").lower()
    if code == "CALENDAR_EVENT_DELETED":
        return (
            "The target item was deleted and cannot be changed. Confirm the target ID "
            "with list/search tools, or create a new item if the user wants to keep it."
        )
    if exc.status_code == 409 or code == "CALENDAR_CONFLICT":
        return "Review the returned conflicts. Retry with force=true only if the user explicitly wants to keep the overlapping time."
    if code == "CALENDAR_PAST_TIME":
        return "Choose a future time. Retry with force=true only if the user explicitly wants to backfill or record a past event."
    if "future" in detail or "past" in detail:
        return "Choose a future ISO8601 datetime with timezone offset, then retry."
    if "required" in detail:
        return "Add the missing required argument described in the error message, then retry."
    return "Fix the request according to message/error_detail and retry only if the user request is still valid."


def _extract_timezone_name(value: Any) -> str:
    tzinfo = getattr(value, "tzinfo", None)
    zone_key = getattr(tzinfo, "key", None)
    if zone_key:
        return str(zone_key)
    return str(tzinfo or constants.UTC_TIMEZONE_NAME)


async def _resolve_event_timezone(
    service: CalendarService,
    user_id: str,
    start_dt: datetime,
    *,
    explicit_timezone: Optional[str] = None,
    fallback_timezone: Optional[str] = None,
) -> str:
    if explicit_timezone not in (None, ""):
        candidate = _normalize_persisted_timezone_or_422(str(explicit_timezone))
        if not _timezone_matches_datetime_offset(service, candidate, start_dt):
            raise AppHTTPException(
                status_code=422,
                detail="timezone does not match timestamp offset",
            )
        return candidate

    for candidate in (fallback_timezone,):
        normalized = _normalize_optional_persisted_timezone(candidate)
        if normalized and _timezone_matches_datetime_offset(service, normalized, start_dt):
            return normalized

    configured_timezone = await _user_config_timezone(user_id)
    for candidate in (
        configured_timezone,
        _extract_iana_timezone_name(start_dt),
    ):
        normalized = _normalize_optional_persisted_timezone(candidate)
        if normalized and _timezone_matches_datetime_offset(service, normalized, start_dt):
            return normalized

    raise AppHTTPException(
        status_code=422,
        detail="Unable to resolve an IANA timezone for the provided timestamp",
    )


async def _user_config_timezone(user_id: str) -> str | None:
    from models.user import UserConfigDao

    config = await UserConfigDao().get_config(user_id)
    return str(config.get("timezone") or "").strip() or None


def _extract_iana_timezone_name(value: Any) -> str | None:
    tzinfo = getattr(value, "tzinfo", None)
    zone_key = getattr(tzinfo, "key", None)
    if zone_key:
        return str(zone_key)
    return None


def _normalize_optional_persisted_timezone(value: str | None) -> str | None:
    try:
        return normalize_persisted_timezone(value, allow_empty=True)
    except ValueError:
        return None


def _normalize_persisted_timezone_or_422(value: str | None) -> str:
    try:
        normalized = normalize_persisted_timezone(value)
    except ValueError as exc:
        raise AppHTTPException(status_code=422, detail="Invalid timezone") from exc
    if normalized is None:
        raise AppHTTPException(status_code=422, detail="Invalid timezone")
    return normalized


def _timezone_matches_datetime_offset(
    service: CalendarService,
    timezone_name: str,
    value: datetime,
) -> bool:
    offset = value.utcoffset()
    if offset is None:
        return False
    zone = service._get_zone(timezone_name)
    return value.astimezone(zone).utcoffset() == offset


__all__ = [name for name in globals() if not name.startswith("__")]
