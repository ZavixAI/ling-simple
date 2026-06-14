import 'package:flutter/services.dart';

import 'package:ling/src/core/platform/app_platform.dart';

enum AppleSignInStatus { success, cancelled, error, unsupported }

class AppleSignInResult {
  const AppleSignInResult({
    required this.status,
    this.identityToken,
    this.authorizationCode,
    this.fullName,
    this.message = '',
  });

  final AppleSignInStatus status;
  final String? identityToken;
  final String? authorizationCode;
  final Map<String, dynamic>? fullName;
  final String message;

  bool get isSuccess =>
      status == AppleSignInStatus.success &&
      (identityToken ?? '').trim().isNotEmpty;

  factory AppleSignInResult.fromJson(Map<Object?, Object?> json) {
    final rawFullName = json['fullName'];
    return AppleSignInResult(
      status: _mapStatus('${json['status'] ?? ''}'),
      identityToken: json['identityToken']?.toString(),
      authorizationCode: json['authorizationCode']?.toString(),
      fullName: rawFullName is Map
          ? Map<String, dynamic>.from(rawFullName)
          : null,
      message: '${json['message'] ?? ''}',
    );
  }

  static AppleSignInStatus _mapStatus(String raw) {
    switch (raw) {
      case 'success':
        return AppleSignInStatus.success;
      case 'cancelled':
        return AppleSignInStatus.cancelled;
      case 'unsupported':
        return AppleSignInStatus.unsupported;
      default:
        return AppleSignInStatus.error;
    }
  }
}

abstract interface class AppleSignInBridge {
  Future<AppleSignInResult> signIn();
}

class MethodChannelAppleSignInBridge implements AppleSignInBridge {
  MethodChannelAppleSignInBridge();

  static const MethodChannel _channel = MethodChannel('ling/apple_sign_in');

  bool get _isSupported => AppPlatformInfo.current == AppPlatform.ios;

  @override
  Future<AppleSignInResult> signIn() async {
    if (!_isSupported) {
      return const AppleSignInResult(status: AppleSignInStatus.unsupported);
    }
    final response = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'signIn',
    );
    return AppleSignInResult.fromJson(response ?? const {});
  }
}
