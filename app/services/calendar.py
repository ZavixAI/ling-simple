"""Ling 日历核心服务：事件 CRUD、重复展开、Apple 映射与 Agent 上下文组装。"""

from __future__ import annotations

import asyncio
import calendar as calendar_lib
import hashlib
import math
import re
import uuid
from collections import Counter
from datetime import UTC, date, datetime, timedelta
from datetime import tzinfo as dt_tzinfo
from time import perf_counter
from typing import Any, Optional

from config import constants
from core.http.exceptions import AppHTTPException
from core.infra.db import transaction_scope
from loguru import logger
from models.base import get_local_now
from models.calendar import (
    AppleCalendarContext,
    AppleCalendarContextDao,
    CalendarEvent,
    CalendarEventDao,
    CalendarEventLink,
    CalendarEventLinkDao,
)
from services.calendar_domain.recurrence import (
    effective_recurrence,
    serialize_imported_apple_recurrence,
    serialize_recurrence,
)
from services.calendar_domain.serialization import (
    build_serialized_event_payload,
    public_metadata,
    sort_serialized_events,
)
from services.calendar_domain.source import event_source, provider_for_source
from services.calendar_domain.time_shape import (
    event_time_shape,
    event_window_overlaps,
    normalize_time_shape,
    validate_time_shape_window,
)
from services.calendar_recurrence import (
    expand_recurrence_window,
    normalize_recurrence_payload,
    parse_raw_rrule,
    recurrence_has_supported_shape,
    validate_supported_recurrence_shape,
)
from services.surface_events import publish_surface_changed
from sqlalchemy.ext.asyncio import AsyncSession
from utils.time import (
    ensure_utc,
    format_datetime,
    normalize_persisted_timezone,
    parse_timezone,
    to_storage_utc,
    to_timezone,
)


def _calendar_log_ref(value: Any) -> str:
    return hashlib.sha256(str(value).encode("utf-8")).hexdigest()[:10]


class CalendarService:
    """日历领域入口：按日/周/月查询、搜索、序列化单条事件及解析时间字符串。"""

    _apple_context_sync_locks: dict[str, asyncio.Lock] = {}

    def __init__(self) -> None:
        self.event_dao = CalendarEventDao()
        self.link_dao = CalendarEventLinkDao()
        self.context_dao = AppleCalendarContextDao()

    async def list_events_for_date(
        self,
        user_id: str,
        target_date: date,
        timezone: str,
    ) -> list[dict[str, Any]]:
        zone = self._get_zone(timezone)
        start_dt = datetime.combine(target_date, datetime.min.time(), tzinfo=zone)
        end_dt = start_dt + timedelta(days=1)
        return await self.list_events_between(user_id, start_dt, end_dt, timezone)

    async def list_events_between(
        self,
        user_id: str,
        start_dt: datetime,
        end_dt: datetime,
        timezone: str | None = None,
    ) -> list[dict[str, Any]]:
        _ = self._resolve_compare_zone(start_dt, timezone)
        events = await self._list_occurrence_views(user_id, start_dt, end_dt)
        return self._sort_serialized_events(events)

    async def list_imported_apple_events_between(
        self,
        user_id: str,
        start_dt: datetime,
        end_dt: datetime,
        *,
        timezone: str,
    ) -> dict[str, Any]:
        events = await self._list_occurrence_views(user_id, start_dt, end_dt)
        apple_events = [
            event
            for event in events
            if str(event.get("source") or "").strip().lower() == constants.CALENDAR_SOURCE_APPLE
        ]
        coverage = await self._apple_sync_coverage(user_id)
        coverage_start = coverage["coverage_start"]
        coverage_end = coverage["coverage_end"]
        coverage_complete = bool(
            coverage_start is not None
            and coverage_end is not None
            and coverage_start <= ensure_utc(start_dt)
            and coverage_end >= ensure_utc(end_dt)
        )
        return {
            "events": self._sort_serialized_events(apple_events),
            "coverage_start": None if coverage_start is None else coverage_start.isoformat(),
            "coverage_end": None if coverage_end is None else coverage_end.isoformat(),
            "coverage_complete": coverage_complete,
            "permission_state": coverage["permission_state"],
        }

    async def find_imported_apple_event_by_id(
        self,
        user_id: str,
        event_id: str,
        *,
        timezone: str = constants.UTC_TIMEZONE_NAME,
    ) -> dict[str, Any] | None:
        imported = await self.list_imported_apple_events_between(
            user_id,
            datetime.now(UTC) - timedelta(days=365),
            datetime.now(UTC) + timedelta(days=365),
            timezone=timezone,
        )
        for item in imported["events"]:
            if item["event_id"] == event_id:
                return item
        return None

    async def search_events(
        self,
        user_id: str,
        query: str,
        *,
        start_dt: datetime | None = None,
        end_dt: datetime | None = None,
        limit: int = 20,
    ) -> list[dict[str, Any]]:
        query_text = (query or "").strip()
        if not query_text:
            return []
        query_tokens = self._tokenize_search_text(query_text)
        if not query_tokens:
            return []

        compare_anchor = start_dt or end_dt or datetime.now(UTC)
        timezone = self._extract_timezone_name(compare_anchor)
        events = await self._list_occurrence_views(
            user_id,
            start_dt or (datetime.now(UTC) - timedelta(days=365)),
            end_dt or (datetime.now(UTC) + timedelta(days=365)),
        )
        if not events:
            return []

        scored = self._rank_serialized_events_by_bm25(events, query_text, query_tokens)
        scored.sort(
            key=lambda item: (
                -item[1],
                self.parse_datetime(item[0]["start_at"]),
            )
        )
        _ = timezone
        return [event for event, _score in scored[: max(1, limit)]]

    async def find_conflicts(
        self,
        user_id: str,
        start_dt: datetime,
        end_dt: datetime,
        timezone: str | None = None,
        *,
        exclude_event_id: str | None = None,
        exclude_occurrence_start_time: str | None = None,
    ) -> list[dict[str, Any]]:
        zone = self._resolve_compare_zone(start_dt, timezone)
        normalized_start = self._to_local(start_dt, zone)
        normalized_end = self._to_local(end_dt, zone)
        events = await self._list_occurrence_views(
            user_id,
            start_dt - timedelta(days=1),
            end_dt + timedelta(days=1),
        )

        conflicts: list[dict[str, Any]] = []
        for event in events:
            if event.get("time_shape") == constants.CALENDAR_TIME_SHAPE_POINT:
                continue
            if self._is_non_blocking_background_event(event):
                continue
            if exclude_event_id and event["event_id"] == exclude_event_id:
                if exclude_occurrence_start_time is None:
                    if not event.get("occurrence_start_at"):
                        continue
                elif event.get("occurrence_start_at") == exclude_occurrence_start_time:
                    continue
            local_start = self._to_local(self.parse_datetime(event["start_at"]), zone)
            local_end = self._to_local(self.parse_datetime(event["end_at"]), zone)
            if local_end <= normalized_start or local_start >= normalized_end:
                continue
            conflicts.append(
                {
                    **event,
                    "overlap_start": format_datetime(max(local_start, normalized_start)),
                    "overlap_end": format_datetime(min(local_end, normalized_end)),
                }
            )
        return conflicts

    def _is_non_blocking_background_event(self, event: dict[str, Any]) -> bool:
        metadata = event.get("metadata") if isinstance(event.get("metadata"), dict) else {}
        kind = str(metadata.get("kind") or event.get("kind") or "").strip().lower()
        return kind == "holiday"

    async def build_month_view(
        self,
        user_id: str,
        month_value: str,
        timezone: str,
        selected_date: Optional[date] = None,
    ) -> dict[str, Any]:
        zone = self._get_zone(timezone)
        try:
            year, month = [int(part) for part in month_value.split("-", 1)]
        except ValueError as exc:
            raise AppHTTPException(status_code=422, detail="Invalid month") from exc

        first_day = date(year, month, 1)
        cal = calendar_lib.Calendar(firstweekday=0)
        month_days = list(cal.itermonthdates(year, month))
        window_start = datetime.combine(month_days[0], datetime.min.time(), tzinfo=zone)
        window_end = datetime.combine(month_days[-1], datetime.min.time(), tzinfo=zone) + timedelta(days=1)
        user_events = await self._list_occurrence_views(user_id, window_start, window_end)
        counts: dict[str, int] = {}
        for event in user_events:
            local_start = self._to_local(self.parse_datetime(event["start_at"]), zone)
            local_end = self._to_local(self.parse_datetime(event["end_at"]), zone)
            is_point = event.get("time_shape") == constants.CALENDAR_TIME_SHAPE_POINT
            if not is_point and local_end <= local_start:
                continue
            current_day = local_start.date()
            last_day = local_start.date() if is_point else (local_end - timedelta(microseconds=1)).date()
            while current_day <= last_day:
                key = current_day.isoformat()
                counts[key] = counts.get(key, 0) + 1
                current_day += timedelta(days=1)

        days = []
        for day in month_days:
            key = day.isoformat()
            days.append(
                {
                    "date": key,
                    "in_current_month": day.month == month,
                    "is_today": day == datetime.now(zone).date(),
                    "is_selected": selected_date == day if selected_date else False,
                    "event_count": counts.get(key, 0),
                    "has_focus_event": False,
                }
            )

        selected = selected_date or first_day
        selected_day_events = await self.list_events_for_date(user_id, selected, timezone)
        return {
            "month": month_value,
            "timezone": timezone,
            "days": days,
            "selected_day_events": selected_day_events,
        }

    async def create_event(self, user_id: str, payload: dict[str, Any]) -> dict[str, Any]:
        source = str(payload.get("source") or constants.CALENDAR_SOURCE_LING).strip().lower()
        if source != constants.CALENDAR_SOURCE_LING:
            raise AppHTTPException(
                status_code=422,
                detail="Only Ling events can be created directly by the backend service",
            )
        timezone = self._normalize_required_persisted_timezone(payload.get("timezone", constants.UTC_TIMEZONE_NAME))
        start_dt = self.parse_datetime(payload["start_at"], timezone)
        end_dt = self.parse_datetime(payload["end_at"], timezone)
        time_shape = normalize_time_shape(payload.get("time_shape"))
        validate_time_shape_window(time_shape, start_dt, end_dt)

        recurrence_rule, recurrence_rrule = normalize_recurrence_payload(payload.get("recurrence"))
        validate_supported_recurrence_shape(recurrence_rule)

        event_id = f"evt_{uuid.uuid4().hex}"
        event = CalendarEvent(
            event_id=event_id,
            user_id=user_id,
            source=constants.CALENDAR_SOURCE_LING,
            title=payload["title"],
            subtitle=payload.get("subtitle"),
            category=payload.get("category", constants.DEFAULT_CALENDAR_CATEGORY),
            time_shape=time_shape,
            start_at=to_storage_utc(start_dt),
            end_at=to_storage_utc(end_dt),
            timezone=timezone,
            location=payload.get("location"),
            meeting_url=payload.get("meeting_url"),
            attendees=payload.get("attendees") or [],
            status=payload.get("status", constants.CALENDAR_STATUS_SCHEDULED),
            focus_mode_enabled=bool(payload.get("focus_mode_enabled", False)),
            series_id=event_id,
            recurrence_rule=recurrence_rule,
            recurrence_rrule=recurrence_rrule,
            recurrence_exdates=[],
            metadata=payload.get("metadata") or {},
        )
        await self.event_dao.insert(event)
        serialized = await self.serialize_event(event)
        await publish_surface_changed(
            user_id=user_id,
            surface="calendar",
            item_id=event.event_id,
            operation="created",
        )
        return serialized

    async def update_event(
        self,
        user_id: str,
        event_id: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        started_at = perf_counter()
        payload = dict(payload)
        metadata_payload = payload.get("metadata") if isinstance(payload.get("metadata"), dict) else {}
        logs_preparation_update = "schedule_preparation" in metadata_payload

        def elapsed_ms() -> int:
            return int((perf_counter() - started_at) * 1000)

        if logs_preparation_update:
            logger.info(
                "[Ling][CalendarService][update_event] start user_ref={} event_id={} "
                "payload_keys={} preparation_count={}",
                _calendar_log_ref(user_id),
                event_id,
                sorted(payload.keys()),
                len(metadata_payload.get("schedule_preparation") or []),
            )
        scope = str(payload.pop("scope", "series") or "series").strip().lower()
        occurrence_start_time = payload.pop("occurrence_start_time", None)
        recurrence_payload_present = "recurrence" in payload
        recurrence_payload = payload.pop("recurrence", None)

        event = await self.event_dao.get_user_event(user_id, event_id)
        if logs_preparation_update:
            logger.info(
                "[Ling][CalendarService][update_event] stage=get_user_event done "
                "user_ref={} event_id={} found={} elapsed_ms={}",
                _calendar_log_ref(user_id),
                event_id,
                event is not None,
                elapsed_ms(),
            )
        if event is None:
            raise AppHTTPException(status_code=404, detail="Event not found")
        self._assert_event_can_be_mutated(event, operation="updated")
        if event_source(event) != constants.CALENDAR_SOURCE_LING:
            raise AppHTTPException(
                status_code=422,
                detail="External calendar events must be updated through their original provider",
            )
        event = await self._resolve_master_event(user_id, event)
        self._assert_event_can_be_mutated(event, operation="updated")
        if logs_preparation_update:
            logger.info(
                "[Ling][CalendarService][update_event] stage=resolve_master_event done "
                "user_ref={} event_id={} master_event_id={} elapsed_ms={}",
                _calendar_log_ref(user_id),
                event_id,
                getattr(event, "event_id", None),
                elapsed_ms(),
            )

        if scope not in {"series", "occurrence"}:
            raise AppHTTPException(status_code=422, detail="scope must be series or occurrence")

        if self._is_recurring_event(event) and scope == "occurrence":
            if logs_preparation_update:
                logger.info(
                    "[Ling][CalendarService][update_event] stage=update_occurrence start "
                    "user_ref={} event_id={} elapsed_ms={}",
                    _calendar_log_ref(user_id),
                    event_id,
                    elapsed_ms(),
                )
            updated = await self._update_occurrence(
                user_id=user_id,
                master_event=event,
                occurrence_start_time=occurrence_start_time,
                payload=payload,
            )
            await publish_surface_changed(
                user_id=user_id,
                surface="calendar",
                item_id=str(updated.get("event_id") or event.event_id),
                operation="updated",
            )
            return updated

        if scope == "occurrence":
            raise AppHTTPException(status_code=422, detail="occurrence scope requires a recurring event")

        old_start_at = event.start_at
        old_recurrence_rrule = event.recurrence_rrule
        old_has_exceptions = bool((event.recurrence_exdates or []) or await self._has_occurrence_overrides(user_id, event))
        if logs_preparation_update:
            logger.info(
                "[Ling][CalendarService][update_event] stage=check_occurrence_overrides done "
                "user_ref={} event_id={} has_exceptions={} elapsed_ms={}",
                _calendar_log_ref(user_id),
                event_id,
                old_has_exceptions,
                elapsed_ms(),
            )

        event_timezone = payload.get("timezone", event.timezone)
        if "timezone" in payload and ("start_at" not in payload or "end_at" not in payload):
            event_timezone = self._normalize_required_persisted_timezone(payload["timezone"])
            payload["timezone"] = event_timezone
        elif "timezone" in payload:
            event_timezone = self._normalize_required_persisted_timezone(payload["timezone"])
            payload["timezone"] = event_timezone

        for field in [
            "title",
            "subtitle",
            "category",
            "time_shape",
            "timezone",
            "location",
            "meeting_url",
            "status",
        ]:
            if field in payload:
                value = normalize_time_shape(payload[field]) if field == "time_shape" else payload[field]
                setattr(event, field, value)
        if "start_at" in payload:
            event.start_at = to_storage_utc(self.parse_datetime(payload["start_at"], event_timezone))
        if "end_at" in payload:
            event.end_at = to_storage_utc(self.parse_datetime(payload["end_at"], event_timezone))
        if "attendees" in payload:
            event.attendees = payload.get("attendees") or []
        if "focus_mode_enabled" in payload:
            event.focus_mode_enabled = bool(payload["focus_mode_enabled"])
        if "metadata" in payload:
            event.extra_data = payload.get("metadata") or {}

        if recurrence_payload_present:
            normalized_recurrence, recurrence_rrule = normalize_recurrence_payload(recurrence_payload)
            validate_supported_recurrence_shape(normalized_recurrence)
            if old_has_exceptions and recurrence_rrule != old_recurrence_rrule:
                raise AppHTTPException(
                    status_code=422,
                    detail="Changing recurrence is not supported after occurrence overrides or deletions exist",
                )
            event.recurrence_rule = normalized_recurrence
            event.recurrence_rrule = recurrence_rrule
            event.series_id = event.series_id or event.event_id
            if not normalized_recurrence:
                event.recurrence_exdates = []
        elif not self._is_recurring_event(event):
            event.series_id = event.series_id or event.event_id

        validate_time_shape_window(
            event_time_shape(event),
            self._as_aware_storage_datetime(event.start_at),
            self._as_aware_storage_datetime(event.end_at),
        )

        if old_start_at != event.start_at and self._is_recurring_event(event):
            delta = self._as_aware_storage_datetime(event.start_at) - self._as_aware_storage_datetime(old_start_at)
            await self._shift_series_exception_keys(user_id, event, delta)

        if logs_preparation_update:
            logger.info(
                "[Ling][CalendarService][update_event] stage=save start user_ref={} "
                "event_id={} elapsed_ms={}",
                _calendar_log_ref(user_id),
                event_id,
                elapsed_ms(),
            )
        await self.event_dao.save(event)
        if logs_preparation_update:
            logger.info(
                "[Ling][CalendarService][update_event] stage=save done user_ref={} "
                "event_id={} elapsed_ms={}",
                _calendar_log_ref(user_id),
                event_id,
                elapsed_ms(),
            )
            logger.info(
                "[Ling][CalendarService][update_event] stage=serialize_event start user_ref={} "
                "event_id={} elapsed_ms={}",
                _calendar_log_ref(user_id),
                event_id,
                elapsed_ms(),
            )
        serialized = await self.serialize_event(event)
        if logs_preparation_update:
            logger.info(
                "[Ling][CalendarService][update_event] stage=serialize_event done user_ref={} "
                "event_id={} elapsed_ms={}",
                _calendar_log_ref(user_id),
                event_id,
                elapsed_ms(),
            )
        await publish_surface_changed(
            user_id=user_id,
            surface="calendar",
            item_id=event.event_id,
            operation="updated",
        )
        if logs_preparation_update:
            logger.info(
                "[Ling][CalendarService][update_event] done user_ref={} event_id={} elapsed_ms={}",
                _calendar_log_ref(user_id),
                event_id,
                elapsed_ms(),
            )
        return serialized

    async def get_event(self, user_id: str, event_id: str) -> dict[str, Any]:
        event = await self.event_dao.get_user_event(user_id, event_id)
        if event is None:
            raise AppHTTPException(status_code=404, detail="Event not found")
        return await self.serialize_event(event)

    async def get_next_recurring_occurrence_after(
        self,
        user_id: str,
        event_id: str,
        after: datetime,
    ) -> dict[str, Any] | None:
        event = await self.event_dao.get_user_event(user_id, event_id)
        if event is None or not self._is_recurring_event(event):
            return None

        window_start = ensure_utc(after) + timedelta(seconds=1)
        window_end = window_start + timedelta(days=366 * 5)
        occurrences = await self._list_occurrence_views(user_id, window_start, window_end)
        matches = [
            item
            for item in occurrences
            if item.get("event_id") == event_id
            and item.get("is_recurring")
            and item.get("occurrence_start_at")
        ]
        if not matches:
            return None
        matches = [
            item
            for item in matches
            if str(item.get("status") or "").strip().lower()
            not in constants.CALENDAR_TERMINAL_STATUSES
        ]
        if not matches:
            return None
        matches.sort(key=lambda item: self.parse_datetime(item["occurrence_start_at"]))
        return matches[0]

    async def delete_event(
        self,
        user_id: str,
        event_id: str,
        *,
        scope: str = "series",
        occurrence_start_time: str | None = None,
        delete_reason: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        event = await self.event_dao.get_user_event(user_id, event_id)
        if event is None:
            raise AppHTTPException(status_code=404, detail="Event not found")
        self._assert_event_can_be_mutated(event, operation="deleted again")
        source = event_source(event)
        if source != constants.CALENDAR_SOURCE_LING:
            if source in {"feishu", "dingtalk"}:
                from services.calendar_integrations.service import ExternalCalendarSyncService

                return await ExternalCalendarSyncService().delete_source_event(
                    user_id=user_id,
                    event=event,
                )
            raise AppHTTPException(
                status_code=422,
                detail="External calendar events must be deleted through their original provider",
            )
        event = await self._resolve_master_event(user_id, event)
        self._assert_event_can_be_mutated(event, operation="deleted again")

        if self._is_recurring_event(event) and scope == "occurrence":
            if not occurrence_start_time:
                raise AppHTTPException(status_code=422, detail="occurrence_start_time is required for occurrence scope")
            occurrence_start = to_storage_utc(self.parse_datetime(occurrence_start_time))
            override = await self.event_dao.get_occurrence_override(
                user_id,
                event.event_id,
                occurrence_start,
            )
            occurrence_info = await self._build_occurrence_info(
                event,
                occurrence_start,
                override_event=override,
            )
            if occurrence_info is None:
                raise AppHTTPException(status_code=404, detail="Occurrence not found")
            deleted_snapshot = self._serialize_occurrence(
                master_event=event,
                occurrence_info=occurrence_info,
                link=None,
            )
            exdates = self._get_recurrence_exdate_keys(event)
            exdates.add(self._storage_datetime_key(occurrence_start))
            event.recurrence_exdates = sorted(exdates)
            occurrence_key = self._storage_datetime_key(occurrence_start)
            deleted_occurrences = dict((event.extra_data or {}).get("deleted_occurrences") or {})
            deleted_occurrences[occurrence_key] = {
                "deleted_at": self._now_utc_iso(),
                "deleted_by": "agent",
                "delete_reason": delete_reason,
                **(metadata or {}),
            }
            event.extra_data = self._merge_event_metadata(
                event,
                {
                    "deleted_at": self._now_utc_iso(),
                    "deleted_by": "agent",
                    "delete_reason": delete_reason,
                    "deleted_occurrences": deleted_occurrences,
                    **(metadata or {}),
                },
            )
            if override is not None:
                await self.event_dao.delete_by_id(CalendarEvent, override.event_id)
            await self.event_dao.save(event)
            await publish_surface_changed(
                user_id=user_id,
                surface="calendar",
                item_id=event.event_id,
                operation="deleted",
            )
            return {
                **deleted_snapshot,
                "deleted": True,
                "event_id": event.event_id,
                "scope": "occurrence",
                "occurrence_start_at": occurrence_start_time,
                "status": constants.CALENDAR_STATUS_CANCELLED,
            }

        link = await self.link_dao.get_by_event_id(event.event_id, user_id)
        deleted_snapshot = await self.serialize_event(event)
        event.status = constants.CALENDAR_STATUS_CANCELLED
        event.is_active = False
        event.extra_data = self._merge_event_metadata(
            event,
            {
                "deleted_at": self._now_utc_iso(),
                "deleted_by": "agent",
                "delete_reason": delete_reason,
                **(metadata or {}),
            },
        )
        await self.event_dao.save(event)
        if self._is_recurring_event(event):
            overrides = await self.event_dao.list_user_events(user_id)
            for override in overrides:
                if override.recurrence_parent_event_id != event.event_id:
                    continue
                override.status = constants.CALENDAR_STATUS_CANCELLED
                override.is_active = False
                override.extra_data = self._merge_event_metadata(
                    override,
                    {
                        "deleted_at": self._now_utc_iso(),
                        "deleted_by": "agent",
                        "delete_reason": delete_reason,
                        **(metadata or {}),
                    },
                )
                await self.event_dao.save(override)
        await publish_surface_changed(
            user_id=user_id,
            surface="calendar",
            item_id=event.event_id,
            operation="deleted",
        )
        return {
            **deleted_snapshot,
            "deleted": True,
            "event_id": event.event_id,
            "scope": "series",
            "status": constants.CALENDAR_STATUS_CANCELLED,
            "apple_link": self._serialize_link(link),
        }

    async def complete_event(
        self,
        user_id: str,
        event_id: str,
        *,
        scope: str = "series",
        occurrence_start_time: str | None = None,
        completed_at: str | None = None,
        outcome: str = "done",
        result_summary: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        event = await self.event_dao.get_user_event(user_id, event_id)
        if event is None:
            raise AppHTTPException(status_code=404, detail="Event not found")
        self._assert_event_can_be_mutated(event, operation="completed")
        if event_source(event) != constants.CALENDAR_SOURCE_LING:
            raise AppHTTPException(
                status_code=422,
                detail="External calendar events cannot be completed through Ling",
            )
        event = await self._resolve_master_event(user_id, event)
        self._assert_event_can_be_mutated(event, operation="completed")
        if scope not in {"series", "occurrence"}:
            raise AppHTTPException(status_code=422, detail="scope must be series or occurrence")
        completion_metadata = {
            "completed_at": completed_at or self._now_utc_iso(),
            "completed_by": "agent",
            "outcome": outcome,
            "result_summary": result_summary,
            **(metadata or {}),
        }
        if self._is_recurring_event(event) and scope == "occurrence":
            current = await self._serialized_occurrence_for_update(
                user_id=user_id,
                master_event=event,
                occurrence_start_time=occurrence_start_time,
            )
            update_payload = {
                "status": constants.CALENDAR_STATUS_COMPLETED,
                "metadata": {
                    **(current.get("metadata") or {}),
                    **completion_metadata,
                },
                "scope": "occurrence",
                "occurrence_start_time": occurrence_start_time,
            }
            completed = await self.update_event(
                user_id,
                event.event_id,
                update_payload,
            )
        elif scope == "occurrence":
            raise AppHTTPException(status_code=422, detail="occurrence scope requires a recurring event")
        else:
            event.status = constants.CALENDAR_STATUS_COMPLETED
            event.is_active = True
            event.extra_data = self._merge_event_metadata(event, completion_metadata)
            await self.event_dao.save(event)
            completed = await self.serialize_event(event)
        await publish_surface_changed(
            user_id=user_id,
            surface="calendar",
            item_id=event.event_id,
            operation="updated",
        )
        return completed

    async def upsert_event_link(
        self,
        user_id: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        metadata = dict(payload.get("metadata") or {})
        existing = await self.link_dao.get_by_event_id(
            payload["event_id"],
            user_id,
        )
        if existing is None:
            existing = CalendarEventLink(
                link_id=f"clink_{uuid.uuid4().hex}",
                event_id=payload["event_id"],
                user_id=user_id,
                device_id=payload["device_id"],
                calendar_identifier=payload["calendar_identifier"],
                event_identifier=payload["event_identifier"],
                sync_state=payload.get("sync_state", constants.CALENDAR_SYNC_STATE_LINKED),
                metadata=metadata,
            )
            await self.link_dao.insert(existing)
        else:
            existing.device_id = payload["device_id"]
            existing.calendar_identifier = payload["calendar_identifier"]
            existing.event_identifier = payload["event_identifier"]
            existing.sync_state = payload.get("sync_state", existing.sync_state)
            existing.extra_data = metadata or existing.extra_data
            await self.link_dao.save(existing)
        await self._deactivate_linked_apple_rows(
            user_id=user_id,
            device_id=existing.device_id,
            event_identifier=existing.event_identifier,
            calendar_item_identifier=(existing.extra_data or {}).get("calendar_item_identifier"),
        )
        return {
            "link_id": existing.link_id,
            "event_id": existing.event_id,
            "device_id": existing.device_id,
            "calendar_identifier": existing.calendar_identifier,
            "event_identifier": existing.event_identifier,
            "calendar_item_identifier": (existing.extra_data or {}).get("calendar_item_identifier"),
            "sync_state": existing.sync_state,
        }

    async def save_calendar_context(
        self,
        user_id: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        context_timezone = self._normalize_optional_persisted_timezone(payload.get("timezone"))
        normalized_events = self._normalize_calendar_context_events(
            user_id=user_id,
            events=payload.get("events") or [],
            timezone=context_timezone,
            device_id=payload["device_id"],
        )
        window_start = to_storage_utc(self.parse_datetime(payload["window_start"]))
        window_end = to_storage_utc(self.parse_datetime(payload["window_end"]))
        sync_lock = self._apple_context_sync_lock(
            user_id=user_id,
            device_id=payload["device_id"],
        )
        async with sync_lock:
            async with transaction_scope() as session:
                mutation_summary = await self._upsert_apple_events_from_context(
                    user_id=user_id,
                    device_id=payload["device_id"],
                    window_start=window_start,
                    window_end=window_end,
                    events=normalized_events,
                    session=session,
                )
                existing = await self.context_dao.get_latest_by_device(
                    user_id,
                    payload["device_id"],
                    session=session,
                )
                if existing is None:
                    existing = AppleCalendarContext(
                        context_id=f"actx_{uuid.uuid4().hex}",
                        user_id=user_id,
                        device_id=payload["device_id"],
                        permission_state=payload.get("permission_state", "granted"),
                        window_start=window_start,
                        window_end=window_end,
                        events=[],
                    )
                    await self.context_dao.insert(existing, session=session)
                else:
                    existing.permission_state = payload.get("permission_state", existing.permission_state)
                    existing.window_start = window_start
                    existing.window_end = window_end
                    existing.events = []
                    await self.context_dao.save(existing, session=session)
        return {
            "context_id": existing.context_id,
            "device_id": existing.device_id,
            "permission_state": existing.permission_state,
            "window_start": format_datetime(existing.window_start),
            "window_end": format_datetime(existing.window_end),
            "events": [],
            "event_count": len(normalized_events),
            **mutation_summary,
        }

    def _apple_context_sync_lock(self, *, user_id: str, device_id: str) -> asyncio.Lock:
        loop_id = id(asyncio.get_running_loop())
        user_ref = _calendar_log_ref(user_id)
        device_ref = _calendar_log_ref(device_id)
        key = f"{loop_id}:{user_ref}:{device_ref}"
        lock = self._apple_context_sync_locks.get(key)
        if lock is None:
            lock = asyncio.Lock()
            self._apple_context_sync_locks[key] = lock
        return lock

    async def list_managed_apple_links(
        self,
        user_id: str,
        device_id: str,
    ) -> dict[str, Any]:
        normalized_device_id = str(device_id or "").strip()
        if not normalized_device_id:
            raise AppHTTPException(status_code=422, detail="device_id is required")
        links = await self.link_dao.list_user_device_links(user_id, normalized_device_id)
        if not links:
            return {"device_id": normalized_device_id, "items": []}

        events = await self.event_dao.list_user_events(user_id)
        event_map = {item.event_id: item for item in events}
        items: list[dict[str, Any]] = []
        for link in links:
            event = event_map.get(link.event_id)
            if event is None or event_source(event) != constants.CALENDAR_SOURCE_LING:
                continue
            items.append(
                {
                    "link_id": link.link_id,
                    "event_id": link.event_id,
                    "device_id": link.device_id,
                    "calendar_identifier": link.calendar_identifier,
                    "event_identifier": link.event_identifier,
                    "calendar_item_identifier": (link.extra_data or {}).get("calendar_item_identifier"),
                    "sync_state": link.sync_state,
                    "is_recurring": self._is_recurring_event(event),
                    "occurrence_start_at": None
                    if getattr(event, "occurrence_start_at", None) is None
                    else format_datetime(event.occurrence_start_at),
                }
            )
        return {"device_id": normalized_device_id, "items": items}

    async def delete_managed_apple_links(
        self,
        user_id: str,
        device_id: str,
    ) -> dict[str, Any]:
        normalized_device_id = str(device_id or "").strip()
        if not normalized_device_id:
            raise AppHTTPException(status_code=422, detail="device_id is required")
        await self.link_dao.delete_where(
            CalendarEventLink,
            where=[
                CalendarEventLink.user_id == user_id,
                CalendarEventLink.device_id == normalized_device_id,
            ],
        )
        return {"device_id": normalized_device_id, "removed": True}

    async def serialize_event(self, event: CalendarEvent) -> dict[str, Any]:
        if event_source(event) != constants.CALENDAR_SOURCE_LING:
            return self._serialize_external_event_row(event)

        link = await self.link_dao.get_by_event_id(event.event_id, event.user_id)
        if (
            bool(getattr(event, "is_occurrence_override", False))
            and getattr(event, "recurrence_parent_event_id", None)
            and getattr(event, "occurrence_start_at", None) is not None
        ):
            master = await self.event_dao.get_user_event(event.user_id, event.recurrence_parent_event_id)
            if master is not None:
                occurrence_info = await self._build_occurrence_info(master, event.occurrence_start_at, override_event=event)
                if occurrence_info is not None:
                    return self._serialize_occurrence(
                        master_event=master,
                        occurrence_info=occurrence_info,
                        link=link,
                    )

        if self._is_recurring_event(event):
            occurrence_info = await self._build_occurrence_info(
                event,
                event.start_at,
            )
            if occurrence_info is not None:
                return self._serialize_occurrence(
                    master_event=event,
                    occurrence_info=occurrence_info,
                    link=link,
                )

        event_zone = self._get_zone(event.timezone)
        normalized_start = self._to_local(event.start_at, event_zone)
        normalized_end = self._to_local(event.end_at, event_zone)
        return build_serialized_event_payload(
            event_id=event.event_id,
            user_id=event.user_id,
            title=event.title,
            subtitle=event.subtitle,
            category=event.category,
            time_shape=event_time_shape(event),
            start_at=normalized_start,
            end_at=normalized_end,
            timezone=event.timezone,
            location=event.location,
            meeting_url=event.meeting_url,
            attendees=event.attendees,
            status=event.status,
            focus_mode_enabled=event.focus_mode_enabled,
            metadata=public_metadata(event),
            sync_state=link.sync_state if link else constants.CALENDAR_SYNC_STATE_PENDING,
            apple_link=self._serialize_link(link),
            source=constants.CALENDAR_SOURCE_LING,
            provider=provider_for_source(constants.CALENDAR_SOURCE_LING),
            is_mutable=True,
            is_deletable=True,
            is_recurring=False,
            series_id=getattr(event, "series_id", None) or event.event_id,
            occurrence_start_at=None,
            is_occurrence_override=False,
            recurrence=None,
            created_at=event.created_at,
            updated_at=event.updated_at,
        )

    def parse_datetime(self, value: str, timezone: str = constants.UTC_TIMEZONE_NAME) -> datetime:
        _ = timezone
        try:
            normalized = value.replace("Z", "+00:00")
            parsed = datetime.fromisoformat(normalized)
        except ValueError as exc:
            raise AppHTTPException(status_code=422, detail="Invalid datetime") from exc
        if parsed.tzinfo is None or parsed.utcoffset() is None:
            raise AppHTTPException(
                status_code=422,
                detail="Datetime must include timezone offset",
                error_code="TIMEZONE_OFFSET_REQUIRED",
            )
        return parsed

    def _get_zone(self, timezone: str) -> dt_tzinfo:
        try:
            return parse_timezone(timezone)
        except Exception as exc:
            raise AppHTTPException(status_code=422, detail="Invalid timezone") from exc

    def _to_local(
        self,
        value: datetime,
        zone: dt_tzinfo,
    ) -> datetime:
        return to_timezone(value, zone)

    def _resolve_compare_zone(
        self,
        anchor: datetime,
        timezone: str | None = None,
    ) -> dt_tzinfo:
        if timezone:
            return self._get_zone(timezone)
        if anchor.tzinfo is not None:
            zone_key = getattr(anchor.tzinfo, "key", None)
            if zone_key:
                return self._get_zone(zone_key)
            offset = anchor.strftime("%z")
            if offset and len(offset) == 5:
                return self._get_zone(f"UTC{offset[:3]}:{offset[3:]}")
        return parse_timezone(constants.UTC_TIMEZONE_NAME)

    async def _list_occurrence_views(
        self,
        user_id: str,
        start_dt: datetime,
        end_dt: datetime,
    ) -> list[dict[str, Any]]:
        events = await self.event_dao.list_user_events(user_id)
        links = await self.link_dao.list_user_links(user_id)
        link_map = {link.event_id: link for link in links}
        overrides_by_parent: dict[str, dict[str, CalendarEvent]] = {}
        masters: list[CalendarEvent] = []

        for event in events:
            if event_source(event) != constants.CALENDAR_SOURCE_LING:
                continue
            if not bool(getattr(event, "is_active", True)):
                continue
            if event.is_occurrence_override and event.recurrence_parent_event_id:
                key = self._storage_datetime_key(event.occurrence_start_at)
                overrides_by_parent.setdefault(event.recurrence_parent_event_id, {})[key] = event
                continue
            masters.append(event)

        serialized: list[dict[str, Any]] = []
        for event in events:
            if event_source(event) == constants.CALENDAR_SOURCE_LING:
                continue
            if not bool(getattr(event, "is_active", True)):
                continue
            serialized_event = self._serialize_external_event_row(event)
            local_end = self.parse_datetime(serialized_event["end_at"])
            local_start = self.parse_datetime(serialized_event["start_at"])
            if not event_window_overlaps(
                start_at=local_start,
                end_at=local_end,
                window_start=start_dt,
                window_end=end_dt,
                time_shape=serialized_event.get("time_shape", constants.CALENDAR_TIME_SHAPE_SPAN),
            ):
                continue
            serialized.append(serialized_event)

        for event in masters:
            if self._should_expand_recurring_event(event):
                serialized.extend(
                    self._expand_recurring_event(
                        master_event=event,
                        overrides=overrides_by_parent.get(event.event_id, {}),
                        start_dt=start_dt,
                        end_dt=end_dt,
                        link=link_map.get(event.event_id),
                    )
                )
                continue

            zone = self._get_zone(event.timezone)
            local_start = self._to_local(event.start_at, zone)
            local_end = self._to_local(event.end_at, zone)
            if not event_window_overlaps(
                start_at=local_start,
                end_at=local_end,
                window_start=start_dt,
                window_end=end_dt,
                time_shape=event_time_shape(event),
            ):
                continue
            serialized.append(
                build_serialized_event_payload(
                    event_id=event.event_id,
                    user_id=event.user_id,
                    title=event.title,
                    subtitle=event.subtitle,
                    category=event.category,
                    time_shape=event_time_shape(event),
                    start_at=local_start,
                    end_at=local_end,
                    timezone=event.timezone,
                    location=event.location,
                    meeting_url=event.meeting_url,
                    attendees=event.attendees,
                    status=event.status,
                    focus_mode_enabled=event.focus_mode_enabled,
                    metadata=public_metadata(event),
                    sync_state=(
                        link_map.get(event.event_id).sync_state
                        if link_map.get(event.event_id)
                        else constants.CALENDAR_SYNC_STATE_PENDING
                    ),
                    apple_link=self._serialize_link(link_map.get(event.event_id)),
                    source=constants.CALENDAR_SOURCE_LING,
                    provider=provider_for_source(constants.CALENDAR_SOURCE_LING),
                    is_mutable=True,
                    is_deletable=True,
                    is_recurring=False,
                    series_id=event.series_id or event.event_id,
                    occurrence_start_at=None,
                    is_occurrence_override=False,
                    recurrence=None,
                    created_at=event.created_at,
                    updated_at=event.updated_at,
                )
            )

        return self._sort_serialized_events(serialized)

    def _expand_recurring_event(
        self,
        *,
        master_event: CalendarEvent,
        overrides: dict[str, CalendarEvent],
        start_dt: datetime,
        end_dt: datetime,
        link: CalendarEventLink | None,
    ) -> list[dict[str, Any]]:
        recurrence = effective_recurrence(master_event)
        if not recurrence or not recurrence_has_supported_shape(recurrence):
            return []

        zone = self._get_zone(master_event.timezone)
        master_start_local = self._to_local(master_event.start_at, zone)
        master_end_local = self._to_local(master_event.end_at, zone)
        window_start_local = self._to_local(start_dt, zone)
        window_end_local = self._to_local(end_dt, zone)
        exdate_keys = self._get_recurrence_exdate_keys(master_event)
        items: list[dict[str, Any]] = []

        for occurrence_start_local, occurrence_end_local in expand_recurrence_window(
            series_start_local=master_start_local,
            series_end_local=master_end_local,
            recurrence=recurrence,
            window_start_local=window_start_local,
            window_end_local=window_end_local,
        ):
            occurrence_start_utc = to_storage_utc(occurrence_start_local)
            occurrence_key = self._storage_datetime_key(occurrence_start_utc)
            override_event = overrides.get(occurrence_key)
            if occurrence_key in exdate_keys or override_event is not None:
                continue
            items.append(
                self._serialize_occurrence(
                    master_event=master_event,
                    occurrence_info={
                        "occurrence_start_utc": self._as_aware_storage_datetime(occurrence_start_utc),
                        "actual_start_local": occurrence_start_local,
                        "actual_end_local": occurrence_end_local,
                        "effective_timezone": master_event.timezone,
                        "override_event": None,
                    },
                    link=link,
                )
            )

        for override_event in overrides.values():
            occurrence_info = self._build_occurrence_info_from_override(master_event, override_event)
            if occurrence_info is None:
                continue
            actual_start_utc = ensure_utc(occurrence_info["actual_start_local"])
            actual_end_utc = ensure_utc(occurrence_info["actual_end_local"])
            if not event_window_overlaps(
                start_at=actual_start_utc,
                end_at=actual_end_utc,
                window_start=start_dt,
                window_end=end_dt,
                time_shape=event_time_shape(master_event),
            ):
                continue
            items.append(
                self._serialize_occurrence(
                    master_event=master_event,
                    occurrence_info=occurrence_info,
                    link=link,
                )
            )
        return items

    async def _update_occurrence(
        self,
        *,
        user_id: str,
        master_event: CalendarEvent,
        occurrence_start_time: str | None,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        if not occurrence_start_time:
            raise AppHTTPException(status_code=422, detail="occurrence_start_time is required for occurrence scope")
        if "recurrence" in payload:
            raise AppHTTPException(status_code=422, detail="recurrence cannot be changed for a single occurrence")
        if "timezone" in payload and ("start_at" not in payload or "end_at" not in payload):
            raise AppHTTPException(
                status_code=422,
                detail="start_at and end_at are required when changing occurrence timezone",
            )

        occurrence_start_utc = to_storage_utc(self.parse_datetime(occurrence_start_time))
        occurrence_info = await self._build_occurrence_info(master_event, occurrence_start_utc)
        if occurrence_info is None:
            raise AppHTTPException(status_code=404, detail="Occurrence not found")

        override = await self.event_dao.get_occurrence_override(user_id, master_event.event_id, occurrence_start_utc)
        override_fields = set(self._override_fields(override)) if override else set()
        effective_timezone = payload.get("timezone", occurrence_info["effective_timezone"])
        if "timezone" in payload:
            effective_timezone = self._normalize_required_persisted_timezone(payload["timezone"])
            payload["timezone"] = effective_timezone

        base_start = occurrence_info["actual_start_local"]
        base_end = occurrence_info["actual_end_local"]
        if "start_at" in payload:
            target_start = self.parse_datetime(payload["start_at"], effective_timezone)
            override_fields.add("start_at")
        else:
            target_start = base_start
        if "end_at" in payload:
            target_end = self.parse_datetime(payload["end_at"], effective_timezone)
            override_fields.add("end_at")
        else:
            target_end = base_end
        validate_time_shape_window(
            event_time_shape(master_event),
            target_start,
            target_end,
        )

        if "timezone" in payload:
            override_fields.add("timezone")

        if override is None:
            override = CalendarEvent(
                event_id=f"evt_{uuid.uuid4().hex}",
                user_id=user_id,
                title=master_event.title,
                subtitle=master_event.subtitle,
                category=master_event.category,
                time_shape=event_time_shape(master_event),
                start_at=to_storage_utc(target_start),
                end_at=to_storage_utc(target_end),
                timezone=effective_timezone,
                location=master_event.location,
                meeting_url=master_event.meeting_url,
                attendees=master_event.attendees,
                status=master_event.status,
                focus_mode_enabled=master_event.focus_mode_enabled,
                series_id=master_event.series_id or master_event.event_id,
                recurrence_parent_event_id=master_event.event_id,
                occurrence_start_at=occurrence_start_utc,
                recurrence_rule=None,
                recurrence_rrule=None,
                recurrence_exdates=[],
                is_occurrence_override=True,
                metadata=public_metadata(master_event),
            )
        else:
            override.start_at = to_storage_utc(target_start)
            override.end_at = to_storage_utc(target_end)
            override.timezone = effective_timezone

        for field in [
            "title",
            "subtitle",
            "category",
            "location",
            "meeting_url",
            "status",
        ]:
            if field in payload:
                setattr(override, field, payload[field])
                override_fields.add(field)
        if "attendees" in payload:
            override.attendees = payload.get("attendees") or []
            override_fields.add("attendees")
        if "focus_mode_enabled" in payload:
            override.focus_mode_enabled = bool(payload["focus_mode_enabled"])
            override_fields.add("focus_mode_enabled")
        if "metadata" in payload:
            override.extra_data = payload.get("metadata") or {}
            override_fields.add("metadata")

        self._set_override_fields(override, override_fields)
        exdates = self._get_recurrence_exdate_keys(master_event)
        exdates.add(self._storage_datetime_key(occurrence_start_utc))
        master_event.recurrence_exdates = sorted(exdates)

        if await self.event_dao.get_occurrence_override(user_id, master_event.event_id, occurrence_start_utc) is None:
            await self.event_dao.insert(override)
        else:
            await self.event_dao.save(override)
        await self.event_dao.save(master_event)

        updated_info = self._build_occurrence_info_from_override(master_event, override)
        if updated_info is None:
            raise AppHTTPException(status_code=500, detail="Failed to build updated occurrence")
        link = await self.link_dao.get_by_event_id(master_event.event_id, user_id)
        return self._serialize_occurrence(master_event=master_event, occurrence_info=updated_info, link=link)

    async def _build_occurrence_info(
        self,
        master_event: CalendarEvent,
        occurrence_start_utc: datetime | None,
        *,
        override_event: CalendarEvent | None = None,
    ) -> dict[str, Any] | None:
        if occurrence_start_utc is None:
            return None
        recurrence = effective_recurrence(master_event)
        if not recurrence:
            return None

        zone = self._get_zone(master_event.timezone)
        master_start_local = self._to_local(master_event.start_at, zone)
        master_end_local = self._to_local(master_event.end_at, zone)
        nominal_occurrence_start_local = self._to_local(occurrence_start_utc, zone)
        nominal_occurrence_end_local = nominal_occurrence_start_local + (master_end_local - master_start_local)

        if override_event is None:
            override_event = None

        actual_start_local = nominal_occurrence_start_local
        actual_end_local = nominal_occurrence_end_local
        effective_timezone = master_event.timezone
        if override_event is not None:
            override_fields = self._override_fields(override_event)
            if {"start_at", "end_at", "timezone"} & override_fields:
                effective_timezone = override_event.timezone
                override_zone = self._get_zone(effective_timezone)
                actual_start_local = self._to_local(override_event.start_at, override_zone)
                actual_end_local = self._to_local(override_event.end_at, override_zone)

        return {
            "occurrence_start_utc": self._as_aware_storage_datetime(occurrence_start_utc),
            "actual_start_local": actual_start_local,
            "actual_end_local": actual_end_local,
            "effective_timezone": effective_timezone,
            "override_event": override_event,
        }

    async def _serialized_occurrence_for_update(
        self,
        *,
        user_id: str,
        master_event: CalendarEvent,
        occurrence_start_time: str | None,
    ) -> dict[str, Any]:
        if not occurrence_start_time:
            raise AppHTTPException(status_code=422, detail="occurrence_start_time is required for occurrence scope")
        occurrence_start_utc = to_storage_utc(self.parse_datetime(occurrence_start_time))
        override = await self.event_dao.get_occurrence_override(
            user_id,
            master_event.event_id,
            occurrence_start_utc,
        )
        occurrence_info = await self._build_occurrence_info(
            master_event,
            occurrence_start_utc,
            override_event=override,
        )
        if occurrence_info is None:
            raise AppHTTPException(status_code=404, detail="Occurrence not found")
        link = await self.link_dao.get_by_event_id(master_event.event_id, user_id)
        return self._serialize_occurrence(
            master_event=master_event,
            occurrence_info=occurrence_info,
            link=link,
        )

    def _merge_event_metadata(
        self,
        event: CalendarEvent,
        metadata: dict[str, Any],
    ) -> dict[str, Any]:
        return {
            **(getattr(event, "extra_data", None) or {}),
            **{
                key: value
                for key, value in metadata.items()
                if value is not None
            },
        }

    def _assert_event_can_be_mutated(
        self,
        event: CalendarEvent,
        *,
        operation: str,
    ) -> None:
        if (
            bool(getattr(event, "is_active", True))
            and getattr(event, "status", None) != constants.CALENDAR_STATUS_CANCELLED
        ):
            return
        raise AppHTTPException(
            status_code=410,
            detail=f"Deleted calendar events cannot be {operation}",
            error_code="CALENDAR_EVENT_DELETED",
            error_detail={
                "event_id": getattr(event, "event_id", None),
                "status": getattr(event, "status", None),
            },
        )

    def _now_utc_iso(self) -> str:
        return datetime.now(UTC).isoformat()

    def _build_occurrence_info_from_override(
        self,
        master_event: CalendarEvent,
        override_event: CalendarEvent,
    ) -> dict[str, Any] | None:
        if override_event.occurrence_start_at is None:
            return None
        return {
            "occurrence_start_utc": self._as_aware_storage_datetime(override_event.occurrence_start_at),
            "actual_start_local": self._to_local(
                override_event.start_at,
                self._get_zone(override_event.timezone),
            ),
            "actual_end_local": self._to_local(
                override_event.end_at,
                self._get_zone(override_event.timezone),
            ),
            "effective_timezone": override_event.timezone,
            "override_event": override_event,
        }

    def _serialize_occurrence(
        self,
        *,
        master_event: CalendarEvent,
        occurrence_info: dict[str, Any],
        link: CalendarEventLink | None,
    ) -> dict[str, Any]:
        override_event = occurrence_info.get("override_event")
        title = self._effective_occurrence_field(master_event, override_event, "title")
        subtitle = self._effective_occurrence_field(master_event, override_event, "subtitle")
        category = self._effective_occurrence_field(master_event, override_event, "category")
        location = self._effective_occurrence_field(master_event, override_event, "location")
        meeting_url = self._effective_occurrence_field(master_event, override_event, "meeting_url")
        status = self._effective_occurrence_field(master_event, override_event, "status")
        attendees = self._effective_occurrence_field(master_event, override_event, "attendees")
        focus_mode_enabled = self._effective_occurrence_field(master_event, override_event, "focus_mode_enabled")
        metadata = self._effective_occurrence_metadata(master_event, override_event)
        return build_serialized_event_payload(
            event_id=master_event.event_id,
            user_id=master_event.user_id,
            title=title,
            subtitle=subtitle,
            category=category,
            time_shape=event_time_shape(master_event),
            start_at=occurrence_info["actual_start_local"],
            end_at=occurrence_info["actual_end_local"],
            timezone=occurrence_info["effective_timezone"],
            location=location,
            meeting_url=meeting_url,
            attendees=attendees,
            status=status,
            focus_mode_enabled=focus_mode_enabled,
            metadata=metadata,
            sync_state=link.sync_state if link else constants.CALENDAR_SYNC_STATE_PENDING,
            apple_link=self._serialize_link(link),
            source=constants.CALENDAR_SOURCE_LING,
            provider=provider_for_source(constants.CALENDAR_SOURCE_LING),
            is_mutable=True,
            is_deletable=True,
            is_recurring=True,
            series_id=master_event.series_id or master_event.event_id,
            occurrence_start_at=self._to_local(
                occurrence_info["occurrence_start_utc"],
                self._get_zone(occurrence_info["effective_timezone"]),
            ),
            is_occurrence_override=override_event is not None,
            recurrence=serialize_recurrence(
                master_event,
                get_zone=self._get_zone,
                to_local=self._to_local,
            ),
            created_at=(override_event or master_event).created_at,
            updated_at=(override_event or master_event).updated_at,
        )

    def _normalize_calendar_context_events(
        self,
        *,
        user_id: str,
        events: list[dict[str, Any]],
        timezone: str | None,
        device_id: str,
    ) -> list[dict[str, Any]]:
        normalized: list[dict[str, Any]] = []
        for item in events:
            event_timezone = self._resolve_imported_event_timezone(
                raw=item,
                fallback_timezone=timezone,
            )
            if event_timezone is None:
                continue
            normalized_item = self._normalize_imported_apple_event(
                user_id=user_id,
                raw=item,
                timezone=event_timezone,
                device_id=device_id,
            )
            if normalized_item is None:
                continue
            normalized.append(normalized_item)
        return normalized

    def _normalize_imported_apple_event(
        self,
        *,
        user_id: str,
        raw: dict[str, Any],
        timezone: str,
        device_id: str,
    ) -> dict[str, Any] | None:
        try:
            start_dt = self.parse_datetime(str(raw.get("start_at") or raw.get("startAt")))
            end_dt = self.parse_datetime(str(raw.get("end_at") or raw.get("endAt")))
        except Exception:
            return None
        if end_dt <= start_dt:
            return None

        requested_zone = self._get_zone(timezone)
        event_identifier = str(raw.get("event_identifier") or raw.get("identifier") or "").strip()
        calendar_identifier = str(raw.get("calendar_identifier") or raw.get("calendarIdentifier") or "").strip()
        calendar_item_identifier = str(
            raw.get("calendar_item_identifier") or raw.get("calendarItemIdentifier") or ""
        ).strip()
        raw_rrules = raw.get("raw_rrules") or raw.get("rawRRules") or []
        if isinstance(raw_rrules, str):
            raw_rrules = [raw_rrules]
        recurrence = raw.get("recurrence")
        if recurrence is None and raw_rrules:
            parsed = parse_raw_rrule(str(raw_rrules[0]))
            recurrence = parsed if parsed else None
        recurrence_output = self._normalize_imported_recurrence(
            recurrence=recurrence,
            raw_rrules=[str(item) for item in raw_rrules if str(item).strip()],
            anchor_start=start_dt,
            anchor_end=end_dt,
        )
        is_recurring = bool(raw.get("is_recurring") or recurrence_output is not None)
        series_identifier = calendar_item_identifier or event_identifier or self._storage_datetime_key(start_dt)
        start_local = self._to_local(start_dt, requested_zone)
        end_local = self._to_local(end_dt, requested_zone)
        occurrence_local = start_local

        metadata = {
            "calendar_title": raw.get("calendar_title") or raw.get("calendarTitle"),
            "is_all_day": bool(raw.get("is_all_day") or raw.get("isAllDay")),
            "kind": str(raw.get("kind") or "event"),
            "raw_rrules": [str(item) for item in raw_rrules if str(item).strip()],
        }

        result = build_serialized_event_payload(
            event_id="",
            user_id=user_id,
            title=str(raw.get("title") or "").strip(),
            subtitle=(str(raw.get("notes") or "").strip() or None),
            category=constants.EXTERNAL_CALENDAR_CATEGORY,
            time_shape=constants.CALENDAR_TIME_SHAPE_SPAN,
            start_at=start_local,
            end_at=end_local,
            timezone=timezone,
            location=(str(raw.get("location") or "").strip() or None),
            meeting_url=None,
            attendees=[],
            status=constants.CALENDAR_STATUS_SCHEDULED,
            focus_mode_enabled=False,
            metadata=metadata,
            sync_state="imported",
            apple_link={
                "device_id": device_id,
                "calendar_identifier": calendar_identifier,
                "event_identifier": event_identifier,
                "calendar_item_identifier": calendar_item_identifier or None,
            },
            source=constants.CALENDAR_SOURCE_APPLE,
            provider=provider_for_source(constants.CALENDAR_SOURCE_APPLE),
            is_mutable=False,
            is_deletable=True,
            is_recurring=is_recurring,
            series_id=series_identifier,
            occurrence_start_at=occurrence_local,
            is_occurrence_override=bool(raw.get("is_detached") or raw.get("isDetached")),
            recurrence=recurrence_output,
        )
        return result

    def _normalize_imported_recurrence(
        self,
        *,
        recurrence: Any,
        raw_rrules: list[str],
        anchor_start: datetime,
        anchor_end: datetime,
    ) -> dict[str, Any] | None:
        structured = dict(recurrence or {}) if isinstance(recurrence, dict) else None
        if structured:
            structured = {key: value for key, value in structured.items() if value not in (None, [], "")}
        if not structured and raw_rrules:
            parsed = parse_raw_rrule(raw_rrules[0])
            structured = parsed or None
        if not structured and not raw_rrules:
            return None
        result = dict(structured or {})
        if raw_rrules:
            result["raw_rrules"] = raw_rrules
        result["anchor_start_at"] = format_datetime(anchor_start)
        result["anchor_end_at"] = format_datetime(anchor_end)
        return result

    async def _get_latest_contexts_by_device(self, user_id: str) -> list[AppleCalendarContext]:
        contexts = await self.context_dao.list_user_contexts(user_id)
        latest_by_device: dict[str, AppleCalendarContext] = {}
        for context in contexts:
            latest_by_device.setdefault(context.device_id, context)
        return list(latest_by_device.values())

    async def _apple_sync_coverage(self, user_id: str) -> dict[str, Any]:
        contexts = await self._get_latest_contexts_by_device(user_id)
        if not contexts:
            return {
                "coverage_start": None,
                "coverage_end": None,
                "permission_state": "unknown",
            }

        permission_state = "unknown"
        coverage_start: datetime | None = None
        coverage_end: datetime | None = None
        for context in contexts:
            if permission_state == "unknown":
                permission_state = context.permission_state
            context_start = self._as_aware_storage_datetime(context.window_start)
            context_end = self._as_aware_storage_datetime(context.window_end)
            coverage_start = context_start if coverage_start is None else min(coverage_start, context_start)
            coverage_end = context_end if coverage_end is None else max(coverage_end, context_end)
        return {
            "coverage_start": coverage_start,
            "coverage_end": coverage_end,
            "permission_state": permission_state,
        }

    async def _upsert_apple_events_from_context(
        self,
        *,
        user_id: str,
        device_id: str,
        window_start: datetime,
        window_end: datetime,
        events: list[dict[str, Any]],
        session: AsyncSession | None = None,
    ) -> dict[str, Any]:
        links = await self.link_dao.list_user_links(user_id, session=session)
        excluded_event_identifiers = {
            (link.event_identifier or "").strip()
            for link in links
            if (link.event_identifier or "").strip()
        }
        excluded_calendar_item_identifiers = {
            str((link.extra_data or {}).get("calendar_item_identifier") or "").strip()
            for link in links
            if str((link.extra_data or {}).get("calendar_item_identifier") or "").strip()
        }
        existing_events = await self.event_dao.list_user_source_events(
            user_id,
            constants.CALENDAR_SOURCE_APPLE,
            session=session,
        )
        pending_by_event_id = {event.event_id: event for event in existing_events}
        seen_event_ids: set[str] = set()
        inserted_count = 0
        updated_count = 0
        deactivated_count = 0

        for item in events:
            apple_link = item.get("apple_link") or {}
            event_identifier = str(apple_link.get("event_identifier") or "").strip()
            calendar_item_identifier = str(apple_link.get("calendar_item_identifier") or "").strip()
            if event_identifier and event_identifier in excluded_event_identifiers:
                continue
            if calendar_item_identifier and calendar_item_identifier in excluded_calendar_item_identifiers:
                continue

            payload = self._build_apple_event_storage_payload(
                item,
                user_id=user_id,
                device_id=device_id,
            )
            existing = pending_by_event_id.get(payload["event_id"])
            if existing is None:
                new_row = CalendarEvent(
                    event_id=payload["event_id"],
                    user_id=user_id,
                    source=constants.CALENDAR_SOURCE_APPLE,
                    title=payload["title"],
                    subtitle=payload["subtitle"],
                    category=payload["category"],
                    time_shape=constants.CALENDAR_TIME_SHAPE_SPAN,
                    start_at=payload["start_at"],
                    end_at=payload["end_at"],
                    timezone=payload["timezone"],
                    location=payload["location"],
                    meeting_url=payload["meeting_url"],
                    attendees=payload["attendees"],
                    status=payload["status"],
                    focus_mode_enabled=payload["focus_mode_enabled"],
                    series_id=payload["series_id"],
                    recurrence_parent_event_id=None,
                    occurrence_start_at=payload["occurrence_start_at"],
                    recurrence_rule=payload["recurrence_rule"],
                    recurrence_rrule=payload["recurrence_rrule"],
                    recurrence_exdates=[],
                    is_occurrence_override=payload["is_occurrence_override"],
                    source_device_id=payload["source_device_id"],
                    external_calendar_identifier=payload["external_calendar_identifier"],
                    external_event_identifier=payload["external_event_identifier"],
                    external_calendar_item_identifier=payload["external_calendar_item_identifier"],
                    is_active=True,
                    metadata=payload["metadata"],
                )
                await self.event_dao.insert(new_row, session=session)
                existing = new_row
                existing_events.append(existing)
                pending_by_event_id[existing.event_id] = existing
                inserted_count += 1
            else:
                if self._apple_storage_payload_differs(existing, payload):
                    self._apply_apple_storage_payload(existing, payload)
                    await self.event_dao.save(existing, session=session)
                    updated_count += 1
            seen_event_ids.add(existing.event_id)

        for event in existing_events:
            if event.event_id in seen_event_ids:
                continue
            if not self._apple_event_overlaps_window(event, window_start, window_end):
                continue
            if bool(getattr(event, "is_active", True)):
                event.is_active = False
                await self.event_dao.save(event, session=session)
                deactivated_count += 1
        return {
            "did_mutate_events": (
                inserted_count > 0 or updated_count > 0 or deactivated_count > 0
            ),
            "inserted_count": inserted_count,
            "updated_count": updated_count,
            "deactivated_count": deactivated_count,
        }

    async def _deactivate_linked_apple_rows(
        self,
        *,
        user_id: str,
        device_id: str,
        event_identifier: str | None,
        calendar_item_identifier: str | None,
    ) -> None:
        normalized_event_identifier = str(event_identifier or "").strip()
        normalized_calendar_item_identifier = str(calendar_item_identifier or "").strip()
        if not normalized_event_identifier and not normalized_calendar_item_identifier:
            return

        apple_events = await self.event_dao.list_user_source_events(user_id, constants.CALENDAR_SOURCE_APPLE)
        for event in apple_events:
            if (event.source_device_id or "").strip() != device_id:
                continue
            matches_event_identifier = (
                normalized_event_identifier
                and (event.external_event_identifier or "").strip() == normalized_event_identifier
            )
            matches_item_identifier = (
                normalized_calendar_item_identifier
                and (event.external_calendar_item_identifier or "").strip()
                == normalized_calendar_item_identifier
            )
            if not matches_event_identifier and not matches_item_identifier:
                continue
            if not bool(getattr(event, "is_active", True)):
                continue
            event.is_active = False
            await self.event_dao.save(event)

    def _build_apple_event_storage_payload(
        self,
        event: dict[str, Any],
        *,
        user_id: str,
        device_id: str,
    ) -> dict[str, Any]:
        apple_link = event.get("apple_link") or {}
        metadata = dict(event.get("metadata") or {})
        recurrence = dict(event.get("recurrence") or {}) if isinstance(event.get("recurrence"), dict) else None
        recurrence_rrule = None
        if recurrence:
            raw_rrules = recurrence.get("raw_rrules")
            if isinstance(raw_rrules, list):
                recurrence_rrule = next(
                    (str(item).strip() for item in raw_rrules if str(item).strip()),
                    None,
                )
            recurrence_rrule = recurrence_rrule or str(recurrence.get("raw_rrule") or "").strip() or None
            metadata["_apple_recurrence"] = recurrence
            if recurrence_rrule:
                metadata["_apple_recurrence_rrule"] = recurrence_rrule
        occurrence_start_at = event.get("occurrence_start_at") or event.get("start_at")
        event_identifier = str(apple_link.get("event_identifier") or "").strip()
        calendar_item_identifier = str(apple_link.get("calendar_item_identifier") or "").strip()
        external_calendar_identifier = str(apple_link.get("calendar_identifier") or "").strip() or None
        external_event_identifier = event_identifier or None
        external_calendar_item_identifier = calendar_item_identifier or None
        series_id = (
            str(event.get("series_id") or "").strip()
            or calendar_item_identifier
            or event_identifier
            or str(event.get("event_id") or "").strip()
        )
        payload = {
            "user_id": user_id,
            "title": str(event.get("title") or "").strip(),
            "subtitle": event.get("subtitle"),
            "category": str(event.get("category") or constants.EXTERNAL_CALENDAR_CATEGORY).strip()
            or constants.EXTERNAL_CALENDAR_CATEGORY,
            "time_shape": constants.CALENDAR_TIME_SHAPE_SPAN,
            "start_at": to_storage_utc(self.parse_datetime(event["start_at"])),
            "end_at": to_storage_utc(self.parse_datetime(event["end_at"])),
            "timezone": self._normalize_required_persisted_timezone(
                event.get("timezone") or constants.UTC_TIMEZONE_NAME
            ),
            "location": event.get("location"),
            "meeting_url": event.get("meeting_url"),
            "attendees": list(event.get("attendees") or []),
            "status": str(event.get("status") or constants.CALENDAR_STATUS_SCHEDULED).strip()
            or constants.CALENDAR_STATUS_SCHEDULED,
            "focus_mode_enabled": bool(event.get("focus_mode_enabled", False)),
            "series_id": series_id,
            "occurrence_start_at": None
            if occurrence_start_at is None
            else to_storage_utc(self.parse_datetime(occurrence_start_at)),
            "recurrence_rule": None,
            "recurrence_rrule": None,
            "is_occurrence_override": bool(event.get("is_occurrence_override")),
            "source_device_id": device_id,
            "external_calendar_identifier": external_calendar_identifier,
            "external_event_identifier": external_event_identifier,
            "external_calendar_item_identifier": external_calendar_item_identifier,
            "metadata": metadata,
        }
        payload["event_id"] = self._build_imported_apple_event_id(payload)
        return payload

    def _apply_apple_storage_payload(
        self,
        event: CalendarEvent,
        payload: dict[str, Any],
    ) -> None:
        event.source = constants.CALENDAR_SOURCE_APPLE
        event.title = payload["title"]
        event.subtitle = payload["subtitle"]
        event.category = payload["category"]
        event.time_shape = constants.CALENDAR_TIME_SHAPE_SPAN
        event.start_at = payload["start_at"]
        event.end_at = payload["end_at"]
        event.timezone = payload["timezone"]
        event.location = payload["location"]
        event.meeting_url = payload["meeting_url"]
        event.attendees = payload["attendees"]
        event.status = payload["status"]
        event.focus_mode_enabled = payload["focus_mode_enabled"]
        event.series_id = payload["series_id"]
        event.occurrence_start_at = payload["occurrence_start_at"]
        event.recurrence_rule = payload["recurrence_rule"]
        event.recurrence_rrule = payload["recurrence_rrule"]
        event.recurrence_parent_event_id = None
        event.recurrence_exdates = []
        event.is_occurrence_override = payload["is_occurrence_override"]
        event.source_device_id = payload["source_device_id"]
        event.external_calendar_identifier = payload["external_calendar_identifier"]
        event.external_event_identifier = payload["external_event_identifier"]
        event.external_calendar_item_identifier = payload["external_calendar_item_identifier"]
        event.is_active = True
        event.extra_data = payload["metadata"]

    def _apple_storage_payload_differs(
        self,
        event: CalendarEvent,
        payload: dict[str, Any],
    ) -> bool:
        current_metadata = dict(getattr(event, "extra_data", None) or {})
        return (
            event_source(event) != constants.CALENDAR_SOURCE_APPLE
            or event.title != payload["title"]
            or (event.subtitle or None) != (payload["subtitle"] or None)
            or (event.category or None) != (payload["category"] or None)
            or event_time_shape(event) != constants.CALENDAR_TIME_SHAPE_SPAN
            or event.start_at != payload["start_at"]
            or event.end_at != payload["end_at"]
            or event.timezone != payload["timezone"]
            or (event.location or None) != (payload["location"] or None)
            or (event.meeting_url or None) != (payload["meeting_url"] or None)
            or (event.attendees or []) != (payload["attendees"] or [])
            or event.status != payload["status"]
            or bool(event.focus_mode_enabled) != bool(payload["focus_mode_enabled"])
            or (event.series_id or None) != (payload["series_id"] or None)
            or event.occurrence_start_at != payload["occurrence_start_at"]
            or event.recurrence_rule != payload["recurrence_rule"]
            or event.recurrence_rrule != payload["recurrence_rrule"]
            or bool(getattr(event, "is_occurrence_override", False))
            != bool(payload["is_occurrence_override"])
            or (event.source_device_id or None) != (payload["source_device_id"] or None)
            or (event.external_calendar_identifier or None)
            != (payload["external_calendar_identifier"] or None)
            or (event.external_event_identifier or None)
            != (payload["external_event_identifier"] or None)
            or (event.external_calendar_item_identifier or None)
            != (payload["external_calendar_item_identifier"] or None)
            or not bool(getattr(event, "is_active", True))
            or current_metadata != dict(payload["metadata"] or {})
        )

    def _apple_event_overlaps_window(
        self,
        event: CalendarEvent,
        window_start: datetime,
        window_end: datetime,
    ) -> bool:
        event_start = self._as_aware_storage_datetime(event.start_at)
        event_end = self._as_aware_storage_datetime(event.end_at)
        return event_end > ensure_utc(window_start) and event_start < ensure_utc(window_end)

    def _should_expand_recurring_event(self, event: CalendarEvent) -> bool:
        return event_source(event) == constants.CALENDAR_SOURCE_LING and self._is_recurring_event(event)

    def _serialize_external_event_row(self, event: CalendarEvent) -> dict[str, Any]:
        source = event_source(event)
        zone = self._get_zone(event.timezone)
        start_at = self._to_local(event.start_at, zone)
        end_at = self._to_local(event.end_at, zone)
        occurrence_start_at = getattr(event, "occurrence_start_at", None)
        recurrence = (
            serialize_imported_apple_recurrence(
                event,
                get_zone=self._get_zone,
                to_local=self._to_local,
            )
            if source == constants.CALENDAR_SOURCE_APPLE
            else serialize_recurrence(
                event,
                get_zone=self._get_zone,
                to_local=self._to_local,
            )
        )
        apple_link = None
        if source == constants.CALENDAR_SOURCE_APPLE:
            apple_link = {
                "device_id": event.source_device_id,
                "calendar_identifier": event.external_calendar_identifier,
                "event_identifier": event.external_event_identifier,
                "calendar_item_identifier": event.external_calendar_item_identifier,
            }
        return build_serialized_event_payload(
            event_id=event.event_id,
            user_id=event.user_id,
            title=event.title,
            subtitle=event.subtitle,
            category=event.category,
            time_shape=event_time_shape(event),
            start_at=start_at,
            end_at=end_at,
            timezone=event.timezone,
            location=event.location,
            meeting_url=event.meeting_url,
            attendees=event.attendees,
            status=event.status,
            focus_mode_enabled=event.focus_mode_enabled,
            metadata=public_metadata(event),
            sync_state="imported",
            apple_link=apple_link,
            source=source,
            provider=provider_for_source(source),
            is_mutable=False,
            is_deletable=source in constants.CALENDAR_EXTERNAL_SOURCES,
            is_recurring=bool(recurrence),
            series_id=event.series_id or event.event_id,
            occurrence_start_at=None
            if occurrence_start_at is None
            else self._to_local(occurrence_start_at, zone),
            is_occurrence_override=bool(getattr(event, "is_occurrence_override", False)),
            recurrence=recurrence,
            created_at=event.created_at,
            updated_at=event.updated_at,
        )

    async def _resolve_master_event(
        self,
        user_id: str,
        event: CalendarEvent,
    ) -> CalendarEvent:
        if event.is_occurrence_override and event.recurrence_parent_event_id:
            master = await self.event_dao.get_user_event(user_id, event.recurrence_parent_event_id)
            if master is not None:
                return master
        return event

    async def _has_occurrence_overrides(self, user_id: str, master_event: CalendarEvent) -> bool:
        events = await self.event_dao.list_user_events(user_id)
        return any(
            event.is_occurrence_override and event.recurrence_parent_event_id == master_event.event_id
            for event in events
        )

    async def _shift_series_exception_keys(
        self,
        user_id: str,
        master_event: CalendarEvent,
        delta: timedelta,
    ) -> None:
        if delta == timedelta(0):
            return

        exdates = []
        for item in master_event.recurrence_exdates or []:
            shifted = self._as_aware_storage_datetime(item) + delta
            exdates.append(self._storage_datetime_key(shifted))
        master_event.recurrence_exdates = sorted(set(exdates))

        events = await self.event_dao.list_user_events(user_id)
        for item in events:
            if not item.is_occurrence_override or item.recurrence_parent_event_id != master_event.event_id:
                continue
            if item.occurrence_start_at is not None:
                item.occurrence_start_at = to_storage_utc(self._as_aware_storage_datetime(item.occurrence_start_at) + delta)
                await self.event_dao.save(item)

    def _is_recurring_event(self, event: CalendarEvent) -> bool:
        return bool(getattr(event, "recurrence_rule", None) or getattr(event, "recurrence_rrule", None))

    def _override_fields(self, event: CalendarEvent | None) -> set[str]:
        if event is None:
            return set()
        raw_fields = (event.extra_data or {}).get("_override_fields") or []
        return {str(item) for item in raw_fields if str(item).strip()}

    def _set_override_fields(self, event: CalendarEvent, fields: set[str]) -> None:
        extra_data = dict(event.extra_data or {})
        extra_data["_override_fields"] = sorted(fields)
        event.extra_data = extra_data

    def _effective_occurrence_field(
        self,
        master_event: CalendarEvent,
        override_event: CalendarEvent | None,
        field_name: str,
    ) -> Any:
        if override_event is not None and field_name in self._override_fields(override_event):
            return getattr(override_event, field_name)
        return getattr(master_event, field_name)

    def _effective_occurrence_metadata(
        self,
        master_event: CalendarEvent,
        override_event: CalendarEvent | None,
    ) -> dict[str, Any]:
        if override_event is not None and "metadata" in self._override_fields(override_event):
            return public_metadata(override_event)
        return public_metadata(master_event)

    def _serialize_link(self, link: CalendarEventLink | None) -> dict[str, Any] | None:
        if link is None:
            return None
        return {
            "device_id": link.device_id,
            "calendar_identifier": link.calendar_identifier,
            "event_identifier": link.event_identifier,
            "calendar_item_identifier": (link.extra_data or {}).get("calendar_item_identifier"),
        }

    def _tokenize_search_text(self, text: str) -> list[str]:
        normalized = (text or "").strip().casefold()
        if not normalized:
            return []
        latin_tokens = re.findall(r"[a-z0-9_]+", normalized)
        cjk_chars = re.findall(r"[\u4e00-\u9fff]", normalized)
        return latin_tokens + cjk_chars

    def _serialized_event_search_text(self, event: dict[str, Any]) -> str:
        title = str(event.get("title") or "").strip()
        subtitle = str(event.get("subtitle") or "").strip()
        location = str(event.get("location") or "").strip()
        meeting_url = str(event.get("meeting_url") or "").strip()
        category = str(event.get("category") or "").strip()
        status = str(event.get("status") or "").strip()
        metadata = str(event.get("metadata") or {})
        attendees = str(event.get("attendees") or [])
        recurrence = str(event.get("recurrence") or {})
        weighted_parts = [
            title,
            title,
            title,
            subtitle,
            subtitle,
            location,
            location,
            meeting_url,
            category,
            status,
            metadata,
            attendees,
            recurrence,
        ]
        return " ".join(part for part in weighted_parts if part)

    def _rank_serialized_events_by_bm25(
        self,
        events: list[dict[str, Any]],
        query_text: str,
        query_tokens: list[str],
    ) -> list[tuple[dict[str, Any], float]]:
        docs = [self._tokenize_search_text(self._serialized_event_search_text(event)) for event in events]
        if not docs:
            return []

        doc_term_freqs = [Counter(tokens) for tokens in docs]
        doc_lengths = [len(tokens) for tokens in docs]
        avg_doc_len = sum(doc_lengths) / max(1, len(doc_lengths))
        doc_freq: Counter[str] = Counter()
        for term_freq in doc_term_freqs:
            doc_freq.update(term_freq.keys())

        k1 = 1.5
        b = 0.75
        query_terms = Counter(query_tokens)
        lower_query = query_text.casefold()
        scored: list[tuple[dict[str, Any], float]] = []

        for event, term_freq, doc_len in zip(
            events,
            doc_term_freqs,
            doc_lengths,
            strict=True,
        ):
            score = 0.0
            norm = k1 * (1 - b + b * (doc_len / max(avg_doc_len, 1e-9)))
            search_text = self._serialized_event_search_text(event).casefold()
            for term, qtf in query_terms.items():
                tf = term_freq.get(term, 0)
                if tf == 0:
                    continue
                df = doc_freq.get(term, 0)
                idf = math.log(1 + (len(events) - df + 0.5) / (df + 0.5))
                score += qtf * idf * ((tf * (k1 + 1)) / (tf + norm))
            if lower_query and lower_query in search_text:
                score += 0.25
            if score > 0:
                scored.append((event, score))
        return scored

    def _storage_datetime_key(self, value: Any) -> str:
        return self._as_aware_storage_datetime(value).isoformat()

    def _get_recurrence_exdate_keys(self, event: CalendarEvent) -> set[str]:
        return {self._storage_datetime_key(item) for item in (event.recurrence_exdates or [])}

    def _as_aware_storage_datetime(self, value: Any) -> datetime:
        if isinstance(value, datetime):
            return ensure_utc(value)
        if value is None:
            raise AppHTTPException(status_code=422, detail="Invalid recurrence datetime key")
        return self.parse_datetime(str(value))

    def _sort_serialized_events(self, events: list[dict[str, Any]]) -> list[dict[str, Any]]:
        return sort_serialized_events(events, parse_datetime=self.parse_datetime)

    def _extract_timezone_name(self, value: datetime) -> str:
        tzinfo = getattr(value, "tzinfo", None)
        zone_key = getattr(tzinfo, "key", None)
        if zone_key:
            return str(zone_key)
        return str(tzinfo or constants.UTC_TIMEZONE_NAME)

    def _extract_iana_timezone_name(self, value: datetime) -> str | None:
        tzinfo = getattr(value, "tzinfo", None)
        zone_key = getattr(tzinfo, "key", None)
        if zone_key:
            return self._normalize_optional_persisted_timezone(zone_key)
        return None

    def _normalize_required_persisted_timezone(self, timezone: str | None) -> str:
        try:
            normalized = normalize_persisted_timezone(timezone)
        except ValueError as exc:
            raise AppHTTPException(status_code=422, detail="Invalid timezone") from exc
        if normalized is None:
            raise AppHTTPException(status_code=422, detail="Invalid timezone")
        return normalized

    def _normalize_optional_persisted_timezone(self, timezone: str | None) -> str | None:
        try:
            return normalize_persisted_timezone(timezone, allow_empty=True)
        except ValueError as exc:
            raise AppHTTPException(status_code=422, detail="Invalid timezone") from exc

    def _resolve_imported_event_timezone(
        self,
        *,
        raw: dict[str, Any],
        fallback_timezone: str | None,
    ) -> str | None:
        for candidate in (
            raw.get("timezone"),
            raw.get("timeZone"),
            fallback_timezone,
        ):
            try:
                normalized = self._normalize_optional_persisted_timezone(
                    None if candidate is None else str(candidate)
                )
            except AppHTTPException:
                continue
            if normalized:
                return normalized
        start_value = raw.get("start_at") or raw.get("startAt")
        if start_value in (None, ""):
            return None
        try:
            start_dt = self.parse_datetime(str(start_value))
        except AppHTTPException:
            return None
        timezone_name = self._extract_iana_timezone_name(start_dt)
        if timezone_name:
            return timezone_name
        if start_dt.utcoffset() == timedelta(0):
            return constants.UTC_TIMEZONE_NAME
        return None

    def _build_imported_apple_event_id(self, payload: dict[str, Any]) -> str:
        user_key = hashlib.sha1(str(payload["user_id"]).encode("utf-8")).hexdigest()[:12]
        occurrence_key = self._storage_datetime_key(payload["occurrence_start_at"] or payload["start_at"])
        identity = (
            payload["user_id"],
            constants.CALENDAR_SOURCE_APPLE,
            payload["is_occurrence_override"],
            payload["source_device_id"],
            payload["external_calendar_identifier"],
            payload["external_event_identifier"],
            payload["external_calendar_item_identifier"],
            occurrence_key,
        )
        identity_key = hashlib.sha1(repr(identity).encode("utf-8")).hexdigest()[:24]
        return f"apple:{user_key}:{identity_key}:{occurrence_key}"
