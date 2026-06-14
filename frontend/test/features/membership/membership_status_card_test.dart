import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/membership/models/membership_models.dart';
import 'package:ling/src/features/membership/presentation/membership_status_card.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/brand_palettes.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  testWidgets('membership status card keeps brand colors in dark theme', (
    tester,
  ) async {
    const strings = LingStrings('en-US');

    await tester.pumpWidget(
      const _MembershipCardHost(
        summary: MembershipSummary(
          tierCode: 'pro',
          accessState: 'active',
          renewalType: 'recurring',
          provider: 'apple',
          startedAt: '2026-05-01T00:00:00Z',
          paidThroughAt: '2026-06-01T00:00:00Z',
          cancelAtPeriodEnd: false,
          dailyChatLimit: null,
          dailyChatUsed: 0,
          dailyChatRemaining: null,
          businessTimezone: 'Asia/Shanghai',
          serverNow: '2026-05-11T00:00:00Z',
          entitlements: <String>['member_core'],
          pointsBalance: 0,
        ),
        strings: strings,
      ),
    );

    final activeIcon = tester.widget<Icon>(
      find.byIcon(Icons.workspace_premium_rounded),
    );
    final activeTier = tester.widget<Text>(
      find.text(strings.membershipActiveStatus),
    );

    expect(activeIcon.color, LingMembershipBrandPalette.activeForeground);
    expect(
      activeTier.style?.color,
      LingMembershipBrandPalette.activeForeground,
    );

    await tester.pumpWidget(
      const _MembershipCardHost(summary: null, strings: strings),
    );

    final inactiveIcon = tester.widget<Icon>(
      find.byIcon(Icons.workspace_premium_rounded),
    );

    expect(inactiveIcon.color, LingMembershipBrandPalette.inactiveAccentDark);
  });

  testWidgets('membership status card renders backend display copy', (
    tester,
  ) async {
    const strings = LingStrings('en-US');
    const summary = MembershipSummary(
      tierCode: 'pro',
      accessState: 'active',
      renewalType: 'recurring',
      provider: 'apple',
      startedAt: '2026-05-01T00:00:00Z',
      paidThroughAt: '2026-06-01T00:00:00Z',
      cancelAtPeriodEnd: false,
      dailyChatLimit: null,
      dailyChatUsed: 0,
      dailyChatRemaining: null,
      businessTimezone: 'Asia/Shanghai',
      serverNow: '2026-05-11T00:00:00Z',
      entitlements: <String>['member_core'],
      pointsBalance: 0,
      display: <String, dynamic>{
        'membership_state_card': <String, dynamic>{
          'title': 'First Month Gift',
          'subtitle': 'Your first month is included.',
        },
      },
    );

    await tester.pumpWidget(
      const _MembershipCardHost(summary: summary, strings: strings),
    );

    expect(find.text('First Month Gift'), findsOneWidget);
    expect(find.text('Your first month is included.'), findsOneWidget);
    expect(find.text(strings.membershipActiveStatus), findsNothing);
  });

  testWidgets('membership status card avoids glass surfaces', (tester) async {
    const strings = LingStrings('en-US');
    const summary = MembershipSummary(
      tierCode: 'pro',
      accessState: 'active',
      renewalType: 'recurring',
      provider: 'apple',
      startedAt: '2026-05-01T00:00:00Z',
      paidThroughAt: '2026-06-01T00:00:00Z',
      cancelAtPeriodEnd: false,
      dailyChatLimit: null,
      dailyChatUsed: 0,
      dailyChatRemaining: null,
      businessTimezone: 'Asia/Shanghai',
      serverNow: '2026-05-11T00:00:00Z',
      entitlements: <String>['member_core'],
      pointsBalance: 0,
    );

    await tester.pumpWidget(
      const _MembershipCardHost(
        summary: summary,
        strings: strings,
        themeMode: ThemeMode.light,
      ),
    );

    expect(find.byType(Ink), findsOneWidget);
    expect(find.byType(DecoratedBox), findsWidgets);
    expect(find.byType(Material), findsWidgets);
    expect(find.byType(GlassCard), findsNothing);
    expect(find.byType(LingGlassSurface), findsNothing);

    await tester.pumpWidget(
      const _MembershipCardHost(
        summary: summary,
        strings: strings,
        themeMode: ThemeMode.dark,
      ),
    );

    expect(find.byType(Ink), findsOneWidget);
    expect(find.byType(DecoratedBox), findsWidgets);
    expect(find.byType(GlassCard), findsNothing);
    expect(find.byType(LingGlassSurface), findsNothing);
  });

  testWidgets('membership status card keeps shadow on rounded outer shape', (
    tester,
  ) async {
    const strings = LingStrings('en-US');

    await tester.pumpWidget(
      const _MembershipCardHost(summary: null, strings: strings),
    );

    final outerDecoration = tester.widget<DecoratedBox>(
      find.byKey(const Key('settings_membership_card')),
    );
    final outerBoxDecoration = outerDecoration.decoration as BoxDecoration;
    final ink = tester.widget<Ink>(find.byType(Ink));
    final inkDecoration = ink.decoration as BoxDecoration;

    expect(outerBoxDecoration.borderRadius, BorderRadius.circular(18));
    expect(outerBoxDecoration.boxShadow, isNotNull);
    expect(outerBoxDecoration.boxShadow, isNotEmpty);
    expect(inkDecoration.borderRadius, BorderRadius.circular(18));
    expect(inkDecoration.boxShadow, isNull);
  });

  testWidgets('membership status card uses readable text in light theme', (
    tester,
  ) async {
    const strings = LingStrings('en-US');
    const summary = MembershipSummary(
      tierCode: 'pro',
      accessState: 'active',
      renewalType: 'recurring',
      provider: 'apple',
      startedAt: '2026-05-01T00:00:00Z',
      paidThroughAt: '2026-06-01T00:00:00Z',
      cancelAtPeriodEnd: false,
      dailyChatLimit: null,
      dailyChatUsed: 0,
      dailyChatRemaining: null,
      businessTimezone: 'Asia/Shanghai',
      serverNow: '2026-05-11T00:00:00Z',
      entitlements: <String>['member_core'],
      pointsBalance: 0,
    );

    await tester.pumpWidget(
      const _MembershipCardHost(
        summary: summary,
        strings: strings,
        themeMode: ThemeMode.light,
      ),
    );

    final activeIcon = tester.widget<Icon>(
      find.byIcon(Icons.workspace_premium_rounded),
    );
    final activeTier = tester.widget<Text>(
      find.text(strings.membershipActiveStatus),
    );

    expect(activeIcon.color, LingMembershipBrandPalette.activeIconLight);
    expect(
      activeTier.style?.color,
      LingMembershipBrandPalette.activeForegroundLight,
    );
  });
}

class _MembershipCardHost extends StatelessWidget {
  const _MembershipCardHost({
    required this.summary,
    required this.strings,
    this.themeMode = ThemeMode.dark,
  });

  final MembershipSummary? summary;
  final LingStrings strings;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: LingMembershipStatusCard(
              summary: summary,
              strings: strings,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
  }
}
