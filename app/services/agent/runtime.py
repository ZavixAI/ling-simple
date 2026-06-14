"""Agent 流式运行管理：同会话并发订阅、孤儿任务回收与会员配额扣减。

AgentRunManager 在路由层持有，协调多客户端 SSE 订阅同一后台 Sage 任务。
客户端断开 SSE 后，服务端 run 仍继续执行到结束，以便完成落库和 APNs 完成通知。
"""

from __future__ import annotations

import asyncio
import json
import time
import uuid
from contextlib import suppress
from dataclasses import dataclass, field
from typing import Any, AsyncGenerator

from core.metrics import metrics
from loguru import logger
from modules.membership.quota import MembershipQuotaService
from services.agent.run_state import AgentRunStateStore
from services.agent.sage import SageMessageChunk
from services.agent.service import AgentService
from services.chat.conversation_events import publish_conversation_entry_changed
from services.push.service import PushNotificationService


@dataclass
class _ActiveAgentRun:
    user_id: str
    session_id: str
    client_run_id: str
    messages: list[dict[str, Any]]
    system_context: dict[str, Any]
    subscribers: set[asyncio.Queue[dict[str, Any] | None]] = field(
        default_factory=set,
    )
    task: asyncio.Task[None] | None = None
    interrupt_requested: bool = False


@dataclass
class _RemoteAgentRunSubscription:
    session_id: str
    client_run_id: str


@dataclass
class _BufferedAssistantMessage:
    message: Any
    pending_content: str = ""
    pending_chunks: int = 0
    last_flush_at: float = field(default_factory=time.monotonic)


class _AssistantChunkBuffer:
    _FLUSH_INTERVAL_SECONDS = 2.0
    _FLUSH_CHUNK_COUNT = 24

    def __init__(self, service: AgentService, user_id: str, session_id: str) -> None:
        self._service = service
        self._user_id = user_id
        self._session_id = session_id
        self._messages: dict[str, _BufferedAssistantMessage] = {}

    def _message_key(self, chunk: SageMessageChunk) -> str | None:
        message_id = chunk.message_id
        if message_id is None:
            return None
        normalized = str(message_id).strip()
        return normalized or None

    def _can_buffer(self, chunk: SageMessageChunk) -> bool:
        can_buffer = getattr(self._service, "can_buffer_assistant_chunk", None)
        if can_buffer is None:
            return False
        return bool(can_buffer(chunk))

    async def _store_chunk(self, chunk: SageMessageChunk) -> list[dict[str, Any]]:
        store_task = asyncio.ensure_future(
            self._service.store_assistant_chunk(
                self._user_id,
                self._session_id,
                chunk,
            )
        )
        try:
            return await asyncio.shield(store_task)
        except asyncio.CancelledError:
            try:
                await store_task
            except Exception:
                logger.exception("[AgentRunManager] 取消期间的消息持久化失败")
            raise

    async def handle_chunk(self, chunk: SageMessageChunk) -> list[dict[str, Any]]:
        kind = (chunk.message_type or chunk.type or "").strip()
        if kind == "stream_end":
            updates = await self.flush_all(is_final=True)
            updates.extend(await self._store_chunk(chunk))
            return updates

        if not self._can_buffer(chunk):
            updates = await self.flush_all(is_final=True)
            updates.extend(await self._store_chunk(chunk))
            return updates

        key = self._message_key(chunk)
        if key is None:
            return await self._store_chunk(chunk)

        buffered = self._messages.get(key)
        current = buffered.message if buffered is not None else None
        merged = self._service.merge_transient_assistant_chunk(
            user_id=self._user_id,
            session_id=self._session_id,
            current=current,
            chunk=chunk,
        )

        pending_content = (
            buffered.pending_content if buffered is not None else ""
        ) + self._content_delta(chunk)
        pending_chunks = (buffered.pending_chunks if buffered is not None else 0) + 1
        last_flush_at = buffered.last_flush_at if buffered is not None else time.monotonic()
        self._messages[key] = _BufferedAssistantMessage(
            message=merged,
            pending_content=pending_content,
            pending_chunks=pending_chunks,
            last_flush_at=last_flush_at,
        )

        if chunk.is_final:
            return await self.flush_message(key, is_final=True)

        updates = self._service.build_entry_updates_for_transient_message(merged)
        if self._should_flush(key):
            updates.extend(await self.flush_message(key, is_final=False))
        return updates

    def _content_delta(self, chunk: SageMessageChunk) -> str:
        return chunk.content if isinstance(chunk.content, str) else ""

    def _should_flush(self, message_id: str) -> bool:
        buffered = self._messages.get(message_id)
        if buffered is None or not buffered.pending_content:
            return False
        if buffered.pending_chunks >= self._FLUSH_CHUNK_COUNT:
            return True
        return time.monotonic() - buffered.last_flush_at >= self._FLUSH_INTERVAL_SECONDS

    async def flush_message(
        self,
        message_id: str,
        *,
        is_final: bool,
    ) -> list[dict[str, Any]]:
        buffered = self._messages.get(message_id)
        if buffered is None:
            return []
        if not buffered.pending_content and not is_final:
            return []
        chunk = self._service.build_chunk_from_transient_message(
            buffered.message,
            content=buffered.pending_content or None,
            is_final=is_final,
        )
        updates = await self._store_chunk(chunk)
        if is_final:
            self._messages.pop(message_id, None)
        else:
            self._messages[message_id] = _BufferedAssistantMessage(
                message=buffered.message,
                last_flush_at=time.monotonic(),
            )
        return updates

    async def flush_all(self, *, is_final: bool) -> list[dict[str, Any]]:
        updates: list[dict[str, Any]] = []
        for message_id in list(self._messages.keys()):
            updates.extend(await self.flush_message(message_id, is_final=is_final))
        return updates


class AgentRunManager:
    """按 client_run_id 管理进行中的流式任务、广播队列与会话级互斥锁。"""

    def __init__(self, run_state_store: AgentRunStateStore | None = None) -> None:
        self._runs: dict[str, _ActiveAgentRun] = {}
        self._remote_subscriptions: dict[
            asyncio.Queue[dict[str, Any] | None],
            _RemoteAgentRunSubscription,
        ] = {}
        self._session_locks: dict[str, asyncio.Lock] = {}
        self._session_locks_lock = asyncio.Lock()
        self._run_state_store = run_state_store or AgentRunStateStore()

    async def _get_session_lock(self, session_id: str) -> asyncio.Lock:
        async with self._session_locks_lock:
            lock = self._session_locks.get(session_id)
            if lock is None:
                lock = asyncio.Lock()
                self._session_locks[session_id] = lock
            return lock

    async def stream_session(
        self,
        *,
        user_id: str,
        session_id: str,
        client_run_id: str,
        messages: list[dict[str, Any]],
        system_context: dict[str, Any],
        consume_quota: bool,
    ) -> AsyncGenerator[str, None]:
        queue = await self.subscribe_session(
            user_id=user_id,
            session_id=session_id,
            client_run_id=client_run_id,
            messages=messages,
            system_context=system_context,
            consume_quota=consume_quota,
        )
        async for chunk in self.stream_queue(session_id=session_id, queue=queue):
            yield chunk

    async def subscribe_session(
        self,
        *,
        user_id: str,
        session_id: str,
        client_run_id: str,
        messages: list[dict[str, Any]],
        system_context: dict[str, Any],
        consume_quota: bool,
    ) -> asyncio.Queue[dict[str, Any] | None]:
        return await self._subscribe(
            user_id=user_id,
            session_id=session_id,
            client_run_id=client_run_id,
            messages=messages,
            system_context=system_context,
            consume_quota=consume_quota,
        )

    async def start_session_run(
        self,
        *,
        user_id: str,
        session_id: str,
        messages: list[dict[str, Any]],
        system_context: dict[str, Any],
        consume_quota: bool,
    ) -> str:
        run_id = f"run_{uuid.uuid4().hex}"
        while True:
            if await self.is_session_active(session_id):
                await self.interrupt_session(user_id=user_id, session_id=session_id)

            session_lock = await self._get_session_lock(session_id)
            async with session_lock:
                active_run = self._runs.get(session_id)
                if active_run is not None:
                    active_client_run_id = active_run.client_run_id
                else:
                    active_client_run_id = None

            if active_client_run_id is not None:
                await self.interrupt_session(user_id=user_id, session_id=session_id)
                continue

            async with session_lock:
                claim = await self._run_state_store.claim(
                    user_id=user_id,
                    session_id=session_id,
                    client_run_id=run_id,
                )
                if not claim.acquired:
                    await self._interrupt_remote_run(
                        user_id=user_id,
                        session_id=session_id,
                        active_client_run_id=claim.state.client_run_id,
                    )
                    continue
                try:
                    if consume_quota:
                        await MembershipQuotaService().consume_daily_chat_quota(user_id)
                except Exception:
                    await self._run_state_store.delete_if_client(session_id, run_id)
                    raise
                active_run = _ActiveAgentRun(
                    user_id=user_id,
                    session_id=session_id,
                    client_run_id=run_id,
                    messages=[dict(item) for item in messages],
                    system_context=dict(system_context),
                )
                active_run.task = asyncio.create_task(
                    self._run(active_run),
                    name=f"agent-run:{session_id}",
                )
                self._runs[session_id] = active_run
                metrics.inc_gauge("ling_agent_active_runs")

            logger.info(
                "[AgentRunManager] 已创建命令式活跃 run "
                f"session={session_id} user={user_id} run_id={run_id}"
            )
            await self._publish_run_event(active_run, "run_started")
            return run_id

    async def stream_queue(
        self,
        *,
        session_id: str,
        queue: asyncio.Queue[dict[str, Any] | None],
    ) -> AsyncGenerator[str, None]:
        try:
            while True:
                payload = await queue.get()
                if payload is None:
                    break
                event_name = str(payload.get("event") or "message").strip() or "message"
                body = json.dumps(payload.get("data") or {}, ensure_ascii=False)
                yield f"event: {event_name}\ndata: {body}\n\n"
        finally:
            await self._unsubscribe(session_id, queue)

    async def interrupt_session(self, *, user_id: str, session_id: str) -> None:
        task: asyncio.Task[None] | None = None
        session_lock = await self._get_session_lock(session_id)
        async with session_lock:
            active_run = self._runs.pop(session_id, None)
            if active_run is not None:
                active_run.interrupt_requested = True
                task = active_run.task
                subscribers = list(active_run.subscribers)
                metrics.dec_gauge("ling_agent_active_runs")
            else:
                subscribers = []

        for queue in subscribers:
            with suppress(asyncio.QueueFull):
                queue.put_nowait(None)

        if task is not None:
            task.cancel()

        await AgentService().interrupt_session(user_id, session_id)
        await self._run_state_store.delete(session_id)

    async def is_session_active(self, session_id: str) -> bool:
        return await self._run_state_store.get(session_id) is not None

    async def get_active_run_payload(self, session_id: str) -> dict[str, Any] | None:
        state = await self._run_state_store.get(session_id)
        if state is None:
            return None
        return {
            "session_id": state.session_id,
            "run_id": state.client_run_id,
            "status": state.status,
            "started_at": state.started_at.isoformat(),
            "heartbeat_at": state.heartbeat_at.isoformat(),
        }

    async def _subscribe(
        self,
        *,
        user_id: str,
        session_id: str,
        client_run_id: str,
        messages: list[dict[str, Any]],
        system_context: dict[str, Any],
        consume_quota: bool,
    ) -> asyncio.Queue[dict[str, Any] | None]:
        while True:
            session_lock = await self._get_session_lock(session_id)
            async with session_lock:
                active_run = self._runs.get(session_id)
                if active_run is not None and active_run.client_run_id != client_run_id:
                    active_client_run_id = active_run.client_run_id
                else:
                    active_client_run_id = None

            if active_client_run_id is not None:
                logger.info(
                    "[AgentRunManager] 新消息到达，中断本地活跃 run "
                    f"session={session_id} user={user_id} "
                    f"active_client_run_id={active_client_run_id} "
                    f"requested_client_run_id={client_run_id}"
                )
                await self.interrupt_session(user_id=user_id, session_id=session_id)
                continue

            async with session_lock:
                active_run = self._runs.get(session_id)
                if active_run is None:
                    claim = await self._run_state_store.claim(
                        user_id=user_id,
                        session_id=session_id,
                        client_run_id=client_run_id,
                    )
                    if not claim.acquired:
                        if claim.state.client_run_id != client_run_id:
                            active_client_run_id = claim.state.client_run_id
                        else:
                            queue: asyncio.Queue[dict[str, Any] | None] = asyncio.Queue()
                            self._remote_subscriptions[queue] = _RemoteAgentRunSubscription(
                                session_id=session_id,
                                client_run_id=client_run_id,
                            )
                            queue.put_nowait(
                                {
                                    "event": "remote_run_active",
                                    "data": {
                                        "session_id": session_id,
                                        "client_run_id": client_run_id,
                                    },
                                }
                            )
                            queue.put_nowait(None)
                            logger.debug(
                                "[AgentRunManager] 订阅者附加到远端活跃 run "
                                f"session={session_id} client_run_id={client_run_id}"
                            )
                            return queue
                    else:
                        try:
                            if consume_quota:
                                await MembershipQuotaService().consume_daily_chat_quota(user_id)
                        except Exception:
                            await self._run_state_store.delete_if_client(
                                session_id,
                                client_run_id,
                            )
                            raise
                        active_run = _ActiveAgentRun(
                            user_id=user_id,
                            session_id=session_id,
                            client_run_id=client_run_id,
                            messages=[dict(item) for item in messages],
                            system_context=dict(system_context),
                        )
                        active_run.task = asyncio.create_task(
                            self._run(active_run),
                            name=f"agent-run:{session_id}",
                        )
                        self._runs[session_id] = active_run
                        metrics.inc_gauge("ling_agent_active_runs")
                        logger.info(
                            "[AgentRunManager] 已创建活跃 run "
                            f"session={session_id} user={user_id} client_run_id={client_run_id}"
                        )
                        active_client_run_id = None

                if active_run is not None and active_run.client_run_id == client_run_id:
                    queue = asyncio.Queue()
                    active_run.subscribers.add(queue)
                    logger.debug(
                        "[AgentRunManager] 订阅者已附加 "
                        f"session={session_id} client_run_id={active_run.client_run_id} "
                        f"subscriber_count={len(active_run.subscribers)}"
                    )
                    return queue

            if active_client_run_id is not None:
                logger.info(
                    "[AgentRunManager] 新消息到达，中断远端活跃 run "
                    f"session={session_id} user={user_id} "
                    f"active_client_run_id={active_client_run_id} "
                    f"requested_client_run_id={client_run_id}"
                )
                await self._interrupt_remote_run(
                    user_id=user_id,
                    session_id=session_id,
                    active_client_run_id=active_client_run_id,
                )

    async def _interrupt_remote_run(
        self,
        *,
        user_id: str,
        session_id: str,
        active_client_run_id: str,
    ) -> None:
        await AgentService().interrupt_session(user_id, session_id)
        await self._run_state_store.delete_if_client(session_id, active_client_run_id)

    async def _unsubscribe(
        self,
        session_id: str,
        queue: asyncio.Queue[dict[str, Any] | None],
    ) -> None:
        session_lock = await self._get_session_lock(session_id)
        async with session_lock:
            remote_subscription = self._remote_subscriptions.pop(queue, None)
            if remote_subscription is not None:
                return
            active_run = self._runs.get(session_id)
            if active_run is None:
                return
            active_run.subscribers.discard(queue)
            if not active_run.subscribers and active_run.task is not None:
                logger.info(
                    "[AgentRunManager] 最后一个订阅者已断开，run 将继续在后台完成 "
                    f"session={session_id} client_run_id={active_run.client_run_id}"
                )

    async def _broadcast(
        self,
        session_id: str,
        payload: dict[str, Any],
    ) -> None:
        session_lock = await self._get_session_lock(session_id)
        async with session_lock:
            active_run = self._runs.get(session_id)
            if active_run is None:
                return
            subscribers = list(active_run.subscribers)

        for queue in subscribers:
            with suppress(asyncio.QueueFull):
                queue.put_nowait(payload)

    async def _publish_entry_update(
        self,
        active_run: _ActiveAgentRun,
        entry: dict[str, Any],
    ) -> None:
        entry_id = str(entry.get("id") or "").strip()
        if not entry_id:
            return
        payload = {
            "type": "conversation_entry",
            "op": "upsert",
            "session_id": active_run.session_id,
            "run_id": active_run.client_run_id,
            "item": entry,
        }
        await publish_conversation_entry_changed(
            user_id=active_run.user_id,
            session_id=active_run.session_id,
            entry_id=entry_id,
            message_id=str(entry.get("message_id") or "") or None,
            created_at=str(entry.get("created_at") or "") or None,
            reason="agent_run_entry",
            payload=payload,
        )

    async def _publish_run_event(
        self,
        active_run: _ActiveAgentRun,
        event_type: str,
    ) -> None:
        await publish_conversation_entry_changed(
            user_id=active_run.user_id,
            session_id=active_run.session_id,
            entry_id=active_run.client_run_id,
            reason=event_type,
            payload={
                "type": event_type,
                "session_id": active_run.session_id,
                "run_id": active_run.client_run_id,
            },
        )

    async def _has_active_subscribers(self, session_id: str) -> bool:
        session_lock = await self._get_session_lock(session_id)
        async with session_lock:
            active_run = self._runs.get(session_id)
            return active_run is not None and bool(active_run.subscribers)

    async def _active_subscriber_count(self, session_id: str) -> int:
        session_lock = await self._get_session_lock(session_id)
        async with session_lock:
            active_run = self._runs.get(session_id)
            if active_run is None:
                return 0
            return len(active_run.subscribers)

    async def _finish_run(self, session_id: str) -> None:
        session_lock = await self._get_session_lock(session_id)
        async with session_lock:
            active_run = self._runs.pop(session_id, None)
            if active_run is None:
                return
            subscribers = list(active_run.subscribers)
            metrics.dec_gauge("ling_agent_active_runs")

        for queue in subscribers:
            with suppress(asyncio.QueueFull):
                queue.put_nowait(None)
        await self._run_state_store.delete_if_client(
            session_id,
            active_run.client_run_id,
        )

    async def _run(self, active_run: _ActiveAgentRun) -> None:
        service = AgentService()
        push_service = PushNotificationService()
        chunk_buffer = _AssistantChunkBuffer(
            service,
            active_run.user_id,
            active_run.session_id,
        )
        saw_final_chunk = False
        stream_had_error = False
        assistant_completion_parts: list[str] = []
        assistant_completion_message_id: str | None = None

        try:
            async for chunk in service.stream_chat_chunks(
                active_run.user_id,
                active_run.session_id,
                active_run.messages,
                active_run.system_context,
            ):
                content_delta = self._completion_push_assistant_delta(chunk)
                if content_delta:
                    chunk_message_id = (
                        str(chunk.message_id).strip()
                        if chunk.message_id is not None
                        else None
                    )
                    if (
                        chunk_message_id
                        and assistant_completion_message_id
                        and chunk_message_id != assistant_completion_message_id
                    ):
                        assistant_completion_parts = []
                    if chunk_message_id:
                        assistant_completion_message_id = chunk_message_id
                    assistant_completion_parts.append(content_delta)
                if chunk.is_final or (chunk.message_type or chunk.type) == "stream_end":
                    saw_final_chunk = True
                if (chunk.message_type or chunk.type) == "error":
                    stream_had_error = True
                await self._run_state_store.heartbeat(
                    active_run.session_id,
                    active_run.client_run_id,
                )
                entry_updates = await chunk_buffer.handle_chunk(chunk)
                for entry in entry_updates:
                    with suppress(Exception):
                        await self._publish_entry_update(active_run, entry)
                    await self._broadcast(
                        active_run.session_id,
                        {
                            "event": "conversation_entry",
                            "data": {"op": "upsert", "item": entry},
                        },
                    )
        except asyncio.CancelledError:
            logger.info(
                f"[AgentRunManager] 已取消活跃 run session={active_run.session_id}"
            )
            with suppress(Exception):
                await chunk_buffer.flush_all(is_final=False)
            if not active_run.interrupt_requested:
                with suppress(Exception):
                    await service.interrupt_session(
                        active_run.user_id,
                        active_run.session_id,
                    )
            raise
        except Exception as exc:
            logger.exception(
                f"[AgentRunManager] 会话发生未处理失败 session={active_run.session_id}"
            )
            stream_had_error = True
            error_chunk = SageMessageChunk(
                role="assistant",
                content=f"Request failed: {exc}",
                message_type="error",
            )
            entry_updates = await chunk_buffer.handle_chunk(error_chunk)
            for entry in entry_updates:
                with suppress(Exception):
                    await self._publish_entry_update(active_run, entry)
                await self._broadcast(
                    active_run.session_id,
                    {
                        "event": "conversation_entry",
                        "data": {"op": "upsert", "item": entry},
                    },
                )
        finally:
            active_subscriber_count = await self._active_subscriber_count(
                active_run.session_id
            )
            should_send_completion_push = not stream_had_error and saw_final_chunk
            push_eligible = should_send_completion_push
            display_delegated_to_client = push_eligible
            skip_reasons: list[str] = []
            if stream_had_error:
                skip_reasons.append("stream_had_error")
            if not saw_final_chunk:
                skip_reasons.append("no_final_chunk")
            logger.info(
                "[AgentRunManager] 完成推送决策 "
                f"session={active_run.session_id} "
                f"user={active_run.user_id} "
                f"saw_final_chunk={saw_final_chunk} "
                f"stream_had_error={stream_had_error} "
                f"active_subscribers={active_subscriber_count} "
                f"push_eligible={push_eligible} "
                f"display_delegated_to_client={display_delegated_to_client} "
                f"should_send={should_send_completion_push} "
                f"reasons={','.join(skip_reasons) if skip_reasons else 'eligible'}"
            )
            if should_send_completion_push:
                logger.info(
                    "[AgentRunManager] 正在触发完成推送 "
                    f"session={active_run.session_id} user={active_run.user_id}"
                )
                try:
                    await push_service.send_agent_completion_notification(
                        user_id=active_run.user_id,
                        session_id=active_run.session_id,
                        content_dedupe_basis=self._completion_push_content_basis(
                            active_run.messages,
                        ),
                        assistant_preview_text="".join(assistant_completion_parts),
                    )
                except Exception:
                    logger.exception(
                        "[AgentRunManager] 完成推送派发失败 "
                        f"session={active_run.session_id} user={active_run.user_id}"
                    )
            with suppress(Exception):
                await self._publish_run_event(
                    active_run,
                    (
                        "run_completed"
                        if saw_final_chunk and not stream_had_error
                        else "run_stopped"
                    ),
                )
            await self._finish_run(active_run.session_id)
            await self._dispatch_notifications_after_conversation(active_run.user_id)

    @staticmethod
    def _completion_push_content_basis(messages: list[dict[str, Any]]) -> str:
        for message in reversed(messages):
            if (message.get("role") or "user") == "user":
                content = message.get("content")
                if isinstance(content, str):
                    return content.strip()
                return json.dumps(content, ensure_ascii=False, sort_keys=True)
        return ""

    @staticmethod
    def _completion_push_assistant_delta(chunk: SageMessageChunk) -> str:
        kind = (chunk.message_type or chunk.type or "").strip()
        if kind in {"stream_end", "error", "tool_call", "tool_call_result"}:
            return ""
        if (chunk.role or "").strip() not in {"", "assistant"}:
            return ""
        if chunk.tool_calls:
            return ""
        return chunk.content if isinstance(chunk.content, str) else ""

    async def _dispatch_notifications_after_conversation(self, user_id: str) -> None:
        try:
            from services.notification import NotificationService

            dispatched = await NotificationService().dispatch_due_notifications(limit=10)
            if dispatched > 0:
                logger.info(
                    "[AgentRunManager] 对话结束后投递等待通知 "
                    f"user={user_id} dispatched={dispatched}"
                )
        except Exception:
            logger.debug(
                "[AgentRunManager] 对话结束后投递等待通知失败 "
                f"user={user_id}",
                exc_info=True,
            )

_AGENT_RUN_MANAGER: AgentRunManager | None = None


def get_agent_run_manager() -> AgentRunManager:
    global _AGENT_RUN_MANAGER
    if _AGENT_RUN_MANAGER is None:
        _AGENT_RUN_MANAGER = AgentRunManager()
    return _AGENT_RUN_MANAGER
