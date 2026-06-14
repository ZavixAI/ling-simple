import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/calendar/application/event_editor_form_support.dart';
import 'package:ling/src/features/calendar/application/event_editor_support.dart';
import 'package:ling/src/features/calendar/models/calendar_event_editor_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_time.dart';
import 'package:ling/src/features/calendar/presentation/schedule_formatters.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/shared_controls.dart';

class LingCalendarEventEditorSheet extends StatefulWidget {
  const LingCalendarEventEditorSheet({
    super.key,
    required this.strings,
    required this.sheetTitle,
    required this.initialStartAt,
    required this.initialEndAt,
    required this.timezone,
    required this.notificationLabel,
    required this.submitLabel,
    this.initialTitle = '',
    this.initialLocation,
    this.initialMeetingUrl,
    this.initialTimeShape = 'span',
    this.initialRecurrence,
    this.initialMutationScope = 'series',
    this.allowMutationScopeSelection = false,
    this.embedded = false,
    this.onCancel,
    this.onSubmitResult,
  });

  final LingStrings strings;
  final String sheetTitle;
  final String initialTitle;
  final String? initialLocation;
  final String? initialMeetingUrl;
  final String initialTimeShape;
  final DateTime initialStartAt;
  final DateTime initialEndAt;
  final String timezone;
  final String notificationLabel;
  final String submitLabel;
  final LingEventRecurrence? initialRecurrence;
  final String initialMutationScope;
  final bool allowMutationScopeSelection;
  final bool embedded;
  final VoidCallback? onCancel;
  final ValueChanged<LingCalendarEventEditorResult>? onSubmitResult;

  @override
  State<LingCalendarEventEditorSheet> createState() =>
      _LingCalendarEventEditorSheetState();
}

class _LingCalendarEventEditorSheetState
    extends State<LingCalendarEventEditorSheet>
    with SingleTickerProviderStateMixin {
  static const Duration _sheetDragAnimationDuration = Duration(
    milliseconds: 240,
  );
  static const double _sheetDismissVelocity = 820;
  static const double _sheetDismissProgress = 0.24;

  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _meetingUrlController;
  late final AnimationController _sheetDragAnimationController;
  late DateTime _startAt;
  late DateTime _endAt;
  late _EventEditorRecurrencePreset _recurrencePreset;
  late Set<String> _weeklyRecurrenceDays;
  late String _mutationScope;
  _EventEditorInlinePicker _activePicker = _EventEditorInlinePicker.none;
  Animation<double>? _sheetDragOffsetAnimation;
  double _sheetDragOffset = 0;
  bool _isDraggingSheet = false;
  bool _isAnimatingSheetBack = false;
  bool _isCompletingSheetDismiss = false;
  String? _titleErrorText;

  LingStrings get s => widget.strings;

  bool get _isEditingThisOccurrenceOnly =>
      widget.allowMutationScopeSelection && _mutationScope == 'occurrence';

  bool get _isPointEvent =>
      widget.initialTimeShape.trim().toLowerCase() == 'point';

  int get _effectiveDurationMinutes {
    if (_isPointEvent) {
      return 0;
    }
    final difference = _endAt.difference(_startAt).inMinutes;
    return difference <= 0 ? 1 : difference;
  }

  LingEventRecurrence? get _editedRecurrence {
    final frequency = switch (_recurrencePreset) {
      _EventEditorRecurrencePreset.daily => 'daily',
      _EventEditorRecurrencePreset.weekly => 'weekly',
      _EventEditorRecurrencePreset.monthly => 'monthly',
      _EventEditorRecurrencePreset.yearly => 'yearly',
      _EventEditorRecurrencePreset.none => '',
    };
    return buildLingEventEditorRecurrence(
      frequency: frequency,
      initialRecurrence: widget.initialRecurrence,
      startAt: _startAt,
      durationMinutes: _effectiveDurationMinutes,
      timezone: widget.timezone,
      weeklyRecurrenceDays: _weeklyRecurrenceDays,
    );
  }

  String? get _recurrenceSummary => formatLingRecurrenceDetailLabel(
    s,
    isRecurring: _editedRecurrence != null,
    recurrence: _editedRecurrence,
    anchorStartAt: _startAt,
  );

  String? get _recurrenceHint {
    if (_isEditingThisOccurrenceOnly) {
      return s.recurringOccurrenceRuleLockedHint;
    }
    if (_editedRecurrence != null) {
      return s.recurringSeriesRuleHint;
    }
    return null;
  }

  DateTime _currentMoment() {
    return DateTime.now();
  }

  DateTime? get _endTimePickerMinimumDate {
    if (!isSameCalendarDay(_startAt, _endAt)) {
      return null;
    }
    return _startAt;
  }

  DateTime _dateWithSelectedTime(DateTime value) {
    return DateTime(
      _startAt.year,
      _startAt.month,
      _startAt.day,
      value.hour,
      value.minute,
    );
  }

  DateTime _timeWithSelectedDate(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      _startAt.hour,
      _startAt.minute,
    );
  }

  DateTime _endDateWithSelectedTime(DateTime value) {
    return DateTime(
      _endAt.year,
      _endAt.month,
      _endAt.day,
      value.hour,
      value.minute,
    );
  }

  DateTime _endTimeWithSelectedDate(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      _endAt.hour,
      _endAt.minute,
    );
  }

  void _toggleInlinePicker(_EventEditorInlinePicker picker) {
    setState(() {
      _activePicker = _activePicker == picker
          ? _EventEditorInlinePicker.none
          : picker;
    });
  }

  void _ensureEndAfterStart() {
    if (_isPointEvent) {
      _endAt = _startAt;
      return;
    }
    if (_endAt.isAfter(_startAt)) {
      return;
    }
    _endAt = _startAt.add(const Duration(minutes: 1));
  }

  void _handleTimeSelectionTap({required bool isEndTime}) {
    _toggleInlinePicker(
      isEndTime
          ? _EventEditorInlinePicker.endTime
          : _EventEditorInlinePicker.startTime,
    );
  }

  @override
  void initState() {
    super.initState();
    _sheetDragAnimationController = AnimationController(
      vsync: this,
      duration: _sheetDragAnimationDuration,
    )..addListener(_handleSheetDragAnimationTick);
    _titleController = TextEditingController(text: widget.initialTitle);
    _locationController = TextEditingController(text: widget.initialLocation);
    _meetingUrlController = TextEditingController(
      text: widget.initialMeetingUrl,
    );
    _startAt = widget.initialStartAt;
    _endAt = widget.initialEndAt;
    _ensureEndAfterStart();
    _recurrencePreset = _presetFromRecurrence(widget.initialRecurrence);
    _weeklyRecurrenceDays = widget.initialRecurrence == null
        ? <String>{weekdayCodeForLingDate(_startAt)}
        : initialLingEventEditorWeeklyRecurrenceDays(
            widget.initialRecurrence!,
            _startAt,
          );
    _mutationScope = widget.initialMutationScope.trim().isEmpty
        ? 'series'
        : widget.initialMutationScope.trim();
  }

  @override
  void dispose() {
    _sheetDragAnimationController
      ..removeListener(_handleSheetDragAnimationTick)
      ..dispose();
    _titleController.dispose();
    _locationController.dispose();
    _meetingUrlController.dispose();
    super.dispose();
  }

  void _handleSheetDragAnimationTick() {
    final nextOffset = _sheetDragOffsetAnimation?.value;
    if (nextOffset == null || !mounted) {
      return;
    }
    setState(() {
      _sheetDragOffset = nextOffset;
    });
  }

  void _setRecurrencePreset(_EventEditorRecurrencePreset preset) {
    setState(() {
      _recurrencePreset = preset;
      if (preset == _EventEditorRecurrencePreset.weekly &&
          _weeklyRecurrenceDays.isEmpty) {
        _weeklyRecurrenceDays = <String>{weekdayCodeForLingDate(_startAt)};
      }
    });
  }

  void _toggleWeeklyRecurrenceDay(String code) {
    setState(() {
      if (_weeklyRecurrenceDays.contains(code)) {
        if (_weeklyRecurrenceDays.length == 1) {
          return;
        }
        _weeklyRecurrenceDays.remove(code);
        return;
      }
      _weeklyRecurrenceDays.add(code);
    });
  }

  void _setMutationScope(String value) {
    if (!widget.allowMutationScopeSelection) {
      return;
    }
    setState(() {
      _mutationScope = value;
    });
  }

  void _handleSheetVerticalDragStart(DragStartDetails details) {
    if (_isCompletingSheetDismiss) {
      return;
    }
    _sheetDragAnimationController.stop();
    _isAnimatingSheetBack = false;
    _isDraggingSheet = true;
  }

  void _handleSheetVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDraggingSheet || _isCompletingSheetDismiss) {
      return;
    }
    final primaryDelta = details.primaryDelta ?? 0;
    if (primaryDelta == 0) {
      return;
    }
    setState(() {
      _sheetDragOffset = (_sheetDragOffset + primaryDelta).clamp(
        0.0,
        double.infinity,
      );
    });
  }

  void _handleSheetVerticalDragEnd(DragEndDetails details, double sheetHeight) {
    if (!_isDraggingSheet || _isCompletingSheetDismiss) {
      _isDraggingSheet = false;
      return;
    }
    _isDraggingSheet = false;
    final shouldDismiss =
        details.primaryVelocity != null &&
            details.primaryVelocity! >= _sheetDismissVelocity ||
        (sheetHeight > 0 &&
            _sheetDragOffset / sheetHeight >= _sheetDismissProgress);
    if (shouldDismiss) {
      _completeSheetDismiss();
      return;
    }
    _animateSheetOffsetTo(0);
  }

  void _animateSheetOffsetTo(double target) {
    if (!mounted) {
      return;
    }
    _sheetDragOffsetAnimation =
        Tween<double>(begin: _sheetDragOffset, end: target).animate(
          CurvedAnimation(
            parent: _sheetDragAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _isAnimatingSheetBack = target == 0;
    _sheetDragAnimationController
      ..reset()
      ..forward().whenCompleteOrCancel(() {
        if (!mounted || !_isAnimatingSheetBack) {
          return;
        }
        setState(() {
          _sheetDragOffset = 0;
          _isAnimatingSheetBack = false;
        });
      });
  }

  void _completeSheetDismiss() {
    if (_isCompletingSheetDismiss || !mounted) {
      return;
    }
    _sheetDragAnimationController.stop();
    _isDraggingSheet = false;
    _isAnimatingSheetBack = false;
    _isCompletingSheetDismiss = true;
    _closeEditor();
  }

  void _closeEditor() {
    final onCancel = widget.onCancel;
    if (onCancel != null) {
      onCancel();
      return;
    }
    Navigator.of(context).pop();
  }

  void _submit() {
    _ensureEndAfterStart();
    final submission = buildLingEventEditorFormSubmission(
      strings: s,
      title: _titleController.text,
      location: _locationController.text,
      meetingUrl: _meetingUrlController.text,
      startAt: _startAt,
      durationMinutes: _effectiveDurationMinutes,
      timeShape: _isPointEvent ? 'point' : 'span',
      recurrence: _isEditingThisOccurrenceOnly ? null : _editedRecurrence,
      mutationScope: _mutationScope,
    );
    if (submission.hasErrors) {
      setState(() {
        _titleErrorText = submission.titleErrorText;
      });
      return;
    }
    final result = submission.result;
    if (result == null) {
      return;
    }
    final onSubmitResult = widget.onSubmitResult;
    if (onSubmitResult != null) {
      onSubmitResult(result);
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final bottomSafeAreaInset = mediaQuery.padding.bottom;
    final currentDate = _currentMoment();
    final panelMaxHeight = screenHeight * 0.78 < 720
        ? screenHeight * 0.78
        : 720.0;
    final availablePanelHeight = screenHeight - keyboardInset - 40;
    final panelHeight = availablePanelHeight < panelMaxHeight
        ? availablePanelHeight
        : panelMaxHeight;
    final recurrenceSummary = _recurrenceSummary;
    final recurrenceHint = _recurrenceHint;
    const editingFooterButtonHeight = 54.0;
    const editingFooterTopPadding = 16.0;
    const editingFooterBottomPadding = 12.0;
    final editingFooterReservedHeight =
        editingFooterTopPadding +
        editingFooterButtonHeight +
        editingFooterBottomPadding +
        bottomSafeAreaInset;
    final calendarTheme = theme.copyWith(
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        dividerColor: Colors.transparent,
        headerForegroundColor: palette.textPrimary,
        headerHeadlineStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
        weekdayStyle: theme.textTheme.bodyMedium?.copyWith(
          color: palette.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        subHeaderForegroundColor: palette.textSecondary,
        dayStyle: theme.textTheme.bodyMedium?.copyWith(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return palette.textSecondary.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return palette.primaryButtonForeground;
          }
          return palette.textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.primaryButtonBackground;
          }
          return Colors.transparent;
        }),
        dayOverlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return palette.accent.withValues(alpha: 0.18);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return palette.accent.withValues(alpha: 0.10);
          }
          return null;
        }),
        dayShape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.primaryButtonForeground;
          }
          return palette.accent;
        }),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.primaryButtonBackground;
          }
          return palette.accentSoft.withValues(alpha: 0.72);
        }),
        todayBorder: BorderSide(color: palette.accent.withValues(alpha: 0.85)),
      ),
    );

    final submitButton = LingAdaptiveFilledButton(
      key: const Key('quick_add_create_button'),
      onPressed: _submit,
      minHeight: editingFooterButtonHeight,
      child: Text(widget.submitLabel),
    );

    final sheetBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((recurrenceSummary ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _EventEditorRecurrenceBanner(
            strings: s,
            summary: recurrenceSummary!.trim(),
            hint: recurrenceHint,
          ),
        ],
        const SizedBox(height: 18),
        _EventEditorBasicFields(
          strings: s,
          titleController: _titleController,
          locationController: _locationController,
          meetingUrlController: _meetingUrlController,
          titleErrorText: _titleErrorText,
          onTitleChanged: (_) {
            if (_titleErrorText == null) {
              return;
            }
            setState(() {
              _titleErrorText = null;
            });
          },
        ),
        const SizedBox(height: 18),
        _EventEditorDateTimeSection(
          strings: s,
          startAt: _startAt,
          endAt: _endAt,
          isPoint: _isPointEvent,
          currentDate: currentDate,
          activePicker: _activePicker,
          calendarTheme: calendarTheme,
          endTimeMinimumDate: _endTimePickerMinimumDate,
          onToggleInlinePicker: _toggleInlinePicker,
          onStartTimeTap: () => _handleTimeSelectionTap(isEndTime: false),
          onEndTimeTap: () => _handleTimeSelectionTap(isEndTime: true),
          onStartDateChanged: (value) {
            setState(() {
              _startAt = _timeWithSelectedDate(value);
              _ensureEndAfterStart();
            });
          },
          onStartTimeChanged: (value) {
            setState(() {
              _startAt = _dateWithSelectedTime(value);
              _ensureEndAfterStart();
            });
          },
          onEndDateChanged: (value) {
            setState(() {
              _endAt = _endTimeWithSelectedDate(value);
              _ensureEndAfterStart();
            });
          },
          onEndTimeChanged: (value) {
            setState(() {
              _endAt = _endDateWithSelectedTime(value);
              _ensureEndAfterStart();
            });
          },
        ),
        _EventEditorRecurrenceSection(
          strings: s,
          allowMutationScopeSelection: widget.allowMutationScopeSelection,
          mutationScope: _mutationScope,
          onSelectMutationScope: _setMutationScope,
          recurrencePreset: _recurrencePreset,
          isEditingThisOccurrenceOnly: _isEditingThisOccurrenceOnly,
          onSelectRecurrencePreset: _setRecurrencePreset,
          weeklyRecurrenceDays: _weeklyRecurrenceDays,
          onToggleWeeklyRecurrenceDay: _toggleWeeklyRecurrenceDay,
        ),
        const SizedBox(height: 18),
        _EventEditorMetaStrip(
          notificationLabel: s.quickAddNotificationLabel,
          notificationValue: widget.notificationLabel,
          timezoneLabel: s.quickAddTimezoneLabel,
          timezoneValue: widget.timezone,
        ),
        SizedBox(height: widget.embedded ? 0 : editingFooterReservedHeight),
      ],
    );

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: sheetBody,
          ),
          _EventEditorEditingFooter(
            topPadding: editingFooterTopPadding,
            bottomPadding: editingFooterBottomPadding,
            child: submitButton,
          ),
        ],
      );
    }

    final sheetContainer = SizedBox(
      key: const Key('quick_add_sheet'),
      width: double.infinity,
      child: Column(
        children: [
          _EventEditorEditingHeader(
            title: widget.sheetTitle,
            onClose: _closeEditor,
            onVerticalDragStart: _handleSheetVerticalDragStart,
            onVerticalDragUpdate: _handleSheetVerticalDragUpdate,
            onVerticalDragEnd: (details) =>
                _handleSheetVerticalDragEnd(details, panelHeight),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: sheetBody,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _EventEditorEditingFooter(
                    topPadding: editingFooterTopPadding,
                    bottomPadding: editingFooterBottomPadding,
                    child: submitButton,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final alignedSheet = Align(
      alignment: Alignment.bottomCenter,
      child: ClipRect(
        child: Transform.translate(
          offset: Offset(0, _sheetDragOffset),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: panelHeight),
            child: sheetContainer,
          ),
        ),
      ),
    );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: alignedSheet,
    );
  }
}

_EventEditorRecurrencePreset _presetFromRecurrence(
  LingEventRecurrence? recurrence,
) {
  final frequency = recurrence?.frequency.trim().toLowerCase() ?? '';
  switch (frequency) {
    case 'daily':
      return _EventEditorRecurrencePreset.daily;
    case 'weekly':
      return _EventEditorRecurrencePreset.weekly;
    case 'monthly':
      return _EventEditorRecurrencePreset.monthly;
    case 'yearly':
      return _EventEditorRecurrencePreset.yearly;
    default:
      return _EventEditorRecurrencePreset.none;
  }
}

enum _EventEditorInlinePicker { none, startDate, startTime, endDate, endTime }

enum _EventEditorRecurrencePreset { none, daily, weekly, monthly, yearly }

class _EventEditorBasicFields extends StatelessWidget {
  const _EventEditorBasicFields({
    required this.strings,
    required this.titleController,
    required this.locationController,
    required this.meetingUrlController,
    required this.titleErrorText,
    required this.onTitleChanged,
  });

  final LingStrings strings;
  final TextEditingController titleController;
  final TextEditingController locationController;
  final TextEditingController meetingUrlController;
  final String? titleErrorText;
  final ValueChanged<String> onTitleChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        _EventEditorGlassField(
          errorText: titleErrorText,
          child: LingGlassTextField(
            key: const Key('quick_add_title_field'),
            controller: titleController,
            placeholder: strings.quickAddTitleLabel,
            prefixIcon: Icon(
              Icons.title_rounded,
              size: 19,
              color: palette.textSecondary,
            ),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            radius: 24,
            onChanged: onTitleChanged,
          ),
        ),
        const SizedBox(height: 12),
        LingGlassTextField(
          key: const Key('quick_add_location_field'),
          controller: locationController,
          placeholder: strings.quickAddLocationLabel,
          prefixIcon: Icon(
            Icons.place_outlined,
            size: 19,
            color: palette.textSecondary,
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          radius: 24,
        ),
        const SizedBox(height: 12),
        LingGlassTextField(
          key: const Key('quick_add_meeting_url_field'),
          controller: meetingUrlController,
          placeholder: strings.eventMeetingLabel,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          prefixIcon: Icon(
            Icons.link_rounded,
            size: 19,
            color: palette.textSecondary,
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          radius: 24,
        ),
      ],
    );
  }
}

class _EventEditorGlassField extends StatelessWidget {
  const _EventEditorGlassField({required this.child, this.errorText});

  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final errorText = this.errorText;
    if (errorText == null) {
      return child;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            errorText,
            style: TextStyle(
              color: context.palette.danger,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventEditorDateTimeSection extends StatelessWidget {
  const _EventEditorDateTimeSection({
    required this.strings,
    required this.startAt,
    required this.endAt,
    required this.isPoint,
    required this.currentDate,
    required this.activePicker,
    required this.calendarTheme,
    required this.endTimeMinimumDate,
    required this.onToggleInlinePicker,
    required this.onStartTimeTap,
    required this.onEndTimeTap,
    required this.onStartDateChanged,
    required this.onStartTimeChanged,
    required this.onEndDateChanged,
    required this.onEndTimeChanged,
  });

  final LingStrings strings;
  final DateTime startAt;
  final DateTime endAt;
  final bool isPoint;
  final DateTime currentDate;
  final _EventEditorInlinePicker activePicker;
  final ThemeData calendarTheme;
  final DateTime? endTimeMinimumDate;
  final ValueChanged<_EventEditorInlinePicker> onToggleInlinePicker;
  final VoidCallback onStartTimeTap;
  final VoidCallback onEndTimeTap;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onStartTimeChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<DateTime> onEndTimeChanged;

  @override
  Widget build(BuildContext context) {
    final selectedDateOnly = DateTime(startAt.year, startAt.month, startAt.day);
    final isStartDatePickerActive =
        activePicker == _EventEditorInlinePicker.startDate;
    final isStartTimePickerActive =
        activePicker == _EventEditorInlinePicker.startTime;
    final isEndDatePickerActive =
        !isPoint && activePicker == _EventEditorInlinePicker.endDate;
    final isEndTimePickerActive =
        !isPoint && activePicker == _EventEditorInlinePicker.endTime;

    return Column(
      children: [
        _EventEditorDateTimeGrid(
          children: [
            _EventEditorDateTimeField(
              key: const Key('quick_add_date_tile'),
              label: strings.quickAddDateLabel,
              value: formatLingDateYmd(startAt),
              icon: Icons.event_outlined,
              selected: isStartDatePickerActive,
              onTap: () =>
                  onToggleInlinePicker(_EventEditorInlinePicker.startDate),
            ),
            _EventEditorDateTimeField(
              key: const Key('quick_add_time_tile'),
              label: strings.quickAddStartTimeLabel,
              value: formatLingHourMinute(startAt),
              icon: Icons.schedule_rounded,
              selected: isStartTimePickerActive,
              onTap: onStartTimeTap,
            ),
            if (!isPoint)
              _EventEditorDateTimeField(
                key: const Key('quick_add_end_date_tile'),
                label: strings.quickAddEndDateLabel,
                value: formatLingDateYmd(endAt),
                icon: Icons.event_repeat_outlined,
                selected: isEndDatePickerActive,
                onTap: () =>
                    onToggleInlinePicker(_EventEditorInlinePicker.endDate),
              ),
            if (!isPoint)
              _EventEditorDateTimeField(
                key: const Key('quick_add_end_time_tile'),
                label: strings.quickAddEndTimeLabel,
                value: formatLingHourMinute(endAt),
                icon: Icons.more_time_rounded,
                selected: isEndTimePickerActive,
                onTap: onEndTimeTap,
              ),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: switch (activePicker) {
            _EventEditorInlinePicker.none => const SizedBox.shrink(),
            _EventEditorInlinePicker.startDate => Padding(
              key: const ValueKey('quick_add_start_date_picker'),
              padding: const EdgeInsets.only(top: 16),
              child: LingLabeledField(
                label: strings.quickAddDateLabel,
                child: Theme(
                  data: calendarTheme,
                  child: LingGlassSurface(
                    radius: 22,
                    tone: LingGlassSurfaceTone.muted,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: CalendarDatePicker(
                      key: const Key('quick_add_start_inline_calendar'),
                      initialDate: selectedDateOnly,
                      currentDate: currentDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      onDateChanged: onStartDateChanged,
                    ),
                  ),
                ),
              ),
            ),
            _EventEditorInlinePicker.startTime => Padding(
              key: const ValueKey('quick_add_start_time_picker'),
              padding: const EdgeInsets.only(top: 16),
              child: LingLabeledField(
                label: strings.quickAddDateTimePickerLabel,
                child: _EventEditorGlassTimePicker(
                  key: const Key('quick_add_start_time_picker'),
                  initialDateTime: startAt,
                  onDateTimeChanged: onStartTimeChanged,
                ),
              ),
            ),
            _EventEditorInlinePicker.endDate =>
              isPoint
                  ? const SizedBox.shrink()
                  : Padding(
                      key: const ValueKey('quick_add_end_date_picker'),
                      padding: const EdgeInsets.only(top: 16),
                      child: LingLabeledField(
                        label: strings.quickAddEndDateLabel,
                        child: Theme(
                          data: calendarTheme,
                          child: LingGlassSurface(
                            radius: 22,
                            tone: LingGlassSurfaceTone.muted,
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                            child: CalendarDatePicker(
                              key: const Key('quick_add_end_inline_calendar'),
                              initialDate: DateTime(
                                endAt.year,
                                endAt.month,
                                endAt.day,
                              ),
                              currentDate: currentDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              onDateChanged: onEndDateChanged,
                            ),
                          ),
                        ),
                      ),
                    ),
            _EventEditorInlinePicker.endTime =>
              isPoint
                  ? const SizedBox.shrink()
                  : Padding(
                      key: const ValueKey('quick_add_end_time_picker'),
                      padding: const EdgeInsets.only(top: 16),
                      child: LingLabeledField(
                        label: strings.quickAddEndTimeLabel,
                        child: _EventEditorGlassTimePicker(
                          key: const Key('quick_add_end_time_picker'),
                          initialDateTime: endAt,
                          minimumDate: endTimeMinimumDate,
                          onDateTimeChanged: onEndTimeChanged,
                        ),
                      ),
                    ),
          },
        ),
      ],
    );
  }
}

class _EventEditorGlassTimePicker extends StatefulWidget {
  const _EventEditorGlassTimePicker({
    super.key,
    required this.initialDateTime,
    required this.onDateTimeChanged,
    this.minimumDate,
  });

  final DateTime initialDateTime;
  final ValueChanged<DateTime> onDateTimeChanged;
  final DateTime? minimumDate;

  @override
  State<_EventEditorGlassTimePicker> createState() =>
      _EventEditorGlassTimePickerState();
}

class _EventEditorGlassTimePickerState
    extends State<_EventEditorGlassTimePicker> {
  late int _hour;
  late int _minute;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    final initial = _clampToMinimum(widget.initialDateTime);
    _hour = initial.hour;
    _minute = initial.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void didUpdateWidget(covariant _EventEditorGlassTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDateTime != widget.initialDateTime ||
        oldWidget.minimumDate != widget.minimumDate) {
      final next = _clampToMinimum(widget.initialDateTime);
      if (_hour == next.hour && _minute == next.minute) {
        return;
      }
      _hour = next.hour;
      _minute = next.minute;
      _hourController.jumpToItem(_hour);
      _minuteController.jumpToItem(_minute);
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  DateTime _candidate(int hour, int minute) {
    final base = widget.initialDateTime;
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  DateTime _clampToMinimum(DateTime value) {
    final minimum = widget.minimumDate;
    if (minimum != null && value.isBefore(minimum)) {
      return minimum;
    }
    return value;
  }

  void _emit({int? hour, int? minute}) {
    final nextHour = hour ?? _hour;
    final nextMinute = minute ?? _minute;
    final next = _clampToMinimum(_candidate(nextHour, nextMinute));
    setState(() {
      _hour = next.hour;
      _minute = next.minute;
    });
    widget.onDateTimeChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pickerTint = _eventEditorPickerTintFor(context, palette);
    return LingGlassSurface(
      height: 216,
      radius: 18,
      tone: LingGlassSurfaceTone.muted,
      tintColor: pickerTint,
      thickness: context.isDarkMode ? 16 : 22,
      blur: context.isDarkMode ? 6 : 7,
      chromaticAberration: context.isDarkMode ? 0.003 : 0.008,
      saturation: context.isDarkMode ? 1.0 : 1.08,
      lightIntensity: context.isDarkMode ? 0.44 : 0.78,
      ambientStrength: context.isDarkMode ? 0.28 : 0.42,
      refractiveIndex: context.isDarkMode ? 1.08 : 1.18,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _EventEditorWheel(
              controller: _hourController,
              itemCount: 24,
              selected: _hour,
              labelBuilder: (value) => value.toString().padLeft(2, '0'),
              onSelectedItemChanged: (value) => _emit(hour: value),
            ),
          ),
          Text(
            ':',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: _EventEditorWheel(
              controller: _minuteController,
              itemCount: 60,
              selected: _minute,
              labelBuilder: (value) => value.toString().padLeft(2, '0'),
              onSelectedItemChanged: (value) => _emit(minute: value),
            ),
          ),
        ],
      ),
    );
  }
}

Color _eventEditorPickerTintFor(BuildContext context, LingPalette palette) {
  return context.isDarkMode
      ? Color.lerp(
          palette.surfaceHigh,
          palette.backgroundElevated,
          0.18,
        )!.withValues(alpha: 0.94)
      : const Color(0xFFF8FAFC).withValues(alpha: 0.98);
}

class _EventEditorWheel extends StatelessWidget {
  const _EventEditorWheel({
    required this.controller,
    required this.itemCount,
    required this.selected,
    required this.labelBuilder,
    required this.onSelectedItemChanged,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final int selected;
  final String Function(int value) labelBuilder;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 42,
      diameterRatio: 1.3,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onSelectedItemChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, index) {
          final isSelected = index == selected;
          return Center(
            child: Text(
              labelBuilder(index),
              style: TextStyle(
                color: isSelected
                    ? palette.textPrimary
                    : palette.textSecondary.withValues(alpha: 0.54),
                fontSize: isSelected ? 22 : 18,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EventEditorDateTimeGrid extends StatelessWidget {
  const _EventEditorDateTimeGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSingleColumn = constraints.maxWidth < 340;
        final spacing = useSingleColumn ? 10.0 : 10.0;
        final itemWidth = useSingleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: 10,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _EventEditorDateTimeField extends StatelessWidget {
  const _EventEditorDateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = LingGlassPanel(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      radius: 20,
      tone: selected
          ? LingGlassSurfaceTone.regular
          : LingGlassSurfaceTone.muted,
      tintColor: selected ? _eventEditorPickerTintFor(context, palette) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? palette.accentSoft.withValues(alpha: 0.74)
                  : palette.surface.withValues(
                      alpha: context.isDarkMode ? 0.22 : 0.58,
                    ),
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                icon,
                size: 17,
                color: selected ? palette.accent : palette.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? palette.accent : palette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            selected
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: selected ? palette.accent : palette.textSecondary,
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

class _EventEditorMetaStrip extends StatelessWidget {
  const _EventEditorMetaStrip({
    required this.notificationLabel,
    required this.notificationValue,
    required this.timezoneLabel,
    required this.timezoneValue,
  });

  final String notificationLabel;
  final String notificationValue;
  final String timezoneLabel;
  final String timezoneValue;

  @override
  Widget build(BuildContext context) {
    return LingGlassPanel(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      radius: 20,
      tone: LingGlassSurfaceTone.muted,
      child: Column(
        children: [
          _EventEditorMetaRow(
            icon: Icons.notifications_none_rounded,
            label: notificationLabel,
            value: notificationValue,
          ),
          const SizedBox(height: 10),
          _EventEditorMetaRow(
            icon: Icons.public_rounded,
            label: timezoneLabel,
            value: timezoneValue,
          ),
        ],
      ),
    );
  }
}

class _EventEditorMetaRow extends StatelessWidget {
  const _EventEditorMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: palette.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: palette.textPrimary,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventEditorRecurrenceBanner extends StatelessWidget {
  const _EventEditorRecurrenceBanner({
    required this.strings,
    required this.summary,
    this.hint,
  });

  final LingStrings strings;
  final String summary;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final normalizedHint = (hint ?? '').trim();
    return Container(
      key: const Key('quick_add_recurrence_banner'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: palette.accentSoft.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.repeat_rounded, size: 18, color: palette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.eventRepeatsLabel,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.trim(),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (normalizedHint.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    normalizedHint,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventEditorRecurrenceSection extends StatelessWidget {
  const _EventEditorRecurrenceSection({
    required this.strings,
    required this.allowMutationScopeSelection,
    required this.mutationScope,
    required this.onSelectMutationScope,
    required this.recurrencePreset,
    required this.isEditingThisOccurrenceOnly,
    required this.onSelectRecurrencePreset,
    required this.weeklyRecurrenceDays,
    required this.onToggleWeeklyRecurrenceDay,
  });

  final LingStrings strings;
  final bool allowMutationScopeSelection;
  final String mutationScope;
  final ValueChanged<String> onSelectMutationScope;
  final _EventEditorRecurrencePreset recurrencePreset;
  final bool isEditingThisOccurrenceOnly;
  final ValueChanged<_EventEditorRecurrencePreset> onSelectRecurrencePreset;
  final Set<String> weeklyRecurrenceDays;
  final ValueChanged<String> onToggleWeeklyRecurrenceDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (allowMutationScopeSelection) ...[
          const SizedBox(height: 16),
          LingLabeledField(
            label: strings.recurringScopeLabel,
            child: _EventEditorSegmentedSelector(
              options: <_EventEditorSegmentOption>[
                _EventEditorSegmentOption(
                  key: const Key('quick_add_scope_occurrence'),
                  label: strings.recurringScopeThisEvent,
                  isSelected: mutationScope == 'occurrence',
                  onTap: () => onSelectMutationScope('occurrence'),
                ),
                _EventEditorSegmentOption(
                  key: const Key('quick_add_scope_series'),
                  label: strings.recurringScopeEntireSeries,
                  isSelected: mutationScope == 'series',
                  onTap: () => onSelectMutationScope('series'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        LingLabeledField(
          label: strings.eventRepeatsLabel,
          child: _EventEditorRecurrenceEditor(
            recurrencePreset: recurrencePreset,
            onSelectPreset: isEditingThisOccurrenceOnly
                ? null
                : onSelectRecurrencePreset,
            presetLabels: <_EventEditorRecurrencePreset, String>{
              _EventEditorRecurrencePreset.none: strings.recurringNoneOption,
              _EventEditorRecurrencePreset.daily: strings.recurringDailyOption,
              _EventEditorRecurrencePreset.weekly:
                  strings.recurringWeeklyOption,
              _EventEditorRecurrencePreset.monthly:
                  strings.recurringMonthlyOption,
              _EventEditorRecurrencePreset.yearly:
                  strings.recurringYearlyOption,
            },
            weekdayCodes: weeklyRecurrenceDays,
            onToggleWeekday: isEditingThisOccurrenceOnly
                ? null
                : onToggleWeeklyRecurrenceDay,
            weekdayLabels: <String, String>{
              for (final code in lingEventEditorWeekdayOrder)
                code: _weekdayLabel(strings, code),
            },
            weekdaySectionLabel: strings.recurringWeeklyDaysLabel,
            disabledHint: isEditingThisOccurrenceOnly
                ? strings.recurringOccurrenceRuleLockedHint
                : null,
          ),
        ),
      ],
    );
  }
}

class _EventEditorRecurrenceEditor extends StatelessWidget {
  const _EventEditorRecurrenceEditor({
    required this.recurrencePreset,
    required this.onSelectPreset,
    required this.presetLabels,
    required this.weekdayCodes,
    required this.onToggleWeekday,
    required this.weekdayLabels,
    required this.weekdaySectionLabel,
    this.disabledHint,
  });

  final _EventEditorRecurrencePreset recurrencePreset;
  final ValueChanged<_EventEditorRecurrencePreset>? onSelectPreset;
  final Map<_EventEditorRecurrencePreset, String> presetLabels;
  final Set<String> weekdayCodes;
  final ValueChanged<String>? onToggleWeekday;
  final Map<String, String> weekdayLabels;
  final String weekdaySectionLabel;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _EventEditorRecurrencePreset.values
              .map(
                (preset) => _EventEditorSelectionChip(
                  key: Key('quick_add_recurrence_${preset.name}'),
                  label: presetLabels[preset] ?? preset.name,
                  selected: recurrencePreset == preset,
                  onTap: onSelectPreset == null
                      ? null
                      : () => onSelectPreset!(preset),
                ),
              )
              .toList(growable: false),
        ),
        if ((disabledHint ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            disabledHint!.trim(),
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ] else if (recurrencePreset == _EventEditorRecurrencePreset.weekly) ...[
          const SizedBox(height: 12),
          Text(
            weekdaySectionLabel,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: lingEventEditorWeekdayOrder
                .map(
                  (code) => _EventEditorSelectionChip(
                    key: Key('quick_add_weekday_$code'),
                    label: weekdayLabels[code] ?? code,
                    selected: weekdayCodes.contains(code),
                    onTap: onToggleWeekday == null
                        ? null
                        : () => onToggleWeekday!(code),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _EventEditorSelectionChip extends StatelessWidget {
  const _EventEditorSelectionChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onTap != null;
    final foreground = selected ? palette.accent : palette.textSecondary;
    final background = selected
        ? palette.accentSoft.withValues(alpha: context.isDarkMode ? 0.5 : 0.72)
        : palette.controlSurface.withValues(
            alpha: context.isDarkMode ? 0.34 : 0.54,
          );
    final borderColor = selected
        ? palette.accent.withValues(alpha: context.isDarkMode ? 0.34 : 0.22)
        : palette.outlineSoft.withValues(
            alpha: context.isDarkMode ? 0.68 : 0.88,
          );

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventEditorSegmentOption {
  const _EventEditorSegmentOption({
    required this.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final Key key;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
}

class _EventEditorSegmentedSelector extends StatelessWidget {
  const _EventEditorSegmentedSelector({required this.options});

  final List<_EventEditorSegmentOption> options;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.outlineSoft),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: options
            .map(
              (option) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    key: option.key,
                    behavior: HitTestBehavior.opaque,
                    onTap: option.onTap,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: option.isSelected
                            ? palette.accentSoft.withValues(
                                alpha: context.isDarkMode ? 0.5 : 0.72,
                              )
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        child: Text(
                          option.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: option.isSelected
                                ? palette.accent
                                : palette.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _EventEditorEditingHeader extends StatelessWidget {
  const _EventEditorEditingHeader({
    required this.title,
    required this.onClose,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
  });

  final String title;
  final VoidCallback onClose;
  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      key: const Key('quick_add_edit_header'),
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: onVerticalDragStart,
      onVerticalDragUpdate: onVerticalDragUpdate,
      onVerticalDragEnd: onVerticalDragEnd,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: LingGlassSurface(
                key: const Key('quick_add_edit_header_drag_handle'),
                width: 42,
                height: 4,
                radius: 999,
                tone: LingGlassSurfaceTone.muted,
                tintColor: palette.outlineSoft,
                child: const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 22,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                LingGlassIconButton(
                  icon: Icons.close_rounded,
                  onPressed: onClose,
                  semanticLabel: MaterialLocalizations.of(
                    context,
                  ).closeButtonTooltip,
                  iconColor: palette.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventEditorEditingFooter extends StatelessWidget {
  const _EventEditorEditingFooter({
    required this.topPadding,
    required this.bottomPadding,
    required this.child,
  });

  final double topPadding;
  final double bottomPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      key: const Key('quick_add_edit_footer'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.surface.withValues(alpha: 0),
            palette.surface.withValues(alpha: 0.88),
            palette.surface,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, topPadding, 20, bottomPadding),
          child: child,
        ),
      ),
    );
  }
}

String _weekdayLabel(LingStrings strings, String code) {
  switch (code) {
    case 'MO':
      return strings.weekdayShort(1);
    case 'TU':
      return strings.weekdayShort(2);
    case 'WE':
      return strings.weekdayShort(3);
    case 'TH':
      return strings.weekdayShort(4);
    case 'FR':
      return strings.weekdayShort(5);
    case 'SA':
      return strings.weekdayShort(6);
    case 'SU':
      return strings.weekdayShort(7);
  }
  return code;
}
