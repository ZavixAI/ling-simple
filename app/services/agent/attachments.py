"""对话附件：校验 MIME/后缀，上传 S3 并返回可访问 URL。"""

from __future__ import annotations

import secrets
from pathlib import Path

from config import constants
from config.settings import get_app_config
from core.http.exceptions import AppHTTPException
from core.infra.s3 import s3
from fastapi import UploadFile

_ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/heic": ".heic",
    "image/heif": ".heif",
}
_ALLOWED_IMAGE_SUFFIXES = {
    ".jpg",
    ".jpeg",
    ".png",
    ".webp",
    ".heic",
    ".heif",
}
_SUFFIX_TO_IMAGE_TYPE = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".heic": "image/heic",
    ".heif": "image/heif",
}
_ALLOWED_AUDIO_TYPES = {
    "audio/m4a": ".m4a",
    "audio/mp4": ".m4a",
    "audio/aac": ".aac",
    "audio/x-caf": ".caf",
    "audio/vnd.wave": ".wav",
    "audio/wav": ".wav",
    "audio/wave": ".wav",
    "audio/x-wav": ".wav",
    "audio/mpeg": ".mp3",
}
_ALLOWED_AUDIO_SUFFIXES = {
    ".aac",
    ".caf",
    ".m4a",
    ".mp3",
    ".wav",
}
_SUFFIX_TO_AUDIO_TYPE = {
    ".aac": "audio/aac",
    ".caf": "audio/x-caf",
    ".m4a": "audio/mp4",
    ".mp3": "audio/mpeg",
    ".wav": "audio/wav",
}


class AttachmentService:
    """处理 UploadFile 与存储后端细节，供 Agent 路由上传接口调用。"""

    async def save_image(self, user_id: str, file: UploadFile) -> dict[str, object]:
        content_type = (file.content_type or "").lower().strip()
        filename = file.filename or "image"
        suffix = Path(filename).suffix.lower()
        normalized_suffix = _ALLOWED_IMAGE_TYPES.get(content_type) or suffix

        if (
            content_type not in _ALLOWED_IMAGE_TYPES
            and normalized_suffix not in _ALLOWED_IMAGE_SUFFIXES
        ):
            raise AppHTTPException(
                status_code=415,
                detail="Only image uploads are supported",
                error_code="invalid_image_type",
                error_detail={"filename": filename, "content_type": content_type},
            )

        payload = await file.read()
        if not payload:
            raise AppHTTPException(
                status_code=422,
                detail="Uploaded image is empty",
                error_code="empty_image",
            )

        cfg = get_app_config()
        if not s3.is_configured(cfg):
            raise AppHTTPException(
                status_code=503,
                detail="Object storage is not configured",
                error_detail="missing LING_S3_BUCKET",
            )

        upload_id = f"img_{secrets.token_hex(12)}"
        safe_suffix = ".jpg" if normalized_suffix == ".jpeg" else normalized_suffix
        resolved_content_type = content_type or _SUFFIX_TO_IMAGE_TYPE.get(
            normalized_suffix,
            "image/jpeg",
        )

        return await self._save_image_to_s3(
            cfg=cfg,
            user_id=user_id,
            upload_id=upload_id,
            filename=filename,
            content_type=resolved_content_type,
            suffix=safe_suffix or ".jpg",
            payload=payload,
        )

    async def save_audio(self, user_id: str, file: UploadFile) -> dict[str, object]:
        content_type = (file.content_type or "").lower().strip()
        filename = file.filename or "voice.caf"
        suffix = Path(filename).suffix.lower()
        normalized_suffix = _ALLOWED_AUDIO_TYPES.get(content_type) or suffix

        if (
            content_type not in _ALLOWED_AUDIO_TYPES
            and normalized_suffix not in _ALLOWED_AUDIO_SUFFIXES
        ):
            raise AppHTTPException(
                status_code=415,
                detail="Only audio uploads are supported",
                error_code="invalid_audio_type",
                error_detail={"filename": filename, "content_type": content_type},
            )

        payload = await file.read()
        if not payload:
            raise AppHTTPException(
                status_code=422,
                detail="Uploaded audio is empty",
                error_code="empty_audio",
            )

        cfg = get_app_config()
        if not s3.is_configured(cfg):
            raise AppHTTPException(
                status_code=503,
                detail="Object storage is not configured",
                error_detail="missing LING_S3_BUCKET",
            )

        upload_id = f"aud_{secrets.token_hex(12)}"
        resolved_content_type = content_type or _SUFFIX_TO_AUDIO_TYPE.get(
            normalized_suffix,
            "audio/x-caf",
        )

        return await self._save_audio_to_s3(
            cfg=cfg,
            user_id=user_id,
            upload_id=upload_id,
            filename=filename,
            content_type=resolved_content_type,
            suffix=normalized_suffix or ".caf",
            payload=payload,
        )

    async def _save_image_to_s3(
        self,
        *,
        cfg,
        user_id: str,
        upload_id: str,
        filename: str,
        content_type: str,
        suffix: str,
        payload: bytes,
    ) -> dict[str, object]:
        object_key = s3.object_key(
            "agent_images",
            user_id,
            f"{upload_id}{suffix}",
        )
        uploaded = await s3.upload_bytes(
            key=object_key,
            body=payload,
            content_type=content_type,
            cache_control="public, max-age=31536000, immutable",
            metadata={"filename": filename},
            cfg=cfg,
        )

        return {
            "attachment_id": upload_id,
            "filename": filename,
            "content_type": content_type,
            "size_bytes": len(payload),
            "storage_provider": constants.STORAGE_PROVIDER_S3,
            "bucket": uploaded.bucket,
            "object_key": uploaded.key,
            "download_path": uploaded.url,
            "download_url": uploaded.url,
            "message_content": {
                "type": "image_url",
                "image_url": {"url": uploaded.url, "detail": "auto"},
            },
        }

    async def _save_audio_to_s3(
        self,
        *,
        cfg,
        user_id: str,
        upload_id: str,
        filename: str,
        content_type: str,
        suffix: str,
        payload: bytes,
    ) -> dict[str, object]:
        object_key = s3.object_key(
            "agent_audio",
            user_id,
            f"{upload_id}{suffix}",
        )
        uploaded = await s3.upload_bytes(
            key=object_key,
            body=payload,
            content_type=content_type,
            cache_control="public, max-age=31536000, immutable",
            metadata={"filename": filename},
            cfg=cfg,
        )

        input_audio = {
            "url": uploaded.url,
            "format": suffix.lstrip(".") or "caf",
            "filename": filename,
        }
        return {
            "attachment_id": upload_id,
            "filename": filename,
            "content_type": content_type,
            "size_bytes": len(payload),
            "storage_provider": constants.STORAGE_PROVIDER_S3,
            "bucket": uploaded.bucket,
            "object_key": uploaded.key,
            "download_path": uploaded.url,
            "download_url": uploaded.url,
            "message_content": {
                "type": "input_audio",
                "input_audio": input_audio,
            },
        }
