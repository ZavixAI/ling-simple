import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/shared/i18n/calendar_notification_formatters.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';

void main() {
  const strings = LingStrings('zh-CN');

  test('formats calendar notification permission labels', () {
    expect(
      formatCalendarNotificationPermissionLabel(
        strings,
        CalendarNotificationPermissionState.granted,
      ),
      isNotEmpty,
    );
    expect(
      formatCalendarNotificationPermissionLabel(
        strings,
        CalendarNotificationPermissionState.denied,
      ),
      isNotEmpty,
    );
  });

  test('formats calendar notification mode labels', () {
    expect(
      formatCalendarNotificationModeLabel(
        strings,
        CalendarNotificationDeliveryMode.bannerSound,
      ),
      isNotEmpty,
    );
    expect(
      formatCalendarNotificationModeLabel(
        strings,
        CalendarNotificationDeliveryMode.silent,
      ),
      isNotEmpty,
    );
  });

  test('formats calendar notification summary', () {
    final summary = formatCalendarNotificationSummary(
      strings,
      const CalendarNotificationSettings(minutesBefore: 30),
    );

    expect(summary, contains('30'));
  });

  test(
    'calendar notification summary ignores removed Apple delivery channel',
    () {
      final summary = formatCalendarNotificationSummary(
        strings,
        const CalendarNotificationSettings(
          deliveryChannel:
              CalendarNotificationDeliveryChannel.appleCalendarWhenSynced,
          minutesBefore: 30,
        ),
      );

      expect(
        summary,
        isNot(contains(strings.calendarNotificationChannelAppleCalendar)),
      );
      expect(summary, contains(strings.calendarNotificationModeBannerSound));
    },
  );

  test('legacy Apple delivery channel is normalized to Ling local', () {
    final settings = CalendarNotificationSettings.fromJson(const {
      'delivery_channel': 'apple_calendar_if_synced',
      'delivery_mode': 'banner_only',
      'minutes_before': 30,
    });

    expect(
      settings.deliveryChannel,
      CalendarNotificationDeliveryChannel.lingLocal,
    );
    expect(settings.deliveryMode, CalendarNotificationDeliveryMode.bannerOnly);
  });
}
