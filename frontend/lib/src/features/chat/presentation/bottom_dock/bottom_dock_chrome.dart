part of '../bottom_dock.dart';

Color _surfaceFillFor(BuildContext context, LingPalette palette) {
  return lingGlassControlTintFor(context, palette);
}

Color _composerFillFor(BuildContext context, LingPalette palette) {
  return lingGlassControlTintFor(context, palette);
}

List<BoxShadow> _quickPromptTagShadowFor(
  BuildContext context,
  LingPalette palette,
) {
  if (context.isDarkMode) {
    return const <BoxShadow>[];
  }
  return [
    BoxShadow(
      color: palette.shadow.withValues(alpha: 0.018),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];
}

Widget _withDockControlBorder({
  required BuildContext context,
  required LingPalette palette,
  required double radius,
  required Widget child,
}) {
  return child;
}

List<BoxShadow> _dockControlShadowFor(
  BuildContext context,
  LingPalette palette,
) {
  return const <BoxShadow>[];
}

Color _textOnGlass(LingPalette palette) {
  return palette.textPrimary;
}

Color _mutedTextOnGlass(LingPalette palette) {
  return palette.textSecondary.withValues(alpha: 0.92);
}

Color _voiceInputForegroundFor(LingPalette palette) {
  return palette.textPrimary;
}

Color _voiceInputIconFor(LingPalette palette) {
  return palette.primaryButtonBackground;
}

Color _transparentButtonTintFor(BuildContext context, LingPalette palette) {
  return lingFloatingControlTintFor(context, palette);
}

Color _recordingDisabledIconFor(BuildContext context, LingPalette palette) {
  return palette.textPrimary.withValues(
    alpha: context.isDarkMode ? 0.52 : 0.34,
  );
}

Color _recordingStopTintFor(BuildContext context, LingPalette palette) {
  return context.isDarkMode
      ? palette.dangerSoft.withValues(alpha: 0.72)
      : palette.dangerSoft.withValues(alpha: 0.90);
}

Color _attachmentBorderFor(BuildContext context, LingPalette palette) {
  return context.isDarkMode
      ? Colors.white.withValues(alpha: 0.16)
      : palette.outlineSoft.withValues(alpha: 0.9);
}

class _LingDockEmbeddedIconButton extends StatelessWidget {
  const _LingDockEmbeddedIconButton({
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    required this.palette,
    required this.size,
    required this.iconColor,
    this.tintColor,
    this.disabledIconColor,
    this.disabledOpacity = 0.45,
  });

  final Key buttonKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final LingPalette palette;
  final double size;
  final Color iconColor;
  final Color? tintColor;
  final Color? disabledIconColor;
  final double disabledOpacity;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return KeyedSubtree(
      key: buttonKey,
      child: Opacity(
        opacity: enabled ? 1 : disabledOpacity,
        child: LingFloatingIconButtonFrame(
          dimension: size,
          child: LingFloatingIconButton(
            icon: icon,
            onTap: onTap,
            semanticLabel: tooltip,
            size: size,
            iconSize: size * 0.46,
            iconColor: enabled
                ? iconColor
                : disabledIconColor ?? palette.textSecondary,
            tintColor: tintColor ?? _transparentButtonTintFor(context, palette),
            useOwnLayer: false,
            thickness: 30,
            blur: 2,
            lightIntensity: context.isDarkMode ? 0.72 : 1.08,
            ambientStrength: context.isDarkMode ? 0.82 : 1.3,
            refractiveIndex: context.isDarkMode ? 1.2 : 1.48,
            saturation: context.isDarkMode ? 1.1 : 1.22,
          ),
        ),
      ),
    );
  }
}

class _LingDockStopRecordingButton extends StatelessWidget {
  const _LingDockStopRecordingButton({
    required this.buttonKey,
    required this.tooltip,
    required this.onTap,
    required this.palette,
    required this.size,
  });

  final Key buttonKey;
  final String tooltip;
  final VoidCallback? onTap;
  final LingPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return KeyedSubtree(
      key: buttonKey,
      child: Semantics(
        button: true,
        label: tooltip,
        enabled: enabled,
        child: LingFloatingIconButtonFrame(
          dimension: size,
          child: LingGlassIconButton(
            icon: Icons.stop_rounded,
            onPressed: onTap,
            semanticLabel: tooltip,
            size: size,
            iconSize: size * 0.56,
            iconColor: enabled
                ? palette.destructiveButtonBackground
                : _recordingDisabledIconFor(context, palette),
            tone: LingGlassSurfaceTone.control,
            tintColor: enabled
                ? _recordingStopTintFor(context, palette)
                : _transparentButtonTintFor(context, palette),
            glowColor: palette.glassHighlight,
            quality: LingGlassQuality.premium,
            useOwnLayer: false,
            thickness: 30,
            blur: 2,
            lightIntensity: context.isDarkMode ? 0.72 : 1.08,
            ambientStrength: context.isDarkMode ? 0.82 : 1.3,
            refractiveIndex: context.isDarkMode ? 1.2 : 1.48,
            saturation: context.isDarkMode ? 1.1 : 1.22,
          ),
        ),
      ),
    );
  }
}

class _LingPlainDockIconButton extends StatelessWidget {
  const _LingPlainDockIconButton({
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    required this.size,
    required this.iconSize,
    required this.iconColor,
    required this.disabledIconColor,
  });

  final Key buttonKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color iconColor;
  final Color disabledIconColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      label: tooltip,
      enabled: enabled,
      child: IconButton(
        key: buttonKey,
        onPressed: LingTapHaptics.wrap(onTap),
        icon: Icon(icon),
        iconSize: iconSize,
        color: enabled ? iconColor : disabledIconColor,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: size, height: size),
        splashRadius: size / 2,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
