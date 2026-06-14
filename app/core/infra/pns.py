from __future__ import annotations

from typing import Optional

from alibabacloud_dypnsapi20170525.client import Client as Dypnsapi20170525Client
from alibabacloud_tea_openapi import models as open_api_models
from config.settings import AppConfig
from loguru import logger


class PnsAdapter:
    def __init__(self) -> None:
        self._client: Dypnsapi20170525Client | None = None

    async def init(
        self,
        cfg: Optional[AppConfig] = None,
    ) -> Optional["Dypnsapi20170525Client"]:
        """Initialize the Aliyun number-auth client."""

        if self._client is not None:
            return self._client

        if cfg is None:
            raise RuntimeError("AppConfig is required to initialize PNS client")

        try:
            access_key_id = (cfg.pns_access_key_id or "").strip()
            access_key_secret = (cfg.pns_access_key_secret or "").strip()

            if access_key_id and access_key_secret:
                client_config = open_api_models.Config(
                    access_key_id=access_key_id,
                    access_key_secret=access_key_secret,
                )
            else:
                from alibabacloud_credentials.client import Client as CredentialClient

                logger.warning(
                    "未在 .env 中配置 LING_PNS_ACCESS_KEY_ID/LING_PNS_ACCESS_KEY_SECRET，号码认证客户端将回退到阿里云默认凭据链"
                )
                credential = CredentialClient()
                client_config = open_api_models.Config(credential=credential)

            client_config.endpoint = cfg.pns_endpoint
            self._client = Dypnsapi20170525Client(client_config)
            logger.debug(f"号码认证客户端初始化成功: {client_config.endpoint}")
            return self._client
        except Exception as error:
            logger.error(f"号码认证客户端初始化失败: {error}")
            return None

    async def close(self) -> None:
        """Clear the cached PNS client reference."""

        self._client = None
        logger.info("号码认证客户端已关闭")


pns = PnsAdapter()
