from __future__ import annotations

import json
import unittest
from unittest.mock import AsyncMock, patch

import httpx

from services.agent.sage import SageClient


class SageClientStreamTimeoutTests(unittest.IsolatedAsyncioTestCase):
    async def test_chat_stream_records_token_usage_without_yielding_it(self) -> None:
        captured: dict[str, object] = {}
        upsert = AsyncMock()

        class _FakeTokenUsageDao:
            def upsert(self, usage):
                captured["usage"] = usage
                return upsert(usage)

        class _FakeStreamResponse:
            status_code = 200

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb):
                return False

            async def aiter_lines(self):
                yield json.dumps(
                    {
                        "role": "assistant",
                        "message_type": "token_usage",
                        "metadata": {
                            "token_usage": {
                                "total_info": {
                                    "prompt_tokens": 10,
                                    "completion_tokens": 4,
                                    "total_tokens": 14,
                                    "cached_tokens": 3,
                                    "reasoning_tokens": 2,
                                    "model": "gpt-test",
                                    "models": ["gpt-test"],
                                },
                                "models": ["gpt-test"],
                            },
                        },
                    }
                )
                yield json.dumps(
                    {
                        "role": "assistant",
                        "content": "ok",
                        "message_type": "assistant_message",
                    }
                )

        class _FakeAsyncClient:
            def __init__(self, *, timeout):
                self.timeout = timeout

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb):
                return False

            def stream(self, method, url, *, json, headers):
                return _FakeStreamResponse()

        with (
            patch("httpx.AsyncClient", _FakeAsyncClient),
            patch("services.agent.sage.AgentTokenUsageDao", _FakeTokenUsageDao),
        ):
            chunks = [
                chunk
                async for chunk in SageClient(
                    api_url="http://sage.internal",
                ).chat_stream(
                    session_id="session-1",
                    messages=[],
                    agent_id="agent-1",
                    user_id="user-1",
                    system_context={},
                )
            ]

        self.assertEqual(len(chunks), 1)
        self.assertEqual(chunks[0].content, "ok")
        upsert.assert_awaited_once()
        usage = captured["usage"]
        self.assertEqual(usage.session_id, "session-1")
        self.assertEqual(usage.user_id, "user-1")
        self.assertEqual(usage.input_tokens, 10)
        self.assertEqual(usage.output_tokens, 4)
        self.assertEqual(usage.total_tokens, 14)
        self.assertEqual(usage.cached_tokens, 3)
        self.assertEqual(usage.reasoning_tokens, 2)
        self.assertEqual(usage.model, "gpt-test")

    async def test_chat_stream_records_empty_token_usage_as_zeroes(self) -> None:
        captured: dict[str, object] = {}
        upsert = AsyncMock()

        class _FakeTokenUsageDao:
            def upsert(self, usage):
                captured["usage"] = usage
                return upsert(usage)

        class _FakeStreamResponse:
            status_code = 200

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb):
                return False

            async def aiter_lines(self):
                yield json.dumps(
                    {
                        "role": "assistant",
                        "message_type": "token_usage",
                        "metadata": {},
                    }
                )

        class _FakeAsyncClient:
            def __init__(self, *, timeout):
                self.timeout = timeout

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb):
                return False

            def stream(self, method, url, *, json, headers):
                return _FakeStreamResponse()

        with (
            patch("httpx.AsyncClient", _FakeAsyncClient),
            patch("services.agent.sage.AgentTokenUsageDao", _FakeTokenUsageDao),
        ):
            chunks = [
                chunk
                async for chunk in SageClient(
                    api_url="http://sage.internal",
                ).chat_stream(
                    session_id="session-1",
                    messages=[],
                    agent_id="agent-1",
                    user_id="user-1",
                    system_context={},
                )
            ]

        self.assertEqual(chunks, [])
        upsert.assert_awaited_once()
        usage = captured["usage"]
        self.assertEqual(usage.input_tokens, 0)
        self.assertEqual(usage.output_tokens, 0)
        self.assertEqual(usage.total_tokens, 0)
        self.assertEqual(usage.raw_usage, {})

    async def test_chat_stream_disables_read_timeout_after_response_starts(self) -> None:
        captured: dict[str, object] = {}

        class _FakeStreamResponse:
            status_code = 200

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb):
                return False

            async def aiter_lines(self):
                yield json.dumps(
                    {
                        "role": "assistant",
                        "content": "ok",
                        "message_type": "assistant_message",
                    }
                )

        class _FakeAsyncClient:
            def __init__(self, *, timeout):
                captured["timeout"] = timeout

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb):
                return False

            def stream(self, method, url, *, json, headers):
                captured["method"] = method
                captured["url"] = url
                return _FakeStreamResponse()

        with patch("httpx.AsyncClient", _FakeAsyncClient):
            chunks = [
                chunk
                async for chunk in SageClient(
                    api_url="http://sage.internal",
                ).chat_stream(
                    session_id="session-1",
                    messages=[],
                    agent_id="agent-1",
                    user_id="user-1",
                    system_context={},
                )
            ]

        timeout = captured["timeout"]
        self.assertIsInstance(timeout, httpx.Timeout)
        self.assertIsNone(timeout.read)
        self.assertEqual(captured["method"], "POST")
        self.assertEqual(captured["url"], "http://sage.internal/api/chat")
        self.assertEqual(chunks[0].content, "ok")

    async def test_chat_stream_error_chunk_includes_exception_type(self) -> None:
        class _FakeAsyncClient:
            def __init__(self, *, timeout):
                self.timeout = timeout

            async def __aenter__(self):
                raise httpx.ReadTimeout("timed out")

            async def __aexit__(self, exc_type, exc, tb):
                return False

        with patch("httpx.AsyncClient", _FakeAsyncClient):
            chunks = [
                chunk
                async for chunk in SageClient(
                    api_url="http://sage.internal",
                ).chat_stream(
                    session_id="session-1",
                    messages=[],
                    agent_id="agent-1",
                    user_id="user-1",
                    system_context={},
                )
            ]

        self.assertEqual(chunks[0].message_type, "error")
        self.assertEqual(chunks[0].content, "Request failed: ReadTimeout: timed out")
        self.assertEqual(chunks[0].error_info["type"], "ReadTimeout")

    async def test_chat_stream_repairs_multiline_tool_result_json(self) -> None:
        class _FakeStreamResponse:
            status_code = 200

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb):
                return False

            async def aiter_lines(self):
                yield (
                    '{"role":"tool","content":{"ok":true,"data":{"search_result":'
                    '[{"content":"1. OpenAI：智能与创造力的结合'
                )
                yield "OpenAI以其强大的语言模型闻名。"
                yield "(1) 高效的内容生成"
                yield (
                    '无论是写作、编程还是学习"}]}},"tool_call_id":'
                    '"functions.location_search_poi:23","type":"tool_call_result"}'
                )

        class _FakeAsyncClient:
            def __init__(self, *, timeout):
                self.timeout = timeout

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb):
                return False

            def stream(self, method, url, *, json, headers):
                return _FakeStreamResponse()

        with patch("httpx.AsyncClient", _FakeAsyncClient):
            chunks = [
                chunk
                async for chunk in SageClient(
                    api_url="http://sage.internal",
                ).chat_stream(
                    session_id="session-1",
                    messages=[],
                    agent_id="agent-1",
                    user_id="user-1",
                    system_context={},
                )
            ]

        self.assertEqual(len(chunks), 1)
        self.assertEqual(chunks[0].role, "tool")
        self.assertEqual(chunks[0].message_type, "tool_call_result")
        self.assertEqual(chunks[0].tool_call_id, "functions.location_search_poi:23")
        self.assertEqual(
            chunks[0].content["data"]["search_result"][0]["content"],
            "1. OpenAI：智能与创造力的结合\n"
            "OpenAI以其强大的语言模型闻名。\n"
            "(1) 高效的内容生成\n"
            "无论是写作、编程还是学习",
        )

    async def test_chat_stream_keeps_named_tool_call_and_coalesces_argument_deltas(self) -> None:
        tool_call_lines = [
            {
                "role": "assistant",
                "message_id": "msg-tool",
                "type": "tool_call",
                "tool_calls": [
                    {
                        "id": "functions.file_write:62",
                        "type": "function",
                        "index": 0,
                        "function": {"name": "file_write", "arguments": ""},
                    }
                ],
            },
            {
                "role": "assistant",
                "message_id": "msg-tool",
                "type": "tool_call",
                "tool_calls": [
                    {
                        "id": "",
                        "type": "function",
                        "index": 0,
                        "function": {"name": None, "arguments": "{\""},
                    }
                ],
            },
            {
                "role": "assistant",
                "message_id": "msg-tool",
                "type": "tool_call",
                "tool_calls": [
                    {
                        "id": "",
                        "type": "function",
                        "index": 0,
                        "function": {"name": None, "arguments": "file_path"},
                    }
                ],
            },
            {
                "role": "assistant",
                "message_id": "msg-tool",
                "type": "tool_call",
                "tool_calls": [
                    {
                        "id": "",
                        "type": "function",
                        "index": 0,
                        "function": {"name": None, "arguments": "\":\"demo.html\"}"},
                    }
                ],
            },
        ]

        class _FakeStreamResponse:
            status_code = 200

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb):
                return False

            async def aiter_lines(self):
                for item in tool_call_lines:
                    yield json.dumps(item)
                yield json.dumps(
                    {
                        "role": "tool",
                        "content": {"ok": True},
                        "tool_call_id": "functions.file_write:62",
                        "type": "tool_call_result",
                    }
                )

        class _FakeAsyncClient:
            def __init__(self, *, timeout):
                self.timeout = timeout

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb):
                return False

            def stream(self, method, url, *, json, headers):
                return _FakeStreamResponse()

        with patch("httpx.AsyncClient", _FakeAsyncClient):
            chunks = [
                chunk
                async for chunk in SageClient(
                    api_url="http://sage.internal",
                ).chat_stream(
                    session_id="session-1",
                    messages=[],
                    agent_id="agent-1",
                    user_id="user-1",
                    system_context={},
                )
            ]

        self.assertEqual(len(chunks), 3)
        self.assertEqual(chunks[0].message_type, "tool_call")
        self.assertEqual(chunks[0].message_id, "msg-tool")
        self.assertEqual(chunks[0].tool_calls[0]["id"], "functions.file_write:62")
        self.assertEqual(chunks[0].tool_calls[0]["function"]["name"], "file_write")
        self.assertEqual(chunks[0].tool_calls[0]["function"]["arguments"], "")
        self.assertEqual(chunks[1].message_type, "tool_call")
        self.assertEqual(chunks[1].message_id, "msg-tool")
        self.assertEqual(chunks[1].tool_calls[0]["id"], "functions.file_write:62")
        self.assertEqual(chunks[1].tool_calls[0]["function"]["name"], "file_write")
        self.assertEqual(
            chunks[1].tool_calls[0]["function"]["arguments"],
            '{"file_path":"demo.html"}',
        )
        self.assertEqual(chunks[2].message_type, "tool_call_result")
        self.assertEqual(chunks[2].tool_call_id, "functions.file_write:62")

    async def test_workspace_listing_passes_layered_query_params(self) -> None:
        captured: dict[str, object] = {}

        class _FakeResponse:
            status_code = 200

            def json(self):
                return {"data": {"files": [], "path": "memory", "max_depth": 0}}

        class _FakeAsyncClient:
            def __init__(self, *, timeout):
                captured["timeout"] = timeout

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb):
                return False

            async def post(self, url, *, headers, params, json):
                captured["url"] = url
                captured["headers"] = headers
                captured["params"] = params
                captured["json"] = json
                return _FakeResponse()

        with patch("httpx.AsyncClient", _FakeAsyncClient):
            result = await SageClient(
                api_url="http://sage.internal",
            ).list_file_workspace(
                user_id="user-1",
                agent_id="agent-1",
                path="memory",
                max_depth=0,
            )

        self.assertEqual(
            captured["url"],
            "http://sage.internal/api/agent/agent-1/file_workspace",
        )
        self.assertEqual(captured["headers"], {"X-Sage-Internal-UserId": "user-1"})
        self.assertEqual(captured["params"], {"path": "memory", "max_depth": 0})
        self.assertEqual(captured["json"], {})
        self.assertEqual(result["path"], "memory")

    async def test_workspace_upload_passes_target_path_as_query_and_form(self) -> None:
        captured: dict[str, object] = {}

        class _FakeResponse:
            status_code = 200
            text = ""

            def json(self):
                return {"data": {"path": "upload_files/demo.jpg"}}

        class _FakeAsyncClient:
            def __init__(self, *, timeout):
                captured["timeout"] = timeout

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb):
                return False

            async def post(self, url, *, headers, params, files, data):
                captured["url"] = url
                captured["headers"] = headers
                captured["params"] = params
                captured["files"] = files
                captured["data"] = data
                return _FakeResponse()

        with patch("httpx.AsyncClient", _FakeAsyncClient):
            result = await SageClient(
                api_url="http://sage.internal",
            ).upload_workspace_file(
                user_id="user-1",
                agent_id="agent-1",
                filename="demo.jpg",
                content=b"image",
                content_type="image/jpeg",
                target_path="upload_files",
            )

        self.assertEqual(
            captured["url"],
            "http://sage.internal/api/agent/agent-1/file_workspace/upload",
        )
        self.assertEqual(captured["headers"], {"X-Sage-Internal-UserId": "user-1"})
        self.assertEqual(captured["params"], {"target_path": "upload_files"})
        self.assertEqual(captured["data"], {"target_path": "upload_files"})
        self.assertEqual(
            captured["files"],
            {"file": ("demo.jpg", b"image", "image/jpeg")},
        )
        self.assertEqual(result, {"path": "upload_files/demo.jpg"})
