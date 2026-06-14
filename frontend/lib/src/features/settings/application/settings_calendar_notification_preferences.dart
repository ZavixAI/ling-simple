import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';

CalendarNotificationSettings calendarNotificationSettingsFromProfile(
  UserProfile? profile,
) {
  final notificationJson =
      profile?.preferences?.calendarNotifications ?? const <String, dynamic>{};
  return CalendarNotificationSettings.fromJson(notificationJson);
}

CalendarSyncSettings calendarSyncSettingsFromProfile(UserProfile? profile) {
  final syncJson =
      profile?.preferences?.calendarSync ?? const <String, dynamic>{};
  return CalendarSyncSettings.fromJson(syncJson);
}

UserProfile? profileWithCalendarNotificationSettings(
  UserProfile? profile,
  CalendarNotificationSettings settings,
) {
  if (profile == null) {
    return null;
  }
  final preferences = profile.preferences ?? const UserPreferences();
  return profile.copyWith(
    preferences: preferences.copyWith(calendarNotifications: settings.toJson()),
  );
}

UserProfile? profileWithCalendarSyncSettings(
  UserProfile? profile,
  CalendarSyncSettings settings,
) {
  if (profile == null) {
    return null;
  }
  final preferences = profile.preferences ?? const UserPreferences();
  return profile.copyWith(
    preferences: preferences.copyWith(calendarSync: settings.toJson()),
  );
}
