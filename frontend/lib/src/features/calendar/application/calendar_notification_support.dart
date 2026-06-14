import 'package:ling/src/core/platform/models/notification_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';

List<CalendarNotificationRequest> buildCalendarNotificationRequests({
  required List<LingEvent> events,
  required LingStrings strings,
  required CalendarNotificationSettings settings,
  Set<String> forceLocalEventIds = const <String>{},
}) {
  final now = DateTime.now();
  final notifications = <CalendarNotificationRequest>[];
  if (!settings.enabled) {
    return notifications;
  }
  for (final event in events) {
    if (event.isPoint) {
      continue;
    }
    final eventId = event.eventId.trim();
    final rawTitle = event.title.trim();
    final title = rawTitle.isEmpty ? strings.untitled : rawTitle;
    final startAt = event.startAt;
    if (eventId.isEmpty || title.isEmpty) {
      continue;
    }
    if (!forceLocalEventIds.contains(eventId) && isSyncedCalendarEvent(event)) {
      continue;
    }
    if (_shouldUseAppleCalendarNativeNotificationForEvent(
      event,
      settings: settings,
      forceLocalEventIds: forceLocalEventIds,
    )) {
      continue;
    }

    final startLeadAt = startAt.subtract(
      Duration(minutes: settings.minutesBefore),
    );
    if (startLeadAt.isAfter(now)) {
      notifications.add(
        CalendarNotificationRequest(
          identifier: 'ling.calendar.$eventId.before.${settings.minutesBefore}',
          title: title,
          body: strings.notificationStartsInMinutesBody(settings.minutesBefore),
          scheduledAt: startLeadAt,
          mode: settings.toJson()['delivery_mode'] as String,
          soundEnabled:
              settings.deliveryMode ==
              CalendarNotificationDeliveryMode.bannerSound,
        ),
      );
    }

    if (settings.notifyAtStart && startAt.isAfter(now)) {
      notifications.add(
        CalendarNotificationRequest(
          identifier: 'ling.calendar.$eventId.start',
          title: title,
          body: strings.notificationStartsNowBody,
          scheduledAt: startAt,
          mode: settings.toJson()['delivery_mode'] as String,
          soundEnabled:
              settings.deliveryMode ==
              CalendarNotificationDeliveryMode.bannerSound,
        ),
      );
    }
  }

  notifications.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  if (notifications.length <= 64) {
    return notifications;
  }
  return notifications.take(64).toList(growable: false);
}

List<Map<String, dynamic>> buildAppleCalendarAlarmPayload(
  CalendarNotificationSettings settings, {
  LingEvent? event,
  bool syncingToAppleCalendar = false,
}) {
  if (settings.deliveryChannel !=
      CalendarNotificationDeliveryChannel.appleCalendarWhenSynced) {
    return const <Map<String, dynamic>>[];
  }
  if (event?.isPoint == true) {
    return const <Map<String, dynamic>>[];
  }
  if (syncingToAppleCalendar ||
      (event != null && isSyncedCalendarEvent(event))) {
    return const <Map<String, dynamic>>[];
  }
  final alarms = <Map<String, dynamic>>[
    {'relativeOffsetSeconds': -(settings.minutesBefore * 60)},
  ];
  if (settings.notifyAtStart) {
    alarms.add(const {'relativeOffsetSeconds': 0});
  }
  return alarms;
}

bool isSyncedCalendarEvent(LingEvent event) {
  final source = event.source.trim().toLowerCase();
  if (source.isNotEmpty && source != 'ling') {
    return true;
  }
  final eventIdentifier = event.appleLink?.eventIdentifier?.trim() ?? '';
  final calendarItemIdentifier =
      event.appleLink?.calendarItemIdentifier?.trim() ?? '';
  return eventIdentifier.isNotEmpty || calendarItemIdentifier.isNotEmpty;
}

bool _shouldUseAppleCalendarNativeNotificationForEvent(
  LingEvent event, {
  required CalendarNotificationSettings settings,
  Set<String> forceLocalEventIds = const <String>{},
}) {
  if (forceLocalEventIds.contains(event.eventId)) {
    return false;
  }
  if (settings.deliveryChannel !=
      CalendarNotificationDeliveryChannel.appleCalendarWhenSynced) {
    return false;
  }
  final eventIdentifier = event.appleLink?.eventIdentifier?.trim() ?? '';
  final calendarItemIdentifier =
      event.appleLink?.calendarItemIdentifier?.trim() ?? '';
  return eventIdentifier.isNotEmpty || calendarItemIdentifier.isNotEmpty;
}
