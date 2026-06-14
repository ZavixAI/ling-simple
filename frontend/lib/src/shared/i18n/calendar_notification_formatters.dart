import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';

String formatCalendarNotificationPermissionLabel(
  LingStrings strings,
  CalendarNotificationPermissionState permission,
) {
  switch (permission) {
    case CalendarNotificationPermissionState.granted:
      return strings.notificationPermissionGranted;
    case CalendarNotificationPermissionState.denied:
      return strings.notificationPermissionDenied;
    case CalendarNotificationPermissionState.notDetermined:
      return strings.notificationPermissionNotDetermined;
    case CalendarNotificationPermissionState.unsupported:
      return strings.notificationPermissionUnsupported;
  }
}

String formatCalendarNotificationModeLabel(
  LingStrings strings,
  CalendarNotificationDeliveryMode mode,
) {
  switch (mode) {
    case CalendarNotificationDeliveryMode.bannerSound:
      return strings.calendarNotificationModeBannerSound;
    case CalendarNotificationDeliveryMode.bannerOnly:
      return strings.calendarNotificationModeBannerOnly;
    case CalendarNotificationDeliveryMode.silent:
      return strings.calendarNotificationModeSilent;
  }
}

String formatCalendarNotificationSummary(
  LingStrings strings,
  CalendarNotificationSettings settings,
) {
  final parts = <String>[
    formatCalendarNotificationModeLabel(strings, settings.deliveryMode),
    strings.notifyBeforeMinutes(settings.minutesBefore),
  ];
  return parts.join(' · ');
}
