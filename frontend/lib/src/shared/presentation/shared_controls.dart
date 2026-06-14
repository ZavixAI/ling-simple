import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

class LingFloatingIconButton extends StatelessWidget {
  const LingFloatingIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.size = 46,
    this.iconSize = 22,
    this.iconColor,
    this.useOwnLayer = true,
    this.tintColor,
    this.thickness,
    this.blur,
    this.chromaticAberration,
    this.lightIntensity,
    this.ambientStrength,
    this.refractiveIndex,
    this.saturation,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final bool useOwnLayer;
  final Color? tintColor;
  final double? thickness;
  final double? blur;
  final double? chromaticAberration;
  final double? lightIntensity;
  final double? ambientStrength;
  final double? refractiveIndex;
  final double? saturation;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return LingGlassIconButton(
      icon: icon,
      onPressed: onTap,
      semanticLabel: semanticLabel,
      size: size,
      iconSize: iconSize,
      iconColor:
          iconColor ??
          (context.isDarkMode ? palette.textPrimary : palette.textSecondary),
      tone: LingGlassSurfaceTone.control,
      tintColor: tintColor ?? lingGlassControlTintFor(context, palette),
      glowColor: palette.glassHighlight,
      quality: LingGlassQuality.premium,
      useOwnLayer: useOwnLayer,
      thickness: thickness,
      blur: blur,
      chromaticAberration: chromaticAberration,
      lightIntensity: lightIntensity,
      ambientStrength: ambientStrength,
      refractiveIndex: refractiveIndex,
      saturation: saturation,
    );
  }
}

Color lingFloatingControlTintFor(BuildContext context, LingPalette palette) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (context.isDarkMode) {
    return palette.surfaceHigh.withValues(alpha: 0.54);
  }
  return palette.surface.withValues(
    alpha: mediaQuery?.highContrast ?? false ? 0.54 : 0.38,
  );
}

class LingFloatingIconButtonFrame extends StatelessWidget {
  const LingFloatingIconButtonFrame({
    super.key,
    required this.child,
    this.dimension = 46,
    this.showRefractionGlow = true,
    this.borderStrength = 0.74,
  });

  final Widget child;
  final double dimension;
  final bool showRefractionGlow;
  final double borderStrength;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox.square(
      dimension: dimension,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _floatingButtonBaseColorFor(context, palette),
        ),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: _floatingButtonEdgeBorderFor(
              context,
              palette,
              strength: borderStrength,
            ),
          ),
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _FloatingButtonLocalBackdrop(),
                if (showRefractionGlow) const _FloatingButtonRefractionGlow(),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _floatingButtonBaseColorFor(BuildContext context, LingPalette palette) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (context.isDarkMode) {
    return palette.surfaceHigh.withValues(alpha: 0.52);
  }
  return palette.surface.withValues(
    alpha: mediaQuery?.highContrast ?? false ? 0.42 : 0.22,
  );
}

Border _floatingButtonEdgeBorderFor(
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

class _FloatingButtonLocalBackdrop extends StatelessWidget {
  const _FloatingButtonLocalBackdrop();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      key: const Key('floating_button_local_backdrop'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.isDarkMode
              ? [
                  palette.surfaceHigh.withValues(alpha: 0.64),
                  palette.surface.withValues(alpha: 0.48),
                ]
              : [
                  palette.surface.withValues(alpha: 0.30),
                  Color.lerp(
                    palette.surface,
                    palette.textSecondary,
                    0.035,
                  )!.withValues(alpha: 0.16),
                ],
        ),
      ),
    );
  }
}

class _FloatingButtonRefractionGlow extends StatelessWidget {
  const _FloatingButtonRefractionGlow();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      key: const Key('floating_button_refraction_glow'),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.42, -0.36),
          radius: 0.95,
          colors: context.isDarkMode
              ? [
                  palette.glassHighlight.withValues(alpha: 0.12),
                  palette.accent.withValues(alpha: 0.06),
                  Colors.transparent,
                ]
              : [
                  palette.surface.withValues(alpha: 0.18),
                  palette.surface.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
          stops: const [0, 0.56, 1],
        ),
      ),
    );
  }
}

class LingLabeledField extends StatelessWidget {
  const LingLabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
