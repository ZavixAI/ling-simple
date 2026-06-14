"""Health check routes."""

from __future__ import annotations

from config.settings import get_app_config
from core.http.render import Response
from core.metrics import metrics
from fastapi import APIRouter, Request
from fastapi.responses import PlainTextResponse

router = APIRouter(tags=["health"])


@router.get("/health")
async def health_check(request: Request):
    """Return application readiness and startup state."""

    cfg = get_app_config()
    startup_error = getattr(request.app.state, "startup_error", None)

    data = {
        "status": "degraded" if startup_error else "ok",
        "app_name": cfg.app_name,
        "request_id": getattr(request.state, "request_id", None),
        "startup_error": startup_error,
    }
    return await Response.success(data=data)


@router.get("/metrics")
async def metrics_snapshot() -> PlainTextResponse:
    return PlainTextResponse(
        metrics.render_prometheus(),
        media_type="text/plain; version=0.0.4",
    )
