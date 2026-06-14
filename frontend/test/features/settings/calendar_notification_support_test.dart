import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/config/constants.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/core/platform/models/notification_models.dart';
import 'package:ling/src/features/calendar/application/calendar_notification_support.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/settings/application/services/settings_device_sync_support.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';

void main() {
  test('prefers device context timezone for push registration', () {
    final timezone = resolvePushRegistrationTimezone(
      fallbackTimezone: 'UTC',
      deviceContext: DeviceContextSnapshot(
        timezone: AppConstants.defaultTimezone,
      ),
    );

    expect(timezone, AppConstants.defaultTimezone);
  });

  test(
    'falls back to settings timezone when device context timezone is blank',
    () {
      final timezone = resolvePushRegistrationTimezone(
        fallbackTimezone: 'UTC',
        deviceContext: const DeviceContextSnapshot(timezone: '   '),
      );

      expect(timezone, 'UTC');
    },
  );

  test('builds push device registration request from notification sources', () {
    final request = buildPushDeviceRegistrationRequest(
      deviceId: 'device-1',
      locale: 'zh-CN',
      fallbackTimezone: 'UTC',
      registration: const RemoteNotificationRegistration(
        pushToken: ' token-1 ',
        appBundleId: ' com.ling.app ',
        apnsEnvironment: ' development ',
      ),
      platform: AppPlatform.ios,
      deviceContext: DeviceContextSnapshot(
        timezone: AppConstants.defaultTimezone,
        deviceModel: 'iPhone16,2',
        formattedAddress: '1 Market St, Shanghai, China',
        name: 'Market',
        thoroughfare: 'Market St',
        subThoroughfare: '1',
        subLocality: 'Huangpu',
        locality: 'Shanghai',
        subAdministrativeArea: 'Shanghai',
        city: 'Shanghai',
        administrativeArea: 'Shanghai',
        postalCode: '200000',
        country: 'CN',
        isoCountryCode: 'CN',
        areasOfInterest: <String>['Bund'],
        latitude: 31.2,
        longitude: 121.5,
        accuracyMeters: 42,
        capturedAt: DateTime.utc(2026, 5, 30, 10),
      ),
    );

    expect(request.deviceId, 'device-1');
    expect(request.platform, 'ios');
    expect(request.transport, 'apns');
    expect(request.pushToken, 'token-1');
    expect(request.appBundleId, 'com.ling.app');
    expect(request.apnsEnvironment, 'development');
    expect(request.locale, 'zh-CN');
    expect(request.timezone, AppConstants.defaultTimezone);
    expect(request.deviceModel, 'iPhone16,2');
    expect(request.formattedAddress, '1 Market St, Shanghai, China');
    expect(request.name, 'Market');
    expect(request.thoroughfare, 'Market St');
    expect(request.subThoroughfare, '1');
    expect(request.subLocality, 'Huangpu');
    expect(request.locality, 'Shanghai');
    expect(request.subAdministrativeArea, 'Shanghai');
    expect(request.city, 'Shanghai');
    expect(request.administrativeArea, 'Shanghai');
    expect(request.postalCode, '200000');
    expect(request.country, 'CN');
    expect(request.isoCountryCode, 'CN');
    expect(request.areasOfInterest, <String>['Bund']);
    expect(request.latitude, 31.2);
    expect(request.longitude, 121.5);
    expect(request.accuracyMeters, 42);
    expect(request.capturedAt, DateTime.utc(2026, 5, 30, 10));
    expect(request.notificationsEnabled, isTrue);
  });

  test('builds HarmonyOS push device registration request', () {
    final request = buildPushDeviceRegistrationRequest(
      deviceId: 'device-1',
      locale: 'zh-CN',
      fallbackTimezone: 'UTC',
      registration: const RemoteNotificationRegistration(pushToken: 'token-1'),
      platform: AppPlatform.ohos,
    );

    expect(request.platform, 'ohos');
    expect(request.transport, 'harmony_push');
  });

  test('can omit location fields from push device registration request', () {
    final request = buildPushDeviceRegistrationRequest(
      deviceId: 'device-1',
      locale: 'zh-CN',
      fallbackTimezone: 'UTC',
      registration: const RemoteNotificationRegistration(pushToken: 'token-1'),
      deviceContext: DeviceContextSnapshot(
        timezone: AppConstants.defaultTimezone,
        deviceModel: 'iPhone16,2',
        formattedAddress: '1 Market St, Shanghai, China',
        name: 'Market',
        thoroughfare: 'Market St',
        subThoroughfare: '1',
        subLocality: 'Huangpu',
        locality: 'Shanghai',
        subAdministrativeArea: 'Shanghai',
        city: 'Shanghai',
        administrativeArea: 'Shanghai',
        postalCode: '200000',
        country: 'CN',
        isoCountryCode: 'CN',
        areasOfInterest: <String>['Bund'],
        latitude: 31.2,
        longitude: 121.5,
        accuracyMeters: 42,
        capturedAt: DateTime.utc(2026, 5, 30, 10),
      ),
      includeLocationData: false,
      platform: AppPlatform.ios,
    );

    expect(request.timezone, AppConstants.defaultTimezone);
    expect(request.deviceModel, 'iPhone16,2');
    expect(request.formattedAddress, isNull);
    expect(request.name, isNull);
    expect(request.thoroughfare, isNull);
    expect(request.subThoroughfare, isNull);
    expect(request.subLocality, isNull);
    expect(request.locality, isNull);
    expect(request.subAdministrativeArea, isNull);
    expect(request.city, isNull);
    expect(request.administrativeArea, isNull);
    expect(request.postalCode, isNull);
    expect(request.country, isNull);
    expect(request.isoCountryCode, isNull);
    expect(request.areasOfInterest, isNull);
    expect(request.latitude, isNull);
    expect(request.longitude, isNull);
    expect(request.accuracyMeters, isNull);
    expect(request.capturedAt, isNull);
  });

  test(
    'buildAppleCalendarAlarmPayload only includes alarms for Apple delivery',
    () {
      expect(
        buildAppleCalendarAlarmPayload(
          const CalendarNotificationSettings(
            deliveryChannel: CalendarNotificationDeliveryChannel.lingLocal,
          ),
        ),
        isEmpty,
      );

      expect(
        buildAppleCalendarAlarmPayload(
          const CalendarNotificationSettings(
            deliveryChannel:
                CalendarNotificationDeliveryChannel.appleCalendarWhenSynced,
            minutesBefore: 30,
            notifyAtStart: true,
          ),
          event: _buildLingEvent(
            eventId: 'local',
            startAt: DateTime.now().add(const Duration(days: 2)),
          ),
        ),
        const <Map<String, dynamic>>[
          {'relativeOffsetSeconds': -1800},
          {'relativeOffsetSeconds': 0},
        ],
      );
    },
  );

  test('buildAppleCalendarAlarmPayload omits alarms for synced events', () {
    final startAt = DateTime.now().add(const Duration(days: 2));
    const settings = CalendarNotificationSettings(
      deliveryChannel:
          CalendarNotificationDeliveryChannel.appleCalendarWhenSynced,
      minutesBefore: 30,
      notifyAtStart: true,
    );

    expect(
      buildAppleCalendarAlarmPayload(
        settings,
        event: _buildLingEvent(
          eventId: 'apple-imported',
          startAt: startAt,
          source: 'apple',
        ),
      ),
      isEmpty,
    );
    expect(
      buildAppleCalendarAlarmPayload(
        settings,
        event: _buildLingEvent(eventId: 'mirroring', startAt: startAt),
        syncingToAppleCalendar: true,
      ),
      isEmpty,
    );
  });

  test('buildCalendarNotificationRequests skips imported synced events', () {
    final startAt = DateTime.now().add(const Duration(days: 2));
    final notifications = buildCalendarNotificationRequests(
      events: <LingEvent>[
        _buildLingEvent(eventId: 'apple', startAt: startAt, source: 'apple'),
        _buildLingEvent(eventId: 'feishu', startAt: startAt, source: 'feishu'),
        _buildLingEvent(eventId: 'local', startAt: startAt),
      ],
      strings: const LingStrings('zh-CN'),
      settings: const CalendarNotificationSettings(notifyAtStart: false),
    );

    expect(notifications, hasLength(1));
    expect(notifications.single.identifier, 'ling.calendar.local.before.15');
  });

  test('buildCalendarNotificationRequests skips point events', () {
    final startAt = DateTime.now().add(const Duration(days: 2));
    final notifications = buildCalendarNotificationRequests(
      events: <LingEvent>[
        _buildLingEvent(eventId: 'point', startAt: startAt, timeShape: 'point'),
      ],
      strings: const LingStrings('zh-CN'),
      settings: const CalendarNotificationSettings(),
    );

    expect(notifications, isEmpty);
  });

  test(
    'buildCalendarNotificationRequests skips linked Apple events in Apple mode',
    () {
      final startAt = DateTime.now().add(const Duration(days: 2));
      final notifications = buildCalendarNotificationRequests(
        events: <LingEvent>[
          _buildLingEvent(
            eventId: 'linked',
            startAt: startAt,
            appleLink: const AppleEventLink(eventIdentifier: 'apple-1'),
          ),
          _buildLingEvent(eventId: 'local', startAt: startAt),
        ],
        strings: const LingStrings('zh-CN'),
        settings: const CalendarNotificationSettings(
          deliveryChannel:
              CalendarNotificationDeliveryChannel.appleCalendarWhenSynced,
          notifyAtStart: false,
        ),
      );

      expect(notifications, hasLength(1));
      expect(notifications.single.identifier, 'ling.calendar.local.before.15');
    },
  );

  test(
    'forceLocalEventIds keeps linked Apple events on Ling notifications',
    () {
      final startAt = DateTime.now().add(const Duration(days: 2));
      final notifications = buildCalendarNotificationRequests(
        events: <LingEvent>[
          _buildLingEvent(
            eventId: 'linked',
            startAt: startAt,
            appleLink: const AppleEventLink(eventIdentifier: 'apple-1'),
          ),
        ],
        strings: const LingStrings('zh-CN'),
        settings: const CalendarNotificationSettings(
          deliveryChannel:
              CalendarNotificationDeliveryChannel.appleCalendarWhenSynced,
          notifyAtStart: false,
        ),
        forceLocalEventIds: const <String>{'linked'},
      );

      expect(notifications, hasLength(1));
      expect(notifications.single.identifier, 'ling.calendar.linked.before.15');
    },
  );
}

LingEvent _buildLingEvent({
  required String eventId,
  required DateTime startAt,
  AppleEventLink? appleLink,
  String source = 'ling',
  String timeShape = 'span',
}) {
  return LingEvent(
    eventId: eventId,
    userId: 'user-1',
    title: 'Morning Run',
    startAt: startAt,
    endAt: timeShape == 'point'
        ? startAt
        : startAt.add(const Duration(minutes: 30)),
    timezone: AppConstants.defaultTimezone,
    appleLink: appleLink,
    source: source,
    timeShape: timeShape,
  );
}
