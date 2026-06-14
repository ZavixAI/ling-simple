import 'package:flutter/material.dart';

import 'package:ling/src/shared/presentation/liquid_glass.dart';

class LingSurfaceGroup extends StatelessWidget {
  const LingSurfaceGroup({
    super.key,
    required this.child,
    this.hasBackground = true,
  });

  final Widget child;
  final bool hasBackground;

  @override
  Widget build(BuildContext context) {
    if (!hasBackground) {
      return child;
    }
    return LingGlassSurface(child: child);
  }
}
