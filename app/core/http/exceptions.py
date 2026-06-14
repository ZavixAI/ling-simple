"""Shared exception types and handlers."""

from __future__ import annotations

from typing import Any

from core.http.render import Response
from fastapi import HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from loguru import logger


class AppHTTPException(HTTPException):
    """Custom HTTP exception for application-level failures."""

    def __init__(
        self,
        status_code: int = 500,
        detail: str = "Internal Server Error",
        *,
        error_code: str | None = None,
        error_detail: Any | None = None,
    ) -> None:
        super().__init__(status_code=status_code, detail=detail)
        self.error_code = error_code
        self.error_detail = error_detail


def register_exception_handlers(app) -> None:
    """Register standardized exception handlers on the app."""

    async def handle_app_exception(request: Request, exc: AppHTTPException):
        payload = await Response.error(
            code=exc.status_code,
            message=exc.detail,
            data={
                "error_code": exc.error_code,
                "error_detail": exc.error_detail,
                "request_id": getattr(request.state, "request_id", None),
            },
        )
        return JSONResponse(status_code=exc.status_code, content=payload.model_dump())

    async def handle_http_exception(request: Request, exc: HTTPException):
        payload = await Response.error(
            code=exc.status_code,
            message=str(exc.detail),
            data={"request_id": getattr(request.state, "request_id", None)},
        )
        return JSONResponse(status_code=exc.status_code, content=payload.model_dump())

    async def handle_validation_exception(
        request: Request,
        exc: RequestValidationError,
    ):
        payload = await Response.error(
            code=422,
            message="Request validation failed",
            data={
                "errors": exc.errors(),
                "request_id": getattr(request.state, "request_id", None),
            },
        )
        return JSONResponse(status_code=422, content=payload.model_dump())

    async def handle_general_exception(request: Request, exc: Exception):
        logger.exception("未处理的应用异常")
        payload = await Response.error(
            code=500,
            message="Internal Server Error",
            data={"request_id": getattr(request.state, "request_id", None)},
        )
        return JSONResponse(status_code=500, content=payload.model_dump())

    app.add_exception_handler(AppHTTPException, handle_app_exception)
    app.add_exception_handler(HTTPException, handle_http_exception)
    app.add_exception_handler(RequestValidationError, handle_validation_exception)
    app.add_exception_handler(Exception, handle_general_exception)
