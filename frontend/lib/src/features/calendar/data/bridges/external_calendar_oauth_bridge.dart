import 'package:flutter/services.dart';

import 'package:ling/src/core/platform/app_platform.dart';

enum ExternalCalendarOAuthStatus { success, cancelled, error, unsupported }

class ExternalCalendarOAuthResult {
  const ExternalCalendarOAuthResult({
    required this.status,
    this.callbackUrl,
    this.message = '',
  });

  final ExternalCalendarOAuthStatus status;
  final String? callbackUrl;
  final String message;

  bool get isSuccess =>
      status == ExternalCalendarOAuthStatus.success &&
      (callbackUrl ?? '').trim().isNotEmpty;

  factory ExternalCalendarOAuthResult.fromJson(Map<Object?, Object?> json) {
    return ExternalCalendarOAuthResult(
      status: _mapStatus('${json['status'] ?? ''}'),
      callbackUrl: json['callbackUrl']?.toString(),
      message: '${json['message'] ?? ''}',
    );
  }

  static ExternalCalendarOAuthStatus _mapStatus(String raw) {
    switch (raw) {
      case 'success':
        return ExternalCalendarOAuthStatus.success;
      case 'cancelled':
        return ExternalCalendarOAuthStatus.cancelled;
      case 'unsupported':
        return ExternalCalendarOAuthStatus.unsupported;
      default:
        return ExternalCalendarOAuthStatus.error;
    }
  }
}

abstract interface class ExternalCalendarOAuthBridge {
  Future<ExternalCalendarOAuthResult> authorize({
    required String authorizeUrl,
    required String callbackScheme,
  });
}

class MethodChannelExternalCalendarOAuthBridge
    implements ExternalCalendarOAuthBridge {
  MethodChannelExternalCalendarOAuthBridge();

  static const MethodChannel _channel = MethodChannel(
    'ling/external_calendar_oauth',
  );

  bool get _isSupported => AppPlatformInfo.current == AppPlatform.ios;

  @override
  Future<ExternalCalendarOAuthResult> authorize({
    required String authorizeUrl,
    required String callbackScheme,
  }) async {
    if (!_isSupported) {
      return const ExternalCalendarOAuthResult(
        status: ExternalCalendarOAuthStatus.unsupported,
      );
    }
    final response = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'authorize',
      <String, dynamic>{
        'authorizeUrl': authorizeUrl,
        'callbackScheme': callbackScheme,
      },
    );
    return ExternalCalendarOAuthResult.fromJson(response ?? const {});
  }
}
