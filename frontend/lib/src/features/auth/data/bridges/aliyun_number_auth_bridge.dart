import 'package:flutter/services.dart';

import 'package:ling/src/core/platform/app_platform.dart';

enum AliyunNumberAuthAvailability {
  available,
  unavailable,
  unsupported,
  unconfigured,
}

enum AliyunNumberAuthLoginStatus { success, fallback, cancelled, error }

class AliyunNumberAuthCapability {
  const AliyunNumberAuthCapability({
    required this.availability,
    this.message = '',
    this.sdkVersion = '',
  });

  const AliyunNumberAuthCapability.unsupported()
    : availability = AliyunNumberAuthAvailability.unsupported,
      message = '',
      sdkVersion = '';

  final AliyunNumberAuthAvailability availability;
  final String message;
  final String sdkVersion;

  bool get canStartLogin =>
      availability == AliyunNumberAuthAvailability.available;

  factory AliyunNumberAuthCapability.fromJson(Map<Object?, Object?> json) {
    return AliyunNumberAuthCapability(
      availability: _mapAvailability('${json['status'] ?? ''}'),
      message: '${json['message'] ?? ''}',
      sdkVersion: '${json['sdkVersion'] ?? ''}',
    );
  }

  static AliyunNumberAuthAvailability _mapAvailability(String raw) {
    switch (raw) {
      case 'available':
        return AliyunNumberAuthAvailability.available;
      case 'unavailable':
        return AliyunNumberAuthAvailability.unavailable;
      case 'unconfigured':
        return AliyunNumberAuthAvailability.unconfigured;
      default:
        return AliyunNumberAuthAvailability.unsupported;
    }
  }
}

class AliyunNumberAuthResult {
  const AliyunNumberAuthResult({
    required this.status,
    this.token,
    this.message = '',
  });

  final AliyunNumberAuthLoginStatus status;
  final String? token;
  final String message;

  bool get isSuccess =>
      status == AliyunNumberAuthLoginStatus.success && (token ?? '').isNotEmpty;

  factory AliyunNumberAuthResult.fromJson(Map<Object?, Object?> json) {
    return AliyunNumberAuthResult(
      status: _mapStatus('${json['status'] ?? ''}'),
      token: json['token']?.toString(),
      message: '${json['message'] ?? ''}',
    );
  }

  static AliyunNumberAuthLoginStatus _mapStatus(String raw) {
    switch (raw) {
      case 'success':
        return AliyunNumberAuthLoginStatus.success;
      case 'fallback':
        return AliyunNumberAuthLoginStatus.fallback;
      case 'cancelled':
        return AliyunNumberAuthLoginStatus.cancelled;
      default:
        return AliyunNumberAuthLoginStatus.error;
    }
  }
}

abstract interface class AliyunNumberAuthBridge {
  Future<AliyunNumberAuthCapability> prepareLogin();
  Future<AliyunNumberAuthResult> startLogin({required bool prefersDarkMode});
}

class MethodChannelAliyunNumberAuthBridge implements AliyunNumberAuthBridge {
  MethodChannelAliyunNumberAuthBridge();

  static const MethodChannel _channel = MethodChannel(
    'ling/aliyun_number_auth',
  );

  bool get _isSupported => AppPlatformInfo.current == AppPlatform.ios;

  @override
  Future<AliyunNumberAuthCapability> prepareLogin() async {
    if (!_isSupported) {
      return const AliyunNumberAuthCapability.unsupported();
    }
    final response = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'prepareLogin',
    );
    return AliyunNumberAuthCapability.fromJson(response ?? const {});
  }

  @override
  Future<AliyunNumberAuthResult> startLogin({
    required bool prefersDarkMode,
  }) async {
    if (!_isSupported) {
      return const AliyunNumberAuthResult(
        status: AliyunNumberAuthLoginStatus.error,
      );
    }
    final response = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'startLogin',
      <String, Object?>{'prefersDarkMode': prefersDarkMode},
    );
    return AliyunNumberAuthResult.fromJson(response ?? const {});
  }
}
