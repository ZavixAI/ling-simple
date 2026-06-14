from __future__ import annotations

import asyncio
import unittest
from dataclasses import replace
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from models.base import get_local_now
from services.agent.run_state import AgentRunClaim, AgentRunState
from services.agent.runtime import AgentRunManager, _ActiveAgentRun, _AssistantChunkBuffer
from services.agent.sage import SageMessageChunk
from services.agent.service import AgentService


class _FakeAgentRunStateStore:
    def __init__(self) -> None:
        self.states: dict[str, AgentRunState] = {}
        self.deleted: list[tuple[str, str | None]] = []

    async def claim(
        self,
        *,
        user_id: str,
        session_id: str,
        client_run_id: str,
    ) -> AgentRunClaim:
        existing = self.states.get(session_id)
        if existing is not None:
            return AgentRunClaim(acquired=False, state=existing)
        now = get_local_now()
        state = AgentRunState(
            session_id=session_id,
            client_run_id=client_run_id,
            user_id=user_id,
            status="active",
            started_at=now,
            heartbeat_at=now,
        )
        self.states[session_id] = state
        return AgentRunClaim(acquired=True, state=state)

    async def get(self, session_id: str) -> AgentRunState | None:
        return self.states.get(session_id)

    async def heartbeat(
        self,
        session_id: str,
        client_run_id: str,
    ) -> AgentRunState | None:
        existing = self.states.get(session_id)
        if existing is None or existing.client_run_id != client_run_id:
            return None
        refreshed = replace(existing, heartbeat_at=get_local_now())
        self.states[session_id] = refreshed
        return refreshed

    async def delete_if_client(self, session_id: str, client_run_id: str) -> int:
        existing = self.states.get(session_id)
        if existing is None or existing.client_run_id != client_run_id:
            return 0
        del self.states[session_id]
        self.deleted.append((session_id, client_run_id))
        return 1

    async def delete(self, session_id: str) -> int:
        existed = session_id in self.states
        self.states.pop(session_id, None)
        self.deleted.append((session_id, None))
        return 1 if existed else 0


def _build_final_chunk() -> SimpleNamespace:
    return SimpleNamespace(
        is_final=True,
        message_type="stream_end",
        type="stream_end",
    )


def _stream_with_chunks(*chunks: SimpleNamespace):
    async def _generator(*args, **kwargs):
        for chunk in chunks:
            yield chunk

    return _generator


def _raising_stream(error: Exception):
    async def _generator(*args, **kwargs):
        raise error
        yield  # pragma: no cover

    return _generator


def _pending_stream():
    async def _generator(*args, **kwargs):
        await asyncio.sleep(3600)
        yield  # pragma: no cover

    return _generator


class AgentRunManagerCompletionNotificationTests(unittest.IsolatedAsyncioTestCase):
    async def test_get_active_run_payload_returns_snapshot_contract(self) -> None:
        store = _FakeAgentRunStateStore()
        manager = AgentRunManager(run_state_store=store)
        await store.claim(
            user_id="user-1",
            session_id="session-1",
            client_run_id="run-1",
        )

        payload = await manager.get_active_run_payload("session-1")

        self.assertIsNotNone(payload)
        assert payload is not None
        self.assertEqual(payload["session_id"], "session-1")
        self.assertEqual(payload["run_id"], "run-1")
        self.assertEqual(payload["status"], "active")
        self.assertIn("started_at", payload)
        self.assertIn("heartbeat_at", payload)

    async def test_run_buffers_assistant_text_chunks_until_stream_end(self) -> None:
        store = _FakeAgentRunStateStore()
        manager = AgentRunManager(run_state_store=store)
        queue: asyncio.Queue[dict[str, object] | None] = asyncio.Queue()
        active_run = _ActiveAgentRun(
            user_id="user-1",
            session_id="session-1",
            client_run_id="run-1",
            messages=[],
            system_context={},
            subscribers={queue},
        )
        manager._runs[active_run.session_id] = active_run
        service = AgentService()
        service.stream_chat_chunks = _stream_with_chunks(
            SageMessageChunk(
                role="assistant",
                message_id="msg-1",
                content="hel",
                message_type="message",
            ),
            SageMessageChunk(
                role="assistant",
                message_id="msg-1",
                content="lo",
                message_type="message",
            ),
            SageMessageChunk(
                role="assistant",
                message_type="stream_end",
                type="stream_end",
                is_final=True,
            ),
        )
        stored_chunks: list[SageMessageChunk] = []

        async def _store_chunk(user_id, session_id, chunk):
            stored_chunks.append(chunk)
            if (chunk.message_type or chunk.type) == "stream_end":
                return []
            return [
                {
                    "id": chunk.message_id,
                    "entry_type": "assistant_message",
                    "text": chunk.content,
                }
            ]

        service.store_assistant_chunk = AsyncMock(side_effect=_store_chunk)
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )

        with (
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            await manager._run(active_run)

        self.assertEqual(len(stored_chunks), 2)
        self.assertEqual(stored_chunks[0].message_id, "msg-1")
        self.assertEqual(stored_chunks[0].content, "hello")
        self.assertTrue(stored_chunks[0].is_final)
        self.assertEqual(stored_chunks[1].message_type, "stream_end")
        payloads = []
        while not queue.empty():
            item = queue.get_nowait()
            if item is not None:
                payloads.append(item)
        self.assertEqual(payloads[0]["data"]["item"]["text"], "hel")
        self.assertEqual(payloads[1]["data"]["item"]["text"], "hello")

    async def test_run_flushes_buffered_text_by_chunk_threshold(self) -> None:
        store = _FakeAgentRunStateStore()
        manager = AgentRunManager(run_state_store=store)
        active_run = _ActiveAgentRun(
            user_id="user-1",
            session_id="session-1",
            client_run_id="run-1",
            messages=[],
            system_context={},
            subscribers={asyncio.Queue()},
        )
        manager._runs[active_run.session_id] = active_run
        service = AgentService()
        service.stream_chat_chunks = _stream_with_chunks(
            SageMessageChunk(
                role="assistant",
                message_id="msg-1",
                content="hel",
                message_type="message",
            ),
            SageMessageChunk(
                role="assistant",
                message_id="msg-1",
                content="lo",
                message_type="message",
            ),
            SageMessageChunk(
                role="assistant",
                message_type="stream_end",
                type="stream_end",
                is_final=True,
            ),
        )
        stored_chunks: list[SageMessageChunk] = []

        async def _store_chunk(user_id, session_id, chunk):
            stored_chunks.append(chunk)
            return []

        service.store_assistant_chunk = AsyncMock(side_effect=_store_chunk)
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )

        with (
            patch.object(_AssistantChunkBuffer, "_FLUSH_CHUNK_COUNT", 1),
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            await manager._run(active_run)

        self.assertEqual([chunk.content for chunk in stored_chunks[:3]], ["hel", "lo", None])
        self.assertFalse(stored_chunks[0].is_final)
        self.assertFalse(stored_chunks[1].is_final)
        self.assertTrue(stored_chunks[2].is_final)
        self.assertEqual(stored_chunks[3].message_type, "stream_end")

    async def test_user_interrupt_preserves_buffered_assistant_text(self) -> None:
        store = _FakeAgentRunStateStore()
        manager = AgentRunManager(run_state_store=store)
        active_run = _ActiveAgentRun(
            user_id="user-1",
            session_id="session-1",
            client_run_id="run-1",
            messages=[],
            system_context={},
        )
        manager._runs[active_run.session_id] = active_run
        chunk_seen = asyncio.Event()

        async def _stream_chat_chunks(*args, **kwargs):
            chunk_seen.set()
            yield SageMessageChunk(
                role="assistant",
                message_id="msg-1",
                content="old partial reply",
                message_type="message",
            )
            await asyncio.Future()

        service = AgentService()
        service.stream_chat_chunks = _stream_chat_chunks
        stored_chunks: list[SageMessageChunk] = []

        async def _store_chunk(user_id, session_id, chunk):
            stored_chunks.append(chunk)
            return []

        service.store_assistant_chunk = AsyncMock(side_effect=_store_chunk)
        service.interrupt_session = AsyncMock()
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )

        with (
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            task = asyncio.create_task(manager._run(active_run))
            await chunk_seen.wait()
            await asyncio.sleep(0)
            active_run.interrupt_requested = True
            task.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await task

        self.assertEqual(len(stored_chunks), 1)
        self.assertEqual(stored_chunks[0].content, "old partial reply")
        self.assertFalse(stored_chunks[0].is_final)
        service.interrupt_session.assert_not_awaited()

    async def test_run_sends_push_when_active_subscribers_exist(self) -> None:
        store = _FakeAgentRunStateStore()
        manager = AgentRunManager(run_state_store=store)
        active_run = _ActiveAgentRun(
            user_id="user-1",
            session_id="session-1",
            client_run_id="run-1",
            messages=[{"role": "user", "content": "帮我整理今天的待办"}],
            system_context={},
            subscribers={asyncio.Queue()},
        )
        manager._runs[active_run.session_id] = active_run
        service = SimpleNamespace(
            stream_chat_chunks=_stream_with_chunks(_build_final_chunk()),
            store_assistant_chunk=AsyncMock(return_value=[]),
            interrupt_session=AsyncMock(),
        )
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )

        with (
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            await manager._run(active_run)

        push_service.send_agent_completion_notification.assert_awaited_once_with(
            user_id="user-1",
            session_id="session-1",
            content_dedupe_basis="帮我整理今天的待办",
            assistant_preview_text="",
        )
        self.assertNotIn("session-1", store.states)

    async def test_run_sends_completion_push_with_final_assistant_preview(self) -> None:
        store = _FakeAgentRunStateStore()
        manager = AgentRunManager(run_state_store=store)
        active_run = _ActiveAgentRun(
            user_id="user-1",
            session_id="session-preview",
            client_run_id="run-preview",
            messages=[{"role": "user", "content": "帮我整理今天的待办"}],
            system_context={},
        )
        manager._runs[active_run.session_id] = active_run
        service = SimpleNamespace(
            stream_chat_chunks=_stream_with_chunks(
                SageMessageChunk(
                    role="assistant",
                    message_id="msg-preview",
                    content="已整理好：",
                    message_type="assistant_message",
                ),
                SageMessageChunk(
                    role="assistant",
                    message_id="tool-preview",
                    content='{"status": "completed"}',
                    message_type="tool_call",
                ),
                SageMessageChunk(
                    role="assistant",
                    message_id="msg-preview",
                    content="今晚先处理邮件。",
                    message_type="assistant_message",
                ),
                _build_final_chunk(),
            ),
            store_assistant_chunk=AsyncMock(return_value=[]),
            interrupt_session=AsyncMock(),
        )
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )

        with (
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            await manager._run(active_run)

        push_service.send_agent_completion_notification.assert_awaited_once_with(
            user_id="user-1",
            session_id="session-preview",
            content_dedupe_basis="帮我整理今天的待办",
            assistant_preview_text="已整理好：今晚先处理邮件。",
        )
        self.assertNotIn("session-preview", store.states)

    async def test_run_sends_push_when_no_active_subscribers_exist(self) -> None:
        store = _FakeAgentRunStateStore()
        manager = AgentRunManager(run_state_store=store)
        active_run = _ActiveAgentRun(
            user_id="user-2",
            session_id="session-2",
            client_run_id="run-2",
            messages=[{"role": "user", "content": "总结一下今天会议"}],
            system_context={},
        )
        manager._runs[active_run.session_id] = active_run
        service = SimpleNamespace(
            stream_chat_chunks=_stream_with_chunks(_build_final_chunk()),
            store_assistant_chunk=AsyncMock(return_value=[]),
            interrupt_session=AsyncMock(),
        )
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )

        with (
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            await manager._run(active_run)

        push_service.send_agent_completion_notification.assert_awaited_once_with(
            user_id="user-2",
            session_id="session-2",
            content_dedupe_basis="总结一下今天会议",
            assistant_preview_text="",
        )
        self.assertNotIn("session-2", store.states)

    async def test_run_skips_push_when_stream_errors(self) -> None:
        store = _FakeAgentRunStateStore()
        manager = AgentRunManager(run_state_store=store)
        active_run = _ActiveAgentRun(
            user_id="user-3",
            session_id="session-3",
            client_run_id="run-3",
            messages=[],
            system_context={},
        )
        manager._runs[active_run.session_id] = active_run
        service = SimpleNamespace(
            stream_chat_chunks=_raising_stream(RuntimeError("boom")),
            store_assistant_chunk=AsyncMock(return_value=[]),
            interrupt_session=AsyncMock(),
        )
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )

        with (
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            await manager._run(active_run)

        push_service.send_agent_completion_notification.assert_not_awaited()
        self.assertNotIn("session-3", store.states)

    async def test_run_skips_push_when_cancelled(self) -> None:
        store = _FakeAgentRunStateStore()
        manager = AgentRunManager(run_state_store=store)
        active_run = _ActiveAgentRun(
            user_id="user-4",
            session_id="session-4",
            client_run_id="run-4",
            messages=[],
            system_context={},
        )
        manager._runs[active_run.session_id] = active_run
        service = SimpleNamespace(
            stream_chat_chunks=_pending_stream(),
            store_assistant_chunk=AsyncMock(return_value=[]),
            interrupt_session=AsyncMock(),
        )
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )

        with (
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            task = asyncio.create_task(manager._run(active_run))
            await asyncio.sleep(0)
            task.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await task

        push_service.send_agent_completion_notification.assert_not_awaited()
        service.interrupt_session.assert_awaited_once_with(
            "user-4",
            "session-4",
        )
        self.assertNotIn("session-4", store.states)

    async def test_manager_interrupt_does_not_duplicate_sage_interrupt(self) -> None:
        store = _FakeAgentRunStateStore()
        manager = AgentRunManager(run_state_store=store)
        active_run = _ActiveAgentRun(
            user_id="user-5",
            session_id="session-5",
            client_run_id="run-5",
            messages=[],
            system_context={},
        )
        manager._runs[active_run.session_id] = active_run
        store.states[active_run.session_id] = AgentRunState(
            session_id=active_run.session_id,
            client_run_id=active_run.client_run_id,
            user_id=active_run.user_id,
            status="active",
            started_at=get_local_now(),
            heartbeat_at=get_local_now(),
        )
        service = SimpleNamespace(
            stream_chat_chunks=_pending_stream(),
            store_assistant_chunk=AsyncMock(return_value=[]),
            interrupt_session=AsyncMock(),
        )
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )

        with (
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            active_run.task = asyncio.create_task(manager._run(active_run))
            await asyncio.sleep(0)
            await manager.interrupt_session(
                user_id=active_run.user_id,
                session_id=active_run.session_id,
            )
            with self.assertRaises(asyncio.CancelledError):
                await active_run.task

        service.interrupt_session.assert_awaited_once_with(
            active_run.user_id,
            active_run.session_id,
        )
        self.assertEqual(store.deleted[-1], (active_run.session_id, None))

    async def test_cancel_waits_for_chunk_persistence_before_cleanup(self) -> None:
        store = _FakeAgentRunStateStore()
        manager = AgentRunManager(run_state_store=store)
        active_run = _ActiveAgentRun(
            user_id="user-6",
            session_id="session-6",
            client_run_id="run-6",
            messages=[],
            system_context={},
        )
        manager._runs[active_run.session_id] = active_run
        store.states[active_run.session_id] = AgentRunState(
            session_id=active_run.session_id,
            client_run_id=active_run.client_run_id,
            user_id=active_run.user_id,
            status="active",
            started_at=get_local_now(),
            heartbeat_at=get_local_now(),
        )
        store_started = asyncio.Event()
        allow_store_finish = asyncio.Event()
        stored_chunks: list[SageMessageChunk] = []

        async def _store_chunk(user_id, session_id, chunk):
            store_started.set()
            await allow_store_finish.wait()
            stored_chunks.append(chunk)
            return []

        service = SimpleNamespace(
            stream_chat_chunks=_stream_with_chunks(
                SageMessageChunk(
                    role="assistant",
                    message_id="msg-6",
                    content="hello",
                    message_type="tool_call",
                )
            ),
            store_assistant_chunk=AsyncMock(side_effect=_store_chunk),
            interrupt_session=AsyncMock(),
        )
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )

        with (
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            task = asyncio.create_task(manager._run(active_run))
            await store_started.wait()
            task.cancel()
            await asyncio.sleep(0)
            self.assertFalse(task.done())
            allow_store_finish.set()
            with self.assertRaises(asyncio.CancelledError):
                await task

        self.assertEqual(len(stored_chunks), 1)
        service.interrupt_session.assert_awaited_once_with(
            active_run.user_id,
            active_run.session_id,
        )


class AgentRunManagerSubscriptionTests(unittest.IsolatedAsyncioTestCase):
    async def test_stream_queue_yields_sse_and_unsubscribes(self) -> None:
        manager = AgentRunManager(run_state_store=_FakeAgentRunStateStore())
        queue = asyncio.Queue()
        await queue.put(
            {
                "event": "conversation_entry",
                "data": {"op": "upsert", "item": {"id": "entry-1"}},
            }
        )
        await queue.put(None)
        active_run = _ActiveAgentRun(
            user_id="user-0",
            session_id="session-0",
            client_run_id="run-0",
            messages=[],
            system_context={},
            subscribers={queue},
        )
        manager._runs[active_run.session_id] = active_run

        chunks = [
            chunk
            async for chunk in manager.stream_queue(
                session_id=active_run.session_id,
                queue=queue,
            )
        ]

        self.assertEqual(
            chunks,
            [
                (
                    'event: conversation_entry\n'
                    'data: {"op": "upsert", "item": {"id": "entry-1"}}\n\n'
                )
            ],
        )
        self.assertNotIn(queue, active_run.subscribers)

    async def test_subscribe_reuses_active_run_for_same_client_run_id(self) -> None:
        manager = AgentRunManager(run_state_store=_FakeAgentRunStateStore())
        quota_service = SimpleNamespace(
            consume_daily_chat_quota=AsyncMock(),
        )
        service = SimpleNamespace(
            stream_chat_chunks=_pending_stream(),
            store_assistant_chunk=AsyncMock(return_value=[]),
            interrupt_session=AsyncMock(),
        )
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )
        with (
            patch(
                "services.agent.runtime.MembershipQuotaService",
                return_value=quota_service,
            ),
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            queue_one = await manager._subscribe(
                user_id="user-1",
                session_id="session-1",
                client_run_id="run-1",
                messages=[{"role": "user", "content": "hello"}],
                system_context={},
                consume_quota=True,
            )
            queue_two = await manager._subscribe(
                user_id="user-1",
                session_id="session-1",
                client_run_id="run-1",
                messages=[{"role": "user", "content": "hello again"}],
                system_context={"foo": "bar"},
                consume_quota=True,
            )

        self.assertIsNot(queue_one, queue_two)
        quota_service.consume_daily_chat_quota.assert_awaited_once_with("user-1")
        self.assertEqual(len(manager._runs["session-1"].subscribers), 2)

        task = manager._runs["session-1"].task
        self.assertIsNotNone(task)
        task.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await task

    async def test_subscribe_consumes_quota_for_image_prompt(self) -> None:
        manager = AgentRunManager(run_state_store=_FakeAgentRunStateStore())
        quota_service = SimpleNamespace(consume_daily_chat_quota=AsyncMock())
        service = SimpleNamespace(
            stream_chat_chunks=_pending_stream(),
            store_assistant_chunk=AsyncMock(return_value=[]),
            interrupt_session=AsyncMock(),
        )
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )

        with (
            patch(
                "services.agent.runtime.MembershipQuotaService",
                return_value=quota_service,
            ),
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            await manager._subscribe(
                user_id="user-free",
                session_id="session-image",
                client_run_id="run-image",
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": "看看这张图"},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": "https://cdn.example.com/img.jpg"
                                },
                            },
                        ],
                    }
                ],
                system_context={},
                consume_quota=True,
            )

        quota_service.consume_daily_chat_quota.assert_awaited_once_with(
            "user-free"
        )
        task = manager._runs["session-image"].task
        self.assertIsNotNone(task)
        task.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await task

    async def test_subscribe_interrupts_active_run_for_different_client_run_id(self) -> None:
        manager = AgentRunManager(run_state_store=_FakeAgentRunStateStore())
        quota_service = SimpleNamespace(
            consume_daily_chat_quota=AsyncMock(),
        )
        service = SimpleNamespace(
            stream_chat_chunks=_pending_stream(),
            store_assistant_chunk=AsyncMock(return_value=[]),
            interrupt_session=AsyncMock(),
        )
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )
        with (
            patch(
                "services.agent.runtime.MembershipQuotaService",
                return_value=quota_service,
            ),
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            queue = await manager._subscribe(
                user_id="user-2",
                session_id="session-2",
                client_run_id="run-1",
                messages=[{"role": "user", "content": "hello"}],
                system_context={},
                consume_quota=True,
            )
            queue_two = await manager._subscribe(
                user_id="user-2",
                session_id="session-2",
                client_run_id="run-2",
                messages=[{"role": "user", "content": "new prompt"}],
                system_context={},
                consume_quota=True,
            )

        self.assertIsNot(queue, queue_two)
        self.assertEqual(quota_service.consume_daily_chat_quota.await_count, 2)
        service.interrupt_session.assert_awaited()
        self.assertEqual(manager._runs["session-2"].client_run_id, "run-2")
        self.assertEqual(manager._runs["session-2"].messages[0]["content"], "new prompt")
        self.assertIs(queue.get_nowait(), None)
        await manager._unsubscribe("session-2", queue_two)
        task = manager._runs["session-2"].task
        self.assertIsNotNone(task)
        task.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await task

    async def test_subscribe_allows_different_sessions_to_claim_quota_concurrently(self) -> None:
        manager = AgentRunManager(run_state_store=_FakeAgentRunStateStore())
        quota_started = {
            "user-1": asyncio.Event(),
            "user-2": asyncio.Event(),
        }
        quota_release = asyncio.Event()

        async def _consume_quota(user_id: str) -> None:
            quota_started[user_id].set()
            await quota_release.wait()

        quota_service = SimpleNamespace(
            consume_daily_chat_quota=AsyncMock(side_effect=_consume_quota),
        )
        service = SimpleNamespace(
            stream_chat_chunks=_pending_stream(),
            store_assistant_chunk=AsyncMock(return_value=[]),
            interrupt_session=AsyncMock(),
        )
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )
        with (
            patch(
                "services.agent.runtime.MembershipQuotaService",
                return_value=quota_service,
            ),
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            subscribe_one = asyncio.create_task(
                manager._subscribe(
                    user_id="user-1",
                    session_id="session-1",
                    client_run_id="run-1",
                    messages=[{"role": "user", "content": "hello"}],
                    system_context={},
                    consume_quota=True,
                )
            )
            await asyncio.wait_for(quota_started["user-1"].wait(), timeout=0.1)
            subscribe_two = asyncio.create_task(
                manager._subscribe(
                    user_id="user-2",
                    session_id="session-2",
                    client_run_id="run-2",
                    messages=[{"role": "user", "content": "world"}],
                    system_context={},
                    consume_quota=True,
                )
            )
            await asyncio.wait_for(quota_started["user-2"].wait(), timeout=0.1)
            quota_release.set()
            queue_one = await subscribe_one
            queue_two = await subscribe_two
            tasks = [
                manager._runs["session-1"].task,
                manager._runs["session-2"].task,
            ]
            for task in tasks:
                self.assertIsNotNone(task)
                task.cancel()
            for task in tasks:
                with self.assertRaises(asyncio.CancelledError):
                    await task

        self.assertIsNotNone(queue_one)
        self.assertIsNotNone(queue_two)
        quota_service.consume_daily_chat_quota.assert_any_await("user-1")
        quota_service.consume_daily_chat_quota.assert_any_await("user-2")

    async def test_subscribe_empty_guidance_flush_run_does_not_consume_quota(self) -> None:
        manager = AgentRunManager(run_state_store=_FakeAgentRunStateStore())
        quota_service = SimpleNamespace(consume_daily_chat_quota=AsyncMock())
        service = SimpleNamespace(
            stream_chat_chunks=_pending_stream(),
            store_assistant_chunk=AsyncMock(return_value=[]),
            interrupt_session=AsyncMock(),
        )
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )
        with (
            patch(
                "services.agent.runtime.MembershipQuotaService",
                return_value=quota_service,
            ),
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            queue = await manager._subscribe(
                user_id="user-1",
                session_id="session-guidance",
                client_run_id="run-guidance",
                messages=[],
                system_context={},
                consume_quota=False,
            )

        self.assertIsNotNone(queue)
        quota_service.consume_daily_chat_quota.assert_not_awaited()
        task = manager._runs["session-guidance"].task
        self.assertIsNotNone(task)
        task.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await task

    async def test_unsubscribe_last_subscriber_keeps_run_active(self) -> None:
        manager = AgentRunManager(run_state_store=_FakeAgentRunStateStore())
        queue = asyncio.Queue()
        task = asyncio.create_task(asyncio.sleep(3600))
        active_run = _ActiveAgentRun(
            user_id="user-3",
            session_id="session-3",
            client_run_id="run-3",
            messages=[],
            system_context={},
            subscribers={queue},
            task=task,
        )
        manager._runs[active_run.session_id] = active_run

        await manager._unsubscribe("session-3", queue)
        await asyncio.sleep(0)

        self.assertFalse(task.cancelled())
        self.assertIn("session-3", manager._runs)
        task.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await task
        await manager._finish_run("session-3")

    async def test_is_session_active_uses_redis_marker_only(self) -> None:
        manager = AgentRunManager(run_state_store=_FakeAgentRunStateStore())
        task = asyncio.create_task(asyncio.sleep(3600))
        manager._runs["session-no-marker"] = _ActiveAgentRun(
            user_id="user-no-marker",
            session_id="session-no-marker",
            client_run_id="run-no-marker",
            messages=[],
            system_context={},
            task=task,
        )

        self.assertFalse(await manager.is_session_active("session-no-marker"))

        task.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await task
        await manager._finish_run("session-no-marker")

    async def test_remote_active_run_reuses_same_client_run_id_without_quota(self) -> None:
        store = _FakeAgentRunStateStore()
        owner = AgentRunManager(run_state_store=store)
        follower = AgentRunManager(run_state_store=store)
        quota_service = SimpleNamespace(
            consume_daily_chat_quota=AsyncMock(),
        )
        service = SimpleNamespace(
            stream_chat_chunks=_pending_stream(),
            store_assistant_chunk=AsyncMock(return_value=[]),
            interrupt_session=AsyncMock(),
        )
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )
        with (
            patch(
                "services.agent.runtime.MembershipQuotaService",
                return_value=quota_service,
            ),
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            owner_queue = await owner._subscribe(
                user_id="user-5",
                session_id="session-5",
                client_run_id="run-5",
                messages=[{"role": "user", "content": "hello"}],
                system_context={},
                consume_quota=True,
            )
            follower_queue = await follower._subscribe(
                user_id="user-5",
                session_id="session-5",
                client_run_id="run-5",
                messages=[{"role": "user", "content": "hello again"}],
                system_context={},
                consume_quota=True,
            )

        self.assertIsNot(owner_queue, follower_queue)
        self.assertTrue(await owner.is_session_active("session-5"))
        self.assertTrue(await follower.is_session_active("session-5"))
        quota_service.consume_daily_chat_quota.assert_awaited_once_with("user-5")
        self.assertNotIn("session-5", follower._runs)

        task = owner._runs["session-5"].task
        self.assertIsNotNone(task)
        task.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await task

    async def test_remote_active_run_interrupts_different_client_run_id(self) -> None:
        store = _FakeAgentRunStateStore()
        owner = AgentRunManager(run_state_store=store)
        follower = AgentRunManager(run_state_store=store)
        quota_service = SimpleNamespace(
            consume_daily_chat_quota=AsyncMock(),
        )
        service = SimpleNamespace(
            stream_chat_chunks=_pending_stream(),
            store_assistant_chunk=AsyncMock(return_value=[]),
            interrupt_session=AsyncMock(),
        )
        push_service = SimpleNamespace(
            send_agent_completion_notification=AsyncMock(),
        )
        with (
            patch(
                "services.agent.runtime.MembershipQuotaService",
                return_value=quota_service,
            ),
            patch("services.agent.runtime.AgentService", return_value=service),
            patch(
                "services.agent.runtime.PushNotificationService",
                return_value=push_service,
            ),
        ):
            await owner._subscribe(
                user_id="user-6",
                session_id="session-6",
                client_run_id="run-6",
                messages=[{"role": "user", "content": "hello"}],
                system_context={},
                consume_quota=True,
            )
            follower_queue = await follower._subscribe(
                user_id="user-6",
                session_id="session-6",
                client_run_id="run-other",
                messages=[{"role": "user", "content": "new prompt"}],
                system_context={},
                consume_quota=True,
            )

        self.assertIsNotNone(follower_queue)
        self.assertEqual(quota_service.consume_daily_chat_quota.await_count, 2)
        service.interrupt_session.assert_awaited()
        self.assertEqual(store.states["session-6"].client_run_id, "run-other")
        self.assertEqual(store.deleted, [("session-6", "run-6")])
        self.assertEqual(follower._runs["session-6"].client_run_id, "run-other")
        tasks = [
            owner._runs["session-6"].task,
            follower._runs["session-6"].task,
        ]
        for task in tasks:
            self.assertIsNotNone(task)
            task.cancel()
        for task in tasks:
            with self.assertRaises(asyncio.CancelledError):
                await task

    async def test_interrupt_clears_remote_marker_without_local_task(self) -> None:
        store = _FakeAgentRunStateStore()
        manager = AgentRunManager(run_state_store=store)
        now = get_local_now()
        store.states["session-7"] = AgentRunState(
            session_id="session-7",
            client_run_id="run-7",
            user_id="user-7",
            status="active",
            started_at=now,
            heartbeat_at=now,
        )
        service = SimpleNamespace(interrupt_session=AsyncMock())

        with patch("services.agent.runtime.AgentService", return_value=service):
            await manager.interrupt_session(user_id="user-7", session_id="session-7")

        service.interrupt_session.assert_awaited_once_with("user-7", "session-7")
        self.assertNotIn("session-7", store.states)


if __name__ == "__main__":
    unittest.main()
