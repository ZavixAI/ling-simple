import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';

@immutable
class LoginSurfacePalette {
  const LoginSurfacePalette({
    required this.background,
    required this.primaryGlow,
    required this.secondaryGlow,
    required this.tagline,
    required this.bubbleTints,
    required this.bubbleText,
  });

  final Color background;
  final Color primaryGlow;
  final Color secondaryGlow;
  final Color tagline;
  final List<Color> bubbleTints;
  final Color bubbleText;
}

@immutable
class LoginPanelPalette {
  const LoginPanelPalette({
    required this.heading,
    required this.secondaryText,
    required this.tertiaryText,
    required this.divider,
    required this.inputSurface,
    required this.inputBorder,
    required this.inputText,
    required this.inputHint,
    required this.iconButton,
    required this.disabledIcon,
    required this.iconButtonOverlay,
    required this.actionText,
    required this.actionDisabledText,
    required this.actionOverlay,
    required this.primaryButtonBackground,
    required this.primaryButtonForeground,
    required this.primaryButtonDisabledBackground,
    required this.primaryButtonDisabledForeground,
    required this.codeCurrentBackground,
    required this.codeFilledBackground,
    required this.codeEmptyBackground,
    required this.codeCurrentBorder,
    required this.codeEmptyBorder,
    required this.codeFilledText,
    required this.codeEmptyText,
    required this.linkText,
    required this.agreementText,
    required this.agreementCheckedFill,
    required this.agreementCheckedBorder,
    required this.agreementUncheckedBorder,
  });

  final Color heading;
  final Color secondaryText;
  final Color tertiaryText;
  final Color divider;
  final Color inputSurface;
  final Color inputBorder;
  final Color inputText;
  final Color inputHint;
  final Color iconButton;
  final Color disabledIcon;
  final Color iconButtonOverlay;
  final Color actionText;
  final Color actionDisabledText;
  final Color actionOverlay;
  final Color primaryButtonBackground;
  final Color primaryButtonForeground;
  final Color primaryButtonDisabledBackground;
  final Color primaryButtonDisabledForeground;
  final Color codeCurrentBackground;
  final Color codeFilledBackground;
  final Color codeEmptyBackground;
  final Color codeCurrentBorder;
  final Color codeEmptyBorder;
  final Color codeFilledText;
  final Color codeEmptyText;
  final Color linkText;
  final Color agreementText;
  final Color agreementCheckedFill;
  final Color agreementCheckedBorder;
  final Color agreementUncheckedBorder;
}

LoginSurfacePalette resolveLoginSurfacePalette(BuildContext context) {
  final palette = context.palette;
  if (context.isDarkMode) {
    return LoginSurfacePalette(
      background: palette.background,
      primaryGlow: palette.accentGlow.withValues(alpha: 0.52),
      secondaryGlow: palette.accentSoft.withValues(alpha: 0.42),
      tagline: palette.textSecondary.withValues(alpha: 0.82),
      bubbleTints: [
        palette.surface,
        palette.surface,
        palette.surface,
        palette.accentSoft,
      ],
      bubbleText: palette.textPrimary.withValues(alpha: 0.88),
    );
  }

  return LoginSurfacePalette(
    background: palette.background,
    primaryGlow: palette.accentSoft.withValues(alpha: 0.36),
    secondaryGlow: palette.surface.withValues(alpha: 0.92),
    tagline: palette.textSecondary.withValues(alpha: 0.72),
    bubbleTints: [
      palette.accentSoft,
      palette.surface,
      palette.surface,
      palette.backgroundElevated,
      palette.surface,
    ],
    bubbleText: palette.textSecondary.withValues(alpha: 0.88),
  );
}

LoginPanelPalette resolveLoginPanelPalette(BuildContext context) {
  final palette = context.palette;
  if (context.isDarkMode) {
    return LoginPanelPalette(
      heading: palette.textPrimary,
      secondaryText: palette.textSecondary.withValues(alpha: 0.92),
      tertiaryText: palette.textSecondary.withValues(alpha: 0.72),
      divider: palette.outlineSoft,
      inputSurface: palette.inputBackground,
      inputBorder: palette.fieldBorder,
      inputText: palette.inputForeground,
      inputHint: palette.inputPlaceholder,
      iconButton: palette.textPrimary.withValues(alpha: 0.82),
      disabledIcon: palette.textSecondary.withValues(alpha: 0.44),
      iconButtonOverlay: palette.textPrimary.withValues(alpha: 0.08),
      actionText: palette.textPrimary.withValues(alpha: 0.9),
      actionDisabledText: palette.textSecondary.withValues(alpha: 0.44),
      actionOverlay: palette.textPrimary.withValues(alpha: 0.08),
      primaryButtonBackground: palette.primaryButtonBackground,
      primaryButtonForeground: palette.primaryButtonForeground,
      primaryButtonDisabledBackground: palette.primaryButtonDisabledBackground,
      primaryButtonDisabledForeground: palette.primaryButtonDisabledForeground,
      codeCurrentBackground: palette.textPrimary.withValues(alpha: 0.10),
      codeFilledBackground: palette.primaryButtonBackground,
      codeEmptyBackground: palette.inputBackground,
      codeCurrentBorder: palette.inputCursor.withValues(alpha: 0.48),
      codeEmptyBorder: palette.outlineSoft,
      codeFilledText: palette.primaryButtonForeground,
      codeEmptyText: palette.inputForeground,
      linkText: palette.textPrimary.withValues(alpha: 0.9),
      agreementText: palette.textSecondary.withValues(alpha: 0.74),
      agreementCheckedFill: palette.primaryButtonBackground,
      agreementCheckedBorder: palette.primaryButtonBackground,
      agreementUncheckedBorder: palette.outlineSoft,
    );
  }

  return LoginPanelPalette(
    heading: palette.textPrimary,
    secondaryText: palette.textSecondary.withValues(alpha: 0.92),
    tertiaryText: palette.textSecondary.withValues(alpha: 0.76),
    divider: palette.outlineSoft.withValues(alpha: 0.5),
    inputSurface: palette.inputBackground,
    inputBorder: palette.fieldBorder,
    inputText: palette.inputForeground,
    inputHint: palette.inputPlaceholder,
    iconButton: palette.textPrimary.withValues(alpha: 0.7),
    disabledIcon: palette.textSecondary.withValues(alpha: 0.52),
    iconButtonOverlay: palette.textPrimary.withValues(alpha: 0.04),
    actionText: palette.textPrimary,
    actionDisabledText: palette.textSecondary.withValues(alpha: 0.5),
    actionOverlay: palette.textPrimary.withValues(alpha: 0.05),
    primaryButtonBackground: palette.primaryButtonBackground,
    primaryButtonForeground: palette.primaryButtonForeground,
    primaryButtonDisabledBackground: palette.primaryButtonDisabledBackground,
    primaryButtonDisabledForeground: palette.primaryButtonDisabledForeground,
    codeCurrentBackground: palette.textPrimary.withValues(alpha: 0.04),
    codeFilledBackground: palette.primaryButtonBackground,
    codeEmptyBackground: palette.inputBackground,
    codeCurrentBorder: palette.textPrimary.withValues(alpha: 0.1),
    codeEmptyBorder: palette.outlineSoft.withValues(alpha: 0.36),
    codeFilledText: palette.primaryButtonForeground,
    codeEmptyText: palette.inputForeground,
    linkText: palette.textPrimary.withValues(alpha: 0.8),
    agreementText: palette.textSecondary.withValues(alpha: 0.74),
    agreementCheckedFill: palette.primaryButtonBackground,
    agreementCheckedBorder: palette.primaryButtonBackground,
    agreementUncheckedBorder: palette.outlineSoft.withValues(alpha: 0.7),
  );
}
