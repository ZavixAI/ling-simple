"""API sub-router exports."""

from modules.membership.router import router as membership_router

from .admin import router as admin_router
from .agent import router as agent_router
from .app import router as app_router
from .auth import router as auth_router
from .calendar import router as calendar_router
from .health import router as health_router
from .integrations import router as integrations_router

__all__ = [
    "agent_router",
    "admin_router",
    "app_router",
    "auth_router",
    "calendar_router",
    "health_router",
    "integrations_router",
    "membership_router",
]
