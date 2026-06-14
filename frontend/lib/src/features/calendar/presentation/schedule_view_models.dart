import 'package:flutter/material.dart';
import 'package:ling/src/features/calendar/models/apple_calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_time.dart';
import 'package:ling/src/features/calendar/presentation/schedule_formatters.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';

class LingScheduleAgendaItem {
  const LingScheduleAgendaItem({
    required this.title,
    required this.subtitle,
    this.location = '',
    required this.startAt,
    required this.endAt,
    this.isAllDay = false,
    this.isPoint = false,
    required this.accent,
    required this.sourceLabel,
    this.categoryLabel = '',
    required this.timeLabel,
    required this.durationLabel,
    this.startTimeLabel,
    this.endTimeLabel,
    this.recurrenceLabel = '',
    this.lingEvent,
    this.appleEvent,
  });

  final String title;
  final String subtitle;
  final String location;
  final DateTime startAt;
  final DateTime endAt;
  final bool isAllDay;
  final bool isPoint;
  final Color accent;
  final String sourceLabel;
  final String categoryLabel;
  final String timeLabel;
  final String durationLabel;
  final String? startTimeLabel;
  final String? endTimeLabel;
  final String recurrenceLabel;
  final LingEvent? lingEvent;
  final AppleCalendarEvent? appleEvent;

  bool get isEditableLingEvent {
    final event = lingEvent;
    if (event == null) {
      return false;
    }
    if (event.isMutable) {
      return true;
    }
    return event.source == 'apple' &&
        (event.appleLink?.eventIdentifier?.trim().isNotEmpty ?? false);
  }

  bool get isDeletable => lingEvent?.isDeletable == true || appleEvent != null;
}

enum LingCalendarScheduleMode { week, month }

enum LingSchedulePrimaryTab { events }

class LingScheduleDayBucket {
  const LingScheduleDayBucket({required this.date, required this.items});

  final DateTime date;
  final List<LingScheduleAgendaItem> items;
}

List<LingScheduleAgendaItem> buildLingScheduleAgendaItems({
  required LingStrings strings,
  required String selectedDate,
  required List<LingEvent> lingEvents,
  required List<AppleCalendarEvent> appleEvents,
  Brightness brightness = Brightness.light,
}) {
  final selectedDay = parseLingDateOnly(selectedDate);
  final items = <LingScheduleAgendaItem>[];

  for (final event in lingEvents) {
    items.addAll(
      _agendaItemsFromUnifiedEventForDay(
        strings,
        event,
        selectedDay,
        brightness: brightness,
      ),
    );
  }

  final mirroredAppleEventIds = _mirroredAppleEventIdsForLingEvents(lingEvents);
  final unifiedAppleEventIds = _unifiedAppleEventIdsForSourceAppleRows(
    lingEvents,
  );
  for (final event in appleEvents) {
    if (mirroredAppleEventIds.contains(event.identifier) ||
        unifiedAppleEventIds.contains(event.identifier)) {
      continue;
    }
    items.addAll(
      _agendaItemsFromAppleEventForDay(
        strings,
        event,
        selectedDay,
        brightness: brightness,
      ),
    );
  }

  items.sort((a, b) => a.startAt.compareTo(b.startAt));
  return items;
}

List<LingScheduleDayBucket> buildLingScheduleDayBuckets({
  required LingStrings strings,
  required DateTime startDate,
  required List<LingEvent> lingEvents,
  required List<AppleCalendarEvent> appleEvents,
  Brightness brightness = Brightness.light,
}) {
  final anchorDate = DateTime(startDate.year, startDate.month, startDate.day);
  final dates = List<DateTime>.generate(
    7,
    (index) => anchorDate.add(Duration(days: index)),
    growable: false,
  );
  final buckets = <String, List<LingScheduleAgendaItem>>{
    for (final date in dates)
      formatLingDateYmd(date): <LingScheduleAgendaItem>[],
  };

  for (final event in lingEvents) {
    for (final date in dates) {
      final items = buckets[formatLingDateYmd(date)]!;
      items.addAll(
        _agendaItemsFromUnifiedEventForDay(
          strings,
          event,
          date,
          brightness: brightness,
        ),
      );
    }
  }

  final mirroredAppleEventIds = _mirroredAppleEventIdsForLingEvents(lingEvents);
  final unifiedAppleEventIds = _unifiedAppleEventIdsForSourceAppleRows(
    lingEvents,
  );
  for (final event in appleEvents) {
    if (mirroredAppleEventIds.contains(event.identifier) ||
        unifiedAppleEventIds.contains(event.identifier)) {
      continue;
    }
    for (final date in dates) {
      final items = buckets[formatLingDateYmd(date)]!;
      items.addAll(
        _agendaItemsFromAppleEventForDay(
          strings,
          event,
          date,
          brightness: brightness,
        ),
      );
    }
  }

  return dates
      .map((date) {
        final key = formatLingDateYmd(date);
        final items = buckets[key]!
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
        return LingScheduleDayBucket(
          date: date,
          items: List<LingScheduleAgendaItem>.unmodifiable(items),
        );
      })
      .toList(growable: false);
}

List<LingEvent> resolveLingScheduleWindowEvents({
  required DateTime windowStartDate,
  required bool hasLoadedWindowEvents,
  required List<LingEvent> windowEvents,
  required List<LingEvent> selectedDayEvents,
}) {
  if (windowEvents.isNotEmpty || hasLoadedWindowEvents) {
    return List<LingEvent>.unmodifiable(windowEvents);
  }

  final startDateOnly = DateTime(
    windowStartDate.year,
    windowStartDate.month,
    windowStartDate.day,
  );
  final fallbackTodayEvents = selectedDayEvents
      .where((event) => isSameCalendarDay(event.startAt, startDateOnly))
      .toList(growable: false);
  if (fallbackTodayEvents.isEmpty) {
    return const <LingEvent>[];
  }
  return List<LingEvent>.unmodifiable(fallbackTodayEvents);
}

List<LingScheduleAgendaItem> _agendaItemsFromUnifiedEventForDay(
  LingStrings strings,
  LingEvent event,
  DateTime day, {
  required Brightness brightness,
}) {
  final segment = _eventSegmentForDay(
    event.startAt,
    event.endAt,
    day,
    isAllDay: false,
    isPoint: event.isPoint,
  );
  if (segment == null) {
    return const <LingScheduleAgendaItem>[];
  }
  return <LingScheduleAgendaItem>[
    event.source == 'apple'
        ? _agendaItemFromStoredAppleEvent(
            strings,
            event,
            segmentStartAt: segment.startAt,
            segmentEndAt: segment.endAt,
            displayStartTimeLabel: segment.displayStartTimeLabel,
            displayEndTimeLabel: segment.displayEndTimeLabel,
            brightness: brightness,
          )
        : _agendaItemFromLingEvent(
            strings,
            event,
            segmentStartAt: segment.startAt,
            segmentEndAt: segment.endAt,
            displayStartTimeLabel: segment.displayStartTimeLabel,
            displayEndTimeLabel: segment.displayEndTimeLabel,
            brightness: brightness,
          ),
  ];
}

LingScheduleAgendaItem _agendaItemFromLingEvent(
  LingStrings strings,
  LingEvent event, {
  required DateTime segmentStartAt,
  required DateTime segmentEndAt,
  String? displayStartTimeLabel,
  String? displayEndTimeLabel,
  required Brightness brightness,
}) {
  final isPointLike =
      event.isPoint || event.startAt.isAtSameMomentAs(event.endAt);
  return LingScheduleAgendaItem(
    title: event.title.isEmpty ? strings.untitled : event.title,
    subtitle: event.subtitle ?? '',
    location: event.location ?? '',
    startAt: segmentStartAt,
    endAt: segmentEndAt,
    isPoint: isPointLike,
    isAllDay: false,
    accent: lingAccentForCategory(event.category, brightness: brightness),
    sourceLabel: '',
    categoryLabel: strings.calendarToolCallCategoryLabel(event.category),
    timeLabel: isPointLike
        ? (displayStartTimeLabel ?? _formatHourMinute(segmentStartAt))
        : _formatAgendaTimeRange(
            segmentStartAt,
            segmentEndAt,
            endLabelOverride: displayEndTimeLabel,
          ),
    durationLabel: isPointLike
        ? ''
        : formatLingAgendaDurationLabel(
            strings,
            segmentEndAt.difference(segmentStartAt),
          ),
    startTimeLabel: displayStartTimeLabel,
    endTimeLabel: displayEndTimeLabel,
    recurrenceLabel:
        formatLingRecurrenceBadgeLabel(
          strings,
          isRecurring: event.isRecurring,
          recurrence: event.recurrence,
          anchorStartAt: event.startAt,
        ) ??
        '',
    lingEvent: event,
  );
}

LingScheduleAgendaItem _agendaItemFromStoredAppleEvent(
  LingStrings strings,
  LingEvent event, {
  required DateTime segmentStartAt,
  required DateTime segmentEndAt,
  String? displayStartTimeLabel,
  String? displayEndTimeLabel,
  required Brightness brightness,
}) {
  final metadata = event.metadata;
  final calendarTitle = '${metadata['calendar_title'] ?? ''}'.trim();
  final kind = '${metadata['kind'] ?? 'event'}'.trim().toLowerCase();
  final isHoliday = kind == 'holiday';
  final isAllDay = metadata['is_all_day'] == true;
  return LingScheduleAgendaItem(
    title: event.title.isEmpty ? strings.untitled : event.title,
    subtitle: event.subtitle ?? '',
    location: event.location ?? '',
    startAt: segmentStartAt,
    endAt: segmentEndAt,
    isAllDay: isAllDay,
    accent: lingAppleAccent(isHoliday: isHoliday, brightness: brightness),
    sourceLabel: calendarTitle.isNotEmpty
        ? calendarTitle
        : (isHoliday ? strings.sourceAppleHoliday : strings.sourceApple),
    categoryLabel: isHoliday ? strings.sourceAppleHoliday : strings.sourceApple,
    timeLabel: isAllDay
        ? strings.allDay
        : _formatAgendaTimeRange(
            segmentStartAt,
            segmentEndAt,
            endLabelOverride: displayEndTimeLabel,
          ),
    durationLabel: isAllDay
        ? strings.allDay
        : formatLingAgendaDurationLabel(
            strings,
            segmentEndAt.difference(segmentStartAt),
          ),
    startTimeLabel: displayStartTimeLabel,
    endTimeLabel: displayEndTimeLabel,
    recurrenceLabel:
        formatLingRecurrenceBadgeLabel(
          strings,
          isRecurring: event.isRecurring,
          recurrence: event.recurrence,
          anchorStartAt: event.startAt,
        ) ??
        '',
    lingEvent: event,
  );
}

LingScheduleAgendaItem _agendaItemFromAppleEvent(
  LingStrings strings,
  AppleCalendarEvent event, {
  required DateTime segmentStartAt,
  required DateTime segmentEndAt,
  String? displayStartTimeLabel,
  String? displayEndTimeLabel,
  required Brightness brightness,
}) {
  final isHoliday = event.kind == AppleCalendarEventKind.holiday;
  final isAllDay = event.isAllDay;
  final sourceLabel = event.calendarTitle?.trim() ?? '';
  return LingScheduleAgendaItem(
    title: event.title,
    subtitle: event.notes ?? '',
    location: event.location ?? '',
    startAt: segmentStartAt,
    endAt: segmentEndAt,
    isAllDay: isAllDay,
    accent: lingAppleAccent(isHoliday: isHoliday, brightness: brightness),
    sourceLabel: sourceLabel.isNotEmpty
        ? sourceLabel
        : (isHoliday ? strings.sourceAppleHoliday : strings.sourceApple),
    categoryLabel: isHoliday ? strings.sourceAppleHoliday : strings.sourceApple,
    timeLabel: isAllDay
        ? strings.allDay
        : _formatAgendaTimeRange(
            segmentStartAt,
            segmentEndAt,
            endLabelOverride: displayEndTimeLabel,
          ),
    durationLabel: isAllDay
        ? strings.allDay
        : formatLingAgendaDurationLabel(
            strings,
            segmentEndAt.difference(segmentStartAt),
          ),
    startTimeLabel: displayStartTimeLabel,
    endTimeLabel: displayEndTimeLabel,
    recurrenceLabel:
        formatLingRecurrenceBadgeLabel(
          strings,
          isRecurring: event.isRecurring,
          recurrence: event.recurrence,
          anchorStartAt: event.startAt,
          rawRRules: event.rawRRules,
        ) ??
        '',
    appleEvent: event,
  );
}

List<LingScheduleAgendaItem> _agendaItemsFromAppleEventForDay(
  LingStrings strings,
  AppleCalendarEvent event,
  DateTime day, {
  required Brightness brightness,
}) {
  final segment = _eventSegmentForDay(
    event.startAt,
    event.endAt,
    day,
    isAllDay: event.isAllDay,
  );
  if (segment == null) {
    return const <LingScheduleAgendaItem>[];
  }
  return <LingScheduleAgendaItem>[
    _agendaItemFromAppleEvent(
      strings,
      event,
      segmentStartAt: segment.startAt,
      segmentEndAt: segment.endAt,
      displayStartTimeLabel: segment.displayStartTimeLabel,
      displayEndTimeLabel: segment.displayEndTimeLabel,
      brightness: brightness,
    ),
  ];
}

Set<String> _mirroredAppleEventIdsForLingEvents(List<LingEvent> lingEvents) {
  return lingEvents
      .where((event) => event.source == 'ling')
      .map((event) => event.appleLink)
      .whereType<AppleEventLink>()
      .map((link) => link.eventIdentifier?.trim() ?? '')
      .where((identifier) => identifier.isNotEmpty)
      .toSet();
}

Set<String> _unifiedAppleEventIdsForSourceAppleRows(
  List<LingEvent> lingEvents,
) {
  return lingEvents
      .where((event) => event.source == 'apple')
      .map((event) => event.appleLink?.eventIdentifier?.trim() ?? '')
      .where((identifier) => identifier.isNotEmpty)
      .toSet();
}

_AgendaDaySegment? _eventSegmentForDay(
  DateTime startAt,
  DateTime endAt,
  DateTime day, {
  required bool isAllDay,
  bool isPoint = false,
}) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final nextDayStart = dayStart.add(const Duration(days: 1));
  if (isPoint) {
    if (startAt.isBefore(dayStart) || !startAt.isBefore(nextDayStart)) {
      return null;
    }
    return _AgendaDaySegment(
      startAt: startAt,
      endAt: startAt,
      displayStartTimeLabel: _formatHourMinute(startAt),
      displayEndTimeLabel: null,
    );
  }
  if (!endAt.isAfter(dayStart) || !startAt.isBefore(nextDayStart)) {
    return null;
  }
  if (isAllDay) {
    return _AgendaDaySegment(startAt: dayStart, endAt: nextDayStart);
  }
  final clippedStart = startAt.isAfter(dayStart) ? startAt : dayStart;
  final clippedEnd = endAt.isBefore(nextDayStart) ? endAt : nextDayStart;
  return _AgendaDaySegment(
    startAt: clippedStart,
    endAt: clippedEnd,
    displayStartTimeLabel: clippedStart.isAtSameMomentAs(dayStart)
        ? '00:00'
        : _formatHourMinute(clippedStart),
    displayEndTimeLabel: clippedEnd.isAtSameMomentAs(nextDayStart)
        ? '24:00'
        : _formatHourMinute(clippedEnd),
  );
}

String _formatAgendaTimeRange(
  DateTime startAt,
  DateTime endAt, {
  String? startLabelOverride,
  String? endLabelOverride,
}) {
  return '${startLabelOverride ?? _formatHourMinute(startAt)} - ${endLabelOverride ?? _formatHourMinute(endAt)}';
}

String _formatHourMinute(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _AgendaDaySegment {
  const _AgendaDaySegment({
    required this.startAt,
    required this.endAt,
    this.displayStartTimeLabel,
    this.displayEndTimeLabel,
  });

  final DateTime startAt;
  final DateTime endAt;
  final String? displayStartTimeLabel;
  final String? displayEndTimeLabel;
}
