from __future__ import annotations

from typing import Any

from loguru import logger


async def publish_surface_changed(
    *,
    user_id: str,
    surface: str,
    item_id: str | None = None,
    operation: str,
    payload: dict[str, Any] | None = None,
) -> None:
    normalized_user_id = str(user_id or "").strip()
    normalized_surface = str(surface or "").strip()
    if not normalized_user_id or not normalized_surface:
        return

    try:
        from services.chat.conversation_events import publish_conversation_entry_changed

        await publish_conversation_entry_changed(
            user_id=normalized_user_id,
            session_id="",
            entry_id=(item_id or normalized_surface).strip() or normalized_surface,
            reason=f"{normalized_surface}_changed",
            payload={
                "type": f"{normalized_surface}_changed",
                "user_id": normalized_user_id,
                "surface": normalized_surface,
                "item_id": item_id,
                "operation": operation,
                **(payload or {}),
            },
        )
    except Exception as exc:
        logger.warning(
            "[SurfaceEvents] publish failed user_id={} surface={} item_id={} operation={} error={}",
            normalized_user_id,
            normalized_surface,
            item_id,
            operation,
            exc,
        )
