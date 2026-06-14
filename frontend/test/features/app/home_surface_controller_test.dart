import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ling/src/app/application/app_shell_controller.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/config/constants.dart';
import 'package:ling/src/core/cache/json_cache_store.dart';
import 'package:ling/src/core/database/app_database.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/storage/preferences_store.dart';
import 'package:ling/src/core/storage/push_device_id_store.dart';
import 'package:ling/src/features/calendar/application/calendar_controller.dart';
import 'package:ling/src/features/calendar/data/bridges/apple_calendar_bridge.dart';
import 'package:ling/src/features/calendar/data/repositories/apple_calendar_sync_repository.dart';
import 'package:ling/src/features/calendar/data/repositories/calendar_integration_repository.dart';
import 'package:ling/src/features/calendar/data/repositories/calendar_repository.dart';
import 'package:ling/src/features/calendar/models/calendar_integration_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';

void main() {
  test(
    'ensureSchedulePageDataLoaded reloads Ling calendar after Apple sync mutated Ling events',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final repository = _SequencedCalendarRepository(database: database);
      final container = ProviderContainer(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repository),
          appleCalendarSyncRepositoryProvider.overrideWithValue(
            _FakeAppleCalendarSyncRepository(didMutateEvents: true),
          ),
          appleCalendarBridgeProvider.overrideWithValue(
            _GrantedAppleCalendarBridge(),
          ),
          pushDeviceIdStoreProvider.overrideWithValue(_FakePushDeviceIdStore()),
        ],
      );
      addTearDown(container.dispose);

      final calendarController = container.read(
        calendarControllerProvider.notifier,
      );
      calendarController.updateTimezone(AppConstants.defaultTimezone);

      await container
          .read(homeSurfaceControllerProvider.notifier)
          .ensureSchedulePageDataLoaded(
            isAuthenticated: true,
            timezone: AppConstants.defaultTimezone,
            calendarNotificationSettings: const CalendarNotificationSettings(
              enabled: false,
            ),
            forceRefresh: true,
          );

      final state = container.read(calendarControllerProvider);
      expect(repository.getEventsForDateCalls, 2);
      expect(repository.getMonthCalls, 2);
      expect(state.events.map((event) => event.eventId), ['evt_ling']);
      expect(
        state.monthSnapshot?.selectedDayEvents.map((event) => event.eventId),
        ['evt_ling'],
      );
    },
  );

  test(
    'ensureSchedulePageDataLoaded skips Ling reload when Apple sync did not mutate Ling events',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final repository = _StableCalendarRepository(database: database);
      final container = ProviderContainer(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repository),
          appleCalendarSyncRepositoryProvider.overrideWithValue(
            _FakeAppleCalendarSyncRepository(didMutateEvents: false),
          ),
          appleCalendarBridgeProvider.overrideWithValue(
            _GrantedAppleCalendarBridge(),
          ),
          pushDeviceIdStoreProvider.overrideWithValue(_FakePushDeviceIdStore()),
        ],
      );
      addTearDown(container.dispose);

      final calendarController = container.read(
        calendarControllerProvider.notifier,
      );
      calendarController.updateTimezone(AppConstants.defaultTimezone);

      final homeSurfaceController = container.read(
        homeSurfaceControllerProvider.notifier,
      );
      await homeSurfaceController.ensureSchedulePageDataLoaded(
        isAuthenticated: true,
        timezone: AppConstants.defaultTimezone,
        calendarNotificationSettings: const CalendarNotificationSettings(
          enabled: false,
        ),
        forceRefresh: true,
      );
      await homeSurfaceController.ensureSchedulePageDataLoaded(
        isAuthenticated: true,
        timezone: AppConstants.defaultTimezone,
        calendarNotificationSettings: const CalendarNotificationSettings(
          enabled: false,
        ),
        forceRefresh: true,
      );

      expect(repository.getEventsForDateCalls, 2);
      expect(repository.getMonthCalls, 2);
    },
  );

  test(
    'concurrent schedule and settings loads share one Apple context upload',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final syncRepository = _FakeAppleCalendarSyncRepository(
        didMutateEvents: false,
        uploadGate: Completer<void>(),
      );
      final container = ProviderContainer(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(
            _StableCalendarRepository(database: database),
          ),
          calendarIntegrationRepositoryProvider.overrideWithValue(
            _FakeCalendarIntegrationRepository(),
          ),
          appleCalendarSyncRepositoryProvider.overrideWithValue(syncRepository),
          appleCalendarBridgeProvider.overrideWithValue(
            _GrantedAppleCalendarBridge(),
          ),
          pushDeviceIdStoreProvider.overrideWithValue(_FakePushDeviceIdStore()),
        ],
      );
      addTearDown(container.dispose);

      final calendarController = container.read(
        calendarControllerProvider.notifier,
      );
      calendarController.updateTimezone(AppConstants.defaultTimezone);
      final homeSurfaceController = container.read(
        homeSurfaceControllerProvider.notifier,
      );

      final scheduleLoad = homeSurfaceController.ensureSchedulePageDataLoaded(
        isAuthenticated: true,
        timezone: AppConstants.defaultTimezone,
        calendarNotificationSettings: const CalendarNotificationSettings(
          enabled: false,
        ),
        forceRefresh: true,
      );
      final settingsLoad = homeSurfaceController.ensureSettingsPageDataLoaded(
        isAuthenticated: true,
        timezone: AppConstants.defaultTimezone,
        forceRefresh: true,
      );

      await pumpEventQueue(times: 5);
      expect(syncRepository.uploadCalls, 1);

      syncRepository.uploadGate!.complete();
      await Future.wait([scheduleLoad, settingsLoad]);

      expect(syncRepository.uploadCalls, 1);
    },
  );
}

class _SequencedCalendarRepository extends CalendarRepository {
  _SequencedCalendarRepository({required super.database})
    : super(
        apiClient: ApiClient(httpClient: _NeverHttpClient()),
        cacheStore: JsonCacheStore(),
      );

  int getEventsForDateCalls = 0;
  int getMonthCalls = 0;

  @override
  Future<List<LingEvent>> getEventsForDate({
    required String date,
    required String timezone,
    bool forceRefresh = false,
  }) async {
    getEventsForDateCalls += 1;
    if (getEventsForDateCalls == 1) {
      return const <LingEvent>[];
    }
    return <LingEvent>[_event('evt_ling', DateTime(2026, 4, 5, 9))];
  }

  @override
  Future<CalendarMonthSnapshot> getMonth({
    required String month,
    required String timezone,
    required String selectedDate,
    bool forceRefresh = false,
  }) async {
    getMonthCalls += 1;
    if (getMonthCalls == 1) {
      return _monthSnapshot(
        month: month,
        selectedDate: selectedDate,
        events: const <LingEvent>[],
      );
    }
    return _monthSnapshot(
      month: month,
      selectedDate: selectedDate,
      events: <LingEvent>[_event('evt_ling', DateTime(2026, 4, 5, 9))],
    );
  }

  @override
  Future<List<LingEvent>> getEventsInWindow({
    required String startAt,
    required String endAt,
    required String timezone,
    bool forceRefresh = false,
  }) async {
    return const <LingEvent>[];
  }
}

class _StableCalendarRepository extends CalendarRepository {
  _StableCalendarRepository({required super.database})
    : super(
        apiClient: ApiClient(httpClient: _NeverHttpClient()),
        cacheStore: JsonCacheStore(),
      );

  int getEventsForDateCalls = 0;
  int getMonthCalls = 0;

  @override
  Future<List<LingEvent>> getEventsForDate({
    required String date,
    required String timezone,
    bool forceRefresh = false,
  }) async {
    getEventsForDateCalls += 1;
    return <LingEvent>[_event('evt_ling', DateTime(2026, 4, 5, 9))];
  }

  @override
  Future<CalendarMonthSnapshot> getMonth({
    required String month,
    required String timezone,
    required String selectedDate,
    bool forceRefresh = false,
  }) async {
    getMonthCalls += 1;
    return _monthSnapshot(
      month: month,
      selectedDate: selectedDate,
      events: <LingEvent>[_event('evt_ling', DateTime(2026, 4, 5, 9))],
    );
  }

  @override
  Future<List<LingEvent>> getEventsInWindow({
    required String startAt,
    required String endAt,
    required String timezone,
    bool forceRefresh = false,
  }) async {
    return const <LingEvent>[];
  }
}

class _FakeAppleCalendarSyncRepository extends AppleCalendarSyncRepository {
  _FakeAppleCalendarSyncRepository({
    required this.didMutateEvents,
    this.uploadGate,
  }) : super(apiClient: ApiClient(httpClient: _NeverHttpClient()));

  final bool didMutateEvents;
  final Completer<void>? uploadGate;
  int uploadCalls = 0;

  @override
  Future<AppleCalendarContextUploadResult> uploadAppleCalendarContext(
    AppleCalendarContextUploadRequest payload,
  ) async {
    uploadCalls += 1;
    await uploadGate?.future;
    return AppleCalendarContextUploadResult(
      didMutateEvents: didMutateEvents,
      insertedCount: didMutateEvents ? 1 : 0,
      updatedCount: 0,
      deactivatedCount: 0,
    );
  }
}

class _FakeCalendarIntegrationRepository extends CalendarIntegrationRepository {
  _FakeCalendarIntegrationRepository()
    : super(apiClient: ApiClient(httpClient: _NeverHttpClient()));

  @override
  Future<List<CalendarConnectionSummary>> listConnections() async =>
      const <CalendarConnectionSummary>[];
}

class _GrantedAppleCalendarBridge implements AppleCalendarBridge {
  @override
  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> draft) async =>
      const <String, dynamic>{};

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

  @override
  Future<Map<String, dynamic>> updateEvent(
    AppleCalendarMutationOptions options,
    Map<String, dynamic> draft,
  ) async => const <String, dynamic>{};
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

LingEvent _event(String id, DateTime startAt) {
  return LingEvent(
    eventId: id,
    userId: 'user-1',
    title: id,
    startAt: startAt,
    endAt: startAt.add(const Duration(hours: 1)),
    timezone: AppConstants.defaultTimezone,
  );
}

CalendarMonthSnapshot _monthSnapshot({
  required String month,
  required String selectedDate,
  required List<LingEvent> events,
}) {
  return CalendarMonthSnapshot(
    month: month,
    timezone: AppConstants.defaultTimezone,
    days: [
      CalendarMonthDay(
        date: selectedDate,
        inCurrentMonth: true,
        isToday: false,
        isSelected: true,
        eventCount: events.length,
        hasFocusEvent: false,
      ),
    ],
    selectedDayEvents: events,
  );
}

class _NeverHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }
}
