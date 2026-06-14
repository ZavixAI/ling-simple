from __future__ import annotations

import base64
import time
from dataclasses import dataclass
from datetime import datetime
from typing import Any

import httpx
import jwt
from config.settings import AppConfig, get_app_config
from core.http.exceptions import AppHTTPException
from cryptography import x509
from jwt import InvalidTokenError
from utils.time import UTC


@dataclass(frozen=True, slots=True)
class AppleTransactionInfo:
    transaction_id: str
    original_transaction_id: str | None
    product_id: str
    bundle_id: str
    purchase_date: datetime | None
    expiration_date: datetime | None
    app_account_token: str | None
    environment: str | None
    raw_claims: dict[str, Any]


@dataclass(frozen=True, slots=True)
class AppleNotificationInfo:
    notification_type: str
    subtype: str | None
    notification_uuid: str | None
    signed_transaction_info: str | None
    signed_renewal_info: str | None
    raw_claims: dict[str, Any]


class AppleJWSVerifier:
    def __init__(self, cfg: AppConfig | None = None) -> None:
        self.cfg = cfg or get_app_config()

    def decode_transaction(self, signed_transaction_info: str) -> AppleTransactionInfo:
        claims = self._decode_jws(signed_transaction_info)
        product_id = self._required_string(claims, "productId")
        transaction_id = self._required_string(claims, "transactionId")
        bundle_id = self._required_string(claims, "bundleId")
        expected_bundle_id = (self.cfg.apple_iap_bundle_id or "").strip()
        if expected_bundle_id and bundle_id != expected_bundle_id:
            raise AppHTTPException(
                status_code=401,
                detail="Apple transaction bundle id mismatch",
                error_detail={"bundle_id": bundle_id},
            )
        return AppleTransactionInfo(
            transaction_id=transaction_id,
            original_transaction_id=self._optional_string(
                claims.get("originalTransactionId")
            ),
            product_id=product_id,
            bundle_id=bundle_id,
            purchase_date=self._millis_datetime(claims.get("purchaseDate")),
            expiration_date=self._millis_datetime(claims.get("expiresDate")),
            app_account_token=self._optional_string(claims.get("appAccountToken")),
            environment=self._optional_string(claims.get("environment")),
            raw_claims=claims,
        )

    def decode_notification(self, signed_payload: str) -> AppleNotificationInfo:
        claims = self._decode_jws(signed_payload)
        data = claims.get("data")
        if not isinstance(data, dict):
            data = {}
        return AppleNotificationInfo(
            notification_type=self._required_string(claims, "notificationType"),
            subtype=self._optional_string(claims.get("subtype")),
            notification_uuid=self._optional_string(claims.get("notificationUUID")),
            signed_transaction_info=self._optional_string(
                data.get("signedTransactionInfo")
            ),
            signed_renewal_info=self._optional_string(data.get("signedRenewalInfo")),
            raw_claims=claims,
        )

    def _decode_jws(self, token: str) -> dict[str, Any]:
        normalized = (token or "").strip()
        if not normalized:
            raise AppHTTPException(status_code=422, detail="Apple signed payload is required")
        try:
            if not self.cfg.apple_iap_verify_signature:
                claims = jwt.decode(
                    normalized,
                    options={
                        "verify_signature": False,
                        "verify_aud": False,
                        "verify_exp": False,
                    },
                )
            else:
                header = jwt.get_unverified_header(normalized)
                cert_chain = header.get("x5c")
                if not isinstance(cert_chain, list) or not cert_chain:
                    raise AppHTTPException(
                        status_code=401,
                        detail="Apple signed payload missing certificate chain",
                    )
                cert_bytes = base64.b64decode(str(cert_chain[0]))
                certificate = x509.load_der_x509_certificate(cert_bytes)
                claims = jwt.decode(
                    normalized,
                    certificate.public_key(),
                    algorithms=[str(header.get("alg") or "ES256")],
                    options={"verify_aud": False, "verify_exp": False},
                )
        except AppHTTPException:
            raise
        except InvalidTokenError as exc:
            raise AppHTTPException(
                status_code=401,
                detail="Invalid Apple signed payload",
            ) from exc
        except Exception as exc:
            raise AppHTTPException(
                status_code=401,
                detail="Unable to verify Apple signed payload",
            ) from exc
        if not isinstance(claims, dict):
            raise AppHTTPException(status_code=401, detail="Apple signed payload invalid")
        return claims

    @staticmethod
    def _required_string(claims: dict[str, Any], key: str) -> str:
        value = AppleJWSVerifier._optional_string(claims.get(key))
        if value is None:
            raise AppHTTPException(
                status_code=422,
                detail=f"Apple signed payload missing {key}",
            )
        return value

    @staticmethod
    def _optional_string(value: Any) -> str | None:
        normalized = str(value or "").strip()
        return normalized or None

    @staticmethod
    def _millis_datetime(value: Any) -> datetime | None:
        if value is None:
            return None
        try:
            millis = int(value)
        except (TypeError, ValueError):
            return None
        return datetime.fromtimestamp(millis / 1000, tz=UTC)


class AppleAppStoreServerClient:
    def __init__(
        self,
        cfg: AppConfig | None = None,
        *,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self.cfg = cfg or get_app_config()
        self._http_client = http_client

    async def get_transaction_info(
        self,
        transaction_id: str,
        *,
        environment: str | None = None,
    ) -> dict[str, Any]:
        token = self._build_bearer_token()
        base_url = self._base_url_for_environment(environment)
        url = f"{base_url}/inApps/v1/transactions/{transaction_id}"
        headers = {"Authorization": f"Bearer {token}"}
        try:
            if self._http_client is not None:
                response = await self._http_client.get(url, headers=headers)
            else:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    response = await client.get(url, headers=headers)
            response.raise_for_status()
            payload = response.json()
        except httpx.HTTPStatusError as exc:
            raise AppHTTPException(
                status_code=502,
                detail="Apple App Store Server API request failed",
                error_detail={"status_code": exc.response.status_code},
            ) from exc
        except httpx.RequestError as exc:
            raise AppHTTPException(
                status_code=502,
                detail="Apple App Store Server API unavailable",
            ) from exc
        except ValueError as exc:
            raise AppHTTPException(
                status_code=502,
                detail="Apple App Store Server API returned invalid JSON",
            ) from exc
        if not isinstance(payload, dict):
            raise AppHTTPException(
                status_code=502,
                detail="Apple App Store Server API response invalid",
            )
        return payload

    def _build_bearer_token(self) -> str:
        issuer_id = (self.cfg.apple_app_store_server_api_issuer_id or "").strip()
        key_id = (self.cfg.apple_app_store_server_api_key_id or "").strip()
        private_key = (self.cfg.apple_app_store_server_api_private_key or "").strip()
        if not issuer_id or not key_id or not private_key:
            raise AppHTTPException(
                status_code=503,
                detail="Apple App Store Server API is not configured",
            )
        now = int(time.time())
        return jwt.encode(
            {
                "iss": issuer_id,
                "iat": now,
                "exp": now + 20 * 60,
                "aud": "appstoreconnect-v1",
                "bid": self.cfg.apple_iap_bundle_id,
            },
            private_key.replace("\\n", "\n"),
            algorithm="ES256",
            headers={"kid": key_id, "typ": "JWT"},
        )

    def _base_url_for_environment(self, environment: str | None) -> str:
        normalized = (environment or "").strip().lower()
        if normalized == "sandbox":
            return self.cfg.apple_app_store_sandbox_api_base_url.rstrip("/")
        return self.cfg.apple_app_store_api_base_url.rstrip("/")
