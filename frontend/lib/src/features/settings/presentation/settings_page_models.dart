import 'package:flutter/material.dart';
import 'package:ling/src/core/platform/models/notification_models.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/calendar/models/apple_calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_integration_models.dart';
import 'package:ling/src/features/chat/data/apple_speech_recognition_bridge.dart';
import 'package:ling/src/features/membership/models/membership_models.dart';
import 'package:ling/src/features/settings/application/settings_state.dart';
import 'package:ling/src/features/settings/data/bridges/photo_library_permission_bridge.dart';
import 'package:ling/src/features/settings/models/account_binding_models.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';
import 'package:ling/src/shared/models/font_size_preference.dart';
import 'package:ling/src/shared/models/phone_country.dart';
import 'package:ling/src/shared/presentation/edge_swipe_back.dart';

class LingSettingsAppearanceData {
  const LingSettingsAppearanceData({
    required this.themeMode,
    required this.localeCode,
    required this.timezone,
    required this.fontSizeLevel,
    this.preferredInputMode = 'text',
    this.localImageCacheBytes,
    this.isClearingLocalImageCache = false,
  });

  final ThemeMode themeMode;
  final String localeCode;
  final String timezone;
  final LingFontSizeLevel fontSizeLevel;
  final String preferredInputMode;
  final int? localImageCacheBytes;
  final bool isClearingLocalImageCache;
}

class LingSettingsMembershipData {
  const LingSettingsMembershipData({required this.summary});

  final MembershipSummary? summary;
}

class LingSettingsAccountData {
  const LingSettingsAccountData({
    required this.profile,
    required this.identities,
    required this.phoneBindingState,
    required this.emailBindingState,
    required this.initialPhoneCountry,
  });

  final UserProfile? profile;
  final List<UserIdentity> identities;
  final SettingsBindingState phoneBindingState;
  final SettingsBindingState emailBindingState;
  final PhoneCountry initialPhoneCountry;
}

class LingSettingsCalendarData {
  const LingSettingsCalendarData({
    required this.appleCalendarPermission,
    required this.connections,
    required this.syncSettings,
    required this.notificationPermission,
    required this.notificationSettings,
  });

  final AppleCalendarPermissionState appleCalendarPermission;
  final List<CalendarConnectionSummary> connections;
  final CalendarSyncSettings syncSettings;
  final CalendarNotificationPermissionState notificationPermission;
  final CalendarNotificationSettings notificationSettings;
}

class LingSettingsAboutData {
  const LingSettingsAboutData();
}

class LingSettingsPageViewModel {
  const LingSettingsPageViewModel({
    required this.appearance,
    required this.membership,
    required this.account,
    required this.calendar,
    this.locationPermission = DeviceLocationPermissionState.unknown,
    this.microphonePermission = SpeechAuthorizationState.unknown,
    this.photoLibraryPermission = PhotoLibraryPermissionState.unknown,
    this.about = const LingSettingsAboutData(),
    required this.strings,
  });

  final LingSettingsAppearanceData appearance;
  final LingSettingsMembershipData membership;
  final LingSettingsAccountData account;
  final LingSettingsCalendarData calendar;
  final DeviceLocationPermissionState locationPermission;
  final SpeechAuthorizationState microphonePermission;
  final PhotoLibraryPermissionState photoLibraryPermission;
  final LingSettingsAboutData about;
  final LingStrings strings;

  ThemeMode get themeMode => appearance.themeMode;
  String get localeCode => appearance.localeCode;
  String get timezone => appearance.timezone;
  LingFontSizeLevel get fontSizeLevel => appearance.fontSizeLevel;
  String get preferredInputMode => appearance.preferredInputMode;
  int? get localImageCacheBytes => appearance.localImageCacheBytes;
  bool get isClearingLocalImageCache => appearance.isClearingLocalImageCache;
  MembershipSummary? get membershipSummary => membership.summary;
  UserProfile? get profile => account.profile;
  List<UserIdentity> get identities => account.identities;
  AppleCalendarPermissionState get appleCalendarPermission =>
      calendar.appleCalendarPermission;
  List<CalendarConnectionSummary> get calendarConnections =>
      calendar.connections;
  CalendarSyncSettings get calendarSyncSettings => calendar.syncSettings;
  CalendarNotificationPermissionState get calendarNotificationPermission =>
      calendar.notificationPermission;
  CalendarNotificationSettings get calendarNotificationSettings =>
      calendar.notificationSettings;
  SettingsBindingState get phoneBindingState => account.phoneBindingState;
  SettingsBindingState get emailBindingState => account.emailBindingState;
  PhoneCountry get initialPhoneCountry => account.initialPhoneCountry;
}

class LingSettingsShellCallbacks {
  const LingSettingsShellCallbacks({
    required this.onClose,
    this.onPageChanged,
    this.onRootBackSwipeCompleted,
    this.onRootBackSwipeDirectionCompleted,
    this.underlayChild,
  });

  final VoidCallback onClose;
  final ValueChanged<String>? onPageChanged;
  final VoidCallback? onRootBackSwipeCompleted;
  final ValueChanged<LingEdgeSwipeDirection>? onRootBackSwipeDirectionCompleted;
  final Widget? underlayChild;
}

class LingSettingsPreferenceCallbacks {
  const LingSettingsPreferenceCallbacks({
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required this.onPreferredInputModeChanged,
    this.onFontSizeLevelChanged,
    this.onClearLocalImageCache,
  });

  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<String> onPreferredInputModeChanged;
  final ValueChanged<LingFontSizeLevel>? onFontSizeLevelChanged;
  final Future<void> Function()? onClearLocalImageCache;
}

class LingSettingsAccountCallbacks {
  const LingSettingsAccountCallbacks({
    required this.onSignOut,
    required this.onDeleteAccount,
    required this.onSendPhoneBindingCode,
    required this.onSendEmailBindingCode,
    required this.onBindPhone,
    required this.onBindEmail,
    required this.onBindApple,
    required this.onBindWeChat,
    required this.onBindingCompleted,
  });

  final Future<void> Function() onSignOut;
  final Future<void> Function() onDeleteAccount;
  final Future<void> Function(String phone) onSendPhoneBindingCode;
  final Future<void> Function(String email) onSendEmailBindingCode;
  final Future<AccountBundle> Function({
    required String phone,
    required String challengeId,
    required String code,
  })
  onBindPhone;
  final Future<AccountBundle> Function({
    required String email,
    required String code,
  })
  onBindEmail;
  final Future<AccountBundle> Function() onBindApple;
  final Future<AccountBundle> Function() onBindWeChat;
  final Future<void> Function(AccountBindingTarget target, AccountBundle result)
  onBindingCompleted;
}

class LingSettingsCalendarCallbacks {
  const LingSettingsCalendarCallbacks({
    required this.onOpenCalendarProviderApp,
    required this.onAuthorizeCalendarProvider,
    required this.onRefreshCalendarProvider,
    required this.onDisconnectCalendarProvider,
    required this.onOpenAppleCalendarSystemSettings,
    required this.onOpenCalendarNotificationSystemSettings,
    required this.onCalendarSyncSettingsChanged,
    required this.onCalendarNotificationSettingsChanged,
    required this.formatCalendarNotificationPermissionLabel,
    required this.formatCalendarNotificationModeLabel,
    required this.formatCalendarNotificationSummary,
  });

  final Future<void> Function(CalendarProviderId provider)
  onOpenCalendarProviderApp;
  final Future<void> Function(CalendarProviderId provider)
  onAuthorizeCalendarProvider;
  final Future<void> Function(CalendarProviderId provider)
  onRefreshCalendarProvider;
  final Future<void> Function(CalendarProviderId provider)
  onDisconnectCalendarProvider;
  final Future<void> Function() onOpenAppleCalendarSystemSettings;
  final Future<void> Function() onOpenCalendarNotificationSystemSettings;
  final ValueChanged<CalendarSyncSettings> onCalendarSyncSettingsChanged;
  final ValueChanged<CalendarNotificationSettings>
  onCalendarNotificationSettingsChanged;
  final String Function(CalendarNotificationPermissionState permission)
  formatCalendarNotificationPermissionLabel;
  final String Function(CalendarNotificationDeliveryMode mode)
  formatCalendarNotificationModeLabel;
  final String Function(CalendarNotificationSettings settings)
  formatCalendarNotificationSummary;
}

class LingSettingsPermissionCallbacks {
  const LingSettingsPermissionCallbacks({
    required this.onRequestNotificationPermission,
    required this.onRequestLocationPermission,
    required this.onRequestMicrophonePermission,
    required this.onRequestPhotoLibraryPermission,
    required this.onOpenNotificationSystemSettings,
    required this.onOpenLocationSystemSettings,
  });

  final Future<void> Function() onRequestNotificationPermission;
  final Future<DeviceContextSnapshot?> Function() onRequestLocationPermission;
  final Future<void> Function() onRequestMicrophonePermission;
  final Future<void> Function() onRequestPhotoLibraryPermission;
  final Future<void> Function() onOpenNotificationSystemSettings;
  final Future<void> Function() onOpenLocationSystemSettings;
}

class LingSettingsMembershipCallbacks {
  const LingSettingsMembershipCallbacks({this.onOpenMembershipPlans});

  final void Function(BuildContext context)? onOpenMembershipPlans;
}

class LingSettingsPageCallbacks {
  const LingSettingsPageCallbacks({
    required this.shell,
    required this.preferences,
    required this.account,
    required this.calendar,
    required this.permissions,
    this.membership = const LingSettingsMembershipCallbacks(),
  });

  final LingSettingsShellCallbacks shell;
  final LingSettingsPreferenceCallbacks preferences;
  final LingSettingsAccountCallbacks account;
  final LingSettingsCalendarCallbacks calendar;
  final LingSettingsPermissionCallbacks permissions;
  final LingSettingsMembershipCallbacks membership;

  VoidCallback get onClose => shell.onClose;
  Future<void> Function() get onSignOut => account.onSignOut;
  Future<void> Function() get onDeleteAccount => account.onDeleteAccount;
  ValueChanged<ThemeMode> get onThemeModeChanged =>
      preferences.onThemeModeChanged;
  ValueChanged<String> get onLocaleChanged => preferences.onLocaleChanged;
  ValueChanged<String> get onPreferredInputModeChanged =>
      preferences.onPreferredInputModeChanged;
  ValueChanged<LingFontSizeLevel>? get onFontSizeLevelChanged =>
      preferences.onFontSizeLevelChanged;
  Future<void> Function()? get onClearLocalImageCache =>
      preferences.onClearLocalImageCache;
  Future<void> Function(CalendarProviderId provider)
  get onOpenCalendarProviderApp => calendar.onOpenCalendarProviderApp;
  Future<void> Function(CalendarProviderId provider)
  get onAuthorizeCalendarProvider => calendar.onAuthorizeCalendarProvider;
  Future<void> Function(CalendarProviderId provider)
  get onRefreshCalendarProvider => calendar.onRefreshCalendarProvider;
  Future<void> Function(CalendarProviderId provider)
  get onDisconnectCalendarProvider => calendar.onDisconnectCalendarProvider;
  Future<void> Function() get onOpenAppleCalendarSystemSettings =>
      calendar.onOpenAppleCalendarSystemSettings;
  Future<void> Function() get onOpenCalendarNotificationSystemSettings =>
      calendar.onOpenCalendarNotificationSystemSettings;
  Future<void> Function() get onRequestNotificationPermission =>
      permissions.onRequestNotificationPermission;
  Future<DeviceContextSnapshot?> Function() get onRequestLocationPermission =>
      permissions.onRequestLocationPermission;
  Future<void> Function() get onRequestMicrophonePermission =>
      permissions.onRequestMicrophonePermission;
  Future<void> Function() get onRequestPhotoLibraryPermission =>
      permissions.onRequestPhotoLibraryPermission;
  Future<void> Function() get onOpenLocationSystemSettings =>
      permissions.onOpenLocationSystemSettings;
  ValueChanged<CalendarNotificationSettings>
  get onCalendarNotificationSettingsChanged =>
      calendar.onCalendarNotificationSettingsChanged;
  ValueChanged<CalendarSyncSettings> get onCalendarSyncSettingsChanged =>
      calendar.onCalendarSyncSettingsChanged;
  Future<void> Function(String phone) get onSendPhoneBindingCode =>
      account.onSendPhoneBindingCode;
  Future<void> Function(String email) get onSendEmailBindingCode =>
      account.onSendEmailBindingCode;
  Future<AccountBundle> Function({
    required String phone,
    required String challengeId,
    required String code,
  })
  get onBindPhone => account.onBindPhone;
  Future<AccountBundle> Function({required String email, required String code})
  get onBindEmail => account.onBindEmail;
  Future<AccountBundle> Function() get onBindApple => account.onBindApple;
  Future<AccountBundle> Function() get onBindWeChat => account.onBindWeChat;
  Future<void> Function(AccountBindingTarget target, AccountBundle result)
  get onBindingCompleted => account.onBindingCompleted;
  void Function(BuildContext context)? get onOpenMembershipPlans =>
      membership.onOpenMembershipPlans;
  String Function(CalendarNotificationPermissionState permission)
  get formatCalendarNotificationPermissionLabel =>
      calendar.formatCalendarNotificationPermissionLabel;
  String Function(CalendarNotificationDeliveryMode mode)
  get formatCalendarNotificationModeLabel =>
      calendar.formatCalendarNotificationModeLabel;
  String Function(CalendarNotificationSettings settings)
  get formatCalendarNotificationSummary =>
      calendar.formatCalendarNotificationSummary;
  VoidCallback? get onRootBackSwipeCompleted => shell.onRootBackSwipeCompleted;
  ValueChanged<String>? get onPageChanged => shell.onPageChanged;
  ValueChanged<LingEdgeSwipeDirection>? get onRootBackSwipeDirectionCompleted =>
      shell.onRootBackSwipeDirectionCompleted;
  Widget? get underlayChild => shell.underlayChild;
}
