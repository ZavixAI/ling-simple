from __future__ import annotations

import asyncio
from dataclasses import dataclass
from typing import Any, Optional
from urllib.parse import quote, urlparse

from boto3.session import Session
from botocore.config import Config as BotoConfig
from config.settings import AppConfig, get_app_config
from core.http.exceptions import AppHTTPException
from loguru import logger


@dataclass(frozen=True)
class S3UploadResult:
    bucket: str
    key: str
    url: str
    etag: Optional[str] = None


def _resolve_s3_addressing_style(cfg: AppConfig) -> str:
    addressing_style = (cfg.s3_addressing_style or "").strip().lower()
    if addressing_style in {"path", "virtual"}:
        return addressing_style
    return "path"


class S3Adapter:
    def __init__(self) -> None:
        self._client: Any | None = None

    def is_configured(self, cfg: Optional[AppConfig] = None) -> bool:
        resolved_cfg = cfg or get_app_config()
        return bool((resolved_cfg.s3_bucket or "").strip())

    def object_key(self, *parts: str, prefix: str = "") -> str:
        normalized_parts = []
        if prefix.strip("/"):
            normalized_parts.append(prefix.strip("/"))

        for part in parts:
            value = (part or "").strip("/")
            if value:
                normalized_parts.append(value)

        return "/".join(normalized_parts)

    async def init(self, cfg: Optional[AppConfig] = None) -> Optional[Any]:
        """Initialize the shared S3-compatible object storage client."""

        if self._client is not None:
            return self._client

        resolved_cfg = cfg or get_app_config()
        if not self.is_configured(resolved_cfg):
            logger.info("未配置 LING_S3_BUCKET，跳过 S3 对象存储客户端初始化")
            return None

        try:
            addressing_style = _resolve_s3_addressing_style(resolved_cfg)
            config_options: dict[str, Any] = {
                "s3": {"addressing_style": addressing_style}
            }

            session = Session(
                aws_access_key_id=(resolved_cfg.s3_access_key_id or "").strip() or None,
                aws_secret_access_key=(resolved_cfg.s3_access_key_secret or "").strip() or None,
                aws_session_token=(resolved_cfg.s3_session_token or "").strip() or None,
                region_name=(resolved_cfg.s3_region or "").strip() or None,
            )
            self._client = session.client(
                "s3",
                endpoint_url=(resolved_cfg.s3_endpoint_url or "").strip() or None,
                config=BotoConfig(signature_version="s3v4", **config_options),
            )
            logger.info(
                "S3 对象存储客户端初始化成功: bucket={}, endpoint={}, addressing_style={}",
                resolved_cfg.s3_bucket,
                (resolved_cfg.s3_endpoint_url or "aws-default").strip(),
                addressing_style,
            )
            return self._client
        except Exception as error:
            logger.error(f"S3 对象存储客户端初始化失败: {error}")
            return None

    def object_url(self, key: str, cfg: Optional[AppConfig] = None) -> str:
        resolved_cfg = cfg or get_app_config()
        bucket = (resolved_cfg.s3_bucket or "").strip()
        if not bucket:
            raise AppHTTPException(
                status_code=503,
                detail="Object storage is not configured",
                error_detail="missing LING_S3_BUCKET",
            )

        normalized_key = quote((key or "").lstrip("/"), safe="/~")
        public_base_url = (resolved_cfg.s3_public_base_url or "").strip().rstrip("/")
        if public_base_url:
            return f"{public_base_url}/{normalized_key}"

        endpoint_url = (resolved_cfg.s3_endpoint_url or "").strip().rstrip("/")
        addressing_style = _resolve_s3_addressing_style(resolved_cfg)
        if endpoint_url:
            parsed = urlparse(endpoint_url)
            if addressing_style == "virtual" and parsed.scheme and parsed.netloc:
                return f"{parsed.scheme}://{bucket}.{parsed.netloc}/{normalized_key}"
            return f"{endpoint_url}/{bucket}/{normalized_key}"

        region = (resolved_cfg.s3_region or "us-east-1").strip()
        host = "s3.amazonaws.com" if region == "us-east-1" else f"s3.{region}.amazonaws.com"
        if addressing_style == "virtual":
            return f"https://{bucket}.{host}/{normalized_key}"
        return f"https://{host}/{bucket}/{normalized_key}"

    async def upload_bytes(
        self,
        *,
        key: str,
        body: bytes,
        content_type: str,
        cache_control: Optional[str] = None,
        metadata: Optional[dict[str, str]] = None,
        cfg: Optional[AppConfig] = None,
    ) -> S3UploadResult:
        resolved_cfg = cfg or get_app_config()
        bucket = (resolved_cfg.s3_bucket or "").strip()
        if not bucket:
            raise AppHTTPException(
                status_code=503,
                detail="Object storage is not configured",
                error_detail="missing LING_S3_BUCKET",
            )

        client = self._client or await self.init(resolved_cfg)
        if client is None:
            raise AppHTTPException(
                status_code=503,
                detail="Object storage client is unavailable",
                error_detail="s3 client unavailable",
            )

        put_kwargs: dict[str, Any] = {
            "Bucket": bucket,
            "Key": key,
            "Body": body,
            "ContentType": content_type or "application/octet-stream",
        }
        if cache_control:
            put_kwargs["CacheControl"] = cache_control
        if metadata:
            put_kwargs["Metadata"] = metadata

        try:
            response = await asyncio.to_thread(client.put_object, **put_kwargs)
        except Exception as error:
            logger.error(f"S3 对象上传失败: bucket={bucket}, key={key}, error={error}")
            raise AppHTTPException(
                status_code=502,
                detail="Failed to upload attachment",
                error_detail=str(error),
            ) from error

        etag = response.get("ETag")
        return S3UploadResult(
            bucket=bucket,
            key=key,
            url=self.object_url(key, cfg=resolved_cfg),
            etag=etag.strip('"') if isinstance(etag, str) else None,
        )

    async def delete_prefix(self, prefix: str, cfg: Optional[AppConfig] = None) -> int:
        """Delete every object under the given prefix."""

        resolved_cfg = cfg or get_app_config()
        if not self.is_configured(resolved_cfg):
            return 0

        normalized_prefix = (prefix or "").strip().lstrip("/")
        if not normalized_prefix:
            return 0

        client = self._client or await self.init(resolved_cfg)
        if client is None:
            logger.warning("S3 客户端不可用，跳过前缀删除: {}", normalized_prefix)
            return 0

        deleted_count = 0
        continuation_token: Optional[str] = None
        bucket = (resolved_cfg.s3_bucket or "").strip()

        while True:
            list_kwargs: dict[str, Any] = {
                "Bucket": bucket,
                "Prefix": normalized_prefix,
            }
            if continuation_token:
                list_kwargs["ContinuationToken"] = continuation_token

            response = await asyncio.to_thread(client.list_objects_v2, **list_kwargs)
            contents = response.get("Contents") or []
            object_batch = [{"Key": item["Key"]} for item in contents if item.get("Key")]
            if object_batch:
                await asyncio.to_thread(
                    client.delete_objects,
                    Bucket=bucket,
                    Delete={"Objects": object_batch, "Quiet": True},
                )
                deleted_count += len(object_batch)

            if not response.get("IsTruncated"):
                break
            continuation_token = response.get("NextContinuationToken")

        return deleted_count

    async def close(self) -> None:
        if self._client is not None:
            close = getattr(self._client, "close", None)
            if callable(close):
                await asyncio.to_thread(close)
        self._client = None
        logger.info("S3 对象存储客户端已关闭")


s3 = S3Adapter()
