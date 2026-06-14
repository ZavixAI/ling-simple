"""用户修改系统时区后的数据纠偏：日程与本地时钟对齐。

思路：在「墙上时间不变」的前提下，把存库的 UTC 时刻按新旧时区重新解释并回写；
仅处理 Ling 自有日程与未来相关数据。
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from config import constants
from core.http.exceptions import AppHTTPException
from models.base import get_local_now
from models.calendar import CalendarEvent, CalendarEventDao
from services.calendar import CalendarService
from services.calendar_domain.recurrence import effective_recurrence
from services.calendar_domain.source import event_source
from services.calendar_recurrence import expand_recurrence_window, recurrence_has_supported_shape
from utils.time import ensure_utc, normalize_persisted_timezone, parse_timezone, to_storage_utc


class TimezoneReconcileService:
    """在用户切换 IANA 时区时，批量平移事件时间。"""

    _FUTURE_LOOKAHEAD_DAYS = 3650

    def __init__(self) -> None:
        self.calendar_service = CalendarService()
        self.event_dao = CalendarEventDao()

    async def reconcile_user_timezone(
        self,
        *,
        user_id: str,
        previous_timezone: str | None,
        next_timezone: str,
    ) -> dict[str, Any]:
        normalized_next_timezone = self._normalize_required_timezone(next_timezone)
        normalized_previous_timezone = self._normalize_fallback_timezone(
            previous_timezone,
            default=normalized_next_timezone,
        )
        if normalized_previous_timezone == normalized_next_timezone:
            return {
                "reconciled": False,
                "event_count": 0,
            }

        now = ensure_utc(get_local_now())
        events = await self.event_dao.list_user_events(user_id)
        overrides_by_parent: dict[str, list[CalendarEvent]] = {}
        masters: list[CalendarEvent] = []
        for event in events:
            if event_source(event) != constants.CALENDAR_SOURCE_LING:
                continue
            if bool(getattr(event, "is_occurrence_override", False)) and event.recurrence_parent_event_id:
                overrides_by_parent.setdefault(event.recurrence_parent_event_id, []).append(event)
                continue
            masters.append(event)

        updated_master_ids: set[str] = set()
        for master in masters:
            if self.calendar_service._is_recurring_event(master):
                overrides = overrides_by_parent.get(master.event_id, [])
                if not self._series_has_future_occurrences(
                    master,
                    overrides,
                    now=now,
                    fallback_timezone=normalized_previous_timezone,
                ):
                    continue
                master_source_timezone = self._source_timezone_for_row(
                    master.timezone,
                    fallback_timezone=normalized_previous_timezone,
                )
                self._shift_event_row(
                    master,
                    source_timezone=master_source_timezone,
                    next_timezone=normalized_next_timezone,
                )
                self._shift_future_exdates(
                    master,
                    now=now,
                    source_timezone=master_source_timezone,
                    next_timezone=normalized_next_timezone,
                )
                await self.event_dao.save(master)
                updated_master_ids.add(master.event_id)

                for override in overrides:
                    if not self._override_is_future(override, now=now):
                        continue
                    override_source_timezone = self._source_timezone_for_row(
                        override.timezone,
                        fallback_timezone=master_source_timezone,
                    )
                    self._shift_event_row(
                        override,
                        source_timezone=override_source_timezone,
                        next_timezone=normalized_next_timezone,
                    )
                    if override.occurrence_start_at is not None and ensure_utc(override.occurrence_start_at) > now:
                        override.occurrence_start_at = self._shift_storage_datetime(
                            override.occurrence_start_at,
                            source_timezone=master_source_timezone,
                            next_timezone=normalized_next_timezone,
                        )
                    await self.event_dao.save(override)
            else:
                if ensure_utc(master.end_at) <= now:
                    continue
                self._shift_event_row(
                    master,
                    source_timezone=self._source_timezone_for_row(
                        master.timezone,
                        fallback_timezone=normalized_previous_timezone,
                    ),
                    next_timezone=normalized_next_timezone,
                )
                await self.event_dao.save(master)
                updated_master_ids.add(master.event_id)

        return {
            "reconciled": True,
            "event_count": len(updated_master_ids),
        }

    def _normalize_required_timezone(self, value: str | None) -> str:
        try:
            normalized = normalize_persisted_timezone(value)
        except ValueError as exc:
            raise AppHTTPException(status_code=422, detail="Invalid timezone") from exc
        if normalized is None:
            raise AppHTTPException(status_code=422, detail="Invalid timezone")
        return normalized

    def _normalize_fallback_timezone(self, value: str | None, *, default: str) -> str:
        normalized = None
        try:
            normalized = normalize_persisted_timezone(value, allow_empty=True)
        except ValueError:
            normalized = None
        if normalized:
            return normalized
        trimmed = str(value or "").strip()
        if trimmed:
            try:
                parse_timezone(trimmed)
                return trimmed
            except Exception:
                pass
        return default

    def _source_timezone_for_row(self, value: str | None, *, fallback_timezone: str) -> str:
        trimmed = str(value or "").strip()
        if trimmed:
            try:
                parse_timezone(trimmed)
                return trimmed
            except Exception:
                pass
        return fallback_timezone

    def _shift_storage_datetime(
        self,
        value: datetime,
        *,
        source_timezone: str,
        next_timezone: str,
    ) -> datetime:
        source_zone = parse_timezone(source_timezone)
        next_zone = parse_timezone(next_timezone)
        local_value = ensure_utc(value).astimezone(source_zone)
        shifted_local = datetime(
            local_value.year,
            local_value.month,
            local_value.day,
            local_value.hour,
            local_value.minute,
            local_value.second,
            local_value.microsecond,
            tzinfo=next_zone,
        )
        return to_storage_utc(shifted_local)

    def _shift_event_row(
        self,
        event: CalendarEvent,
        *,
        source_timezone: str,
        next_timezone: str,
    ) -> None:
        event.start_at = self._shift_storage_datetime(
            event.start_at,
            source_timezone=source_timezone,
            next_timezone=next_timezone,
        )
        event.end_at = self._shift_storage_datetime(
            event.end_at,
            source_timezone=source_timezone,
            next_timezone=next_timezone,
        )
        event.timezone = next_timezone

    def _shift_future_exdates(
        self,
        event: CalendarEvent,
        *,
        now: datetime,
        source_timezone: str,
        next_timezone: str,
    ) -> None:
        shifted_keys: set[str] = set()
        for value in event.recurrence_exdates or []:
            occurrence_start_at = self.calendar_service._as_aware_storage_datetime(value)
            if occurrence_start_at > now:
                occurrence_start_at = ensure_utc(
                    self._shift_storage_datetime(
                        occurrence_start_at,
                        source_timezone=source_timezone,
                        next_timezone=next_timezone,
                    )
                )
            shifted_keys.add(self.calendar_service._storage_datetime_key(occurrence_start_at))
        event.recurrence_exdates = sorted(shifted_keys)

    def _override_is_future(
        self,
        override: CalendarEvent,
        *,
        now: datetime,
    ) -> bool:
        if override.occurrence_start_at is not None and ensure_utc(override.occurrence_start_at) > now:
            return True
        return ensure_utc(override.end_at) > now

    def _series_has_future_occurrences(
        self,
        master: CalendarEvent,
        overrides: list[CalendarEvent],
        *,
        now: datetime,
        fallback_timezone: str,
    ) -> bool:
        if any(self._override_is_future(item, now=now) for item in overrides):
            return True
        recurrence = effective_recurrence(master)
        if not recurrence or not recurrence_has_supported_shape(recurrence):
            return False
        source_timezone = self._source_timezone_for_row(
            master.timezone,
            fallback_timezone=fallback_timezone,
        )
        source_zone = parse_timezone(source_timezone)
        master_start_local = self.calendar_service._to_local(master.start_at, source_zone)
        master_end_local = self.calendar_service._to_local(master.end_at, source_zone)
        window_start_local = ensure_utc(now).astimezone(source_zone)
        window_end_local = window_start_local + timedelta(days=self._FUTURE_LOOKAHEAD_DAYS)
        exdate_keys = self.calendar_service._get_recurrence_exdate_keys(master)
        for occurrence_start_local, _occurrence_end_local in expand_recurrence_window(
            series_start_local=master_start_local,
            series_end_local=master_end_local,
            recurrence=recurrence,
            window_start_local=window_start_local,
            window_end_local=window_end_local,
        ):
            occurrence_key = self.calendar_service._storage_datetime_key(
                to_storage_utc(occurrence_start_local)
            )
            if occurrence_key in exdate_keys:
                continue
            return True
        return False
