from __future__ import annotations

from datetime import datetime
from typing import Optional

from config import constants
from sqlalchemy import JSON, Index, Integer, String, and_, desc, exists, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base, BaseDao, get_local_now


class AgentSession(Base):
    __tablename__ = "agent_sessions"
    __table_args__ = (
        Index(
            "ix_agent_sessions_user_last_message_created",
            "user_id",
            "last_message_at",
            "created_at",
        ),
    )

    session_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    agent_id: Mapped[str] = mapped_column(String(128), nullable=False)
    entry_mode: Mapped[str] = mapped_column(String(32), nullable=False, default="text")
    selected_date: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    timezone: Mapped[str] = mapped_column(String(64), nullable=False, default=constants.UTC_TIMEZONE_NAME)
    title: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    extra_data: Mapped[dict] = mapped_column(JSON, nullable=False, default={})
    last_message_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        session_id: str,
        user_id: str,
        agent_id: str,
        entry_mode: str,
        timezone: str,
        selected_date: Optional[str] = None,
        title: Optional[str] = None,
        metadata: Optional[dict] = None,
    ):
        now = get_local_now()
        self.session_id = session_id
        self.user_id = user_id
        self.agent_id = agent_id
        self.entry_mode = entry_mode
        self.selected_date = selected_date
        self.timezone = timezone
        self.title = title
        self.extra_data = metadata or {}
        self.last_message_at = None
        self.created_at = now
        self.updated_at = now


class AgentMessage(Base):
    __tablename__ = "agent_messages"
    __table_args__ = (
        Index(
            "ix_agent_messages_user_session_created_record",
            "user_id",
            "session_id",
            "created_at",
            "record_id",
        ),
        Index(
            "ix_agent_messages_user_created_record",
            "user_id",
            "created_at",
            "record_id",
        ),
        Index(
            "ix_agent_messages_user_session_message_created",
            "user_id",
            "session_id",
            "message_id",
            "created_at",
        ),
        Index(
            "ix_agent_messages_user_session_role_final_created",
            "user_id",
            "session_id",
            "role",
            "is_final",
            "created_at",
        ),
        Index(
            "ix_agent_messages_user_session_role_type_created",
            "user_id",
            "session_id",
            "role",
            "message_type",
            "created_at",
        ),
        Index(
            "ix_agent_messages_user_type_created",
            "user_id",
            "message_type",
            "created_at",
        ),
        Index(
            "ix_agent_messages_user_role_created",
            "user_id",
            "role",
            "created_at",
        ),
        Index(
            "ix_agent_messages_user_session_tool_call_created",
            "user_id",
            "session_id",
            "tool_call_id",
            "created_at",
        ),
    )

    record_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    session_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    message_id: Mapped[Optional[str]] = mapped_column(String(128), nullable=True, index=True)
    tool_call_id: Mapped[Optional[str]] = mapped_column(String(128), nullable=True, index=True)
    role: Mapped[str] = mapped_column(String(32), nullable=False)
    message: Mapped[dict] = mapped_column(JSON, nullable=False, default={})
    message_type: Mapped[Optional[str]] = mapped_column(String(64), nullable=True, index=True)
    is_final: Mapped[bool] = mapped_column(nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        record_id: str,
        session_id: str,
        user_id: str,
        role: str,
        message: Optional[dict] = None,
        message_id: Optional[str] = None,
        tool_call_id: Optional[str] = None,
        message_type: Optional[str] = None,
        is_final: bool = False,
    ):
        now = get_local_now()
        self.record_id = record_id
        self.session_id = session_id
        self.user_id = user_id
        self.message_id = message_id
        self.tool_call_id = tool_call_id
        self.role = role
        self.message = message or {}
        self.message_type = message_type
        self.is_final = is_final
        self.created_at = now
        self.updated_at = now


class AgentTokenUsage(Base):
    __tablename__ = "agent_token_usages"
    __table_args__ = (
        Index("ix_agent_token_usages_user_updated", "user_id", "updated_at"),
    )

    session_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    input_tokens: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    output_tokens: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_tokens: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    cached_tokens: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    reasoning_tokens: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    model: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    models: Mapped[list] = mapped_column(JSON, nullable=False, default=[])
    raw_usage: Mapped[dict] = mapped_column(JSON, nullable=False, default={})
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        *,
        session_id: str,
        user_id: str,
        input_tokens: int = 0,
        output_tokens: int = 0,
        total_tokens: int = 0,
        cached_tokens: int = 0,
        reasoning_tokens: int = 0,
        model: Optional[str] = None,
        models: Optional[list] = None,
        raw_usage: Optional[dict] = None,
    ):
        now = get_local_now()
        self.session_id = session_id
        self.user_id = user_id
        self.input_tokens = input_tokens
        self.output_tokens = output_tokens
        self.total_tokens = total_tokens
        self.cached_tokens = cached_tokens
        self.reasoning_tokens = reasoning_tokens
        self.model = model
        self.models = models or []
        self.raw_usage = raw_usage or {}
        self.created_at = now
        self.updated_at = now


class AgentSessionDao(BaseDao):
    async def get_or_create_user_session(
        self,
        *,
        session_id: str,
        user_id: str,
        agent_id: str,
        entry_mode: str,
        timezone: str,
        selected_date: Optional[str] = None,
        title: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> AgentSession:
        existing = await self.get_user_session(user_id, session_id)
        if existing is not None:
            return existing

        created = AgentSession(
            session_id=session_id,
            user_id=user_id,
            agent_id=agent_id,
            entry_mode=entry_mode,
            timezone=timezone,
            selected_date=selected_date,
            title=title,
            metadata=metadata,
        )
        db = await self._get_db()
        async with db.get_session(autocommit=False) as active_session:
            active_session.add(created)
            try:
                await active_session.commit()
            except IntegrityError:
                await active_session.rollback()
                existing = await self.get_user_session(user_id, session_id)
                if existing is not None:
                    return existing
                raise
        return created

    async def save(
        self,
        agent_session: AgentSession,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        agent_session.updated_at = get_local_now()
        return await BaseDao.save(self, agent_session, session=session)

    async def get_user_session(
        self,
        user_id: str,
        session_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[AgentSession]:
        return await BaseDao.get_first(
            self,
            AgentSession,
            where=[
                AgentSession.user_id == user_id,
                AgentSession.session_id == session_id,
            ],
            session=session,
        )

    async def get_latest_user_session(
        self,
        user_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[AgentSession]:
        async with self._session_scope(session=session) as active_session:
            stmt = (
                select(AgentSession)
                .where(AgentSession.user_id == user_id)
                .order_by(
                    AgentSession.last_message_at.is_(None).asc(),
                    desc(AgentSession.last_message_at),
                    desc(AgentSession.created_at),
                )
                .limit(1)
            )
            res = await active_session.execute(stmt)
            return res.scalars().first()


class AgentMessageDao(BaseDao):
    async def save(
        self,
        message: AgentMessage,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        message.updated_at = get_local_now()
        return await BaseDao.save(self, message, session=session)

    async def get_latest_session_message(
        self,
        user_id: str,
        session_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[AgentMessage]:
        async with self._session_scope(session=session) as active_session:
            stmt = (
                select(AgentMessage)
                .where(
                    AgentMessage.user_id == user_id,
                    AgentMessage.session_id == session_id,
                )
                .order_by(
                    AgentMessage.created_at.desc(),
                    AgentMessage.record_id.desc(),
                )
                .limit(1)
            )
            res = await active_session.execute(stmt)
            return res.scalars().first()

    async def list_session_messages(
        self,
        user_id: str,
        session_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> list[AgentMessage]:
        async with self._session_scope(session=session) as active_session:
            stmt = (
                select(AgentMessage)
                .where(
                    AgentMessage.user_id == user_id,
                    AgentMessage.session_id == session_id,
                )
                .order_by(
                    AgentMessage.created_at.asc(),
                    AgentMessage.record_id.asc(),
                )
            )
            res = await active_session.execute(stmt)
            return list(res.scalars().all())

    async def list_user_messages(
        self,
        user_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> list[AgentMessage]:
        async with self._session_scope(session=session) as active_session:
            stmt = (
                select(AgentMessage)
                .where(AgentMessage.user_id == user_id)
                .order_by(
                    AgentMessage.created_at.asc(),
                    AgentMessage.record_id.asc(),
                )
            )
            res = await active_session.execute(stmt)
            return list(res.scalars().all())

    async def list_session_messages_desc(
        self,
        user_id: str,
        session_id: str,
        *,
        limit: int = 50,
        offset: int = 0,
        before_created_at: datetime | None = None,
        before_record_id: str | None = None,
        session: AsyncSession | None = None,
    ) -> list[AgentMessage]:
        async with self._session_scope(session=session) as active_session:
            conditions = [
                AgentMessage.user_id == user_id,
                AgentMessage.session_id == session_id,
            ]
            if before_created_at is not None:
                if before_record_id:
                    conditions.append(
                        or_(
                            AgentMessage.created_at < before_created_at,
                            and_(
                                AgentMessage.created_at == before_created_at,
                                AgentMessage.record_id < before_record_id,
                            ),
                        )
                    )
                else:
                    conditions.append(AgentMessage.created_at < before_created_at)
            stmt = (
                select(AgentMessage)
                .where(*conditions)
                .order_by(
                    AgentMessage.created_at.desc(),
                    AgentMessage.record_id.desc(),
                )
                .limit(max(1, limit))
                .offset(max(0, offset))
            )
            res = await active_session.execute(stmt)
            return list(res.scalars().all())

    async def list_user_messages_desc(
        self,
        user_id: str,
        *,
        limit: int = 50,
        before_created_at: datetime | None = None,
        before_record_id: str | None = None,
        session: AsyncSession | None = None,
    ) -> list[AgentMessage]:
        async with self._session_scope(session=session) as active_session:
            conditions = [AgentMessage.user_id == user_id]
            if before_created_at is not None:
                if before_record_id:
                    conditions.append(
                        or_(
                            AgentMessage.created_at < before_created_at,
                            and_(
                                AgentMessage.created_at == before_created_at,
                                AgentMessage.record_id < before_record_id,
                            ),
                        )
                    )
                else:
                    conditions.append(AgentMessage.created_at < before_created_at)
            stmt = (
                select(AgentMessage)
                .where(*conditions)
                .order_by(
                    AgentMessage.created_at.desc(),
                    AgentMessage.record_id.desc(),
                )
                .limit(max(1, limit))
            )
            res = await active_session.execute(stmt)
            return list(res.scalars().all())

    async def get_session_message(
        self,
        user_id: str,
        session_id: str,
        message_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[AgentMessage]:
        return await BaseDao.get_first(
            self,
            AgentMessage,
            where=[
                AgentMessage.user_id == user_id,
                AgentMessage.session_id == session_id,
                AgentMessage.message_id == message_id,
            ],
            order_by=AgentMessage.created_at.asc(),
            session=session,
        )

    async def list_unfinished_session_messages(
        self,
        user_id: str,
        session_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> list[AgentMessage]:
        async with self._session_scope(session=session) as active_session:
            stmt = (
                select(AgentMessage)
                .where(
                    AgentMessage.user_id == user_id,
                    AgentMessage.session_id == session_id,
                    AgentMessage.role == "assistant",
                    AgentMessage.is_final.is_(False),
                )
                .order_by(
                    AgentMessage.created_at.asc(),
                    AgentMessage.record_id.asc(),
                )
            )
            res = await active_session.execute(stmt)
            return list(res.scalars().all())

    async def list_session_tool_call_messages(
        self,
        user_id: str,
        session_id: str,
        tool_call_id: str | None = None,
        *,
        session: AsyncSession | None = None,
    ) -> list[AgentMessage]:
        async with self._session_scope(session=session) as active_session:
            conditions = [
                AgentMessage.user_id == user_id,
                AgentMessage.session_id == session_id,
                AgentMessage.role == "assistant",
                AgentMessage.message_type == "tool_call",
            ]
            if tool_call_id:
                conditions.append(AgentMessage.tool_call_id == tool_call_id)
            stmt = (
                select(AgentMessage)
                .where(*conditions)
                .order_by(
                    AgentMessage.created_at.asc(),
                    AgentMessage.record_id.asc(),
                )
            )
            res = await active_session.execute(stmt)
            return list(res.scalars().all())

    async def list_session_tool_result_messages(
        self,
        user_id: str,
        session_id: str,
        tool_call_id: str | None = None,
        *,
        session: AsyncSession | None = None,
    ) -> list[AgentMessage]:
        async with self._session_scope(session=session) as active_session:
            conditions = [
                AgentMessage.user_id == user_id,
                AgentMessage.session_id == session_id,
                AgentMessage.role == "tool",
                AgentMessage.message_type == "tool_call_result",
            ]
            if tool_call_id:
                conditions.append(AgentMessage.tool_call_id == tool_call_id)
            stmt = (
                select(AgentMessage)
                .where(*conditions)
                .order_by(
                    AgentMessage.created_at.asc(),
                    AgentMessage.record_id.asc(),
                )
            )
            res = await active_session.execute(stmt)
            return list(res.scalars().all())

    async def has_messages_between(
        self,
        user_id: str,
        *,
        start_at: datetime,
        end_at: datetime,
        roles: list[str] | None = None,
        exclude_message_types: list[str] | None = None,
        session: AsyncSession | None = None,
    ) -> bool:
        async with self._session_scope(session=session) as active_session:
            conditions = [
                AgentMessage.user_id == user_id,
                AgentMessage.created_at >= start_at,
                AgentMessage.created_at < end_at,
            ]
            if roles:
                conditions.append(AgentMessage.role.in_(roles))
            if exclude_message_types:
                conditions.append(
                    or_(
                        AgentMessage.message_type.is_(None),
                        ~AgentMessage.message_type.in_(exclude_message_types),
                    ),
                )
            stmt = select(
                exists().where(and_(*conditions)),
            )
            res = await active_session.execute(stmt)
            return bool(res.scalar())

    async def list_user_session_ids_between(
        self,
        user_id: str,
        *,
        start_at: datetime,
        end_at: datetime,
        exclude_message_types: list[str] | None = None,
        session: AsyncSession | None = None,
    ) -> list[str]:
        """列出指定时间窗内用户主动发言所在的 session_id。"""
        async with self._session_scope(session=session) as active_session:
            conditions = [
                AgentMessage.user_id == user_id,
                AgentMessage.role == "user",
                AgentMessage.created_at >= start_at,
                AgentMessage.created_at < end_at,
            ]
            if exclude_message_types:
                conditions.append(
                    or_(
                        AgentMessage.message_type.is_(None),
                        ~AgentMessage.message_type.in_(exclude_message_types),
                    ),
                )
            stmt = (
                select(AgentMessage.session_id)
                .where(and_(*conditions))
                .group_by(AgentMessage.session_id)
                .order_by(func.min(AgentMessage.created_at).asc())
            )
            res = await active_session.execute(stmt)
            return [str(session_id) for session_id in res.scalars().all() if session_id]

    async def count_messages_between(
        self,
        user_id: str,
        *,
        start_at: datetime,
        end_at: datetime,
        roles: list[str] | None = None,
        exclude_message_types: list[str] | None = None,
        session: AsyncSession | None = None,
    ) -> int:
        """统计指定时间窗内匹配条件的消息数量，用于活跃度判断。"""
        from sqlalchemy import func as sa_func

        async with self._session_scope(session=session) as active_session:
            conditions = [
                AgentMessage.user_id == user_id,
                AgentMessage.created_at >= start_at,
                AgentMessage.created_at < end_at,
            ]
            if roles:
                conditions.append(AgentMessage.role.in_(roles))
            if exclude_message_types:
                conditions.append(
                    or_(
                        AgentMessage.message_type.is_(None),
                        ~AgentMessage.message_type.in_(exclude_message_types),
                    ),
                )
            stmt = select(sa_func.count(AgentMessage.record_id)).where(and_(*conditions))
            res = await active_session.execute(stmt)
            return int(res.scalar() or 0)

    async def list_recent_user_messages(
        self,
        user_id: str,
        *,
        since: datetime,
        limit: int = 10,
        session: AsyncSession | None = None,
    ) -> list[AgentMessage]:
        """列出近期用户消息。"""
        async with self._session_scope(session=session) as active_session:
            stmt = (
                select(AgentMessage)
                .where(
                    AgentMessage.user_id == user_id,
                    AgentMessage.role == "user",
                    AgentMessage.created_at >= since,
                )
                .order_by(AgentMessage.created_at.desc())
                .limit(max(1, limit))
            )
            res = await active_session.execute(stmt)
            return list(res.scalars().all())


class AgentTokenUsageDao(BaseDao):
    async def upsert(
        self,
        usage: AgentTokenUsage,
        *,
        session: AsyncSession | None = None,
    ) -> AgentTokenUsage:
        async with self._session_scope(session=session) as active_session:
            existing = await active_session.get(AgentTokenUsage, usage.session_id)
            if existing is None:
                active_session.add(usage)
                return usage

            existing.user_id = usage.user_id
            existing.input_tokens = usage.input_tokens
            existing.output_tokens = usage.output_tokens
            existing.total_tokens = usage.total_tokens
            existing.cached_tokens = usage.cached_tokens
            existing.reasoning_tokens = usage.reasoning_tokens
            existing.model = usage.model
            existing.models = usage.models
            existing.raw_usage = usage.raw_usage
            existing.updated_at = get_local_now()
            return existing
