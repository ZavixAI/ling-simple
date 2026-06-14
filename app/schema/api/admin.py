from __future__ import annotations

from datetime import date
from typing import Literal

from config import constants
from pydantic import BaseModel, Field


class AdminSmsChallengeRequest(BaseModel):
    provider_id: Literal[constants.AUTH_PROVIDER_LOCAL] = constants.AUTH_PROVIDER_LOCAL
    phone: str
    phone_area_code: str | None = None


class AdminTokenRequest(BaseModel):
    provider_id: Literal[constants.AUTH_PROVIDER_LOCAL] = constants.AUTH_PROVIDER_LOCAL
    grant_type: Literal["sms_code"] = "sms_code"
    challenge_id: str | None = None
    phone: str
    phone_area_code: str | None = None
    code: str = Field(min_length=1, max_length=16)


class AdminDateRangeQuery(BaseModel):
    start_date: date
    end_date: date


class AdminMembershipSubscriptionReleaseRequest(BaseModel):
    reason: str = Field(min_length=1, max_length=500)
    expected_provider_subscription_id: str | None = Field(default=None, max_length=255)
    allow_production: bool = False


class AdminMembershipSubscriptionTransferRequest(BaseModel):
    target_user_id: str = Field(min_length=1, max_length=128)
    reason: str = Field(min_length=1, max_length=500)
    expected_provider_subscription_id: str | None = Field(default=None, max_length=255)
    allow_production: bool = False
    move_periods: bool = True


__all__ = [
    "AdminDateRangeQuery",
    "AdminMembershipSubscriptionReleaseRequest",
    "AdminMembershipSubscriptionTransferRequest",
    "AdminSmsChallengeRequest",
    "AdminTokenRequest",
]
