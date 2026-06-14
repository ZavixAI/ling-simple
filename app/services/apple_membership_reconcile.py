from __future__ import annotations

import asyncio

from config import constants
from config.settings import AppConfig
from core.http.context import background_request_context
from loguru import logger
from modules.membership.models import MembershipSubscriptionDao
from modules.membership.service import MembershipService

_APPLE_RECONCILE_INTERVAL_SECONDS = 6 * 60 * 60
_APPLE_RECONCILE_BATCH_SIZE = 50
_RECONCILABLE_STATUSES = [
    constants.MEMBERSHIP_STATUS_ACTIVE,
    constants.MEMBERSHIP_STATUS_CANCEL_SCHEDULED,
    constants.MEMBERSHIP_STATUS_PAYMENT_FAILED,
]


class AppleMembershipReconcileWorker:
    """Periodic best-effort reconciliation against App Store Server API."""

    def __init__(self, config: AppConfig) -> None:
        self._config = config
        self._subscription_dao = MembershipSubscriptionDao()
        self._membership_service = MembershipService()
        self._stop_event = asyncio.Event()
        self._task: asyncio.Task[None] | None = None

    def start(self) -> None:
        if not self._has_server_api_credentials():
            logger.info("[AppleMembershipReconcileWorker] App Store Server API 未配置，跳过启动")
            return
        if self._task is not None and not self._task.done():
            return
        self._stop_event.clear()
        self._task = asyncio.create_task(self._run_loop())
        logger.info("[AppleMembershipReconcileWorker] 已启动")

    async def stop(self) -> None:
        self._stop_event.set()
        if self._task is None:
            return
        await self._task
        self._task = None
        logger.info("[AppleMembershipReconcileWorker] 已停止")

    async def _run_loop(self) -> None:
        while not self._stop_event.is_set():
            with background_request_context("apple-membership-reconcile-tick"):
                try:
                    await self.tick()
                except Exception:
                    logger.exception("[AppleMembershipReconcileWorker] tick 执行失败")
            try:
                await asyncio.wait_for(
                    self._stop_event.wait(),
                    timeout=_APPLE_RECONCILE_INTERVAL_SECONDS,
                )
            except asyncio.TimeoutError:
                continue

    async def tick(self) -> int:
        subscriptions = await self._subscription_dao.list_provider_subscriptions(
            constants.PAYMENT_PROVIDER_APPLE,
            statuses=_RECONCILABLE_STATUSES,
            limit=_APPLE_RECONCILE_BATCH_SIZE,
        )
        reconciled = 0
        for subscription in subscriptions:
            transaction_id = (subscription.extra_data or {}).get("latest_transaction_id")
            if not isinstance(transaction_id, str) or not transaction_id.strip():
                continue
            try:
                await self._membership_service.reconcile_apple_transaction(
                    transaction_id.strip()
                )
                reconciled += 1
            except Exception:
                logger.warning(
                    "[AppleMembershipReconcileWorker] 订阅对账失败 "
                    f"subscription_id={subscription.subscription_id}"
                )
        if reconciled:
            logger.info(f"[AppleMembershipReconcileWorker] 已对账 {reconciled} 个 Apple 订阅")
        return reconciled

    def _has_server_api_credentials(self) -> bool:
        return bool(
            self._config.apple_app_store_server_api_issuer_id
            and self._config.apple_app_store_server_api_key_id
            and self._config.apple_app_store_server_api_private_key
        )
