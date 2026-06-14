import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/calendar/models/apple_calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_time.dart';
import 'package:ling/src/features/calendar/presentation/schedule_agenda_card.dart';
import 'package:ling/src/features/calendar/presentation/schedule_formatters.dart';
import 'package:ling/src/features/calendar/presentation/schedule_header.dart';
import 'package:ling/src/features/calendar/presentation/schedule_view_models.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class LingWeekScheduleSection extends StatelessWidget {
  const LingWeekScheduleSection({
    super.key,
    required this.title,
    required this.weekModeButtonLabel,
    required this.modeButtonLabel,
    required this.isLoadingCalendar,
    required this.todayDateOnly,
    required this.currentDateTime,
    required this.dayBuckets,
    required this.onToggleMode,
    required this.onEditLingEvent,
    required this.onDeleteLingEvent,
    required this.onDeleteAppleEvent,
  });

  final String title;
  final String weekModeButtonLabel;
  final String modeButtonLabel;
  final bool isLoadingCalendar;
  final DateTime todayDateOnly;
  final DateTime currentDateTime;
  final List<LingScheduleDayBucket> dayBuckets;
  final VoidCallback onToggleMode;
  final ValueChanged<LingEvent> onEditLingEvent;
  final ValueChanged<LingEvent> onDeleteLingEvent;
  final ValueChanged<AppleCalendarEvent> onDeleteAppleEvent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            LingScheduleModeToggleButton(
              key: const Key('schedule_show_month_button'),
              currentMode: LingCalendarScheduleMode.week,
              weekLabel: weekModeButtonLabel,
              monthLabel: modeButtonLabel,
              onShowWeekMode: () {},
              onShowMonthMode: onToggleMode,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isLoadingCalendar)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: GlassProgressIndicator.circular()),
          )
        else
          Column(
            key: const Key('seven_day_section'),
            children: dayBuckets
                .map(
                  (bucket) => _ScheduleDayRow(
                    bucket: bucket,
                    todayDateOnly: todayDateOnly,
                    currentDateTime: currentDateTime,
                    onEditLingEvent: onEditLingEvent,
                    onDeleteLingEvent: onDeleteLingEvent,
                    onDeleteAppleEvent: onDeleteAppleEvent,
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _ScheduleDayRow extends StatelessWidget {
  const _ScheduleDayRow({
    required this.bucket,
    required this.todayDateOnly,
    required this.currentDateTime,
    required this.onEditLingEvent,
    required this.onDeleteLingEvent,
    required this.onDeleteAppleEvent,
  });

  final LingScheduleDayBucket bucket;
  final DateTime todayDateOnly;
  final DateTime currentDateTime;
  final ValueChanged<LingEvent> onEditLingEvent;
  final ValueChanged<LingEvent> onDeleteLingEvent;
  final ValueChanged<AppleCalendarEvent> onDeleteAppleEvent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final strings = LingStrings(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final dateKey = formatLingDateYmd(bucket.date);
    final isToday = isSameCalendarDay(bucket.date, todayDateOnly);
    final activeItemIndex = isToday && bucket.items.isNotEmpty
        ? _currentTimeActiveItemIndex(bucket.items, currentDateTime)
        : null;
    final relativeLabel = _relativeDayLabel(
      strings: strings,
      date: bucket.date,
      todayDateOnly: todayDateOnly,
    );
    final isTomorrow = isSameCalendarDay(
      bucket.date,
      todayDateOnly.add(const Duration(days: 1)),
    );
    return Padding(
      key: Key('schedule_day_row_$dateKey'),
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatLingScheduleDayTitle(strings, bucket.date),
                  key: Key('schedule_day_title_$dateKey'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
              ),
              if (relativeLabel.isNotEmpty)
                Text(
                  relativeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: palette.accent,
                  ),
                ),
            ],
          ),
          if (bucket.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Column(
              children: List.generate(bucket.items.length, (index) {
                final item = bucket.items[index];
                final currentTimeProgress = index == activeItemIndex
                    ? _currentTimeProgressForItem(item, currentDateTime)
                    : null;
                return Column(
                  children: [
                    _ScheduleTimelineEventCard(
                      item: item,
                      isLast: index == bucket.items.length - 1,
                      currentTimeProgress: currentTimeProgress,
                      onEditLingEvent: onEditLingEvent,
                      onDeleteLingEvent: onDeleteLingEvent,
                      onDeleteAppleEvent: onDeleteAppleEvent,
                    ),
                  ],
                );
              }),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              strings.emptyDayNote(
                isToday: isToday,
                isTomorrow: isTomorrow,
                date: bucket.date,
              ),
              style: TextStyle(
                color: palette.textSecondary,
                height: 1.45,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleTimelineEventCard extends StatelessWidget {
  const _ScheduleTimelineEventCard({
    required this.item,
    required this.isLast,
    this.currentTimeProgress,
    required this.onEditLingEvent,
    required this.onDeleteLingEvent,
    required this.onDeleteAppleEvent,
  });

  final LingScheduleAgendaItem item;
  final bool isLast;
  final double? currentTimeProgress;
  final ValueChanged<LingEvent> onEditLingEvent;
  final ValueChanged<LingEvent> onDeleteLingEvent;
  final ValueChanged<AppleCalendarEvent> onDeleteAppleEvent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        LingScheduleAgendaCard(
          item: item,
          currentTimeProgress: currentTimeProgress,
          onEditLingEvent: onEditLingEvent,
          onDeleteLingEvent: onDeleteLingEvent,
          onDeleteAppleEvent: onDeleteAppleEvent,
          bottomSpacing: 0,
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.fromLTRB(102, 8, 0, 8),
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                color: palette.outlineSoft.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
      ],
    );
  }
}

bool _isTimedDurationItem(LingScheduleAgendaItem item) {
  return !item.isAllDay && !item.isPoint && item.endAt.isAfter(item.startAt);
}

int? _currentTimeActiveItemIndex(
  List<LingScheduleAgendaItem> items,
  DateTime currentDateTime,
) {
  for (var index = 0; index < items.length; index += 1) {
    if (_isCurrentTimeWithinItem(items[index], currentDateTime)) {
      return index;
    }
  }
  return null;
}

bool _isCurrentTimeWithinItem(
  LingScheduleAgendaItem item,
  DateTime currentDateTime,
) {
  return _isTimedDurationItem(item) &&
      !currentDateTime.isBefore(item.startAt) &&
      currentDateTime.isBefore(item.endAt);
}

double? _currentTimeProgressForItem(
  LingScheduleAgendaItem item,
  DateTime currentDateTime,
) {
  if (!_isCurrentTimeWithinItem(item, currentDateTime)) {
    return null;
  }
  final durationMs = item.endAt.difference(item.startAt).inMilliseconds;
  if (durationMs <= 0) {
    return null;
  }
  final elapsedMs = currentDateTime.difference(item.startAt).inMilliseconds;
  return (elapsedMs / durationMs).clamp(0.0, 1.0);
}

String _relativeDayLabel({
  required LingStrings strings,
  required DateTime date,
  required DateTime todayDateOnly,
}) {
  if (isSameCalendarDay(date, todayDateOnly)) {
    return strings.isZh ? '今天' : 'Today';
  }
  final tomorrow = todayDateOnly.add(const Duration(days: 1));
  if (isSameCalendarDay(date, tomorrow)) {
    return strings.isZh ? '明天' : 'Tomorrow';
  }
  return '';
}
