from __future__ import annotations

import json
import re
from typing import Any, Optional

from alibabacloud_dysmsapi20170525 import models as dysmsapi_models
from alibabacloud_dysmsapi20170525.client import Client as Dysmsapi20170525Client
from alibabacloud_tea_openapi import models as open_api_models
from config.settings import AppConfig, get_app_config
from core.http.exceptions import AppHTTPException
from utils.logging import logger


class SmsAdapter:
    def __init__(self) -> None:
        self._client: Dysmsapi20170525Client | None = None

    async def init(self, cfg: Optional[AppConfig] = None) -> Dysmsapi20170525Client:
        if self._client is not None:
            return self._client

        resolved_cfg = cfg or get_app_config()
        access_key_id = (resolved_cfg.sms_access_key_id or "").strip()
        access_key_secret = (resolved_cfg.sms_access_key_secret or "").strip()

        if access_key_id and access_key_secret:
            client_config = open_api_models.Config(
                access_key_id=access_key_id,
                access_key_secret=access_key_secret,
            )
        else:
            from alibabacloud_credentials.client import Client as CredentialClient

            logger.warning(
                "未在 .env 中配置 LING_SMS_ACCESS_KEY_ID/LING_SMS_ACCESS_KEY_SECRET，短信客户端将回退到阿里云默认凭据链"
            )
            credential = CredentialClient()
            client_config = open_api_models.Config(credential=credential)

        client_config.endpoint = resolved_cfg.sms_endpoint
        self._client = Dysmsapi20170525Client(client_config)
        logger.debug(f"短信客户端初始化成功: {client_config.endpoint}")
        return self._client

    async def send_template_sms(
        self,
        *,
        phone: str,
        template_code: str,
        template_data: dict[str, Any],
        sign_name: str,
    ) -> None:
        client = await self.init()
        request = dysmsapi_models.SendSmsRequest(
            phone_numbers=self._format_phone_numbers(phone),
            sign_name=sign_name,
            template_code=template_code,
            template_param=json.dumps(dict(template_data or {}), ensure_ascii=False),
        )
        try:
            response = await client.send_sms_async(request)
            body = response.body.to_map() if hasattr(response.body, "to_map") else {}
            code = str(body.get("Code") or body.get("code") or "").strip()
            message = str(body.get("Message") or body.get("message") or "").strip()
            if code.upper() != "OK":
                raise AppHTTPException(
                    status_code=400,
                    detail="短信发送失败",
                    error_detail=message or code,
                )
            logger.info(f"模板短信发送成功: {phone}")
        except AppHTTPException:
            raise
        except Exception as error:
            message = getattr(error, "message", "") or str(error)
            recommend = ""
            data = getattr(error, "data", None)
            if isinstance(data, dict):
                recommend = str(data.get("Recommend") or data.get("recommend") or "")
            logger.error(f"模板短信发送失败: {phone}, error={message}, recommend={recommend}")
            if "unable to load credentials" in message.lower() or "credentialexception" in message.lower():
                raise AppHTTPException(
                    detail="短信凭据未配置，请在 .env 中设置 LING_SMS_ACCESS_KEY_ID 和 LING_SMS_ACCESS_KEY_SECRET",
                    error_detail=recommend or message,
                ) from error
            raise AppHTTPException(
                detail="短信发送失败",
                error_detail=recommend or message,
            ) from error

    async def close(self) -> None:
        self._client = None
        logger.info("短信客户端已关闭")

    def _format_phone_numbers(self, phone: str) -> str:
        normalized = (phone or "").strip()
        digits = re.sub(r"\D", "", normalized)
        if normalized.startswith("+86") and len(digits) == 13:
            return digits[2:]
        if normalized.startswith("+") and digits:
            return digits
        return digits or normalized


sms = SmsAdapter()
