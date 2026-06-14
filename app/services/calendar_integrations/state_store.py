"""第三方日历 Redis 状态：OAuth state 防 CSRF、同步触发防抖标记 CalendarSyncTriggerStore。"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

from config.settings import AppConfig, get_app_config
from core.infra.redis import redis
from models.base import get_local_now


def _serialize_datetime(value: datetime | None) -> str | None:
    return value.isoformat() if value is not None else None


def _deserialize_datetime(value: str | None) -> datetime | None:
    if not value:
        return None
    return datetime.fromisoformat(value)


@dataclass
class RedisCalendarOAuthState:
    state: str
    provider_id: str
    user_id: str
    redirect_uri: str
    callback_scheme: str
    created_at: datetime
    expire_at: datetime
    consumed_at: datetime | None = None
    extra_data: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "state": self.state,
            "provider_id": self.provider_id,
            "user_id": self.user_id,
            "redirect_uri": self.redirect_uri,
            "callback_scheme": self.callback_scheme,
            "created_at": _serialize_datetime(self.created_at),
            "expire_at": _serialize_datetime(self.expire_at),
            "consumed_at": _serialize_datetime(self.consumed_at),
            "extra_data": dict(self.extra_data or {}),
        }

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "RedisCalendarOAuthState":
        return cls(
            state=str(payload["state"]),
            provider_id=str(payload["provider_id"]),
            user_id=str(payload["user_id"]),
            redirect_uri=str(payload["redirect_uri"]),
            callback_scheme=str(payload["callback_scheme"]),
            created_at=_deserialize_datetime(payload.get("created_at")) or get_local_now(),
            expire_at=_deserialize_datetime(payload.get("expire_at")) or get_local_now(),
            consumed_at=_deserialize_datetime(payload.get("consumed_at")),
            extra_data=dict(payload.get("extra_data") or {}),
        )


class CalendarOAuthStateStore:
    def __init__(self, cfg: AppConfig | None = None) -> None:
        self.cfg = cfg or get_app_config()

    def _state_key(self, state: str) -> str:
        return redis.key("calendar", "oauth_state", state)

    async def save(self, state: RedisCalendarOAuthState) -> None:
        ttl_seconds = max(
            1,
            int((state.expire_at - get_local_now()).total_seconds()),
        )
        await redis.set_json(
            self._state_key(state.state),
            state.to_dict(),
            ex=ttl_seconds,
        )

    async def get(self, state: str) -> RedisCalendarOAuthState | None:
        payload = await redis.get_json(
            self._state_key(state),
            default=None,
        )
        if payload is None:
            return None
        return RedisCalendarOAuthState.from_dict(payload)

    async def delete(self, state: str) -> int:
        return await redis.delete(self._state_key(state))


class CalendarSyncTriggerStore:
    def __init__(self, cfg: AppConfig | None = None) -> None:
        self.cfg = cfg or get_app_config()

    def _trigger_key(self, provider_id: str, fingerprint: str) -> str:
        return redis.key("calendar", "trigger", provider_id, fingerprint)

    async def reserve(
        self,
        provider_id: str,
        fingerprint: str,
        *,
        ttl_seconds: int = 24 * 60 * 60,
    ) -> bool:
        normalized_provider = str(provider_id or "").strip().lower()
        normalized_fingerprint = str(fingerprint or "").strip()
        if not normalized_provider or not normalized_fingerprint:
            return False
        reserved = await redis.set_if_absent(
            self._trigger_key(normalized_provider, normalized_fingerprint),
            "1",
            ex=max(1, ttl_seconds),
        )
        return bool(reserved)
