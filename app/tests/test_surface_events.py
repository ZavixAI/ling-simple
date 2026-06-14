from __future__ import annotations

import unittest
from typing import Any
from unittest.mock import patch

import core.infra.redis as redis_module
from services.surface_events import publish_surface_changed


class _FakeRedis:
    def __init__(self) -> None:
        self.xadd_calls: list[dict[str, Any]] = []

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


class SurfaceEventsTests(unittest.IsolatedAsyncioTestCase):
    async def test_publish_surface_changed_writes_typed_payload(self) -> None:
        redis = _FakeRedis()

        with patch.object(redis_module.redis, "_client", redis):
            await publish_surface_changed(
                user_id="user-1",
                surface="calendar",
                item_id="evt_1",
                operation="updated",
            )

        fields = redis.xadd_calls[0]["fields"]
        self.assertEqual(fields["session_id"], "")
        self.assertEqual(fields["entry_id"], "evt_1")
        self.assertEqual(fields["reason"], "calendar_changed")
        self.assertIn('"type": "calendar_changed"', fields["payload"])
        self.assertIn('"surface": "calendar"', fields["payload"])
        self.assertIn('"operation": "updated"', fields["payload"])


if __name__ == "__main__":
    unittest.main()
