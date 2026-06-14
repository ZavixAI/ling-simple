"""Application configuration helpers."""

from __future__ import annotations

import os
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any, Optional

from utils.env import env_bool, env_int, env_str


def get_workspace_root() -> Path:
    """Return the workspace root that contains the app package."""

    return Path(__file__).resolve().parents[2]


def _normalize_dir(path_value: str) -> str:
    normalized = (
        path_value
        if os.path.isabs(path_value)
        else os.path.abspath(os.path.join(get_workspace_root(), path_value))
    )
    os.makedirs(normalized, exist_ok=True)
    return normalized


@dataclass(frozen=True)
class AppConfig:
    """Process-wide backend configuration.

    Low-frequency defaults live in code and ship with normal releases.
    Only fields that commonly vary by environment, carry secrets, or identify
    external resources are loaded from env vars.
    """

    # App identity and process defaults.
    app_name: str = "ling"
    port: int = 8000

    # Local runtime paths and CORS.
    logs_dir: str = "./logs"
    cors_origins: tuple[str, ...] = ("*",)

    # Object storage defaults plus optional per-env overrides.
    s3_endpoint_url: Optional[str] = "https://oss-cn-shanghai.aliyuncs.com"
    s3_region: str = "cn-shanghai"
    s3_access_key_id: Optional[str] = None
    s3_access_key_secret: Optional[str] = None
    s3_session_token: Optional[str] = None
    s3_bucket: Optional[str] = None
    s3_public_base_url: Optional[str] = None
    s3_addressing_style: str = "path"

    # Primary database connection.
    mysql_host: str = "127.0.0.1"
    mysql_port: int = 3306
    mysql_user: str = "root"
    mysql_password: str = ""
    mysql_database: str = "ling"
    mysql_charset: str = "utf8mb4"

    # Redis for auth state and ephemeral data.
    redis_host: str = "127.0.0.1"
    redis_port: int = 6379
    redis_db: int = 0
    redis_username: Optional[str] = None
    redis_password: Optional[str] = None

    # Auth and login flows.
    access_token_expire_minutes: int = 24 * 60
    refresh_token_expire_days: int = 30
    admin_phone_whitelist: str = ""
    admin_token_expire_minutes: int = 30 * 24 * 60

    sms_endpoint: str = "dysmsapi.aliyuncs.com"
    sms_access_key_id: Optional[str] = None
    sms_access_key_secret: Optional[str] = None
    sms_sign_name: Optional[str] = "北京零一之间科技有限公司"
    sms_template_code: Optional[str] = "SMS_506170335"
    sms_challenge_expire_minutes: int = 5
    sms_challenge_resend_seconds: int = 60
    
    wechat_app_id: Optional[str] = None
    wechat_app_secret: Optional[str] = None
    feishu_app_id: Optional[str] = None
    feishu_app_secret: Optional[str] = None
    
    apple_issuer: str = "https://appleid.apple.com"
    apple_jwks_url: str = "https://appleid.apple.com/auth/keys"
    mobile_oauth_callback_scheme: str = "ling-oauth"
    
    feishu_authorize_url: str = "https://accounts.feishu.cn/open-apis/authen/v1/authorize"
    feishu_token_url: str = "https://open.feishu.cn/open-apis/authen/v1/oidc/access_token"
    feishu_api_base_url: str = "https://open.feishu.cn/open-apis"
    feishu_ios_redirect_uri: str = "ling-oauth://calendar-auth/feishu"
    
    dingtalk_client_id: Optional[str] = None
    dingtalk_client_secret: Optional[str] = None
    dingtalk_stream_url: Optional[str] = None
    dingtalk_authorize_url: str = "https://login.dingtalk.com/oauth2/auth"
    dingtalk_token_url: str = "https://api.dingtalk.com/v1.0/oauth2/userAccessToken"
    dingtalk_api_base_url: str = "https://api.dingtalk.com"
    dingtalk_ios_redirect_uri: str = "ling-oauth://calendar-auth/dingtalk"

    # Aliyun phone number verification.
    pns_endpoint: str = "dypnsapi.aliyuncs.com"
    pns_access_key_id: Optional[str] = None
    pns_access_key_secret: Optional[str] = None

    # Aliyun email verification.
    eml_endpoint: str = "dm.aliyuncs.com"
    eml_access_key_id: Optional[str] = None
    eml_access_key_secret: Optional[str] = None
    eml_account_name: Optional[str] = "	ling@mail.zavixai.com"
    eml_template_id: Optional[str] = "431003"
    eml_register_subject: str = "Ling 安全验证，请确认您的邮箱"

    # Sage agent integration.
    sage_api_url: str = "http://172.16.44.0:30050/api/chat"
    sage_agent_id: str = "agent_56adf26d"

    # APNs push notifications.
    apns_team_id: Optional[str] = None
    apns_key_id: Optional[str] = None
    apns_auth_key: Optional[str] = None

    # HarmonyOS push notifications.
    harmony_push_client_id: Optional[str] = None
    harmony_push_client_secret: Optional[str] = None
    harmony_push_app_id: Optional[str] = None
    harmony_push_endpoint: Optional[str] = None

    notification_dispatch_interval_seconds: int = 15
    notification_dispatch_batch_size: int = 20

    # Mobile app release gates.
    min_ios_version: str = "0.0.0+0"
    ios_app_store_url: str = "https://testflight.apple.com/join/JfEr7hyq"

    # Membership and App Store subscriptions.
    apple_iap_bundle_id: str = "top.withling.ling"
    apple_iap_verify_signature: bool = True
    apple_app_store_api_base_url: str = "https://api.storekit.apple.com"
    apple_app_store_sandbox_api_base_url: str = "https://api.storekit-sandbox.apple.com"
    apple_app_store_server_api_issuer_id: Optional[str] = None
    apple_app_store_server_api_key_id: Optional[str] = None
    apple_app_store_server_api_private_key: Optional[str] = None

    # 高德地图 Web 服务（地理编码、POI、天气等 MCP 工具）
    amap_web_key: Optional[str] = None

    # RideClaw travel resources (read-only flight/hotel search MCP tools).
    rideclaw_api_base_url: str = "https://open.longxiachuxing.com/api"
    rideclaw_api_token: Optional[str] = None
    rideclaw_timeout_seconds: int = 30


_APP_CONFIG: AppConfig | None = None


def build_app_config(**overrides: Any) -> AppConfig:
    """Build config from code defaults, env vars, and call-site overrides."""

    config = AppConfig(
        # Runtime wiring.
        port=env_int("LING_PORT", AppConfig.port),
        logs_dir=env_str("LING_LOGS_DIR", AppConfig.logs_dir) or AppConfig.logs_dir,
        # Object storage.
        s3_endpoint_url=env_str(
            "LING_S3_ENDPOINT_URL",
            AppConfig.s3_endpoint_url,
        ),
        s3_region=env_str(
            "LING_S3_REGION",
            AppConfig.s3_region,
        )
        or AppConfig.s3_region,
        s3_access_key_id=env_str(
            "LING_S3_ACCESS_KEY_ID",
            AppConfig.s3_access_key_id,
        ),
        s3_access_key_secret=env_str(
            "LING_S3_ACCESS_KEY_SECRET",
            AppConfig.s3_access_key_secret,
        ),
        s3_session_token=env_str(
            "LING_S3_SESSION_TOKEN",
            AppConfig.s3_session_token,
        ),
        s3_bucket=env_str("LING_S3_BUCKET", AppConfig.s3_bucket),
        s3_public_base_url=env_str(
            "LING_S3_PUBLIC_BASE_URL",
            AppConfig.s3_public_base_url,
        ),
        s3_addressing_style=env_str(
            "LING_S3_ADDRESSING_STYLE",
            AppConfig.s3_addressing_style,
        )
        or AppConfig.s3_addressing_style,
        # MySQL and Redis.
        mysql_host=env_str("LING_MYSQL_HOST", AppConfig.mysql_host)
        or AppConfig.mysql_host,
        mysql_port=env_int("LING_MYSQL_PORT", AppConfig.mysql_port),
        mysql_user=env_str("LING_MYSQL_USER", AppConfig.mysql_user)
        or AppConfig.mysql_user,
        mysql_password=env_str("LING_MYSQL_PASSWORD", AppConfig.mysql_password)
        or AppConfig.mysql_password,
        mysql_database=env_str("LING_MYSQL_DATABASE", AppConfig.mysql_database)
        or AppConfig.mysql_database,
        redis_host=env_str("LING_REDIS_HOST", AppConfig.redis_host)
        or AppConfig.redis_host,
        redis_port=env_int("LING_REDIS_PORT", AppConfig.redis_port),
        redis_db=env_int("LING_REDIS_DB", AppConfig.redis_db),
        redis_username=env_str("LING_REDIS_USERNAME", AppConfig.redis_username),
        redis_password=env_str("LING_REDIS_PASSWORD", AppConfig.redis_password),
        # Auth env and provider-specific identifiers.
        admin_phone_whitelist=env_str(
            "LING_ADMIN_PHONE_WHITELIST",
            AppConfig.admin_phone_whitelist,
        )
        or AppConfig.admin_phone_whitelist,
        admin_token_expire_minutes=env_int(
            "LING_ADMIN_TOKEN_EXPIRE_MINUTES",
            AppConfig.admin_token_expire_minutes,
        ),
        sms_access_key_id=env_str(
            "LING_SMS_ACCESS_KEY_ID",
            AppConfig.sms_access_key_id,
        ),
        sms_access_key_secret=env_str(
            "LING_SMS_ACCESS_KEY_SECRET",
            AppConfig.sms_access_key_secret,
        ),
        sms_sign_name=env_str(
            "LING_SMS_SIGN_NAME",
            AppConfig.sms_sign_name,
        ),
        sms_template_code=env_str(
            "LING_SMS_TEMPLATE_CODE",
            AppConfig.sms_template_code,
        ),
        feishu_app_id=env_str(
            "LING_FEISHU_APP_ID",
            AppConfig.feishu_app_id,
        ),
        feishu_app_secret=env_str(
            "LING_FEISHU_APP_SECRET",
            AppConfig.feishu_app_secret,
        ),
        dingtalk_client_id=env_str(
            "LING_DINGTALK_CLIENT_ID",
            AppConfig.dingtalk_client_id,
        ),
        dingtalk_client_secret=env_str(
            "LING_DINGTALK_CLIENT_SECRET",
            AppConfig.dingtalk_client_secret,
        ),
        dingtalk_stream_url=env_str(
            "LING_DINGTALK_STREAM_URL",
            AppConfig.dingtalk_stream_url,
        ),
        wechat_app_id=env_str(
            "LING_WECHAT_APP_ID",
            AppConfig.wechat_app_id,
        ),
        wechat_app_secret=env_str(
            "LING_WECHAT_APP_SECRET",
            AppConfig.wechat_app_secret,
        ),
        # Aliyun phone number verification.
        pns_access_key_id=env_str(
            "LING_PNS_ACCESS_KEY_ID",
            AppConfig.pns_access_key_id,
        ),
        pns_access_key_secret=env_str(
            "LING_PNS_ACCESS_KEY_SECRET",
            AppConfig.pns_access_key_secret,
        ),
        # Aliyun email verification.
        eml_access_key_id=env_str(
            "LING_EML_ACCESS_KEY_ID",
            AppConfig.eml_access_key_id,
        ),
        eml_access_key_secret=env_str(
            "LING_EML_ACCESS_KEY_SECRET",
            AppConfig.eml_access_key_secret,
        ),
        eml_account_name=env_str(
            "LING_EML_ACCOUNT_NAME",
            AppConfig.eml_account_name,
        ),
        eml_template_id=env_str(
            "LING_EML_TEMPLATE_ID",
            AppConfig.eml_template_id,
        ),
        eml_register_subject=env_str(
            "LING_EML_REGISTER_SUBJECT",
            AppConfig.eml_register_subject,
        )
        or AppConfig.eml_register_subject,
        # Sage agent integration.
        sage_api_url=env_str("LING_SAGE_API_URL", AppConfig.sage_api_url)
        or AppConfig.sage_api_url,
        sage_agent_id=env_str("LING_SAGE_AGENT_ID", AppConfig.sage_agent_id)
        or AppConfig.sage_agent_id,
        # APNs push notifications.
        apns_team_id=env_str("LING_APNS_TEAM_ID", AppConfig.apns_team_id),
        apns_key_id=env_str("LING_APNS_KEY_ID", AppConfig.apns_key_id),
        apns_auth_key=env_str("LING_APNS_AUTH_KEY", AppConfig.apns_auth_key),
        # HarmonyOS push notifications.
        harmony_push_client_id=env_str(
            "LING_HARMONY_PUSH_CLIENT_ID",
            AppConfig.harmony_push_client_id,
        ),
        harmony_push_client_secret=env_str(
            "LING_HARMONY_PUSH_CLIENT_SECRET",
            AppConfig.harmony_push_client_secret,
        ),
        harmony_push_app_id=env_str(
            "LING_HARMONY_PUSH_APP_ID",
            AppConfig.harmony_push_app_id,
        ),
        harmony_push_endpoint=env_str(
            "LING_HARMONY_PUSH_ENDPOINT",
            AppConfig.harmony_push_endpoint,
        ),
        min_ios_version=env_str(
            "LING_MIN_IOS_VERSION",
            AppConfig.min_ios_version,
        )
        or AppConfig.min_ios_version,
        apple_iap_bundle_id=env_str(
            "LING_APPLE_IAP_BUNDLE_ID",
            AppConfig.apple_iap_bundle_id,
        )
        or AppConfig.apple_iap_bundle_id,
        apple_iap_verify_signature=env_bool(
            "LING_APPLE_IAP_VERIFY_SIGNATURE",
            AppConfig.apple_iap_verify_signature,
        ),
        apple_app_store_api_base_url=env_str(
            "LING_APPLE_APP_STORE_API_BASE_URL",
            AppConfig.apple_app_store_api_base_url,
        )
        or AppConfig.apple_app_store_api_base_url,
        apple_app_store_sandbox_api_base_url=env_str(
            "LING_APPLE_APP_STORE_SANDBOX_API_BASE_URL",
            AppConfig.apple_app_store_sandbox_api_base_url,
        )
        or AppConfig.apple_app_store_sandbox_api_base_url,
        apple_app_store_server_api_issuer_id=env_str(
            "LING_APPLE_APP_STORE_SERVER_API_ISSUER_ID",
            AppConfig.apple_app_store_server_api_issuer_id,
        ),
        apple_app_store_server_api_key_id=env_str(
            "LING_APPLE_APP_STORE_SERVER_API_KEY_ID",
            AppConfig.apple_app_store_server_api_key_id,
        ),
        apple_app_store_server_api_private_key=env_str(
            "LING_APPLE_APP_STORE_SERVER_API_PRIVATE_KEY",
            AppConfig.apple_app_store_server_api_private_key,
        ),
        amap_web_key=env_str("LING_AMAP_WEB_KEY", AppConfig.amap_web_key),
        rideclaw_api_base_url=env_str(
            "LING_RIDECLAW_API_BASE_URL",
            AppConfig.rideclaw_api_base_url,
        )
        or AppConfig.rideclaw_api_base_url,
        rideclaw_api_token=env_str(
            "LING_RIDECLAW_API_TOKEN",
            AppConfig.rideclaw_api_token,
        ),
        rideclaw_timeout_seconds=env_int(
            "LING_RIDECLAW_TIMEOUT_SECONDS",
            AppConfig.rideclaw_timeout_seconds,
        ),
    )

    resolved_overrides = {
        key: value for key, value in overrides.items() if value is not None
    }
    if resolved_overrides:
        config = replace(config, **resolved_overrides)

    return replace(
        config,
        logs_dir=_normalize_dir(config.logs_dir),
    )


def init_app_config(**overrides: Any) -> AppConfig:
    """Rebuild and cache app configuration."""

    global _APP_CONFIG

    _APP_CONFIG = build_app_config(**overrides)
    return _APP_CONFIG


def get_app_config() -> AppConfig:
    """Return the cached config, building it on first access."""

    global _APP_CONFIG

    if _APP_CONFIG is None:
        _APP_CONFIG = build_app_config()
    return _APP_CONFIG


__all__ = [
    "AppConfig",
    "build_app_config",
    "get_app_config",
    "get_workspace_root",
    "init_app_config",
]
