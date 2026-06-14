import 'package:json_annotation/json_annotation.dart';

part 'calendar_models.g.dart';

DateTime _parseLingWallClockDateTime(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw FormatException('Invalid empty datetime');
  }

  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(\.(\d{1,6}))?)?',
  ).firstMatch(normalized);
  if (match == null) {
    return DateTime.parse(normalized);
  }

  final fractional = (match.group(8) ?? '').padRight(6, '0');
  final microseconds = fractional.isEmpty ? 0 : int.parse(fractional);
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6) ?? '0'),
    microseconds ~/ 1000,
    microseconds % 1000,
  );
}

String _encodeLingWallClockDateTime(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$year-$month-$day'
      'T$hour:$minute:$second';
}

@JsonSerializable()
class AppleEventLink {
  const AppleEventLink({
    this.deviceId,
    this.calendarIdentifier,
    this.eventIdentifier,
    this.calendarItemIdentifier,
  });

  @JsonKey(name: 'device_id')
  final String? deviceId;
  @JsonKey(name: 'calendar_identifier')
  final String? calendarIdentifier;
  @JsonKey(name: 'event_identifier')
  final String? eventIdentifier;
  @JsonKey(name: 'calendar_item_identifier')
  final String? calendarItemIdentifier;

  factory AppleEventLink.fromJson(Map<String, dynamic> json) =>
      _$AppleEventLinkFromJson(json);

  Map<String, dynamic> toJson() => _$AppleEventLinkToJson(this);
}

class LingEventRecurrence {
  const LingEventRecurrence({
    required this.frequency,
    this.interval = 1,
    this.count,
    this.until,
    this.byWeekday = const <String>[],
    this.byMonthDay = const <int>[],
    this.byMonth = const <int>[],
    this.rawRrule,
    this.rawRrules = const <String>[],
    this.anchorStartAt,
    this.anchorEndAt,
  });

  final String frequency;
  final int interval;
  final int? count;
  final String? until;
  final List<String> byWeekday;
  final List<int> byMonthDay;
  final List<int> byMonth;
  final String? rawRrule;
  final List<String> rawRrules;
  final String? anchorStartAt;
  final String? anchorEndAt;

  factory LingEventRecurrence.fromJson(Map<String, dynamic> json) {
    return LingEventRecurrence(
      frequency: '${json['frequency'] ?? json['freq'] ?? ''}'.trim(),
      interval: json['interval'] is int
          ? json['interval'] as int
          : int.tryParse('${json['interval'] ?? ''}') ?? 1,
      count: json['count'] is int
          ? json['count'] as int
          : int.tryParse('${json['count'] ?? ''}'),
      until: json['until']?.toString(),
      byWeekday: _decodeStringList(json['by_weekday'] ?? json['byWeekday']),
      byMonthDay: _decodeIntList(json['by_month_day'] ?? json['byMonthDay']),
      byMonth: _decodeIntList(json['by_month'] ?? json['byMonth']),
      rawRrule: json['raw_rrule']?.toString() ?? json['rawRrule']?.toString(),
      rawRrules: _decodeStringList(json['raw_rrules'] ?? json['rawRRules']),
      anchorStartAt:
          json['anchor_start_at']?.toString() ??
          json['anchorStartAt']?.toString(),
      anchorEndAt:
          json['anchor_end_at']?.toString() ?? json['anchorEndAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'frequency': frequency,
      'interval': interval,
      if (count != null) 'count': count,
      if (until != null) 'until': until,
      if (byWeekday.isNotEmpty) 'by_weekday': byWeekday,
      if (byMonthDay.isNotEmpty) 'by_month_day': byMonthDay,
      if (byMonth.isNotEmpty) 'by_month': byMonth,
      if (rawRrule != null) 'raw_rrule': rawRrule,
      if (rawRrules.isNotEmpty) 'raw_rrules': rawRrules,
      if (anchorStartAt != null) 'anchor_start_at': anchorStartAt,
      if (anchorEndAt != null) 'anchor_end_at': anchorEndAt,
    };
  }
}

class LingEvent {
  const LingEvent({
    required this.eventId,
    required this.userId,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.timezone,
    this.subtitle,
    this.category = 'personal',
    this.location,
    this.meetingUrl,
    this.attendees = const <Map<String, dynamic>>[],
    this.status = 'scheduled',
    this.timeShape = 'span',
    this.focusModeEnabled = false,
    this.metadata = const <String, dynamic>{},
    this.syncState = 'pending',
    this.appleLink,
    this.source = 'ling',
    this.provider = 'ling',
    this.isMutable = true,
    this.isDeletable = true,
    this.isRecurring = false,
    this.seriesId,
    this.occurrenceStartAt,
    this.isOccurrenceOverride = false,
    this.recurrence,
    this.createdAt,
    this.updatedAt,
  });

  @JsonKey(name: 'event_id')
  final String eventId;
  @JsonKey(name: 'user_id')
  final String userId;
  final String title;
  final String? subtitle;
  final String category;
  @JsonKey(
    name: 'start_at',
    fromJson: _parseLingWallClockDateTime,
    toJson: _encodeLingWallClockDateTime,
  )
  final DateTime startAt;
  @JsonKey(
    name: 'end_at',
    fromJson: _parseLingWallClockDateTime,
    toJson: _encodeLingWallClockDateTime,
  )
  final DateTime endAt;
  final String timezone;
  final String? location;
  @JsonKey(name: 'meeting_url')
  final String? meetingUrl;
  final List<Map<String, dynamic>> attendees;
  final String status;
  @JsonKey(name: 'time_shape')
  final String timeShape;
  @JsonKey(name: 'focus_mode_enabled')
  final bool focusModeEnabled;
  final Map<String, dynamic> metadata;
  @JsonKey(name: 'sync_state')
  final String syncState;
  @JsonKey(name: 'apple_link')
  final AppleEventLink? appleLink;
  final String source;
  final String provider;
  @JsonKey(name: 'is_mutable')
  final bool isMutable;
  @JsonKey(name: 'is_deletable')
  final bool isDeletable;
  @JsonKey(name: 'is_recurring')
  final bool isRecurring;
  @JsonKey(name: 'series_id')
  final String? seriesId;
  @JsonKey(
    name: 'occurrence_start_at',
    fromJson: _parseNullableDateTime,
    toJson: _encodeNullableLingWallClockDateTime,
  )
  final DateTime? occurrenceStartAt;
  @JsonKey(name: 'is_occurrence_override')
  final bool isOccurrenceOverride;
  final LingEventRecurrence? recurrence;
  @JsonKey(
    name: 'created_at',
    fromJson: _parseNullableDateTime,
    toJson: _encodeNullableLingWallClockDateTime,
  )
  final DateTime? createdAt;
  @JsonKey(
    name: 'updated_at',
    fromJson: _parseNullableDateTime,
    toJson: _encodeNullableLingWallClockDateTime,
  )
  final DateTime? updatedAt;

  bool get isPoint => timeShape.trim().toLowerCase() == 'point';

  LingEvent copyWith({
    String? eventId,
    String? userId,
    String? title,
    String? subtitle,
    String? category,
    DateTime? startAt,
    DateTime? endAt,
    String? timezone,
    String? location,
    bool clearLocation = false,
    String? meetingUrl,
    bool clearMeetingUrl = false,
    List<Map<String, dynamic>>? attendees,
    String? status,
    String? timeShape,
    bool? focusModeEnabled,
    Map<String, dynamic>? metadata,
    String? syncState,
    AppleEventLink? appleLink,
    String? source,
    String? provider,
    bool? isMutable,
    bool? isDeletable,
    bool? isRecurring,
    String? seriesId,
    DateTime? occurrenceStartAt,
    bool? isOccurrenceOverride,
    LingEventRecurrence? recurrence,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LingEvent(
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      timezone: timezone ?? this.timezone,
      location: clearLocation ? null : (location ?? this.location),
      meetingUrl: clearMeetingUrl ? null : (meetingUrl ?? this.meetingUrl),
      attendees: attendees ?? this.attendees,
      status: status ?? this.status,
      timeShape: timeShape ?? this.timeShape,
      focusModeEnabled: focusModeEnabled ?? this.focusModeEnabled,
      metadata: metadata ?? this.metadata,
      syncState: syncState ?? this.syncState,
      appleLink: appleLink ?? this.appleLink,
      source: source ?? this.source,
      provider: provider ?? this.provider,
      isMutable: isMutable ?? this.isMutable,
      isDeletable: isDeletable ?? this.isDeletable,
      isRecurring: isRecurring ?? this.isRecurring,
      seriesId: seriesId ?? this.seriesId,
      occurrenceStartAt: occurrenceStartAt ?? this.occurrenceStartAt,
      isOccurrenceOverride: isOccurrenceOverride ?? this.isOccurrenceOverride,
      recurrence: recurrence ?? this.recurrence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory LingEvent.fromJson(Map<String, dynamic> json) {
    return LingEvent(
      eventId: '${json['event_id'] ?? ''}',
      userId: '${json['user_id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      subtitle: json['subtitle']?.toString(),
      category: '${json['category'] ?? 'personal'}',
      startAt: _parseLingWallClockDateTime('${json['start_at']}'),
      endAt: _parseLingWallClockDateTime('${json['end_at']}'),
      timezone: '${json['timezone'] ?? 'UTC'}',
      location: json['location']?.toString(),
      meetingUrl: json['meeting_url']?.toString(),
      attendees: _decodeMapList(json['attendees']),
      status: '${json['status'] ?? 'scheduled'}',
      timeShape: '${json['time_shape'] ?? 'span'}',
      focusModeEnabled: json['focus_mode_enabled'] == true,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const <String, dynamic>{},
      syncState: '${json['sync_state'] ?? 'pending'}',
      appleLink: json['apple_link'] is Map
          ? AppleEventLink.fromJson(
              Map<String, dynamic>.from(json['apple_link'] as Map),
            )
          : null,
      source: '${json['source'] ?? 'ling'}',
      provider: '${json['provider'] ?? 'ling'}',
      isMutable: json['is_mutable'] != false,
      isDeletable: json['is_deletable'] != false,
      isRecurring: json['is_recurring'] == true,
      seriesId: json['series_id']?.toString(),
      occurrenceStartAt: _parseNullableDateTime(json['occurrence_start_at']),
      isOccurrenceOverride: json['is_occurrence_override'] == true,
      recurrence: json['recurrence'] is Map
          ? LingEventRecurrence.fromJson(
              Map<String, dynamic>.from(json['recurrence'] as Map),
            )
          : null,
      createdAt: _parseNullableDateTime(json['created_at']),
      updatedAt: _parseNullableDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'event_id': eventId,
      'user_id': userId,
      'title': title,
      'subtitle': subtitle,
      'category': category,
      'start_at': _encodeLingWallClockDateTime(startAt),
      'end_at': _encodeLingWallClockDateTime(endAt),
      'timezone': timezone,
      'location': location,
      'meeting_url': meetingUrl,
      'attendees': attendees,
      'status': status,
      'time_shape': timeShape,
      'focus_mode_enabled': focusModeEnabled,
      'metadata': metadata,
      'sync_state': syncState,
      'apple_link': appleLink?.toJson(),
      'source': source,
      'provider': provider,
      'is_mutable': isMutable,
      'is_deletable': isDeletable,
      'is_recurring': isRecurring,
      'series_id': seriesId,
      'occurrence_start_at': _encodeNullableLingWallClockDateTime(
        occurrenceStartAt,
      ),
      'is_occurrence_override': isOccurrenceOverride,
      'recurrence': recurrence?.toJson(),
      'created_at': _encodeNullableLingWallClockDateTime(createdAt),
      'updated_at': _encodeNullableLingWallClockDateTime(updatedAt),
    };
  }
}

class LingEventUpsertRequest {
  const LingEventUpsertRequest({
    required this.title,
    required this.category,
    required this.startAt,
    required this.endAt,
    required this.timezone,
    required this.attendees,
    required this.status,
    this.timeShape = 'span',
    required this.focusModeEnabled,
    required this.metadata,
    this.subtitle,
    this.location,
    this.meetingUrl,
    this.recurrence,
    this.scope = 'series',
    this.occurrenceStartTime,
  });

  final String title;
  final String? subtitle;
  final String category;
  final String startAt;
  final String endAt;
  final String timezone;
  final String? location;
  final String? meetingUrl;
  final List<Map<String, dynamic>> attendees;
  final String status;
  final String timeShape;
  final bool focusModeEnabled;
  final Map<String, dynamic> metadata;
  final LingEventRecurrence? recurrence;
  final String scope;
  final String? occurrenceStartTime;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'subtitle': subtitle,
      'category': category,
      'start_at': startAt,
      'end_at': endAt,
      'timezone': timezone,
      'location': location,
      'meeting_url': meetingUrl,
      'attendees': attendees,
      'status': status,
      'time_shape': timeShape,
      'focus_mode_enabled': focusModeEnabled,
      'metadata': metadata,
      if (recurrence != null) 'recurrence': recurrence!.toJson(),
      'scope': scope,
      if (occurrenceStartTime != null)
        'occurrence_start_time': occurrenceStartTime,
    };
  }
}

DateTime? _parseNullableDateTime(Object? value) {
  final raw = (value ?? '').toString().trim();
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

String? _encodeNullableLingWallClockDateTime(DateTime? value) {
  if (value == null) {
    return null;
  }
  return _encodeLingWallClockDateTime(value);
}

List<String> _decodeStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<int> _decodeIntList(Object? value) {
  if (value is! List) {
    return const <int>[];
  }
  return value
      .map((item) => item is int ? item : int.tryParse('$item'))
      .whereType<int>()
      .toList(growable: false);
}

List<Map<String, dynamic>> _decodeMapList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map<Object?, Object?>>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

class AppleEventLinkRequest {
  const AppleEventLinkRequest({
    required this.lingEventId,
    required this.deviceId,
    required this.calendarIdentifier,
    required this.eventIdentifier,
    required this.syncState,
    this.metadata = const <String, dynamic>{},
  });

  final String lingEventId;
  final String deviceId;
  final String calendarIdentifier;
  final String eventIdentifier;
  final String syncState;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'event_id': lingEventId,
      'device_id': deviceId,
      'calendar_identifier': calendarIdentifier,
      'event_identifier': eventIdentifier,
      'sync_state': syncState,
      'metadata': metadata,
    };
  }
}

class AppleCalendarContextUploadRequest {
  const AppleCalendarContextUploadRequest({
    required this.deviceId,
    required this.windowStart,
    required this.windowEnd,
    required this.permissionState,
    required this.events,
    this.timezone,
  });

  final String deviceId;
  final String windowStart;
  final String windowEnd;
  final String permissionState;
  final List<Map<String, dynamic>> events;
  final String? timezone;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'device_id': deviceId,
      'window_start': windowStart,
      'window_end': windowEnd,
      'permission_state': permissionState,
      'events': events,
      'timezone': timezone,
    };
  }
}

@JsonSerializable()
class CalendarMonthDay {
  const CalendarMonthDay({
    required this.date,
    required this.inCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.eventCount,
    required this.hasFocusEvent,
  });

  final String date;
  @JsonKey(name: 'in_current_month')
  final bool inCurrentMonth;
  @JsonKey(name: 'is_today')
  final bool isToday;
  @JsonKey(name: 'is_selected')
  final bool isSelected;
  @JsonKey(name: 'event_count')
  final int eventCount;
  @JsonKey(name: 'has_focus_event')
  final bool hasFocusEvent;

  factory CalendarMonthDay.fromJson(Map<String, dynamic> json) =>
      _$CalendarMonthDayFromJson(json);

  Map<String, dynamic> toJson() => _$CalendarMonthDayToJson(this);
}

@JsonSerializable(explicitToJson: true)
class CalendarMonthSnapshot {
  const CalendarMonthSnapshot({
    required this.month,
    required this.timezone,
    required this.days,
    required this.selectedDayEvents,
  });

  final String month;
  final String timezone;
  final List<CalendarMonthDay> days;
  @JsonKey(name: 'selected_day_events')
  final List<LingEvent> selectedDayEvents;

  factory CalendarMonthSnapshot.fromJson(Map<String, dynamic> json) =>
      _$CalendarMonthSnapshotFromJson(json);

  Map<String, dynamic> toJson() => _$CalendarMonthSnapshotToJson(this);
}
