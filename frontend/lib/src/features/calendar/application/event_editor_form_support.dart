import 'package:ling/src/features/calendar/models/calendar_event_editor_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';

class LingEventEditorFormSubmission {
  const LingEventEditorFormSubmission({this.titleErrorText, this.result});

  final String? titleErrorText;
  final LingCalendarEventEditorResult? result;

  bool get hasErrors => titleErrorText != null;
}

LingEventEditorFormSubmission buildLingEventEditorFormSubmission({
  required LingStrings strings,
  required String title,
  required String location,
  required String meetingUrl,
  required DateTime startAt,
  required int durationMinutes,
  String timeShape = 'span',
  required LingEventRecurrence? recurrence,
  required String mutationScope,
}) {
  final normalizedTitle = title.trim();
  final normalizedLocation = location.trim();
  final normalizedMeetingUrl = meetingUrl.trim();
  final titleError = normalizedTitle.isEmpty
      ? strings.quickAddTitleRequired
      : null;
  if (titleError != null) {
    return LingEventEditorFormSubmission(titleErrorText: titleError);
  }
  return LingEventEditorFormSubmission(
    result: LingCalendarEventEditorResult.saved(
      LingCalendarEventDraft(
        title: normalizedTitle,
        startAt: startAt,
        durationMinutes: durationMinutes,
        timeShape: timeShape,
        location: normalizedLocation.isEmpty ? null : normalizedLocation,
        meetingUrl: normalizedMeetingUrl.isEmpty ? null : normalizedMeetingUrl,
        recurrence: recurrence,
        mutationScope: mutationScope,
      ),
    ),
  );
}
