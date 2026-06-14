from __future__ import annotations

import json
import unittest
from typing import Any
from unittest.mock import patch

import core.infra.redis as redis_module
from services.agent.run_state import AgentRunStateStore


class _FakeRedis:
    def __init__(self) -> None:
        self.values: dict[str, str] = {}
        self.ttls: dict[str, int] = {}

    async def set(
        self,
        key: str,
        value: str,
        *,
        ex: int | None = None,
        nx: bool = False,
    ) -> bool:
        if nx and key in self.values:
            return False
        self.values[key] = value
        if ex is not None:
            self.ttls[key] = ex
        return True

    async def get(self, key: str) -> str | None:
        return self.values.get(key)

    async def delete(self, key: str) -> int:
        existed = key in self.values
        self.values.pop(key, None)
        self.ttls.pop(key, None)
        return 1 if existed else 0

    async def eval(self, script: str, key_count: int, *args: Any) -> int:
        _ = script, key_count
        key = str(args[0])
        expected_client_run_id = str(args[1])
        payload = self.values.get(key)
        if payload is None:
            return 0
        decoded = json.loads(payload)
        if decoded["client_run_id"] != expected_client_run_id:
            return 0
        if len(args) >= 4:
            self.values[key] = str(args[2])
            self.ttls[key] = int(args[3])
            return 1
        await self.delete(key)
        return 1


class AgentRunStateStoreTests(unittest.IsolatedAsyncioTestCase):
    async def test_claim_sets_marker_and_conflicting_claim_reads_existing(self) -> None:
        redis = _FakeRedis()
        store = AgentRunStateStore(ttl_seconds=1800)

        with patch.object(redis_module.redis, "_client", redis):
            first = await store.claim(
                user_id="user-1",
                session_id="session-1",
                client_run_id="run-1",
            )
            second = await store.claim(
                user_id="user-1",
                session_id="session-1",
                client_run_id="run-2",
            )

        self.assertTrue(first.acquired)
        self.assertFalse(second.acquired)
        self.assertEqual(second.state.client_run_id, "run-1")
        self.assertEqual(redis.ttls["ling:agent:active_run:session-1"], 1800)

    async def test_same_client_claim_refreshes_existing_marker(self) -> None:
        redis = _FakeRedis()
        store = AgentRunStateStore(ttl_seconds=1200)

        with patch.object(redis_module.redis, "_client", redis):
            await store.claim(
                user_id="user-2",
                session_id="session-2",
                client_run_id="run-2",
            )
            second = await store.claim(
                user_id="user-2",
                session_id="session-2",
                client_run_id="run-2",
            )

        self.assertFalse(second.acquired)
        self.assertEqual(second.state.client_run_id, "run-2")
        self.assertEqual(redis.ttls["ling:agent:active_run:session-2"], 1200)

    async def test_delete_if_client_only_deletes_matching_marker(self) -> None:
        redis = _FakeRedis()
        store = AgentRunStateStore()

        with patch.object(redis_module.redis, "_client", redis):
            await store.claim(
                user_id="user-3",
                session_id="session-3",
                client_run_id="run-3",
            )
            skipped = await store.delete_if_client("session-3", "run-other")
            deleted = await store.delete_if_client("session-3", "run-3")

        self.assertEqual(skipped, 0)
        self.assertEqual(deleted, 1)
        self.assertNotIn("ling:agent:active_run:session-3", redis.values)


if __name__ == "__main__":
    unittest.main()
