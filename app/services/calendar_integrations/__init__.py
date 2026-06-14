"""第三方日历接入：OAuth、增量同步、钉钉/飞书回调与连接状态 Redis 存储。"""

from .providers import (
    PROVIDER_APPLE_LOCAL,
    PROVIDER_DINGTALK,
    PROVIDER_FEISHU,
    build_provider_client,
)
from .service import (
    CalendarConnectionService,
    CalendarOAuthService,
    ExternalCalendarSyncService,
    FeishuWebhookService,
)
from .state_store import CalendarSyncTriggerStore
from .stream import DingTalkCalendarStreamConsumer

__all__ = [
    "PROVIDER_APPLE_LOCAL",
    "PROVIDER_DINGTALK",
    "PROVIDER_FEISHU",
    "build_provider_client",
    "CalendarConnectionService",
    "CalendarOAuthService",
    "ExternalCalendarSyncService",
    "FeishuWebhookService",
    "DingTalkCalendarStreamConsumer",
    "CalendarSyncTriggerStore",
]
