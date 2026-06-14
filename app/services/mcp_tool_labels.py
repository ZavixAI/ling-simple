"""User-facing labels for MCP tool names."""

from __future__ import annotations

import hashlib
import json
from typing import Any

SUPPORTED_TOOL_LABEL_LOCALES = ("en", "zh")

_TOOL_LABELS: dict[str, dict[str, str]] = {
    "calendar_complete_event": {
        "en": "complete event",
        "zh": "完成日程",
    },
    "calendar_create_event": {
        "en": "create event",
        "zh": "创建日程",
    },
    "calendar_delete_event": {
        "en": "delete event",
        "zh": "删除日程",
    },
    "calendar_list_events": {
        "en": "calendar lookup",
        "zh": "读取日程",
    },
    "calendar_update_event": {
        "en": "update event",
        "zh": "更新日程",
    },
    "location_geocode_address": {
        "en": "geocode address",
        "zh": "地址解析为坐标",
    },
    "location_reverse_geocode": {
        "en": "reverse geocode",
        "zh": "坐标解析为地址",
    },
    "location_route_plan": {
        "en": "route planning",
        "zh": "路线规划",
    },
    "location_search_poi": {
        "en": "search places",
        "zh": "地点搜索",
    },
    "location_weather_query": {
        "en": "weather lookup",
        "zh": "天气查询",
    },
    "travel_flight_airport_search": {
        "en": "search airports",
        "zh": "查询机场",
    },
    "travel_flight_search": {
        "en": "search flights",
        "zh": "查询航班",
    },
    "travel_hotel_rooms": {
        "en": "check hotel rooms",
        "zh": "查询酒店房型",
    },
    "travel_hotel_search": {
        "en": "search hotels",
        "zh": "查询酒店",
    },
}


def normalized_tool_label_locale(locale: str | None) -> str:
    normalized = (locale or "").strip().lower()
    if normalized.startswith("zh"):
        return "zh"
    return "en"


def mcp_tool_label_registry_version() -> str:
    payload = json.dumps(_TOOL_LABELS, ensure_ascii=False, sort_keys=True)
    digest = hashlib.sha256(payload.encode("utf-8")).hexdigest()[:12]
    return f"mcp-tool-labels-{digest}"


def mcp_tool_labels_for_locale(locale: str | None) -> dict[str, Any]:
    resolved_locale = normalized_tool_label_locale(locale)
    labels = {
        name: values[resolved_locale]
        for name, values in sorted(_TOOL_LABELS.items())
        if resolved_locale in values
    }
    return {
        "version": mcp_tool_label_registry_version(),
        "locale": resolved_locale,
        "labels": labels,
    }


def all_mcp_tool_label_names() -> set[str]:
    return set(_TOOL_LABELS)


def labels_for_tool(name: str) -> dict[str, str] | None:
    return _TOOL_LABELS.get(name)


__all__ = [
    "SUPPORTED_TOOL_LABEL_LOCALES",
    "all_mcp_tool_label_names",
    "labels_for_tool",
    "mcp_tool_label_registry_version",
    "mcp_tool_labels_for_locale",
    "normalized_tool_label_locale",
]
