from __future__ import annotations

import asyncio
import unittest
from unittest.mock import AsyncMock, patch

from api.mcp import (
    ling_mcp,
    travel_flight_search,
    travel_hotel_rooms,
    travel_hotel_search,
)


class TravelMcpToolsTests(unittest.IsolatedAsyncioTestCase):
    async def test_flight_search_returns_success_wrapped_payload(self) -> None:
        fake = {"flights": [{"flight_no": "HO1887"}]}
        with patch(
            "api.mcp_tools.travel.RideClawService.flight_search",
            new=AsyncMock(return_value=fake),
        ) as mock_search:
            result = await travel_flight_search.fn(
                user_id="u1",
                from_code="SHA",
                to_code="SZX",
                depart_date="2026-06-15",
            )

        self.assertTrue(result["ok"])
        self.assertEqual(result["data"]["travel"], fake)
        self.assertIn("flight options", result["next_tip"])
        self.assertIn("Do not repeat", result["next_tip"])
        mock_search.assert_awaited_once()
        self.assertEqual(mock_search.await_args.args[0]["from_code"], "SHA")
        self.assertNotIn("order", result["action"])

    async def test_hotel_search_returns_success_wrapped_payload(self) -> None:
        fake = {"hotels": [{"hotel_name": "杭州西湖希尔顿酒店"}]}
        with patch(
            "api.mcp_tools.travel.RideClawService.hotel_search",
            new=AsyncMock(return_value=fake),
        ) as mock_search:
            result = await travel_hotel_search.fn(
                user_id="u1",
                destination="杭州西湖",
                check_in="2026-06-15",
                check_out="2026-06-17",
                max_price=1000,
            )

        self.assertTrue(result["ok"])
        self.assertEqual(result["data"]["travel"], fake)
        self.assertIn("hotel options", result["next_tip"])
        self.assertIn("Do not repeat", result["next_tip"])
        self.assertEqual(mock_search.await_args.args[0]["filters"]["max_price"], 1000)

    async def test_hotel_rooms_returns_success_wrapped_payload(self) -> None:
        fake = {"rooms": [{"room_name": "大床房"}]}
        with patch(
            "api.mcp_tools.travel.RideClawService.hotel_rooms",
            new=AsyncMock(return_value=fake),
        ) as mock_rooms:
            result = await travel_hotel_rooms.fn(
                user_id="u1",
                hotel_id="H1",
                rooms_ref="rooms-token",
            )

        self.assertTrue(result["ok"])
        self.assertEqual(result["data"]["travel"], fake)
        self.assertEqual(mock_rooms.await_args.args[0]["rooms_ref"], "rooms-token")

    def test_registered_tools_exclude_order_creation(self) -> None:
        async def _load_registered_names() -> set[str]:
            tools = await ling_mcp.get_tools()
            return set(tools.keys())

        names = asyncio.run(_load_registered_names())
        self.assertIn("travel_flight_airport_search", names)
        self.assertIn("travel_flight_search", names)
        self.assertIn("travel_hotel_search", names)
        self.assertIn("travel_hotel_rooms", names)
        self.assertNotIn("travel_flight_pricing", names)
        self.assertNotIn("travel_flight_order_create", names)
        self.assertNotIn("travel_hotel_order_create", names)


if __name__ == "__main__":
    unittest.main()
