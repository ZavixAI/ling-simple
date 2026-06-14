from __future__ import annotations

from typing import Any

from config import constants
from core.http.dependencies import require_current_user
from core.http.render import Response
from core.infra.db import transaction_scope
from fastapi import APIRouter, Body, Depends, Request
from models.user import User
from modules.membership.service import MembershipService
from schema.api.membership import (
    AppleConfirmRequest,
    AppleNotificationRequest,
    CheckoutPrepareRequest,
)

router = APIRouter(prefix="/membership", tags=["membership"])
_CURRENT_USER_DEPENDENCY = Depends(require_current_user)
_OPTIONAL_BODY = Body(None)


@router.get("/summary")
async def get_membership_summary(
    request: Request,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    async with transaction_scope() as session:
        data = await MembershipService().build_summary(
            user.user_id,
            locale=_request_locale(request),
            session=session,
        )
    return await Response.success(data=data.model_dump())


@router.get("/catalog")
async def get_membership_catalog(
    request: Request,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    _ = user
    items = await MembershipService().get_catalog(locale=_request_locale(request))
    return await Response.success(
        data={"items": [item.model_dump() for item in items]}
    )


@router.post("/checkout/prepare")
async def prepare_membership_checkout(
    payload: CheckoutPrepareRequest,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await MembershipService().prepare_checkout(
        user.user_id,
        internal_product_code=payload.internal_product_code,
        provider=payload.provider,
        platform=payload.platform,
    )
    return await Response.success(data=data)


@router.post("/apple/confirm")
async def confirm_apple_membership_purchase(
    request: Request,
    payload: AppleConfirmRequest,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await MembershipService().confirm_apple_purchase(
        user.user_id,
        payload.model_dump(exclude_none=True),
        locale=_request_locale(request),
    )
    return await Response.success(data=data.model_dump())


@router.post("/providers/apple/notifications")
async def receive_apple_membership_notification(
    payload: AppleNotificationRequest,
):
    data = await MembershipService().apply_apple_server_notification(
        payload.model_dump(),
    )
    return await Response.success(data=data)


@router.post("/providers/apple/reconcile/{transaction_id}")
async def reconcile_apple_membership_transaction(
    transaction_id: str,
    environment: str | None = None,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    _ = user
    data = await MembershipService().reconcile_apple_transaction(
        transaction_id,
        environment=environment,
    )
    return await Response.success(data=data.model_dump())


@router.post("/providers/alipay/notify")
async def receive_alipay_membership_notification(
    payload: dict[str, Any] | None = _OPTIONAL_BODY,
):
    data = await MembershipService().apply_provider_notification(
        constants.PAYMENT_PROVIDER_ALIPAY,
        payload or {},
    )
    return await Response.success(data=data)


@router.post("/providers/wechat/notify")
async def receive_wechat_membership_notification(
    payload: dict[str, Any] | None = _OPTIONAL_BODY,
):
    data = await MembershipService().apply_provider_notification(
        constants.PAYMENT_PROVIDER_WECHAT,
        payload or {},
    )
    return await Response.success(data=data)


@router.post("/subscriptions/{subscription_id}/cancel")
async def cancel_membership_subscription(
    subscription_id: str,
    provider: str | None = None,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await MembershipService().cancel_provider_subscription(
        provider=provider,
        user_id=user.user_id,
        subscription_id=subscription_id,
    )
    return await Response.success(data=data)


def _request_locale(request: Request) -> str | None:
    return (
        request.headers.get("X-Ling-Locale")
        or request.headers.get("Accept-Language")
        or None
    )
