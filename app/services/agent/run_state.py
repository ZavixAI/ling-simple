"""Redis-backed active Agent run markers."""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime
from typing import Any

from config import constants
from config.settings import AppConfig, get_app_config
from core.infra.redis import redis
from models.base import get_local_now

_DEFAULT_AGENT_RUN_TTL_SECONDS = 60 * 60


def _serialize_datetime(value: datetime | None) -> str | None:
    return value.isoformat() if value is not None else None


def _deserialize_datetime(value: str) -> datetime:
    return datetime.fromisoformat(value)


@dataclass(frozen=True)
class AgentRunState:
    session_id: str
    client_run_id: str
    user_id: str
    status: str
    started_at: datetime
    heartbeat_at: datetime

    def to_dict(self) -> dict[str, Any]:
        return {
            "session_id": self.session_id,
            "client_run_id": self.client_run_id,
            "user_id": self.user_id,
            "status": self.status,
            "started_at": _serialize_datetime(self.started_at),
            "heartbeat_at": _serialize_datetime(self.heartbeat_at),
        }

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), ensure_ascii=False)

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "AgentRunState":
        return cls(
            session_id=str(payload["session_id"]),
            client_run_id=str(payload["client_run_id"]),
            user_id=str(payload["user_id"]),
            status=str(payload["status"]),
            started_at=_deserialize_datetime(payload["started_at"]),
            heartbeat_at=_deserialize_datetime(payload["heartbeat_at"]),
        )


@dataclass(frozen=True)
class AgentRunClaim:
    acquired: bool
    state: AgentRunState


class AgentRunStateStore:
    """Store active run ownership in Redis so all workers share one view."""

    def __init__(
        self,
        cfg: AppConfig | None = None,
        *,
        ttl_seconds: int = _DEFAULT_AGENT_RUN_TTL_SECONDS,
    ) -> None:
        self.cfg = cfg or get_app_config()
        self.ttl_seconds = int(ttl_seconds)

    def _run_key(self, session_id: str) -> str:
        return redis.key("agent", "active_run", session_id)

    async def claim(
        self,
        *,
        user_id: str,
        session_id: str,
        client_run_id: str,
    ) -> AgentRunClaim:
        now = get_local_now()
        state = AgentRunState(
            session_id=session_id,
            client_run_id=client_run_id,
            user_id=user_id,
            status=constants.AGENT_RUN_STATUS_ACTIVE,
            started_at=now,
            heartbeat_at=now,
        )
        reserved = await redis.set_if_absent(
            self._run_key(session_id),
            state.to_json(),
            ex=self.ttl_seconds,
        )
        if reserved:
            return AgentRunClaim(acquired=True, state=state)

        existing = await self.get(session_id)
        if existing.client_run_id == client_run_id:
            refreshed = await self.heartbeat(session_id, client_run_id)
            return AgentRunClaim(acquired=False, state=refreshed)
        return AgentRunClaim(acquired=False, state=existing)

    async def get(self, session_id: str) -> AgentRunState | None:
        raw_payload = await redis.get(self._run_key(session_id))
        payload = json.loads(raw_payload) if raw_payload is not None else None
        if payload is None:
            return None
        return AgentRunState.from_dict(payload)

    async def heartbeat(
        self,
        session_id: str,
        client_run_id: str,
    ) -> AgentRunState | None:
        existing = await self.get(session_id)
        if existing is None or existing.client_run_id != client_run_id:
            return None
        refreshed = AgentRunState(
            session_id=existing.session_id,
            client_run_id=existing.client_run_id,
            user_id=existing.user_id,
            status=constants.AGENT_RUN_STATUS_ACTIVE,
            started_at=existing.started_at,
            heartbeat_at=get_local_now(),
        )
        updated = await redis.eval(
            """
local payload = redis.call("GET", KEYS[1])
if not payload then
  return 0
end
local decoded = cjson.decode(payload)
if decoded["client_run_id"] ~= ARGV[1] then
  return 0
end
redis.call("SET", KEYS[1], ARGV[2], "EX", ARGV[3])
return 1
""",
            1,
            self._run_key(session_id),
            client_run_id,
            refreshed.to_json(),
            str(self.ttl_seconds),
        )
        return refreshed if int(updated or 0) == 1 else None

    async def delete_if_client(self, session_id: str, client_run_id: str) -> int:
        deleted = await redis.eval(
            """
local payload = redis.call("GET", KEYS[1])
if not payload then
  return 0
end
local decoded = cjson.decode(payload)
if decoded["client_run_id"] ~= ARGV[1] then
  return 0
end
return redis.call("DEL", KEYS[1])
""",
            1,
            self._run_key(session_id),
            client_run_id,
        )
        return int(deleted or 0)

    async def delete(self, session_id: str) -> int:
        return await redis.delete(self._run_key(session_id))
