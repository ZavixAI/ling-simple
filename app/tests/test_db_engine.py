from __future__ import annotations

import unittest

from core.infra.db import _configure_aiomysql_pre_ping
from sqlalchemy.ext.asyncio import create_async_engine


class DatabaseEngineTests(unittest.TestCase):
    def test_aiomysql_pre_ping_passes_reconnect_false(self) -> None:
        engine = create_async_engine("mysql+aiomysql://user:pass@127.0.0.1:3306/db")
        seen_ping_args: list[bool] = []

        class Connection:
            def ping(self, reconnect: bool) -> None:
                seen_ping_args.append(reconnect)

        try:
            engine.sync_engine.dialect._send_false_to_ping = False

            _configure_aiomysql_pre_ping(engine)
            engine.sync_engine.dialect.do_ping(Connection())

            self.assertIs(engine.sync_engine.dialect._send_false_to_ping, True)
            self.assertEqual(seen_ping_args, [False])
        finally:
            engine.sync_engine.dispose()


if __name__ == "__main__":
    unittest.main()
