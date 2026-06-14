from datetime import datetime
from typing import Any, Dict, Optional

from config import constants
from sqlalchemy import JSON, Index, String, func, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base, BaseDao, get_local_now

DEFAULT_QUIET_HOURS_START = "22:00"
DEFAULT_QUIET_HOURS_END = "08:00"
DEFAULT_PREFERRED_INPUT_MODE = "text"
PREFERRED_INPUT_MODE_CHOICES = frozenset({"text", "voice"})


def normalize_quiet_hour_value(value: Any) -> str | None:
    """把 quiet_hours_* 字段标准化为 HH:MM；非法返回 None。"""
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    try:
        hour_str, minute_str = text.split(":", 1)
        hour = int(hour_str)
        minute = int(minute_str)
    except (ValueError, AttributeError):
        return None
    if not (0 <= hour <= 23) or not (0 <= minute <= 59):
        return None
    return f"{hour:02d}:{minute:02d}"


def normalize_preferred_input_mode_value(value: Any) -> str | None:
    """校验 preferred_input_mode；合法返回小写 key，否则 None。"""
    if value is None:
        return None
    text = str(value).strip().lower()
    if text in PREFERRED_INPUT_MODE_CHOICES:
        return text
    return None


def coerce_preferred_input_mode_stored(value: Any) -> str:
    """读取配置时归一化到合法枚举，便于前端展示。"""
    normalized = normalize_preferred_input_mode_value(value)
    if normalized is not None:
        return normalized
    return DEFAULT_PREFERRED_INPUT_MODE


class UserConfig(Base):
    __tablename__ = "user_configs"

    user_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    config: Mapped[Dict[str, Any]] = mapped_column(JSON, nullable=False, default={})
    updated_at: Mapped[datetime] = mapped_column(default=get_local_now, onupdate=get_local_now)

    def __init__(self, user_id: str, config: Dict[str, Any] = None):
        self.user_id = user_id
        self.config = config or {}
        self.updated_at = get_local_now()


class UserConfigDao(BaseDao):
    async def get_config(
        self,
        user_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Dict[str, Any]:
        obj = await BaseDao.get_by_id(
            self,
            UserConfig,
            user_id,
            session=session,
        )
        return obj.config if obj else {}

    async def update_config(
        self,
        user_id: str,
        updates: Dict[str, Any],
        *,
        session: AsyncSession | None = None,
    ) -> Dict[str, Any]:
        obj = await BaseDao.get_by_id(
            self,
            UserConfig,
            user_id,
            session=session,
        )
        if not obj:
            obj = UserConfig(user_id=user_id, config=updates)
            await BaseDao.insert(self, obj, session=session)
        else:
            # Deep merge or shallow merge? Shallow for now.
            new_config = obj.config.copy()
            new_config.update(updates)
            obj.config = new_config
            await BaseDao.save(self, obj, session=session)
        return obj.config


class User(Base):
    __tablename__ = "users"

    user_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    username: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    nickname: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    phonenum: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    phone_area_code: Mapped[Optional[str]] = mapped_column(String(8), nullable=True)
    role: Mapped[str] = mapped_column(String(64), default="user")
    avatar_url: Mapped[Optional[str]] = mapped_column(String(1024), nullable=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default=constants.USER_STATUS_ACTIVE,
        index=True,
    )
    deleted_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        user_id: str,
        username: str,
        password_hash: str,
        nickname: Optional[str] = None,
        email: Optional[str] = None,
        phonenum: Optional[str] = None,
        phone_area_code: Optional[str] = None,
        role: str = "user",
        avatar_url: Optional[str] = None,
        status: str = constants.USER_STATUS_ACTIVE,
        deleted_at: Optional[datetime] = None,
        created_at: Optional[datetime] = None,
        updated_at: Optional[datetime] = None,
    ):
        self.user_id = user_id
        self.username = username
        self.nickname = nickname
        self.password_hash = password_hash
        self.email = email
        self.phonenum = phonenum
        self.phone_area_code = phone_area_code
        self.role = role
        self.avatar_url = avatar_url
        self.status = status
        self.deleted_at = deleted_at
        self.created_at = created_at or get_local_now()
        self.updated_at = updated_at or get_local_now()

    def get_user_id(self) -> str:
        return self.user_id

    @property
    def is_deleted(self) -> bool:
        return self.status == constants.USER_STATUS_DELETED or self.deleted_at is not None


class UserExternalIdentity(Base):
    __tablename__ = "user_external_identities"
    __table_args__ = (
        Index(
            "ux_user_external_identities_provider_subject",
            "provider_id",
            "provider_subject",
            unique=True,
        ),
    )

    identity_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    provider_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    provider_subject: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    provider_username: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    provider_email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    profile: Mapped[Dict[str, Any]] = mapped_column(JSON, nullable=False, default={})
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        identity_id: str,
        user_id: str,
        provider_id: str,
        provider_subject: str,
        provider_username: Optional[str] = None,
        provider_email: Optional[str] = None,
        profile: Optional[Dict[str, Any]] = None,
        created_at: Optional[datetime] = None,
        updated_at: Optional[datetime] = None,
    ):
        self.identity_id = identity_id
        self.user_id = user_id
        self.provider_id = provider_id
        self.provider_subject = provider_subject
        self.provider_username = provider_username
        self.provider_email = provider_email
        self.profile = profile or {}
        self.created_at = created_at or get_local_now()
        self.updated_at = updated_at or get_local_now()


class UserDao(BaseDao):
    """用户数据访问层"""

    @staticmethod
    def _active_user_condition():
        return or_(
            User.status.is_(None),
            User.status != constants.USER_STATUS_DELETED,
        )

    async def get_by_id(
        self,
        user_id: str,
        *,
        include_deleted: bool = False,
        session: AsyncSession | None = None,
    ) -> Optional[User]:
        """根据用户ID查询用户"""
        user = await BaseDao.get_by_id(self, User, user_id, session=session)
        if user is None:
            return None
        if not include_deleted and user.is_deleted:
            return None
        return user

    async def get_by_username(
        self,
        username: str,
        *,
        include_deleted: bool = False,
        session: AsyncSession | None = None,
    ) -> Optional[User]:
        """根据用户名查询用户"""
        where = [User.username == username]
        if not include_deleted:
            where.append(self._active_user_condition())
        return await BaseDao.get_first(
            self,
            User,
            where=where,
            session=session,
        )

    async def get_by_email(
        self,
        email: str,
        *,
        include_deleted: bool = False,
        session: AsyncSession | None = None,
    ) -> Optional[User]:
        """根据邮箱查询用户"""
        normalized_email = (email or "").strip().lower()
        where = [func.lower(User.email) == normalized_email]
        if not include_deleted:
            where.append(self._active_user_condition())
        return await BaseDao.get_first(
            self,
            User,
            where=where,
            session=session,
        )

    async def get_by_phone(
        self,
        phone: str,
        phone_area_code: Optional[str] = None,
        *,
        include_deleted: bool = False,
        session: AsyncSession | None = None,
    ) -> Optional[User]:
        normalized_phone = (phone or "").strip()
        normalized_area_code = (phone_area_code or "").strip()
        if normalized_area_code:
            where = [
                User.phonenum == normalized_phone,
                User.phone_area_code == normalized_area_code,
            ]
            if not include_deleted:
                where.append(self._active_user_condition())
            user = await BaseDao.get_first(
                self,
                User,
                where=where,
                session=session,
            )
            if user is not None:
                return user

        where = [User.phonenum == normalized_phone]
        if not include_deleted:
            where.append(self._active_user_condition())
        return await BaseDao.get_first(
            self,
            User,
            where=where,
            session=session,
        )

    async def save(
        self,
        user: User,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        """保存用户"""
        user.updated_at = get_local_now()
        return await BaseDao.save(self, user, session=session)
    
    async def get_list(
        self,
        limit: int = 100,
        *,
        session: AsyncSession | None = None,
    ) -> list[User]:
        """查询所有用户"""
        return await BaseDao.get_list(
            self,
            User,
            limit=limit,
            session=session,
        )


class UserExternalIdentityDao(BaseDao):
    async def get_by_provider_subject(
        self,
        provider_id: str,
        provider_subject: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[UserExternalIdentity]:
        return await BaseDao.get_first(
            self,
            UserExternalIdentity,
            where=[
                UserExternalIdentity.provider_id == provider_id,
                UserExternalIdentity.provider_subject == provider_subject,
            ],
            session=session,
        )

    async def get_by_user_provider(
        self,
        user_id: str,
        provider_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[UserExternalIdentity]:
        return await BaseDao.get_first(
            self,
            UserExternalIdentity,
            where=[
                UserExternalIdentity.user_id == user_id,
                UserExternalIdentity.provider_id == provider_id,
            ],
            session=session,
        )

    async def save(
        self,
        identity: UserExternalIdentity,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        identity.updated_at = get_local_now()
        return await BaseDao.save(self, identity, session=session)

    async def list_by_user_id(
        self,
        user_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> list[UserExternalIdentity]:
        return await BaseDao.get_list(
            self,
            UserExternalIdentity,
            where=[UserExternalIdentity.user_id == user_id],
            order_by=UserExternalIdentity.created_at.desc(),
            session=session,
        )
