import asyncio
from datetime import timedelta
from types import SimpleNamespace

import pytest

from core.http.exceptions import AppHTTPException
from models.base import get_local_now
from services.chat_quick_prompts import ChatQuickPromptService, chat_quick_prompts


def test_chat_quick_prompts_returns_localized_backend_config():
    zh = chat_quick_prompts(locale="zh-CN")
    en = chat_quick_prompts(locale="en-US")

    assert zh["cache_ttl_seconds"] == 12 * 60 * 60
    assert en["cache_ttl_seconds"] == 12 * 60 * 60
    assert len(zh["prompts"]) == 9
    assert len(en["prompts"]) == len(zh["prompts"])
    assert zh["prompts"][0]["label"] == "🗓 整理今天"
    assert en["prompts"][0]["label"] == "🗓 Plan today"


def test_chat_quick_prompts_are_natural_and_hide_internal_names():
    payload = chat_quick_prompts(locale="zh-CN")
    joined_prompts = "\n".join(prompt["prompt"] for prompt in payload["prompts"])

    forbidden_fragments = [
        "tool",
        "workspace",
        "upload_files",
        "/app/agents",
        "MCP",
        "技能",
        "工具名称",
    ]
    for fragment in forbidden_fragments:
        assert fragment not in joined_prompts

    prompts_by_id = {prompt["id"]: prompt for prompt in payload["prompts"]}
    assert set(prompts_by_id) == {
        "plan_today",
        "add_reminder",
        "find_time",
        "open_schedule",
        "review_week",
        "plan_trip",
        "check_route_weather",
        "search_flights",
        "search_hotels",
    }
    assert prompts_by_id["plan_trip"]["mode"] == "needs_input"
    assert prompts_by_id["open_schedule"]["mode"] == "needs_input"


class _FakeUsageDao:
    def __init__(self, rows=None):
        self.rows = rows or []
        self.recorded = []

    async def list_usage(self, user_id, surface):
        return [
            row
            for row in self.rows
            if row.user_id == user_id and row.surface == surface
        ]

    async def record_use(self, user_id, surface, prompt_id):
        self.recorded.append((user_id, surface, prompt_id))
        return SimpleNamespace(
            prompt_id=prompt_id,
            surface=surface,
            use_count=1,
            weighted_score=1.0,
            last_used_at=get_local_now(),
        )


def test_chat_quick_prompts_default_order_without_usage():
    payload = asyncio.run(
        ChatQuickPromptService(usage_dao=_FakeUsageDao()).list_prompts(
            user_id="user-1",
            locale="zh-CN",
            surface="chat",
        )
    )

    assert [prompt["id"] for prompt in payload["prompts"][:3]] == [
        "plan_today",
        "add_reminder",
        "find_time",
    ]


def test_chat_quick_prompts_orders_by_user_surface_usage():
    now = get_local_now()
    payload = asyncio.run(
        ChatQuickPromptService(
            usage_dao=_FakeUsageDao(
                rows=[
                        SimpleNamespace(
                            user_id="user-1",
                            surface="chat",
                            prompt_id="search_flights",
                            use_count=3,
                            weighted_score=3.0,
                            last_used_at=now,
                    ),
                    SimpleNamespace(
                            user_id="user-2",
                            surface="chat",
                            prompt_id="search_hotels",
                            use_count=20,
                            weighted_score=20.0,
                            last_used_at=now,
                    ),
                    SimpleNamespace(
                            user_id="user-1",
                            surface="settings",
                            prompt_id="plan_trip",
                            use_count=20,
                            weighted_score=20.0,
                            last_used_at=now - timedelta(days=1),
                    ),
                ]
            )
        ).list_prompts(user_id="user-1", locale="zh-CN", surface="chat")
    )

    assert payload["prompts"][0]["id"] == "search_flights"


def test_chat_quick_prompt_record_use_rejects_unknown_prompt():
    with pytest.raises(AppHTTPException):
        asyncio.run(
            ChatQuickPromptService(usage_dao=_FakeUsageDao()).record_use(
                user_id="user-1",
                prompt_id="missing",
                surface="chat",
            )
        )
