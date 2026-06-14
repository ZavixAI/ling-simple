from __future__ import annotations

from datetime import datetime

from sqlalchemy import Float, Index, Integer, String, UniqueConstraint, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base, BaseDao, get_local_now


class ChatQuickPromptUsage(Base):
    __tablename__ = "chat_quick_prompt_usage"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "surface",
            "prompt_id",
            name="ux_chat_quick_prompt_usage_user_surface_prompt",
        ),
        Index("ix_chat_quick_prompt_usage_user_surface", "user_id", "surface"),
    )

    usage_id: Mapped[str] = mapped_column(String(320), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    surface: Mapped[str] = mapped_column(String(64), nullable=False, default="chat", index=True)
    prompt_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    use_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    weighted_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    last_used_at: Mapped[datetime | None] = mapped_column(nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        *,
        user_id: str,
        surface: str,
        prompt_id: str,
        use_count: int = 0,
        weighted_score: float = 0.0,
        last_used_at: datetime | None = None,
    ) -> None:
        now = get_local_now()
        normalized_surface = surface.strip() or "chat"
        normalized_prompt_id = prompt_id.strip()
        self.usage_id = f"{user_id}:{normalized_surface}:{normalized_prompt_id}"
        self.user_id = user_id
        self.surface = normalized_surface
        self.prompt_id = normalized_prompt_id
        self.use_count = use_count
        self.weighted_score = weighted_score
        self.last_used_at = last_used_at
        self.created_at = now
        self.updated_at = now


class ChatQuickPromptUsageDao(BaseDao):
    async def get_usage(
        self,
        user_id: str,
        surface: str,
        prompt_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> ChatQuickPromptUsage | None:
        return await BaseDao.get_first(
            self,
            ChatQuickPromptUsage,
            where=[
                ChatQuickPromptUsage.user_id == user_id,
                ChatQuickPromptUsage.surface == surface,
                ChatQuickPromptUsage.prompt_id == prompt_id,
            ],
            session=session,
        )

    async def list_usage(
        self,
        user_id: str,
        surface: str,
        *,
        session: AsyncSession | None = None,
    ) -> list[ChatQuickPromptUsage]:
        return await BaseDao.get_list(
            self,
            ChatQuickPromptUsage,
            where=[
                ChatQuickPromptUsage.user_id == user_id,
                ChatQuickPromptUsage.surface == surface,
            ],
            session=session,
        )

    async def record_use(
        self,
        user_id: str,
        surface: str,
        prompt_id: str,
    ) -> ChatQuickPromptUsage:
        now = get_local_now()
        async with self._session_scope(autocommit=False) as active_session:
            stmt = select(ChatQuickPromptUsage).where(
                ChatQuickPromptUsage.user_id == user_id,
                ChatQuickPromptUsage.surface == surface,
                ChatQuickPromptUsage.prompt_id == prompt_id,
            )
            result = await active_session.execute(stmt)
            usage = result.scalars().first()
            if usage is None:
                usage = ChatQuickPromptUsage(
                    user_id=user_id,
                    surface=surface,
                    prompt_id=prompt_id,
                    use_count=1,
                    weighted_score=1.0,
                    last_used_at=now,
                )
                active_session.add(usage)
            else:
                usage.use_count += 1
                usage.weighted_score += 1.0
                usage.last_used_at = now
                usage.updated_at = now
            await active_session.commit()
            return usage
