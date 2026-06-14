"""Generic read-only access to Sage agent workspace files."""

from __future__ import annotations

import mimetypes
import posixpath
from dataclasses import dataclass
from pathlib import PurePosixPath
from urllib.parse import quote, unquote, urlparse

from config.settings import get_app_config
from services.agent.sage import SageClient

MAX_AGENT_FILE_BYTES = 10 * 1024 * 1024


@dataclass(frozen=True)
class AgentWorkspaceFileData:
    path: str
    filename: str
    content_type: str
    content: bytes


class AgentFileService:
    def __init__(self, sage_client: SageClient | None = None) -> None:
        self._sage_client = sage_client or SageClient()
        self._cfg = get_app_config()

    async def get_file_data(self, user_id: str, file_path: str) -> AgentWorkspaceFileData:
        normalized_path = normalize_agent_workspace_file_reference(
            file_path,
            user_id=user_id,
            agent_id=self._cfg.sage_agent_id,
        )
        download = await self._sage_client.download_workspace_file(
            user_id=user_id,
            agent_id=self._cfg.sage_agent_id,
            file_path=normalized_path,
            max_bytes=MAX_AGENT_FILE_BYTES,
        )
        filename = download.filename or _filename_from_path(normalized_path)
        content_type = _normalize_content_type(download.content_type, filename)
        return AgentWorkspaceFileData(
            path=normalized_path,
            filename=filename,
            content_type=content_type,
            content=download.content,
        )


def normalize_agent_workspace_file_reference(
    value: str,
    *,
    user_id: str | None = None,
    agent_id: str | None = None,
) -> str:
    candidate = (value or "").strip()
    if not candidate:
        raise ValueError("Invalid file path")
    if any(ord(ch) < 32 for ch in candidate):
        raise ValueError("Invalid file path")
    parsed = urlparse(candidate)
    if parsed.scheme:
        if parsed.scheme.lower() != "file":
            raise ValueError("Unsupported file URL")
        candidate = unquote(parsed.path or "")
    else:
        candidate = unquote(candidate)
    if not candidate.strip():
        raise ValueError("Invalid file path")
    candidate = candidate.replace("\\", "/").strip()
    if candidate.startswith("/sage-workspace/"):
        candidate = candidate.removeprefix("/sage-workspace/")
    if candidate.startswith("sage-workspace/"):
        candidate = candidate.removeprefix("sage-workspace/")
    virtual_prefix = _agent_virtual_workspace_prefix(user_id, agent_id)
    if virtual_prefix and candidate.startswith(virtual_prefix):
        candidate = candidate.removeprefix(virtual_prefix)
    if candidate.startswith("/"):
        return candidate
    normalized = posixpath.normpath(candidate)
    if normalized in {"", ".", ".."} or normalized.startswith("../"):
        raise ValueError("Invalid file path")
    parts = PurePosixPath(normalized).parts
    if any(part in {"", ".", ".."} or part.startswith(".") for part in parts):
        raise ValueError("Invalid file path")
    return normalized


def _agent_virtual_workspace_prefix(
    user_id: str | None,
    agent_id: str | None,
) -> str | None:
    normalized_user_id = (user_id or "").strip().strip("/")
    normalized_agent_id = (agent_id or "").strip().strip("/")
    if not normalized_user_id or not normalized_agent_id:
        return None
    return f"/app/agents/{normalized_user_id}/{normalized_agent_id}/"


def _filename_from_path(path: str) -> str:
    filename = PurePosixPath(path).name
    return filename or "file"


def _normalize_content_type(content_type: str | None, filename: str) -> str:
    value = (content_type or "").split(";", 1)[0].strip().lower()
    if value and value != "application/octet-stream":
        return content_type or value
    guessed = mimetypes.guess_type(filename)[0]
    return guessed or "application/octet-stream"


def agent_file_content_disposition(filename: str) -> str:
    fallback = "".join(
        ch if ch.isascii() and ch not in {'"', "\\", ";", "\r", "\n"} else "_"
        for ch in filename
    ).strip("_")
    if not fallback or fallback.startswith("."):
        fallback = "file"
    return f'inline; filename="{fallback}"; filename*=UTF-8\'\'{quote(filename)}'


def agent_file_path_header(path: str) -> str:
    """Encode a workspace path for HTTP headers.

    Starlette encodes header values as latin-1, so non-ASCII paths must be
    percent-encoded before they are placed in a custom header.
    """

    return quote(path, safe="/:._-~")
