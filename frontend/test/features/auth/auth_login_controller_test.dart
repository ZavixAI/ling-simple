import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/features/auth/application/auth_controller.dart';
import 'package:ling/src/features/auth/application/auth_login_controller.dart';
import 'package:ling/src/features/auth/application/auth_state.dart';
import 'package:ling/src/features/auth/data/bridges/aliyun_number_auth_bridge.dart';
import 'package:ling/src/features/auth/data/bridges/apple_sign_in_bridge.dart';
import 'package:ling/src/features/auth/data/bridges/wechat_login_bridge.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';

void main() {
  test('defaults to login method choice entry', () {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        aliyunNumberAuthBridgeProvider.overrideWithValue(
          const _FakeAliyunNumberAuthBridge(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(authLoginControllerProvider).method,
      AuthLoginMethod.choice,
    );
  });

  test(
    'sendLoginCode updates email challenge state and delegates request',
    () async {
      final authController = _FakeAuthController();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => authController),
          aliyunNumberAuthBridgeProvider.overrideWithValue(
            const _FakeAliyunNumberAuthBridge(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authLoginControllerProvider.notifier)
          .sendLoginCode('user@example.com');

      final state = container.read(authLoginControllerProvider);
      expect(state.emailCodeRequested, isTrue);
      expect(state.isSendingCode, isFalse);
      expect(authController.lastRequestedEmail, 'user@example.com');
    },
  );

  test('sendSmsLoginCode stores challenge id and delegates request', () async {
    final authController = _FakeAuthController();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => authController),
        aliyunNumberAuthBridgeProvider.overrideWithValue(
          const _FakeAliyunNumberAuthBridge(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authLoginControllerProvider.notifier);
    notifier.selectLoginMethod(AuthLoginMethod.phone);
    await notifier.sendSmsLoginCode(phone: '13800138000', phoneAreaCode: '+86');

    final state = container.read(authLoginControllerProvider);
    expect(state.phoneCodeRequested, isTrue);
    expect(state.smsChallengeId, 'sms-challenge-1');
    expect(state.isSendingCode, isFalse);
    expect(authController.lastRequestedPhone, '13800138000');
    expect(authController.lastRequestedPhoneAreaCode, '+86');
  });

  test('verifySmsLoginCode delegates challenge exchange', () async {
    final authController = _FakeAuthController();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => authController),
        aliyunNumberAuthBridgeProvider.overrideWithValue(
          const _FakeAliyunNumberAuthBridge(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authLoginControllerProvider.notifier);
    notifier.selectLoginMethod(AuthLoginMethod.phone);
    await notifier.sendSmsLoginCode(phone: '13800138000', phoneAreaCode: '+86');
    await notifier.verifySmsLoginCode(
      phone: '13800138000',
      phoneAreaCode: '+86',
      code: '123456',
    );

    expect(authController.lastSmsChallengeId, 'sms-challenge-1');
    expect(authController.lastSmsCode, '123456');
    expect(
      container.read(authLoginControllerProvider).isVerifyingCode,
      isFalse,
    );
  });

  test(
    'verifySmsLoginCode allows admin whitelist static code without challenge',
    () async {
      final authController = _FakeAuthController();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => authController),
          aliyunNumberAuthBridgeProvider.overrideWithValue(
            const _FakeAliyunNumberAuthBridge(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authLoginControllerProvider.notifier);
      notifier.selectLoginMethod(AuthLoginMethod.phone);
      await notifier.verifySmsLoginCode(
        phone: '19965269038',
        phoneAreaCode: '+86',
        code: '111111',
      );

      expect(authController.lastRequestedPhone, '19965269038');
      expect(authController.lastSmsChallengeId, isEmpty);
      expect(authController.lastSmsCode, '111111');
    },
  );

  test(
    'prepareAliyunNumberAuth stores available capability on success',
    () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          aliyunNumberAuthBridgeProvider.overrideWithValue(
            const _FakeAliyunNumberAuthBridge(
              prepareResult: AliyunNumberAuthCapability(
                availability: AliyunNumberAuthAvailability.available,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authLoginControllerProvider.notifier)
          .prepareAliyunNumberAuth(
            resetRetryCount: true,
            platform: AppPlatform.ios,
          );

      final state = container.read(authLoginControllerProvider);
      expect(state.aliyunNumberAuthPrepared, isTrue);
      expect(state.aliyunNumberAuthCapability.canStartLogin, isTrue);
    },
  );

  test('prepareAliyunNumberAuth defaults to phone when unavailable', () async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        aliyunNumberAuthBridgeProvider.overrideWithValue(
          const _FakeAliyunNumberAuthBridge(
            prepareResult: AliyunNumberAuthCapability(
              availability: AliyunNumberAuthAvailability.unavailable,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authLoginControllerProvider.notifier)
        .prepareAliyunNumberAuth(
          resetRetryCount: true,
          platform: AppPlatform.ios,
        );

    expect(
      container.read(authLoginControllerProvider).method,
      AuthLoginMethod.phone,
    );
  });

  test(
    'prepareAliyunNumberAuth can keep method choice when unavailable',
    () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          aliyunNumberAuthBridgeProvider.overrideWithValue(
            const _FakeAliyunNumberAuthBridge(
              prepareResult: AliyunNumberAuthCapability(
                availability: AliyunNumberAuthAvailability.unavailable,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authLoginControllerProvider.notifier)
          .prepareAliyunNumberAuth(
            resetRetryCount: true,
            platform: AppPlatform.ios,
            autoSelectPhoneWhenUnavailable: false,
          );

      final state = container.read(authLoginControllerProvider);
      expect(state.method, AuthLoginMethod.choice);
      expect(state.aliyunNumberAuthPrepared, isTrue);
      expect(state.aliyunNumberAuthCapability.canStartLogin, isFalse);
    },
  );

  test('aliyunNumberAuthStatusMessage hides SIM availability failures', () {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        aliyunNumberAuthBridgeProvider.overrideWithValue(
          const _FakeAliyunNumberAuthBridge(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authLoginControllerProvider.notifier);
    notifier.state = container
        .read(authLoginControllerProvider)
        .copyWith(
          aliyunNumberAuthCapability: const AliyunNumberAuthCapability(
            availability: AliyunNumberAuthAvailability.unavailable,
            message: '[600007] 无SIM卡',
          ),
        );

    expect(notifier.aliyunNumberAuthStatusMessage(LingStrings('zh-CN')), '');

    notifier.state = container
        .read(authLoginControllerProvider)
        .copyWith(
          aliyunNumberAuthCapability: const AliyunNumberAuthCapability(
            availability: AliyunNumberAuthAvailability.unavailable,
            message: '[600004] 获取运营商配置信息失败',
          ),
        );

    expect(notifier.aliyunNumberAuthStatusMessage(LingStrings('zh-CN')), '');
  });

  test(
    'startAliyunOneClickLogin delegates successful token exchange',
    () async {
      final authController = _FakeAuthController();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => authController),
          aliyunNumberAuthBridgeProvider.overrideWithValue(
            const _FakeAliyunNumberAuthBridge(
              startResult: AliyunNumberAuthResult(
                status: AliyunNumberAuthLoginStatus.success,
                token: 'token-1',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authLoginControllerProvider.notifier)
          .startAliyunOneClickLogin(
            strings: LingStrings('zh-CN'),
            prefersDarkMode: false,
          );

      expect(authController.lastAliyunToken, 'token-1');
      expect(
        container.read(authLoginControllerProvider).isOneClickSigningIn,
        isFalse,
      );
    },
  );

  test(
    'startAliyunOneClickLogin ignores user cancellation and keeps choice entry',
    () async {
      final authController = _FakeAuthController();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => authController),
          aliyunNumberAuthBridgeProvider.overrideWithValue(
            const _FakeAliyunNumberAuthBridge(
              startResult: AliyunNumberAuthResult(
                status: AliyunNumberAuthLoginStatus.cancelled,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authLoginControllerProvider.notifier)
          .startAliyunOneClickLogin(
            strings: LingStrings('zh-CN'),
            prefersDarkMode: false,
          );

      expect(authController.lastAliyunToken, isNull);
      expect(
        container.read(authLoginControllerProvider).method,
        AuthLoginMethod.choice,
      );
      expect(
        container.read(authLoginControllerProvider).isOneClickSigningIn,
        isFalse,
      );
    },
  );

  test('startAppleSignIn delegates successful token exchange', () async {
    final authController = _FakeAuthController();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => authController),
        aliyunNumberAuthBridgeProvider.overrideWithValue(
          const _FakeAliyunNumberAuthBridge(),
        ),
        appleSignInBridgeProvider.overrideWithValue(
          const _FakeAppleSignInBridge(
            result: AppleSignInResult(
              status: AppleSignInStatus.success,
              identityToken: 'apple-token-1',
              authorizationCode: 'apple-code-1',
              fullName: <String, dynamic>{'given_name': 'Ling'},
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authLoginControllerProvider.notifier)
        .startAppleSignIn(strings: LingStrings('zh-CN'));

    expect(authController.lastAppleIdentityToken, 'apple-token-1');
    expect(authController.lastAppleAuthorizationCode, 'apple-code-1');
    expect(authController.lastAppleFullName, const <String, dynamic>{
      'given_name': 'Ling',
    });
    expect(
      container.read(authLoginControllerProvider).isAppleSigningIn,
      isFalse,
    );
  });

  test('startAppleSignIn hides Apple authorization error code 1000', () async {
    final authController = _FakeAuthController();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => authController),
        aliyunNumberAuthBridgeProvider.overrideWithValue(
          const _FakeAliyunNumberAuthBridge(),
        ),
        appleSignInBridgeProvider.overrideWithValue(
          const _FakeAppleSignInBridge(
            result: AppleSignInResult(
              status: AppleSignInStatus.error,
              message:
                  '未能完成操作。（com.apple.AuthenticationServices.AuthorizationError错误1000。）',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(authLoginControllerProvider.notifier)
          .startAppleSignIn(strings: LingStrings('zh-CN')),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          '请先在系统设置登录 Apple 账户后再试。',
        ),
      ),
    );
    expect(authController.lastAppleIdentityToken, isNull);
    expect(
      container.read(authLoginControllerProvider).isAppleSigningIn,
      isFalse,
    );
  });

  test('startWeChatLogin delegates successful auth code exchange', () async {
    final authController = _FakeAuthController();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => authController),
        aliyunNumberAuthBridgeProvider.overrideWithValue(
          const _FakeAliyunNumberAuthBridge(),
        ),
        weChatLoginBridgeProvider.overrideWithValue(
          const _FakeWeChatLoginBridge(
            result: WeChatLoginResult(
              status: WeChatLoginStatus.success,
              authCode: 'wechat-code-1',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authLoginControllerProvider.notifier)
        .startWeChatLogin(strings: LingStrings('zh-CN'));

    expect(authController.lastWeChatAuthCode, 'wechat-code-1');
    expect(
      container.read(authLoginControllerProvider).isWeChatSigningIn,
      isFalse,
    );
  });
}

class _FakeAuthController extends AuthController {
  String? lastRequestedEmail;
  String? lastEmailCode;
  String? lastRequestedPhone;
  String? lastRequestedPhoneAreaCode;
  String? lastSmsChallengeId;
  String? lastSmsCode;
  String? lastAliyunToken;
  String? lastAppleIdentityToken;
  String? lastAppleAuthorizationCode;
  Map<String, dynamic>? lastAppleFullName;
  String? lastWeChatAuthCode;

  @override
  AuthState build() => const AuthStateUnauthenticated();

  @override
  Future<ChallengeResult> requestEmailChallenge(
    String email, {
    String purpose = 'login',
  }) async {
    lastRequestedEmail = email;
    return const ChallengeResult();
  }

  @override
  Future<void> signInWithEmailCode({
    required String email,
    required String code,
  }) async {
    lastRequestedEmail = email;
    lastEmailCode = code;
  }

  @override
  Future<ChallengeResult> requestSmsChallenge(
    String phone, {
    String? phoneAreaCode,
    String purpose = 'login',
  }) async {
    lastRequestedPhone = phone;
    lastRequestedPhoneAreaCode = phoneAreaCode;
    return const ChallengeResult(challengeId: 'sms-challenge-1');
  }

  @override
  Future<void> signInWithSmsCode({
    required String phone,
    String? phoneAreaCode,
    String? challengeId,
    required String code,
  }) async {
    lastRequestedPhone = phone;
    lastRequestedPhoneAreaCode = phoneAreaCode;
    lastSmsChallengeId = challengeId ?? '';
    lastSmsCode = code;
  }

  @override
  Future<void> signInWithAliyunOneClickToken(String token) async {
    lastAliyunToken = token;
  }

  @override
  Future<void> signInWithAppleIdentityToken({
    required String identityToken,
    String? authorizationCode,
    Map<String, dynamic>? fullName,
  }) async {
    lastAppleIdentityToken = identityToken;
    lastAppleAuthorizationCode = authorizationCode;
    lastAppleFullName = fullName;
  }

  @override
  Future<void> signInWithWeChatAuthCode(String authCode) async {
    lastWeChatAuthCode = authCode;
  }
}

class _FakeAliyunNumberAuthBridge implements AliyunNumberAuthBridge {
  const _FakeAliyunNumberAuthBridge({
    this.prepareResult = const AliyunNumberAuthCapability.unsupported(),
    this.startResult = const AliyunNumberAuthResult(
      status: AliyunNumberAuthLoginStatus.cancelled,
    ),
  });

  final AliyunNumberAuthCapability prepareResult;
  final AliyunNumberAuthResult startResult;

  @override
  Future<AliyunNumberAuthCapability> prepareLogin() async {
    return prepareResult;
  }

  @override
  Future<AliyunNumberAuthResult> startLogin({
    required bool prefersDarkMode,
  }) async {
    return startResult;
  }
}

class _FakeAppleSignInBridge implements AppleSignInBridge {
  const _FakeAppleSignInBridge({
    this.result = const AppleSignInResult(status: AppleSignInStatus.cancelled),
  });

  final AppleSignInResult result;

  @override
  Future<AppleSignInResult> signIn() async {
    return result;
  }
}

class _FakeWeChatLoginBridge implements WeChatLoginBridge {
  const _FakeWeChatLoginBridge({
    this.result = const WeChatLoginResult(status: WeChatLoginStatus.cancelled),
  });

  final WeChatLoginResult result;

  @override
  Future<WeChatLoginResult> startLogin() async {
    return result;
  }
}
