"""Public app metadata routes."""

from __future__ import annotations

from config import constants
from config.settings import get_app_config
from core.http.render import Response
from fastapi import APIRouter, Query
from services.mcp_tool_labels import mcp_tool_labels_for_locale

router = APIRouter(prefix="/app", tags=["app"])


@router.get("/version-policy")
async def version_policy(
    platform: str = Query(..., min_length=1),
    version: str = Query(..., min_length=1),
):
    """Return whether the current app version must update before continuing."""

    cfg = get_app_config()
    normalized_platform = platform.strip().lower()
    current_version_info = _version_info(version)
    minimum_version_info = _version_info("0.0.0+0")
    app_store_url: str | None = None
    update_required = False

    if normalized_platform == constants.PLATFORM_IOS:
        minimum_version_info = _version_info(cfg.min_ios_version)
        app_store_url = cfg.ios_app_store_url
        update_required = bool(app_store_url) and _compare_version_info(
            current_version_info,
            minimum_version_info,
        ) < 0

    return await Response.success(
        data={
            "platform": normalized_platform,
            "minimum_version": minimum_version_info.name,
            "minimum_build": minimum_version_info.build,
            "current_version": current_version_info.name,
            "current_build": current_version_info.build,
            "update_required": update_required,
            "update_url": app_store_url,
            "app_store_url": app_store_url,
        }
    )


@router.get("/tool-labels")
async def tool_labels(locale: str = Query("en", min_length=1)):
    """Return safe, user-facing MCP tool labels for the requested locale."""

    return await Response.success(data=mcp_tool_labels_for_locale(locale))


class _VersionInfo:
    def __init__(self, name: str, build: int) -> None:
        self.name = name
        self.build = build


def _version_info(value: str) -> _VersionInfo:
    raw = value.strip()
    name, separator, build_text = raw.partition("+")
    return _VersionInfo(
        name=_version_name(name),
        build=_version_build(build_text if separator else ""),
    )


def _version_name(value: str) -> str:
    return value.strip().split("+", 1)[0].strip() or "0.0.0"


def _version_build(value: str) -> int:
    normalized = value.strip()
    number = ""
    for char in normalized:
        if not char.isdigit():
            break
        number += char
    return int(number or "0")


def _compare_version_info(left: _VersionInfo, right: _VersionInfo) -> int:
    version_compare = _compare_versions(left.name, right.name)
    if version_compare != 0:
        return version_compare
    if left.build < right.build:
        return -1
    if left.build > right.build:
        return 1
    return 0


def _compare_versions(left: str, right: str) -> int:
    left_parts = _version_parts(left)
    right_parts = _version_parts(right)
    max_length = max(len(left_parts), len(right_parts))

    for index in range(max_length):
        left_part = left_parts[index] if index < len(left_parts) else 0
        right_part = right_parts[index] if index < len(right_parts) else 0
        if left_part < right_part:
            return -1
        if left_part > right_part:
            return 1
    return 0


def _version_parts(value: str) -> tuple[int, ...]:
    parts: list[int] = []
    for part in _version_name(value).split("."):
        number = ""
        for char in part:
            if not char.isdigit():
                break
            number += char
        parts.append(int(number or "0"))
    return tuple(parts)


__all__ = ["router"]
