from __future__ import annotations

import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from core.infra.s3 import S3UploadResult
from services.agent.attachments import AttachmentService


class AttachmentServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_image_upload_route_allows_free_user_without_membership_gate(self) -> None:
        from api.routers.agent import upload_agent_images

        saved = {
            "attachment_id": "img_1",
            "message_content": {
                "type": "image_url",
                "image_url": {"url": "https://cdn.example.com/img.jpg"},
            },
        }
        attachment_service = SimpleNamespace(save_image=AsyncMock(return_value=saved))

        with patch(
            "api.routers.agent.AttachmentService",
            return_value=attachment_service,
        ):
            response = await upload_agent_images(
                files=[SimpleNamespace(filename="img.jpg")],
                user=SimpleNamespace(user_id="user-free"),
            )

        assert response.data == {"items": [saved]}
        attachment_service.save_image.assert_awaited_once()

    async def test_save_audio_to_s3_returns_input_audio_message_content(self) -> None:
        uploaded = S3UploadResult(
            bucket="ling-test",
            key="agent_audio/user-1/aud_1.m4a",
            url="https://cdn.example.com/agent_audio/user-1/aud_1.m4a",
        )

        with patch(
            "services.agent.attachments.s3.upload_bytes",
            new=AsyncMock(return_value=uploaded),
        ) as upload_bytes:
            result = await AttachmentService()._save_audio_to_s3(
                cfg=object(),
                user_id="user-1",
                upload_id="aud_1",
                filename="note.m4a",
                content_type="audio/mp4",
                suffix=".m4a",
                payload=b"voice",
            )

        self.assertEqual(result["attachment_id"], "aud_1")
        self.assertEqual(result["object_key"], uploaded.key)
        self.assertEqual(
            result["message_content"],
            {
                "type": "input_audio",
                "input_audio": {
                    "url": uploaded.url,
                    "format": "m4a",
                    "filename": "note.m4a",
                },
            },
        )
        upload_bytes.assert_awaited_once()


if __name__ == "__main__":
    unittest.main()
