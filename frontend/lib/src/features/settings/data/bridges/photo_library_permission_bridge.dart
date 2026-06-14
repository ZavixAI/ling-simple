import 'package:flutter/services.dart';

import 'package:ling/src/core/platform/app_platform.dart';

enum PhotoLibraryPermissionState {
  granted,
  notDetermined,
  denied,
  restricted,
  unsupported,
  unknown,
}

String serializePhotoLibraryPermissionState(PhotoLibraryPermissionState state) {
  switch (state) {
    case PhotoLibraryPermissionState.granted:
      return 'granted';
    case PhotoLibraryPermissionState.notDetermined:
      return 'not_determined';
    case PhotoLibraryPermissionState.denied:
      return 'denied';
    case PhotoLibraryPermissionState.restricted:
      return 'restricted';
    case PhotoLibraryPermissionState.unsupported:
      return 'unsupported';
    case PhotoLibraryPermissionState.unknown:
      return 'unknown';
  }
}

abstract interface class PhotoLibraryPermissionBridge {
  Future<PhotoLibraryPermissionState> getPermissionState();
  Future<PhotoLibraryPermissionState> requestPermission();
  Future<void> openSystemSettings();
}

class MethodChannelPhotoLibraryPermissionBridge
    implements PhotoLibraryPermissionBridge {
  MethodChannelPhotoLibraryPermissionBridge();

  static const MethodChannel _channel = MethodChannel(
    'ling/photo_library_permission',
  );

  bool get _isSupported => AppPlatformInfo.current == AppPlatform.ios;

  @override
  Future<PhotoLibraryPermissionState> getPermissionState() async {
    if (!_isSupported) {
      return PhotoLibraryPermissionState.unsupported;
    }
    final value = await _channel.invokeMethod<String>('getPermissionState');
    return _mapPermission(value);
  }

  @override
  Future<PhotoLibraryPermissionState> requestPermission() async {
    if (!_isSupported) {
      return PhotoLibraryPermissionState.unsupported;
    }
    final value = await _channel.invokeMethod<String>('requestPermission');
    return _mapPermission(value);
  }

  @override
  Future<void> openSystemSettings() async {
    if (!_isSupported) {
      return;
    }
    await _channel.invokeMethod<void>('openSystemSettings');
  }

  PhotoLibraryPermissionState _mapPermission(String? value) {
    switch (value) {
      case 'granted':
        return PhotoLibraryPermissionState.granted;
      case 'denied':
        return PhotoLibraryPermissionState.denied;
      case 'restricted':
        return PhotoLibraryPermissionState.restricted;
      case 'not_determined':
        return PhotoLibraryPermissionState.notDetermined;
      default:
        return PhotoLibraryPermissionState.unsupported;
    }
  }
}
