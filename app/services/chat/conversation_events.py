"""Redis Stream backed conversation change events."""

from __future__ import annotations

import json
from collections.abc import AsyncIterator
from dataclasses import dataclass
from typing import Any

from core.infra.redis import redis

_STREAM_MAXLEN = 1000
_DEFAULT_BLOCK_MS = 25_000


def _is_redis_timeout(error: Exception) -> bool:
    error_type = type(error)
    return error_type.__name__ == "TimeoutError" and error_type.__module__.startswith("redis")


@dataclass(frozen=True)
class ConversationEntryChangedEvent:
    session_id: str
    entry_id: str
    message_id: str | None
    created_at: str | None
    reason: str
    payload: dict[str, Any] | None = None

    def to_stream_fields(self) -> dict[str, str]:
        fields = {
            "session_id": self.session_id,
            "entry_id": self.entry_id,
            "message_id": self.message_id or "",
            "created_at": self.created_at or "",
            "reason": self.reason,
        }
        if self.payload is not None:
            fields["payload"] = json.dumps(self.payload, ensure_ascii=False)
        return fields

    def to_sse_payload(self) -> dict[str, Any]:
        if self.payload is not None:
            return self.payload
        return self.to_stream_fields()

    @classmethod
    def from_stream_fields(cls, fields: dict[Any, Any]) -> "ConversationEntryChangedEvent":
        def read(name: str) -> str:
            value = fields.get(name)
            if value is None:
                value = fields.get(name.encode("utf-8"))
            if isinstance(value, bytes):
                value = value.decode("utf-8")
            return str(value or "").strip()

        message_id = read("message_id")
        created_at = read("created_at")
        raw_payload = read("payload")
        payload: dict[str, Any] | None = None
        if raw_payload:
            decoded = json.loads(raw_payload)
            if isinstance(decoded, dict):
                payload = decoded
        return cls(
            session_id=read("session_id"),
            entry_id=read("entry_id"),
            message_id=message_id or None,
            created_at=created_at or None,
            reason=read("reason") or "conversation_entry_changed",
            payload=payload,
        )


def conversation_events_stream_key(user_id: str) -> str:
    return redis.key("chat", "conversation_events", user_id)


async def publish_conversation_entry_changed(
    *,
    user_id: str,
    session_id: str,
    entry_id: str,
    message_id: str | None = None,
    created_at: str | None = None,
    reason: str = "conversation_entry_changed",
    payload: dict[str, Any] | None = None,
) -> str:
    event = ConversationEntryChangedEvent(
        session_id=session_id,
        entry_id=entry_id,
        message_id=message_id,
        created_at=created_at,
        reason=reason,
        payload=payload,
    )
    return await redis.stream_add(
        conversation_events_stream_key(user_id),
        event.to_stream_fields(),
        maxlen=_STREAM_MAXLEN,
        approximate=True,
    )


async def stream_conversation_events(
    *,
    user_id: str,
    last_event_id: str | None = None,
    block_ms: int = _DEFAULT_BLOCK_MS,
) -> AsyncIterator[tuple[str | None, ConversationEntryChangedEvent | None]]:
    cursor = (last_event_id or "$").strip() or "$"
    stream_key = conversation_events_stream_key(user_id)
    while True:
        try:
            response = await redis.stream_read(
                {stream_key: cursor},
                count=10,
                block=max(1, int(block_ms)),
            )
        except Exception as error:
            if not _is_redis_timeout(error):
                raise
            yield None, None
            continue
        if not response:
            yield None, None
            continue
        for _, entries in response:
            for stream_id, fields in entries:
                cursor = (
                    stream_id.decode("utf-8") if isinstance(stream_id, bytes) else str(stream_id)
                )
                yield cursor, ConversationEntryChangedEvent.from_stream_fields(fields)
