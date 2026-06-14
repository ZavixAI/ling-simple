# ruff: noqa: F403,F405,I001
"""Location MCP tools."""

from __future__ import annotations

from api.mcp_tools.shared import *  # noqa: F403


_ROUTE_RESULT_DETAIL_NOTE = (
    "Raw turn-by-turn details and route geometry are omitted because Ling uses this "
    "tool for route judgment and user-facing summaries."
)
_ROUTE_ALLOWED_SHOW_FIELDS = {"cost"}


def _compact_route_show_fields(show_fields: str | None) -> str | None:
    requested = [
        item.strip().lower()
        for item in (show_fields or "").split(",")
        if item.strip()
    ]
    allowed = [
        item
        for item in requested
        if item in _ROUTE_ALLOWED_SHOW_FIELDS
    ]
    return ",".join(allowed) or None


def _compact_route_plan_result(raw: dict[str, Any], *, mode: str) -> dict[str, Any]:
    route = raw.get("route") if isinstance(raw.get("route"), dict) else {}
    summary: dict[str, Any] = {
        "provider": "amap",
        "status": raw.get("status"),
        "info": raw.get("info"),
        "infocode": raw.get("infocode"),
        "mode": mode,
        "detail_policy": _ROUTE_RESULT_DETAIL_NOTE,
    }

    if route:
        for key in ("origin", "destination", "taxi_cost"):
            if route.get(key) not in (None, ""):
                summary[key] = route.get(key)

    transits = route.get("transits") if isinstance(route.get("transits"), list) else None
    paths = route.get("paths") if isinstance(route.get("paths"), list) else None
    if transits is not None:
        summary["route_count"] = len(transits)
        summary["routes"] = [
            _compact_transit_route(item, index=index)
            for index, item in enumerate(transits[:3], start=1)
            if isinstance(item, dict)
        ]
        summary["routes_omitted"] = max(0, len(transits) - 3)
    elif paths is not None:
        summary["route_count"] = len(paths)
        summary["routes"] = [
            _compact_path_route(item, index=index)
            for index, item in enumerate(paths[:3], start=1)
            if isinstance(item, dict)
        ]
        summary["routes_omitted"] = max(0, len(paths) - 3)
    else:
        summary["route_count"] = 0
        summary["routes"] = []

    return summary


def _compact_path_route(path: dict[str, Any], *, index: int) -> dict[str, Any]:
    cost = path.get("cost") if isinstance(path.get("cost"), dict) else {}
    compact: dict[str, Any] = {
        "index": index,
        "distance_m": _string_or_none(path.get("distance")),
        "duration_s": _string_or_none(cost.get("duration") or path.get("duration")),
        "tolls_yuan": _string_or_none(cost.get("tolls")),
        "toll_distance_m": _string_or_none(cost.get("toll_distance")),
        "traffic_lights": _string_or_none(cost.get("traffic_lights")),
    }
    steps = path.get("steps") if isinstance(path.get("steps"), list) else []
    compact["key_segments"] = [
        _compact_path_step(step)
        for step in steps[:5]
        if isinstance(step, dict)
    ]
    compact["segments_omitted"] = max(0, len(steps) - 5)
    return _drop_empty_values(compact)


def _compact_path_step(step: dict[str, Any]) -> dict[str, Any]:
    cost = step.get("cost") if isinstance(step.get("cost"), dict) else {}
    navi = step.get("navi") if isinstance(step.get("navi"), dict) else {}
    return _drop_empty_values(
        {
            "instruction": _truncate_text(step.get("instruction"), limit=80),
            "road_name": _string_or_none(step.get("road_name")),
            "distance_m": _string_or_none(step.get("step_distance")),
            "duration_s": _string_or_none(cost.get("duration")),
            "action": _string_or_none(navi.get("action")),
            "assistant_action": _string_or_none(navi.get("assistant_action")),
        }
    )


def _compact_transit_route(transit: dict[str, Any], *, index: int) -> dict[str, Any]:
    compact: dict[str, Any] = {
        "index": index,
        "cost_yuan": _string_or_none(transit.get("cost")),
        "distance_m": _string_or_none(transit.get("distance")),
        "duration_s": _string_or_none(transit.get("duration")),
        "walking_distance_m": _string_or_none(transit.get("walking_distance")),
    }
    segments = transit.get("segments") if isinstance(transit.get("segments"), list) else []
    compact["key_segments"] = [
        _compact_transit_segment(segment)
        for segment in segments[:5]
        if isinstance(segment, dict)
    ]
    compact["segments_omitted"] = max(0, len(segments) - 5)
    return _drop_empty_values(compact)


def _compact_transit_segment(segment: dict[str, Any]) -> dict[str, Any]:
    bus = segment.get("bus") if isinstance(segment.get("bus"), dict) else {}
    walking = segment.get("walking") if isinstance(segment.get("walking"), dict) else {}
    buslines = bus.get("buslines") if isinstance(bus.get("buslines"), list) else []
    first_busline = buslines[0] if buslines and isinstance(buslines[0], dict) else {}
    return _drop_empty_values(
        {
            "walking_distance_m": _string_or_none(walking.get("distance")),
            "bus_name": _string_or_none(first_busline.get("name")),
            "bus_type": _string_or_none(first_busline.get("type")),
            "departure_stop": _nested_name(first_busline.get("departure_stop")),
            "arrival_stop": _nested_name(first_busline.get("arrival_stop")),
            "bus_stops": _string_or_none(first_busline.get("via_num")),
            "bus_distance_m": _string_or_none(first_busline.get("distance")),
            "bus_duration_s": _string_or_none(first_busline.get("duration")),
        }
    )


def _nested_name(value: Any) -> str | None:
    if isinstance(value, dict):
        return _string_or_none(value.get("name"))
    return None


def _string_or_none(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _truncate_text(value: Any, *, limit: int) -> str | None:
    text = _string_or_none(value)
    if text is None or len(text) <= limit:
        return text
    return f"{text[: limit - 1]}..."


def _drop_empty_values(value: dict[str, Any]) -> dict[str, Any]:
    return {
        key: item
        for key, item in value.items()
        if item not in (None, "", [], {})
    }


@ling_mcp.tool(
    name="location_geocode_address",
    description=(
        "Convert a human-readable Chinese address TEXT into GPS coordinates (forward geocoding). "
        "Input must be an address string like 北京市海淀区中关村大街1号 — NOT coordinates. "
        "If you already have latitude/longitude numbers and need the address, use location_reverse_geocode instead."
    ),
)
async def location_geocode_address(
    user_id: Annotated[str, Field(description="Tenant-scoped user ID (for audit context).")],
    address: Annotated[
        str,
        Field(description="Human-readable address text, e.g. 北京市海淀区中关村大街1号. Must NOT be coordinates — use location_reverse_geocode for that."),
    ],
    city: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Optional city scope for matching: Chinese name, pinyin, citycode, or adcode."),
    ] = None,
) -> dict[str, Any]:
    action = "location_geocode_address"
    try:
        _ = user_id
        service = AmapWebService()
        raw = await service.geocode_address(address=address, city=city)
        return _success(action, {"location": raw})
    except Exception as exc:
        return _error(action, exc)


@ling_mcp.tool(
    name="location_reverse_geocode",
    description=(
        "Convert GPS coordinates (longitude, latitude numbers) into a human-readable address (reverse geocoding). "
        "Use this when you have numeric coordinates (e.g. from device location) and need the street/district/city name. "
        "Set extensions=all to also get nearby POIs and roads within the given radius."
    ),
)
async def location_reverse_geocode(
    user_id: Annotated[str, Field(description="Tenant-scoped user ID (for audit context).")],
    longitude: Annotated[float, Field(description="Longitude in decimal degrees (e.g. 117.118).")],
    latitude: Annotated[float, Field(description="Latitude in decimal degrees (e.g. 31.819).")],
    radius: Annotated[
        int | SkipJsonSchema[None],
        Field(description="Optional search radius in meters (0-3000); meaningful when extensions=all."),
    ] = None,
    extensions: Annotated[
        str,
        Field(description="Result detail: base (address only) or all (address + nearby POIs/roads)."),
    ] = "base",
    poitype: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Optional POI type codes (pipe-separated) when extensions=all."),
    ] = None,
) -> dict[str, Any]:
    action = "location_reverse_geocode"
    try:
        _ = user_id
        service = AmapWebService()
        raw = await service.reverse_geocode(
            longitude=longitude,
            latitude=latitude,
            radius=radius,
            extensions=extensions,
            poitype=poitype,
        )
        return _success(action, {"location": raw})
    except Exception as exc:
        return _error(action, exc)


@ling_mcp.tool(
    name="location_search_poi",
    description=(
        "Search POIs via the location service. Supports search_type=text or around. "
        "For text search, provide keywords or types and optionally region + city_limit. "
        "For around search, provide location=longitude,latitude and radius. "
        "Results are similarity-ranked; check at most the first two pages, then treat no match as likely unavailable."
    ),
)
async def location_search_poi(
    user_id: Annotated[str, Field(description="Tenant-scoped user ID (for audit context).")],
    search_type: Annotated[
        Literal["text", "around"],
        Field(description="POI search mode: text or around."),
    ] = "text",
    keywords: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Search keyword (single term, max 80 characters). Required with types only for text search; optional for around search."),
    ] = None,
    types: Annotated[
        str | SkipJsonSchema[None],
        Field(description="POI type codes (pipe-separated). Mutually optional with keywords."),
    ] = None,
    region: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Text search only. Boost or limit region: citycode, adcode, or city name like 北京市."),
    ] = None,
    city_limit: Annotated[
        bool,
        Field(description="Text search only. When true, only return POIs inside region."),
    ] = False,
    location: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Around search only. Center coordinate as longitude,latitude, e.g. 116.397499,39.908722."),
    ] = None,
    radius: Annotated[
        int | SkipJsonSchema[None],
        Field(description="Around search only. Search radius in meters; defaults to 1000."),
    ] = None,
    page_size: Annotated[int, Field(description="Page size 1-25 (default 10).")] = 10,
    page_num: Annotated[int, Field(description="Page number starting at 1. For similarity searches, prefer checking only pages 1-2 unless the user asks to browse more.")] = 1,
    show_fields: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Optional comma-separated extra result fields supported by the provider."),
    ] = None,
) -> dict[str, Any]:
    action = "location_search_poi"
    try:
        _ = user_id
        service = AmapWebService()
        raw = await service.search_poi(
            search_type=search_type,
            keywords=keywords,
            types=types,
            region=region,
            city_limit=city_limit,
            location=location,
            radius=radius,
            page_size=page_size,
            page_num=page_num,
            show_fields=show_fields,
        )
        return _success(action, {"location": raw})
    except Exception as exc:
        return _error(action, exc)


@ling_mcp.tool(
    name="location_route_plan",
    description=(
        "Plan a route via the location service. Supports mode=driving, walking, bicycling, electrobike, or transit. "
        "origin and destination must be coordinates in longitude,latitude format; geocode addresses first when needed. "
        "Transit route planning also requires origin_city and destination_city city codes."
    ),
)
async def location_route_plan(
    user_id: Annotated[str, Field(description="Tenant-scoped user ID (for audit context).")],
    mode: Annotated[
        Literal["driving", "walking", "bicycling", "electrobike", "transit"],
        Field(description="Route mode: driving, walking, bicycling, electrobike, or transit."),
    ],
    origin: Annotated[str, Field(description="Origin coordinate as longitude,latitude, e.g. 116.397499,39.908722.")],
    destination: Annotated[str, Field(description="Destination coordinate as longitude,latitude.")],
    strategy: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Driving/transit only. Optional route strategy value for supported modes."),
    ] = None,
    show_fields: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Optional comma-separated extra result fields. Only compact summary fields such as cost are returned to the agent."),
    ] = None,
    isindoor: Annotated[
        int | SkipJsonSchema[None],
        Field(description="Walking only. 1 to include indoor route planning, 0 to disable."),
    ] = None,
    origin_city: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Transit only. Origin city code."),
    ] = None,
    destination_city: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Transit only. Destination city code."),
    ] = None,
) -> dict[str, Any]:
    action = "location_route_plan"
    try:
        _ = user_id
        service = AmapWebService()
        raw = await service.route_plan(
            mode=mode,
            origin=origin,
            destination=destination,
            strategy=strategy,
            show_fields=_compact_route_show_fields(show_fields),
            isindoor=isindoor,
            origin_city=origin_city,
            destination_city=destination_city,
        )
        return _success(action, {"location": _compact_route_plan_result(raw, mode=mode)})
    except Exception as exc:
        return _error(action, exc)


@ling_mcp.tool(
    name="location_weather_query",
    description=(
        "Query current or forecast weather for a region using an administrative region adcode. "
        "extensions=base returns live weather; extensions=all returns multi-day forecast."
    ),
)
async def location_weather_query(
    user_id: Annotated[str, Field(description="Tenant-scoped user ID (for audit context).")],
    city_adcode: Annotated[str, Field(description="Administrative region adcode, e.g. 110101 for Beijing Dongcheng.")],
    extensions: Annotated[
        str,
        Field(description="base for live weather, all for forecast list."),
    ] = "base",
) -> dict[str, Any]:
    action = "location_weather_query"
    try:
        _ = user_id
        service = AmapWebService()
        raw = await service.weather(city_adcode=city_adcode, extensions=extensions)
        return _success(action, {"location": raw})
    except Exception as exc:
        return _error(action, exc)


__all__ = [name for name in globals() if not name.startswith("__")]
