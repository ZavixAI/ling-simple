import 'dart:convert';

import 'package:ling/src/core/cache/json_cache_store.dart';
import 'package:ling/src/core/database/app_database.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/network/json_payload_codec.dart';
import 'package:ling/src/core/storage/local_persistence_policy.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_time.dart';

class CalendarRepository {
  CalendarRepository({
    required ApiClient apiClient,
    required JsonCacheStore cacheStore,
    required AppDatabase database,
    LocalPersistencePolicy? localPersistencePolicy,
  }) : _apiClient = apiClient,
       _cacheStore = cacheStore,
       _database = database,
       _localPersistencePolicy =
           localPersistencePolicy ?? const LocalPersistencePolicy();

  static const String calendarDayPrefix = 'ling.cache.v2.calendar.day.';
  static const String calendarWindowPrefix = 'ling.cache.v2.calendar.window.';
  static const String calendarMonthPrefix = 'ling.cache.v2.calendar.month.';
  static const Duration calendarDayCacheTtl = Duration(minutes: 2);
  static const Duration calendarWindowCacheTtl = Duration(minutes: 1);
  static const Duration calendarMonthCacheTtl = Duration(minutes: 3);

  final ApiClient _apiClient;
  final JsonCacheStore _cacheStore;
  final AppDatabase _database;
  final LocalPersistencePolicy _localPersistencePolicy;

  Future<List<LingEvent>> getEventsForDate({
    required String date,
    required String timezone,
    bool forceRefresh = false,
  }) {
    final cacheKey = '$calendarDayPrefix$date.$timezone';
    return _cacheStore.getOrLoad<List<LingEvent>>(
      cacheKey,
      ttl: calendarDayCacheTtl,
      forceRefresh: forceRefresh,
      loader: () async {
        if (!forceRefresh &&
            _localPersistencePolicy.canPersistToProtectedDatabase(
              LocalDataSensitivity.privateEphemeral,
            )) {
          final stored = await _database.readCalendarDayPayload(
            date: date,
            timezone: timezone,
            maxAge: calendarDayCacheTtl,
          );
          if (stored != null) {
            return _decodeLingEventList(decodeStoredJson(stored.payload));
          }
        }
        final response = await _apiClient.get(
          '/calendar/events',
          queryParameters: <String, Object?>{
            'date': date,
            'timezone': timezone,
          },
        );
        final data = asJsonMap(response.data);
        final events = _decodeLingEventList(data['events']);
        if (_localPersistencePolicy.canPersistToProtectedDatabase(
          LocalDataSensitivity.privateEphemeral,
        )) {
          await _database.saveCalendarDayPayload(
            date: date,
            timezone: timezone,
            payload: jsonEncode(
              events.map((event) => event.toJson()).toList(growable: false),
            ),
          );
        }
        return events;
      },
      encoder: (events) => events.map((event) => event.toJson()).toList(),
      decoder: _decodeLingEventList,
    );
  }

  Future<List<LingEvent>> getEventsInWindow({
    required String startAt,
    required String endAt,
    required String timezone,
    bool forceRefresh = false,
  }) {
    final normalizedStartAt = normalizeCalendarWindowBoundaryToMinute(startAt);
    final normalizedEndAt = normalizeCalendarWindowBoundaryToMinute(endAt);
    final cacheKey =
        '$calendarWindowPrefix$normalizedStartAt.$normalizedEndAt.$timezone';
    return _cacheStore.getOrLoad<List<LingEvent>>(
      cacheKey,
      ttl: calendarWindowCacheTtl,
      forceRefresh: forceRefresh,
      loader: () async {
        final response = await _apiClient.get(
          '/calendar/events/window',
          queryParameters: <String, Object?>{
            'start_at': normalizedStartAt,
            'end_at': normalizedEndAt,
            'timezone': timezone,
          },
        );
        final data = asJsonMap(response.data);
        return _decodeLingEventList(data['events']);
      },
      encoder: (events) => events.map((event) => event.toJson()).toList(),
      decoder: _decodeLingEventList,
    );
  }

  Future<LingEvent> getEventById(String eventId) async {
    final response = await _apiClient.get('/calendar/events/$eventId');
    return LingEvent.fromJson(asJsonMap(response.data));
  }

  Future<CalendarMonthSnapshot> getMonth({
    required String month,
    required String timezone,
    required String selectedDate,
    bool forceRefresh = false,
  }) {
    final cacheKey = '$calendarMonthPrefix$month.$timezone.$selectedDate';
    return _cacheStore.getOrLoad<CalendarMonthSnapshot>(
      cacheKey,
      ttl: calendarMonthCacheTtl,
      forceRefresh: forceRefresh,
      loader: () async {
        if (!forceRefresh &&
            _localPersistencePolicy.canPersistToProtectedDatabase(
              LocalDataSensitivity.privateEphemeral,
            )) {
          final stored = await _database.readCalendarMonthPayload(
            month: month,
            timezone: timezone,
            selectedDate: selectedDate,
            maxAge: calendarMonthCacheTtl,
          );
          if (stored != null) {
            return CalendarMonthSnapshot.fromJson(
              decodeStoredMap(stored.payload),
            );
          }
        }
        final response = await _apiClient.get(
          '/calendar/month',
          queryParameters: <String, Object?>{
            'month': month,
            'timezone': timezone,
            'selected_date': selectedDate,
          },
        );
        final snapshot = CalendarMonthSnapshot.fromJson(
          asJsonMap(response.data),
        );
        if (_localPersistencePolicy.canPersistToProtectedDatabase(
          LocalDataSensitivity.privateEphemeral,
        )) {
          await _database.saveCalendarMonthPayload(
            month: month,
            timezone: timezone,
            selectedDate: selectedDate,
            payload: jsonEncode(snapshot.toJson()),
          );
        }
        return snapshot;
      },
      encoder: (value) => value.toJson(),
      decoder: (value) => CalendarMonthSnapshot.fromJson(asJsonMap(value)),
    );
  }

  Future<LingEvent> updateEvent(
    String eventId,
    LingEventUpsertRequest payload,
  ) async {
    final response = await _apiClient.patch(
      '/calendar/events/$eventId',
      body: payload.toJson(),
    );
    await clearCalendarCache();
    return LingEvent.fromJson(asJsonMap(response.data));
  }

  Future<void> deleteEvent(
    String eventId, {
    String scope = 'series',
    String? occurrenceStartTime,
  }) async {
    await _apiClient.delete(
      '/calendar/events/$eventId',
      queryParameters: <String, Object?>{
        'scope': scope,
        ...?occurrenceStartTime == null
            ? null
            : <String, Object?>{'occurrence_start_time': occurrenceStartTime},
      },
    );
    await clearCalendarCache();
  }

  Future<void> clearCalendarCache() async {
    await _cacheStore.invalidatePrefix(calendarDayPrefix);
    await _cacheStore.invalidatePrefix(calendarWindowPrefix);
    await _cacheStore.invalidatePrefix(calendarMonthPrefix);
    await _database.clearCalendarDayCaches();
    await _database.clearCalendarMonthCaches();
  }
}

List<LingEvent> _decodeLingEventList(Object? value) {
  if (value is! List) {
    return const <LingEvent>[];
  }
  return value
      .whereType<Map<Object?, Object?>>()
      .map((item) => LingEvent.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}
