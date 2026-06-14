# ruff: noqa: F403,F405,I001
"""Calendar MCP tools."""

from __future__ import annotations

from api.mcp_tools.shared import *  # noqa: F403


def _event_source(value: Any) -> str:
    return normalize_calendar_source(value)


def _replace_schedule_preparation(
    metadata: dict[str, Any],
    preparation: list[dict[str, Any]] | None,
) -> dict[str, Any]:
    next_metadata = dict(metadata or {})
    normalized: list[dict[str, Any]] = []
    for item in preparation or []:
        if not isinstance(item, dict):
            continue
        title = str(item.get("title") or "").strip()
        path = str(item.get("path") or "").strip()
        if not title and path:
            title = path.rsplit("/", 1)[-1]
        if not title and not path:
            continue
        normalized.append(
            {
                **({"title": title} if title else {}),
                **({"path": path} if path else {}),
            }
        )
    next_metadata["schedule_preparation"] = normalized
    return next_metadata


def _normalize_metadata(metadata: Any) -> dict[str, Any] | None:
    if metadata is None:
        return None
    if isinstance(metadata, str):
        text = metadata.strip()
        return {"markdown": text} if text else {}
    if not isinstance(metadata, dict):
        return {"markdown": str(metadata).strip()} if str(metadata).strip() else {}

    if "markdown" in metadata and len(metadata) == 1:
        markdown = str(metadata.get("markdown") or "").strip()
        return {"markdown": markdown} if markdown else {}

    lines: list[str] = []
    for key, value in metadata.items():
        label = str(key).strip()
        if not label:
            continue
        if isinstance(value, list):
            lines.append(f"- **{label}**:")
            for item in value:
                lines.append(f"  - {item}")
        elif isinstance(value, dict):
            lines.append(f"- **{label}**:")
            for child_key, child_value in value.items():
                lines.append(f"  - **{child_key}**: {child_value}")
        else:
            lines.append(f"- **{label}**: {value}")
    return {"markdown": "\n".join(lines)} if lines else {}


def _replace_metadata_markdown(
    metadata: dict[str, Any],
    normalized_metadata: dict[str, Any],
) -> dict[str, Any]:
    next_metadata = dict(metadata or {})
    if "markdown" in normalized_metadata:
        next_metadata["markdown"] = normalized_metadata["markdown"]
    for key, value in normalized_metadata.items():
        if key != "markdown":
            next_metadata[key] = value
    return next_metadata


def _parse_vevent(icalendar: str) -> dict[str, Any]:
    lines = _unfold_icalendar_lines(icalendar)
    properties: dict[str, list[tuple[dict[str, str], str]]] = {}
    in_vevent = False
    supported_properties = {
        "SUMMARY",
        "DTSTART",
        "DTEND",
        "DESCRIPTION",
        "LOCATION",
        "URL",
        "CATEGORIES",
        "RRULE",
    }
    active_multiline_property: str | None = None
    for raw_line in lines:
        raw_line = _normalize_legacy_ical_property(raw_line, supported_properties)
        line_name = _icalendar_line_name(raw_line)
        if line_name == "BEGIN" and raw_line.split(":", 1)[-1].strip().upper() == "VEVENT":
            in_vevent = True
            active_multiline_property = None
            continue
        if line_name == "END" and raw_line.split(":", 1)[-1].strip().upper() == "VEVENT":
            break
        if not in_vevent:
            continue
        if line_name not in supported_properties:
            if (
                active_multiline_property == "DESCRIPTION"
                and properties.get("DESCRIPTION")
                and not _looks_like_icalendar_property(raw_line)
            ):
                params, value = properties["DESCRIPTION"][-1]
                properties["DESCRIPTION"][-1] = (params, f"{value}\n{raw_line}")
            continue
        key, params, value = _parse_icalendar_line(raw_line)
        properties.setdefault(key, []).append((params, value))
        active_multiline_property = key if key == "DESCRIPTION" else None

    summary = _clean_ical_text(_first_ical_value(properties, "SUMMARY"))
    if not summary:
        raise _icalendar_error("VEVENT must include SUMMARY")

    dtstart_params, dtstart_value = _required_ical_property(properties, "DTSTART")
    start_at, timezone = _parse_ical_datetime(dtstart_value, dtstart_params, property_name="DTSTART")
    dtend = properties.get("DTEND")
    if dtend:
        dtend_params, dtend_value = dtend[0]
        end_at, end_timezone = _parse_ical_datetime(dtend_value, dtend_params, property_name="DTEND")
        if timezone == constants.UTC_TIMEZONE_NAME and end_timezone != constants.UTC_TIMEZONE_NAME:
            timezone = end_timezone
        time_shape = constants.CALENDAR_TIME_SHAPE_SPAN
    else:
        end_at = start_at
        time_shape = constants.CALENDAR_TIME_SHAPE_POINT

    rrule = _first_ical_value(properties, "RRULE")
    recurrence = None
    if rrule:
        recurrence = _validated_rrule_payload(rrule)

    categories = _clean_ical_text(_first_ical_value(properties, "CATEGORIES"))
    category = constants.DEFAULT_CALENDAR_CATEGORY
    if categories:
        first_category = categories.split(",", 1)[0].strip().lower()
        if first_category in constants.CALENDAR_VALID_CATEGORIES:
            category = first_category

    return {
        "title": summary,
        "subtitle": _clean_ical_text(_first_ical_value(properties, "DESCRIPTION")),
        "category": category,
        "time_shape": time_shape,
        "start_at": start_at,
        "end_at": end_at,
        "timezone": timezone,
        "location": _clean_ical_text(_first_ical_value(properties, "LOCATION")),
        "meeting_url": _clean_ical_text(_first_ical_value(properties, "URL")),
        "recurrence": recurrence,
        "present_properties": set(properties.keys()),
    }


def _unfold_icalendar_lines(icalendar: str) -> list[str]:
    unfolded: list[str] = []
    for raw_line in str(icalendar or "").replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if raw_line[:1] in {" ", "\t"} and unfolded:
            unfolded[-1] += raw_line[1:]
            continue
        unfolded.append(raw_line.strip())
    return unfolded


def _parse_icalendar_line(line: str) -> tuple[str, dict[str, str], str]:
    name_and_params, separator, value = line.partition(":")
    if not separator:
        raise _icalendar_error("VEVENT lines must use NAME[:PARAMS]:value syntax")
    segments = name_and_params.split(";")
    key = segments[0].strip().upper()
    params: dict[str, str] = {}
    for segment in segments[1:]:
        param_key, _, param_value = segment.partition("=")
        if param_key and param_value:
            params[param_key.strip().upper()] = param_value.strip().strip('"')
    return key, params, value.strip()


def _normalize_legacy_ical_property(line: str, supported_properties: set[str]) -> str:
    if ":" in line:
        return line
    match = re.match(r"^([A-Z0-9-]+)=(.*)$", line.strip(), flags=re.IGNORECASE)
    if match is None:
        return line
    key = match.group(1).strip().upper()
    if key not in supported_properties or key in {"DTSTART", "DTEND"}:
        return line
    return f"{key}:{match.group(2).strip()}"


def _looks_like_icalendar_property(line: str) -> bool:
    return bool(re.match(r"^[A-Z0-9-]+(?:;[^:]*)?:", line.strip()))


def _icalendar_line_name(line: str) -> str:
    head = line.split(":", 1)[0].split(";", 1)[0]
    return head.strip().upper()


def _first_ical_value(properties: dict[str, list[tuple[dict[str, str], str]]], key: str) -> str | None:
    values = properties.get(key)
    if not values:
        return None
    return values[0][1]


def _required_ical_property(
    properties: dict[str, list[tuple[dict[str, str], str]]],
    key: str,
) -> tuple[dict[str, str], str]:
    values = properties.get(key)
    if not values:
        raise _icalendar_error(f"VEVENT must include {key}")
    return values[0]


def _parse_ical_datetime(
    value: str,
    params: dict[str, str],
    *,
    property_name: str,
) -> tuple[str, str]:
    normalized = value.strip()
    tzid = params.get("TZID")
    if normalized.endswith("Z"):
        parsed = datetime.strptime(normalized, "%Y%m%dT%H%M%SZ").replace(tzinfo=dt_timezone.utc)
        _assert_ical_weekday_matches(property_name, parsed, params)
        return parsed.isoformat(), constants.UTC_TIMEZONE_NAME
    if not tzid:
        raise _icalendar_error("DTSTART/DTEND must include TZID or use UTC Z time")
    try:
        zone = ZoneInfo(tzid)
    except ZoneInfoNotFoundError as exc:
        raise _icalendar_error(f"Unsupported TZID: {tzid}") from exc

    for pattern in ("%Y%m%dT%H%M%S", "%Y%m%dT%H%M", "%Y%m%d"):
        try:
            parsed = datetime.strptime(normalized, pattern)
        except ValueError:
            continue
        if pattern == "%Y%m%d":
            parsed = parsed.replace(hour=0, minute=0, second=0)
        localized = parsed.replace(tzinfo=zone)
        _assert_ical_weekday_matches(property_name, localized, params)
        return localized.isoformat(), tzid
    raise _icalendar_error("DTSTART/DTEND must use RFC5545 DATE-TIME like 20260512T090000")


def _assert_ical_weekday_matches(
    property_name: str,
    value: datetime,
    params: dict[str, str],
) -> None:
    expected = str(params.get(_ICAL_WEEKDAY_PARAM) or "").strip().upper()
    actual = _ICAL_WEEKDAY_CODES[value.weekday()]
    if not expected:
        raise _icalendar_weekday_error(
            f"{property_name} must include {_ICAL_WEEKDAY_PARAM}",
            property_name=property_name,
            expected_weekday=None,
            actual_date=value.date().isoformat(),
            actual_weekday=actual,
        )
    if expected not in _ICAL_WEEKDAY_CODES:
        raise _icalendar_weekday_error(
            f"{property_name} has unsupported {_ICAL_WEEKDAY_PARAM}: {expected}",
            property_name=property_name,
            expected_weekday=expected,
            actual_date=value.date().isoformat(),
            actual_weekday=actual,
        )
    if expected != actual:
        raise _icalendar_weekday_error(
            f"{property_name} {_ICAL_WEEKDAY_PARAM} does not match the event date",
            property_name=property_name,
            expected_weekday=expected,
            actual_date=value.date().isoformat(),
            actual_weekday=actual,
        )


def _clean_ical_text(value: str | None) -> str | None:
    if value is None:
        return None
    return (
        value.replace("\\n", "\n")
        .replace("\\N", "\n")
        .replace("\\,", ",")
        .replace("\\;", ";")
        .replace("\\\\", "\\")
        .strip()
        or None
    )


def _validated_rrule_payload(rrule: str | None) -> str | None:
    normalized = str(rrule or "").strip()
    if not normalized:
        return None
    try:
        _assert_supported_rrule_syntax(normalized)
        recurrence, _ = normalize_recurrence_payload(normalized)
        validate_supported_recurrence_shape(recurrence)
    except AppHTTPException as exc:
        raise AppHTTPException(
            status_code=422,
            detail=f"Invalid or unsupported RRULE: {exc.detail}",
            error_code="INVALID_RRULE",
            error_detail=SUPPORTED_RRULE_DETAIL,
        ) from exc
    return normalized


def _assert_supported_rrule_syntax(rrule: str) -> None:
    supported_keys = {"FREQ", "INTERVAL", "COUNT", "UNTIL", "BYDAY", "BYMONTHDAY", "BYMONTH"}
    seen_keys: set[str] = set()
    for part in rrule.split(";"):
        if not part.strip() or "=" not in part:
            raise AppHTTPException(status_code=422, detail="RRULE parts must use KEY=VALUE syntax")
        key, value = part.split("=", 1)
        normalized_key = key.strip().upper()
        if normalized_key not in supported_keys:
            raise AppHTTPException(status_code=422, detail=f"Unsupported RRULE property: {normalized_key}")
        if normalized_key in seen_keys:
            raise AppHTTPException(status_code=422, detail=f"Duplicate RRULE property: {normalized_key}")
        if not value.strip():
            raise AppHTTPException(status_code=422, detail=f"RRULE property {normalized_key} cannot be empty")
        seen_keys.add(normalized_key)
    if "FREQ" not in seen_keys:
        raise AppHTTPException(status_code=422, detail="RRULE must include FREQ")


def _icalendar_error(message: str) -> AppHTTPException:
    return AppHTTPException(
        status_code=422,
        detail=f"Invalid VEVENT: {message}",
        error_code="INVALID_ICALENDAR_EVENT",
        error_detail=SUPPORTED_RRULE_DETAIL,
    )


def _icalendar_weekday_error(
    message: str,
    *,
    property_name: str,
    expected_weekday: str | None,
    actual_date: str,
    actual_weekday: str,
) -> AppHTTPException:
    return AppHTTPException(
        status_code=422,
        detail=f"Invalid VEVENT: {message}",
        error_code="INVALID_ICALENDAR_WEEKDAY",
        error_detail={
            "property": property_name,
            "weekday_param": _ICAL_WEEKDAY_PARAM,
            "expected_weekday": expected_weekday,
            "actual_date": actual_date,
            "actual_weekday": actual_weekday,
            "supported_weekdays": list(_ICAL_WEEKDAY_CODES),
        },
    )


def _calendar_current_local_time(timezone_name: str) -> datetime:
    return datetime.now(parse_timezone(timezone_name))


def _past_calendar_time_warning(start_at: str, current_time: datetime) -> dict[str, Any]:
    return {
        "code": "CALENDAR_PAST_TIME_FORCED",
        "message": "Event uses a past start time because force=true",
        "start_at": start_at,
        "current_time": format_datetime(current_time),
    }


def _check_calendar_start_not_past(
    *,
    start_at: str,
    timezone_name: str,
    force: bool,
) -> dict[str, Any] | None:
    target_start = datetime.fromisoformat(start_at.replace("Z", "+00:00"))
    current_time = _calendar_current_local_time(timezone_name)
    if target_start >= current_time:
        return None
    if force:
        return _past_calendar_time_warning(start_at, current_time)
    raise AppHTTPException(
        status_code=422,
        detail="Calendar event start time is in the past",
        error_code="CALENDAR_PAST_TIME",
        error_detail={
            "start_at": start_at,
            "current_time": format_datetime(current_time),
            "force_available": True,
        },
    )


def _build_apple_client_action(
    *,
    operation: Literal["create", "update", "delete"],
    draft: dict[str, Any] | None = None,
    mutation_options: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "client_action_id": f"apple_action_{uuid.uuid4().hex}",
        "kind": "apple_calendar_mutation",
        "operation": operation,
        "draft": {
            key: value
            for key, value in (draft or {}).items()
            if value not in (None, "")
        },
        "mutation_options": {
            key: value
            for key, value in (mutation_options or {}).items()
            if value not in (None, "")
        },
    }


def _build_external_readonly_client_action(
    *,
    provider: str,
    operation: Literal["update", "delete"],
) -> dict[str, Any]:
    normalized_provider = _event_source(provider)
    return {
        "client_action_id": f"external_action_{uuid.uuid4().hex}",
        "kind": "external_calendar_readonly",
        "provider": normalized_provider,
        "operation": operation,
        "message": f"Please modify this event in {normalized_provider}.",
    }


def _calendar_result_payload(
    *,
    source: str,
    data: dict[str, Any],
    client_action: dict[str, Any] | None = None,
) -> dict[str, Any]:
    payload = dict(data)
    normalized_source = _event_source(source)
    payload["source"] = normalized_source
    payload["provider"] = provider_for_source(normalized_source)
    if client_action is not None:
        payload["client_action"] = client_action
        payload["execution_status"] = constants.MCP_EXECUTION_STATUS_PENDING_CLIENT
        payload["target_source"] = normalized_source
    return payload


def _assert_calendar_event_not_deleted(event: Any) -> None:
    if (
        bool(getattr(event, "is_active", True))
        and getattr(event, "status", None) != constants.CALENDAR_STATUS_CANCELLED
    ):
        return
    raise AppHTTPException(
        status_code=410,
        detail="Deleted calendar events cannot be updated",
        error_code="CALENDAR_EVENT_DELETED",
        error_detail={
            "event_id": getattr(event, "event_id", None),
            "status": getattr(event, "status", None),
        },
    )


def _apple_draft_from_event_payload(
    event: dict[str, Any],
    *,
    include_recurrence: bool = True,
) -> dict[str, Any]:
    draft = {
        "title": event.get("title"),
        "calendarIdentifier": ((event.get("apple_link") or {}).get("calendar_identifier")),
        "startAt": event.get("start_at"),
        "endAt": event.get("end_at"),
        "location": event.get("location"),
        "notes": event.get("subtitle"),
        "timezone": event.get("timezone"),
    }
    if include_recurrence and event.get("recurrence") is not None:
        draft["recurrence"] = event.get("recurrence")
    return {key: value for key, value in draft.items() if value is not None}


def _apple_mutation_options_from_event(event: dict[str, Any]) -> dict[str, Any]:
    apple_link = event.get("apple_link") or {}
    occurrence_date = event.get("occurrence_start_at") or event.get("start_at")
    options = {
        "eventIdentifier": apple_link.get("event_identifier"),
        "calendarItemIdentifier": apple_link.get("calendar_item_identifier"),
        "occurrenceDate": occurrence_date,
        constants.APPLE_CALENDAR_MUTATION_SPAN_KEY: constants.APPLE_CALENDAR_MUTATION_THIS_EVENT,
    }
    return {key: value for key, value in options.items() if value not in (None, "")}
@ling_mcp.tool(
    name="calendar_list_events",
    description="List calendar events for a specific user. Pass event_id to fetch one exact event. If query and event_id are empty, start_time and end_time are required and must include timezone offsets. If query is provided, BM25 ranking is applied; when time range is omitted, a default ±365-day window around now is used.",
)
async def calendar_list_events(
    user_id: Annotated[str, Field(description="The tenant-scoped user ID whose calendar will be queried.")],
    start_time: Annotated[str | SkipJsonSchema[None], BeforeValidator(_empty_string_to_none), Field(description="Optional ISO8601 inclusive range start with timezone offset. Required when query is empty.")] = None,
    end_time: Annotated[str | SkipJsonSchema[None], BeforeValidator(_empty_string_to_none), Field(description="Optional ISO8601 exclusive range end with timezone offset. Required when query is empty.")] = None,
    query: Annotated[str | SkipJsonSchema[None], BeforeValidator(_empty_string_to_none), Field(description="Optional natural-language keyword search, such as weekly sync or 客户会议.")] = None,
    event_id: Annotated[str | SkipJsonSchema[None], BeforeValidator(_empty_string_to_none), Field(description="Optional exact Ling calendar event ID. When provided, other filters are ignored.")] = None,
    limit: Annotated[int, Field(description="Maximum number of matched events to return when query is provided.")] = 20,
) -> dict[str, Any]:
    action = "calendar_list_events"
    try:
        service = CalendarService()
        if event_id:
            event = await service.get_event(user_id, event_id)
            return _success(
                action,
                {
                    "start_time": None,
                    "end_time": None,
                    "query": query,
                    "event_id": event_id,
                    "default_time_window_applied": False,
                    "events": [event],
                    "count": 1,
                },
            )
        start_dt = service.parse_datetime(start_time) if start_time else None
        end_dt = service.parse_datetime(end_time) if end_time else None
        has_query = bool(query and query.strip())
        default_time_window_applied = False

        if not has_query:
            if start_dt is None or end_dt is None:
                raise AppHTTPException(
                    status_code=422,
                    detail="start_time and end_time are required when query is empty",
                )
        else:
            if (start_dt is None) ^ (end_dt is None):
                raise AppHTTPException(
                    status_code=422,
                    detail="start_time and end_time must be provided together when filtering query results by time range",
                )
            if start_dt is None and end_dt is None:
                now = datetime.now(dt_timezone.utc)
                start_dt = now - timedelta(days=365)
                end_dt = now + timedelta(days=365)
                default_time_window_applied = True

        if start_dt is not None and end_dt is not None and start_dt >= end_dt:
            raise AppHTTPException(
                status_code=422,
                detail="start_time must be earlier than end_time",
            )

        warnings: list[dict[str, Any]] = []
        if query and query.strip():
            events = await service.search_events(
                user_id,
                query,
                start_dt=start_dt,
                end_dt=end_dt,
                limit=limit,
            )
        else:
            assert start_dt is not None and end_dt is not None
            events = await service.list_events_between(user_id, start_dt, end_dt)

        assert start_dt is not None and end_dt is not None
        imported = await service.list_imported_apple_events_between(
            user_id,
            start_dt,
            end_dt,
            timezone=_extract_timezone_name(start_dt),
        )
        if imported["coverage_start"] is not None and not imported["coverage_complete"]:
            warnings.append(
                {
                    "code": "APPLE_IMPORT_WINDOW_LIMITED",
                    "message": "Apple imported events only cover the uploaded device window.",
                    "coverage_start": imported["coverage_start"],
                    "coverage_end": imported["coverage_end"],
                }
            )

        return _success(
            action,
            {
                "start_time": None if start_dt is None else start_dt.isoformat(),
                "end_time": None if end_dt is None else end_dt.isoformat(),
                "query": query,
                "default_time_window_applied": default_time_window_applied,
                "events": events,
                "count": len(events),
            },
            warnings=warnings,
        )
    except Exception as exc:
        return _error(action, exc)


@ling_mcp.tool(
    name="calendar_create_event",
    description=(
        "Create a confirmed calendar event for a specific user from a compact RFC 5545 VEVENT string. "
        "Use this single tool for both span events and point reminders. VEVENT must include SUMMARY and DTSTART; "
        "include DTEND for span events and omit DTEND for point reminders. "
        "add RRULE only when the user explicitly asks for repetition. Conflicts and past start times are rejected unless force=true. "
        "Supported RRULE subset: FREQ=DAILY|WEEKLY|MONTHLY|YEARLY with optional INTERVAL, COUNT, UNTIL, BYDAY, BYMONTHDAY, BYMONTH. "
        f"DTSTART/DTEND must use TZID plus X-LING-WEEKDAY, e.g. DTSTART;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=TU:20260512T090000, or UTC Z time with X-LING-WEEKDAY."
    ),
)
async def calendar_create_event(
    user_id: Annotated[str, Field(description="The tenant-scoped user ID who owns the calendar event.")],
    vevent: Annotated[
        str,
        Field(
            description=(
                "RFC 5545 VEVENT text. Required properties: SUMMARY, DTSTART. "
                "Use DTEND for span events; omit DTEND for point reminders. "
                "Optional properties: DESCRIPTION, LOCATION, URL, CATEGORIES, RRULE. "
                "Use CATEGORIES for structured category: personal, work, meeting, travel, health, family, or other. "
                "DTSTART and DTEND must include X-LING-WEEKDAY=MO|TU|WE|TH|FR|SA|SU matching the calendar date. "
                f"Example one-off: BEGIN:VEVENT\\nSUMMARY:Morning sync\\nDTSTART;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=TU:20260512T090000\\nDTEND;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=TU:20260512T093000\\nEND:VEVENT. "
                f"Example point reminder: BEGIN:VEVENT\\nSUMMARY:Call parents\\nDTSTART;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=TU:20260512T200000\\nEND:VEVENT. "
                f"Example recurring: BEGIN:VEVENT\\nSUMMARY:Weekly standup\\nDTSTART;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=TU:20260512T090000\\nDTEND;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=TU:20260512T093000\\nRRULE:FREQ=WEEKLY;BYDAY=TU;COUNT=8\\nEND:VEVENT."
            ),
        ),
    ],
    check_conflicts: Annotated[bool, Field(description="Whether to detect overlaps with existing events before creating.")] = True,
    force: Annotated[bool, Field(description="Create even if conflicts or a confirmed past start time exist. Forced conditions will be returned as warnings.")] = False,
) -> dict[str, Any]:
    action = "calendar_create_event"
    try:
        service = CalendarService()
        event_payload = _parse_vevent(vevent)
        start_dt = service.parse_datetime(event_payload["start_at"])
        end_dt = service.parse_datetime(event_payload["end_at"])
        resolved_timezone = event_payload["timezone"]
        time_shape = event_payload["time_shape"]
        if time_shape == constants.CALENDAR_TIME_SHAPE_SPAN and start_dt >= end_dt:
            raise AppHTTPException(status_code=422, detail="DTSTART must be earlier than DTEND")
        warnings = []
        past_time_warning = _check_calendar_start_not_past(
            start_at=event_payload["start_at"],
            timezone_name=resolved_timezone,
            force=force,
        )
        if past_time_warning:
            warnings.append(past_time_warning)

        conflicts = []
        if check_conflicts and time_shape == constants.CALENDAR_TIME_SHAPE_SPAN:
            conflicts = await service.find_conflicts(user_id, start_dt, end_dt, resolved_timezone)
        if conflicts and not force:
            raise AppHTTPException(
                status_code=409,
                detail="Calendar conflicts detected",
                error_code="CALENDAR_CONFLICT",
                error_detail={
                    "conflict_count": len(conflicts),
                    "conflicts": conflicts,
                    "force_available": True,
                },
            )

        base_payload = {
            "title": event_payload["title"],
            "subtitle": event_payload["subtitle"],
            "category": event_payload["category"],
            "time_shape": time_shape,
            "start_at": event_payload["start_at"],
            "end_at": event_payload["end_at"],
            "timezone": resolved_timezone,
            "location": event_payload["location"],
            "meeting_url": event_payload["meeting_url"],
            "attendees": [],
            "status": constants.CALENDAR_STATUS_SCHEDULED,
            "focus_mode_enabled": False,
            "metadata": {},
            "recurrence": event_payload["recurrence"],
            "source": constants.CALENDAR_SOURCE_LING,
        }
        event = await service.create_event(user_id, base_payload)
        if conflicts:
            warnings.append(
                {
                    "code": "CALENDAR_CONFLICT_FORCED",
                    "message": "Event created with overlapping calendar events because force=true",
                    "conflicts": conflicts,
                }
            )
        return _success(
            action,
            event,
            warnings=warnings,
            next_actions=calendar_next_actions(
                action,
                event if isinstance(event, dict) else {},
            ),
        )
    except Exception as exc:
        return _error(action, exc)


@ling_mcp.tool(
    name="calendar_update_event",
    description=(
        "Update an existing calendar event. Search with calendar_list_events first and pass the exact event_id. "
        "Use vevent only when changing ordinary visible event fields; use metadata for Markdown notes; "
        "use preparation for a list of prepared material file paths. At least one of vevent, metadata, or preparation is required. "
        "When vevent is provided, it must include SUMMARY and DTSTART; include DTEND for span events and omit DTEND for point reminders. "
        "DTSTART and DTEND must include X-LING-WEEKDAY matching the calendar date. "
        "For recurring events, scope=series updates the whole series; scope=occurrence updates one occurrence and requires occurrence_start_time. "
        "Include RRULE only when changing the whole series recurrence rule; omit RRULE to keep the existing recurrence unchanged. "
        "Past start times are rejected unless force=true."
    ),
)
async def calendar_update_event(
    user_id: Annotated[str, Field(description="The tenant-scoped user ID who owns the event.")],
    event_id: Annotated[str, Field(description="The calendar event ID to update.")],
    vevent: Annotated[
        str | SkipJsonSchema[None],
        BeforeValidator(_empty_string_to_none),
        Field(
            description=(
                "Optional RFC 5545 VEVENT text containing updated ordinary event fields. Required only when changing title, time, location, meeting URL, category, or recurrence. Required VEVENT properties when provided: SUMMARY, DTSTART. "
                "Use DTEND for span events; omit DTEND for point reminders. "
                "Optional properties: DESCRIPTION, LOCATION, URL, CATEGORIES, RRULE. "
                "Use CATEGORIES for structured category: personal, work, meeting, travel, health, family, or other. "
                "Include RRULE only with scope=series when changing recurrence; omit RRULE to keep recurrence unchanged. "
                "DTSTART and DTEND must include X-LING-WEEKDAY=MO|TU|WE|TH|FR|SA|SU matching the calendar date. "
                f"Example: BEGIN:VEVENT\\nSUMMARY:Updated sync\\nDTSTART;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=TU:20260512T100000\\nDTEND;TZID={constants.DEFAULT_TIMEZONE};X-LING-WEEKDAY=TU:20260512T103000\\nLOCATION:Office\\nEND:VEVENT."
            ),
        ),
    ] = None,
    metadata: Annotated[
        Any,
        Field(
            description=(
                "Optional Markdown note text to replace metadata.markdown. "
                f"{METADATA_MARKDOWN_REQUIREMENTS} "
                "Non-string values are accepted and converted to Markdown text instead of failing."
            ),
        ),
    ] = None,
    preparation: Annotated[
        list[dict[str, Any]] | SkipJsonSchema[None],
        BeforeValidator(_empty_string_to_none),
        Field(
            description=(
                "Optional prepared materials list. Use only after Ling has prepared files for this event. "
                "Each item must include title and path; pass an empty list to clear stale prepared materials. Example: "
                '[{"title":"会议准备文档","path":"/absolute/or/agent/file/path.md"}].'
            ),
        ),
    ] = None,
    scope: Annotated[
        Literal["series", "occurrence"],
        Field(description="Mutation scope for recurring events: series or occurrence."),
    ] = "series",
    occurrence_start_time: Annotated[
        str | SkipJsonSchema[None],
        BeforeValidator(_empty_string_to_none),
        Field(description="Original ISO8601 occurrence start including timezone offset. Required when scope=occurrence."),
    ] = None,
    check_conflicts: Annotated[bool, Field(description="Whether to detect overlaps with other events before updating.")] = True,
    force: Annotated[bool, Field(description="Apply the update even if conflicts or a confirmed past start time exist. Forced conditions will be returned as warnings.")] = False,
) -> dict[str, Any]:
    action = "calendar_update_event"
    started_at = perf_counter()
    stage = "start"

    def elapsed_ms() -> int:
        return int((perf_counter() - started_at) * 1000)

    try:
        has_vevent = bool(str(vevent or "").strip())
        has_metadata = metadata is not None
        has_preparation = preparation is not None
        preparation_count = len(preparation) if isinstance(preparation, list) else None
        logger.info(
            "[Ling][MCP][calendar_update_event] start user_ref={} event_id={} "
            "has_vevent={} has_metadata={} has_preparation={} preparation_count={} "
            "scope={} check_conflicts={} force={}",
            _mcp_log_ref(user_id),
            event_id,
            has_vevent,
            has_metadata,
            has_preparation,
            preparation_count,
            scope,
            check_conflicts,
            force,
        )
        service = CalendarService()
        stage = "get_user_event"
        event = await service.event_dao.get_user_event(user_id, event_id)
        logger.info(
            "[Ling][MCP][calendar_update_event] stage=get_user_event done user_ref={} "
            "event_id={} found={} elapsed_ms={}",
            _mcp_log_ref(user_id),
            event_id,
            event is not None,
            elapsed_ms(),
        )
        if event is None:
            raise AppHTTPException(status_code=404, detail="Event not found")
        _assert_calendar_event_not_deleted(event)
        stage = "serialize_event_before_update"
        serialized_event = await service.serialize_event(event)
        logger.info(
            "[Ling][MCP][calendar_update_event] stage=serialize_event_before_update done "
            "user_ref={} event_id={} source={} elapsed_ms={}",
            _mcp_log_ref(user_id),
            event_id,
            serialized_event.get("source"),
            elapsed_ms(),
        )
        target_source = _event_source(serialized_event.get("source"))

        if not (has_vevent or has_metadata or has_preparation):
            raise AppHTTPException(
                status_code=422,
                detail="At least one of vevent, metadata, or preparation is required",
            )

        update_payload: dict[str, Any] = {}
        conflicts = []
        warnings = []
        if has_vevent:
            event_payload = _parse_vevent(str(vevent))
            present_properties = event_payload.get("present_properties") or set()
            update_payload.update(
                {
                    "title": event_payload["title"],
                    "time_shape": event_payload["time_shape"],
                    "start_at": event_payload["start_at"],
                    "end_at": event_payload["end_at"],
                    "timezone": event_payload["timezone"],
                }
            )
            if "DESCRIPTION" in present_properties:
                update_payload["subtitle"] = event_payload["subtitle"]
            if "CATEGORIES" in present_properties:
                update_payload["category"] = event_payload["category"]
            if "LOCATION" in present_properties:
                update_payload["location"] = event_payload["location"]
            if "URL" in present_properties:
                update_payload["meeting_url"] = event_payload["meeting_url"]
            if scope == "occurrence" and occurrence_start_time is None:
                raise AppHTTPException(
                    status_code=422,
                    detail="occurrence_start_time is required when scope=occurrence",
                )
            if scope == "occurrence" and event_payload.get("recurrence") is not None:
                raise AppHTTPException(
                    status_code=422,
                    detail="RRULE cannot be changed for a single occurrence",
                    error_code="RECURRENCE_UPDATE_REQUIRES_SERIES_SCOPE",
                    error_detail=SUPPORTED_RRULE_DETAIL,
                )
            if scope == "series" and event_payload.get("recurrence") is not None:
                update_payload["recurrence"] = event_payload["recurrence"]

            target_start = service.parse_datetime(update_payload["start_at"])
            target_end = service.parse_datetime(update_payload["end_at"])
            target_timezone = update_payload["timezone"]
            target_time_shape = update_payload["time_shape"]
            if target_time_shape == constants.CALENDAR_TIME_SHAPE_SPAN and target_start >= target_end:
                raise AppHTTPException(status_code=422, detail="DTSTART must be earlier than DTEND")
            past_time_warning = _check_calendar_start_not_past(
                start_at=update_payload["start_at"],
                timezone_name=target_timezone,
                force=force,
            )
            if past_time_warning:
                warnings.append(past_time_warning)
            if check_conflicts and target_time_shape == constants.CALENDAR_TIME_SHAPE_SPAN:
                stage = "find_conflicts"
                conflicts = await service.find_conflicts(
                    user_id,
                    target_start,
                    target_end,
                    target_timezone,
                    exclude_event_id=event_id,
                    exclude_occurrence_start_time=occurrence_start_time,
                )
                logger.info(
                    "[Ling][MCP][calendar_update_event] stage=find_conflicts done user_ref={} "
                    "event_id={} conflict_count={} elapsed_ms={}",
                    _mcp_log_ref(user_id),
                    event_id,
                    len(conflicts),
                    elapsed_ms(),
                )
            if conflicts and not force:
                raise AppHTTPException(
                    status_code=409,
                    detail="Calendar conflicts detected",
                    error_code="CALENDAR_CONFLICT",
                    error_detail={
                        "conflict_count": len(conflicts),
                        "conflicts": conflicts,
                        "force_available": True,
                    },
                )

        next_metadata = (
            dict(serialized_event.get("metadata") or {})
            if isinstance(serialized_event.get("metadata"), dict)
            else {}
        )
        if has_metadata:
            normalized_metadata = _normalize_metadata(metadata) or {}
            if not normalized_metadata:
                raise AppHTTPException(status_code=422, detail="metadata must not be empty")
            next_metadata = _replace_metadata_markdown(next_metadata, normalized_metadata)
        if has_preparation:
            stage = "normalize_preparation"
            next_metadata = _replace_schedule_preparation(next_metadata, preparation)
            logger.info(
                "[Ling][MCP][calendar_update_event] stage=normalize_preparation done user_ref={} "
                "event_id={} preparation_count={} metadata_keys={} elapsed_ms={}",
                _mcp_log_ref(user_id),
                event_id,
                len(next_metadata.get("schedule_preparation") or []),
                sorted(next_metadata.keys()),
                elapsed_ms(),
            )
        if has_metadata or has_preparation:
            update_payload["metadata"] = next_metadata
            if target_source != constants.CALENDAR_SOURCE_LING:
                raise AppHTTPException(
                    status_code=422,
                    detail="Only Ling events support metadata or preparation updates through this tool",
                )

        if scope == "occurrence" and occurrence_start_time is not None:
            update_payload["scope"] = scope
            update_payload["occurrence_start_time"] = occurrence_start_time
        elif has_vevent:
            update_payload["scope"] = scope

        if target_source != constants.CALENDAR_SOURCE_LING:
            merged_event = {
                **serialized_event,
                **{
                    "title": update_payload.get("title", serialized_event.get("title")),
                    "subtitle": update_payload.get("subtitle", serialized_event.get("subtitle")),
                    "category": update_payload.get("category", serialized_event.get("category")),
                    "start_at": update_payload.get("start_at", serialized_event.get("start_at")),
                    "end_at": update_payload.get("end_at", serialized_event.get("end_at")),
                    "timezone": update_payload.get("timezone", serialized_event.get("timezone")),
                    "location": update_payload.get("location", serialized_event.get("location")),
                    "meeting_url": update_payload.get("meeting_url", serialized_event.get("meeting_url")),
                    "recurrence": update_payload.get("recurrence", serialized_event.get("recurrence")),
                    "attendees": update_payload.get("attendees", serialized_event.get("attendees")),
                    "status": update_payload.get("status", serialized_event.get("status")),
                    "focus_mode_enabled": update_payload.get(
                        "focus_mode_enabled",
                        serialized_event.get("focus_mode_enabled"),
                    ),
                    "metadata": update_payload.get("metadata", serialized_event.get("metadata")),
                },
            }
            client_action = (
                _build_apple_client_action(
                    operation="update",
                    draft=_apple_draft_from_event_payload(
                        merged_event,
                        include_recurrence="recurrence" in update_payload,
                    ),
                    mutation_options=_apple_mutation_options_from_event(serialized_event),
                )
                if target_source == constants.CALENDAR_SOURCE_APPLE
                else _build_external_readonly_client_action(
                    provider=target_source,
                    operation="update",
                )
            )
            updated = _calendar_result_payload(
                source=target_source,
                data=merged_event,
                client_action=client_action,
            )
        else:
            stage = "service_update_event"
            logger.info(
                "[Ling][MCP][calendar_update_event] stage=service_update_event start user_ref={} "
                "event_id={} payload_keys={} elapsed_ms={}",
                _mcp_log_ref(user_id),
                event_id,
                sorted(update_payload.keys()),
                elapsed_ms(),
            )
            updated = await service.update_event(user_id, event_id, update_payload)
            logger.info(
                "[Ling][MCP][calendar_update_event] stage=service_update_event done user_ref={} "
                "event_id={} updated_event_id={} elapsed_ms={}",
                _mcp_log_ref(user_id),
                event_id,
                updated.get("event_id") if isinstance(updated, dict) else None,
                elapsed_ms(),
            )
        if conflicts:
            warnings.append(
                {
                    "code": "CALENDAR_CONFLICT_FORCED",
                    "message": "Event updated with overlapping calendar events because force=true",
                    "conflicts": conflicts,
                }
            )
        stage = "build_response"
        result = _success(
            action,
            updated,
            warnings=warnings,
            next_actions=calendar_next_actions(
                action,
                updated if isinstance(updated, dict) else {},
            ),
        )
        logger.info(
            "[Ling][MCP][calendar_update_event] done user_ref={} event_id={} "
            "ok={} elapsed_ms={}",
            _mcp_log_ref(user_id),
            event_id,
            result.get("ok"),
            elapsed_ms(),
        )
        return result
    except Exception as exc:
        logger.exception(
            "[Ling][MCP][calendar_update_event] failed user_ref={} event_id={} stage={} elapsed_ms={}",
            _mcp_log_ref(user_id),
            event_id,
            stage,
            elapsed_ms(),
        )
        return _error(action, exc)


@ling_mcp.tool(
    name="calendar_complete_event",
    description=(
        "Mark an existing Ling calendar event as completed and preserve it in history. "
        "Use this when the user says an event is done, already happened, or provides the result/outcome."
    ),
)
async def calendar_complete_event(
    user_id: Annotated[str, Field(description="The tenant-scoped user ID who owns the event.")],
    event_id: Annotated[str, Field(description="The Ling calendar event ID to complete.")],
    scope: Annotated[
        Literal["series", "occurrence"],
        Field(description="Completion scope for recurring events: series or occurrence."),
    ] = "series",
    occurrence_start_time: Annotated[
        str | SkipJsonSchema[None],
        BeforeValidator(_empty_string_to_none),
        Field(description="Original ISO8601 occurrence start including timezone offset. Required when scope=occurrence."),
    ] = None,
    completed_at: Annotated[
        str | SkipJsonSchema[None],
        BeforeValidator(_empty_string_to_none),
        Field(description="Optional ISO8601 completion time with timezone offset. Defaults to now."),
    ] = None,
    outcome: Annotated[
        Literal["done", "partially_done", "missed", "unknown"],
        Field(description="Completion outcome."),
    ] = "done",
    result_summary: Annotated[
        str | SkipJsonSchema[None],
        BeforeValidator(_empty_string_to_none),
        Field(description="Optional short summary of what happened or the result."),
    ] = None,
    metadata: Annotated[
        Any,
        Field(
            description=(
                "Optional Markdown note text to replace the event metadata note. "
                f"{METADATA_MARKDOWN_REQUIREMENTS} "
                "Non-string values are accepted and converted to Markdown text."
            ),
        ),
    ] = None,
) -> dict[str, Any]:
    action = "calendar_complete_event"
    try:
        service = CalendarService()
        if completed_at is not None:
            service.parse_datetime(completed_at)
        completed = await service.complete_event(
            user_id,
            event_id,
            scope=scope,
            occurrence_start_time=occurrence_start_time,
            completed_at=completed_at,
            outcome=outcome,
            result_summary=result_summary,
            metadata=_normalize_metadata(metadata) or {},
        )
        return _success(
            action,
            completed,
            next_actions=calendar_next_actions(
                action,
                completed if isinstance(completed, dict) else {},
            ),
        )
    except Exception as exc:
        return _error(action, exc)


@ling_mcp.tool(
    name="calendar_delete_event",
    description=(
        "Delete, cancel, or discard an existing calendar event for a specific user. "
        "For Ling events this is a soft delete: status becomes cancelled and the event is hidden from default lists."
    ),
)
async def calendar_delete_event(
    user_id: Annotated[str, Field(description="The tenant-scoped user ID who owns the event.")],
    event_id: Annotated[str, Field(description="The calendar event ID to delete.")],
    scope: Annotated[
        Literal["series", "occurrence"],
        Field(description="Deletion scope for recurring events: series or occurrence."),
    ] = "series",
    occurrence_start_time: Annotated[
        str | SkipJsonSchema[None],
        BeforeValidator(_empty_string_to_none),
        Field(description="Original ISO8601 occurrence start including timezone offset. Required when scope=occurrence."),
    ] = None,
    delete_reason: Annotated[
        str | SkipJsonSchema[None],
        BeforeValidator(_empty_string_to_none),
        Field(description="Optional reason for deleting/cancelling this event."),
    ] = None,
    metadata: Annotated[
        Any,
        Field(
            description=(
                "Optional Markdown note text to replace the event metadata note before soft deletion. "
                f"{METADATA_MARKDOWN_REQUIREMENTS} "
                "Non-string values are accepted and converted to Markdown text."
            ),
        ),
    ] = None,
) -> dict[str, Any]:
    action = "calendar_delete_event"
    try:
        service = CalendarService()
        event = await service.event_dao.get_user_event(user_id, event_id)
        if event is None:
            raise AppHTTPException(status_code=404, detail="Event not found")
        serialized_event = await service.serialize_event(event)
        target_source = _event_source(serialized_event.get("source"))
        if target_source != constants.CALENDAR_SOURCE_LING:
            client_action = (
                _build_apple_client_action(
                    operation="delete",
                    mutation_options=_apple_mutation_options_from_event(serialized_event),
                )
                if target_source == constants.CALENDAR_SOURCE_APPLE
                else _build_external_readonly_client_action(
                    provider=target_source,
                    operation="delete",
                )
            )
            result = _calendar_result_payload(
                source=target_source,
                data={
                    **serialized_event,
                    "deleted": True,
                    "scope": scope,
                    "occurrence_start_at": occurrence_start_time
                    or serialized_event.get("occurrence_start_at"),
                },
                client_action=client_action,
            )
        else:
            result = await service.delete_event(
                user_id,
                event_id,
                scope=scope,
                occurrence_start_time=occurrence_start_time,
                delete_reason=delete_reason,
                metadata=_normalize_metadata(metadata) or {},
            )
            apple_link = result.get("apple_link")
            if apple_link:
                result = _calendar_result_payload(
                    source=constants.CALENDAR_SOURCE_LING,
                    data=result,
                    client_action=_build_apple_client_action(
                        operation="delete",
                        mutation_options={
                            "eventIdentifier": apple_link.get("event_identifier"),
                            "calendarItemIdentifier": apple_link.get("calendar_item_identifier"),
                            "occurrenceDate": occurrence_start_time,
                            constants.APPLE_CALENDAR_MUTATION_SPAN_KEY: (
                                constants.APPLE_CALENDAR_MUTATION_THIS_EVENT
                                if scope == constants.CALENDAR_UPDATE_SCOPE_OCCURRENCE
                                else constants.APPLE_CALENDAR_MUTATION_FUTURE_EVENTS
                            ),
                        },
                    ),
                )
        return _success(
            action,
            result,
            next_actions=calendar_next_actions(
                action,
                result if isinstance(result, dict) else {},
            ),
        )
    except Exception as exc:
        return _error(action, exc)


__all__ = [name for name in globals() if not name.startswith("__")]
