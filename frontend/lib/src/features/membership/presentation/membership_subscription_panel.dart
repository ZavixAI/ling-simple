import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/membership/application/membership_controller.dart';
import 'package:ling/src/features/membership/models/membership_models.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/brand_palettes.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/notice.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

const _lingMembershipPrivacyUrl = 'https://withling.top/privacy/';
const _lingMembershipStandardEulaUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

Future<void> showLingMembershipSubscriptionPage({
  required BuildContext context,
  required LingStrings strings,
}) async {
  await Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (routeContext, animation, secondaryAnimation) =>
          _LingMembershipSubscriptionPage(strings: strings),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
          child: child,
        );
      },
    ),
  );
}

class _LingMembershipSubscriptionPage extends StatelessWidget {
  const _LingMembershipSubscriptionPage({required this.strings});

  final LingStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mediaQuery = MediaQuery.of(context);
    return Material(
      color: palette.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.membershipTitle,
                      key: const Key('membership_subscription_page_title'),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  LingGlassIconButton(
                    key: const Key('membership_subscription_page_close'),
                    semanticLabel: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icons.close_rounded,
                    size: 44,
                    iconSize: 20,
                    tone: LingGlassSurfaceTone.control,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: LingMembershipSubscriptionPanel(
                  strings: strings,
                  showLegalLinks: false,
                  onPurchaseCompleted: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                20 + mediaQuery.padding.bottom,
              ),
              child: _MembershipLegalLinks(strings: strings),
            ),
          ],
        ),
      ),
    );
  }
}

class LingMembershipSubscriptionPanel extends ConsumerStatefulWidget {
  const LingMembershipSubscriptionPanel({
    super.key,
    required this.strings,
    this.fallbackSummary,
    this.onPurchaseCompleted,
    this.showLegalLinks = true,
  });

  final LingStrings strings;
  final MembershipSummary? fallbackSummary;
  final VoidCallback? onPurchaseCompleted;
  final bool showLegalLinks;

  @override
  ConsumerState<LingMembershipSubscriptionPanel> createState() =>
      _LingMembershipSubscriptionPanelState();
}

class _LingMembershipSubscriptionPanelState
    extends ConsumerState<LingMembershipSubscriptionPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref
            .read(membershipControllerProvider.notifier)
            .ensureCatalogLoaded(forceRefresh: true),
      );
      unawaited(
        ref
            .read(membershipControllerProvider.notifier)
            .refreshSummary(forceRefresh: true),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final state = ref.watch(membershipControllerProvider);
    final summary = state.summary ?? widget.fallbackSummary;
    final isAlreadyMember = summary?.isMember == true;
    final product = _firstProProduct(state.catalog);
    final proPriceLabel = _planPriceLabel(strings, product);
    final isBusy = state.isLoadingCatalog || state.isPurchasing;
    final isWaitingForInitialCatalog =
        product == null && !state.hasLoadedCatalog && state.catalog.isEmpty;
    final palette = context.palette;
    final membershipForeground = LingMembershipBrandPalette.activeForeground;

    if (isWaitingForInitialCatalog) {
      return const _MembershipCatalogLoadingState();
    }

    final content = <Widget>[
      _TierComparisonSection(
        strings: strings,
        product: product,
        proPriceLabel: proPriceLabel,
      ),
      const SizedBox(height: 28),
      if (isAlreadyMember)
        _buildActiveMembershipCard(
          context: context,
          strings: strings,
          palette: palette,
          summary: summary,
        )
      else
        LingAdaptiveFilledButton(
          key: const Key('membership_purchase_button'),
          onPressed: isBusy || product == null
              ? null
              : () => unawaited(_handlePurchase(product)),
          minHeight: 56,
          foregroundColor: membershipForeground,
          child: isBusy
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: GlassProgressIndicator.circular(
                    size: 24,
                    color: membershipForeground,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  _purchaseLabel(strings, product),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.center,
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 4,
          children: [
            TextButton(
              key: const Key('membership_restore_purchases_button'),
              style: _membershipTextLinkStyle(palette),
              onPressed: state.isRestoring || state.isPurchasing
                  ? null
                  : () => unawaited(_handleRestorePurchases()),
              child: state.isRestoring
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: GlassProgressIndicator.circular(
                        size: 18,
                        color: palette.textSecondary,
                        strokeWidth: 2.2,
                      ),
                    )
                  : Text(strings.membershipRestorePurchases),
            ),
            Text(
              '/',
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
            TextButton(
              key: const Key('membership_manage_subscription_button'),
              style: _membershipTextLinkStyle(palette),
              onPressed: state.isPurchasing
                  ? null
                  : () => unawaited(_handleOpenSubscriptionManagement()),
              child: Text(strings.membershipManageSubscription),
            ),
          ],
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...content,
        if (widget.showLegalLinks) ...[
          const SizedBox(height: 24),
          _MembershipLegalLinks(strings: strings),
        ],
      ],
    );
  }

  Widget _buildActiveMembershipCard({
    required BuildContext context,
    required LingStrings strings,
    required LingPalette palette,
    required MembershipSummary? summary,
  }) {
    final isDark = context.isDarkMode;
    final foreground = isDark
        ? LingMembershipBrandPalette.activeForeground
        : LingMembershipBrandPalette.activeForegroundLight;
    final secondaryForeground = isDark
        ? foreground.withValues(alpha: 0.88)
        : LingMembershipBrandPalette.activeForegroundMutedLight;
    final iconBackground = isDark
        ? LingMembershipBrandPalette.activeStateIconBackgroundDark
        : LingMembershipBrandPalette.activeStateIconBackgroundLight;
    final iconBorder = isDark
        ? LingMembershipBrandPalette.activeStateIconBorderDark
        : LingMembershipBrandPalette.activeStateIconBorderLight;

    final display = _activeMembershipDisplay(strings, summary);

    return Container(
      key: const Key('membership_active_card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? LingMembershipBrandPalette.activeStateGradientDark
              : LingMembershipBrandPalette.activeStateGradientLight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? LingMembershipBrandPalette.activeStateBorderDark
              : LingMembershipBrandPalette.activeStateBorderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? LingMembershipBrandPalette.activeStateShadowDark
                : LingMembershipBrandPalette.activeStateShadowLight,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
              border: Border.all(color: iconBorder),
            ),
            child: Icon(Icons.verified_rounded, size: 22, color: foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display.title,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  display.subtitle,
                  style: TextStyle(
                    color: secondaryForeground,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePurchase(MembershipCatalogProduct product) async {
    try {
      final result = await ref
          .read(membershipControllerProvider.notifier)
          .purchaseAppleProduct(product);
      if (!mounted) {
        return;
      }
      switch (result.status) {
        case MembershipActionStatus.success:
          showLingTopNotice(context, widget.strings.membershipPurchaseSuccess);
          widget.onPurchaseCompleted?.call();
          return;
        case MembershipActionStatus.pending:
          showLingTopNotice(
            context,
            result.message.isEmpty
                ? widget.strings.membershipPurchasePending
                : result.message,
          );
          return;
        case MembershipActionStatus.unsupported:
          showLingTopNotice(
            context,
            result.message.isEmpty
                ? widget.strings.membershipUnsupportedPlatform
                : result.message,
          );
          return;
        case MembershipActionStatus.cancelled:
        case MembershipActionStatus.idle:
          return;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      showLingTopNotice(
        context,
        _membershipErrorMessage(widget.strings, error),
      );
    }
  }

  Future<void> _handleRestorePurchases() async {
    try {
      final result = await ref
          .read(membershipControllerProvider.notifier)
          .restoreApplePurchases();
      if (!mounted) {
        return;
      }
      switch (result.status) {
        case MembershipActionStatus.success:
          showLingTopNotice(context, widget.strings.membershipRestoreSuccess);
          widget.onPurchaseCompleted?.call();
          return;
        case MembershipActionStatus.unsupported:
          showLingTopNotice(
            context,
            result.message.isEmpty
                ? widget.strings.membershipUnsupportedPlatform
                : result.message,
          );
          return;
        case MembershipActionStatus.idle:
          showLingTopNotice(
            context,
            widget.strings.membershipNoRestorablePurchases,
          );
          return;
        case MembershipActionStatus.pending:
          showLingTopNotice(
            context,
            result.message.isEmpty
                ? widget.strings.membershipPurchasePending
                : result.message,
          );
          return;
        case MembershipActionStatus.cancelled:
          showLingTopNotice(
            context,
            result.message.isEmpty
                ? widget.strings.membershipNoRestorablePurchases
                : result.message,
          );
          return;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      showLingTopNotice(
        context,
        _membershipErrorMessage(widget.strings, error),
      );
    }
  }

  Future<void> _handleOpenSubscriptionManagement() async {
    if (AppPlatformInfo.current != AppPlatform.ios) {
      showLingTopNotice(context, widget.strings.membershipUnsupportedPlatform);
      return;
    }
    try {
      await ref
          .read(membershipControllerProvider.notifier)
          .openAppleSubscriptionManagement();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showLingTopNotice(context, '$error');
    }
  }
}

class _MembershipLegalLinks extends StatelessWidget {
  const _MembershipLegalLinks({required this.strings});

  final LingStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final linkStyle = _membershipTextLinkStyle(palette);
    return Align(
      alignment: Alignment.center,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          TextButton(
            key: const Key('membership_privacy_policy_link'),
            style: linkStyle,
            onPressed: () => _openMembershipLegalUrl(_lingMembershipPrivacyUrl),
            child: Text(strings.membershipPrivacyPolicyLink),
          ),
          Text(
            '/',
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
          TextButton(
            key: const Key('membership_terms_of_use_link'),
            style: linkStyle,
            onPressed: () =>
                _openMembershipLegalUrl(_lingMembershipStandardEulaUrl),
            child: Text(strings.membershipTermsOfUseLink),
          ),
        ],
      ),
    );
  }
}

ButtonStyle _membershipTextLinkStyle(LingPalette palette) {
  return TextButton.styleFrom(
    backgroundColor: Colors.transparent,
    disabledBackgroundColor: Colors.transparent,
    foregroundColor: palette.accent,
    disabledForegroundColor: palette.textSecondary,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    side: BorderSide.none,
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    ),
  );
}

Future<void> _openMembershipLegalUrl(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

class _MembershipCatalogLoadingState extends StatelessWidget {
  const _MembershipCatalogLoadingState();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LingGlassSurface(
      key: const Key('membership_catalog_loading_state'),
      width: double.infinity,
      height: 240,
      radius: 24,
      tone: LingGlassSurfaceTone.muted,
      tintColor: palette.surfaceMuted.withValues(alpha: 0.45),
      child: Center(
        child: GlassProgressIndicator.circular(
          size: 28,
          color: palette.textSecondary,
          strokeWidth: 2.6,
        ),
      ),
    );
  }
}

const _appleSubscriptionLinkedErrorCode =
    'apple_subscription_linked_to_another_account';

String _membershipErrorMessage(LingStrings strings, Object error) {
  if (error is! ApiException) {
    return '$error';
  }
  final cause = error.cause;
  if (cause is Map) {
    final data = cause['data'];
    if (data is Map) {
      final errorCode = '${data['error_code'] ?? ''}'.trim();
      if (errorCode == _appleSubscriptionLinkedErrorCode) {
        return strings.membershipLinkedToAnotherAccount;
      }
    }
  }
  return error.message;
}

class _TierComparisonSection extends StatelessWidget {
  const _TierComparisonSection({
    required this.strings,
    required this.product,
    required this.proPriceLabel,
  });

  final LingStrings strings;
  final MembershipCatalogProduct? product;
  final String proPriceLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cards = _tierComparisonCards(
      strings: strings,
      product: product,
      proPriceLabel: proPriceLabel,
    );
    final freeCard = cards[0];
    final proCard = cards[1];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TierColumn(
              key: const Key('membership_free_tier_card'),
              tierLabel: freeCard.title,
              priceLabel: freeCard.priceLabel,
              features: freeCard.features,
              isHighlighted: false,
              palette: palette,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TierColumn(
              key: const Key('membership_pro_tier_card'),
              tierLabel: proCard.title,
              priceLabel: proCard.priceLabel,
              features: proCard.features,
              isHighlighted: true,
              palette: palette,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCardDisplay {
  const _TierCardDisplay({
    required this.title,
    required this.priceLabel,
    required this.features,
  });

  final String title;
  final String priceLabel;
  final List<String> features;
}

class _ActiveMembershipDisplay {
  const _ActiveMembershipDisplay({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class _TierColumn extends StatelessWidget {
  const _TierColumn({
    super.key,
    required this.tierLabel,
    required this.priceLabel,
    required this.features,
    required this.isHighlighted,
    required this.palette,
  });

  final String tierLabel;
  final String priceLabel;
  final List<String> features;
  final bool isHighlighted;
  final LingPalette palette;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final cardGradient = isHighlighted
        ? (isDark
              ? LingMembershipBrandPalette.proCardGradientDark
              : LingMembershipBrandPalette.proCardGradientLight)
        : (isDark
              ? LingMembershipBrandPalette.freeCardGradientDark
              : LingMembershipBrandPalette.freeCardGradientLight);
    final cardBorder = isHighlighted
        ? (isDark
              ? LingMembershipBrandPalette.proCardBorderDark
              : LingMembershipBrandPalette.proCardBorderLight)
        : (isDark
              ? LingMembershipBrandPalette.freeCardBorderDark
              : LingMembershipBrandPalette.freeCardBorderLight);
    final cardShadow = isHighlighted
        ? (isDark
              ? LingMembershipBrandPalette.proCardShadowDark
              : LingMembershipBrandPalette.proCardShadowLight)
        : (isDark
              ? LingMembershipBrandPalette.freeCardShadowDark
              : LingMembershipBrandPalette.freeCardShadowLight);
    final membershipForeground = LingMembershipBrandPalette.activeForeground;
    final membershipAccent = context.isDarkMode
        ? LingMembershipBrandPalette.inactiveAccentDark
        : LingMembershipBrandPalette.inactiveAccentLight;
    final textColor = isHighlighted
        ? (isDark
              ? membershipForeground
              : LingMembershipBrandPalette.activeForegroundLight)
        : palette.textPrimary;
    final subTextColor = isHighlighted
        ? (isDark
              ? membershipForeground.withValues(alpha: 0.78)
              : LingMembershipBrandPalette.activeForegroundMutedLight)
        : palette.textSecondary;
    final checkBg = isHighlighted
        ? (isDark
              ? LingMembershipBrandPalette.proCardCheckBackgroundDark
              : LingMembershipBrandPalette.proCardCheckBackgroundLight)
        : (isDark
              ? LingMembershipBrandPalette.freeCardCheckBackgroundDark
              : LingMembershipBrandPalette.freeCardCheckBackgroundLight);
    final checkIconColor = isHighlighted
        ? (isDark
              ? membershipForeground
              : LingMembershipBrandPalette.activeIconLight)
        : membershipAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cardGradient,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
            blurRadius: isHighlighted ? 24 : 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tierLabel,
            style: TextStyle(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            priceLabel,
            style: TextStyle(
              color: subTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < features.length; i++) ...[
            if (i != 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LingGlassSurface(
                  margin: const EdgeInsets.only(top: 2),
                  width: 18,
                  height: 18,
                  radius: 999,
                  tone: isHighlighted
                      ? LingGlassSurfaceTone.accent
                      : LingGlassSurfaceTone.muted,
                  tintColor: checkBg,
                  child: Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: checkIconColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    features[i],
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

MembershipCatalogChannel? _preferredChannel(MembershipCatalogProduct? product) {
  if (product == null) {
    return null;
  }
  if (AppPlatformInfo.current == AppPlatform.ios) {
    return product.firstChannelForProvider('apple');
  }
  return product.channels.isEmpty ? null : product.channels.first;
}

String _formatPrice(int amountMinor) {
  final value = amountMinor / 100;
  if (value == value.truncateToDouble()) {
    return '¥${value.toInt()}';
  }
  return '¥${value.toStringAsFixed(2)}';
}

String _planPriceLabel(LingStrings strings, MembershipCatalogProduct? product) {
  final amountMinor = _preferredChannel(product)?.amountMinor;
  if (amountMinor == null || amountMinor <= 0) {
    return strings.membershipProMonthlyPrice;
  }
  final period = strings.isZh ? '每月' : 'month';
  return '${_formatPrice(amountMinor)}/$period';
}

List<_TierCardDisplay> _tierComparisonCards({
  required LingStrings strings,
  required MembershipCatalogProduct? product,
  required String proPriceLabel,
}) {
  final errorCards = <_TierCardDisplay>[
    _TierCardDisplay(
      title: strings.membershipServerConfigErrorTitle,
      priceLabel: '',
      features: [strings.membershipServerConfigErrorMessage],
    ),
    _TierCardDisplay(
      title: strings.membershipServerConfigErrorTitle,
      priceLabel: '',
      features: [strings.membershipServerConfigErrorMessage],
    ),
  ];
  if (product == null) {
    return errorCards;
  }
  final fallback = <_TierCardDisplay>[
    _TierCardDisplay(
      title: 'Free',
      priceLabel: strings.isZh ? '免费' : 'Free',
      features: [
        strings.membershipFreeFeatureSchedule,
        strings.membershipFreeFeatureIdea,
        strings.membershipFreeFeatureLimitedChat,
      ],
    ),
    _TierCardDisplay(
      title: 'Pro',
      priceLabel: proPriceLabel,
      features: [
        strings.membershipProFeatureUnlimitedChat,
        strings.membershipProFeatureImageInput,
        strings.membershipProFeatureAllTools,
        strings.membershipProFeaturePriority,
      ],
    ),
  ];
  final sheet = _asStringKeyMap(product.metadata['subscription_sheet']);
  final rawCards = sheet?['tier_cards'];
  if (rawCards is! List) {
    return errorCards;
  }
  final byTier = <String, _TierCardDisplay>{};
  for (final item in rawCards) {
    final raw = _asStringKeyMap(item);
    if (raw == null) {
      continue;
    }
    final tierCode = '${raw['tier_code'] ?? ''}'.trim();
    if (tierCode.isEmpty) {
      continue;
    }
    final fallbackCard = tierCode == 'pro' ? fallback[1] : fallback[0];
    byTier[tierCode] = _TierCardDisplay(
      title: _localizedText(raw, 'title', strings, fallbackCard.title),
      priceLabel: tierCode == 'pro'
          ? _localizedText(raw, 'price_label', strings, proPriceLabel)
          : _localizedText(
              raw,
              'price_label',
              strings,
              fallbackCard.priceLabel,
            ),
      features: _localizedStringList(
        raw,
        'features',
        strings,
        fallbackCard.features,
      ),
    );
  }
  return <_TierCardDisplay>[
    byTier['free'] ?? fallback[0],
    byTier['pro'] ?? fallback[1],
  ];
}

_ActiveMembershipDisplay _activeMembershipDisplay(
  LingStrings strings,
  MembershipSummary? summary,
) {
  final card = _asStringKeyMap(summary?.display['membership_state_card']);
  return _ActiveMembershipDisplay(
    title: _localizedText(
      card,
      'title',
      strings,
      strings.membershipProAccessTitle,
    ),
    subtitle: _localizedText(
      card,
      'subtitle',
      strings,
      strings.membershipProAccessSubtitle,
    ),
  );
}

Map<String, dynamic>? _asStringKeyMap(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

String _localizedText(
  Map<String, dynamic>? source,
  String key,
  LingStrings strings,
  String fallback,
) {
  if (source == null) {
    return fallback;
  }
  final localizedKey = strings.isZh ? '${key}_zh' : '${key}_en';
  final localized = '${source[localizedKey] ?? ''}'.trim();
  if (localized.isNotEmpty) {
    return localized;
  }
  final value = '${source[key] ?? ''}'.trim();
  return value.isEmpty ? fallback : value;
}

List<String> _localizedStringList(
  Map<String, dynamic> source,
  String key,
  LingStrings strings,
  List<String> fallback,
) {
  final localizedKey = strings.isZh ? '${key}_zh' : '${key}_en';
  final raw = source[localizedKey] ?? source[key];
  if (raw is! List) {
    return fallback;
  }
  final values = raw
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  return values.isEmpty ? fallback : values;
}

MembershipCatalogProduct? _firstProProduct(
  List<MembershipCatalogProduct> catalog,
) {
  for (final product in catalog) {
    if (product.tierCode == 'pro') {
      return product;
    }
  }
  return null;
}

String _purchaseLabel(LingStrings strings, MembershipCatalogProduct? product) {
  final channel = _preferredChannel(product);
  final amountMinor = channel?.amountMinor;
  if (product == null || amountMinor == null || amountMinor <= 0) {
    return strings.membershipPurchaseAction;
  }
  final price = _formatPrice(amountMinor);
  final period = strings.isZh ? '连续包月' : 'Monthly';
  return '${strings.membershipStartRecurringAction} $price/$period';
}
