"""FastAPI 应用生命周期：启动时初始化基础设施与后台任务，关闭时逆序释放。

与 main.py 中的 lifespan 组合使用；内层可再嵌套 MCP（如 FastMCP）的 lifespan。
启动失败会将异常信息写入 app.state.startup_error，健康检查可据此暴露状态。
"""

from __future__ import annotations

from contextlib import AbstractAsyncContextManager, asynccontextmanager
from typing import AsyncIterator, Callable

from config.settings import AppConfig, init_app_config
from core.infra.db import (
    close_db_client,
    init_db_client,
)
from core.infra.eml import eml
from core.infra.pns import pns
from core.infra.redis import redis
from core.infra.s3 import s3
from core.infra.sms import sms
from fastapi import FastAPI
from loguru import logger
from services.apple_membership_reconcile import AppleMembershipReconcileWorker
from services.calendar_integrations import DingTalkCalendarStreamConsumer
from services.notification_delivery import NotificationDeliveryDispatcher


async def initialize_infra_resources(cfg: AppConfig):
    """Initialize shared infrastructure resources."""

    logger.info("正在初始化基础设施资源...")
    db_manager = await init_db_client(cfg)
    logger.info("数据库客户端初始化成功。")
    await db_manager.initialize_schema()
    logger.info("数据库表结构初始化成功。")
    await redis.init(cfg)
    logger.info("Redis 客户端初始化成功。")
    await eml.init(cfg)
    logger.info("邮件客户端初始化成功。")
    await pns.init(cfg)
    logger.info("号码认证客户端初始化成功。")
    await sms.init(cfg)
    logger.info("短信客户端初始化成功。")
    s3_client = await s3.init(cfg)
    if s3_client:
        logger.info("S3 对象存储客户端初始化成功。")
    elif (cfg.s3_bucket or "").strip():
        logger.warning("S3 对象存储客户端初始化返回 None。")


async def shutdown_infra_resources() -> None:
    """Shutdown shared infrastructure resources."""

    await close_db_client()
    await redis.close()
    await eml.close()
    await pns.close()
    await sms.close()
    await s3.close()


def _start_background_services(app_instance: FastAPI, cfg: AppConfig) -> None:
    notification_dispatcher = NotificationDeliveryDispatcher(cfg)
    notification_dispatcher.start()
    app_instance.state.notification_dispatcher = notification_dispatcher

    dingtalk_stream_consumer = DingTalkCalendarStreamConsumer(cfg)
    dingtalk_stream_consumer.start()
    app_instance.state.dingtalk_stream_consumer = dingtalk_stream_consumer

    apple_membership_reconcile_worker = AppleMembershipReconcileWorker(cfg)
    apple_membership_reconcile_worker.start()
    app_instance.state.apple_membership_reconcile_worker = (
        apple_membership_reconcile_worker
    )


async def _stop_background_services(app_instance: FastAPI) -> None:
    apple_membership_reconcile_worker = getattr(
        app_instance.state,
        "apple_membership_reconcile_worker",
        None,
    )
    if apple_membership_reconcile_worker is not None:
        await apple_membership_reconcile_worker.stop()

    dingtalk_stream_consumer = getattr(
        app_instance.state,
        "dingtalk_stream_consumer",
        None,
    )
    if dingtalk_stream_consumer is not None:
        await dingtalk_stream_consumer.stop()

    notification_dispatcher = getattr(
        app_instance.state,
        "notification_dispatcher",
        None,
    )
    if notification_dispatcher is not None:
        await notification_dispatcher.stop()


def build_app_lifespan(
    nested_lifespan: Callable[[FastAPI], AbstractAsyncContextManager[None]] | None = None,
):
    """构造 FastAPI lifespan：startup 初始化资源与后台循环，shutdown 停止并清理。"""

    @asynccontextmanager
    async def lifespan(app_instance: FastAPI) -> AsyncIterator[None]:
        app_instance.state.startup_error = None
        app_instance.state.startup_config = None

        try:
            logger.info("应用启动中...")
            startup_cfg = init_app_config()
            app_instance.state.startup_config = startup_cfg
            await initialize_infra_resources(startup_cfg)
            _start_background_services(app_instance, startup_cfg)
            logger.info("应用启动完成。")
        except Exception as exc:
            logger.exception("应用启动失败")
            app_instance.state.startup_error = str(exc)
            raise

        try:
            # 请求处理阶段：可选嵌套 MCP 等子应用的 lifespan
            if nested_lifespan is None:
                yield
            else:
                async with nested_lifespan(app_instance):
                    yield
        finally:
            logger.info("应用关闭中...")
            await _stop_background_services(app_instance)
            await shutdown_infra_resources()
            logger.info("应用关闭完成。")

    return lifespan
