import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/calendar/presentation/calendar_event_hero_chrome.dart';

void main() {
  test('event hero accent follows event category', () {
    final palette = AppTheme.light().extension<LingPalette>()!;

    expect(
      lingCalendarEventHeroAccentColor(palette, category: 'personal'),
      palette.warning,
    );
    expect(
      lingCalendarEventHeroAccentColor(palette, category: 'work'),
      palette.primaryButtonBackground,
    );
  });

  test('event hero gradient is shared by compact and expanded surfaces', () {
    final palette = AppTheme.light().extension<LingPalette>()!;
    final accent = lingCalendarEventHeroAccentColor(
      palette,
      category: 'personal',
    );

    final compactGradient = lingCalendarEventHeroGradientColors(
      palette: palette,
      isDark: false,
      accentColor: accent,
    );
    final expandedGradient = lingCalendarEventHeroGradientColors(
      palette: palette,
      isDark: false,
      accentColor: accent,
    );

    expect(compactGradient, expandedGradient);
  });
}
