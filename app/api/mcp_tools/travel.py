# ruff: noqa: F403,F405,I001
"""Read-only travel resource MCP tools."""

from __future__ import annotations

from api.mcp_tools.shared import *  # noqa: F403
from services.rideclaw import RideClawService


@ling_mcp.tool(
    name="travel_flight_airport_search",
    description=(
        "Search airport/city codes for flight queries. Read-only. "
        "Use before flight search when the user gives city or airport names instead of IATA-style codes. "
        "This is similarity-ranked; if the returned candidates do not contain the requested city/airport, do not keep retrying."
    ),
)
async def travel_flight_airport_search(
    user_id: Annotated[str, Field(description="Tenant-scoped user ID (for audit context).")],
    keyword: Annotated[str, Field(description="Airport or city keyword, e.g. 上海, 深圳, SHA, SZX.")],
    page_size: Annotated[int, Field(description="Maximum airport candidates to return, 1-50.")] = 20,
) -> dict[str, Any]:
    action = "travel_flight_airport_search"
    try:
        _ = user_id
        data = await RideClawService().airport_search(keyword=keyword, page_size=page_size)
        return _success(action, {"travel": data})
    except Exception as exc:
        return _error(action, exc)


@ling_mcp.tool(
    name="travel_flight_search",
    description=(
        "Search read-only flight availability and prices. Does not create orders. "
        "Use airport codes such as SHA/SZX; call travel_flight_airport_search first if needed."
    ),
)
async def travel_flight_search(
    user_id: Annotated[str, Field(description="Tenant-scoped user ID (for audit context).")],
    from_code: Annotated[str, Field(description="Departure airport or city code, e.g. SHA.")],
    to_code: Annotated[str, Field(description="Arrival airport or city code, e.g. SZX.")],
    depart_date: Annotated[str, Field(description="Departure date in YYYY-MM-DD format.")],
    trip_mode: Annotated[
        Literal["domestic", "international"],
        Field(description="Flight market mode."),
    ] = "domestic",
    trip_type: Annotated[
        Literal["oneway", "roundtrip"],
        Field(description="Trip type."),
    ] = "oneway",
    return_date: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Return date in YYYY-MM-DD format. Required only for roundtrip."),
    ] = None,
    cabin_class: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Cabin class filter, e.g. economy, business, first."),
    ] = None,
    flight_no: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Optional exact flight number filter."),
    ] = None,
    adult_count: Annotated[int, Field(description="Adult passenger count.")] = 1,
    child_count: Annotated[int, Field(description="Child passenger count.")] = 0,
    infant_count: Annotated[int, Field(description="Infant passenger count.")] = 0,
    page_size: Annotated[int, Field(description="Maximum flight candidates to return, 1-20. Default 10; keep count broad and details compact.")] = 10,
    sort_by: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Optional provider sort key, e.g. price."),
    ] = "price",
) -> dict[str, Any]:
    action = "travel_flight_search"
    try:
        payload: dict[str, Any] = {
            "trip_mode": trip_mode,
            "trip_type": trip_type,
            "from_code": from_code,
            "to_code": to_code,
            "depart_date": depart_date,
            "return_date": return_date,
            "cabin_class": cabin_class,
            "flight_no": flight_no,
            "passengers": {
                "adult": max(1, adult_count),
                "child": max(0, child_count),
                "infant": max(0, infant_count),
            },
            "page_size": page_size,
            "sort_by": sort_by,
        }
        data = await RideClawService().flight_search(payload)
        return _success(action, {"travel": data})
    except Exception as exc:
        return _error(action, exc)


@ling_mcp.tool(
    name="travel_hotel_search",
    description=(
        "Search read-only hotel availability candidates. Does not create orders. "
        "Use for destination, date, budget, star, distance, facility, and scene-based hotel planning. "
        "Hotel search is similarity-ranked; check at most pages 1-2, then treat no match as likely unavailable."
    ),
)
async def travel_hotel_search(
    user_id: Annotated[str, Field(description="Tenant-scoped user ID (for audit context).")],
    destination: Annotated[str, Field(description="Destination text, e.g. 杭州西湖.")],
    check_in: Annotated[str, Field(description="Check-in date in YYYY-MM-DD format.")],
    check_out: Annotated[str, Field(description="Check-out date in YYYY-MM-DD format.")],
    adult_count: Annotated[int, Field(description="Adult guest count.")] = 2,
    room_count: Annotated[int, Field(description="Room count.")] = 1,
    page: Annotated[int, Field(description="Page number starting at 1. For similarity searches, prefer checking only pages 1-2 unless the user asks to browse more.")] = 1,
    page_size: Annotated[int, Field(description="Page size, 1-50.")] = 10,
    sort_by: Annotated[
        Literal["best", "price", "rating", "star", "distance"],
        Field(description="Sort key."),
    ] = "best",
    scene: Annotated[
        Literal["couple", "family", "senior", "business", "inbound"] | SkipJsonSchema[None],
        Field(description="Travel scene tag."),
    ] = None,
    adcode: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Optional administrative area code for more precise destination matching."),
    ] = None,
    latitude: Annotated[
        float | SkipJsonSchema[None],
        Field(description="Optional latitude for distance sorting/filtering."),
    ] = None,
    longitude: Annotated[
        float | SkipJsonSchema[None],
        Field(description="Optional longitude for distance sorting/filtering."),
    ] = None,
    min_price: Annotated[
        float | SkipJsonSchema[None],
        Field(description="Optional minimum nightly price."),
    ] = None,
    max_price: Annotated[
        float | SkipJsonSchema[None],
        Field(description="Optional maximum nightly price."),
    ] = None,
    star_levels: Annotated[
        list[int] | SkipJsonSchema[None],
        Field(description="Optional hotel star levels, e.g. [4,5]."),
    ] = None,
    min_review_score: Annotated[
        float | SkipJsonSchema[None],
        Field(description="Optional minimum review score from 0 to 5."),
    ] = None,
    max_distance_km: Annotated[
        float | SkipJsonSchema[None],
        Field(description="Optional maximum distance in km; meaningful with latitude/longitude."),
    ] = None,
    breakfast_included: Annotated[
        bool | SkipJsonSchema[None],
        Field(description="Optional breakfast filter."),
    ] = None,
    refundable: Annotated[
        bool | SkipJsonSchema[None],
        Field(description="Optional refundable filter."),
    ] = None,
    has_wifi: Annotated[
        bool | SkipJsonSchema[None],
        Field(description="Optional Wi-Fi facility filter."),
    ] = None,
    has_parking: Annotated[
        bool | SkipJsonSchema[None],
        Field(description="Optional parking facility filter."),
    ] = None,
    hotel_brand: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Optional hotel brand filter."),
    ] = None,
) -> dict[str, Any]:
    action = "travel_hotel_search"
    try:
        filters = {
            "min_price": min_price,
            "max_price": max_price,
            "star_levels": star_levels,
            "min_review_score": min_review_score,
            "max_distance_km": max_distance_km,
            "breakfast_included": breakfast_included,
            "refundable": refundable,
            "has_wifi": has_wifi,
            "has_parking": has_parking,
            "hotel_brand": hotel_brand,
        }
        payload = {
            "destination": destination,
            "check_in": check_in,
            "check_out": check_out,
            "adult_count": max(1, adult_count),
            "room_count": max(1, room_count),
            "page": max(1, page),
            "page_size": page_size,
            "sort_by": sort_by,
            "scene": scene,
            "adcode": adcode,
            "latitude": latitude,
            "longitude": longitude,
            "filters": {key: value for key, value in filters.items() if value not in (None, "")},
        }
        data = await RideClawService().hotel_search(payload)
        return _success(action, {"travel": data})
    except Exception as exc:
        return _error(action, exc)


@ling_mcp.tool(
    name="travel_hotel_rooms",
    description=(
        "Search read-only room type details for a selected hotel. Does not create orders. "
        "Use after travel_hotel_search when room availability, breakfast, cancellation, or room price matters."
    ),
)
async def travel_hotel_rooms(
    user_id: Annotated[str, Field(description="Tenant-scoped user ID (for audit context).")],
    hotel_id: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Hotel ID from travel_hotel_search."),
    ] = None,
    rooms_ref: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Read-only room query reference from travel_hotel_search rooms_ref."),
    ] = None,
    check_in: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Check-in date in YYYY-MM-DD format."),
    ] = None,
    check_out: Annotated[
        str | SkipJsonSchema[None],
        Field(description="Check-out date in YYYY-MM-DD format."),
    ] = None,
    adult_count: Annotated[int, Field(description="Adult guest count.")] = 2,
    room_count: Annotated[int, Field(description="Room count.")] = 1,
) -> dict[str, Any]:
    action = "travel_hotel_rooms"
    try:
        _ = user_id
        payload = {
            "hotel_id": hotel_id,
            "rooms_ref": rooms_ref,
            "check_in": check_in,
            "check_out": check_out,
            "adult_count": max(1, adult_count),
            "room_count": max(1, room_count),
        }
        data = await RideClawService().hotel_rooms(payload)
        return _success(action, {"travel": data})
    except Exception as exc:
        return _error(action, exc)


__all__ = [name for name in globals() if not name.startswith("__")]
