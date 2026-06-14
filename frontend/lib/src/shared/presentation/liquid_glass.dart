import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/shared/presentation/tap_haptics.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

enum LingGlassQuality { standard, premium }

enum LingGlassSurfaceTone { regular, muted, elevated, accent, control }

const Key _lingGlassButtonBorderKey = Key('ling_glass_button_border');
const Key _lingGlassIconButtonBorderKey = Key('ling_glass_icon_button_border');
const Key _lingGlassChipBorderKey = Key('ling_glass_chip_border');
const Key _lingGlassSliderThumbBorderKey = Key(
  'ling_glass_slider_thumb_border',
);

const double _lingGlassSliderThumbRadius = 15;
const double _lingGlassSliderTrackHeight = 4;

GlassQuality lingGlassQualityFor(LingGlassQuality quality) {
  return switch (quality) {
    LingGlassQuality.standard => GlassQuality.standard,
    LingGlassQuality.premium => GlassQuality.standard,
  };
}

GlassThemeData lingGlassThemeDataFor(BuildContext context) {
  final palette = context.palette;
  final brightness = Theme.of(context).brightness;
  final isDark = brightness == Brightness.dark;
  final variant = GlassThemeVariant(
    settings: GlassThemeSettings(
      thickness: isDark ? 18 : 30,
      blur: isDark ? 7 : 8,
      glassColor: isDark ? palette.glassTint : palette.glassElevatedTint,
      chromaticAberration: isDark ? 0.006 : 0.018,
      refractiveIndex: isDark ? 1.12 : 1.26,
      saturation: isDark ? 1.04 : 1.32,
      lightIntensity: isDark ? 0.58 : 1.08,
      ambientStrength: isDark ? 0.32 : 0.48,
      specularSharpness: GlassSpecularSharpness.medium,
    ),
    quality: GlassQuality.standard,
    glowColors: GlassGlowColors(
      primary: isDark
          ? Colors.white.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.44),
      secondary: palette.glassHighlight,
      success: palette.success,
      warning: palette.warning,
      danger: palette.danger,
      info: palette.info,
      glowBlurRadius: isDark ? 10 : 14,
      glowSpreadRadius: 0.12,
      glowOpacity: isDark ? 0.72 : 0.86,
    ),
    borderRadius: 24,
  );
  return GlassThemeData(light: variant, dark: variant);
}

LiquidGlassSettings lingGlassSettingsFor(
  BuildContext context,
  LingGlassSurfaceTone tone, {
  Color? tintColor,
  double? thickness,
  double? blur,
  double? chromaticAberration,
  double? lightIntensity,
  double? ambientStrength,
  double? refractiveIndex,
  double? saturation,
  double? lightAngle,
  GlassSpecularSharpness? specularSharpness,
}) {
  final palette = context.palette;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final tint =
      tintColor ??
      switch (tone) {
        LingGlassSurfaceTone.regular => palette.glassTint,
        LingGlassSurfaceTone.muted => palette.glassMutedTint,
        LingGlassSurfaceTone.elevated => palette.glassElevatedTint,
        LingGlassSurfaceTone.accent => palette.primaryButtonBackground,
        LingGlassSurfaceTone.control => lingGlassControlTintFor(
          context,
          palette,
        ),
      };
  final resolvedBlur =
      blur ??
      switch (tone) {
        LingGlassSurfaceTone.control => 4.0,
        LingGlassSurfaceTone.accent => isDark ? 6.0 : 7.0,
        LingGlassSurfaceTone.elevated => isDark ? 8.0 : 9.0,
        _ => isDark ? 7.0 : 8.0,
      };

  return LiquidGlassSettings(
    thickness:
        thickness ??
        switch (tone) {
          LingGlassSurfaceTone.control => 30,
          LingGlassSurfaceTone.accent => isDark ? 18 : 28,
          _ => isDark ? 20 : 32,
        },
    blur: resolvedBlur,
    glassColor: tint,
    chromaticAberration:
        chromaticAberration ??
        switch (tone) {
          LingGlassSurfaceTone.control => isDark ? 0.006 : 0.018,
          LingGlassSurfaceTone.accent => isDark ? 0.004 : 0.012,
          _ => isDark ? 0.006 : 0.018,
        },
    refractiveIndex:
        refractiveIndex ??
        (tone == LingGlassSurfaceTone.control
            ? (isDark ? 1.16 : 1.26)
            : isDark
            ? 1.12
            : 1.26),
    saturation:
        saturation ??
        (tone == LingGlassSurfaceTone.control
            ? (isDark ? 1.08 : 1.32)
            : isDark
            ? 1.04
            : 1.34),
    lightIntensity:
        lightIntensity ??
        (tone == LingGlassSurfaceTone.control
            ? (isDark ? 0.72 : 1.08)
            : isDark
            ? 0.58
            : 1.02),
    ambientStrength:
        ambientStrength ??
        (tone == LingGlassSurfaceTone.control
            ? (isDark ? 1.08 : 2.0)
            : isDark
            ? 0.34
            : 0.52),
    lightAngle:
        lightAngle ??
        (tone == LingGlassSurfaceTone.control ? 0.75 * math.pi : 0),
    specularSharpness: specularSharpness ?? GlassSpecularSharpness.medium,
  );
}

LiquidGlassSettings? _settingsForLayerMode(
  BuildContext context, {
  required bool useOwnLayer,
  required LiquidGlassSettings settings,
}) {
  if (useOwnLayer || InheritedLiquidGlass.of(context) == null) {
    return settings;
  }
  return null;
}

Color lingGlassPanelTintFor(BuildContext context, LingPalette palette) {
  final mediaQuery = MediaQuery.of(context);
  if (mediaQuery.highContrast) {
    return context.isDarkMode
        ? palette.surface.withValues(alpha: 0.88)
        : palette.surface.withValues(alpha: 0.90);
  }
  return context.isDarkMode
      ? palette.surface.withValues(alpha: 0.86)
      : palette.surface.withValues(alpha: 0.96);
}

Color lingGlassControlTintFor(BuildContext context, LingPalette palette) {
  final mediaQuery = MediaQuery.of(context);
  if (mediaQuery.highContrast) {
    return context.isDarkMode
        ? palette.surface.withValues(alpha: 0.88)
        : palette.surface.withValues(alpha: 0.90);
  }
  return context.isDarkMode
      ? palette.surfaceHigh.withValues(alpha: 0.28)
      : palette.surface.withValues(alpha: 0.64);
}

Color lingGlassPromptActionTintFor(BuildContext context, LingPalette palette) {
  if (MediaQuery.of(context).highContrast) {
    return lingGlassControlTintFor(context, palette);
  }
  return context.isDarkMode
      ? palette.glassHighlight.withValues(alpha: 0.12)
      : palette.glassElevatedTint.withValues(alpha: 0.82);
}

LiquidGlassSettings lingGlassPromptActionSettingsFor(
  BuildContext context, {
  Color? tintColor,
}) {
  return LiquidGlassSettings(
    thickness: 5,
    blur: 5,
    ambientStrength: 0.3,
    lightAngle: 0.75 * math.pi,
    glassColor:
        tintColor ?? lingGlassPromptActionTintFor(context, context.palette),
  );
}

BorderSide _lingGlassControlBorderSideFor(
  BuildContext context,
  LingPalette palette, {
  bool enabled = true,
}) {
  final opacity = enabled ? 1.0 : 0.58;
  return BorderSide(
    color: context.isDarkMode
        ? palette.glassBorder.withValues(alpha: 0.44 * opacity)
        : palette.fieldBorder.withValues(alpha: 0.82 * opacity),
    width: context.isDarkMode ? 0.65 : 1,
  );
}

List<BoxShadow> _lingGlassControlShadowsFor(
  BuildContext context,
  LingPalette palette, {
  bool enabled = true,
}) {
  final alpha = enabled ? 1.0 : 0.62;
  return [
    BoxShadow(
      color: palette.shadow.withValues(
        alpha: (context.isDarkMode ? 0.18 : 0.13) * alpha,
      ),
      blurRadius: context.isDarkMode ? 16 : 22,
      offset: Offset(0, context.isDarkMode ? 6 : 8),
    ),
    BoxShadow(
      color: palette.glassHighlight.withValues(
        alpha: context.isDarkMode ? 0.02 * alpha : 0.36 * alpha,
      ),
      blurRadius: 1,
      offset: const Offset(0, 1),
    ),
  ];
}

BorderSide _lingGlassSurfaceBorderSideFor(
  BuildContext context,
  LingPalette palette,
) {
  return BorderSide(
    color: context.isDarkMode
        ? palette.glassBorder.withValues(alpha: 0.34)
        : palette.fieldBorder.withValues(alpha: 0.52),
    width: context.isDarkMode ? 0.65 : 1,
  );
}

List<BoxShadow> _lingGlassSurfaceShadowsFor(
  BuildContext context,
  LingPalette palette,
) {
  return [
    BoxShadow(
      color: palette.shadow.withValues(alpha: context.isDarkMode ? 0.14 : 0.08),
      blurRadius: context.isDarkMode ? 18 : 26,
      offset: Offset(0, context.isDarkMode ? 8 : 12),
    ),
  ];
}

Widget _withLingGlassSurfaceChrome({
  required BuildContext context,
  required LingPalette palette,
  required double radius,
  required Widget child,
}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: _lingGlassSurfaceShadowsFor(context, palette),
    ),
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: _lingGlassSurfaceBorderSideFor(context, palette),
        ),
      ),
      child: child,
    ),
  );
}

class LingLongPressScale extends StatefulWidget {
  const LingLongPressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 1.08,
    this.highlightRadius = 999,
    this.duration = const Duration(milliseconds: 110),
    this.reverseDuration = const Duration(milliseconds: 130),
  });

  final Widget child;
  final bool enabled;
  final double scale;
  final double highlightRadius;
  final Duration duration;
  final Duration reverseDuration;

  @override
  State<LingLongPressScale> createState() => _LingLongPressScaleState();
}

class _LingLongPressScaleState extends State<LingLongPressScale> {
  bool _selected = false;

  void _setSelected(bool selected) {
    if (!widget.enabled || _selected == selected) {
      return;
    }
    setState(() {
      _selected = selected;
    });
  }

  @override
  void didUpdateWidget(covariant LingLongPressScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _selected) {
      _selected = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.enabled ? (_) => _setSelected(true) : null,
      onPointerUp: widget.enabled ? (_) => _setSelected(false) : null,
      onPointerCancel: widget.enabled ? (_) => _setSelected(false) : null,
      child: AnimatedScale(
        scale: _selected ? widget.scale : 1,
        duration: _selected ? widget.duration : widget.reverseDuration,
        curve: _selected ? Curves.easeOutBack : Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class LingGlassLayer extends StatelessWidget {
  const LingGlassLayer({
    super.key,
    required this.child,
    this.tone = LingGlassSurfaceTone.regular,
    this.tintColor,
    this.thickness,
    this.blur,
    this.chromaticAberration,
    this.lightIntensity,
    this.ambientStrength,
    this.refractiveIndex,
    this.saturation,
    this.lightAngle,
    this.specularSharpness,
    this.quality = LingGlassQuality.standard,
    this.blend = 10,
  });

  final Widget child;
  final LingGlassSurfaceTone tone;
  final Color? tintColor;
  final double? thickness;
  final double? blur;
  final double? chromaticAberration;
  final double? lightIntensity;
  final double? ambientStrength;
  final double? refractiveIndex;
  final double? saturation;
  final double? lightAngle;
  final GlassSpecularSharpness? specularSharpness;
  final LingGlassQuality quality;
  final double blend;

  @override
  Widget build(BuildContext context) {
    return AdaptiveLiquidGlassLayer(
      settings: lingGlassSettingsFor(
        context,
        tone,
        tintColor: tintColor,
        thickness: thickness,
        blur: blur,
        chromaticAberration: chromaticAberration,
        lightIntensity: lightIntensity,
        ambientStrength: ambientStrength,
        refractiveIndex: refractiveIndex,
        saturation: saturation,
        lightAngle: lightAngle,
        specularSharpness: specularSharpness,
      ),
      quality: lingGlassQualityFor(quality),
      blendAmount: blend,
      child: child,
    );
  }
}

class LingGlassBlendGroup extends StatelessWidget {
  const LingGlassBlendGroup({super.key, required this.child, this.blend = 10});

  final Widget child;
  final double blend;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassBlendGroup(blend: blend, child: child);
  }
}

class LingGlassSurface extends StatelessWidget {
  const LingGlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.constraints,
    this.width,
    this.height,
    this.alignment,
    this.radius = 20,
    this.tone = LingGlassSurfaceTone.regular,
    this.quality = LingGlassQuality.standard,
    this.clipBehavior = Clip.antiAlias,
    this.tintColor,
    this.thickness,
    this.blur,
    this.chromaticAberration,
    this.lightIntensity,
    this.ambientStrength,
    this.refractiveIndex,
    this.saturation,
    this.lightAngle,
    this.specularSharpness,
    this.useOwnLayer = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxConstraints? constraints;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final double radius;
  final LingGlassSurfaceTone tone;
  final LingGlassQuality quality;
  final Clip clipBehavior;
  final Color? tintColor;
  final double? thickness;
  final double? blur;
  final double? chromaticAberration;
  final double? lightIntensity;
  final double? ambientStrength;
  final double? refractiveIndex;
  final double? saturation;
  final double? lightAngle;
  final GlassSpecularSharpness? specularSharpness;
  final bool useOwnLayer;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final settings = lingGlassSettingsFor(
      context,
      tone,
      tintColor: tintColor,
      thickness: thickness,
      blur: blur,
      chromaticAberration: chromaticAberration,
      lightIntensity: lightIntensity,
      ambientStrength: ambientStrength,
      refractiveIndex: refractiveIndex,
      saturation: saturation,
      lightAngle: lightAngle,
      specularSharpness: specularSharpness,
    );
    Widget content = GlassContainer(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      alignment: alignment,
      shape: LiquidRoundedSuperellipse(borderRadius: radius),
      settings: _settingsForLayerMode(
        context,
        useOwnLayer: useOwnLayer,
        settings: settings,
      ),
      useOwnLayer: useOwnLayer,
      quality: lingGlassQualityFor(quality),
      clipBehavior: clipBehavior,
      child: child,
    );

    content = _withLingGlassSurfaceChrome(
      context: context,
      palette: palette,
      radius: radius,
      child: content,
    );

    if (constraints != null) {
      content = ConstrainedBox(constraints: constraints!, child: content);
    }
    return content;
  }
}

class LingGlassIconButton extends StatelessWidget {
  const LingGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    this.size = 46,
    this.iconSize = 22,
    this.iconColor,
    this.tintColor,
    this.tone = LingGlassSurfaceTone.regular,
    this.glowColor,
    this.interactionScale = 1,
    this.stretch = 0,
    this.quality = LingGlassQuality.standard,
    this.thickness,
    this.blur,
    this.chromaticAberration,
    this.lightIntensity,
    this.ambientStrength,
    this.refractiveIndex,
    this.saturation,
    this.lightAngle,
    this.specularSharpness,
    this.useOwnLayer = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final Color? tintColor;
  final LingGlassSurfaceTone tone;
  final Color? glowColor;
  final double interactionScale;
  final double stretch;
  final LingGlassQuality quality;
  final double? thickness;
  final double? blur;
  final double? chromaticAberration;
  final double? lightIntensity;
  final double? ambientStrength;
  final double? refractiveIndex;
  final double? saturation;
  final double? lightAngle;
  final GlassSpecularSharpness? specularSharpness;
  final bool useOwnLayer;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final resolvedIconColor = iconColor ?? palette.textSecondary;
    final settings = lingGlassSettingsFor(
      context,
      tone,
      tintColor: tintColor,
      thickness: thickness,
      blur: blur,
      chromaticAberration: chromaticAberration,
      lightIntensity: lightIntensity,
      ambientStrength: ambientStrength,
      refractiveIndex: refractiveIndex,
      saturation: saturation,
      lightAngle: lightAngle,
      specularSharpness: specularSharpness,
    );

    final button = GlassIconButton(
      icon: Icon(icon, color: resolvedIconColor),
      onPressed: LingTapHaptics.wrap(onPressed),
      size: size,
      iconSize: iconSize,
      glowColor: glowColor ?? palette.glassHighlight,
      glowRadius: 1.1,
      interactionScale: interactionScale <= 0 ? 0.96 : interactionScale,
      useOwnLayer: useOwnLayer,
      settings: _settingsForLayerMode(
        context,
        useOwnLayer: useOwnLayer,
        settings: settings,
      ),
      quality: lingGlassQualityFor(quality),
    );

    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onPressed != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: _lingGlassControlShadowsFor(
            context,
            palette,
            enabled: onPressed != null,
          ),
        ),
        child: DecoratedBox(
          key: _lingGlassIconButtonBorderKey,
          position: DecorationPosition.foreground,
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(size / 2),
              side: _lingGlassControlBorderSideFor(
                context,
                palette,
                enabled: onPressed != null,
              ),
            ),
          ),
          child: button,
        ),
      ),
    );
  }
}

class LingGlassButton extends StatelessWidget {
  const LingGlassButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.minHeight = 54,
    this.width,
    this.expand = true,
    this.radius = 24,
    this.tone = LingGlassSurfaceTone.accent,
    this.foregroundColor,
    this.disabledForegroundColor,
    this.tintColor,
    this.disabledTintColor,
    this.glowColor,
    this.settings,
    this.quality = LingGlassQuality.standard,
    this.showBorder = true,
    this.interactionScale,
    this.stretch,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double minHeight;
  final double? width;
  final bool expand;
  final double radius;
  final LingGlassSurfaceTone tone;
  final Color? foregroundColor;
  final Color? disabledForegroundColor;
  final Color? tintColor;
  final Color? disabledTintColor;
  final Color? glowColor;
  final LiquidGlassSettings? settings;
  final LingGlassQuality quality;
  final bool showBorder;
  final double? interactionScale;
  final double? stretch;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null;
    final defaultForeground = tone == LingGlassSurfaceTone.accent
        ? palette.primaryButtonForeground
        : palette.textPrimary;
    final defaultDisabledForeground = tone == LingGlassSurfaceTone.accent
        ? palette.primaryButtonDisabledForeground
        : defaultForeground.withValues(alpha: 0.72);
    final resolvedForeground = enabled
        ? (foregroundColor ?? defaultForeground)
        : (disabledForegroundColor ??
              foregroundColor ??
              defaultDisabledForeground);
    final resolvedTint = enabled
        ? (tintColor ??
              (tone == LingGlassSurfaceTone.accent
                  ? palette.primaryButtonBackground
                  : null))
        : (disabledTintColor ??
              tintColor ??
              (tone == LingGlassSurfaceTone.accent
                  ? palette.primaryButtonDisabledBackground
                  : null));
    final borderSide = _lingGlassButtonBorderSideFor(
      context,
      palette,
      tone,
      resolvedTint,
      enabled,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth =
            width ??
            (expand && constraints.hasBoundedWidth
                ? constraints.maxWidth
                : 160.0);
        final defaultTextStyle = TextStyle(
          color: resolvedForeground,
          fontSize: minHeight <= 44 ? 15 : 17,
          height: 1.08,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        );
        final content = DefaultTextStyle.merge(
          style: defaultTextStyle,
          child: IconTheme.merge(
            data: IconThemeData(color: resolvedForeground),
            child: SizedBox(
              width: resolvedWidth,
              height: minHeight,
              child: Center(child: child),
            ),
          ),
        );

        return SizedBox(
          width: resolvedWidth,
          height: minHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: _lingGlassControlShadowsFor(
                context,
                palette,
                enabled: enabled,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GlassButton.custom(
                  onTap: LingTapHaptics.wrap(onPressed) ?? () {},
                  enabled: enabled,
                  width: resolvedWidth,
                  height: minHeight,
                  shape: LiquidRoundedSuperellipse(borderRadius: radius),
                  settings:
                      settings ??
                      lingGlassSettingsFor(
                        context,
                        tone,
                        tintColor: resolvedTint,
                      ),
                  useOwnLayer: true,
                  quality: lingGlassQualityFor(quality),
                  interactionScale: interactionScale ?? (enabled ? 1.02 : 1),
                  stretch: stretch ?? (enabled ? 0.12 : 0),
                  glowColor: enabled
                      ? (glowColor ?? palette.glassHighlight)
                      : Colors.transparent,
                  child: content,
                ),
                if (showBorder)
                  IgnorePointer(
                    child: DecoratedBox(
                      key: _lingGlassButtonBorderKey,
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radius),
                          side: borderSide,
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

BorderSide _lingGlassButtonBorderSideFor(
  BuildContext context,
  LingPalette palette,
  LingGlassSurfaceTone tone,
  Color? tintColor,
  bool enabled,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final opacity = enabled ? 1.0 : 0.58;
  final color = switch (tone) {
    LingGlassSurfaceTone.accent =>
      (tintColor ?? palette.primaryButtonBackground).withValues(
        alpha: isDark ? 0.26 * opacity : 0.24 * opacity,
      ),
    _ =>
      isDark
          ? palette.glassBorder.withValues(alpha: 0.48 * opacity)
          : palette.fieldBorder.withValues(alpha: 0.96 * opacity),
  };
  return BorderSide(color: color, width: isDark ? 0.65 : 1);
}

class LingGlassChip extends StatelessWidget {
  const LingGlassChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.height = 34,
    this.maxWidth = 180,
    this.padding = const EdgeInsets.symmetric(horizontal: 13),
    this.textStyle,
    this.foregroundColor,
    this.tintColor,
    this.glowColor,
    this.quality = LingGlassQuality.standard,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final double height;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;
  final Color? foregroundColor;
  final Color? tintColor;
  final Color? glowColor;
  final LingGlassQuality quality;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null;
    final resolvedForeground = foregroundColor ?? palette.textSecondary;
    final resolvedTextStyle =
        textStyle ??
        TextStyle(
          color: resolvedForeground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        );

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              boxShadow: _lingGlassControlShadowsFor(
                context,
                palette,
                enabled: enabled,
              ),
            ),
            child: DecoratedBox(
              key: _lingGlassChipBorderKey,
              position: DecorationPosition.foreground,
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(height / 2),
                  side: _lingGlassControlBorderSideFor(
                    context,
                    palette,
                    enabled: enabled,
                  ),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: GlassChip(
                  label: label,
                  icon: leadingIcon == null ? null : Icon(leadingIcon),
                  onTap: LingTapHaptics.wrap(onPressed),
                  iconSize: 17,
                  iconColor: resolvedForeground,
                  labelStyle: resolvedTextStyle.copyWith(
                    color: resolvedForeground,
                  ),
                  padding: padding,
                  settings: lingGlassSettingsFor(
                    context,
                    LingGlassSurfaceTone.regular,
                    tintColor: tintColor,
                  ),
                  useOwnLayer: true,
                  quality: lingGlassQualityFor(quality),
                  interactionScale: 1.03,
                  stretch: 0.16,
                  glowRadius: 0.8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LingGlassTextField extends StatelessWidget {
  const LingGlassTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLength,
    this.readOnly = false,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.minLines,
    this.maxLines = 1,
    this.enabled = true,
    this.textStyle,
    this.placeholderStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.radius = 18,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int? maxLength;
  final bool readOnly;
  final bool autofocus;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final int? minLines;
  final int maxLines;
  final bool enabled;
  final TextStyle? textStyle;
  final TextStyle? placeholderStyle;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final resolvedTextStyle =
        textStyle ?? TextStyle(fontSize: 16, color: palette.inputForeground);
    final resolvedPlaceholderStyle =
        placeholderStyle ??
        TextStyle(fontSize: 16, color: palette.inputPlaceholder);

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(color: palette.fieldBorder),
          ),
        ),
        child: GlassContainer(
          padding: padding,
          shape: LiquidRoundedSuperellipse(borderRadius: radius),
          settings: lingGlassSettingsFor(
            context,
            LingGlassSurfaceTone.muted,
            tintColor: palette.inputBackground,
            blur: context.isDarkMode ? 7 : 5,
            lightIntensity: context.isDarkMode ? 0.58 : 0.76,
          ),
          useOwnLayer: true,
          quality: GlassQuality.standard,
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                prefixIcon!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    obscureText: obscureText,
                    keyboardType: keyboardType,
                    textInputAction: textInputAction,
                    maxLength: maxLength,
                    readOnly: readOnly,
                    autofocus: autofocus,
                    autocorrect: autocorrect,
                    enableSuggestions: enableSuggestions,
                    textCapitalization: textCapitalization,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    inputFormatters: inputFormatters,
                    minLines: minLines,
                    maxLines: maxLines,
                    enabled: enabled,
                    cursorColor: palette.inputCursor,
                    style: resolvedTextStyle,
                    decoration: InputDecoration(
                      hintText: placeholder,
                      hintStyle: resolvedPlaceholderStyle,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      counterText: '',
                    ),
                  ),
                ),
              ),
              if (suffixIcon != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: LingTapHaptics.wrap(onSuffixTap),
                  child: suffixIcon,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LingGlassSheetFrame extends StatelessWidget {
  const LingGlassSheetFrame({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 28,
    this.maxWidth,
    this.showDragHandle = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double? maxWidth;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget content = child;
    if (showDragHandle) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: 42,
              child: GlassDivider(
                thickness: 4,
                height: 4,
                color: palette.textSecondary.withValues(alpha: 0.28),
              ),
            ),
          ),
          content,
        ],
      );
    }
    Widget surface = GlassCard(
      padding: padding ?? EdgeInsets.zero,
      margin: margin,
      shape: LiquidRoundedSuperellipse(borderRadius: radius),
      settings: lingGlassSettingsFor(context, LingGlassSurfaceTone.elevated),
      useOwnLayer: true,
      quality: GlassQuality.standard,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
    surface = _withLingGlassSurfaceChrome(
      context: context,
      palette: palette,
      radius: radius,
      child: surface,
    );
    if (maxWidth != null) {
      surface = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: surface,
      );
    }
    return surface;
  }
}

class LingGlassPanel extends StatelessWidget {
  const LingGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.width,
    this.height,
    this.radius = 24,
    this.tone = LingGlassSurfaceTone.elevated,
    this.quality = LingGlassQuality.standard,
    this.clipBehavior = Clip.none,
    this.tintColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double radius;
  final LingGlassSurfaceTone tone;
  final LingGlassQuality quality;
  final Clip clipBehavior;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _withLingGlassSurfaceChrome(
      context: context,
      palette: palette,
      radius: radius,
      child: GlassCard(
        width: width,
        height: height,
        padding: padding,
        margin: margin,
        shape: LiquidRoundedSuperellipse(borderRadius: radius),
        settings: lingGlassSettingsFor(context, tone, tintColor: tintColor),
        useOwnLayer: true,
        quality: lingGlassQualityFor(quality),
        clipBehavior: clipBehavior,
        child: child,
      ),
    );
  }
}

class LingGlassListTile extends StatelessWidget {
  const LingGlassListTile({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.isLast = true,
    this.standalone = true,
    this.destructive = false,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 13,
    ),
  });

  final Widget title;
  final Widget? leading;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isLast;
  final bool standalone;
  final bool destructive;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = destructive ? palette.danger : palette.textPrimary;
    final titleStyle = TextStyle(
      color: foreground,
      fontSize: 16,
      fontWeight: FontWeight.w400,
    );
    final subtitleStyle = TextStyle(
      color: palette.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w400,
    );
    final iconColor = destructive ? palette.danger : palette.textPrimary;
    final settings = lingGlassSettingsFor(context, LingGlassSurfaceTone.muted);

    if (standalone) {
      return GlassListTile.standalone(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: LingTapHaptics.wrap(onTap),
        onLongPress: LingTapHaptics.wrap(onLongPress),
        contentPadding: contentPadding,
        leadingIconColor: iconColor,
        titleStyle: titleStyle,
        subtitleStyle: subtitleStyle,
        settings: _settingsForLayerMode(
          context,
          useOwnLayer: false,
          settings: settings,
        ),
        quality: GlassQuality.standard,
      );
    }

    return GlassListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: LingTapHaptics.wrap(onTap),
      onLongPress: LingTapHaptics.wrap(onLongPress),
      isLast: isLast,
      contentPadding: contentPadding,
      leadingIconColor: iconColor,
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
      dividerIndent: leading == null ? 16 : 60,
    );
  }
}

class LingGlassSlider extends StatelessWidget {
  const LingGlassSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedInactiveColor =
        inactiveColor ??
        (isDark
            ? palette.glassMutedTint
            : palette.fieldBorder.withValues(alpha: 0.88));
    final thumbBorderColor = isDark
        ? palette.glassBorder.withValues(alpha: 0.86)
        : palette.fieldBorder;

    return LayoutBuilder(
      builder: (context, constraints) {
        final normalizedValue = max == min
            ? 0.0
            : ((value - min) / (max - min)).clamp(0.0, 1.0);
        final thumbWidth = _lingGlassSliderThumbRadius * 2.6;
        final thumbHeight = _lingGlassSliderThumbRadius * 1.6;
        final sliderHeight = _lingGlassSliderThumbRadius * 2 + 16;
        final trackWidth =
            constraints.maxWidth - (_lingGlassSliderThumbRadius * 2);
        final thumbPosition =
            _lingGlassSliderThumbRadius + (trackWidth * normalizedValue);
        void emitTappedValue(double nextValue) {
          if (onChanged == null || nextValue == value) {
            return;
          }
          HapticFeedback.selectionClick();
          onChanged!(nextValue);
        }

        void handlePointerDown(PointerDownEvent event) {
          if (onChanged == null) {
            return;
          }
          final normalizedTap =
              ((event.localPosition.dx - _lingGlassSliderThumbRadius) /
                      trackWidth)
                  .clamp(0.0, 1.0);
          var nextValue = min + (normalizedTap * (max - min));
          if (divisions != null) {
            final stepSize = (max - min) / divisions!;
            nextValue = (nextValue / stepSize).round() * stepSize + min;
            nextValue = nextValue.clamp(min, max);
          }
          emitTappedValue(nextValue);
        }

        return SizedBox(
          height: sliderHeight,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: onChanged == null ? null : handlePointerDown,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GlassSlider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                  onChangeStart: onChangeStart,
                  onChangeEnd: onChangeEnd,
                  activeColor: activeColor ?? palette.primaryButtonBackground,
                  inactiveColor: resolvedInactiveColor,
                  thumbColor: thumbColor ?? palette.primaryButtonForeground,
                  trackHeight: _lingGlassSliderTrackHeight,
                  thumbRadius: _lingGlassSliderThumbRadius,
                  settings: lingGlassSettingsFor(
                    context,
                    LingGlassSurfaceTone.muted,
                  ),
                  useOwnLayer: true,
                  quality: GlassQuality.standard,
                  glowColor: palette.glassHighlight,
                ),
                Positioned(
                  left: thumbPosition - _lingGlassSliderThumbRadius,
                  top: (sliderHeight - thumbHeight) / 2,
                  width: thumbWidth,
                  height: thumbHeight,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: _lingGlassSliderThumbBorderKey,
                      decoration: ShapeDecoration(
                        shape: StadiumBorder(
                          side: BorderSide(color: thumbBorderColor),
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

class LingGlassTextArea extends StatelessWidget {
  const LingGlassTextArea({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.minLines = 3,
    this.maxLines = 5,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.inputFormatters,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassTextArea(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      inputFormatters: inputFormatters,
      textStyle: TextStyle(fontSize: 16, color: palette.inputForeground),
      placeholderStyle: TextStyle(
        fontSize: 16,
        color: palette.inputPlaceholder,
      ),
      settings: lingGlassSettingsFor(
        context,
        LingGlassSurfaceTone.muted,
        tintColor: palette.inputBackground,
      ),
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: const LiquidRoundedSuperellipse(borderRadius: 18),
      glowColor: palette.glassHighlight,
    );
  }
}

class LingGlassPicker extends StatelessWidget {
  const LingGlassPicker({
    super.key,
    required this.value,
    required this.onTap,
    this.placeholder = '',
    this.icon,
    this.height = 48,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String? value;
  final VoidCallback? onTap;
  final String placeholder;
  final Widget? icon;
  final double height;
  final double? width;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const radius = 16.0;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: palette.fieldBorder),
        ),
      ),
      child: GlassPicker(
        value: value,
        placeholder: placeholder,
        onTap: LingTapHaptics.wrap(onTap),
        icon:
            icon ??
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: palette.textSecondary,
              size: 18,
            ),
        height: height,
        width: width,
        padding: padding,
        textStyle: TextStyle(
          color: palette.inputForeground,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        placeholderStyle: TextStyle(
          color: palette.inputPlaceholder,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        settings: lingGlassSettingsFor(
          context,
          LingGlassSurfaceTone.muted,
          tintColor: palette.inputBackground,
        ),
        useOwnLayer: true,
        quality: GlassQuality.standard,
        shape: const LiquidRoundedSuperellipse(borderRadius: radius),
      ),
    );
  }
}

class LingGlassBadge extends StatelessWidget {
  const LingGlassBadge({
    super.key,
    required this.child,
    this.count = 0,
    this.showZero = false,
    this.backgroundColor,
    this.textColor,
  });

  final Widget child;
  final int count;
  final bool showZero;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassBadge(
      count: count,
      showZero: showZero,
      backgroundColor: backgroundColor ?? palette.primaryButtonBackground,
      textColor: textColor ?? palette.primaryButtonForeground,
      settings: lingGlassSettingsFor(context, LingGlassSurfaceTone.accent),
      quality: GlassQuality.standard,
      child: child,
    );
  }
}

class LingGlassToolbar extends StatelessWidget {
  const LingGlassToolbar({
    super.key,
    required this.children,
    this.height = 44,
    this.alignment = MainAxisAlignment.spaceBetween,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final List<Widget> children;
  final double height;
  final MainAxisAlignment alignment;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassToolbar(
      height: height,
      alignment: alignment,
      padding: padding,
      settings: lingGlassSettingsFor(context, LingGlassSurfaceTone.elevated),
      quality: lingGlassQualityFor(LingGlassQuality.premium),
      backgroundColor: context.palette.glassTint,
      children: children,
    );
  }
}

class LingGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LingGlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.height = 44,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return GlassAppBar(
      title: title,
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
      preferredSize: preferredSize,
      padding: padding,
      backgroundColor: context.palette.glassTint,
    );
  }
}

class LingGlassSegmentedControl extends StatelessWidget {
  const LingGlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentSelected,
    this.height = 36,
  });

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onSegmentSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassSegmentedControl(
      segments: segments,
      selectedIndex: selectedIndex,
      onSegmentSelected: onSegmentSelected,
      height: height,
      selectedTextStyle: TextStyle(
        color: palette.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      unselectedTextStyle: TextStyle(
        color: palette.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      backgroundColor: palette.glassMutedTint,
      indicatorColor: palette.glassElevatedTint,
      settings: lingGlassSettingsFor(context, LingGlassSurfaceTone.muted),
      useOwnLayer: true,
      quality: GlassQuality.standard,
      glowColor: palette.glassHighlight,
    );
  }
}

class LingGlassFloatingSwitchItem<T extends Object> {
  const LingGlassFloatingSwitchItem({
    required this.value,
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.key,
  });

  final T value;
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final Key? key;
}

class LingGlassFloatingSwitch<T extends Object> extends StatefulWidget {
  const LingGlassFloatingSwitch({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.width,
    this.height = 62,
    this.foregroundColor,
    this.mutedForegroundColor,
    this.selectedTextShadow,
    this.unselectedTextShadow,
    this.labelFontSize = 12,
    this.iconSize = 20,
    this.showIcons = true,
    this.horizontalLabelPadding = 6,
    this.iconLabelSpacing = 3,
    this.padding = const EdgeInsets.all(4),
  });

  final List<LingGlassFloatingSwitchItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final double? width;
  final double height;
  final Color? foregroundColor;
  final Color? mutedForegroundColor;
  final List<Shadow>? selectedTextShadow;
  final List<Shadow>? unselectedTextShadow;
  final double labelFontSize;
  final double iconSize;
  final bool showIcons;
  final double horizontalLabelPadding;
  final double iconLabelSpacing;
  final EdgeInsetsGeometry padding;

  @override
  State<LingGlassFloatingSwitch<T>> createState() =>
      _LingGlassFloatingSwitchState<T>();
}

class _LingGlassFloatingSwitchState<T extends Object>
    extends State<LingGlassFloatingSwitch<T>> {
  int _fromIndex = 0;
  int _toIndex = 0;
  int _animationSerial = 0;

  int _selectedIndexFor(LingGlassFloatingSwitch<T> widget) {
    final selectedIndex = widget.items.indexWhere(
      (item) => item.value == widget.selected,
    );
    return selectedIndex < 0 ? 0 : selectedIndex;
  }

  @override
  void initState() {
    super.initState();
    _toIndex = _selectedIndexFor(widget);
    _fromIndex = _toIndex;
  }

  @override
  void didUpdateWidget(covariant LingGlassFloatingSwitch<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _selectedIndexFor(widget);
    final itemCountChanged = oldWidget.items.length != widget.items.length;
    if (itemCountChanged) {
      _fromIndex = nextIndex;
      _toIndex = nextIndex;
      _animationSerial += 1;
      return;
    }
    if (nextIndex != _toIndex) {
      _fromIndex = _toIndex;
      _toIndex = nextIndex;
      _animationSerial += 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.items.isNotEmpty,
      'LingGlassFloatingSwitch needs at least one item.',
    );
    final palette = context.palette;
    final isDark = context.isDarkMode;
    final resolvedWidth =
        widget.width ?? math.min(324.0, MediaQuery.sizeOf(context).width - 54);
    final foreground =
        widget.foregroundColor ??
        (isDark ? palette.primaryButtonForeground : palette.textPrimary);
    final mutedForeground =
        widget.mutedForegroundColor ??
        palette.textSecondary.withValues(alpha: isDark ? 0.82 : 0.72);
    final indicatorTint = isDark
        ? palette.surfaceHigh.withValues(alpha: 0.30)
        : palette.surface.withValues(alpha: 0.62);
    final mediaQuery = MediaQuery.of(context);
    final reduceMotion =
        mediaQuery.disableAnimations || mediaQuery.accessibleNavigation;

    return LingGlassSurface(
      width: resolvedWidth,
      height: widget.height,
      radius: widget.height / 2,
      padding: widget.padding,
      tone: LingGlassSurfaceTone.control,
      quality: LingGlassQuality.premium,
      thickness: isDark ? 24 : 30,
      blur: isDark ? 2 : 2.5,
      chromaticAberration: isDark ? 0.006 : 0.018,
      lightIntensity: isDark ? 0.68 : 1.08,
      ambientStrength: isDark ? 0.72 : 1.3,
      refractiveIndex: isDark ? 1.18 : 1.48,
      saturation: isDark ? 1.08 : 1.22,
      lightAngle: 0.75 * math.pi,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / widget.items.length;
          return Stack(
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey<int>(_animationSerial),
                tween: Tween<double>(begin: 0, end: 1),
                duration: reduceMotion
                    ? const Duration(milliseconds: 140)
                    : const Duration(milliseconds: 360),
                curve: Curves.linear,
                builder: (context, rawProgress, _) {
                  final motionProgress = reduceMotion
                      ? Curves.easeOutCubic.transform(rawProgress)
                      : Curves.easeOutQuart.transform(rawProgress);
                  final centerIndex =
                      _fromIndex + ((_toIndex - _fromIndex) * motionProgress);
                  final travel = (_toIndex - _fromIndex).abs().toDouble();
                  final liquidEnergy = reduceMotion
                      ? 0.0
                      : math.sin(math.pi * rawProgress);
                  final stretch =
                      liquidEnergy * math.min(0.34, 0.12 + 0.08 * travel);
                  final indicatorWidth = itemWidth * (1 + stretch);
                  final indicatorLeft =
                      (centerIndex * itemWidth) -
                      ((indicatorWidth - itemWidth) / 2);
                  final clampedLeft = indicatorLeft
                      .clamp(
                        0.0,
                        math.max(0.0, constraints.maxWidth - indicatorWidth),
                      )
                      .toDouble();
                  final glowAlpha = liquidEnergy * (isDark ? 0.10 : 0.18);
                  return Positioned(
                    left: clampedLeft,
                    top: 0,
                    width: indicatorWidth,
                    height: constraints.maxHeight,
                    child: Transform.scale(
                      scaleY: 1 + (liquidEnergy * 0.025),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            indicatorTint,
                            palette.glassHighlight,
                            glowAlpha,
                          ),
                          borderRadius: BorderRadius.circular(
                            widget.height / 2,
                          ),
                          border: Border.all(
                            color: isDark
                                ? palette.glassBorder.withValues(
                                    alpha: 0.36 + (liquidEnergy * 0.10),
                                  )
                                : palette.fieldBorder.withValues(
                                    alpha: 0.40 + (liquidEnergy * 0.10),
                                  ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: palette.shadow.withValues(
                                alpha:
                                    (isDark ? 0.14 : 0.10) +
                                    (liquidEnergy * (isDark ? 0.035 : 0.035)),
                              ),
                              blurRadius: 12 + (liquidEnergy * 8),
                              offset: Offset(0, 4 + (liquidEnergy * 2)),
                            ),
                            if (!reduceMotion)
                              BoxShadow(
                                color: palette.glassHighlight.withValues(
                                  alpha: glowAlpha,
                                ),
                                blurRadius: 10 + (liquidEnergy * 10),
                                spreadRadius: 0.2,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Row(
                children: [
                  for (final item in widget.items)
                    _LingGlassFloatingSwitchItemButton<T>(
                      item: item,
                      selected: item.value == widget.selected,
                      foreground: foreground,
                      mutedForeground: mutedForeground,
                      selectedTextShadow: widget.selectedTextShadow,
                      unselectedTextShadow: widget.unselectedTextShadow,
                      labelFontSize: widget.labelFontSize,
                      iconSize: widget.iconSize,
                      showIcon: widget.showIcons,
                      horizontalLabelPadding: widget.horizontalLabelPadding,
                      iconLabelSpacing: widget.iconLabelSpacing,
                      onTap: () => widget.onChanged(item.value),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LingGlassFloatingSwitchItemButton<T extends Object>
    extends StatelessWidget {
  const _LingGlassFloatingSwitchItemButton({
    required this.item,
    required this.selected,
    required this.foreground,
    required this.mutedForeground,
    required this.selectedTextShadow,
    required this.unselectedTextShadow,
    required this.labelFontSize,
    required this.iconSize,
    required this.showIcon,
    required this.horizontalLabelPadding,
    required this.iconLabelSpacing,
    required this.onTap,
  });

  final LingGlassFloatingSwitchItem<T> item;
  final bool selected;
  final Color foreground;
  final Color mutedForeground;
  final List<Shadow>? selectedTextShadow;
  final List<Shadow>? unselectedTextShadow;
  final double labelFontSize;
  final double iconSize;
  final bool showIcon;
  final double horizontalLabelPadding;
  final double iconLabelSpacing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? foreground : mutedForeground;
    final icon = selected ? item.selectedIcon ?? item.icon : item.icon;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: GestureDetector(
          key: item.key,
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalLabelPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showIcon) ...[
                    Icon(icon, color: color, size: iconSize),
                    SizedBox(height: iconLabelSpacing),
                  ],
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                      shadows: selected
                          ? selectedTextShadow
                          : unselectedTextShadow,
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

class LingGlassDialogAction {
  const LingGlassDialogAction({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isDestructive;
}

Future<T?> showLingGlassDialog<T>({
  required BuildContext context,
  String? title,
  String? message,
  Widget? content,
  required List<LingGlassDialogAction> actions,
}) {
  return GlassDialog.show<T>(
    context: context,
    title: title,
    message: message,
    content: content,
    settings: lingGlassSettingsFor(context, LingGlassSurfaceTone.elevated),
    quality: GlassQuality.standard,
    actions: actions
        .map(
          (action) => GlassDialogAction(
            label: action.label,
            onPressed: action.onPressed,
            isPrimary: action.isPrimary,
            isDestructive: action.isDestructive,
          ),
        )
        .toList(),
  );
}
