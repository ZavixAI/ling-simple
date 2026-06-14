import 'package:flutter/services.dart';

import 'package:ling/src/core/platform/app_platform.dart';

abstract interface class AppRuntimeBridge {
  Future<bool> isRunningOnSimulator();
}

class MethodChannelAppRuntimeBridge implements AppRuntimeBridge {
  const MethodChannelAppRuntimeBridge();

  static const MethodChannel _channel = MethodChannel('ling/app_runtime');

  bool get _isSupported => isNativeLingBridgeSupported();

  @override
  Future<bool> isRunningOnSimulator() async {
    if (!_isSupported) {
      return false;
    }
    final value = await _channel.invokeMethod<bool>('isSimulator');
    return value == true;
  }
}
