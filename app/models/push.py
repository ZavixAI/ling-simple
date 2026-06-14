from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from sqlalchemy import JSON, String
from sqlalchemy.ext.mutable import MutableDict
from sqlalchemy.orm import Mapped, mapped_column

from config import constants
from .base import Base, BaseDao, get_local_now


class UserPushDevice(Base):
    __tablename__ = "user_push_devices"

    device_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    platform: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    transport: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    push_token: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    app_bundle_id: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
    )
    apns_environment: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default=constants.APNS_ENVIRONMENT_PRODUCTION,
    )
    locale: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    timezone: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    device_model: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    location_data: Mapped[Optional[dict[str, Any]]] = mapped_column(
        MutableDict.as_mutable(JSON),
        nullable=True,
    )
    notifications_enabled: Mapped[bool] = mapped_column(nullable=False, default=True)
    timezone_updated_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    location_updated_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    last_registered_at: Mapped[datetime] = mapped_column(nullable=False)
    last_seen_at: Mapped[datetime] = mapped_column(nullable=False)
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        *,
        device_id: str,
        user_id: str,
        platform: str,
        transport: str,
        push_token: str,
        app_bundle_id: str | None = None,
        apns_environment: str = constants.APNS_ENVIRONMENT_PRODUCTION,
        locale: str | None = None,
        timezone: str | None = None,
        device_model: str | None = None,
        location_data: dict[str, Any] | None = None,
        notifications_enabled: bool = True,
    ) -> None:
        now = get_local_now()
        self.device_id = device_id
        self.user_id = user_id
        self.platform = platform
        self.transport = transport
        self.push_token = push_token
        self.app_bundle_id = app_bundle_id
        self.apns_environment = apns_environment
        self.locale = locale
        self.timezone = timezone
        self.device_model = device_model
        self.location_data = location_data
        self.notifications_enabled = notifications_enabled
        self.timezone_updated_at = now if timezone else None
        self.location_updated_at = now if location_data else None
        self.last_registered_at = now
        self.last_seen_at = now
        self.created_at = now
        self.updated_at = now


class UserPushDeviceDao(BaseDao):
    async def list_all_devices(self) -> list[UserPushDevice]:
        return await BaseDao.get_list(
            self,
            UserPushDevice,
            order_by=UserPushDevice.updated_at.desc(),
        )

    async def get_device_by_id(self, device_id: str) -> Optional[UserPushDevice]:
        return await BaseDao.get_first(
            self,
            UserPushDevice,
            where=[UserPushDevice.device_id == device_id],
        )

    async def get_device_by_push_token(
        self,
        *,
        push_token: str,
        platform: str | None = None,
        transport: str | None = None,
    ) -> Optional[UserPushDevice]:
        where = [UserPushDevice.push_token == push_token]
        if platform:
            where.append(UserPushDevice.platform == platform)
        if transport:
            where.append(UserPushDevice.transport == transport)
        return await BaseDao.get_first(
            self,
            UserPushDevice,
            where=where,
            order_by=UserPushDevice.updated_at.desc(),
        )

    async def get_user_device(
        self,
        user_id: str,
        device_id: str,
    ) -> Optional[UserPushDevice]:
        return await BaseDao.get_first(
            self,
            UserPushDevice,
            where=[
                UserPushDevice.user_id == user_id,
                UserPushDevice.device_id == device_id,
            ],
        )

    async def get_latest_active_device(
        self,
        user_id: str,
        *,
        platform: str | None = None,
        transport: str | None = None,
    ) -> Optional[UserPushDevice]:
        where = [
            UserPushDevice.user_id == user_id,
            UserPushDevice.notifications_enabled.is_(True),
        ]
        if platform:
            where.append(UserPushDevice.platform == platform)
        if transport:
            where.append(UserPushDevice.transport == transport)
        return await BaseDao.get_first(
            self,
            UserPushDevice,
            where=where,
            order_by=UserPushDevice.updated_at.desc(),
        )

    async def get_latest_device(
        self,
        user_id: str,
        *,
        platform: str | None = None,
        transport: str | None = None,
    ) -> Optional[UserPushDevice]:
        where = [UserPushDevice.user_id == user_id]
        if platform:
            where.append(UserPushDevice.platform == platform)
        if transport:
            where.append(UserPushDevice.transport == transport)
        return await BaseDao.get_first(
            self,
            UserPushDevice,
            where=where,
            order_by=UserPushDevice.updated_at.desc(),
        )

    async def list_active_devices(
        self,
        user_id: str,
        *,
        platform: str | None = None,
        transport: str | None = None,
    ) -> list[UserPushDevice]:
        where = [
            UserPushDevice.user_id == user_id,
            UserPushDevice.notifications_enabled.is_(True),
        ]
        if platform:
            where.append(UserPushDevice.platform == platform)
        if transport:
            where.append(UserPushDevice.transport == transport)
        return await BaseDao.get_list(
            self,
            UserPushDevice,
            where=where,
            order_by=UserPushDevice.updated_at.desc(),
        )

    async def save(self, device: UserPushDevice) -> bool:
        device.updated_at = get_local_now()
        return await BaseDao.save(self, device)

    async def delete_user_device(self, user_id: str, device_id: str) -> None:
        await BaseDao.delete_where(
            self,
            UserPushDevice,
            [
                UserPushDevice.user_id == user_id,
                UserPushDevice.device_id == device_id,
            ],
        )

    async def delete_device_by_id(self, device_id: str) -> None:
        await BaseDao.delete_where(
            self,
            UserPushDevice,
            [UserPushDevice.device_id == device_id],
        )

    async def delete_user_devices_except(
        self,
        user_id: str,
        *,
        keep_device_id: str,
        platform: str | None = None,
        transport: str | None = None,
    ) -> None:
        where = [
            UserPushDevice.user_id == user_id,
            UserPushDevice.device_id != keep_device_id,
        ]
        if platform:
            where.append(UserPushDevice.platform == platform)
        if transport:
            where.append(UserPushDevice.transport == transport)
        await BaseDao.delete_where(self, UserPushDevice, where)
