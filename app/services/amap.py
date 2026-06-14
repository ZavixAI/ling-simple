"""高德地图 Web 服务 API 客户端（地理编码、逆地理、POI、路线、天气）。"""

from __future__ import annotations

from typing import Any
from urllib.parse import urlencode

import httpx
from config.settings import AppConfig, get_app_config
from core.http.exceptions import AppHTTPException

_AMAP_HTTP_TIMEOUT = 20.0


class AmapWebService:
    """封装 restapi.amap.com 常用接口，供 MCP 等模块调用。"""

    def __init__(self, cfg: AppConfig | None = None) -> None:
        self._cfg = cfg or get_app_config()

    def _api_key(self) -> str:
        raw = getattr(self._cfg, "amap_web_key", None)
        key = (raw or "").strip()
        if not key:
            raise AppHTTPException(
                status_code=503,
                detail="Amap Web Service key is not configured; set LING_AMAP_WEB_KEY",
                error_code="AMAP_KEY_MISSING",
            )
        return key

    @staticmethod
    async def _get_json(url: str) -> dict[str, Any]:
        async with httpx.AsyncClient(timeout=_AMAP_HTTP_TIMEOUT) as client:
            response = await client.get(url)
        response.raise_for_status()
        payload = response.json()
        if not isinstance(payload, dict):
            raise AppHTTPException(
                status_code=502,
                detail="Amap returned a non-object JSON body",
                error_code="AMAP_INVALID_RESPONSE",
            )
        return payload

    async def geocode_address(
        self,
        *,
        address: str,
        city: str | None = None,
    ) -> dict[str, Any]:
        """地理编码：结构化地址 → 经纬度候选（支持多地名/相似结果）。"""
        addr = address.strip()
        if not addr:
            raise AppHTTPException(status_code=422, detail="address must not be empty")

        q: dict[str, str] = {
            "key": self._api_key(),
            "address": addr,
            "output": "json",
        }
        if city and city.strip():
            q["city"] = city.strip()
        url = f"https://restapi.amap.com/v3/geocode/geo?{urlencode(q)}"
        return await self._get_json(url)

    async def reverse_geocode(
        self,
        *,
        longitude: float,
        latitude: float,
        radius: int | None = None,
        extensions: str = "base",
        poitype: str | None = None,
    ) -> dict[str, Any]:
        """逆地理编码：经纬度 → 结构化地址（extensions=all 时可带周边 POI）。"""
        loc = f"{longitude:.6f},{latitude:.6f}"
        q: dict[str, str] = {
            "key": self._api_key(),
            "location": loc,
            "output": "json",
            "extensions": extensions if extensions in {"base", "all"} else "base",
        }
        if radius is not None:
            if not 0 <= radius <= 3000:
                raise AppHTTPException(
                    status_code=422,
                    detail="radius must be between 0 and 3000 meters",
                )
            q["radius"] = str(radius)
        if poitype and poitype.strip():
            q["poitype"] = poitype.strip()
        url = f"https://restapi.amap.com/v3/geocode/regeo?{urlencode(q)}"
        return await self._get_json(url)

    async def search_poi_text(
        self,
        *,
        keywords: str | None = None,
        types: str | None = None,
        region: str | None = None,
        city_limit: bool = False,
        page_size: int = 10,
        page_num: int = 1,
        show_fields: str | None = None,
    ) -> dict[str, Any]:
        """地点搜索 2.0：关键字或类型检索 POI（二选一必填）。"""
        kw = keywords.strip() if keywords else ""
        tc = types.strip() if types else ""
        if not kw and not tc:
            raise AppHTTPException(
                status_code=422,
                detail="Either keywords or types must be provided for POI search",
            )
        if len(kw) > 80:
            raise AppHTTPException(status_code=422, detail="keywords length must not exceed 80 characters")

        q: dict[str, str] = {
            "key": self._api_key(),
            "page_size": str(min(25, max(1, page_size))),
            "page_num": str(max(1, page_num)),
        }
        if kw:
            q["keywords"] = kw
        if tc:
            q["types"] = tc
        if region and region.strip():
            q["region"] = region.strip()
        if city_limit:
            q["city_limit"] = "true"
        if show_fields and show_fields.strip():
            q["show_fields"] = show_fields.strip()

        url = f"https://restapi.amap.com/v5/place/text?{urlencode(q)}"
        return await self._get_json(url)

    async def search_poi(
        self,
        *,
        search_type: str = "text",
        keywords: str | None = None,
        types: str | None = None,
        region: str | None = None,
        city_limit: bool = False,
        location: str | None = None,
        radius: int | None = None,
        page_size: int = 10,
        page_num: int = 1,
        show_fields: str | None = None,
    ) -> dict[str, Any]:
        """地点搜索 2.0：文本、周边检索。"""
        kind = (search_type or "text").strip().lower()
        if kind not in {"text", "around"}:
            raise AppHTTPException(status_code=422, detail="search_type must be text or around")

        q: dict[str, str] = {
            "key": self._api_key(),
            "output": "json",
        }
        if show_fields and show_fields.strip():
            q["show_fields"] = show_fields.strip()

        if kind == "text":
            kw = keywords.strip() if keywords else ""
            tc = types.strip() if types else ""
            if not kw and not tc:
                raise AppHTTPException(
                    status_code=422,
                    detail="Either keywords or types must be provided for POI text search",
                )
            if len(kw) > 80:
                raise AppHTTPException(status_code=422, detail="keywords length must not exceed 80 characters")
            q["page_size"] = str(min(25, max(1, page_size)))
            q["page_num"] = str(max(1, page_num))
            if kw:
                q["keywords"] = kw
            if tc:
                q["types"] = tc
            if region and region.strip():
                q["region"] = region.strip()
            if city_limit:
                q["city_limit"] = "true"
            url = f"https://restapi.amap.com/v5/place/text?{urlencode(q)}"
            return await self._get_json(url)

        if kind == "around":
            loc = (location or "").strip()
            if not loc:
                raise AppHTTPException(status_code=422, detail="location is required for POI around search")
            kw = keywords.strip() if keywords else ""
            tc = types.strip() if types else ""
            if len(kw) > 80:
                raise AppHTTPException(status_code=422, detail="keywords length must not exceed 80 characters")
            q["location"] = loc
            q["radius"] = str(min(50000, max(0, radius if radius is not None else 1000)))
            q["page_size"] = str(min(25, max(1, page_size)))
            q["page_num"] = str(max(1, page_num))
            if kw:
                q["keywords"] = kw
            if tc:
                q["types"] = tc
            url = f"https://restapi.amap.com/v5/place/around?{urlencode(q)}"
            return await self._get_json(url)

    async def route_plan(
        self,
        *,
        mode: str,
        origin: str,
        destination: str,
        strategy: str | None = None,
        show_fields: str | None = None,
        isindoor: int | None = None,
        origin_city: str | None = None,
        destination_city: str | None = None,
    ) -> dict[str, Any]:
        """路径规划 2.0：驾车、步行、骑行、电动车、公共交通。"""
        route_mode = (mode or "").strip().lower()
        endpoints = {
            "driving": "driving",
            "walking": "walking",
            "bicycling": "bicycling",
            "electrobike": "electrobike",
            "transit": "transit/integrated",
        }
        if route_mode not in endpoints:
            raise AppHTTPException(
                status_code=422,
                detail="mode must be driving, walking, bicycling, electrobike, or transit",
            )

        orig = origin.strip()
        dest = destination.strip()
        if not orig or not dest:
            raise AppHTTPException(status_code=422, detail="origin and destination must not be empty")

        q: dict[str, str] = {
            "key": self._api_key(),
            "origin": orig,
            "destination": dest,
            "output": "json",
        }
        if route_mode in {"driving", "transit"} and strategy and strategy.strip():
            q["strategy"] = strategy.strip()
        if show_fields and show_fields.strip():
            q["show_fields"] = show_fields.strip()
        if route_mode == "walking" and isindoor is not None:
            q["isindoor"] = "1" if isindoor else "0"

        if route_mode == "transit":
            city1 = (origin_city or "").strip()
            city2 = (destination_city or "").strip()
            if not city1 or not city2:
                raise AppHTTPException(
                    status_code=422,
                    detail="origin_city and destination_city are required for transit route planning",
                )
            q["city1"] = city1
            q["city2"] = city2

        path = endpoints[route_mode]
        url = f"https://restapi.amap.com/v5/direction/{path}?{urlencode(q)}"
        return await self._get_json(url)

    async def weather(
        self,
        *,
        city_adcode: str,
        extensions: str = "base",
    ) -> dict[str, Any]:
        """天气查询：城市 / 区域 adcode。"""
        code = city_adcode.strip()
        if not code:
            raise AppHTTPException(status_code=422, detail="city_adcode must not be empty")
        ext = extensions if extensions in {"base", "all"} else "base"
        q: dict[str, str] = {
            "key": self._api_key(),
            "city": code,
            "extensions": ext,
            "output": "json",
        }
        url = f"https://restapi.amap.com/v3/weather/weatherInfo?{urlencode(q)}"
        return await self._get_json(url)


__all__ = ["AmapWebService"]
