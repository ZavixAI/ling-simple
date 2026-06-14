import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_time.dart';
import 'package:ling/src/features/calendar/models/lunar_calendar.dart';

class LingCalendarMonthGrid extends StatelessWidget {
  const LingCalendarMonthGrid({
    super.key,
    required this.weekdayHeaders,
    required this.monthDays,
    required this.selectedDate,
    required this.appleCountByDate,
    required this.onSelectDate,
    this.todayDateOnly,
    this.dayKeyPrefix = 'calendar_month_day',
  });

  final List<String> weekdayHeaders;
  final List<CalendarMonthDay> monthDays;
  final String selectedDate;
  final Map<String, int> appleCountByDate;
  final ValueChanged<String> onSelectDate;
  final DateTime? todayDateOnly;
  final String dayKeyPrefix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              for (final label in weekdayHeaders) _WeekdayLabel(label),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: monthDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final day = monthDays[index];
              final date = day.date;
              final dateOnly = parseLingDateOnly(date);
              final isPastDay =
                  todayDateOnly != null && dateOnly.isBefore(todayDateOnly!);
              final markerCount =
                  day.eventCount + (appleCountByDate[date] ?? 0);

              return LingCalendarMonthDayCell(
                key: ValueKey<String>('${dayKeyPrefix}_$date'),
                date: dateOnly,
                isCurrentMonth: day.inCurrentMonth,
                isSelected: date == selectedDate,
                isPastDay: isPastDay,
                markerCount: markerCount,
                onTap: day.inCurrentMonth ? () => onSelectDate(date) : null,
              );
            },
          ),
        ],
      ),
    );
  }
}

class LingCalendarMonthDayCell extends StatelessWidget {
  const LingCalendarMonthDayCell({
    super.key,
    required this.date,
    required this.isCurrentMonth,
    required this.isSelected,
    required this.isPastDay,
    required this.markerCount,
    this.onTap,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final bool isSelected;
  final bool isPastDay;
  final int markerCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lunarLabel = formatLingLunarDate(date);
    final enabled = onTap != null;
    final foreground = isSelected
        ? palette.onAccent
        : isCurrentMonth
        ? (isPastDay ? palette.textSecondary : palette.textPrimary)
        : palette.textTertiary.withValues(alpha: 0.52);
    final lunarColor = isSelected
        ? palette.onAccent.withValues(alpha: 0.84)
        : isCurrentMonth
        ? palette.textTertiary
        : palette.textTertiary.withValues(alpha: 0.42);

    return Semantics(
      button: enabled,
      selected: isSelected,
      label: '${date.year}-${date.month}-${date.day} $lunarLabel',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? palette.accent : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    maxLines: 1,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lunarLabel,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: lunarColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _MonthDayMarker(
                    isVisible: markerCount > 0,
                    color: isSelected
                        ? palette.onAccent.withValues(alpha: 0.9)
                        : isPastDay
                        ? palette.outline.withValues(alpha: 0.62)
                        : palette.accent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthDayMarker extends StatelessWidget {
  const _MonthDayMarker({required this.isVisible, required this.color});

  final bool isVisible;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: isVisible ? color : Colors.transparent,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
