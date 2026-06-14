import 'package:ling/src/features/calendar/models/calendar_event_editor_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_time.dart';

const List<String> lingEventEditorWeekdayOrder = <String>[
  'MO',
  'TU',
  'WE',
  'TH',
  'FR',
  'SA',
  'SU',
];

List<String> sortedLingEventEditorWeekdayCodes(Iterable<String> codes) {
  final values = codes
      .map((value) => value.trim().toUpperCase())
      .where(lingEventEditorWeekdayOrder.contains)
      .toSet()
      .toList(growable: true);
  values.sort(
    (left, right) => lingEventEditorWeekdayOrder
        .indexOf(left)
        .compareTo(lingEventEditorWeekdayOrder.indexOf(right)),
  );
  return List<String>.unmodifiable(values);
}

List<int> sortedLingEventEditorMonthDays(Iterable<int> days) {
  final values =
      days.where((value) => value != 0).toSet().toList(growable: true)
        ..sort((left, right) => left.compareTo(right));
  return List<int>.unmodifiable(values);
}

List<int> sortedLingEventEditorMonths(Iterable<int> months) {
  final values =
      months
          .where((value) => value >= 1 && value <= 12)
          .toSet()
          .toList(growable: true)
        ..sort((left, right) => left.compareTo(right));
  return List<int>.unmodifiable(values);
}

String weekdayCodeForLingDate(DateTime value) {
  return lingEventEditorWeekdayOrder[(value.weekday - 1).clamp(0, 6)];
}

Set<String> initialLingEventEditorWeeklyRecurrenceDays(
  LingEventRecurrence recurrence,
  DateTime startAt,
) {
  final weekdayCodes = recurrence.byWeekday
      .map((value) => value.trim().toUpperCase())
      .where(lingEventEditorWeekdayOrder.contains)
      .toSet();
  if (weekdayCodes.isNotEmpty) {
    return weekdayCodes;
  }
  return <String>{weekdayCodeForLingDate(startAt)};
}

LingEventRecurrence? buildLingEventEditorRecurrence({
  required String frequency,
  required LingEventRecurrence? initialRecurrence,
  required DateTime startAt,
  required int durationMinutes,
  required String timezone,
  required Set<String> weeklyRecurrenceDays,
}) {
  final normalizedFrequency = frequency.trim().toLowerCase();
  if (normalizedFrequency.isEmpty) {
    return null;
  }

  final nextByWeekday = normalizedFrequency == 'weekly'
      ? sortedLingEventEditorWeekdayCodes(weeklyRecurrenceDays)
      : const <String>[];
  final nextByMonthDay =
      normalizedFrequency == 'monthly' || normalizedFrequency == 'yearly'
      ? <int>[startAt.day]
      : const <int>[];
  final nextByMonth = normalizedFrequency == 'yearly'
      ? <int>[startAt.month]
      : const <int>[];
  final shouldPreserveRawRules =
      initialRecurrence != null &&
      initialRecurrence.frequency.trim().toLowerCase() == normalizedFrequency &&
      sortedLingEventEditorWeekdayCodes(
            initialRecurrence.byWeekday.toSet(),
          ).join(',') ==
          nextByWeekday.join(',') &&
      sortedLingEventEditorMonthDays(initialRecurrence.byMonthDay).join(',') ==
          nextByMonthDay.join(',') &&
      sortedLingEventEditorMonths(initialRecurrence.byMonth).join(',') ==
          nextByMonth.join(',');

  return LingEventRecurrence(
    frequency: normalizedFrequency,
    interval: initialRecurrence?.interval ?? 1,
    count: initialRecurrence?.count,
    until: initialRecurrence?.until,
    byWeekday: nextByWeekday,
    byMonthDay: nextByMonthDay,
    byMonth: nextByMonth,
    rawRrule: shouldPreserveRawRules ? initialRecurrence.rawRrule : null,
    rawRrules: shouldPreserveRawRules
        ? initialRecurrence.rawRrules
        : const <String>[],
    anchorStartAt: formatLingDateTimeWithTimezone(startAt, timezone),
    anchorEndAt: formatLingDateTimeWithTimezone(
      startAt.add(Duration(minutes: durationMinutes)),
      timezone,
    ),
  );
}

LingEventUpsertRequest buildLingEventPayloadFromDraft({
  required LingCalendarEventDraft draft,
  required String timezone,
  LingEvent? existingEvent,
  String scope = 'series',
  String? occurrenceStartTime,
  bool includeRecurrence = true,
}) {
  final metadata =
      existingEvent?.metadata ??
      <String, dynamic>{'source': 'quick_add', 'created_from': 'schedule_fab'};
  final attendees = existingEvent?.attendees ?? const <Map<String, dynamic>>[];
  return LingEventUpsertRequest(
    title: draft.title,
    subtitle: draft.location,
    category: existingEvent?.category ?? 'personal',
    startAt: formatLingDateTimeWithTimezone(
      draft.startAt,
      existingEvent?.timezone ?? timezone,
    ),
    endAt: formatLingDateTimeWithTimezone(
      draft.endAt,
      existingEvent?.timezone ?? timezone,
    ),
    timezone: existingEvent?.timezone ?? timezone,
    location: draft.location,
    meetingUrl: draft.meetingUrl,
    attendees: attendees,
    status: existingEvent?.status ?? 'scheduled',
    timeShape: draft.timeShape,
    focusModeEnabled: existingEvent?.focusModeEnabled == true,
    metadata: metadata,
    recurrence: includeRecurrence ? draft.recurrence : null,
    scope: draft.mutationScope.isEmpty ? scope : draft.mutationScope,
    occurrenceStartTime: occurrenceStartTime,
  );
}
