import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/platform/models/notification_models.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/calendar/models/apple_calendar_models.dart';
import 'package:ling/src/features/chat/data/apple_speech_recognition_bridge.dart';
import 'package:ling/src/features/settings/application/settings_state.dart';
import 'package:ling/src/features/settings/data/bridges/photo_library_permission_bridge.dart';
import 'package:ling/src/features/settings/presentation/settings_page.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';
import 'package:ling/src/shared/models/font_size_preference.dart';
import 'package:ling/src/shared/models/phone_country.dart';

void main() {
  final strings = LingStrings('zh-CN');

  testWidgets('opens account security without layout exceptions', (
    tester,
  ) async {
    await _pumpSettingsPage(tester, strings);

    await tester.tap(find.text(strings.accountSecuritySectionTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
    expect(find.text(strings.signInMethodsTitle), findsOneWidget);
  });

  testWidgets('opens general settings without layout exceptions', (
    tester,
  ) async {
    await _pumpSettingsPage(tester, strings);

    await tester.tap(find.text(strings.generalSectionTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
    expect(find.text(strings.appearance), findsOneWidget);
  });
}

Future<void> _pumpSettingsPage(WidgetTester tester, LingStrings strings) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: LingSettingsPage(data: _settingsData(strings), actions: _actions),
      ),
    ),
  );
}

LingSettingsPageViewModel _settingsData(LingStrings strings) {
  return LingSettingsPageViewModel(
    strings: strings,
    appearance: const LingSettingsAppearanceData(
      themeMode: ThemeMode.system,
      localeCode: 'zh-CN',
      timezone: 'Asia/Shanghai',
      fontSizeLevel: LingFontSizeLevel.medium,
    ),
    membership: const LingSettingsMembershipData(summary: null),
    account: const LingSettingsAccountData(
      profile: UserProfile(userId: 'test-user', email: 'test@example.com'),
      identities: [],
      phoneBindingState: SettingsBindingState(),
      emailBindingState: SettingsBindingState(),
      initialPhoneCountry: PhoneCountry(
        code: 'CN',
        dialCode: '+86',
        label: 'CN +86',
        name: '中国大陆',
      ),
    ),
    calendar: const LingSettingsCalendarData(
      appleCalendarPermission: AppleCalendarPermissionState.notDetermined,
      connections: [],
      syncSettings: CalendarSyncSettings(),
      notificationPermission: CalendarNotificationPermissionState.notDetermined,
      notificationSettings: CalendarNotificationSettings(),
    ),
    locationPermission: DeviceLocationPermissionState.notDetermined,
    microphonePermission: SpeechAuthorizationState.notDetermined,
    photoLibraryPermission: PhotoLibraryPermissionState.notDetermined,
  );
}

final LingSettingsPageCallbacks _actions = LingSettingsPageCallbacks(
  shell: LingSettingsShellCallbacks(onClose: () {}),
  preferences: LingSettingsPreferenceCallbacks(
    onThemeModeChanged: (_) {},
    onLocaleChanged: (_) {},
    onPreferredInputModeChanged: (_) {},
  ),
  account: LingSettingsAccountCallbacks(
    onSignOut: () async {},
    onDeleteAccount: () async {},
    onSendPhoneBindingCode: (_) async {},
    onSendEmailBindingCode: (_) async {},
    onBindPhone:
        ({
          required String phone,
          required String challengeId,
          required String code,
        }) async {
          return _accountBundle;
        },
    onBindEmail: ({required String email, required String code}) async {
      return _accountBundle;
    },
    onBindApple: () async => _accountBundle,
    onBindWeChat: () async => _accountBundle,
    onBindingCompleted: (_, _) async {},
  ),
  calendar: LingSettingsCalendarCallbacks(
    onOpenCalendarProviderApp: (_) async {},
    onAuthorizeCalendarProvider: (_) async {},
    onRefreshCalendarProvider: (_) async {},
    onDisconnectCalendarProvider: (_) async {},
    onOpenAppleCalendarSystemSettings: () async {},
    onOpenCalendarNotificationSystemSettings: () async {},
    onCalendarSyncSettingsChanged: (_) {},
    onCalendarNotificationSettingsChanged: (_) {},
    formatCalendarNotificationPermissionLabel: (_) => '',
    formatCalendarNotificationModeLabel: (_) => '',
    formatCalendarNotificationSummary: (_) => '',
  ),
  permissions: LingSettingsPermissionCallbacks(
    onRequestNotificationPermission: () async {},
    onRequestLocationPermission: () async => null,
    onRequestMicrophonePermission: () async {},
    onRequestPhotoLibraryPermission: () async {},
    onOpenNotificationSystemSettings: () async {},
    onOpenLocationSystemSettings: () async {},
  ),
);

const AccountBundle _accountBundle = AccountBundle(
  profile: UserProfile(userId: 'test-user', email: 'test@example.com'),
  identities: [],
);
