import 'package:ling/src/features/auth/data/bridges/apple_sign_in_bridge.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';

String appleSignInFailureMessage(
  AppleSignInResult result,
  LingStrings strings,
) {
  final nativeMessage = result.message.trim();
  if (_isAppleAccountRequiredError(nativeMessage)) {
    return strings.appleSignInAccountRequired;
  }
  return nativeMessage.isNotEmpty ? nativeMessage : strings.appleSignInFailed;
}

bool _isAppleAccountRequiredError(String message) {
  final normalized = message.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  return normalized.contains(
        'com.apple.authenticationservices.authorizationerror',
      ) &&
      normalized.contains('1000');
}
