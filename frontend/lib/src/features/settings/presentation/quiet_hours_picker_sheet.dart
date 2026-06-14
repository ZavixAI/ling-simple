import 'package:flutter/material.dart';

import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

class QuietHoursPickerResult {
  const QuietHoursPickerResult({required this.start, required this.end});

  final String start;
  final String end;
}

Future<QuietHoursPickerResult?> showLingQuietHoursPickerSheet({
  required BuildContext context,
  required LingStrings strings,
  required String initialStart,
  required String initialEnd,
}) {
  return showLingAdaptiveSheet<QuietHoursPickerResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: _QuietHoursPickerBody(
          strings: strings,
          initialStart: initialStart,
          initialEnd: initialEnd,
        ),
      );
    },
  );
}

class _QuietHoursPickerBody extends StatefulWidget {
  const _QuietHoursPickerBody({
    required this.strings,
    required this.initialStart,
    required this.initialEnd,
  });

  final LingStrings strings;
  final String initialStart;
  final String initialEnd;

  @override
  State<_QuietHoursPickerBody> createState() => _QuietHoursPickerBodyState();
}

class _QuietHoursPickerBodyState extends State<_QuietHoursPickerBody> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = _parseHHmm(widget.initialStart);
    _end = _parseHHmm(widget.initialEnd);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final strings = widget.strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            alignment: Alignment.center,
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              strings.quietHoursPickerTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildLabel(palette, strings.quietHoursStartLabel),
          const SizedBox(height: 4),
          _buildPicker(
            key: const Key('quiet_hours_start_picker'),
            value: _start,
            onChanged: (value) => setState(() => _start = value),
          ),
          const SizedBox(height: 16),
          _buildLabel(palette, strings.quietHoursEndLabel),
          const SizedBox(height: 4),
          _buildPicker(
            key: const Key('quiet_hours_end_picker'),
            value: _end,
            onChanged: (value) => setState(() => _end = value),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: LingAdaptiveFilledButton(
                  key: const Key('quiet_hours_cancel_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  minHeight: 48,
                  backgroundColor: palette.glassMutedTint,
                  foregroundColor: palette.textPrimary,
                  child: Text(strings.quietHoursCancelAction),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LingAdaptiveFilledButton(
                  key: const Key('quiet_hours_save_button'),
                  minHeight: 48,
                  onPressed: () {
                    Navigator.of(context).pop(
                      QuietHoursPickerResult(
                        start: _formatHHmm(_start),
                        end: _formatHHmm(_end),
                      ),
                    );
                  },
                  child: Text(strings.quietHoursSaveAction),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(LingPalette palette, String text) {
    return Text(
      text,
      style: TextStyle(
        color: palette.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildPicker({
    required Key key,
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) {
    return _QuietHoursGlassTimePicker(
      key: key,
      value: value,
      onChanged: onChanged,
    );
  }
}

class _QuietHoursGlassTimePicker extends StatefulWidget {
  const _QuietHoursGlassTimePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_QuietHoursGlassTimePicker> createState() =>
      _QuietHoursGlassTimePickerState();
}

class _QuietHoursGlassTimePickerState
    extends State<_QuietHoursGlassTimePicker> {
  late int _hour;
  late int _minuteIndex;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _setFromValue(widget.value);
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minuteIndex);
  }

  @override
  void didUpdateWidget(covariant _QuietHoursGlassTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _setFromValue(widget.value);
      _hourController.jumpToItem(_hour);
      _minuteController.jumpToItem(_minuteIndex);
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _setFromValue(DateTime value) {
    _hour = value.hour;
    _minuteIndex = (value.minute / 5).round().clamp(0, 11);
  }

  void _emit({int? hour, int? minuteIndex}) {
    final nextHour = hour ?? _hour;
    final nextMinuteIndex = minuteIndex ?? _minuteIndex;
    setState(() {
      _hour = nextHour;
      _minuteIndex = nextMinuteIndex;
    });
    final base = widget.value;
    widget.onChanged(
      DateTime(base.year, base.month, base.day, nextHour, nextMinuteIndex * 5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LingGlassSurface(
      height: 168,
      radius: 16,
      tone: LingGlassSurfaceTone.muted,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _QuietHoursWheel(
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
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: _QuietHoursWheel(
              controller: _minuteController,
              itemCount: 12,
              selected: _minuteIndex,
              labelBuilder: (value) => (value * 5).toString().padLeft(2, '0'),
              onSelectedItemChanged: (value) => _emit(minuteIndex: value),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietHoursWheel extends StatelessWidget {
  const _QuietHoursWheel({
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
      itemExtent: 38,
      diameterRatio: 1.25,
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
                fontSize: isSelected ? 20 : 17,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }
}

DateTime _parseHHmm(String value) {
  final parts = value.split(':');
  final now = DateTime.now();
  if (parts.length != 2) {
    return DateTime(now.year, now.month, now.day, 22, 0);
  }
  final hour = int.tryParse(parts[0]) ?? 22;
  final minute = int.tryParse(parts[1]) ?? 0;
  return DateTime(
    now.year,
    now.month,
    now.day,
    hour.clamp(0, 23),
    minute.clamp(0, 59),
  );
}

String _formatHHmm(DateTime value) {
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
