import 'package:flutter/material.dart';

@immutable
class LingPalette extends ThemeExtension<LingPalette> {
  const LingPalette({
    required this.background,
    required this.backgroundElevated,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceHigh,
    required this.surfaceFrost,
    required this.textPrimary,
    required this.textSecondary,
    required this.outline,
    required this.outlineSoft,
    required this.accent,
    required this.accentSoft,
    required this.glassTint,
    required this.glassMutedTint,
    required this.glassElevatedTint,
    required this.glassBorder,
    required this.glassHighlight,
    required this.accentGlow,
    required this.fieldBorder,
    required this.controlSurface,
    required this.textTertiary,
    required this.dividerMuted,
    required this.chromeScrimStrong,
    required this.chromeScrimSoft,
    required this.imageOverlayBase,
    required this.imageOverlayAccent,
    required this.imageOverlayBlank,
    required this.imageOverlayShade,
    required this.safeAreaOverlay,
    required this.shadow,
    required this.scrim,
    required this.danger,
    required this.dangerSoft,
    required this.dangerBorder,
    required this.success,
    required this.warning,
    required this.info,
    required this.onAccent,
    required this.primaryButtonBackground,
    required this.primaryButtonForeground,
    required this.primaryButtonDisabledBackground,
    required this.primaryButtonDisabledForeground,
    required this.destructiveButtonBackground,
    required this.destructiveButtonForeground,
    required this.inputBackground,
    required this.inputPlaceholder,
    required this.inputForeground,
    required this.inputCursor,
  });

  final Color background;
  final Color backgroundElevated;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceHigh;
  final Color surfaceFrost;
  final Color textPrimary;
  final Color textSecondary;
  final Color outline;
  final Color outlineSoft;
  final Color accent;
  final Color accentSoft;
  final Color glassTint;
  final Color glassMutedTint;
  final Color glassElevatedTint;
  final Color glassBorder;
  final Color glassHighlight;
  final Color accentGlow;
  final Color fieldBorder;
  final Color controlSurface;
  final Color textTertiary;
  final Color dividerMuted;
  final Color chromeScrimStrong;
  final Color chromeScrimSoft;
  final Color imageOverlayBase;
  final Color imageOverlayAccent;
  final Color imageOverlayBlank;
  final Color imageOverlayShade;
  final Color safeAreaOverlay;
  final Color shadow;
  final Color scrim;
  final Color danger;
  final Color dangerSoft;
  final Color dangerBorder;
  final Color success;
  final Color warning;
  final Color info;
  final Color onAccent;
  final Color primaryButtonBackground;
  final Color primaryButtonForeground;
  final Color primaryButtonDisabledBackground;
  final Color primaryButtonDisabledForeground;
  final Color destructiveButtonBackground;
  final Color destructiveButtonForeground;
  final Color inputBackground;
  final Color inputPlaceholder;
  final Color inputForeground;
  final Color inputCursor;

  @override
  LingPalette copyWith({
    Color? background,
    Color? backgroundElevated,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceHigh,
    Color? surfaceFrost,
    Color? textPrimary,
    Color? textSecondary,
    Color? outline,
    Color? outlineSoft,
    Color? accent,
    Color? accentSoft,
    Color? glassTint,
    Color? glassMutedTint,
    Color? glassElevatedTint,
    Color? glassBorder,
    Color? glassHighlight,
    Color? accentGlow,
    Color? fieldBorder,
    Color? controlSurface,
    Color? textTertiary,
    Color? dividerMuted,
    Color? chromeScrimStrong,
    Color? chromeScrimSoft,
    Color? imageOverlayBase,
    Color? imageOverlayAccent,
    Color? imageOverlayBlank,
    Color? imageOverlayShade,
    Color? safeAreaOverlay,
    Color? shadow,
    Color? scrim,
    Color? danger,
    Color? dangerSoft,
    Color? dangerBorder,
    Color? success,
    Color? warning,
    Color? info,
    Color? onAccent,
    Color? primaryButtonBackground,
    Color? primaryButtonForeground,
    Color? primaryButtonDisabledBackground,
    Color? primaryButtonDisabledForeground,
    Color? destructiveButtonBackground,
    Color? destructiveButtonForeground,
    Color? inputBackground,
    Color? inputPlaceholder,
    Color? inputForeground,
    Color? inputCursor,
  }) {
    return LingPalette(
      background: background ?? this.background,
      backgroundElevated: backgroundElevated ?? this.backgroundElevated,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceFrost: surfaceFrost ?? this.surfaceFrost,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      outline: outline ?? this.outline,
      outlineSoft: outlineSoft ?? this.outlineSoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      glassTint: glassTint ?? this.glassTint,
      glassMutedTint: glassMutedTint ?? this.glassMutedTint,
      glassElevatedTint: glassElevatedTint ?? this.glassElevatedTint,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      accentGlow: accentGlow ?? this.accentGlow,
      fieldBorder: fieldBorder ?? this.fieldBorder,
      controlSurface: controlSurface ?? this.controlSurface,
      textTertiary: textTertiary ?? this.textTertiary,
      dividerMuted: dividerMuted ?? this.dividerMuted,
      chromeScrimStrong: chromeScrimStrong ?? this.chromeScrimStrong,
      chromeScrimSoft: chromeScrimSoft ?? this.chromeScrimSoft,
      imageOverlayBase: imageOverlayBase ?? this.imageOverlayBase,
      imageOverlayAccent: imageOverlayAccent ?? this.imageOverlayAccent,
      imageOverlayBlank: imageOverlayBlank ?? this.imageOverlayBlank,
      imageOverlayShade: imageOverlayShade ?? this.imageOverlayShade,
      safeAreaOverlay: safeAreaOverlay ?? this.safeAreaOverlay,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      dangerBorder: dangerBorder ?? this.dangerBorder,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      onAccent: onAccent ?? this.onAccent,
      primaryButtonBackground:
          primaryButtonBackground ?? this.primaryButtonBackground,
      primaryButtonForeground:
          primaryButtonForeground ?? this.primaryButtonForeground,
      primaryButtonDisabledBackground:
          primaryButtonDisabledBackground ??
          this.primaryButtonDisabledBackground,
      primaryButtonDisabledForeground:
          primaryButtonDisabledForeground ??
          this.primaryButtonDisabledForeground,
      destructiveButtonBackground:
          destructiveButtonBackground ?? this.destructiveButtonBackground,
      destructiveButtonForeground:
          destructiveButtonForeground ?? this.destructiveButtonForeground,
      inputBackground: inputBackground ?? this.inputBackground,
      inputPlaceholder: inputPlaceholder ?? this.inputPlaceholder,
      inputForeground: inputForeground ?? this.inputForeground,
      inputCursor: inputCursor ?? this.inputCursor,
    );
  }

  @override
  LingPalette lerp(ThemeExtension<LingPalette>? other, double t) {
    if (other is! LingPalette) {
      return this;
    }
    return LingPalette(
      background: Color.lerp(background, other.background, t)!,
      backgroundElevated: Color.lerp(
        backgroundElevated,
        other.backgroundElevated,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceFrost: Color.lerp(surfaceFrost, other.surfaceFrost, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineSoft: Color.lerp(outlineSoft, other.outlineSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassMutedTint: Color.lerp(glassMutedTint, other.glassMutedTint, t)!,
      glassElevatedTint: Color.lerp(
        glassElevatedTint,
        other.glassElevatedTint,
        t,
      )!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      fieldBorder: Color.lerp(fieldBorder, other.fieldBorder, t)!,
      controlSurface: Color.lerp(controlSurface, other.controlSurface, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      dividerMuted: Color.lerp(dividerMuted, other.dividerMuted, t)!,
      chromeScrimStrong: Color.lerp(
        chromeScrimStrong,
        other.chromeScrimStrong,
        t,
      )!,
      chromeScrimSoft: Color.lerp(chromeScrimSoft, other.chromeScrimSoft, t)!,
      imageOverlayBase: Color.lerp(
        imageOverlayBase,
        other.imageOverlayBase,
        t,
      )!,
      imageOverlayAccent: Color.lerp(
        imageOverlayAccent,
        other.imageOverlayAccent,
        t,
      )!,
      imageOverlayBlank: Color.lerp(
        imageOverlayBlank,
        other.imageOverlayBlank,
        t,
      )!,
      imageOverlayShade: Color.lerp(
        imageOverlayShade,
        other.imageOverlayShade,
        t,
      )!,
      safeAreaOverlay: Color.lerp(safeAreaOverlay, other.safeAreaOverlay, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      dangerBorder: Color.lerp(dangerBorder, other.dangerBorder, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      primaryButtonBackground: Color.lerp(
        primaryButtonBackground,
        other.primaryButtonBackground,
        t,
      )!,
      primaryButtonForeground: Color.lerp(
        primaryButtonForeground,
        other.primaryButtonForeground,
        t,
      )!,
      primaryButtonDisabledBackground: Color.lerp(
        primaryButtonDisabledBackground,
        other.primaryButtonDisabledBackground,
        t,
      )!,
      primaryButtonDisabledForeground: Color.lerp(
        primaryButtonDisabledForeground,
        other.primaryButtonDisabledForeground,
        t,
      )!,
      destructiveButtonBackground: Color.lerp(
        destructiveButtonBackground,
        other.destructiveButtonBackground,
        t,
      )!,
      destructiveButtonForeground: Color.lerp(
        destructiveButtonForeground,
        other.destructiveButtonForeground,
        t,
      )!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      inputPlaceholder: Color.lerp(
        inputPlaceholder,
        other.inputPlaceholder,
        t,
      )!,
      inputForeground: Color.lerp(inputForeground, other.inputForeground, t)!,
      inputCursor: Color.lerp(inputCursor, other.inputCursor, t)!,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLow = Color(0xFFFFFFFF);
  static const Color surfaceHigh = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF64D2FF);
  static const Color tertiary = Color(0xFF5AC8FA);
  static const Color onSurface = Color(0xFF111318);
  static const Color onSurfaceVariant = Color(0xFF68707A);
  static const Color outline = Color(0xFFE1E5EA);

  static const LingPalette _lightPalette = LingPalette(
    background: Color(0xFFFFFFFF),
    backgroundElevated: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFFFFFFF),
    surfaceFrost: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF111318),
    textSecondary: Color(0xFF68707A),
    outline: Color(0xFFE1E5EA),
    outlineSoft: Color(0xFFDCE3EA),
    accent: Color(0xFF64D2FF),
    accentSoft: Color(0xFFE7F8FF),
    glassTint: Color(0xB8FFFFFF),
    glassMutedTint: Color(0xF2FFFFFF),
    glassElevatedTint: Color(0xFFFFFFFF),
    glassBorder: Color(0x9EFFFFFF),
    glassHighlight: Color(0xADFFFFFF),
    accentGlow: Color(0x3D64D2FF),
    fieldBorder: Color(0xFFDCE3EA),
    controlSurface: Color(0xFFFFFFFF),
    textTertiary: Color(0x9968707A),
    dividerMuted: Color(0x99DCE3EA),
    chromeScrimStrong: Color(0x75FFFFFF),
    chromeScrimSoft: Color(0x47FFFFFF),
    imageOverlayBase: Color(0x1FFFFFFF),
    imageOverlayAccent: Color(0x2EFFFFFF),
    imageOverlayBlank: Color(0xE6FFFFFF),
    imageOverlayShade: Color(0x0F000000),
    safeAreaOverlay: Color(0xD6FFFFFF),
    shadow: Color(0x14000000),
    scrim: Color(0x66000000),
    danger: Color(0xFFFF3B30),
    dangerSoft: Color(0xFFFFEDEC),
    dangerBorder: Color(0xFFFFC8C5),
    success: Color(0xFF34C759),
    warning: Color(0xFFFF9500),
    info: Color(0xFF5AC8FA),
    onAccent: Color(0xFF020407),
    primaryButtonBackground: Color(0xFF007AFF),
    primaryButtonForeground: Color(0xFFFFFFFF),
    primaryButtonDisabledBackground: Color(0x4D64D2FF),
    primaryButtonDisabledForeground: Color(0xCC68707A),
    destructiveButtonBackground: Color(0xFFFF3B30),
    destructiveButtonForeground: Color(0xFFFFFFFF),
    inputBackground: Color(0xFFFFFFFF),
    inputPlaceholder: Color(0x8568707A),
    inputForeground: Color(0xFF111318),
    inputCursor: Color(0xFF64D2FF),
  );

  static const LingPalette _darkPalette = LingPalette(
    background: Color(0xFF020407),
    backgroundElevated: Color(0xFF151A20),
    surface: Color(0xFF151A20),
    surfaceMuted: Color(0xFF1A2028),
    surfaceHigh: Color(0xFF242C36),
    surfaceFrost: Color(0xD9151A20),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFAEB7C2),
    outline: Color(0xFF313B47),
    outlineSoft: Color(0xFF303A49),
    accent: Color(0xFF64D2FF),
    accentSoft: Color(0xFF163547),
    glassTint: Color(0xA3151A20),
    glassMutedTint: Color(0x991A2028),
    glassElevatedTint: Color(0xB3151A20),
    glassBorder: Color(0x38FFFFFF),
    glassHighlight: Color(0x26FFFFFF),
    accentGlow: Color(0x400091FF),
    fieldBorder: Color(0xFF303A49),
    controlSurface: Color(0xCC151A20),
    textTertiary: Color(0x80AEB7C2),
    dividerMuted: Color(0x66303A49),
    chromeScrimStrong: Color(0x94020407),
    chromeScrimSoft: Color(0x5C020407),
    imageOverlayBase: Color(0x7A020407),
    imageOverlayAccent: Color(0x1F151A20),
    imageOverlayBlank: Color(0xE0020407),
    imageOverlayShade: Color(0x4D000000),
    safeAreaOverlay: Color(0xB8000000),
    shadow: Color(0x52000000),
    scrim: Color(0x99000000),
    danger: Color(0xFFFF453A),
    dangerSoft: Color(0xFF351614),
    dangerBorder: Color(0xFF66312C),
    success: Color(0xFF30D158),
    warning: Color(0xFFFF9F0A),
    info: Color(0xFF64D2FF),
    onAccent: Color(0xFF020407),
    primaryButtonBackground: Color(0xFF0A84FF),
    primaryButtonForeground: Color(0xFFF8FAFC),
    primaryButtonDisabledBackground: Color(0xFF17324A),
    primaryButtonDisabledForeground: Color(0xFFAEB7C2),
    destructiveButtonBackground: Color(0xFFC91E16),
    destructiveButtonForeground: Color(0xFFF8FAFC),
    inputBackground: Color(0xE0141920),
    inputPlaceholder: Color(0x8AAEB7C2),
    inputForeground: Color(0xFFF8FAFC),
    inputCursor: Color(0xFF64D2FF),
  );

  static ThemeData light() =>
      _buildTheme(brightness: Brightness.light, palette: _lightPalette);

  static ThemeData dark() =>
      _buildTheme(brightness: Brightness.dark, palette: _darkPalette);

  static LingPalette paletteOf(BuildContext context) =>
      Theme.of(context).extension<LingPalette>()!;

  static ButtonStyle _withoutPressedStateAnimation(ButtonStyle style) {
    return style.copyWith(
      animationDuration: Duration.zero,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required LingPalette palette,
  }) {
    final primaryTextColor = palette.textPrimary;
    final defaultBodyTextColor = palette.textSecondary;
    final defaultActionTextColor = palette.accent;
    final baseTextTheme = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;
    final colorScheme =
        ColorScheme.fromSeed(
          brightness: brightness,
          seedColor: palette.accent,
          primary: palette.accent,
          secondary: palette.accent,
          surface: palette.surface,
          onSurface: palette.textPrimary,
          error: palette.danger,
        ).copyWith(
          primary: palette.accent,
          onPrimary: palette.primaryButtonForeground,
          secondary: palette.accent,
          onSecondary: palette.primaryButtonForeground,
          surface: palette.surface,
          onSurface: palette.textPrimary,
          error: palette.danger,
          onError: palette.destructiveButtonForeground,
          surfaceTint: Colors.transparent,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      cardColor: palette.surface,
      fontFamily: 'Inter',
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.inputCursor,
        selectionColor: palette.accent.withValues(
          alpha: brightness == Brightness.dark ? 0.34 : 0.24,
        ),
        selectionHandleColor: palette.inputCursor,
      ),
      textTheme: baseTextTheme.copyWith(
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          height: 1.05,
          letterSpacing: 0,
          color: primaryTextColor,
          fontFamily: 'Plus Jakarta Sans',
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.1,
          color: primaryTextColor,
          fontFamily: 'Plus Jakarta Sans',
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: primaryTextColor,
          fontFamily: 'Plus Jakarta Sans',
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.5,
          color: primaryTextColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: defaultBodyTextColor,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _withoutPressedStateAnimation(
          FilledButton.styleFrom(
            backgroundColor: palette.primaryButtonBackground,
            foregroundColor: palette.primaryButtonForeground,
            disabledBackgroundColor: palette.primaryButtonDisabledBackground,
            disabledForegroundColor: palette.primaryButtonDisabledForeground,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: const StadiumBorder(),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _withoutPressedStateAnimation(
          OutlinedButton.styleFrom(
            foregroundColor: palette.textPrimary,
            side: BorderSide(color: palette.fieldBorder),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _withoutPressedStateAnimation(
          TextButton.styleFrom(
            foregroundColor: defaultActionTextColor,
            side: BorderSide(color: palette.fieldBorder),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: _withoutPressedStateAnimation(
          IconButton.styleFrom(foregroundColor: palette.textSecondary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputBackground,
        hintStyle: TextStyle(color: palette.inputPlaceholder),
        labelStyle: TextStyle(color: palette.inputPlaceholder),
        floatingLabelStyle: TextStyle(color: palette.inputCursor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: palette.fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: palette.fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: palette.accent, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.surfaceFrost,
        contentTextStyle: TextStyle(color: palette.textPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      splashFactory: NoSplash.splashFactory,
      dividerColor: palette.outlineSoft,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      shadowColor: palette.shadow,
      iconTheme: IconThemeData(color: palette.textSecondary),
      extensions: [palette],
    );
  }
}

extension AppThemeContext on BuildContext {
  LingPalette get palette => AppTheme.paletteOf(this);

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  bool get isCompactPhoneWidth => MediaQuery.sizeOf(this).width <= 390;
}
