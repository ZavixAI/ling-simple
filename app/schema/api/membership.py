"""Membership API payload schemas."""

from __future__ import annotations

from typing import Any, Literal

from config import constants
from pydantic import BaseModel, Field


class MembershipSummaryPayload(BaseModel):
    tier_code: str
    access_state: str
    renewal_type: str | None = None
    provider: str | None = None
    started_at: str | None = None
    paid_through_at: str | None = None
    cancel_at_period_end: bool = False
    daily_chat_limit: int | None = None
    daily_chat_used: int = 0
    daily_chat_remaining: int | None = None
    business_timezone: str
    server_now: str
    entitlements: list[str] = Field(default_factory=list)
    feature_entitlements: list[str] = Field(default_factory=list)
    limits: dict[str, Any] = Field(default_factory=dict)
    points_balance: int = 0
    active_product_code: str | None = None
    display: dict[str, Any] = Field(default_factory=dict)


class MembershipCatalogChannelPayload(BaseModel):
    provider: str
    platform: str
    provider_product_id: str
    currency_code: str
    amount_minor: int
    marketing_label: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class MembershipCatalogProductPayload(BaseModel):
    internal_product_code: str
    tier_code: str
    period_code: str
    renewal_type: str
    duration_months: int
    display_name: str
    display_subtitle: str | None = None
    marketing_label: str | None = None
    daily_chat_limit: int | None = None
    entitlements: list[str] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)
    channels: list[MembershipCatalogChannelPayload] = Field(default_factory=list)


class CheckoutPrepareRequest(BaseModel):
    internal_product_code: str
    provider: Literal[
        constants.PAYMENT_PROVIDER_APPLE,
        constants.PAYMENT_PROVIDER_ALIPAY,
        constants.PAYMENT_PROVIDER_WECHAT,
    ]
    platform: str


class AppleConfirmRequest(BaseModel):
    order_no: str | None = None
    provider_product_id: str | None = None
    transaction_id: str | None = None
    original_transaction_id: str | None = None
    purchase_date: str | None = None
    expiration_date: str | None = None
    app_account_token: str | None = None
    signed_transaction_info: str | None = None
    raw_payload: dict[str, Any] = Field(default_factory=dict)


class AppleNotificationRequest(BaseModel):
    signed_payload: str | None = None
    signedPayload: str | None = None


class ProviderSubscriptionCancelResponse(BaseModel):
    subscription_id: str
    cancel_at_period_end: bool
    provider: str
    status: str


__all__ = [
    "AppleConfirmRequest",
    "AppleNotificationRequest",
    "CheckoutPrepareRequest",
    "MembershipCatalogChannelPayload",
    "MembershipCatalogProductPayload",
    "MembershipSummaryPayload",
    "ProviderSubscriptionCancelResponse",
]
