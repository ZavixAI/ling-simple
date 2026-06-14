import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';

List<BoxShadow> lingConversationCardShadowFor(
  BuildContext context,
  LingPalette palette, {
  double strength = 1,
}) {
  if (context.isDarkMode) {
    return const <BoxShadow>[];
  }
  return [
    BoxShadow(
      color: palette.shadow.withValues(alpha: 0.12 * strength),
      blurRadius: 18 * strength,
      offset: Offset(0, 6 * strength),
    ),
    BoxShadow(
      color: palette.shadow.withValues(alpha: 0.07 * strength),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
}

Border lingConversationFloatingEdgeBorderFor(
  BuildContext context,
  LingPalette palette, {
  double strength = 1,
}) {
  final alpha = (context.isDarkMode ? 0.18 : 0.58) * strength;
  return Border.all(
    color: context.isDarkMode
        ? palette.glassBorder.withValues(alpha: alpha)
        : palette.outlineSoft.withValues(alpha: alpha),
    width: 0.7,
  );
}

class LingConversationCardChrome extends StatelessWidget {
  const LingConversationCardChrome({
    super.key,
    required this.child,
    required this.borderRadius,
    this.strength = 1,
  });

  final Widget child;
  final BorderRadiusGeometry borderRadius;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: lingConversationCardShadowFor(
          context,
          palette,
          strength: strength,
        ),
      ),
      child: child,
    );
  }
}
