import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_time.dart';

enum AppleCalendarPermissionState {
  granted,
  denied,
  notDetermined,
  unsupported,
}

enum AppleCalendarEventKind { event, holiday }

Map<String, dynamic> buildAppleCalendarDraftFromLingEvent({
  required LingEvent event,
  required List<Map<String, dynamic>> alarms,
  String fallbackTitle = 'Untitled',
  String? calendarIdentifier,
  bool includeRecurrence = true,
  bool useRecurrenceAnchors = false,
}) {
  final title = event.title.trim().isEmpty ? fallbackTitle : event.title.trim();
  final subtitle = (event.subtitle ?? '').trim();
  final location = (event.location ?? '').trim();
  final recurrence = includeRecurrence ? event.recurrence : null;
  final startAt = useRecurrenceAnchors
      ? (recurrence?.anchorStartAt ??
            formatLingDateTimeWithTimezone(event.startAt, event.timezone))
      : formatLingDateTimeWithTimezone(event.startAt, event.timezone);
  final endAt = useRecurrenceAnchors
      ? (recurrence?.anchorEndAt ??
            formatLingDateTimeWithTimezone(event.endAt, event.timezone))
      : formatLingDateTimeWithTimezone(event.endAt, event.timezone);
  return <String, dynamic>{
    'title': title,
    'calendarIdentifier': calendarIdentifier,
    'startAt': startAt,
    'endAt': endAt,
    'location': location,
    'notes': subtitle,
    'timezone': event.timezone,
    'url': '',
    'alarms': alarms,
    if (includeRecurrence) 'recurrence': recurrence?.toJson(),
  };
}

bool _looksLikeAppleHoliday(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  return normalized.contains('holiday') ||
      normalized.contains('holidays') ||
      normalized.contains('节假日') ||
      normalized.contains('假期') ||
      normalized.contains('法定假日') ||
      normalized.contains('放假');
}

AppleCalendarEventKind _parseAppleCalendarEventKind(
  Object? raw, {
  String calendarTitle = '',
  String title = '',
}) {
  switch ('$raw'.trim().toLowerCase()) {
    case 'holiday':
      return AppleCalendarEventKind.holiday;
    case 'event':
      return AppleCalendarEventKind.event;
  }
  if (_looksLikeAppleHoliday(calendarTitle) || _looksLikeAppleHoliday(title)) {
    return AppleCalendarEventKind.holiday;
  }
  return AppleCalendarEventKind.event;
}

class AppleCalendarItem {
  const AppleCalendarItem({
    required this.identifier,
    required this.title,
    required this.isDefault,
  });

  final String identifier;
  final String title;
  final bool isDefault;

  factory AppleCalendarItem.fromJson(Map<Object?, Object?> json) {
    return AppleCalendarItem(
      identifier: '${json['identifier'] ?? ''}',
      title: '${json['title'] ?? ''}',
      isDefault: json['isDefault'] == true,
    );
  }
}

class AppleCalendarEvent {
  const AppleCalendarEvent({
    required this.identifier,
    required this.calendarIdentifier,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.timezone,
    this.calendarTitle,
    this.calendarItemIdentifier,
    this.notes,
    this.location,
    this.isAllDay = false,
    this.kind = AppleCalendarEventKind.event,
    this.occurrenceDate,
    this.isDetached = false,
    this.isRecurring = false,
    this.recurrence,
    this.rawRRules = const <String>[],
  });

  final String identifier;
  final String calendarIdentifier;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final String timezone;
  final String? calendarTitle;
  final String? calendarItemIdentifier;
  final String? notes;
  final String? location;
  final bool isAllDay;
  final AppleCalendarEventKind kind;
  final DateTime? occurrenceDate;
  final bool isDetached;
  final bool isRecurring;
  final LingEventRecurrence? recurrence;
  final List<String> rawRRules;

  AppleCalendarEvent copyWith({
    String? identifier,
    String? calendarIdentifier,
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    String? timezone,
    String? calendarTitle,
    String? calendarItemIdentifier,
    String? notes,
    String? location,
    bool? isAllDay,
    AppleCalendarEventKind? kind,
    DateTime? occurrenceDate,
    bool? isDetached,
    bool? isRecurring,
    LingEventRecurrence? recurrence,
    List<String>? rawRRules,
  }) {
    return AppleCalendarEvent(
      identifier: identifier ?? this.identifier,
      calendarIdentifier: calendarIdentifier ?? this.calendarIdentifier,
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      timezone: timezone ?? this.timezone,
      calendarTitle: calendarTitle ?? this.calendarTitle,
      calendarItemIdentifier:
          calendarItemIdentifier ?? this.calendarItemIdentifier,
      notes: notes ?? this.notes,
      location: location ?? this.location,
      isAllDay: isAllDay ?? this.isAllDay,
      kind: kind ?? this.kind,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      isDetached: isDetached ?? this.isDetached,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrence: recurrence ?? this.recurrence,
      rawRRules: rawRRules ?? this.rawRRules,
    );
  }

  factory AppleCalendarEvent.fromJson(Map<Object?, Object?> json) {
    final calendarTitle = json['calendarTitle']?.toString();
    final title = '${json['title'] ?? ''}';
    final timezone = _normalizeAppleTimezone(json['timezone']?.toString());
    final rawRRules = _decodeRawRRules(json['rawRRules'] ?? json['raw_rrules']);
    final startAt = _convertAppleEventDateTime('${json['startAt']}', timezone);
    final endAt = _convertAppleEventDateTime('${json['endAt']}', timezone);
    final occurrenceDate = _convertOptionalAppleEventDateTime(
      json['occurrenceDate'] ?? json['occurrence_date'],
      timezone,
    );
    final recurrence = json['recurrence'] is Map
        ? LingEventRecurrence.fromJson(
            Map<String, dynamic>.from(json['recurrence'] as Map),
          )
        : null;
    final explicitRecurring =
        json['isRecurring'] == true || json['is_recurring'] == true;
    final hasRecurrenceMetadata = recurrence != null || rawRRules.isNotEmpty;
    return AppleCalendarEvent(
      identifier: '${json['identifier'] ?? ''}',
      calendarIdentifier: '${json['calendarIdentifier'] ?? ''}',
      title: title,
      startAt: startAt,
      endAt: endAt,
      timezone: timezone,
      calendarTitle: calendarTitle,
      calendarItemIdentifier:
          json['calendarItemIdentifier']?.toString() ??
          json['calendar_item_identifier']?.toString(),
      notes: json['notes']?.toString(),
      location: json['location']?.toString(),
      isAllDay: json['isAllDay'] == true || json['is_all_day'] == true,
      kind: _parseAppleCalendarEventKind(
        json['kind'],
        calendarTitle: calendarTitle ?? '',
        title: title,
      ),
      occurrenceDate: occurrenceDate,
      isDetached: json['isDetached'] == true || json['is_detached'] == true,
      isRecurring:
          hasRecurrenceMetadata ||
          (explicitRecurring && occurrenceDate == null),
      recurrence: recurrence,
      rawRRules: rawRRules,
    );
  }

  AppleCalendarEvent normalizedToTimezone(String timezone) {
    final normalizedTimezone = _normalizeAppleTimezone(timezone);
    return copyWith(
      timezone: normalizedTimezone,
      startAt: convertLingWallTimeBetweenTimezones(
        startAt,
        fromTimezone: this.timezone,
        toTimezone: normalizedTimezone,
      ),
      endAt: convertLingWallTimeBetweenTimezones(
        endAt,
        fromTimezone: this.timezone,
        toTimezone: normalizedTimezone,
      ),
      occurrenceDate: occurrenceDate == null
          ? null
          : convertLingWallTimeBetweenTimezones(
              occurrenceDate!,
              fromTimezone: this.timezone,
              toTimezone: normalizedTimezone,
            ),
    );
  }

  Map<String, dynamic> toSummaryJson({String? timezone}) {
    final normalizedTimezone = _normalizeAppleTimezone(
      timezone ?? this.timezone,
    );
    final startAtValue = formatLingDateTimeWithTimezone(
      startAt,
      normalizedTimezone,
    );
    final endAtValue = formatLingDateTimeWithTimezone(
      endAt,
      normalizedTimezone,
    );
    return {
      'event_identifier': identifier,
      'calendar_identifier': calendarIdentifier,
      'calendar_item_identifier': calendarItemIdentifier,
      'calendar_title': calendarTitle,
      'title': title,
      'start_at': startAtValue,
      'end_at': endAtValue,
      'timezone': normalizedTimezone,
      'notes': notes,
      'location': location,
      'is_all_day': isAllDay,
      'kind': kind.name,
      'occurrence_date': occurrenceDate == null
          ? null
          : formatLingDateTimeWithTimezone(occurrenceDate!, normalizedTimezone),
      'is_detached': isDetached,
      'is_recurring': isRecurring,
      'recurrence': recurrence?.toJson(),
      'raw_rrules': rawRRules,
    };
  }
}

class AppleManagedEventLink {
  const AppleManagedEventLink({
    required this.linkId,
    required this.eventId,
    required this.deviceId,
    required this.calendarIdentifier,
    required this.eventIdentifier,
    required this.isRecurring,
    this.calendarItemIdentifier,
    this.occurrenceStartAt,
    this.syncState,
  });

  final String linkId;
  final String eventId;
  final String deviceId;
  final String calendarIdentifier;
  final String eventIdentifier;
  final bool isRecurring;
  final String? calendarItemIdentifier;
  final DateTime? occurrenceStartAt;
  final String? syncState;

  factory AppleManagedEventLink.fromJson(Map<Object?, Object?> json) {
    return AppleManagedEventLink(
      linkId: '${json['link_id'] ?? json['linkId'] ?? ''}',
      eventId: '${json['event_id'] ?? json['eventId'] ?? ''}',
      deviceId: '${json['device_id'] ?? json['deviceId'] ?? ''}',
      calendarIdentifier:
          '${json['calendar_identifier'] ?? json['calendarIdentifier'] ?? ''}',
      eventIdentifier:
          '${json['event_identifier'] ?? json['eventIdentifier'] ?? ''}',
      isRecurring: json['is_recurring'] == true || json['isRecurring'] == true,
      calendarItemIdentifier:
          json['calendar_item_identifier']?.toString() ??
          json['calendarItemIdentifier']?.toString(),
      occurrenceStartAt: _parseOptionalDateTime(
        json['occurrence_start_at'] ?? json['occurrenceStartAt'],
      ),
      syncState:
          json['sync_state']?.toString() ?? json['syncState']?.toString(),
    );
  }

  Map<String, dynamic> toDeletionJson() {
    return <String, dynamic>{
      'eventIdentifier': eventIdentifier,
      'calendarIdentifier': calendarIdentifier,
      if (calendarItemIdentifier?.trim().isNotEmpty ?? false)
        'calendarItemIdentifier': calendarItemIdentifier,
      if (occurrenceStartAt != null)
        'occurrenceDate': occurrenceStartAt!.toIso8601String(),
      'span': isRecurring
          ? AppleCalendarMutationSpan.futureEvents.name
          : AppleCalendarMutationSpan.thisEvent.name,
    };
  }
}

enum AppleCalendarMutationSpan { thisEvent, futureEvents }

class AppleCalendarMutationOptions {
  const AppleCalendarMutationOptions({
    required this.eventIdentifier,
    this.calendarItemIdentifier,
    this.occurrenceDate,
    this.span = AppleCalendarMutationSpan.thisEvent,
  });

  final String eventIdentifier;
  final String? calendarItemIdentifier;
  final DateTime? occurrenceDate;
  final AppleCalendarMutationSpan span;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'eventIdentifier': eventIdentifier,
      if (calendarItemIdentifier?.trim().isNotEmpty ?? false)
        'calendarItemIdentifier': calendarItemIdentifier,
      if (occurrenceDate != null)
        'occurrenceDate': occurrenceDate!.toIso8601String(),
      'span': span.name,
    };
  }
}

DateTime? _parseOptionalDateTime(Object? value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

String _normalizeAppleTimezone(String? value) {
  final normalized = (value ?? '').trim();
  if (normalized.isEmpty) {
    return 'UTC';
  }
  return normalized;
}

DateTime _convertAppleEventDateTime(String value, String timezone) {
  return convertLingDateTimeToTimezone(DateTime.parse(value), timezone);
}

DateTime? _convertOptionalAppleEventDateTime(Object? value, String timezone) {
  final parsed = _parseOptionalDateTime(value);
  if (parsed == null) {
    return null;
  }
  return convertLingDateTimeToTimezone(parsed, timezone);
}

List<String> _decodeRawRRules(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
