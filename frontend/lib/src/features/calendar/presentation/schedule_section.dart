import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/calendar/application/calendar_controller.dart';
import 'package:ling/src/features/calendar/application/schedule_event_actions.dart';
import 'package:ling/src/features/calendar/application/schedule_surface_controller.dart';
import 'package:ling/src/features/calendar/models/apple_calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_event_editor_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_time.dart';
import 'package:ling/src/features/calendar/presentation/event_details_sheet.dart';
import 'package:ling/src/features/calendar/presentation/event_editor_sheet.dart';
import 'package:ling/src/features/calendar/presentation/schedule_content.dart';
import 'package:ling/src/features/calendar/presentation/schedule_formatters.dart';
import 'package:ling/src/features/calendar/presentation/schedule_header.dart';
import 'package:ling/src/features/calendar/presentation/schedule_view_models.dart';
import 'package:ling/src/features/chat/application/object_reference.dart';
import 'package:ling/src/shared/i18n/calendar_notification_formatters.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/edge_swipe_back.dart';
import 'package:ling/src/shared/presentation/notice.dart';

enum _LingScheduleSwipeAction {
  closeToRight,
  closeToLeft,
}

typedef _ScheduleAnalyticsTrack =
    Future<void> Function(
      String eventName, {
      required String action,
      String? source,
      Map<String, Object?> properties,
    });

class LingCalendarScheduleSection extends ConsumerStatefulWidget {
  const LingCalendarScheduleSection({
    super.key,
    required this.isOpen,
    required this.selectedDate,
    required this.isLoadingCalendar,
    required this.lingEvents,
    required this.monthData,
    required this.timezone,
    required this.appleEvents,
    required this.calendarNotificationSettings,
    required this.strings,
    required this.onClose,
    required this.onRefreshAppleCalendarData,
    required this.onSyncCalendarNotificationSchedule,
    this.onBackSwipeCompleted,
    this.onBackSwipeDirectionCompleted,
    this.onObjectReferenceSelected,
    this.underlayChild,
  });

  final bool isOpen;
  final String selectedDate;
  final bool isLoadingCalendar;
  final List<LingEvent> lingEvents;
  final CalendarMonthSnapshot? monthData;
  final String timezone;
  final List<AppleCalendarEvent> appleEvents;
  final CalendarNotificationSettings calendarNotificationSettings;
  final LingStrings strings;
  final VoidCallback onClose;
  final Future<void> Function({bool forceRefresh}) onRefreshAppleCalendarData;
  final Future<void> Function() onSyncCalendarNotificationSchedule;
  final VoidCallback? onBackSwipeCompleted;
  final ValueChanged<LingEdgeSwipeDirection>? onBackSwipeDirectionCompleted;
  final ValueChanged<LingObjectReference>? onObjectReferenceSelected;
  final Widget? underlayChild;

  @override
  ConsumerState<LingCalendarScheduleSection> createState() =>
      _LingCalendarScheduleSectionState();
}

class _LingCalendarScheduleSectionState
    extends ConsumerState<LingCalendarScheduleSection> {
  static const double _pageSwipeActivationWidth = 120;
  static const double _tabSwitchCompletionVelocity = 820;
  static const double _tabSwitchCompletionProgress = 0.24;

  final LingEdgeSwipeBackController _edgeSwipeBackController =
      LingEdgeSwipeBackController();
  final ScrollController _scheduleScrollController = ScrollController();
  LingCalendarScheduleMode _mode = LingCalendarScheduleMode.week;
  LingSchedulePrimaryTab _primaryTab = LingSchedulePrimaryTab.events;
  late DateTime _currentDateTime;
  Timer? _currentTimeTimer;
  double _tabSwitchDragOffset = 0;
  bool _isTabSwitchDragActive = false;
  LingEdgeSwipeDirection? _activeTabSwitchDirection;
  bool _forceDismissOnNextBack = false;
  LingEdgeSwipeDirection? _forcedDismissDirection;
  _LingScheduleSwipeAction? _pendingSwipeAction;

  CalendarController get _calendarController =>
      ref.read(calendarControllerProvider.notifier);
  ScheduleSurfaceController get _scheduleSurfaceController =>
      ref.read(scheduleSurfaceControllerProvider.notifier);
  ScheduleEventActions get _scheduleEventActions =>
      ref.read(scheduleEventActionsProvider);
  _ScheduleSectionEventFlow get _eventFlow => _ScheduleSectionEventFlow(
    context: context,
    strings: s,
    timezone: widget.timezone,
    calendarNotificationSettings: widget.calendarNotificationSettings,
    eventActions: _scheduleEventActions,
    isMounted: () => mounted,
    refreshAppleCalendar: widget.onRefreshAppleCalendarData,
    syncCalendarNotificationSchedule: widget.onSyncCalendarNotificationSchedule,
    showMessage: _showMessage,
    showError: _showError,
    onObjectReferenceSelected: widget.onObjectReferenceSelected,
    track: _trackScheduleEvent,
  );

  LingStrings get s => widget.strings;

  @override
  void initState() {
    super.initState();
    _currentDateTime = currentLingDateTime(widget.timezone);
    if (widget.isOpen) {
      _startCurrentTimeTicker();
    }
    if (widget.isOpen) {
      unawaited(
        _scheduleSurfaceController.ensureLoaded(timezone: widget.timezone),
      );
    }
  }

  @override
  void didUpdateWidget(covariant LingCalendarScheduleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final didOpen = !oldWidget.isOpen && widget.isOpen;
    if (didOpen) {
      _currentDateTime = currentLingDateTime(widget.timezone);
      _startCurrentTimeTicker();
      _primaryTab = LingSchedulePrimaryTab.events;
      _mode = LingCalendarScheduleMode.week;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          _scheduleSurfaceController.ensureLoaded(timezone: widget.timezone),
        );
      });
      return;
    }
    if (oldWidget.isOpen && !widget.isOpen) {
      _currentTimeTimer?.cancel();
      _currentTimeTimer = null;
    }
    if (widget.isOpen && oldWidget.timezone != widget.timezone) {
      _currentDateTime = currentLingDateTime(widget.timezone);
      _startCurrentTimeTicker();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          _scheduleSurfaceController.refreshWindowEvents(
            timezone: widget.timezone,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _currentTimeTimer?.cancel();
    _scheduleScrollController.dispose();
    super.dispose();
  }

  void _startCurrentTimeTicker() {
    _currentTimeTimer?.cancel();
    _currentTimeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || !widget.isOpen) {
        return;
      }
      setState(() {
        _currentDateTime = currentLingDateTime(widget.timezone);
      });
    });
  }

  void _showError(Object error) {
    final message = error is ApiException ? error.message : error.toString();
    if (!mounted) {
      return;
    }
    showLingTopNotice(context, message);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    showLingTopNotice(context, message);
  }

  Future<void> _trackScheduleEvent(
    String eventName, {
    required String action,
    String? source,
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    return ref
        .read(analyticsTrackerProvider)
        .track(
          eventName,
          surface: 'calendar',
          action: action,
          source: source,
          timezone: widget.timezone,
          properties: properties,
        );
  }

  Future<void> _handleCloseRequested() async {
    _forceDismissOnNextBack = true;
    _forcedDismissDirection = LingEdgeSwipeDirection.leftToRight;
    final didAnimate = await _edgeSwipeBackController.animateBack();
    if (didAnimate) {
      return;
    }
    if (!mounted) {
      return;
    }
    _forceDismissOnNextBack = false;
    _forcedDismissDirection = null;
    widget.onClose();
  }

  void _handleTabSwitchDragStart(DragStartDetails details) {
    _activeTabSwitchDirection = null;
    _isTabSwitchDragActive = false;
    _tabSwitchDragOffset = 0;
  }

  void _handleTabSwitchDragUpdate(DragUpdateDetails details) {
    if (!_isTabSwitchDragActive) {
      return;
    }
    final primaryDelta = details.primaryDelta ?? 0;
    if (primaryDelta == 0) {
      return;
    }
    final direction = _activeTabSwitchDirection;
    if (direction == null) {
      return;
    }
    final nextOffset = _tabSwitchDragOffset + primaryDelta;
    _tabSwitchDragOffset = switch (direction) {
      LingEdgeSwipeDirection.leftToRight => nextOffset.clamp(
        0,
        double.infinity,
      ),
      LingEdgeSwipeDirection.rightToLeft => nextOffset.clamp(
        double.negativeInfinity,
        0,
      ),
    };
  }

  void _handleTabSwitchDragEnd(DragEndDetails details) {
    if (!_isTabSwitchDragActive) {
      return;
    }
    final direction = _activeTabSwitchDirection;
    if (direction == null) {
      _isTabSwitchDragActive = false;
      _tabSwitchDragOffset = 0;
      return;
    }
    final width = context.size?.width ?? 0;
    final velocity = details.primaryVelocity ?? 0;
    final shouldComplete =
        switch (direction) {
          LingEdgeSwipeDirection.leftToRight =>
            velocity >= _tabSwitchCompletionVelocity,
          LingEdgeSwipeDirection.rightToLeft =>
            velocity <= -_tabSwitchCompletionVelocity,
        } ||
        (width > 0 &&
            _tabSwitchDragOffset.abs() / width >= _tabSwitchCompletionProgress);
    if (!shouldComplete) {
      _isTabSwitchDragActive = false;
      _activeTabSwitchDirection = null;
      _tabSwitchDragOffset = 0;
      return;
    }
    _isTabSwitchDragActive = false;
    _activeTabSwitchDirection = null;
    _tabSwitchDragOffset = 0;
    _handleTabSwitchCompleted(direction);
  }

  void _handleTabSwitchCompleted(LingEdgeSwipeDirection direction) {
    _showScheduleTab();
  }

  void _showScheduleTab() {
    if (_primaryTab == LingSchedulePrimaryTab.events ||
        _activeTabSwitchDirection != null) {
      return;
    }
    setState(() {
      _primaryTab = LingSchedulePrimaryTab.events;
    });
    unawaited(
      _trackScheduleEvent(
        'calendar.tab.switch',
        action: 'tab_switch',
        source: 'schedule',
      ),
    );
  }

  _LingScheduleSwipeAction _resolveSwipeAction(
    LingEdgeSwipeDirection direction,
  ) {
    final forcedDismissDirection = _forcedDismissDirection;
    if (_forceDismissOnNextBack && forcedDismissDirection != null) {
      return forcedDismissDirection == LingEdgeSwipeDirection.leftToRight
          ? _LingScheduleSwipeAction.closeToRight
          : _LingScheduleSwipeAction.closeToLeft;
    }
    return switch (direction) {
      LingEdgeSwipeDirection.leftToRight =>
        _LingScheduleSwipeAction.closeToRight,
      LingEdgeSwipeDirection.rightToLeft =>
        _LingScheduleSwipeAction.closeToLeft,
    };
  }

  bool _isCloseSwipeAction(_LingScheduleSwipeAction action) {
    return action == _LingScheduleSwipeAction.closeToRight ||
        action == _LingScheduleSwipeAction.closeToLeft;
  }

  void _handleSwipeDirectionCompleted(LingEdgeSwipeDirection direction) {
    final action = _resolveSwipeAction(direction);
    _pendingSwipeAction = action;
    if (_isCloseSwipeAction(action)) {
      widget.onBackSwipeDirectionCompleted?.call(direction);
    }
  }

  void _handleSwipeBackCompleted() {
    final action = _pendingSwipeAction;
    _pendingSwipeAction = null;
    _forceDismissOnNextBack = false;
    _forcedDismissDirection = null;
    if (!mounted) {
      return;
    }
    switch (action) {
      case _LingScheduleSwipeAction.closeToRight:
      case _LingScheduleSwipeAction.closeToLeft:
      case null:
        widget.onBackSwipeCompleted?.call();
        widget.onClose();
        return;
    }
  }

  Future<void> _changeSelectedMonth(int delta) {
    return _calendarController.changeSelectedMonth(delta);
  }

  Widget _buildScheduleView({
    Key? key,
    required ScheduleSurfaceState surfaceState,
    LingSchedulePrimaryTab? primaryTab,
  }) {
    final activePrimaryTab = primaryTab ?? _primaryTab;
    final brightness = Theme.of(context).brightness;
    final now = _currentDateTime;
    final today = now;
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final selectedDateOnly = parseLingDateOnly(widget.selectedDate);
    final weekEvents = resolveLingScheduleWindowEvents(
      windowStartDate: todayDateOnly,
      hasLoadedWindowEvents: surfaceState.hasLoadedWindowEvents,
      windowEvents: surfaceState.windowEvents,
      selectedDayEvents: widget.lingEvents,
    );
    final isWeekLoading =
        surfaceState.isLoadingWindowEvents &&
        !surfaceState.hasLoadedWindowEvents &&
        weekEvents.isEmpty;
    final monthAgendaItems = buildLingScheduleAgendaItems(
      strings: s,
      selectedDate: widget.selectedDate,
      lingEvents: widget.lingEvents,
      appleEvents: widget.appleEvents,
      brightness: brightness,
    );
    return LingCalendarScheduleContent(
      key: key,
      isOpen: widget.isOpen,
      showPinnedTopBar: false,
      monthTitle: formatLingMonthTitle(s, selectedDateOnly),
      selectedPrimaryTab: activePrimaryTab,
      scheduleTabLabel: s.scheduleTab,
      currentMode: _mode,
      selectedDate: widget.selectedDate,
      weekdayHeaders: s.weekdayHeaders,
      monthDays: widget.monthData?.days ?? const <CalendarMonthDay>[],
      appleEvents: widget.appleEvents,
      todayDateOnly: todayDateOnly,
      currentDateTime: now,
      isLoadingCalendar: isWeekLoading,
      weekHeaderLabel: s.next7Days,
      weekModeButtonLabel: s.switchToWeekView,
      monthModeButtonLabel: s.switchToMonthView,
      windowTitle: formatLingSevenDayWindowTitle(s, todayDateOnly),
      monthAgendaTitle: formatLingSelectedAgendaTitle(s, widget.selectedDate),
      monthAgendaItems: monthAgendaItems,
      emptyScheduleLabel: s.emptySchedule,
      dayBuckets: buildLingScheduleDayBuckets(
        strings: s,
        startDate: todayDateOnly,
        lingEvents: weekEvents,
        appleEvents: widget.appleEvents,
        brightness: brightness,
      ),
      scrollController: _scheduleScrollController,
      onClose: () => unawaited(_handleCloseRequested()),
      onShowScheduleTab: _showScheduleTab,
      onShowWeekMode: () {
        if (_mode == LingCalendarScheduleMode.week) {
          return;
        }
        setState(() {
          _mode = LingCalendarScheduleMode.week;
        });
        unawaited(
          _trackScheduleEvent(
            'calendar.mode.switch',
            action: 'mode_switch',
            source: 'week',
          ),
        );
      },
      onShowMonthMode: () {
        if (_mode == LingCalendarScheduleMode.month) {
          return;
        }
        setState(() {
          _mode = LingCalendarScheduleMode.month;
        });
        unawaited(
          _trackScheduleEvent(
            'calendar.mode.switch',
            action: 'mode_switch',
            source: 'month',
          ),
        );
      },
      onToday: () {
        if (widget.isLoadingCalendar) {
          return;
        }
        unawaited(
          _trackScheduleEvent(
            'calendar.date.select',
            action: 'date_select',
            source: 'today',
          ),
        );
        _calendarController.selectDate(formatLingDateYmd(todayDateOnly));
      },
      onPreviousMonth: () {
        if (widget.isLoadingCalendar) {
          return;
        }
        unawaited(
          _trackScheduleEvent(
            'calendar.month.navigate',
            action: 'month_navigate',
            source: 'previous',
          ),
        );
        _changeSelectedMonth(-1);
      },
      onNextMonth: () {
        if (widget.isLoadingCalendar) {
          return;
        }
        unawaited(
          _trackScheduleEvent(
            'calendar.month.navigate',
            action: 'month_navigate',
            source: 'next',
          ),
        );
        _changeSelectedMonth(1);
      },
      onSelectDate: (date) {
        unawaited(
          _trackScheduleEvent(
            'calendar.date.select',
            action: 'date_select',
            source: 'month_grid',
          ),
        );
        _calendarController.selectDate(date);
      },
      onEditLingEvent: (event) {
        unawaited(
          _trackScheduleEvent(
            'calendar.event.detail_open',
            action: 'event_detail_open',
            source: event.source,
          ),
        );
        _eventFlow.openEventDetailsSheet(event);
      },
      onDeleteLingEvent: (event) => _eventFlow.confirmDeleteLingEvent(event),
      onDeleteAppleEvent: (event) =>
          _eventFlow.confirmDeleteAppleCalendarEvent(event),
      editActionLabel: s.editAction,
      deleteActionLabel: s.deleteAction,
    );
  }

  Widget _buildFixedScheduleTopBar() {
    return SafeArea(
      top: true,
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: LingSchedulePinnedHeaderBackdrop(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: LingSchedulePinnedTopBar(
              selectedTab: _primaryTab,
              scheduleTabLabel: s.scheduleTab,
              showCloseButton: widget.isOpen,
              onShowScheduleTab: _showScheduleTab,
              onClose: () => unawaited(_handleCloseRequested()),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pageBackgroundColor = palette.background;
    final surfaceState = ref.watch(scheduleSurfaceControllerProvider);
    return LingEdgeSwipeBackContainer(
      key: const Key('schedule_edge_swipe_container'),
      controller: _edgeSwipeBackController,
      edgeActivationWidth: _pageSwipeActivationWidth,
      onBack: _handleSwipeBackCompleted,
      swipeDirections: const <LingEdgeSwipeDirection>{
        LingEdgeSwipeDirection.leftToRight,
      },
      onSwipeBackDirectionCompleted: _handleSwipeDirectionCompleted,
      underlayChild: widget.underlayChild,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _handleTabSwitchDragStart,
        onHorizontalDragUpdate: _handleTabSwitchDragUpdate,
        onHorizontalDragEnd: _handleTabSwitchDragEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(decoration: BoxDecoration(color: pageBackgroundColor)),
            SafeArea(
              top: true,
              bottom: false,
              child: _buildScheduleView(
                key: const ValueKey<String>('schedule_view_events'),
                surfaceState: surfaceState,
                primaryTab: LingSchedulePrimaryTab.events,
              ),
            ),
            _buildFixedScheduleTopBar(),
          ],
        ),
      ),
    );
  }

}


class _ScheduleSectionEventFlow {
  const _ScheduleSectionEventFlow({
    required this.context,
    required this.strings,
    required this.timezone,
    required this.calendarNotificationSettings,
    required this.eventActions,
    required this.isMounted,
    required this.refreshAppleCalendar,
    required this.syncCalendarNotificationSchedule,
    required this.showMessage,
    required this.showError,
    this.onObjectReferenceSelected,
    required this.track,
  });

  final BuildContext context;
  final LingStrings strings;
  final String timezone;
  final CalendarNotificationSettings calendarNotificationSettings;
  final ScheduleEventActions eventActions;
  final bool Function() isMounted;
  final Future<void> Function({bool forceRefresh}) refreshAppleCalendar;
  final Future<void> Function() syncCalendarNotificationSchedule;
  final ValueChanged<String> showMessage;
  final ValueChanged<Object> showError;
  final ValueChanged<LingObjectReference>? onObjectReferenceSelected;
  final _ScheduleAnalyticsTrack track;

  Future<void> openEventDetailsSheet(LingEvent event) {
    return showLingEventDetailsSheet(
      context: context,
      strings: strings,
      event: event,
      useHeroTransition: true,
      editActionLabel: strings.editAction,
      deleteActionLabel: event.isDeletable ? strings.deleteAction : null,
      onSubmitLingEventEdit: saveEventEdit,
      onDeleteLingEvent: event.isDeletable
          ? (event) => unawaited(confirmDeleteLingEvent(event))
          : null,
      onReferenceLingEvent: onObjectReferenceSelected == null
          ? null
          : (reference) => onObjectReferenceSelected!(reference),
    );
  }

  Future<void> openEditEventSheet(LingEvent event) async {
    final startAt = event.startAt;
    final endAt = event.endAt;
    final result = await showLingAdaptiveSheet<LingCalendarEventEditorResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return LingCalendarEventEditorSheet(
          strings: strings,
          sheetTitle: strings.editEvent,
          initialTitle: event.title,
          initialLocation: (event.location ?? '').trim(),
          initialMeetingUrl: (event.meetingUrl ?? '').trim(),
          initialTimeShape: event.timeShape,
          initialStartAt: startAt,
          initialEndAt: endAt,
          timezone: event.timezone,
          notificationLabel: calendarNotificationSettings.enabled
              ? formatCalendarNotificationSummary(
                  strings,
                  calendarNotificationSettings,
                )
              : strings.quickAddNoNotification,
          submitLabel: strings.saveEventChanges,
          initialRecurrence: event.recurrence,
          initialMutationScope: 'series',
          allowMutationScopeSelection:
              event.isRecurring && event.occurrenceStartAt != null,
        );
      },
    );
    if (result == null) {
      return;
    }
    await saveEventEdit(event, result);
  }

  Future<bool> saveEventEdit(
    LingEvent event,
    LingCalendarEventEditorResult result,
  ) async {
    final draft = result.draft;
    if (draft == null) {
      return false;
    }
    final eventId = event.eventId.trim();
    if (eventId.isEmpty) {
      return false;
    }
    final mutationScope =
        scheduleEventMutationScopeFromApiValue(result.mutationScope) ??
        await _chooseRecurringMutationScope(event, isDelete: false);
    if (mutationScope == null) {
      return false;
    }
    try {
      await eventActions.updateEvent(
        event: event,
        draft: draft,
        mutationScope: mutationScope,
        timezone: timezone,
        strings: strings,
        calendarNotificationSettings: calendarNotificationSettings,
        refreshAppleCalendar: refreshAppleCalendar,
      );
      await syncCalendarNotificationSchedule();
      showMessage(strings.updatedEvent(draft.title));
      unawaited(
        track(
          'calendar.event.edit_success',
          action: 'event_edit_success',
          source: event.source,
          properties: <String, Object?>{'mutation_scope': mutationScope.name},
        ),
      );
      return true;
    } catch (error) {
      unawaited(
        track(
          'calendar.event.edit_failure',
          action: 'event_edit_failure',
          source: event.source,
          properties: <String, Object?>{
            'error_type': error.runtimeType.toString(),
          },
        ),
      );
      showError(error);
      return false;
    }
  }

  Future<void> confirmDeleteLingEvent(LingEvent event) async {
    final title = event.title.trim().isEmpty
        ? strings.untitled
        : event.title.trim();
    final mutationScope = await _chooseRecurringMutationScope(
      event,
      isDelete: true,
    );
    if (mutationScope == null) {
      return;
    }
    final confirmed = await _confirmEventDelete(
      title: title,
      isRecurring: event.isRecurring,
      mutationScope: mutationScope,
    );
    if (confirmed != true || event.eventId.trim().isEmpty) {
      return;
    }
    try {
      await eventActions.deleteLingEvent(
        event: event,
        mutationScope: mutationScope,
        timezone: timezone,
        strings: strings,
        refreshAppleCalendar: refreshAppleCalendar,
      );
      await syncCalendarNotificationSchedule();
      showMessage(strings.deletedEvent(title));
      unawaited(
        track(
          'calendar.event.delete_success',
          action: 'event_delete_success',
          source: event.source,
          properties: <String, Object?>{'mutation_scope': mutationScope.name},
        ),
      );
    } catch (error) {
      unawaited(
        track(
          'calendar.event.delete_failure',
          action: 'event_delete_failure',
          source: event.source,
          properties: <String, Object?>{
            'error_type': error.runtimeType.toString(),
          },
        ),
      );
      showError(error);
    }
  }

  Future<void> confirmDeleteAppleCalendarEvent(AppleCalendarEvent event) async {
    final title = event.title.trim().isEmpty
        ? strings.untitled
        : event.title.trim();
    final mutationScope = await _chooseAppleRecurringMutationScope(
      event,
      isDelete: true,
    );
    if (mutationScope == null) {
      return;
    }
    final confirmed = await _confirmEventDelete(
      title: title,
      isRecurring: event.isRecurring,
      mutationScope: mutationScope,
    );
    if (confirmed != true || event.identifier.trim().isEmpty) {
      return;
    }
    try {
      await eventActions.deleteAppleCalendarEvent(
        event: event,
        mutationScope: mutationScope,
        timezone: timezone,
        refreshAppleCalendar: refreshAppleCalendar,
      );
      showMessage(strings.deletedEvent(title));
      unawaited(
        track(
          'calendar.event.delete_success',
          action: 'event_delete_success',
          source: 'apple',
          properties: <String, Object?>{'mutation_scope': mutationScope.name},
        ),
      );
    } catch (error) {
      unawaited(
        track(
          'calendar.event.delete_failure',
          action: 'event_delete_failure',
          source: 'apple',
          properties: <String, Object?>{
            'error_type': error.runtimeType.toString(),
          },
        ),
      );
      showError(error);
    }
  }

  Future<bool?> _confirmEventDelete({
    required String title,
    required bool isRecurring,
    required ScheduleEventMutationScope mutationScope,
  }) {
    final confirmMessage = !isRecurring
        ? strings.deleteEventConfirmMessage(title)
        : mutationScope == ScheduleEventMutationScope.occurrence
        ? strings.deleteThisEventConfirmMessage(title)
        : strings.deleteSeriesConfirmMessage(title);
    if (!isMounted()) {
      return Future<bool?>.value();
    }
    return showLingAdaptiveConfirmationDialog(
      context: context,
      title: strings.deleteEventAction,
      message: confirmMessage,
      cancelLabel: strings.cancel,
      confirmLabel: strings.deleteAction,
      isDestructive: true,
    );
  }

  Future<ScheduleEventMutationScope?> _chooseRecurringMutationScope(
    LingEvent event, {
    required bool isDelete,
  }) async {
    if (!event.isRecurring || event.occurrenceStartAt == null) {
      return ScheduleEventMutationScope.series;
    }
    return _showRecurringMutationScopeSheet(isDelete: isDelete);
  }

  Future<ScheduleEventMutationScope?> _chooseAppleRecurringMutationScope(
    AppleCalendarEvent event, {
    required bool isDelete,
  }) async {
    if (!event.isRecurring || event.occurrenceDate == null) {
      return ScheduleEventMutationScope.series;
    }
    return _showRecurringMutationScopeSheet(isDelete: isDelete);
  }

  Future<ScheduleEventMutationScope?> _showRecurringMutationScopeSheet({
    required bool isDelete,
  }) {
    return showLingAdaptiveActionSheet<ScheduleEventMutationScope>(
      context: context,
      title: isDelete
          ? strings.recurringDeleteScopeTitle
          : strings.recurringEditScopeTitle,
      message: isDelete
          ? strings.recurringDeleteScopeMessage
          : strings.recurringEditScopeMessage,
      cancelLabel: strings.cancel,
      actions: <LingAdaptiveActionSheetAction<ScheduleEventMutationScope>>[
        LingAdaptiveActionSheetAction<ScheduleEventMutationScope>(
          value: ScheduleEventMutationScope.occurrence,
          label: strings.recurringScopeThisEvent,
          icon: Icons.event_repeat,
          isDestructive: isDelete,
        ),
        LingAdaptiveActionSheetAction<ScheduleEventMutationScope>(
          value: ScheduleEventMutationScope.series,
          label: strings.recurringScopeEntireSeries,
          icon: Icons.view_timeline,
          isDestructive: isDelete,
        ),
      ],
    );
  }
}
