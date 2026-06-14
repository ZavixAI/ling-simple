"""Request-scoped user context."""

from __future__ import annotations

from contextvars import ContextVar
from typing import Optional

_user_context: ContextVar[dict[str, Optional[str]] | None] = ContextVar(
    "user_context",
    default=None,
)


def clear_user_context() -> None:
    """Clear the current user context."""

    _user_context.set({})


def set_user_context(
    *,
    user_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
) -> None:
    """Store user-scoped request information."""

    _user_context.set(
        {
            "user_id": user_id,
            "tenant_id": tenant_id,
        }
    )


def get_user_context() -> dict[str, Optional[str]]:
    """Return the current user context."""

    return dict(_user_context.get() or {})


def get_current_user_id() -> Optional[str]:
    """Return the current user id."""

    return get_user_context().get("user_id")


def get_current_tenant_id() -> Optional[str]:
    """Return the current tenant id."""

    return get_user_context().get("tenant_id")
