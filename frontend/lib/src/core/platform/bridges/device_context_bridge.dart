import 'package:flutter/services.dart';

import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/core/platform/models/notification_models.dart';

abstract interface class DeviceContextBridge {
  Future<DeviceContextSnapshot?> getLatestContext({bool startTracking = false});
  Future<DeviceLocationPermissionState> getLocationPermissionState();
  Future<DeviceContextSnapshot?> requestForegroundLocationContext();
  Future<void> openSystemSettings();
  Future<void> configureBackend({
    required String apiBaseUrl,
    required String apiPrefix,
  });
  Future<void> startTracking();
  Future<void> stopTracking();
}

class MethodChannelDeviceContextBridge implements DeviceContextBridge {
  MethodChannelDeviceContextBridge();

  static const MethodChannel _channel = MethodChannel('ling/device_context');

  bool get _isSupported => isNativeLingBridgeSupported();

  @override
  Future<DeviceContextSnapshot?> getLatestContext({
    bool startTracking = false,
  }) async {
    if (!_isSupported) {
      return null;
    }
    final value = await _channel.invokeMethod<Object>('getLatestContext', {
      'startTracking': startTracking,
    });
    if (value is Map<String, dynamic>) {
      return DeviceContextSnapshot.fromJson(value);
    }
    if (value is Map) {
      return DeviceContextSnapshot.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }

  @override
  Future<DeviceLocationPermissionState> getLocationPermissionState() async {
    if (!_isSupported) {
      return DeviceLocationPermissionState.unsupported;
    }
    final value = await _channel.invokeMethod<String>(
      'getLocationPermissionState',
    );
    return deserializeDeviceLocationPermissionState(value);
  }

  @override
  Future<DeviceContextSnapshot?> requestForegroundLocationContext() async {
    if (!_isSupported) {
      return null;
    }
    final value = await _channel.invokeMethod<Object>(
      'requestForegroundLocationContext',
    );
    if (value is Map<String, dynamic>) {
      return DeviceContextSnapshot.fromJson(value);
    }
    if (value is Map) {
      return DeviceContextSnapshot.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }

  @override
  Future<void> openSystemSettings() async {
    if (!_isSupported) {
      return;
    }
    await _channel.invokeMethod<void>('openSystemSettings');
  }

  @override
  Future<void> configureBackend({
    required String apiBaseUrl,
    required String apiPrefix,
  }) async {
    if (!_isSupported) {
      return;
    }
    await _channel.invokeMethod<void>('configureBackend', {
      'apiBaseUrl': apiBaseUrl,
      'apiPrefix': apiPrefix,
    });
  }

  @override
  Future<void> startTracking() async {
    if (!_isSupported) {
      return;
    }
    await _channel.invokeMethod<void>('startTracking');
  }

  @override
  Future<void> stopTracking() async {
    if (!_isSupported) {
      return;
    }
    await _channel.invokeMethod<void>('stopTracking');
  }
}
