"""Case-conversion helpers for payload data."""

from __future__ import annotations

import re
from typing import Any

from pydantic import BaseModel

_FIRST_PASS_CAMEL_PATTERN = re.compile(r"(.)([A-Z][a-z]+)")
_SECOND_PASS_CAMEL_PATTERN = re.compile(r"([a-z0-9])([A-Z])")
_IDENTIFIER_KEY_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_-]*$")


def to_snake_case_key(key: str) -> str:
    """Convert one key to snake_case."""

    if not key or not _IDENTIFIER_KEY_PATTERN.match(key):
        return key

    normalized = key.replace("-", "_")
    first_pass = _FIRST_PASS_CAMEL_PATTERN.sub(r"\1_\2", normalized)
    second_pass = _SECOND_PASS_CAMEL_PATTERN.sub(r"\1_\2", first_pass)
    return second_pass.lower()


def to_snake_case_data(value: Any) -> Any:
    """Recursively convert dictionary keys to snake_case."""

    if isinstance(value, BaseModel):
        return to_snake_case_data(value.model_dump())

    if isinstance(value, dict):
        return {
            to_snake_case_key(key) if isinstance(key, str) else key: to_snake_case_data(
                item
            )
            for key, item in value.items()
        }

    if isinstance(value, list):
        return [to_snake_case_data(item) for item in value]

    if isinstance(value, tuple):
        return [to_snake_case_data(item) for item in value]

    if isinstance(value, set):
        return [to_snake_case_data(item) for item in value]

    return value
