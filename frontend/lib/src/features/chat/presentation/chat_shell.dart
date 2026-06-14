import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/shared/presentation/shared_controls.dart';

class LingCalendarChatShell extends StatefulWidget {
  const LingCalendarChatShell({
    super.key,
    required this.conversationList,
    required this.bottomDock,
    this.bottomOverlay,
    this.bottomFloatingControl,
    this.bottomFloatingControlOffset = 0,
    this.onBottomOverlayDismissed,
    required this.onAvatarTap,
    required this.onCalendarTap,
    required this.hasUnreadCalendarBadge,
  });

  final Widget conversationList;
  final Widget bottomDock;
  final Widget? bottomOverlay;
  final Widget? bottomFloatingControl;
  final double bottomFloatingControlOffset;
  final VoidCallback? onBottomOverlayDismissed;
  final VoidCallback onAvatarTap;
  final VoidCallback onCalendarTap;
  final bool hasUnreadCalendarBadge;

  static const double topContentInset = 100;
  static const double bottomContentInset = 168;
  static const double topBarMaskHeight = 118;
  static const double messageActionOverlayHeightFactor = 1 / 3;

  @override
  State<LingCalendarChatShell> createState() => _LingCalendarChatShellState();
}

class _LingCalendarChatShellState extends State<LingCalendarChatShell> {
  @override
  Widget build(BuildContext context) {
    final overlay = widget.bottomOverlay;
    final isOverlayVisible = overlay != null;

    return Stack(
      children: [
        Positioned.fill(child: _buildConversationLayer()),
        if (!isOverlayVisible)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _LingBottomDockConversationFade(),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            },
            child: isOverlayVisible
                ? const SizedBox.shrink(
                    key: ValueKey('chat_bottom_dock_hidden'),
                  )
                : KeyedSubtree(
                    key: const ValueKey('chat_bottom_dock_visible'),
                    child: widget.bottomDock,
                  ),
          ),
        ),
        if (overlay != null)
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor:
                    LingCalendarChatShell.messageActionOverlayHeightFactor,
                alignment: Alignment.bottomCenter,
                child: _LingBottomOverlayDismissContainer(
                  key: ValueKey<Object?>(
                    'chat_bottom_overlay_${overlay.key ?? overlay.runtimeType}',
                  ),
                  onDismissed: widget.onBottomOverlayDismissed,
                  child: overlay,
                ),
              ),
            ),
          ),
        if (!isOverlayVisible && widget.bottomFloatingControl != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.bottomFloatingControlOffset,
            child: Center(child: widget.bottomFloatingControl),
          ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _LingTopBarConversationFade(),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: RepaintBoundary(
            child: LingCalendarTopBar(
              onAvatarTap: widget.onAvatarTap,
              onCalendarTap: widget.onCalendarTap,
              hasUnreadCalendarBadge: widget.hasUnreadCalendarBadge,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConversationLayer() {
    return Stack(
      fit: StackFit.expand,
      children: [const LingConversationBackdrop(), widget.conversationList],
    );
  }
}

class LingConversationBackdrop extends StatelessWidget {
  const LingConversationBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.isDarkMode) {
      return const SizedBox.shrink();
    }
    final palette = context.palette;
    return CustomPaint(
      key: const Key('chat_light_conversation_backdrop'),
      painter: _LingLightConversationBackdropPainter(
        background: palette.background,
        accent: palette.accent,
        accentSoft: palette.accentSoft,
        outline: palette.outlineSoft,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _LingLightConversationBackdropPainter extends CustomPainter {
  const _LingLightConversationBackdropPainter({
    required this.background,
    required this.accent,
    required this.accentSoft,
    required this.outline,
  });

  final Color background;
  final Color accent;
  final Color accentSoft;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final rect = Offset.zero & size;
    final coolWhite = Color.lerp(background, accentSoft, 0.30)!;
    final softWhite = Color.lerp(background, outline, 0.16)!;
    final warmWhite = Color.lerp(background, const Color(0xFFFFF5E6), 0.24)!;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [background, softWhite, coolWhite, warmWhite],
          stops: const [0, 0.48, 0.78, 1],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: [
            accent.withValues(alpha: 0.052),
            accent.withValues(alpha: 0.018),
            Colors.transparent,
          ],
          stops: const [0, 0.42, 1],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.centerRight,
          colors: [Color(0x1AFFDFA8), Color(0x0AFFF8ED), Colors.transparent],
          stops: [0, 0.48, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_LingLightConversationBackdropPainter oldDelegate) {
    return background != oldDelegate.background ||
        accent != oldDelegate.accent ||
        accentSoft != oldDelegate.accentSoft ||
        outline != oldDelegate.outline;
  }
}

class _LingBottomDockConversationFade extends StatelessWidget {
  const _LingBottomDockConversationFade();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fadeColor = context.isDarkMode
        ? palette.background
        : palette.backgroundElevated;

    return IgnorePointer(
      child: SizedBox(
        height: 132,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                fadeColor.withValues(alpha: 0),
                fadeColor.withValues(alpha: 0.74),
                fadeColor.withValues(alpha: 0.96),
              ],
              stops: const [0.0, 0.56, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _LingTopBarConversationFade extends StatelessWidget {
  const _LingTopBarConversationFade();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDarkMode = context.isDarkMode;
    final fadeColor = isDarkMode
        ? palette.background
        : palette.backgroundElevated;

    return SizedBox(
      key: const Key('chat_top_bar_conversation_fade'),
      height: LingCalendarChatShell.topBarMaskHeight,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                fadeColor.withValues(alpha: 0.96),
                fadeColor.withValues(alpha: 0.78),
                fadeColor.withValues(alpha: 0.32),
                fadeColor.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.42, 0.76, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _LingBottomOverlayDismissContainer extends StatefulWidget {
  const _LingBottomOverlayDismissContainer({
    super.key,
    required this.child,
    this.onDismissed,
  });

  final Widget child;
  final VoidCallback? onDismissed;

  @override
  State<_LingBottomOverlayDismissContainer> createState() =>
      _LingBottomOverlayDismissContainerState();
}

class _LingBottomOverlayDismissContainerState
    extends State<_LingBottomOverlayDismissContainer>
    with SingleTickerProviderStateMixin {
  static const Duration _animationDuration = Duration(milliseconds: 240);
  static const double _completionVelocity = 820;
  static const double _completionProgress = 0.24;

  late final AnimationController _animationController;
  Animation<double>? _offsetAnimation;
  double _dragOffset = 0;
  bool _isDragging = false;
  bool _isAnimatingBack = false;
  bool _isCompletingDismiss = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    )..addListener(_handleAnimationTick);
  }

  @override
  void didUpdateWidget(covariant _LingBottomOverlayDismissContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.key != widget.child.key && _dragOffset > 0) {
      _animationController.stop();
      _offsetAnimation = null;
      _isDragging = false;
      _isAnimatingBack = false;
      _isCompletingDismiss = false;
      setState(() {
        _dragOffset = 0;
      });
    }
  }

  @override
  void dispose() {
    _animationController
      ..removeListener(_handleAnimationTick)
      ..dispose();
    super.dispose();
  }

  void _handleAnimationTick() {
    final nextOffset = _offsetAnimation?.value;
    if (nextOffset == null || !mounted) {
      return;
    }
    setState(() {
      _dragOffset = nextOffset;
    });
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    if (_isCompletingDismiss) {
      return;
    }
    _animationController.stop();
    _isAnimatingBack = false;
    _isDragging = true;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isCompletingDismiss) {
      return;
    }
    final primaryDelta = details.primaryDelta ?? 0;
    if (primaryDelta == 0) {
      return;
    }
    setState(() {
      _dragOffset = (_dragOffset + primaryDelta).clamp(0.0, double.infinity);
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (!_isDragging || _isCompletingDismiss) {
      _isDragging = false;
      return;
    }
    _isDragging = false;
    final height = context.size?.height ?? 0;
    final shouldDismiss =
        details.primaryVelocity != null &&
            details.primaryVelocity! >= _completionVelocity ||
        (height > 0 && _dragOffset / height >= _completionProgress);
    if (shouldDismiss) {
      _completeDismiss(height);
      return;
    }
    _animateOffsetTo(0);
  }

  void _animateOffsetTo(double target) {
    if (!mounted) {
      return;
    }
    _offsetAnimation = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _isAnimatingBack = target == 0;
    _animationController
      ..reset()
      ..forward().whenCompleteOrCancel(() {
        if (!mounted || !_isAnimatingBack) {
          return;
        }
        setState(() {
          _dragOffset = 0;
          _isAnimatingBack = false;
        });
      });
  }

  void _completeDismiss(double height) {
    if (_isCompletingDismiss) {
      return;
    }
    _isCompletingDismiss = true;
    final targetOffset = height > 0 ? height : _dragOffset;
    _offsetAnimation = Tween<double>(begin: _dragOffset, end: targetOffset)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController
      ..reset()
      ..forward().whenCompleteOrCancel(() {
        if (!mounted) {
          return;
        }
        final onDismissed = widget.onDismissed;
        setState(() {
          _dragOffset = 0;
          _isCompletingDismiss = false;
          _isAnimatingBack = false;
        });
        onDismissed?.call();
      });
  }

  @override
  Widget build(BuildContext context) {
    final child = ClipRect(
      child: Transform.translate(
        offset: Offset(0, _dragOffset),
        child: widget.child,
      ),
    );
    if (widget.onDismissed == null) {
      return child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: _handleVerticalDragStart,
      onVerticalDragUpdate: _handleVerticalDragUpdate,
      onVerticalDragEnd: _handleVerticalDragEnd,
      child: child,
    );
  }
}

class LingCalendarTopBar extends StatelessWidget {
  const LingCalendarTopBar({
    super.key,
    required this.onAvatarTap,
    required this.onCalendarTap,
    required this.hasUnreadCalendarBadge,
  });

  final VoidCallback onAvatarTap;
  final VoidCallback onCalendarTap;
  final bool hasUnreadCalendarBadge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final topBarButtonTint = _lingTopBarButtonGlassTintFor(context, palette);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _LingTopBarFloatingButton(
            showRefractionGlow: true,
            child: LingFloatingIconButton(
              key: const Key('topbar_avatar_button'),
              icon: Icons.person_outline_rounded,
              onTap: onAvatarTap,
              semanticLabel: '设置',
              tintColor: topBarButtonTint,
              useOwnLayer: false,
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _LingTopBarFloatingButton(
                showRefractionGlow: true,
                child: LingFloatingIconButton(
                  key: const Key('topbar_calendar_button'),
                  icon: Icons.calendar_today_outlined,
                  onTap: onCalendarTap,
                  semanticLabel: '日历',
                  tintColor: topBarButtonTint,
                  useOwnLayer: false,
                ),
              ),
              if (hasUnreadCalendarBadge)
                const Positioned(
                  top: 1,
                  right: 1,
                  child: _LingCalendarUnreadBadge(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LingTopBarFloatingButton extends StatelessWidget {
  const _LingTopBarFloatingButton({
    required this.child,
    this.showRefractionGlow = true,
  });

  final Widget child;
  final bool showRefractionGlow;

  @override
  Widget build(BuildContext context) {
    return LingFloatingIconButtonFrame(
      showRefractionGlow: showRefractionGlow,
      child: child,
    );
  }
}

Color _lingTopBarButtonGlassTintFor(BuildContext context, LingPalette palette) {
  return lingFloatingControlTintFor(context, palette);
}

class _LingCalendarUnreadBadge extends StatelessWidget {
  const _LingCalendarUnreadBadge();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: const Key('topbar_calendar_unread_badge'),
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: palette.danger, shape: BoxShape.circle),
    );
  }
}
