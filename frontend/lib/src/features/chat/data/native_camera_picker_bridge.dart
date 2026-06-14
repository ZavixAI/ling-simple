// ignore_for_file: use_null_aware_elements

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ling/src/core/platform/app_platform.dart';

abstract interface class NativeCameraPickerBridge {
  Future<XFile?> pickImage({double? maxWidth, int imageQuality = 88});
}

class MethodChannelNativeCameraPickerBridge
    implements NativeCameraPickerBridge {
  MethodChannelNativeCameraPickerBridge();

  static const MethodChannel _methodChannel = MethodChannel(
    'ling/native_camera_picker',
  );

  bool get _isSupported => AppPlatformInfo.current == AppPlatform.ios;

  @override
  Future<XFile?> pickImage({double? maxWidth, int imageQuality = 88}) async {
    if (!_isSupported) {
      throw PlatformException(
        code: 'unsupported',
        message: 'Native camera picker is only available on iOS.',
      );
    }

    final path = await _methodChannel.invokeMethod<String>('pickImage', {
      if (maxWidth != null) 'maxWidth': maxWidth,
      'imageQuality': imageQuality,
    });
    if (path == null || path.isEmpty) {
      return null;
    }
    return XFile(path);
  }
}
