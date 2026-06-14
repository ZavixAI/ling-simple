import 'package:ling/src/features/calendar/models/calendar_models.dart';

class LingCalendarEventDraft {
  const LingCalendarEventDraft({
    required this.title,
    required this.startAt,
    required this.durationMinutes,
    this.timeShape = 'span',
    this.location,
    this.meetingUrl,
    this.recurrence,
    this.mutationScope = 'series',
  });

  final String title;
  final DateTime startAt;
  final int durationMinutes;
  final String timeShape;
  final String? location;
  final String? meetingUrl;
  final LingEventRecurrence? recurrence;
  final String mutationScope;

  bool get isPoint => timeShape.trim().toLowerCase() == 'point';

  DateTime get endAt =>
      isPoint ? startAt : startAt.add(Duration(minutes: durationMinutes));
}

class LingCalendarEventEditorResult {
  const LingCalendarEventEditorResult._({
    this.draft,
    this.mutationScope = 'series',
  });

  LingCalendarEventEditorResult.saved(LingCalendarEventDraft draft)
    : this._(draft: draft, mutationScope: draft.mutationScope);

  final LingCalendarEventDraft? draft;
  final String mutationScope;
}
