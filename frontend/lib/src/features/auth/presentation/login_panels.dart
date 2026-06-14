import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ling/src/features/auth/presentation/login_visual_palettes.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/phone_country.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/phone_country_code_picker_sheet.dart';
import 'package:ling/src/shared/presentation/tap_haptics.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

final List<TextInputFormatter> _emailIdentityInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9@._%+\-]')),
];

class LingCalendarEmailLoginPanel extends StatelessWidget {
  const LingCalendarEmailLoginPanel({
    super.key,
    required this.isZh,
    required this.title,
    required this.emailController,
    required this.codeController,
    required this.codeFocusNode,
    required this.emailPlaceholder,
    required this.verificationCodeLabel,
    required this.sendCodeLabel,
    required this.resendCodeLabel,
    required this.signingInLabel,
    required this.loginActionLabel,
    required this.emailCodeRequested,
    required this.isSendingCode,
    required this.isVerifyingCode,
    required this.isAgreementAccepted,
    required this.strings,
    this.backToMethodsLabel,
    required this.onSendCode,
    required this.onVerifyCode,
    required this.onAgreementChanged,
    required this.onOpenPrivacyAgreement,
    required this.onOpenSecurityAgreement,
    this.selectedPhoneCountry,
    this.onPhoneCountryChanged,
    this.isPhoneLogin = false,
    this.onBackToMethods,
  });

  final bool isZh;
  final String title;
  final TextEditingController emailController;
  final TextEditingController codeController;
  final FocusNode codeFocusNode;
  final String emailPlaceholder;
  final String verificationCodeLabel;
  final String sendCodeLabel;
  final String resendCodeLabel;
  final String signingInLabel;
  final String loginActionLabel;
  final bool emailCodeRequested;
  final bool isSendingCode;
  final bool isVerifyingCode;
  final bool isAgreementAccepted;
  final LingStrings strings;
  final String? backToMethodsLabel;
  final VoidCallback onSendCode;
  final VoidCallback onVerifyCode;
  final ValueChanged<bool> onAgreementChanged;
  final VoidCallback onOpenPrivacyAgreement;
  final VoidCallback onOpenSecurityAgreement;
  final PhoneCountry? selectedPhoneCountry;
  final ValueChanged<PhoneCountry>? onPhoneCountryChanged;
  final bool isPhoneLogin;
  final VoidCallback? onBackToMethods;

  @override
  Widget build(BuildContext context) {
    final colors = resolveLoginPanelPalette(context);
    final trimmedTitle = title.trim();
    return Column(
      key: const Key('email_login_form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (trimmedTitle.isNotEmpty) ...[
          Text(
            trimmedTitle,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: colors.heading,
            ),
          ),
          const SizedBox(height: 32),
        ],
        _LoginIdentityField(
          controller: emailController,
          hint: emailPlaceholder,
          keyboardType: isPhoneLogin
              ? TextInputType.number
              : TextInputType.emailAddress,
          inputFormatters: isPhoneLogin
              ? [FilteringTextInputFormatter.digitsOnly]
              : _emailIdentityInputFormatters,
          selectedPhoneCountry: selectedPhoneCountry,
          onPhoneCountryChanged: onPhoneCountryChanged,
          colors: colors,
        ),
        const SizedBox(height: 28),
        _EmailVerificationBlock(
          isZh: isZh,
          codeController: codeController,
          codeFocusNode: codeFocusNode,
          verificationCodeLabel: verificationCodeLabel,
          sendCodeLabel: sendCodeLabel,
          resendCodeLabel: resendCodeLabel,
          signingInLabel: signingInLabel,
          loginActionLabel: loginActionLabel,
          emailCodeRequested: emailCodeRequested,
          isSendingCode: isSendingCode,
          isVerifyingCode: isVerifyingCode,
          onSendCode: onSendCode,
          onVerifyCode: onVerifyCode,
          colors: colors,
        ),
        if (backToMethodsLabel != null && onBackToMethods != null) ...[
          const SizedBox(height: 20),
          LingGlassButton(
            key: const Key('back_to_login_methods_button'),
            onPressed: onBackToMethods,
            minHeight: 40,
            radius: 999,
            tone: LingGlassSurfaceTone.muted,
            foregroundColor: colors.secondaryText,
            child: Text(
              backToMethodsLabel!,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }
}

class LingCalendarLoginMethodPanel extends StatelessWidget {
  const LingCalendarLoginMethodPanel({
    super.key,
    required this.prepared,
    required this.canStartOneClick,
    required this.showAppleSignIn,
    required this.showWeChatSignIn,
    required this.isSigningIn,
    required this.isAppleSigningIn,
    required this.isWeChatSigningIn,
    required this.isAuthBusy,
    required this.oneClickLabel,
    required this.appleLabel,
    required this.wechatLabel,
    required this.emailLabel,
    required this.preparingLabel,
    required this.authingLabel,
    required this.appleAuthingLabel,
    required this.wechatAuthingLabel,
    required this.statusMessage,
    required this.isAgreementAccepted,
    required this.strings,
    required this.onStartOneClick,
    required this.onStartAppleSignIn,
    required this.onStartWeChatSignIn,
    required this.onAgreementChanged,
    required this.onAgreementRequired,
    required this.onSelectPhoneLogin,
    required this.onSelectEmailLogin,
    required this.onOpenPrivacyAgreement,
    required this.onOpenSecurityAgreement,
  });

  final bool prepared;
  final bool canStartOneClick;
  final bool showAppleSignIn;
  final bool showWeChatSignIn;
  final bool isSigningIn;
  final bool isAppleSigningIn;
  final bool isWeChatSigningIn;
  final bool isAuthBusy;
  final String oneClickLabel;
  final String appleLabel;
  final String wechatLabel;
  final String emailLabel;
  final String preparingLabel;
  final String authingLabel;
  final String appleAuthingLabel;
  final String wechatAuthingLabel;
  final String statusMessage;
  final bool isAgreementAccepted;
  final LingStrings strings;
  final VoidCallback onStartOneClick;
  final VoidCallback onStartAppleSignIn;
  final VoidCallback onStartWeChatSignIn;
  final ValueChanged<bool> onAgreementChanged;
  final VoidCallback onAgreementRequired;
  final VoidCallback onSelectPhoneLogin;
  final VoidCallback onSelectEmailLogin;
  final VoidCallback onOpenPrivacyAgreement;
  final VoidCallback onOpenSecurityAgreement;

  @override
  Widget build(BuildContext context) {
    final colors = resolveLoginPanelPalette(context);
    final oneClickButtonText = isSigningIn
        ? authingLabel
        : statusMessage.isNotEmpty
        ? statusMessage
        : prepared
        ? oneClickLabel
        : preparingLabel;

    return Column(
      key: const Key('login_method_choice_panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DemoLoginButton.primary(
          key: const Key('one_click_phone_button'),
          text: oneClickButtonText,
          onTap: prepared && canStartOneClick && !isAuthBusy
              ? isAgreementAccepted
                    ? onStartOneClick
                    : onAgreementRequired
              : null,
          colors: colors,
        ),
        const SizedBox(height: 26),
        _OtherLoginMethodsDivider(text: strings.otherSignInMethodsTitle),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            _OtherLoginMethodButton(
              key: const Key('phone_sign_in_button'),
              semanticLabel: strings.otherPhoneLogin,
              icon: const Icon(Icons.phone_iphone_rounded, size: 20),
              onTap: isAuthBusy ? null : onSelectPhoneLogin,
            ),
            _OtherLoginMethodButton(
              key: const Key('login_method_email_button'),
              semanticLabel: emailLabel,
              icon: const Icon(Icons.mail_outline_rounded, size: 20),
              onTap: isAuthBusy ? null : onSelectEmailLogin,
            ),
            if (showAppleSignIn)
              _OtherLoginMethodButton(
                key: const Key('apple_sign_in_button'),
                semanticLabel: appleLabel,
                icon: const Text(
                  '',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                isLoading: isAppleSigningIn,
                onTap: isAuthBusy ? null : onStartAppleSignIn,
              ),
            if (showWeChatSignIn)
              _OtherLoginMethodButton(
                key: const Key('wechat_sign_in_button'),
                semanticLabel: wechatLabel,
                icon: const FaIcon(FontAwesomeIcons.weixin, size: 20),
                foregroundColor: colors.disabledIcon,
                onTap: null,
              ),
          ],
        ),
      ],
    );
  }
}

class _OtherLoginMethodsDivider extends StatelessWidget {
  const _OtherLoginMethodsDivider({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = resolveLoginPanelPalette(context);
    return Row(
      key: const Key('other_login_methods_divider'),
      children: [
        const Expanded(child: _DashedDividerTrack()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            text,
            style: TextStyle(
              color: colors.tertiaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const Expanded(child: _DashedDividerTrack()),
      ],
    );
  }
}

class _DashedDividerTrack extends StatelessWidget {
  const _DashedDividerTrack();

  @override
  Widget build(BuildContext context) {
    final colors = resolveLoginPanelPalette(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = ((constraints.maxWidth / 10).floor()).clamp(2, 200);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashCount,
            (_) => Container(
              width: 6,
              height: 1.4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OtherLoginMethodButton extends StatelessWidget {
  const _OtherLoginMethodButton({
    super.key,
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
    this.foregroundColor,
    this.isLoading = false,
  });

  final String semanticLabel;
  final Widget icon;
  final VoidCallback? onTap;
  final Color? foregroundColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = resolveLoginPanelPalette(context);
    final resolvedForeground = foregroundColor ?? colors.iconButton;
    final effectiveOnTap = isLoading ? null : onTap;
    final isEnabled = effectiveOnTap != null;

    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: isEnabled,
      child: LingLongPressScale(
        enabled: isEnabled,
        scale: 0.94,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: LingTapHaptics.wrap(effectiveOnTap),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: isEnabled || isLoading ? 1 : 0.58,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: isLoading
                    ? GlassProgressIndicator.circular(
                        size: 16,
                        strokeWidth: 2.2,
                        color: resolvedForeground,
                      )
                    : IconTheme(
                        data: IconThemeData(color: resolvedForeground),
                        child: icon,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailVerificationBlock extends StatelessWidget {
  const _EmailVerificationBlock({
    required this.isZh,
    required this.codeController,
    required this.codeFocusNode,
    required this.verificationCodeLabel,
    required this.sendCodeLabel,
    required this.resendCodeLabel,
    required this.signingInLabel,
    required this.loginActionLabel,
    required this.emailCodeRequested,
    required this.isSendingCode,
    required this.isVerifyingCode,
    required this.onSendCode,
    required this.onVerifyCode,
    required this.colors,
  });

  final bool isZh;
  final TextEditingController codeController;
  final FocusNode codeFocusNode;
  final String verificationCodeLabel;
  final String sendCodeLabel;
  final String resendCodeLabel;
  final String signingInLabel;
  final String loginActionLabel;
  final bool emailCodeRequested;
  final bool isSendingCode;
  final bool isVerifyingCode;
  final VoidCallback onSendCode;
  final VoidCallback onVerifyCode;
  final LoginPanelPalette colors;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: codeController,
      builder: (context, value, _) {
        final canVerify =
            emailCodeRequested &&
            value.text.trim().length == 6 &&
            !isVerifyingCode;
        final sendButton = LingGlassButton(
          onPressed: isSendingCode ? null : onSendCode,
          expand: false,
          width: 96,
          minHeight: 32,
          radius: 10,
          tone: LingGlassSurfaceTone.muted,
          foregroundColor: isSendingCode
              ? colors.actionDisabledText
              : colors.actionText,
          child: Text(
            emailCodeRequested ? resendCodeLabel : sendCodeLabel,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    isZh
                        ? verificationCodeLabel
                        : verificationCodeLabel.toUpperCase(),
                    style: TextStyle(
                      color: colors.tertiaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                sendButton,
              ],
            ),
            const SizedBox(height: 16),
            _LingVerificationCodeField(
              controller: codeController,
              focusNode: codeFocusNode,
              colors: colors,
            ),
            const SizedBox(height: 28),
            _DemoLoginButton.primary(
              key: const Key('email_login_submit_button'),
              containerKey: const Key('email_login_submit_button_container'),
              text: isVerifyingCode ? signingInLabel : loginActionLabel,
              onTap: canVerify ? onVerifyCode : null,
              colors: colors,
            ),
          ],
        );
      },
    );
  }
}

class _LoginIdentityField extends StatelessWidget {
  const _LoginIdentityField({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    required this.colors,
    this.inputFormatters,
    this.selectedPhoneCountry,
    this.onPhoneCountryChanged,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final LoginPanelPalette colors;
  final List<TextInputFormatter>? inputFormatters;
  final PhoneCountry? selectedPhoneCountry;
  final ValueChanged<PhoneCountry>? onPhoneCountryChanged;

  @override
  Widget build(BuildContext context) {
    if (selectedPhoneCountry != null) {
      return Row(
        key: const Key('login_identity_field_container'),
        children: [
          SizedBox(
            width: 116,
            child: LingGlassPicker(
              key: const Key('login_phone_country_dropdown'),
              value: selectedPhoneCountry!.label,
              onTap: () async {
                final country = await showPhoneCountryCodePickerSheet(
                  context: context,
                  selected: selectedPhoneCountry!,
                );
                if (country != null && context.mounted) {
                  onPhoneCountryChanged?.call(country);
                }
              },
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _buildTextField()),
        ],
      );
    }

    return _buildTextField();
  }

  Widget _buildTextField() {
    return LingGlassTextField(
      key: const Key('login_identity_field_container'),
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      placeholder: hint,
      textStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.inputText,
      ),
      placeholderStyle: TextStyle(
        color: colors.inputHint,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      radius: 16,
    );
  }
}

class _LingVerificationCodeField extends StatelessWidget {
  const _LingVerificationCodeField({
    required this.controller,
    required this.focusNode,
    required this.colors,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final LoginPanelPalette colors;
  static const int _length = 6;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const slotGap = 8.0;
        final availableWidth = constraints.maxWidth;
        final slotWidth =
            ((availableWidth - ((_length - 1) * slotGap)) / _length).clamp(
              32.0,
              42.0,
            );

        return SizedBox(
          height: 54,
          child: Stack(
            children: [
              Opacity(
                opacity: 0,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_length),
                  ],
                  maxLength: _length,
                  decoration: const InputDecoration(counterText: ''),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => focusNode.requestFocus(),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([controller, focusNode]),
                    builder: (context, _) {
                      final text = controller.text;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_length, (index) {
                          final isFilled = text.length > index;
                          final isCurrent = text.length == index;
                          final borderColor = isCurrent
                              ? colors.codeCurrentBorder
                              : isFilled
                              ? colors.codeFilledBackground.withValues(
                                  alpha: 0.72,
                                )
                              : colors.codeEmptyBorder;
                          return Padding(
                            padding: EdgeInsets.only(
                              right: index == _length - 1 ? 0 : slotGap,
                            ),
                            child: DecoratedBox(
                              key: Key('login_code_slot_border_$index'),
                              position: DecorationPosition.foreground,
                              decoration: ShapeDecoration(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: borderColor,
                                    width: isCurrent ? 1.3 : 1,
                                  ),
                                ),
                              ),
                              child: LingGlassSurface(
                                key: Key('login_code_slot_$index'),
                                width: slotWidth,
                                height: 48,
                                radius: 12,
                                tintColor: isCurrent
                                    ? colors.codeCurrentBackground
                                    : isFilled
                                    ? colors.codeFilledBackground
                                    : colors.codeEmptyBackground,
                                alignment: Alignment.center,
                                child: Text(
                                  isFilled ? text[index] : '',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: isFilled
                                        ? colors.codeFilledText
                                        : colors.codeEmptyText,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DemoLoginButton extends StatelessWidget {
  const _DemoLoginButton.primary({
    super.key,
    required this.text,
    required this.onTap,
    required this.colors,
    this.containerKey,
  });

  final String text;
  final VoidCallback? onTap;
  final LoginPanelPalette colors;
  final Key? containerKey;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: containerKey,
      child: LingGlassButton(
        onPressed: onTap,
        minHeight: 56,
        radius: 16,
        foregroundColor: onTap == null
            ? colors.primaryButtonDisabledForeground
            : colors.primaryButtonForeground,
        tintColor: colors.primaryButtonBackground,
        disabledTintColor: colors.primaryButtonDisabledBackground,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class LingLoginAgreementFooter extends StatelessWidget {
  const LingLoginAgreementFooter({
    super.key,
    required this.strings,
    required this.isAgreed,
    required this.onChanged,
    required this.onOpenPrivacyAgreement,
    required this.onOpenSecurityAgreement,
  });

  final LingStrings strings;
  final bool isAgreed;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenPrivacyAgreement;
  final VoidCallback onOpenSecurityAgreement;

  @override
  Widget build(BuildContext context) {
    final colors = resolveLoginPanelPalette(context);
    final linkStyle = TextStyle(
      color: colors.linkText,
      fontWeight: FontWeight.w800,
    );

    return GestureDetector(
      key: const Key('login_agreement_footer'),
      behavior: HitTestBehavior.opaque,
      onTap: LingTapHaptics.wrap(() => onChanged(!isAgreed)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LingGlassSurface(
            key: const Key('login_agreement_checkbox'),
            width: 18,
            height: 18,
            radius: 5,
            tintColor: isAgreed
                ? colors.agreementCheckedFill
                : colors.agreementUncheckedBorder.withValues(alpha: 0.18),
            child: isAgreed
                ? Center(
                    child: Icon(
                      Icons.check,
                      size: 12,
                      color: colors.primaryButtonForeground,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: RichText(
              key: const Key('login_agreement_text'),
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: colors.agreementText,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(text: strings.agreementReadAndAcceptPrefix),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      key: const Key('login_privacy_agreement_link'),
                      behavior: HitTestBehavior.translucent,
                      onTap: LingTapHaptics.wrap(onOpenPrivacyAgreement),
                      child: Text(
                        '《${strings.privacyAgreementTitle}》',
                        style: linkStyle,
                      ),
                    ),
                  ),
                  TextSpan(text: strings.agreementConnector),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      key: const Key('login_security_agreement_link'),
                      behavior: HitTestBehavior.translucent,
                      onTap: LingTapHaptics.wrap(onOpenSecurityAgreement),
                      child: Text(
                        '《${strings.securityAgreementTitle}》',
                        style: linkStyle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
