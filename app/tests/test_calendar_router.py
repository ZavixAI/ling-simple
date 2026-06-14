from __future__ import annotations

import importlib.util
import sys
import unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import AsyncMock, patch

from config import constants

import httpx
from core.http.dependencies import require_current_user
from fastapi import FastAPI
from models.user import User

_CALENDAR_ROUTER_SPEC = importlib.util.spec_from_file_location(
    "ling_calendar_router_test_module",
    Path(__file__).resolve().parents[1] / "api" / "routers" / "calendar.py",
)
assert _CALENDAR_ROUTER_SPEC is not None and _CALENDAR_ROUTER_SPEC.loader is not None
_CALENDAR_ROUTER_MODULE = importlib.util.module_from_spec(_CALENDAR_ROUTER_SPEC)
sys.modules[_CALENDAR_ROUTER_SPEC.name] = _CALENDAR_ROUTER_MODULE
_CALENDAR_ROUTER_SPEC.loader.exec_module(_CALENDAR_ROUTER_MODULE)
calendar_router = _CALENDAR_ROUTER_MODULE.router


class CalendarRouterRouteOrderTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        app = FastAPI()
        app.include_router(calendar_router, prefix="/ling-api")
        app.dependency_overrides[require_current_user] = self._mock_user
        self._app = app

    def tearDown(self) -> None:
        self._app.dependency_overrides.clear()

    @staticmethod
    def _mock_user() -> User:
        return User(user_id="user-1", username="tester", password_hash="secret")

    async def test_window_route_is_not_captured_by_event_id_route(self) -> None:
        with patch.object(_CALENDAR_ROUTER_MODULE, "CalendarService") as service_cls:
            service = service_cls.return_value
            service.parse_datetime.side_effect = [
                datetime(2026, 4, 7, 0, 0, 0),
                datetime(2026, 4, 14, 0, 0, 0),
            ]
            service.list_events_between = AsyncMock(return_value=[])

            async with httpx.AsyncClient(
                transport=httpx.ASGITransport(app=self._app),
                base_url="http://testserver",
            ) as client:
                response = await client.get(
                    "/ling-api/calendar/events/window",
                    params={
                        "start_at": "2026-04-07T00:00:00+08:00",
                        "end_at": "2026-04-14T00:00:00+08:00",
                        "timezone": constants.DEFAULT_TIMEZONE,
                    },
                )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["message"], "success")
        self.assertEqual(payload["data"]["events"], [])
        service.list_events_between.assert_awaited_once_with(
            "user-1",
            datetime(2026, 4, 7, 0, 0, 0),
            datetime(2026, 4, 14, 0, 0, 0),
            constants.DEFAULT_TIMEZONE,
        )
        service.get_event.assert_not_called()


if __name__ == "__main__":
    unittest.main()
