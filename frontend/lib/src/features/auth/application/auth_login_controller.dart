import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/config/feature_flags.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/features/auth/application/apple_sign_in_error_message.dart';
import 'package:ling/src/features/auth/application/auth_controller.dart';
import 'package:ling/src/features/auth/data/bridges/aliyun_number_auth_bridge.dart';
import 'package:ling/src/features/auth/data/bridges/apple_sign_in_bridge.dart';
import 'package:ling/src/features/auth/data/bridges/wechat_login_bridge.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';

bool supportsLingOneClickPhoneLogin(AppPlatform platform) {
  return platform == AppPlatform.ios;
}

bool supportsLingAppleSignIn(AppPlatform platform) {
  return platform == AppPlatform.ios;
}

bool supportsLingWeChatSignIn(AppPlatform platform) {
  return LingFeatureFlags.weChatAuth && platform == AppPlatform.ios;
}

bool isLingEmailCodeComplete(String code) {
  return code.trim().length == 6;
}

const String adminWhitelistBypassSmsCode = '111111';

bool isAdminWhitelistBypassSmsCode(String code) {
  return code.trim() == adminWhitelistBypassSmsCode;
}

bool isRetryableAliyunNumberAuthError(Object error) {
  if (error is MissingPluginException) {
    return true;
  }
  if (error is PlatformException && error.code == 'channel-error') {
    return true;
  }
  final message = '$error';
  return message.contains('MissingPluginException') ||
      message.contains('channel-error');
}

bool shouldHideAliyunNumberAuthStatusMessage(String message) {
  final normalized = message.toLowerCase().replaceAll(' ', '');
  return normalized.contains('600007') ||
      normalized.contains('无sim卡') ||
      normalized.contains('未检测到sim卡') ||
      normalized.contains('nosim') ||
      normalized.contains('600004') ||
      normalized.contains('获取运营商配置信息失败');
}

Duration computeLingAliyunPrepareRetryDelay(int prepareAttempts) {
  final retryMultiplier = prepareAttempts > 1 ? prepareAttempts : 1;
  return Duration(milliseconds: 250 * retryMultiplier);
}

enum AuthLoginMethod { choice, phone, email, apple, wechat }

class AuthLoginState {
  const AuthLoginState({
    this.method = AuthLoginMethod.choice,
    this.isSendingCode = false,
    this.isVerifyingCode = false,
    this.isOneClickSigningIn = false,
    this.isAppleSigningIn = false,
    this.isWeChatSigningIn = false,
    this.isPreparingAliyunNumberAuth = false,
    this.aliyunNumberAuthPrepared = false,
    this.emailCodeRequested = false,
    this.smsChallengeId = '',
    this.aliyunNumberAuthCapability =
        const AliyunNumberAuthCapability.unsupported(),
    this.aliyunNumberAuthPrepareAttempts = 0,
  });

  final AuthLoginMethod method;
  final bool isSendingCode;
  final bool isVerifyingCode;
  final bool isOneClickSigningIn;
  final bool isAppleSigningIn;
  final bool isWeChatSigningIn;
  final bool isPreparingAliyunNumberAuth;
  final bool aliyunNumberAuthPrepared;
  final bool emailCodeRequested;
  final String smsChallengeId;
  final AliyunNumberAuthCapability aliyunNumberAuthCapability;
  final int aliyunNumberAuthPrepareAttempts;

  bool get isEmailLogin => method == AuthLoginMethod.email;
  bool get isPhoneLogin => method == AuthLoginMethod.phone;
  bool get isChoosingLoginMethod => method == AuthLoginMethod.choice;
  bool get phoneCodeRequested => smsChallengeId.isNotEmpty;
  bool get isAuthBusy =>
      isSendingCode ||
      isVerifyingCode ||
      isOneClickSigningIn ||
      isAppleSigningIn ||
      isWeChatSigningIn;

  AuthLoginState copyWith({
    AuthLoginMethod? method,
    bool? isSendingCode,
    bool? isVerifyingCode,
    bool? isOneClickSigningIn,
    bool? isAppleSigningIn,
    bool? isWeChatSigningIn,
    bool? isPreparingAliyunNumberAuth,
    bool? aliyunNumberAuthPrepared,
    bool? emailCodeRequested,
    String? smsChallengeId,
    AliyunNumberAuthCapability? aliyunNumberAuthCapability,
    int? aliyunNumberAuthPrepareAttempts,
  }) {
    return AuthLoginState(
      method: method ?? this.method,
      isSendingCode: isSendingCode ?? this.isSendingCode,
      isVerifyingCode: isVerifyingCode ?? this.isVerifyingCode,
      isOneClickSigningIn: isOneClickSigningIn ?? this.isOneClickSigningIn,
      isAppleSigningIn: isAppleSigningIn ?? this.isAppleSigningIn,
      isWeChatSigningIn: isWeChatSigningIn ?? this.isWeChatSigningIn,
      isPreparingAliyunNumberAuth:
          isPreparingAliyunNumberAuth ?? this.isPreparingAliyunNumberAuth,
      aliyunNumberAuthPrepared:
          aliyunNumberAuthPrepared ?? this.aliyunNumberAuthPrepared,
      emailCodeRequested: emailCodeRequested ?? this.emailCodeRequested,
      smsChallengeId: smsChallengeId ?? this.smsChallengeId,
      aliyunNumberAuthCapability:
          aliyunNumberAuthCapability ?? this.aliyunNumberAuthCapability,
      aliyunNumberAuthPrepareAttempts:
          aliyunNumberAuthPrepareAttempts ??
          this.aliyunNumberAuthPrepareAttempts,
    );
  }
}

class AuthLoginController extends Notifier<AuthLoginState> {
  Timer? _aliyunNumberAuthRetryTimer;

  AliyunNumberAuthBridge get _aliyunNumberAuthBridge =>
      ref.read(aliyunNumberAuthBridgeProvider);
  AppleSignInBridge get _appleSignInBridge =>
      ref.read(appleSignInBridgeProvider);
  WeChatLoginBridge get _weChatLoginBridge =>
      ref.read(weChatLoginBridgeProvider);

  @override
  AuthLoginState build() {
    ref.onDispose(() {
      _aliyunNumberAuthRetryTimer?.cancel();
    });
    return const AuthLoginState();
  }

  void selectLoginMethod(AuthLoginMethod value) {
    if (state.method == value) {
      return;
    }
    state = state.copyWith(
      method: value,
      emailCodeRequested: false,
      smsChallengeId: '',
    );
  }

  void usePhoneLoginWhenOneClickUnavailable() {
    if (!state.isChoosingLoginMethod) {
      return;
    }
    state = state.copyWith(method: AuthLoginMethod.phone);
  }

  Future<void> sendLoginCode(String email) async {
    state = state.copyWith(isSendingCode: true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestEmailChallenge(email);
      state = state.copyWith(emailCodeRequested: true);
    } finally {
      state = state.copyWith(isSendingCode: false);
    }
  }

  Future<void> sendSmsLoginCode({
    required String phone,
    required String phoneAreaCode,
  }) async {
    state = state.copyWith(isSendingCode: true, smsChallengeId: '');
    try {
      final challenge = await ref
          .read(authControllerProvider.notifier)
          .requestSmsChallenge(phone, phoneAreaCode: phoneAreaCode);
      state = state.copyWith(smsChallengeId: challenge.challengeId ?? '');
    } finally {
      state = state.copyWith(isSendingCode: false);
    }
  }

  Future<void> verifyLoginCode({
    required String email,
    required String code,
  }) async {
    if (!state.isEmailLogin || !state.emailCodeRequested) {
      return;
    }
    if (!isLingEmailCodeComplete(code)) {
      return;
    }
    state = state.copyWith(isVerifyingCode: true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signInWithEmailCode(email: email, code: code);
    } finally {
      state = state.copyWith(isVerifyingCode: false);
    }
  }

  Future<void> verifySmsLoginCode({
    required String phone,
    required String phoneAreaCode,
    required String code,
  }) async {
    final usesWhitelistBypass = isAdminWhitelistBypassSmsCode(code);
    if (!state.isPhoneLogin ||
        (!state.phoneCodeRequested && !usesWhitelistBypass)) {
      return;
    }
    if (!isLingEmailCodeComplete(code)) {
      return;
    }
    state = state.copyWith(isVerifyingCode: true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signInWithSmsCode(
            phone: phone,
            phoneAreaCode: phoneAreaCode,
            challengeId: state.smsChallengeId,
            code: code,
          );
    } finally {
      state = state.copyWith(isVerifyingCode: false);
    }
  }

  Future<void> prepareAliyunNumberAuth({
    bool resetRetryCount = false,
    required AppPlatform platform,
    bool autoSelectPhoneWhenUnavailable = true,
  }) async {
    if (!supportsLingOneClickPhoneLogin(platform) ||
        state.isPreparingAliyunNumberAuth) {
      return;
    }
    if (resetRetryCount) {
      state = state.copyWith(
        aliyunNumberAuthPrepareAttempts: 0,
        aliyunNumberAuthPrepared: false,
      );
    }
    _aliyunNumberAuthRetryTimer?.cancel();
    state = state.copyWith(isPreparingAliyunNumberAuth: true);
    try {
      final capability = await _aliyunNumberAuthBridge.prepareLogin();
      state = state.copyWith(
        isPreparingAliyunNumberAuth: false,
        aliyunNumberAuthCapability: capability,
        aliyunNumberAuthPrepared: true,
        aliyunNumberAuthPrepareAttempts: 0,
      );
      if (!capability.canStartLogin && autoSelectPhoneWhenUnavailable) {
        usePhoneLoginWhenOneClickUnavailable();
      }
    } catch (error) {
      if (isRetryableAliyunNumberAuthError(error) &&
          state.aliyunNumberAuthPrepareAttempts < 3) {
        final nextAttempts = state.aliyunNumberAuthPrepareAttempts + 1;
        state = state.copyWith(
          isPreparingAliyunNumberAuth: false,
          aliyunNumberAuthPrepareAttempts: nextAttempts,
        );
        _scheduleAliyunNumberAuthRetry(
          platform: platform,
          autoSelectPhoneWhenUnavailable: autoSelectPhoneWhenUnavailable,
        );
        return;
      }
      state = state.copyWith(
        isPreparingAliyunNumberAuth: false,
        aliyunNumberAuthPrepared: true,
        aliyunNumberAuthCapability: AliyunNumberAuthCapability(
          availability: AliyunNumberAuthAvailability.unavailable,
          message: '$error',
        ),
      );
      if (autoSelectPhoneWhenUnavailable) {
        usePhoneLoginWhenOneClickUnavailable();
      }
      rethrow;
    }
  }

  Future<void> handleAppResumed({required AppPlatform platform}) async {
    if (platform != AppPlatform.ios ||
        state.aliyunNumberAuthCapability.canStartLogin) {
      return;
    }
    await prepareAliyunNumberAuth(
      resetRetryCount: true,
      platform: platform,
      autoSelectPhoneWhenUnavailable: !state.isChoosingLoginMethod,
    );
  }

  Future<void> startAliyunOneClickLogin({
    required LingStrings strings,
    required bool prefersDarkMode,
  }) async {
    state = state.copyWith(isOneClickSigningIn: true);
    try {
      final nativeResult = await _aliyunNumberAuthBridge.startLogin(
        prefersDarkMode: prefersDarkMode,
      );
      if (nativeResult.isSuccess) {
        await ref
            .read(authControllerProvider.notifier)
            .signInWithAliyunOneClickToken(nativeResult.token!);
        return;
      }
      if (nativeResult.status == AliyunNumberAuthLoginStatus.fallback) {
        throw ApiException(message: strings.phoneCodeLoginUnsupported);
      }
      if (nativeResult.status == AliyunNumberAuthLoginStatus.cancelled) {
        return;
      }
      throw ApiException(
        message: nativeResult.message.trim().isNotEmpty
            ? nativeResult.message.trim()
            : strings.oneClickPhoneAuthFailed,
      );
    } finally {
      state = state.copyWith(isOneClickSigningIn: false);
    }
  }

  Future<void> startAppleSignIn({required LingStrings strings}) async {
    state = state.copyWith(isAppleSigningIn: true);
    try {
      final nativeResult = await _appleSignInBridge.signIn();
      if (nativeResult.isSuccess) {
        await ref
            .read(authControllerProvider.notifier)
            .signInWithAppleIdentityToken(
              identityToken: nativeResult.identityToken!,
              authorizationCode: nativeResult.authorizationCode,
              fullName: nativeResult.fullName,
            );
        return;
      }
      if (nativeResult.status == AppleSignInStatus.cancelled) {
        return;
      }
      if (nativeResult.status == AppleSignInStatus.unsupported) {
        throw ApiException(message: strings.appleSignInUnavailable);
      }
      throw ApiException(
        message: appleSignInFailureMessage(nativeResult, strings),
      );
    } finally {
      state = state.copyWith(isAppleSigningIn: false);
    }
  }

  Future<void> startWeChatLogin({required LingStrings strings}) async {
    state = state.copyWith(isWeChatSigningIn: true);
    try {
      final nativeResult = await _weChatLoginBridge.startLogin();
      if (nativeResult.isSuccess) {
        await ref
            .read(authControllerProvider.notifier)
            .signInWithWeChatAuthCode(nativeResult.authCode!);
        return;
      }
      if (nativeResult.status == WeChatLoginStatus.cancelled) {
        return;
      }
      if (nativeResult.status == WeChatLoginStatus.unsupported) {
        throw ApiException(message: strings.wechatSignInUnavailable);
      }
      throw ApiException(
        message: nativeResult.message.trim().isNotEmpty
            ? nativeResult.message.trim()
            : strings.wechatSignInFailed,
      );
    } finally {
      state = state.copyWith(isWeChatSigningIn: false);
    }
  }

  void resetEmailCodeRequested() {
    if (!state.emailCodeRequested) {
      return;
    }
    state = state.copyWith(emailCodeRequested: false);
  }

  void resetSmsCodeRequested() {
    if (!state.phoneCodeRequested) {
      return;
    }
    state = state.copyWith(smsChallengeId: '');
  }

  String aliyunNumberAuthStatusMessage(LingStrings strings) {
    final capability = state.aliyunNumberAuthCapability;
    switch (capability.availability) {
      case AliyunNumberAuthAvailability.unconfigured:
        final message = capability.message.trim();
        return message.isNotEmpty ? message : strings.oneClickPhoneUnconfigured;
      case AliyunNumberAuthAvailability.unavailable:
        final message = capability.message.trim();
        if (shouldHideAliyunNumberAuthStatusMessage(message)) {
          return '';
        }
        return message.isNotEmpty ? message : strings.oneClickPhoneUnavailable;
      case AliyunNumberAuthAvailability.unsupported:
        return strings.oneClickPhoneUnavailable;
      case AliyunNumberAuthAvailability.available:
        return '';
    }
  }

  void _scheduleAliyunNumberAuthRetry({
    required AppPlatform platform,
    required bool autoSelectPhoneWhenUnavailable,
  }) {
    _aliyunNumberAuthRetryTimer?.cancel();
    final delay = computeLingAliyunPrepareRetryDelay(
      state.aliyunNumberAuthPrepareAttempts,
    );
    _aliyunNumberAuthRetryTimer = Timer(delay, () {
      unawaited(
        prepareAliyunNumberAuth(
          platform: platform,
          autoSelectPhoneWhenUnavailable: autoSelectPhoneWhenUnavailable,
        ),
      );
    });
  }
}

final authLoginControllerProvider =
    NotifierProvider<AuthLoginController, AuthLoginState>(
      AuthLoginController.new,
    );
