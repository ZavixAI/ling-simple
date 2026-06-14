import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/auth/presentation/login_surface.dart';
import 'package:ling/src/features/auth/presentation/login_visual_palettes.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

void main() {
  testWidgets(
    'login view uses light theme colors for safe areas and system bars',
    (tester) async {
      await _pumpLoginView(tester, themeMode: ThemeMode.light);
      final palette = AppTheme.light().extension<LingPalette>()!;
      final expectedOverlay = SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: palette.background,
        systemNavigationBarDividerColor: Colors.transparent,
      );

      final topFill = tester.widget<ColoredBox>(
        find.byKey(const Key('login_top_safe_area_fill')),
      );
      final bottomFill = tester.widget<ColoredBox>(
        find.byKey(const Key('login_bottom_safe_area_fill')),
      );
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byKey(const Key('login_system_overlay')),
      );

      expect(topFill.color, palette.background);
      expect(bottomFill.color, palette.background);
      expect(overlay.value.statusBarColor, Colors.transparent);
      expect(overlay.value.systemNavigationBarColor, palette.background);
      expect(
        overlay.value.statusBarIconBrightness,
        expectedOverlay.statusBarIconBrightness,
      );
      expect(
        overlay.value.systemNavigationBarIconBrightness,
        expectedOverlay.systemNavigationBarIconBrightness,
      );
      expect(
        overlay.value.statusBarBrightness,
        expectedOverlay.statusBarBrightness,
      );
    },
  );

  testWidgets(
    'login view uses dark theme colors for safe areas and system bars',
    (tester) async {
      await _pumpLoginView(tester, themeMode: ThemeMode.dark);
      final loginBackground = resolveLoginSurfacePalette(
        tester.element(find.byType(LingCalendarLoginSurface)),
      ).background;
      final expectedOverlay = SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: loginBackground,
        systemNavigationBarDividerColor: Colors.transparent,
      );

      final topFill = tester.widget<ColoredBox>(
        find.byKey(const Key('login_top_safe_area_fill')),
      );
      final bottomFill = tester.widget<ColoredBox>(
        find.byKey(const Key('login_bottom_safe_area_fill')),
      );
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byKey(const Key('login_system_overlay')),
      );

      expect(topFill.color, loginBackground);
      expect(bottomFill.color, loginBackground);
      expect(overlay.value.statusBarColor, Colors.transparent);
      expect(overlay.value.systemNavigationBarColor, loginBackground);
      expect(
        overlay.value.statusBarIconBrightness,
        expectedOverlay.statusBarIconBrightness,
      );
      expect(
        overlay.value.systemNavigationBarIconBrightness,
        expectedOverlay.systemNavigationBarIconBrightness,
      );
      expect(
        overlay.value.statusBarBrightness,
        expectedOverlay.statusBarBrightness,
      );
    },
  );

  testWidgets('login hero bubbles use liquid glass surfaces', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: LingCalendarLoginHero(
            isZh: true,
            title: '你好，我是 Ling。',
            welcomeLead: '你好，我是',
            welcomeBrand: 'Ling',
            tagline: '让 Ling 帮你找到今天的节奏',
          ),
        ),
      ),
    );
    await tester.pump();

    final bubbleSurfaces = tester.widgetList<LingGlassSurface>(
      find.byKey(const Key('login_hero_bubble_chip')),
    );

    expect(bubbleSurfaces, isNotEmpty);
    for (final surface in bubbleSurfaces) {
      expect(surface.quality, LingGlassQuality.premium);
      expect(surface.tintColor, isNot(Colors.grey));
    }
  });

  testWidgets('compact login mode keeps hero top position stable', (
    tester,
  ) async {
    await _pumpLoginView(
      tester,
      themeMode: ThemeMode.light,
      compactVerticalSpacing: false,
      hero: const SizedBox(
        key: Key('stable_login_hero'),
        width: 120,
        height: 48,
      ),
    );
    final regularHeroTop = tester
        .getTopLeft(find.byKey(const Key('stable_login_hero')))
        .dy;

    await _pumpLoginView(
      tester,
      themeMode: ThemeMode.light,
      compactVerticalSpacing: true,
      hero: const SizedBox(
        key: Key('stable_login_hero'),
        width: 120,
        height: 48,
      ),
    );
    final compactHeroTop = tester
        .getTopLeft(find.byKey(const Key('stable_login_hero')))
        .dy;

    expect(compactHeroTop, regularHeroTop);
  });
}

Future<void> _pumpLoginView(
  WidgetTester tester, {
  required ThemeMode themeMode,
  bool compactVerticalSpacing = false,
  Widget hero = const SizedBox.shrink(),
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(padding: EdgeInsets.only(top: 44, bottom: 34)),
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: Scaffold(
          body: LingCalendarLoginSurface(
            compactVerticalSpacing: compactVerticalSpacing,
            hero: hero,
            currentPanel: const SizedBox.shrink(),
            bottomFooter: const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
