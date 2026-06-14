"""Agent 消息持久化辅助：从 Sage 流中识别工具调用名，决定是否落库工具参数白名单。"""

from __future__ import annotations

import json
from typing import Any

def resolve_tool_call_function_name(tool_call: dict[str, Any] | None) -> str | None:
    if not isinstance(tool_call, dict):
        return None
    function_payload = tool_call.get("function")
    if isinstance(function_payload, dict):
        return _normalized_string(function_payload.get("name"))
    return _normalized_string(tool_call.get("name"))


def resolve_tool_call_result_function_name(tool_result: str | None) -> str | None:
    payload = _decode_tool_call_result_payload(tool_result)
    if payload is None:
        return None
    direct_function_name = _normalized_string(payload.get("function_name"))
    if direct_function_name is not None:
        return direct_function_name
    direct_action = _normalized_string(payload.get("action"))
    if direct_action is not None:
        return direct_action
    data = payload.get("data")
    if isinstance(data, dict):
        return _normalized_string(data.get("function_name"))
    return None


def _decode_tool_call_result_payload(tool_result: str | None) -> dict[str, Any] | None:
    normalized = _normalized_string(tool_result)
    if normalized is None:
        return None
    try:
        decoded = json.loads(normalized)
    except Exception:
        return None
    if isinstance(decoded, dict):
        return decoded
    return None


def _normalized_string(value: Any) -> str | None:
    if value is None:
        return None
    normalized = str(value).strip()
    if not normalized or normalized == "null":
        return None
    return normalized
