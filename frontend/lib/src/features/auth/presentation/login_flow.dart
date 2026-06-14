import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/auth/application/auth_login_controller.dart';
import 'package:ling/src/features/auth/presentation/login_section.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/phone_country.dart';
import 'package:ling/src/shared/presentation/legal_documents.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/notice.dart';

class LingCalendarLoginFlow extends ConsumerStatefulWidget {
  const LingCalendarLoginFlow({super.key, required this.strings});

  final LingStrings strings;

  @override
  ConsumerState<LingCalendarLoginFlow> createState() =>
      _LingCalendarLoginFlowState();
}

class _LingCalendarLoginFlowState extends ConsumerState<LingCalendarLoginFlow>
    with WidgetsBindingObserver {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  PhoneCountry _selectedPhoneCountry = phoneCountries.first;
  bool _isLoginAgreementAccepted = true;
  bool _isVerifyingLoginCode = false;

  LingStrings get s => widget.strings;
  bool get _supportsOneClickPhoneLogin =>
      supportsLingOneClickPhoneLogin(AppPlatformInfo.current);
  bool get _supportsAppleSignIn =>
      supportsLingAppleSignIn(AppPlatformInfo.current);
  bool get _supportsWeChatSignIn =>
      supportsLingWeChatSignIn(AppPlatformInfo.current);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _codeController.addListener(_handleCodeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _trackLogin('auth.login.view', action: 'view');
      final notifier = ref.read(authLoginControllerProvider.notifier);
      if (AppPlatformInfo.current == AppPlatform.ios) {
        unawaited(
          notifier.prepareAliyunNumberAuth(
            resetRetryCount: true,
            platform: AppPlatformInfo.current,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeController.removeListener(_handleCodeChanged);
    _emailController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref
            .read(authLoginControllerProvider.notifier)
            .handleAppResumed(platform: AppPlatformInfo.current),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(authLoginControllerProvider);
    final phoneCodeReady =
        loginState.phoneCodeRequested ||
        (loginState.isPhoneLogin &&
            isAdminWhitelistBypassSmsCode(_codeController.text));
    return LingCalendarLoginSection(
      loginMethod: loginState.method,
      supportsOneClickPhoneLogin: _supportsOneClickPhoneLogin,
      supportsAppleSignIn: _supportsAppleSignIn,
      supportsWeChatSignIn: _supportsWeChatSignIn,
      isAuthBusy: loginState.isAuthBusy,
      emailController: _emailController,
      phoneController: _phoneController,
      codeController: _codeController,
      codeFocusNode: _codeFocusNode,
      emailCodeRequested: loginState.emailCodeRequested,
      phoneCodeRequested: phoneCodeReady,
      isSendingCode: loginState.isSendingCode,
      isVerifyingCode: loginState.isVerifyingCode,
      aliyunNumberAuthPrepared: loginState.aliyunNumberAuthPrepared,
      aliyunNumberAuthCapability: loginState.aliyunNumberAuthCapability,
      isOneClickSigningIn: loginState.isOneClickSigningIn,
      isAppleSigningIn: loginState.isAppleSigningIn,
      isWeChatSigningIn: loginState.isWeChatSigningIn,
      isAgreementAccepted: _isLoginAgreementAccepted,
      onSendCode: () => unawaited(_sendLoginCode()),
      onVerifyCode: () => unawaited(_verifyLoginCode()),
      onStartOneClick: () => unawaited(_startAliyunOneClickLogin()),
      onStartAppleSignIn: () => unawaited(_startAppleSignIn()),
      onStartWeChatSignIn: () => unawaited(_startWeChatLogin()),
      onAgreementChanged: _handleAgreementChanged,
      onAgreementRequired: () =>
          unawaited(_runAfterAgreement(_startAliyunOneClickLogin)),
      onSelectPhoneLogin: () => _setLoginMethod(AuthLoginMethod.phone),
      onSelectEmailLogin: () => _setLoginMethod(AuthLoginMethod.email),
      onBackToLoginMethods: () => _setLoginMethod(AuthLoginMethod.choice),
      onOpenPrivacyAgreement: _showPrivacyAgreement,
      onOpenSecurityAgreement: _showSecurityAgreement,
      selectedPhoneCountry: _selectedPhoneCountry,
      onPhoneCountryChanged: _handlePhoneCountryChanged,
      aliyunNumberAuthStatusMessage: (_) => ref
          .read(authLoginControllerProvider.notifier)
          .aliyunNumberAuthStatusMessage(s),
      strings: s,
    );
  }

  void _showError(Object error) {
    final message = error is ApiException ? error.message : error.toString();
    if (!mounted) {
      return;
    }
    showLingTopNotice(context, message);
  }

  void _setLoginMethod(AuthLoginMethod value) {
    final notifier = ref.read(authLoginControllerProvider.notifier);
    notifier.selectLoginMethod(value);
    _trackLogin(
      'auth.method.select',
      action: 'method_select',
      source: value.name,
    );
    _codeController.clear();
    if (value == AuthLoginMethod.choice && _supportsOneClickPhoneLogin) {
      unawaited(
        notifier.prepareAliyunNumberAuth(
          resetRetryCount: true,
          platform: AppPlatformInfo.current,
          autoSelectPhoneWhenUnavailable: false,
        ),
      );
    }
  }

  void _handlePhoneCountryChanged(PhoneCountry value) {
    setState(() {
      _selectedPhoneCountry = value;
    });
    ref
        .read(authLoginControllerProvider.notifier)
        .selectLoginMethod(AuthLoginMethod.phone);
    ref.read(authLoginControllerProvider.notifier).resetSmsCodeRequested();
    _codeController.clear();
  }

  void _handleAgreementChanged(bool value) {
    setState(() {
      _isLoginAgreementAccepted = value;
    });
    _trackLogin(
      'auth.agreement.change',
      action: 'agreement_change',
      properties: <String, Object?>{'accepted': value},
    );
  }

  void _handleCodeChanged() {
    final loginState = ref.read(authLoginControllerProvider);
    if (loginState.isPhoneLogin && mounted) {
      setState(() {});
    }
    if (_isVerifyingLoginCode ||
        (!loginState.isEmailLogin && !loginState.isPhoneLogin) ||
        (loginState.isEmailLogin && !loginState.emailCodeRequested) ||
        (loginState.isPhoneLogin &&
            !loginState.phoneCodeRequested &&
            !isAdminWhitelistBypassSmsCode(_codeController.text)) ||
        loginState.isVerifyingCode ||
        !isLingEmailCodeComplete(_codeController.text)) {
      return;
    }
    unawaited(_verifyLoginCode());
  }

  void _showPrivacyAgreement() {
    unawaited(
      showLingLegalDocumentDialog(
        context: context,
        strings: s,
        type: LingLegalDocumentType.privacy,
      ),
    );
  }

  void _showSecurityAgreement() {
    unawaited(
      showLingLegalDocumentDialog(
        context: context,
        strings: s,
        type: LingLegalDocumentType.security,
      ),
    );
  }

  Future<void> _sendLoginCode() async {
    final isPhone = ref.read(authLoginControllerProvider).isPhoneLogin;
    try {
      final notifier = ref.read(authLoginControllerProvider.notifier);
      if (isPhone) {
        if (_phoneController.text.trim().isEmpty) {
          _showError(s.phonePlaceholder);
          return;
        }
        await notifier.sendSmsLoginCode(
          phone: _phoneController.text,
          phoneAreaCode: _selectedPhoneCountry.dialCode,
        );
        _trackLogin(
          'auth.code.send_success',
          action: 'code_send_success',
          source: 'phone',
        );
        return;
      }
      await notifier.sendLoginCode(_emailController.text);
      _trackLogin(
        'auth.code.send_success',
        action: 'code_send_success',
        source: 'email',
      );
    } catch (error) {
      _trackLogin(
        'auth.code.send_failure',
        action: 'code_send_failure',
        source: isPhone ? 'phone' : 'email',
        properties: <String, Object?>{
          'error_type': error.runtimeType.toString(),
        },
      );
      _showError(error);
    }
  }

  Future<void> _verifyLoginCode() async {
    if (_isVerifyingLoginCode) {
      return;
    }
    _isVerifyingLoginCode = true;
    try {
      await _runAfterAgreement(() async {
        try {
          final notifier = ref.read(authLoginControllerProvider.notifier);
          if (ref.read(authLoginControllerProvider).isPhoneLogin) {
            await notifier.verifySmsLoginCode(
              phone: _phoneController.text,
              phoneAreaCode: _selectedPhoneCountry.dialCode,
              code: _codeController.text,
            );
            _trackLogin(
              'auth.login.success',
              action: 'login_success',
              source: 'phone_code',
            );
            return;
          }
          await notifier.verifyLoginCode(
            email: _emailController.text,
            code: _codeController.text,
          );
          _trackLogin(
            'auth.login.success',
            action: 'login_success',
            source: 'email_code',
          );
        } catch (error) {
          _codeController.clear();
          _trackLogin(
            'auth.login.failure',
            action: 'login_failure',
            source: ref.read(authLoginControllerProvider).isPhoneLogin
                ? 'phone_code'
                : 'email_code',
            properties: <String, Object?>{
              'error_type': error.runtimeType.toString(),
            },
          );
          _showError(error);
        }
      });
    } finally {
      _isVerifyingLoginCode = false;
    }
  }

  Future<void> _startAliyunOneClickLogin() async {
    await _runAfterAgreement(() async {
      try {
        await ref
            .read(authLoginControllerProvider.notifier)
            .startAliyunOneClickLogin(
              strings: s,
              prefersDarkMode: context.isDarkMode,
            );
        _trackLogin(
          'auth.login.success',
          action: 'login_success',
          source: 'aliyun_one_click',
        );
      } catch (error) {
        _trackLogin(
          'auth.login.failure',
          action: 'login_failure',
          source: 'aliyun_one_click',
          properties: <String, Object?>{
            'error_type': error.runtimeType.toString(),
          },
        );
        _showError(error);
        if (error is ApiException &&
            error.message == s.phoneCodeLoginUnsupported) {
          ref
              .read(authLoginControllerProvider.notifier)
              .usePhoneLoginWhenOneClickUnavailable();
        }
        await ref
            .read(authLoginControllerProvider.notifier)
            .prepareAliyunNumberAuth(platform: AppPlatformInfo.current);
      }
    });
  }

  Future<void> _startAppleSignIn() async {
    await _runAfterAgreement(() async {
      try {
        await ref
            .read(authLoginControllerProvider.notifier)
            .startAppleSignIn(strings: s);
        _trackLogin(
          'auth.login.success',
          action: 'login_success',
          source: 'apple',
        );
      } catch (error) {
        _trackLogin(
          'auth.login.failure',
          action: 'login_failure',
          source: 'apple',
          properties: <String, Object?>{
            'error_type': error.runtimeType.toString(),
          },
        );
        _showError(error);
      }
    });
  }

  Future<void> _startWeChatLogin() async {
    await _runAfterAgreement(() async {
      try {
        await ref
            .read(authLoginControllerProvider.notifier)
            .startWeChatLogin(strings: s);
        _trackLogin(
          'auth.login.success',
          action: 'login_success',
          source: 'wechat',
        );
      } catch (error) {
        _trackLogin(
          'auth.login.failure',
          action: 'login_failure',
          source: 'wechat',
          properties: <String, Object?>{
            'error_type': error.runtimeType.toString(),
          },
        );
        _showError(error);
      }
    });
  }

  void _trackLogin(
    String eventName, {
    required String action,
    String? source,
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    unawaited(
      ref
          .read(analyticsTrackerProvider)
          .track(
            eventName,
            surface: 'auth',
            action: action,
            source: source,
            locale: s.localeCode,
            properties: properties,
          ),
    );
  }

  Future<void> _runAfterAgreement(Future<void> Function() action) async {
    if (!mounted) {
      return;
    }
    if (_isLoginAgreementAccepted) {
      await action();
      return;
    }
    final palette = context.palette;
    final shouldContinue = await showDialog<bool>(
      context: context,
      barrierColor: palette.scrim.withValues(alpha: 0.28),
      builder: (dialogContext) {
        return _AgreementRequiredDialog(strings: s);
      },
    );
    if (shouldContinue != true || !mounted) {
      return;
    }
    _handleAgreementChanged(true);
    await action();
  }
}

class _AgreementRequiredDialog extends StatelessWidget {
  const _AgreementRequiredDialog({required this.strings});

  final LingStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: LingGlassSurface(
              key: const Key('login_agreement_required_dialog'),
              padding: const EdgeInsets.all(28),
              radius: 32,
              tone: LingGlassSurfaceTone.elevated,
              quality: LingGlassQuality.premium,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LingGlassSurface(
                    padding: const EdgeInsets.all(16),
                    radius: 999,
                    tone: LingGlassSurfaceTone.accent,
                    tintColor: palette.accentSoft.withValues(alpha: 0.76),
                    child: Icon(
                      Icons.privacy_tip_rounded,
                      color: palette.accent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    strings.oneClickAgreementRequiredTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings.oneClickAgreementRequiredMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  LingGlassButton(
                    key: const Key('login_agreement_confirm_button'),
                    onPressed: () => Navigator.of(context).pop(true),
                    minHeight: 56,
                    radius: 16,
                    foregroundColor: palette.primaryButtonForeground,
                    tintColor: palette.primaryButtonBackground,
                    child: Text(
                      strings.agreeAndContinueAction,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LingGlassButton(
                    key: const Key('login_agreement_cancel_button'),
                    onPressed: () => Navigator.of(context).pop(false),
                    minHeight: 48,
                    radius: 16,
                    tone: LingGlassSurfaceTone.muted,
                    foregroundColor: palette.textSecondary.withValues(
                      alpha: 0.72,
                    ),
                    child: Text(
                      strings.thinkAgainAction,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
