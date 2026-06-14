import 'package:flutter/material.dart';
import 'package:ling/src/features/auth/application/auth_login_controller.dart';
import 'package:ling/src/features/auth/application/auth_login_models.dart';
import 'package:ling/src/features/auth/presentation/login_panels.dart';
import 'package:ling/src/features/auth/presentation/login_surface.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/phone_country.dart';

class LingCalendarLoginSection extends StatelessWidget {
  const LingCalendarLoginSection({
    super.key,
    required this.loginMethod,
    required this.supportsOneClickPhoneLogin,
    required this.supportsAppleSignIn,
    required this.supportsWeChatSignIn,
    required this.isAuthBusy,
    required this.emailController,
    required this.phoneController,
    required this.codeController,
    required this.codeFocusNode,
    required this.emailCodeRequested,
    required this.phoneCodeRequested,
    required this.isSendingCode,
    required this.isVerifyingCode,
    required this.aliyunNumberAuthPrepared,
    required this.aliyunNumberAuthCapability,
    required this.isOneClickSigningIn,
    required this.isAppleSigningIn,
    required this.isWeChatSigningIn,
    required this.isAgreementAccepted,
    required this.onSendCode,
    required this.onVerifyCode,
    required this.onStartOneClick,
    required this.onStartAppleSignIn,
    required this.onStartWeChatSignIn,
    required this.onAgreementChanged,
    required this.onAgreementRequired,
    required this.onSelectPhoneLogin,
    required this.onSelectEmailLogin,
    required this.onBackToLoginMethods,
    required this.onOpenPrivacyAgreement,
    required this.onOpenSecurityAgreement,
    required this.aliyunNumberAuthStatusMessage,
    required this.selectedPhoneCountry,
    required this.onPhoneCountryChanged,
    required this.strings,
  });

  final AuthLoginMethod loginMethod;
  final bool supportsOneClickPhoneLogin;
  final bool supportsAppleSignIn;
  final bool supportsWeChatSignIn;
  final bool isAuthBusy;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController codeController;
  final FocusNode codeFocusNode;
  final bool emailCodeRequested;
  final bool phoneCodeRequested;
  final bool isSendingCode;
  final bool isVerifyingCode;
  final bool aliyunNumberAuthPrepared;
  final AuthAliyunNumberAuthCapability aliyunNumberAuthCapability;
  final bool isOneClickSigningIn;
  final bool isAppleSigningIn;
  final bool isWeChatSigningIn;
  final bool isAgreementAccepted;
  final VoidCallback onSendCode;
  final VoidCallback onVerifyCode;
  final VoidCallback onStartOneClick;
  final VoidCallback onStartAppleSignIn;
  final VoidCallback onStartWeChatSignIn;
  final ValueChanged<bool> onAgreementChanged;
  final VoidCallback onAgreementRequired;
  final VoidCallback onSelectPhoneLogin;
  final VoidCallback onSelectEmailLogin;
  final VoidCallback onBackToLoginMethods;
  final VoidCallback onOpenPrivacyAgreement;
  final VoidCallback onOpenSecurityAgreement;
  final String Function(AuthAliyunNumberAuthCapability capability)
  aliyunNumberAuthStatusMessage;
  final PhoneCountry selectedPhoneCountry;
  final ValueChanged<PhoneCountry> onPhoneCountryChanged;
  final LingStrings strings;

  @override
  Widget build(BuildContext context) {
    final canStartOneClick =
        supportsOneClickPhoneLogin &&
        aliyunNumberAuthPrepared &&
        aliyunNumberAuthCapability.canStartLogin;
    final oneClickStatusMessage = supportsOneClickPhoneLogin
        ? aliyunNumberAuthPrepared && !aliyunNumberAuthCapability.canStartLogin
              ? aliyunNumberAuthStatusMessage(aliyunNumberAuthCapability)
              : ''
        : strings.oneClickPhoneUnavailable;
    final isChoosingLoginMethod = loginMethod == AuthLoginMethod.choice;
    final isPhoneLogin = loginMethod == AuthLoginMethod.phone;

    return LingCalendarLoginSurface(
      compactVerticalSpacing: !isChoosingLoginMethod,
      hero: LingCalendarLoginHero(
        isZh: strings.isZh,
        title: strings.loginHeroTitle,
        welcomeLead: strings.loginWelcomeLead,
        welcomeBrand: strings.loginWelcomeBrand,
        tagline: strings.loginRhythmTagline,
        showBubbles: isChoosingLoginMethod,
      ),
      bottomFooter: LingLoginAgreementFooter(
        strings: strings,
        isAgreed: isAgreementAccepted,
        onChanged: onAgreementChanged,
        onOpenPrivacyAgreement: onOpenPrivacyAgreement,
        onOpenSecurityAgreement: onOpenSecurityAgreement,
      ),
      currentPanel: isChoosingLoginMethod
          ? LingCalendarLoginMethodPanel(
              prepared: aliyunNumberAuthPrepared,
              canStartOneClick: canStartOneClick,
              isSigningIn: isOneClickSigningIn,
              showAppleSignIn: supportsAppleSignIn,
              showWeChatSignIn: supportsWeChatSignIn,
              isAppleSigningIn: isAppleSigningIn,
              isWeChatSigningIn: isWeChatSigningIn,
              isAuthBusy: isAuthBusy,
              oneClickLabel: strings.oneClickLoginAction,
              appleLabel: strings.appleSignInAction,
              wechatLabel: strings.wechatSignInAction,
              emailLabel: strings.emailLoginAction,
              preparingLabel: strings.oneClickPhonePreparing,
              authingLabel: strings.oneClickPhoneAuthing,
              appleAuthingLabel: strings.appleSignInAuthing,
              wechatAuthingLabel: strings.wechatSignInAuthing,
              statusMessage: oneClickStatusMessage,
              isAgreementAccepted: isAgreementAccepted,
              strings: strings,
              onStartOneClick: onStartOneClick,
              onStartAppleSignIn: onStartAppleSignIn,
              onStartWeChatSignIn: onStartWeChatSignIn,
              onAgreementChanged: onAgreementChanged,
              onAgreementRequired: onAgreementRequired,
              onSelectPhoneLogin: onSelectPhoneLogin,
              onSelectEmailLogin: onSelectEmailLogin,
              onOpenPrivacyAgreement: onOpenPrivacyAgreement,
              onOpenSecurityAgreement: onOpenSecurityAgreement,
            )
          : LingCalendarEmailLoginPanel(
              isZh: strings.isZh,
              title: '',
              emailController: isPhoneLogin ? phoneController : emailController,
              codeController: codeController,
              codeFocusNode: codeFocusNode,
              emailPlaceholder: isPhoneLogin
                  ? strings.phonePlaceholder
                  : strings.emailPlaceholder,
              verificationCodeLabel: strings.verificationCode,
              sendCodeLabel: isPhoneLogin
                  ? strings.sendPhoneVerificationCode
                  : strings.sendEmailVerificationCode,
              resendCodeLabel: strings.resendCode,
              signingInLabel: strings.signingIn,
              loginActionLabel: strings.loginAction,
              emailCodeRequested: isPhoneLogin
                  ? phoneCodeRequested
                  : emailCodeRequested,
              isSendingCode: isSendingCode,
              isVerifyingCode: isVerifyingCode,
              isAgreementAccepted: isAgreementAccepted,
              strings: strings,
              selectedPhoneCountry: isPhoneLogin ? selectedPhoneCountry : null,
              onPhoneCountryChanged: isPhoneLogin
                  ? onPhoneCountryChanged
                  : null,
              isPhoneLogin: isPhoneLogin,
              backToMethodsLabel: strings.backToLoginMethods,
              onSendCode: onSendCode,
              onVerifyCode: onVerifyCode,
              onAgreementChanged: onAgreementChanged,
              onOpenPrivacyAgreement: onOpenPrivacyAgreement,
              onOpenSecurityAgreement: onOpenSecurityAgreement,
              onBackToMethods: onBackToLoginMethods,
            ),
    );
  }
}
