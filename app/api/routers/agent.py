"""Agent session, voice, attachment, and streaming routes."""

from __future__ import annotations

import asyncio
import json

from config import constants
from core.http.dependencies import require_current_user
from core.http.exceptions import AppHTTPException
from core.http.render import Response
from fastapi import APIRouter, Depends, File, Query, Request, UploadFile
from fastapi.responses import Response as FastAPIResponse
from fastapi.responses import StreamingResponse
from loguru import logger
from models.user import User
from schema.api.agent import (
    AgentInjectUserMessagePayload,
    AgentRunCreatePayload,
    AgentSessionCreatePayload,
    AgentStreamPayload,
    AgentUpdateInjectUserMessagePayload,
)
from services.agent.attachments import AttachmentService
from services.agent.files import (
    AgentFileService,
    agent_file_content_disposition,
    agent_file_path_header,
)
from services.agent.runtime import get_agent_run_manager
from services.agent.service import AgentService
from services.chat.conversation_events import stream_conversation_events

router = APIRouter(tags=["agent"])
_CURRENT_USER_DEPENDENCY = Depends(require_current_user)
_LAST_EVENT_ID_QUERY = Query(default=None)
_IMAGE_FILES = File(...)
_AUDIO_FILES = File(...)
_AGENT_FILE_PATH_QUERY = Query(...)
_AGENT_EVENT_NAME = "agent_event"


@router.get("/agent/file/data")
async def get_agent_file_data(
    path: str = _AGENT_FILE_PATH_QUERY,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    try:
        data = await AgentFileService().get_file_data(user.user_id, path)
    except ValueError as exc:
        raise AppHTTPException(status_code=422, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise AppHTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        logger.warning(
            "[AgentFileAPI] 获取 workspace 文件失败 user_id={} path={}: {}",
            user.user_id,
            path,
            exc,
        )
        raise AppHTTPException(
            status_code=502,
            detail="Agent file is unavailable",
        ) from exc
    return FastAPIResponse(
        content=data.content,
        media_type=data.content_type,
        headers={
            "Content-Disposition": agent_file_content_disposition(data.filename),
            "X-Ling-Agent-File-Path": agent_file_path_header(data.path),
        },
    )


@router.post("/agent/sessions")
async def create_agent_session(
    payload: AgentSessionCreatePayload,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await AgentService().create_session(
        user.user_id,
        payload.entry_mode,
        payload.timezone,
        payload.selected_date,
    )
    return await Response.success(data=data)


@router.get("/agent/sessions/latest")
async def get_latest_agent_session(
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = {
        "item": await AgentService().get_latest_session(user.user_id),
    }
    return await Response.success(data=data)


@router.get("/agent/events")
@router.get("/agent/conversation-events")
async def stream_agent_conversation_events(
    request: Request,
    last_event_id: str | None = _LAST_EVENT_ID_QUERY,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    async def generator():
        try:
            yield ": connected\n\n"
            async for stream_id, event in stream_conversation_events(
                user_id=user.user_id,
                last_event_id=last_event_id,
            ):
                if await request.is_disconnected():
                    break
                if event is None:
                    yield ": heartbeat\n\n"
                    continue
                payload = json.dumps(event.to_sse_payload(), ensure_ascii=False)
                yield (f"id: {stream_id}\nevent: {_AGENT_EVENT_NAME}\ndata: {payload}\n\n")
        except asyncio.CancelledError:
            raise

    return StreamingResponse(
        generator(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.get("/agent/conversation-entries")
async def list_agent_conversation_entries(
    limit: int = Query(default=80, ge=1, le=300),
    before_created_at: str | None = Query(default=None),
    before_record_id: str | None = Query(default=None),
    current_session_id: str | None = Query(default=None),
    user: User = _CURRENT_USER_DEPENDENCY,
):
    normalized_session_id = (current_session_id or "").strip()
    manager = get_agent_run_manager()
    active_run = (
        await manager.get_active_run_payload(normalized_session_id)
        if normalized_session_id
        else None
    )
    is_active = active_run is not None
    entries_payload = await AgentService().list_user_conversation_entries(
        user.user_id,
        message_limit=limit,
        before_created_at=before_created_at,
        before_record_id=before_record_id,
    )
    logger.info(
        "[AgentAPI] 列出用户对话时间线 user_id={} current_session_id={} active={} count={} has_more={}",
        user.user_id,
        normalized_session_id,
        is_active,
        len(entries_payload["items"]),
        entries_payload["has_more"],
    )
    data = {
        "items": entries_payload["items"],
        "is_active": is_active,
        "active_run": active_run,
        "has_more": entries_payload["has_more"],
        "message_limit": entries_payload["message_limit"],
        "older_cursor": entries_payload["older_cursor"],
    }
    return await Response.success(data=data)


@router.get("/agent/sessions/{session_id}")
async def get_agent_session(
    session_id: str,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = await AgentService().get_session(user.user_id, session_id)
    if data is None:
        raise AppHTTPException(status_code=404, detail="Session not found")
    return await Response.success(data=data)


@router.get("/agent/sessions/{session_id}/messages")
async def list_agent_session_messages(
    session_id: str,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    data = {
        "items": await AgentService().list_messages(user.user_id, session_id),
    }
    return await Response.success(data=data)


@router.get("/agent/sessions/{session_id}/entries")
async def list_agent_session_entries(
    session_id: str,
    limit: int = Query(default=80, ge=1, le=300),
    before_created_at: str | None = Query(default=None),
    before_record_id: str | None = Query(default=None),
    user: User = _CURRENT_USER_DEPENDENCY,
):
    manager = get_agent_run_manager()
    active_run = await manager.get_active_run_payload(session_id)
    is_active = active_run is not None
    entries_payload = await AgentService().list_conversation_entries(
        user.user_id,
        session_id,
        keep_last_assistant_streaming=is_active,
        message_limit=limit,
        before_created_at=before_created_at,
        before_record_id=before_record_id,
    )
    logger.info(
        "[AgentAPI] 列出会话记录 user_id={} session_id={} active={} count={} has_more={}",
        user.user_id,
        session_id,
        is_active,
        len(entries_payload["items"]),
        entries_payload["has_more"],
    )
    data = {
        "items": entries_payload["items"],
        "is_active": is_active,
        "active_run": active_run,
        "has_more": entries_payload["has_more"],
        "message_limit": entries_payload["message_limit"],
        "older_cursor": entries_payload["older_cursor"],
    }
    return await Response.success(data=data)


@router.post("/agent/sessions/{session_id}/interrupt")
async def interrupt_agent_session(
    session_id: str,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    session = await AgentService().get_session(user.user_id, session_id)
    if session is None:
        raise AppHTTPException(status_code=404, detail="Session not found")
    try:
        await get_agent_run_manager().interrupt_session(
            user_id=user.user_id,
            session_id=session_id,
        )
    except Exception as exc:
        raise AppHTTPException(
            status_code=502,
            detail=f"Failed to interrupt session: {exc}",
        ) from exc
    return await Response.success(
        data={"session_id": session_id, "interrupted": True},
    )


@router.post("/agent/sessions/{session_id}/inject-user-message")
async def inject_agent_user_message(
    session_id: str,
    payload: AgentInjectUserMessagePayload,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    agent_service = AgentService()
    session = await agent_service.get_session(user.user_id, session_id)
    if session is None:
        raise AppHTTPException(status_code=404, detail="Session not found")
    try:
        data = await agent_service.inject_user_message(
            user_id=user.user_id,
            session_id=session_id,
            content=payload.content,
            guidance_id=payload.guidance_id,
            metadata=payload.metadata,
        )
    except Exception as exc:
        raise AppHTTPException(
            status_code=502,
            detail=f"Failed to inject guidance: {exc}",
        ) from exc
    return await Response.success(data=data)


@router.get("/agent/sessions/{session_id}/inject-user-message")
async def list_agent_user_message_injections(
    session_id: str,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    agent_service = AgentService()
    session = await agent_service.get_session(user.user_id, session_id)
    if session is None:
        raise AppHTTPException(status_code=404, detail="Session not found")
    try:
        data = await agent_service.list_pending_user_injections(
            user_id=user.user_id,
            session_id=session_id,
        )
    except Exception as exc:
        raise AppHTTPException(
            status_code=502,
            detail=f"Failed to list guidance: {exc}",
        ) from exc
    return await Response.success(data=data)


@router.patch("/agent/sessions/{session_id}/inject-user-message/{guidance_id}")
async def update_agent_user_message_injection(
    session_id: str,
    guidance_id: str,
    payload: AgentUpdateInjectUserMessagePayload,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    agent_service = AgentService()
    session = await agent_service.get_session(user.user_id, session_id)
    if session is None:
        raise AppHTTPException(status_code=404, detail="Session not found")
    try:
        data = await agent_service.update_pending_user_injection(
            user_id=user.user_id,
            session_id=session_id,
            guidance_id=guidance_id,
            content=payload.content,
        )
    except Exception as exc:
        raise AppHTTPException(
            status_code=502,
            detail=f"Failed to update guidance: {exc}",
        ) from exc
    return await Response.success(data=data)


@router.delete("/agent/sessions/{session_id}/inject-user-message/{guidance_id}")
async def delete_agent_user_message_injection(
    session_id: str,
    guidance_id: str,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    agent_service = AgentService()
    session = await agent_service.get_session(user.user_id, session_id)
    if session is None:
        raise AppHTTPException(status_code=404, detail="Session not found")
    try:
        data = await agent_service.delete_pending_user_injection(
            user_id=user.user_id,
            session_id=session_id,
            guidance_id=guidance_id,
        )
    except Exception as exc:
        raise AppHTTPException(
            status_code=502,
            detail=f"Failed to delete guidance: {exc}",
        ) from exc
    return await Response.success(data=data)


@router.post("/agent/attachments/images")
async def upload_agent_images(
    files: list[UploadFile] = _IMAGE_FILES,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    if not files:
        raise AppHTTPException(status_code=422, detail="At least one image is required")

    items = []
    for file in files:
        items.append(await AttachmentService().save_image(user.user_id, file))
    return await Response.success(data={"items": items})


@router.post("/agent/attachments/audio")
async def upload_agent_audio(
    files: list[UploadFile] = _AUDIO_FILES,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    if not files:
        raise AppHTTPException(status_code=422, detail="At least one audio file is required")

    items = []
    for file in files:
        items.append(await AttachmentService().save_audio(user.user_id, file))
    return await Response.success(data={"items": items})


@router.post("/agent/sessions/{session_id}/stream")
async def stream_agent_session(
    session_id: str,
    payload: AgentStreamPayload,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    logger.warning(
        "[AgentRouter] /agent/sessions/{session_id}/stream 已废弃，请使用 /runs "
        f"session={session_id} user={user.user_id}"
    )
    agent_service = AgentService()
    session = await agent_service.get_session(user.user_id, session_id)
    if session is None:
        raise AppHTTPException(status_code=404, detail="Session not found")

    has_messages = len(payload.messages or []) > 0
    client_run_id = payload.client_run_id
    manager = get_agent_run_manager()
    if not has_messages:
        raise AppHTTPException(status_code=422, detail="Messages cannot be empty")
    if await manager.is_session_active(session_id):
        await manager.interrupt_session(user_id=user.user_id, session_id=session_id)
    queue = await manager.subscribe_session(
        user_id=user.user_id,
        session_id=session_id,
        client_run_id=client_run_id,
        messages=[item.model_dump(exclude_none=True) for item in payload.messages],
        system_context=dict(payload.system_context or {}),
        consume_quota=has_messages,
    )
    generator = manager.stream_queue(session_id=session_id, queue=queue)
    return StreamingResponse(
        generator,
        media_type="text/event-stream",
        headers={
            "Deprecation": "true",
            "X-Ling-Deprecated-Endpoint": "agent-session-stream",
        },
    )


@router.post("/agent/sessions/{session_id}/runs")
async def create_agent_session_run(
    session_id: str,
    payload: AgentRunCreatePayload,
    user: User = _CURRENT_USER_DEPENDENCY,
):
    agent_service = AgentService()
    session = await agent_service.get_session(user.user_id, session_id)
    if session is None:
        raise AppHTTPException(status_code=404, detail="Session not found")

    has_messages = len(payload.messages or []) > 0
    if not has_messages:
        raise AppHTTPException(status_code=422, detail="Messages cannot be empty")

    run_id = await get_agent_run_manager().start_session_run(
        user_id=user.user_id,
        session_id=session_id,
        messages=[item.model_dump(exclude_none=True) for item in payload.messages],
        system_context=dict(payload.system_context or {}),
        consume_quota=has_messages,
    )
    return await Response.success(
        data={
            "session_id": session_id,
            "run_id": run_id,
            "status": "accepted",
        },
    )
