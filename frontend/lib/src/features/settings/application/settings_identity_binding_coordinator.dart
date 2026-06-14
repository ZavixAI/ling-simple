import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/features/auth/application/apple_sign_in_error_message.dart';
import 'package:ling/src/features/auth/data/bridges/apple_sign_in_bridge.dart';
import 'package:ling/src/features/auth/data/bridges/wechat_login_bridge.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/settings/application/settings_controller.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';

class SettingsIdentityBindingCoordinator {
  const SettingsIdentityBindingCoordinator(this.ref);

  final Ref ref;

  Future<AccountBundle> bindAppleIdentity({
    required LingStrings strings,
  }) async {
    final bridge = ref.read(appleSignInBridgeProvider);
    final result = await bridge.signIn();
    if (result.isSuccess) {
      return ref
          .read(settingsControllerProvider.notifier)
          .bindAppleIdentity(
            identityToken: result.identityToken!,
            authorizationCode: result.authorizationCode,
            fullName: result.fullName,
          );
    }
    if (result.status == AppleSignInStatus.cancelled) {
      throw ApiException(message: strings.appleSignInCancelled);
    }
    if (result.status == AppleSignInStatus.unsupported) {
      throw ApiException(message: strings.appleSignInUnavailable);
    }
    throw ApiException(message: appleSignInFailureMessage(result, strings));
  }

  Future<AccountBundle> bindWeChatIdentity({
    required LingStrings strings,
  }) async {
    final bridge = ref.read(weChatLoginBridgeProvider);
    final result = await bridge.startLogin();
    if (result.isSuccess) {
      return ref
          .read(settingsControllerProvider.notifier)
          .bindWeChatIdentity(authCode: result.authCode!);
    }
    if (result.status == WeChatLoginStatus.cancelled) {
      throw ApiException(message: strings.wechatSignInCancelled);
    }
    if (result.status == WeChatLoginStatus.unsupported) {
      throw ApiException(message: strings.wechatSignInUnavailable);
    }
    throw ApiException(
      message: result.message.trim().isNotEmpty
          ? result.message.trim()
          : strings.wechatSignInFailed,
    );
  }
}

final settingsIdentityBindingCoordinatorProvider =
    Provider<SettingsIdentityBindingCoordinator>(
      SettingsIdentityBindingCoordinator.new,
    );
