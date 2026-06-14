import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/calendar/presentation/schedule_agenda_card.dart';
import 'package:ling/src/features/calendar/presentation/schedule_view_models.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  testWidgets('long location metadata does not overflow narrow cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final startAt = DateTime(2026, 5, 10, 9);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: LingScheduleAgendaCard(
                item: LingScheduleAgendaItem(
                  title: 'Morning planning',
                  subtitle: '',
                  location:
                      'Conference room with a very long location name that should be constrained by the agenda card instead of overflowing the row',
                  startAt: startAt,
                  endAt: startAt.add(const Duration(hours: 1)),
                  accent: Colors.teal,
                  sourceLabel: 'Ling',
                  categoryLabel: '',
                  timeLabel: '09:00',
                  durationLabel: '1h',
                ),
                onEditLingEvent: (_) {},
                onDeleteLingEvent: (_) {},
                onDeleteAppleEvent: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('uses stable schedule card tint in light and dark modes', (
    tester,
  ) async {
    final startAt = DateTime(2026, 5, 10, 9);
    final item = LingScheduleAgendaItem(
      title: 'Morning planning',
      subtitle: '',
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 1)),
      accent: Colors.teal,
      sourceLabel: 'Ling',
      categoryLabel: '',
      timeLabel: '09:00',
      durationLabel: '1h',
    );

    Future<LiquidGlassSettings> pumpAndReadSettings(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: LingScheduleAgendaCard(
                item: item,
                onEditLingEvent: (_) {},
                onDeleteLingEvent: (_) {},
                onDeleteAppleEvent: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      return tester.widget<GlassCard>(find.byType(GlassCard)).settings!;
    }

    final lightSettings = await pumpAndReadSettings(AppTheme.light());
    expect(lightSettings.glassColor.r, closeTo(0.9725, 0.001));
    expect(lightSettings.glassColor.g, closeTo(0.9804, 0.001));
    expect(lightSettings.glassColor.b, closeTo(0.9882, 0.001));
    expect(lightSettings.glassColor.a, closeTo(0.98, 0.001));
    expect(lightSettings.saturation, 1.08);
    expect(lightSettings.lightIntensity, 0.82);

    final darkSettings = await pumpAndReadSettings(AppTheme.dark());
    expect(darkSettings.glassColor.a, closeTo(0.94, 0.001));
    expect(darkSettings.saturation, 1.0);
    expect(darkSettings.lightIntensity, 0.46);
  });
}
