import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/membership/application/membership_gate.dart';
import 'package:ling/src/features/membership/models/membership_models.dart';
import 'package:ling/src/features/membership/presentation/membership_subscription_panel.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/brand_palettes.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

Future<void> showLingMembershipGateSheet({
  required BuildContext context,
  required LingStrings strings,
  required MembershipGateResult gate,
  String? title,
  String? body,
  List<String>? benefits,
}) async {
  final rootContext = context;
  final shouldOpenPlans = await showLingAdaptiveSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) {
      final palette = sheetContext.palette;
      final message = switch (gate.reason) {
        QuotaExhaustedReason.membershipRequired =>
          strings.membershipRequiredMessage,
        QuotaExhaustedReason.dailyLimitReached =>
          strings.membershipQuotaExhaustedMessage,
        QuotaExhaustedReason.unknown => strings.membershipQuotaExhaustedMessage,
      };
      final accent = sheetContext.isDarkMode
          ? LingMembershipBrandPalette.inactiveAccentDark
          : LingMembershipBrandPalette.inactiveAccentLight;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: LingGlassSurface(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                radius: 28,
                tone: LingGlassSurfaceTone.elevated,
                quality: LingGlassQuality.standard,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MembershipUpgradeHero(
                      strings: strings,
                      title:
                          title ??
                          (gate.reason ==
                                  QuotaExhaustedReason.membershipRequired
                              ? strings.membershipUpgradeHeroTitle
                              : strings.membershipQuotaExhaustedTitle),
                      body: body ?? message,
                      benefits: benefits,
                      accent: accent,
                    ),
                    if (gate.summary != null) ...[
                      const SizedBox(height: 14),
                      _MembershipSummaryInline(
                        summary: gate.summary!,
                        strings: strings,
                      ),
                    ],
                    const SizedBox(height: 18),
                    LingAdaptiveFilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      minHeight: 52,
                      child: Text(strings.membershipUpgradeAction),
                    ),
                    const SizedBox(height: 10),
                    LingAdaptiveFilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      minHeight: 48,
                      backgroundColor: palette.glassMutedTint,
                      foregroundColor: palette.textPrimary,
                      child: Text(strings.cancel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  if (shouldOpenPlans != true || !rootContext.mounted) {
    return;
  }
  await showLingMembershipSubscriptionPage(
    context: rootContext,
    strings: strings,
  );
}

class _MembershipUpgradeHero extends StatelessWidget {
  const _MembershipUpgradeHero({
    required this.strings,
    required this.title,
    required this.body,
    this.benefits,
    required this.accent,
  });

  final LingStrings strings;
  final String title;
  final String body;
  final List<String>? benefits;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final benefitLabels =
        benefits ??
        [
          strings.membershipUpgradeBenefitChat,
          strings.membershipUpgradeBenefitImageInput,
          strings.membershipUpgradeBenefitMemory,
        ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LingGlassSurface(
              width: 48,
              height: 48,
              radius: 18,
              tone: LingGlassSurfaceTone.accent,
              tintColor: accent.withValues(alpha: 0.16),
              child: Icon(Icons.workspace_premium_rounded, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 14,
            height: 1.45,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final benefit in benefitLabels)
              _MembershipBenefitPill(text: benefit, accent: accent),
          ],
        ),
      ],
    );
  }
}

class _MembershipBenefitPill extends StatelessWidget {
  const _MembershipBenefitPill({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LingGlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      radius: 999,
      tone: LingGlassSurfaceTone.muted,
      tintColor: accent.withValues(alpha: context.isDarkMode ? 0.14 : 0.10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: accent),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipSummaryInline extends StatelessWidget {
  const _MembershipSummaryInline({
    required this.summary,
    required this.strings,
  });

  final MembershipSummary summary;
  final LingStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final remaining = summary.dailyChatRemaining;
    final quotaText = summary.isUnlimitedDailyChat
        ? strings.membershipUnlimitedDailyChat
        : strings.membershipDailyChatLimit(summary.dailyChatLimit ?? 0);
    return LingGlassSurface(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      radius: 18,
      tone: LingGlassSurfaceTone.muted,
      child: Row(
        children: [
          Expanded(
            child: Text(
              quotaText,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (remaining != null)
            Text(
              '${summary.dailyChatUsed}/${summary.dailyChatLimit}',
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
