"""
ORM 模型基类与通用 DAO
"""

from contextlib import asynccontextmanager
from datetime import datetime
from typing import Any, Optional, Sequence, Type

from core.infra.db import db_retry
from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import DeclarativeBase
from utils.time import utc_now_naive


def get_local_now() -> datetime:
    """Returns the current UTC time as a naive datetime object for DB storage."""
    return utc_now_naive()


class Base(DeclarativeBase):
    pass


class BaseDao:
    """基础DAO类"""

    def __init__(self):
        self.db = None

    async def _get_db(self):
        if self.db is not None:
            return self.db
        
        from core.infra.db import get_global_db
        self.db = await get_global_db()
        return self.db

    @asynccontextmanager
    async def _session_scope(
        self,
        *,
        session: AsyncSession | None = None,
        autocommit: bool = True,
    ):
        if session is not None:
            yield session
            return

        db = await self._get_db()
        async with db.get_session(autocommit=autocommit) as managed_session:
            yield managed_session

    async def _execute_statement(
        self,
        stmt: Any,
        *,
        session: AsyncSession | None = None,
    ) -> Any:
        async with self._session_scope(session=session) as active_session:
            return await active_session.execute(stmt)

    async def insert(
        self,
        obj: Any,
        *,
        session: AsyncSession | None = None,
    ) -> None:
        """插入对象"""
        async with self._session_scope(session=session) as active_session:
            active_session.add(obj)

    async def batch_insert(
        self,
        objs: Sequence[Any],
        *,
        session: AsyncSession | None = None,
    ) -> None:
        """批量插入对象"""
        if not objs:
            return
        async with self._session_scope(session=session) as active_session:
            active_session.add_all(list(objs))

    async def save(
        self,
        obj: Any,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        """保存对象"""
        async with self._session_scope(session=session) as active_session:
            await active_session.merge(obj)
            return True

    @db_retry()
    async def get_by_id(
        self,
        model: Type[Any],
        pk: Any,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[Any]:
        """根据主键查询对象"""
        async with self._session_scope(session=session) as active_session:
            return await active_session.get(model, pk)

    async def delete_by_id(
        self,
        model: Type[Any],
        pk: Any,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        """根据主键删除对象"""
        async with self._session_scope(session=session) as active_session:
            obj = await active_session.get(model, pk)
            if obj:
                await active_session.delete(obj)
                return True
            return False

    @db_retry()
    async def get_all(
        self, 
        model: Type[Any], 
        order_by: Any | None = None,
        options: Sequence[Any] | None = None,
        session: AsyncSession | None = None,
    ) -> list[Any]:
        """查询所有对象"""
        async with self._session_scope(session=session) as active_session:
            stmt = select(model)
            if options:
                for opt in options:
                    stmt = stmt.options(opt)
            if order_by is not None:
                stmt = stmt.order_by(order_by)
            res = await active_session.execute(stmt)
            return list(res.scalars().all())

    @db_retry()
    async def get_list(
        self,
        model: Type[Any],
        where: Sequence[Any] | None = None,
        order_by: Any | None = None,
        limit: int | None = None,
        options: Sequence[Any] | None = None,
        session: AsyncSession | None = None,
    ) -> list[Any]:
        """查询对象列表"""
        async with self._session_scope(session=session) as active_session:
            stmt = select(model)
            if options:
                for opt in options:
                    stmt = stmt.options(opt)
            if where:
                for cond in where:
                    stmt = stmt.where(cond)
            if order_by is not None:
                stmt = stmt.order_by(order_by)
            if limit is not None:
                stmt = stmt.limit(limit)
            res = await active_session.execute(stmt)
            return list(res.scalars().all())

    @db_retry()
    async def get_first(
        self,
        model: Type[Any],
        where: Sequence[Any] | None = None,
        order_by: Any | None = None,
        options: Sequence[Any] | None = None,
        session: AsyncSession | None = None,
    ) -> Optional[Any]:
        """查询第一个对象"""
        async with self._session_scope(session=session) as active_session:
            stmt = select(model)
            if options:
                for opt in options:
                    stmt = stmt.options(opt)
            if where:
                for cond in where:
                    stmt = stmt.where(cond)
            if order_by is not None:
                stmt = stmt.order_by(order_by)
            stmt = stmt.limit(1)
            res = await active_session.execute(stmt)
            return res.scalars().first()

    @db_retry()
    async def count(
        self,
        model: Type[Any],
        where: Sequence[Any] | None = None,
        *,
        session: AsyncSession | None = None,
    ) -> int:
        """查询对象数量"""
        async with self._session_scope(session=session) as active_session:
            stmt = select(func.count()).select_from(model)
            if where:
                for cond in where:
                    stmt = stmt.where(cond)
            res = await active_session.execute(stmt)
            return int(res.scalar() or 0)

    @db_retry()
    async def paginate_list(
        self,
        model: Type[Any],
        where: Sequence[Any] | None = None,
        order_by: Any | None = None,
        page: int = 1,
        page_size: int = 20,
        session: AsyncSession | None = None,
    ) -> tuple[list[Any], int]:
        """分页查询对象列表"""
        async with self._session_scope(session=session) as active_session:
            base_stmt = select(model)
            if where:
                for cond in where:
                    base_stmt = base_stmt.where(cond)
            count_stmt = select(func.count()).select_from(base_stmt.subquery())
            total = int((await active_session.execute(count_stmt)).scalar() or 0)
            if order_by is not None:
                if isinstance(order_by, tuple):
                    base_stmt = base_stmt.order_by(*order_by)
                else:
                    base_stmt = base_stmt.order_by(order_by)
            base_stmt = base_stmt.offset((page - 1) * page_size).limit(page_size)
            res = await active_session.execute(base_stmt)
            return list(res.scalars().all()), total

    async def update_where(
        self,
        model: Type[Any],
        where: Sequence[Any],
        values: dict,
        *,
        session: AsyncSession | None = None,
    ) -> None:
        """根据条件更新对象"""
        async with self._session_scope(session=session) as active_session:
            stmt = update(model)
            for cond in where or []:
                stmt = stmt.where(cond)
            await active_session.execute(stmt.values(**values))

    async def delete_where(
        self,
        model: Type[Any],
        where: Sequence[Any],
        *,
        session: AsyncSession | None = None,
    ) -> None:
        """根据条件删除对象"""
        async with self._session_scope(session=session) as active_session:
            stmt = delete(model)
            for cond in where or []:
                stmt = stmt.where(cond)
            await active_session.execute(stmt)
