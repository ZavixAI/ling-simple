import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/calendar/models/apple_calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/presentation/schedule_agenda_card.dart';
import 'package:ling/src/features/calendar/presentation/schedule_header.dart';
import 'package:ling/src/features/calendar/presentation/schedule_month_card.dart';
import 'package:ling/src/features/calendar/presentation/schedule_view_models.dart';
import 'package:ling/src/shared/presentation/shared_controls.dart';
import 'package:ling/src/shared/presentation/tap_haptics.dart';

class LingMonthScheduleSection extends StatelessWidget {
  const LingMonthScheduleSection({
    super.key,
    required this.monthTitle,
    required this.monthModeButtonLabel,
    required this.modeButtonLabel,
    required this.weekdayHeaders,
    required this.monthDays,
    required this.selectedDate,
    required this.todayDateOnly,
    required this.appleCountByDate,
    required this.agendaTitle,
    required this.agendaItems,
    required this.emptyScheduleLabel,
    required this.todayButtonLabel,
    required this.isLoadingCalendar,
    required this.onSelectDate,
    required this.onToday,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToggleMode,
    required this.onEditLingEvent,
    required this.onDeleteLingEvent,
    required this.onDeleteAppleEvent,
  });

  final String monthTitle;
  final String monthModeButtonLabel;
  final String modeButtonLabel;
  final List<String> weekdayHeaders;
  final List<CalendarMonthDay> monthDays;
  final String selectedDate;
  final DateTime todayDateOnly;
  final Map<String, int> appleCountByDate;
  final String agendaTitle;
  final List<LingScheduleAgendaItem> agendaItems;
  final String emptyScheduleLabel;
  final String todayButtonLabel;
  final bool isLoadingCalendar;
  final ValueChanged<String> onSelectDate;
  final VoidCallback onToday;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
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
              child: Text(
                monthTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            LingScheduleModeToggleButton(
              key: const Key('schedule_show_week_button'),
              currentMode: LingCalendarScheduleMode.month,
              weekLabel: modeButtonLabel,
              monthLabel: monthModeButtonLabel,
              onShowWeekMode: onToggleMode,
              onShowMonthMode: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _MonthTodayButton(
              key: const Key('month_today_button'),
              label: todayButtonLabel,
              onTap: onToday,
            ),
            const Spacer(),
            LingFloatingIconButton(
              key: const Key('month_prev_button'),
              icon: Icons.chevron_left_rounded,
              onTap: onPreviousMonth,
            ),
            const SizedBox(width: 8),
            LingFloatingIconButton(
              key: const Key('month_next_button'),
              icon: Icons.chevron_right_rounded,
              onTap: onNextMonth,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          key: const Key('schedule_month_section'),
          child: LingScheduleMonthCard(
            weekdayHeaders: weekdayHeaders,
            monthDays: monthDays,
            selectedDate: selectedDate,
            todayDateOnly: todayDateOnly,
            appleCountByDate: appleCountByDate,
            onSelectDate: onSelectDate,
          ),
        ),
        const SizedBox(height: 32),
        _MonthAgendaContent(
          agendaTitle: agendaTitle,
          agendaItems: agendaItems,
          emptyScheduleLabel: emptyScheduleLabel,
          isLoadingCalendar: isLoadingCalendar,
          onEditLingEvent: onEditLingEvent,
          onDeleteLingEvent: onDeleteLingEvent,
          onDeleteAppleEvent: onDeleteAppleEvent,
        ),
      ],
    );
  }
}

class _MonthTodayButton extends StatelessWidget {
  const _MonthTodayButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: LingTapHaptics.wrap(onTap),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark
              ? palette.backgroundElevated.withValues(alpha: 0.84)
              : palette.backgroundElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? palette.outlineSoft.withValues(alpha: 0.72)
                : palette.outlineSoft,
          ),
        ),
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.today_rounded,
                    size: 14,
                    color: isDark ? palette.accent : palette.textPrimary,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthAgendaContent extends StatefulWidget {
  const _MonthAgendaContent({
    required this.agendaTitle,
    required this.agendaItems,
    required this.emptyScheduleLabel,
    required this.isLoadingCalendar,
    required this.onEditLingEvent,
    required this.onDeleteLingEvent,
    required this.onDeleteAppleEvent,
  });

  final String agendaTitle;
  final List<LingScheduleAgendaItem> agendaItems;
  final String emptyScheduleLabel;
  final bool isLoadingCalendar;
  final ValueChanged<LingEvent> onEditLingEvent;
  final ValueChanged<LingEvent> onDeleteLingEvent;
  final ValueChanged<AppleCalendarEvent> onDeleteAppleEvent;

  @override
  State<_MonthAgendaContent> createState() => _MonthAgendaContentState();
}

class _MonthAgendaContentState extends State<_MonthAgendaContent> {
  late _VisibleMonthAgenda _visibleAgenda;

  @override
  void initState() {
    super.initState();
    _visibleAgenda = _captureAgenda(widget);
  }

  @override
  void didUpdateWidget(covariant _MonthAgendaContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isLoadingCalendar) {
      _visibleAgenda = _captureAgenda(widget);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleAgenda = widget.isLoadingCalendar
        ? _visibleAgenda
        : _captureAgenda(widget);

    return AnimatedSize(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[...previousChildren, ?currentChild],
          );
        },
        child: _MonthAgendaBody(
          key: ValueKey<String>(visibleAgenda.signature),
          agenda: visibleAgenda,
          emptyScheduleLabel: widget.emptyScheduleLabel,
          onEditLingEvent: widget.onEditLingEvent,
          onDeleteLingEvent: widget.onDeleteLingEvent,
          onDeleteAppleEvent: widget.onDeleteAppleEvent,
        ),
      ),
    );
  }

  _VisibleMonthAgenda _captureAgenda(_MonthAgendaContent widget) {
    return _VisibleMonthAgenda(
      title: widget.agendaTitle,
      items: List<LingScheduleAgendaItem>.unmodifiable(widget.agendaItems),
    );
  }
}

class _MonthAgendaBody extends StatelessWidget {
  const _MonthAgendaBody({
    super.key,
    required this.agenda,
    required this.emptyScheduleLabel,
    required this.onEditLingEvent,
    required this.onDeleteLingEvent,
    required this.onDeleteAppleEvent,
  });

  final _VisibleMonthAgenda agenda;
  final String emptyScheduleLabel;
  final ValueChanged<LingEvent> onEditLingEvent;
  final ValueChanged<LingEvent> onDeleteLingEvent;
  final ValueChanged<AppleCalendarEvent> onDeleteAppleEvent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            agenda.title,
            key: const Key('schedule_month_agenda_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (agenda.items.isEmpty)
            Container(
              key: const Key('schedule_month_empty_state'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                emptyScheduleLabel,
                style: TextStyle(color: palette.textSecondary, height: 1.5),
              ),
            )
          else
            ...agenda.items.map(
              (item) => LingScheduleAgendaCard(
                key: ValueKey<String>('month_agenda_${_agendaItemKey(item)}'),
                item: item,
                onEditLingEvent: onEditLingEvent,
                onDeleteLingEvent: onDeleteLingEvent,
                onDeleteAppleEvent: onDeleteAppleEvent,
              ),
            ),
        ],
      ),
    );
  }
}

class _VisibleMonthAgenda {
  const _VisibleMonthAgenda({required this.title, required this.items});

  final String title;
  final List<LingScheduleAgendaItem> items;

  String get signature {
    final buffer = StringBuffer(title)
      ..write('|')
      ..write(items.length);
    for (final item in items) {
      buffer.write('|');
      buffer.write(_agendaItemKey(item));
    }
    return buffer.toString();
  }
}

String _agendaItemKey(LingScheduleAgendaItem item) {
  final sourceId =
      item.lingEvent?.eventId ??
      item.appleEvent?.calendarItemIdentifier ??
      item.appleEvent?.identifier ??
      item.title;
  return '$sourceId-${item.startAt.microsecondsSinceEpoch}-${item.endAt.microsecondsSinceEpoch}';
}
