import 'package:flutter/material.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/presentation/calendar_month_grid.dart';

class LingScheduleMonthCard extends StatelessWidget {
  const LingScheduleMonthCard({
    super.key,
    required this.weekdayHeaders,
    required this.monthDays,
    required this.selectedDate,
    required this.appleCountByDate,
    required this.onSelectDate,
    this.todayDateOnly,
  });

  final List<String> weekdayHeaders;
  final List<CalendarMonthDay> monthDays;
  final String selectedDate;
  final Map<String, int> appleCountByDate;
  final ValueChanged<String> onSelectDate;
  final DateTime? todayDateOnly;

  @override
  Widget build(BuildContext context) {
    return LingCalendarMonthGrid(
      weekdayHeaders: weekdayHeaders,
      monthDays: monthDays,
      selectedDate: selectedDate,
      todayDateOnly: todayDateOnly,
      appleCountByDate: appleCountByDate,
      dayKeyPrefix: 'schedule_month_day',
      onSelectDate: onSelectDate,
    );
  }
}
