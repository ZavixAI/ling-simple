"""RideClaw travel resources client for read-only flight and hotel search."""

from __future__ import annotations

import hashlib
import time
from typing import Any

import httpx
from config.settings import AppConfig, get_app_config
from core.http.exceptions import AppHTTPException

_ORDER_TOKEN_KEYS = {"offer_id"}
_REQUEST_SECRET_KEYS = {"authorization", "token", "api_key", "apikey"}
_QUERY_REF_TTL_SECONDS = 30 * 60
_QUERY_REFS: dict[str, tuple[float, str]] = {}
_FLIGHT_RULE_DETAIL_NOTE = "Cabin rule details are summarized for planning; confirm baggage, change, refund, and final price with the supplier before booking."


class RideClawService:
    """Small provider wrapper that keeps credentials and raw payloads server-side."""

    def __init__(self, cfg: AppConfig | None = None) -> None:
        self._cfg = cfg or get_app_config()

    def _api_token(self) -> str:
        token = (self._cfg.rideclaw_api_token or "").strip()
        if not token:
            raise AppHTTPException(
                status_code=503,
                detail="RideClaw API token is not configured; set LING_RIDECLAW_API_TOKEN",
                error_code="RIDECLAW_TOKEN_MISSING",
            )
        return token

    def _base_url(self) -> str:
        base_url = (self._cfg.rideclaw_api_base_url or "").strip().rstrip("/")
        if not base_url:
            raise AppHTTPException(
                status_code=503,
                detail="RideClaw API base URL is not configured",
                error_code="RIDECLAW_ENDPOINT_MISSING",
            )
        return base_url

    def _timeout(self) -> float:
        return float(max(1, self._cfg.rideclaw_timeout_seconds or 30))

    async def airport_search(self, *, keyword: str, page_size: int = 20) -> dict[str, Any]:
        normalized_keyword = keyword.strip()
        if not normalized_keyword:
            raise AppHTTPException(status_code=422, detail="keyword must not be empty")
        payload = await self._request_json(
            "GET",
            "/open/v1/flight/airport/search",
            params={
                "keyword": normalized_keyword,
                "page_size": min(50, max(1, page_size)),
            },
        )
        return self._sanitize_airport_search(payload)

    async def flight_search(self, payload: dict[str, Any]) -> dict[str, Any]:
        body = self._clean_payload(payload)
        self._require_fields(body, ("from_code", "to_code", "depart_date"))
        body.setdefault("trip_mode", "domestic")
        body.setdefault("trip_type", "oneway")
        body.setdefault("passengers", {"adult": 1, "child": 0, "infant": 0})
        body["page_size"] = min(20, max(1, int(body.get("page_size") or 10)))
        raw = await self._request_json("POST", "/open/v1/flight/search", json=body)
        return self._sanitize_flight_search(raw)

    async def hotel_search(self, payload: dict[str, Any]) -> dict[str, Any]:
        body = self._clean_payload(payload)
        self._require_fields(body, ("destination", "check_in", "check_out"))
        body["page_size"] = min(50, max(1, int(body.get("page_size") or 10)))
        raw = await self._request_json("POST", "/open/v1/hotel/search", json=body)
        return self._sanitize_hotel_search(raw)

    async def hotel_rooms(self, payload: dict[str, Any]) -> dict[str, Any]:
        body = self._clean_payload(payload)
        if not body.get("rooms_ref") and not body.get("search_offer_id"):
            raise AppHTTPException(
                status_code=422,
                detail="rooms_ref is required for hotel room details",
            )
        if "rooms_ref" in body and "search_offer_id" not in body:
            body["search_offer_id"] = self._resolve_query_ref(body.pop("rooms_ref"))
        raw = await self._request_json("POST", "/open/v1/hotel/rooms", json=body)
        return self._sanitize_hotel_rooms(raw)

    async def _request_json(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        json: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        url = f"{self._base_url()}{path}"
        headers = {
            "Authorization": f"Bearer {self._api_token()}",
            "Accept": "application/json",
        }
        if json is not None:
            headers["Content-Type"] = "application/json"
        try:
            async with httpx.AsyncClient(timeout=self._timeout()) as client:
                response = await client.request(
                    method,
                    url,
                    headers=headers,
                    params=params,
                    json=json,
                )
            response.raise_for_status()
            payload = response.json()
        except httpx.HTTPStatusError as exc:
            raise AppHTTPException(
                status_code=exc.response.status_code,
                detail="RideClaw request failed",
                error_code="RIDECLAW_HTTP_ERROR",
                error_detail={"status_code": exc.response.status_code},
            ) from exc
        except httpx.TimeoutException as exc:
            raise AppHTTPException(
                status_code=504,
                detail="RideClaw request timed out",
                error_code="RIDECLAW_TIMEOUT",
            ) from exc
        except Exception as exc:
            raise AppHTTPException(
                status_code=502,
                detail="RideClaw request failed",
                error_code="RIDECLAW_REQUEST_FAILED",
                error_detail=str(exc),
            ) from exc

        if not isinstance(payload, dict):
            raise AppHTTPException(
                status_code=502,
                detail="RideClaw returned a non-object JSON body",
                error_code="RIDECLAW_INVALID_RESPONSE",
            )
        code = payload.get("code")
        if code not in (None, 0, "0"):
            raise AppHTTPException(
                status_code=502,
                detail=str(payload.get("message") or "RideClaw business error"),
                error_code="RIDECLAW_BUSINESS_ERROR",
                error_detail={"code": code},
            )
        return payload

    @staticmethod
    def _require_fields(payload: dict[str, Any], fields: tuple[str, ...]) -> None:
        missing = [field for field in fields if not str(payload.get(field) or "").strip()]
        if missing:
            raise AppHTTPException(
                status_code=422,
                detail=f"Missing required fields: {', '.join(missing)}",
                error_code="RIDECLAW_INPUT_MISSING",
                error_detail={"missing": missing},
            )

    @staticmethod
    def _clean_payload(payload: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(payload, dict):
            raise AppHTTPException(status_code=422, detail="payload must be a JSON object")
        cleaned: dict[str, Any] = {}
        for key, value in payload.items():
            if value in (None, ""):
                continue
            if str(key).lower() in _REQUEST_SECRET_KEYS:
                continue
            cleaned[key] = value
        return cleaned

    @staticmethod
    def _data(payload: dict[str, Any]) -> Any:
        return payload.get("data", payload)

    def _sanitize_airport_search(self, payload: dict[str, Any]) -> dict[str, Any]:
        data = self._data(payload)
        airports = (
            data.get("airports", data.get("items", data.get("list", [])))
            if isinstance(data, dict)
            else data
        )
        return {
            "airports": [self._pick(item, ("airport_code", "airport_name", "city_code", "city_name", "country_code", "country_name")) for item in self._as_list(airports)],
        }

    def _sanitize_flight_search(self, payload: dict[str, Any]) -> dict[str, Any]:
        data = self._data(payload)
        if not isinstance(data, dict):
            return {"flights": []}
        return {
            "page": data.get("page"),
            "page_size": data.get("page_size"),
            "total": data.get("total"),
            "detail_policy": _FLIGHT_RULE_DETAIL_NOTE,
            "flights": [self._sanitize_flight(item) for item in self._as_list(data.get("flights"))],
            "return_flights": [self._sanitize_flight(item) for item in self._as_list(data.get("return_flights"))],
        }

    def _sanitize_hotel_search(self, payload: dict[str, Any]) -> dict[str, Any]:
        data = self._data(payload)
        if not isinstance(data, dict):
            return {"hotels": []}
        return {
            "search_id": data.get("search_id"),
            "total": data.get("total"),
            "page_info": data.get("page_info"),
            "hotels": [self._sanitize_hotel(item) for item in self._as_list(data.get("hotels"))],
        }

    def _sanitize_hotel_rooms(self, payload: dict[str, Any]) -> dict[str, Any]:
        data = self._data(payload)
        return {
            "rooms": self._sanitize_recursive(data),
        }

    def _sanitize_flight(self, item: Any) -> dict[str, Any]:
        if not isinstance(item, dict):
            return {}
        summary = self._flight_summary(item)
        cabins = self._sanitize_cabins(item.get("cabins"))
        result: dict[str, Any] = self._pick(
            item,
            (
                "flight_no",
                "airline_code",
                "airline_name",
                "dep_time",
                "arr_time",
                "dep_airport_code",
                "dep_airport_name",
                "dep_terminal",
                "dep_city_code",
                "dep_city_name",
                "arr_airport_code",
                "arr_airport_name",
                "arr_terminal",
                "arr_city_code",
                "arr_city_name",
                "duration_minutes",
                "stop_count",
                "aircraft_type",
                "meal",
            ),
        )
        if summary:
            result["summary"] = summary
        if cabins:
            result["cabins"] = cabins
        return result

    def _sanitize_cabins(self, cabins: Any) -> list[str]:
        cabin_items = [item for item in self._as_list(cabins) if isinstance(item, dict)]
        if not cabin_items:
            return []
        sorted_items = sorted(cabin_items, key=self._fare_sort_price)
        return [summary for item in sorted_items[:3] if (summary := self._fare_summary(item))]

    @staticmethod
    def _fare_sort_price(item: dict[str, Any]) -> float:
        for key in ("lowest_price", "adult_price"):
            try:
                return float(item.get(key))
            except (TypeError, ValueError):
                continue
        return float("inf")

    def _flight_summary(self, item: dict[str, Any]) -> str:
        airline = self._string_or_none(item.get("airline_name"))
        flight_no = self._string_or_none(item.get("flight_no"))
        dep_time = self._short_datetime(item.get("dep_time"))
        arr_time = self._short_datetime(item.get("arr_time"))
        dep = self._airport_label(item, prefix="dep")
        arr = self._airport_label(item, prefix="arr")
        duration = self._duration_label(item.get("duration_minutes"))
        stop = self._stop_label(item.get("stop_count"))
        extras = [
            value
            for value in (
                duration,
                stop,
                self._aircraft_label(item.get("aircraft_type")),
                self._meal_label(item.get("meal")),
            )
            if value
        ]
        head = " ".join(value for value in (airline, flight_no) if value)
        route = f"{dep_time} {dep} -> {arr_time} {arr}".strip()
        tail = f" ({', '.join(extras)})" if extras else ""
        return f"{head} {route}{tail}".strip()

    def _fare_summary(self, item: dict[str, Any]) -> str:
        cabin = self._string_or_none(item.get("cabin_name")) or self._string_or_none(item.get("cabin_class")) or "Cabin"
        parts = [cabin]
        price = self._price_label(item.get("lowest_price"))
        if price:
            parts.append(price)
        taxes = self._tax_label(item)
        if taxes:
            parts.append(taxes)
        seat = self._seat_label(item.get("seat_status"))
        if seat:
            parts.append(seat)
        if item.get("pricing_required"):
            parts.append("price needs supplier confirmation")
        return ", ".join(parts)

    def _airport_label(self, item: dict[str, Any], *, prefix: str) -> str:
        airport = self._string_or_none(item.get(f"{prefix}_airport_name"))
        code = self._string_or_none(item.get(f"{prefix}_airport_code"))
        terminal = self._string_or_none(item.get(f"{prefix}_terminal"))
        label = airport or code or ""
        if code and airport:
            label = f"{airport} {code}"
        if terminal:
            label = f"{label} {terminal}".strip()
        return label

    @staticmethod
    def _short_datetime(value: Any) -> str:
        text = RideClawService._string_or_none(value)
        if not text:
            return ""
        return text[5:16] if len(text) >= 16 else text

    @staticmethod
    def _duration_label(value: Any) -> str | None:
        try:
            minutes = int(value)
        except (TypeError, ValueError):
            return None
        hours, remainder = divmod(minutes, 60)
        if hours and remainder:
            return f"{hours}h{remainder}m"
        if hours:
            return f"{hours}h"
        return f"{remainder}m"

    @staticmethod
    def _stop_label(value: Any) -> str | None:
        try:
            stops = int(value)
        except (TypeError, ValueError):
            return None
        return "direct" if stops == 0 else f"{stops} stop"

    @staticmethod
    def _meal_label(value: Any) -> str | None:
        text = RideClawService._string_or_none(value)
        if not text:
            return None
        return f"meal: {text}"

    @staticmethod
    def _aircraft_label(value: Any) -> str | None:
        text = RideClawService._string_or_none(value)
        if not text:
            return None
        return f"aircraft: {text}"

    @staticmethod
    def _price_label(value: Any) -> str | None:
        try:
            amount = float(value)
        except (TypeError, ValueError):
            return None
        formatted = int(amount) if amount.is_integer() else amount
        return f"from CNY {formatted}"

    @staticmethod
    def _tax_label(item: dict[str, Any]) -> str | None:
        total = 0.0
        found = False
        for key in ("airport_tax", "fuel_tax"):
            try:
                total += float(item.get(key))
                found = True
            except (TypeError, ValueError):
                continue
        if not found:
            return None
        formatted = int(total) if total.is_integer() else total
        return f"taxes CNY {formatted}"

    @staticmethod
    def _seat_label(value: Any) -> str | None:
        text = RideClawService._string_or_none(value)
        if not text:
            return None
        mapping = {
            "enough": "seats available",
            "few": "few seats",
            "none": "sold out",
        }
        return mapping.get(text.lower(), f"seat status: {text}")

    def _sanitize_hotel(self, item: Any) -> dict[str, Any]:
        if not isinstance(item, dict):
            return {}
        result = self._pick(
            item,
            (
                "hotel_id",
                "hotel_name",
                "hotel_name_en",
                "brand_name",
                "star_rating",
                "star_tag",
                "city",
                "district",
                "business_zone",
                "address",
                "latitude",
                "longitude",
                "distance_km",
                "lowest_price",
                "currency",
                "review_score",
                "review_count",
                "has_breakfast",
                "has_wifi",
                "has_parking",
                "has_restaurant",
                "scene_tags",
                "main_picture",
            ),
        )
        if item.get("search_offer_id"):
            result["rooms_ref"] = self._store_query_ref("hotel", item.get("search_offer_id"))
        return result

    def _sanitize_recursive(self, value: Any) -> Any:
        if isinstance(value, dict):
            cleaned: dict[str, Any] = {}
            for key, item in value.items():
                key_text = str(key)
                if key_text in _ORDER_TOKEN_KEYS or key_text.lower() in _REQUEST_SECRET_KEYS:
                    continue
                if key_text == "search_offer_id":
                    cleaned["query_ref"] = self._store_query_ref("query", item)
                    continue
                cleaned[key_text] = self._sanitize_recursive(self._compact_text(item))
            return cleaned
        if isinstance(value, list):
            return [self._sanitize_recursive(item) for item in value]
        return self._compact_text(value)

    def _store_query_ref(self, kind: str, raw: Any) -> str:
        raw_text = str(raw or "").strip()
        if not raw_text:
            return ""
        self._prune_query_refs()
        digest = hashlib.sha256(raw_text.encode("utf-8")).hexdigest()[:16]
        ref = f"rc_{kind}_{digest}"
        _QUERY_REFS[ref] = (time.time() + _QUERY_REF_TTL_SECONDS, raw_text)
        return ref

    def _resolve_query_ref(self, value: Any) -> str:
        text = str(value or "").strip()
        if not text:
            return ""
        self._prune_query_refs()
        cached = _QUERY_REFS.get(text)
        if cached is not None:
            return cached[1]
        return text

    @staticmethod
    def _prune_query_refs() -> None:
        now = time.time()
        expired = [key for key, (expires_at, _) in _QUERY_REFS.items() if expires_at < now]
        for key in expired:
            _QUERY_REFS.pop(key, None)

    @staticmethod
    def _compact_text(value: Any) -> Any:
        if not isinstance(value, str):
            return value
        text = value.strip()
        if len(text) <= 180:
            return text
        return f"{text[:177]}..."

    @staticmethod
    def _string_or_none(value: Any) -> str | None:
        if value is None:
            return None
        text = str(value).strip()
        return text or None

    @staticmethod
    def _pick(item: dict[str, Any], keys: tuple[str, ...]) -> dict[str, Any]:
        return {
            key: RideClawService._compact_text(item[key])
            for key in keys
            if item.get(key) not in (None, "")
        }

    @staticmethod
    def _as_list(value: Any) -> list[Any]:
        return value if isinstance(value, list) else []
