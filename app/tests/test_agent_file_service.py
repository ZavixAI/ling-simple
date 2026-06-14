import unittest

from services.agent.files import (
    AgentFileService,
    agent_file_content_disposition,
    agent_file_path_header,
    normalize_agent_workspace_file_reference,
)
from services.agent.sage import SageWorkspaceFileDownload


class _FakeSageClient:
    def __init__(self) -> None:
        self.downloads: list[str] = []

    async def download_workspace_file(
        self,
        *,
        user_id: str,
        agent_id: str,
        file_path: str,
        max_bytes: int,
    ):
        self.downloads.append(file_path)
        return SageWorkspaceFileDownload(
            content=b"<html></html>",
            content_type="text/html; charset=utf-8",
            filename=None,
        )


class AgentFileServiceTests(unittest.IsolatedAsyncioTestCase):
    def test_normalizes_relative_workspace_path(self):
        self.assertEqual(
            normalize_agent_workspace_file_reference("reports/daily.html"),
            "reports/daily.html",
        )

    def test_normalizes_file_url(self):
        self.assertEqual(
            normalize_agent_workspace_file_reference("file:///tmp/report.html"),
            "/tmp/report.html",
        )

    def test_rejects_http_url(self):
        with self.assertRaises(ValueError):
            normalize_agent_workspace_file_reference("https://example.com/a.html")

    def test_rejects_path_traversal(self):
        with self.assertRaises(ValueError):
            normalize_agent_workspace_file_reference("../secret.html")

    async def test_get_file_data_downloads_binary_from_sage(self):
        client = _FakeSageClient()
        service = AgentFileService(sage_client=client)

        result = await service.get_file_data("user-1", "reports/daily.html")

        self.assertEqual(result.path, "reports/daily.html")
        self.assertEqual(result.filename, "daily.html")
        self.assertEqual(result.content_type, "text/html; charset=utf-8")
        self.assertEqual(result.content, b"<html></html>")
        self.assertEqual(client.downloads, ["reports/daily.html"])

    async def test_get_file_data_strips_matching_virtual_workspace_prefix(self):
        client = _FakeSageClient()
        service = AgentFileService(sage_client=client)

        result = await service.get_file_data(
            "user-1",
            "file:///app/agents/user-1/agent_56adf26d/upload_files/demo.jpg",
        )

        self.assertEqual(result.path, "upload_files/demo.jpg")
        self.assertEqual(client.downloads, ["upload_files/demo.jpg"])

    async def test_get_file_data_keeps_foreign_virtual_workspace_absolute(self):
        client = _FakeSageClient()
        service = AgentFileService(sage_client=client)

        result = await service.get_file_data(
            "user-1",
            "file:///app/agents/other-user/agent_56adf26d/upload_files/demo.jpg",
        )

        self.assertEqual(
            result.path,
            "/app/agents/other-user/agent_56adf26d/upload_files/demo.jpg",
        )
        self.assertEqual(
            client.downloads,
            ["/app/agents/other-user/agent_56adf26d/upload_files/demo.jpg"],
        )

    def test_content_disposition_encodes_non_ascii_filename(self):
        value = agent_file_content_disposition("明天的报告.html")

        self.assertIn('filename="file"', value)
        self.assertIn("filename*=UTF-8''", value)
        self.assertIn("%E6%98%8E", value)

    def test_path_header_encodes_non_ascii_path(self):
        value = agent_file_path_header(
            "/app/agents/user/agent_56adf26d/temp/面试问题清单.md"
        )

        self.assertEqual(
            value,
            "/app/agents/user/agent_56adf26d/temp/%E9%9D%A2%E8%AF%95%E9%97%AE%E9%A2%98%E6%B8%85%E5%8D%95.md",
        )
        value.encode("latin-1")


if __name__ == "__main__":
    unittest.main()
