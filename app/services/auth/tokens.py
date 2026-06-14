"""Shared auth token helpers."""

from __future__ import annotations

import hashlib

ACCESS_TOKEN_PREFIX = "at_"
REFRESH_TOKEN_PREFIX = "rt_"


def hash_token(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def is_opaque_access_token(value: str) -> bool:
    return value.strip().startswith(ACCESS_TOKEN_PREFIX)
