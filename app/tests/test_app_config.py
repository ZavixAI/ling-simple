from __future__ import annotations

import os
import tempfile
import unittest
from unittest.mock import patch

from api.router import router
from config import constants
from config.settings import AppConfig, build_app_config
from core.infra.db import SessionManager


class AppConfigCleanupTests(unittest.TestCase):
    def _build_config_with_temp_dirs(
        self,
        extra_env: dict[str, str] | None = None,
    ) -> AppConfig:
        with tempfile.TemporaryDirectory() as tmpdir:
            env = {
                "LING_LOGS_DIR": os.path.join(tmpdir, "logs"),
            }
            if extra_env:
                env.update(extra_env)

            with patch.dict(os.environ, env, clear=True):
                return build_app_config()

    def test_build_app_config_excludes_removed_backend_fields(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            env = {
                "LING_LOGS_DIR": os.path.join(tmpdir, "logs"),
                "LING_DATA_DIR": os.path.join(tmpdir, "ignored_data"),
                "LING_MYSQL_HOST": "mysql",
                "LING_MYSQL_USER": "ling",
                "LING_MYSQL_PASSWORD": "secret",
                "LING_MYSQL_DATABASE": "ling",
                "LING_REDIS_HOST": "redis",
                "LING_REDIS_PASSWORD": "redis-secret",
                "LING_API_PREFIX": "/ignored-prefix",
                "LING_DB_TYPE": "file",
                "LING_WECHAT_IOS_UNIVERSAL_LINK": "https://example.com/app",
                "LING_MYSQL_ROOT_PASSWORD": "root-secret",
                "LING_UPLOADS_DIR": os.path.join(tmpdir, "ignored_uploads"),
                "LING_HOST": "example.com",
            }

            with patch.dict(os.environ, env, clear=True):
                cfg = build_app_config()

        self.assertEqual(cfg.mysql_host, "mysql")
        self.assertEqual(cfg.redis_host, "redis")
        self.assertFalse(hasattr(cfg, "api_prefix"))
        self.assertFalse(hasattr(cfg, "data_dir"))
        self.assertFalse(hasattr(cfg, "db_type"))
        self.assertFalse(hasattr(cfg, "mysql_root_password"))
        self.assertFalse(hasattr(cfg, "uploads_dir"))
        self.assertFalse(hasattr(cfg, "wechat_ios_universal_link"))
        self.assertFalse(hasattr(cfg, "speech_token_domain"))
        self.assertFalse(hasattr(cfg, "speech_gateway_url"))
        self.assertFalse(hasattr(cfg, "speech_access_key_id"))
        self.assertFalse(hasattr(cfg, "speech_access_key_secret"))
        self.assertFalse(hasattr(cfg, "speech_security_token"))
        self.assertFalse(hasattr(cfg, "speech_app_key"))
        self.assertFalse(hasattr(cfg, "sms_security_token"))
        self.assertFalse(hasattr(cfg, "pns_security_token"))
        self.assertFalse(hasattr(cfg, "eml_security_token"))
        self.assertFalse(hasattr(cfg, "membership_beta_all_users_pro"))

    def test_build_app_config_uses_code_defaults_for_stable_values(self) -> None:
        cfg = self._build_config_with_temp_dirs()

        self.assertEqual(cfg.app_name, "ling")
        self.assertEqual(cfg.apple_issuer, "https://appleid.apple.com")
        self.assertEqual(cfg.apple_jwks_url, "https://appleid.apple.com/auth/keys")
        self.assertEqual(constants.APPLE_AUDIENCE_IOS, "top.withling.ling")
        self.assertEqual(cfg.mobile_oauth_callback_scheme, "ling-oauth")
        self.assertEqual(cfg.feishu_authorize_url, "https://accounts.feishu.cn/open-apis/authen/v1/authorize")
        self.assertEqual(cfg.feishu_token_url, "https://open.feishu.cn/open-apis/authen/v1/oidc/access_token")
        self.assertEqual(cfg.feishu_api_base_url, "https://open.feishu.cn/open-apis")
        self.assertEqual(cfg.feishu_ios_redirect_uri, "ling-oauth://calendar-auth/feishu")
        self.assertEqual(cfg.dingtalk_authorize_url, "https://login.dingtalk.com/oauth2/auth")
        self.assertEqual(cfg.dingtalk_token_url, "https://api.dingtalk.com/v1.0/oauth2/userAccessToken")
        self.assertEqual(cfg.dingtalk_api_base_url, "https://api.dingtalk.com")
        self.assertEqual(cfg.dingtalk_ios_redirect_uri, "ling-oauth://calendar-auth/dingtalk")
        self.assertEqual(cfg.ios_app_store_url, "https://testflight.apple.com/join/JfEr7hyq")
        self.assertEqual(cfg.apple_iap_bundle_id, "top.withling.ling")
        self.assertTrue(cfg.apple_iap_verify_signature)
        self.assertEqual(cfg.s3_endpoint_url, "https://oss-cn-shanghai.aliyuncs.com")
        self.assertEqual(cfg.s3_region, "cn-shanghai")
        self.assertEqual(cfg.s3_addressing_style, "path")
        self.assertEqual(cfg.sms_endpoint, "dysmsapi.aliyuncs.com")
        self.assertEqual(cfg.pns_endpoint, "dypnsapi.aliyuncs.com")
        self.assertEqual(cfg.eml_endpoint, "dm.aliyuncs.com")
        self.assertEqual(cfg.mysql_charset, "utf8mb4")
        self.assertEqual(cfg.notification_dispatch_batch_size, 20)

    def test_build_app_config_ignores_env_for_other_code_managed_defaults(self) -> None:
        cfg = self._build_config_with_temp_dirs(
            {
                "LING_APP_NAME": "custom-app",
                "LING_APPLE_ISSUER": "https://example.com/apple",
                "LING_APPLE_JWKS_URL": "https://example.com/jwks",
                "LING_FEISHU_AUTHORIZE_URL": "https://example.com/feishu/oauth",
                "LING_DINGTALK_API_BASE_URL": "https://example.com/dingtalk",
                "LING_IOS_APP_STORE_URL": "https://example.com/app",
                "LING_SMS_ENDPOINT": "sms.example.internal",
                "LING_PNS_ENDPOINT": "pns.example.internal",
                "LING_EML_ENDPOINT": "eml.example.internal",
                "LING_MYSQL_CHARSET": "latin1",
                "LING_REMINDER_DISPATCH_BATCH_SIZE": "8",
            }
        )

        self.assertEqual(cfg.app_name, "ling")
        self.assertEqual(cfg.apple_issuer, "https://appleid.apple.com")
        self.assertEqual(cfg.apple_jwks_url, "https://appleid.apple.com/auth/keys")
        self.assertEqual(cfg.feishu_authorize_url, "https://accounts.feishu.cn/open-apis/authen/v1/authorize")
        self.assertEqual(cfg.dingtalk_api_base_url, "https://api.dingtalk.com")
        self.assertEqual(cfg.ios_app_store_url, "https://testflight.apple.com/join/JfEr7hyq")
        self.assertEqual(cfg.sms_endpoint, "dysmsapi.aliyuncs.com")
        self.assertEqual(cfg.pns_endpoint, "dypnsapi.aliyuncs.com")
        self.assertEqual(cfg.eml_endpoint, "dm.aliyuncs.com")
        self.assertEqual(cfg.mysql_charset, "utf8mb4")
        self.assertEqual(cfg.notification_dispatch_batch_size, 20)

    def test_build_app_config_keeps_env_override_for_env_managed_values(self) -> None:
        cfg = self._build_config_with_temp_dirs(
            {
                "LING_PORT": "9000",
                "LING_MYSQL_HOST": "mysql.internal",
                "LING_MYSQL_PORT": "3307",
                "LING_REDIS_DB": "3",
                "LING_SMS_ACCESS_KEY_ID": "sms-ak",
                "LING_SMS_ACCESS_KEY_SECRET": "sms-secret",
                "LING_SMS_SIGN_NAME": "Ling",
                "LING_SMS_TEMPLATE_CODE": "SMS_001",
                "LING_WECHAT_APP_ID": "wx-dev-app",
                "LING_S3_ENDPOINT_URL": "https://oss-cn-hangzhou.aliyuncs.com",
                "LING_S3_REGION": "cn-hangzhou",
                "LING_S3_BUCKET": "ling-dev",
                "LING_S3_ADDRESSING_STYLE": "virtual",
                "LING_S3_PUBLIC_BASE_URL": "https://cdn.example.com",
                "LING_EML_TEMPLATE_ID": "TPL_001",
                "LING_SAGE_API_URL": "http://sage.internal/api/chat",
                "LING_SAGE_AGENT_ID": "agent_dev",
                "LING_HARMONY_PUSH_CLIENT_ID": "harmony-client",
                "LING_HARMONY_PUSH_CLIENT_SECRET": "harmony-secret",
                "LING_HARMONY_PUSH_APP_ID": "harmony-app",
                "LING_HARMONY_PUSH_ENDPOINT": "https://push.example.com/send",
                "LING_APPLE_IAP_BUNDLE_ID": "com.example.ling.dev",
                "LING_APPLE_IAP_VERIFY_SIGNATURE": "false",
                "LING_APPLE_APP_STORE_SERVER_API_ISSUER_ID": "issuer-id",
                "LING_APPLE_APP_STORE_SERVER_API_KEY_ID": "key-id",
                "LING_APPLE_APP_STORE_SERVER_API_PRIVATE_KEY": "private-key",
            }
        )

        self.assertEqual(cfg.port, 9000)
        self.assertEqual(cfg.cors_origins, ("*",))
        self.assertEqual(cfg.mysql_host, "mysql.internal")
        self.assertEqual(cfg.mysql_port, 3307)
        self.assertEqual(cfg.redis_db, 3)
        self.assertEqual(cfg.sms_access_key_id, "sms-ak")
        self.assertEqual(cfg.sms_access_key_secret, "sms-secret")
        self.assertEqual(cfg.sms_sign_name, "Ling")
        self.assertEqual(cfg.sms_template_code, "SMS_001")
        self.assertEqual(cfg.wechat_app_id, "wx-dev-app")
        self.assertEqual(cfg.s3_endpoint_url, "https://oss-cn-hangzhou.aliyuncs.com")
        self.assertEqual(cfg.s3_region, "cn-hangzhou")
        self.assertEqual(cfg.s3_bucket, "ling-dev")
        self.assertEqual(cfg.s3_addressing_style, "virtual")
        self.assertEqual(cfg.s3_public_base_url, "https://cdn.example.com")
        self.assertEqual(cfg.eml_template_id, "TPL_001")
        self.assertEqual(cfg.sage_api_url, "http://sage.internal/api/chat")
        self.assertEqual(cfg.sage_agent_id, "agent_dev")
        self.assertEqual(cfg.harmony_push_client_id, "harmony-client")
        self.assertEqual(cfg.harmony_push_client_secret, "harmony-secret")
        self.assertEqual(cfg.harmony_push_app_id, "harmony-app")
        self.assertEqual(cfg.harmony_push_endpoint, "https://push.example.com/send")
        self.assertEqual(cfg.apple_iap_bundle_id, "com.example.ling.dev")
        self.assertFalse(cfg.apple_iap_verify_signature)
        self.assertEqual(cfg.apple_app_store_server_api_issuer_id, "issuer-id")
        self.assertEqual(cfg.apple_app_store_server_api_key_id, "key-id")
        self.assertEqual(cfg.apple_app_store_server_api_private_key, "private-key")

    def test_session_manager_always_uses_mysql_config(self) -> None:
        cfg = AppConfig(
            mysql_host="db.internal",
            mysql_port=3307,
            mysql_user="ling",
            mysql_password="secret",
            mysql_database="ling",
            mysql_charset="utf8mb4",
        )

        manager = SessionManager(cfg)

        self.assertEqual(manager._engine_name, "mysql")
        self.assertEqual(manager.mysql_config["host"], "db.internal")
        self.assertEqual(manager.mysql_config["port"], 3307)
        self.assertEqual(manager.mysql_config["database"], "ling")

    def test_backend_router_prefix_is_fixed(self) -> None:
        self.assertEqual(router.prefix, "/ling-api")
        route_paths = {route.path for route in router.routes}
        self.assertNotIn("/ling-api/agent/voice/sessions", route_paths)


if __name__ == "__main__":
    unittest.main()
