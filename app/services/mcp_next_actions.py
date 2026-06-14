"""Deterministic next-action suggestions for Ling product objects.

These actions are user-facing prompt suggestions. They must never imply a
separate manual editing surface; follow-up changes should go back through Ling.
"""

from __future__ import annotations

from typing import Any

from config import constants


def next_actions_for_tool_result(
    action: str,
    data: dict[str, Any] | None,
) -> list[dict[str, str]]:
    payload = _unwrap_result_data(data)
    if action.startswith("calendar_"):
        return calendar_next_actions(action, payload)
    return []


def calendar_next_actions(
    action: str,
    event: dict[str, Any] | None,
) -> list[dict[str, str]]:
    data = _unwrap_result_data(event)
    title = _title(data, fallback="这个日程")
    event_id = str(data.get("event_id") or data.get("id") or "").strip()
    resource = {
        "kind": "prompt",
        "resource_type": "calendar_event",
        "resource_id": event_id,
    }
    if action == "calendar_delete_event":
        deleted_title = _raw_title(data)
        if not deleted_title:
            return []
        return [
            _action(
                "重新安排",
                f"请帮我重新安排「{deleted_title}」。",
                "这个日程已经取消，下一步适合重新找一个可行时间。",
                resource,
            )
        ]
    if action == "calendar_complete_event":
        if _calendar_category(data) == constants.CALENDAR_CATEGORY_MEETING:
            return [
                _action(
                    "记录复盘",
                    f"请帮我记录「{title}」的会后复盘。",
                    "这个日程的结构化分类是 meeting，适合补充结果和后续事项。",
                    resource,
                )
            ]
        return [
            _action(
                "记录结果",
                f"请帮我记录「{title}」的完成结果。",
                "这个日程已完成，适合保存结果。",
                resource,
            )
        ]
    time_shape = str(data.get("time_shape") or "").strip()
    actions: list[dict[str, str]] = []
    if time_shape == constants.CALENDAR_TIME_SHAPE_POINT:
        if not _has_description_or_note(data):
            actions.append(
                _action(
                    "补充提醒说明",
                    f"请帮我给「{title}」补充一下提醒说明。",
                    "这个提醒还没有说明，补充后 Ling 更容易理解提醒场景。",
                    resource,
                )
            )
        if not data.get("recurrence"):
            actions.append(
                _action(
                    "设为重复事项",
                    f"请帮我把「{title}」设置成合适的重复提醒。",
                    "这个提醒目前只发生一次，如果是习惯或周期事项，可以继续设置重复。",
                    resource,
                )
            )
        return actions[:3]
    if not _has_location(data):
        actions.append(
            _action(
                "补充地点",
                f"请帮我给「{title}」补充地点。",
                "这个日程还没有地点，补充后 Ling 能更好地判断通勤、准备和提醒上下文。",
                resource,
            )
        )
    if _calendar_category(data) == constants.CALENDAR_CATEGORY_MEETING:
        if not _has_meeting_url(data):
            actions.append(
                _action(
                    "补充会议链接",
                    f"请帮我给「{title}」补充会议链接。",
                    "这个日程的结构化分类是 meeting，补充线上入口后 Ling 可以在需要时直接引用。",
                    resource,
                )
            )
        if not _has_attendees(data):
            actions.append(
                _action(
                    "补充参会人",
                    f"请帮我给「{title}」补充参会人。",
                    "这个日程的结构化分类是 meeting，补充参会人后 Ling 更容易理解协作关系。",
                    resource,
                )
            )
        if not _has_description_or_note(data):
            actions.append(
                _action(
                    "补充会议议题",
                    f"请帮我给「{title}」补充会议议题和准备事项。",
                    "这个日程的结构化分类是 meeting，补充议题后 Ling 能更好地做会前提醒和会后跟进。",
                    resource,
                )
            )
        return actions[:3]
    if not _has_description_or_note(data):
        actions.append(
            _action(
                "补充说明",
                f"请帮我给「{title}」补充说明和注意事项。",
                "这个日程信息还比较薄，补充后 Ling 能更好地理解这件事。",
                resource,
            )
        )
    if _calendar_category(data) == constants.CALENDAR_CATEGORY_TRAVEL:
        actions.append(
            _action(
                "整理出行准备",
                f"请帮我整理「{title}」的出行准备事项。",
                "出行类日程通常需要路线、物品和时间缓冲。",
                resource,
            )
        )
    return actions[:3]


def _action(
    label: str,
    prompt: str,
    reason: str,
    resource: dict[str, str],
) -> dict[str, str]:
    item = {
        "label": label,
        "prompt": prompt,
        "reason": reason,
        "kind": resource["kind"],
        "resource_type": resource["resource_type"],
    }
    if resource.get("resource_id"):
        item["resource_id"] = resource["resource_id"]
    return item


def _unwrap_result_data(value: dict[str, Any] | None) -> dict[str, Any]:
    if not isinstance(value, dict):
        return {}
    data = value.get("data")
    if isinstance(data, dict):
        return data
    return value


def _title(data: dict[str, Any], *, fallback: str) -> str:
    return str(data.get("title") or data.get("summary") or fallback).strip()


def _raw_title(data: dict[str, Any]) -> str:
    return str(data.get("title") or data.get("summary") or "").strip()


def _calendar_category(data: dict[str, Any]) -> str:
    return str(data.get("category") or "").strip().lower()


def _has_location(data: dict[str, Any]) -> bool:
    return bool(str(data.get("location") or "").strip())


def _has_meeting_url(data: dict[str, Any]) -> bool:
    return bool(str(data.get("meeting_url") or data.get("url") or "").strip())


def _has_attendees(data: dict[str, Any]) -> bool:
    attendees = data.get("attendees")
    return isinstance(attendees, list) and len(attendees) > 0


def _has_description_or_note(data: dict[str, Any]) -> bool:
    if str(data.get("subtitle") or data.get("description") or "").strip():
        return True
    metadata = data.get("metadata")
    if isinstance(metadata, dict):
        return bool(str(metadata.get("markdown") or "").strip())
    return False

