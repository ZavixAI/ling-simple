"""为 Sage 请求拼装 system_context：时区、本地时间、粗略位置与回复语言偏好。"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from config import constants
from models.push import UserPushDevice, UserPushDeviceDao
from models.user import UserConfigDao
from utils.time import format_datetime, parse_timezone


class AgentRuntimeContextBuilder:
    """在发起对话前 enrich()，把设备侧上下文合并进上游传入的 system_context。"""

    _RESPONSE_LANGUAGE_INSTRUCTIONS = {
        "zh": (
            "用户可见的回复、通知、操作按钮、Ling 的一天摘要和面向用户的工具内容"
            "使用中文。内部工具参数按工具要求填写。"
        ),
        "en": (
            "Use English for user-visible replies, notifications, action labels, "
            "assistant summaries, and user-facing tool content. Internal tool "
            "arguments may keep their required schema values."
        ),
    }

    def __init__(self) -> None:
        self.push_device_dao = UserPushDeviceDao()
        self.user_config_dao = UserConfigDao()

    async def enrich(
        self,
        user_id: str,
        system_context: dict[str, Any],
        *,
        digest_profile: str = "default",
    ) -> dict[str, Any]:
        resolved_context = dict(system_context or {})
        latest_device = await self.push_device_dao.get_latest_device(user_id)
        user_config = await self._get_user_config(user_id)

        resolved_timezone = self._resolve_user_timezone(
            latest_device,
            resolved_context,
            user_config,
        )
        last_known_location = self._resolve_user_location(latest_device)
        resolved_local_time = self._resolve_user_local_time(resolved_timezone)
        resolved_response_language = self._resolve_user_response_language(
            latest_device,
            user_config,
        )

        resolved_context.pop("current_location", None)
        resolved_context["last_known_location"] = last_known_location
        resolved_context["current_timezone"] = resolved_timezone
        resolved_context["current_time"] = resolved_local_time
        resolved_context["response_language"] = resolved_response_language
        resolved_context["response_language_instruction"] = (
            self._response_language_instruction(resolved_response_language)
        )
        resolved_context.pop("user_context_digest", None)
        return resolved_context

    async def _get_user_config(self, user_id: str) -> dict[str, Any]:
        try:
            return await self.user_config_dao.get_config(user_id)
        except Exception:
            return {}

    def _resolve_user_timezone(
        self,
        latest_device: UserPushDevice | None,
        system_context: dict[str, Any],
        user_config: dict[str, Any],
    ) -> str:
        candidates = []
        if latest_device is not None:
            candidates.append(self._normalize_string(latest_device.timezone))
        candidates.append(self._normalize_string(user_config.get("timezone")))
        candidates.append(self._normalize_string(system_context.get("current_timezone")))
        candidates.append(self._normalize_string(system_context.get("timezone")))
        candidates.append(constants.DEFAULT_TIMEZONE)
        for candidate in candidates:
            if candidate is None:
                continue
            try:
                parse_timezone(candidate)
            except Exception:
                continue
            return candidate
        return constants.DEFAULT_TIMEZONE

    def _resolve_user_location(
        self,
        latest_device: UserPushDevice | None,
    ) -> str:
        if latest_device is None:
            return ""
        return self._format_device_location(latest_device)

    def _resolve_user_local_time(
        self,
        timezone_name: str,
    ) -> str:
        try:
            zone = parse_timezone(timezone_name)
        except Exception:
            zone = parse_timezone(constants.UTC_TIMEZONE_NAME)
        current_time = datetime.now().astimezone(zone)
        formatted = format_datetime(current_time) or ""
        return f"{formatted}, {current_time.strftime('%A')}"

    def _resolve_user_response_language(
        self,
        latest_device: UserPushDevice | None,
        user_config: dict[str, Any],
    ) -> str:
        candidates = [self._normalize_string(user_config.get("locale"))]
        if latest_device is not None:
            candidates.append(self._normalize_string(getattr(latest_device, "locale", None)))
        candidates.append(constants.DEFAULT_LOCALE)
        for candidate in candidates:
            if candidate:
                return candidate
        return constants.DEFAULT_LOCALE

    def _response_language_instruction(self, locale: str) -> str:
        language_code = self._response_language_code(locale)
        return self._RESPONSE_LANGUAGE_INSTRUCTIONS.get(
            language_code,
            self._RESPONSE_LANGUAGE_INSTRUCTIONS["en"],
        )

    def _response_language_code(self, locale: str | None) -> str:
        normalized = str(locale or constants.DEFAULT_LOCALE).strip().lower()
        return normalized.split("-", 1)[0].split("_", 1)[0]

    def _format_device_location(self, device: UserPushDevice) -> str:
        location_data = device.location_data or {}
        address = self._format_approximate_address(location_data)

        latitude = location_data.get("latitude")
        longitude = location_data.get("longitude")
        accuracy = location_data.get("accuracy_meters")

        coord_str = ""
        if latitude is not None and longitude is not None:
            coord_str = f"{latitude}, {longitude}"

            # 拼误差（放在括号内）
            if accuracy is not None:
                try:
                    accuracy_val = float(accuracy)
                    coord_str += f" ±{int(accuracy_val)}m"
                except (ValueError, TypeError):
                    pass

            coord_str = f"({coord_str})"

        recorded_ago = self._format_location_recorded_ago(device, location_data)
        parts = []
        if address:
            parts.append(f"大概地址：{address}")
        if coord_str:
            parts.append(f"坐标：{coord_str}")
        if recorded_ago:
            parts.append(f"{recorded_ago}记录")
        if not parts:
            return ""
        parts.append("文字地址为系统反查的大概地址，精确位置以坐标为准。")
        return "；".join(parts)

    def _format_approximate_address(self, location_data: dict[str, Any]) -> str:
        formatted = self._normalize_string(location_data.get("formatted_address"))
        if formatted:
            return formatted
        segments = []
        for key in (
            "name",
            "sub_thoroughfare",
            "thoroughfare",
            "sub_locality",
            "locality",
            "city",
            "sub_administrative_area",
            "administrative_area",
            "postal_code",
            "country",
        ):
            value = self._normalize_string(location_data.get(key))
            if value and value not in segments:
                segments.append(value)
        areas = location_data.get("areas_of_interest")
        if isinstance(areas, list):
            for area in areas:
                value = self._normalize_string(area)
                if value and value not in segments:
                    segments.insert(0, value)
        return ", ".join(segments)

    def _format_location_recorded_ago(
        self,
        device: UserPushDevice,
        location_data: dict[str, Any],
    ) -> str:
        timestamp = self._parse_datetime(location_data.get("captured_at"))
        if timestamp is None:
            timestamp = getattr(device, "location_updated_at", None)
        if timestamp is None:
            return ""
        now = datetime.now(tz=timestamp.tzinfo) if timestamp.tzinfo else datetime.now()
        seconds = max(0, int((now - timestamp).total_seconds()))
        if seconds < 60:
            return "刚刚"
        minutes = seconds // 60
        if minutes < 60:
            return f"约 {minutes} 分钟前"
        hours = minutes // 60
        if hours < 24:
            return f"约 {hours} 小时前"
        days = hours // 24
        return f"约 {days} 天前"

    def _parse_datetime(self, value: Any) -> datetime | None:
        if not isinstance(value, str) or not value.strip():
            return None
        normalized = value.strip()
        if normalized.endswith("Z"):
            normalized = f"{normalized[:-1]}+00:00"
        try:
            return datetime.fromisoformat(normalized)
        except ValueError:
            return None

    def _normalize_string(self, value: Any) -> str | None:
        if value is None:
            return None
        normalized = str(value).strip()
        return normalized or None
