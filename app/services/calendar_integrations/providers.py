"""各日历云厂商 HTTP 客户端：授权 URL、token 交换、事件列表/增量游标与领域映射。

build_provider_client 按 PROVIDER_* 常量构造具体实现。
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Any
from urllib.parse import urlencode

import httpx
from config import constants
from config.settings import AppConfig, get_app_config
from core.http.exceptions import AppHTTPException

PROVIDER_FEISHU = constants.CALENDAR_SOURCE_FEISHU
PROVIDER_DINGTALK = constants.CALENDAR_SOURCE_DINGTALK
PROVIDER_APPLE_LOCAL = constants.CALENDAR_SOURCE_APPLE_LOCAL


def _utc_now() -> datetime:
    return datetime.now(UTC)


def _normalize_optional_string(value: Any) -> str | None:
    normalized = str(value or "").strip()
    return normalized or None


def _parse_expire_at(
    *,
    expires_in: Any = None,
    expire_at: Any = None,
) -> datetime | None:
    if expire_at not in (None, ""):
        try:
            if isinstance(expire_at, (int, float)):
                return datetime.fromtimestamp(float(expire_at), tz=UTC)
            normalized = str(expire_at).replace("Z", "+00:00")
            parsed = datetime.fromisoformat(normalized)
            return parsed if parsed.tzinfo else parsed.replace(tzinfo=UTC)
        except ValueError:
            return None
    if expires_in in (None, ""):
        return None
    try:
        seconds = int(float(expires_in))
    except (TypeError, ValueError):
        return None
    return _utc_now() + timedelta(seconds=max(0, seconds))


def _parse_external_datetime(value: Any) -> str | None:
    normalized = _normalize_optional_string(value)
    if normalized is None:
        return None
    if normalized.endswith("Z"):
        return normalized[:-1] + "+00:00"
    return normalized


def _hash_payload(payload: Any) -> str:
    return hashlib.sha256(str(payload).encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class CalendarOAuthStart:
    authorize_url: str
    callback_scheme: str


@dataclass(frozen=True)
class CalendarOAuthExchangeResult:
    provider_id: str
    external_user_id: str
    external_user_name: str | None
    external_email: str | None
    external_tenant_id: str | None
    external_tenant_name: str | None
    access_token: str
    refresh_token: str | None
    access_token_expires_at: datetime | None
    refresh_token_expires_at: datetime | None
    primary_calendar_id: str | None
    metadata: dict[str, Any]


@dataclass(frozen=True)
class CalendarSyncBatch:
    events: list[dict[str, Any]]
    next_page_token: str | None = None
    next_sync_token: str | None = None


class BaseCalendarProviderClient:
    provider_id: str
    provider_name: str

    def __init__(
        self,
        cfg: AppConfig | None = None,
        *,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self.cfg = cfg or get_app_config()
        self._http_client = http_client

    def is_configured(self) -> bool:
        raise NotImplementedError

    def build_oauth_start(self, *, state: str) -> CalendarOAuthStart:
        raise NotImplementedError

    async def exchange_code(
        self,
        *,
        code: str,
        redirect_uri: str,
    ) -> CalendarOAuthExchangeResult:
        raise NotImplementedError

    async def refresh_access_token(
        self,
        *,
        refresh_token: str,
    ) -> dict[str, Any]:
        raise NotImplementedError

    async def list_events(
        self,
        *,
        access_token: str,
        external_user_id: str | None,
        calendar_id: str,
        page_token: str | None = None,
        sync_token: str | None = None,
        full_sync: bool = False,
    ) -> CalendarSyncBatch:
        raise NotImplementedError

    async def delete_event(
        self,
        *,
        access_token: str,
        external_user_id: str | None,
        calendar_id: str,
        event_id: str,
    ) -> None:
        raise NotImplementedError

    async def subscribe_primary_calendar(
        self,
        *,
        access_token: str,
        calendar_id: str,
    ) -> dict[str, Any] | None:
        return None

    async def _request(
        self,
        method: str,
        url: str,
        *,
        headers: dict[str, str] | None = None,
        params: dict[str, Any] | None = None,
        json_body: dict[str, Any] | None = None,
        data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        try:
            if self._http_client is not None:
                response = await self._http_client.request(
                    method,
                    url,
                    headers=headers,
                    params=params,
                    json=json_body,
                    data=data,
                )
            else:
                async with httpx.AsyncClient(timeout=15.0) as client:
                    response = await client.request(
                        method,
                        url,
                        headers=headers,
                        params=params,
                        json=json_body,
                        data=data,
                    )
            response.raise_for_status()
        except httpx.HTTPStatusError as exc:
            raise AppHTTPException(
                status_code=502,
                detail=f"{self.provider_name} upstream request failed",
                error_detail={
                    "provider": self.provider_id,
                    "url": url,
                    "status_code": exc.response.status_code,
                    "body": exc.response.text,
                },
            ) from exc
        except httpx.RequestError as exc:
            raise AppHTTPException(
                status_code=502,
                detail=f"{self.provider_name} upstream request failed",
                error_detail={
                    "provider": self.provider_id,
                    "url": url,
                    "reason": str(exc),
                },
            ) from exc

        try:
            payload = response.json()
        except ValueError as exc:
            raise AppHTTPException(
                status_code=502,
                detail=f"{self.provider_name} returned invalid JSON",
            ) from exc
        if not isinstance(payload, dict):
            raise AppHTTPException(
                status_code=502,
                detail=f"{self.provider_name} returned unexpected payload",
            )
        return payload


class FeishuCalendarProviderClient(BaseCalendarProviderClient):
    provider_id = PROVIDER_FEISHU
    provider_name = "Feishu"

    def is_configured(self) -> bool:
        return bool((self.cfg.feishu_app_id or "").strip()) and bool(
            (self.cfg.feishu_app_secret or "").strip()
        ) and bool((self.cfg.feishu_ios_redirect_uri or "").strip())

    def build_oauth_start(self, *, state: str) -> CalendarOAuthStart:
        redirect_uri = _normalize_optional_string(self.cfg.feishu_ios_redirect_uri)
        if not redirect_uri or not self.is_configured():
            raise AppHTTPException(status_code=503, detail="Feishu calendar is not configured")
        query = urlencode(
            {
                "app_id": self.cfg.feishu_app_id,
                "redirect_uri": redirect_uri,
                "response_type": "code",
                "state": state,
                "scope": "calendar:calendar calendar:event",
            }
        )
        return CalendarOAuthStart(
            authorize_url=f"{self.cfg.feishu_authorize_url}?{query}",
            callback_scheme=redirect_uri.split(":", 1)[0],
        )

    async def exchange_code(
        self,
        *,
        code: str,
        redirect_uri: str,
    ) -> CalendarOAuthExchangeResult:
        token_payload = await self._request(
            "POST",
            self.cfg.feishu_token_url,
            headers={"Content-Type": "application/json"},
            json_body={
                "grant_type": "authorization_code",
                "code": code,
                "client_id": self.cfg.feishu_app_id,
                "client_secret": self.cfg.feishu_app_secret,
                "redirect_uri": redirect_uri,
            },
        )
        data = token_payload.get("data") if isinstance(token_payload.get("data"), dict) else token_payload
        access_token = _normalize_optional_string(data.get("access_token"))
        if not access_token:
            raise AppHTTPException(status_code=401, detail="Feishu authorization failed")
        primary_calendar = await self._request(
            "GET",
            f"{self.cfg.feishu_api_base_url}/calendar/v4/calendars/primary",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        primary_data = primary_calendar.get("data") if isinstance(primary_calendar.get("data"), dict) else {}
        calendar_id = _normalize_optional_string(
            primary_data.get("calendar", {}).get("calendar_id")
            if isinstance(primary_data.get("calendar"), dict)
            else primary_data.get("calendar_id")
        )
        user_id = _normalize_optional_string(data.get("open_id") or data.get("sub"))
        if not user_id:
            user_id = _normalize_optional_string(primary_data.get("user_id"))
        return CalendarOAuthExchangeResult(
            provider_id=self.provider_id,
            external_user_id=user_id or "feishu_user",
            external_user_name=_normalize_optional_string(data.get("name")),
            external_email=_normalize_optional_string(data.get("email")),
            external_tenant_id=_normalize_optional_string(data.get("tenant_key")),
            external_tenant_name=_normalize_optional_string(data.get("tenant_name")),
            access_token=access_token,
            refresh_token=_normalize_optional_string(data.get("refresh_token")),
            access_token_expires_at=_parse_expire_at(expires_in=data.get("expires_in")),
            refresh_token_expires_at=_parse_expire_at(expires_in=data.get("refresh_expires_in")),
            primary_calendar_id=calendar_id,
            metadata={
                "token_payload": data,
                "primary_calendar_payload": primary_data,
            },
        )

    async def refresh_access_token(self, *, refresh_token: str) -> dict[str, Any]:
        payload = await self._request(
            "POST",
            self.cfg.feishu_token_url,
            headers={"Content-Type": "application/json"},
            json_body={
                "grant_type": "refresh_token",
                "refresh_token": refresh_token,
                "client_id": self.cfg.feishu_app_id,
                "client_secret": self.cfg.feishu_app_secret,
            },
        )
        data = payload.get("data") if isinstance(payload.get("data"), dict) else payload
        return {
            "access_token": _normalize_optional_string(data.get("access_token")),
            "refresh_token": _normalize_optional_string(data.get("refresh_token")) or refresh_token,
            "access_token_expires_at": _parse_expire_at(expires_in=data.get("expires_in")),
            "refresh_token_expires_at": _parse_expire_at(expires_in=data.get("refresh_expires_in")),
            "metadata": {"refresh_payload": data},
        }

    async def list_events(
        self,
        *,
        access_token: str,
        external_user_id: str | None,
        calendar_id: str,
        page_token: str | None = None,
        sync_token: str | None = None,
        full_sync: bool = False,
    ) -> CalendarSyncBatch:
        _ = external_user_id, full_sync
        params: dict[str, Any] = {"page_size": 100}
        if page_token:
            params["page_token"] = page_token
        if sync_token:
            params["sync_token"] = sync_token
        payload = await self._request(
            "GET",
            f"{self.cfg.feishu_api_base_url}/calendar/v4/calendars/{calendar_id}/events",
            headers={"Authorization": f"Bearer {access_token}"},
            params=params,
        )
        data = payload.get("data") if isinstance(payload.get("data"), dict) else {}
        items = data.get("items") if isinstance(data.get("items"), list) else []
        events = [self._normalize_event(calendar_id=calendar_id, item=item) for item in items if isinstance(item, dict)]
        return CalendarSyncBatch(
            events=events,
            next_page_token=_normalize_optional_string(data.get("page_token")),
            next_sync_token=_normalize_optional_string(data.get("sync_token")),
        )

    async def subscribe_primary_calendar(
        self,
        *,
        access_token: str,
        calendar_id: str,
    ) -> dict[str, Any] | None:
        payload = await self._request(
            "POST",
            f"{self.cfg.feishu_api_base_url}/calendar/v4/calendars/{calendar_id}/events/subscription",
            headers={"Authorization": f"Bearer {access_token}"},
            json_body={},
        )
        return payload.get("data") if isinstance(payload.get("data"), dict) else payload

    async def delete_event(
        self,
        *,
        access_token: str,
        external_user_id: str | None,
        calendar_id: str,
        event_id: str,
    ) -> None:
        _ = external_user_id
        await self._request(
            "DELETE",
            f"{self.cfg.feishu_api_base_url}/calendar/v4/calendars/{calendar_id}/events/{event_id}",
            headers={"Authorization": f"Bearer {access_token}"},
        )

    def _normalize_event(
        self,
        *,
        calendar_id: str,
        item: dict[str, Any],
    ) -> dict[str, Any]:
        start_time = item.get("start_time") if isinstance(item.get("start_time"), dict) else {}
        end_time = item.get("end_time") if isinstance(item.get("end_time"), dict) else {}
        organizer = item.get("organizer") if isinstance(item.get("organizer"), dict) else {}
        event_id = _normalize_optional_string(item.get("event_id") or item.get("id")) or ""
        return {
            "calendar_id": calendar_id,
            "event_id": event_id,
            "title": _normalize_optional_string(item.get("summary")) or "Untitled",
            "subtitle": _normalize_optional_string(item.get("description")),
            "start_at": _parse_external_datetime(start_time.get("date_time") or item.get("start_time")),
            "end_at": _parse_external_datetime(end_time.get("date_time") or item.get("end_time")),
            "timezone": _normalize_optional_string(start_time.get("timezone"))
            or constants.UTC_TIMEZONE_NAME,
            "location": _normalize_optional_string(item.get("location", {}).get("name") if isinstance(item.get("location"), dict) else item.get("location")),
            "status": _normalize_optional_string(item.get("status"))
            or constants.CALENDAR_STATUS_SCHEDULED,
            "meeting_url": _normalize_optional_string(item.get("meeting_url")),
            "attendees": item.get("attendees") if isinstance(item.get("attendees"), list) else [],
            "updated_at": _parse_external_datetime(item.get("update_time") or item.get("updated_time")),
            "organizer": organizer,
            "metadata": {
                "etag": item.get("etag"),
                "raw_payload_digest": _hash_payload(item),
            },
        }


class DingTalkCalendarProviderClient(BaseCalendarProviderClient):
    provider_id = PROVIDER_DINGTALK
    provider_name = "DingTalk"

    def is_configured(self) -> bool:
        return bool((self.cfg.dingtalk_client_id or "").strip()) and bool(
            (self.cfg.dingtalk_client_secret or "").strip()
        ) and bool((self.cfg.dingtalk_ios_redirect_uri or "").strip())

    def build_oauth_start(self, *, state: str) -> CalendarOAuthStart:
        redirect_uri = _normalize_optional_string(self.cfg.dingtalk_ios_redirect_uri)
        if not redirect_uri or not self.is_configured():
            raise AppHTTPException(status_code=503, detail="DingTalk calendar is not configured")
        query = urlencode(
            {
                "client_id": self.cfg.dingtalk_client_id,
                "redirect_uri": redirect_uri,
                "response_type": "code",
                "scope": "openid",
                "state": state,
                "prompt": "consent",
            }
        )
        return CalendarOAuthStart(
            authorize_url=f"{self.cfg.dingtalk_authorize_url}?{query}",
            callback_scheme=redirect_uri.split(":", 1)[0],
        )

    async def exchange_code(
        self,
        *,
        code: str,
        redirect_uri: str,
    ) -> CalendarOAuthExchangeResult:
        token_payload = await self._request(
            "POST",
            self.cfg.dingtalk_token_url,
            headers={"Content-Type": "application/json"},
            json_body={
                "clientId": self.cfg.dingtalk_client_id,
                "clientSecret": self.cfg.dingtalk_client_secret,
                "code": code,
                "grantType": "authorization_code",
                "redirectUri": redirect_uri,
            },
        )
        access_token = _normalize_optional_string(token_payload.get("accessToken"))
        if not access_token:
            raise AppHTTPException(status_code=401, detail="DingTalk authorization failed")
        user_id = _normalize_optional_string(token_payload.get("unionId")) or _normalize_optional_string(
            token_payload.get("userId")
        )
        calendar_payload = await self._request(
            "GET",
            f"{self.cfg.dingtalk_api_base_url}/v1.0/calendar/users/me/calendars/primary",
            headers={"x-acs-dingtalk-access-token": access_token},
        )
        calendar_id = _normalize_optional_string(calendar_payload.get("id") or calendar_payload.get("calendarId"))
        return CalendarOAuthExchangeResult(
            provider_id=self.provider_id,
            external_user_id=user_id or "dingtalk_user",
            external_user_name=_normalize_optional_string(token_payload.get("nick")) or _normalize_optional_string(token_payload.get("name")),
            external_email=_normalize_optional_string(token_payload.get("email")),
            external_tenant_id=_normalize_optional_string(token_payload.get("corpId")),
            external_tenant_name=_normalize_optional_string(token_payload.get("corpName")),
            access_token=access_token,
            refresh_token=_normalize_optional_string(token_payload.get("refreshToken")),
            access_token_expires_at=_parse_expire_at(expires_in=token_payload.get("expireIn")),
            refresh_token_expires_at=_parse_expire_at(expires_in=token_payload.get("refreshTokenExpireIn")),
            primary_calendar_id=calendar_id,
            metadata={
                "token_payload": token_payload,
                "primary_calendar_payload": calendar_payload,
            },
        )

    async def refresh_access_token(self, *, refresh_token: str) -> dict[str, Any]:
        payload = await self._request(
            "POST",
            self.cfg.dingtalk_token_url,
            headers={"Content-Type": "application/json"},
            json_body={
                "clientId": self.cfg.dingtalk_client_id,
                "clientSecret": self.cfg.dingtalk_client_secret,
                "refreshToken": refresh_token,
                "grantType": "refresh_token",
            },
        )
        return {
            "access_token": _normalize_optional_string(payload.get("accessToken")),
            "refresh_token": _normalize_optional_string(payload.get("refreshToken")) or refresh_token,
            "access_token_expires_at": _parse_expire_at(expires_in=payload.get("expireIn")),
            "refresh_token_expires_at": _parse_expire_at(expires_in=payload.get("refreshTokenExpireIn")),
            "metadata": {"refresh_payload": payload},
        }

    async def list_events(
        self,
        *,
        access_token: str,
        external_user_id: str | None,
        calendar_id: str,
        page_token: str | None = None,
        sync_token: str | None = None,
        full_sync: bool = False,
    ) -> CalendarSyncBatch:
        user_id = external_user_id or "me"
        params: dict[str, Any] = {"maxResults": 100}
        if page_token:
            params["nextToken"] = page_token
        if sync_token:
            params["syncToken"] = sync_token
        if full_sync:
            params["timeMin"] = (_utc_now() - timedelta(days=365)).isoformat()
            params["timeMax"] = (_utc_now() + timedelta(days=365)).isoformat()
        payload = await self._request(
            "GET",
            f"{self.cfg.dingtalk_api_base_url}/v1.0/calendar/users/{user_id}/calendars/{calendar_id}/events",
            headers={"x-acs-dingtalk-access-token": access_token},
            params=params,
        )
        items = payload.get("value") if isinstance(payload.get("value"), list) else payload.get("items")
        if not isinstance(items, list):
            items = []
        events = [self._normalize_event(calendar_id=calendar_id, item=item) for item in items if isinstance(item, dict)]
        return CalendarSyncBatch(
            events=events,
            next_page_token=_normalize_optional_string(payload.get("nextToken")),
            next_sync_token=_normalize_optional_string(payload.get("syncToken")),
        )

    async def delete_event(
        self,
        *,
        access_token: str,
        external_user_id: str | None,
        calendar_id: str,
        event_id: str,
    ) -> None:
        user_id = external_user_id or "me"
        await self._request(
            "DELETE",
            f"{self.cfg.dingtalk_api_base_url}/v1.0/calendar/users/{user_id}/calendars/{calendar_id}/events/{event_id}",
            headers={"x-acs-dingtalk-access-token": access_token},
        )

    def _normalize_event(
        self,
        *,
        calendar_id: str,
        item: dict[str, Any],
    ) -> dict[str, Any]:
        start = item.get("start") if isinstance(item.get("start"), dict) else {}
        end = item.get("end") if isinstance(item.get("end"), dict) else {}
        organizer = item.get("organizer") if isinstance(item.get("organizer"), dict) else {}
        return {
            "calendar_id": calendar_id,
            "event_id": _normalize_optional_string(item.get("id") or item.get("eventId")) or "",
            "title": _normalize_optional_string(item.get("summary") or item.get("subject")) or "Untitled",
            "subtitle": _normalize_optional_string(item.get("description") or item.get("bodyPreview")),
            "start_at": _parse_external_datetime(start.get("dateTime") or item.get("startDateTime")),
            "end_at": _parse_external_datetime(end.get("dateTime") or item.get("endDateTime")),
            "timezone": _normalize_optional_string(start.get("timeZone"))
            or constants.UTC_TIMEZONE_NAME,
            "location": _normalize_optional_string(item.get("location", {}).get("displayName") if isinstance(item.get("location"), dict) else item.get("location")),
            "status": _normalize_optional_string(item.get("status"))
            or constants.CALENDAR_STATUS_SCHEDULED,
            "meeting_url": _normalize_optional_string(item.get("onlineMeetingUrl")),
            "attendees": item.get("attendees") if isinstance(item.get("attendees"), list) else [],
            "updated_at": _parse_external_datetime(item.get("lastModifiedDateTime") or item.get("updatedTime")),
            "organizer": organizer,
            "metadata": {
                "etag": item.get("etag"),
                "raw_payload_digest": _hash_payload(item),
            },
        }


def build_provider_client(
    provider_id: str,
    *,
    cfg: AppConfig | None = None,
    http_client: httpx.AsyncClient | None = None,
) -> BaseCalendarProviderClient:
    normalized = str(provider_id or "").strip().lower()
    if normalized == PROVIDER_FEISHU:
        return FeishuCalendarProviderClient(cfg, http_client=http_client)
    if normalized == PROVIDER_DINGTALK:
        return DingTalkCalendarProviderClient(cfg, http_client=http_client)
    raise AppHTTPException(status_code=422, detail="Unsupported calendar provider")
