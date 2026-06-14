import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

VoidCallback? _lingTopNoticeDismiss;

void showLingTopNotice(BuildContext context, String message) {
  final dismissPrevious = _lingTopNoticeDismiss;
  _lingTopNoticeDismiss = null;
  if (dismissPrevious != null) {
    try {
      dismissPrevious();
    } on FlutterError {
      // The package removes the overlay after its duration; a later notice may
      // still hold the old dismiss callback.
    }
  }

  late final VoidCallback dismiss;
  dismiss = _showLingTopNoticeOverlay(
    context,
    message: message,
    duration: const Duration(milliseconds: 2400),
    onDismissed: () {
      if (identical(_lingTopNoticeDismiss, dismiss)) {
        _lingTopNoticeDismiss = null;
      }
    },
  );
  _lingTopNoticeDismiss = dismiss;
}

VoidCallback _showLingTopNoticeOverlay(
  BuildContext context, {
  required String message,
  required Duration duration,
  required VoidCallback onDismissed,
}) {
  final overlayState = Overlay.of(context);
  late final OverlayEntry overlayEntry;
  var removed = false;

  void removeEntry() {
    if (removed) {
      return;
    }
    removed = true;
    overlayEntry.remove();
    onDismissed();
  }

  overlayEntry = OverlayEntry(
    builder: (context) => _LingTopNoticeOverlay(
      message: message,
      duration: duration,
      onDismissed: removeEntry,
    ),
  );

  overlayState.insert(overlayEntry);
  return removeEntry;
}

class _LingTopNoticeOverlay extends StatefulWidget {
  const _LingTopNoticeOverlay({
    required this.message,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_LingTopNoticeOverlay> createState() => _LingTopNoticeOverlayState();
}

class _LingTopNoticeOverlayState extends State<_LingTopNoticeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;
  var _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5),
        reverseCurve: const Interval(0.5, 1),
      ),
    );

    _controller.forward();
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissed) {
      return;
    }
    _dismissed = true;
    _dismissTimer?.cancel();
    await _controller.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  void _handleSwipeDismissed() {
    if (_dismissed) {
      return;
    }
    _dismissed = true;
    _dismissTimer?.cancel();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 16;
    Widget toast = DefaultTextStyle.merge(
      style: const TextStyle(decoration: TextDecoration.none),
      child: _LingTopNoticeToast(message: widget.message),
    );

    toast = Dismissible(
      key: const Key('ling_top_notice_dismissible'),
      direction: DismissDirection.up,
      onDismissed: (_) => _handleSwipeDismissed(),
      child: toast,
    );

    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(opacity: _fadeAnimation, child: toast),
      ),
    );
  }
}

class _LingTopNoticeToast extends StatelessWidget {
  const _LingTopNoticeToast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    final backgroundColor = isDark
        ? palette.surfaceHigh.withValues(alpha: 0.86)
        : palette.surface.withValues(alpha: 0.96);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : palette.outlineSoft.withValues(alpha: 0.74);
    final iconColor = isDark ? palette.info : palette.primaryButtonBackground;

    return Semantics(
      liveRegion: true,
      label: message,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow.withValues(alpha: isDark ? 0.46 : 0.14),
                  blurRadius: isDark ? 28 : 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: LingGlassSurface(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              radius: 24,
              tone: LingGlassSurfaceTone.elevated,
              tintColor: backgroundColor,
              thickness: isDark ? 18 : 24,
              blur: isDark ? 7 : 8,
              lightIntensity: isDark ? 0.56 : 0.86,
              ambientStrength: isDark ? 0.36 : 0.64,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_rounded, color: iconColor, size: 20),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: palette.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            letterSpacing: 0,
                          ) ??
                          TextStyle(
                            color: palette.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            letterSpacing: 0,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
