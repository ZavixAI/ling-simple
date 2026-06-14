import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

bool isSameCalendarDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

DateTime parseLingDateOnly(String value) {
  final parts = value.split('-');
  if (parts.length != 3) {
    return DateTime.parse(value);
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return DateTime.parse(value);
  }
  return DateTime(year, month, day);
}

String formatLingDateYmd(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String formatLingHourMinute(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

bool _didInitializeLingTimeZones = false;

void _ensureLingTimeZonesInitialized() {
  if (_didInitializeLingTimeZones) {
    return;
  }
  tz_data.initializeTimeZones();
  _didInitializeLingTimeZones = true;
}

tz.Location _resolveLingLocation(String timezone) {
  _ensureLingTimeZonesInitialized();
  final normalized = timezone.trim();
  if (normalized.isEmpty) {
    return tz.UTC;
  }
  try {
    return tz.getLocation(normalized);
  } catch (_) {
    return tz.UTC;
  }
}

DateTime currentLingDateTime(String timezone, {DateTime? now}) {
  final location = _resolveLingLocation(timezone);
  final zoned = tz.TZDateTime.from(now ?? DateTime.now(), location);
  return DateTime(
    zoned.year,
    zoned.month,
    zoned.day,
    zoned.hour,
    zoned.minute,
    zoned.second,
    zoned.millisecond,
    zoned.microsecond,
  );
}

DateTime convertLingDateTimeToTimezone(DateTime value, String timezone) {
  final location = _resolveLingLocation(timezone);
  final zoned = tz.TZDateTime.from(value, location);
  return DateTime(
    zoned.year,
    zoned.month,
    zoned.day,
    zoned.hour,
    zoned.minute,
    zoned.second,
    zoned.millisecond,
    zoned.microsecond,
  );
}

DateTime convertLingWallTimeBetweenTimezones(
  DateTime value, {
  required String fromTimezone,
  required String toTimezone,
}) {
  final sourceLocation = _resolveLingLocation(fromTimezone);
  final targetLocation = _resolveLingLocation(toTimezone);
  final source = tz.TZDateTime(
    sourceLocation,
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
  final target = tz.TZDateTime.from(source, targetLocation);
  return DateTime(
    target.year,
    target.month,
    target.day,
    target.hour,
    target.minute,
    target.second,
    target.millisecond,
    target.microsecond,
  );
}

String formatLingDateTimeWithTimezone(DateTime value, String timezone) {
  final location = _resolveLingLocation(timezone);
  final zoned = tz.TZDateTime(
    location,
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
  final date = formatLingDateYmd(zoned);
  final hour = zoned.hour.toString().padLeft(2, '0');
  final minute = zoned.minute.toString().padLeft(2, '0');
  final second = zoned.second.toString().padLeft(2, '0');
  final offset = _formatLingTimezoneOffset(zoned.timeZoneOffset);
  return '${date}T$hour:$minute:$second$offset';
}

DateTime normalizeLingDateTimeToMinute(DateTime value) {
  return DateTime(value.year, value.month, value.day, value.hour, value.minute);
}

final RegExp _lingCalendarWindowBoundaryPattern = RegExp(
  r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2})(?::\d{2}(?:\.\d{1,6})?)?([zZ]|[+-]\d{2}:\d{2})?$',
);

String normalizeCalendarWindowBoundaryToMinute(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return normalized;
  }
  final match = _lingCalendarWindowBoundaryPattern.firstMatch(normalized);
  if (match == null) {
    return normalized;
  }
  final prefix = match.group(1)!;
  final suffix = match.group(2) ?? '';
  return '$prefix:00$suffix';
}

String _formatLingTimezoneOffset(Duration offset) {
  final totalMinutes = offset.inMinutes;
  final sign = totalMinutes < 0 ? '-' : '+';
  final absoluteMinutes = totalMinutes.abs();
  final hours = (absoluteMinutes ~/ 60).toString().padLeft(2, '0');
  final minutes = (absoluteMinutes % 60).toString().padLeft(2, '0');
  return '$sign$hours:$minutes';
}

String formatLingDateTimeNaive(DateTime value) {
  final date = formatLingDateYmd(value);
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${date}T$hour:$minute:00';
}
