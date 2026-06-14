import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/calendar/models/apple_calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/presentation/schedule_view_models.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

const double _scheduleAgendaCardRadius = 24;
const Color _scheduleCurrentTimeGreen = Color(0xFF34C759);

class LingScheduleAgendaCard extends StatelessWidget {
  const LingScheduleAgendaCard({
    super.key,
    required this.item,
    required this.onEditLingEvent,
    required this.onDeleteLingEvent,
    required this.onDeleteAppleEvent,
    this.currentTimeProgress,
    this.bottomSpacing = 10,
  });

  final LingScheduleAgendaItem item;
  final ValueChanged<LingEvent> onEditLingEvent;
  final ValueChanged<LingEvent> onDeleteLingEvent;
  final ValueChanged<AppleCalendarEvent> onDeleteAppleEvent;
  final double? currentTimeProgress;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final event = item.lingEvent;
    final appleEvent = item.appleEvent;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: _SwipeRevealDelete(
        identity:
            event?.eventId ??
            appleEvent?.calendarItemIdentifier ??
            appleEvent?.identifier ??
            '${item.startAt.microsecondsSinceEpoch}-${item.title}',
        enabled: item.isDeletable && (event != null || appleEvent != null),
        borderRadius: BorderRadius.circular(_scheduleAgendaCardRadius),
        onDelete: event != null
            ? () => onDeleteLingEvent(event)
            : appleEvent == null
            ? null
            : () => onDeleteAppleEvent(appleEvent),
        child: _ScheduleEventTile(
          item: item,
          currentTimeProgress: currentTimeProgress,
          onEditLingEvent: onEditLingEvent,
        ),
      ),
    );
  }
}

class _ScheduleEventTile extends StatelessWidget {
  const _ScheduleEventTile({
    required this.item,
    required this.onEditLingEvent,
    this.currentTimeProgress,
  });

  final LingScheduleAgendaItem item;
  final ValueChanged<LingEvent> onEditLingEvent;
  final double? currentTimeProgress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    final isEditable = item.isEditableLingEvent;
    final hasContentMeta =
        item.subtitle.isNotEmpty ||
        item.location.isNotEmpty ||
        item.categoryLabel.isNotEmpty ||
        item.sourceLabel.isNotEmpty ||
        item.recurrenceLabel.isNotEmpty;
    final hasMetaBlock = hasContentMeta;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactWidth = constraints.maxWidth < 340;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isEditable ? () => onEditLingEvent(item.lingEvent!) : null,
          child: Container(
            foregroundDecoration: isDark
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      _scheduleAgendaCardRadius,
                    ),
                    border: Border.all(
                      color: palette.glassBorder.withValues(alpha: 0.3),
                    ),
                  )
                : null,
            child: GlassCard(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: const LiquidRoundedSuperellipse(
                borderRadius: _scheduleAgendaCardRadius,
              ),
              settings: _scheduleAgendaCardGlassSettings(context, palette),
              useOwnLayer: true,
              quality: GlassQuality.standard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AgendaTimeColumn(
                        item: item,
                        isCompactWidth: isCompactWidth,
                        hasMetaBlock: hasMetaBlock,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _AgendaAccentDot(
                                  color: item.accent,
                                  isActive: currentTimeProgress != null,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.22,
                                      fontWeight: FontWeight.w800,
                                      color: palette.textPrimary,
                                      fontFamily: 'Plus Jakarta Sans',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (item.subtitle.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.only(left: 20),
                                child: Text(
                                  item.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                            if (item.location.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.only(left: 20),
                                child: _AgendaMetaText(
                                  icon: Icons.place_outlined,
                                  label: item.location,
                                ),
                              ),
                            ],
                            if (hasContentMeta) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 20),
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 6,
                                  children: [
                                    if (item.categoryLabel.isNotEmpty)
                                      _InfoPill(label: item.categoryLabel),
                                    if (item.recurrenceLabel.isNotEmpty)
                                      _InfoPill(label: item.recurrenceLabel),
                                    if (item.sourceLabel.isNotEmpty)
                                      _InfoPill(label: item.sourceLabel),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (currentTimeProgress != null) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.only(
                        left: _agendaTimeColumnWidth(isCompactWidth) + 34,
                      ),
                      child: _AgendaCurrentProgressBar(
                        progress: currentTimeProgress!,
                        color: _scheduleCurrentTimeGreen,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

LiquidGlassSettings _scheduleAgendaCardGlassSettings(
  BuildContext context,
  LingPalette palette,
) {
  final isDark = context.isDarkMode;
  final tint = isDark
      ? Color.lerp(
          palette.surfaceHigh,
          const Color(0xFF111820),
          0.28,
        )!.withValues(alpha: 0.94)
      : const Color(0xFFF8FAFC).withValues(alpha: 0.98);
  return lingGlassSettingsFor(
    context,
    LingGlassSurfaceTone.muted,
    tintColor: tint,
    thickness: isDark ? 18 : 24,
    blur: isDark ? 6.5 : 7.5,
    chromaticAberration: isDark ? 0.003 : 0.008,
    saturation: isDark ? 1.0 : 1.08,
    lightIntensity: isDark ? 0.46 : 0.82,
    ambientStrength: isDark ? 0.28 : 0.42,
    refractiveIndex: isDark ? 1.08 : 1.18,
  );
}

class _AgendaTimeColumn extends StatelessWidget {
  const _AgendaTimeColumn({
    required this.item,
    required this.isCompactWidth,
    required this.hasMetaBlock,
  });

  final LingScheduleAgendaItem item;
  final bool isCompactWidth;
  final bool hasMetaBlock;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final width = _agendaTimeColumnWidth(isCompactWidth);

    if (item.isAllDay || item.isPoint) {
      return SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              item.timeLabel,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
            if (item.durationLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.durationLabel,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final railHeight = hasMetaBlock ? 74.0 : 62.0;

    return SizedBox(
      width: width,
      height: railHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _AgendaTimeText(
            label: item.startTimeLabel ?? _formatHourMinute(item.startAt),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                _compactDurationLabel(context, item),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
          _AgendaTimeText(
            label: item.endTimeLabel ?? _formatHourMinute(item.endAt),
          ),
        ],
      ),
    );
  }
}

double _agendaTimeColumnWidth(bool isCompactWidth) => isCompactWidth ? 78 : 88;

class _AgendaAccentDot extends StatelessWidget {
  const _AgendaAccentDot({required this.color, this.isActive = false});

  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      width: isActive ? 9 : 8,
      height: isActive ? 9 : 8,
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: isDark ? (isActive ? 0.94 : 0.78) : (isActive ? 0.88 : 0.72),
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(
              alpha: isDark
                  ? (isActive ? 0.28 : 0.16)
                  : (isActive ? 0.22 : 0.12),
            ),
            blurRadius: isActive ? 12 : 8,
            spreadRadius: isActive ? 2 : 1,
          ),
        ],
      ),
    );
  }
}

class _AgendaCurrentProgressBar extends StatefulWidget {
  const _AgendaCurrentProgressBar({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  State<_AgendaCurrentProgressBar> createState() =>
      _AgendaCurrentProgressBarState();
}

class _AgendaCurrentProgressBarState extends State<_AgendaCurrentProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        key: const Key('schedule_current_event_progress'),
        height: 2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: widget.color.withValues(alpha: isDark ? 0.22 : 0.14),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widget.progress,
              child: ColoredBox(
                color: widget.color.withValues(alpha: isDark ? 0.86 : 0.78),
              ),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widget.progress,
              child: _FlowingProgressHighlight(
                controller: _controller,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowingProgressHighlight extends StatelessWidget {
  const _FlowingProgressHighlight({
    required this.controller,
    required this.color,
  });

  final Animation<double> controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final highlightWidth = width.clamp(24.0, 56.0) * 0.8;
          return AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              const sweepEnd = 0.76;
              final rawProgress = controller.value;
              if (rawProgress > sweepEnd) {
                return const SizedBox.shrink();
              }
              final progress = rawProgress / sweepEnd;
              final travel = width + highlightWidth;
              final dx = (progress * travel) - highlightWidth;
              final edgeFade = progress < 0.14
                  ? progress / 0.14
                  : progress > 0.86
                  ? (1 - progress) / 0.14
                  : 1.0;
              return Opacity(
                opacity: edgeFade.clamp(0.0, 1.0),
                child: Transform.translate(offset: Offset(dx, 0), child: child),
              );
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: highlightWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0),
                      Colors.white.withValues(alpha: isDark ? 0.5 : 0.62),
                      color.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AgendaTimeText extends StatelessWidget {
  const _AgendaTimeText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Text(
      label,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 12,
        height: 1.15,
        fontWeight: FontWeight.w800,
        color: palette.textPrimary,
        fontFamily: 'Plus Jakarta Sans',
      ),
    );
  }
}

String _compactDurationLabel(
  BuildContext context,
  LingScheduleAgendaItem item,
) {
  if (item.isAllDay) {
    return item.durationLabel;
  }
  if (item.isPoint) {
    return '';
  }

  final totalMinutes = item.endAt.difference(item.startAt).inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  final isZh = Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('zh');

  if (hours > 0 && minutes > 0) {
    return isZh
        ? '$hours小时$minutes分'
        : '$hours'
              'h $minutes'
              'm';
  }
  if (hours > 0) {
    return isZh
        ? '$hours小时'
        : '$hours'
              'h';
  }
  return isZh
      ? '$totalMinutes分'
      : '$totalMinutes'
            'm';
}

String _formatHourMinute(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _AgendaMetaText extends StatelessWidget {
  const _AgendaMetaText({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: palette.textSecondary),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Text(
      label,
      style: TextStyle(
        color: palette.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SwipeRevealDelete extends StatefulWidget {
  const _SwipeRevealDelete({
    required this.identity,
    required this.child,
    required this.borderRadius,
    this.enabled = true,
    this.onDelete,
  });

  final Object identity;
  final Widget child;
  final BorderRadius borderRadius;
  final bool enabled;
  final FutureOr<void> Function()? onDelete;

  @override
  State<_SwipeRevealDelete> createState() => _SwipeRevealDeleteState();
}

class _SwipeRevealDeleteState extends State<_SwipeRevealDelete> {
  static const double _actionExtent = 72;
  static const Duration _animationDuration = Duration(milliseconds: 220);

  double _dragOffset = 0;
  bool _isProcessingDelete = false;

  @override
  void didUpdateWidget(covariant _SwipeRevealDelete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity || !widget.enabled) {
      _dragOffset = 0;
      _isProcessingDelete = false;
    }
  }

  void _setOpen(bool open) {
    final nextOffset = open ? -_actionExtent : 0.0;
    if (_dragOffset == nextOffset) {
      return;
    }
    setState(() {
      _dragOffset = nextOffset;
    });
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    final nextOffset = (_dragOffset + details.delta.dx).clamp(
      -_actionExtent,
      0.0,
    );
    if (nextOffset == _dragOffset) {
      return;
    }
    setState(() {
      _dragOffset = nextOffset;
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity <= -240) {
      _setOpen(true);
      return;
    }
    if (velocity >= 240) {
      _setOpen(false);
      return;
    }
    _setOpen(_dragOffset.abs() >= _actionExtent * 0.45);
  }

  Future<void> _handleDelete() async {
    final onDelete = widget.onDelete;
    if (_isProcessingDelete || onDelete == null) {
      return;
    }
    setState(() {
      _isProcessingDelete = true;
    });
    try {
      await Future.sync(onDelete);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingDelete = false;
          _dragOffset = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.onDelete == null) {
      return widget.child;
    }

    final palette = context.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.dangerSoft,
                      borderRadius: widget.borderRadius,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _dragOffset == 0 ? null : () => _setOpen(false),
                  onHorizontalDragUpdate: _handleHorizontalDragUpdate,
                  onHorizontalDragEnd: _handleHorizontalDragEnd,
                  child: AnimatedContainer(
                    width: constraints.maxWidth,
                    duration: _animationDuration,
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.translationValues(_dragOffset, 0, 0),
                    child: AbsorbPointer(
                      absorbing: _dragOffset != 0,
                      child: widget.child,
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  child: IgnorePointer(
                    ignoring: _dragOffset == 0,
                    child: AnimatedOpacity(
                      duration: _animationDuration,
                      curve: Curves.easeOutCubic,
                      opacity: _dragOffset == 0 ? 0 : 1,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Material(
                          color: palette.danger,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _isProcessingDelete ? null : _handleDelete,
                            child: _isProcessingDelete
                                ? Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: GlassProgressIndicator.circular(
                                      size: 20,
                                      strokeWidth: 2,
                                      color: Colors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
