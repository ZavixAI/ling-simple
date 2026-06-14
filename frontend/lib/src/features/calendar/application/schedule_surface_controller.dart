import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/storage/push_device_id_store.dart';
import 'package:ling/src/features/calendar/application/calendar_controller.dart';
import 'package:ling/src/features/calendar/application/calendar_notification_support.dart';
import 'package:ling/src/features/calendar/application/event_editor_support.dart';
import 'package:ling/src/features/calendar/data/bridges/apple_calendar_bridge.dart';
import 'package:ling/src/features/calendar/data/repositories/apple_calendar_sync_repository.dart';
import 'package:ling/src/features/calendar/models/calendar_event_editor_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_time.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';

class ScheduleSurfaceState {
  const ScheduleSurfaceState({
    this.windowEvents = const <LingEvent>[],
    this.hasLoadedWindowEvents = false,
    this.isLoadingWindowEvents = false,
  });

  final List<LingEvent> windowEvents;
  final bool hasLoadedWindowEvents;
  final bool isLoadingWindowEvents;

  ScheduleSurfaceState copyWith({
    List<LingEvent>? windowEvents,
    bool? hasLoadedWindowEvents,
    bool? isLoadingWindowEvents,
  }) {
    return ScheduleSurfaceState(
      windowEvents: windowEvents ?? this.windowEvents,
      hasLoadedWindowEvents:
          hasLoadedWindowEvents ?? this.hasLoadedWindowEvents,
      isLoadingWindowEvents:
          isLoadingWindowEvents ?? this.isLoadingWindowEvents,
    );
  }
}

class ScheduleSurfaceEventMutation {
  const ScheduleSurfaceEventMutation({
    required this.scopeApiValue,
    required this.appleSpan,
    required this.includeRecurrence,
    this.occurrenceStartTime,
  });

  final String scopeApiValue;
  final AppleCalendarMutationSpan appleSpan;
  final bool includeRecurrence;
  final String? occurrenceStartTime;
}

class ScheduleSurfaceController extends Notifier<ScheduleSurfaceState> {
  CalendarController get _calendarController =>
      ref.read(calendarControllerProvider.notifier);
  AppleCalendarBridge get _appleCalendarBridge =>
      ref.read(appleCalendarBridgeProvider);
  AppleCalendarSyncRepository get _appleCalendarSyncRepository =>
      ref.read(appleCalendarSyncRepositoryProvider);
  PushDeviceIdStore get _pushDeviceIdStore =>
      ref.read(pushDeviceIdStoreProvider);

  int _windowRequestId = 0;
  @override
  ScheduleSurfaceState build() => const ScheduleSurfaceState();

  void clear() {
    state = const ScheduleSurfaceState();
    _windowRequestId = 0;
  }

  Future<void> ensureLoaded({
    required String timezone,
    bool forceRefresh = false,
  }) async {
    await refreshWindowEvents(timezone: timezone, forceRefresh: forceRefresh);
  }

  Future<void> refreshWindowEvents({
    required String timezone,
    bool forceRefresh = false,
  }) async {
    final now = currentLingDateTime(timezone);
    final startAt = DateTime(now.year, now.month, now.day);
    final endAt = startAt.add(const Duration(days: 7));
    final requestId = ++_windowRequestId;
    state = state.copyWith(isLoadingWindowEvents: true);
    try {
      final events = await _calendarController.getEventsInWindow(
        startAt: formatLingDateTimeWithTimezone(startAt, timezone),
        endAt: formatLingDateTimeWithTimezone(endAt, timezone),
        timezone: timezone,
        forceRefresh: forceRefresh,
      );
      if (requestId != _windowRequestId) {
        return;
      }
      state = state.copyWith(
        windowEvents: events,
        hasLoadedWindowEvents: true,
        isLoadingWindowEvents: false,
      );
    } catch (_) {
      if (requestId != _windowRequestId) {
        return;
      }
      state = state.copyWith(isLoadingWindowEvents: false);
      rethrow;
    }
  }

  Future<LingEvent> updateEvent({
    required LingEvent event,
    required LingCalendarEventDraft draft,
    required String timezone,
    required LingStrings strings,
    required CalendarNotificationSettings calendarNotificationSettings,
    required ScheduleSurfaceEventMutation mutation,
  }) async {
    final updatedEvent = await _calendarController.updateEvent(
      event.eventId.trim(),
      buildLingEventPayloadFromDraft(
        draft: draft,
        timezone: timezone,
        existingEvent: event,
        scope: mutation.scopeApiValue,
        occurrenceStartTime: mutation.occurrenceStartTime,
        includeRecurrence: mutation.includeRecurrence,
      ),
      nextFocusedDate: draft.startAt,
    );
    await _syncUpdatedLingEventToAppleCalendar(
      previousEvent: event,
      updatedEvent: updatedEvent,
      mutation: mutation,
      calendarNotificationSettings: calendarNotificationSettings,
      strings: strings,
    );
    await _syncAfterLingEventMutation(
      timezone: timezone,
      forceRefreshWindow: true,
    );
    return updatedEvent;
  }

  Future<void> deleteEvent({
    required LingEvent event,
    required String timezone,
    required String scopeApiValue,
    required AppleCalendarMutationSpan appleSpan,
    String? occurrenceStartTime,
  }) async {
    await _deleteLinkedAppleCalendarEvent(event, appleSpan: appleSpan);
    await _calendarController.deleteEvent(
      event.eventId.trim(),
      scope: scopeApiValue,
      occurrenceStartTime: occurrenceStartTime,
    );
    await _syncAfterLingEventMutation(
      timezone: timezone,
      forceRefreshWindow: true,
    );
  }

  Future<void> _syncAfterLingEventMutation({
    required String timezone,
    bool forceRefreshWindow = false,
  }) async {
    await refreshWindowEvents(
      timezone: timezone,
      forceRefresh: forceRefreshWindow,
    );
  }

  Future<void> _syncUpdatedLingEventToAppleCalendar({
    required LingEvent previousEvent,
    required LingEvent updatedEvent,
    required ScheduleSurfaceEventMutation mutation,
    required CalendarNotificationSettings calendarNotificationSettings,
    required LingStrings strings,
  }) async {
    if (updatedEvent.isPoint) {
      return;
    }
    final appleLink = previousEvent.appleLink ?? updatedEvent.appleLink;
    final eventIdentifier = appleLink?.eventIdentifier?.trim() ?? '';
    if (eventIdentifier.isEmpty) {
      return;
    }
    final options = AppleCalendarMutationOptions(
      eventIdentifier: eventIdentifier,
      calendarItemIdentifier: appleLink?.calendarItemIdentifier,
      occurrenceDate: previousEvent.isRecurring
          ? (previousEvent.occurrenceStartAt ?? previousEvent.startAt)
          : null,
      span: mutation.appleSpan,
    );
    final draft = buildAppleCalendarDraftFromLingEvent(
      event: updatedEvent,
      alarms: buildAppleCalendarAlarmPayload(
        calendarNotificationSettings,
        event: updatedEvent,
      ),
      fallbackTitle: strings.untitled,
      calendarIdentifier: appleLink?.calendarIdentifier,
      includeRecurrence: mutation.includeRecurrence,
    );
    Map<String, dynamic> response;
    try {
      response = await _appleCalendarBridge.updateEvent(options, draft);
    } on PlatformException catch (error) {
      if (error.code != 'not_found') {
        rethrow;
      }
      if (mutation.appleSpan == AppleCalendarMutationSpan.thisEvent) {
        return;
      }
      response = await _appleCalendarBridge.createEvent(draft);
    }
    if (mutation.appleSpan == AppleCalendarMutationSpan.thisEvent) {
      return;
    }
    final nextEventIdentifier =
        '${response['eventIdentifier'] ?? eventIdentifier}'.trim();
    final nextCalendarIdentifier =
        '${response['calendarIdentifier'] ?? appleLink?.calendarIdentifier ?? ''}'
            .trim();
    final nextCalendarItemIdentifier =
        '${response['calendarItemIdentifier'] ?? appleLink?.calendarItemIdentifier ?? ''}'
            .trim();
    if (nextEventIdentifier.isEmpty || nextCalendarIdentifier.isEmpty) {
      return;
    }
    final linkedDeviceId = appleLink?.deviceId?.trim() ?? '';
    final deviceId = linkedDeviceId.isNotEmpty
        ? linkedDeviceId
        : await _pushDeviceIdStore.getOrCreate();
    await _appleCalendarSyncRepository.linkAppleEvent(
      AppleEventLinkRequest(
        lingEventId: updatedEvent.eventId,
        deviceId: deviceId,
        calendarIdentifier: nextCalendarIdentifier,
        eventIdentifier: nextEventIdentifier,
        syncState: 'linked',
        metadata: <String, dynamic>{
          if (nextCalendarItemIdentifier.isNotEmpty)
            'calendar_item_identifier': nextCalendarItemIdentifier,
        },
      ),
    );
  }

  Future<void> _deleteLinkedAppleCalendarEvent(
    LingEvent lingEvent, {
    required AppleCalendarMutationSpan appleSpan,
  }) async {
    if (lingEvent.isPoint) {
      return;
    }
    final eventIdentifier = lingEvent.appleLink?.eventIdentifier?.trim() ?? '';
    if (eventIdentifier.isEmpty) {
      return;
    }
    await _appleCalendarBridge.deleteEvent(
      AppleCalendarMutationOptions(
        eventIdentifier: eventIdentifier,
        calendarItemIdentifier: lingEvent.appleLink?.calendarItemIdentifier,
        occurrenceDate: lingEvent.isRecurring
            ? (lingEvent.occurrenceStartAt ?? lingEvent.startAt)
            : null,
        span: appleSpan,
      ),
    );
  }
}

final scheduleSurfaceControllerProvider =
    NotifierProvider<ScheduleSurfaceController, ScheduleSurfaceState>(
      ScheduleSurfaceController.new,
    );
