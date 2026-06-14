"""Authentication and profile routes."""

from __future__ import annotations

from config import constants
from core.http.dependencies import require_current_user
from core.http.exceptions import AppHTTPException
from core.http.render import Response
from fastapi import APIRouter, Depends, Request
from models.user import User
from schema.api.auth import (
    BindEmailRequest,
    BindIdentityRequest,
    BindPhoneRequest,
    EmailChallengeRequest,
    PreferencesUpdateRequest,
    PushDeviceContextUpdateRequest,
    PushDeviceUpsertRequest,
    RevokeTokenRequest,
    SmsChallengeRequest,
    TokenRequest,
)
from services.auth.auth import AuthService
from services.badge import BadgeService
from services.push.service import PushNotificationService
from services.timezone_reconcile import TimezoneReconcileService
from utils.time import normalize_persisted_timezone

router = APIRouter(tags=["auth"])
_CURRENT_USER_DEPENDENCY = Depends(require_current_user)


@router.get("/oauth2/providers")
async def list_oauth2_providers():
    return await Response.success(data=AuthService().list_providers())


@router.post("/auth/sms/challenges")
async def create_sms_challenge(payload: SmsChallengeRequest):
    if payload.provider_id != constants.AUTH_PROVIDER_LOCAL:
        raise AppHTTPException(status_code=422, detail="Unsupported provider")
    data = await AuthService().create_sms_challenge(
        payload.phone,
        payload.purpose,
        phone_area_code=payload.phone_area_code,
    )
    return await Response.success(data=data)


@router.post("/auth/email/challenges")
async def create_email_challenge(payload: EmailChallengeRequest):
    if payload.provider_id != constants.AUTH_PROVIDER_LOCAL:
        raise AppHTTPException(status_code=422, detail="Unsupported provider")
    data = await AuthService().create_email_challenge(payload.email)
    return await Response.success(data=data)


@router.post("/oauth2/token")
async def exchange_oauth2_token(payload: TokenRequest):
    service = AuthService()
    push_device = None
    if payload.grant_type != "refresh_token":
        if payload.push_device is None:
            raise AppHTTPException(
                status_code=422,
                detail="push_device is required",
            )
        push_device = payload.push_device.model_dump()

    if payload.grant_type == "sms_code":
        if not payload.phone or not payload.code:
            raise AppHTTPException(
                status_code=422,
                detail="phone and code are required",
            )
        data = await service.exchange_sms_code(
            payload.phone,
            payload.challenge_id,
            payload.code,
            payload.scope,
            phone_area_code=payload.phone_area_code,
            push_device=push_device,
        )
        return await Response.success(data=data)

    if payload.grant_type == "email_code":
        if not payload.email or not payload.code:
            raise AppHTTPException(
                status_code=422,
                detail="email and code are required",
            )
        data = await service.exchange_email_code(
            payload.email,
            payload.code,
            payload.scope,
            push_device=push_device,
        )
        return await Response.success(data=data)

    if payload.grant_type == "aliyun_one_click":
        if not payload.one_click_token:
            raise AppHTTPException(
                status_code=422,
                detail="one_click_token is required",
        )
        data = await service.exchange_aliyun_one_click_token(
            payload.one_click_token,
            payload.scope,
            push_device=push_device,
        )
        return await Response.success(data=data)

    if payload.grant_type == "apple_identity_token":
        if payload.provider_id != constants.AUTH_PROVIDER_APPLE:
            raise AppHTTPException(
                status_code=422,
                detail="provider_id=apple is required",
            )
        if not payload.apple_identity_token:
            raise AppHTTPException(
                status_code=422,
                detail="apple_identity_token is required",
            )
        data = await service.exchange_apple_identity_token(
            payload.apple_identity_token,
            payload.scope,
            authorization_code=payload.apple_authorization_code,
            full_name=payload.apple_full_name,
            push_device=push_device,
        )
        return await Response.success(data=data)

    if payload.grant_type == "wechat_auth_code":
        if payload.provider_id != constants.AUTH_PROVIDER_WECHAT:
            raise AppHTTPException(
                status_code=422,
                detail="provider_id=wechat is required",
            )
        if not payload.wechat_auth_code:
            raise AppHTTPException(
                status_code=422,
                detail="wechat_auth_code is required",
            )
        data = await service.exchange_wechat_auth_code(
            payload.wechat_auth_code,
            payload.scope,
            push_device=push_device,
        )
        return await Response.success(data=data)

    if not payload.refresh_token:
        raise AppHTTPException(
            status_code=422,
            detail="refresh_token is required",
        )
    data = await service.refresh_access_token(payload.refresh_token)
    return await Response.success(data=data)


@router.post("/oauth2/revoke")
async def revoke_oauth2_token(payload: RevokeTokenRequest):
    data = await AuthService().revoke_refresh_token(payload.token)
    return await Response.success(data=data)


@router.get("/me")
async def get_me(user: User = _CURRENT_USER_DEPENDENCY):
    data = await AuthService().get_account_bundle(user)
    return await Response.success(data=data)


@router.get("/me/quick-prompts")
async def list_chat_quick_prompts(
    request: Request,
    locale: str | None = None,
    surface: str | None = None,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    from services.chat_quick_prompts import ChatQuickPromptService

    resolved_locale = locale or request.headers.get("X-Ling-Locale") or request.headers.get(
        "Accept-Language"
    )
    data = await ChatQuickPromptService().list_prompts(
        user_id=user.user_id,
        locale=resolved_locale,
        surface=surface,
    )
    return await Response.success(data=data)


@router.post("/me/quick-prompts/{prompt_id}/use")
async def record_chat_quick_prompt_use(
    request: Request,
    prompt_id: str,
    surface: str | None = None,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    from services.chat_quick_prompts import ChatQuickPromptService

    body_surface = None
    try:
        body = await request.json()
        if isinstance(body, dict):
            body_surface = body.get("surface")
    except Exception:
        body_surface = None
    data = await ChatQuickPromptService().record_use(
        user_id=user.user_id,
        prompt_id=prompt_id,
        surface=surface or body_surface,
    )
    return await Response.success(data=data)


@router.get("/me/badge")
async def get_my_badge(user: User = _CURRENT_USER_DEPENDENCY):
    data = await BadgeService().get_user_badge_count(user.user_id)
    return await Response.success(data=data.to_dict())


@router.post("/me/badge/read-all")
async def mark_my_notifications_read(user: User = _CURRENT_USER_DEPENDENCY):
    data = await BadgeService().mark_all_notifications_read(user.user_id)
    return await Response.success(data=data.to_dict())


@router.post("/notifications/{notification_id}/open")
async def open_notification(
    notification_id: str,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await BadgeService().mark_notification_opened(
        user.user_id,
        notification_id,
    )
    return await Response.success(data=data.to_dict())


@router.patch("/me")
async def update_me(
    payload: PreferencesUpdateRequest,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    from models.user import (
        UserConfigDao,
        normalize_preferred_input_mode_value,
        normalize_quiet_hour_value,
    )

    updates = payload.model_dump(exclude_none=True)
    current_config = await UserConfigDao().get_config(user.user_id)
    previous_timezone = str(current_config.get("timezone") or "").strip() or None
    if "timezone" in updates:
        try:
            updates["timezone"] = normalize_persisted_timezone(updates["timezone"])
        except ValueError as exc:
            raise AppHTTPException(status_code=422, detail="Invalid timezone") from exc

    for key in ("quiet_hours_start", "quiet_hours_end"):
        if key in updates:
            normalized = normalize_quiet_hour_value(updates[key])
            if normalized is None:
                raise AppHTTPException(
                    status_code=422,
                    detail=f"Invalid {key}, expected HH:MM",
                )
            updates[key] = normalized

    if "preferred_input_mode" in updates:
        normalized = normalize_preferred_input_mode_value(
            updates["preferred_input_mode"],
        )
        if normalized is None:
            raise AppHTTPException(
                status_code=422,
                detail="Invalid preferred_input_mode, expected text|voice",
            )
        updates["preferred_input_mode"] = normalized

    await UserConfigDao().update_config(user.user_id, updates)
    timezone_changed = (
        "timezone" in updates and updates["timezone"] != previous_timezone
    )
    if timezone_changed:
        try:
            await TimezoneReconcileService().reconcile_user_timezone(
                user_id=user.user_id,
                previous_timezone=previous_timezone,
                next_timezone=updates["timezone"] or constants.DEFAULT_TIMEZONE,
            )
        except Exception:
            await UserConfigDao().update_config(
                user.user_id,
                {"timezone": previous_timezone},
            )
            raise
    data = await AuthService().get_account_bundle(user)
    return await Response.success(data=data)


@router.post("/me/push-devices")
async def upsert_push_device(
    payload: PushDeviceUpsertRequest,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await PushNotificationService().register_device(
        user_id=user.user_id,
        device_id=payload.device_id,
        platform=payload.platform,
        transport=payload.transport,
        push_token=payload.push_token,
        app_bundle_id=payload.app_bundle_id,
        apns_environment=payload.apns_environment,
        locale=payload.locale,
        timezone=payload.timezone,
        device_model=payload.device_model,
        formatted_address=payload.formatted_address,
        name=payload.name,
        thoroughfare=payload.thoroughfare,
        sub_thoroughfare=payload.sub_thoroughfare,
        sub_locality=payload.sub_locality,
        locality=payload.locality,
        sub_administrative_area=payload.sub_administrative_area,
        city=payload.city,
        administrative_area=payload.administrative_area,
        postal_code=payload.postal_code,
        country=payload.country,
        iso_country_code=payload.iso_country_code,
        areas_of_interest=payload.areas_of_interest,
        latitude=payload.latitude,
        longitude=payload.longitude,
        accuracy_meters=payload.accuracy_meters,
        captured_at=payload.captured_at,
        notifications_enabled=payload.notifications_enabled,
    )
    return await Response.success(data=data)


@router.post("/push-devices/context")
async def update_push_device_context(payload: PushDeviceContextUpdateRequest):
    data = await PushNotificationService().update_device_context_by_credentials(
        device_id=payload.device_id,
        push_token=payload.push_token,
        timezone=payload.timezone,
        device_model=payload.device_model,
        formatted_address=payload.formatted_address,
        name=payload.name,
        thoroughfare=payload.thoroughfare,
        sub_thoroughfare=payload.sub_thoroughfare,
        sub_locality=payload.sub_locality,
        locality=payload.locality,
        sub_administrative_area=payload.sub_administrative_area,
        city=payload.city,
        administrative_area=payload.administrative_area,
        postal_code=payload.postal_code,
        country=payload.country,
        iso_country_code=payload.iso_country_code,
        areas_of_interest=payload.areas_of_interest,
        latitude=payload.latitude,
        longitude=payload.longitude,
        accuracy_meters=payload.accuracy_meters,
        captured_at=payload.captured_at,
    )
    return await Response.success(data=data)


@router.delete("/me/push-devices/{device_id}")
async def delete_push_device(
    device_id: str,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await PushNotificationService().delete_device(
        user_id=user.user_id,
        device_id=device_id,
    )
    return await Response.success(data=data)


@router.post("/me/bind-phone")
async def bind_phone(
    payload: BindPhoneRequest,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await AuthService().bind_phone(
        user,
        payload.phone,
        payload.challenge_id,
        payload.code,
        phone_area_code=payload.phone_area_code,
    )
    return await Response.success(data=data)


@router.post("/me/bind-email")
async def bind_email(
    payload: BindEmailRequest,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await AuthService().bind_email(user, payload.email, payload.code)
    return await Response.success(data=data)


@router.post("/me/bind-identity")
async def bind_identity(
    payload: BindIdentityRequest,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await AuthService().bind_identity(
        user,
        provider_id=payload.provider_id,
        apple_identity_token=payload.apple_identity_token,
        apple_authorization_code=payload.apple_authorization_code,
        apple_full_name=payload.apple_full_name,
        wechat_auth_code=payload.wechat_auth_code,
    )
    return await Response.success(data=data)


@router.delete("/me")
async def delete_my_account(user: User = _CURRENT_USER_DEPENDENCY):
    data = await AuthService().delete_account(user)
    return await Response.success(data=data)
