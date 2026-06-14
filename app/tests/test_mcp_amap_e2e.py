"""位置服务 MCP 函数级端到端测试（真实 HTTPS）。

验证路径：``location_*`` MCP 工具 → 位置服务客户端 → 地图服务 API。不经 FastMCP HTTP 协议，与生产调用链一致。

默认 ``unittest.skip``，仅在显式开启且配置了 Key 时跑，避免 CI/无密钥环境打外网：

    export LING_AMAP_E2E=1
    export LING_AMAP_WEB_KEY=<location Web service key>

在 ``app`` 目录、且已安装 ``requirements.txt``：``PYTHONPATH=. python -m unittest tests.test_mcp_amap_e2e -v``

Docker：根目录 ``.env`` 配置变量；在容器内 ``/app`` 执行上述命令（依赖镜像内已装依赖）。
"""

from __future__ import annotations

import os
import unittest
from contextlib import contextmanager
from unittest.mock import patch

from api.mcp import (
    location_geocode_address,
    location_reverse_geocode,
    location_route_plan,
    location_search_poi,
    location_weather_query,
)
from config.settings import AppConfig

_SKIP_LIVE = (
    os.getenv("LING_AMAP_E2E", "").strip() != "1"
    or not (os.getenv("LING_AMAP_WEB_KEY") or "").strip()
)
_SKIP_REASON = "Set LING_AMAP_E2E=1 and LING_AMAP_WEB_KEY to run live location MCP tool tests"


def _live_config() -> AppConfig:
    return AppConfig(amap_web_key=os.environ["LING_AMAP_WEB_KEY"].strip())


@contextmanager
def _patch_location_config():
    cfg = _live_config()
    with patch("services.amap.get_app_config", return_value=cfg):
        yield


@unittest.skipIf(_SKIP_LIVE, _SKIP_REASON)
class LocationMcpToolsFunctionE2ETests(unittest.IsolatedAsyncioTestCase):
    """位置服务 MCP 工具各一条真实网络用例。"""

    async def test_location_geocode_address(self) -> None:
        with _patch_location_config():
            result = await location_geocode_address.fn(
                user_id="e2e_user",
                address="北京市朝阳区阜通东大街6号",
            )
        self.assertTrue(result.get("ok"), result)
        self.assertEqual(result.get("action"), "location_geocode_address")
        location = (result.get("data") or {}).get("location") or {}
        self.assertEqual(location.get("status"), "1", location)
        self.assertGreaterEqual(int(location.get("count") or 0), 1)

    async def test_location_reverse_geocode(self) -> None:
        with _patch_location_config():
            result = await location_reverse_geocode.fn(
                user_id="e2e_user",
                longitude=116.480881,
                latitude=39.989410,
            )
        self.assertTrue(result.get("ok"), result)
        self.assertEqual(result.get("action"), "location_reverse_geocode")
        location = (result.get("data") or {}).get("location") or {}
        self.assertEqual(location.get("status"), "1", location)
        self.assertIn("regeocode", location)

    async def test_location_search_poi(self) -> None:
        with _patch_location_config():
            result = await location_search_poi.fn(
                user_id="e2e_user",
                keywords="北京大学",
                region="北京市",
            )
        self.assertTrue(result.get("ok"), result)
        self.assertEqual(result.get("action"), "location_search_poi")
        location = (result.get("data") or {}).get("location") or {}
        self.assertEqual(location.get("infocode"), "10000", location)
        self.assertIsInstance(location.get("pois"), list)

    async def test_location_weather_query(self) -> None:
        with _patch_location_config():
            result = await location_weather_query.fn(
                user_id="e2e_user",
                city_adcode="110101",
                extensions="base",
            )
        self.assertTrue(result.get("ok"), result)
        self.assertEqual(result.get("action"), "location_weather_query")
        location = (result.get("data") or {}).get("location") or {}
        self.assertEqual(location.get("status"), "1", location)
        self.assertIsInstance(location.get("lives"), list)
        self.assertGreaterEqual(len(location.get("lives") or []), 1)

    async def test_location_route_plan(self) -> None:
        with _patch_location_config():
            result = await location_route_plan.fn(
                user_id="e2e_user",
                mode="walking",
                origin="116.480881,39.989410",
                destination="116.481499,39.990475",
            )
        self.assertTrue(result.get("ok"), result)
        self.assertEqual(result.get("action"), "location_route_plan")
        location = (result.get("data") or {}).get("location") or {}
        self.assertEqual(location.get("status"), "1", location)
        self.assertIn("route", location)


if __name__ == "__main__":
    unittest.main()
