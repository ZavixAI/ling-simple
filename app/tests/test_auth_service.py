from __future__ import annotations

import unittest
from contextlib import asynccontextmanager
from dataclasses import replace
from datetime import timedelta
from unittest.mock import AsyncMock, Mock, patch

import services.auth.auth as auth_module
import app.api.routers.auth as auth_router
from config import constants
from core.http.exceptions import AppHTTPException
from core.infra.redis import redis
from fastapi.security import HTTPAuthorizationCredentials
from models.base import get_local_now
from models.push import UserPushDevice
from models.user import User, UserExternalIdentity
from services.auth.auth import AuthService
from services.auth.external_providers import ExternalIdentityPayload
from services.auth.state_store import RedisAccessTokenState, RedisRefreshTokenState
from starlette.requests import Request

import app.core.http.dependencies as dependencies_module


@asynccontextmanager
async def _fake_transaction_session(session=None):
    yield session or object()


@asynccontextmanager
async def _fake_redis_lock_context(*args, **kwargs):
    yield


def _push_device_payload(device_id: str = "device-1") -> dict[str, object]:
    return {
        "device_id": device_id,
        "platform": "ios",
        "transport": "apns",
        "push_token": "push-token",
        "app_bundle_id": "com.ling.test",
        "locale": "zh-CN",
        "timezone": constants.DEFAULT_TIMEZONE,
        "device_model": "iPhone16,2",
        "notifications_enabled": True,
    }


class AuthRouterTokenTests(unittest.IsolatedAsyncioTestCase):
    async def test_sms_challenge_creates_challenge(self) -> None:
        with patch.object(auth_router, "AuthService") as auth_cls:
            auth_cls.return_value.create_sms_challenge = AsyncMock(
                return_value={"challenge_id": "challenge-1"}
            )
            response = await auth_router.create_sms_challenge(
                auth_router.SmsChallengeRequest(
                    phone="13800138000",
                )
            )

        self.assertEqual(response.data["challenge_id"], "challenge-1")

    async def test_non_refresh_token_exchanges_code(self) -> None:
        token_payload = {
            "token_type": "Bearer",
            "access_token": "access",
            "refresh_token": "refresh",
            "expires_in": 3600,
            "scope": "openid profile",
            "user": {"user_id": "user-1"},
            "identities": [],
        }
        with patch.object(auth_router, "AuthService") as auth_cls:
            auth_cls.return_value.exchange_email_code = AsyncMock(
                return_value=token_payload
            )
            response = await auth_router.exchange_oauth2_token(
                auth_router.TokenRequest(
                    grant_type="email_code",
                    email="user@example.com",
                    code="123456",
                    push_device=_push_device_payload(),
                )
            )

        self.assertEqual(response.data["access_token"], "access")

    async def test_refresh_token_returns_new_access_token(self) -> None:
        token_payload = {
            "token_type": "Bearer",
            "access_token": "access",
            "refresh_token": "refresh",
            "expires_in": 3600,
            "scope": "openid profile",
        }
        with patch.object(auth_router, "AuthService") as auth_cls:
            auth_cls.return_value.refresh_access_token = AsyncMock(
                return_value=token_payload
            )
            response = await auth_router.exchange_oauth2_token(
                auth_router.TokenRequest(
                    grant_type="refresh_token",
                    refresh_token="refresh",
                )
            )

        self.assertEqual(response.data["access_token"], "access")


class AuthServiceSmsCodeTests(unittest.IsolatedAsyncioTestCase):
    def _make_service(self) -> AuthService:
        service = AuthService()
        service.cfg = replace(
            service.cfg,
            admin_phone_whitelist="+8619965269038",
        )
        service._get_or_create_local_user = AsyncMock(
            return_value=(
                User(user_id="user-1", username="u1", password_hash="x"),
                False,
            )
        )
        service._build_auth_payload = AsyncMock(
            return_value={
                "token_type": "Bearer",
                "access_token": "access",
                "refresh_token": "refresh",
                "user": {"user_id": "user-1"},
                "identities": [],
            }
        )
        service._verify_sms_challenge = AsyncMock()
        return service

    async def test_admin_whitelist_phone_can_login_with_static_code_without_challenge(
        self,
    ) -> None:
        service = self._make_service()

        payload = await service.exchange_sms_code(
            "19965269038",
            None,
            "111111",
            "openid profile",
            phone_area_code="+86",
            push_device=_push_device_payload(),
        )

        self.assertEqual(payload["access_token"], "access")
        service._verify_sms_challenge.assert_not_awaited()
        service._get_or_create_local_user.assert_awaited_once()
        self.assertEqual(
            service._get_or_create_local_user.await_args.kwargs["login_type"],
            "admin_whitelist_code",
        )

    async def test_non_whitelist_static_code_still_requires_challenge(self) -> None:
        service = self._make_service()

        with self.assertRaises(AppHTTPException) as caught:
            await service.exchange_sms_code(
                "13900000000",
                None,
                "111111",
                "openid profile",
                phone_area_code="+86",
                push_device=_push_device_payload(),
            )

        self.assertEqual(caught.exception.status_code, 422)
        service._verify_sms_challenge.assert_not_awaited()
        service._get_or_create_local_user.assert_not_awaited()


class AuthServiceExternalIdentityTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self._original_transaction_scope = auth_module.transaction_scope
        auth_module.transaction_scope = _fake_transaction_session

    def tearDown(self) -> None:
        auth_module.transaction_scope = self._original_transaction_scope

    def _make_service(self) -> AuthService:
        service = AuthService()
        service.user_dao.get_by_id = AsyncMock(return_value=None)
        service.user_dao.get_by_email = AsyncMock(return_value=None)
        service.user_dao.get_by_phone = AsyncMock(return_value=None)
        service.user_dao.get_by_username = AsyncMock(return_value=None)
        service.user_dao.insert = AsyncMock()
        service.user_dao.save = AsyncMock()
        service.user_config_dao.get_config = AsyncMock(return_value={})
        service.identity_dao.get_by_provider_subject = AsyncMock(return_value=None)
        service.identity_dao.insert = AsyncMock()
        service.identity_dao.save = AsyncMock()
        service.identity_dao.list_by_user_id = AsyncMock(return_value=[])
        service.ling_dao.get_by_user_id = AsyncMock(return_value=None)
        service.state_store.get_refresh_token = AsyncMock(return_value=None)
        service.state_store.save_refresh_token = AsyncMock()
        service.state_store.save_access_token = AsyncMock()
        service.state_store.delete_access_tokens_by_device = AsyncMock(return_value=0)
        service.state_store.delete_access_tokens_by_user = AsyncMock(return_value=0)
        service.state_store.delete_refresh_tokens_by_user = AsyncMock(return_value=0)
        service._build_auth_payload = AsyncMock(
            return_value={
                "token_type": "Bearer",
                "access_token": "access-token",
                "refresh_token": "refresh-token",
                "scope": "openid profile",
                "is_new_user": True,
            }
        )
        service._build_unique_username_from_external_identity = AsyncMock(
            return_value="apple_user"
        )
        service._create_default_user_config = AsyncMock()
        service._issue_tokens = AsyncMock(
            return_value={
                "token_type": "Bearer",
                "access_token": "new-access-token",
                "refresh_token": "new-refresh-token",
                "expires_in": 3600,
                "scope": "openid profile",
            }
        )
        return service

    async def test_exchange_apple_identity_token_creates_new_user_without_auto_merge(
        self,
    ) -> None:
        service = self._make_service()
        existing_user = User(
            user_id="u_local",
            username="existing-user",
            password_hash="hash",
            email="same@example.com",
        )
        service.user_dao.get_by_email = AsyncMock(return_value=existing_user)
        service.external_auth_service.verify_apple_identity_token = AsyncMock(
            return_value=ExternalIdentityPayload(
                provider_id="apple",
                provider_subject="apple-subject-1",
                provider_username="same@example.com",
                provider_email="same@example.com",
                nickname="Apple Ling",
                profile={"email": "same@example.com"},
            )
        )

        payload = await service.exchange_apple_identity_token(
            "identity-token",
            "openid profile",
            push_device=_push_device_payload(),
        )

        inserted_user = service.user_dao.insert.await_args.args[0]
        inserted_identity = service.identity_dao.insert.await_args.args[0]
        build_args = service._build_auth_payload.await_args

        self.assertEqual(payload["is_new_user"], True)
        self.assertNotEqual(inserted_user.user_id, existing_user.user_id)
        self.assertEqual(inserted_user.nickname, "Apple Ling")
        self.assertIsNone(inserted_user.email)
        self.assertEqual(inserted_identity.provider_id, "apple")
        self.assertEqual(inserted_identity.provider_subject, "apple-subject-1")
        self.assertIs(build_args.args[0], inserted_user)
        self.assertEqual(build_args.kwargs["provider_id"], "apple")
        self.assertEqual(build_args.kwargs["is_new_user"], True)
        self.assertEqual(build_args.kwargs["push_device"], _push_device_payload())
        service.user_dao.get_by_email.assert_not_awaited()

    async def test_exchange_apple_identity_token_reuses_existing_identity_user(
        self,
    ) -> None:
        service = self._make_service()
        existing_user = User(
            user_id="u_apple",
            username="apple-user",
            password_hash="hash",
        )
        existing_identity = UserExternalIdentity(
            identity_id="ident_apple",
            user_id="u_apple",
            provider_id="apple",
            provider_subject="apple-subject-2",
            provider_username="old@example.com",
            provider_email=None,
            profile={"login_type": "apple_identity_token"},
        )
        service.identity_dao.get_by_provider_subject = AsyncMock(
            side_effect=[existing_identity, existing_identity]
        )
        service.user_dao.get_by_id = AsyncMock(return_value=existing_user)
        service._build_auth_payload = AsyncMock(
            return_value={
                "token_type": "Bearer",
                "access_token": "access-token",
                "refresh_token": "refresh-token",
                "scope": "openid profile",
                "is_new_user": False,
            }
        )
        service.external_auth_service.verify_apple_identity_token = AsyncMock(
            return_value=ExternalIdentityPayload(
                provider_id="apple",
                provider_subject="apple-subject-2",
                provider_username="apple@example.com",
                provider_email="apple@example.com",
                nickname="Updated Apple Name",
                avatar_url="https://cdn.example.com/apple.png",
                profile={"email": "apple@example.com"},
            )
        )

        payload = await service.exchange_apple_identity_token(
            "identity-token",
            "openid profile",
            push_device=_push_device_payload(),
        )

        self.assertEqual(payload["is_new_user"], False)
        self.assertEqual(existing_user.nickname, "Updated Apple Name")
        self.assertEqual(existing_user.avatar_url, "https://cdn.example.com/apple.png")
        service.user_dao.insert.assert_not_awaited()
        service.identity_dao.insert.assert_not_awaited()
        service.identity_dao.save.assert_awaited_once()
        service.user_dao.save.assert_awaited_once()
        service._build_auth_payload.assert_awaited_once_with(
            existing_user,
            scope="openid profile",
            is_new_user=False,
            provider_id="apple",
            push_device=_push_device_payload(),
        )

    async def test_bind_identity_rejects_conflict_with_another_user(self) -> None:
        service = self._make_service()
        current_user = User(
            user_id="u_current",
            username="current-user",
            password_hash="hash",
        )
        conflict_identity = UserExternalIdentity(
            identity_id="ident_conflict",
            user_id="u_other",
            provider_id="apple",
            provider_subject="apple-subject-3",
        )
        service.identity_dao.get_by_provider_subject = AsyncMock(
            return_value=conflict_identity
        )
        service.external_auth_service.verify_apple_identity_token = AsyncMock(
            return_value=ExternalIdentityPayload(
                provider_id="apple",
                provider_subject="apple-subject-3",
                provider_username="apple@example.com",
            )
        )

        with self.assertRaises(AppHTTPException) as ctx:
            await service.bind_identity(
                current_user,
                provider_id="apple",
                apple_identity_token="identity-token",
            )

        self.assertEqual(ctx.exception.status_code, 409)
        self.assertEqual(ctx.exception.error_code, "identity_already_exists")
        service.identity_dao.insert.assert_not_awaited()

    async def test_refresh_access_token_reissues_with_original_provider(self) -> None:
        service = self._make_service()
        now = get_local_now()
        refresh_state = RedisRefreshTokenState(
            token_id="rtid_1",
            user_id="u_wechat",
            provider_id="wechat",
            token_hash="token-hash",
            scope="openid profile",
            expire_at=now + timedelta(days=7),
            revoked_at=None,
            last_used_at=None,
            created_at=now,
            updated_at=now,
            extra_data={"device_id": "device-1"},
        )
        current_user = User(
            user_id="u_wechat",
            username="wechat-user",
            password_hash="hash",
        )
        service.state_store.get_refresh_token = AsyncMock(return_value=refresh_state)
        service.user_dao.get_by_id = AsyncMock(return_value=current_user)
        service.push_device_dao.get_user_device = AsyncMock(
            return_value=UserPushDevice(
                device_id="device-1",
                user_id="u_wechat",
                platform="ios",
                transport="apns",
                push_token="push-token",
            )
        )

        with patch.object(redis, "lock_or_raise", _fake_redis_lock_context):
            payload = await service.refresh_access_token("raw-refresh-token")

        self.assertEqual(payload["access_token"], "new-access-token")
        self.assertEqual(payload["refresh_token"], "new-refresh-token")
        self.assertEqual(payload["identities"], [])
        self.assertIsNotNone(refresh_state.revoked_at)
        self.assertIsNotNone(refresh_state.last_used_at)
        service.state_store.get_refresh_token.assert_awaited_once_with(
            service._hash_token("raw-refresh-token")
        )
        service.state_store.save_refresh_token.assert_awaited_once()
        service.state_store.delete_access_tokens_by_device.assert_awaited_once_with(
            "u_wechat",
            "device-1",
        )
        service._issue_tokens.assert_awaited_once_with(
            current_user,
            scope="openid profile",
            provider_id="wechat",
            device_id="device-1",
        )

    async def test_refresh_access_token_rejects_deleted_user(self) -> None:
        service = self._make_service()
        now = get_local_now()
        refresh_state = RedisRefreshTokenState(
            token_id="rtid_deleted",
            user_id="u_deleted",
            provider_id="email",
            token_hash="token-hash",
            scope="openid profile",
            expire_at=now + timedelta(days=7),
            revoked_at=None,
            last_used_at=None,
            created_at=now,
            updated_at=now,
            extra_data={"device_id": "device-1"},
        )
        service.state_store.get_refresh_token = AsyncMock(return_value=refresh_state)
        service.user_dao.get_by_id = AsyncMock(return_value=None)

        with patch.object(redis, "lock_or_raise", _fake_redis_lock_context):
            with self.assertRaises(AppHTTPException) as ctx:
                await service.refresh_access_token("raw-refresh-token")

        self.assertEqual(ctx.exception.status_code, 401)
        self.assertEqual(ctx.exception.detail, "User not found")
        service._issue_tokens.assert_not_awaited()

    async def test_delete_account_schedules_external_cleanups_after_core_deletion(self) -> None:
        service = self._make_service()
        user = User(
            user_id="u_delete",
            username="delete-user",
            password_hash="hash",
        )
        calls: list[str] = []

        service.state_store.delete_refresh_tokens_by_user = AsyncMock(
            side_effect=lambda *args, **kwargs: calls.append("refresh_tokens")
        )
        service.identity_dao.delete_where = AsyncMock(
            side_effect=lambda *args, **kwargs: calls.append("identities")
        )
        service.user_config_dao.delete_where = AsyncMock(
            side_effect=lambda *args, **kwargs: calls.append("user_config")
        )
        service.calendar_link_dao.delete_where = AsyncMock(
            side_effect=lambda *args, **kwargs: calls.append("calendar_links")
        )
        service.calendar_context_dao.delete_where = AsyncMock(
            side_effect=lambda *args, **kwargs: calls.append("calendar_context")
        )
        service.calendar_provider_connection_dao.delete_where = AsyncMock(
            side_effect=lambda *args, **kwargs: calls.append("calendar_provider_connections")
        )
        service.calendar_event_dao.delete_where = AsyncMock(
            side_effect=lambda *args, **kwargs: calls.append("calendar_events")
        )
        service.push_device_dao.delete_where = AsyncMock(
            side_effect=lambda *args, **kwargs: calls.append("user_push_devices")
        )
        service.agent_message_dao.delete_where = AsyncMock(
            side_effect=lambda *args, **kwargs: calls.append("agent_messages")
        )
        service.agent_session_dao.delete_where = AsyncMock(
            side_effect=lambda *args, **kwargs: calls.append("agent_sessions")
        )
        service.user_dao.save = AsyncMock(
            side_effect=lambda *args, **kwargs: calls.append("user_soft_delete")
        )
        service._schedule_user_uploads_cleanup = Mock(
            side_effect=lambda **_: calls.append("uploads_schedule")
        )
        service._schedule_sage_workspace_cleanup = Mock(
            side_effect=lambda **_: calls.append("sage_schedule")
        )

        with patch.object(redis, "delete", AsyncMock(return_value=0)) as redis_delete:
            payload = await service.delete_account(
                user,
            )

        self.assertEqual(payload["deleted"], True)
        self.assertEqual(payload["user_id"], "u_delete")
        self.assertEqual(calls[-1], "sage_schedule")
        self.assertEqual(
            calls,
            [
                "identities",
                "user_config",
                "calendar_links",
                "calendar_context",
                "calendar_provider_connections",
                "calendar_events",
                "user_push_devices",
                "agent_messages",
                "agent_sessions",
                "user_soft_delete",
                "refresh_tokens",
                "uploads_schedule",
                "sage_schedule",
            ],
        )
        self.assertEqual(user.status, constants.USER_STATUS_DELETED)
        self.assertIsNotNone(user.deleted_at)
        self.assertEqual(user.username, "deleted_u_delete")
        self.assertIsNone(user.email)
        self.assertIsNone(user.phonenum)
        redis_delete.assert_awaited_once_with("ling:membership:entitlement:u_delete")
        service._schedule_user_uploads_cleanup.assert_called_once_with(
            user_id="u_delete",
        )
        service._schedule_sage_workspace_cleanup.assert_called_once_with(
            user_id="u_delete",
        )

    async def test_delete_account_deletes_all_supported_user_scoped_records(self) -> None:
        service = self._make_service()
        user = User(
            user_id="u_delete",
            username="delete-user",
            password_hash="hash",
        )

        service.state_store.delete_refresh_tokens_by_user = AsyncMock()
        service.identity_dao.delete_where = AsyncMock()
        service.user_config_dao.delete_where = AsyncMock()
        service.calendar_link_dao.delete_where = AsyncMock()
        service.calendar_context_dao.delete_where = AsyncMock()
        service.calendar_provider_connection_dao.delete_where = AsyncMock()
        service.calendar_event_dao.delete_where = AsyncMock()
        service.push_device_dao.delete_where = AsyncMock()
        service.agent_message_dao.delete_where = AsyncMock()
        service.agent_session_dao.delete_where = AsyncMock()
        service.user_dao.save = AsyncMock()
        service._schedule_user_uploads_cleanup = Mock()
        service._schedule_sage_workspace_cleanup = Mock()

        with patch.object(redis, "delete", AsyncMock(return_value=0)):
            await service.delete_account(user)

        self.assertFalse(service.identity_dao.delete_where.await_args.kwargs["session"] is None)
        self.assertEqual(
            service.state_store.delete_refresh_tokens_by_user.await_args.args,
            ("u_delete",),
        )
        delete_where_calls = [
            service.identity_dao.delete_where.await_args,
            service.user_config_dao.delete_where.await_args,
            service.calendar_link_dao.delete_where.await_args,
            service.calendar_context_dao.delete_where.await_args,
            service.calendar_provider_connection_dao.delete_where.await_args,
            service.calendar_event_dao.delete_where.await_args,
            service.push_device_dao.delete_where.await_args,
            service.agent_message_dao.delete_where.await_args,
            service.agent_session_dao.delete_where.await_args,
        ]
        for call in delete_where_calls:
            self.assertEqual(len(call.args), 2)
            self.assertEqual(str(call.args[1][0].right.value), "u_delete")
            self.assertIn("session", call.kwargs)
            self.assertIsNotNone(call.kwargs["session"])

        self.assertIs(service.user_dao.save.await_args.args[0], user)
        self.assertEqual(user.status, constants.USER_STATUS_DELETED)
        self.assertIsNotNone(user.deleted_at)
        self.assertEqual(user.username, "deleted_u_delete")
        self.assertIsNone(user.nickname)
        self.assertIsNone(user.email)
        self.assertIsNone(user.phonenum)
        self.assertIsNone(user.phone_area_code)
        self.assertIsNone(user.avatar_url)
        self.assertTrue(user.password_hash.startswith("!deleted-"))
        self.assertIn("session", service.user_dao.save.await_args.kwargs)
        service._schedule_user_uploads_cleanup.assert_called_once_with(
            user_id="u_delete",
        )
        service._schedule_sage_workspace_cleanup.assert_called_once_with(
            user_id="u_delete",
        )


class AuthServiceBuildAuthPayloadTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self._original_lock_or_raise = auth_module.redis.lock_or_raise
        auth_module.redis.lock_or_raise = _fake_redis_lock_context

    def tearDown(self) -> None:
        auth_module.redis.lock_or_raise = self._original_lock_or_raise

    async def test_build_auth_payload_fires_user_created_for_new_user(self) -> None:
        service = AuthService()
        service.identity_dao.list_by_user_id = AsyncMock(return_value=[])
        service.user_config_dao.get_config = AsyncMock(return_value={})
        service.state_store.delete_refresh_tokens_by_user = AsyncMock(return_value=0)
        service.state_store.delete_access_tokens_by_user = AsyncMock(return_value=0)
        service._register_login_push_device = AsyncMock(
            return_value={"device_id": "device-1"}
        )
        service._issue_tokens = AsyncMock(
            return_value={
                "token_type": "Bearer",
                "access_token": "tok",
                "refresh_token": "ref",
                "expires_in": 3600,
                "scope": "openid profile",
            }
        )
        user = User(
            user_id="u_new",
            username="u_new",
            password_hash="hash",
        )
        payload = await service._build_auth_payload(
            user,
            scope="openid profile",
            is_new_user=True,
            provider_id="apple",
            push_device=_push_device_payload(),
        )

        self.assertTrue(payload["is_new_user"])
        service._register_login_push_device.assert_awaited_once_with(
            user_id="u_new",
            push_device=_push_device_payload(),
        )
        service.state_store.delete_refresh_tokens_by_user.assert_awaited_once_with(
            "u_new"
        )
        service.state_store.delete_access_tokens_by_user.assert_awaited_once_with(
            "u_new"
        )
        service._issue_tokens.assert_awaited_once_with(
            user,
            scope="openid profile",
            provider_id="apple",
            device_id="device-1",
        )

    async def test_build_auth_payload_marks_returning_user(self) -> None:
        service = AuthService()
        service.identity_dao.list_by_user_id = AsyncMock(return_value=[])
        service.user_config_dao.get_config = AsyncMock(return_value={})
        service.state_store.delete_refresh_tokens_by_user = AsyncMock(return_value=0)
        service.state_store.delete_access_tokens_by_user = AsyncMock(return_value=0)
        service._register_login_push_device = AsyncMock(
            return_value={"device_id": "device-1"}
        )
        service._issue_tokens = AsyncMock(
            return_value={
                "token_type": "Bearer",
                "access_token": "tok",
                "refresh_token": "ref",
                "expires_in": 3600,
                "scope": "openid profile",
            }
        )
        user = User(
            user_id="u_existing",
            username="u_existing",
            password_hash="hash",
        )
        payload = await service._build_auth_payload(
            user,
            scope="openid profile",
            is_new_user=False,
            provider_id="apple",
            push_device=_push_device_payload(),
        )

        self.assertFalse(payload["is_new_user"])

    async def test_build_auth_payload_requires_push_device(self) -> None:
        service = AuthService()
        user = User(
            user_id="u_existing",
            username="u_existing",
            password_hash="hash",
        )

        with self.assertRaises(AppHTTPException) as ctx:
            await service._build_auth_payload(
                user,
                scope="openid profile",
                is_new_user=False,
                provider_id="apple",
                push_device=None,
            )

        self.assertEqual(ctx.exception.status_code, 422)

    async def test_issue_tokens_binds_device_id_to_access_and_refresh_tokens(self) -> None:
        service = AuthService()
        service.state_store.save_access_token = AsyncMock()
        service.state_store.save_refresh_token = AsyncMock()
        user = User(
            user_id="u_existing",
            username="u_existing",
            password_hash="hash",
        )

        payload = await service._issue_tokens(
            user,
            scope="openid profile",
            provider_id="apple",
            device_id="device-1",
        )

        self.assertTrue(payload["access_token"].startswith("at_"))
        self.assertTrue(payload["refresh_token"].startswith("rt_"))
        self.assertEqual(payload["device_id"], "device-1")
        saved_access_token = service.state_store.save_access_token.await_args.args[0]
        self.assertIsInstance(saved_access_token, RedisAccessTokenState)
        self.assertEqual(saved_access_token.user_id, "u_existing")
        self.assertEqual(saved_access_token.provider_id, "apple")
        self.assertEqual(saved_access_token.scope, "openid profile")
        self.assertEqual(saved_access_token.device_id, "device-1")
        self.assertEqual(saved_access_token.user_data["username"], "u_existing")
        saved_token = service.state_store.save_refresh_token.await_args.args[0]
        self.assertEqual(saved_token.extra_data["device_id"], "device-1")


class RequireCurrentUserOpaqueTokenTests(unittest.IsolatedAsyncioTestCase):
    async def test_require_current_user_rejects_non_opaque_access_token(self) -> None:
        request = Request({"type": "http", "headers": []})

        with self.assertRaises(AppHTTPException) as ctx:
            await dependencies_module.require_current_user(
                request,
                HTTPAuthorizationCredentials(
                    scheme="Bearer",
                    credentials="legacy.jwt.token",
                ),
            )

        self.assertEqual(ctx.exception.status_code, 401)
        self.assertEqual(ctx.exception.detail, "Invalid token")

    async def test_require_current_user_rejects_admin_opaque_access_token(self) -> None:
        state_store = Mock()
        state_store.get_access_token = AsyncMock(
            return_value=RedisAccessTokenState(
                token_id="token-1",
                user_id="+8613800000000",
                provider_id="admin_sms",
                token_hash="hash",
                scope="admin",
                device_id="admin",
                expire_at=get_local_now() + timedelta(hours=1),
                created_at=get_local_now(),
                updated_at=get_local_now(),
                user_data={"username": "+8613800000000"},
                extra_data={"typ": "admin", "phone": "+8613800000000"},
            )
        )
        request = Request({"type": "http", "headers": []})

        with patch.object(
            dependencies_module,
            "RedisAuthStateStore",
            return_value=state_store,
        ):
            with self.assertRaises(AppHTTPException) as ctx:
                await dependencies_module.require_current_user(
                    request,
                    HTTPAuthorizationCredentials(
                        scheme="Bearer",
                        credentials="at_admin",
                    ),
                )

        self.assertEqual(ctx.exception.status_code, 401)
        self.assertEqual(ctx.exception.detail, "Invalid token")

    async def test_require_current_user_resolves_opaque_access_token(self) -> None:
        state_store = Mock()
        state_store.get_access_token = AsyncMock(
            return_value=RedisAccessTokenState(
                token_id="token-1",
                user_id="user-1",
                provider_id="email",
                token_hash="hash",
                scope="openid profile",
                device_id="device-1",
                expire_at=get_local_now() + timedelta(hours=1),
                created_at=get_local_now(),
                updated_at=get_local_now(),
                user_data={
                    "username": "user-1",
                    "nickname": "Ling",
                    "role": "user",
                },
            )
        )
        request = Request({"type": "http", "headers": []})

        with patch.object(
            dependencies_module,
            "RedisAuthStateStore",
            return_value=state_store,
        ):
            user = await dependencies_module.require_current_user(
                request,
                HTTPAuthorizationCredentials(
                    scheme="Bearer",
                    credentials="at_opaque",
                ),
            )

        self.assertEqual(user.user_id, "user-1")
        self.assertEqual(user.nickname, "Ling")
        self.assertEqual(request.state.user_claims["device_id"], "device-1")
        state_store.get_access_token.assert_awaited_once()


if __name__ == "__main__":
    unittest.main()
