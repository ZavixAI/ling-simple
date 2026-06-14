import 'package:flutter/material.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_time.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';

Color lingAccentForCategory(
  String category, {
  Brightness brightness = Brightness.light,
}) {
  final palette = _calendarSemanticPaletteFor(brightness);
  switch (category) {
    case 'focus':
      return palette.focus;
    case 'wellness':
      return palette.wellness;
    case 'meeting':
      return palette.meeting;
    default:
      return palette.general;
  }
}

Color lingAppleAccent({
  required bool isHoliday,
  Brightness brightness = Brightness.light,
}) {
  final palette = _calendarSemanticPaletteFor(brightness);
  return isHoliday ? palette.appleHoliday : palette.appleEvent;
}

class _CalendarSemanticPalette {
  const _CalendarSemanticPalette({
    required this.focus,
    required this.wellness,
    required this.meeting,
    required this.general,
    required this.appleHoliday,
    required this.appleEvent,
  });

  final Color focus;
  final Color wellness;
  final Color meeting;
  final Color general;
  final Color appleHoliday;
  final Color appleEvent;
}

const _lightCalendarSemanticPalette = _CalendarSemanticPalette(
  focus: Color(0xFF3B82F6),
  wellness: Color(0xFF14B8A6),
  meeting: Color(0xFF7C3AED),
  general: Color(0xFF64748B),
  appleHoliday: Color(0xFFD97706),
  appleEvent: Color(0xFF0F766E),
);

const _darkCalendarSemanticPalette = _CalendarSemanticPalette(
  focus: Color(0xFF7DD3FC),
  wellness: Color(0xFF5EEAD4),
  meeting: Color(0xFFC4B5FD),
  general: Color(0xFF94A3B8),
  appleHoliday: Color(0xFFFBBF24),
  appleEvent: Color(0xFF67E8F9),
);

_CalendarSemanticPalette _calendarSemanticPaletteFor(Brightness brightness) {
  return brightness == Brightness.dark
      ? _darkCalendarSemanticPalette
      : _lightCalendarSemanticPalette;
}

String formatLingMonthTitle(LingStrings strings, DateTime date) {
  return strings.monthTitle(date.year, date.month);
}

String formatLingAgendaDurationLabel(LingStrings strings, Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (strings.isZh) {
    if (hours > 0 && minutes > 0) {
      return '$hours小时$minutes分钟';
    }
    if (hours > 0) {
      return '$hours小时';
    }
    return '$totalMinutes分钟';
  }
  if (hours > 0 && minutes > 0) {
    return '${hours}h ${minutes}m';
  }
  if (hours > 0) {
    return '${hours}h';
  }
  return '${totalMinutes}m';
}

String formatLingSelectedAgendaTitle(LingStrings strings, String selectedDate) {
  final selected = parseLingDateOnly(selectedDate);
  if (strings.isZh) {
    return '${selected.month}月${selected.day}日日程';
  }
  return 'Schedule for ${_englishMonthShort(selected.month)} ${selected.day}';
}

String formatLingSevenDayWindowTitle(LingStrings strings, DateTime startDate) {
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final end = start.add(const Duration(days: 6));
  if (strings.isZh) {
    return '${start.month}月${start.day}日 - ${end.month}月${end.day}日';
  }
  return '${_englishMonthShort(start.month)} ${start.day} - ${_englishMonthShort(end.month)} ${end.day}';
}

String formatLingScheduleDayMonthLabel(LingStrings strings, DateTime date) {
  if (strings.isZh) {
    return '${date.month}月';
  }
  return _englishMonthShort(date.month).toUpperCase();
}

String formatLingScheduleDayDateLabel(LingStrings strings, DateTime date) {
  if (strings.isZh) {
    return '${date.month}月${date.day}日';
  }
  return '${_englishMonthShort(date.month)} ${date.day}';
}

String formatLingScheduleDayTitle(LingStrings strings, DateTime date) {
  if (strings.isZh) {
    return '${date.month}月${date.day}日 ${strings.weekdayShort(date.weekday)}';
  }
  return '${strings.weekdayShort(date.weekday)}, ${_englishMonthShort(date.month)} ${date.day}';
}

String? formatLingRecurrenceBadgeLabel(
  LingStrings strings, {
  required bool isRecurring,
  LingEventRecurrence? recurrence,
  required DateTime anchorStartAt,
  List<String> rawRRules = const <String>[],
}) {
  if (!isRecurring && recurrence == null && rawRRules.isEmpty) {
    return null;
  }

  final normalizedFrequency = _resolvedRecurrenceFrequency(
    recurrence,
    rawRRules,
  );
  switch (normalizedFrequency) {
    case 'daily':
      return strings.isZh ? '每天' : 'Daily';
    case 'weekly':
      final weekdayCodes = _resolvedWeekdayCodes(recurrence, anchorStartAt);
      if (weekdayCodes.isEmpty) {
        return strings.isZh ? '每周' : 'Weekly';
      }
      final weekdays = weekdayCodes
          .map((code) => _formatWeekdayCode(strings, code))
          .join(strings.isZh ? '、' : ', ');
      return strings.isZh ? '每周$weekdays' : 'Weekly · $weekdays';
    case 'monthly':
      final monthDays = _resolvedMonthDays(recurrence, anchorStartAt);
      if (monthDays.isEmpty) {
        return strings.isZh ? '每月' : 'Monthly';
      }
      return strings.isZh
          ? '每月${_formatMonthDayList(strings, monthDays)}'
          : 'Monthly · day ${_formatMonthDayList(strings, monthDays)}';
    case 'yearly':
      final label = _resolvedYearlyDateLabel(
        strings,
        recurrence,
        anchorStartAt,
      );
      if (label == null) {
        return strings.isZh ? '每年' : 'Yearly';
      }
      return strings.isZh ? '每年$label' : 'Yearly · $label';
  }

  return strings.recurringEventBadge;
}

String? formatLingRecurrenceDetailLabel(
  LingStrings strings, {
  required bool isRecurring,
  LingEventRecurrence? recurrence,
  required DateTime anchorStartAt,
  List<String> rawRRules = const <String>[],
}) {
  final badge = formatLingRecurrenceBadgeLabel(
    strings,
    isRecurring: isRecurring,
    recurrence: recurrence,
    anchorStartAt: anchorStartAt,
    rawRRules: rawRRules,
  );
  if (badge == null) {
    return null;
  }

  final normalizedFrequency = _resolvedRecurrenceFrequency(
    recurrence,
    rawRRules,
  );
  String summary;
  switch (normalizedFrequency) {
    case 'daily':
      summary = strings.isZh ? '每天重复' : 'Repeats daily';
      break;
    case 'weekly':
      final weekdayCodes = _resolvedWeekdayCodes(recurrence, anchorStartAt);
      if (weekdayCodes.isEmpty) {
        summary = strings.isZh ? '每周重复' : 'Repeats weekly';
      } else {
        final weekdays = weekdayCodes
            .map((code) => _formatWeekdayCode(strings, code))
            .join(strings.isZh ? '、' : ', ');
        summary = strings.isZh
            ? '每周$weekdays重复'
            : 'Repeats weekly on $weekdays';
      }
      break;
    case 'monthly':
      final monthDays = _resolvedMonthDays(recurrence, anchorStartAt);
      if (monthDays.isEmpty) {
        summary = strings.isZh ? '每月重复' : 'Repeats monthly';
      } else {
        summary = strings.isZh
            ? '每月${_formatMonthDayList(strings, monthDays)}重复'
            : 'Repeats monthly on day ${_formatMonthDayList(strings, monthDays)}';
      }
      break;
    case 'yearly':
      final label = _resolvedYearlyDateLabel(
        strings,
        recurrence,
        anchorStartAt,
      );
      if (label == null) {
        summary = strings.isZh ? '每年重复' : 'Repeats yearly';
      } else {
        summary = strings.isZh ? '每年$label重复' : 'Repeats yearly on $label';
      }
      break;
    default:
      summary = strings.isZh ? '循环日程' : 'Recurring event';
  }

  final recurrenceCount = recurrence?.count;
  final recurrenceUntil = (recurrence?.until ?? '').trim();
  final qualifiers = <String>[
    if (recurrenceCount != null)
      strings.isZh
          ? '共$recurrenceCount次'
          : '$recurrenceCount occurrence${recurrenceCount == 1 ? '' : 's'}',
    if (recurrenceUntil.isNotEmpty)
      strings.isZh
          ? '截止${_formatRecurrenceUntil(strings, recurrenceUntil)}'
          : 'Until ${_formatRecurrenceUntil(strings, recurrenceUntil)}',
  ];
  if (qualifiers.isEmpty) {
    return summary;
  }
  return '$summary · ${qualifiers.join(' · ')}';
}

String _resolvedRecurrenceFrequency(
  LingEventRecurrence? recurrence,
  List<String> rawRRules,
) {
  final frequency = recurrence?.frequency.trim().toLowerCase() ?? '';
  if (frequency.isNotEmpty) {
    return frequency;
  }
  for (final rawRule in rawRRules) {
    final match = RegExp(r'FREQ=([A-Z]+)').firstMatch(rawRule.toUpperCase());
    if (match != null) {
      return match.group(1)!.toLowerCase();
    }
  }
  return '';
}

List<String> _resolvedWeekdayCodes(
  LingEventRecurrence? recurrence,
  DateTime anchorStartAt,
) {
  final weekdayCodes =
      recurrence?.byWeekday
          .map((value) => value.trim().toUpperCase())
          .where((value) => _weekdayOrder.contains(value))
          .toSet()
          .toList(growable: false) ??
      const <String>[];
  if (weekdayCodes.isNotEmpty) {
    final sorted = weekdayCodes.toList(growable: true);
    sorted.sort(
      (left, right) =>
          _weekdayOrder.indexOf(left).compareTo(_weekdayOrder.indexOf(right)),
    );
    return List<String>.unmodifiable(sorted);
  }
  return <String>[_weekdayCodeFromDate(anchorStartAt)];
}

List<int> _resolvedMonthDays(
  LingEventRecurrence? recurrence,
  DateTime anchorStartAt,
) {
  final monthDays =
      recurrence?.byMonthDay.toSet().toList(growable: true) ?? <int>[];
  monthDays.removeWhere((day) => day == 0);
  if (monthDays.isNotEmpty) {
    monthDays.sort((left, right) => left.compareTo(right));
    return List<int>.unmodifiable(monthDays);
  }
  return <int>[anchorStartAt.day];
}

String? _resolvedYearlyDateLabel(
  LingStrings strings,
  LingEventRecurrence? recurrence,
  DateTime anchorStartAt,
) {
  final months = recurrence?.byMonth.toSet().toList(growable: true) ?? <int>[];
  months.removeWhere((month) => month < 1 || month > 12);
  months.sort((left, right) => left.compareTo(right));

  final monthDays =
      recurrence?.byMonthDay.toSet().toList(growable: true) ?? <int>[];
  monthDays.removeWhere((day) => day == 0);
  monthDays.sort((left, right) => left.compareTo(right));

  final month = months.length == 1 ? months.single : anchorStartAt.month;
  final day = monthDays.length == 1 ? monthDays.single : anchorStartAt.day;
  if (months.length > 1 || monthDays.length > 1) {
    return null;
  }
  if (strings.isZh) {
    return '$month月${_formatMonthDayValue(strings, day)}';
  }
  return '${_englishMonthShort(month)} ${_formatMonthDayValue(strings, day)}';
}

String _formatWeekdayCode(LingStrings strings, String code) {
  switch (code) {
    case 'MO':
      return strings.isZh ? '一' : strings.weekdayShort(1);
    case 'TU':
      return strings.isZh ? '二' : strings.weekdayShort(2);
    case 'WE':
      return strings.isZh ? '三' : strings.weekdayShort(3);
    case 'TH':
      return strings.isZh ? '四' : strings.weekdayShort(4);
    case 'FR':
      return strings.isZh ? '五' : strings.weekdayShort(5);
    case 'SA':
      return strings.isZh ? '六' : strings.weekdayShort(6);
    case 'SU':
      return strings.isZh ? '日' : strings.weekdayShort(7);
  }
  return code;
}

String _formatMonthDayList(LingStrings strings, List<int> days) {
  return days
      .map((day) => _formatMonthDayValue(strings, day))
      .join(strings.isZh ? '、' : ', ');
}

String _formatMonthDayValue(LingStrings strings, int day) {
  if (strings.isZh) {
    if (day < 0) {
      return '倒数${day.abs()}日';
    }
    return '$day日';
  }
  return '$day';
}

String _formatRecurrenceUntil(LingStrings strings, String rawUntil) {
  final parsed = DateTime.tryParse(rawUntil);
  if (parsed == null) {
    return rawUntil;
  }
  if (strings.isZh) {
    return '${parsed.year}年${parsed.month}月${parsed.day}日';
  }
  return '${_englishMonthShort(parsed.month)} ${parsed.day}, ${parsed.year}';
}

String _weekdayCodeFromDate(DateTime value) {
  return _weekdayOrder[(value.weekday - 1).clamp(0, 6)];
}

const List<String> _weekdayOrder = <String>[
  'MO',
  'TU',
  'WE',
  'TH',
  'FR',
  'SA',
  'SU',
];

String _englishMonthShort(int month) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[(month - 1).clamp(0, 11)];
}
