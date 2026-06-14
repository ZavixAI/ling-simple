import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/config/constants.dart';
import 'package:ling/src/core/cache/json_cache_store.dart';
import 'package:ling/src/core/database/app_database.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/storage/preferences_store.dart';
import 'package:ling/src/core/storage/push_device_id_store.dart';
import 'package:ling/src/features/calendar/application/schedule_surface_controller.dart';
import 'package:ling/src/features/calendar/data/bridges/apple_calendar_bridge.dart';
import 'package:ling/src/features/calendar/data/repositories/apple_calendar_sync_repository.dart';
import 'package:ling/src/features/calendar/data/repositories/calendar_repository.dart';
import 'package:ling/src/features/calendar/models/calendar_event_editor_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';

void main() {
  test('updateEvent recreates stale linked Apple calendar event', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final previousEvent = _event(
      title: '不吃早餐提醒',
      appleLink: const AppleEventLink(
        deviceId: 'device-1',
        calendarIdentifier: 'calendar-old',
        eventIdentifier: 'event-old',
        calendarItemIdentifier: 'item-old',
      ),
      recurrence: const LingEventRecurrence(
        frequency: 'weekly',
        byWeekday: <String>['MO', 'WE', 'FR'],
        rawRrule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
      ),
    );
    final updatedEvent = previousEvent.copyWith(title: '不吃早餐提醒更新');
    final repository = _FakeCalendarRepository(
      database: database,
      updatedEvent: updatedEvent,
    );
    final appleBridge = _StaleLinkedAppleCalendarBridge();
    final syncRepository = _FakeAppleCalendarSyncRepository();
    final container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repository),
        appleCalendarBridgeProvider.overrideWithValue(appleBridge),
        appleCalendarSyncRepositoryProvider.overrideWithValue(syncRepository),
        pushDeviceIdStoreProvider.overrideWithValue(_FakePushDeviceIdStore()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(scheduleSurfaceControllerProvider.notifier)
        .updateEvent(
          event: previousEvent,
          draft: LingCalendarEventDraft(
            title: '不吃早餐提醒更新',
            startAt: DateTime(2026, 5, 11, 8),
            durationMinutes: 15,
            recurrence: const LingEventRecurrence(
              frequency: 'weekly',
              byWeekday: <String>['MO', 'WE', 'FR'],
              rawRrule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
            ),
          ),
          timezone: AppConstants.defaultTimezone,
          strings: const LingStrings('zh-CN'),
          calendarNotificationSettings: const CalendarNotificationSettings(),
          mutation: const ScheduleSurfaceEventMutation(
            scopeApiValue: 'series',
            appleSpan: AppleCalendarMutationSpan.futureEvents,
            includeRecurrence: true,
          ),
        );

    expect(appleBridge.updateCalls, 1);
    expect(appleBridge.createCalls, 1);
    expect(syncRepository.links, hasLength(1));
    expect(syncRepository.links.single.lingEventId, 'evt_1');
    expect(syncRepository.links.single.deviceId, 'device-1');
    expect(syncRepository.links.single.calendarIdentifier, 'calendar-new');
    expect(syncRepository.links.single.eventIdentifier, 'event-new');
    expect(
      syncRepository.links.single.metadata['calendar_item_identifier'],
      'item-new',
    );
  });
}

LingEvent _event({
  required String title,
  AppleEventLink? appleLink,
  LingEventRecurrence? recurrence,
}) {
  return LingEvent(
    eventId: 'evt_1',
    userId: 'user-1',
    title: title,
    category: 'personal',
    startAt: DateTime(2026, 5, 11, 8),
    endAt: DateTime(2026, 5, 11, 8, 15),
    timezone: AppConstants.defaultTimezone,
    appleLink: appleLink,
    isRecurring: recurrence != null,
    seriesId: 'evt_1',
    recurrence: recurrence,
  );
}

class _FakeCalendarRepository extends CalendarRepository {
  _FakeCalendarRepository({required super.database, required this.updatedEvent})
    : super(
        apiClient: ApiClient(httpClient: _NeverHttpClient()),
        cacheStore: JsonCacheStore(),
      );

  final LingEvent updatedEvent;

  @override
  Future<LingEvent> updateEvent(
    String eventId,
    LingEventUpsertRequest payload,
  ) async {
    return updatedEvent;
  }

  @override
  Future<List<LingEvent>> getEventsInWindow({
    required String startAt,
    required String endAt,
    required String timezone,
    bool forceRefresh = false,
  }) async {
    return <LingEvent>[updatedEvent];
  }

  @override
  Future<List<LingEvent>> getEventsForDate({
    required String date,
    required String timezone,
    bool forceRefresh = false,
  }) async {
    return <LingEvent>[updatedEvent];
  }

  @override
  Future<CalendarMonthSnapshot> getMonth({
    required String month,
    required String timezone,
    required String selectedDate,
    bool forceRefresh = false,
  }) async {
    return CalendarMonthSnapshot(
      month: month,
      timezone: timezone,
      days: <CalendarMonthDay>[
        CalendarMonthDay(
          date: selectedDate,
          inCurrentMonth: true,
          isToday: false,
          isSelected: true,
          eventCount: 1,
          hasFocusEvent: false,
        ),
      ],
      selectedDayEvents: <LingEvent>[updatedEvent],
    );
  }
}

class _FakeAppleCalendarSyncRepository extends AppleCalendarSyncRepository {
  _FakeAppleCalendarSyncRepository()
    : super(apiClient: ApiClient(httpClient: _NeverHttpClient()));

  final List<AppleEventLinkRequest> links = <AppleEventLinkRequest>[];

  @override
  Future<void> linkAppleEvent(AppleEventLinkRequest payload) async {
    links.add(payload);
  }
}

class _StaleLinkedAppleCalendarBridge implements AppleCalendarBridge {
  int updateCalls = 0;
  int createCalls = 0;

  @override
  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> draft) async {
    createCalls += 1;
    return <String, dynamic>{
      'eventIdentifier': 'event-new',
      'calendarIdentifier': 'calendar-new',
      'calendarItemIdentifier': 'item-new',
    };
  }

  @override
  Future<Map<String, dynamic>> updateEvent(
    AppleCalendarMutationOptions options,
    Map<String, dynamic> draft,
  ) async {
    updateCalls += 1;
    throw PlatformException(
      code: 'not_found',
      message: 'eventIdentifier is invalid',
    );
  }

  @override
  Future<void> deleteEvent(AppleCalendarMutationOptions options) async {}

  @override
  Future<void> deleteManagedEvents(List<AppleManagedEventLink> links) async {}

  @override
  Future<AppleCalendarPermissionState> getPermissionState() async =>
      AppleCalendarPermissionState.granted;

  @override
  Future<List<AppleCalendarItem>> listCalendars() async =>
      const <AppleCalendarItem>[];

  @override
  Future<List<AppleCalendarEvent>> listEvents({
    required DateTime startAt,
    required DateTime endAt,
  }) async => const <AppleCalendarEvent>[];

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<AppleCalendarPermissionState> requestPermission() async =>
      AppleCalendarPermissionState.granted;
}

class _FakePushDeviceIdStore extends PushDeviceIdStore {
  _FakePushDeviceIdStore() : super(preferencesStore: const PreferencesStore());

  @override
  Future<String> getOrCreate() async => 'device-1';

  @override
  Future<String?> read() async => 'device-1';

  @override
  Future<void> clear() async {}
}

class _NeverHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }
}
