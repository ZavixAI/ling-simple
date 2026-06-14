from __future__ import annotations

import asyncio
import unittest
from contextlib import asynccontextmanager
from datetime import timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from config import constants
from models.base import Base, get_local_now
from models.notification import Notification, NotificationDao
from services.notification import NotificationService
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine


@asynccontextmanager
async def _fake_lock(*_args, **_kwargs):
    yield True


@asynccontextmanager
async def _fake_lock_or_raise(*_args, **_kwargs):
    yield None


class NotificationServiceDispatchTests(unittest.IsolatedAsyncioTestCase):
    async def test_dispatch_due_notifications_honors_configured_concurrency(self) -> None:
        service = NotificationService(
            config=SimpleNamespace(
                notification_dispatch_max_concurrency=2,
                notification_dispatch_claim_timeout_seconds=300,
            )
        )
        notifications = [
            SimpleNamespace(notification_id="ntf_1"),
            SimpleNamespace(notification_id="ntf_2"),
        ]
        started = {item.notification_id: asyncio.Event() for item in notifications}
        release = asyncio.Event()

        async def _dispatch(notification) -> bool:
            started[notification.notification_id].set()
            await release.wait()
            return True

        service.notification_dao.list_due_notifications = AsyncMock(return_value=notifications)
        service._dispatch_notification = AsyncMock(side_effect=_dispatch)

        dispatch_task = asyncio.create_task(service.dispatch_due_notifications(limit=10))
        await asyncio.wait_for(started["ntf_1"].wait(), timeout=0.1)
        await asyncio.wait_for(started["ntf_2"].wait(), timeout=0.1)
        release.set()
        dispatched = await dispatch_task

        self.assertEqual(dispatched, 2)
        self.assertEqual(service._dispatch_notification.await_count, 2)

    async def test_create_notification_reuses_existing_record_for_same_dedupe_key(self) -> None:
        service = NotificationService()
        existing = SimpleNamespace(
            notification_id="ntf_existing",
            user_id="user-1",
            title="Old",
            body="Old body",
            category="general",
            priority="normal",
            silent=False,
            dedupe_key="dedupe-1",
            target_type=None,
            target_id=None,
            target_action=None,
            send_time=None,
            status="queued",
            dispatch_claimed_at=None,
            status_detail=None,
            delivered_at=None,
            opened_at=None,
            dismissed_at=None,
            failed_at=None,
            created_at=get_local_now(),
            updated_at=get_local_now(),
        )
        service.notification_dao.get_latest_by_dedupe_key = AsyncMock(
            return_value=existing
        )
        service.notification_dao.save = AsyncMock(return_value=True)

        with patch("services.notification.redis.lock_or_raise", _fake_lock_or_raise):
            result = await service.create_notification(
                "user-1",
                {
                    "title": "New title",
                    "body": "New body",
                    "dedupe_key": "dedupe-1",
                },
            )

        self.assertTrue(result["deduplicated"])
        self.assertEqual(existing.title, "New title")
        self.assertEqual(existing.body, "New body")
        service.notification_dao.save.assert_awaited_once_with(existing)

    async def test_dispatch_due_notification_marks_sent_on_success(self) -> None:
        service = NotificationService()
        notification = SimpleNamespace(
            notification_id="ntf_1",
            user_id="user-1",
            title="Title",
            body="Body",
            category="general",
            priority="normal",
            silent=False,
            dedupe_key=None,
            target_type=None,
            target_id=None,
            target_action=None,
            send_time=None,
            status="queued",
            dispatch_claimed_at=None,
            status_detail=None,
            delivered_at=None,
            opened_at=None,
            dismissed_at=None,
            failed_at=None,
            created_at=get_local_now(),
            updated_at=get_local_now(),
        )
        service.notification_dao.list_due_notifications = AsyncMock(return_value=[notification])
        service.notification_dao.get_by_id = AsyncMock(return_value=notification)
        service.notification_dao.save = AsyncMock(return_value=True)
        service.push_service.send_app_notification = AsyncMock(
            return_value={"success": 1, "failed": 0, "skipped": 0}
        )
        service._is_user_conversation_active = AsyncMock(return_value=False)
        service._insert_notification_as_conversation_message = AsyncMock()

        with patch("services.notification.redis.lock", _fake_lock):
            dispatched = await service.dispatch_due_notifications(limit=10)

        self.assertEqual(dispatched, 1)
        self.assertEqual(notification.status, "sent")
        self.assertIsNone(notification.dispatch_claimed_at)
        self.assertIsNotNone(notification.delivered_at)
        self.assertEqual(service.notification_dao.save.await_count, 2)
        service._insert_notification_as_conversation_message.assert_awaited_once_with(
            notification
        )

    async def test_dispatch_due_notification_mirrors_message_on_push_failure(self) -> None:
        service = NotificationService()
        notification = SimpleNamespace(
            notification_id="ntf_failed",
            user_id="user-1",
            title="Title",
            body="Body",
            category="general",
            priority="normal",
            silent=False,
            dedupe_key=None,
            target_type=None,
            target_id=None,
            target_action=None,
            send_time=None,
            status="queued",
            dispatch_claimed_at=None,
            status_detail=None,
            delivered_at=None,
            opened_at=None,
            dismissed_at=None,
            failed_at=None,
            created_at=get_local_now(),
            updated_at=get_local_now(),
        )
        service.notification_dao.list_due_notifications = AsyncMock(return_value=[notification])
        service.notification_dao.get_by_id = AsyncMock(return_value=notification)
        service.notification_dao.save = AsyncMock(return_value=True)
        service.push_service.send_app_notification = AsyncMock(
            return_value={"success": 0, "failed": 1, "skipped": 0}
        )
        service._is_user_conversation_active = AsyncMock(return_value=False)
        service._insert_notification_as_conversation_message = AsyncMock()

        with patch("services.notification.redis.lock", _fake_lock):
            dispatched = await service.dispatch_due_notifications(limit=10)

        self.assertEqual(dispatched, 1)
        self.assertEqual(notification.status, "failed")
        self.assertIsNotNone(notification.failed_at)
        service._insert_notification_as_conversation_message.assert_awaited_once_with(
            notification
        )

    async def test_dispatch_due_notification_skips_agent_completion_control_notification(self) -> None:
        service = NotificationService()
        notification = SimpleNamespace(
            notification_id="ntf_agent_done",
            user_id="user-1",
            title="Ling",
            body="Ling has completed your request",
            category=constants.NOTIFICATION_CATEGORY_AGENT_COMPLETION,
            priority="normal",
            silent=False,
            dedupe_key="agent_completion:content:abc",
            target_type=None,
            target_id=None,
            target_action=None,
            send_time=None,
            status=constants.NOTIFICATION_STATUS_QUEUED,
            dispatch_claimed_at=None,
            status_detail=None,
            delivered_at=None,
            opened_at=None,
            dismissed_at=None,
            failed_at=None,
            created_at=get_local_now(),
            updated_at=get_local_now(),
        )
        service.notification_dao.list_due_notifications = AsyncMock(
            return_value=[notification]
        )
        service.notification_dao.get_by_id = AsyncMock(return_value=notification)
        service.notification_dao.save = AsyncMock(return_value=True)
        service.push_service.send_app_notification = AsyncMock()
        service._insert_notification_as_conversation_message = AsyncMock()

        with patch("services.notification.redis.lock", _fake_lock):
            dispatched = await service.dispatch_due_notifications(limit=10)

        self.assertEqual(dispatched, 0)
        self.assertEqual(notification.status, constants.NOTIFICATION_STATUS_QUEUED)
        service.push_service.send_app_notification.assert_not_awaited()
        service._insert_notification_as_conversation_message.assert_not_awaited()

    async def test_dispatch_due_notification_waits_when_user_is_chatting(self) -> None:
        service = NotificationService()
        notification = SimpleNamespace(
            notification_id="ntf_chatting",
            user_id="user-1",
            title="Title",
            body="Body",
            category="general",
            priority="normal",
            silent=False,
            dedupe_key=None,
            target_type=None,
            target_id=None,
            target_action=None,
            send_time=None,
            status="queued",
            dispatch_claimed_at=None,
            status_detail=None,
            delivered_at=None,
            opened_at=None,
            dismissed_at=None,
            failed_at=None,
            created_at=get_local_now(),
            updated_at=get_local_now(),
        )
        service.notification_dao.list_due_notifications = AsyncMock(return_value=[notification])
        service.notification_dao.get_by_id = AsyncMock(return_value=notification)
        service.notification_dao.save = AsyncMock(return_value=True)
        service._is_user_conversation_active = AsyncMock(return_value=True)
        service.push_service.send_app_notification = AsyncMock()

        with patch("services.notification.redis.lock", _fake_lock):
            dispatched = await service.dispatch_due_notifications(limit=10)

        self.assertEqual(dispatched, 0)
        self.assertEqual(notification.status, "queued")
        self.assertIsNone(notification.dispatch_claimed_at)
        self.assertEqual(
            notification.status_detail,
            "Waiting for active conversation to finish",
        )
        service.push_service.send_app_notification.assert_not_awaited()

    async def test_dispatch_notification_by_id_keeps_future_notification_queued(self) -> None:
        service = NotificationService()
        notification = SimpleNamespace(
            notification_id="ntf_2",
            user_id="user-1",
            title="Title",
            body="Body",
            category="general",
            priority="normal",
            silent=False,
            dedupe_key=None,
            target_type=None,
            target_id=None,
            target_action=None,
            send_time=get_local_now() + timedelta(minutes=10),
            status="queued",
            dispatch_claimed_at=None,
            status_detail=None,
            delivered_at=None,
            opened_at=None,
            dismissed_at=None,
            failed_at=None,
            created_at=get_local_now(),
            updated_at=get_local_now(),
        )
        service.notification_dao.get_by_id = AsyncMock(return_value=notification)
        service.push_service.send_app_notification = AsyncMock()

        result = await service.dispatch_notification_by_id("ntf_2")

        self.assertEqual(result["status"], "queued")
        service.push_service.send_app_notification.assert_not_awaited()

    async def test_insert_notification_message_is_idempotent(self) -> None:
        service = NotificationService()
        notification = SimpleNamespace(
            notification_id="ntf_existing_message",
            user_id="user-1",
            title="Title",
            body="Body",
            category="general",
            priority="normal",
            status=constants.NOTIFICATION_STATUS_FAILED,
            status_detail="Push delivery failed for 1 device(s)",
            target_type=None,
            target_id=None,
            target_action=None,
        )
        session = SimpleNamespace(
            session_id="session-1",
            last_message_at=None,
        )
        session_dao = SimpleNamespace(
            get_or_create_user_session=AsyncMock(return_value=session),
            save=AsyncMock(),
        )
        message_dao = SimpleNamespace(
            get_session_message=AsyncMock(return_value=SimpleNamespace()),
            insert=AsyncMock(),
        )
        push_device_dao = SimpleNamespace(
            get_latest_device=AsyncMock(
                return_value=SimpleNamespace(timezone=constants.DEFAULT_TIMEZONE)
            )
        )
        user_config_dao = SimpleNamespace(get_config=AsyncMock(return_value={}))

        with (
            patch("models.agent.AgentSessionDao", return_value=session_dao),
            patch("models.agent.AgentMessageDao", return_value=message_dao),
            patch("models.push.UserPushDeviceDao", return_value=push_device_dao),
            patch("models.user.UserConfigDao", return_value=user_config_dao),
            patch(
                "services.notification.get_app_config",
                return_value=SimpleNamespace(sage_agent_id="agent-1"),
            ),
        ):
            await service._insert_notification_as_conversation_message(notification)

        message_dao.get_session_message.assert_awaited_once_with(
            "user-1",
            "session-1",
            "msg_ntf_existing_message",
        )
        message_dao.insert.assert_not_awaited()
        session_dao.save.assert_not_awaited()


class NotificationDaoDueQueryTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.engine = create_async_engine("sqlite+aiosqlite:///:memory:", future=True)
        async with self.engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        self.session_factory = async_sessionmaker(
            bind=self.engine,
            autoflush=False,
            autocommit=False,
            expire_on_commit=False,
        )
        self.dao = NotificationDao()
        self.dao.db = self

    async def asyncTearDown(self) -> None:
        await self.engine.dispose()

    @asynccontextmanager
    async def get_session(self, autocommit: bool = True):
        session = self.session_factory()
        try:
            yield session
            if autocommit:
                await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()

    async def test_list_due_notifications_excludes_agent_completion_controls(self) -> None:
        ordinary = Notification(
            notification_id="ntf_regular",
            user_id="user-1",
            title="Title",
            body="Body",
            category=constants.DEFAULT_NOTIFICATION_CATEGORY,
            status=constants.NOTIFICATION_STATUS_QUEUED,
        )
        agent_completion = Notification(
            notification_id="ntf_agent_done",
            user_id="user-1",
            title="Ling",
            body="Done",
            category=constants.NOTIFICATION_CATEGORY_AGENT_COMPLETION,
            status=constants.NOTIFICATION_STATUS_QUEUED,
        )
        async with self.get_session() as session:
            session.add_all([ordinary, agent_completion])

        due = await self.dao.list_due_notifications(now=get_local_now(), limit=10)

        self.assertEqual([item.notification_id for item in due], ["ntf_regular"])


if __name__ == "__main__":
    unittest.main()
