import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/features/calendar/data/bridges/apple_calendar_bridge.dart';
import 'package:ling/src/features/calendar/models/calendar_integration_models.dart';
import 'package:ling/src/features/settings/presentation/settings_page.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';

void main() {
  final strings = LingStrings('en-US');

  test('only Apple calendar is visible in settings provider list', () {
    expect(visibleSettingsCalendarProviders, const <CalendarProviderId>[
      CalendarProviderId.appleLocal,
    ]);
  });

  test('maps Apple local authorization from system calendar permission', () {
    expect(
      settingsCalendarAuthorizationStatusLabel(
        strings: strings,
        provider: CalendarProviderId.appleLocal,
        appleCalendarPermission: AppleCalendarPermissionState.granted,
        calendarConnections: const [],
      ),
      strings.calendarAccessAuthorized,
    );
    expect(
      settingsCalendarAuthorizationStatusLabel(
        strings: strings,
        provider: CalendarProviderId.appleLocal,
        appleCalendarPermission: AppleCalendarPermissionState.denied,
        calendarConnections: const [],
      ),
      strings.calendarAccessUnauthorized,
    );
  });

  test('maps authorization status from connection state', () {
    final connections = <CalendarConnectionSummary>[
      const CalendarConnectionSummary(
        providerId: CalendarProviderId.feishu,
        providerName: 'Feishu',
        kind: 'oauth',
        status: 'connected',
        isEnabled: true,
        isConnected: true,
        eventCount: 4,
      ),
    ];

    expect(
      settingsCalendarAuthorizationStatusLabel(
        strings: strings,
        provider: CalendarProviderId.feishu,
        appleCalendarPermission: AppleCalendarPermissionState.denied,
        calendarConnections: connections,
      ),
      strings.notificationPermissionGranted,
    );
    expect(
      settingsCalendarAuthorizationStatusLabel(
        strings: strings,
        provider: CalendarProviderId.dingtalk,
        appleCalendarPermission: AppleCalendarPermissionState.denied,
        calendarConnections: connections,
      ),
      strings.notificationPermissionUnauthorized,
    );
  });

  test('shows provider menu for actionable remote states only', () {
    expect(
      shouldShowSettingsCalendarProviderMenu(
        const CalendarConnectionSummary(
          providerId: CalendarProviderId.feishu,
          providerName: 'Feishu',
          kind: 'oauth',
          status: 'action_required',
          isEnabled: true,
          isConnected: true,
          eventCount: 0,
        ),
      ),
      isTrue,
    );
    expect(
      shouldShowSettingsCalendarProviderMenu(
        const CalendarConnectionSummary(
          providerId: CalendarProviderId.appleLocal,
          providerName: 'Apple',
          kind: 'system',
          status: 'connected',
          isEnabled: true,
          isConnected: true,
          eventCount: 0,
        ),
      ),
      isFalse,
    );
  });
}
