import 'package:flutter/material.dart';

class LingCalendarAuthenticatedShell extends StatelessWidget {
  const LingCalendarAuthenticatedShell({
    super.key,
    required this.isCalendarOpen,
    required this.isSettingsOpen,
    required this.calendarHiddenOffset,
    required this.settingsHiddenOffset,
    required this.screenTransitionDuration,
    required this.chatView,
    required this.scheduleSection,
    required this.settingsPage,
  });

  final bool isCalendarOpen;
  final bool isSettingsOpen;
  final Offset calendarHiddenOffset;
  final Offset settingsHiddenOffset;
  final Duration screenTransitionDuration;
  final Widget chatView;
  final Widget scheduleSection;
  final Widget settingsPage;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: chatView),
          _AnimatedOverlayView(
            visible: isCalendarOpen,
            duration: screenTransitionDuration,
            hiddenOffset: calendarHiddenOffset,
            child: scheduleSection,
          ),
          _AnimatedOverlayView(
            visible: isSettingsOpen,
            duration: screenTransitionDuration,
            hiddenOffset: settingsHiddenOffset,
            child: settingsPage,
          ),
        ],
      ),
    );
  }
}

class _AnimatedOverlayView extends StatelessWidget {
  const _AnimatedOverlayView({
    required this.visible,
    required this.duration,
    required this.hiddenOffset,
    required this.child,
  });

  final bool visible;
  final Duration duration;
  final Offset hiddenOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : hiddenOffset,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: RepaintBoundary(child: child),
      ),
    );
  }
}
