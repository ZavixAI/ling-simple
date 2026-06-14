"""手机验证码：生成、限流、Redis challenge 存储与发送入口。"""

from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import timedelta

from config import constants
from config.settings import get_app_config
from core.http.exceptions import AppHTTPException
from core.infra.sms import sms
from models.base import get_local_now
from services.auth.state_store import RedisAuthStateStore, RedisSmsChallengeState

SMS_VERIFICATION_CODE_LENGTH = 6
SMS_CHALLENGE_PROVIDER_ID = constants.AUTH_PROVIDER_LOCAL


def _generate_verification_code() -> str:
    return "".join(secrets.choice("0123456789") for _ in range(SMS_VERIFICATION_CODE_LENGTH))


def _hash_verification_code(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


async def send_sms_challenge_code(phone: str, purpose: str) -> tuple[RedisSmsChallengeState, str]:
    cfg = get_app_config()
    store = RedisAuthStateStore(cfg)
    remaining_seconds = await store.reserve_sms_resend(phone, SMS_CHALLENGE_PROVIDER_ID)
    now = get_local_now()
    if remaining_seconds is not None:
        raise AppHTTPException(
            status_code=429,
            detail="SMS challenge requested too frequently",
            error_detail={"resend_after_seconds": int(remaining_seconds)},
        )

    code = _generate_verification_code()
    challenge = RedisSmsChallengeState(
        challenge_id=f"smsc_{uuid.uuid4().hex}",
        provider_id=SMS_CHALLENGE_PROVIDER_ID,
        phone=phone,
        purpose=purpose,
        code_hash=_hash_verification_code(code),
        status=constants.AUTH_CHALLENGE_STATUS_PENDING,
        attempt_count=0,
        expire_at=now + timedelta(minutes=cfg.sms_challenge_expire_minutes),
        max_attempts=3,
        consumed_at=None,
        created_at=now,
        updated_at=now,
    )
    await store.save_sms_challenge(challenge)
    await _send_verification_sms(phone, code)
    return challenge, code


async def _send_verification_sms(phone: str, code: str) -> None:
    cfg = get_app_config()
    await sms.send_template_sms(
        phone=phone,
        template_code=cfg.sms_template_code or "",
        template_data={"code": code},
        sign_name=cfg.sms_sign_name or "",
    )
