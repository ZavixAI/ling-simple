"""Localized chat quick prompt configuration."""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from core.http.exceptions import AppHTTPException
from models.chat_quick_prompt import ChatQuickPromptUsage, ChatQuickPromptUsageDao
from models.base import get_local_now

_CACHE_TTL_SECONDS = 12 * 60 * 60
_VERSION = "2026-06-quick-prompts-v4"
_DEFAULT_SURFACE = "chat"


class ChatQuickPromptService:
    def __init__(self, usage_dao: ChatQuickPromptUsageDao | None = None) -> None:
        self.usage_dao = usage_dao or ChatQuickPromptUsageDao()

    async def list_prompts(
        self,
        *,
        user_id: str,
        locale: str | None = None,
        surface: str | None = None,
    ) -> dict[str, Any]:
        normalized_surface = _normalize_surface(surface)
        payload = chat_quick_prompts(locale=locale)
        usage_rows = await self.usage_dao.list_usage(user_id, normalized_surface)
        payload["prompts"] = _sort_prompts_for_usage(payload["prompts"], usage_rows)
        return payload

    async def record_use(
        self,
        *,
        user_id: str,
        prompt_id: str,
        surface: str | None = None,
    ) -> dict[str, Any]:
        normalized_prompt_id = _normalize_prompt_id(prompt_id)
        known_prompt_ids = {prompt["id"] for prompt in _zh_prompts()}
        if normalized_prompt_id not in known_prompt_ids:
            raise AppHTTPException(status_code=404, detail="Quick prompt not found")
        normalized_surface = _normalize_surface(surface)
        usage = await self.usage_dao.record_use(
            user_id,
            normalized_surface,
            normalized_prompt_id,
        )
        return {
            "prompt_id": usage.prompt_id,
            "surface": usage.surface,
            "use_count": usage.use_count,
            "weighted_score": usage.weighted_score,
            "last_used_at": usage.last_used_at.isoformat() if usage.last_used_at else None,
        }


def chat_quick_prompts(locale: str | None = None) -> dict[str, Any]:
    is_zh = str(locale or "").strip().lower().startswith("zh")
    return {
        "version": _VERSION,
        "cache_ttl_seconds": _CACHE_TTL_SECONDS,
        "prompts": _zh_prompts() if is_zh else _en_prompts(),
    }


def _normalize_surface(surface: str | None) -> str:
    normalized = str(surface or _DEFAULT_SURFACE).strip().lower()
    return normalized or _DEFAULT_SURFACE


def _normalize_prompt_id(prompt_id: str | None) -> str:
    return str(prompt_id or "").strip()


def _sort_prompts_for_usage(
    prompts: list[dict[str, str]],
    usage_rows: list[ChatQuickPromptUsage],
) -> list[dict[str, str]]:
    if not usage_rows:
        return prompts
    usage_by_id = {row.prompt_id: row for row in usage_rows}
    now = get_local_now()

    def usage_score(prompt: dict[str, str]) -> tuple[float, int]:
        row = usage_by_id.get(prompt["id"])
        if row is None:
            return (0.0, 0)
        recency = _recency_boost(row.last_used_at, now=now)
        return (float(row.weighted_score or 0.0) + recency, int(row.use_count or 0))

    return sorted(
        prompts,
        key=lambda prompt: (
            -usage_score(prompt)[0],
            -usage_score(prompt)[1],
            prompts.index(prompt),
        ),
    )


def _recency_boost(last_used_at: datetime | None, *, now: datetime) -> float:
    if last_used_at is None:
        return 0.0
    age = now - last_used_at
    if age < timedelta(0):
        return 0.25
    if age >= timedelta(days=7):
        return 0.0
    return max(0.0, 0.25 * (1 - age / timedelta(days=7)))


def _prompt(
    prompt_id: str,
    label: str,
    mode: str,
    prompt: str,
    hint: str = "",
) -> dict[str, str]:
    return {
        "id": prompt_id,
        "label": label,
        "mode": mode,
        "prompt": prompt,
        "hint": hint,
    }


def _zh_prompts() -> list[dict[str, str]]:
    return [
        _prompt(
            "plan_today",
            "🗓 整理今天",
            "direct",
            "帮我做一份整理今天的报告：先看今天有哪些安排，再给我一个简短的执行顺序和需要注意的事项。",
            "整理今天的安排",
        ),
        _prompt(
            "add_reminder",
            "⏰ 加提醒",
            "needs_input",
            "根据用户补充输入创建提醒；如果仍缺少必要的提醒内容或时间，只追问缺少的必要信息，信息齐了就直接创建。",
            "说清提醒内容和时间",
        ),
        _prompt(
            "find_time",
            "🔎 找时间",
            "needs_input",
            "根据用户补充输入为这件事寻找合适空档；优先结合已有日程判断时间，并在需要时只追问必要信息。",
            "说要安排什么和时长",
        ),
        _prompt(
            "open_schedule",
            "📅 看日程",
            "needs_input",
            "根据用户补充输入查看相关日程，并用简短列表告诉用户重点。",
            "说想查看哪段时间",
        ),
        _prompt(
            "review_week",
            "🧭 回顾本周",
            "needs_input",
            "根据用户补充输入回顾本周，结合本周安排、已完成或需要跟进事项，给出简短总结和可执行调整。",
            "说想回顾的重点",
        ),
        _prompt(
            "plan_trip",
            "🧳 规划出行",
            "needs_input",
            "根据用户补充输入规划出行安排；需要时只追问目的地、日期、人数、偏好或预算等必要信息，并优先结合位置、路线、天气、航班和酒店工具。",
            "说目的地和日期",
        ),
        _prompt(
            "check_route_weather",
            "🗺 路线天气",
            "needs_input",
            "根据用户补充输入查询地点、路线和天气；如果缺少出发地、目的地或日期，只追问缺少的信息。",
            "说出发地和目的地",
        ),
        _prompt(
            "search_flights",
            "✈️ 查航班",
            "needs_input",
            "根据用户补充输入查询航班；如果缺少出发城市、到达城市、日期或人数，只追问缺少的信息。",
            "说航线和日期",
        ),
        _prompt(
            "search_hotels",
            "🏨 查酒店",
            "needs_input",
            "根据用户补充输入查询酒店；如果缺少城市、入住/离店日期、人数或房间数，只追问缺少的信息。",
            "说城市和日期",
        ),
    ]


def _en_prompts() -> list[dict[str, str]]:
    return [
        _prompt("plan_today", "🗓 Plan today", "direct", "Make me a report for organizing today: first check what is already scheduled, then give me a short order of execution and anything I should keep tracking.", "Plan today"),
        _prompt("add_reminder", "⏰ Add reminder", "needs_input", "Create a reminder from the user input. If the reminder content or time is still missing, ask only for the missing required detail; once complete, create it.", "Say what and when"),
        _prompt("find_time", "🔎 Find time", "needs_input", "Find a suitable time slot for the user input. Prefer using the current schedule, and ask only for required missing details when needed.", "Say what and how long"),
        _prompt("open_schedule", "📅 Schedule", "needs_input", "Review the schedule related to the user input and summarize the key points in a short list.", "Say which time to review"),
        _prompt("review_week", "🧭 Review week", "needs_input", "Review the week based on the user input, using this week’s schedule, completed items, and follow-ups to provide a short summary and actionable adjustments.", "Say what to review"),
        _prompt("plan_trip", "🧳 Plan trip", "needs_input", "Plan travel from the user input. Ask only for missing required details such as destination, dates, travelers, preferences, or budget, and prefer location, route, weather, flight, and hotel tools.", "Say destination and dates"),
        _prompt("check_route_weather", "🗺 Route weather", "needs_input", "Look up places, routes, and weather from the user input. If the origin, destination, or date is missing, ask only for the missing detail.", "Say origin and destination"),
        _prompt("search_flights", "✈️ Search flights", "needs_input", "Search flights from the user input. If origin, destination, date, or travelers are missing, ask only for the missing detail.", "Say route and date"),
        _prompt("search_hotels", "🏨 Search hotels", "needs_input", "Search hotels from the user input. If city, check-in/check-out dates, travelers, or room count are missing, ask only for the missing detail.", "Say city and dates"),
    ]
