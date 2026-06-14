import 'package:flutter/services.dart';

import 'package:ling/src/core/platform/app_platform.dart';

abstract interface class ReviewRequestBridge {
  Future<bool> requestReview();
}

class MethodChannelReviewRequestBridge implements ReviewRequestBridge {
  MethodChannelReviewRequestBridge();

  static const MethodChannel _channel = MethodChannel('ling/review_request');

  bool get _isSupported => AppPlatformInfo.current == AppPlatform.ios;

  @override
  Future<bool> requestReview() async {
    if (!_isSupported) {
      return false;
    }
    final response = await _channel.invokeMethod<bool>('requestReview');
    return response == true;
  }
}
