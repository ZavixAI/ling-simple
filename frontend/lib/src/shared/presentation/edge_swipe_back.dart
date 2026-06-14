import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum LingEdgeSwipeDirection { leftToRight, rightToLeft }

class LingEdgeSwipeBackController {
  Future<bool> Function()? _animateBack;

  Future<bool> animateBack() async {
    final animateBack = _animateBack;
    if (animateBack == null) {
      return false;
    }
    return animateBack();
  }
}

class LingEdgeSwipeBackContainer extends StatefulWidget {
  const LingEdgeSwipeBackContainer({
    super.key,
    required this.child,
    required this.onBack,
    this.onBackForDirection,
    this.controller,
    this.enabled = true,
    this.edgeActivationWidth = 28,
    this.completionVelocity = 820,
    this.completionProgress = 0.24,
    this.underlayChild,
    this.underlayBuilder,
    this.onSwipeProgressChanged,
    this.onSwipeActivityChanged,
    this.onSwipeBackCompleted,
    this.onSwipeBackDirectionCompleted,
    this.swipeDirections = const <LingEdgeSwipeDirection>{
      LingEdgeSwipeDirection.leftToRight,
    },
    this.programmaticDirection = LingEdgeSwipeDirection.leftToRight,
    this.keepCompletedOffsetUntilBack = false,
  });

  final Widget child;
  final VoidCallback onBack;
  final ValueChanged<LingEdgeSwipeDirection>? onBackForDirection;
  final LingEdgeSwipeBackController? controller;
  final bool enabled;
  final double edgeActivationWidth;
  final double completionVelocity;
  final double completionProgress;
  final Widget? underlayChild;
  final Widget? Function(LingEdgeSwipeDirection? direction)? underlayBuilder;
  final ValueChanged<double>? onSwipeProgressChanged;
  final ValueChanged<bool>? onSwipeActivityChanged;
  final VoidCallback? onSwipeBackCompleted;
  final ValueChanged<LingEdgeSwipeDirection>? onSwipeBackDirectionCompleted;
  final Set<LingEdgeSwipeDirection> swipeDirections;
  final LingEdgeSwipeDirection programmaticDirection;
  final bool keepCompletedOffsetUntilBack;

  @override
  State<LingEdgeSwipeBackContainer> createState() =>
      _LingEdgeSwipeBackContainerState();
}

class _LingEdgeSwipeBackContainerState extends State<LingEdgeSwipeBackContainer>
    with SingleTickerProviderStateMixin {
  static const double _dragActivationDistance = 8;

  late final AnimationController _animationController;
  Animation<double>? _offsetAnimation;

  double _dragOffset = 0;
  bool _isEdgeDragActive = false;
  bool _isAnimatingBack = false;
  bool _isCompletingBack = false;
  LingEdgeSwipeDirection? _activeSwipeDirection;
  LingEdgeSwipeDirection? _underlayDirection;
  double _lastReportedProgress = 0;
  bool _lastReportedSwipeActivity = false;
  int? _trackedPointer;
  Offset? _dragStartLocalPosition;
  LingEdgeSwipeDirection? _pendingSwipeDirection;
  VelocityTracker? _velocityTracker;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(_handleAnimationTick);
    widget.controller?._animateBack = _animateBack;
  }

  @override
  void didUpdateWidget(covariant LingEdgeSwipeBackContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._animateBack = null;
      widget.controller?._animateBack = _animateBack;
    }
  }

  @override
  void dispose() {
    widget.controller?._animateBack = null;
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
    _reportSwipeState();
  }

  LingEdgeSwipeDirection? _directionForGlobalPosition(Offset globalPosition) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final localPosition = renderBox?.globalToLocal(globalPosition);
    final localDx = localPosition?.dx ?? globalPosition.dx;
    final width = context.size?.width ?? renderBox?.size.width ?? 0;
    final isLeftEdgeActive = localDx <= widget.edgeActivationWidth;
    final isRightEdgeActive =
        width > 0 && localDx >= width - widget.edgeActivationWidth;
    if (isLeftEdgeActive &&
        widget.swipeDirections.contains(LingEdgeSwipeDirection.leftToRight)) {
      return LingEdgeSwipeDirection.leftToRight;
    }
    if (isRightEdgeActive &&
        widget.swipeDirections.contains(LingEdgeSwipeDirection.rightToLeft)) {
      return LingEdgeSwipeDirection.rightToLeft;
    }
    return null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled || _isCompletingBack || _trackedPointer != null) {
      return;
    }
    final direction = _directionForGlobalPosition(event.position);
    _trackedPointer = direction == null ? null : event.pointer;
    _dragStartLocalPosition = direction == null ? null : event.localPosition;
    _pendingSwipeDirection = direction;
    _velocityTracker = direction == null
        ? null
        : (VelocityTracker.withKind(event.kind)
            ..addPosition(event.timeStamp, event.localPosition));
    if (direction == _underlayDirection) {
      return;
    }
    setState(() {
      _underlayDirection = direction;
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!widget.enabled ||
        _isCompletingBack ||
        event.pointer != _trackedPointer) {
      return;
    }
    _velocityTracker?.addPosition(event.timeStamp, event.localPosition);
    if (_isEdgeDragActive) {
      _updateDragOffset(event.delta.dx);
      return;
    }

    final direction = _pendingSwipeDirection;
    final startPosition = _dragStartLocalPosition;
    if (direction == null || startPosition == null) {
      return;
    }

    final dragDelta = event.localPosition - startPosition;
    final horizontalDelta = dragDelta.dx;
    final horizontalDistance = horizontalDelta.abs();
    final verticalDistance = dragDelta.dy.abs();
    if (verticalDistance > _dragActivationDistance &&
        verticalDistance > horizontalDistance) {
      _clearPointerTracking(clearUnderlay: true);
      return;
    }

    final isAllowedDirection = switch (direction) {
      LingEdgeSwipeDirection.leftToRight => horizontalDelta > 0,
      LingEdgeSwipeDirection.rightToLeft => horizontalDelta < 0,
    };
    if (!isAllowedDirection ||
        horizontalDistance < _dragActivationDistance ||
        horizontalDistance <= verticalDistance) {
      return;
    }

    _animationController.stop();
    _isAnimatingBack = false;
    _isEdgeDragActive = true;
    _activeSwipeDirection = direction;
    setState(() {
      _underlayDirection = direction;
      _dragOffset = switch (direction) {
        LingEdgeSwipeDirection.leftToRight => horizontalDelta.clamp(
          0,
          double.infinity,
        ),
        LingEdgeSwipeDirection.rightToLeft => horizontalDelta.clamp(
          double.negativeInfinity,
          0,
        ),
      };
    });
    _reportSwipeState();
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _trackedPointer) {
      return;
    }
    if (event is PointerCancelEvent) {
      if (_isEdgeDragActive && _dragOffset != 0) {
        _isEdgeDragActive = false;
        _activeSwipeDirection = null;
        _animateOffsetTo(0);
        _clearPointerTracking(clearUnderlay: false);
        return;
      }
      _clearPointerTracking(clearUnderlay: true);
      return;
    }
    if (_isCompletingBack) {
      _clearPointerTracking(clearUnderlay: false);
      return;
    }
    if (!_isEdgeDragActive || _dragOffset == 0) {
      _clearPointerTracking(clearUnderlay: true);
      return;
    }
    if (event is PointerUpEvent) {
      _velocityTracker?.addPosition(event.timeStamp, event.localPosition);
    }
    final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0.0;
    _handleDragEnd(velocity);
    _clearPointerTracking(clearUnderlay: false);
  }

  void _updateDragOffset(double primaryDelta) {
    if (primaryDelta == 0) {
      return;
    }
    final direction = _activeSwipeDirection;
    if (direction == null) {
      return;
    }
    setState(() {
      final nextOffset = _dragOffset + primaryDelta;
      _dragOffset = switch (direction) {
        LingEdgeSwipeDirection.leftToRight => nextOffset.clamp(
          0,
          double.infinity,
        ),
        LingEdgeSwipeDirection.rightToLeft => nextOffset.clamp(
          double.negativeInfinity,
          0,
        ),
      };
    });
    _reportSwipeState();
  }

  void _handleDragEnd(double primaryVelocity) {
    if (!_isEdgeDragActive || _isCompletingBack) {
      _isEdgeDragActive = false;
      return;
    }
    _isEdgeDragActive = false;
    final direction = _activeSwipeDirection;
    _activeSwipeDirection = null;
    if (direction == null) {
      _animateOffsetTo(0);
      return;
    }
    final width = context.size?.width ?? 0;
    final shouldComplete =
        switch (direction) {
          LingEdgeSwipeDirection.leftToRight =>
            primaryVelocity >= widget.completionVelocity,
          LingEdgeSwipeDirection.rightToLeft =>
            primaryVelocity <= -widget.completionVelocity,
        } ||
        (width > 0 && _dragOffset.abs() / width >= widget.completionProgress);
    if (shouldComplete) {
      _completeBack(width, direction);
      return;
    }
    _animateOffsetTo(0);
  }

  void _clearPointerTracking({required bool clearUnderlay}) {
    _trackedPointer = null;
    _dragStartLocalPosition = null;
    _pendingSwipeDirection = null;
    _velocityTracker = null;
    if (!clearUnderlay || _dragOffset != 0 || _underlayDirection == null) {
      return;
    }
    setState(() {
      _underlayDirection = null;
    });
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
          _underlayDirection = null;
        });
        _reportSwipeState(force: true);
      });
  }

  Future<bool> _animateBack() async {
    if (!mounted || !widget.enabled) {
      return false;
    }
    if (_isCompletingBack) {
      return true;
    }
    _animationController.stop();
    _isEdgeDragActive = false;
    _isAnimatingBack = false;
    _activeSwipeDirection = null;
    _clearPointerTracking(clearUnderlay: false);
    _underlayDirection = widget.programmaticDirection;
    _completeBack(
      context.size?.width ?? MediaQuery.sizeOf(context).width,
      widget.programmaticDirection,
    );
    return true;
  }

  void _completeBack(double width, LingEdgeSwipeDirection direction) {
    if (_isCompletingBack) {
      return;
    }
    _isCompletingBack = true;
    final onSwipeBackCompleted = widget.onSwipeBackCompleted;
    final onSwipeBackDirectionCompleted = widget.onSwipeBackDirectionCompleted;
    final onBack = widget.onBack;
    final onBackForDirection = widget.onBackForDirection;
    _underlayDirection = direction;
    final targetDistance = width > 0
        ? width
        : (_dragOffset.abs() > 0 ? _dragOffset.abs() : 0.0);
    final double targetOffset = switch (direction) {
      LingEdgeSwipeDirection.leftToRight => targetDistance,
      LingEdgeSwipeDirection.rightToLeft => -targetDistance,
    };
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
        if (widget.keepCompletedOffsetUntilBack) {
          _reportSwipeState(force: true);
          onSwipeBackDirectionCompleted?.call(direction);
          onSwipeBackCompleted?.call();
          if (onBackForDirection != null) {
            onBackForDirection(direction);
          } else {
            onBack();
          }
          return;
        }
        setState(() {
          _dragOffset = 0;
          _isCompletingBack = false;
          _isAnimatingBack = false;
          _underlayDirection = null;
        });
        _reportSwipeState(force: true);
        if (!widget.keepCompletedOffsetUntilBack) {
          onSwipeBackDirectionCompleted?.call(direction);
          onSwipeBackCompleted?.call();
          if (onBackForDirection != null) {
            onBackForDirection(direction);
          } else {
            onBack();
          }
        }
      });
  }

  double _swipeProgressForWidth(double width) {
    if (width <= 0) {
      return 0;
    }
    return (_dragOffset.abs() / width).clamp(0.0, 1.0);
  }

  void _reportSwipeState({bool force = false}) {
    final width = context.size?.width ?? 0;
    final progress = _swipeProgressForWidth(width);
    final isSwipeActive = progress > 0;
    if (force || (progress - _lastReportedProgress).abs() > 0.001) {
      _lastReportedProgress = progress;
      widget.onSwipeProgressChanged?.call(progress);
    }
    if (force || isSwipeActive != _lastReportedSwipeActivity) {
      _lastReportedSwipeActivity = isSwipeActive;
      widget.onSwipeActivityChanged?.call(isSwipeActive);
    }
  }

  @override
  Widget build(BuildContext context) {
    final underlayChild =
        widget.underlayBuilder?.call(_underlayDirection) ??
        widget.underlayChild;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.enabled ? _handlePointerDown : null,
      onPointerMove: widget.enabled ? _handlePointerMove : null,
      onPointerUp: widget.enabled ? _handlePointerEnd : null,
      onPointerCancel: widget.enabled ? _handlePointerEnd : null,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (underlayChild != null)
              IgnorePointer(ignoring: true, child: underlayChild),
            Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
