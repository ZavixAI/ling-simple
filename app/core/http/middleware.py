"""HTTP middleware registration."""

from __future__ import annotations

import time

from config.settings import get_app_config
from core.http.context import clear_request_context, create_request_id, set_request_context
from core.http.user_context import clear_user_context
from core.metrics import metrics
from fastapi import Request
from fastapi.middleware.cors import CORSMiddleware
from loguru import logger

REQUEST_LOG_SUPPRESSED_PATHS = {
    "/ling-api/health",
}


def _metrics_path(request: Request) -> str:
    route = request.scope.get("route")
    route_path = getattr(route, "path", None)
    return route_path or request.url.path


def _record_http_metrics(
    request: Request,
    *,
    status_code: int,
    duration_ms: float,
    failed: bool = False,
) -> None:
    labels = {
        "method": request.method,
        "path": _metrics_path(request),
        "status": str(status_code),
    }
    metrics.inc_counter("ling_http_requests_total", labels=labels)
    metrics.observe("ling_http_request_duration_ms", duration_ms, labels=labels)
    if failed:
        metrics.inc_counter("ling_http_requests_failed_total", labels=labels)


def register_middlewares(app) -> None:
    """Register shared middlewares."""

    cfg = get_app_config()
    allow_origins = list(cfg.cors_origins) or ["*"]

    app.add_middleware(
        CORSMiddleware,
        allow_origins=allow_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.middleware("http")
    async def request_context_middleware(request: Request, call_next):
        request_id = create_request_id()
        request_logger = logger.bind(request_id=request_id)
        started_at = time.perf_counter()
        metrics_enabled = not request.url.path.endswith("/metrics")
        if metrics_enabled:
            metrics.inc_gauge("ling_http_inflight_requests")

        clear_request_context()
        clear_user_context()
        set_request_context(request_id, request_logger)

        request.state.request_id = request_id
        request.state.logger = request_logger

        try:
            response = await call_next(request)
        except Exception:
            duration_ms = round((time.perf_counter() - started_at) * 1000, 2)
            if metrics_enabled:
                _record_http_metrics(
                    request,
                    status_code=500,
                    duration_ms=duration_ms,
                    failed=True,
                )
            request_logger.exception(
                f"{request.method} {request.url.path} 处理失败，耗时 {duration_ms} ms"
            )
            raise
        else:
            duration_ms = round((time.perf_counter() - started_at) * 1000, 2)
            if metrics_enabled:
                _record_http_metrics(
                    request,
                    status_code=response.status_code,
                    duration_ms=duration_ms,
                    failed=response.status_code >= 500,
                )
            if request.url.path not in REQUEST_LOG_SUPPRESSED_PATHS:
                request_logger.info(
                    f"{request.method} {request.url.path} -> {response.status_code} ({duration_ms} ms)"
                )
            response.headers["X-Request-ID"] = request_id
            return response
        finally:
            if metrics_enabled:
                metrics.dec_gauge("ling_http_inflight_requests")
            clear_request_context()
            clear_user_context()
