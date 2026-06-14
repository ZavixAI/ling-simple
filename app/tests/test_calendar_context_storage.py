from __future__ import annotations

import unittest
from contextlib import asynccontextmanager
from datetime import datetime

from models.base import Base
from models.calendar import AppleCalendarContext, AppleCalendarContextDao
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


class AppleCalendarContextDaoTests(unittest.IsolatedAsyncioTestCase):
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
        self.dao = AppleCalendarContextDao()
        self.dao.db = _TestSessionManager(self.session_factory)

    async def asyncTearDown(self) -> None:
        await self.engine.dispose()

    async def test_get_latest_by_device_returns_most_recent_context(self) -> None:
        older = AppleCalendarContext(
            context_id="ctx_old",
            user_id="user-1",
            device_id="device-a",
            permission_state="granted",
            window_start=datetime(2026, 4, 1, 0, 0, 0),
            window_end=datetime(2026, 4, 1, 1, 0, 0),
            events=[{"title": "old"}],
        )
        older.created_at = datetime(2026, 4, 1, 0, 0, 0)
        older.updated_at = datetime(2026, 4, 1, 0, 0, 0)

        latest = AppleCalendarContext(
            context_id="ctx_new",
            user_id="user-1",
            device_id="device-a",
            permission_state="granted",
            window_start=datetime(2026, 4, 2, 0, 0, 0),
            window_end=datetime(2026, 4, 2, 1, 0, 0),
            events=[{"title": "new"}],
        )
        latest.created_at = datetime(2026, 4, 2, 0, 0, 0)
        latest.updated_at = datetime(2026, 4, 2, 0, 0, 0)

        await self.dao.insert(older)
        await self.dao.insert(latest)

        context = await self.dao.get_latest_by_device("user-1", "device-a")

        self.assertIsNotNone(context)
        assert context is not None
        self.assertEqual(context.context_id, "ctx_new")
        self.assertEqual(context.events, [{"title": "new"}])

    async def test_list_user_contexts_preserves_updated_at_desc_order(self) -> None:
        earliest = AppleCalendarContext(
            context_id="ctx_1",
            user_id="user-1",
            device_id="device-a",
            permission_state="granted",
            window_start=datetime(2026, 4, 1, 0, 0, 0),
            window_end=datetime(2026, 4, 1, 1, 0, 0),
            events=[],
        )
        earliest.created_at = datetime(2026, 4, 1, 0, 0, 0)
        earliest.updated_at = datetime(2026, 4, 1, 0, 0, 0)

        middle = AppleCalendarContext(
            context_id="ctx_2",
            user_id="user-1",
            device_id="device-b",
            permission_state="granted",
            window_start=datetime(2026, 4, 2, 0, 0, 0),
            window_end=datetime(2026, 4, 2, 1, 0, 0),
            events=[],
        )
        middle.created_at = datetime(2026, 4, 2, 0, 0, 0)
        middle.updated_at = datetime(2026, 4, 2, 0, 0, 0)

        latest = AppleCalendarContext(
            context_id="ctx_3",
            user_id="user-1",
            device_id="device-c",
            permission_state="granted",
            window_start=datetime(2026, 4, 3, 0, 0, 0),
            window_end=datetime(2026, 4, 3, 1, 0, 0),
            events=[],
        )
        latest.created_at = datetime(2026, 4, 3, 0, 0, 0)
        latest.updated_at = datetime(2026, 4, 3, 0, 0, 0)

        await self.dao.insert(earliest)
        await self.dao.insert(middle)
        await self.dao.insert(latest)

        contexts = await self.dao.list_user_contexts("user-1")

        self.assertEqual(
            [context.context_id for context in contexts],
            ["ctx_3", "ctx_2", "ctx_1"],
        )

    async def test_list_user_contexts_uses_explicit_session(self) -> None:
        context = AppleCalendarContext(
            context_id="ctx_1",
            user_id="user-1",
            device_id="device-a",
            permission_state="granted",
            window_start=datetime(2026, 4, 1, 0, 0, 0),
            window_end=datetime(2026, 4, 1, 1, 0, 0),
            events=[],
        )

        async with self.session_factory() as session:
            async with session.begin():
                session.add(context)
                await session.flush()
                contexts = await self.dao.list_user_contexts("user-1", session=session)

        self.assertEqual([item.context_id for item in contexts], ["ctx_1"])


if __name__ == "__main__":
    unittest.main()
