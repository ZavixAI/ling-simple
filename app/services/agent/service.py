"""Agent 会话与对话：创建会话、流式 chat、消息落库、图片规范化与会员配额。

与 SageClient、AgentRuntimeContextBuilder 协作；工具调用持久化策略见 persistence 模块。
"""

from __future__ import annotations

import asyncio
import base64
import json
import mimetypes
import os
import uuid
from copy import deepcopy
from datetime import datetime
from pathlib import Path
from typing import Any, AsyncGenerator
from urllib.parse import urlparse

import httpx
from config import constants
from config.settings import get_app_config
from core.http.exceptions import AppHTTPException
from loguru import logger
from models.agent import AgentMessage, AgentMessageDao, AgentSession, AgentSessionDao
from models.base import get_local_now
from modules.membership.service import MembershipService
from services.agent.persistence import (
    resolve_tool_call_function_name,
    resolve_tool_call_result_function_name,
)
from services.agent.runtime_context import AgentRuntimeContextBuilder
from services.agent.sage import SageClient, SageMessageChunk
from utils.image_size_guard import ensure_image_url_within_size_limit
from utils.time import UTC, format_datetime, normalize_persisted_timezone, parse_timezone
from uuid_v7.base import uuid7 as generate_uuid7

_IMAGE_SUFFIX_TO_CONTENT_TYPE = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".heic": "image/heic",
    ".heif": "image/heif",
}

VOICE_TRANSCRIPT_SAGE_CONTEXT_PREFIX = "【语音转写】"
_TRANSIENT_CONTENT_UNSET = object()
_DEFAULT_CONVERSATION_ENTRY_MESSAGE_LIMIT = 80
_MAX_CONVERSATION_ENTRY_MESSAGE_LIMIT = 300


def build_daily_session_id(user_id: str, timezone: str) -> str:
    """按用户时区「当天」生成稳定 session_id，便于同日多轮共用一个会话。"""
    try:
        zone = parse_timezone(timezone)
    except ValueError:
        zone = UTC
    current_date = get_local_now().replace(tzinfo=UTC).astimezone(zone).strftime("%Y%m%d")
    return f"ling_{user_id}_{current_date}"

class AgentService:
    """Agent 领域 API：会话 CRUD、流式推理、历史查询与附件 URL 处理。"""

    def __init__(self) -> None:
        self.cfg = get_app_config()
        self.session_dao = AgentSessionDao()
        self.message_dao = AgentMessageDao()
        self.membership_service = MembershipService()
        self.runtime_context_builder = AgentRuntimeContextBuilder()
        self.sage_client = SageClient()

    async def create_session(
        self,
        user_id: str,
        entry_mode: str,
        timezone: str,
        selected_date: str | None,
    ) -> dict[str, Any]:
        try:
            normalized_timezone = normalize_persisted_timezone(timezone)
        except ValueError as exc:
            raise AppHTTPException(status_code=422, detail="Invalid timezone") from exc
        if normalized_timezone is None:
            raise AppHTTPException(status_code=422, detail="Invalid timezone")
        timezone = normalized_timezone
        session_id = build_daily_session_id(user_id, timezone)
        session = await self.session_dao.get_or_create_user_session(
            session_id=session_id,
            user_id=user_id,
            agent_id=self.cfg.sage_agent_id,
            entry_mode=entry_mode,
            timezone=timezone,
            selected_date=selected_date,
        )
        return self.serialize_session(session)

    async def get_session(self, user_id: str, session_id: str) -> dict[str, Any] | None:
        session = await self.session_dao.get_user_session(user_id, session_id)
        if session is None:
            return None
        return self.serialize_session(session)

    async def get_latest_session(self, user_id: str) -> dict[str, Any] | None:
        session = await self.session_dao.get_latest_user_session(user_id)
        if session is None:
            return None
        return self.serialize_session(session)

    async def list_messages(self, user_id: str, session_id: str) -> list[dict[str, Any]]:
        messages = await self.message_dao.list_session_messages(user_id, session_id)
        return [self.serialize_message(item) for item in messages]

    async def interrupt_session(self, user_id: str, session_id: str) -> None:
        await self.sage_client.interrupt_session(session_id=session_id, user_id=user_id)

    async def inject_user_message(
        self,
        *,
        user_id: str,
        session_id: str,
        content: Any,
        guidance_id: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        return await self.sage_client.inject_user_message(
            session_id=session_id,
            content=content,
            guidance_id=guidance_id,
            metadata=metadata,
            user_id=user_id,
        )

    async def list_pending_user_injections(
        self,
        *,
        user_id: str,
        session_id: str,
    ) -> dict[str, Any]:
        return await self.sage_client.list_pending_user_injections(
            session_id=session_id,
            user_id=user_id,
        )

    async def update_pending_user_injection(
        self,
        *,
        user_id: str,
        session_id: str,
        guidance_id: str,
        content: Any,
    ) -> dict[str, Any]:
        return await self.sage_client.update_pending_user_injection(
            session_id=session_id,
            guidance_id=guidance_id,
            content=content,
            user_id=user_id,
        )

    async def delete_pending_user_injection(
        self,
        *,
        user_id: str,
        session_id: str,
        guidance_id: str,
    ) -> dict[str, Any]:
        return await self.sage_client.delete_pending_user_injection(
            session_id=session_id,
            guidance_id=guidance_id,
            user_id=user_id,
        )

    async def store_user_messages(
        self,
        user_id: str,
        session_id: str,
        messages: list[dict[str, Any]],
    ) -> None:
        for item in messages:
            message_id = self._normalize_message_id(item.get("message_id"))
            role = item.get("role", "user")
            record = AgentMessage(
                record_id=self._next_agent_message_record_id(),
                session_id=session_id,
                user_id=user_id,
                message_id=message_id,
                role=role,
                message={
                    "content": deepcopy(item.get("content")),
                    "tool_calls": self._normalize_tool_calls(item.get("tool_calls")),
                },
                message_type="user_input",
                is_final=True,
            )
            await self.message_dao.insert(record)
        await self._touch_session(session_id, user_id)

    async def stream_chat(
        self,
        user_id: str,
        session_id: str,
        messages: list[dict[str, Any]],
        system_context: dict[str, Any],
    ) -> AsyncGenerator[str, None]:
        async for chunk in self.stream_chat_chunks(
            user_id,
            session_id,
            messages,
            system_context,
        ):
            payload = json.dumps(chunk.to_dict(), ensure_ascii=False)
            yield f"event: sage_chunk\ndata: {payload}\n\n"

    async def stream_chat_chunks(
        self,
        user_id: str,
        session_id: str,
        messages: list[dict[str, Any]],
        system_context: dict[str, Any],
    ) -> AsyncGenerator[SageMessageChunk, None]:
        await self.store_user_messages(user_id, session_id, messages)
        session = await self.session_dao.get_user_session(user_id, session_id)
        if session is not None:
            session.last_message_at = get_local_now()
            session.agent_id = self.cfg.sage_agent_id
            await self.session_dao.save(session)

        resolved_system_context = await self.runtime_context_builder.enrich(
            user_id,
            system_context,
        )
        sage_messages = await self._prepare_messages_for_sage(
            messages,
            user_id=user_id,
        )
        async for chunk in self.sage_client.chat_stream(
            session_id=session_id,
            messages=sage_messages,
            agent_id=self.cfg.sage_agent_id,
            user_id=user_id,
            system_context=resolved_system_context,
        ):
            yield chunk

    async def _prepare_messages_for_sage(
        self,
        messages: list[dict[str, Any]],
        *,
        user_id: str | None = None,
        leading_messages: list[dict[str, Any]] | None = None,
    ) -> list[dict[str, Any]]:
        prepared_messages: list[dict[str, Any]] = []
        for leading_message in leading_messages or []:
            prepared_messages.append(
                await self._prepare_message_for_sage(leading_message, user_id=user_id)
            )
        for message in messages:
            prepared_messages.append(
                await self._prepare_message_for_sage(message, user_id=user_id)
            )
        return prepared_messages

    async def _prepare_message_for_sage(
        self,
        message: dict[str, Any],
        *,
        user_id: str | None = None,
    ) -> dict[str, Any]:
        prepared_message = deepcopy(message)
        metadata = prepared_message.pop("metadata", None)
        content = prepared_message.get("content")
        if isinstance(content, list):
            prepared_content: list[Any] = []
            for item in content:
                prepared_content.extend(
                    await self._prepare_content_item_for_sage(item, user_id=user_id)
                )
            prepared_message["content"] = prepared_content if prepared_content else ""
        if self._is_voice_transcript_message(metadata):
            prepared_message["content"] = self._mark_voice_transcript_content_for_sage(
                prepared_message.get("content")
            )
        return prepared_message

    def _is_voice_transcript_message(self, metadata: Any) -> bool:
        return (
            isinstance(metadata, dict)
            and str(metadata.get("input_source") or "").strip() == "voice_transcript"
        )

    def _mark_voice_transcript_content_for_sage(self, content: Any) -> Any:
        """Only mark voice transcript context in the payload sent to Sage."""
        if isinstance(content, str):
            stripped = content.strip()
            if not stripped or stripped.startswith(VOICE_TRANSCRIPT_SAGE_CONTEXT_PREFIX):
                return content
            return self._prefix_text_content_for_sage(
                content,
                prefix=VOICE_TRANSCRIPT_SAGE_CONTEXT_PREFIX,
            )
        if isinstance(content, list):
            marked = deepcopy(content)
            for item in marked:
                if not isinstance(item, dict):
                    continue
                if str(item.get("type") or "").strip() != "text":
                    continue
                text = item.get("text")
                if (
                    isinstance(text, str)
                    and text.strip()
                    and not text.strip().startswith(
                        VOICE_TRANSCRIPT_SAGE_CONTEXT_PREFIX
                    )
                ):
                    item["text"] = self._prefix_text_content_for_sage(
                        text,
                        prefix=VOICE_TRANSCRIPT_SAGE_CONTEXT_PREFIX,
                    )
                    break
            return marked
        return content

    def _prefix_text_content_for_sage(self, content: str, *, prefix: str) -> str:
        stripped = content.strip()
        if not stripped or stripped.startswith(prefix):
            return content

        lines = content.splitlines(keepends=True)
        leading_skill_tag_end = 0
        for line in lines:
            normalized_line = line.strip()
            if normalized_line.startswith("<skill>") and normalized_line.endswith(
                "</skill>"
            ):
                leading_skill_tag_end += len(line)
                continue
            break
        if leading_skill_tag_end > 0:
            return (
                content[:leading_skill_tag_end]
                + prefix
                + content[leading_skill_tag_end:]
            )
        return f"{prefix}{content}"

    async def _prepare_content_item_for_sage(
        self,
        item: Any,
        *,
        user_id: str | None = None,
    ) -> list[Any]:
        if not isinstance(item, dict):
            return [deepcopy(item)]
        item_type = str(item.get("type") or "").strip()
        if item_type == "input_audio":
            return []
        if item_type != "image_url":
            return [deepcopy(item)]
        return await self._prepare_image_url_content_item(item, user_id=user_id)

    async def _prepare_image_url_content_item(
        self,
        item: dict[str, Any],
        *,
        user_id: str | None = None,
    ) -> list[dict[str, Any]]:
        image_url_payload = (
            deepcopy(item.get("image_url"))
            if isinstance(item.get("image_url"), dict)
            else {}
        )
        url = str(image_url_payload.get("url") or "").strip()
        if not url:
            return [deepcopy(item)]

        try:
            guarded_url = await ensure_image_url_within_size_limit(url)
        except Exception as exc:
            logger.warning(f"[AgentService] 为 Sage 准备图片 URL 失败：{url} ({exc})")
            return [deepcopy(item)]

        image_url_payload["url"] = guarded_url
        next_item = deepcopy(item)
        next_item["image_url"] = image_url_payload
        items = [next_item]
        reference_note = await self._build_sage_workspace_image_reference(
            user_id=user_id,
            source_url=guarded_url,
        )
        if reference_note:
            items.append({"type": "text", "text": reference_note})
        return items

    async def _build_sage_workspace_image_reference(
        self,
        *,
        user_id: str | None,
        source_url: str,
    ) -> str | None:
        if not user_id:
            return None
        try:
            payload, content_type = (
                self._decode_image_data_url(source_url)
                if source_url.startswith("data:")
                else await self._read_image_payload(source_url)
            )
            content_type = self._resolve_image_content_type(content_type, source_url)
        except Exception as exc:
            logger.warning(
                "[AgentService] 读取 Sage workspace 图片引用失败："
                f"user_id={user_id} source={source_url} ({exc})"
            )
            return None
        return await self._upload_sage_workspace_image_reference(
            user_id=user_id,
            source_url=source_url,
            payload=payload,
            content_type=content_type,
        )

    async def _upload_sage_workspace_image_reference(
        self,
        *,
        user_id: str | None,
        source_url: str,
        payload: bytes,
        content_type: str,
    ) -> str | None:
        if not user_id:
            return None
        filename = self._workspace_image_filename(source_url, content_type)
        try:
            uploaded = await self.sage_client.upload_workspace_file(
                user_id=user_id,
                agent_id=self.cfg.sage_agent_id,
                filename=filename,
                content=payload,
                content_type=content_type,
                target_path="upload_files",
            )
        except Exception as exc:
            logger.warning(
                "[AgentService] 上传图片到 Sage workspace 失败："
                f"user_id={user_id} filename={filename} ({exc})"
            )
            return None

        path = str(uploaded.get("path") or "").strip() or f"upload_files/{filename}"
        path = path.replace("\\", "/").lstrip("/")
        file_url = f"file:///app/agents/{user_id}/{self.cfg.sage_agent_id}/{path}"
        return (
            "【Ling 附件引用】上面的图片已同时保存到当前用户的 "
            f"agent workspace，Markdown 图片引用：![{filename}]({file_url})。"
            "这两个内容是同一张图片；如果后续写入日程或想法的 Markdown，"
            "请优先保存这个文件引用，方便 Ling 前端在详情页展示和打开。"
        )

    def _workspace_image_filename(self, source_url: str, content_type: str) -> str:
        parsed_url = urlparse(source_url)
        parsed_name = "" if parsed_url.scheme == "data" else Path(parsed_url.path).name
        stem = Path(parsed_name).stem.strip() if parsed_name else ""
        suffix = {
            "image/jpeg": ".jpg",
            "image/png": ".png",
            "image/webp": ".webp",
            "image/heic": ".heic",
            "image/heif": ".heif",
        }.get(content_type.lower(), ".jpg")
        safe_stem = "".join(
            ch if ch.isascii() and (ch.isalnum() or ch in {"-", "_"}) else "_"
            for ch in (stem or "image")
        ).strip("_")
        if not safe_stem:
            safe_stem = "image"
        return f"{safe_stem}_{uuid.uuid4().hex[:10]}{suffix}"

    async def _read_image_payload(self, url: str) -> tuple[bytes, str | None]:
        parsed = urlparse(url)

        if parsed.scheme == "file":
            file_path = Path(parsed.path)
            payload = await asyncio.to_thread(file_path.read_bytes)
            return payload, self._resolve_image_content_type(None, file_path.as_posix())

        if parsed.scheme in {"http", "https"}:
            async with httpx.AsyncClient(timeout=20.0) as client:
                response = await client.get(url)
                response.raise_for_status()
                header_content_type = str(response.headers.get("content-type") or "").strip()
                return response.content, header_content_type.split(";", 1)[0] or None

        raise ValueError(f"Unsupported image URL: {url}")

    def _decode_image_data_url(self, url: str) -> tuple[bytes, str | None]:
        header, separator, encoded = url.partition(",")
        if not separator or ";base64" not in header.lower():
            raise ValueError("Unsupported image data URL")
        content_type = header.removeprefix("data:").split(";", 1)[0] or None
        return base64.b64decode(encoded, validate=True), content_type

    def _resolve_image_content_type(
        self,
        content_type: str | None,
        url: str,
    ) -> str:
        normalized = str(content_type or "").strip().lower()
        if normalized.startswith("image/"):
            return normalized
        suffix = Path(urlparse(url).path).suffix.lower()
        guessed = _IMAGE_SUFFIX_TO_CONTENT_TYPE.get(suffix) or mimetypes.guess_type(url)[0]
        return guessed or "image/jpeg"

    async def store_assistant_chunk(
        self,
        user_id: str,
        session_id: str,
        chunk: SageMessageChunk,
    ) -> list[dict[str, Any]]:
        message_type = (chunk.message_type or chunk.type or "").strip() or None
        if message_type == "stream_end":
            await self._touch_session(session_id, user_id)
            return await self._finalize_session_messages(user_id, session_id)

        message_id = self._resolve_chunk_message_id(chunk)
        existing = await self.message_dao.get_session_message(
            user_id,
            session_id,
            message_id,
        )
        tool_call_id = self._normalize_message_id(chunk.tool_call_id)
        next_message = self._merge_message_payload(
            existing.message if existing is not None else None,
            role=chunk.role or "assistant",
            message_type=message_type,
            content=chunk.content,
            tool_calls=chunk.tool_calls,
            tool_call_id=tool_call_id,
            metadata=chunk.metadata,
            error_info=chunk.error_info,
        )
        resolved_tool_call_id = self._resolve_stored_tool_call_id(
            role=chunk.role or "assistant",
            message_type=message_type,
            payload=next_message,
            explicit_tool_call_id=tool_call_id,
        )

        if existing is None:
            stored = AgentMessage(
                record_id=self._next_agent_message_record_id(),
                session_id=session_id,
                user_id=user_id,
                message_id=message_id,
                tool_call_id=resolved_tool_call_id,
                role=chunk.role or "assistant",
                message=next_message,
                message_type=message_type,
                is_final=chunk.is_final,
            )
            await self.message_dao.insert(stored)
        else:
            stored = existing
            stored.role = chunk.role or stored.role
            stored.message = next_message
            stored.tool_call_id = resolved_tool_call_id
            if message_type is not None:
                stored.message_type = message_type
            stored.is_final = stored.is_final or chunk.is_final
            await self.message_dao.save(stored)

        await self._touch_session(session_id, user_id)
        return await self.build_entry_updates_for_message(user_id, session_id, stored)

    def can_buffer_assistant_chunk(self, chunk: SageMessageChunk) -> bool:
        kind = (chunk.message_type or chunk.type or "").strip()
        if kind in {"stream_end", "tool_call", "tool_call_result", "error"}:
            return False
        if (chunk.role or "assistant") != "assistant":
            return False
        if chunk.tool_calls:
            return False
        if self._normalize_message_id(chunk.message_id) is None:
            return False
        return isinstance(chunk.content, str) or chunk.is_final

    def merge_transient_assistant_chunk(
        self,
        *,
        user_id: str,
        session_id: str,
        current: AgentMessage | None,
        chunk: SageMessageChunk,
    ) -> AgentMessage:
        message_type = (chunk.message_type or chunk.type or "").strip() or None
        message_id = self._resolve_chunk_message_id(chunk)
        next_message = self._merge_message_payload(
            current.message if current is not None else None,
            role=chunk.role or "assistant",
            message_type=message_type,
            content=chunk.content,
            tool_calls=chunk.tool_calls,
            tool_call_id=self._normalize_message_id(chunk.tool_call_id),
            metadata=chunk.metadata,
            error_info=chunk.error_info,
        )

        if current is None:
            return AgentMessage(
                record_id=f"transient_{message_id}",
                session_id=session_id,
                user_id=user_id,
                message_id=message_id,
                tool_call_id=self._resolve_stored_tool_call_id(
                    role=chunk.role or "assistant",
                    message_type=message_type,
                    payload=next_message,
                    explicit_tool_call_id=self._normalize_message_id(
                        chunk.tool_call_id,
                    ),
                ),
                role=chunk.role or "assistant",
                message=next_message,
                message_type=message_type,
                is_final=chunk.is_final,
            )

        current.role = chunk.role or current.role
        current.message = next_message
        current.tool_call_id = self._resolve_stored_tool_call_id(
            role=chunk.role or current.role,
            message_type=message_type or current.message_type,
            payload=next_message,
            explicit_tool_call_id=self._normalize_message_id(chunk.tool_call_id),
        )
        if message_type is not None:
            current.message_type = message_type
        current.is_final = current.is_final or chunk.is_final
        current.updated_at = get_local_now()
        return current

    def build_entry_updates_for_transient_message(
        self,
        message: AgentMessage,
    ) -> list[dict[str, Any]]:
        if message.role == "assistant":
            return [self._build_assistant_entry(message)]
        return []

    def build_chunk_from_transient_message(
        self,
        message: AgentMessage,
        *,
        content: Any = _TRANSIENT_CONTENT_UNSET,
        is_final: bool,
    ) -> SageMessageChunk:
        resolved_content = (
            (message.message or {}).get("content")
            if content is _TRANSIENT_CONTENT_UNSET
            else content
        )
        return SageMessageChunk(
            role=message.role,
            content=deepcopy(resolved_content),
            tool_calls=self._normalize_tool_calls(
                (message.message or {}).get("tool_calls"),
            ),
            message_id=message.message_id,
            message_type=message.message_type,
            is_final=is_final,
            metadata=deepcopy((message.message or {}).get("metadata")),
            error_info=deepcopy((message.message or {}).get("error_info")),
        )

    async def _finalize_session_messages(
        self,
        user_id: str,
        session_id: str,
    ) -> list[dict[str, Any]]:
        unfinished_messages = await self.message_dao.list_unfinished_session_messages(
            user_id,
            session_id,
        )
        if not unfinished_messages:
            return []

        updates: list[dict[str, Any]] = []
        for message in unfinished_messages:
            if message.is_final:
                continue
            message.is_final = True
            await self.message_dao.save(message)
            updates.extend(
                await self.build_entry_updates_for_message(
                    user_id,
                    session_id,
                    message,
                )
            )
        return updates

    async def build_entry_updates_for_message(
        self,
        user_id: str,
        session_id: str,
        message: AgentMessage,
    ) -> list[dict[str, Any]]:
        message_kind = (message.message_type or "").strip()
        if message.role == "assistant" and message_kind == "tool_call":
            tool_calls = self._normalize_tool_calls(message.message.get("tool_calls"))
            tool_results_by_id = (
                await self._list_tool_result_messages_by_id(user_id, session_id)
                if message.is_final
                else {}
            )
            return [
                self._build_tool_call_entry(
                    tool_call=tool_call,
                    result_message=tool_results_by_id.get(
                        self._normalize_message_id(tool_call.get("id"))
                    ),
                    source_message=message,
                )
                for tool_call in tool_calls
            ]
        if message.role == "tool" and message_kind == "tool_call_result":
            return [await self._build_tool_call_entry_from_result(user_id, session_id, message)]
        if message.role == "assistant":
            return [self._build_assistant_entry(message)]
        return []

    async def list_conversation_entries(
        self,
        user_id: str,
        session_id: str,
        *,
        keep_last_assistant_streaming: bool = False,
        message_limit: int | None = _DEFAULT_CONVERSATION_ENTRY_MESSAGE_LIMIT,
        before_created_at: str | None = None,
        before_record_id: str | None = None,
    ) -> dict[str, Any]:
        normalized_limit = self._normalize_conversation_entry_message_limit(message_limit)
        before_created_at_value = self._parse_conversation_entry_cursor_datetime(
            before_created_at,
        )
        before_record_id_value = self._normalize_message_id(before_record_id)
        has_more = False
        older_cursor: dict[str, str] | None = None
        if normalized_limit is None:
            messages = await self.message_dao.list_session_messages(user_id, session_id)
        else:
            messages_desc = await self.message_dao.list_session_messages_desc(
                user_id,
                session_id,
                limit=normalized_limit + 1,
                before_created_at=before_created_at_value,
                before_record_id=before_record_id_value,
            )
            has_more = len(messages_desc) > normalized_limit
            messages = list(reversed(messages_desc[:normalized_limit]))
            if messages:
                earliest = messages[0]
                older_cursor = {
                    "before_created_at": format_datetime(earliest.created_at) or "",
                    "before_record_id": earliest.record_id,
                }
        entries = self._assemble_conversation_entries(
            messages,
            keep_last_assistant_streaming=keep_last_assistant_streaming,
        )
        return {
            "items": entries,
            "has_more": has_more,
            "message_limit": normalized_limit,
            "older_cursor": older_cursor,
        }

    async def list_user_conversation_entries(
        self,
        user_id: str,
        *,
        message_limit: int | None = _DEFAULT_CONVERSATION_ENTRY_MESSAGE_LIMIT,
        before_created_at: str | None = None,
        before_record_id: str | None = None,
    ) -> dict[str, Any]:
        normalized_limit = self._normalize_conversation_entry_message_limit(message_limit)
        before_created_at_value = self._parse_conversation_entry_cursor_datetime(
            before_created_at,
        )
        before_record_id_value = self._normalize_message_id(before_record_id)
        has_more = False
        older_cursor: dict[str, str] | None = None
        if normalized_limit is None:
            messages = await self.message_dao.list_user_messages(user_id)
        else:
            messages_desc = await self.message_dao.list_user_messages_desc(
                user_id,
                limit=normalized_limit + 1,
                before_created_at=before_created_at_value,
                before_record_id=before_record_id_value,
            )
            has_more = len(messages_desc) > normalized_limit
            messages = list(reversed(messages_desc[:normalized_limit]))
            if messages:
                earliest = messages[0]
                older_cursor = {
                    "before_created_at": format_datetime(earliest.created_at) or "",
                    "before_record_id": earliest.record_id,
                }
        entries = self._assemble_conversation_entries(
            messages,
            keep_last_assistant_streaming=False,
        )
        return {
            "items": entries,
            "has_more": has_more,
            "message_limit": normalized_limit,
            "older_cursor": older_cursor,
        }

    def _normalize_conversation_entry_message_limit(
        self,
        message_limit: int | None,
    ) -> int | None:
        if message_limit is None or message_limit <= 0:
            return None
        return min(max(1, int(message_limit)), _MAX_CONVERSATION_ENTRY_MESSAGE_LIMIT)

    def _parse_conversation_entry_cursor_datetime(
        self,
        value: str | None,
    ) -> datetime | None:
        normalized = (value or "").strip()
        if not normalized:
            return None
        try:
            parsed = datetime.fromisoformat(normalized.replace("Z", "+00:00"))
        except ValueError as exc:
            raise AppHTTPException(
                status_code=422,
                detail="Invalid conversation cursor",
            ) from exc
        return parsed.astimezone(UTC).replace(tzinfo=None) if parsed.tzinfo else parsed

    def _assemble_conversation_entries(
        self,
        messages: list[AgentMessage],
        *,
        keep_last_assistant_streaming: bool,
    ) -> list[dict[str, Any]]:
        entries: list[dict[str, Any]] = []
        tool_results_by_id = {
            (message.session_id, tool_call_id): message
            for message in messages
            if message.role == "tool"
            and (message.message_type or "").strip() == "tool_call_result"
            and (tool_call_id := self._tool_call_id_from_message(message)) is not None
        }
        requested_tool_result_ids: set[tuple[str, str]] = set()
        for message in messages:
            if message.role != "assistant":
                continue
            if (message.message_type or "").strip() != "tool_call":
                continue
            for tool_call in self._normalize_tool_calls(
                message.message.get("tool_calls")
            ):
                tool_call_id = self._normalize_message_id(tool_call.get("id"))
                if tool_call_id is not None:
                    requested_tool_result_ids.add(
                        (message.session_id, tool_call_id)
                    )
        last_assistant_index: int | None = None

        for message in messages:
            message_kind = (message.message_type or "").strip()
            if message.role == "user" and message_kind == "user_input":
                entries.append(self._build_user_entry(message))
                continue

            if message.role == "assistant" and message_kind == "tool_call":
                for tool_call in self._normalize_tool_calls(message.message.get("tool_calls")):
                    tool_call_id = self._normalize_message_id(tool_call.get("id"))
                    result_message = (
                        tool_results_by_id.get((message.session_id, tool_call_id))
                        if tool_call_id is not None
                        else None
                    )
                    entries.append(
                        self._build_tool_call_entry(
                            tool_call=tool_call,
                            result_message=result_message,
                            source_message=message,
                        )
                    )
                continue

            if message.role == "assistant":
                entry = self._build_assistant_entry(message)
                last_assistant_index = len(entries)
                entries.append(entry)
                continue

            if (
                message.role == "tool"
                and message_kind == "tool_call_result"
                and (tool_call_id := self._tool_call_id_from_message(message)) is not None
                and (message.session_id, tool_call_id) not in requested_tool_result_ids
            ):
                entries.append(
                    self._build_tool_call_entry(
                        tool_call=None,
                        result_message=message,
                    )
                )

        if keep_last_assistant_streaming and last_assistant_index is not None:
            entry = entries[last_assistant_index]
            if (
                entry.get("entry_type") == "assistant_message"
                and entry.get("message_type") != "error"
                and entry.get("is_streaming") is False
            ):
                source_message = next(
                    (
                        item
                        for item in reversed(messages)
                        if item.role == "assistant"
                        and (item.message_type or "").strip() != "tool_call"
                    ),
                    None,
                )
                if source_message is not None and not source_message.is_final:
                    entry["is_streaming"] = True

        return entries

    def _build_user_entry(self, message: AgentMessage) -> dict[str, Any]:
        content = message.message.get("content")
        text_parts: list[str] = []
        attachments: list[dict[str, Any]] = []

        if isinstance(content, str):
            text_parts.append(content)
        elif isinstance(content, list):
            for item in content:
                if not isinstance(item, dict):
                    continue
                item_type = str(item.get("type") or "").strip()
                if item_type == "text":
                    text_value = item.get("text")
                    if isinstance(text_value, str) and text_value.strip():
                        text_parts.append(text_value)
                    continue
                if item_type in {"image_url", "input_audio"}:
                    attachments.append(self._attachment_from_message_content(item))

        return {
            "id": message.message_id or message.record_id,
            "session_id": message.session_id,
            "entry_type": "user_message",
            "role": "user",
            "created_at": format_datetime(message.created_at),
            "message_id": message.message_id,
            "message_type": message.message_type,
            "text": "\n".join(part for part in text_parts if part).strip(),
            "attachments": attachments,
            "is_streaming": False,
            "tool_call_id": None,
            "tool_name": None,
            "tool_arguments": None,
            "tool_result": None,
            "metadata": deepcopy((message.message or {}).get("metadata") or {}),
            "status": constants.AGENT_EXECUTION_STATUS_COMPLETED,
        }

    def _build_assistant_entry(self, message: AgentMessage) -> dict[str, Any]:
        text = self._content_to_text(message.message.get("content"))
        if not text.strip() and (message.message_type or "").strip() == "error":
            text = "Sage returned an error."
        entry = {
            "id": message.message_id or message.record_id,
            "session_id": message.session_id,
            "entry_type": "assistant_message",
            "role": "assistant",
            "created_at": format_datetime(message.created_at),
            "message_id": message.message_id,
            "message_type": message.message_type,
            "text": text,
            "attachments": [],
            "is_streaming": not message.is_final and (message.message_type or "").strip() != "error",
            "tool_call_id": None,
            "tool_name": None,
            "tool_arguments": None,
            "tool_result": None,
            "status": constants.AGENT_EXECUTION_STATUS_COMPLETED,
        }
        return entry

    async def _build_tool_call_entry_from_result(
        self,
        user_id: str,
        session_id: str,
        message: AgentMessage,
    ) -> dict[str, Any]:
        tool_call, source_message = await self._find_tool_call_request(
            user_id,
            session_id,
            self._tool_call_id_from_message(message),
        )
        return self._build_tool_call_entry(
            tool_call=tool_call,
            result_message=message,
            source_message=source_message,
        )

    async def _find_tool_call_request(
        self,
        user_id: str,
        session_id: str,
        tool_call_id: str | None,
    ) -> tuple[dict[str, Any] | None, AgentMessage | None]:
        if tool_call_id is None:
            return None, None
        messages = await self.message_dao.list_session_tool_call_messages(
            user_id,
            session_id,
            tool_call_id=tool_call_id,
        )
        found = self._find_tool_call_in_messages(messages, tool_call_id)
        if found[0] is not None:
            return found
        messages = await self.message_dao.list_session_tool_call_messages(
            user_id,
            session_id,
        )
        return self._find_tool_call_in_messages(messages, tool_call_id)

    def _find_tool_call_in_messages(
        self,
        messages: list[AgentMessage],
        tool_call_id: str,
    ) -> tuple[dict[str, Any] | None, AgentMessage | None]:
        for message in messages:
            for tool_call in self._normalize_tool_calls(message.message.get("tool_calls")):
                if self._normalize_message_id(tool_call.get("id")) == tool_call_id:
                    return tool_call, message
        return None, None

    async def _list_tool_result_messages_by_id(
        self,
        user_id: str,
        session_id: str,
    ) -> dict[str, AgentMessage]:
        messages = await self.message_dao.list_session_tool_result_messages(
            user_id,
            session_id,
        )
        return {
            tool_call_id: message
            for message in messages
            if (tool_call_id := self._tool_call_id_from_message(message)) is not None
        }

    def _build_tool_call_entry(
        self,
        *,
        tool_call: dict[str, Any] | None,
        result_message: AgentMessage | None = None,
        source_message: AgentMessage | None = None,
    ) -> dict[str, Any]:
        function_payload = (
            tool_call.get("function")
            if isinstance(tool_call, dict) and isinstance(tool_call.get("function"), dict)
            else {}
        )
        tool_call_id = self._normalize_message_id(
            tool_call.get("id") if isinstance(tool_call, dict) else None,
        )
        if tool_call_id is None and result_message is not None:
            tool_call_id = self._tool_call_id_from_message(result_message)
        arguments_value = function_payload.get("arguments")
        tool_arguments = self._stringify_value(arguments_value)
        result_content = (
            result_message.message.get("content")
            if result_message is not None
            else None
        )
        tool_result = (
            self._content_to_text(result_content)
            if result_content is not None
            else None
        )
        tool_name = resolve_tool_call_result_function_name(
            self._normalize_string(tool_result),
        ) or resolve_tool_call_function_name(tool_call)
        is_completed = result_message is not None
        source_created_at = (
            source_message.created_at if source_message is not None else None
        )
        result_created_at = (
            result_message.created_at if result_message is not None else None
        )
        duration_ms = (
            max(
                0,
                int((result_created_at - source_created_at).total_seconds() * 1000),
            )
            if source_created_at is not None and result_created_at is not None
            else None
        )
        entry_id = (
            f"tool_call:{tool_call_id}"
            if tool_call_id is not None
            else f"tool_call:{result_message.message_id or uuid.uuid4().hex}"
        )

        return {
            "id": entry_id,
            "session_id": (
                getattr(result_message, "session_id", None)
                if result_message is not None
                else getattr(source_message, "session_id", None)
                if source_message is not None
                else None
            ),
            "entry_type": "tool_call",
            "role": "assistant",
            "created_at": format_datetime(source_created_at or result_created_at),
            "message_id": result_message.message_id if result_message is not None else None,
            "message_type": "tool_call",
            "text": "",
            "attachments": [],
            "is_streaming": not is_completed,
            "tool_call_id": tool_call_id,
            "tool_name": tool_name,
            "tool_arguments": tool_arguments,
            "tool_result": tool_result,
            "duration_ms": duration_ms,
            "status": (
                constants.AGENT_EXECUTION_STATUS_COMPLETED
                if is_completed
                else constants.AGENT_EXECUTION_STATUS_RUNNING
            ),
        }

    async def _touch_session(self, session_id: str, user_id: str) -> None:
        now = get_local_now()
        await self.session_dao.update_where(
            AgentSession,
            where=[
                AgentSession.user_id == user_id,
                AgentSession.session_id == session_id,
            ],
            values={
                "last_message_at": now,
                "updated_at": now,
            },
        )

    def _merge_message_payload(
        self,
        current: dict[str, Any] | None,
        *,
        role: str,
        message_type: str | None,
        content: Any,
        tool_calls: list[dict[str, Any]] | None,
        tool_call_id: str | None,
        metadata: dict[str, Any] | None,
        error_info: dict[str, Any] | None,
    ) -> dict[str, Any]:
        payload = dict(current or {})
        kind = (message_type or "").strip()
        if role == "assistant" and kind == "tool_call":
            return {
                "tool_calls": self._minimize_tool_calls_for_storage(
                    self._merge_tool_calls(
                        payload.get("tool_calls"),
                        tool_calls,
                    ),
                )
            }
        if role == "tool" and kind == "tool_call_result":
            merged_content = self._merge_content(payload.get("content"), content)
            resolved_tool_call_id = (
                self._normalize_message_id(tool_call_id)
                or self._normalize_message_id(payload.get("tool_call_id"))
            )
            next_payload: dict[str, Any] = {}
            if merged_content is not None:
                next_payload["content"] = deepcopy(merged_content)
            if resolved_tool_call_id is not None:
                next_payload["tool_call_id"] = resolved_tool_call_id
            return next_payload

        payload["content"] = self._merge_content(payload.get("content"), content)
        payload["tool_calls"] = self._merge_tool_calls(
            payload.get("tool_calls"),
            tool_calls,
        )
        if metadata:
            payload["metadata"] = {
                **dict(payload.get("metadata") or {}),
                **deepcopy(metadata),
            }
        if error_info:
            payload["error_info"] = {
                **dict(payload.get("error_info") or {}),
                **deepcopy(error_info),
            }
        return payload

    def _merge_content(self, current: Any, incoming: Any) -> Any:
        if incoming is None:
            return deepcopy(current)
        if current is None:
            return deepcopy(incoming)
        if isinstance(current, str) and isinstance(incoming, str):
            return f"{current}{incoming}"
        if isinstance(current, list) and isinstance(incoming, list):
            return [*deepcopy(current), *deepcopy(incoming)]
        if isinstance(current, dict) and isinstance(incoming, dict):
            merged = deepcopy(current)
            merged.update(deepcopy(incoming))
            return merged
        return deepcopy(incoming)

    def _merge_tool_calls(self, current: Any, incoming: Any) -> list[dict[str, Any]]:
        merged: list[dict[str, Any]] = []
        order: list[str] = []
        for source in (self._normalize_tool_calls(current), self._normalize_tool_calls(incoming)):
            for tool_call in source:
                tool_call_id = self._tool_call_identity(tool_call)
                if tool_call_id not in order:
                    order.append(tool_call_id)
                    merged.append(tool_call)
                    continue
                index = order.index(tool_call_id)
                merged[index] = self._merge_tool_call(merged[index], tool_call)
        return merged

    def _merge_tool_call(
        self,
        current: dict[str, Any],
        incoming: dict[str, Any],
    ) -> dict[str, Any]:
        merged = dict(current)
        for key, value in incoming.items():
            if key == "function" and isinstance(value, dict) and isinstance(merged.get(key), dict):
                nested = dict(merged[key])
                for nested_key, nested_value in value.items():
                    if nested_key == "arguments":
                        nested[nested_key] = self._merge_content(
                            nested.get(nested_key),
                            nested_value,
                        )
                        continue
                    nested[nested_key] = deepcopy(nested_value)
                merged[key] = nested
                continue
            merged[key] = deepcopy(value)
        return merged

    def _normalize_tool_calls(self, value: Any) -> list[dict[str, Any]]:
        if not isinstance(value, list):
            return []
        items: list[dict[str, Any]] = []
        for item in value:
            if isinstance(item, dict):
                items.append(deepcopy(item))
        return items

    def _tool_call_identity(self, tool_call: dict[str, Any]) -> str:
        tool_call_id = self._normalize_message_id(tool_call.get("id"))
        if tool_call_id is not None:
            return tool_call_id
        function_payload = tool_call.get("function")
        return json.dumps(function_payload or tool_call, ensure_ascii=False, sort_keys=True)

    def _minimize_tool_calls_for_storage(self, value: Any) -> list[dict[str, Any]]:
        minimized: list[dict[str, Any]] = []
        for tool_call in self._normalize_tool_calls(value):
            tool_call_id = self._normalize_message_id(tool_call.get("id"))
            if tool_call_id is None:
                continue
            minimized_tool_call: dict[str, Any] = {"id": tool_call_id}
            tool_name = resolve_tool_call_function_name(tool_call)
            if tool_name is not None:
                minimized_tool_call["function"] = {"name": tool_name}
            function_payload = (
                tool_call.get("function")
                if isinstance(tool_call.get("function"), dict)
                else {}
            )
            if "arguments" in function_payload:
                function_entry = (
                    minimized_tool_call.get("function")
                    if isinstance(minimized_tool_call.get("function"), dict)
                    else {}
                )
                function_entry["arguments"] = deepcopy(function_payload.get("arguments"))
                minimized_tool_call["function"] = function_entry
            minimized.append(minimized_tool_call)
        return minimized

    def _tool_call_id_from_message(self, message: AgentMessage) -> str | None:
        return self._normalize_message_id(
            getattr(message, "tool_call_id", None),
        ) or self._tool_call_id_from_payload(message.message)

    def _tool_call_id_from_payload(self, payload: Any) -> str | None:
        if not isinstance(payload, dict):
            return None
        return self._normalize_message_id(payload.get("tool_call_id"))

    def _resolve_stored_tool_call_id(
        self,
        *,
        role: str,
        message_type: str | None,
        payload: dict[str, Any],
        explicit_tool_call_id: str | None,
    ) -> str | None:
        if explicit_tool_call_id is not None:
            return explicit_tool_call_id
        if role == "tool" or (message_type or "").strip() == "tool_call_result":
            return self._tool_call_id_from_payload(payload)
        if role == "assistant" and (message_type or "").strip() == "tool_call":
            for tool_call in self._normalize_tool_calls(payload.get("tool_calls")):
                tool_call_id = self._normalize_message_id(tool_call.get("id"))
                if tool_call_id is not None:
                    return tool_call_id
        return None

    def _resolve_chunk_message_id(self, chunk: SageMessageChunk) -> str:
        return (
            self._normalize_message_id(chunk.message_id)
            or self._normalize_message_id(chunk.tool_call_id)
            or self._normalize_message_id(chunk.chunk_id)
            or f"msg_{uuid.uuid4().hex}"
        )

    def _next_agent_message_record_id(self) -> str:
        value = generate_uuid7()
        return f"amsg_{getattr(value, 'hex', value)}"

    def _normalize_message_id(self, value: Any) -> str | None:
        normalized = str(value or "").strip()
        return normalized or None

    def _attachment_from_message_content(self, item: dict[str, Any]) -> dict[str, Any]:
        item_type = str(item.get("type") or "").strip()
        url_value = item.get("input_audio") if item_type == "input_audio" else item.get("image_url")
        url = (
            str(url_value.get("url") or "").strip()
            if isinstance(url_value, dict)
            else ""
        )
        fallback_filename = "voice" if item_type == "input_audio" else "image"
        filename = (
            str(url_value.get("filename") or "").strip()
            if isinstance(url_value, dict)
            else ""
        ) or os.path.basename(urlparse(url).path) or fallback_filename
        return {
            "attachment_id": "",
            "filename": filename,
            "url": url,
            "message_content": deepcopy(item),
        }

    def _content_to_text(self, value: Any) -> str:
        if value is None:
            return ""
        if isinstance(value, str):
            return value
        if isinstance(value, list):
            text_parts = [
                str(item.get("text") or "").strip()
                for item in value
                if isinstance(item, dict) and str(item.get("type") or "").strip() == "text"
            ]
            resolved = "\n".join(part for part in text_parts if part).strip()
            if resolved:
                return resolved
            return self._stringify_value(value)
        if isinstance(value, dict):
            if str(value.get("type") or "").strip() == "text":
                return str(value.get("text") or "")
            return self._stringify_value(value)
        return str(value)

    def _stringify_value(self, value: Any) -> str | None:
        if value is None:
            return None
        if isinstance(value, str):
            return value
        return json.dumps(value, ensure_ascii=False, indent=2)

    def _normalize_string(self, value: Any) -> str | None:
        if value is None:
            return None
        normalized = str(value).strip()
        return normalized or None

    def serialize_session(self, session: AgentSession) -> dict[str, Any]:
        return {
            "session_id": session.session_id,
            "user_id": session.user_id,
            "agent_id": session.agent_id,
            "entry_mode": session.entry_mode,
            "selected_date": session.selected_date,
            "timezone": session.timezone,
            "title": session.title,
            "metadata": session.extra_data,
            "last_message_at": None
            if session.last_message_at is None
            else format_datetime(session.last_message_at),
            "created_at": format_datetime(session.created_at),
            "updated_at": format_datetime(session.updated_at),
        }

    def serialize_message(self, message: AgentMessage) -> dict[str, Any]:
        return {
            "record_id": message.record_id,
            "session_id": message.session_id,
            "message_id": message.message_id,
            "tool_call_id": message.tool_call_id,
            "role": message.role,
            "message": deepcopy(message.message),
            "message_type": message.message_type,
            "is_final": message.is_final,
            "created_at": format_datetime(message.created_at),
            "updated_at": format_datetime(message.updated_at),
        }
