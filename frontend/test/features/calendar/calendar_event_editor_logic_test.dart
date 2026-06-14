import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/config/constants.dart';
import 'package:ling/src/features/calendar/application/event_editor_support.dart';
import 'package:ling/src/features/calendar/models/calendar_event_editor_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';

void main() {
  test(
    'buildLingEventPayloadFromDraft encodes start and end with timezone offsets',
    () {
      final payload = buildLingEventPayloadFromDraft(
        draft: LingCalendarEventDraft(
          title: '晨会',
          startAt: DateTime(2026, 4, 5, 9),
          durationMinutes: 30,
          location: '会议室',
        ),
        timezone: AppConstants.defaultTimezone,
      );

      expect(payload.startAt, '2026-04-05T09:00:00+08:00');
      expect(payload.endAt, '2026-04-05T09:30:00+08:00');
      expect(payload.timezone, AppConstants.defaultTimezone);
    },
  );

  test('buildLingEventPayloadFromDraft encodes point event shape', () {
    final payload = buildLingEventPayloadFromDraft(
      draft: LingCalendarEventDraft(
        title: '提醒给爸妈打电话',
        startAt: DateTime(2026, 4, 5, 20),
        durationMinutes: 0,
        timeShape: 'point',
      ),
      timezone: AppConstants.defaultTimezone,
    );

    expect(payload.timeShape, 'point');
    expect(payload.startAt, '2026-04-05T20:00:00+08:00');
    expect(payload.endAt, payload.startAt);
  });

  test(
    'buildLingEventPayloadFromDraft carries occurrence scope without recurrence',
    () {
      final existingEvent = LingEvent(
        eventId: 'evt-series',
        userId: 'user-1',
        title: '晨会',
        startAt: DateTime(2026, 4, 5, 9),
        endAt: DateTime(2026, 4, 5, 9, 30),
        timezone: AppConstants.defaultTimezone,
        isRecurring: true,
        occurrenceStartAt: DateTime(2026, 4, 5, 9),
        recurrence: const LingEventRecurrence(
          frequency: 'weekly',
          interval: 1,
          byWeekday: <String>['MO'],
        ),
      );
      final payload = buildLingEventPayloadFromDraft(
        draft: LingCalendarEventDraft(
          title: '晨会改期',
          startAt: DateTime(2026, 4, 5, 10),
          durationMinutes: 45,
          location: '会议室 A',
          mutationScope: 'occurrence',
        ),
        timezone: AppConstants.defaultTimezone,
        existingEvent: existingEvent,
        scope: 'occurrence',
        occurrenceStartTime: '2026-04-05T09:00:00+08:00',
        includeRecurrence: false,
      );

      expect(payload.scope, 'occurrence');
      expect(payload.occurrenceStartTime, '2026-04-05T09:00:00+08:00');
      expect(payload.recurrence, isNull);
    },
  );

  test(
    'buildLingEventPayloadFromDraft writes edited recurrence for series updates',
    () {
      final payload = buildLingEventPayloadFromDraft(
        draft: LingCalendarEventDraft(
          title: '晨会',
          startAt: DateTime(2026, 4, 5, 9),
          durationMinutes: 30,
          location: '会议室',
          recurrence: const LingEventRecurrence(
            frequency: 'weekly',
            byWeekday: <String>['MO', 'WE'],
            anchorStartAt: '2026-04-05T09:00:00+08:00',
            anchorEndAt: '2026-04-05T09:30:00+08:00',
          ),
          mutationScope: 'series',
        ),
        timezone: AppConstants.defaultTimezone,
      );

      expect(payload.scope, 'series');
      expect(payload.recurrence, isNotNull);
      expect(payload.recurrence!.frequency, 'weekly');
      expect(payload.recurrence!.byWeekday, <String>['MO', 'WE']);
    },
  );
}
