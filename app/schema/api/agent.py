"""Agent API payload schemas."""

from __future__ import annotations

from typing import Any, Literal

from config import constants
from pydantic import BaseModel, Field, field_validator


class AgentMessagePayload(BaseModel):
    message_id: str | None = None
    role: Literal["system", "user", "assistant", "tool"]
    content: str | list[dict[str, Any]] | None = None
    metadata: dict[str, Any] | None = None


class AgentSessionCreatePayload(BaseModel):
    entry_mode: str = "text"
    selected_date: str | None = None
    timezone: str = constants.UTC_TIMEZONE_NAME


class AgentStreamPayload(BaseModel):
    messages: list[AgentMessagePayload]
    system_context: dict[str, Any] = Field(default_factory=dict)
    client_run_id: str

    @field_validator("client_run_id")
    @classmethod
    def validate_client_run_id(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("client_run_id is required")
        return normalized


class AgentRunCreatePayload(BaseModel):
    messages: list[AgentMessagePayload]
    system_context: dict[str, Any] = Field(default_factory=dict)


class AgentInjectUserMessagePayload(BaseModel):
    content: str | list[dict[str, Any]]
    guidance_id: str | None = None
    metadata: dict[str, Any] | None = None


class AgentUpdateInjectUserMessagePayload(BaseModel):
    content: str | list[dict[str, Any]]


__all__ = [
    "AgentInjectUserMessagePayload",
    "AgentMessagePayload",
    "AgentRunCreatePayload",
    "AgentSessionCreatePayload",
    "AgentStreamPayload",
    "AgentUpdateInjectUserMessagePayload",
]
