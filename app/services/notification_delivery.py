"""通知投递后台循环：按配置间隔轮询到期通知并交给 NotificationService 批量发送。

在 lifecycle 启动时 start()，关闭时 stop()；单例挂在 app.state.notification_dispatcher。
"""

from __future__ import annotations

import asyncio

from config.settings import AppConfig
from core.http.context import background_request_context
from loguru import logger
from services.notification import NotificationService


class NotificationDeliveryDispatcher:
    """asyncio 后台任务：wait_for(stop_event, timeout=interval) 实现可中断的固定周期调度。"""

    def __init__(self, config: AppConfig) -> None:
        self._config = config
        self._service = NotificationService(config)
        self._stop_event = asyncio.Event()
        self._task: asyncio.Task[None] | None = None

    def start(self) -> None:
        """启动后台投递循环（幂等：已在跑则忽略）。"""
        if self._task is not None and not self._task.done():
            return
        self._stop_event.clear()
        self._task = asyncio.create_task(self._run_loop())

    async def stop(self) -> None:
        self._stop_event.set()
        if self._task is None:
            return
        await self._task
        self._task = None

    async def _run_loop(self) -> None:
        # 间隔与批量来自 AppConfig，避免硬编码；异常只打日志不退出循环
        interval = max(5, self._config.notification_dispatch_interval_seconds)
        batch_size = max(1, self._config.notification_dispatch_batch_size)
        while not self._stop_event.is_set():
            with background_request_context("notification-delivery-tick"):
                try:
                    dispatched = await self._service.dispatch_due_notifications(
                        limit=batch_size,
                    )
                    if dispatched > 0:
                        logger.info(
                            f"[NotificationDeliveryDispatcher] 已投递 {dispatched} 条通知。"
                        )
                except Exception:
                    logger.exception("[NotificationDeliveryDispatcher] 投递通知失败。")
            try:
                await asyncio.wait_for(self._stop_event.wait(), timeout=interval)
            except asyncio.TimeoutError:
                continue
