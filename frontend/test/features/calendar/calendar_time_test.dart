import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/config/constants.dart';
import 'package:ling/src/features/calendar/models/calendar_time.dart';

void main() {
  test(
    'formatLingDateTimeWithTimezone encodes the requested timezone offset',
    () {
      final formatted = formatLingDateTimeWithTimezone(
        DateTime(2026, 4, 5),
        AppConstants.defaultTimezone,
      );

      expect(formatted, '2026-04-05T00:00:00+08:00');
    },
  );

  test(
    'currentLingDateTime converts an instant into the requested timezone',
    () {
      final converted = currentLingDateTime(
        AppConstants.defaultTimezone,
        now: DateTime.parse('2026-04-04T16:30:00Z'),
      );

      expect(converted, DateTime(2026, 4, 5, 0, 30));
    },
  );

  test(
    'convertLingDateTimeToTimezone rehydrates Apple UTC timestamps into the requested timezone',
    () {
      final converted = convertLingDateTimeToTimezone(
        DateTime.parse('2026-04-04T16:30:00Z'),
        AppConstants.defaultTimezone,
      );

      expect(converted, DateTime(2026, 4, 5, 0, 30));
    },
  );
}
