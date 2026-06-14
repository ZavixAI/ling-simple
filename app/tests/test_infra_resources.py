from __future__ import annotations

import unittest
from unittest.mock import AsyncMock, Mock, patch

import lifecycle
from lifecycle import initialize_infra_resources


class InfraResourcesTests(unittest.IsolatedAsyncioTestCase):
    async def test_initialize_infra_resources_initializes_database_schema(self) -> None:
        cfg = Mock()
        cfg.s3_bucket = ""
        db_manager = Mock()
        db_manager.initialize_schema = AsyncMock()

        with (
            patch(
                "lifecycle.init_db_client",
                new=AsyncMock(return_value=db_manager),
            ) as init_db_client,
            patch.object(lifecycle.redis, "init", new=AsyncMock()) as redis_init,
            patch.object(lifecycle.eml, "init", new=AsyncMock()) as init_eml_client,
            patch.object(lifecycle.pns, "init", new=AsyncMock()) as init_pns_client,
            patch.object(
                lifecycle.s3,
                "init",
                new=AsyncMock(return_value=None),
            ) as init_s3_client,
        ):
            await initialize_infra_resources(cfg)

        init_db_client.assert_awaited_once_with(cfg)
        db_manager.initialize_schema.assert_awaited_once_with()
        redis_init.assert_awaited_once_with(cfg)
        init_eml_client.assert_awaited_once_with(cfg)
        init_pns_client.assert_awaited_once_with(cfg)
        init_s3_client.assert_awaited_once_with(cfg)


if __name__ == "__main__":
    unittest.main()
