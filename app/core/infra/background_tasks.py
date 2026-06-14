from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from typing import Any

from loguru import logger


class BackgroundTaskRunner:
    def __init__(
        self,
        name: str,
        *,
        max_concurrency: int = 4,
        max_pending: int = 64,
    ) -> None:
        self._name = str(name or "background").strip() or "background"
        self._max_pending = max(1, int(max_pending))
        self._semaphore = asyncio.Semaphore(max(1, int(max_concurrency)))
        self._pending_count = 0
        self._dedupe_keys: set[str] = set()

    def submit(
        self,
        *,
        task_name: str,
        coro_factory: Callable[[], Awaitable[None]],
        dedupe_key: str | None = None,
    ) -> bool:
        normalized_task_name = str(task_name or "task").strip() or "task"
        normalized_dedupe_key = str(dedupe_key or "").strip() or None
        if normalized_dedupe_key and normalized_dedupe_key in self._dedupe_keys:
            logger.debug(
                "[BackgroundTaskRunner] 跳过重复任务 "
                f"runner={self._name} task={normalized_task_name} key={normalized_dedupe_key}"
            )
            return False
        if self._pending_count >= self._max_pending:
            logger.warning(
                "[BackgroundTaskRunner] 待处理队列已满，丢弃任务 "
                f"runner={self._name} task={normalized_task_name} pending={self._pending_count}"
            )
            return False

        if normalized_dedupe_key:
            self._dedupe_keys.add(normalized_dedupe_key)
        self._pending_count += 1

        async def _runner() -> None:
            try:
                async with self._semaphore:
                    await coro_factory()
            finally:
                self._pending_count = max(0, self._pending_count - 1)
                if normalized_dedupe_key:
                    self._dedupe_keys.discard(normalized_dedupe_key)

        task_coro = _runner()
        try:
            asyncio.create_task(
                task_coro,
                name=f"{self._name}:{normalized_task_name}",
            )
        except RuntimeError:
            task_coro.close()
            self._pending_count = max(0, self._pending_count - 1)
            if normalized_dedupe_key:
                self._dedupe_keys.discard(normalized_dedupe_key)
            return False
        except Exception:
            task_coro.close()
            self._pending_count = max(0, self._pending_count - 1)
            if normalized_dedupe_key:
                self._dedupe_keys.discard(normalized_dedupe_key)
            raise
        return True

    def submit_call(
        self,
        coro_fn: Callable[..., Awaitable[None]],
        *args: Any,
        task_name: str | None = None,
        dedupe_key: str | None = None,
    ) -> bool:
        normalized_task_name = task_name or getattr(coro_fn, "__name__", "task")

        async def _run() -> None:
            try:
                await coro_fn(*args)
            except Exception as exc:
                logger.warning(
                    "[BackgroundTaskRunner] 后台任务执行失败 "
                    f"runner={self._name} task={normalized_task_name} "
                    f"error_type={type(exc).__name__} error={str(exc)[:500]}",
                    exc_info=True,
                )

        return self.submit(
            task_name=normalized_task_name,
            coro_factory=_run,
            dedupe_key=dedupe_key,
        )


class BackgroundTasksAdapter:
    def runner(
        self,
        name: str,
        *,
        max_concurrency: int = 4,
        max_pending: int = 64,
    ) -> BackgroundTaskRunner:
        return BackgroundTaskRunner(
            name,
            max_concurrency=max_concurrency,
            max_pending=max_pending,
        )


background_tasks = BackgroundTasksAdapter()
