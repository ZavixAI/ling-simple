import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

Widget _host(
  Widget child, {
  ThemeMode themeMode = ThemeMode.light,
  bool highContrast = false,
  bool disableAnimations = false,
}) {
  final theme = themeMode == ThemeMode.dark
      ? AppTheme.dark()
      : AppTheme.light();
  return MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: themeMode,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          highContrast: highContrast,
          disableAnimations: disableAnimations,
        ),
        child: Theme(
          data: theme,
          child: Scaffold(
            body: LingGlassLayer(child: Center(child: child)),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platformCalls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    platformCalls.clear();
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      methodCall,
    ) async {
      if (methodCall.method == 'HapticFeedback.vibrate') {
        platformCalls.add(methodCall);
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('LingGlassQuality.premium defaults to standard plugin quality', () {
    expect(
      lingGlassQualityFor(LingGlassQuality.premium),
      GlassQuality.standard,
    );
  });

  testWidgets('LingGlassSurface builds child content', (tester) async {
    await tester.pumpWidget(
      _host(const LingGlassSurface(child: Text('glass content'))),
    );

    expect(find.text('glass content'), findsOneWidget);
  });

  testWidgets('LingGlassSurface reads light and dark palette tokens', (
    tester,
  ) async {
    Color? resolvedTint;

    await tester.pumpWidget(
      _host(
        LingGlassSurface(
          child: Builder(
            builder: (context) {
              resolvedTint = context.palette.glassTint;
              return const Text('light glass');
            },
          ),
        ),
      ),
    );

    expect(resolvedTint, AppTheme.light().extension<LingPalette>()!.glassTint);

    await tester.pumpWidget(
      _host(
        LingGlassSurface(
          child: Builder(
            builder: (context) {
              resolvedTint = context.palette.glassTint;
              return const Text('dark glass');
            },
          ),
        ),
        themeMode: ThemeMode.dark,
      ),
    );

    expect(resolvedTint, AppTheme.dark().extension<LingPalette>()!.glassTint);
  });

  testWidgets('LingGlassSurface renders through GlassContainer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const LingGlassSurface(
          key: Key('light_glass_surface'),
          child: Text('light glass'),
        ),
      ),
    );

    final container = tester.widget<GlassContainer>(
      find
          .descendant(
            of: find.byKey(const Key('light_glass_surface')),
            matching: find.byType(GlassContainer),
          )
          .first,
    );

    expect(container.useOwnLayer, isTrue);
    expect(container.quality, GlassQuality.standard);
    expect(container.settings?.glassColor, isNotNull);
  });

  testWidgets('LingGlassSurface maps dark palette into glass settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const LingGlassSurface(
          key: Key('dark_glass_surface'),
          child: Text('dark glass'),
        ),
        themeMode: ThemeMode.dark,
      ),
    );

    final container = tester.widget<GlassContainer>(
      find
          .descendant(
            of: find.byKey(const Key('dark_glass_surface')),
            matching: find.byType(GlassContainer),
          )
          .first,
    );

    expect(
      container.settings?.glassColor,
      AppTheme.dark().extension<LingPalette>()!.glassTint,
    );
  });

  testWidgets('LingGlassSurface inherits settings in grouped layer mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const LingGlassLayer(
          child: LingGlassSurface(
            key: Key('grouped_glass_surface'),
            useOwnLayer: false,
            child: Text('grouped glass'),
          ),
        ),
      ),
    );

    final container = tester.widget<GlassContainer>(
      find
          .descendant(
            of: find.byKey(const Key('grouped_glass_surface')),
            matching: find.byType(GlassContainer),
          )
          .first,
    );

    expect(container.useOwnLayer, isFalse);
    expect(container.settings, isNull);
  });

  testWidgets(
    'lingGlassSettingsFor keeps light glass white and dark glass dark',
    (tester) async {
      LiquidGlassSettings? lightSettings;
      LiquidGlassSettings? darkSettings;

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              lightSettings = lingGlassSettingsFor(
                context,
                LingGlassSurfaceTone.regular,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              darkSettings = lingGlassSettingsFor(
                context,
                LingGlassSurfaceTone.regular,
              );
              return const SizedBox.shrink();
            },
          ),
          themeMode: ThemeMode.dark,
        ),
      );

      expect(lightSettings?.glassColor, const Color(0xB8FFFFFF));
      expect(darkSettings?.glassColor, const Color(0xA3151A20));
    },
  );

  testWidgets('control glass uses package searchable bar style', (
    tester,
  ) async {
    LiquidGlassSettings? lightSettings;
    LiquidGlassSettings? darkSettings;

    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            lightSettings = lingGlassSettingsFor(
              context,
              LingGlassSurfaceTone.control,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            darkSettings = lingGlassSettingsFor(
              context,
              LingGlassSurfaceTone.control,
            );
            return const SizedBox.shrink();
          },
        ),
        themeMode: ThemeMode.dark,
      ),
    );

    final darkPalette = AppTheme.dark().extension<LingPalette>()!;
    final lightPalette = AppTheme.light().extension<LingPalette>()!;
    expect(
      lightSettings?.glassColor,
      lightPalette.surface.withValues(alpha: 0.64),
    );
    expect(
      darkSettings?.glassColor,
      darkPalette.surfaceHigh.withValues(alpha: 0.28),
    );
    expect(lightSettings?.thickness, 30);
    expect(lightSettings?.blur, 4);
    expect(lightSettings?.ambientStrength, 2);
    expect(lightSettings?.refractiveIndex, 1.26);
    expect(lightSettings?.lightAngle, 0.75 * math.pi);
    expect(lightSettings?.specularSharpness, GlassSpecularSharpness.medium);
  });

  testWidgets('control glass adapts tint for high contrast themes', (
    tester,
  ) async {
    LiquidGlassSettings? lightSettings;
    LiquidGlassSettings? darkSettings;

    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            lightSettings = lingGlassSettingsFor(
              context,
              LingGlassSurfaceTone.control,
            );
            return const SizedBox.shrink();
          },
        ),
        highContrast: true,
      ),
    );

    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            darkSettings = lingGlassSettingsFor(
              context,
              LingGlassSurfaceTone.control,
            );
            return const SizedBox.shrink();
          },
        ),
        themeMode: ThemeMode.dark,
        highContrast: true,
      ),
    );

    final lightPalette = AppTheme.light().extension<LingPalette>()!;
    final darkPalette = AppTheme.dark().extension<LingPalette>()!;
    expect(
      lightSettings?.glassColor,
      lightPalette.surface.withValues(alpha: 0.90),
    );
    expect(
      darkSettings?.glassColor,
      darkPalette.surface.withValues(alpha: 0.88),
    );
  });

  testWidgets('LingGlassButton keeps liquid-glass effect across themes', (
    tester,
  ) async {
    Future<void> expectButton({
      required ThemeMode themeMode,
      required Color expectedTint,
      required Color expectedBorder,
      required double expectedBorderWidth,
      required double expectedAmbient,
    }) async {
      await tester.pumpWidget(
        _host(
          LingGlassButton(
            onPressed: () {},
            tone: LingGlassSurfaceTone.control,
            child: const Text('Action'),
          ),
          themeMode: themeMode,
        ),
      );

      final glassButton = tester.widget<GlassButton>(find.byType(GlassButton));
      final border = tester.widget<DecoratedBox>(
        find.byKey(const Key('ling_glass_button_border')),
      );
      final decoration = border.decoration as ShapeDecoration;
      final shape = decoration.shape as RoundedRectangleBorder;

      expect(glassButton.settings?.glassColor, expectedTint);
      expect(glassButton.settings?.thickness, 30);
      expect(glassButton.settings?.blur, 4);
      expect(glassButton.settings?.ambientStrength, expectedAmbient);
      expect(
        glassButton.settings?.refractiveIndex,
        themeMode == ThemeMode.dark ? 1.16 : 1.26,
      );
      expect(glassButton.settings?.lightAngle, 0.75 * math.pi);
      expect(shape.side.color, expectedBorder);
      expect(shape.side.width, expectedBorderWidth);
    }

    final lightPalette = AppTheme.light().extension<LingPalette>()!;
    final darkPalette = AppTheme.dark().extension<LingPalette>()!;
    await expectButton(
      themeMode: ThemeMode.light,
      expectedTint: lightPalette.surface.withValues(alpha: 0.64),
      expectedBorder: lightPalette.fieldBorder.withValues(alpha: 0.96),
      expectedBorderWidth: 1,
      expectedAmbient: 2,
    );
    await expectButton(
      themeMode: ThemeMode.dark,
      expectedTint: darkPalette.surfaceHigh.withValues(alpha: 0.28),
      expectedBorder: darkPalette.glassBorder.withValues(alpha: 0.48),
      expectedBorderWidth: 0.65,
      expectedAmbient: 1.08,
    );
  });

  testWidgets('LingGlassIconButton keeps visible glass chrome by theme', (
    tester,
  ) async {
    Future<void> expectIconButton({
      required ThemeMode themeMode,
      required Color expectedTint,
      required Color expectedBorder,
      required double expectedBorderWidth,
    }) async {
      await tester.pumpWidget(
        _host(
          LingGlassIconButton(
            icon: Icons.add_rounded,
            onPressed: () {},
            tone: LingGlassSurfaceTone.control,
          ),
          themeMode: themeMode,
        ),
      );

      final glassIconButton = tester.widget<GlassIconButton>(
        find.byType(GlassIconButton),
      );
      final border = tester.widget<DecoratedBox>(
        find.byKey(const Key('ling_glass_icon_button_border')),
      );
      final decoration = border.decoration as ShapeDecoration;
      final shape = decoration.shape as RoundedRectangleBorder;

      expect(glassIconButton.settings?.glassColor, expectedTint);
      expect(glassIconButton.settings?.thickness, 30);
      expect(glassIconButton.settings?.blur, 4);
      expect(
        glassIconButton.settings?.ambientStrength,
        themeMode == ThemeMode.dark ? 1.08 : 2,
      );
      expect(glassIconButton.settings?.lightAngle, 0.75 * math.pi);
      expect(shape.side.color, expectedBorder);
      expect(shape.side.width, expectedBorderWidth);
    }

    final lightPalette = AppTheme.light().extension<LingPalette>()!;
    final darkPalette = AppTheme.dark().extension<LingPalette>()!;
    await expectIconButton(
      themeMode: ThemeMode.light,
      expectedTint: lightPalette.surface.withValues(alpha: 0.64),
      expectedBorder: lightPalette.fieldBorder.withValues(alpha: 0.82),
      expectedBorderWidth: 1,
    );
    await expectIconButton(
      themeMode: ThemeMode.dark,
      expectedTint: darkPalette.surfaceHigh.withValues(alpha: 0.28),
      expectedBorder: darkPalette.glassBorder.withValues(alpha: 0.44),
      expectedBorderWidth: 0.65,
    );
  });

  testWidgets('LingGlassChip preserves regular glass and border by theme', (
    tester,
  ) async {
    Future<void> expectChip({
      required ThemeMode themeMode,
      required Color expectedTint,
      required Color expectedBorder,
      required double expectedBorderWidth,
    }) async {
      await tester.pumpWidget(
        _host(
          LingGlassChip(label: 'Chip', onPressed: () {}),
          themeMode: themeMode,
        ),
      );

      final chip = tester.widget<GlassChip>(find.byType(GlassChip));
      final border = tester.widget<DecoratedBox>(
        find.byKey(const Key('ling_glass_chip_border')),
      );
      final decoration = border.decoration as ShapeDecoration;
      final shape = decoration.shape as RoundedRectangleBorder;

      expect(chip.settings?.glassColor, expectedTint);
      expect(chip.settings?.thickness, themeMode == ThemeMode.dark ? 20 : 32);
      expect(chip.settings?.blur, themeMode == ThemeMode.dark ? 7 : 8);
      expect(
        chip.settings?.ambientStrength,
        themeMode == ThemeMode.dark ? 0.34 : 0.52,
      );
      expect(shape.side.color, expectedBorder);
      expect(shape.side.width, expectedBorderWidth);
    }

    final lightPalette = AppTheme.light().extension<LingPalette>()!;
    final darkPalette = AppTheme.dark().extension<LingPalette>()!;
    await expectChip(
      themeMode: ThemeMode.light,
      expectedTint: lightPalette.glassTint,
      expectedBorder: lightPalette.fieldBorder.withValues(alpha: 0.82),
      expectedBorderWidth: 1,
    );
    await expectChip(
      themeMode: ThemeMode.dark,
      expectedTint: darkPalette.glassTint,
      expectedBorder: darkPalette.glassBorder.withValues(alpha: 0.44),
      expectedBorderWidth: 0.65,
    );
  });

  testWidgets('LingGlassSegmentedControl keeps glass settings by theme', (
    tester,
  ) async {
    Future<void> expectSegmented({
      required ThemeMode themeMode,
      required Color expectedBackground,
      required Color expectedIndicator,
      required Color expectedGlass,
    }) async {
      await tester.pumpWidget(
        _host(
          LingGlassSegmentedControl(
            segments: const ['All', 'Open'],
            selectedIndex: 0,
            onSegmentSelected: (_) {},
          ),
          themeMode: themeMode,
        ),
      );

      final control = tester.widget<GlassSegmentedControl>(
        find.byType(GlassSegmentedControl),
      );

      expect(control.backgroundColor, expectedBackground);
      expect(control.indicatorColor, expectedIndicator);
      expect(control.settings?.glassColor, expectedGlass);
      expect(control.settings?.blur, themeMode == ThemeMode.dark ? 7 : 8);
      expect(
        control.settings?.thickness,
        themeMode == ThemeMode.dark ? 20 : 32,
      );
      expect(control.useOwnLayer, isTrue);
      expect(control.quality, GlassQuality.standard);
    }

    final lightPalette = AppTheme.light().extension<LingPalette>()!;
    final darkPalette = AppTheme.dark().extension<LingPalette>()!;
    await expectSegmented(
      themeMode: ThemeMode.light,
      expectedBackground: lightPalette.glassMutedTint,
      expectedIndicator: lightPalette.glassElevatedTint,
      expectedGlass: lightPalette.glassMutedTint,
    );
    await expectSegmented(
      themeMode: ThemeMode.dark,
      expectedBackground: darkPalette.glassMutedTint,
      expectedIndicator: darkPalette.glassElevatedTint,
      expectedGlass: darkPalette.glassMutedTint,
    );
  });

  testWidgets('LingGlassFloatingSwitch uses floating glass by theme', (
    tester,
  ) async {
    Future<void> expectFloatingSwitch({
      required ThemeMode themeMode,
      required Color expectedGlass,
      required double expectedBlur,
      required double expectedThickness,
    }) async {
      var selected = 'today';
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              return LingGlassFloatingSwitch<String>(
                width: 240,
                items: const [
                  LingGlassFloatingSwitchItem(
                    value: 'today',
                    label: 'Today',
                    icon: Icons.space_dashboard_rounded,
                  ),
                  LingGlassFloatingSwitchItem(
                    value: 'moments',
                    label: 'Moments',
                    icon: Icons.auto_awesome_rounded,
                  ),
                ],
                selected: selected,
                onChanged: (value) => setState(() => selected = value),
              );
            },
          ),
          themeMode: themeMode,
        ),
      );

      expect(find.byType(GlassBottomBar), findsNothing);
      expect(find.byType(GlassSegmentedControl), findsNothing);
      final surface = tester.widget<LingGlassSurface>(
        find.byType(LingGlassSurface).last,
      );
      final container = tester.widget<GlassContainer>(
        find
            .descendant(
              of: find.byType(LingGlassFloatingSwitch<String>),
              matching: find.byType(GlassContainer),
            )
            .first,
      );

      expect(surface.tone, LingGlassSurfaceTone.control);
      expect(surface.quality, LingGlassQuality.premium);
      expect(container.settings?.glassColor, expectedGlass);
      expect(container.settings?.blur, expectedBlur);
      expect(container.settings?.thickness, expectedThickness);
      expect(
        container.settings?.ambientStrength,
        themeMode == ThemeMode.dark ? 0.72 : 1.3,
      );
      expect(container.settings?.lightAngle, 0.75 * math.pi);

      await tester.tap(find.text('Moments'));
      await tester.pump();
      expect(selected, 'moments');
    }

    final lightPalette = AppTheme.light().extension<LingPalette>()!;
    final darkPalette = AppTheme.dark().extension<LingPalette>()!;
    await expectFloatingSwitch(
      themeMode: ThemeMode.light,
      expectedGlass: lightPalette.surface.withValues(alpha: 0.64),
      expectedBlur: 2.5,
      expectedThickness: 30,
    );
    await expectFloatingSwitch(
      themeMode: ThemeMode.dark,
      expectedGlass: darkPalette.surfaceHigh.withValues(alpha: 0.28),
      expectedBlur: 2,
      expectedThickness: 24,
    );
  });

  testWidgets('LingGlassFloatingSwitch stretches only during full motion', (
    tester,
  ) async {
    Future<void> pumpSwitch({required bool disableAnimations}) async {
      var selected = 'today';
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              return LingGlassFloatingSwitch<String>(
                width: 240,
                items: const [
                  LingGlassFloatingSwitchItem(
                    value: 'today',
                    label: 'Today',
                    icon: Icons.space_dashboard_rounded,
                  ),
                  LingGlassFloatingSwitchItem(
                    value: 'moments',
                    label: 'Moments',
                    icon: Icons.auto_awesome_rounded,
                  ),
                ],
                selected: selected,
                onChanged: (value) => setState(() => selected = value),
              );
            },
          ),
          disableAnimations: disableAnimations,
        ),
      );
    }

    Positioned indicator() {
      return tester
          .widgetList<Positioned>(
            find.descendant(
              of: find.byType(LingGlassFloatingSwitch<String>),
              matching: find.byType(Positioned),
            ),
          )
          .first;
    }

    await pumpSwitch(disableAnimations: false);
    final restingWidth = indicator().width!;
    await tester.tap(find.text('Moments'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(indicator().width, greaterThan(restingWidth));
    await tester.pumpAndSettle();
    expect(indicator().width, restingWidth);

    await pumpSwitch(disableAnimations: true);
    final reducedMotionRestingWidth = indicator().width!;
    await tester.tap(find.text('Moments'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(indicator().width, reducedMotionRestingWidth);
  });

  testWidgets('LingAdaptiveSwitch keeps switch glass settings by theme', (
    tester,
  ) async {
    Future<void> expectSwitch({
      required ThemeMode themeMode,
      required Color expectedInactiveColor,
      required Color expectedActiveColor,
      required Color expectedThumbColor,
      required Color expectedGlass,
    }) async {
      await tester.pumpWidget(
        _host(
          LingAdaptiveSwitch(value: false, onChanged: (_) {}),
          themeMode: themeMode,
        ),
      );

      final glassSwitch = tester.widget<GlassSwitch>(find.byType(GlassSwitch));

      expect(glassSwitch.inactiveColor, Colors.transparent);
      expect(glassSwitch.activeColor, expectedActiveColor);
      expect(glassSwitch.thumbColor, expectedThumbColor);
      expect(glassSwitch.settings?.glassColor, expectedGlass);
      expect(glassSwitch.settings?.blur, themeMode == ThemeMode.dark ? 7 : 8);
      expect(
        glassSwitch.settings?.thickness,
        themeMode == ThemeMode.dark ? 20 : 32,
      );

      final inactiveTrack = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(LingAdaptiveSwitch),
              matching: find.byType(DecoratedBox),
            ),
          )
          .first;
      final decoration = inactiveTrack.decoration as BoxDecoration;
      expect(decoration.color, expectedInactiveColor);
    }

    final lightPalette = AppTheme.light().extension<LingPalette>()!;
    final darkPalette = AppTheme.dark().extension<LingPalette>()!;
    await expectSwitch(
      themeMode: ThemeMode.light,
      expectedInactiveColor: lightPalette.fieldBorder.withValues(alpha: 0.92),
      expectedActiveColor: lightPalette.primaryButtonBackground,
      expectedThumbColor: lightPalette.primaryButtonForeground,
      expectedGlass: lightPalette.glassMutedTint,
    );
    await expectSwitch(
      themeMode: ThemeMode.dark,
      expectedInactiveColor: darkPalette.glassMutedTint,
      expectedActiveColor: darkPalette.primaryButtonBackground,
      expectedThumbColor: darkPalette.primaryButtonForeground,
      expectedGlass: darkPalette.glassMutedTint,
    );
  });

  testWidgets('LingGlassButton default accent uses semantic button colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        LingGlassButton(onPressed: () {}, child: const Text('Continue')),
        themeMode: ThemeMode.dark,
      ),
    );

    final palette = AppTheme.dark().extension<LingPalette>()!;
    final glassButton = tester.widget<GlassButton>(find.byType(GlassButton));
    final text = tester.widget<Text>(find.text('Continue'));
    final defaultTextStyle = DefaultTextStyle.of(
      tester.element(find.text('Continue')),
    );

    expect(glassButton.settings?.glassColor, palette.primaryButtonBackground);
    expect(
      text.style?.color ?? defaultTextStyle.style.color,
      palette.primaryButtonForeground,
    );
  });

  testWidgets('LingGlassButton does not inherit oversized parent text style', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        DefaultTextStyle.merge(
          style: const TextStyle(
            fontSize: 72,
            decoration: TextDecoration.underline,
          ),
          child: LingGlassButton(onPressed: () {}, child: const Text('Open')),
        ),
      ),
    );

    final buttonTextStyle = DefaultTextStyle.of(
      tester.element(find.text('Open')),
    );
    expect(buttonTextStyle.style.fontSize, 17);
    expect(buttonTextStyle.style.height, 1.08);
    expect(buttonTextStyle.style.decoration, TextDecoration.none);
  });

  testWidgets('LingGlassButton muted tone keeps a visible light-mode border', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        LingGlassButton(
          onPressed: () {},
          tone: LingGlassSurfaceTone.muted,
          child: const Text('Cancel'),
        ),
      ),
    );

    final palette = AppTheme.light().extension<LingPalette>()!;
    final border = tester.widget<DecoratedBox>(
      find.byKey(const Key('ling_glass_button_border')),
    );
    final decoration = border.decoration as ShapeDecoration;
    final shape = decoration.shape as RoundedRectangleBorder;

    expect(shape.side.color, palette.fieldBorder.withValues(alpha: 0.96));
    expect(shape.side.width, 1);
  });

  testWidgets('LingGlassButton keeps disabled callbacks inert', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      _host(
        LingGlassButton(onPressed: null, child: const Text('Disabled')),
        themeMode: ThemeMode.dark,
      ),
    );

    final palette = AppTheme.dark().extension<LingPalette>()!;
    expect(find.byType(GlassButton), findsOneWidget);
    final disabledButton = tester.widget<GlassButton>(find.byType(GlassButton));
    final disabledText = tester.widget<Text>(find.text('Disabled'));
    final disabledDefaultTextStyle = DefaultTextStyle.of(
      tester.element(find.text('Disabled')),
    );
    expect(
      disabledButton.settings?.glassColor,
      palette.primaryButtonDisabledBackground,
    );
    expect(
      disabledText.style?.color ?? disabledDefaultTextStyle.style.color,
      palette.primaryButtonDisabledForeground,
    );
    final opacityWidgets = tester.widgetList<Opacity>(
      find.descendant(
        of: find.byType(LingGlassButton),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacityWidgets.where((widget) => widget.opacity == 0.55), isEmpty);
    await tester.tap(find.text('Disabled'));
    await tester.pump();
    expect(taps, 0);

    await tester.pumpWidget(
      _host(
        LingGlassButton(onPressed: () => taps++, child: const Text('Enabled')),
      ),
    );

    await tester.tap(find.text('Enabled'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('LingLongPressScale enlarges while pressed', (tester) async {
    await tester.pumpWidget(
      _host(
        const LingLongPressScale(
          key: Key('press_scale'),
          child: SizedBox(width: 80, height: 44, child: Text('Hold')),
        ),
      ),
    );

    AnimatedScale scaleWidget() {
      return tester
          .widgetList<AnimatedScale>(
            find.descendant(
              of: find.byKey(const Key('press_scale')),
              matching: find.byType(AnimatedScale),
            ),
          )
          .first;
    }

    expect(scaleWidget().scale, 1);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Hold')),
    );
    await tester.pump();

    expect(scaleWidget().scale, 1.08);

    await gesture.up();
    await tester.pump();

    expect(scaleWidget().scale, 1);
  });

  testWidgets('LingLongPressScale keeps dark press highlight off', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const LingLongPressScale(
          key: Key('dark_press_scale'),
          child: SizedBox(width: 80, height: 44, child: Text('Hold dark')),
        ),
        themeMode: ThemeMode.dark,
      ),
    );

    AnimatedScale scaleWidget() {
      return tester
          .widgetList<AnimatedScale>(
            find.descendant(
              of: find.byKey(const Key('dark_press_scale')),
              matching: find.byType(AnimatedScale),
            ),
          )
          .first;
    }

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Hold dark')),
    );
    await tester.pump();

    expect(scaleWidget().scale, 1.08);

    await gesture.up();
    await tester.pump();

    expect(scaleWidget().scale, 1);
  });

  testWidgets('LingGlassTextField accepts text input', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(LingGlassTextField(controller: controller, placeholder: 'Message')),
    );

    expect(find.byType(GlassTextField), findsNothing);
    expect(find.byType(GlassContainer), findsWidgets);
    await tester.enterText(find.byType(TextField), 'hello');
    expect(controller.text, 'hello');
  });

  testWidgets('LingGlassTextField uses semantic input colors', (tester) async {
    await tester.pumpWidget(
      _host(
        const LingGlassTextField(placeholder: 'Message'),
        themeMode: ThemeMode.dark,
      ),
    );

    final palette = AppTheme.dark().extension<LingPalette>()!;
    final textField = tester.widget<TextField>(find.byType(TextField));
    final glassContainer = tester
        .widgetList<GlassContainer>(
          find.descendant(
            of: find.byType(LingGlassTextField),
            matching: find.byType(GlassContainer),
          ),
        )
        .first;

    expect(textField.cursorColor, palette.inputCursor);
    expect(textField.style?.color, palette.inputForeground);
    expect(textField.decoration?.hintStyle?.color, palette.inputPlaceholder);
    expect(glassContainer.settings?.glassColor, palette.inputBackground);
    final edge = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(LingGlassTextField),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = edge.decoration as ShapeDecoration;
    final shape = decoration.shape as RoundedRectangleBorder;
    expect(shape.side.color, palette.fieldBorder);
  });

  testWidgets('LingGlassTextField has no button-like press wrapper', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const LingGlassTextField(placeholder: 'Email')),
    );

    expect(find.byType(GlassTextField), findsNothing);
    expect(
      find.descendant(
        of: find.byType(LingGlassTextField),
        matching: find.byType(AnimatedScale),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(LingGlassTextField),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.button == true,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('LingGlassChip renders through GlassChip', (tester) async {
    await tester.pumpWidget(
      _host(
        LingGlassChip(
          label: 'Today',
          leadingIcon: Icons.today_rounded,
          onPressed: () {},
          maxWidth: 96,
        ),
      ),
    );

    expect(find.byType(GlassChip), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('new glass wrappers render through SDK components', (
    tester,
  ) async {
    var tileTaps = 0;
    var sliderValue = 0.4;
    var pickerTaps = 0;

    await tester.pumpWidget(
      _host(
        Column(
          children: [
            LingGlassPanel(child: const Text('Panel')),
            LingGlassListTile(
              title: const Text('Tile'),
              onTap: () => tileTaps++,
            ),
            LingGlassSlider(
              value: sliderValue,
              onChanged: (value) => sliderValue = value,
            ),
            LingGlassPicker(value: 'Week', onTap: () => pickerTaps++),
          ],
        ),
      ),
    );

    expect(find.byType(GlassCard), findsWidgets);
    expect(find.byType(GlassListTile), findsOneWidget);
    expect(find.byType(GlassSlider), findsOneWidget);
    expect(find.byType(GlassPicker), findsOneWidget);

    await tester.tap(find.text('Tile'));
    await tester.tap(find.text('Week'));
    await tester.pump();

    expect(tileTaps, 1);
    expect(pickerTaps, 1);
    expect(sliderValue, 0.4);
  });

  testWidgets('LingGlassSlider keeps thumb and track visible in light mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(LingGlassSlider(value: 0.5, onChanged: (_) {})),
    );

    final palette = AppTheme.light().extension<LingPalette>()!;
    final slider = tester.widget<GlassSlider>(find.byType(GlassSlider));
    final border = tester.widget<DecoratedBox>(
      find.byKey(const Key('ling_glass_slider_thumb_border')),
    );
    final decoration = border.decoration as ShapeDecoration;
    final shape = decoration.shape as StadiumBorder;

    expect(slider.inactiveColor, palette.fieldBorder.withValues(alpha: 0.88));
    expect(shape.side.color, palette.fieldBorder);
  });

  testWidgets('LingGlassSlider avoids repeated haptics while dragging', (
    tester,
  ) async {
    var sliderValue = 2.0;

    await tester.pumpWidget(
      _host(
        LingGlassSlider(
          value: sliderValue,
          min: 0,
          max: 4,
          divisions: 4,
          onChanged: (value) {
            sliderValue = value;
          },
        ),
      ),
    );

    final slider = tester.widget<GlassSlider>(find.byType(GlassSlider));
    slider.onChanged?.call(2);
    slider.onChanged?.call(2);
    slider.onChanged?.call(3);

    expect(sliderValue, 3);
    expect(platformCalls, isEmpty);
  });

  testWidgets('LingGlassSlider tap haptic only fires for a changed value', (
    tester,
  ) async {
    var sliderValue = 2.0;

    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            return LingGlassSlider(
              value: sliderValue,
              min: 0,
              max: 4,
              divisions: 4,
              onChanged: (value) {
                setState(() {
                  sliderValue = value;
                });
              },
            );
          },
        ),
      ),
    );

    final box = tester.renderObject<RenderBox>(find.byType(LingGlassSlider));
    final center = box.localToGlobal(box.size.center(Offset.zero));
    await tester.tapAt(center);
    await tester.pump();

    expect(sliderValue, 2);
    expect(platformCalls, isEmpty);

    await tester.tapAt(center.translate(box.size.width / 2 - 1, 0));
    await tester.pump();

    expect(sliderValue, 4);
    expect(platformCalls, hasLength(1));
    expect(platformCalls.single.arguments, 'HapticFeedbackType.selectionClick');
  });

  testWidgets('LingGlassSheetFrame renders through GlassCard', (tester) async {
    await tester.pumpWidget(
      _host(
        const LingGlassSheetFrame(
          showDragHandle: true,
          child: Text('sheet content'),
        ),
      ),
    );

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.text('sheet content'), findsOneWidget);
  });

  testWidgets('adaptive sheets disable sheet-level press feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return LingGlassButton(
              onPressed: () {
                showLingAdaptiveSheet<void>(
                  context: context,
                  builder: (_) => const Text('Sheet content'),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<GlassSheet>(find.byType(GlassSheet));
    expect(sheet.interactionScale, 1);
    expect(sheet.stretch, 0);
    expect(sheet.enableInteractionGlow, isFalse);
    expect(sheet.enableSaturationGlow, isFalse);
    expect(sheet.suppressInteractionOnChildren, isTrue);
  });

  testWidgets('adaptive sheets provide app text style for sheet content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return LingGlassButton(
              onPressed: () {
                showLingAdaptiveSheet<void>(
                  context: context,
                  builder: (_) => const Text('Sheet content'),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final sheetTextStyle = DefaultTextStyle.of(
      tester.element(find.text('Sheet content')),
    );
    expect(sheetTextStyle.style.decoration, TextDecoration.none);
  });

  testWidgets('settings option sheet uses quiet rows', (tester) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return LingGlassButton(
              onPressed: () {
                showLingSettingsOptionSheet<String>(
                  context: context,
                  title: 'Mode',
                  cancelLabel: 'Cancel',
                  selected: 'week',
                  options: const [
                    LingSettingsPickerOption(value: 'week', label: 'Week'),
                    LingSettingsPickerOption(value: 'month', label: 'Month'),
                  ],
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('Mode'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    final sheet = tester.widget<GlassSheet>(find.byType(GlassSheet));
    expect(sheet.interactionScale, 1);
    expect(sheet.stretch, 0);
    expect(sheet.enableInteractionGlow, isFalse);
    expect(sheet.enableSaturationGlow, isFalse);
  });

  testWidgets('settings option sheet can hide title and cancel button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return LingGlassButton(
              onPressed: () {
                showLingSettingsOptionSheet<String>(
                  context: context,
                  title: 'Mode',
                  cancelLabel: 'Cancel',
                  selected: 'week',
                  showTitle: false,
                  showCancelButton: false,
                  options: const [
                    LingSettingsPickerOption(value: 'week', label: 'Week'),
                    LingSettingsPickerOption(value: 'month', label: 'Month'),
                  ],
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Mode'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('LingGlassTextField uses app-owned icon layout', (tester) async {
    var suffixTaps = 0;

    await tester.pumpWidget(
      _host(
        LingGlassTextField(
          placeholder: 'Search',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: const Icon(Icons.clear),
          onSuffixTap: () => suffixTaps++,
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));

    expect(textField.decoration?.hintText, 'Search');
    expect(find.byType(Divider), findsNothing);
    expect(find.byType(VerticalDivider), findsNothing);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(suffixTaps, 1);
  });
}
