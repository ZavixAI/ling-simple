import 'package:flutter/material.dart';
import 'package:ling/src/features/calendar/models/apple_calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_time.dart';
import 'package:ling/src/features/calendar/presentation/month_schedule_section.dart';
import 'package:ling/src/features/calendar/presentation/schedule_header.dart';
import 'package:ling/src/features/calendar/presentation/schedule_view_models.dart';
import 'package:ling/src/features/calendar/presentation/week_schedule_section.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';

class LingCalendarScheduleContent extends StatefulWidget {
  const LingCalendarScheduleContent({
    super.key,
    this.isOpen = false,
    this.showPinnedTopBar = true,
    required this.monthTitle,
    required this.selectedPrimaryTab,
    required this.scheduleTabLabel,
    required this.selectedDate,
    required this.weekdayHeaders,
    required this.monthDays,
    required this.appleEvents,
    required this.todayDateOnly,
    required this.currentDateTime,
    required this.isLoadingCalendar,
    required this.currentMode,
    required this.weekHeaderLabel,
    required this.weekModeButtonLabel,
    required this.monthModeButtonLabel,
    required this.windowTitle,
    required this.monthAgendaTitle,
    required this.monthAgendaItems,
    required this.emptyScheduleLabel,
    required this.dayBuckets,
    required this.scrollController,
    required this.onClose,
    required this.onShowScheduleTab,
    required this.onShowWeekMode,
    required this.onShowMonthMode,
    required this.onToday,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
    required this.onEditLingEvent,
    required this.onDeleteLingEvent,
    required this.onDeleteAppleEvent,
    required this.editActionLabel,
    required this.deleteActionLabel,
  });

  final bool isOpen;
  final bool showPinnedTopBar;
  final String monthTitle;
  final LingSchedulePrimaryTab selectedPrimaryTab;
  final String scheduleTabLabel;
  final String selectedDate;
  final List<String> weekdayHeaders;
  final List<CalendarMonthDay> monthDays;
  final List<AppleCalendarEvent> appleEvents;
  final DateTime todayDateOnly;
  final DateTime currentDateTime;
  final bool isLoadingCalendar;
  final LingCalendarScheduleMode currentMode;
  final String weekHeaderLabel;
  final String weekModeButtonLabel;
  final String monthModeButtonLabel;
  final String windowTitle;
  final String monthAgendaTitle;
  final List<LingScheduleAgendaItem> monthAgendaItems;
  final String emptyScheduleLabel;
  final List<LingScheduleDayBucket> dayBuckets;
  final ScrollController scrollController;
  final VoidCallback onClose;
  final VoidCallback onShowScheduleTab;
  final VoidCallback onShowWeekMode;
  final VoidCallback onShowMonthMode;
  final VoidCallback onToday;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<String> onSelectDate;
  final ValueChanged<LingEvent> onEditLingEvent;
  final ValueChanged<LingEvent> onDeleteLingEvent;
  final ValueChanged<AppleCalendarEvent> onDeleteAppleEvent;
  final String editActionLabel;
  final String deleteActionLabel;

  @override
  State<LingCalendarScheduleContent> createState() =>
      _LingCalendarScheduleContentState();
}

class _LingCalendarScheduleContentState
    extends State<LingCalendarScheduleContent> {
  @override
  Widget build(BuildContext context) {
    final appleCountByDate = <String, int>{};
    for (final event in widget.appleEvents) {
      var currentDay = DateTime(
        event.startAt.year,
        event.startAt.month,
        event.startAt.day,
      );
      final lastDay = DateTime(
        event.endAt.subtract(const Duration(microseconds: 1)).year,
        event.endAt.subtract(const Duration(microseconds: 1)).month,
        event.endAt.subtract(const Duration(microseconds: 1)).day,
      );
      while (!currentDay.isAfter(lastDay)) {
        final key = formatLingDateYmd(currentDay);
        appleCountByDate[key] = (appleCountByDate[key] ?? 0) + 1;
        currentDay = currentDay.add(const Duration(days: 1));
      }
    }
    final strings = LingStrings(
      Localizations.localeOf(context).toLanguageTag(),
    );

    return Stack(
      children: [
        CustomScrollView(
          key: const PageStorageKey<String>('schedule_list'),
          controller: widget.scrollController,
          slivers: [
            if (widget.showPinnedTopBar)
              PinnedHeaderSliver(
                child: LingSchedulePinnedHeaderBackdrop(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: LingSchedulePinnedTopBar(
                      selectedTab: widget.selectedPrimaryTab,
                      scheduleTabLabel: widget.scheduleTabLabel,
                      showCloseButton: widget.isOpen,
                      onShowScheduleTab: widget.onShowScheduleTab,
                      onClose: widget.onClose,
                    ),
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 72)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
              sliver: SliverToBoxAdapter(
                child: switch (widget.selectedPrimaryTab) {
                  LingSchedulePrimaryTab.events
                      when widget.currentMode ==
                          LingCalendarScheduleMode.month =>
                    LingMonthScheduleSection(
                      monthTitle: widget.monthTitle,
                      modeButtonLabel: widget.weekModeButtonLabel,
                      monthModeButtonLabel: widget.monthModeButtonLabel,
                      weekdayHeaders: widget.weekdayHeaders,
                      monthDays: widget.monthDays,
                      selectedDate: widget.selectedDate,
                      todayDateOnly: widget.todayDateOnly,
                      appleCountByDate: appleCountByDate,
                      agendaTitle: widget.monthAgendaTitle,
                      agendaItems: widget.monthAgendaItems,
                      emptyScheduleLabel: widget.emptyScheduleLabel,
                      todayButtonLabel: strings.calendarTodayAction,
                      isLoadingCalendar: widget.isLoadingCalendar,
                      onSelectDate: widget.onSelectDate,
                      onToday: widget.onToday,
                      onPreviousMonth: widget.onPreviousMonth,
                      onNextMonth: widget.onNextMonth,
                      onToggleMode: widget.onShowWeekMode,
                      onEditLingEvent: widget.onEditLingEvent,
                      onDeleteLingEvent: widget.onDeleteLingEvent,
                      onDeleteAppleEvent: widget.onDeleteAppleEvent,
                    ),
                  _ => LingWeekScheduleSection(
                    title: widget.weekHeaderLabel,
                    weekModeButtonLabel: widget.weekModeButtonLabel,
                    modeButtonLabel: widget.monthModeButtonLabel,
                    isLoadingCalendar: widget.isLoadingCalendar,
                    todayDateOnly: widget.todayDateOnly,
                    currentDateTime: widget.currentDateTime,
                    dayBuckets: widget.dayBuckets,
                    onToggleMode: widget.onShowMonthMode,
                    onEditLingEvent: widget.onEditLingEvent,
                    onDeleteLingEvent: widget.onDeleteLingEvent,
                    onDeleteAppleEvent: widget.onDeleteAppleEvent,
                  ),
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
