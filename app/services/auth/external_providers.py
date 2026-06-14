"""第三方身份校验：如 Apple Sign In JWT 解析与 JWKS 缓存，产出 ExternalIdentityPayload。"""

from __future__ import annotations

import asyncio
import json
import time
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any, cast

import httpx
import jwt
from alibabacloud_dypnsapi20170525 import models as dypnsapi_models
from config import constants
from config.settings import AppConfig, get_app_config
from core.http.exceptions import AppHTTPException
from core.infra.pns import pns
from jwt.algorithms import RSAAlgorithm
from loguru import logger

if TYPE_CHECKING:
    from jwt.algorithms import AllowedPublicKeys
else:
    AllowedPublicKeys = Any


@dataclass(frozen=True)
class ExternalIdentityPayload:
    provider_id: str
    provider_subject: str
    provider_username: str | None = None
    provider_email: str | None = None
    nickname: str | None = None
    avatar_url: str | None = None
    profile: dict[str, Any] = field(default_factory=dict)


class ExternalAuthProviderService:
    """封装各 external provider 的 HTTP/JWT 验证逻辑，供 AuthService 汇聚到本地用户。"""

    def __init__(
        self,
        cfg: AppConfig | None = None,
        *,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self.cfg = cfg or get_app_config()
        self._http_client = http_client
        self._apple_jwks_cache: tuple[float, list[dict[str, Any]]] | None = None

    async def verify_apple_identity_token(
        self,
        identity_token: str,
        *,
        authorization_code: str | None = None,
        full_name: dict[str, Any] | None = None,
    ) -> ExternalIdentityPayload:
        normalized_token = (identity_token or "").strip()
        if not normalized_token:
            raise AppHTTPException(
                status_code=422,
                detail="apple_identity_token is required",
            )
        if not (constants.APPLE_AUDIENCE_IOS or "").strip():
            raise AppHTTPException(
                status_code=503,
                detail="Apple sign in is not configured",
            )

        signing_key = await self._resolve_apple_signing_key(normalized_token)
        try:
            claims = jwt.decode(
                normalized_token,
                signing_key,
                algorithms=["RS256"],
                audience=constants.APPLE_AUDIENCE_IOS,
                issuer=self.cfg.apple_issuer,
            )
        except jwt.ExpiredSignatureError as exc:
            raise AppHTTPException(
                status_code=401,
                detail="Apple identity token expired",
            ) from exc
        except jwt.InvalidTokenError as exc:
            raise AppHTTPException(
                status_code=401,
                detail="Invalid Apple identity token",
            ) from exc

        provider_subject = str(claims.get("sub") or "").strip()
        if not provider_subject:
            raise AppHTTPException(
                status_code=401,
                detail="Apple identity token subject missing",
            )

        email = self._normalize_optional_string(claims.get("email"), lowercase=True)
        normalized_name = self._normalize_apple_full_name(full_name)
        nickname = (
            normalized_name.get("display_name")
            or self._nickname_from_email(email)
            or "Apple User"
        )
        profile = self._compact_dict(
            {
                "login_type": "apple_identity_token",
                "email": email,
                "email_verified": self._normalize_optional_bool(
                    claims.get("email_verified")
                ),
                "is_private_email": self._normalize_optional_bool(
                    claims.get("is_private_email")
                ),
                "authorization_code_present": bool(
                    self._normalize_optional_string(authorization_code)
                ),
                "full_name": normalized_name or None,
            }
        )
        return ExternalIdentityPayload(
            provider_id=constants.AUTH_PROVIDER_APPLE,
            provider_subject=provider_subject,
            provider_username=email or nickname,
            provider_email=email,
            nickname=nickname,
            profile=profile,
        )

    async def exchange_wechat_auth_code(
        self,
        auth_code: str,
    ) -> ExternalIdentityPayload:
        normalized_code = (auth_code or "").strip()
        if not normalized_code:
            raise AppHTTPException(
                status_code=422,
                detail="wechat_auth_code is required",
            )
        if not (self.cfg.wechat_app_id or "").strip() or not (
            self.cfg.wechat_app_secret or ""
        ).strip():
            raise AppHTTPException(
                status_code=503,
                detail="WeChat sign in is not configured",
            )

        token_payload = await self._request_json(
            "https://api.weixin.qq.com/sns/oauth2/access_token",
            params={
                "appid": self.cfg.wechat_app_id,
                "secret": self.cfg.wechat_app_secret,
                "code": normalized_code,
                "grant_type": "authorization_code",
            },
        )
        self._raise_if_wechat_error(token_payload, "WeChat authorization failed")

        access_token = self._normalize_optional_string(token_payload.get("access_token"))
        openid = self._normalize_optional_string(token_payload.get("openid"))
        if not access_token or not openid:
            raise AppHTTPException(
                status_code=401,
                detail="Invalid WeChat authorization response",
            )

        userinfo = await self._request_json(
            "https://api.weixin.qq.com/sns/userinfo",
            params={
                "access_token": access_token,
                "openid": openid,
                "lang": "zh_CN",
            },
            allow_error_response=True,
        )
        if userinfo:
            self._raise_if_wechat_error(userinfo, "WeChat user profile fetch failed")

        unionid = self._normalize_optional_string(
            userinfo.get("unionid") if userinfo else None
        ) or self._normalize_optional_string(token_payload.get("unionid"))
        provider_subject = unionid or openid
        nickname = self._normalize_optional_string(
            userinfo.get("nickname") if userinfo else None
        )
        avatar_url = self._normalize_optional_string(
            userinfo.get("headimgurl") if userinfo else None
        )
        profile = self._compact_dict(
            {
                "login_type": "wechat_auth_code",
                "openid": openid,
                "unionid": unionid,
                "nickname": nickname,
                "avatar_url": avatar_url,
                "scope": self._normalize_optional_string(token_payload.get("scope")),
            }
        )
        return ExternalIdentityPayload(
            provider_id=constants.AUTH_PROVIDER_WECHAT,
            provider_subject=provider_subject,
            provider_username=nickname or openid,
            nickname=nickname or "WeChat User",
            avatar_url=avatar_url,
            profile=profile,
        )

    async def resolve_aliyun_mobile_number(self, access_token: str) -> dict[str, Any]:
        normalized_token = (access_token or "").strip()
        if not normalized_token:
            raise AppHTTPException(status_code=422, detail="One-click token is required")

        client = await pns.init(self.cfg)
        if client is None:
            raise AppHTTPException(detail="号码认证客户端不可用", error_detail="pns client unavailable")

        request = dypnsapi_models.GetMobileRequest(access_token=normalized_token)

        try:
            if hasattr(client, "get_mobile_async"):
                response = await client.get_mobile_async(request)
            else:
                response = await asyncio.to_thread(
                    client.get_mobile,
                    request,
                )
        except Exception as error:
            message = getattr(error, "message", "") or str(error)
            recommend = ""
            data = getattr(error, "data", None)
            if isinstance(data, dict):
                recommend = str(data.get("Recommend") or data.get("recommend") or "")
            logger.error(f"号码认证服务端取号失败: {message}, recommend={recommend}")
            if "unable to load credentials" in message.lower() or "credentialexception" in message.lower():
                raise AppHTTPException(
                    detail="号码认证凭据未配置，请在 .env 中设置 LING_PNS_ACCESS_KEY_ID 和 LING_PNS_ACCESS_KEY_SECRET",
                    error_detail=recommend or message,
                ) from error
            raise AppHTTPException(
                status_code=400,
                detail="本机号码认证失败",
                error_detail=recommend or message,
            ) from error

        body = {}
        if hasattr(response, "body") and response.body is not None:
            if hasattr(response.body, "to_map"):
                body = response.body.to_map() or {}
            elif isinstance(response.body, dict):
                body = dict(response.body)

        code = str(body.get("Code") or body.get("code") or "").strip()
        message = str(body.get("Message") or body.get("message") or "").strip()
        result = body.get("GetMobileResultDTO") or body.get("getMobileResultDTO") or {}
        if not isinstance(result, dict):
            result = {}

        mobile = str(result.get("Mobile") or result.get("mobile") or "").strip()
        if code and code.upper() != "OK" and not mobile:
            raise AppHTTPException(
                status_code=400,
                detail="本机号码认证失败",
                error_detail=message or code,
            )
        if not mobile:
            raise AppHTTPException(
                status_code=400,
                detail="本机号码认证失败",
                error_detail=message or "missing mobile number",
            )

        return {
            "phone": mobile,
            "request_id": body.get("RequestId") or body.get("requestId"),
            "carrier": result.get("Carrier") or result.get("carrier"),
        }

    async def _resolve_apple_signing_key(self, identity_token: str) -> AllowedPublicKeys:
        header = jwt.get_unverified_header(identity_token)
        key_id = str(header.get("kid") or "").strip()
        if not key_id:
            raise AppHTTPException(
                status_code=401,
                detail="Apple identity token key id missing",
            )
        jwks = await self._fetch_apple_jwks()
        for item in jwks:
            if str(item.get("kid") or "").strip() == key_id:
                return cast(
                    AllowedPublicKeys,
                    RSAAlgorithm.from_jwk(json.dumps(item)),
                )
        raise AppHTTPException(
            status_code=401,
            detail="Apple signing key not found",
        )

    async def _fetch_apple_jwks(self) -> list[dict[str, Any]]:
        now = time.monotonic()
        if self._apple_jwks_cache and self._apple_jwks_cache[0] > now:
            return self._apple_jwks_cache[1]

        payload = await self._request_json(self.cfg.apple_jwks_url)
        keys = payload.get("keys")
        if not isinstance(keys, list) or not keys:
            raise AppHTTPException(
                status_code=502,
                detail="Apple JWKS response invalid",
            )
        normalized_keys = [
            item for item in keys if isinstance(item, dict) and item.get("kid")
        ]
        if not normalized_keys:
            raise AppHTTPException(
                status_code=502,
                detail="Apple JWKS response empty",
            )
        self._apple_jwks_cache = (now + 300, normalized_keys)
        return normalized_keys

    async def _request_json(
        self,
        url: str,
        *,
        params: dict[str, Any] | None = None,
        allow_error_response: bool = False,
    ) -> dict[str, Any]:
        try:
            if self._http_client is not None:
                response = await self._http_client.get(url, params=params)
            else:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    response = await client.get(url, params=params)
            response.raise_for_status()
        except httpx.HTTPStatusError as exc:
            if allow_error_response and exc.response.content:
                try:
                    payload = exc.response.json()
                    if isinstance(payload, dict):
                        return payload
                except ValueError:
                    pass
            raise AppHTTPException(
                status_code=502,
                detail="Upstream provider request failed",
                error_detail={"provider_url": url, "status_code": exc.response.status_code},
            ) from exc
        except httpx.RequestError as exc:
            raise AppHTTPException(
                status_code=502,
                detail="Upstream provider unavailable",
                error_detail={"provider_url": url},
            ) from exc

        try:
            payload = response.json()
        except ValueError as exc:
            raise AppHTTPException(
                status_code=502,
                detail="Upstream provider returned invalid JSON",
                error_detail={"provider_url": url},
            ) from exc
        if not isinstance(payload, dict):
            raise AppHTTPException(
                status_code=502,
                detail="Upstream provider returned invalid payload",
                error_detail={"provider_url": url},
            )
        return payload

    def _raise_if_wechat_error(
        self,
        payload: dict[str, Any],
        detail: str,
    ) -> None:
        errcode = payload.get("errcode")
        if errcode in (None, 0, "0"):
            return
        raise AppHTTPException(
            status_code=401,
            detail=detail,
            error_detail={
                "errcode": errcode,
                "errmsg": payload.get("errmsg"),
            },
        )

    def _normalize_apple_full_name(
        self,
        full_name: dict[str, Any] | None,
    ) -> dict[str, Any]:
        if not isinstance(full_name, dict):
            return {}
        given_name = self._normalize_optional_string(full_name.get("given_name"))
        family_name = self._normalize_optional_string(full_name.get("family_name"))
        middle_name = self._normalize_optional_string(full_name.get("middle_name"))
        nickname = self._normalize_optional_string(full_name.get("nickname"))
        display_name = " ".join(
            item for item in [given_name, middle_name, family_name] if item
        ).strip()
        return self._compact_dict(
            {
                "given_name": given_name,
                "middle_name": middle_name,
                "family_name": family_name,
                "nickname": nickname,
                "display_name": display_name or nickname,
            }
        )

    def _nickname_from_email(self, value: str | None) -> str | None:
        normalized = self._normalize_optional_string(value, lowercase=True)
        if not normalized or "@" not in normalized:
            return None
        local_part = normalized.split("@", 1)[0].strip()
        return local_part or None

    def _normalize_optional_string(
        self,
        value: Any,
        *,
        lowercase: bool = False,
    ) -> str | None:
        normalized = str(value or "").strip()
        if not normalized:
            return None
        return normalized.lower() if lowercase else normalized

    def _normalize_optional_bool(self, value: Any) -> bool | None:
        if isinstance(value, bool):
            return value
        normalized = str(value or "").strip().lower()
        if normalized in {"true", "1", "yes"}:
            return True
        if normalized in {"false", "0", "no"}:
            return False
        return None

    def _compact_dict(self, value: dict[str, Any]) -> dict[str, Any]:
        return {key: item for key, item in value.items() if item is not None}
