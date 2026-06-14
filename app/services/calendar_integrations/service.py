"""第三方日历业务：ExternalCalendarSyncService 拉取增量写 Ling 事件；OAuth 与连接管理；飞书 webhook。"""

from __future__ import annotations

import hashlib
import secrets
import time
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any
from urllib.parse import parse_qs, urlparse

from config import constants
from config.settings import AppConfig, get_app_config
from core.http.exceptions import AppHTTPException
from core.infra.redis import redis
from core.metrics import metrics
from loguru import logger
from models.calendar import AppleCalendarContextDao, CalendarEvent, CalendarEventDao
from models.calendar_provider import CalendarProviderConnection, CalendarProviderConnectionDao
from services.calendar_integrations.providers import (
    PROVIDER_APPLE_LOCAL,
    PROVIDER_DINGTALK,
    PROVIDER_FEISHU,
    BaseCalendarProviderClient,
    CalendarOAuthExchangeResult,
    build_provider_client,
)
from services.calendar_integrations.state_store import (
    CalendarOAuthStateStore,
    CalendarSyncTriggerStore,
    RedisCalendarOAuthState,
)
from utils.time import (
    format_datetime,
    normalize_persisted_timezone,
    to_storage_utc,
    utc_now_naive,
)


def _utc_now() -> datetime:
    return datetime.now(UTC)


def _aware_to_storage(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    return to_storage_utc(value)


class ExternalCalendarSyncService:
    """按 provider 拉取变更并映射为 CalendarEvent；处理冲突、去重与连接失效。"""

    def __init__(
        self,
        cfg: AppConfig | None = None,
        *,
        connection_dao: CalendarProviderConnectionDao | None = None,
        event_dao: CalendarEventDao | None = None,
    ) -> None:
        self.cfg = cfg or get_app_config()
        self.connection_dao = connection_dao or CalendarProviderConnectionDao()
        self.event_dao = event_dao or CalendarEventDao()

    async def run_initial_sync(self, connection_id: str) -> dict[str, Any]:
        async with redis.lock_or_raise(
            f"calendar:sync:{connection_id}",
            error=AppHTTPException(
                status_code=409,
                detail="Calendar sync already in progress",
            ),
            ttl_seconds=180,
            wait_timeout_seconds=5,
        ):
            connection = await self.connection_dao.get_by_id(connection_id)
            if connection is None:
                raise AppHTTPException(status_code=404, detail="Calendar connection not found")
            provider = build_provider_client(connection.provider_id, cfg=self.cfg)
            try:
                await self._ensure_access_token(connection, provider)
                event_count = await self._run_full_sync(connection, provider)
                if connection.provider_id == PROVIDER_FEISHU:
                    try:
                        subscription = await provider.subscribe_primary_calendar(
                            access_token=connection.access_token or "",
                            calendar_id=connection.primary_calendar_id or "",
                        )
                        metadata = dict(connection.extra_data or {})
                        metadata["subscription"] = subscription
                        connection.extra_data = metadata
                        await self.connection_dao.save(connection)
                    except Exception as exc:
                        metadata = dict(connection.extra_data or {})
                        metadata["subscription_error"] = str(exc)
                        connection.extra_data = metadata
                        await self.connection_dao.save(connection)
                return {
                    "connection_id": connection.connection_id,
                    "provider_id": connection.provider_id,
                    "event_count": event_count,
                    "status": connection.status,
                }
            except Exception as exc:
                await self._mark_connection_error(connection, exc)
                raise

    async def run_delta_sync(
        self,
        connection_id: str,
        *,
        trigger: str,
    ) -> dict[str, Any]:
        started_at = time.perf_counter()
        async with redis.lock(
            f"calendar:sync:{connection_id}",
            ttl_seconds=180,
            wait_timeout_seconds=1,
        ) as acquired:
            if not acquired:
                metrics.inc_counter("ling_calendar_delta_sync_skipped_total")
                connection = await self.connection_dao.get_by_id(connection_id)
                if connection is None:
                    raise AppHTTPException(status_code=404, detail="Calendar connection not found")
                return {
                    "connection_id": connection.connection_id,
                    "provider_id": connection.provider_id,
                    "event_count": 0,
                    "status": connection.status,
                    constants.CALENDAR_SYNC_RESULT_KEY_SKIPPED: True,
                    "reason": "sync_already_in_progress",
                }

            connection = await self.connection_dao.get_by_id(connection_id)
            if connection is None:
                raise AppHTTPException(status_code=404, detail="Calendar connection not found")
            provider = build_provider_client(connection.provider_id, cfg=self.cfg)
            try:
                await self._ensure_access_token(connection, provider)
                page_token: str | None = None
                imported = 0
                deleted_keys: set[str] = set()
                while True:
                    batch = await provider.list_events(
                        access_token=connection.access_token or "",
                        external_user_id=connection.external_user_id,
                        calendar_id=connection.primary_calendar_id or "",
                        page_token=page_token,
                        sync_token=connection.sync_token,
                    )
                    active_events, batch_deleted = self._split_deleted_events(batch.events)
                    deleted_keys.update(batch_deleted)
                    imported += await self.upsert_imported_events(connection, active_events)
                    if batch.next_sync_token:
                        connection.sync_token = batch.next_sync_token
                    page_token = batch.next_page_token
                    if not page_token:
                        break
                if deleted_keys:
                    await self.deactivate_deleted_events(connection, deleted_keys)
                metrics.inc_counter("ling_calendar_delta_sync_imported_total", imported)
                metrics.inc_counter("ling_calendar_delta_sync_deleted_total", len(deleted_keys))
                metrics.observe(
                    "ling_calendar_delta_sync_duration_ms",
                    round((time.perf_counter() - started_at) * 1000, 2),
                )
                logger.info(
                    "[ExternalCalendarSyncService] 增量同步完成 "
                    f"connection_id={connection.connection_id} provider={connection.provider_id} "
                    f"imported={imported} deleted={len(deleted_keys)} trigger={trigger}"
                )
                connection.status = constants.CALENDAR_CONNECTION_STATUS_CONNECTED
                connection.last_delta_sync_at = utc_now_naive()
                connection.last_error = None
                metadata = dict(connection.extra_data or {})
                metadata["last_trigger"] = trigger
                connection.extra_data = metadata
                await self.connection_dao.save(connection)
                return {
                    "connection_id": connection.connection_id,
                    "provider_id": connection.provider_id,
                    "event_count": imported,
                    "status": connection.status,
                }
            except Exception as exc:
                await self._mark_connection_error(connection, exc)
                raise

    async def delete_source_event(self, *, user_id: str, event: CalendarEvent) -> dict[str, Any]:
        provider_id = str(event.source or "").strip().lower()
        if provider_id not in {PROVIDER_FEISHU, PROVIDER_DINGTALK}:
            raise AppHTTPException(
                status_code=422,
                detail="Unsupported external calendar provider for delete",
            )
        connection_id = str(event.source_device_id or "").strip()
        if not connection_id:
            raise AppHTTPException(status_code=422, detail="Calendar connection not found")

        connection = await self.connection_dao.get_by_id(connection_id)
        if connection is None or connection.user_id != user_id or connection.provider_id != provider_id:
            raise AppHTTPException(status_code=404, detail="Calendar connection not found")

        external_event_id = str(event.external_event_identifier or "").strip()
        calendar_id = str(
            event.external_calendar_identifier or connection.primary_calendar_id or ""
        ).strip()
        if not external_event_id or not calendar_id:
            raise AppHTTPException(
                status_code=422,
                detail="External calendar event identifiers are incomplete",
            )

        provider = build_provider_client(provider_id, cfg=self.cfg)
        await self._ensure_access_token(connection, provider)
        await provider.delete_event(
            access_token=connection.access_token or "",
            external_user_id=connection.external_user_id,
            calendar_id=calendar_id,
            event_id=external_event_id,
        )
        event.is_active = False
        event.status = constants.CALENDAR_STATUS_CANCELLED
        await self.event_dao.save(event)
        return {
            "deleted": True,
            "event_id": event.event_id,
            "source": provider_id,
            "provider": provider_id,
            "external_event_identifier": external_event_id,
        }

    async def upsert_imported_events(
        self,
        connection: CalendarProviderConnection,
        upstream_events: list[dict[str, Any]],
    ) -> int:
        external_event_ids = {
            str(item.get("event_id") or "").strip()
            for item in upstream_events
            if str(item.get("event_id") or "").strip()
        }
        existing_events = await self.event_dao.list_connection_source_events(
            connection.user_id,
            connection.provider_id,
            connection.connection_id,
            external_event_identifiers=external_event_ids,
        )
        existing_by_external = {
            str(item.external_event_identifier or ""): item
            for item in existing_events
        }
        touched = 0
        for item in upstream_events:
            event_id = str(item.get("event_id") or "").strip()
            if not event_id:
                continue
            status = str(item.get("status") or constants.CALENDAR_STATUS_SCHEDULED).strip().lower()
            existing = existing_by_external.get(event_id)
            if self._is_deleted_status(status):
                if existing is not None:
                    existing.is_active = False
                    existing.status = constants.CALENDAR_STATUS_CANCELLED
                    existing.extra_data = {
                        **dict(existing.extra_data or {}),
                        **dict(item.get("metadata") or {}),
                    }
                    await self.event_dao.save(existing)
                    touched += 1
                continue
            payload = self._build_event_payload(connection=connection, item=item)
            if existing is None:
                row = CalendarEvent(
                    event_id=payload["event_id"],
                    user_id=connection.user_id,
                    source=connection.provider_id,
                    title=payload["title"],
                    subtitle=payload["subtitle"],
                    category=constants.EXTERNAL_CALENDAR_CATEGORY,
                    time_shape=constants.CALENDAR_TIME_SHAPE_SPAN,
                    start_at=payload["start_at"],
                    end_at=payload["end_at"],
                    timezone=payload["timezone"],
                    location=payload["location"],
                    meeting_url=payload["meeting_url"],
                    attendees=payload["attendees"],
                    status=payload["status"],
                    focus_mode_enabled=False,
                    series_id=payload["series_id"],
                    source_device_id=connection.connection_id,
                    external_calendar_identifier=connection.primary_calendar_id,
                    external_event_identifier=event_id,
                    metadata=payload["metadata"],
                )
                row.is_active = status not in constants.CALENDAR_DELETED_STATUSES
                await self.event_dao.insert(row)
            else:
                existing.title = payload["title"]
                existing.subtitle = payload["subtitle"]
                existing.start_at = payload["start_at"]
                existing.end_at = payload["end_at"]
                existing.timezone = payload["timezone"]
                existing.location = payload["location"]
                existing.meeting_url = payload["meeting_url"]
                existing.attendees = payload["attendees"]
                existing.status = payload["status"]
                existing.series_id = payload["series_id"]
                existing.external_calendar_identifier = connection.primary_calendar_id
                existing.extra_data = payload["metadata"]
                existing.is_active = status not in constants.CALENDAR_DELETED_STATUSES
                await self.event_dao.save(existing)
            touched += 1
        return touched

    async def deactivate_deleted_events(
        self,
        connection: CalendarProviderConnection,
        deleted_keys: set[str],
    ) -> int:
        if not deleted_keys:
            raise ValueError("deleted_keys is required")
        events = await self.event_dao.list_connection_source_events(
            connection.user_id,
            connection.provider_id,
            connection.connection_id,
            external_event_identifiers=deleted_keys,
        )
        count = 0
        for event in events:
            if not event.is_active:
                continue
            event.is_active = False
            event.status = constants.CALENDAR_STATUS_CANCELLED
            await self.event_dao.save(event)
            count += 1
        return count

    async def _ensure_access_token(
        self,
        connection: CalendarProviderConnection,
        provider: BaseCalendarProviderClient,
    ) -> None:
        expires_at = connection.access_token_expires_at
        if connection.access_token and (
            expires_at is None
            or expires_at.replace(tzinfo=UTC) > _utc_now() + timedelta(minutes=2)
        ):
            return
        refresh_token = str(connection.refresh_token or "").strip()
        if not refresh_token:
            raise AppHTTPException(status_code=401, detail="Calendar access token expired")
        refreshed = await provider.refresh_access_token(refresh_token=refresh_token)
        access_token = str(refreshed.get("access_token") or "").strip()
        if not access_token:
            raise AppHTTPException(status_code=401, detail="Calendar token refresh failed")
        connection.access_token = access_token
        connection.refresh_token = str(refreshed.get("refresh_token") or refresh_token).strip()
        connection.access_token_expires_at = _aware_to_storage(
            refreshed.get("access_token_expires_at")
        )
        connection.refresh_token_expires_at = _aware_to_storage(
            refreshed.get("refresh_token_expires_at")
        )
        metadata = dict(connection.extra_data or {})
        metadata.update(refreshed.get("metadata") or {})
        connection.extra_data = metadata
        await self.connection_dao.save(connection)

    async def _run_full_sync(
        self,
        connection: CalendarProviderConnection,
        provider: BaseCalendarProviderClient,
    ) -> int:
        connection.status = constants.CALENDAR_CONNECTION_STATUS_SYNCING
        connection.last_error = None
        await self.connection_dao.save(connection)
        page_token: str | None = None
        total = 0
        active_external_ids: set[str] = set()
        while True:
            batch = await provider.list_events(
                access_token=connection.access_token or "",
                external_user_id=connection.external_user_id,
                calendar_id=connection.primary_calendar_id or "",
                page_token=page_token,
                full_sync=True,
            )
            total += await self.upsert_imported_events(connection, batch.events)
            for item in batch.events:
                event_id = str(item.get("event_id") or "").strip()
                if event_id:
                    active_external_ids.add(event_id)
            if batch.next_sync_token:
                connection.sync_token = batch.next_sync_token
            page_token = batch.next_page_token
            if not page_token:
                break

        existing = await self.event_dao.list_user_source_events(
            connection.user_id,
            connection.provider_id,
        )
        for event in existing:
            if str(event.source_device_id or "") != connection.connection_id:
                continue
            if str(event.external_event_identifier or "") in active_external_ids:
                continue
            event.is_active = False
            event.status = constants.CALENDAR_STATUS_CANCELLED
            await self.event_dao.save(event)

        connection.status = constants.CALENDAR_CONNECTION_STATUS_CONNECTED
        connection.last_full_sync_at = utc_now_naive()
        connection.last_error = None
        await self.connection_dao.save(connection)
        return total

    def _split_deleted_events(
        self,
        upstream_events: list[dict[str, Any]],
    ) -> tuple[list[dict[str, Any]], set[str]]:
        active_events: list[dict[str, Any]] = []
        deleted_keys: set[str] = set()
        for item in upstream_events:
            event_id = str(item.get("event_id") or "").strip()
            status = str(item.get("status") or "").strip().lower()
            if event_id and self._is_deleted_status(status):
                deleted_keys.add(event_id)
                active_events.append(item)
                continue
            active_events.append(item)
        return active_events, deleted_keys

    def _is_deleted_status(self, status: str) -> bool:
        normalized = str(status or "").strip().lower()
        return normalized in constants.CALENDAR_DELETED_STATUSES

    async def _mark_connection_error(
        self,
        connection: CalendarProviderConnection,
        exc: Exception,
    ) -> None:
        detail = getattr(exc, "detail", None)
        message = str(detail or exc or "calendar sync failed").strip() or "calendar sync failed"
        connection.status = constants.CALENDAR_CONNECTION_STATUS_ERROR
        connection.last_error = message[:2048]
        await self.connection_dao.save(connection)

    def _build_event_payload(
        self,
        *,
        connection: CalendarProviderConnection,
        item: dict[str, Any],
    ) -> dict[str, Any]:
        start_raw = str(item.get("start_at") or "").strip()
        end_raw = str(item.get("end_at") or "").strip()
        if not start_raw or not end_raw:
            raise AppHTTPException(status_code=422, detail="Imported calendar event is missing time range")
        start_at = datetime.fromisoformat(start_raw.replace("Z", "+00:00"))
        end_at = datetime.fromisoformat(end_raw.replace("Z", "+00:00"))
        external_event_id = str(item.get("event_id") or "").strip()
        stable_local_id = (
            f"{connection.provider_id}:{connection.connection_id}:{external_event_id}"
        )
        metadata = dict(item.get("metadata") or {})
        metadata.update(
            {
                "provider": connection.provider_id,
                "external_user_id": connection.external_user_id,
                "external_tenant_id": connection.external_tenant_id,
                "updated_at": item.get("updated_at"),
                "organizer": item.get("organizer"),
            }
        )
        return {
            "event_id": stable_local_id,
            "title": str(item.get("title") or "Untitled").strip() or "Untitled",
            "subtitle": str(item.get("subtitle") or "").strip() or None,
            "start_at": to_storage_utc(start_at),
            "end_at": to_storage_utc(end_at),
            "timezone": self._normalize_persisted_timezone(
                item.get("timezone") or constants.UTC_TIMEZONE_NAME
            ),
            "location": str(item.get("location") or "").strip() or None,
            "meeting_url": str(item.get("meeting_url") or "").strip() or None,
            "attendees": item.get("attendees") if isinstance(item.get("attendees"), list) else [],
            "status": str(item.get("status") or constants.CALENDAR_STATUS_SCHEDULED).strip().lower()
            or constants.CALENDAR_STATUS_SCHEDULED,
            "series_id": stable_local_id,
            "metadata": metadata,
        }

    def _normalize_persisted_timezone(self, value: Any) -> str:
        try:
            normalized = normalize_persisted_timezone(None if value is None else str(value))
        except ValueError as exc:
            raise AppHTTPException(status_code=422, detail="Invalid timezone") from exc
        if normalized is None:
            raise AppHTTPException(status_code=422, detail="Invalid timezone")
        return normalized


class CalendarConnectionService:
    """面向 API 的连接列表与健康摘要：聚合 Apple 本地与各 OAuth provider 状态。"""

    def __init__(
        self,
        cfg: AppConfig | None = None,
        *,
        connection_dao: CalendarProviderConnectionDao | None = None,
        event_dao: CalendarEventDao | None = None,
        context_dao: AppleCalendarContextDao | None = None,
        sync_service: ExternalCalendarSyncService | None = None,
    ) -> None:
        self.cfg = cfg or get_app_config()
        self.connection_dao = connection_dao or CalendarProviderConnectionDao()
        self.event_dao = event_dao or CalendarEventDao()
        self.context_dao = context_dao or AppleCalendarContextDao()
        self.sync_service = sync_service or ExternalCalendarSyncService(
            self.cfg,
            connection_dao=self.connection_dao,
            event_dao=self.event_dao,
        )

    async def list_connections(self, user_id: str) -> list[dict[str, Any]]:
        summaries: list[dict[str, Any]] = [await self._build_apple_summary(user_id)]
        for provider_id, provider_name in (
            (PROVIDER_FEISHU, "Feishu"),
            (PROVIDER_DINGTALK, "DingTalk"),
        ):
            provider = build_provider_client(provider_id, cfg=self.cfg)
            connection = await self.connection_dao.get_by_user_provider(user_id, provider_id)
            events = await self.event_dao.list_user_source_events(user_id, provider_id)
            active_count = sum(1 for item in events if item.is_active)
            status = constants.CALENDAR_CONNECTION_STATUS_NOT_CONNECTED
            last_synced_at = None
            last_error = None
            account_label = None
            metadata = {}
            if connection is not None:
                status = connection.status or constants.CALENDAR_CONNECTION_STATUS_CONNECTED
                last_synced_at = connection.last_delta_sync_at or connection.last_full_sync_at
                last_error = connection.last_error
                account_label = connection.external_email or connection.external_user_name
                metadata = dict(connection.extra_data or {})
            elif not provider.is_configured():
                status = constants.CALENDAR_CONNECTION_STATUS_UNAVAILABLE
                last_error = f"{provider_name} calendar is not configured"
            summaries.append(
                {
                    "provider_id": provider_id,
                    "provider_name": provider_name,
                    "kind": "oauth",
                    "status": status,
                    "is_enabled": provider.is_configured(),
                    "is_connected": connection is not None
                    and status
                    not in {
                        constants.CALENDAR_CONNECTION_STATUS_NOT_CONNECTED,
                        constants.CALENDAR_CONNECTION_STATUS_UNAVAILABLE,
                    },
                    "event_count": active_count,
                    "last_synced_at": None if last_synced_at is None else format_datetime(last_synced_at),
                    "last_error": last_error,
                    "account_label": account_label,
                    "metadata": metadata,
                }
            )
        return summaries

    async def refresh_connection(self, user_id: str, provider_id: str) -> dict[str, Any]:
        connection = await self.connection_dao.get_by_user_provider(user_id, provider_id)
        if connection is None:
            raise AppHTTPException(status_code=404, detail="Calendar connection not found")
        return await self.sync_service.run_initial_sync(connection.connection_id)

    async def disconnect(self, user_id: str, provider_id: str) -> dict[str, Any]:
        connection = await self.connection_dao.get_by_user_provider(user_id, provider_id)
        if connection is None:
            return {"provider_id": provider_id, "disconnected": True}
        events = await self.event_dao.list_user_source_events(user_id, provider_id)
        for event in events:
            if str(event.source_device_id or "") != connection.connection_id:
                continue
            if not event.is_active:
                continue
            event.is_active = False
            event.status = constants.CALENDAR_STATUS_CANCELLED
            await self.event_dao.save(event)
        await self.connection_dao.delete_by_id(CalendarProviderConnection, connection.connection_id)
        return {"provider_id": provider_id, "disconnected": True}

    async def _build_apple_summary(self, user_id: str) -> dict[str, Any]:
        contexts = await self.context_dao.list_user_contexts(user_id)
        latest = contexts[0] if contexts else None
        events = await self.event_dao.list_user_source_events(user_id, constants.CALENDAR_SOURCE_APPLE)
        active_count = sum(1 for item in events if item.is_active)
        permission_state = str(
            latest.permission_state if latest else constants.CALENDAR_PERMISSION_NOT_DETERMINED
        )
        status = constants.CALENDAR_CONNECTION_STATUS_NOT_CONNECTED
        if permission_state == constants.CALENDAR_PERMISSION_GRANTED:
            status = constants.CALENDAR_CONNECTION_STATUS_CONNECTED
        elif permission_state in {constants.CALENDAR_PERMISSION_DENIED, constants.CALENDAR_PERMISSION_UNSUPPORTED}:
            status = constants.CALENDAR_CONNECTION_STATUS_ACTION_REQUIRED
        return {
            "provider_id": PROVIDER_APPLE_LOCAL,
            "provider_name": "Apple Calendar",
            "kind": "system_permission",
            "status": status,
            "is_enabled": True,
            "is_connected": permission_state == constants.CALENDAR_PERMISSION_GRANTED,
            "event_count": active_count,
            "last_synced_at": None if latest is None else format_datetime(latest.updated_at),
            "last_error": None,
            "account_label": None,
            "metadata": {
                "permission_state": permission_state,
            },
        }


class CalendarOAuthService:
    """OAuth 授权码流程：start_oauth 写 state，callback 换 token 并持久化 CalendarProviderConnection。"""

    def __init__(
        self,
        cfg: AppConfig | None = None,
        *,
        state_store: CalendarOAuthStateStore | None = None,
        connection_dao: CalendarProviderConnectionDao | None = None,
        sync_service: ExternalCalendarSyncService | None = None,
    ) -> None:
        self.cfg = cfg or get_app_config()
        self.state_store = state_store or CalendarOAuthStateStore(self.cfg)
        self.connection_dao = connection_dao or CalendarProviderConnectionDao()
        self.sync_service = sync_service or ExternalCalendarSyncService(
            self.cfg,
            connection_dao=self.connection_dao,
        )

    async def start_oauth(self, provider_id: str, user_id: str) -> dict[str, Any]:
        provider = build_provider_client(provider_id, cfg=self.cfg)
        if not provider.is_configured():
            raise AppHTTPException(status_code=503, detail=f"{provider_id} calendar is not configured")
        state_value = f"cs_{secrets.token_urlsafe(24)}"
        oauth_start = provider.build_oauth_start(state=state_value)
        parsed_redirect = urlparse(oauth_start.authorize_url)
        redirect_query = parse_qs(parsed_redirect.query)
        redirect_uri = str(redirect_query.get("redirect_uri", [""])[0]).strip()
        await self.state_store.save(
            RedisCalendarOAuthState(
                state=state_value,
                provider_id=provider_id,
                user_id=user_id,
                redirect_uri=redirect_uri,
                callback_scheme=oauth_start.callback_scheme,
                created_at=utc_now_naive(),
                expire_at=utc_now_naive() + timedelta(minutes=10),
            )
        )
        return {
            "provider_id": provider_id,
            "authorize_url": oauth_start.authorize_url,
            "callback_scheme": oauth_start.callback_scheme,
        }

    async def complete_oauth(
        self,
        provider_id: str,
        user_id: str,
        callback_url: str,
    ) -> dict[str, Any]:
        parsed = urlparse(callback_url)
        params = parse_qs(parsed.query)
        code = str(params.get("code", [""])[0]).strip()
        state = str(params.get("state", [""])[0]).strip()
        if not code or not state:
            raise AppHTTPException(status_code=422, detail="OAuth callback is missing code or state")
        stored = await self.state_store.get(state)
        if stored is None:
            raise AppHTTPException(status_code=401, detail="OAuth state expired")
        if stored.provider_id != provider_id or stored.user_id != user_id:
            raise AppHTTPException(status_code=401, detail="OAuth state mismatch")
        if stored.expire_at < utc_now_naive():
            await self.state_store.delete(state)
            raise AppHTTPException(status_code=401, detail="OAuth state expired")

        provider = build_provider_client(provider_id, cfg=self.cfg)
        exchange = await provider.exchange_code(code=code, redirect_uri=stored.redirect_uri)
        connection = await self._upsert_connection(
            user_id=user_id,
            exchange=exchange,
        )
        await self.state_store.delete(state)
        sync_result = await self.sync_service.run_initial_sync(connection.connection_id)
        return {
            "provider_id": provider_id,
            "connection_id": connection.connection_id,
            "status": connection.status,
            "sync": sync_result,
        }

    async def _upsert_connection(
        self,
        *,
        user_id: str,
        exchange: CalendarOAuthExchangeResult,
    ) -> CalendarProviderConnection:
        connection = await self.connection_dao.get_by_user_provider(
            user_id,
            exchange.provider_id,
        )
        if connection is None:
            connection = CalendarProviderConnection(
                connection_id=f"cconn_{uuid.uuid4().hex}",
                user_id=user_id,
                provider_id=exchange.provider_id,
                status=constants.CALENDAR_CONNECTION_STATUS_CONNECTED,
                external_user_id=exchange.external_user_id,
                external_user_name=exchange.external_user_name,
                external_email=exchange.external_email,
                external_tenant_id=exchange.external_tenant_id,
                external_tenant_name=exchange.external_tenant_name,
                primary_calendar_id=exchange.primary_calendar_id,
                access_token=exchange.access_token,
                refresh_token=exchange.refresh_token,
                access_token_expires_at=_aware_to_storage(exchange.access_token_expires_at),
                refresh_token_expires_at=_aware_to_storage(exchange.refresh_token_expires_at),
                metadata=exchange.metadata,
            )
            await self.connection_dao.insert(connection)
            return connection

        connection.status = constants.CALENDAR_CONNECTION_STATUS_CONNECTED
        connection.external_user_id = exchange.external_user_id
        connection.external_user_name = exchange.external_user_name
        connection.external_email = exchange.external_email
        connection.external_tenant_id = exchange.external_tenant_id
        connection.external_tenant_name = exchange.external_tenant_name
        connection.primary_calendar_id = exchange.primary_calendar_id
        connection.access_token = exchange.access_token
        connection.refresh_token = exchange.refresh_token
        connection.access_token_expires_at = _aware_to_storage(exchange.access_token_expires_at)
        connection.refresh_token_expires_at = _aware_to_storage(exchange.refresh_token_expires_at)
        connection.last_error = None
        connection.extra_data = dict(exchange.metadata or {})
        await self.connection_dao.save(connection)
        return connection


class FeishuWebhookService:
    """飞书开放平台回调：校验事件类型并触发对应连接的增量同步（可经 trigger_store 防抖）。"""

    def __init__(
        self,
        cfg: AppConfig | None = None,
        *,
        connection_dao: CalendarProviderConnectionDao | None = None,
        sync_service: ExternalCalendarSyncService | None = None,
        trigger_store: CalendarSyncTriggerStore | None = None,
    ) -> None:
        self.cfg = cfg or get_app_config()
        self.connection_dao = connection_dao or CalendarProviderConnectionDao()
        self.sync_service = sync_service or ExternalCalendarSyncService(
            self.cfg,
            connection_dao=self.connection_dao,
        )
        self.trigger_store = trigger_store or CalendarSyncTriggerStore(self.cfg)

    async def handle_webhook(self, payload: dict[str, Any]) -> dict[str, Any]:
        webhook_type = str(payload.get("type") or "").strip().lower()
        if webhook_type == "url_verification":
            return {"challenge": payload.get("challenge")}

        header = payload.get("header") if isinstance(payload.get("header"), dict) else {}
        event_type = str(header.get("event_type") or "").strip()
        if event_type != "calendar.calendar.event.changed_v4":
            return {"accepted": True, "event_type": event_type or "unknown"}

        event = payload.get("event") if isinstance(payload.get("event"), dict) else {}
        tenant_key = str(header.get("tenant_key") or "").strip() or None
        trigger_id = self._build_trigger_id(header=header, payload=payload)
        reserved = await self.trigger_store.reserve(
            PROVIDER_FEISHU,
            trigger_id,
            ttl_seconds=7 * 24 * 60 * 60,
        )
        if not reserved:
            return {"accepted": True, "duplicate": True, "matched_connections": 0}
        calendar_id = str(
            event.get("calendar_id")
            or event.get("calendar", {}).get("calendar_id")
            if isinstance(event.get("calendar"), dict)
            else event.get("calendar_id")
            or ""
        ).strip()
        connections = await self.connection_dao.list_by_provider_tenant(
            provider_id=PROVIDER_FEISHU,
            external_tenant_id=tenant_key,
        )
        matched = 0
        for connection in connections:
            if calendar_id and str(connection.primary_calendar_id or "").strip() not in {"", calendar_id}:
                continue
            connection.last_webhook_at = utc_now_naive()
            await self.connection_dao.save(connection)
            await self.sync_service.run_delta_sync(
                connection.connection_id,
                trigger="feishu_webhook",
            )
            matched += 1
        return {"accepted": True, "matched_connections": matched}

    def _build_trigger_id(
        self,
        *,
        header: dict[str, Any],
        payload: dict[str, Any],
    ) -> str:
        event_id = str(
            header.get("event_id")
            or header.get("event_id_v2")
            or header.get("message_id")
            or ""
        ).strip()
        if event_id:
            return event_id
        raw = str(payload).encode("utf-8")
        return hashlib.sha256(raw).hexdigest()
