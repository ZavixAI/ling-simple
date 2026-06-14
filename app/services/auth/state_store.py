"""认证相关 Redis 状态：短信 challenge、refresh token、邮箱验证码键空间与序列化。"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any

from config.settings import AppConfig, get_app_config
from core.infra.redis import redis
from models.base import get_local_now


def _serialize_datetime(value: datetime | None) -> str | None:
    return value.isoformat() if value is not None else None


def _deserialize_datetime(value: str | None) -> datetime | None:
    if not value:
        return None
    return datetime.fromisoformat(value)


def _seconds_until(value: datetime, *, now: datetime | None = None) -> int:
    reference = now or get_local_now()
    return max(0, math.ceil((value - reference).total_seconds()))


@dataclass
class RedisSmsChallengeState:
    challenge_id: str
    provider_id: str
    phone: str
    purpose: str
    code_hash: str
    status: str
    attempt_count: int
    max_attempts: int
    expire_at: datetime
    consumed_at: datetime | None
    created_at: datetime
    updated_at: datetime
    extra_data: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "challenge_id": self.challenge_id,
            "provider_id": self.provider_id,
            "phone": self.phone,
            "purpose": self.purpose,
            "code_hash": self.code_hash,
            "status": self.status,
            "attempt_count": self.attempt_count,
            "max_attempts": self.max_attempts,
            "expire_at": _serialize_datetime(self.expire_at),
            "consumed_at": _serialize_datetime(self.consumed_at),
            "created_at": _serialize_datetime(self.created_at),
            "updated_at": _serialize_datetime(self.updated_at),
            "extra_data": dict(self.extra_data or {}),
        }

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "RedisSmsChallengeState":
        return cls(
            challenge_id=str(payload["challenge_id"]),
            provider_id=str(payload["provider_id"]),
            phone=str(payload["phone"]),
            purpose=str(payload["purpose"]),
            code_hash=str(payload["code_hash"]),
            status=str(payload["status"]),
            attempt_count=int(payload["attempt_count"]),
            max_attempts=int(payload["max_attempts"]),
            expire_at=_deserialize_datetime(payload.get("expire_at")) or get_local_now(),
            consumed_at=_deserialize_datetime(payload.get("consumed_at")),
            created_at=_deserialize_datetime(payload.get("created_at")) or get_local_now(),
            updated_at=_deserialize_datetime(payload.get("updated_at")) or get_local_now(),
            extra_data=dict(payload.get("extra_data") or {}),
        )


@dataclass
class RedisEmailVerificationState:
    email: str
    code_hash: str
    expire_at: datetime
    resend_available_at: datetime
    created_at: datetime

    def to_dict(self) -> dict[str, Any]:
        return {
            "email": self.email,
            "code_hash": self.code_hash,
            "expire_at": _serialize_datetime(self.expire_at),
            "resend_available_at": _serialize_datetime(self.resend_available_at),
            "created_at": _serialize_datetime(self.created_at),
        }

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "RedisEmailVerificationState":
        return cls(
            email=str(payload["email"]),
            code_hash=str(payload["code_hash"]),
            expire_at=_deserialize_datetime(payload.get("expire_at")) or get_local_now(),
            resend_available_at=_deserialize_datetime(payload.get("resend_available_at"))
            or get_local_now(),
            created_at=_deserialize_datetime(payload.get("created_at")) or get_local_now(),
        )


@dataclass
class RedisAccessTokenState:
    token_id: str
    user_id: str
    provider_id: str
    token_hash: str
    scope: str
    device_id: str
    expire_at: datetime
    created_at: datetime
    updated_at: datetime
    user_data: dict[str, Any] = field(default_factory=dict)
    extra_data: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "token_id": self.token_id,
            "user_id": self.user_id,
            "provider_id": self.provider_id,
            "token_hash": self.token_hash,
            "scope": self.scope,
            "device_id": self.device_id,
            "expire_at": _serialize_datetime(self.expire_at),
            "created_at": _serialize_datetime(self.created_at),
            "updated_at": _serialize_datetime(self.updated_at),
            "user_data": dict(self.user_data or {}),
            "extra_data": dict(self.extra_data or {}),
        }

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "RedisAccessTokenState":
        return cls(
            token_id=str(payload["token_id"]),
            user_id=str(payload["user_id"]),
            provider_id=str(payload["provider_id"]),
            token_hash=str(payload["token_hash"]),
            scope=str(payload["scope"]),
            device_id=str(payload["device_id"]),
            expire_at=_deserialize_datetime(payload.get("expire_at")) or get_local_now(),
            created_at=_deserialize_datetime(payload.get("created_at")) or get_local_now(),
            updated_at=_deserialize_datetime(payload.get("updated_at")) or get_local_now(),
            user_data=dict(payload.get("user_data") or {}),
            extra_data=dict(payload.get("extra_data") or {}),
        )


@dataclass
class RedisRefreshTokenState:
    token_id: str
    user_id: str
    provider_id: str
    token_hash: str
    scope: str
    expire_at: datetime
    revoked_at: datetime | None
    last_used_at: datetime | None
    created_at: datetime
    updated_at: datetime
    extra_data: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "token_id": self.token_id,
            "user_id": self.user_id,
            "provider_id": self.provider_id,
            "token_hash": self.token_hash,
            "scope": self.scope,
            "expire_at": _serialize_datetime(self.expire_at),
            "revoked_at": _serialize_datetime(self.revoked_at),
            "last_used_at": _serialize_datetime(self.last_used_at),
            "created_at": _serialize_datetime(self.created_at),
            "updated_at": _serialize_datetime(self.updated_at),
            "extra_data": dict(self.extra_data or {}),
        }

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "RedisRefreshTokenState":
        return cls(
            token_id=str(payload["token_id"]),
            user_id=str(payload["user_id"]),
            provider_id=str(payload["provider_id"]),
            token_hash=str(payload["token_hash"]),
            scope=str(payload["scope"]),
            expire_at=_deserialize_datetime(payload.get("expire_at")) or get_local_now(),
            revoked_at=_deserialize_datetime(payload.get("revoked_at")),
            last_used_at=_deserialize_datetime(payload.get("last_used_at")),
            created_at=_deserialize_datetime(payload.get("created_at")) or get_local_now(),
            updated_at=_deserialize_datetime(payload.get("updated_at")) or get_local_now(),
            extra_data=dict(payload.get("extra_data") or {}),
        )


class RedisAuthStateStore:
    def __init__(self, cfg: AppConfig | None = None) -> None:
        self.cfg = cfg or get_app_config()

    def _sms_challenge_key(self, challenge_id: str) -> str:
        return redis.key("auth", "sms_challenge", challenge_id)

    def _sms_resend_key(self, provider_id: str, phone: str) -> str:
        return redis.key("auth", "sms_resend", provider_id, phone)

    def _email_verification_key(self, email: str) -> str:
        return redis.key("auth", "email_verification", email)

    def _email_resend_key(self, email: str) -> str:
        return redis.key("auth", "email_resend", email)

    def _refresh_token_key(self, token_hash: str) -> str:
        return redis.key("auth", "refresh_token", token_hash)

    def _refresh_user_tokens_key(self, user_id: str) -> str:
        return redis.key("auth", "refresh_tokens_by_user", user_id)

    def _access_token_key(self, token_hash: str) -> str:
        return redis.key("auth", "access_token", token_hash)

    def _access_user_tokens_key(self, user_id: str) -> str:
        return redis.key("auth", "access_tokens_by_user", user_id)

    def _access_device_tokens_key(self, user_id: str, device_id: str) -> str:
        return redis.key("auth", "access_tokens_by_device", user_id, device_id)

    async def reserve_sms_resend(self, phone: str, provider_id: str) -> int | None:
        key = self._sms_resend_key(provider_id, phone)
        reserved = await redis.set_if_absent(
            key,
            "1",
            ex=self.cfg.sms_challenge_resend_seconds,
        )
        if reserved:
            return None
        ttl = await redis.ttl(key)
        return ttl if ttl > 0 else self.cfg.sms_challenge_resend_seconds

    async def save_sms_challenge(self, state: RedisSmsChallengeState) -> None:
        ttl_seconds = _seconds_until(state.expire_at)
        if ttl_seconds <= 0:
            await redis.delete(self._sms_challenge_key(state.challenge_id))
            return
        await redis.set_json(
            self._sms_challenge_key(state.challenge_id),
            state.to_dict(),
            ex=ttl_seconds,
        )

    async def get_sms_challenge(self, challenge_id: str) -> RedisSmsChallengeState | None:
        payload = await redis.get_json(
            self._sms_challenge_key(challenge_id),
            default=None,
        )
        if payload is None:
            return None
        return RedisSmsChallengeState.from_dict(payload)

    async def begin_email_verification(
        self,
        email: str,
        *,
        code_hash: str,
        ttl_seconds: int,
        resend_seconds: int,
    ) -> int | None:
        resend_key = self._email_resend_key(email)
        reserved = await redis.set_if_absent(resend_key, "1", ex=resend_seconds)
        if not reserved:
            ttl = await redis.ttl(resend_key)
            return ttl if ttl > 0 else resend_seconds

        now = get_local_now()
        state = RedisEmailVerificationState(
            email=email,
            code_hash=code_hash,
            expire_at=now + timedelta(seconds=ttl_seconds),
            resend_available_at=now + timedelta(seconds=resend_seconds),
            created_at=now,
        )
        await redis.set_json(
            self._email_verification_key(email),
            state.to_dict(),
            ex=ttl_seconds,
        )
        return None

    async def get_email_verification(
        self,
        email: str,
    ) -> RedisEmailVerificationState | None:
        payload = await redis.get_json(
            self._email_verification_key(email),
            default=None,
        )
        if payload is None:
            return None
        return RedisEmailVerificationState.from_dict(payload)

    async def delete_email_verification(self, email: str) -> int:
        return await redis.delete(self._email_verification_key(email))

    async def delete_email_resend(self, email: str) -> int:
        return await redis.delete(self._email_resend_key(email))

    async def save_access_token(self, state: RedisAccessTokenState) -> None:
        ttl_seconds = _seconds_until(state.expire_at)
        token_key = self._access_token_key(state.token_hash)
        user_tokens_key = self._access_user_tokens_key(state.user_id)
        device_tokens_key = self._access_device_tokens_key(
            state.user_id,
            state.device_id,
        )
        if ttl_seconds <= 0:
            await redis.delete(token_key)
            await redis.srem(user_tokens_key, state.token_hash)
            await redis.srem(device_tokens_key, state.token_hash)
            return

        await redis.set_json(token_key, state.to_dict(), ex=ttl_seconds)
        await redis.sadd(user_tokens_key, state.token_hash)
        await redis.sadd(device_tokens_key, state.token_hash)
        for index_key in (user_tokens_key, device_tokens_key):
            current_ttl = await redis.ttl(index_key)
            if current_ttl < ttl_seconds:
                await redis.expire(index_key, ttl_seconds)

    async def get_access_token(self, token_hash: str) -> RedisAccessTokenState | None:
        payload = await redis.get_json(
            self._access_token_key(token_hash),
            default=None,
        )
        if payload is None:
            return None
        state = RedisAccessTokenState.from_dict(payload)
        if state.expire_at < get_local_now():
            await redis.delete(self._access_token_key(token_hash))
            await redis.srem(self._access_user_tokens_key(state.user_id), token_hash)
            await redis.srem(
                self._access_device_tokens_key(state.user_id, state.device_id),
                token_hash,
            )
            return None
        return state

    async def delete_access_token(self, token_hash: str) -> int:
        state = await self.get_access_token(token_hash)
        deleted = await redis.delete(self._access_token_key(token_hash))
        if state is not None:
            await redis.srem(self._access_user_tokens_key(state.user_id), token_hash)
            await redis.srem(
                self._access_device_tokens_key(state.user_id, state.device_id),
                token_hash,
            )
        return deleted

    async def delete_access_tokens_by_user(self, user_id: str) -> int:
        user_tokens_key = self._access_user_tokens_key(user_id)
        token_hashes = list(await redis.smembers(user_tokens_key))
        deleted = 0
        if token_hashes:
            states: list[RedisAccessTokenState] = []
            for token_hash in token_hashes:
                state = await self.get_access_token(token_hash)
                if state is not None:
                    states.append(state)
            deleted += await redis.delete(
                *[self._access_token_key(token_hash) for token_hash in token_hashes]
            )
            for state in states:
                await redis.srem(
                    self._access_device_tokens_key(state.user_id, state.device_id),
                    state.token_hash,
                )
        deleted += await redis.delete(user_tokens_key)
        return deleted

    async def delete_access_tokens_by_device(
        self,
        user_id: str,
        device_id: str,
    ) -> int:
        device_tokens_key = self._access_device_tokens_key(user_id, device_id)
        token_hashes = list(await redis.smembers(device_tokens_key))
        deleted = 0
        if token_hashes:
            deleted += await redis.delete(
                *[self._access_token_key(token_hash) for token_hash in token_hashes]
            )
            await redis.srem(self._access_user_tokens_key(user_id), *token_hashes)
        deleted += await redis.delete(device_tokens_key)
        return deleted

    async def delete_access_tokens_by_user_except_device(
        self,
        user_id: str,
        keep_device_id: str,
    ) -> int:
        user_tokens_key = self._access_user_tokens_key(user_id)
        token_hashes = list(await redis.smembers(user_tokens_key))
        delete_hashes: list[str] = []
        delete_device_ids: set[str] = set()
        for token_hash in token_hashes:
            state = await self.get_access_token(token_hash)
            if state is None:
                delete_hashes.append(token_hash)
                continue
            if state.device_id != keep_device_id:
                delete_hashes.append(token_hash)
                delete_device_ids.add(state.device_id)

        deleted = 0
        if delete_hashes:
            deleted += await redis.delete(
                *[self._access_token_key(token_hash) for token_hash in delete_hashes]
            )
            await redis.srem(user_tokens_key, *delete_hashes)
            for device_id in delete_device_ids:
                await redis.srem(
                    self._access_device_tokens_key(user_id, device_id),
                    *delete_hashes,
                )
        return deleted

    async def save_refresh_token(self, state: RedisRefreshTokenState) -> None:
        ttl_seconds = _seconds_until(state.expire_at)
        if ttl_seconds <= 0:
            await redis.delete(self._refresh_token_key(state.token_hash))
            await redis.srem(self._refresh_user_tokens_key(state.user_id), state.token_hash)
            return
        await redis.set_json(
            self._refresh_token_key(state.token_hash),
            state.to_dict(),
            ex=ttl_seconds,
        )
        user_tokens_key = self._refresh_user_tokens_key(state.user_id)
        await redis.sadd(user_tokens_key, state.token_hash)
        current_ttl = await redis.ttl(user_tokens_key)
        if current_ttl < ttl_seconds:
            await redis.expire(user_tokens_key, ttl_seconds)

    async def get_refresh_token(self, token_hash: str) -> RedisRefreshTokenState | None:
        payload = await redis.get_json(
            self._refresh_token_key(token_hash),
            default=None,
        )
        if payload is None:
            return None
        return RedisRefreshTokenState.from_dict(payload)

    async def delete_refresh_tokens_by_user(self, user_id: str) -> int:
        user_tokens_key = self._refresh_user_tokens_key(user_id)
        token_hashes = list(await redis.smembers(user_tokens_key))
        deleted = 0
        if token_hashes:
            deleted += await redis.delete(
                *[self._refresh_token_key(token_hash) for token_hash in token_hashes]
            )
        deleted += await redis.delete(user_tokens_key)
        return deleted
