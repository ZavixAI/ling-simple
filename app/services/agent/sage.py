"""
Sage API 客户端

负责与 Sage 平台进行通信，发送消息并处理流式响应。
"""

import asyncio
import json
import traceback
from copy import deepcopy
from dataclasses import dataclass
from email.message import Message
from typing import Any, AsyncGenerator, Dict, List, Optional
from urllib.parse import urljoin

from config.settings import get_app_config
from loguru import logger
from models.agent import AgentTokenUsage, AgentTokenUsageDao


@dataclass
class SageMessageChunk:
    """
    Sage 消息片段 - OpenAI兼容格式

    定义Agent流式返回的单个消息块的结构，确保所有必要字段都存在。
    支持OpenAI消息格式和工具调用。
    """

    # 必需字段 - OpenAI标准
    role: str = "assistant"  # 消息角色 (user, assistant, system, tool)

    # 内容字段（content 和 tool_calls 至少有一个）
    content: Optional[Any] = None  # 支持文本或多模态内容
    tool_calls: Optional[List[Dict[str, Any]]] = None  # 工具调用列表（OpenAI格式）

    # 消息标识
    message_id: Optional[str] = None  # 消息唯一标识符

    # 工具调用ID（tool角色消息必需）
    tool_call_id: Optional[str] = None  # 工具调用ID（tool角色消息必需）

    # 显示和类型字段
    type: Optional[str] = None  # 消息类型（兼容现有系统）
    message_type: Optional[str] = None  # 消息类型（备用字段）

    # 时间戳
    timestamp: Optional[float] = None  # 时间戳

    # 元数据字段
    agent_name: Optional[str] = None  # 生成消息的Agent名称
    agent_type: Optional[str] = None  # Agent类型
    chunk_id: Optional[str] = None  # 消息块ID（用于流式传输）
    is_final: bool = False  # 是否为最终消息块
    is_chunk: bool = False  # 是否为消息块

    # 扩展字段
    metadata: Optional[Dict[str, Any]] = None  # 额外的元数据
    error_info: Optional[Dict[str, Any]] = None  # 错误信息
    session_id: Optional[str] = None  # 会话ID

    # 其他兼容字段
    updated_at: Optional[str] = None  # 更新时间

    def __post_init__(self):
        """初始化后处理"""
        # 确保 type 和 message_type 一致
        if self.type and not self.message_type:
            self.message_type = self.type
        elif self.message_type and not self.type:
            self.type = self.message_type

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'SageMessageChunk':
        """从字典创建消息片段"""
        # 处理字段映射
        kwargs = {
            "role": data.get("role", "assistant"),
            "content": data.get("content"),
            "tool_calls": data.get("tool_calls"),
            "message_id": data.get("message_id"),
            "tool_call_id": data.get("tool_call_id"),
            "type": data.get("type") or data.get("message_type"),
            "message_type": data.get("message_type") or data.get("type"),
            "timestamp": data.get("timestamp"),
            "agent_name": data.get("agent_name"),
            "agent_type": data.get("agent_type"),
            "chunk_id": data.get("chunk_id"),
            "is_final": data.get("is_final", False),
            "is_chunk": data.get("is_chunk", False),
            "metadata": data.get("metadata"),
            "error_info": data.get("error_info"),
            "session_id": data.get("session_id"),
            "updated_at": data.get("updated_at"),
        }
        return cls(**kwargs)

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        result = {}
        for key, value in self.__dict__.items():
            if value is not None:
                result[key] = value
        return result


@dataclass(frozen=True)
class SageWorkspaceFileDownload:
    content: bytes
    content_type: str | None
    filename: str | None


def _filename_from_content_disposition(value: str | None) -> str | None:
    if not value:
        return None
    message = Message()
    message["content-disposition"] = value
    filename = message.get_filename()
    return filename.strip() if filename else None


class SageClient:
    """
    Sage API 客户端
    负责与 Sage 平台 API 进行通信
    """

    IGNORED_EVENT_TYPES = frozenset({"token_usage"})
    _STREAM_TIMEOUT_SECONDS = 90.0
    _STREAM_READ_TIMEOUT_SECONDS: float | None = None
    _MAX_CONCURRENCY = 8
    _STREAM_SEMAPHORE: asyncio.Semaphore | None = None
    _MAX_PENDING_STREAM_JSON_BYTES = 1024 * 1024

    def __init__(self, api_url: Optional[str] = None):
        """
        初始化 Sage 客户端

        Args:
            api_url: Sage API 的基础 URL。如果未提供，使用默认地址。
        """
        cfg = get_app_config()
        self.api_url = api_url or cfg.sage_api_url

    @classmethod
    def _get_stream_semaphore(cls) -> asyncio.Semaphore:
        if cls._STREAM_SEMAPHORE is None:
            cls._STREAM_SEMAPHORE = asyncio.Semaphore(cls._MAX_CONCURRENCY)
        return cls._STREAM_SEMAPHORE

    @classmethod
    def should_ignore_event(cls, data: Dict[str, Any]) -> bool:
        """过滤不需要透传到上层的内部事件。"""
        event_type = (data.get("type") or data.get("message_type") or "").strip()
        return event_type in cls.IGNORED_EVENT_TYPES

    @staticmethod
    def _looks_like_json_payload(line: str) -> bool:
        return line.startswith("{") or line.startswith("[")

    @classmethod
    def _decode_stream_json(cls, payload: str) -> Any | None:
        try:
            return json.loads(payload)
        except json.JSONDecodeError:
            repaired_payload = cls._escape_raw_control_chars_in_json_strings(payload)
            if repaired_payload == payload:
                return None
            try:
                return json.loads(repaired_payload)
            except json.JSONDecodeError:
                return None

    @staticmethod
    def _escape_raw_control_chars_in_json_strings(payload: str) -> str:
        """Repair JSON emitted with raw line breaks inside string values."""
        result: list[str] = []
        in_string = False
        escaped = False
        changed = False
        for char in payload:
            if not in_string:
                result.append(char)
                if char == '"':
                    in_string = True
                continue

            if escaped:
                result.append(char)
                escaped = False
                continue
            if char == "\\":
                result.append(char)
                escaped = True
                continue
            if char == '"':
                result.append(char)
                in_string = False
                continue
            if char == "\n":
                result.append("\\n")
                changed = True
                continue
            if char == "\r":
                result.append("\\r")
                changed = True
                continue
            if char == "\t":
                result.append("\\t")
                changed = True
                continue
            if ord(char) < 0x20:
                result.append(f"\\u{ord(char):04x}")
                changed = True
                continue
            result.append(char)
        return "".join(result) if changed else payload

    @staticmethod
    def _stream_event_type(data: Dict[str, Any]) -> str:
        return str(data.get("type") or data.get("message_type") or "").strip()

    @classmethod
    def _is_tool_call_stream_event(cls, data: Dict[str, Any]) -> bool:
        return (
            cls._stream_event_type(data) == "tool_call"
            and isinstance(data.get("tool_calls"), list)
            and bool(data.get("tool_calls"))
        )

    @classmethod
    def _tool_call_stream_event_has_function_name(cls, data: Dict[str, Any]) -> bool:
        tool_calls = data.get("tool_calls")
        if not isinstance(tool_calls, list):
            return False
        for tool_call in tool_calls:
            if not isinstance(tool_call, dict):
                continue
            function_payload = tool_call.get("function")
            if not isinstance(function_payload, dict):
                continue
            if cls._non_empty_string(function_payload.get("name")) is not None:
                return True
        return False

    @staticmethod
    def _non_empty_string(value: Any) -> str | None:
        if value is None:
            return None
        text = str(value).strip()
        return text or None

    @classmethod
    def _same_tool_call_stream_message(
        cls,
        current: Dict[str, Any],
        incoming: Dict[str, Any],
    ) -> bool:
        current_message_id = cls._non_empty_string(current.get("message_id"))
        incoming_message_id = cls._non_empty_string(incoming.get("message_id"))
        if current_message_id and incoming_message_id:
            return current_message_id == incoming_message_id
        if current_message_id or incoming_message_id:
            return False
        return True

    @classmethod
    def _merge_tool_call_stream_event(
        cls,
        current: Dict[str, Any] | None,
        incoming: Dict[str, Any],
    ) -> Dict[str, Any]:
        if current is None:
            return deepcopy(incoming)

        merged = deepcopy(current)
        for key, value in incoming.items():
            if key == "tool_calls":
                continue
            if key == "metadata" and isinstance(value, dict):
                merged[key] = {
                    **dict(merged.get(key) or {}),
                    **deepcopy(value),
                }
                continue
            if key == "is_final":
                merged[key] = bool(merged.get(key)) or bool(value)
                continue
            if key in {"timestamp", "chunk_id", "updated_at"}:
                if value is not None:
                    merged[key] = deepcopy(value)
                continue
            if cls._non_empty_string(value) is not None or key not in merged:
                merged[key] = deepcopy(value)

        merged["tool_calls"] = cls._merge_tool_call_stream_items(
            merged.get("tool_calls"),
            incoming.get("tool_calls"),
        )
        return merged

    @classmethod
    def _merge_tool_call_stream_items(
        cls,
        current: Any,
        incoming: Any,
    ) -> list[dict[str, Any]]:
        merged = [
            deepcopy(item)
            for item in current
            if isinstance(item, dict)
        ] if isinstance(current, list) else []
        incoming_items = [
            item
            for item in incoming
            if isinstance(item, dict)
        ] if isinstance(incoming, list) else []

        keys = [
            cls._tool_call_stream_key(item, position)
            for position, item in enumerate(merged)
        ]
        for position, item in enumerate(incoming_items):
            key = cls._tool_call_stream_key(item, position)
            if (
                key not in keys
                and cls._is_unidentified_single_tool_delta(
                    item,
                    incoming_items,
                    merged,
                )
            ):
                key = keys[0]
            if key not in keys:
                keys.append(key)
                merged.append(deepcopy(item))
                continue
            index = keys.index(key)
            merged[index] = cls._merge_tool_call_stream_item(merged[index], item)
        return merged

    @classmethod
    def _tool_call_stream_key(cls, tool_call: dict[str, Any], position: int) -> str:
        index = tool_call.get("index")
        if not isinstance(index, bool) and index is not None:
            index_text = cls._non_empty_string(index)
            if index_text is not None:
                return f"index:{index_text}"
        tool_call_id = cls._non_empty_string(tool_call.get("id"))
        if tool_call_id is not None:
            return f"id:{tool_call_id}"
        return f"position:{position}"

    @classmethod
    def _is_unidentified_single_tool_delta(
        cls,
        tool_call: dict[str, Any],
        incoming_items: list[dict[str, Any]],
        merged_items: list[dict[str, Any]],
    ) -> bool:
        return (
            len(incoming_items) == 1
            and len(merged_items) == 1
            and cls._non_empty_string(tool_call.get("id")) is None
            and tool_call.get("index") is None
        )

    @classmethod
    def _merge_tool_call_stream_item(
        cls,
        current: dict[str, Any],
        incoming: dict[str, Any],
    ) -> dict[str, Any]:
        merged = deepcopy(current)
        for key, value in incoming.items():
            if key == "function" and isinstance(value, dict):
                current_function = (
                    merged.get("function")
                    if isinstance(merged.get("function"), dict)
                    else {}
                )
                merged["function"] = cls._merge_tool_call_stream_function(
                    current_function,
                    value,
                )
                continue
            if cls._non_empty_string(value) is None and key in merged:
                continue
            merged[key] = deepcopy(value)
        return merged

    @classmethod
    def _merge_tool_call_stream_function(
        cls,
        current: dict[str, Any],
        incoming: dict[str, Any],
    ) -> dict[str, Any]:
        merged = deepcopy(current)
        for key, value in incoming.items():
            if key == "arguments":
                existing = merged.get("arguments")
                if isinstance(existing, str) and isinstance(value, str):
                    merged[key] = f"{existing}{value}"
                elif value is not None:
                    merged[key] = deepcopy(value)
                continue
            if cls._non_empty_string(value) is None and key in merged:
                continue
            merged[key] = deepcopy(value)
        return merged

    async def _chunk_from_stream_event(
        self,
        *,
        data: Dict[str, Any],
        session_id: str,
        user_id: Optional[str],
    ) -> SageMessageChunk | None:
        event_type = data.get("type") or data.get("message_type")
        if event_type == "token_usage":
            await self._record_token_usage_event(
                session_id=session_id,
                user_id=user_id,
                data=data,
            )
            return None
        if self.should_ignore_event(data):
            return None

        if event_type == "stream_end":
            return SageMessageChunk(
                role="assistant",
                type="stream_end",
                message_type="stream_end",
                is_final=True,
                metadata=data if isinstance(data, dict) else None,
                session_id=session_id,
            )

        return SageMessageChunk.from_dict(data)

    @staticmethod
    def _int_token(value: Any) -> int:
        if isinstance(value, bool):
            return 0
        if isinstance(value, (int, float)):
            return int(value)
        return 0

    async def _record_token_usage_event(
        self,
        *,
        session_id: str,
        user_id: Optional[str],
        data: Dict[str, Any],
    ) -> None:
        metadata = data.get("metadata") if isinstance(data.get("metadata"), dict) else {}
        token_usage = (
            metadata.get("token_usage")
            if isinstance(metadata.get("token_usage"), dict)
            else {}
        )
        total_info = (
            token_usage.get("total_info")
            if isinstance(token_usage.get("total_info"), dict)
            else {}
        )
        raw_models = (
            token_usage.get("models")
            or total_info.get("models")
            or metadata.get("models")
        )
        models = (
            [str(item) for item in raw_models]
            if isinstance(raw_models, list)
            else []
        )
        model = total_info.get("model") or metadata.get("model")
        usage = AgentTokenUsage(
            session_id=session_id,
            user_id=str(user_id or session_id),
            input_tokens=self._int_token(total_info.get("prompt_tokens")),
            output_tokens=self._int_token(total_info.get("completion_tokens")),
            total_tokens=self._int_token(total_info.get("total_tokens")),
            cached_tokens=self._int_token(total_info.get("cached_tokens")),
            reasoning_tokens=self._int_token(total_info.get("reasoning_tokens")),
            model=str(model) if model else None,
            models=models,
            raw_usage=token_usage,
        )
        await AgentTokenUsageDao().upsert(usage)
        logger.info(
            "[SageClient] 已记录 token_usage session_id={} total={} input={} output={}",
            session_id,
            usage.total_tokens,
            usage.input_tokens,
            usage.output_tokens,
        )


    async def interrupt_session(
        self,
        session_id: str,
        user_id: Optional[str] = None,
    ) -> None:
        """Interrupt an active Sage session."""
        import httpx

        async with httpx.AsyncClient(timeout=15.0) as client:
            await self._interrupt_session(client, session_id, user_id)

    async def _interrupt_session(
        self,
        client: Any,
        session_id: str,
        user_id: Optional[str] = None,
    ) -> None:
        headers = {"X-Sage-Internal-UserId": user_id} if user_id else {}
        interrupt_url = urljoin(self.api_url, f"/api/sessions/{session_id}/interrupt")
        logger.info(f"[SageClient] 正在中断会话 session_id={session_id}")
        response = await client.post(interrupt_url, headers=headers, timeout=5.0)
        if response.status_code >= 400:
            raise RuntimeError(
                f"Sage interrupt failed ({response.status_code}): {response.text}"
            )

    async def inject_user_message(
        self,
        *,
        session_id: str,
        content: Any,
        guidance_id: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None,
        user_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        return await self._pending_user_injection_request(
            "POST",
            session_id=session_id,
            user_id=user_id,
            json_payload={
                "content": content,
                "guidance_id": guidance_id,
                "metadata": metadata,
            },
        )

    async def list_pending_user_injections(
        self,
        *,
        session_id: str,
        user_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        return await self._pending_user_injection_request(
            "GET",
            session_id=session_id,
            user_id=user_id,
        )

    async def update_pending_user_injection(
        self,
        *,
        session_id: str,
        guidance_id: str,
        content: Any,
        user_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        return await self._pending_user_injection_request(
            "PATCH",
            session_id=session_id,
            guidance_id=guidance_id,
            user_id=user_id,
            json_payload={"content": content},
        )

    async def delete_pending_user_injection(
        self,
        *,
        session_id: str,
        guidance_id: str,
        user_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        return await self._pending_user_injection_request(
            "DELETE",
            session_id=session_id,
            guidance_id=guidance_id,
            user_id=user_id,
        )

    async def _pending_user_injection_request(
        self,
        method: str,
        *,
        session_id: str,
        user_id: Optional[str],
        guidance_id: Optional[str] = None,
        json_payload: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        import httpx

        path = f"/api/sessions/{session_id}/inject-user-message"
        if guidance_id:
            path = f"{path}/{guidance_id}"
        headers = {"X-Sage-Internal-UserId": user_id} if user_id else {}
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.request(
                method,
                urljoin(self.api_url, path),
                json=json_payload,
                headers=headers,
            )
        if response.status_code >= 400:
            raise RuntimeError(
                f"Sage pending guidance failed ({response.status_code}): {response.text}"
            )
        payload = response.json()
        data = payload.get("data") if isinstance(payload, dict) else payload
        return data if isinstance(data, dict) else {"result": data}

    async def delete_workspace(
        self,
        *,
        user_id: str,
        agent_id: str,
    ) -> Dict[str, Any] | None:
        """删除用户在 Sage 中的 workspace 记录。"""
        import httpx

        delete_url = urljoin(self.api_url, "/api/agent/workspace/delete")
        payload = {
            "agent_id": agent_id,
            "user_id": user_id,
        }
        resolved_headers: Dict[str, str] = {}
        if user_id:
            resolved_headers.setdefault("X-Sage-Internal-UserId", user_id)
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(
                    delete_url,
                    json=payload,
                    headers=resolved_headers,
                )
                if response.status_code >= 400:
                    logger.warning(
                        f"[SageClient] 删除 workspace 失败 "
                        f"({response.status_code}): {response.text}"
                    )
                    return None
                result = response.json()
                data = result.get("data") if isinstance(result, dict) else result
                logger.info(
                    f"[SageClient] 删除 workspace 成功 user={user_id}, agent={agent_id}: {data}"
                )
                return data
        except Exception as exc:
            logger.warning(f"[SageClient] 删除 workspace 出错：{exc}")
            return None

    async def list_file_workspace(
        self,
        *,
        user_id: str,
        agent_id: str,
        path: str | None = None,
        max_depth: int | None = None,
    ) -> Dict[str, Any]:
        """List files in the user's Sage agent workspace."""
        import httpx

        headers = {"X-Sage-Internal-UserId": user_id} if user_id else {}
        workspace_url = urljoin(self.api_url, f"/api/agent/{agent_id}/file_workspace")
        params: dict[str, Any] = {}
        if path:
            params["path"] = path
        if max_depth is not None:
            params["max_depth"] = max_depth
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                workspace_url,
                headers=headers,
                params=params,
                json={},
            )
            if response.status_code >= 400:
                raise RuntimeError(
                    f"Sage workspace listing failed "
                    f"({response.status_code}): {response.text}"
                )
            result = response.json()
            data = result.get("data") if isinstance(result, dict) else result
            return data if isinstance(data, dict) else {}

    async def download_workspace_text_file(
        self,
        *,
        user_id: str,
        agent_id: str,
        file_path: str,
        max_bytes: int,
    ) -> tuple[str, bool]:
        """Download a workspace file as UTF-8 text with a byte limit."""
        import httpx

        headers = {"X-Sage-Internal-UserId": user_id} if user_id else {}
        download_url = urljoin(
            self.api_url,
            f"/api/agent/{agent_id}/file_workspace/download",
        )
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(
                download_url,
                headers=headers,
                params={"file_path": file_path},
            )
            if response.status_code >= 400:
                raise RuntimeError(
                    f"Sage workspace download failed "
                    f"({response.status_code}): {response.text}"
                )
            content = response.content
            truncated = len(content) > max_bytes
            if truncated:
                content = content[:max_bytes]
            return content.decode("utf-8", errors="replace"), truncated

    async def download_workspace_file(
        self,
        *,
        user_id: str,
        agent_id: str,
        file_path: str,
        max_bytes: int,
    ) -> SageWorkspaceFileDownload:
        """Download a workspace file as raw bytes with a byte limit."""
        import httpx

        headers = {"X-Sage-Internal-UserId": user_id} if user_id else {}
        download_url = urljoin(
            self.api_url,
            f"/api/agent/{agent_id}/file_workspace/download",
        )
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(
                download_url,
                headers=headers,
                params={"file_path": file_path},
            )
            if response.status_code >= 400:
                raise RuntimeError(
                    f"Sage workspace download failed "
                    f"({response.status_code}): {response.text}"
                )
            content = response.content
            if len(content) > max_bytes:
                raise RuntimeError("Workspace file is too large to preview")
            disposition = response.headers.get("content-disposition")
            return SageWorkspaceFileDownload(
                content=content,
                content_type=response.headers.get("content-type"),
                filename=_filename_from_content_disposition(disposition),
            )

    async def upload_workspace_file(
        self,
        *,
        user_id: str,
        agent_id: str,
        filename: str,
        content: bytes,
        content_type: str,
        target_path: str = "",
    ) -> Dict[str, Any]:
        """Upload a file into the user's Sage agent workspace."""
        import httpx

        headers = {"X-Sage-Internal-UserId": user_id} if user_id else {}
        upload_url = urljoin(
            self.api_url,
            f"/api/agent/{agent_id}/file_workspace/upload",
        )
        files = {"file": (filename, content, content_type)}
        data = {"target_path": target_path} if target_path else {}
        params = {"target_path": target_path} if target_path else {}
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                upload_url,
                headers=headers,
                params=params,
                files=files,
                data=data,
            )
            if response.status_code >= 400:
                raise RuntimeError(
                    f"Sage workspace upload failed "
                    f"({response.status_code}): {response.text}"
                )
            result = response.json()
            data_payload = result.get("data") if isinstance(result, dict) else result
            return data_payload if isinstance(data_payload, dict) else {}

    async def evaluate_once(
        self,
        session_id: str,
        messages: List[Dict[str, Any]],
        agent_id: str,
        user_id: Optional[str],
        system_context: Dict[str, Any],
    ) -> str:
        """非流式单轮调用：消费完整个流，拼接所有 assistant content 返回完整文本。

        用于不需要流式展示、只需要最终结果的内部场景。
        """
        parts: list[str] = []
        async for chunk in self.chat_stream(
            session_id=session_id,
            messages=messages,
            agent_id=agent_id,
            user_id=user_id,
            system_context=system_context,
        ):
            if chunk.role == "assistant" and chunk.content:
                if isinstance(chunk.content, str):
                    parts.append(chunk.content)
                elif isinstance(chunk.content, list):
                    for item in chunk.content:
                        if isinstance(item, dict) and item.get("type") == "text":
                            parts.append(str(item.get("text", "")))
        return "".join(parts)

    async def chat_stream(
        self,
        session_id: str,
        messages: List[Dict[str, Any]],
        agent_id: str,
        user_id: Optional[str],
        system_context: Dict[str, Any],
    ) -> AsyncGenerator[SageMessageChunk, None]:
        """
        与 Sage API 进行流式对话

        Args:
            session_id: 会话 ID
            messages: 消息列表，支持字符串或多模态 content
            agent_id: Agent ID
            user_id: 用户 ID
            system_context: 系统上下文
            extra_mcp_config: 额外的 MCP 配置

        Yields:
            SageMessageChunk: 流式响应的消息片段
        """
        # 构建请求负载
        payload = {
            "messages": messages,
            "session_id": session_id,
            "agent_id": agent_id,
            "user_id": user_id or session_id,
            "system_context": dict(system_context or {}),
        }

        logger.info(f"[SageClient] 正在发送请求到 {self.api_url} | session_id={session_id}")
        logger.info(f"[SageClient] agent_id={agent_id}")
        logger.info(f"[SageClient] user_id={payload['user_id']}")
        try:
            raw_payload = json.dumps(payload, ensure_ascii=False, default=str)
        except Exception as exc:
            raw_payload = f"<failed to serialize Sage payload: {exc}>"
        logger.warning(
            "[SageClient] 原始 /api/chat 请求体 session_id={} payload={}",
            session_id,
            raw_payload,
        )

        headers = {"X-Sage-Internal-UserId": user_id} if user_id else {}
        pending_tool_call_data: Dict[str, Any] | None = None
        pending_tool_call_emitted = False
        pending_tool_call_dirty = False
        try:
            import httpx

            stream_timeout = httpx.Timeout(
                timeout=self._STREAM_TIMEOUT_SECONDS,
                connect=10.0,
                read=self._STREAM_READ_TIMEOUT_SECONDS,
                write=10.0,
                pool=10.0,
            )
            async with self._get_stream_semaphore():
                async with httpx.AsyncClient(timeout=stream_timeout) as client:
                    chat_url = urljoin(self.api_url, "/api/chat")
                    async with client.stream(
                        "POST",
                        chat_url,
                        json=payload,
                        headers=headers,
                    ) as response:
                        if response.status_code != 200:
                            error_bytes = await response.aread()
                            error_text = error_bytes.decode('utf-8')
                            logger.error(f"[SageClient] API 错误：{response.status_code} - {error_text}")
                            yield SageMessageChunk(
                                role="assistant",
                                content=f"Sage API Error ({response.status_code}): {error_text}",
                                message_type="error"
                            )
                            return

                        data = None
                        pending_json_lines: list[str] = []
                        async for line in response.aiter_lines():
                            line = line.strip()
                            if not line:
                                continue

                            try:
                                candidate = line
                                if pending_json_lines:
                                    pending_json_lines.append(line)
                                    candidate = "\n".join(pending_json_lines)

                                decoded = self._decode_stream_json(candidate)
                                if decoded is None:
                                    if pending_json_lines:
                                        if (
                                            len(candidate.encode("utf-8"))
                                            > self._MAX_PENDING_STREAM_JSON_BYTES
                                        ):
                                            logger.warning(
                                                "[SageClient] JSON chunk 缓冲过大，"
                                                "丢弃未完成内容：{}",
                                                candidate[:500],
                                            )
                                            pending_json_lines = []
                                        continue
                                    if self._looks_like_json_payload(line):
                                        pending_json_lines = [line]
                                        continue
                                    logger.warning(f"[SageClient] 无效 JSON chunk：{line}")
                                    continue

                                pending_json_lines = []
                                if not isinstance(decoded, dict):
                                    logger.warning(
                                        "[SageClient] 无效 JSON chunk 类型：{}",
                                        type(decoded).__name__,
                                    )
                                    continue
                                data = decoded
                                if self._is_tool_call_stream_event(data):
                                    if (
                                        pending_tool_call_data is not None
                                        and not self._same_tool_call_stream_message(
                                            pending_tool_call_data,
                                            data,
                                        )
                                    ):
                                        chunk = None
                                        if (
                                            not pending_tool_call_emitted
                                            or pending_tool_call_dirty
                                        ):
                                            chunk = await self._chunk_from_stream_event(
                                                data=pending_tool_call_data,
                                                session_id=session_id,
                                                user_id=user_id,
                                            )
                                        pending_tool_call_data = None
                                        pending_tool_call_emitted = False
                                        pending_tool_call_dirty = False
                                        if chunk is not None:
                                            yield chunk
                                    if (
                                        pending_tool_call_data is not None
                                        and pending_tool_call_emitted
                                    ):
                                        pending_tool_call_dirty = True
                                    pending_tool_call_data = self._merge_tool_call_stream_event(
                                        pending_tool_call_data,
                                        data,
                                    )
                                    if (
                                        not pending_tool_call_emitted
                                        and self._tool_call_stream_event_has_function_name(
                                            pending_tool_call_data,
                                        )
                                    ):
                                        chunk = await self._chunk_from_stream_event(
                                            data=pending_tool_call_data,
                                            session_id=session_id,
                                            user_id=user_id,
                                        )
                                        if chunk is not None:
                                            yield chunk
                                        pending_tool_call_emitted = True
                                        pending_tool_call_dirty = False
                                    continue

                                if pending_tool_call_data is not None:
                                    chunk = None
                                    if (
                                        not pending_tool_call_emitted
                                        or pending_tool_call_dirty
                                    ):
                                        chunk = await self._chunk_from_stream_event(
                                            data=pending_tool_call_data,
                                            session_id=session_id,
                                            user_id=user_id,
                                        )
                                    pending_tool_call_data = None
                                    pending_tool_call_emitted = False
                                    pending_tool_call_dirty = False
                                    if chunk is not None:
                                        yield chunk

                                chunk = await self._chunk_from_stream_event(
                                    data=data,
                                    session_id=session_id,
                                    user_id=user_id,
                                )
                                if chunk is not None:
                                    yield chunk

                            except json.JSONDecodeError:
                                logger.warning(f"[SageClient] 无效 JSON chunk：{line}")
                            except Exception as e:
                                if data:
                                    logger.warning(f"[SageClient] data={data}")
                                traceback.print_exc()
                                logger.error(f"[SageClient] 处理 chunk 出错：{e}")
                        if pending_json_lines:
                            pending = "\n".join(pending_json_lines)
                            logger.warning(
                                "[SageClient] 流结束时仍有未完成 JSON chunk：{}",
                                pending[:500],
                            )
                        if pending_tool_call_data is not None:
                            chunk = None
                            if (
                                not pending_tool_call_emitted
                                or pending_tool_call_dirty
                            ):
                                chunk = await self._chunk_from_stream_event(
                                    data=pending_tool_call_data,
                                    session_id=session_id,
                                    user_id=user_id,
                                )
                            pending_tool_call_data = None
                            pending_tool_call_emitted = False
                            pending_tool_call_dirty = False
                            if chunk is not None:
                                yield chunk

        except Exception as e:
            error_type = type(e).__name__
            error_message = str(e).strip()
            error_detail = f"{error_type}: {error_message}" if error_message else error_type
            logger.error(f"[SageClient] 请求失败：{error_detail}")
            traceback.print_exc()
            if pending_tool_call_data is not None:
                try:
                    chunk = None
                    if (
                        not pending_tool_call_emitted
                        or pending_tool_call_dirty
                    ):
                        chunk = await self._chunk_from_stream_event(
                            data=pending_tool_call_data,
                            session_id=session_id,
                            user_id=user_id,
                        )
                    pending_tool_call_data = None
                    pending_tool_call_emitted = False
                    pending_tool_call_dirty = False
                    if chunk is not None:
                        yield chunk
                except Exception:
                    logger.warning("[SageClient] 刷新未完成 tool_call chunk 失败")
            yield SageMessageChunk(
                role="assistant",
                content=f"Request failed: {error_detail}",
                message_type="error",
                error_info={
                    "type": error_type,
                    "message": error_message,
                },
            )
