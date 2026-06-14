"""MCP application entrypoint."""

from __future__ import annotations

from api.mcp_tools import calendar as _calendar
from api.mcp_tools import location as _location
from api.mcp_tools import shared as _shared
from api.mcp_tools import travel as _travel

ling_mcp = _shared.ling_mcp
ling_mcp_http = _shared.ling_mcp_http

_MODULES = (
    _shared,
    _calendar,
    _location,
    _travel,
)

_EXPORTS = [
    "ling_mcp",
    "ling_mcp_http",
    "calendar_list_events",
    "calendar_create_event",
    "calendar_update_event",
    "calendar_complete_event",
    "calendar_delete_event",
    "location_geocode_address",
    "location_reverse_geocode",
    "location_search_poi",
    "location_route_plan",
    "location_weather_query",
    "travel_flight_airport_search",
    "travel_flight_search",
    "travel_hotel_search",
    "travel_hotel_rooms",
]


def __getattr__(name: str):
    for module in _MODULES:
        if hasattr(module, name):
            return getattr(module, name)
    raise AttributeError(name)


for _name in _EXPORTS:
    if _name not in globals():
        globals()[_name] = __getattr__(_name)

__all__ = list(_EXPORTS)
