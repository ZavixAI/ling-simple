import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';

class LingTypingIndicator extends StatefulWidget {
  const LingTypingIndicator({super.key, this.dotSize = 8});

  final double dotSize;

  @override
  State<LingTypingIndicator> createState() => _LingTypingIndicatorState();
}

class _LingTypingIndicatorState extends State<LingTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (index) {
            final progress = (_controller.value + index * 0.18) % 1;
            final emphasis = 1 - ((progress - 0.5).abs() * 2).clamp(0.0, 1.0);
            final opacity = 0.3 + (emphasis * 0.7);
            final scale = 0.82 + (emphasis * 0.3);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.dotSize * 0.18),
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.dotSize,
                    height: widget.dotSize,
                    decoration: BoxDecoration(
                      color: palette.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
