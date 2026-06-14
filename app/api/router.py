"""Top-level API router."""

from api.routers import (
    admin_router,
    agent_router,
    app_router,
    auth_router,
    calendar_router,
    health_router,
    integrations_router,
    membership_router,
)
from fastapi import APIRouter

# Backend API prefix is intentionally fixed to keep clients and docs aligned.
router = APIRouter(prefix="/ling-api")
router.include_router(app_router)
router.include_router(admin_router)
router.include_router(auth_router)
router.include_router(calendar_router)
router.include_router(integrations_router)
router.include_router(agent_router)
router.include_router(health_router)
router.include_router(membership_router)

__all__ = ["router"]
