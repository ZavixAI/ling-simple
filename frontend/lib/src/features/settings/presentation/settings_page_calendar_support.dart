import 'package:ling/src/features/calendar/models/apple_calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_integration_models.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';

const visibleSettingsCalendarProviders = <CalendarProviderId>[
  CalendarProviderId.appleLocal,
];

CalendarConnectionSummary? settingsCalendarConnectionFor(
  Iterable<CalendarConnectionSummary> connections,
  CalendarProviderId provider,
) {
  for (final connection in connections) {
    if (connection.providerId == provider) {
      return connection;
    }
  }
  return null;
}

String settingsCalendarProviderTitle(
  LingStrings strings,
  CalendarProviderId provider,
) {
  return switch (provider) {
    CalendarProviderId.appleLocal => strings.appleCalendarRowTitle,
    CalendarProviderId.feishu => strings.feishuCalendarRowTitle,
    CalendarProviderId.dingtalk => strings.dingtalkCalendarRowTitle,
  };
}

String settingsCalendarAuthorizationStatusLabel({
  required LingStrings strings,
  required CalendarProviderId provider,
  required AppleCalendarPermissionState appleCalendarPermission,
  required Iterable<CalendarConnectionSummary> calendarConnections,
}) {
  if (provider == CalendarProviderId.appleLocal) {
    return appleCalendarPermission == AppleCalendarPermissionState.granted
        ? strings.calendarAccessAuthorized
        : strings.calendarAccessUnauthorized;
  }
  final connection = settingsCalendarConnectionFor(
    calendarConnections,
    provider,
  );
  if (connection == null) {
    return strings.notificationPermissionUnauthorized;
  }
  switch (connection.status) {
    case 'connected':
    case 'syncing':
      return strings.notificationPermissionGranted;
    default:
      return strings.notificationPermissionUnauthorized;
  }
}

bool shouldShowSettingsCalendarProviderMenu(
  CalendarConnectionSummary? connection,
) {
  if (connection == null ||
      connection.isAppleLocal ||
      !connection.isConnected) {
    return false;
  }
  switch (connection.status) {
    case 'connected':
    case 'syncing':
    case 'error':
    case 'action_required':
      return true;
    default:
      return false;
  }
}
