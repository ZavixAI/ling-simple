from __future__ import annotations

import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch
from config import constants

from api.mcp import (
    AppNotificationPayload,
    _insert_notification_as_conversation_message,
    run_app_send_notification_pipeline,
)
from services.agent.service import build_daily_session_id


class MpcNotificationTests(unittest.IsolatedAsyncioTestCase):
    async def test_send_notification_pipeline_returns_after_submit_dispatch(self) -> None:
        service = SimpleNamespace(
            create_notification=AsyncMock(
                return_value={
                    "notification_id": "ntf_1",
                    "status": constants.NOTIFICATION_STATUS_QUEUED,
                }
            ),
            submit_immediate_dispatch=Mock(return_value=True),
        )

        with patch("services.notification.NotificationService", return_value=service):
            result = await run_app_send_notification_pipeline(
                "user-1",
                {
                    "title": "Hello",
                    "body": "World",
                },
            )

        self.assertTrue(result["accepted"])
        self.assertTrue(result["dispatch_submitted"])
        self.assertEqual(result["status"], constants.NOTIFICATION_STATUS_QUEUED)
        service.create_notification.assert_awaited_once()
        service.submit_immediate_dispatch.assert_called_once_with("ntf_1")

    async def test_insert_notification_creates_daily_session_with_resolved_timezone(self) -> None:
        session_dao = SimpleNamespace(
            get_or_create_user_session=AsyncMock(
                return_value=SimpleNamespace(
                    session_id=build_daily_session_id("user-1", constants.DEFAULT_TIMEZONE),
                    last_message_at=None,
                )
            ),
            save=AsyncMock(),
        )
        message_dao = SimpleNamespace(
            get_session_message=AsyncMock(return_value=None),
            insert=AsyncMock(),
        )
        push_device_dao = SimpleNamespace(
            get_latest_device=AsyncMock(return_value=SimpleNamespace(timezone=constants.DEFAULT_TIMEZONE))
        )
        user_config_dao = SimpleNamespace(get_config=AsyncMock(return_value={}))

        with (
            patch("models.agent.AgentSessionDao", return_value=session_dao),
            patch("models.agent.AgentMessageDao", return_value=message_dao),
            patch("models.push.UserPushDeviceDao", return_value=push_device_dao),
            patch("models.user.UserConfigDao", return_value=user_config_dao),
            patch(
                "api.mcp_tools.assistant.get_app_config",
                return_value=SimpleNamespace(sage_agent_id="agent-1"),
            ),
        ):
            await _insert_notification_as_conversation_message(
                user_id="user-1",
                notification=AppNotificationPayload(
                    title="Hello",
                    body="World\n[会议材料](file:///app/agents/user-1/report.md)\n<ling-action label=\"打开\" prompt=\"打开\" />",
                ),
            )

        session_dao.get_or_create_user_session.assert_awaited_once_with(
            session_id=build_daily_session_id("user-1", constants.DEFAULT_TIMEZONE),
            user_id="user-1",
            agent_id="agent-1",
            entry_mode="text",
            timezone=constants.DEFAULT_TIMEZONE,
        )
        message_dao.insert.assert_awaited_once()
        created_message = message_dao.insert.await_args.args[0]
        self.assertEqual(
            created_message.message["content"],
            "World\n[会议材料](file:///app/agents/user-1/report.md)\n<ling-action label=\"打开\" prompt=\"打开\" />",
        )


if __name__ == "__main__":
    unittest.main()
