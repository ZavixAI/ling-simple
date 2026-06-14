from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

from config import constants


@dataclass(slots=True)
class MembershipProviderEvent:
    provider: str
    user_id: str
    internal_product_code: str | None = None
    provider_product_id: str | None = None
    external_transaction_id: str | None = None
    external_subscription_id: str | None = None
    order_no: str | None = None
    event_type: str = constants.PAYMENT_TRANSACTION_TYPE_PURCHASE
    status: str = constants.PAYMENT_TRANSACTION_STATUS_SUCCEEDED
    occurred_at: datetime | None = None
    expiration_at: datetime | None = None
    cancel_at_period_end: bool = False
    payload: dict[str, Any] = field(default_factory=dict)
