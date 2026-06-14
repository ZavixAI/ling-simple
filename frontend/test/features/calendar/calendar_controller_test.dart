import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/config/constants.dart';
import 'package:ling/src/core/cache/json_cache_store.dart';
import 'package:ling/src/core/database/app_database.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/features/calendar/application/calendar_controller.dart';
import 'package:ling/src/features/calendar/data/repositories/calendar_repository.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';

void main() {
  test('load only applies the latest in-flight request result', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = _FakeCalendarRepository(database: database);
    final container = ProviderContainer(
      overrides: [calendarRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final controller = container.read(calendarControllerProvider.notifier);

    final firstLoad = controller.selectDate('2026-04-04');
    final secondLoad = controller.selectDate('2026-04-05');

    repository.completeDay('2026-04-05', [
      _event('event-new', DateTime(2026, 4, 5, 9)),
    ]);
    repository.completeMonth(
      '2026-04',
      '2026-04-05',
      _monthSnapshot(
        month: '2026-04',
        selectedDate: '2026-04-05',
        events: [_event('event-new', DateTime(2026, 4, 5, 9))],
      ),
    );

    await secondLoad;

    var state = container.read(calendarControllerProvider);
    expect(state.selectedDate, '2026-04-05');
    expect(state.events.map((event) => event.eventId), ['event-new']);
    expect(
      state.monthSnapshot?.selectedDayEvents.map((event) => event.eventId),
      ['event-new'],
    );

    repository.completeDay('2026-04-04', [
      _event('event-stale', DateTime(2026, 4, 4, 9)),
    ]);
    repository.completeMonth(
      '2026-04',
      '2026-04-04',
      _monthSnapshot(
        month: '2026-04',
        selectedDate: '2026-04-04',
        events: [_event('event-stale', DateTime(2026, 4, 4, 9))],
      ),
    );

    await firstLoad;

    state = container.read(calendarControllerProvider);
    expect(state.selectedDate, '2026-04-05');
    expect(state.events.map((event) => event.eventId), ['event-new']);
    expect(
      state.monthSnapshot?.selectedDayEvents.map((event) => event.eventId),
      ['event-new'],
    );
  });
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

class _FakeCalendarRepository extends CalendarRepository {
  _FakeCalendarRepository({required super.database})
    : super(
        apiClient: ApiClient(httpClient: _NeverHttpClient()),
        cacheStore: JsonCacheStore(),
      );

  final Map<String, Completer<List<LingEvent>>> _dayRequests = {};
  final Map<String, Completer<CalendarMonthSnapshot>> _monthRequests = {};

  @override
  Future<List<LingEvent>> getEventsForDate({
    required String date,
    required String timezone,
    bool forceRefresh = false,
  }) {
    return (_dayRequests[date] ??= Completer<List<LingEvent>>()).future;
  }

  @override
  Future<CalendarMonthSnapshot> getMonth({
    required String month,
    required String timezone,
    required String selectedDate,
    bool forceRefresh = false,
  }) {
    final key = '$month|$selectedDate';
    return (_monthRequests[key] ??= Completer<CalendarMonthSnapshot>()).future;
  }

  void completeDay(String date, List<LingEvent> events) {
    (_dayRequests[date] ??= Completer<List<LingEvent>>()).complete(events);
  }

  void completeMonth(
    String month,
    String selectedDate,
    CalendarMonthSnapshot snapshot,
  ) {
    final key = '$month|$selectedDate';
    (_monthRequests[key] ??= Completer<CalendarMonthSnapshot>()).complete(
      snapshot,
    );
  }
}

class _NeverHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }
}
