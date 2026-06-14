from __future__ import annotations

from typing import Any, Optional

from alibabacloud_dm20151123 import models as dm_20151123_models
from alibabacloud_dm20151123.client import Client as Dm20151123Client
from alibabacloud_tea_openapi import models as open_api_models
from config.settings import AppConfig, get_app_config
from core.http.exceptions import AppHTTPException
from loguru import logger


class EmlAdapter:
    def __init__(self) -> None:
        self._client: Dm20151123Client | None = None

    async def init(
        self,
        cfg: Optional[AppConfig] = None,
    ) -> Optional["Dm20151123Client"]:
        """初始化阿里云邮件推送客户端。"""

        if self._client is not None:
            return self._client

        if cfg is None:
            raise RuntimeError("StartupConfig is required to initialize EML client")

        try:
            access_key_id = (cfg.eml_access_key_id or "").strip()
            access_key_secret = (cfg.eml_access_key_secret or "").strip()

            if access_key_id and access_key_secret:
                client_config = open_api_models.Config(
                    access_key_id=access_key_id,
                    access_key_secret=access_key_secret,
                )
            else:
                from alibabacloud_credentials.client import Client as CredentialClient

                logger.warning(
                    "未在 .env 中配置 LING_EML_ACCESS_KEY_ID/LING_EML_ACCESS_KEY_SECRET，邮件客户端将回退到阿里云默认凭据链"
                )
                credential = CredentialClient()
                client_config = open_api_models.Config(credential=credential)
            client_config.endpoint = cfg.eml_endpoint
            self._client = Dm20151123Client(client_config)
            logger.debug(f"邮件客户端初始化成功: {client_config.endpoint}")
            return self._client
        except Exception as e:
            logger.error(f"邮件客户端初始化失败: {e}")
            return None

    def client(self) -> "Dm20151123Client":
        if self._client is None:
            raise AppHTTPException(detail="邮件客户端未初始化", error_detail="eml client not initialized")
        return self._client

    async def send_template_mail(
        self,
        *,
        to_address: str,
        template_id: str,
        template_data: dict[str, Any],
        subject: str,
        cfg: Optional[AppConfig] = None,
    ) -> None:
        resolved_cfg = cfg or get_app_config()
        account_name = (resolved_cfg.eml_account_name or "").strip()
        normalized_template_id = (template_id or "").strip()
        normalized_subject = (subject or "").strip()

        if not account_name or not normalized_template_id:
            raise AppHTTPException(
                detail="邮件服务未配置完整",
                error_detail="missing eml account name or template id",
            )

        client = await self.init(resolved_cfg)
        if client is None:
            raise AppHTTPException(detail="邮件客户端不可用", error_detail="eml client unavailable")

        template = dm_20151123_models.SingleSendMailRequestTemplate(
            template_data=dict(template_data or {}),
            template_id=normalized_template_id,
        )
        mail_request = dm_20151123_models.SingleSendMailRequest(
            template=template,
            account_name=account_name,
            address_type=1,
            reply_to_address=False,
            to_address=to_address,
            subject=normalized_subject,
        )

        try:
            await client.single_send_mail_async(mail_request)
            logger.info(f"模板邮件发送成功: {to_address}")
        except Exception as error:
            message = getattr(error, "message", "") or str(error)
            recommend = ""
            data = getattr(error, "data", None)
            if isinstance(data, dict):
                recommend = str(data.get("Recommend") or "")
            logger.error(f"模板邮件发送失败: {to_address}, error={message}, recommend={recommend}")
            if "unable to load credentials" in message.lower() or "credentialexception" in message.lower():
                raise AppHTTPException(
                    detail="邮件凭据未配置，请在 .env 中设置 LING_EML_ACCESS_KEY_ID 和 LING_EML_ACCESS_KEY_SECRET",
                    error_detail=recommend or message,
                ) from error
            raise AppHTTPException(
                detail="邮件发送失败",
                error_detail=recommend or message,
            ) from error

    async def close(self) -> None:
        self._client = None
        logger.info("邮件客户端已关闭")


eml = EmlAdapter()
