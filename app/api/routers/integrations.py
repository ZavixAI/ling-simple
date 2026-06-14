"""Device integration routes."""

from __future__ import annotations

from core.http.dependencies import require_current_user
from core.http.render import Response
from fastapi import APIRouter, Depends, Query, Request
from models.user import User
from schema.api.integrations import (
    AppleCalendarContextPayload,
    AppleEventLinkPayload,
    CalendarOAuthCompletePayload,
)
from services.calendar import CalendarService
from services.calendar_integrations import (
    CalendarConnectionService,
    CalendarOAuthService,
    FeishuWebhookService,
)

router = APIRouter(tags=["integrations"])
_CURRENT_USER_DEPENDENCY = Depends(require_current_user)
_DEVICE_ID_QUERY = Query(...)


@router.post("/integrations/apple/event-links")
async def upsert_apple_event_link(
    payload: AppleEventLinkPayload,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await CalendarService().upsert_event_link(
        user.user_id,
        payload.model_dump(),
    )
    return await Response.success(data=data)


@router.post("/integrations/apple/calendar-context")
async def save_apple_calendar_context(
    payload: AppleCalendarContextPayload,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await CalendarService().save_calendar_context(
        user.user_id,
        payload.model_dump(),
    )
    return await Response.success(data=data)


@router.get("/integrations/apple/managed-links")
async def list_managed_apple_links(
    device_id: str = _DEVICE_ID_QUERY,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await CalendarService().list_managed_apple_links(
        user.user_id,
        device_id,
    )
    return await Response.success(data=data)


@router.delete("/integrations/apple/managed-links")
async def delete_managed_apple_links(
    device_id: str = _DEVICE_ID_QUERY,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await CalendarService().delete_managed_apple_links(
        user.user_id,
        device_id,
    )
    return await Response.success(data=data)


@router.get("/integrations/calendar/connections")
async def list_calendar_connections(
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = {
        "items": await CalendarConnectionService().list_connections(user.user_id),
    }
    return await Response.success(data=data)


@router.post("/integrations/calendar/oauth/{provider}/start")
async def start_calendar_oauth(
    provider: str,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await CalendarOAuthService().start_oauth(provider, user.user_id)
    return await Response.success(data=data)


@router.post("/integrations/calendar/oauth/{provider}/complete")
async def complete_calendar_oauth(
    provider: str,
    payload: CalendarOAuthCompletePayload,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await CalendarOAuthService().complete_oauth(
        provider,
        user.user_id,
        payload.callback_url,
    )
    return await Response.success(data=data)


@router.post("/integrations/calendar/connections/{provider}/sync")
async def refresh_calendar_connection(
    provider: str,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await CalendarConnectionService().refresh_connection(
        user.user_id,
        provider,
    )
    return await Response.success(data=data)


@router.delete("/integrations/calendar/connections/{provider}")
async def disconnect_calendar_connection(
    provider: str,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await CalendarConnectionService().disconnect(user.user_id, provider)
    return await Response.success(data=data)


@router.post("/integrations/calendar/webhooks/feishu")
async def handle_feishu_calendar_webhook(request: Request):
    payload = await request.json()
    data = await FeishuWebhookService().handle_webhook(payload if isinstance(payload, dict) else {})
    return data
