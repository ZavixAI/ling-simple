// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppleEventLink _$AppleEventLinkFromJson(Map<String, dynamic> json) =>
    AppleEventLink(
      deviceId: json['device_id'] as String?,
      calendarIdentifier: json['calendar_identifier'] as String?,
      eventIdentifier: json['event_identifier'] as String?,
      calendarItemIdentifier: json['calendar_item_identifier'] as String?,
    );

Map<String, dynamic> _$AppleEventLinkToJson(AppleEventLink instance) =>
    <String, dynamic>{
      'device_id': instance.deviceId,
      'calendar_identifier': instance.calendarIdentifier,
      'event_identifier': instance.eventIdentifier,
      'calendar_item_identifier': instance.calendarItemIdentifier,
    };

CalendarMonthDay _$CalendarMonthDayFromJson(Map<String, dynamic> json) =>
    CalendarMonthDay(
      date: json['date'] as String,
      inCurrentMonth: json['in_current_month'] as bool,
      isToday: json['is_today'] as bool,
      isSelected: json['is_selected'] as bool,
      eventCount: (json['event_count'] as num).toInt(),
      hasFocusEvent: json['has_focus_event'] as bool,
    );

Map<String, dynamic> _$CalendarMonthDayToJson(CalendarMonthDay instance) =>
    <String, dynamic>{
      'date': instance.date,
      'in_current_month': instance.inCurrentMonth,
      'is_today': instance.isToday,
      'is_selected': instance.isSelected,
      'event_count': instance.eventCount,
      'has_focus_event': instance.hasFocusEvent,
    };

CalendarMonthSnapshot _$CalendarMonthSnapshotFromJson(
  Map<String, dynamic> json,
) => CalendarMonthSnapshot(
  month: json['month'] as String,
  timezone: json['timezone'] as String,
  days: (json['days'] as List<dynamic>)
      .map((e) => CalendarMonthDay.fromJson(e as Map<String, dynamic>))
      .toList(),
  selectedDayEvents: (json['selected_day_events'] as List<dynamic>)
      .map((e) => LingEvent.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$CalendarMonthSnapshotToJson(
  CalendarMonthSnapshot instance,
) => <String, dynamic>{
  'month': instance.month,
  'timezone': instance.timezone,
  'days': instance.days.map((e) => e.toJson()).toList(),
  'selected_day_events': instance.selectedDayEvents
      .map((e) => e.toJson())
      .toList(),
};
