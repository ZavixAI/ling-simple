from __future__ import annotations

from datetime import date

from core.http.dependencies import require_current_admin
from core.http.render import Response
from fastapi import APIRouter, Depends, Query
from schema.api.admin import (
    AdminMembershipSubscriptionReleaseRequest,
    AdminMembershipSubscriptionTransferRequest,
    AdminSmsChallengeRequest,
    AdminTokenRequest,
)
from services.admin_auth import AdminAuthService
from services.admin_membership import AdminMembershipService

router = APIRouter(prefix="/admin", tags=["admin"])
_CURRENT_ADMIN_DEPENDENCY = Depends(require_current_admin)


@router.post("/auth/sms/challenges")
async def create_admin_sms_challenge(payload: AdminSmsChallengeRequest):
    data = await AdminAuthService().create_sms_challenge(
        phone=payload.phone,
        phone_area_code=payload.phone_area_code,
    )
    return await Response.success(data=data)


@router.post("/auth/token")
async def exchange_admin_token(payload: AdminTokenRequest):
    data = await AdminAuthService().exchange_sms_code(
        phone=payload.phone,
        phone_area_code=payload.phone_area_code,
        challenge_id=payload.challenge_id,
        code=payload.code,
    )
    return await Response.success(data=data)


@router.get("/token-usage")
async def list_admin_token_usage(
    start_date: date,
    end_date: date,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    query: str | None = None,
    _: dict = _CURRENT_ADMIN_DEPENDENCY,
):
    data = await AnalyticsAdminQueryService().token_usage(
        start_date=start_date,
        end_date=end_date,
        page=page,
        page_size=page_size,
        query=query,
    )
    return await Response.success(data=data)


@router.get("/users")
async def list_admin_users(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    query: str | None = None,
    _: dict = _CURRENT_ADMIN_DEPENDENCY,
):
    data = await AnalyticsAdminQueryService().users(
        page=page,
        page_size=page_size,
        query=query,
    )
    return await Response.success(data=data)


@router.get("/user-records/conversations")
async def list_admin_user_record_conversations(
    start_date: date,
    end_date: date,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    query: str | None = None,
    _: dict = _CURRENT_ADMIN_DEPENDENCY,
):
    data = await AnalyticsAdminQueryService().user_record_conversations(
        start_date=start_date,
        end_date=end_date,
        page=page,
        page_size=page_size,
        query=query,
    )
    return await Response.success(data=data)


@router.get("/users/{user_id}/daily-metrics")
async def get_admin_user_daily_metrics(
    user_id: str,
    start_date: date,
    end_date: date,
    _: dict = _CURRENT_ADMIN_DEPENDENCY,
):
    data = await AnalyticsAdminQueryService().user_daily_metrics(
        user_id=user_id,
        start_date=start_date,
        end_date=end_date,
    )
    return await Response.success(data=data)


@router.get("/membership/orders")
async def list_admin_membership_orders(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    query: str | None = None,
    provider: str | None = None,
    status: str | None = None,
    user_id: str | None = None,
    _: dict = _CURRENT_ADMIN_DEPENDENCY,
):
    data = await AdminMembershipService().list_orders(
        page=page,
        page_size=page_size,
        query=query,
        provider=provider,
        status=status,
        user_id=user_id,
    )
    return await Response.success(data=data)


@router.get("/membership/subscriptions")
async def list_admin_membership_subscriptions(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    query: str | None = None,
    provider: str | None = None,
    status: str | None = None,
    user_id: str | None = None,
    _: dict = _CURRENT_ADMIN_DEPENDENCY,
):
    data = await AdminMembershipService().list_subscriptions(
        page=page,
        page_size=page_size,
        query=query,
        provider=provider,
        status=status,
        user_id=user_id,
    )
    return await Response.success(data=data)


@router.get("/membership/subscriptions/{subscription_id}")
async def get_admin_membership_subscription(
    subscription_id: str,
    _: dict = _CURRENT_ADMIN_DEPENDENCY,
):
    data = await AdminMembershipService().get_subscription_detail(subscription_id)
    return await Response.success(data=data)


@router.post("/membership/subscriptions/{subscription_id}/release-binding")
async def release_admin_membership_subscription_binding(
    subscription_id: str,
    payload: AdminMembershipSubscriptionReleaseRequest,
    admin: dict = _CURRENT_ADMIN_DEPENDENCY,
):
    data = await AdminMembershipService().release_apple_subscription_binding(
        subscription_id=subscription_id,
        admin=admin,
        reason=payload.reason,
        expected_provider_subscription_id=payload.expected_provider_subscription_id,
        allow_production=payload.allow_production,
    )
    return await Response.success(data=data)


@router.post("/membership/subscriptions/{subscription_id}/transfer-binding")
async def transfer_admin_membership_subscription_binding(
    subscription_id: str,
    payload: AdminMembershipSubscriptionTransferRequest,
    admin: dict = _CURRENT_ADMIN_DEPENDENCY,
):
    data = await AdminMembershipService().transfer_apple_subscription_binding(
        subscription_id=subscription_id,
        target_user_id=payload.target_user_id,
        admin=admin,
        reason=payload.reason,
        expected_provider_subscription_id=payload.expected_provider_subscription_id,
        allow_production=payload.allow_production,
        move_periods=payload.move_periods,
    )
    return await Response.success(data=data)
