"""Reusable request dependencies."""

from __future__ import annotations

from core.http.exceptions import AppHTTPException
from core.http.user_context import set_user_context
from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from loguru import logger
from models.user import User
from services.auth.state_store import RedisAccessTokenState, RedisAuthStateStore
from services.auth.tokens import hash_token, is_opaque_access_token
from services.admin_auth import AdminAuthService

bearer_scheme = HTTPBearer(auto_error=False)
_BEARER_CREDENTIALS_DEPENDENCY = Depends(bearer_scheme)


async def require_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = _BEARER_CREDENTIALS_DEPENDENCY,
) -> User:
    """Resolve and attach the authenticated user."""

    if credentials is None or not credentials.credentials:
        raise AppHTTPException(status_code=401, detail="Unauthorized")

    access_token = credentials.credentials.strip()
    if not is_opaque_access_token(access_token):
        raise AppHTTPException(status_code=401, detail="Invalid token")
    return await _require_opaque_access_token_user(request, access_token)


async def _require_opaque_access_token_user(
    request: Request,
    access_token: str,
) -> User:
    try:
        token_state = await RedisAuthStateStore().get_access_token(
            hash_token(access_token),
        )
    except Exception as exc:
        logger.warning("[AuthDependency] 读取 access token session 失败: {}", exc)
        raise AppHTTPException(status_code=401, detail="Invalid token") from exc

    if token_state is None:
        raise AppHTTPException(status_code=401, detail="Token expired or revoked")
    if not token_state.user_id or not token_state.device_id:
        raise AppHTTPException(status_code=401, detail="Invalid token payload")
    if token_state.extra_data.get("typ") == "admin":
        raise AppHTTPException(status_code=401, detail="Invalid token")

    user = _user_from_access_token_state(token_state)
    claims = {
        "sub": token_state.user_id,
        "provider_id": token_state.provider_id,
        "scope": token_state.scope,
        "device_id": token_state.device_id,
        "token_id": token_state.token_id,
    }
    request.state.user_claims = claims
    set_user_context(user_id=token_state.user_id)
    return user


def _user_from_access_token_state(token_state: RedisAccessTokenState) -> User:
    user_data = dict(token_state.user_data or {})
    username = str(user_data.get("username") or token_state.user_id).strip()
    if not username:
        raise AppHTTPException(status_code=401, detail="Invalid token payload")
    return User(
        user_id=token_state.user_id,
        username=username,
        password_hash="",
        nickname=user_data.get("nickname"),
        email=user_data.get("email"),
        phonenum=user_data.get("phonenum"),
        phone_area_code=user_data.get("phone_area_code"),
        role=str(user_data.get("role") or "user"),
        avatar_url=user_data.get("avatar_url"),
    )


async def require_current_admin(
    credentials: HTTPAuthorizationCredentials | None = _BEARER_CREDENTIALS_DEPENDENCY,
) -> dict:
    if credentials is None or not credentials.credentials:
        raise AppHTTPException(status_code=401, detail="Unauthorized")
    return await AdminAuthService().parse_admin_token(credentials.credentials.strip())
