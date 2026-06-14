"""Calendar CRUD and views."""

from __future__ import annotations

from datetime import datetime

from config import constants
from core.http.dependencies import require_current_user
from core.http.exceptions import AppHTTPException
from core.http.render import Response
from fastapi import APIRouter, Depends, Query
from models.user import User
from schema.api.calendar import CalendarEventPayload, CalendarEventUpdatePayload
from services.calendar import CalendarService

router = APIRouter(tags=["calendar"])
_CURRENT_USER_DEPENDENCY = Depends(require_current_user)
_DATE_QUERY = Query(...)
_START_AT_QUERY = Query(...)
_END_AT_QUERY = Query(...)
_MONTH_QUERY = Query(...)
_UTC_QUERY = Query(constants.UTC_TIMEZONE_NAME)
_SELECTED_DATE_QUERY = Query(None)
_DELETE_SCOPE_QUERY = Query("series")
_OCCURRENCE_START_TIME_QUERY = Query(None)


@router.get("/calendar/events")
async def get_calendar_events(
    date: str = _DATE_QUERY,
    timezone: str = _UTC_QUERY,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    target_date = datetime.fromisoformat(date).date()
    data = {
        "selected_date": target_date.isoformat(),
        "events": await CalendarService().list_events_for_date(
            user.user_id,
            target_date,
            timezone,
        ),
    }
    return await Response.success(data=data)


@router.get("/calendar/events/window")
async def get_calendar_events_window(
    start_at: str = _START_AT_QUERY,
    end_at: str = _END_AT_QUERY,
    timezone: str = _UTC_QUERY,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    service = CalendarService()
    start_dt = service.parse_datetime(start_at)
    end_dt = service.parse_datetime(end_at)
    if end_dt <= start_dt:
        raise AppHTTPException(
            status_code=422,
            detail="end_at must be after start_at",
        )
    data = {
        "start_at": start_dt.isoformat(),
        "end_at": end_dt.isoformat(),
        "timezone": timezone,
        "events": await service.list_events_between(
            user.user_id,
            start_dt,
            end_dt,
            timezone,
        ),
    }
    return await Response.success(data=data)


@router.get("/calendar/events/{event_id}")
async def get_calendar_event(
    event_id: str,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await CalendarService().get_event(user.user_id, event_id)
    return await Response.success(data=data)


@router.get("/calendar/week")
async def get_calendar_week(
    date: str = _DATE_QUERY,
    timezone: str = _UTC_QUERY,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    target_date = datetime.fromisoformat(date).date()
    service = CalendarService()
    days = []
    for index in range(7):
        day = target_date.fromordinal(target_date.toordinal() + index)
        events = await service.list_events_for_date(user.user_id, day, timezone)
        days.append(
            {
                "date": day.isoformat(),
                "weekday": day.strftime("%a"),
                "day_number": day.day,
                "is_selected": index == 0,
                "has_events": bool(events),
                "events_count": len(events),
            }
        )
    return await Response.success(
        data={
            "selected_date": target_date.isoformat(),
            "days": days,
        }
    )


@router.get("/calendar/month")
async def get_calendar_month(
    month: str = _MONTH_QUERY,
    timezone: str = _UTC_QUERY,
    selected_date: str | None = _SELECTED_DATE_QUERY,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await CalendarService().build_month_view(
        user.user_id,
        month,
        timezone,
        datetime.fromisoformat(selected_date).date() if selected_date else None,
    )
    return await Response.success(data=data)


@router.post("/calendar/events")
async def create_calendar_event(
    payload: CalendarEventPayload,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await CalendarService().create_event(
        user.user_id,
        payload.model_dump(),
    )
    return await Response.success(data=data)


@router.patch("/calendar/events/{event_id}")
async def update_calendar_event(
    event_id: str,
    payload: CalendarEventUpdatePayload,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await CalendarService().update_event(
        user.user_id,
        event_id,
        payload.model_dump(exclude_none=True),
    )
    return await Response.success(data=data)


@router.delete("/calendar/events/{event_id}")
async def delete_calendar_event(
    event_id: str,
    scope: str = _DELETE_SCOPE_QUERY,
    occurrence_start_time: str | None = _OCCURRENCE_START_TIME_QUERY,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await CalendarService().delete_event(
        user.user_id,
        event_id,
        scope=scope,
        occurrence_start_time=occurrence_start_time,
    )
    return await Response.success(data=data)
