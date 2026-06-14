from __future__ import annotations

import asyncio
import unittest
from contextlib import asynccontextmanager

from models.agent import AgentTokenUsage, AgentTokenUsageDao
from models.base import Base
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine


class _TestSessionManager:
    def __init__(self, session_factory: async_sessionmaker):
        self._session_factory = session_factory

    @asynccontextmanager
    async def get_session(self, autocommit: bool = True):
        session = self._session_factory()
        try:
            yield session
            if autocommit:
                await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


class AgentTokenUsageDaoTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.engine = create_async_engine("sqlite+aiosqlite:///:memory:", future=True)
        async with self.engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        self.session_factory = async_sessionmaker(
            bind=self.engine,
            autoflush=False,
            autocommit=False,
            expire_on_commit=False,
        )
        self.db = _TestSessionManager(self.session_factory)

    async def asyncTearDown(self) -> None:
        await self.engine.dispose()

    async def test_upsert_keeps_latest_usage_for_session(self) -> None:
        dao = AgentTokenUsageDao()
        dao.db = self.db

        first = await dao.upsert(
            AgentTokenUsage(
                session_id="session-1",
                user_id="user-1",
                input_tokens=10,
                output_tokens=5,
                total_tokens=15,
                model="model-a",
                models=["model-a"],
                raw_usage={"total_info": {"total_tokens": 15}},
            )
        )
        created_at = first.created_at
        await asyncio.sleep(0.01)

        second = await dao.upsert(
            AgentTokenUsage(
                session_id="session-1",
                user_id="user-1",
                input_tokens=20,
                output_tokens=8,
                total_tokens=28,
                cached_tokens=4,
                reasoning_tokens=3,
                model="model-b",
                models=["model-b"],
                raw_usage={"total_info": {"total_tokens": 28}},
            )
        )

        async with self.db.get_session() as session:
            stored = await session.get(AgentTokenUsage, "session-1")

        self.assertIsNotNone(stored)
        self.assertEqual(second.session_id, "session-1")
        self.assertEqual(stored.created_at, created_at)
        self.assertGreater(stored.updated_at, created_at)
        self.assertEqual(stored.input_tokens, 20)
        self.assertEqual(stored.output_tokens, 8)
        self.assertEqual(stored.total_tokens, 28)
        self.assertEqual(stored.cached_tokens, 4)
        self.assertEqual(stored.reasoning_tokens, 3)
        self.assertEqual(stored.model, "model-b")
        self.assertEqual(stored.models, ["model-b"])
