import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/features/calendar/application/calendar_notification_support.dart';
import 'package:ling/src/features/calendar/application/schedule_surface_controller.dart';
import 'package:ling/src/features/calendar/data/bridges/apple_calendar_bridge.dart';
import 'package:ling/src/features/calendar/models/calendar_event_editor_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_time.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';

enum ScheduleEventMutationScope { occurrence, series }

extension ScheduleEventMutationScopeApi on ScheduleEventMutationScope {
  String get apiValue =>
      this == ScheduleEventMutationScope.occurrence ? 'occurrence' : 'series';

  AppleCalendarMutationSpan get appleSpan =>
      this == ScheduleEventMutationScope.occurrence
      ? AppleCalendarMutationSpan.thisEvent
      : AppleCalendarMutationSpan.futureEvents;
}

ScheduleEventMutationScope? scheduleEventMutationScopeFromApiValue(
  String? value,
) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'occurrence':
      return ScheduleEventMutationScope.occurrence;
    case 'series':
      return ScheduleEventMutationScope.series;
    default:
      return null;
  }
}

String? occurrenceStartTimeForScheduleMutation(
  LingEvent event,
  ScheduleEventMutationScope scope,
) {
  if (scope != ScheduleEventMutationScope.occurrence) {
    return null;
  }
  final occurrenceStartAt = event.occurrenceStartAt ?? event.startAt;
  return formatLingDateTimeWithTimezone(occurrenceStartAt, event.timezone);
}

class ScheduleEventActions {
  const ScheduleEventActions({
    required AppleCalendarBridge appleCalendarBridge,
    required ScheduleSurfaceController scheduleSurfaceController,
  }) : _appleCalendarBridge = appleCalendarBridge,
       _scheduleSurfaceController = scheduleSurfaceController;

  final AppleCalendarBridge _appleCalendarBridge;
  final ScheduleSurfaceController _scheduleSurfaceController;

  Future<void> updateEvent({
    required LingEvent event,
    required LingCalendarEventDraft draft,
    required ScheduleEventMutationScope mutationScope,
    required String timezone,
    required LingStrings strings,
    required CalendarNotificationSettings calendarNotificationSettings,
    required Future<void> Function({bool forceRefresh}) refreshAppleCalendar,
  }) async {
    if (event.source == 'apple') {
      await updateImportedAppleEvent(
        event: event,
        draft: draft,
        mutationScope: mutationScope,
        strings: strings,
        calendarNotificationSettings: calendarNotificationSettings,
      );
    } else {
      await _scheduleSurfaceController.updateEvent(
        event: event,
        draft: draft,
        timezone: timezone,
        strings: strings,
        calendarNotificationSettings: calendarNotificationSettings,
        mutation: ScheduleSurfaceEventMutation(
          scopeApiValue: mutationScope.apiValue,
          appleSpan: mutationScope.appleSpan,
          includeRecurrence: mutationScope == ScheduleEventMutationScope.series,
          occurrenceStartTime: occurrenceStartTimeForScheduleMutation(
            event,
            mutationScope,
          ),
        ),
      );
    }
    await refreshAppleCalendar(forceRefresh: true);
    await _scheduleSurfaceController.refreshWindowEvents(
      timezone: timezone,
      forceRefresh: true,
    );
  }

  Future<void> updateImportedAppleEvent({
    required LingEvent event,
    required LingCalendarEventDraft draft,
    required ScheduleEventMutationScope mutationScope,
    required LingStrings strings,
    required CalendarNotificationSettings calendarNotificationSettings,
  }) async {
    final eventIdentifier = event.appleLink?.eventIdentifier?.trim() ?? '';
    if (eventIdentifier.isEmpty) {
      throw StateError('Apple event identifier is missing');
    }
    await _appleCalendarBridge.updateEvent(
      AppleCalendarMutationOptions(
        eventIdentifier: eventIdentifier,
        calendarItemIdentifier: event.appleLink?.calendarItemIdentifier,
        occurrenceDate: mutationScope == ScheduleEventMutationScope.occurrence
            ? (event.occurrenceStartAt ?? event.startAt)
            : null,
        span: mutationScope.appleSpan,
      ),
      buildAppleCalendarDraftFromLingEvent(
        event: event.copyWith(
          title: draft.title,
          subtitle: draft.location,
          location: draft.location,
          meetingUrl: draft.meetingUrl,
          startAt: draft.startAt,
          endAt: draft.endAt,
          timezone: event.timezone,
          recurrence: draft.recurrence,
          isRecurring: draft.recurrence != null,
        ),
        alarms: buildAppleCalendarAlarmPayload(
          calendarNotificationSettings,
          event: event,
        ),
        fallbackTitle: strings.untitled,
        calendarIdentifier: event.appleLink?.calendarIdentifier,
        includeRecurrence: mutationScope == ScheduleEventMutationScope.series,
      ),
    );
  }

  Future<void> deleteLingEvent({
    required LingEvent event,
    required ScheduleEventMutationScope mutationScope,
    required String timezone,
    required LingStrings strings,
    required Future<void> Function({bool forceRefresh}) refreshAppleCalendar,
  }) async {
    if (event.source == 'apple') {
      await deleteImportedAppleEvent(
        event: event,
        mutationScope: mutationScope,
        timezone: timezone,
        refreshAppleCalendar: refreshAppleCalendar,
      );
      return;
    }
    await _scheduleSurfaceController.deleteEvent(
      event: event,
      timezone: timezone,
      scopeApiValue: mutationScope.apiValue,
      appleSpan: mutationScope.appleSpan,
      occurrenceStartTime: occurrenceStartTimeForScheduleMutation(
        event,
        mutationScope,
      ),
    );
    await refreshAppleCalendar(forceRefresh: true);
    await _scheduleSurfaceController.refreshWindowEvents(
      timezone: timezone,
      forceRefresh: true,
    );
  }

  Future<void> deleteAppleCalendarEvent({
    required AppleCalendarEvent event,
    required ScheduleEventMutationScope mutationScope,
    required String timezone,
    required Future<void> Function({bool forceRefresh}) refreshAppleCalendar,
  }) async {
    await _appleCalendarBridge.deleteEvent(
      AppleCalendarMutationOptions(
        eventIdentifier: event.identifier.trim(),
        calendarItemIdentifier: event.calendarItemIdentifier,
        occurrenceDate: mutationScope == ScheduleEventMutationScope.occurrence
            ? (event.occurrenceDate ?? event.startAt)
            : null,
        span: mutationScope.appleSpan,
      ),
    );
    await refreshAppleCalendar(forceRefresh: true);
    await _scheduleSurfaceController.refreshWindowEvents(
      timezone: timezone,
      forceRefresh: true,
    );
  }

  Future<void> deleteImportedAppleEvent({
    required LingEvent event,
    required ScheduleEventMutationScope mutationScope,
    required String timezone,
    required Future<void> Function({bool forceRefresh}) refreshAppleCalendar,
  }) async {
    final eventIdentifier = event.appleLink?.eventIdentifier?.trim() ?? '';
    if (eventIdentifier.isEmpty) {
      return;
    }
    await _appleCalendarBridge.deleteEvent(
      AppleCalendarMutationOptions(
        eventIdentifier: eventIdentifier,
        calendarItemIdentifier: event.appleLink?.calendarItemIdentifier,
        occurrenceDate: mutationScope == ScheduleEventMutationScope.occurrence
            ? (event.occurrenceStartAt ?? event.startAt)
            : null,
        span: mutationScope.appleSpan,
      ),
    );
    await refreshAppleCalendar(forceRefresh: true);
    await _scheduleSurfaceController.refreshWindowEvents(
      timezone: timezone,
      forceRefresh: true,
    );
  }
}

final scheduleEventActionsProvider = Provider<ScheduleEventActions>((ref) {
  return ScheduleEventActions(
    appleCalendarBridge: ref.read(appleCalendarBridgeProvider),
    scheduleSurfaceController: ref.read(
      scheduleSurfaceControllerProvider.notifier,
    ),
  );
});
