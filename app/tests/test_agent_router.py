from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from models.user import User
from schema.api.agent import AgentMessagePayload, AgentRunCreatePayload, AgentStreamPayload

_AGENT_ROUTER_PATH = Path(__file__).resolve().parents[1] / "api" / "routers" / "agent.py"
_SPEC = importlib.util.spec_from_file_location("agent_router_under_test", _AGENT_ROUTER_PATH)
assert _SPEC is not None and _SPEC.loader is not None
agent_router = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(agent_router)


class AgentRouterStreamTests(unittest.IsolatedAsyncioTestCase):
    async def test_agent_events_alias_keeps_legacy_conversation_events_route(self) -> None:
        endpoints_by_path = {
            route.path: route.endpoint
            for route in agent_router.router.routes
            if hasattr(route, "endpoint")
        }

        self.assertIs(
            endpoints_by_path["/agent/events"],
            agent_router.stream_agent_conversation_events,
        )
        self.assertIs(
            endpoints_by_path["/agent/conversation-events"],
            agent_router.stream_agent_conversation_events,
        )

    async def test_agent_events_first_chunk_does_not_query_snapshot(self) -> None:
        stream_started = False

        async def _stream_conversation_events(**_kwargs):
            nonlocal stream_started
            stream_started = True
            if False:
                yield None, None

        request = SimpleNamespace(is_disconnected=AsyncMock(return_value=False))
        user = User(
            user_id="user-1",
            username="user-1",
            password_hash="hash",
        )

        with patch.object(
            agent_router,
            "stream_conversation_events",
            side_effect=_stream_conversation_events,
        ):
            response = await agent_router.stream_agent_conversation_events(
                request=request,
                user=user,
            )
            first_chunk = await anext(response.body_iterator)

        self.assertEqual(first_chunk, ": connected\n\n")
        self.assertFalse(stream_started)

    async def test_session_entries_include_active_run_snapshot(self) -> None:
        manager = SimpleNamespace(
            get_active_run_payload=AsyncMock(
                return_value={
                    "session_id": "session-1",
                    "run_id": "run-active",
                    "status": "active",
                    "started_at": "2026-05-28T10:00:00",
                    "heartbeat_at": "2026-05-28T10:00:01",
                }
            ),
        )
        agent_service = SimpleNamespace(
            list_conversation_entries=AsyncMock(
                return_value={
                    "items": [],
                    "has_more": False,
                    "message_limit": 80,
                    "older_cursor": None,
                }
            ),
        )
        user = User(
            user_id="user-1",
            username="user-1",
            password_hash="hash",
        )

        with (
            patch.object(agent_router, "AgentService", return_value=agent_service),
            patch.object(agent_router, "get_agent_run_manager", return_value=manager),
        ):
            response = await agent_router.list_agent_session_entries(
                session_id="session-1",
                user=user,
            )

        self.assertTrue(response.data["is_active"])
        self.assertEqual(response.data["active_run"]["run_id"], "run-active")
        manager.get_active_run_payload.assert_awaited_once_with("session-1")

    async def test_create_run_starts_new_manager_run(self) -> None:
        manager = SimpleNamespace(
            start_session_run=AsyncMock(return_value="run-server-1"),
        )
        agent_service = SimpleNamespace(
            get_session=AsyncMock(return_value={"session_id": "session-1"}),
        )
        payload = AgentRunCreatePayload(
            system_context={"rerun_from_guidance": True},
            messages=[
                AgentMessagePayload(
                    message_id="msg-app-1",
                    role="user",
                    content="hello",
                )
            ],
        )
        user = User(
            user_id="user-1",
            username="user-1",
            password_hash="hash",
        )

        with (
            patch.object(agent_router, "AgentService", return_value=agent_service),
            patch.object(agent_router, "get_agent_run_manager", return_value=manager),
        ):
            response = await agent_router.create_agent_session_run(
                session_id="session-1",
                payload=payload,
                user=user,
            )

        self.assertEqual(response.data["run_id"], "run-server-1")
        manager.start_session_run.assert_awaited_once_with(
            user_id="user-1",
            session_id="session-1",
            messages=[{"message_id": "msg-app-1", "role": "user", "content": "hello"}],
            system_context={"rerun_from_guidance": True},
            consume_quota=True,
        )

    async def test_stream_interrupts_before_subscribe_when_messages_present(self) -> None:
        calls: list[str] = []

        async def _interrupt_session(**_kwargs):
            calls.append("interrupt")

        async def _subscribe_session(**_kwargs):
            calls.append("subscribe")
            return "queue"

        async def _stream_queue(**_kwargs):
            if False:
                yield ""

        manager = SimpleNamespace(
            is_session_active=AsyncMock(return_value=True),
            interrupt_session=AsyncMock(side_effect=_interrupt_session),
            subscribe_session=AsyncMock(side_effect=_subscribe_session),
            stream_queue=_stream_queue,
        )
        agent_service = SimpleNamespace(
            get_session=AsyncMock(return_value={"session_id": "session-1"}),
        )
        payload = AgentStreamPayload(
            client_run_id="run-1",
            system_context={"rerun_from_guidance": True},
            messages=[
                AgentMessagePayload(
                    role="user",
                    content="hello",
                )
            ],
        )
        user = User(
            user_id="user-1",
            username="user-1",
            password_hash="hash",
        )

        with (
            patch.object(agent_router, "AgentService", return_value=agent_service),
            patch.object(agent_router, "get_agent_run_manager", return_value=manager),
        ):
            response = await agent_router.stream_agent_session(
                session_id="session-1",
                payload=payload,
                user=user,
            )

        self.assertEqual(response.media_type, "text/event-stream")
        self.assertEqual(calls, ["interrupt", "subscribe"])
        manager.interrupt_session.assert_awaited_once_with(
            user_id="user-1",
            session_id="session-1",
        )
        manager.subscribe_session.assert_awaited_once()
        self.assertEqual(
            manager.subscribe_session.await_args.kwargs["system_context"],
            {"rerun_from_guidance": True},
        )

    async def test_stream_skips_interrupt_when_session_is_idle(self) -> None:
        async def _stream_queue(**_kwargs):
            if False:
                yield ""

        manager = SimpleNamespace(
            is_session_active=AsyncMock(return_value=False),
            interrupt_session=AsyncMock(),
            subscribe_session=AsyncMock(return_value="queue"),
            stream_queue=_stream_queue,
        )
        agent_service = SimpleNamespace(
            get_session=AsyncMock(return_value={"session_id": "session-1"}),
        )
        payload = AgentStreamPayload(
            client_run_id="run-1",
            messages=[
                AgentMessagePayload(
                    role="user",
                    content="hello",
                )
            ],
        )
        user = User(
            user_id="user-1",
            username="user-1",
            password_hash="hash",
        )

        with (
            patch.object(agent_router, "AgentService", return_value=agent_service),
            patch.object(agent_router, "get_agent_run_manager", return_value=manager),
        ):
            response = await agent_router.stream_agent_session(
                session_id="session-1",
                payload=payload,
                user=user,
            )

        self.assertEqual(response.media_type, "text/event-stream")
        manager.is_session_active.assert_awaited_once_with("session-1")
        manager.interrupt_session.assert_not_awaited()
        manager.subscribe_session.assert_awaited_once()

    async def test_stream_rejects_empty_messages(self) -> None:
        manager = SimpleNamespace(
            is_session_active=AsyncMock(),
            interrupt_session=AsyncMock(),
            subscribe_session=AsyncMock(return_value="queue"),
            stream_queue=lambda **_kwargs: iter(()),
        )
        agent_service = SimpleNamespace(
            get_session=AsyncMock(return_value={"session_id": "session-1"}),
        )
        payload = AgentStreamPayload(client_run_id="run-1", messages=[])
        user = User(
            user_id="user-1",
            username="user-1",
            password_hash="hash",
        )

        with (
            patch.object(agent_router, "AgentService", return_value=agent_service),
            patch.object(agent_router, "get_agent_run_manager", return_value=manager),
        ):
            with self.assertRaises(agent_router.AppHTTPException):
                await agent_router.stream_agent_session(
                    session_id="session-1",
                    payload=payload,
                    user=user,
                )

        manager.interrupt_session.assert_not_awaited()
        manager.is_session_active.assert_not_awaited()
        manager.subscribe_session.assert_not_awaited()


if __name__ == "__main__":
    unittest.main()
