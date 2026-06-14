from __future__ import annotations

import unittest
from typing import Any
from unittest.mock import patch

import core.infra.redis as redis_module
from services.chat.conversation_events import (
    publish_conversation_entry_changed,
    stream_conversation_events,
)

_RedisTimeoutError = type(
    "TimeoutError",
    (Exception,),
    {"__module__": "redis.exceptions"},
)


class _FakeRedis:
    def __init__(self) -> None:
        self.xadd_calls: list[dict[str, Any]] = []
        self.xread_calls: list[dict[str, Any]] = []
        self.xread_responses: list[Any] = []

    async def xadd(
        self,
        name: str,
        fields: dict[str, str],
        *,
        maxlen: int | None = None,
        approximate: bool = False,
    ) -> str:
        self.xadd_calls.append(
            {
                "name": name,
                "fields": fields,
                "maxlen": maxlen,
                "approximate": approximate,
            }
        )
        return "1-0"

    async def xread(
        self,
        streams: dict[str, str],
        *,
        count: int | None = None,
        block: int | None = None,
    ) -> Any:
        self.xread_calls.append({"streams": streams, "count": count, "block": block})
        if self.xread_responses:
            response = self.xread_responses.pop(0)
            if isinstance(response, BaseException):
                raise response
            return response
        return []


class ConversationEventsTests(unittest.IsolatedAsyncioTestCase):
    async def test_publish_writes_trimmed_stream_event(self) -> None:
        redis = _FakeRedis()

        with patch.object(redis_module.redis, "_client", redis):
            stream_id = await publish_conversation_entry_changed(
                user_id="user-1",
                session_id="session-1",
                entry_id="entry-1",
                message_id="message-1",
                created_at="2026-05-07T10:00:00+00:00",
                reason="assistant_message",
            )

        self.assertEqual(stream_id, "1-0")
        self.assertEqual(redis.xadd_calls[0]["name"], "ling:chat:conversation_events:user-1")
        self.assertEqual(redis.xadd_calls[0]["maxlen"], 1000)
        self.assertTrue(redis.xadd_calls[0]["approximate"])
        self.assertEqual(
            redis.xadd_calls[0]["fields"],
            {
                "session_id": "session-1",
                "entry_id": "entry-1",
                "message_id": "message-1",
                "created_at": "2026-05-07T10:00:00+00:00",
                "reason": "assistant_message",
            },
        )

    async def test_publish_can_include_direct_payload(self) -> None:
        redis = _FakeRedis()

        with patch.object(redis_module.redis, "_client", redis):
            await publish_conversation_entry_changed(
                user_id="user-1",
                session_id="session-1",
                entry_id="entry-1",
                reason="agent_run_entry",
                payload={
                    "type": "conversation_entry",
                    "op": "upsert",
                    "session_id": "session-1",
                    "run_id": "run-1",
                    "item": {"id": "entry-1", "text": "hello"},
                },
            )

        self.assertIn("payload", redis.xadd_calls[0]["fields"])

    async def test_stream_reads_from_last_event_id_and_yields_heartbeat(self) -> None:
        redis = _FakeRedis()
        redis.xread_responses = [
            [
                (
                    "ling:chat:conversation_events:user-1",
                    [
                        (
                            "2-0",
                            {
                                "session_id": "session-1",
                                "entry_id": "entry-1",
                                "message_id": "",
                                "created_at": "",
                                "reason": "assistant_message",
                            },
                        )
                    ],
                )
            ],
            [],
        ]

        with patch.object(redis_module.redis, "_client", redis):
            events = stream_conversation_events(
                user_id="user-1",
                last_event_id="1-0",
                block_ms=1,
            )
            first_id, first_event = await events.__anext__()
            heartbeat_id, heartbeat_event = await events.__anext__()

        self.assertEqual(first_id, "2-0")
        assert first_event is not None
        self.assertEqual(first_event.session_id, "session-1")
        self.assertIsNone(heartbeat_id)
        self.assertIsNone(heartbeat_event)
        self.assertEqual(
            redis.xread_calls[0]["streams"],
            {"ling:chat:conversation_events:user-1": "1-0"},
        )
        self.assertEqual(
            redis.xread_calls[1]["streams"],
            {"ling:chat:conversation_events:user-1": "2-0"},
        )

    async def test_stream_timeout_yields_heartbeat(self) -> None:
        redis = _FakeRedis()
        redis.xread_responses = [_RedisTimeoutError("timeout")]

        with patch.object(redis_module.redis, "_client", redis):
            events = stream_conversation_events(
                user_id="user-1",
                last_event_id="1-0",
                block_ms=1,
            )
            heartbeat_id, heartbeat_event = await events.__anext__()

        self.assertIsNone(heartbeat_id)
        self.assertIsNone(heartbeat_event)
