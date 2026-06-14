import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/membership/application/membership_controller.dart';
import 'package:ling/src/features/membership/application/membership_gate.dart';
import 'package:ling/src/features/membership/application/membership_state.dart';
import 'package:ling/src/features/membership/models/membership_models.dart';
import 'package:ling/src/features/membership/presentation/membership_gate_sheet.dart';
import 'package:ling/src/features/membership/presentation/membership_subscription_panel.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/brand_palettes.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

const _defaultSubscriptionSheetMetadata = <String, dynamic>{
  'subscription_sheet': <String, dynamic>{
    'tier_cards': <Map<String, dynamic>>[
      <String, dynamic>{
        'tier_code': 'free',
        'title': 'Free',
        'price_label_zh': '免费',
        'features_zh': <String>['基础日程管理', '基础想法管理', '每日 50 次文字/图片对话'],
      },
      <String, dynamic>{
        'tier_code': 'pro',
        'title': 'Pro',
        'features_zh': <String>[
          '不限文字/图片对话',
          'Ling Workbench 完整视图',
          '图片输入与理解',
          '记忆整理与分享素材能力',
          '新能力优先开放',
        ],
      },
    ],
  },
};

void main() {
  testWidgets('membership gate shows a stronger Pro upgrade card', (
    tester,
  ) async {
    const strings = LingStrings('zh-CN');

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  unawaited(
                    showLingMembershipGateSheet(
                      context: context,
                      strings: strings,
                      gate: const MembershipGateResult(
                        shouldBlock: true,
                        reason: QuotaExhaustedReason.dailyLimitReached,
                        summary: MembershipSummary(
                          tierCode: 'free',
                          accessState: 'inactive',
                          renewalType: null,
                          provider: null,
                          startedAt: null,
                          paidThroughAt: null,
                          cancelAtPeriodEnd: false,
                          dailyChatLimit: 50,
                          dailyChatUsed: 50,
                          dailyChatRemaining: 0,
                          businessTimezone: 'Asia/Shanghai',
                          serverNow: '2026-06-08T00:00:00+00:00',
                          entitlements: <String>['chat_daily_limit'],
                          pointsBalance: 0,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('今日免费对话次数已用完'), findsOneWidget);
    expect(find.text('不限文字/图片对话'), findsOneWidget);
    expect(find.text('图片输入与理解'), findsOneWidget);
    expect(find.text('记忆整理与分享素材能力'), findsOneWidget);
    expect(find.text('升级 Pro'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(
      tester
          .widgetList<LingGlassSurface>(find.byType(LingGlassSurface))
          .where((surface) => surface.quality == LingGlassQuality.premium),
      isEmpty,
    );
  });

  testWidgets('Ling mascot membership gate does not scroll internally', (
    tester,
  ) async {
    const strings = LingStrings('zh-CN');

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  unawaited(
                    showLingMembershipGateSheet(
                      context: context,
                      strings: strings,
                      gate: const MembershipGateResult(
                        shouldBlock: true,
                        reason: QuotaExhaustedReason.membershipRequired,
                        summary: MembershipSummary(
                          tierCode: 'free',
                          accessState: 'inactive',
                          renewalType: null,
                          provider: null,
                          startedAt: null,
                          paidThroughAt: null,
                          cancelAtPeriodEnd: false,
                          dailyChatLimit: 50,
                          dailyChatUsed: 0,
                          dailyChatRemaining: 50,
                          businessTimezone: 'Asia/Shanghai',
                          serverNow: '2026-06-08T00:00:00+00:00',
                          entitlements: <String>['chat_daily_limit'],
                          pointsBalance: 0,
                        ),
                      ),
                      title: strings.membershipLingSurfaceGateTitle,
                      body: strings.membershipLingSurfaceGateBody,
                      benefits: [
                        strings.membershipUpgradeBenefitImageInput,
                        strings.membershipUpgradeBenefitMemory,
                        strings.membershipUpgradeBenefitChat,
                      ],
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(strings.membershipLingSurfaceGateTitle), findsOneWidget);
    expect(find.text(strings.membershipUpgradeAction), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets('subscription panel waits for initial catalog before rendering', (
    tester,
  ) async {
    const strings = LingStrings('zh-CN');
    final container = ProviderContainer(
      overrides: [
        membershipControllerProvider.overrideWith(
          _LoadingMembershipController.new,
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const Scaffold(
            body: LingMembershipSubscriptionPanel(strings: strings),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('membership_catalog_loading_state')),
      findsOneWidget,
    );
    expect(find.text(strings.membershipServerConfigErrorTitle), findsNothing);
  });

  testWidgets(
    'subscription panel uses the catalog price for the pro plan and CTA',
    (tester) async {
      const strings = LingStrings('zh-CN');
      final product = MembershipCatalogProduct(
        internalProductCode: 'pro_month_recurring',
        tierCode: 'pro',
        periodCode: 'month',
        renewalType: 'recurring',
        durationMonths: 1,
        displayName: 'Pro 连续包月',
        displaySubtitle: '全部功能 + 不限对话',
        marketingLabel: null,
        dailyChatLimit: null,
        entitlements: const <String>['member_core', 'member_advanced'],
        metadata: _defaultSubscriptionSheetMetadata,
        channels: const <MembershipCatalogChannel>[
          MembershipCatalogChannel(
            provider: 'apple',
            platform: 'ios',
            providerProductId: 'ling.pro_month_recurring',
            currencyCode: 'CNY',
            amountMinor: 29800,
            marketingLabel: null,
            metadata: <String, dynamic>{},
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          membershipControllerProvider.overrideWith(
            () => _FakeMembershipController(catalog: [product]),
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: const Scaffold(
              body: LingMembershipSubscriptionPanel(strings: strings),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('¥298/每月'), findsOneWidget);
      expect(find.text('¥298/月起'), findsNothing);
      expect(find.text('开通自动续费 ¥298/连续包月'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const Key('membership_free_tier_card')))
            .height,
        tester
            .getSize(find.byKey(const Key('membership_pro_tier_card')))
            .height,
      );
    },
  );

  testWidgets('subscription panel exposes review-required purchase links', (
    tester,
  ) async {
    const strings = LingStrings('en-US');
    final product = MembershipCatalogProduct(
      internalProductCode: 'pro_month_recurring',
      tierCode: 'pro',
      periodCode: 'month',
      renewalType: 'recurring',
      durationMonths: 1,
      displayName: 'Pro Monthly',
      displaySubtitle: 'All features and unlimited chats',
      marketingLabel: null,
      dailyChatLimit: null,
      entitlements: const <String>['member_core', 'member_advanced'],
      metadata: _defaultSubscriptionSheetMetadata,
      channels: const <MembershipCatalogChannel>[
        MembershipCatalogChannel(
          provider: 'apple',
          platform: 'ios',
          providerProductId: 'ling.pro_month_recurring',
          currencyCode: 'CNY',
          amountMinor: 29800,
          marketingLabel: null,
          metadata: <String, dynamic>{},
        ),
      ],
    );
    final controller = _FakeMembershipController(catalog: [product]);
    final container = ProviderContainer(
      overrides: [membershipControllerProvider.overrideWith(() => controller)],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en', 'US'),
          supportedLocales: const [Locale('en', 'US')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: LingMembershipSubscriptionPanel(strings: strings),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('membership_restore_purchases_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('membership_manage_subscription_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('membership_privacy_policy_link')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('membership_terms_of_use_link')),
      findsOneWidget,
    );
    expect(find.text(strings.membershipRestorePurchases), findsOneWidget);
    expect(find.text(strings.membershipManageSubscription), findsOneWidget);
    expect(find.text(strings.membershipPrivacyPolicyLink), findsOneWidget);
    expect(find.text(strings.membershipTermsOfUseLink), findsOneWidget);
    final restoreLink = tester.widget<TextButton>(
      find.byKey(const Key('membership_restore_purchases_button')),
    );
    final manageLink = tester.widget<TextButton>(
      find.byKey(const Key('membership_manage_subscription_button')),
    );
    final privacyLink = tester.widget<TextButton>(
      find.byKey(const Key('membership_privacy_policy_link')),
    );
    final termsLink = tester.widget<TextButton>(
      find.byKey(const Key('membership_terms_of_use_link')),
    );
    expect(restoreLink.style?.side?.resolve(<WidgetState>{}), BorderSide.none);
    expect(manageLink.style?.side?.resolve(<WidgetState>{}), BorderSide.none);
    expect(privacyLink.style?.side?.resolve(<WidgetState>{}), BorderSide.none);
    expect(termsLink.style?.side?.resolve(<WidgetState>{}), BorderSide.none);

    await tester.tap(
      find.byKey(const Key('membership_restore_purchases_button')),
    );
    await tester.pumpAndSettle();

    expect(controller.restoreCallCount, 1);
  });

  testWidgets('subscription panel renders tier copy from catalog metadata', (
    tester,
  ) async {
    const strings = LingStrings('zh-CN');
    final product = MembershipCatalogProduct(
      internalProductCode: 'pro_month_recurring',
      tierCode: 'pro',
      periodCode: 'month',
      renewalType: 'recurring',
      durationMonths: 1,
      displayName: 'Pro 连续包月',
      displaySubtitle: '全部功能 + 不限对话',
      marketingLabel: null,
      dailyChatLimit: null,
      entitlements: const <String>['member_core', 'member_advanced'],
      metadata: const <String, dynamic>{
        'subscription_sheet': <String, dynamic>{
          'tier_cards': <Map<String, dynamic>>[
            <String, dynamic>{
              'tier_code': 'free',
              'title': 'Starter',
              'price_label_zh': '入门',
              'features_zh': <String>['后端 Free 权益'],
            },
            <String, dynamic>{
              'tier_code': 'pro',
              'title': 'Plus',
              'features_zh': <String>['后端 Pro 权益'],
            },
          ],
        },
      },
      channels: const <MembershipCatalogChannel>[
        MembershipCatalogChannel(
          provider: 'apple',
          platform: 'ios',
          providerProductId: 'ling.pro_month_recurring',
          currencyCode: 'CNY',
          amountMinor: 29800,
          marketingLabel: null,
          metadata: <String, dynamic>{},
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        membershipControllerProvider.overrideWith(
          () => _FakeMembershipController(catalog: [product]),
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: LingMembershipSubscriptionPanel(strings: strings),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Starter'), findsOneWidget);
    expect(find.text('入门'), findsOneWidget);
    expect(find.text('后端 Free 权益'), findsOneWidget);
    expect(find.text('Plus'), findsOneWidget);
    expect(find.text('后端 Pro 权益'), findsOneWidget);
    expect(find.text(strings.membershipFreeFeatureSchedule), findsNothing);
  });

  testWidgets('subscription panel does not render entitlement sections', (
    tester,
  ) async {
    const strings = LingStrings('zh-CN');
    final product = MembershipCatalogProduct(
      internalProductCode: 'pro_month_recurring',
      tierCode: 'pro',
      periodCode: 'month',
      renewalType: 'recurring',
      durationMonths: 1,
      displayName: 'Pro 连续包月',
      displaySubtitle: '全部功能 + 不限对话',
      marketingLabel: null,
      dailyChatLimit: null,
      entitlements: const <String>['member_core', 'member_advanced'],
      metadata: const <String, dynamic>{
        ..._defaultSubscriptionSheetMetadata,
        'entitlement_sections': <Map<String, dynamic>>[
          <String, dynamic>{
            'title_zh': '页面功能点',
            'free_items_zh': <String>['基础查看'],
            'pro_items_zh': <String>['图片输入与理解'],
          },
          <String, dynamic>{
            'title_zh': '高级能力',
            'free_items_zh': <String>['日程提醒'],
            'pro_items_zh': <String>['记忆整理'],
          },
          <String, dynamic>{
            'title_zh': '对话次数',
            'free_items_zh': <String>['每日 50 次对话'],
            'pro_items_zh': <String>['每日不限对话'],
          },
        ],
      },
      channels: const <MembershipCatalogChannel>[
        MembershipCatalogChannel(
          provider: 'apple',
          platform: 'ios',
          providerProductId: 'ling.pro_month_recurring',
          currencyCode: 'CNY',
          amountMinor: 29800,
          marketingLabel: null,
          metadata: <String, dynamic>{},
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        membershipControllerProvider.overrideWith(
          () => _FakeMembershipController(catalog: [product]),
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: LingMembershipSubscriptionPanel(strings: strings),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('页面功能点'), findsNothing);
    expect(find.text('高级能力'), findsNothing);
    expect(find.text('对话次数'), findsNothing);
    expect(find.text('记忆整理'), findsNothing);
    expect(find.text('每日不限对话'), findsNothing);
  });

  testWidgets(
    'subscription panel keeps membership card text white in dark mode',
    (tester) async {
      const strings = LingStrings('zh-CN');
      final product = MembershipCatalogProduct(
        internalProductCode: 'pro_month_recurring',
        tierCode: 'pro',
        periodCode: 'month',
        renewalType: 'recurring',
        durationMonths: 1,
        displayName: 'Pro 连续包月',
        displaySubtitle: '全部功能 + 不限对话',
        marketingLabel: null,
        dailyChatLimit: null,
        entitlements: const <String>['member_core', 'member_advanced'],
        metadata: _defaultSubscriptionSheetMetadata,
        channels: const <MembershipCatalogChannel>[
          MembershipCatalogChannel(
            provider: 'apple',
            platform: 'ios',
            providerProductId: 'ling.pro_month_recurring',
            currencyCode: 'CNY',
            amountMinor: 29800,
            marketingLabel: null,
            metadata: <String, dynamic>{},
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          membershipControllerProvider.overrideWith(
            () => _FakeMembershipController(catalog: [product]),
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            home: const Scaffold(
              body: LingMembershipSubscriptionPanel(strings: strings),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final proLabel = tester.widget<Text>(find.text('Pro'));
      final purchaseButton = tester.widget<LingAdaptiveFilledButton>(
        find.byKey(const Key('membership_purchase_button')),
      );

      expect(
        proLabel.style?.color,
        LingMembershipBrandPalette.activeForeground,
      );
      expect(
        purchaseButton.foregroundColor,
        LingMembershipBrandPalette.activeForeground,
      );
    },
  );

  testWidgets(
    'subscription panel avoids white membership card text in light mode',
    (tester) async {
      const strings = LingStrings('zh-CN');
      final product = MembershipCatalogProduct(
        internalProductCode: 'pro_month_recurring',
        tierCode: 'pro',
        periodCode: 'month',
        renewalType: 'recurring',
        durationMonths: 1,
        displayName: 'Pro 连续包月',
        displaySubtitle: '全部功能 + 不限对话',
        marketingLabel: null,
        dailyChatLimit: null,
        entitlements: const <String>['member_core', 'member_advanced'],
        metadata: _defaultSubscriptionSheetMetadata,
        channels: const <MembershipCatalogChannel>[
          MembershipCatalogChannel(
            provider: 'apple',
            platform: 'ios',
            providerProductId: 'ling.pro_month_recurring',
            currencyCode: 'CNY',
            amountMinor: 29800,
            marketingLabel: null,
            metadata: <String, dynamic>{},
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          membershipControllerProvider.overrideWith(
            () => _FakeMembershipController(catalog: [product]),
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.light,
            home: const Scaffold(
              body: LingMembershipSubscriptionPanel(strings: strings),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final proLabel = tester.widget<Text>(find.text('Pro'));
      final proCard = tester.widget<Container>(
        find
            .ancestor(of: find.text('Pro'), matching: find.byType(Container))
            .first,
      );
      final decoration = proCard.decoration as BoxDecoration;

      expect(
        proLabel.style?.color,
        LingMembershipBrandPalette.activeForegroundLight,
      );
      expect(
        decoration.gradient,
        isA<LinearGradient>().having(
          (gradient) => gradient.colors,
          'colors',
          LingMembershipBrandPalette.proCardGradientLight,
        ),
      );
      expect(decoration.color, isNull);
    },
  );

  testWidgets('subscription panel uses refined dark card colors', (
    tester,
  ) async {
    const strings = LingStrings('zh-CN');
    final product = MembershipCatalogProduct(
      internalProductCode: 'pro_month_recurring',
      tierCode: 'pro',
      periodCode: 'month',
      renewalType: 'recurring',
      durationMonths: 1,
      displayName: 'Pro 连续包月',
      displaySubtitle: '全部功能 + 不限对话',
      marketingLabel: null,
      dailyChatLimit: null,
      entitlements: const <String>['member_core', 'member_advanced'],
      metadata: _defaultSubscriptionSheetMetadata,
      channels: const <MembershipCatalogChannel>[
        MembershipCatalogChannel(
          provider: 'apple',
          platform: 'ios',
          providerProductId: 'ling.pro_month_recurring',
          currencyCode: 'CNY',
          amountMinor: 29800,
          marketingLabel: null,
          metadata: <String, dynamic>{},
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        membershipControllerProvider.overrideWith(
          () => _FakeMembershipController(catalog: [product]),
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: LingMembershipSubscriptionPanel(strings: strings),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final proCard = tester.widget<Container>(
      find
          .ancestor(of: find.text('Pro'), matching: find.byType(Container))
          .first,
    );
    final decoration = proCard.decoration as BoxDecoration;

    expect(
      decoration.gradient,
      isA<LinearGradient>().having(
        (gradient) => gradient.colors,
        'colors',
        LingMembershipBrandPalette.proCardGradientDark,
      ),
    );
    expect(decoration.border, isNotNull);
  });

  testWidgets('active membership card is visible in light mode', (
    tester,
  ) async {
    const strings = LingStrings('zh-CN');
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
    final container = ProviderContainer(
      overrides: [
        membershipControllerProvider.overrideWith(
          () => _FakeMembershipController(
            catalog: const <MembershipCatalogProduct>[],
            summary: summary,
          ),
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: LingMembershipSubscriptionPanel(strings: strings),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final activeCard = tester.widget<Container>(
      find.byKey(const Key('membership_active_card')),
    );
    final activeCardFinder = find.byKey(const Key('membership_active_card'));
    final decoration = activeCard.decoration as BoxDecoration;
    final title = tester.widget<Text>(
      find.descendant(
        of: activeCardFinder,
        matching: find.text(strings.membershipProAccessTitle),
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.verified_rounded));

    expect(
      decoration.gradient,
      isA<LinearGradient>().having(
        (gradient) => gradient.colors,
        'colors',
        LingMembershipBrandPalette.activeStateGradientLight,
      ),
    );
    expect(
      title.style?.color,
      LingMembershipBrandPalette.activeForegroundLight,
    );
    expect(icon.color, LingMembershipBrandPalette.activeForegroundLight);
    expect(
      find.descendant(
        of: activeCardFinder,
        matching: find.text(strings.membershipProAccessSubtitle),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: activeCardFinder,
        matching: find.text(strings.membershipServerConfigErrorTitle),
      ),
      findsNothing,
    );
  });

  testWidgets('active membership card renders copy from summary display', (
    tester,
  ) async {
    const strings = LingStrings('zh-CN');
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
          'title': '后端会员状态',
          'subtitle': '后端说明文字',
        },
      },
    );
    final container = ProviderContainer(
      overrides: [
        membershipControllerProvider.overrideWith(
          () => _FakeMembershipController(
            catalog: const <MembershipCatalogProduct>[],
            summary: summary,
          ),
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const Scaffold(
            body: LingMembershipSubscriptionPanel(strings: strings),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('后端会员状态'), findsOneWidget);
    expect(find.text('后端说明文字'), findsOneWidget);
    expect(find.text(strings.membershipAlreadyActiveAction), findsNothing);
  });

  testWidgets('subscription page opens on a compact viewport', (tester) async {
    const strings = LingStrings('zh-CN');
    final product = MembershipCatalogProduct(
      internalProductCode: 'pro_month_recurring',
      tierCode: 'pro',
      periodCode: 'month',
      renewalType: 'recurring',
      durationMonths: 1,
      displayName: 'Pro 连续包月',
      displaySubtitle: '全部功能 + 不限对话',
      marketingLabel: null,
      dailyChatLimit: null,
      entitlements: const <String>['member_core', 'member_advanced'],
      metadata: _defaultSubscriptionSheetMetadata,
      channels: const <MembershipCatalogChannel>[
        MembershipCatalogChannel(
          provider: 'apple',
          platform: 'ios',
          providerProductId: 'ling.pro_month_recurring',
          currencyCode: 'CNY',
          amountMinor: 29800,
          marketingLabel: null,
          metadata: <String, dynamic>{},
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        membershipControllerProvider.overrideWith(
          () => _FakeMembershipController(catalog: [product]),
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    });

    await tester.binding.setSurfaceSize(const Size(390, 620));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    showLingMembershipSubscriptionPage(
                      context: context,
                      strings: strings,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(strings.membershipTitle), findsOneWidget);
    expect(find.byKey(const Key('membership_purchase_button')), findsOneWidget);
    expect(
      find.byKey(const Key('membership_privacy_policy_link')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('membership_terms_of_use_link')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('membership_purchase_button'))).dy,
      greaterThanOrEqualTo(0),
    );
    expect(
      tester
          .getBottomRight(find.byKey(const Key('membership_terms_of_use_link')))
          .dy,
      lessThanOrEqualTo(620),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('subscription page fits the viewport', (tester) async {
    const strings = LingStrings('zh-CN');
    final product = MembershipCatalogProduct(
      internalProductCode: 'pro_month_recurring',
      tierCode: 'pro',
      periodCode: 'month',
      renewalType: 'recurring',
      durationMonths: 1,
      displayName: 'Pro 连续包月',
      displaySubtitle: '全部功能 + 不限对话',
      marketingLabel: null,
      dailyChatLimit: null,
      entitlements: const <String>['member_core', 'member_advanced'],
      metadata: _defaultSubscriptionSheetMetadata,
      channels: const <MembershipCatalogChannel>[
        MembershipCatalogChannel(
          provider: 'apple',
          platform: 'ios',
          providerProductId: 'ling.pro_month_recurring',
          currencyCode: 'CNY',
          amountMinor: 29800,
          marketingLabel: null,
          metadata: <String, dynamic>{},
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        membershipControllerProvider.overrideWith(
          () => _FakeMembershipController(catalog: [product]),
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    });

    await tester.binding.setSurfaceSize(const Size(430, 839));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    showLingMembershipSubscriptionPage(
                      context: context,
                      strings: strings,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(strings.membershipTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeMembershipController extends MembershipController {
  _FakeMembershipController({required this.catalog, this.summary});

  final List<MembershipCatalogProduct> catalog;
  final MembershipSummary? summary;
  int restoreCallCount = 0;

  @override
  MembershipState build() => MembershipState(
    catalog: catalog,
    summary: summary,
    hasLoadedCatalog: true,
  );

  @override
  Future<List<MembershipCatalogProduct>> ensureCatalogLoaded({
    bool forceRefresh = false,
  }) async {
    state = state.copyWith(catalog: catalog, isLoadingCatalog: false);
    return catalog;
  }

  @override
  Future<MembershipSummary?> refreshSummary({bool forceRefresh = false}) async {
    state = state.copyWith(summary: summary, isLoadingSummary: false);
    return summary;
  }

  @override
  Future<MembershipActionResult> restoreApplePurchases() async {
    restoreCallCount += 1;
    return MembershipActionResult(status: MembershipActionStatus.idle);
  }
}

class _LoadingMembershipController extends MembershipController {
  @override
  MembershipState build() => const MembershipState();

  @override
  Future<List<MembershipCatalogProduct>> ensureCatalogLoaded({
    bool forceRefresh = false,
  }) async {
    state = state.copyWith(isLoadingCatalog: true);
    return const <MembershipCatalogProduct>[];
  }

  @override
  Future<MembershipSummary?> refreshSummary({bool forceRefresh = false}) async {
    return null;
  }
}
