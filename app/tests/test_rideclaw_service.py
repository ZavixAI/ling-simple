from __future__ import annotations

import unittest
from typing import Any
from unittest.mock import patch

from config.settings import AppConfig
from core.http.exceptions import AppHTTPException
from services.rideclaw import RideClawService


class _FakeResponse:
    def __init__(self, payload: dict[str, Any], *, status_code: int = 200, status_error: bool = False) -> None:
        self._payload = payload
        self.status_code = status_code
        self._status_error = status_error

    def raise_for_status(self) -> None:
        if self._status_error:
            request = object()
            raise __import__("httpx").HTTPStatusError(
                "bad status",
                request=request,
                response=self,
            )

    def json(self) -> dict[str, Any]:
        return self._payload


class _FakeAsyncClient:
    last_request: dict[str, Any] | None = None
    response = _FakeResponse({"code": 0, "data": {}})

    def __init__(self, *, timeout: float) -> None:
        self.timeout = timeout

    async def __aenter__(self) -> "_FakeAsyncClient":
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        return None

    async def request(
        self,
        method: str,
        url: str,
        *,
        headers: dict[str, str],
        params: dict[str, Any] | None = None,
        json: dict[str, Any] | None = None,
    ) -> _FakeResponse:
        self.__class__.last_request = {
            "method": method,
            "url": url,
            "headers": headers,
            "params": params,
            "json": json,
        }
        return self.__class__.response


class RideClawServiceTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        _FakeAsyncClient.last_request = None
        _FakeAsyncClient.response = _FakeResponse({"code": 0, "data": {}})

    async def test_token_missing_does_not_send_request(self) -> None:
        service = RideClawService(AppConfig(rideclaw_api_token=None))

        with self.assertRaises(AppHTTPException) as ctx:
            await service.flight_search(
                {
                    "from_code": "SHA",
                    "to_code": "SZX",
                    "depart_date": "2026-06-15",
                }
            )

        self.assertEqual(ctx.exception.error_code, "RIDECLAW_TOKEN_MISSING")
        self.assertIsNone(_FakeAsyncClient.last_request)

    async def test_flight_search_posts_authorized_payload(self) -> None:
        _FakeAsyncClient.response = _FakeResponse(
            {
                "code": 0,
                "data": {
                    "search_id": "S1",
                    "flights": [
                        {
                            "flight_id": "F1",
                            "flight_no": "HO1887",
                            "airline_code": "HO",
                            "airline_name": "吉祥航空",
                            "aircraft_type": "789",
                            "dep_time": "2026-06-15 08:00",
                            "arr_time": "2026-06-15 10:30",
                            "dep_airport_code": "SHA",
                            "dep_airport_name": "虹桥国际机场",
                            "dep_terminal": "T2",
                            "arr_airport_code": "SZX",
                            "arr_airport_name": "宝安国际机场",
                            "arr_terminal": "T3",
                            "cabins": [
                                {
                                    "lowest_price": 880,
                                    "cabin_name": "公务舱",
                                    "baggage_rule": "very long baggage text",
                                    "change_rule": "very long change text",
                                    "refund_rule": "very long refund text",
                                },
                                {
                                    "lowest_price": 580,
                                    "cabin_name": "经济舱",
                                    "airport_tax": 50,
                                    "fuel_tax": 20,
                                    "seat_status": "A",
                                    "baggage_rule": "very long baggage text",
                                    "change_rule": "very long change text",
                                    "refund_rule": "very long refund text",
                                    "offer_id": "order-token",
                                    "search_offer_id": "pricing-token",
                                }
                            ],
                        }
                    ],
                },
                "request_id": "req1",
            }
        )
        service = RideClawService(
            AppConfig(
                rideclaw_api_base_url="https://example.test/api",
                rideclaw_api_token="test-token",
            )
        )

        with patch("services.rideclaw.httpx.AsyncClient", _FakeAsyncClient):
            result = await service.flight_search(
                {
                    "from_code": "SHA",
                    "to_code": "SZX",
                    "depart_date": "2026-06-15",
                }
            )

        request = _FakeAsyncClient.last_request
        assert request is not None
        self.assertEqual(request["method"], "POST")
        self.assertEqual(request["url"], "https://example.test/api/open/v1/flight/search")
        self.assertEqual(request["headers"]["Authorization"], "Bearer test-token")
        self.assertEqual(request["json"]["from_code"], "SHA")
        self.assertEqual(request["json"]["page_size"], 10)
        self.assertIn("HO1887", result["flights"][0]["summary"])
        self.assertEqual(result["flights"][0]["dep_airport_name"], "虹桥国际机场")
        self.assertEqual(result["flights"][0]["arr_airport_name"], "宝安国际机场")
        self.assertIn("aircraft: 789", result["flights"][0]["summary"])
        self.assertIn("from CNY 580", result["flights"][0]["cabins"][0])
        self.assertIn("经济舱", result["flights"][0]["cabins"][0])
        self.assertIn("detail_policy", result)
        encoded = str(result["flights"][0])
        self.assertNotIn("offer_id", encoded)
        self.assertNotIn("search_offer_id", encoded)
        self.assertNotIn("pricing_ref", encoded)
        self.assertNotIn("baggage_rule", encoded)
        self.assertNotIn("change_rule", encoded)
        self.assertNotIn("refund_rule", encoded)

    async def test_hotel_search_sanitizes_room_reference(self) -> None:
        _FakeAsyncClient.response = _FakeResponse(
            {
                "code": 0,
                "data": {
                    "hotels": [
                        {
                            "hotel_id": "H1",
                            "hotel_name": "杭州西湖希尔顿酒店",
                            "lowest_price": 800,
                            "search_offer_id": "rooms-token",
                            "offer_id": "order-token",
                        }
                    ],
                },
            }
        )
        service = RideClawService(AppConfig(rideclaw_api_token="test-token"))

        with patch("services.rideclaw.httpx.AsyncClient", _FakeAsyncClient):
            result = await service.hotel_search(
                {
                    "destination": "杭州西湖",
                    "check_in": "2026-06-15",
                    "check_out": "2026-06-17",
                }
            )

        self.assertTrue(result["hotels"][0]["rooms_ref"].startswith("rc_hotel_"))
        self.assertNotIn("offer_id", result["hotels"][0])
        self.assertNotIn("search_offer_id", result["hotels"][0])

    async def test_business_error_is_normalized(self) -> None:
        _FakeAsyncClient.response = _FakeResponse(
            {
                "code": 40113,
                "message": "token invalid",
                "request_id": "req-bad",
            }
        )
        service = RideClawService(AppConfig(rideclaw_api_token="test-token"))

        with (
            patch("services.rideclaw.httpx.AsyncClient", _FakeAsyncClient),
            self.assertRaises(AppHTTPException) as ctx,
        ):
            await service.hotel_rooms({"rooms_ref": "rooms-token"})

        self.assertEqual(ctx.exception.error_code, "RIDECLAW_BUSINESS_ERROR")
        self.assertEqual(ctx.exception.error_detail["code"], 40113)

    async def test_http_error_is_normalized(self) -> None:
        _FakeAsyncClient.response = _FakeResponse({}, status_code=403, status_error=True)
        service = RideClawService(AppConfig(rideclaw_api_token="test-token"))

        with (
            patch("services.rideclaw.httpx.AsyncClient", _FakeAsyncClient),
            self.assertRaises(AppHTTPException) as ctx,
        ):
            await service.airport_search(keyword="上海")

        self.assertEqual(ctx.exception.error_code, "RIDECLAW_HTTP_ERROR")
        self.assertEqual(ctx.exception.status_code, 403)


if __name__ == "__main__":
    unittest.main()
