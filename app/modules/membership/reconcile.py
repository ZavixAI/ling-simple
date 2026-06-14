from __future__ import annotations

from modules.membership.models import MembershipStateDao, PaymentOrderDao
from modules.membership.service import MembershipService


class MembershipReconcileService:
    """Best-effort membership reconciliation hooks."""

    def __init__(self) -> None:
        self.membership_service = MembershipService()
        self.order_dao = PaymentOrderDao()
        self.state_dao = MembershipStateDao()

    async def reconcile_pending_orders(self, limit: int = 50) -> list[dict]:
        orders = await self.order_dao.list_pending_orders(limit=limit)
        return [
            {
                "order_no": order.order_no,
                "user_id": order.user_id,
                "provider": order.provider,
                "status": order.status,
            }
            for order in orders
        ]

    async def reconcile_user_state(self, user_id: str) -> dict:
        summary = await self.membership_service.build_summary(user_id)
        return summary.model_dump()

