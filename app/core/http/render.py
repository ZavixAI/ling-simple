"""Standard API response models."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from core.http.case import to_snake_case_data
from pydantic import BaseModel, Field


class StandardResponse(BaseModel):
    """Shared API response envelope."""

    code: int = 200
    message: str = "success"
    data: Any | None = None
    timestamp: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )


class Response:
    """Response builders used by routers and handlers."""

    @staticmethod
    async def success(
        message: str = "success",
        data: Any | None = None,
        code: int = 200,
    ) -> StandardResponse:
        return StandardResponse(
            code=code,
            message=message,
            data=to_snake_case_data(data),
        )

    @staticmethod
    async def error(
        code: int = 500,
        message: str = "operation failed",
        data: Any | None = None,
    ) -> StandardResponse:
        return StandardResponse(
            code=code,
            message=message,
            data=to_snake_case_data(data),
        )
