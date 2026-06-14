import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/features/settings/models/account_binding_models.dart';
import 'package:ling/src/features/settings/presentation/settings_account_binding_panel.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';

void main() {
  group('localizeAccountBindingError', () {
    test('maps english already-exists phone errors to zh copy', () {
      final strings = const LingStrings('zh-CN');

      final message = localizeAccountBindingError(
        error: ApiException(
          message: 'phone number already exists',
          statusCode: 409,
        ),
        strings: strings,
        target: AccountBindingTarget.phone,
        action: AccountBindingErrorAction.bind,
      );

      expect(message, strings.phoneAlreadyInUse);
    });

    test('maps english already-bound email errors to en copy', () {
      final strings = const LingStrings('en-US');

      final message = localizeAccountBindingError(
        error: ApiException(
          message: 'email already bound',
          statusCode: 400,
          cause: <String, dynamic>{'error': 'email already bound'},
        ),
        strings: strings,
        target: AccountBindingTarget.email,
        action: AccountBindingErrorAction.bind,
      );

      expect(message, strings.emailAlreadyInUse);
    });

    test('maps invalid verification code errors to localized copy', () {
      final strings = const LingStrings('zh-CN');

      final message = localizeAccountBindingError(
        error: ApiException(
          message: 'verification code is invalid',
          statusCode: 400,
        ),
        strings: strings,
        target: AccountBindingTarget.email,
        action: AccountBindingErrorAction.bind,
      );

      expect(message, strings.bindingVerificationCodeInvalid);
    });

    test('maps rate-limited send code errors to localized copy', () {
      final strings = const LingStrings('en-US');

      final message = localizeAccountBindingError(
        error: ApiException(message: 'too many requests', statusCode: 429),
        strings: strings,
        target: AccountBindingTarget.email,
        action: AccountBindingErrorAction.sendCode,
      );

      expect(message, strings.bindingRequestTooFrequent);
    });

    test('falls back to target-specific generic binding failure', () {
      final strings = const LingStrings('en-US');

      final message = localizeAccountBindingError(
        error: ApiException(message: 'internal server error', statusCode: 500),
        strings: strings,
        target: AccountBindingTarget.wechat,
        action: AccountBindingErrorAction.bind,
      );

      expect(message, strings.wechatIdentityBindingFailed);
    });
  });
}
