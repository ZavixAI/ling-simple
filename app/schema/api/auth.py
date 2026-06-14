"""Authentication API payload schemas."""

from __future__ import annotations

from typing import Any, Literal

from config import constants
from pydantic import BaseModel, Field, model_validator


class SmsChallengeRequest(BaseModel):
    provider_id: Literal[constants.AUTH_PROVIDER_LOCAL] = constants.AUTH_PROVIDER_LOCAL
    phone: str
    phone_area_code: str | None = None
    purpose: str = "login"


class EmailChallengeRequest(BaseModel):
    provider_id: Literal[constants.AUTH_PROVIDER_LOCAL] = constants.AUTH_PROVIDER_LOCAL
    email: str
    purpose: str = "login"


class PushDeviceUpsertRequest(BaseModel):
    device_id: str
    platform: Literal[
        constants.PLATFORM_IOS,
        constants.PLATFORM_OHOS,
    ] = constants.PLATFORM_IOS
    transport: Literal[
        constants.PUSH_TRANSPORT_APNS,
        constants.PUSH_TRANSPORT_HARMONY,
    ] = constants.PUSH_TRANSPORT_APNS
    push_token: str
    app_bundle_id: str | None = None
    apns_environment: str | None = None
    locale: str | None = None
    timezone: str | None = None
    device_model: str | None = None
    formatted_address: str | None = None
    name: str | None = None
    thoroughfare: str | None = None
    sub_thoroughfare: str | None = None
    sub_locality: str | None = None
    locality: str | None = None
    sub_administrative_area: str | None = None
    city: str | None = None
    administrative_area: str | None = None
    postal_code: str | None = None
    country: str | None = None
    iso_country_code: str | None = None
    areas_of_interest: list[str] | None = None
    latitude: float | None = None
    longitude: float | None = None
    accuracy_meters: float | None = None
    captured_at: str | None = None
    notifications_enabled: bool = True

    @model_validator(mode="after")
    def validate_platform_transport(self) -> "PushDeviceUpsertRequest":
        allowed = {
            constants.PLATFORM_IOS: constants.PUSH_TRANSPORT_APNS,
            constants.PLATFORM_OHOS: constants.PUSH_TRANSPORT_HARMONY,
        }
        if allowed[self.platform] != self.transport:
            raise ValueError("Invalid platform and transport combination")
        return self


class TokenRequest(BaseModel):
    provider_id: Literal[
        constants.AUTH_PROVIDER_LOCAL,
        constants.AUTH_PROVIDER_APPLE,
        constants.AUTH_PROVIDER_WECHAT,
    ] = constants.AUTH_PROVIDER_LOCAL
    grant_type: Literal[
        "sms_code",
        "email_code",
        "aliyun_one_click",
        "apple_identity_token",
        "wechat_auth_code",
        "refresh_token",
    ]
    challenge_id: str | None = None
    phone: str | None = None
    phone_area_code: str | None = None
    email: str | None = None
    code: str | None = None
    one_click_token: str | None = None
    apple_identity_token: str | None = None
    apple_authorization_code: str | None = None
    apple_full_name: dict[str, Any] | None = None
    wechat_auth_code: str | None = None
    refresh_token: str | None = None
    push_device: PushDeviceUpsertRequest | None = None
    scope: str = Field(default="openid profile calendar agent offline_access")


class RevokeTokenRequest(BaseModel):
    token: str
    token_type_hint: str = "refresh_token"


class PreferencesUpdateRequest(BaseModel):
    timezone: str | None = None
    locale: str | None = None
    theme_mode: str | None = None
    voice_input_enabled: bool | None = None
    preferred_input_mode: str | None = None
    default_calendar_provider: str | None = None
    calendar_sync: dict[str, Any] | None = None
    calendar_notifications: dict[str, Any] | None = None
    device_permissions: dict[str, Any] | None = None
    quiet_hours_start: str | None = None
    quiet_hours_end: str | None = None


class BindPhoneRequest(BaseModel):
    challenge_id: str
    phone: str
    phone_area_code: str | None = None
    code: str


class BindEmailRequest(BaseModel):
    email: str
    code: str


class BindIdentityRequest(BaseModel):
    provider_id: Literal[constants.AUTH_PROVIDER_APPLE, constants.AUTH_PROVIDER_WECHAT]
    apple_identity_token: str | None = None
    apple_authorization_code: str | None = None
    apple_full_name: dict[str, Any] | None = None
    wechat_auth_code: str | None = None


class PushDeviceContextUpdateRequest(BaseModel):
    device_id: str
    push_token: str
    timezone: str | None = None
    device_model: str | None = None
    formatted_address: str | None = None
    name: str | None = None
    thoroughfare: str | None = None
    sub_thoroughfare: str | None = None
    sub_locality: str | None = None
    locality: str | None = None
    sub_administrative_area: str | None = None
    city: str | None = None
    administrative_area: str | None = None
    postal_code: str | None = None
    country: str | None = None
    iso_country_code: str | None = None
    areas_of_interest: list[str] | None = None
    latitude: float | None = None
    longitude: float | None = None
    accuracy_meters: float | None = None
    captured_at: str | None = None


__all__ = [
    "BindEmailRequest",
    "BindIdentityRequest",
    "BindPhoneRequest",
    "EmailChallengeRequest",
    "PreferencesUpdateRequest",
    "PushDeviceContextUpdateRequest",
    "PushDeviceUpsertRequest",
    "RevokeTokenRequest",
    "SmsChallengeRequest",
    "TokenRequest",
]
