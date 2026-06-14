from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import JSON, Index, String
from sqlalchemy.orm import Mapped, mapped_column

from config import constants
from .base import Base, BaseDao, get_local_now


class CalendarProviderConnection(Base):
    __tablename__ = "calendar_provider_connections"
    __table_args__ = (
        Index(
            "ux_calendar_provider_connections_user_provider",
            "user_id",
            "provider_id",
            unique=True,
        ),
        Index(
            "ix_calendar_provider_connections_provider_external",
            "provider_id",
            "external_tenant_id",
            "external_user_id",
        ),
    )

    connection_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    provider_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    status: Mapped[str] = mapped_column(
        String(32), nullable=False, default=constants.CALENDAR_CONNECTION_STATUS_NOT_CONNECTED
    )
    external_user_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    external_user_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    external_email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    external_tenant_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True, index=True)
    external_tenant_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    primary_calendar_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    access_token: Mapped[Optional[str]] = mapped_column(String(4096), nullable=True)
    refresh_token: Mapped[Optional[str]] = mapped_column(String(4096), nullable=True)
    access_token_expires_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    refresh_token_expires_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    sync_token: Mapped[Optional[str]] = mapped_column(String(4096), nullable=True)
    last_full_sync_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    last_delta_sync_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    last_webhook_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    last_error: Mapped[Optional[str]] = mapped_column(String(2048), nullable=True)
    extra_data: Mapped[dict] = mapped_column(JSON, nullable=False, default={})
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        *,
        connection_id: str,
        user_id: str,
        provider_id: str,
        status: str = constants.CALENDAR_CONNECTION_STATUS_NOT_CONNECTED,
        external_user_id: str | None = None,
        external_user_name: str | None = None,
        external_email: str | None = None,
        external_tenant_id: str | None = None,
        external_tenant_name: str | None = None,
        primary_calendar_id: str | None = None,
        access_token: str | None = None,
        refresh_token: str | None = None,
        access_token_expires_at: datetime | None = None,
        refresh_token_expires_at: datetime | None = None,
        sync_token: str | None = None,
        last_full_sync_at: datetime | None = None,
        last_delta_sync_at: datetime | None = None,
        last_webhook_at: datetime | None = None,
        last_error: str | None = None,
        metadata: dict | None = None,
    ) -> None:
        now = get_local_now()
        self.connection_id = connection_id
        self.user_id = user_id
        self.provider_id = provider_id
        self.status = status
        self.external_user_id = external_user_id
        self.external_user_name = external_user_name
        self.external_email = external_email
        self.external_tenant_id = external_tenant_id
        self.external_tenant_name = external_tenant_name
        self.primary_calendar_id = primary_calendar_id
        self.access_token = access_token
        self.refresh_token = refresh_token
        self.access_token_expires_at = access_token_expires_at
        self.refresh_token_expires_at = refresh_token_expires_at
        self.sync_token = sync_token
        self.last_full_sync_at = last_full_sync_at
        self.last_delta_sync_at = last_delta_sync_at
        self.last_webhook_at = last_webhook_at
        self.last_error = last_error
        self.extra_data = metadata or {}
        self.created_at = now
        self.updated_at = now


class CalendarProviderConnectionDao(BaseDao):
    async def save(self, connection: CalendarProviderConnection) -> bool:
        connection.updated_at = get_local_now()
        return await BaseDao.save(self, connection)

    async def get_by_user_provider(
        self,
        user_id: str,
        provider_id: str,
    ) -> CalendarProviderConnection | None:
        return await BaseDao.get_first(
            self,
            CalendarProviderConnection,
            where=[
                CalendarProviderConnection.user_id == user_id,
                CalendarProviderConnection.provider_id == provider_id,
            ],
        )

    async def get_by_id(
        self,
        connection_id: str,
    ) -> CalendarProviderConnection | None:
        return await BaseDao.get_by_id(self, CalendarProviderConnection, connection_id)

    async def list_by_user_id(self, user_id: str) -> list[CalendarProviderConnection]:
        return await BaseDao.get_list(
            self,
            CalendarProviderConnection,
            where=[CalendarProviderConnection.user_id == user_id],
            order_by=CalendarProviderConnection.created_at.asc(),
        )

    async def get_by_provider_external_user(
        self,
        *,
        provider_id: str,
        external_tenant_id: str | None,
        external_user_id: str,
    ) -> CalendarProviderConnection | None:
        where = [
            CalendarProviderConnection.provider_id == provider_id,
            CalendarProviderConnection.external_user_id == external_user_id,
        ]
        if external_tenant_id is None:
            where.append(CalendarProviderConnection.external_tenant_id.is_(None))
        else:
            where.append(CalendarProviderConnection.external_tenant_id == external_tenant_id)
        return await BaseDao.get_first(
            self,
            CalendarProviderConnection,
            where=where,
        )

    async def list_by_provider_tenant(
        self,
        *,
        provider_id: str,
        external_tenant_id: str | None,
    ) -> list[CalendarProviderConnection]:
        where = [CalendarProviderConnection.provider_id == provider_id]
        if external_tenant_id is None:
            where.append(CalendarProviderConnection.external_tenant_id.is_(None))
        else:
            where.append(CalendarProviderConnection.external_tenant_id == external_tenant_id)
        return await BaseDao.get_list(
            self,
            CalendarProviderConnection,
            where=where,
            order_by=CalendarProviderConnection.updated_at.desc(),
        )
