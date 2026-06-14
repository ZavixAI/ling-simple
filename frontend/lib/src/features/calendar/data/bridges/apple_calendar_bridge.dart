import 'package:flutter/services.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/features/calendar/models/apple_calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';

export 'package:ling/src/features/calendar/models/apple_calendar_models.dart';

abstract interface class AppleCalendarBridge {
  Future<AppleCalendarPermissionState> getPermissionState();
  Future<AppleCalendarPermissionState> requestPermission();
  Future<void> openSystemSettings();
  Future<List<AppleCalendarItem>> listCalendars();
  Future<List<AppleCalendarEvent>> listEvents({
    required DateTime startAt,
    required DateTime endAt,
  });
  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> draft);
  Future<Map<String, dynamic>> updateEvent(
    AppleCalendarMutationOptions options,
    Map<String, dynamic> draft,
  );
  Future<void> deleteEvent(AppleCalendarMutationOptions options);
  Future<void> deleteManagedEvents(List<AppleManagedEventLink> links);
}

class MethodChannelAppleCalendarBridge implements AppleCalendarBridge {
  MethodChannelAppleCalendarBridge();

  static const MethodChannel _channel = MethodChannel('ling/apple_calendar');

  bool get _isSupported => AppPlatformInfo.current == AppPlatform.ios;

  @override
  Future<AppleCalendarPermissionState> getPermissionState() async {
    if (!_isSupported) {
      return AppleCalendarPermissionState.unsupported;
    }
    final value = await _channel.invokeMethod<String>('getPermissionState');
    return _mapPermission(value);
  }

  @override
  Future<AppleCalendarPermissionState> requestPermission() async {
    if (!_isSupported) {
      return AppleCalendarPermissionState.unsupported;
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
  Future<List<AppleCalendarItem>> listCalendars() async {
    if (!_isSupported) {
      return const [];
    }
    final response = await _channel.invokeMethod<List<dynamic>>(
      'listCalendars',
    );
    return (response ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) => AppleCalendarItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  @override
  Future<List<AppleCalendarEvent>> listEvents({
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    if (!_isSupported) {
      return const [];
    }
    final response = await _channel.invokeMethod<List<dynamic>>('listEvents', {
      'startAt': _encodeDate(startAt),
      'endAt': _encodeDate(endAt),
    });
    return (response ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) =>
              AppleCalendarEvent.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> draft) async {
    if (!_isSupported) {
      throw PlatformException(
        code: 'unsupported',
        message: 'Apple Calendar unavailable',
      );
    }
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'createEvent',
      _normalizeDraft(draft),
    );
    return response ?? const {};
  }

  @override
  Future<Map<String, dynamic>> updateEvent(
    AppleCalendarMutationOptions options,
    Map<String, dynamic> draft,
  ) async {
    if (!_isSupported) {
      throw PlatformException(
        code: 'unsupported',
        message: 'Apple Calendar unavailable',
      );
    }
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'updateEvent',
      {...options.toJson(), ..._normalizeDraft(draft)},
    );
    return response ?? const {};
  }

  @override
  Future<void> deleteEvent(AppleCalendarMutationOptions options) async {
    if (!_isSupported) {
      return;
    }
    await _channel.invokeMethod<void>('deleteEvent', options.toJson());
  }

  @override
  Future<void> deleteManagedEvents(List<AppleManagedEventLink> links) async {
    if (!_isSupported || links.isEmpty) {
      return;
    }
    await _channel.invokeMethod<void>('deleteManagedEvents', {
      'items': links
          .map((item) => item.toDeletionJson())
          .toList(growable: false),
    });
  }

  AppleCalendarPermissionState _mapPermission(String? raw) {
    switch (raw) {
      case 'granted':
        return AppleCalendarPermissionState.granted;
      case 'denied':
        return AppleCalendarPermissionState.denied;
      case 'not_determined':
        return AppleCalendarPermissionState.notDetermined;
      default:
        return AppleCalendarPermissionState.unsupported;
    }
  }

  Map<String, dynamic> _normalizeDraft(Map<String, dynamic> draft) {
    final normalized = Map<String, dynamic>.from(draft);
    for (final key in const ['startAt', 'endAt']) {
      final value = normalized[key];
      if (value is DateTime) {
        normalized[key] = _encodeDate(value);
      }
    }
    final recurrence = normalized['recurrence'];
    if (recurrence is LingEventRecurrence) {
      normalized['recurrence'] = recurrence.toJson();
    }
    final occurrenceDate = normalized['occurrenceDate'];
    if (occurrenceDate is DateTime) {
      normalized['occurrenceDate'] = _encodeDate(occurrenceDate);
    }
    return normalized;
  }

  String _encodeDate(DateTime value) => value.toUtc().toIso8601String();
}
