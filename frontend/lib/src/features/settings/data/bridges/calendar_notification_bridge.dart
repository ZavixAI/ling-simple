import 'package:flutter/services.dart';

import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/core/platform/models/notification_models.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';

abstract interface class CalendarNotificationBridge {
  Future<CalendarNotificationPermissionState> getPermissionState();
  Future<CalendarNotificationPermissionState> requestPermission();
  Future<void> openSystemSettings();
  Future<void> syncNotifications(
    List<CalendarNotificationRequest> notifications,
  );
  Future<void> cancelAllNotifications();
  Future<RemoteNotificationRegistration?> registerRemoteNotifications();
  Future<void> setApplicationBadgeCount(int count);
  Future<void> setForegroundNotificationContext(String context);
  Stream<ForegroundRemoteNotificationEvent>
  foregroundRemoteNotificationEvents();
}

class MethodChannelCalendarNotificationBridge
    implements CalendarNotificationBridge {
  MethodChannelCalendarNotificationBridge();

  static const MethodChannel _channel = MethodChannel(
    'ling/calendar_notifications',
  );
  static const EventChannel _eventChannel = EventChannel(
    'ling/calendar_notifications/events',
  );

  bool get _isSupported => isNativeLingBridgeSupported();

  @override
  Future<CalendarNotificationPermissionState> getPermissionState() async {
    if (!_isSupported) {
      return CalendarNotificationPermissionState.unsupported;
    }
    final value = await _channel.invokeMethod<String>('getPermissionState');
    return _mapPermission(value);
  }

  @override
  Future<CalendarNotificationPermissionState> requestPermission() async {
    if (!_isSupported) {
      return CalendarNotificationPermissionState.unsupported;
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

  @override
  Future<void> syncNotifications(
    List<CalendarNotificationRequest> notifications,
  ) async {
    if (!_isSupported) {
      return;
    }
    await _channel.invokeMethod<void>('syncNotifications', {
      'notifications': notifications
          .map((item) => item.toJson())
          .toList(growable: false),
    });
  }

  @override
  Future<void> cancelAllNotifications() async {
    if (!_isSupported) {
      return;
    }
    await _channel.invokeMethod<void>('cancelAllNotifications');
  }

  @override
  Future<RemoteNotificationRegistration?> registerRemoteNotifications() async {
    if (!_isSupported) {
      return null;
    }
    final value = await _channel.invokeMethod<Object>(
      'registerRemoteNotifications',
    );
    if (value is Map<String, dynamic>) {
      return RemoteNotificationRegistration.fromJson(value);
    }
    if (value is Map) {
      return RemoteNotificationRegistration.fromJson(
        Map<String, dynamic>.from(value),
      );
    }
    return null;
  }

  @override
  Future<void> setApplicationBadgeCount(int count) async {
    if (!_isSupported) {
      return;
    }
    await _channel.invokeMethod<void>('setApplicationBadgeCount', {
      'count': count < 0 ? 0 : count,
    });
  }

  @override
  Future<void> setForegroundNotificationContext(String context) async {
    if (!_isSupported) {
      return;
    }
    await _channel.invokeMethod<void>('setForegroundNotificationContext', {
      'context': context,
    });
  }

  @override
  Stream<ForegroundRemoteNotificationEvent>
  foregroundRemoteNotificationEvents() {
    if (!_isSupported) {
      return const Stream<ForegroundRemoteNotificationEvent>.empty();
    }
    return _eventChannel.receiveBroadcastStream().map((dynamic event) {
      final json = event is Map
          ? Map<Object?, Object?>.from(event)
          : const <Object?, Object?>{};
      return ForegroundRemoteNotificationEvent.fromJson(json);
    });
  }

  CalendarNotificationPermissionState _mapPermission(String? raw) {
    switch (raw) {
      case 'granted':
        return CalendarNotificationPermissionState.granted;
      case 'denied':
        return CalendarNotificationPermissionState.denied;
      case 'not_determined':
        return CalendarNotificationPermissionState.notDetermined;
      default:
        return CalendarNotificationPermissionState.unsupported;
    }
  }
}
