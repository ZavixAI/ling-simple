from __future__ import annotations

from datetime import datetime
from typing import Optional, Sequence

from sqlalchemy import JSON, Index, String
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column

from config import constants
from .base import Base, BaseDao, get_local_now


class CalendarEvent(Base):
    __tablename__ = "events"

    event_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    source: Mapped[str] = mapped_column(String(32), nullable=False, default=constants.CALENDAR_SOURCE_LING, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    subtitle: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    category: Mapped[str] = mapped_column(String(64), nullable=False, default=constants.DEFAULT_CALENDAR_CATEGORY)
    time_shape: Mapped[str] = mapped_column(String(16), nullable=False, default=constants.CALENDAR_TIME_SHAPE_SPAN, index=True)
    start_at: Mapped[datetime] = mapped_column(nullable=False, index=True)
    end_at: Mapped[datetime] = mapped_column(nullable=False, index=True)
    timezone: Mapped[str] = mapped_column(String(64), nullable=False, default=constants.UTC_TIMEZONE_NAME)
    location: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    meeting_url: Mapped[Optional[str]] = mapped_column(String(1024), nullable=True)
    attendees: Mapped[list] = mapped_column(JSON, nullable=False, default=[])
    status: Mapped[str] = mapped_column(String(32), nullable=False, default=constants.CALENDAR_STATUS_SCHEDULED)
    focus_mode_enabled: Mapped[bool] = mapped_column(nullable=False, default=False)
    series_id: Mapped[Optional[str]] = mapped_column(String(128), nullable=True, index=True)
    recurrence_parent_event_id: Mapped[Optional[str]] = mapped_column(String(128), nullable=True, index=True)
    occurrence_start_at: Mapped[Optional[datetime]] = mapped_column(nullable=True, index=True)
    recurrence_rule: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    recurrence_rrule: Mapped[Optional[str]] = mapped_column(String(2048), nullable=True)
    recurrence_exdates: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    is_occurrence_override: Mapped[bool] = mapped_column(nullable=False, default=False)
    source_device_id: Mapped[Optional[str]] = mapped_column(String(128), nullable=True, index=True)
    external_calendar_identifier: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    external_event_identifier: Mapped[Optional[str]] = mapped_column(String(255), nullable=True, index=True)
    external_calendar_item_identifier: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        index=True,
    )
    is_active: Mapped[bool] = mapped_column(nullable=False, default=True, index=True)
    extra_data: Mapped[dict] = mapped_column(JSON, nullable=False, default={})
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        event_id: str,
        user_id: str,
        title: str,
        start_at: datetime,
        end_at: datetime,
        timezone: str,
        source: str = constants.CALENDAR_SOURCE_LING,
        subtitle: Optional[str] = None,
        category: str = constants.DEFAULT_CALENDAR_CATEGORY,
        time_shape: str = constants.CALENDAR_TIME_SHAPE_SPAN,
        location: Optional[str] = None,
        meeting_url: Optional[str] = None,
        attendees: Optional[list] = None,
        status: str = constants.CALENDAR_STATUS_SCHEDULED,
        focus_mode_enabled: bool = False,
        series_id: Optional[str] = None,
        recurrence_parent_event_id: Optional[str] = None,
        occurrence_start_at: Optional[datetime] = None,
        recurrence_rule: Optional[dict] = None,
        recurrence_rrule: Optional[str] = None,
        recurrence_exdates: Optional[list] = None,
        is_occurrence_override: bool = False,
        source_device_id: Optional[str] = None,
        external_calendar_identifier: Optional[str] = None,
        external_event_identifier: Optional[str] = None,
        external_calendar_item_identifier: Optional[str] = None,
        is_active: bool = True,
        metadata: Optional[dict] = None,
    ):
        now = get_local_now()
        self.event_id = event_id
        self.user_id = user_id
        self.source = source
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.time_shape = time_shape
        self.start_at = start_at
        self.end_at = end_at
        self.timezone = timezone
        self.location = location
        self.meeting_url = meeting_url
        self.attendees = attendees or []
        self.status = status
        self.focus_mode_enabled = focus_mode_enabled
        self.series_id = series_id
        self.recurrence_parent_event_id = recurrence_parent_event_id
        self.occurrence_start_at = occurrence_start_at
        self.recurrence_rule = recurrence_rule
        self.recurrence_rrule = recurrence_rrule
        self.recurrence_exdates = recurrence_exdates or []
        self.is_occurrence_override = is_occurrence_override
        self.source_device_id = source_device_id
        self.external_calendar_identifier = external_calendar_identifier
        self.external_event_identifier = external_event_identifier
        self.external_calendar_item_identifier = external_calendar_item_identifier
        self.is_active = is_active
        self.extra_data = metadata or {}
        self.created_at = now
        self.updated_at = now


class CalendarEventLink(Base):
    __tablename__ = "calendar_event_links"

    link_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    event_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    provider_id: Mapped[str] = mapped_column(
        String(64), nullable=False, default=constants.CALENDAR_SOURCE_APPLE_LOCAL
    )
    device_id: Mapped[str] = mapped_column(String(128), nullable=False)
    calendar_identifier: Mapped[str] = mapped_column(String(255), nullable=False)
    event_identifier: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    sync_state: Mapped[str] = mapped_column(
        String(32), nullable=False, default=constants.CALENDAR_SYNC_STATE_LINKED
    )
    extra_data: Mapped[dict] = mapped_column(JSON, nullable=False, default={})
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        link_id: str,
        event_id: str,
        user_id: str,
        device_id: str,
        calendar_identifier: str,
        event_identifier: str,
        sync_state: str = constants.CALENDAR_SYNC_STATE_LINKED,
        provider_id: str = constants.CALENDAR_SOURCE_APPLE_LOCAL,
        metadata: Optional[dict] = None,
    ):
        now = get_local_now()
        self.link_id = link_id
        self.event_id = event_id
        self.user_id = user_id
        self.provider_id = provider_id
        self.device_id = device_id
        self.calendar_identifier = calendar_identifier
        self.event_identifier = event_identifier
        self.sync_state = sync_state
        self.extra_data = metadata or {}
        self.created_at = now
        self.updated_at = now


class AppleCalendarContext(Base):
    __tablename__ = "apple_calendar_contexts"
    __table_args__ = (
        Index(
            "ix_apple_calendar_contexts_user_device_updated_at",
            "user_id",
            "device_id",
            "updated_at",
        ),
        Index(
            "ix_apple_calendar_contexts_user_updated_at",
            "user_id",
            "updated_at",
        ),
    )

    context_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    device_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    permission_state: Mapped[str] = mapped_column(String(32), nullable=False, default="unknown")
    window_start: Mapped[datetime] = mapped_column(nullable=False)
    window_end: Mapped[datetime] = mapped_column(nullable=False)
    events: Mapped[list] = mapped_column(JSON, nullable=False, default=[])
    created_at: Mapped[datetime] = mapped_column(nullable=False)
    updated_at: Mapped[datetime] = mapped_column(nullable=False)

    def __init__(
        self,
        context_id: str,
        user_id: str,
        device_id: str,
        permission_state: str,
        window_start: datetime,
        window_end: datetime,
        events: Optional[list] = None,
    ):
        now = get_local_now()
        self.context_id = context_id
        self.user_id = user_id
        self.device_id = device_id
        self.permission_state = permission_state
        self.window_start = window_start
        self.window_end = window_end
        self.events = events or []
        self.created_at = now
        self.updated_at = now


class CalendarEventDao(BaseDao):
    async def save(
        self,
        event: CalendarEvent,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        event.updated_at = get_local_now()
        return await BaseDao.save(self, event, session=session)

    async def get_user_event(
        self,
        user_id: str,
        event_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[CalendarEvent]:
        return await BaseDao.get_first(
            self,
            CalendarEvent,
            where=[
                CalendarEvent.user_id == user_id,
                CalendarEvent.event_id == event_id,
            ],
            session=session,
        )

    async def list_user_events(
        self,
        user_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> list[CalendarEvent]:
        return await BaseDao.get_list(
            self,
            CalendarEvent,
            where=[CalendarEvent.user_id == user_id],
            order_by=CalendarEvent.start_at.asc(),
            session=session,
        )

    async def list_user_source_events(
        self,
        user_id: str,
        source: str,
        *,
        session: AsyncSession | None = None,
    ) -> list[CalendarEvent]:
        return await BaseDao.get_list(
            self,
            CalendarEvent,
            where=[
                CalendarEvent.user_id == user_id,
                CalendarEvent.source == source,
            ],
            order_by=CalendarEvent.start_at.asc(),
            session=session,
        )

    async def list_source_events(
        self,
        sources: Sequence[str],
        *,
        session: AsyncSession | None = None,
    ) -> list[CalendarEvent]:
        normalized_sources = [
            str(source).strip()
            for source in sources
            if str(source).strip()
        ]
        if not normalized_sources:
            raise ValueError("sources is required")
        return await BaseDao.get_list(
            self,
            CalendarEvent,
            where=[CalendarEvent.source.in_(normalized_sources)],
            order_by=CalendarEvent.start_at.asc(),
            session=session,
        )

    async def list_connection_source_events(
        self,
        user_id: str,
        source: str,
        connection_id: str,
        *,
        external_event_identifiers: set[str] | None = None,
        session: AsyncSession | None = None,
    ) -> list[CalendarEvent]:
        where = [
            CalendarEvent.user_id == user_id,
            CalendarEvent.source == source,
            CalendarEvent.source_device_id == connection_id,
        ]
        if external_event_identifiers:
            where.append(
                CalendarEvent.external_event_identifier.in_(external_event_identifiers)
            )
        return await BaseDao.get_list(
            self,
            CalendarEvent,
            where=where,
            order_by=CalendarEvent.start_at.asc(),
            session=session,
        )

    async def get_occurrence_override(
        self,
        user_id: str,
        parent_event_id: str,
        occurrence_start_at: datetime,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[CalendarEvent]:
        return await BaseDao.get_first(
            self,
            CalendarEvent,
            where=[
                CalendarEvent.user_id == user_id,
                CalendarEvent.recurrence_parent_event_id == parent_event_id,
                CalendarEvent.occurrence_start_at == occurrence_start_at,
                CalendarEvent.is_occurrence_override.is_(True),
            ],
            session=session,
        )


class CalendarEventLinkDao(BaseDao):
    async def save(
        self,
        link: CalendarEventLink,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        link.updated_at = get_local_now()
        return await BaseDao.save(self, link, session=session)

    async def get_by_event_id(
        self,
        event_id: str,
        user_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[CalendarEventLink]:
        return await BaseDao.get_first(
            self,
            CalendarEventLink,
            where=[
                CalendarEventLink.event_id == event_id,
                CalendarEventLink.user_id == user_id,
            ],
            session=session,
        )

    async def list_user_links(
        self,
        user_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> list[CalendarEventLink]:
        return await BaseDao.get_list(
            self,
            CalendarEventLink,
            where=[CalendarEventLink.user_id == user_id],
            order_by=CalendarEventLink.updated_at.desc(),
            session=session,
        )

    async def list_user_device_links(
        self,
        user_id: str,
        device_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> list[CalendarEventLink]:
        return await BaseDao.get_list(
            self,
            CalendarEventLink,
            where=[
                CalendarEventLink.user_id == user_id,
                CalendarEventLink.device_id == device_id,
            ],
            order_by=CalendarEventLink.updated_at.desc(),
            session=session,
        )

    async def list_all_links(
        self,
        *,
        session: AsyncSession | None = None,
    ) -> list[CalendarEventLink]:
        return await BaseDao.get_all(
            self,
            CalendarEventLink,
            order_by=CalendarEventLink.updated_at.desc(),
            session=session,
        )


class AppleCalendarContextDao(BaseDao):
    async def save(
        self,
        context: AppleCalendarContext,
        *,
        session: AsyncSession | None = None,
    ) -> bool:
        context.updated_at = get_local_now()
        return await BaseDao.save(self, context, session=session)

    async def get_latest_by_device(
        self,
        user_id: str,
        device_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> Optional[AppleCalendarContext]:
        return await BaseDao.get_first(
            self,
            AppleCalendarContext,
            where=[
                AppleCalendarContext.user_id == user_id,
                AppleCalendarContext.device_id == device_id,
            ],
            order_by=AppleCalendarContext.updated_at.desc(),
            session=session,
        )

    async def list_user_contexts(
        self,
        user_id: str,
        *,
        session: AsyncSession | None = None,
    ) -> list[AppleCalendarContext]:
        return await BaseDao.get_list(
            self,
            AppleCalendarContext,
            where=[AppleCalendarContext.user_id == user_id],
            order_by=AppleCalendarContext.updated_at.desc(),
            session=session,
        )
