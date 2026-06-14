import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/config/constants.dart';
import 'package:ling/src/features/calendar/data/bridges/apple_calendar_bridge.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';

void main() {
  test(
    'buildAppleCalendarDraftFromLingEvent clears stale recurrence for non-recurring events',
    () {
      final event = LingEvent(
        eventId: 'evt_1',
        userId: 'user-1',
        title: 'Lunch',
        startAt: DateTime(2026, 4, 20, 11, 0),
        endAt: DateTime(2026, 4, 20, 14, 0),
        timezone: AppConstants.defaultTimezone,
        isRecurring: false,
      );

      final draft = buildAppleCalendarDraftFromLingEvent(
        event: event,
        alarms: const <Map<String, dynamic>>[],
      );

      expect(draft.containsKey('recurrence'), isTrue);
      expect(draft['recurrence'], isNull);
      expect(draft['url'], '');
    },
  );

  test(
    'buildAppleCalendarDraftFromLingEvent omits recurrence when updating one occurrence only',
    () {
      final event = LingEvent(
        eventId: 'evt_2',
        userId: 'user-1',
        title: 'Weekly sync',
        startAt: DateTime(2026, 4, 20, 11, 0),
        endAt: DateTime(2026, 4, 20, 12, 0),
        timezone: AppConstants.defaultTimezone,
        isRecurring: true,
        recurrence: const LingEventRecurrence(frequency: 'weekly'),
      );

      final draft = buildAppleCalendarDraftFromLingEvent(
        event: event,
        alarms: const <Map<String, dynamic>>[],
        includeRecurrence: false,
      );

      expect(draft.containsKey('recurrence'), isFalse);
    },
  );

  test(
    'createEvent preserves offset-aware timestamps when bridging to iOS',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final channel = const MethodChannel('ling/apple_calendar');
      final previousPlatform = debugDefaultTargetPlatformOverride;
      final calls = <MethodCall>[];
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return <String, dynamic>{};
          });

      try {
        final bridge = MethodChannelAppleCalendarBridge();
        await bridge.createEvent({
          'title': 'Trip',
          'startAt': '2026-04-17T08:00:00+08:00',
          'endAt': '2026-04-17T09:00:00+08:00',
          'timezone': AppConstants.defaultTimezone,
        });

        expect(calls, hasLength(1));
        expect(calls.single.method, 'createEvent');
        final arguments = Map<Object?, Object?>.from(
          calls.single.arguments as Map,
        );
        expect(arguments['startAt'], '2026-04-17T08:00:00+08:00');
        expect(arguments['endAt'], '2026-04-17T09:00:00+08:00');
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    },
  );

  test('toSummaryJson encodes Apple events using the requested timezone', () {
    final event = AppleCalendarEvent(
      identifier: 'apple-1',
      calendarIdentifier: 'cal-1',
      title: 'Morning Run',
      startAt: DateTime(2026, 4, 5, 0, 30),
      endAt: DateTime(2026, 4, 5, 1, 30),
      timezone: AppConstants.defaultTimezone,
    );

    final summary = event.toSummaryJson(timezone: AppConstants.defaultTimezone);

    expect(summary['start_at'], '2026-04-05T00:30:00+08:00');
    expect(summary['end_at'], '2026-04-05T01:30:00+08:00');
  });

  test('normalizedToTimezone keeps Apple events on the correct local day', () {
    final event = AppleCalendarEvent.fromJson({
      'identifier': 'apple-1',
      'calendarIdentifier': 'cal-1',
      'title': 'Morning Run',
      'startAt': '2026-04-04T16:30:00Z',
      'endAt': '2026-04-04T17:30:00Z',
    });

    final normalized = event.normalizedToTimezone(AppConstants.defaultTimezone);

    expect(normalized.startAt, DateTime(2026, 4, 5, 0, 30));
    expect(normalized.endAt, DateTime(2026, 4, 5, 1, 30));
  });

  test('fromJson parses recurrence metadata from Apple payloads', () {
    final event = AppleCalendarEvent.fromJson({
      'identifier': 'apple-2',
      'calendarIdentifier': 'cal-1',
      'calendarItemIdentifier': 'item-1',
      'title': 'Yoga',
      'startAt': '2026-04-05T01:00:00Z',
      'endAt': '2026-04-05T02:00:00Z',
      'occurrenceDate': '2026-04-05T01:00:00Z',
      'isDetached': true,
      'isRecurring': true,
      'recurrence': {
        'frequency': 'weekly',
        'interval': 2,
        'by_weekday': ['MO', 'FR'],
      },
      'rawRRules': ['FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR'],
    });

    expect(event.calendarItemIdentifier, 'item-1');
    expect(event.occurrenceDate, DateTime(2026, 4, 5, 1));
    expect(event.isDetached, isTrue);
    expect(event.isRecurring, isTrue);
    expect(event.recurrence?.frequency, 'weekly');
    expect(event.recurrence?.interval, 2);
    expect(event.recurrence?.byWeekday, ['MO', 'FR']);
    expect(event.rawRRules, ['FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR']);
  });

  test(
    'fromJson does not mark occurrence-only Apple payloads as recurring',
    () {
      final event = AppleCalendarEvent.fromJson({
        'identifier': 'apple-occurrence-only',
        'calendarIdentifier': 'cal-1',
        'title': 'One-off Apple Event',
        'startAt': '2026-04-05T01:00:00Z',
        'endAt': '2026-04-05T02:00:00Z',
        'occurrenceDate': '2026-04-05T01:00:00Z',
        'isRecurring': true,
      });

      expect(event.occurrenceDate, DateTime(2026, 4, 5, 1));
      expect(event.isRecurring, isFalse);
      expect(event.recurrence, isNull);
      expect(event.rawRRules, isEmpty);
    },
  );

  test(
    'toSummaryJson keeps recurrence and occurrence date aligned to timezone',
    () {
      final event = AppleCalendarEvent(
        identifier: 'apple-3',
        calendarIdentifier: 'cal-1',
        calendarItemIdentifier: 'item-3',
        title: 'Standup',
        startAt: DateTime.parse('2026-04-05T01:00:00Z'),
        endAt: DateTime.parse('2026-04-05T01:30:00Z'),
        timezone: 'UTC',
        occurrenceDate: DateTime.parse('2026-04-05T01:00:00Z'),
        isRecurring: true,
        recurrence: const LingEventRecurrence(
          frequency: 'daily',
          interval: 1,
          rawRrules: <String>['FREQ=DAILY'],
        ),
        rawRRules: const <String>['FREQ=DAILY'],
      );

      final summary = event
          .normalizedToTimezone(AppConstants.defaultTimezone)
          .toSummaryJson(timezone: AppConstants.defaultTimezone);

      expect(summary['occurrence_date'], '2026-04-05T09:00:00+08:00');
      expect(summary['recurrence'], isA<Map<String, dynamic>>());
      expect(summary['raw_rrules'], ['FREQ=DAILY']);
    },
  );
}
