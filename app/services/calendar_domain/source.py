"""Calendar source/provider normalization policy."""

from __future__ import annotations

from typing import Any

from config import constants


def normalize_source(value: Any) -> str:
    source = str(value or constants.CALENDAR_SOURCE_LING).strip().lower()
    if source in constants.CALENDAR_EXTERNAL_SOURCES:
        return source
    return constants.CALENDAR_SOURCE_LING


def event_source(event: Any) -> str:
    return normalize_source(getattr(event, "source", None))


def provider_for_source(source: str) -> str:
    normalized = str(source).strip().lower()
    if normalized == constants.CALENDAR_SOURCE_APPLE:
        return constants.CALENDAR_SOURCE_APPLE_LOCAL
    if normalized in {"feishu", "dingtalk"}:
        return normalized
    return constants.CALENDAR_SOURCE_LING
