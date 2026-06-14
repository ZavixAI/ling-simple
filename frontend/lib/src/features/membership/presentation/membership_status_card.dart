import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/membership/application/membership_gate.dart';
import 'package:ling/src/features/membership/models/membership_models.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/brand_palettes.dart';

class LingMembershipStatusCard extends StatelessWidget {
  const LingMembershipStatusCard({
    super.key,
    required this.summary,
    required this.strings,
    required this.onTap,
  });

  final MembershipSummary? summary;
  final LingStrings strings;
  final VoidCallback onTap;
  static const double _cardRadius = 18;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final currentSummary = summary;
    final isActive = currentSummary?.isMember == true;
    final colors = _MembershipStatusCardColors.resolve(
      isDark: context.isDarkMode,
      isActive: isActive,
      palette: palette,
    );
    final expiryLabel = formatMembershipGmt8Label(
      parseMembershipUtc(currentSummary?.paidThroughAt),
    );
    final stateCard = _membershipStateCardDisplay(strings, currentSummary);
    final fallbackLines = <String>[
      if (isActive && expiryLabel.isNotEmpty)
        strings.membershipExpiresAt(expiryLabel),
      if (currentSummary?.cancelAtPeriodEnd == true)
        strings.membershipCancelAtPeriodEnd,
    ];
    final lines = stateCard.subtitle.isNotEmpty
        ? <String>[stateCard.subtitle]
        : fallbackLines;

    final cardBorderRadius = BorderRadius.circular(_cardRadius);

    return DecoratedBox(
      key: const Key('settings_membership_card'),
      decoration: BoxDecoration(
        borderRadius: cardBorderRadius,
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: cardBorderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: cardBorderRadius,
          child: Ink(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: cardBorderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors.gradient,
              ),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.iconBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.iconBorder),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: colors.icon,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.membershipTitle.toUpperCase(),
                        style: TextStyle(
                          color: colors.secondaryText,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stateCard.title,
                        style: TextStyle(
                          color: colors.primaryText,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (lines.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        for (final line in lines)
                          Text(
                            line,
                            style: TextStyle(
                              color: colors.secondaryText,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.actionBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.chevron,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MembershipStatusCardColors {
  const _MembershipStatusCardColors({
    required this.gradient,
    required this.border,
    required this.shadow,
    required this.primaryText,
    required this.secondaryText,
    required this.icon,
    required this.iconBackground,
    required this.iconBorder,
    required this.actionBackground,
    required this.chevron,
  });

  final List<Color> gradient;
  final Color border;
  final Color shadow;
  final Color primaryText;
  final Color secondaryText;
  final Color icon;
  final Color iconBackground;
  final Color iconBorder;
  final Color actionBackground;
  final Color chevron;

  static _MembershipStatusCardColors resolve({
    required bool isDark,
    required bool isActive,
    required LingPalette palette,
  }) {
    if (isActive) {
      return isDark
          ? _MembershipStatusCardColors(
              gradient: LingMembershipBrandPalette.activeGradientDark,
              border: LingMembershipBrandPalette.activeBorderDark,
              shadow: LingMembershipBrandPalette.activeShadowDark,
              primaryText: LingMembershipBrandPalette.activeForeground,
              secondaryText: LingMembershipBrandPalette.activeForegroundMuted,
              icon: LingMembershipBrandPalette.activeForeground,
              iconBackground:
                  LingMembershipBrandPalette.activeIconBackgroundDark,
              iconBorder: LingMembershipBrandPalette.activeIconBorderDark,
              actionBackground:
                  LingMembershipBrandPalette.activeActionBackgroundDark,
              chevron: LingMembershipBrandPalette.activeForegroundSoft,
            )
          : _MembershipStatusCardColors(
              gradient: LingMembershipBrandPalette.activeGradientLight,
              border: LingMembershipBrandPalette.activeBorderLight,
              shadow: LingMembershipBrandPalette.activeShadowLight,
              primaryText: LingMembershipBrandPalette.activeForegroundLight,
              secondaryText:
                  LingMembershipBrandPalette.activeForegroundMutedLight,
              icon: LingMembershipBrandPalette.activeIconLight,
              iconBackground:
                  LingMembershipBrandPalette.activeIconBackgroundLight,
              iconBorder: LingMembershipBrandPalette.activeIconBorderLight,
              actionBackground:
                  LingMembershipBrandPalette.activeActionBackgroundLight,
              chevron: LingMembershipBrandPalette.activeChevronLight,
            );
    }

    return isDark
        ? _MembershipStatusCardColors(
            gradient: LingMembershipBrandPalette.inactiveGradientDark,
            border: LingMembershipBrandPalette.inactiveBorderDark,
            shadow: LingMembershipBrandPalette.inactiveShadowDark,
            primaryText: palette.textPrimary,
            secondaryText: palette.textSecondary,
            icon: LingMembershipBrandPalette.inactiveAccentDark,
            iconBackground:
                LingMembershipBrandPalette.inactiveIconBackgroundDark,
            iconBorder: LingMembershipBrandPalette.inactiveIconBorderDark,
            actionBackground:
                LingMembershipBrandPalette.inactiveActionBackgroundDark,
            chevron: palette.textSecondary,
          )
        : _MembershipStatusCardColors(
            gradient: LingMembershipBrandPalette.inactiveGradientLight,
            border: palette.outlineSoft,
            shadow: palette.shadow,
            primaryText: palette.textPrimary,
            secondaryText: palette.textSecondary,
            icon: LingMembershipBrandPalette.inactiveAccentLight,
            iconBackground:
                LingMembershipBrandPalette.inactiveIconBackgroundLight,
            iconBorder: LingMembershipBrandPalette.inactiveIconBorderLight,
            actionBackground:
                LingMembershipBrandPalette.inactiveActionBackgroundLight,
            chevron: palette.textSecondary,
          );
  }
}

_MembershipStateCardDisplay _membershipStateCardDisplay(
  LingStrings strings,
  MembershipSummary? summary,
) {
  final display = summary?.display['membership_state_card'];
  if (display is Map) {
    final title = '${display['title'] ?? ''}'.trim();
    final subtitle = '${display['subtitle'] ?? ''}'.trim();
    if (title.isNotEmpty || subtitle.isNotEmpty) {
      return _MembershipStateCardDisplay(
        title: title.isNotEmpty
            ? title
            : _fallbackMembershipStateTitle(strings, summary),
        subtitle: subtitle,
      );
    }
  }
  return _MembershipStateCardDisplay(
    title: _fallbackMembershipStateTitle(strings, summary),
    subtitle: '',
  );
}

String _fallbackMembershipStateTitle(
  LingStrings strings,
  MembershipSummary? summary,
) {
  return summary?.isMember == true
      ? strings.membershipActiveStatus
      : strings.membershipInactiveStatus;
}

class _MembershipStateCardDisplay {
  const _MembershipStateCardDisplay({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}
