from __future__ import annotations

import asyncio
import json
import unittest
from unittest.mock import AsyncMock, Mock, patch

from api.mcp import (
    location_geocode_address,
    location_reverse_geocode,
    location_route_plan,
    location_search_poi,
    location_weather_query,
    ling_mcp,
)
from services.amap import AmapWebService


class LocationMcpToolsTests(unittest.IsolatedAsyncioTestCase):
    async def test_service_builds_poi_around_url(self) -> None:
        with patch(
            "services.amap.AmapWebService._get_json",
            new=AsyncMock(return_value={"status": "1"}),
        ) as mock_get:
            await AmapWebService(Mock(amap_web_key="test-key")).search_poi(
                search_type="around",
                keywords="咖啡",
                location="116.397499,39.908722",
                radius=1500,
            )

        url = mock_get.await_args.args[0]
        self.assertIn("/v5/place/around?", url)
        self.assertIn("keywords=", url)
        self.assertIn("location=116.397499%2C39.908722", url)
        self.assertIn("radius=1500", url)

    async def test_service_builds_route_plan_url(self) -> None:
        with patch(
            "services.amap.AmapWebService._get_json",
            new=AsyncMock(return_value={"status": "1"}),
        ) as mock_get:
            await AmapWebService(Mock(amap_web_key="test-key")).route_plan(
                mode="walking",
                origin="116.397499,39.908722",
                destination="116.407499,39.918722",
                strategy="2",
                show_fields="cost,navi",
            )

        url = mock_get.await_args.args[0]
        self.assertIn("/v5/direction/walking?", url)
        self.assertIn("origin=116.397499%2C39.908722", url)
        self.assertIn("destination=116.407499%2C39.918722", url)
        self.assertIn("show_fields=cost%2Cnavi", url)
        self.assertNotIn("strategy=2", url)

    async def test_service_builds_transit_route_plan_url(self) -> None:
        with patch(
            "services.amap.AmapWebService._get_json",
            new=AsyncMock(return_value={"status": "1"}),
        ) as mock_get:
            await AmapWebService(Mock(amap_web_key="test-key")).route_plan(
                mode="transit",
                origin="116.397499,39.908722",
                destination="116.407499,39.918722",
                origin_city="010",
                destination_city="021",
                strategy="2",
                show_fields="cost,navi",
            )

        url = mock_get.await_args.args[0]
        self.assertIn("/v5/direction/transit/integrated?", url)
        self.assertIn("origin=116.397499%2C39.908722", url)
        self.assertIn("destination=116.407499%2C39.918722", url)
        self.assertIn("city1=010", url)
        self.assertIn("city2=021", url)
        self.assertIn("strategy=2", url)
        self.assertIn("show_fields=cost%2Cnavi", url)

    async def test_geocode_returns_success_wrapped_payload(self) -> None:
        fake = {"status": "1", "geocodes": []}

        with (
            patch(
                "services.amap.AmapWebService.geocode_address",
                new=AsyncMock(return_value=fake),
            ) as mock_geo,
            patch(
                "services.amap.get_app_config",
                return_value=Mock(amap_web_key="test-key"),
            ),
        ):
            result = await location_geocode_address.fn(
                user_id="u1",
                address="北京市朝阳区阜通东大街6号",
            )

        self.assertTrue(result["ok"])
        self.assertEqual(result["data"]["location"], fake)
        mock_geo.assert_awaited_once()

    async def test_reverse_geocode_propagates_service_error(self) -> None:
        from core.http.exceptions import AppHTTPException

        async def _raise(*_a: object, **_k: object) -> None:
            raise AppHTTPException(status_code=422, detail="bad")

        with (
            patch("services.amap.AmapWebService.reverse_geocode", new=AsyncMock(side_effect=_raise)),
            patch(
                "services.amap.get_app_config",
                return_value=Mock(amap_web_key="test-key"),
            ),
        ):
            result = await location_reverse_geocode.fn(
                user_id="u1",
                longitude=116.397499,
                latitude=39.908722,
            )

        self.assertFalse(result["ok"])

    async def test_search_poi_supports_around_mode(self) -> None:
        fake = {"status": "1", "pois": []}

        with (
            patch(
                "services.amap.AmapWebService.search_poi",
                new=AsyncMock(return_value=fake),
            ) as mock_search,
            patch(
                "services.amap.get_app_config",
                return_value=Mock(amap_web_key="test-key"),
            ),
        ):
            result = await location_search_poi.fn(
                user_id="u1",
                search_type="around",
                keywords="咖啡",
                location="116.397499,39.908722",
                radius=1500,
            )

        self.assertTrue(result["ok"])
        self.assertEqual(result["data"]["location"], fake)
        mock_search.assert_awaited_once()
        self.assertEqual(mock_search.await_args.kwargs["search_type"], "around")

    async def test_route_plan_returns_success_wrapped_payload(self) -> None:
        fake = {"status": "1", "route": {"paths": []}}

        with (
            patch(
                "services.amap.AmapWebService.route_plan",
                new=AsyncMock(return_value=fake),
            ) as mock_route,
            patch(
                "services.amap.get_app_config",
                return_value=Mock(amap_web_key="test-key"),
            ),
        ):
            result = await location_route_plan.fn(
                user_id="u1",
                mode="walking",
                origin="116.397499,39.908722",
                destination="116.407499,39.918722",
            )

        self.assertTrue(result["ok"])
        self.assertEqual(result["data"]["location"]["status"], "1")
        self.assertEqual(result["data"]["location"]["route_count"], 0)
        self.assertEqual(result["data"]["location"]["routes"], [])
        mock_route.assert_awaited_once()
        self.assertEqual(mock_route.await_args.kwargs["mode"], "walking")

    async def test_route_plan_returns_compact_payload_without_navigation_details(self) -> None:
        fake = {
            "status": "1",
            "info": "OK",
            "infocode": "10000",
            "route": {
                "origin": "116.34630014749015,39.94084562477987",
                "destination": "116.592642,40.078920",
                "taxi_cost": "91",
                "paths": [
                    {
                        "distance": "29614",
                        "cost": {
                            "duration": "2424",
                            "tolls": "5",
                            "toll_distance": "1631",
                            "traffic_lights": "17",
                        },
                        "steps": [
                            {
                                "instruction": "向西行驶33米右转",
                                "road_name": "",
                                "step_distance": "33",
                                "cost": {"duration": "20"},
                                "polyline": "116.1,39.1;116.2,39.2",
                                "navi": {
                                    "action": "右转",
                                    "assistant_action": "到达右转路口",
                                },
                            },
                            {
                                "instruction": "沿西直门外大街辅路行驶很长很长很长很长很长很长很长很长很长很长一段",
                                "road_name": "西直门外大街辅路",
                                "step_distance": "359",
                                "cost": {"duration": "51"},
                                "polyline": "116.3,39.3;116.4,39.4",
                                "navi": {
                                    "action": "向右前方行驶",
                                    "assistant_action": "进入主路",
                                },
                            },
                        ],
                    }
                ],
            },
        }

        with (
            patch(
                "services.amap.AmapWebService.route_plan",
                new=AsyncMock(return_value=fake),
            ) as mock_route,
            patch(
                "services.amap.get_app_config",
                return_value=Mock(amap_web_key="test-key"),
            ),
        ):
            result = await location_route_plan.fn(
                user_id="u1",
                mode="driving",
                origin="116.34630014749015,39.94084562477987",
                destination="116.592642,40.078920",
                show_fields="cost,navi,polyline",
            )

        self.assertTrue(result["ok"])
        compact = result["data"]["location"]
        self.assertEqual(compact["mode"], "driving")
        self.assertEqual(compact["taxi_cost"], "91")
        self.assertEqual(compact["routes"][0]["distance_m"], "29614")
        self.assertEqual(compact["routes"][0]["duration_s"], "2424")
        self.assertEqual(compact["routes"][0]["key_segments"][0]["action"], "右转")
        self.assertEqual(mock_route.await_args.kwargs["show_fields"], "cost")

        encoded = json.dumps(compact, ensure_ascii=False)
        self.assertNotIn("polyline", encoded)
        self.assertNotIn("116.1,39.1", encoded)
        self.assertNotIn("navi", encoded)

    async def test_route_plan_forwards_transit_city_codes(self) -> None:
        fake = {"status": "1", "route": {"transits": []}}

        with (
            patch(
                "services.amap.AmapWebService.route_plan",
                new=AsyncMock(return_value=fake),
            ) as mock_route,
            patch(
                "services.amap.get_app_config",
                return_value=Mock(amap_web_key="test-key"),
            ),
        ):
            result = await location_route_plan.fn(
                user_id="u1",
                mode="transit",
                origin="116.397499,39.908722",
                destination="116.407499,39.918722",
                origin_city="010",
                destination_city="021",
            )

        self.assertTrue(result["ok"])
        self.assertEqual(result["data"]["location"]["status"], "1")
        self.assertEqual(result["data"]["location"]["route_count"], 0)
        self.assertEqual(result["data"]["location"]["routes"], [])
        mock_route.assert_awaited_once()
        self.assertEqual(mock_route.await_args.kwargs["origin_city"], "010")
        self.assertEqual(mock_route.await_args.kwargs["destination_city"], "021")

    def test_registered_tools_keep_metadata_while_handlers_remain_callable(self) -> None:
        self.assertTrue(callable(location_geocode_address.fn))
        self.assertTrue(callable(location_reverse_geocode.fn))
        self.assertTrue(callable(location_search_poi.fn))
        self.assertTrue(callable(location_route_plan.fn))
        self.assertTrue(callable(location_weather_query.fn))

        async def _load_registered_names() -> set[str]:
            tools = await ling_mcp.get_tools()
            return set(tools.keys())

        names = asyncio.run(_load_registered_names())
        self.assertIn("location_geocode_address", names)
        self.assertIn("location_reverse_geocode", names)
        self.assertIn("location_search_poi", names)
        self.assertIn("location_route_plan", names)
        self.assertIn("location_weather_query", names)


if __name__ == "__main__":
    unittest.main()
