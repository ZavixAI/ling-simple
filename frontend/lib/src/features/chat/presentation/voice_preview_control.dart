import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';

class LingVoicePreviewControl extends StatefulWidget {
  const LingVoicePreviewControl({
    super.key,
    required this.source,
    required this.onPlay,
    required this.onStop,
    this.onLoadDuration,
    this.compact = false,
    this.embedded = false,
    this.fillWidth = false,
    this.isHighlighted = false,
  });

  final String source;
  final Future<Duration> Function(String source) onPlay;
  final FutureOr<void> Function() onStop;
  final Future<Duration> Function(String source)? onLoadDuration;
  final bool compact;
  final bool embedded;
  final bool fillWidth;
  final bool isHighlighted;

  @override
  State<LingVoicePreviewControl> createState() =>
      _LingVoicePreviewControlState();
}

class _LingVoicePreviewControlState extends State<LingVoicePreviewControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barsController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  Timer? _positionTimer;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDuration();
  }

  @override
  void didUpdateWidget(covariant LingVoicePreviewControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _stopLocalPlaybackState();
      _duration = Duration.zero;
      _position = Duration.zero;
      _loadDuration();
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _barsController.dispose();
    if (_isPlaying) {
      unawaited(Future<void>.sync(widget.onStop));
    }
    super.dispose();
  }

  Future<void> _loadDuration() async {
    final source = widget.source.trim();
    final loader = widget.onLoadDuration;
    if (source.isEmpty || loader == null) {
      return;
    }
    try {
      final loadedDuration = await loader(source);
      if (!mounted || source != widget.source.trim()) {
        return;
      }
      setState(() {
        _duration = loadedDuration;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _duration = Duration.zero;
      });
    }
  }

  Future<void> _togglePlayback() async {
    final source = widget.source.trim();
    if (source.isEmpty || _isLoading) {
      return;
    }
    if (_isPlaying) {
      await widget.onStop();
      _stopLocalPlaybackState();
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final playbackDuration = await widget.onPlay(source);
      if (!mounted) {
        return;
      }
      final resolvedDuration = playbackDuration > Duration.zero
          ? playbackDuration
          : _duration;
      setState(() {
        _duration = resolvedDuration;
        _position = Duration.zero;
        _isPlaying = true;
        _isLoading = false;
      });
      _barsController.repeat();
      _startPositionTimer();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isPlaying = false;
      });
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    final total = _duration;
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted || !_isPlaying) {
        timer.cancel();
        return;
      }
      final nextPosition = _position + const Duration(milliseconds: 200);
      if (total > Duration.zero && nextPosition >= total) {
        setState(() {
          _position = total;
        });
        _stopLocalPlaybackState(resetPosition: true);
        return;
      }
      setState(() {
        _position = nextPosition;
      });
    });
  }

  void _stopLocalPlaybackState({bool resetPosition = false}) {
    _positionTimer?.cancel();
    _positionTimer = null;
    _barsController.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _isPlaying = false;
      _isLoading = false;
      if (resetPosition) {
        _position = Duration.zero;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final height = widget.embedded
        ? 40.0
        : widget.compact
        ? 42.0
        : 48.0;
    final iconSize = widget.embedded
        ? 18.0
        : widget.compact
        ? 18.0
        : 20.0;
    final playControlSize = widget.embedded ? 30.0 : iconSize + 4;
    final sourceAvailable = widget.source.trim().isNotEmpty;
    final foreground = widget.isHighlighted
        ? palette.accent
        : palette.textPrimary;
    final durationSeconds = math.max(1, _duration.inSeconds);
    final width = widget.embedded
        ? _embeddedVoicePreviewWidthForSeconds(durationSeconds)
        : _voicePreviewWidthForSeconds(
            durationSeconds,
            compact: widget.compact,
          );
    final effectivePosition = _isPlaying ? _position : Duration.zero;
    final borderRadius = BorderRadius.circular(999);
    final controlFill = widget.embedded
        ? _embeddedVoicePreviewFillFor(context, palette)
        : widget.isHighlighted
        ? palette.accent.withValues(alpha: 0.16)
        : palette.surface.withValues(alpha: context.isDarkMode ? 0.42 : 0.58);
    final controlBorder = widget.embedded
        ? _embeddedVoicePreviewBorderFor(context, palette)
        : widget.isHighlighted
        ? palette.accent.withValues(alpha: 0.36)
        : palette.outline.withValues(alpha: 0.24);
    final playFill = _embeddedVoicePreviewPlayFillFor(
      context,
      palette,
      isPlaying: _isPlaying,
      sourceAvailable: sourceAvailable,
    );
    final playIconColor = _embeddedVoicePreviewPlayIconColorFor(
      palette,
      isPlaying: _isPlaying,
      sourceAvailable: sourceAvailable,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('voice_preview_control'),
        onTap: sourceAvailable ? _togglePlayback : null,
        borderRadius: borderRadius,
        child: Container(
          height: height,
          width: widget.fillWidth ? double.infinity : width,
          padding: EdgeInsets.fromLTRB(
            widget.embedded
                ? 6
                : widget.compact
                ? 8
                : 10,
            0,
            widget.embedded
                ? 10
                : widget.compact
                ? 10
                : 12,
            0,
          ),
          decoration: BoxDecoration(
            color: controlFill,
            borderRadius: borderRadius,
            border: Border.all(color: controlBorder, width: 0.7),
          ),
          child: Row(
            children: [
              if (widget.embedded)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: playControlSize,
                  height: playControlSize,
                  decoration: BoxDecoration(
                    color: playFill,
                    shape: BoxShape.circle,
                    boxShadow: _isPlaying && sourceAvailable
                        ? [
                            BoxShadow(
                              color: palette.accentGlow.withValues(alpha: 0.8),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : const <BoxShadow>[],
                  ),
                  child: Center(
                    child: _isLoading
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.7,
                              color: playIconColor,
                            ),
                          )
                        : Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: iconSize + 2,
                            color: playIconColor,
                          ),
                  ),
                )
              else
                Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: iconSize + 4,
                  color: sourceAvailable
                      ? foreground
                      : palette.textSecondary.withValues(alpha: 0.56),
                ),
              SizedBox(
                width: widget.embedded
                    ? 10
                    : widget.compact
                    ? 7
                    : 9,
              ),
              Expanded(
                child: _LingVoicePreviewBars(
                  animation: _barsController,
                  active: _isPlaying,
                  embedded: widget.embedded,
                  color: sourceAvailable
                      ? foreground
                      : palette.textSecondary.withValues(alpha: 0.5),
                ),
              ),
              SizedBox(
                width: widget.embedded
                    ? 10
                    : widget.compact
                    ? 8
                    : 10,
              ),
              SizedBox(
                width: widget.embedded
                    ? 56
                    : widget.compact
                    ? 54
                    : 60,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_formatDuration(effectivePosition)}/${_formatDuration(_duration)}',
                    key: const Key('voice_preview_duration_label'),
                    maxLines: 1,
                    style: TextStyle(
                      color: sourceAvailable
                          ? foreground.withValues(
                              alpha: widget.embedded ? 0.66 : 0.74,
                            )
                          : palette.textSecondary.withValues(alpha: 0.5),
                      fontSize: widget.embedded || widget.compact ? 11 : 12,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _voicePreviewWidthForSeconds(int seconds, {required bool compact}) {
  final clamped = seconds.clamp(1, 60);
  final base = compact ? 132.0 : 148.0;
  final max = compact ? 226.0 : 260.0;
  final extra = math.log(clamped + 1) / math.log(61) * (max - base);
  return base + extra;
}

double _embeddedVoicePreviewWidthForSeconds(int seconds) {
  final clamped = seconds.clamp(1, 60);
  const base = 142.0;
  const max = 204.0;
  final extra = math.log(clamped + 1) / math.log(61) * (max - base);
  return base + extra;
}

String _formatDuration(Duration duration) {
  final seconds = math.max(0, duration.inSeconds);
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

Color _embeddedVoicePreviewFillFor(BuildContext context, LingPalette palette) {
  if (context.isDarkMode) {
    return palette.textPrimary.withValues(alpha: 0.055);
  }
  return palette.textPrimary.withValues(alpha: 0.035);
}

Color _embeddedVoicePreviewBorderFor(
  BuildContext context,
  LingPalette palette,
) {
  if (context.isDarkMode) {
    return palette.textPrimary.withValues(alpha: 0.075);
  }
  return palette.outline.withValues(alpha: 0.28);
}

Color _embeddedVoicePreviewPlayFillFor(
  BuildContext context,
  LingPalette palette, {
  required bool isPlaying,
  required bool sourceAvailable,
}) {
  if (!sourceAvailable) {
    return palette.textSecondary.withValues(alpha: 0.1);
  }
  if (isPlaying) {
    return palette.accent;
  }
  if (context.isDarkMode) {
    return palette.textPrimary.withValues(alpha: 0.1);
  }
  return palette.surface.withValues(alpha: 0.78);
}

Color _embeddedVoicePreviewPlayIconColorFor(
  LingPalette palette, {
  required bool isPlaying,
  required bool sourceAvailable,
}) {
  if (!sourceAvailable) {
    return palette.textSecondary.withValues(alpha: 0.5);
  }
  return isPlaying ? palette.onAccent : palette.textPrimary;
}

class _LingVoicePreviewBars extends StatelessWidget {
  const _LingVoicePreviewBars({
    required this.animation,
    required this.active,
    required this.embedded,
    required this.color,
  });

  final Animation<double> animation;
  final bool active;
  final bool embedded;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 52.0;
            final barCount = embedded
                ? math.max(7, (availableWidth / 7).floor())
                : math.max(5, (availableWidth / 9).floor());
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var index = 0; index < barCount; index += 1)
                  _LingVoicePreviewBar(
                    index: index,
                    progress: active ? animation.value : 0,
                    active: active,
                    embedded: embedded,
                    color: color,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _LingVoicePreviewBar extends StatelessWidget {
  const _LingVoicePreviewBar({
    required this.index,
    required this.progress,
    required this.active,
    required this.embedded,
    required this.color,
  });

  final int index;
  final double progress;
  final bool active;
  final bool embedded;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final phase = progress * math.pi * 2 + index * 0.72;
    final wave = (math.sin(phase) + 1) / 2;
    final idle = embedded ? 4.0 + (index % 4) * 1.6 : 6.0 + (index % 4) * 2.0;
    final height = active
        ? embedded
              ? 4.0 + wave * 11.0
              : 6.0 + wave * 15.0
        : idle;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: embedded ? 2 : 3,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: active
              ? embedded
                    ? 0.84
                    : 0.9
              : embedded
              ? 0.38
              : 0.58,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
