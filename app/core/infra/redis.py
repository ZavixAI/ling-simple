"""Shared Redis client helpers for temporary backend state."""

from __future__ import annotations

import inspect
import json
from collections.abc import AsyncIterator, Awaitable, Callable, Mapping
from contextlib import asynccontextmanager
from typing import Any, Protocol, cast
from urllib.parse import quote

from config import constants
from config.settings import AppConfig, get_app_config
from core.http.exceptions import AppHTTPException
from loguru import logger
from redis.asyncio import Redis

_REDIS_KEY_PREFIX = constants.REDIS_KEY_PREFIX


class _RedisLock(Protocol):
    def acquire(self) -> Awaitable[bool]: ...

    def release(self) -> Awaitable[None]: ...


class _AsyncRedisClient(Protocol):
    def ping(self) -> Awaitable[bool]: ...

    def set(
        self,
        name: str,
        value: Any,
        *,
        ex: int | None = None,
        nx: bool = False,
    ) -> Awaitable[Any]: ...

    def get(self, name: str) -> Awaitable[Any]: ...

    def delete(self, *names: str) -> Awaitable[int]: ...

    def ttl(self, name: str) -> Awaitable[int]: ...

    def expire(self, name: str, time: int) -> Awaitable[bool]: ...

    def sadd(self, name: str, *values: Any) -> Awaitable[int]: ...

    def srem(self, name: str, *values: Any) -> Awaitable[int]: ...

    def smembers(self, name: str) -> Awaitable[set[Any]]: ...

    def xadd(
        self,
        name: str,
        fields: Mapping[str, Any],
        *,
        maxlen: int | None = None,
        approximate: bool = True,
    ) -> Awaitable[str]: ...

    def xread(
        self,
        streams: Mapping[str, str],
        *,
        count: int | None = None,
        block: int | None = None,
    ) -> Awaitable[Any]: ...

    def eval(self, script: str, numkeys: int, *args: Any) -> Awaitable[Any]: ...

    def lock(
        self,
        name: str,
        *,
        timeout: float,
        sleep: float,
        blocking: bool,
        blocking_timeout: float | None,
        raise_on_release_error: bool,
    ) -> _RedisLock: ...


def _build_redis_url(cfg: AppConfig | None = None) -> str:
    resolved_cfg = cfg or get_app_config()
    auth_segment = ""
    username = (resolved_cfg.redis_username or "").strip()
    password = (resolved_cfg.redis_password or "").strip()
    if username or password:
        auth_segment = f"{quote(username, safe='')}:{quote(password, safe='')}@"

    host = (resolved_cfg.redis_host or "127.0.0.1").strip()
    port = int(resolved_cfg.redis_port or 6379)
    db = int(resolved_cfg.redis_db or 0)
    return f"redis://{auth_segment}{host}:{port}/{db}"


def _sanitize_redis_url(redis_url: str) -> str:
    if "@" not in redis_url:
        return redis_url
    _, suffix = redis_url.rsplit("@", 1)
    return f"redis://***@{suffix}"


class RedisAdapter:
    def __init__(self) -> None:
        self._client: _AsyncRedisClient | None = None

    def _client_or_raise(self) -> _AsyncRedisClient:
        if self._client is None:
            raise AppHTTPException(
                status_code=503,
                detail="Redis client is not initialized",
                error_detail="redis client not initialized",
            )
        return self._client

    async def init(self, cfg: AppConfig | None = None) -> _AsyncRedisClient | None:
        """Initialize the shared Redis client."""

        if self._client is not None:
            return self._client

        resolved_cfg = cfg or get_app_config()

        redis_url = _build_redis_url(resolved_cfg)
        try:
            client = cast(
                _AsyncRedisClient,
                Redis.from_url(
                    redis_url,
                    encoding="utf-8",
                    decode_responses=True,
                    socket_connect_timeout=5,
                    socket_timeout=30,
                    health_check_interval=30,
                ),
            )
            await client.ping()
            self._client = client
            logger.info("Redis 客户端初始化成功: {}", _sanitize_redis_url(redis_url))
            return self._client
        except Exception as error:
            logger.error("Redis 客户端初始化失败: {}", error)
            raise AppHTTPException(
                status_code=503,
                detail="Redis 初始化失败",
                error_detail=str(error),
            ) from error

    def key(self, *parts: str) -> str:
        normalized_parts = [
            str(part).strip(":")
            for part in parts
            if str(part or "").strip(":")
        ]
        key_prefix = _REDIS_KEY_PREFIX.strip(":")
        if key_prefix:
            normalized_parts.insert(0, key_prefix)
        return ":".join(normalized_parts)

    async def set(self, key: str, value: Any, *, ex: int | None = None) -> bool:
        client = self._client_or_raise()
        return bool(await client.set(key, value, ex=ex))

    async def get(self, key: str, *, default: Any = None) -> Any:
        client = self._client_or_raise()
        value = await client.get(key)
        return default if value is None else value

    async def delete(self, *keys: str) -> int:
        normalized_keys = [key for key in keys if key]
        if not normalized_keys:
            return 0
        client = self._client_or_raise()
        return int(await client.delete(*normalized_keys))

    async def ttl(self, key: str) -> int:
        client = self._client_or_raise()
        return int(await client.ttl(key))

    async def expire(self, key: str, seconds: int) -> bool:
        client = self._client_or_raise()
        return bool(await client.expire(key, max(1, int(seconds))))

    async def set_if_absent(
        self,
        key: str,
        value: Any,
        *,
        ex: int | None = None,
    ) -> bool:
        client = self._client_or_raise()
        return bool(await client.set(key, value, ex=ex, nx=True))

    async def set_json(
        self,
        key: str,
        value: Any,
        *,
        ex: int | None = None,
    ) -> bool:
        return await self.set(key, json.dumps(value, ensure_ascii=False), ex=ex)

    async def get_json(self, key: str, *, default: Any = None) -> Any:
        payload = await self.get(key, default=None)
        if payload is None:
            return default
        return json.loads(payload)

    async def sadd(self, key: str, *values: Any) -> int:
        client = self._client_or_raise()
        return int(await client.sadd(key, *values))

    async def srem(self, key: str, *values: Any) -> int:
        client = self._client_or_raise()
        return int(await client.srem(key, *values))

    async def smembers(self, key: str) -> set[Any]:
        client = self._client_or_raise()
        return set(await client.smembers(key))

    async def stream_add(
        self,
        key: str,
        fields: dict[str, Any],
        *,
        maxlen: int | None = None,
        approximate: bool = True,
    ) -> str:
        client = self._client_or_raise()
        return str(
            await client.xadd(
                key,
                fields,
                maxlen=maxlen,
                approximate=approximate,
            )
        )

    async def stream_read(
        self,
        streams: dict[str, str],
        *,
        count: int | None = None,
        block: int | None = None,
    ) -> Any:
        client = self._client_or_raise()
        return await client.xread(streams, count=count, block=block)

    async def eval(self, script: str, numkeys: int, *args: Any) -> Any:
        client = self._client_or_raise()
        return await client.eval(script, numkeys, *args)

    async def close(self) -> None:
        if self._client is None:
            return

        close = getattr(self._client, "aclose", None) or getattr(
            self._client,
            "close",
            None,
        )
        if callable(close):
            result = close()
            if inspect.isawaitable(result):
                await result

        self._client = None
        logger.info("Redis 客户端已关闭")

    @asynccontextmanager
    async def lock(
        self,
        name: str,
        *,
        ttl_seconds: float = 30.0,
        wait_timeout_seconds: float = 0.0,
        retry_interval_seconds: float = 0.1,
    ) -> AsyncIterator[bool]:
        normalized_name = str(name or "").strip(": ")
        if not normalized_name:
            yield False
            return

        lock_key = self.key("lock", normalized_name)
        client = self._client_or_raise()
        lock = client.lock(
            lock_key,
            timeout=max(1.0, float(ttl_seconds)),
            sleep=max(0.01, float(retry_interval_seconds)),
            blocking=wait_timeout_seconds > 0,
            blocking_timeout=max(0.0, float(wait_timeout_seconds))
            if wait_timeout_seconds > 0
            else None,
            raise_on_release_error=False,
        )
        acquired = bool(await lock.acquire())
        if not acquired:
            yield False
            return

        try:
            yield True
        finally:
            try:
                await lock.release()
            except Exception as exc:
                logger.warning(
                    "[RedisLock] 释放 redis 锁失败 "
                    f"name={normalized_name} reason={exc}"
                )

    @asynccontextmanager
    async def lock_or_raise(
        self,
        name: str,
        *,
        error: Exception | Callable[[], Exception],
        ttl_seconds: float = 30.0,
        wait_timeout_seconds: float = 0.0,
        retry_interval_seconds: float = 0.1,
    ) -> AsyncIterator[None]:
        async with self.lock(
            name,
            ttl_seconds=ttl_seconds,
            wait_timeout_seconds=wait_timeout_seconds,
            retry_interval_seconds=retry_interval_seconds,
        ) as acquired:
            if not acquired:
                raise error() if callable(error) else error
            yield


redis = RedisAdapter()
