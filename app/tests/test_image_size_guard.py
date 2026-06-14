from __future__ import annotations

import io
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from PIL import Image
from utils.image_size_guard import ensure_image_url_within_size_limit


class ImageSizeGuardTests(unittest.IsolatedAsyncioTestCase):
    async def test_remote_image_over_limit_is_compressed_and_uploaded(self) -> None:
        buffer = io.BytesIO()
        Image.effect_noise((900, 700), 100).convert("RGB").save(
            buffer,
            format="JPEG",
            quality=95,
        )
        image_bytes = buffer.getvalue()
        max_bytes = 80_000
        captured_upload: dict[str, object] = {}
        guarded_url = "https://cdn.example.com/guarded.jpg"

        class _FakeResponse:
            def __init__(self, *, content: bytes = b"") -> None:
                self.content = content
                self.headers = {
                    "Content-Length": str(len(image_bytes) * 3),
                    "Content-Type": "image/jpeg",
                }
                self.status_code = 200

            def raise_for_status(self) -> None:
                return None

        class _FakeAsyncClient:
            def __init__(self, *args, **kwargs) -> None:
                pass

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb) -> None:
                return None

            async def head(self, url: str) -> _FakeResponse:
                return _FakeResponse()

            async def get(self, url: str) -> _FakeResponse:
                return _FakeResponse(content=image_bytes)

        async def _fake_upload_bytes(**kwargs):
            captured_upload.update(kwargs)
            return SimpleNamespace(
                bucket="ling-test",
                key=kwargs["key"],
                url=guarded_url,
            )

        with (
            patch("utils.image_size_guard.httpx.AsyncClient", _FakeAsyncClient),
            patch(
                "utils.image_size_guard.s3.upload_bytes",
                new=AsyncMock(side_effect=_fake_upload_bytes),
            ),
        ):
            result = await ensure_image_url_within_size_limit(
                "https://cdn.example.com/original.jpg",
                max_bytes=max_bytes,
            )

        self.assertEqual(result, guarded_url)
        self.assertEqual(captured_upload["content_type"], "image/jpeg")
        self.assertLessEqual(len(captured_upload["body"]), max_bytes)
        self.assertIn("agent_images/image_guards/", captured_upload["key"])


if __name__ == "__main__":
    unittest.main()
