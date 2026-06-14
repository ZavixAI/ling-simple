import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/calendar/presentation/schedule_view_models.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

class LingSchedulePinnedTopBar extends StatelessWidget {
  const LingSchedulePinnedTopBar({
    super.key,
    required this.selectedTab,
    required this.scheduleTabLabel,
    required this.showCloseButton,
    required this.onShowScheduleTab,
    required this.onClose,
  });

  final LingSchedulePrimaryTab selectedTab;
  final String scheduleTabLabel;
  final bool showCloseButton;
  final VoidCallback onShowScheduleTab;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        key: const Key('schedule_header_top_bar'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _ScheduleTopTextTabs(
              selectedTab: selectedTab,
              scheduleLabel: scheduleTabLabel,
              onSelectSchedule: onShowScheduleTab,
            ),
          ),
          if (showCloseButton) ...[
            const SizedBox(width: 12),
            _ScheduleHeaderCloseButton(
              key: const Key('schedule_close_button'),
              onTap: onClose,
            ),
          ],
        ],
      ),
    );
  }
}

class LingWeekModePinnedHeader extends StatelessWidget {
  const LingWeekModePinnedHeader({
    super.key,
    required this.weekModeButtonLabel,
    required this.modeButtonLabel,
    required this.onToggleMode,
  });

  final String weekModeButtonLabel;
  final String modeButtonLabel;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LingScheduleModeToggleButton(
          key: const Key('schedule_show_month_button'),
          currentMode: LingCalendarScheduleMode.week,
          weekLabel: weekModeButtonLabel,
          monthLabel: modeButtonLabel,
          onShowWeekMode: () {},
          onShowMonthMode: onToggleMode,
        ),
      ],
    );
  }
}

class LingScheduleModeToggleButton extends StatelessWidget {
  const LingScheduleModeToggleButton({
    super.key,
    required this.currentMode,
    required this.weekLabel,
    required this.monthLabel,
    required this.onShowWeekMode,
    required this.onShowMonthMode,
  });

  final LingCalendarScheduleMode currentMode;
  final String weekLabel;
  final String monthLabel;
  final VoidCallback onShowWeekMode;
  final VoidCallback onShowMonthMode;

  @override
  Widget build(BuildContext context) {
    final compactWeekLabel = _compactScheduleModeLabel(weekLabel);
    final compactMonthLabel = _compactScheduleModeLabel(monthLabel);
    return SizedBox(
      width: 174,
      height: 38,
      child: LingGlassFloatingSwitch<LingCalendarScheduleMode>(
        width: 174,
        height: 38,
        padding: const EdgeInsets.all(2),
        selected: currentMode,
        showIcons: false,
        labelFontSize: 13,
        horizontalLabelPadding: 10,
        onChanged: (mode) {
          if (mode == LingCalendarScheduleMode.week) {
            onShowWeekMode();
          } else {
            onShowMonthMode();
          }
        },
        items: [
          LingGlassFloatingSwitchItem(
            value: LingCalendarScheduleMode.week,
            label: compactWeekLabel,
            icon: Icons.view_week_rounded,
          ),
          LingGlassFloatingSwitchItem(
            value: LingCalendarScheduleMode.month,
            label: compactMonthLabel,
            icon: Icons.calendar_month_rounded,
          ),
        ],
      ),
    );
  }
}

String _compactScheduleModeLabel(String label) {
  final trimmed = label.trim();
  if (trimmed.startsWith('查看') && trimmed.length > 2) {
    return trimmed.substring(2);
  }
  return trimmed;
}

class LingSchedulePinnedHeaderBackdrop extends StatelessWidget {
  const LingSchedulePinnedHeaderBackdrop({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(0, 0, 0, 8),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      key: const Key('schedule_header_backdrop'),
      padding: padding,
      child: DecoratedBox(
        decoration: BoxDecoration(color: palette.background),
        child: child,
      ),
    );
  }
}

class _ScheduleHeaderCloseButton extends StatelessWidget {
  const _ScheduleHeaderCloseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('schedule_close_button_material'),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.close_rounded,
            size: 30,
            color: context.palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ScheduleTopTextTabs extends StatelessWidget {
  const _ScheduleTopTextTabs({
    required this.selectedTab,
    required this.scheduleLabel,
    required this.onSelectSchedule,
  });

  final LingSchedulePrimaryTab selectedTab;
  final String scheduleLabel;
  final VoidCallback onSelectSchedule;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    TextStyle styleFor(bool isSelected) {
      return TextStyle(
        fontSize: isSelected ? 28 : 20,
        height: 1,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        letterSpacing: 0,
        color: isSelected ? palette.textPrimary : palette.textSecondary,
        fontFamily: 'Plus Jakarta Sans',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ScheduleTopTextTab(
            label: scheduleLabel,
            style: styleFor(selectedTab == LingSchedulePrimaryTab.events),
            onTap: onSelectSchedule,
          ),
        ],
      ),
    );
  }
}

class _ScheduleTopTextTab extends StatelessWidget {
  const _ScheduleTopTextTab({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(label, style: style),
        ),
      ),
    );
  }
}
