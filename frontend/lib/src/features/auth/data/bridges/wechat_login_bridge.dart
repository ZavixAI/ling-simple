import 'package:flutter/services.dart';

import 'package:ling/src/core/platform/app_platform.dart';

enum WeChatLoginStatus { success, cancelled, error, unsupported }

class WeChatLoginResult {
  const WeChatLoginResult({
    required this.status,
    this.authCode,
    this.message = '',
  });

  final WeChatLoginStatus status;
  final String? authCode;
  final String message;

  bool get isSuccess =>
      status == WeChatLoginStatus.success && (authCode ?? '').trim().isNotEmpty;

  factory WeChatLoginResult.fromJson(Map<Object?, Object?> json) {
    return WeChatLoginResult(
      status: _mapStatus('${json['status'] ?? ''}'),
      authCode: json['authCode']?.toString(),
      message: '${json['message'] ?? ''}',
    );
  }

  static WeChatLoginStatus _mapStatus(String raw) {
    switch (raw) {
      case 'success':
        return WeChatLoginStatus.success;
      case 'cancelled':
        return WeChatLoginStatus.cancelled;
      case 'unsupported':
        return WeChatLoginStatus.unsupported;
      default:
        return WeChatLoginStatus.error;
    }
  }
}

abstract interface class WeChatLoginBridge {
  Future<WeChatLoginResult> startLogin();
}

class MethodChannelWeChatLoginBridge implements WeChatLoginBridge {
  MethodChannelWeChatLoginBridge();

  static const MethodChannel _channel = MethodChannel('ling/wechat_login');

  bool get _isSupported => AppPlatformInfo.current == AppPlatform.ios;

  @override
  Future<WeChatLoginResult> startLogin() async {
    if (!_isSupported) {
      return const WeChatLoginResult(status: WeChatLoginStatus.unsupported);
    }
    final response = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'startLogin',
    );
    return WeChatLoginResult.fromJson(response ?? const {});
  }
}
