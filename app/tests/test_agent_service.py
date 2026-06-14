from __future__ import annotations

import base64
import io
import json
import unittest
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from config import constants
from config.settings import get_app_config
from models.agent import AgentMessage, AgentSession, AgentSessionDao
from PIL import Image
from services.agent.runtime_context import AgentRuntimeContextBuilder
from services.agent.sage import SageMessageChunk
from services.agent.service import AgentService, build_daily_session_id
from sqlalchemy.exc import IntegrityError


class AgentServiceRuntimeSystemContextTests(unittest.IsolatedAsyncioTestCase):
    def _parse_current_time_with_weekday(self, value: str) -> tuple[datetime, str]:
        timestamp, weekday = value.split(",", 1)
        return datetime.fromisoformat(timestamp.strip()), weekday.strip()

    async def test_enrich_runtime_system_context_uses_user_locale_and_latest_device_values(
        self,
    ) -> None:
        builder = AgentRuntimeContextBuilder()
        builder.push_device_dao.get_latest_device = AsyncMock(
            return_value=SimpleNamespace(
                locale="en-US",
                timezone="America/Los_Angeles",
                location_data={
                    "country": "China",
                    "administrative_area": "Shanghai",
                    "city": "Shanghai",
                },
            )
        )
        builder.user_config_dao.get_config = AsyncMock(
            return_value={"timezone": "Asia/Tokyo", "locale": "zh-CN"},
        )

        resolved = await builder.enrich(
            "user-1",
            {"timezone": constants.DEFAULT_TIMEZONE},
        )

        self.assertEqual(resolved["current_timezone"], "America/Los_Angeles")
        self.assertNotIn("current_location", resolved)
        self.assertIn("大概地址：Shanghai, China", resolved["last_known_location"])
        self.assertIn("文字地址为系统反查的大概地址", resolved["last_known_location"])
        self.assertEqual(resolved["response_language"], "zh-CN")
        self.assertIn("使用中文", resolved["response_language_instruction"])
        parsed_time, weekday = self._parse_current_time_with_weekday(resolved["current_time"])
        self.assertIsNotNone(parsed_time.tzinfo)
        self.assertEqual(weekday, parsed_time.strftime("%A"))

    async def test_enrich_runtime_system_context_falls_back_to_device_locale(
        self,
    ) -> None:
        builder = AgentRuntimeContextBuilder()
        builder.push_device_dao.get_latest_device = AsyncMock(
            return_value=SimpleNamespace(
                locale="en-US",
                timezone="America/Los_Angeles",
                location_data={},
            )
        )
        builder.user_config_dao.get_config = AsyncMock(return_value={})

        resolved = await builder.enrich(
            "user-1",
            {"timezone": constants.DEFAULT_TIMEZONE},
        )

        self.assertEqual(resolved["response_language"], "en-US")
        self.assertIn("Use English", resolved["response_language_instruction"])
        self.assertIn(
            "user-visible replies",
            resolved["response_language_instruction"],
        )

    async def test_enrich_runtime_system_context_falls_back_to_latest_device(
        self,
    ) -> None:
        builder = AgentRuntimeContextBuilder()
        builder.push_device_dao.get_latest_device = AsyncMock(
            return_value=SimpleNamespace(
                locale="en-US",
                timezone="America/New_York",
                location_data={
                    "latitude": 40.7128,
                    "longitude": -74.006,
                },
            )
        )
        builder.user_config_dao.get_config = AsyncMock(return_value={})

        resolved = await builder.enrich("user-2", {})

        self.assertEqual(resolved["current_timezone"], "America/New_York")
        self.assertNotIn("current_location", resolved)
        self.assertIn("坐标：(40.7128, -74.006)", resolved["last_known_location"])
        self.assertIn("精确位置以坐标为准", resolved["last_known_location"])
        self.assertEqual(resolved["response_language"], "en-US")
        self.assertIn("Use English", resolved["response_language_instruction"])
        parsed_time, weekday = self._parse_current_time_with_weekday(resolved["current_time"])
        self.assertIsNotNone(parsed_time.tzinfo)
        self.assertEqual(weekday, parsed_time.strftime("%A"))

    async def test_enrich_runtime_system_context_uses_location_captured_at(
        self,
    ) -> None:
        builder = AgentRuntimeContextBuilder()
        captured_at = datetime.now(timezone.utc) - timedelta(minutes=8)
        builder.push_device_dao.get_latest_device = AsyncMock(
            return_value=SimpleNamespace(
                locale="zh-CN",
                timezone=constants.DEFAULT_TIMEZONE,
                location_data={
                    "formatted_address": "1 Market St, Shanghai, China",
                    "captured_at": captured_at.isoformat(),
                },
                location_updated_at=datetime.now(timezone.utc) - timedelta(days=1),
            )
        )
        builder.user_config_dao.get_config = AsyncMock(return_value={})

        resolved = await builder.enrich("user-4", {})

        self.assertIn("大概地址：1 Market St, Shanghai, China", resolved["last_known_location"])
        self.assertIn("约 8 分钟前记录", resolved["last_known_location"])

    async def test_enrich_runtime_system_context_falls_back_to_location_updated_at(
        self,
    ) -> None:
        builder = AgentRuntimeContextBuilder()
        builder.push_device_dao.get_latest_device = AsyncMock(
            return_value=SimpleNamespace(
                locale="zh-CN",
                timezone=constants.DEFAULT_TIMEZONE,
                location_data={"city": "Shanghai"},
                location_updated_at=datetime.now(timezone.utc) - timedelta(hours=2),
            )
        )
        builder.user_config_dao.get_config = AsyncMock(return_value={})

        resolved = await builder.enrich("user-5", {})

        self.assertIn("大概地址：Shanghai", resolved["last_known_location"])
        self.assertIn("约 2 小时前记录", resolved["last_known_location"])

    async def test_enrich_runtime_system_context_overwrites_existing_runtime_values(
        self,
    ) -> None:
        builder = AgentRuntimeContextBuilder()
        builder.push_device_dao.get_latest_device = AsyncMock(return_value=None)
        builder.user_config_dao.get_config = AsyncMock(return_value={})

        resolved = await builder.enrich(
            "user-3",
            {
                "current_location": "Shanghai Xuhui",
                "current_timezone": "Asia/Tokyo",
                "current_time": "2026-04-05T12:34:56+09:00",
                "response_language": "ja-JP",
            },
        )

        self.assertNotIn("current_location", resolved)
        self.assertEqual(resolved["last_known_location"], "")
        self.assertEqual(resolved["current_timezone"], "Asia/Tokyo")
        self.assertEqual(resolved["response_language"], "zh-CN")
        self.assertNotEqual(resolved["current_time"], "2026-04-05T12:34:56+09:00")
        parsed_time, weekday = self._parse_current_time_with_weekday(resolved["current_time"])
        self.assertEqual(parsed_time.utcoffset(), timedelta(hours=9))
        self.assertEqual(weekday, parsed_time.strftime("%A"))

    async def test_enrich_runtime_system_context_defaults_to_utc_when_missing(
        self,
    ) -> None:
        builder = AgentRuntimeContextBuilder()
        builder.push_device_dao.get_latest_device = AsyncMock(return_value=None)
        builder.user_config_dao.get_config = AsyncMock(return_value={"timezone": "America/Chicago"})

        resolved = await builder.enrich(
            "user-4",
            {"timezone": "Invalid/Timezone"},
        )

        self.assertNotIn("current_location", resolved)
        self.assertEqual(resolved["last_known_location"], "")
        self.assertEqual(resolved["current_timezone"], "America/Chicago")
        self.assertEqual(resolved["response_language"], "zh-CN")
        parsed_time, weekday = self._parse_current_time_with_weekday(resolved["current_time"])
        self.assertIsNotNone(parsed_time.tzinfo)
        self.assertEqual(weekday, parsed_time.strftime("%A"))

    async def test_enrich_runtime_system_context_defaults_to_default_timezone_when_missing(
        self,
    ) -> None:
        builder = AgentRuntimeContextBuilder()
        builder.push_device_dao.get_latest_device = AsyncMock(return_value=None)
        builder.user_config_dao.get_config = AsyncMock(return_value={})

        resolved = await builder.enrich(
            "user-5",
            {"timezone": "Invalid/Timezone"},
        )

        self.assertNotIn("current_location", resolved)
        self.assertEqual(resolved["last_known_location"], "")
        self.assertEqual(resolved["current_timezone"], constants.DEFAULT_TIMEZONE)
        self.assertEqual(resolved["response_language"], "zh-CN")
        parsed_time, weekday = self._parse_current_time_with_weekday(resolved["current_time"])
        self.assertEqual(parsed_time.utcoffset(), timedelta(hours=8))
        self.assertEqual(weekday, parsed_time.strftime("%A"))


class AgentServiceConversationEntryTests(unittest.TestCase):
    def test_user_entry_includes_guidance_metadata_and_attachments(self) -> None:
        service = AgentService()
        message = AgentMessage(
            record_id="umsg-guidance",
            session_id="session-1",
            user_id="user-1",
            message_id="msg-guidance",
            role="user",
            message={
                "content": [
                    {"type": "text", "text": "看这张图"},
                    {
                        "type": "image_url",
                        "image_url": {"url": "https://example.com/a.png"},
                    },
                ],
                "metadata": {"guidance_id": "guidance-1", "ling_source": "text"},
            },
            message_type="user_input",
            is_final=True,
        )

        entry = service._build_user_entry(message)

        self.assertEqual(entry["text"], "看这张图")
        self.assertEqual(entry["metadata"]["guidance_id"], "guidance-1")
        self.assertEqual(entry["attachments"][0]["message_content"]["type"], "image_url")

    def test_assistant_entry_omits_internal_message_metadata(self) -> None:
        service = AgentService()
        message = AgentMessage(
            record_id="amsg-normal",
            session_id="session-1",
            user_id="user-1",
            message_id="msg-normal",
            role="assistant",
            message={
                "content": "普通回复",
                "internal_metadata": {"title": "不应该透出"},
            },
            message_type=None,
            is_final=True,
        )

        entry = service._build_assistant_entry(message)

        self.assertNotIn("internal_metadata", entry)


class AgentServiceToolCallPersistenceTests(unittest.IsolatedAsyncioTestCase):
    async def test_store_non_whitelist_tool_call_keeps_arguments_in_message(
        self,
    ) -> None:
        service = AgentService()
        inserted_messages = []

        async def _capture_insert(message):
            inserted_messages.append(message)

        service.message_dao.get_session_message = AsyncMock(return_value=None)
        service.message_dao.insert = AsyncMock(side_effect=_capture_insert)
        service.build_entry_updates_for_message = AsyncMock(return_value=[])
        service._touch_session = AsyncMock()

        chunk = SageMessageChunk(
            role="assistant",
            message_id="msg-tool-call",
            message_type="tool_call",
            tool_calls=[
                {
                    "id": "call-1",
                    "function": {
                        "name": "search_memory",
                        "arguments": {
                            "query": "生日",
                        },
                    },
                }
            ],
        )

        await service.store_assistant_chunk("user-1", "session-1", chunk)

        self.assertEqual(len(inserted_messages), 1)
        self.assertEqual(inserted_messages[0].tool_call_id, "call-1")
        self.assertEqual(
            inserted_messages[0].message,
            {
                "tool_calls": [
                    {
                        "id": "call-1",
                        "function": {
                            "name": "search_memory",
                            "arguments": {"query": "生日"},
                        },
                    }
                ]
            },
        )


    async def test_store_whitelist_tool_call_keeps_arguments_in_message(
        self,
    ) -> None:
        service = AgentService()
        inserted_messages = []

        async def _capture_insert(message):
            inserted_messages.append(message)

        service.message_dao.get_session_message = AsyncMock(return_value=None)
        service.message_dao.insert = AsyncMock(side_effect=_capture_insert)
        service.build_entry_updates_for_message = AsyncMock(return_value=[])
        service._touch_session = AsyncMock()

        chunk = SageMessageChunk(
            role="assistant",
            message_id="msg-calendar-call",
            message_type="tool_call",
            tool_calls=[
                {
                    "id": "call-calendar",
                    "type": "function",
                    "function": {
                        "name": "calendar_create_event",
                        "arguments": {
                            "title": "前往上海出行",
                        },
                    },
                }
            ],
        )

        await service.store_assistant_chunk("user-1", "session-1", chunk)

        self.assertEqual(len(inserted_messages), 1)
        self.assertEqual(inserted_messages[0].tool_call_id, "call-calendar")
        self.assertEqual(
            inserted_messages[0].message,
            {
                "tool_calls": [
                    {
                        "id": "call-calendar",
                        "function": {
                            "name": "calendar_create_event",
                            "arguments": {"title": "前往上海出行"},
                        },
                    }
                ]
            },
        )

    async def test_store_tool_call_streaming_arguments_concat_by_message_id(
        self,
    ) -> None:
        service = AgentService()
        stored_message = None

        async def _get_session_message(user_id, session_id, message_id):
            nonlocal stored_message
            if stored_message is None:
                return None
            if (
                stored_message.user_id == user_id
                and stored_message.session_id == session_id
                and stored_message.message_id == message_id
            ):
                return stored_message
            return None

        async def _capture_insert(message):
            nonlocal stored_message
            stored_message = message

        async def _capture_save(message):
            nonlocal stored_message
            stored_message = message

        service.message_dao.get_session_message = AsyncMock(side_effect=_get_session_message)
        service.message_dao.insert = AsyncMock(side_effect=_capture_insert)
        service.message_dao.save = AsyncMock(side_effect=_capture_save)
        service.build_entry_updates_for_message = AsyncMock(return_value=[])
        service._touch_session = AsyncMock()

        first_chunk = SageMessageChunk(
            role="assistant",
            message_id="msg-tool-call-stream",
            message_type="tool_call",
            tool_calls=[
                {
                    "id": "call-1",
                    "function": {
                        "name": "calendar_create_event",
                        "arguments": '{"title":"前往',
                    },
                }
            ],
        )
        second_chunk = SageMessageChunk(
            role="assistant",
            message_id="msg-tool-call-stream",
            message_type="tool_call",
            tool_calls=[
                {
                    "id": "call-1",
                    "function": {
                        "arguments": '上海出行"}',
                    },
                }
            ],
            is_final=True,
        )

        await service.store_assistant_chunk("user-1", "session-1", first_chunk)
        await service.store_assistant_chunk("user-1", "session-1", second_chunk)

        self.assertIsNotNone(stored_message)
        self.assertEqual(stored_message.tool_call_id, "call-1")
        self.assertEqual(
            stored_message.message,
            {
                "tool_calls": [
                    {
                        "id": "call-1",
                        "function": {
                            "name": "calendar_create_event",
                            "arguments": '{"title":"前往上海出行"}',
                        },
                    }
                ]
            },
        )
        serialized = service.serialize_message(stored_message)
        self.assertEqual(
            serialized["message"]["tool_calls"][0]["function"]["arguments"],
            '{"title":"前往上海出行"}',
        )

    async def test_store_non_whitelist_tool_result_keeps_content_before_insert(
        self,
    ) -> None:
        service = AgentService()
        inserted_messages = []

        async def _capture_insert(message):
            inserted_messages.append(message)

        service.message_dao.get_session_message = AsyncMock(return_value=None)
        service.message_dao.insert = AsyncMock(side_effect=_capture_insert)
        service.build_entry_updates_for_message = AsyncMock(return_value=[])
        service._touch_session = AsyncMock()

        chunk = SageMessageChunk(
            role="tool",
            message_id="msg-tool-result",
            message_type="tool_call_result",
            tool_call_id="call-search",
            content='{"ok": true, "function_name": "search_memory"}',
            is_final=True,
        )

        await service.store_assistant_chunk("user-1", "session-1", chunk)

        self.assertEqual(len(inserted_messages), 1)
        self.assertEqual(inserted_messages[0].tool_call_id, "call-search")
        self.assertEqual(
            inserted_messages[0].message,
            {
                "content": '{"ok": true, "function_name": "search_memory"}',
                "tool_call_id": "call-search",
            },
        )
        serialized = service.serialize_message(inserted_messages[0])
        self.assertEqual(serialized["tool_call_id"], "call-search")

    async def test_store_whitelist_tool_result_keeps_content_with_result_name(
        self,
    ) -> None:
        service = AgentService()
        inserted_messages = []

        async def _capture_insert(message):
            inserted_messages.append(message)

        service.message_dao.get_session_message = AsyncMock(return_value=None)
        service.message_dao.insert = AsyncMock(side_effect=_capture_insert)
        service.build_entry_updates_for_message = AsyncMock(return_value=[])
        service._touch_session = AsyncMock()

        chunk = SageMessageChunk(
            role="tool",
            message_id="msg-calendar-result",
            message_type="tool_call_result",
            tool_call_id="call-calendar",
            content='{"ok": true, "action": "calendar_create_event", "data": {"event_id": "evt-1", "title": "前往上海出行"}}',
            is_final=True,
        )

        await service.store_assistant_chunk("user-1", "session-1", chunk)

        self.assertEqual(len(inserted_messages), 1)
        self.assertEqual(inserted_messages[0].tool_call_id, "call-calendar")
        self.assertEqual(
            inserted_messages[0].message,
            {
                "content": '{"ok": true, "action": "calendar_create_event", "data": {"event_id": "evt-1", "title": "前往上海出行"}}',
                "tool_call_id": "call-calendar",
            },
        )

    async def test_store_travel_tool_result_keeps_content_with_result_name(
        self,
    ) -> None:
        service = AgentService()
        inserted_messages = []

        async def _capture_insert(message):
            inserted_messages.append(message)

        service.message_dao.get_session_message = AsyncMock(return_value=None)
        service.message_dao.insert = AsyncMock(side_effect=_capture_insert)
        service.build_entry_updates_for_message = AsyncMock(return_value=[])
        service._touch_session = AsyncMock()

        chunk = SageMessageChunk(
            role="tool",
            message_id="msg-travel-result",
            message_type="tool_call_result",
            tool_call_id="call-travel",
            content='{"ok": true, "action": "travel_flight_search", "data": {"origin": "SHA", "destination": "BJS"}}',
            is_final=True,
        )

        await service.store_assistant_chunk("user-1", "session-1", chunk)

        self.assertEqual(len(inserted_messages), 1)
        self.assertEqual(
            inserted_messages[0].message,
            {
                "content": '{"ok": true, "action": "travel_flight_search", "data": {"origin": "SHA", "destination": "BJS"}}',
                "tool_call_id": "call-travel",
            },
        )

    async def test_store_whitelist_tool_result_keeps_content_with_request_name_fallback(
        self,
    ) -> None:
        service = AgentService()
        inserted_messages = []

        async def _capture_insert(message):
            inserted_messages.append(message)

        service.message_dao.get_session_message = AsyncMock(return_value=None)
        service.message_dao.insert = AsyncMock(side_effect=_capture_insert)
        service.build_entry_updates_for_message = AsyncMock(return_value=[])
        service._touch_session = AsyncMock()
        service._find_tool_call_request = AsyncMock(
            return_value=(
                {
                    "id": "call-calendar",
                    "function": {
                        "name": "calendar_update_event",
                    },
                },
                None,
            )
        )

        chunk = SageMessageChunk(
            role="tool",
            message_id="msg-calendar-result",
            message_type="tool_call_result",
            tool_call_id="call-calendar",
            content='{"ok": true, "data": {"event_id": "evt-1", "title": "前往上海出行"}}',
            is_final=True,
        )

        await service.store_assistant_chunk("user-1", "session-1", chunk)

        self.assertEqual(len(inserted_messages), 1)
        self.assertEqual(
            inserted_messages[0].message,
            {
                "content": '{"ok": true, "data": {"event_id": "evt-1", "title": "前往上海出行"}}',
                "tool_call_id": "call-calendar",
            },
        )

    async def test_store_location_tool_result_keeps_content_with_request_name_fallback(
        self,
    ) -> None:
        service = AgentService()
        inserted_messages = []

        async def _capture_insert(message):
            inserted_messages.append(message)

        service.message_dao.get_session_message = AsyncMock(return_value=None)
        service.message_dao.insert = AsyncMock(side_effect=_capture_insert)
        service.build_entry_updates_for_message = AsyncMock(return_value=[])
        service._touch_session = AsyncMock()
        service._find_tool_call_request = AsyncMock(
            return_value=(
                {
                    "id": "call-intent",
                    "function": {
                        "name": "location_route_plan",
                    },
                },
                None,
            )
        )

        chunk = SageMessageChunk(
            role="tool",
            message_id="msg-location-result",
            message_type="tool_call_result",
            tool_call_id="call-intent",
            content='{"ok": true, "data": {"distance_meters": 12000, "duration_seconds": 1800}}',
            is_final=True,
        )

        await service.store_assistant_chunk("user-1", "session-1", chunk)

        self.assertEqual(len(inserted_messages), 1)
        self.assertEqual(
            inserted_messages[0].message,
            {
                "content": '{"ok": true, "data": {"distance_meters": 12000, "duration_seconds": 1800}}',
                "tool_call_id": "call-intent",
            },
        )

    async def test_find_tool_call_request_falls_back_for_multi_call_message(
        self,
    ) -> None:
        service = AgentService()
        tool_call_message = AgentMessage(
            record_id="amsg-tool-call",
            session_id="session-1",
            user_id="user-1",
            role="assistant",
            message={
                "tool_calls": [
                    {"id": "call-first", "function": {"name": "search_memory"}},
                    {"id": "call-second", "function": {"name": "calendar_create_event"}},
                ]
            },
            message_id="msg-tool-call",
            tool_call_id="call-first",
            message_type="tool_call",
            is_final=True,
        )
        service.message_dao.list_session_tool_call_messages = AsyncMock(
            side_effect=[[], [tool_call_message]],
        )

        tool_call, source_message = await service._find_tool_call_request(
            "user-1",
            "session-1",
            "call-second",
        )

        self.assertIs(source_message, tool_call_message)
        self.assertEqual(tool_call["function"]["name"], "calendar_create_event")
        self.assertEqual(
            service.message_dao.list_session_tool_call_messages.await_args_list[0].kwargs,
            {"tool_call_id": "call-second"},
        )
        self.assertEqual(
            service.message_dao.list_session_tool_call_messages.await_args_list[1].kwargs,
            {},
        )

    async def test_assemble_conversation_entries_uses_nested_tool_call_id(
        self,
    ) -> None:
        service = AgentService()
        tool_call_message = AgentMessage(
            record_id="amsg-tool-call",
            session_id="session-1",
            user_id="user-1",
            role="assistant",
            message={
                "tool_calls": [
                    {
                        "id": "call-1",
                        "function": {
                            "name": "search_memory",
                        },
                    }
                ]
            },
            message_id="msg-tool-call",
            message_type="tool_call",
            is_final=True,
        )
        tool_call_message.created_at = datetime(2026, 4, 10, 9, 0, 0)
        tool_call_message.updated_at = datetime(2026, 4, 10, 9, 0, 0)

        tool_result_message = AgentMessage(
            record_id="amsg-tool-result",
            session_id="session-1",
            user_id="user-1",
            role="tool",
            message={
                "tool_call_id": "call-1",
            },
            message_id="msg-tool-result",
            message_type="tool_call_result",
            is_final=True,
        )
        tool_result_message.created_at = datetime(2026, 4, 10, 9, 0, 5)
        tool_result_message.updated_at = datetime(2026, 4, 10, 9, 0, 5)

        entries = service._assemble_conversation_entries(
            [tool_call_message, tool_result_message],
            keep_last_assistant_streaming=False,
        )

        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["entry_type"], "tool_call")
        self.assertEqual(entries[0]["tool_call_id"], "call-1")
        self.assertEqual(entries[0]["tool_name"], "search_memory")
        self.assertEqual(entries[0]["status"], "completed")
        self.assertIsNone(entries[0]["tool_arguments"])
        self.assertIsNone(entries[0]["tool_result"])

    async def test_assemble_conversation_keeps_unmatched_tool_result_order(
        self,
    ) -> None:
        service = AgentService()
        old_calendar_result = AgentMessage(
            record_id="amsg-old-calendar-result",
            session_id="session-1",
            user_id="user-1",
            role="tool",
            message={
                "tool_call_id": "call-old-calendar",
                "content": (
                    '{"ok": true, "action": "calendar_create_event", '
                    '"data": {"event_id": "evt-old", "title": "历史日程"}}'
                ),
            },
            message_id="msg-old-calendar-result",
            message_type="tool_call_result",
            is_final=True,
        )
        old_calendar_result.created_at = datetime(2026, 5, 19, 7, 30, 0)
        old_calendar_result.updated_at = old_calendar_result.created_at

        user_message = AgentMessage(
            record_id="amsg-user",
            session_id="session-1",
            user_id="user-1",
            role="user",
            message={"content": "有时间要试一下新的 Gemini 3.5 新模型"},
            message_id=None,
            message_type="user_input",
            is_final=True,
        )
        user_message.created_at = datetime(2026, 5, 19, 7, 39, 33)
        user_message.updated_at = user_message.created_at

        travel_call = AgentMessage(
            record_id="amsg-travel-call",
            session_id="session-1",
            user_id="user-1",
            role="assistant",
            message={
                "tool_calls": [
                    {
                        "id": "call-intent",
                        "function": {"name": "travel_flight_search"},
                    }
                ]
            },
            message_id="msg-intent-call",
            message_type="tool_call",
            is_final=True,
        )
        travel_call.created_at = datetime(2026, 5, 19, 7, 39, 39)
        travel_call.updated_at = travel_call.created_at

        travel_result = AgentMessage(
            record_id="amsg-travel-result",
            session_id="session-1",
            user_id="user-1",
            role="tool",
            message={
                "tool_call_id": "call-intent",
                "content": (
                    '{"ok": true, "action": "travel_flight_search", '
                    '"data": {"origin": "SHA", "destination": "BJS"}}'
                ),
            },
            message_id="msg-intent-result",
            message_type="tool_call_result",
            is_final=True,
        )
        travel_result.created_at = datetime(2026, 5, 19, 7, 39, 42)
        travel_result.updated_at = travel_result.created_at

        final_reply = AgentMessage(
            record_id="amsg-final",
            session_id="session-1",
            user_id="user-1",
            role="assistant",
            message={"content": "已帮你查找航班"},
            message_id="msg-final",
            message_type="do_subtask_result",
            is_final=True,
        )
        final_reply.created_at = datetime(2026, 5, 19, 7, 39, 45)
        final_reply.updated_at = final_reply.created_at

        entries = service._assemble_conversation_entries(
            [
                old_calendar_result,
                user_message,
                travel_call,
                travel_result,
                final_reply,
            ],
            keep_last_assistant_streaming=False,
        )

        self.assertEqual(
            [
                (entry["id"], entry["entry_type"], entry["tool_name"])
                for entry in entries
            ],
            [
                (
                    "tool_call:call-old-calendar",
                    "tool_call",
                    "calendar_create_event",
                ),
                ("amsg-user", "user_message", None),
                ("tool_call:call-intent", "tool_call", "travel_flight_search"),
                ("msg-final", "assistant_message", None),
            ],
        )

    async def test_list_conversation_entries_reads_tail_window_only(self) -> None:
        service = AgentService()
        messages = [
            AgentMessage(
                record_id=f"amsg-{index}",
                session_id="session-1",
                user_id="user-1",
                role="assistant" if index % 2 else "user",
                message={"content": f"message-{index}"},
                message_id=f"msg-{index}",
                message_type="message" if index % 2 else "user_input",
                is_final=True,
            )
            for index in range(3)
        ]
        for index, message in enumerate(messages):
            message.created_at = datetime(2026, 4, 10, 9, index, 0)
            message.updated_at = message.created_at
        service.message_dao.list_session_messages_desc = AsyncMock(
            return_value=[messages[2], messages[1], messages[0]]
        )
        service.message_dao.list_session_messages = AsyncMock()

        payload = await service.list_conversation_entries(
            "user-1",
            "session-1",
            message_limit=2,
        )

        self.assertTrue(payload["has_more"])
        self.assertEqual(payload["message_limit"], 2)
        self.assertEqual(
            [item["id"] for item in payload["items"]],
            ["msg-1", "msg-2"],
        )
        service.message_dao.list_session_messages_desc.assert_awaited_once_with(
            "user-1",
            "session-1",
            limit=3,
            before_created_at=None,
            before_record_id=None,
        )
        service.message_dao.list_session_messages.assert_not_called()

    async def test_list_user_conversation_entries_pages_across_daily_sessions(self) -> None:
        service = AgentService()
        messages = [
            AgentMessage(
                record_id=f"amsg-{index}",
                session_id=(
                    "ling_user-1_20260410"
                    if index < 2
                    else "ling_user-1_20260411"
                ),
                user_id="user-1",
                role="assistant" if index % 2 else "user",
                message={"content": f"message-{index}"},
                message_id=f"msg-{index}",
                message_type="message" if index % 2 else "user_input",
                is_final=True,
            )
            for index in range(4)
        ]
        for index, message in enumerate(messages):
            message.created_at = datetime(2026, 4, 10, 9, index, 0)
            message.updated_at = message.created_at
        service.message_dao.list_user_messages_desc = AsyncMock(
            return_value=[messages[3], messages[2], messages[1]]
        )
        service.message_dao.list_user_messages = AsyncMock()

        payload = await service.list_user_conversation_entries(
            "user-1",
            message_limit=2,
        )

        self.assertTrue(payload["has_more"])
        self.assertEqual(payload["message_limit"], 2)
        self.assertEqual(
            [(item["session_id"], item["id"]) for item in payload["items"]],
            [
                ("ling_user-1_20260411", "msg-2"),
                ("ling_user-1_20260411", "msg-3"),
            ],
        )
        self.assertEqual(
            payload["older_cursor"],
            {
                "before_created_at": "2026-04-10T09:02:00+00:00",
                "before_record_id": "amsg-2",
            },
        )
        service.message_dao.list_user_messages_desc.assert_awaited_once_with(
            "user-1",
            limit=3,
            before_created_at=None,
            before_record_id=None,
        )
        service.message_dao.list_user_messages.assert_not_called()

    async def test_list_user_conversation_entries_applies_cursor_timestamp(self) -> None:
        service = AgentService()
        service.message_dao.list_user_messages_desc = AsyncMock(return_value=[])

        payload = await service.list_user_conversation_entries(
            "user-1",
            message_limit=2,
            before_created_at="2026-05-17T07:16:27+00:00",
            before_record_id="amsg_older",
        )

        self.assertFalse(payload["has_more"])
        service.message_dao.list_user_messages_desc.assert_awaited_once_with(
            "user-1",
            limit=3,
            before_created_at=datetime(2026, 5, 17, 7, 16, 27),
            before_record_id="amsg_older",
        )

    async def test_build_tool_call_entry_keeps_calendar_card_result(
        self,
    ) -> None:
        service = AgentService()
        entry = service._build_tool_call_entry(
            tool_call={
                "id": "call-calendar",
                "function": {
                    "name": "calendar_create_event",
                    "arguments": {
                        "title": "前往上海出行",
                    },
                },
            },
            result_message=SimpleNamespace(
                tool_call_id="call-calendar",
                message={
                    "content": '{"ok": true, "action": "calendar_create_event", "data": {"event_id": "evt-1"}}',
                },
                message_id="msg-calendar-result",
                created_at=datetime(2026, 4, 10, 9, 0, 6),
            ),
            source_message=SimpleNamespace(
                created_at=datetime(2026, 4, 10, 9, 0, 0),
            ),
        )

        self.assertEqual(entry["tool_name"], "calendar_create_event")
        self.assertEqual(
            json.loads(entry["tool_arguments"]),
            {"title": "前往上海出行"},
        )
        self.assertEqual(
            entry["tool_result"],
            '{"ok": true, "action": "calendar_create_event", "data": {"event_id": "evt-1"}}',
        )
        self.assertEqual(entry["duration_ms"], 6000)

    async def test_build_entry_updates_for_finalized_tool_call_keeps_result(
        self,
    ) -> None:
        service = AgentService()
        tool_call_message = AgentMessage(
            record_id="amsg-tool-call-final",
            session_id="session-1",
            user_id="user-1",
            role="assistant",
            message={
                "tool_calls": [
                    {
                        "id": "call-calendar",
                        "function": {
                            "name": "calendar_create_event",
                            "arguments": {
                                "title": "前往上海出行",
                            },
                        },
                    }
                ]
            },
            message_id="msg-tool-call-final",
            message_type="tool_call",
            is_final=True,
        )
        tool_call_message.created_at = datetime(2026, 4, 10, 9, 0, 0)
        tool_call_message.updated_at = datetime(2026, 4, 10, 9, 0, 0)

        tool_result_message = AgentMessage(
            record_id="amsg-tool-result-final",
            session_id="session-1",
            user_id="user-1",
            role="tool",
            message={
                "tool_call_id": "call-calendar",
                "content": '{"ok": true, "action": "calendar_create_event", "data": {"event_id": "evt-1", "title": "前往上海出行"}}',
            },
            message_id="msg-tool-result-final",
            message_type="tool_call_result",
            is_final=True,
        )
        tool_result_message.created_at = datetime(2026, 4, 10, 9, 0, 6)
        tool_result_message.updated_at = datetime(2026, 4, 10, 9, 0, 6)

        service.message_dao.list_session_tool_result_messages = AsyncMock(
            return_value=[tool_result_message]
        )

        updates = await service.build_entry_updates_for_message(
            "user-1",
            "session-1",
            tool_call_message,
        )

        self.assertEqual(len(updates), 1)
        self.assertEqual(updates[0]["id"], "tool_call:call-calendar")
        self.assertEqual(updates[0]["status"], "completed")
        self.assertFalse(updates[0]["is_streaming"])
        self.assertEqual(updates[0]["tool_name"], "calendar_create_event")
        self.assertEqual(
            updates[0]["tool_result"],
            '{"ok": true, "action": "calendar_create_event", "data": {"event_id": "evt-1", "title": "前往上海出行"}}',
        )

    def test_next_agent_message_record_id_uses_uuid7(self) -> None:
        service = AgentService()
        fake_uuid = SimpleNamespace(hex="018f5c6e8a7d7d64b9c89c2f7ad5e8d1")
        with patch("services.agent.service.generate_uuid7", return_value=fake_uuid):
            record_id = service._next_agent_message_record_id()
        self.assertEqual(record_id, "amsg_018f5c6e8a7d7d64b9c89c2f7ad5e8d1")


class AgentServiceSageImageUrlTests(unittest.IsolatedAsyncioTestCase):
    async def test_prepare_messages_for_sage_keeps_remote_image_as_url(self) -> None:
        service = AgentService()
        buffer = io.BytesIO()
        Image.effect_noise((1600, 1200), 100).convert("RGB").save(
            buffer,
            format="JPEG",
            quality=95,
        )
        image_bytes = buffer.getvalue()

        class _FakeResponse:
            def __init__(self) -> None:
                self.content = image_bytes
                self.headers = {"content-type": "image/jpeg; charset=binary"}

            def raise_for_status(self) -> None:
                return None

        class _FakeAsyncClient:
            def __init__(self, *args, **kwargs) -> None:
                pass

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb) -> None:
                return None

            async def get(self, url: str) -> _FakeResponse:
                self.requested_url = url
                return _FakeResponse()

        messages = [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": "https://cdn.example.com/demo.webp",
                            "detail": "auto",
                        },
                    }
                ],
            }
        ]

        with patch("utils.image_size_guard.httpx.AsyncClient", _FakeAsyncClient):
            prepared = await service._prepare_messages_for_sage(messages)

        self.assertEqual(
            prepared[0]["content"][0]["image_url"]["url"],
            "https://cdn.example.com/demo.webp",
        )
        self.assertEqual(
            messages[0]["content"][0]["image_url"]["url"],
            "https://cdn.example.com/demo.webp",
        )

    async def test_prepare_messages_for_sage_omits_input_audio(self) -> None:
        service = AgentService()
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "语音转写文本"},
                    {
                        "type": "input_audio",
                        "input_audio": {
                            "url": "https://cdn.example.com/voice.caf",
                            "format": "caf",
                        },
                    },
                ],
            }
        ]

        prepared = await service._prepare_messages_for_sage(messages)

        self.assertEqual(
            prepared,
            [
                {
                    "role": "user",
                    "content": [{"type": "text", "text": "语音转写文本"}],
                }
            ],
        )
        self.assertEqual(messages[0]["content"][1]["type"], "input_audio")

    async def test_prepare_messages_for_sage_marks_voice_transcript_text_only(self) -> None:
        service = AgentService()
        messages = [
            {
                "role": "user",
                "content": "帮我安排明天下午三点开会",
                "metadata": {"input_source": "voice_transcript"},
            }
        ]

        prepared = await service._prepare_messages_for_sage(messages)

        self.assertEqual(
            prepared,
            [
                {
                    "role": "user",
                    "content": "【语音转写】帮我安排明天下午三点开会",
                }
            ],
        )
        self.assertEqual(messages[0]["content"], "帮我安排明天下午三点开会")
        self.assertNotIn("metadata", prepared[0])

    async def test_prepare_messages_for_sage_marks_voice_transcript_after_skill_tags(
        self,
    ) -> None:
        service = AgentService()
        messages = [
            {
                "role": "user",
                "content": "<skill>schedule-management</skill>\n安排明天三点开会",
                "metadata": {"input_source": "voice_transcript"},
            }
        ]

        prepared = await service._prepare_messages_for_sage(messages)

        self.assertEqual(
            prepared[0]["content"],
            "<skill>schedule-management</skill>\n【语音转写】安排明天三点开会",
        )

    async def test_prepare_messages_for_sage_marks_voice_transcript_list_text_only(
        self,
    ) -> None:
        service = AgentService()
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "语音转写文本"},
                    {
                        "type": "input_audio",
                        "input_audio": {
                            "url": "https://cdn.example.com/voice.caf",
                            "format": "caf",
                        },
                    },
                ],
                "metadata": {"input_source": "voice_transcript"},
            }
        ]

        prepared = await service._prepare_messages_for_sage(messages)

        self.assertEqual(
            prepared,
            [
                {
                    "role": "user",
                    "content": [{"type": "text", "text": "【语音转写】语音转写文本"}],
                }
            ],
        )
        self.assertEqual(messages[0]["content"][0]["text"], "语音转写文本")

    async def test_prepare_messages_for_sage_adds_workspace_reference_for_image(
        self,
    ) -> None:
        service = AgentService()
        buffer = io.BytesIO()
        Image.new("RGB", (1024, 768), (12, 34, 56)).save(buffer, format="JPEG")
        image_bytes = buffer.getvalue()
        captured_upload: dict[str, object] = {}

        class _FakeResponse:
            def __init__(self) -> None:
                self.content = image_bytes
                self.headers = {"content-type": "image/jpeg; charset=binary"}

            def raise_for_status(self) -> None:
                return None

        class _FakeAsyncClient:
            def __init__(self, *args, **kwargs) -> None:
                pass

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb) -> None:
                return None

            async def get(self, url: str) -> _FakeResponse:
                self.requested_url = url
                return _FakeResponse()

        async def _fake_upload_workspace_file(**kwargs):
            captured_upload.update(kwargs)
            return {
                "path": f"upload_files/{kwargs['filename']}",
                "size": len(kwargs["content"]),
            }

        service.sage_client.upload_workspace_file = _fake_upload_workspace_file
        messages = [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": "https://cdn.example.com/demo.webp",
                            "detail": "auto",
                        },
                    }
                ],
            }
        ]

        with (
            patch("utils.image_size_guard.httpx.AsyncClient", _FakeAsyncClient),
            patch("services.agent.service.httpx.AsyncClient", _FakeAsyncClient),
            patch(
                "services.agent.service.uuid.uuid4",
                return_value=SimpleNamespace(hex="abcdef1234567890"),
            ),
        ):
            prepared = await service._prepare_messages_for_sage(
                messages,
                user_id="user-1",
            )

        content = prepared[0]["content"]
        self.assertEqual(len(content), 2)
        self.assertEqual(
            content[0]["image_url"]["url"],
            "https://cdn.example.com/demo.webp",
        )
        self.assertEqual(captured_upload["user_id"], "user-1")
        self.assertEqual(captured_upload["agent_id"], service.cfg.sage_agent_id)
        self.assertEqual(captured_upload["filename"], "demo_abcdef1234.jpg")
        self.assertEqual(captured_upload["content_type"], "image/jpeg")
        self.assertEqual(captured_upload["target_path"], "upload_files")
        self.assertEqual(captured_upload["content"], image_bytes)
        reference_note = content[1]["text"]
        self.assertIn("上面的图片", reference_note)
        self.assertNotIn("base64", reference_note)
        self.assertIn("这两个内容是同一张图片", reference_note)
        self.assertIn(
            f"![demo_abcdef1234.jpg](file:///app/agents/user-1/{service.cfg.sage_agent_id}/upload_files/demo_abcdef1234.jpg)",
            reference_note,
        )

    async def test_prepare_messages_for_sage_uploads_data_url_image_reference(
        self,
    ) -> None:
        service = AgentService()
        buffer = io.BytesIO()
        Image.new("RGB", (640, 480), (45, 67, 89)).save(buffer, format="PNG")
        image_bytes = buffer.getvalue()
        captured_upload: dict[str, object] = {}

        async def _fake_upload_workspace_file(**kwargs):
            captured_upload.update(kwargs)
            return {
                "path": f"upload_files/{kwargs['filename']}",
                "size": len(kwargs["content"]),
            }

        service.sage_client.upload_workspace_file = _fake_upload_workspace_file
        guarded_url = "https://cdn.example.com/guarded-image.png"
        messages = [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": (
                                "data:image/png;base64,"
                                f"{base64.b64encode(image_bytes).decode('ascii')}"
                            ),
                            "detail": "auto",
                        },
                    }
                ],
            }
        ]

        class _FakeResponse:
            def __init__(self) -> None:
                self.content = image_bytes
                self.headers = {"content-type": "image/png; charset=binary"}

            def raise_for_status(self) -> None:
                return None

        class _FakeAsyncClient:
            def __init__(self, *args, **kwargs) -> None:
                pass

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb) -> None:
                return None

            async def get(self, url: str) -> _FakeResponse:
                self.requested_url = url
                return _FakeResponse()

        with patch(
            "services.agent.service.uuid.uuid4",
            return_value=SimpleNamespace(hex="abcdef1234567890"),
        ), patch(
            "utils.image_size_guard.s3.upload_bytes",
            new=AsyncMock(
                return_value=SimpleNamespace(
                    bucket="ling-test",
                    key="agent_images/image_guards/guarded.png",
                    url=guarded_url,
                )
            ),
        ), patch("services.agent.service.httpx.AsyncClient", _FakeAsyncClient):
            prepared = await service._prepare_messages_for_sage(
                messages,
                user_id="user-1",
            )

        content = prepared[0]["content"]
        self.assertEqual(len(content), 2)
        self.assertEqual(content[0]["image_url"]["url"], guarded_url)
        self.assertEqual(captured_upload["filename"], "guarded-image_abcdef1234.png")
        self.assertEqual(captured_upload["content_type"], "image/png")
        self.assertEqual(captured_upload["target_path"], "upload_files")
        self.assertEqual(captured_upload["content"], image_bytes)
        reference_note = content[1]["text"]
        self.assertIn("Markdown 图片引用", reference_note)
        self.assertIn(
            f"![guarded-image_abcdef1234.png](file:///app/agents/user-1/{service.cfg.sage_agent_id}/upload_files/guarded-image_abcdef1234.png)",
            reference_note,
        )


class AgentServiceSessionCreationTests(unittest.IsolatedAsyncioTestCase):
    async def test_create_session_reuses_existing_daily_session_id(self) -> None:
        service = AgentService()
        existing_session = AgentSession(
            session_id="ling_user-1_20260416",
            user_id="user-1",
            agent_id=get_app_config().sage_agent_id,
            entry_mode="chat",
            timezone=constants.DEFAULT_TIMEZONE,
            selected_date="2026-04-16",
        )
        service.session_dao.get_user_session = AsyncMock(return_value=existing_session)
        service.session_dao.insert = AsyncMock()

        result = await service.create_session(
            "user-1",
            "voice",
            constants.DEFAULT_TIMEZONE,
            "2026-04-16",
        )

        self.assertEqual(result["session_id"], "ling_user-1_20260416")
        service.session_dao.insert.assert_not_awaited()

    async def test_create_session_creates_daily_session_id_when_missing(self) -> None:
        service = AgentService()
        created_session = AgentSession(
            session_id="ling_user-1_20260416",
            user_id="user-1",
            agent_id=get_app_config().sage_agent_id,
            entry_mode="chat",
            timezone=constants.DEFAULT_TIMEZONE,
            selected_date="2026-04-16",
        )
        service.session_dao.get_or_create_user_session = AsyncMock(return_value=created_session)

        with patch(
            "services.agent.service.get_local_now",
            return_value=datetime(2026, 4, 15, 16, 30, 0),
        ):
            result = await service.create_session(
                "user-1",
                "chat",
                constants.DEFAULT_TIMEZONE,
                "2026-04-16",
            )

        self.assertEqual(result["session_id"], "ling_user-1_20260416")
        service.session_dao.get_or_create_user_session.assert_awaited_once_with(
            session_id="ling_user-1_20260416",
            user_id="user-1",
            agent_id=get_app_config().sage_agent_id,
            entry_mode="chat",
            timezone=constants.DEFAULT_TIMEZONE,
            selected_date="2026-04-16",
        )

    async def test_get_or_create_user_session_returns_existing_after_duplicate_insert(self) -> None:
        class _ActiveSession:
            def __init__(self) -> None:
                self.added: list[AgentSession] = []
                self.rolled_back = False

            def add(self, item: AgentSession) -> None:
                self.added.append(item)

            async def commit(self) -> None:
                raise IntegrityError("insert agent_sessions", {}, Exception("duplicate"))

            async def rollback(self) -> None:
                self.rolled_back = True

        class _SessionScope:
            def __init__(self, active_session: _ActiveSession) -> None:
                self.active_session = active_session

            async def __aenter__(self) -> _ActiveSession:
                return self.active_session

            async def __aexit__(self, exc_type, exc, tb) -> bool:
                return False

        class _Db:
            def __init__(self, active_session: _ActiveSession) -> None:
                self.active_session = active_session

            def get_session(self, autocommit: bool = True) -> _SessionScope:
                return _SessionScope(self.active_session)

        dao = AgentSessionDao()
        active_session = _ActiveSession()
        existing_session = AgentSession(
            session_id="ling_user-1_20260416",
            user_id="user-1",
            agent_id=get_app_config().sage_agent_id,
            entry_mode="chat",
            timezone=constants.DEFAULT_TIMEZONE,
        )
        dao.get_user_session = AsyncMock(side_effect=[None, existing_session])
        dao._get_db = AsyncMock(return_value=_Db(active_session))

        result = await dao.get_or_create_user_session(
            session_id="ling_user-1_20260416",
            user_id="user-1",
            agent_id=get_app_config().sage_agent_id,
            entry_mode="chat",
            timezone=constants.DEFAULT_TIMEZONE,
        )

        self.assertIs(result, existing_session)
        self.assertEqual(len(active_session.added), 1)
        self.assertTrue(active_session.rolled_back)


class DailySessionIdBuilderTests(unittest.TestCase):
    def test_build_daily_session_id_uses_timezone_date(self) -> None:
        with patch(
            "services.agent.service.get_local_now",
            return_value=datetime(2026, 4, 15, 16, 30, 0),
        ):
            session_id = build_daily_session_id("user-1", constants.DEFAULT_TIMEZONE)

        self.assertEqual(session_id, "ling_user-1_20260416")


if __name__ == "__main__":
    unittest.main()
