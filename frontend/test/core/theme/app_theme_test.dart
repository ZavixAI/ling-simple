import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/theme/app_theme.dart';

void main() {
  test('dark theme uses Frost Mono readable text surfaces', () {
    final theme = AppTheme.dark();
    final palette = theme.extension<LingPalette>()!;

    expect(palette.textPrimary, const Color(0xFFF8FAFC));
    expect(theme.textTheme.bodyMedium?.color, const Color(0xFFAEB7C2));
    expect(theme.textTheme.bodyLarge?.color, const Color(0xFFF8FAFC));
    expect(theme.colorScheme.onSurface, const Color(0xFFF8FAFC));
  });

  test('theme accent colors use Frost Mono ice blue', () {
    final lightPalette = AppTheme.light().extension<LingPalette>()!;
    final darkPalette = AppTheme.dark().extension<LingPalette>()!;

    expect(AppTheme.primary, const Color(0xFF64D2FF));
    expect(lightPalette.accent, const Color(0xFF64D2FF));
    expect(lightPalette.accentSoft, const Color(0xFFE7F8FF));
    expect(lightPalette.onAccent, const Color(0xFF020407));
    expect(darkPalette.accent, const Color(0xFF64D2FF));
    expect(darkPalette.accentSoft, const Color(0xFF163547));
    expect(darkPalette.onAccent, const Color(0xFF020407));
  });

  test('light theme muted surfaces stay white instead of gray', () {
    final palette = AppTheme.light().extension<LingPalette>()!;

    expect(AppTheme.background, const Color(0xFFFFFFFF));
    expect(palette.background, const Color(0xFFFFFFFF));
    expect(palette.backgroundElevated, const Color(0xFFFFFFFF));
    expect(AppTheme.surfaceLow, const Color(0xFFFFFFFF));
    expect(AppTheme.surfaceHigh, const Color(0xFFFFFFFF));
    expect(palette.surfaceMuted, const Color(0xFFFFFFFF));
    expect(palette.surfaceHigh, const Color(0xFFFFFFFF));
    expect(palette.surfaceFrost, const Color(0xFFFFFFFF));
    expect(palette.glassMutedTint, const Color(0xF2FFFFFF));
    expect(palette.glassElevatedTint, const Color(0xFFFFFFFF));
    expect(palette.controlSurface, const Color(0xFFFFFFFF));
    expect(palette.safeAreaOverlay, const Color(0xD6FFFFFF));
    expect(palette.imageOverlayBlank, const Color(0xE6FFFFFF));
  });

  test('themes expose semantic button and input colors', () {
    final lightTheme = AppTheme.light();
    final darkTheme = AppTheme.dark();
    final lightPalette = lightTheme.extension<LingPalette>()!;
    final darkPalette = darkTheme.extension<LingPalette>()!;

    expect(lightPalette.primaryButtonBackground, const Color(0xFF007AFF));
    expect(lightPalette.primaryButtonForeground, const Color(0xFFFFFFFF));
    expect(lightPalette.inputBackground, const Color(0xFFFFFFFF));
    expect(lightPalette.inputForeground, const Color(0xFF111318));
    expect(lightPalette.inputPlaceholder, const Color(0x8568707A));
    expect(
      lightTheme.inputDecorationTheme.fillColor,
      lightPalette.inputBackground,
    );
    expect(
      lightTheme.inputDecorationTheme.hintStyle?.color,
      lightPalette.inputPlaceholder,
    );

    expect(darkPalette.primaryButtonBackground, const Color(0xFF0A84FF));
    expect(darkPalette.primaryButtonForeground, const Color(0xFFF8FAFC));
    expect(
      darkPalette.primaryButtonDisabledBackground,
      const Color(0xFF17324A),
    );
    expect(
      darkPalette.primaryButtonDisabledForeground,
      const Color(0xFFAEB7C2),
    );
    expect(darkPalette.destructiveButtonBackground, const Color(0xFFC91E16));
    expect(darkPalette.destructiveButtonForeground, const Color(0xFFF8FAFC));
    expect(darkPalette.inputBackground, const Color(0xE0141920));
    expect(darkPalette.inputForeground, const Color(0xFFF8FAFC));
    expect(darkPalette.inputPlaceholder, const Color(0x8AAEB7C2));
    expect(
      darkTheme.colorScheme.onPrimary,
      darkPalette.primaryButtonForeground,
    );
    expect(
      darkTheme.inputDecorationTheme.fillColor,
      darkPalette.inputBackground,
    );
    expect(
      darkTheme.inputDecorationTheme.hintStyle?.color,
      darkPalette.inputPlaceholder,
    );
  });

  test('dark semantic foregrounds stay readable instead of black', () {
    final palette = AppTheme.dark().extension<LingPalette>()!;

    expect(palette.primaryButtonForeground, isNot(palette.onAccent));
    expect(
      palette.primaryButtonForeground.computeLuminance(),
      greaterThan(0.8),
    );
    expect(
      palette.primaryButtonDisabledForeground.computeLuminance(),
      greaterThan(0.35),
    );
    expect(palette.inputForeground.computeLuminance(), greaterThan(0.8));
    expect(palette.inputPlaceholder.computeLuminance(), greaterThan(0.25));
    expect(palette.primaryButtonForeground, isNot(const Color(0xFF020407)));
  });

  test('dark theme surfaces use Frost Mono graphite colors', () {
    final darkPalette = AppTheme.dark().extension<LingPalette>()!;

    expect(darkPalette.background, const Color(0xFF020407));
    expect(darkPalette.backgroundElevated, const Color(0xFF151A20));
    expect(darkPalette.surface, const Color(0xFF151A20));
    expect(darkPalette.surfaceMuted, const Color(0xFF1A2028));
    expect(darkPalette.surfaceHigh, const Color(0xFF242C36));
    expect(darkPalette.surfaceFrost, const Color(0xD9151A20));
    expect(darkPalette.textSecondary, const Color(0xFFAEB7C2));
    expect(darkPalette.outline, const Color(0xFF313B47));
    expect(darkPalette.outlineSoft, const Color(0xFF303A49));
    expect(darkPalette.dividerMuted, const Color(0x66303A49));
  });

  test('dark theme text actions default to the iOS blue accent', () {
    final theme = AppTheme.dark();
    final palette = theme.extension<LingPalette>()!;

    expect(palette.accent, const Color(0xFF64D2FF));
    expect(theme.cupertinoOverrideTheme, isNull);
  });

  test('text button theme keeps text actions visibly bounded', () {
    final lightTheme = AppTheme.light();
    final darkTheme = AppTheme.dark();
    final lightPalette = lightTheme.extension<LingPalette>()!;
    final darkPalette = darkTheme.extension<LingPalette>()!;

    expect(
      lightTheme.textButtonTheme.style?.side?.resolve({})?.color,
      lightPalette.fieldBorder,
    );
    expect(
      darkTheme.textButtonTheme.style?.side?.resolve({})?.color,
      darkPalette.fieldBorder,
    );
    expect(
      lightTheme.textButtonTheme.style?.shape?.resolve({}),
      isA<StadiumBorder>(),
    );
  });

  test('dark theme text cursor uses the iOS blue accent color', () {
    final theme = AppTheme.dark();
    final palette = theme.extension<LingPalette>()!;

    expect(theme.textSelectionTheme.cursorColor, palette.inputCursor);
    expect(theme.textSelectionTheme.selectionHandleColor, palette.inputCursor);
  });

  test('light and dark themes expose mode-specific glass tokens', () {
    final lightPalette = AppTheme.light().extension<LingPalette>()!;
    final darkPalette = AppTheme.dark().extension<LingPalette>()!;

    expect(lightPalette.glassTint, isNot(darkPalette.glassTint));
    expect(lightPalette.glassMutedTint, isNot(darkPalette.glassMutedTint));
    expect(
      lightPalette.glassElevatedTint,
      isNot(darkPalette.glassElevatedTint),
    );
    expect(lightPalette.glassBorder, isNot(darkPalette.glassBorder));
    expect(lightPalette.glassHighlight, isNot(darkPalette.glassHighlight));
    expect(lightPalette.accentGlow, isNot(darkPalette.accentGlow));
    expect(lightPalette.fieldBorder, isNot(darkPalette.fieldBorder));
    expect(lightPalette.controlSurface, isNot(darkPalette.controlSurface));
    expect(lightPalette.textTertiary, isNot(darkPalette.textTertiary));
    expect(lightPalette.dividerMuted, isNot(darkPalette.dividerMuted));
    expect(
      lightPalette.chromeScrimStrong,
      isNot(darkPalette.chromeScrimStrong),
    );
    expect(lightPalette.chromeScrimSoft, isNot(darkPalette.chromeScrimSoft));
    expect(lightPalette.imageOverlayBase, isNot(darkPalette.imageOverlayBase));
    expect(
      lightPalette.imageOverlayAccent,
      isNot(darkPalette.imageOverlayAccent),
    );
    expect(
      lightPalette.imageOverlayBlank,
      isNot(darkPalette.imageOverlayBlank),
    );
    expect(
      lightPalette.imageOverlayShade,
      isNot(darkPalette.imageOverlayShade),
    );
    expect(lightPalette.safeAreaOverlay, isNot(darkPalette.safeAreaOverlay));
    expect(
      lightPalette.primaryButtonBackground,
      isNot(darkPalette.primaryButtonBackground),
    );
    expect(lightPalette.inputBackground, isNot(darkPalette.inputBackground));
    expect(lightPalette.inputPlaceholder, isNot(darkPalette.inputPlaceholder));
  });

  test('palette interpolation includes glass tokens', () {
    final lightPalette = AppTheme.light().extension<LingPalette>()!;
    final darkPalette = AppTheme.dark().extension<LingPalette>()!;
    final midPalette = lightPalette.lerp(darkPalette, 0.5);

    expect(midPalette.glassTint, isNot(lightPalette.glassTint));
    expect(midPalette.glassTint, isNot(darkPalette.glassTint));
    expect(midPalette.controlSurface, isNot(lightPalette.controlSurface));
    expect(midPalette.controlSurface, isNot(darkPalette.controlSurface));
    expect(midPalette.chromeScrimStrong, isNot(lightPalette.chromeScrimStrong));
    expect(midPalette.chromeScrimStrong, isNot(darkPalette.chromeScrimStrong));
    expect(midPalette.imageOverlayBase, isNot(lightPalette.imageOverlayBase));
    expect(midPalette.imageOverlayBase, isNot(darkPalette.imageOverlayBase));
    expect(
      midPalette.primaryButtonBackground,
      isNot(lightPalette.primaryButtonBackground),
    );
    expect(midPalette.inputBackground, isNot(lightPalette.inputBackground));
  });
}
