"""邮箱注册验证码：发信、限流、Redis 存哈希与 TTL，与注册流程解耦。"""

from __future__ import annotations

import hashlib
import re
import secrets

from config.settings import get_app_config
from core.http.exceptions import AppHTTPException
from core.infra.eml import eml
from core.infra.redis import redis
from loguru import logger
from services.auth.state_store import RedisAuthStateStore

REGISTER_VERIFICATION_CODE_LENGTH = 6
REGISTER_VERIFICATION_CODE_TTL_SECONDS = 5 * 60
REGISTER_VERIFICATION_RESEND_INTERVAL_SECONDS = 30

_EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_CODE_PATTERN = re.compile(r"^\d{6}$")


def normalize_email(email: str | None) -> str:
    return (email or "").strip().lower()


def validate_register_email(email: str | None) -> str:
    normalized_email = normalize_email(email)
    if not normalized_email:
        raise AppHTTPException(
            status_code=422,
            detail="请输入邮箱地址",
            error_detail="email is required",
        )
    if not _EMAIL_PATTERN.fullmatch(normalized_email):
        raise AppHTTPException(
            status_code=422,
            detail="邮箱格式不正确",
            error_detail="invalid email format",
        )
    return normalized_email


def validate_verification_code(code: str | None) -> str:
    normalized_code = (code or "").strip()
    if not _CODE_PATTERN.fullmatch(normalized_code):
        raise AppHTTPException(
            status_code=422,
            detail="验证码错误",
            error_detail="invalid verification code format",
        )
    return normalized_code


def _generate_verification_code() -> str:
    return "".join(
        secrets.choice("0123456789")
        for _ in range(REGISTER_VERIFICATION_CODE_LENGTH)
    )


def _hash_verification_code(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


async def send_register_email_code(email: str) -> tuple[int, int]:
    normalized_email = validate_register_email(email)
    cfg = get_app_config()
    store = RedisAuthStateStore(cfg)
    code = _generate_verification_code()

    async with redis.lock_or_raise(
        f"auth:email-code:{normalized_email}",
        error=lambda: AppHTTPException(
            status_code=409,
            detail="邮箱验证码请求处理中，请稍后重试",
            error_detail="email verification lock timeout",
        ),
        ttl_seconds=10,
        wait_timeout_seconds=2,
    ):
        remaining_seconds = await store.begin_email_verification(
            normalized_email,
            code_hash=_hash_verification_code(code),
            ttl_seconds=REGISTER_VERIFICATION_CODE_TTL_SECONDS,
            resend_seconds=REGISTER_VERIFICATION_RESEND_INTERVAL_SECONDS,
        )
        if remaining_seconds is not None:
            raise AppHTTPException(
                status_code=429,
                detail=f"验证码发送过于频繁，请 {remaining_seconds} 秒后重试",
                error_detail="verification code send throttled",
            )

    try:
        await _send_register_verification_mail(normalized_email, code)
    except Exception:
        await store.delete_email_verification(normalized_email)
        try:
            await store.delete_email_resend(normalized_email)
        except Exception:
            pass
        raise

    logger.info(f"注册验证码已生成并发送: {normalized_email}")
    return (
        REGISTER_VERIFICATION_CODE_TTL_SECONDS,
        REGISTER_VERIFICATION_RESEND_INTERVAL_SECONDS,
    )


async def _send_register_verification_mail(to_address: str, code: str) -> None:
    cfg = get_app_config()
    template_id = (cfg.eml_template_id or "").strip()
    subject = (cfg.eml_register_subject or "").strip()

    try:
        await eml.send_template_mail(
            to_address=to_address,
            template_id=template_id,
            template_data={"code": code},
            subject=subject,
            cfg=cfg,
        )
        logger.info(f"注册验证码邮件发送成功: {to_address}")
    except AppHTTPException:
        logger.error(f"注册验证码邮件发送失败: {to_address}")
        raise


async def verify_register_email_code(email: str, code: str) -> None:
    normalized_email = validate_register_email(email)
    normalized_code = validate_verification_code(code)
    store = RedisAuthStateStore()

    record = await store.get_email_verification(normalized_email)
    if not record:
        raise AppHTTPException(
            status_code=400,
            detail="验证码错误",
            error_detail="verification code missing or expired",
        )
    if record.code_hash != _hash_verification_code(normalized_code):
        raise AppHTTPException(
            status_code=400,
            detail="验证码错误",
            error_detail="verification code mismatch",
        )
    await store.delete_email_verification(normalized_email)

    logger.info(f"注册验证码校验成功: {normalized_email}")
