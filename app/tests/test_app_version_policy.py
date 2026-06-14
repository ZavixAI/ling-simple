from __future__ import annotations

import os
import tempfile
import unittest
from importlib import util
from pathlib import Path
from unittest.mock import patch

import httpx
from config.settings import build_app_config, init_app_config
from fastapi import FastAPI

_ROUTER_MODULE_PATH = Path(__file__).resolve().parents[1] / "api" / "routers" / "app.py"
_ROUTER_SPEC = util.spec_from_file_location("app_version_policy_router", _ROUTER_MODULE_PATH)
if _ROUTER_SPEC is None or _ROUTER_SPEC.loader is None:
    raise RuntimeError("Unable to load app version policy router")
_ROUTER_MODULE = util.module_from_spec(_ROUTER_SPEC)
_ROUTER_SPEC.loader.exec_module(_ROUTER_MODULE)
app_router = _ROUTER_MODULE.router


class AppVersionPolicyConfigTests(unittest.TestCase):
    def test_build_app_config_reads_version_policy_env(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            env = {
                "LING_LOGS_DIR": os.path.join(tmpdir, "logs"),
                "LING_MIN_IOS_VERSION": "1.2.3",
                "LING_IOS_APP_STORE_URL": "https://example.com/app",
            }

            with patch.dict(os.environ, env, clear=True):
                cfg = build_app_config()

        self.assertEqual(cfg.min_ios_version, "1.2.3")
        self.assertEqual(
            cfg.ios_app_store_url,
            "https://testflight.apple.com/join/JfEr7hyq",
        )


class AppVersionPolicyRouterTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        app = FastAPI()
        app.include_router(app_router, prefix="/ling-api")
        self.app = app

    async def _get_policy(self, platform: str, version: str) -> dict:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=self.app),
            base_url="http://testserver",
        ) as client:
            response = await client.get(
                "/ling-api/app/version-policy",
                params={"platform": platform, "version": version},
            )

        self.assertEqual(response.status_code, 200)
        return response.json()["data"]

    async def test_returns_tool_labels_for_requested_locale(self) -> None:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=self.app),
            base_url="http://testserver",
        ) as client:
            response = await client.get(
                "/ling-api/app/tool-labels",
                params={"locale": "zh-CN"},
            )

        self.assertEqual(response.status_code, 200)
        data = response.json()["data"]
        self.assertEqual(data["locale"], "zh")
        self.assertTrue(data["version"].startswith("mcp-tool-labels-"))
        self.assertEqual(
            data["labels"]["travel_flight_search"],
            "查询航班",
        )

    async def test_requires_update_when_ios_version_is_below_minimum(self) -> None:
        init_app_config(min_ios_version="1.0.2")

        data = await self._get_policy("ios", "1.0.1+2026041101")

        self.assertEqual(data["current_version"], "1.0.1")
        self.assertEqual(data["current_build"], 2026041101)
        self.assertEqual(data["minimum_version"], "1.0.2")
        self.assertEqual(data["minimum_build"], 0)
        self.assertTrue(data["update_required"])
        self.assertEqual(data["update_url"], "https://testflight.apple.com/join/JfEr7hyq")
        self.assertEqual(data["app_store_url"], "https://testflight.apple.com/join/JfEr7hyq")

    async def test_requires_update_when_ios_build_is_below_minimum(self) -> None:
        init_app_config(min_ios_version="1.0.2+2026060101")

        data = await self._get_policy("ios", "1.0.2+2026060100")

        self.assertEqual(data["current_version"], "1.0.2")
        self.assertEqual(data["current_build"], 2026060100)
        self.assertEqual(data["minimum_version"], "1.0.2")
        self.assertEqual(data["minimum_build"], 2026060101)
        self.assertTrue(data["update_required"])

    async def test_allows_ios_version_at_or_above_minimum(self) -> None:
        init_app_config(min_ios_version="1.0.2+10")

        equal_data = await self._get_policy("ios", "1.0.2+10")
        newer_data = await self._get_policy("ios", "1.1.0")

        self.assertFalse(equal_data["update_required"])
        self.assertFalse(newer_data["update_required"])

    async def test_allows_non_ios_platforms(self) -> None:
        init_app_config(min_ios_version="9.9.9")

        data = await self._get_policy("web", "1.0.1")

        self.assertEqual(data["platform"], "web")
        self.assertEqual(data["minimum_version"], "0.0.0")
        self.assertFalse(data["update_required"])


if __name__ == "__main__":
    unittest.main()
