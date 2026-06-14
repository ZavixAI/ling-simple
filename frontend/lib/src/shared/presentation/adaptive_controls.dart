import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/tap_haptics.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class LingAdaptiveSegmentOption<T> {
  const LingAdaptiveSegmentOption({required this.value, required this.child});

  final T value;
  final Widget child;
}

class LingAdaptiveSegmentedControl<T extends Object> extends StatefulWidget {
  const LingAdaptiveSegmentedControl({
    super.key,
    required this.groupValue,
    required this.onValueChanged,
    required this.segments,
    this.padding = const EdgeInsets.all(3),
    this.commitDelay = Duration.zero,
  });

  final T groupValue;
  final ValueChanged<T> onValueChanged;
  final List<LingAdaptiveSegmentOption<T>> segments;
  final EdgeInsetsGeometry padding;
  final Duration commitDelay;

  @override
  State<LingAdaptiveSegmentedControl<T>> createState() =>
      _LingAdaptiveSegmentedControlState<T>();
}

class _LingAdaptiveSegmentedControlState<T extends Object>
    extends State<LingAdaptiveSegmentedControl<T>> {
  Timer? _duplicateSelectionTimer;
  Timer? _commitSelectionTimer;
  int? _recentlyEmittedIndex;
  int? _visualSelectedIndex;

  @override
  void dispose() {
    _duplicateSelectionTimer?.cancel();
    _commitSelectionTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LingAdaptiveSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupValue != widget.groupValue) {
      _visualSelectedIndex = null;
    }
  }

  void _handleSegmentSelected(int index) {
    final segment = index >= 0 && index < widget.segments.length
        ? widget.segments[index]
        : null;
    if (segment == null || _recentlyEmittedIndex == index) {
      return;
    }
    _recentlyEmittedIndex = index;
    _duplicateSelectionTimer?.cancel();
    _duplicateSelectionTimer = Timer(const Duration(milliseconds: 120), () {
      _recentlyEmittedIndex = null;
    });
    setState(() {
      _visualSelectedIndex = index;
    });
    final emitSelection = LingTapHaptics.wrapValueChanged(
      widget.onValueChanged,
    );
    _commitSelectionTimer?.cancel();
    if (widget.commitDelay == Duration.zero) {
      emitSelection?.call(segment.value);
      return;
    }
    _commitSelectionTimer = Timer(widget.commitDelay, () {
      if (!mounted) {
        return;
      }
      emitSelection?.call(segment.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    final selectedIndex = widget.segments.indexWhere(
      (segment) => segment.value == widget.groupValue,
    );
    final clampedSelectedIndex = selectedIndex < 0 ? 0 : selectedIndex;
    final visualSelectedIndex = _visualSelectedIndex ?? clampedSelectedIndex;
    final labels = [
      for (final segment in widget.segments) _segmentLabel(segment),
    ];
    return LingGlassLayer(
      tone: LingGlassSurfaceTone.control,
      quality: LingGlassQuality.premium,
      blend: 12,
      tintColor: isDark
          ? palette.glassMutedTint.withValues(alpha: 0.72)
          : lingGlassControlTintFor(context, palette),
      thickness: isDark ? 22 : 30,
      blur: isDark ? 7 : 5,
      saturation: isDark ? 1.04 : 1.18,
      child: LingGlassBlendGroup(
        blend: 12,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withValues(alpha: isDark ? 0.16 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SizedBox(
            height: 38,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = widget.padding.horizontal;
                final verticalPadding = widget.padding.vertical;
                final availableWidth = constraints.maxWidth - horizontalPadding;
                final availableHeight = constraints.maxHeight - verticalPadding;
                final segmentWidth = availableWidth / widget.segments.length;
                final selectedBorderColor = isDark
                    ? Colors.white.withValues(alpha: 0.24)
                    : palette.outlineSoft.withValues(alpha: 0.58);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: LingGlassSurface(
                        radius: 22,
                        padding: widget.padding,
                        tone: LingGlassSurfaceTone.control,
                        quality: LingGlassQuality.premium,
                        useOwnLayer: false,
                        tintColor: isDark
                            ? palette.glassMutedTint.withValues(alpha: 0.72)
                            : lingGlassControlTintFor(context, palette),
                        thickness: isDark ? 22 : 30,
                        blur: isDark ? 7 : 5,
                        saturation: isDark ? 1.04 : 1.18,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      left:
                          widget.padding
                              .resolve(Directionality.of(context))
                              .left +
                          segmentWidth * visualSelectedIndex,
                      top: widget.padding
                          .resolve(Directionality.of(context))
                          .top,
                      width: segmentWidth,
                      height: availableHeight,
                      child: LingGlassSurface(
                        radius: 20,
                        tone: LingGlassSurfaceTone.elevated,
                        quality: LingGlassQuality.premium,
                        useOwnLayer: false,
                        tintColor: isDark
                            ? palette.glassElevatedTint.withValues(alpha: 0.96)
                            : palette.surface.withValues(alpha: 0.62),
                        thickness: isDark ? 18 : 26,
                        blur: isDark ? 5 : 2,
                        saturation: isDark ? 1.04 : 1.22,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selectedBorderColor,
                              width: isDark ? 1.1 : 0.8,
                            ),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: widget.padding,
                        child: Row(
                          children: [
                            for (
                              var index = 0;
                              index < widget.segments.length;
                              index++
                            )
                              Expanded(
                                child: _SegmentButton(
                                  label: labels[index],
                                  selected: visualSelectedIndex == index,
                                  onTap: () => _handleSegmentSelected(index),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isDark
                                  ? palette.outlineSoft.withValues(alpha: 0.58)
                                  : palette.outlineSoft.withValues(alpha: 0.72),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _segmentLabel(LingAdaptiveSegmentOption<T> segment) {
    final child = segment.child;
    if (child is Text && child.data != null) {
      return child.data!;
    }
    return segment.value.toString();
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: selected
                  ? palette.textPrimary
                  : palette.textSecondary.withValues(
                      alpha: context.isDarkMode ? 1 : 0.9,
                    ),
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}

class LingAdaptiveSwitch extends StatelessWidget {
  const LingAdaptiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onChanged != null;
    final isDarkMode = context.isDarkMode;
    final inactiveTrackColor = isDarkMode
        ? palette.glassMutedTint
        : palette.fieldBorder.withValues(alpha: 0.92);
    final inactiveBorderColor = isDarkMode
        ? palette.outlineSoft.withValues(alpha: 0.82)
        : palette.outlineSoft.withValues(alpha: 0.92);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            AnimatedOpacity(
              opacity: value ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: inactiveTrackColor,
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow.withValues(
                        alpha: isDarkMode ? 0.18 : 0.08,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const SizedBox(width: 58, height: 26),
              ),
            ),
            GlassSwitch(
              value: value,
              onChanged: LingTapHaptics.wrapValueChanged(onChanged) ?? (_) {},
              activeColor: palette.primaryButtonBackground,
              inactiveColor: Colors.transparent,
              thumbColor: palette.primaryButtonForeground,
              settings: lingGlassSettingsFor(
                context,
                LingGlassSurfaceTone.muted,
              ),
              useOwnLayer: true,
              quality: GlassQuality.standard,
            ),
            IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 58,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: value ? Colors.transparent : inactiveBorderColor,
                    width: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LingAdaptiveFilledButton extends StatelessWidget {
  const LingAdaptiveFilledButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.minHeight = 54,
    this.expand = true,
    this.backgroundColor,
    this.foregroundColor,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double minHeight;
  final bool expand;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isPrimary = backgroundColor == null;
    final resolvedForeground =
        foregroundColor ??
        (isPrimary ? palette.primaryButtonForeground : palette.textPrimary);
    final resolvedDisabledForeground =
        disabledForegroundColor ??
        (isPrimary
            ? palette.primaryButtonDisabledForeground
            : resolvedForeground.withValues(alpha: 0.72));
    final resolvedTint = backgroundColor ?? palette.primaryButtonBackground;
    final resolvedDisabledTint =
        disabledBackgroundColor ??
        backgroundColor?.withValues(alpha: 0.34) ??
        palette.primaryButtonDisabledBackground;
    final childWrapper = SizedBox(
      width: expand ? double.infinity : null,
      child: Align(alignment: Alignment.center, child: child),
    );

    return LingGlassButton(
      onPressed: onPressed,
      minHeight: minHeight,
      expand: expand,
      radius: borderRadius?.topLeft.x ?? 24,
      tone: isPrimary
          ? LingGlassSurfaceTone.accent
          : LingGlassSurfaceTone.muted,
      foregroundColor: resolvedForeground,
      disabledForegroundColor: resolvedDisabledForeground,
      tintColor: resolvedTint,
      disabledTintColor: resolvedDisabledTint,
      child: childWrapper,
    );
  }
}

class LingAdaptiveActionSheetAction<T> {
  const LingAdaptiveActionSheetAction({
    required this.value,
    required this.label,
    this.icon,
    this.isDestructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool isDestructive;
}

Future<T?> showLingAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  EdgeInsets margin = EdgeInsets.zero,
}) {
  return GlassSheet.show<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    showDragIndicator: false,
    margin: margin,
    padding: EdgeInsets.zero,
    isScrollable: false,
    barrierColor: context.palette.scrim.withValues(alpha: 0.18),
    settings: lingGlassSettingsFor(context, LingGlassSurfaceTone.elevated),
    quality: GlassQuality.standard,
    interactionScale: 1,
    stretch: 0,
    enableInteractionGlow: false,
    enableSaturationGlow: false,
    suppressInteractionOnChildren: true,
    builder: (sheetContext) {
      final textTheme = Theme.of(sheetContext).textTheme;
      final sheetPalette = sheetContext.palette;
      final defaultTextStyle =
          (textTheme.bodyMedium ?? TextStyle(color: sheetPalette.textPrimary))
              .copyWith(
                color: textTheme.bodyMedium?.color ?? sheetPalette.textPrimary,
                decoration: TextDecoration.none,
              );
      return DefaultTextStyle(
        style: defaultTextStyle,
        child: GlassInteractionSilence(child: builder(sheetContext)),
      );
    },
  );
}

Future<bool?> showLingAdaptiveConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? detailMessage,
  required String cancelLabel,
  required String confirmLabel,
  bool isDestructive = false,
}) {
  final palette = context.palette;
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: palette.scrim.withValues(alpha: 0.28),
    builder: (dialogContext) => _LingAdaptiveConfirmationDialog(
      title: title,
      message: message,
      detailMessage: detailMessage,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      isDestructive: isDestructive,
      onCancel: () => Navigator.of(dialogContext).pop(false),
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
}

class _LingAdaptiveConfirmationDialog extends StatelessWidget {
  const _LingAdaptiveConfirmationDialog({
    required this.title,
    required this.message,
    required this.detailMessage,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.isDestructive,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String? detailMessage;
  final String cancelLabel;
  final String confirmLabel;
  final bool isDestructive;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final confirmTint = isDestructive
        ? palette.destructiveButtonBackground
        : palette.primaryButtonBackground;
    final confirmForeground = isDestructive
        ? palette.destructiveButtonForeground
        : palette.primaryButtonForeground;

    return Dialog(
      key: const Key('ling_adaptive_confirmation_dialog'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 44, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: LingGlassSurface(
          tone: LingGlassSurfaceTone.elevated,
          radius: 24,
          tintColor: lingGlassPanelTintFor(context, palette),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                key: const Key('ling_adaptive_confirmation_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 18,
                  height: 1.24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                key: const Key('ling_adaptive_confirmation_message'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 14,
                  height: 1.42,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (detailMessage != null && detailMessage!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  detailMessage!,
                  key: const Key('ling_adaptive_confirmation_detail_message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textTertiary,
                    fontSize: 12,
                    height: 1.38,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _LingConfirmationActionButton(
                      textKey: const Key(
                        'ling_adaptive_confirmation_cancel_label',
                      ),
                      label: cancelLabel,
                      onPressed: onCancel,
                      foregroundColor: palette.textPrimary,
                      tone: LingGlassSurfaceTone.muted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LingConfirmationActionButton(
                      textKey: const Key(
                        'ling_adaptive_confirmation_confirm_label',
                      ),
                      label: confirmLabel,
                      onPressed: onConfirm,
                      foregroundColor: confirmForeground,
                      tintColor: confirmTint,
                      tone: LingGlassSurfaceTone.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LingConfirmationActionButton extends StatelessWidget {
  const _LingConfirmationActionButton({
    required this.textKey,
    required this.label,
    required this.onPressed,
    required this.foregroundColor,
    required this.tone,
    this.tintColor,
  });

  final Key textKey;
  final String label;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final LingGlassSurfaceTone tone;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    return LingGlassButton(
      onPressed: onPressed,
      minHeight: 44,
      radius: 14,
      tone: tone,
      tintColor: tintColor,
      foregroundColor: foregroundColor,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          key: textKey,
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: foregroundColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

Future<T?> showLingAdaptiveActionSheet<T>({
  required BuildContext context,
  required String title,
  String? message,
  required String cancelLabel,
  required List<LingAdaptiveActionSheetAction<T>> actions,
}) {
  final palette = context.palette;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: palette.scrim.withValues(alpha: 0.28),
    isScrollControlled: false,
    useSafeArea: true,
    builder: (sheetContext) {
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.86;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LingGlassSurface(
                    radius: 18,
                    tone: LingGlassSurfaceTone.elevated,
                    padding: EdgeInsets.zero,
                    tintColor: _adaptiveSheetTintFor(sheetContext),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title.trim().isNotEmpty || message != null)
                          _LingActionSheetHeader(
                            title: title,
                            message: message,
                          ),
                        for (
                          var index = 0;
                          index < actions.length;
                          index++
                        ) ...[
                          if (index > 0 ||
                              title.trim().isNotEmpty ||
                              message != null)
                            Divider(
                              height: 1,
                              thickness: 0.5,
                              color: palette.outline.withValues(alpha: 0.18),
                            ),
                          _LingActionSheetButton<T>(
                            action: actions[index],
                            onSelected: (value) =>
                                Navigator.of(sheetContext).pop(value),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  LingGlassSurface(
                    radius: 18,
                    tone: LingGlassSurfaceTone.elevated,
                    tintColor: _adaptiveSheetTintFor(sheetContext),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: LingTapHaptics.wrap(
                        () => Navigator.of(sheetContext).pop(),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: Center(
                          child: Text(
                            cancelLabel,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Color _adaptiveSheetTintFor(BuildContext context) {
  final palette = context.palette;
  return lingGlassPanelTintFor(context, palette);
}

class _LingActionSheetHeader extends StatelessWidget {
  const _LingActionSheetHeader({required this.title, this.message});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        children: [
          if (title.trim().isNotEmpty)
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (message case final value?) ...[
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LingActionSheetButton<T> extends StatelessWidget {
  const _LingActionSheetButton({
    required this.action,
    required this.onSelected,
  });

  final LingAdaptiveActionSheetAction<T> action;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = action.isDestructive
        ? palette.danger
        : palette.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: LingTapHaptics.wrap(() => onSelected(action.value)),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (action.icon case final icon?) ...[
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 10),
            ],
            Text(
              action.label,
              style: TextStyle(
                color: foreground,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LingSettingsPickerOption<T extends Object> {
  const LingSettingsPickerOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;
  final String? subtitle;
}

class LingSettingsOptionList<T extends Object> extends StatelessWidget {
  const LingSettingsOptionList({
    super.key,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final T selected;
  final List<LingSettingsPickerOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        for (var index = 0; index < options.length; index++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _LingSettingsOptionRow<T>(
              option: options[index],
              isSelected: options[index].value == selected,
              onSelected: onChanged,
            ),
          ),
          if (index < options.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GlassDivider(
                color: palette.outlineSoft.withValues(alpha: 0.5),
              ),
            ),
        ],
      ],
    );
  }
}

Future<T?> showLingSettingsOptionSheet<T extends Object>({
  required BuildContext context,
  required String title,
  required String cancelLabel,
  required T selected,
  required List<LingSettingsPickerOption<T>> options,
  bool showTitle = true,
  bool showCancelButton = true,
}) {
  final maxHeight = MediaQuery.sizeOf(context).height * 0.62;
  return GlassSheet.show<T>(
    context: context,
    showDragIndicator: true,
    margin: EdgeInsets.only(
      left: 10,
      right: 10,
      bottom: MediaQuery.viewPaddingOf(context).bottom + 8,
    ),
    padding: EdgeInsets.zero,
    isScrollable: false,
    topBorderRadius: 28,
    settings: lingGlassSettingsFor(
      context,
      LingGlassSurfaceTone.elevated,
      tintColor: _settingsOptionSheetTintFor(context),
      thickness: context.isDarkMode ? 16 : 22,
      blur: context.isDarkMode ? 6 : 7,
      chromaticAberration: context.isDarkMode ? 0.003 : 0.008,
      saturation: context.isDarkMode ? 1.0 : 1.08,
      lightIntensity: context.isDarkMode ? 0.44 : 0.78,
      ambientStrength: context.isDarkMode ? 0.28 : 0.42,
      refractiveIndex: context.isDarkMode ? 1.08 : 1.18,
    ),
    quality: GlassQuality.standard,
    interactionScale: 1,
    stretch: 0,
    enableInteractionGlow: false,
    enableSaturationGlow: false,
    suppressInteractionOnChildren: true,
    builder: (sheetContext) {
      final palette = sheetContext.palette;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTitle && title.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(
                  12,
                  showTitle && title.trim().isNotEmpty ? 0 : 8,
                  12,
                  showCancelButton ? 16 : 12,
                ),
                physics: const ClampingScrollPhysics(),
                itemCount: options.length,
                separatorBuilder: (_, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GlassDivider(
                    color: palette.outlineSoft.withValues(alpha: 0.5),
                  ),
                ),
                itemBuilder: (context, index) {
                  final opt = options[index];
                  final isSelected = opt.value == selected;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _LingSettingsOptionRow<T>(
                      option: opt,
                      isSelected: isSelected,
                      onSelected: (value) =>
                          Navigator.of(sheetContext).pop(value),
                    ),
                  );
                },
              ),
            ),
            if (showCancelButton)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: LingGlassButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  minHeight: 48,
                  tone: LingGlassSurfaceTone.muted,
                  foregroundColor: palette.textPrimary,
                  child: Text(cancelLabel),
                ),
              ),
          ],
        ),
      );
    },
  );
}

Color _settingsOptionSheetTintFor(BuildContext context) {
  final palette = context.palette;
  return context.isDarkMode
      ? palette.surface.withValues(alpha: 0.96)
      : palette.surface.withValues(alpha: 0.98);
}

class _LingSettingsOptionRow<T extends Object> extends StatelessWidget {
  const _LingSettingsOptionRow({
    required this.option,
    required this.isSelected,
    required this.onSelected,
  });

  final LingSettingsPickerOption<T> option;
  final bool isSelected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tintColor = isSelected
        ? (context.isDarkMode
              ? palette.accentSoft.withValues(alpha: 0.94)
              : Colors.transparent)
        : palette.controlSurface.withValues(
            alpha: context.isDarkMode ? 0.34 : 0,
          );
    final borderColor = isSelected
        ? palette.accent.withValues(alpha: context.isDarkMode ? 0.68 : 0.82)
        : palette.outlineSoft.withValues(
            alpha: context.isDarkMode ? 0.62 : 0.84,
          );
    final selectedMarkerColor = palette.primaryButtonBackground;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: LingTapHaptics.wrap(() => onSelected(option.value)),
      child: LingGlassSurface(
        constraints: BoxConstraints(
          minHeight: (option.subtitle ?? '').trim().isEmpty ? 50 : 66,
        ),
        radius: 18,
        tone: LingGlassSurfaceTone.muted,
        tintColor: tintColor,
        thickness: context.isDarkMode ? 12 : 18,
        blur: context.isDarkMode ? 5 : 6,
        chromaticAberration: context.isDarkMode ? 0.002 : 0.006,
        saturation: context.isDarkMode ? 1.0 : 1.04,
        lightIntensity: context.isDarkMode ? 0.38 : 0.68,
        ambientStrength: context.isDarkMode ? 0.24 : 0.34,
        refractiveIndex: context.isDarkMode ? 1.06 : 1.14,
        padding: EdgeInsets.zero,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 4,
                  height: 24,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? selectedMarkerColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: palette.textPrimary,
                        ),
                      ),
                      if ((option.subtitle ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          option.subtitle!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: selectedMarkerColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: palette.primaryButtonForeground,
                    ),
                  )
                else
                  const SizedBox(width: 20, height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
