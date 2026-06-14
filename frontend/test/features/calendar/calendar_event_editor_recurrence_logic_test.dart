import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/config/constants.dart';
import 'package:ling/src/features/calendar/application/event_editor_support.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';

void main() {
  group('buildLingEventEditorRecurrence', () {
    test('preserves raw rules when the effective rule does not change', () {
      const initialRecurrence = LingEventRecurrence(
        frequency: 'weekly',
        byWeekday: <String>['MO', 'WE'],
        rawRrule: 'FREQ=WEEKLY;BYDAY=MO,WE',
        rawRrules: <String>['FREQ=WEEKLY;BYDAY=MO,WE'],
      );

      final recurrence = buildLingEventEditorRecurrence(
        frequency: 'weekly',
        initialRecurrence: initialRecurrence,
        startAt: DateTime(2026, 4, 13, 9, 30),
        durationMinutes: 45,
        timezone: AppConstants.defaultTimezone,
        weeklyRecurrenceDays: <String>{'WE', 'MO'},
      );

      expect(recurrence, isNotNull);
      expect(recurrence!.rawRrule, initialRecurrence.rawRrule);
      expect(recurrence.rawRrules, initialRecurrence.rawRrules);
      expect(recurrence.byWeekday, <String>['MO', 'WE']);
      expect(recurrence.anchorStartAt, '2026-04-13T09:30:00+08:00');
      expect(recurrence.anchorEndAt, '2026-04-13T10:15:00+08:00');
    });

    test('rebuilds normalized monthly rules when the frequency changes', () {
      const initialRecurrence = LingEventRecurrence(
        frequency: 'weekly',
        byWeekday: <String>['MO'],
        rawRrule: 'FREQ=WEEKLY;BYDAY=MO',
      );

      final recurrence = buildLingEventEditorRecurrence(
        frequency: 'monthly',
        initialRecurrence: initialRecurrence,
        startAt: DateTime(2026, 5, 21, 18, 0),
        durationMinutes: 30,
        timezone: AppConstants.defaultTimezone,
        weeklyRecurrenceDays: const <String>{},
      );

      expect(recurrence, isNotNull);
      expect(recurrence!.rawRrule, isNull);
      expect(recurrence.rawRrules, isEmpty);
      expect(recurrence.byMonthDay, <int>[21]);
      expect(recurrence.byWeekday, isEmpty);
    });
  });
}
