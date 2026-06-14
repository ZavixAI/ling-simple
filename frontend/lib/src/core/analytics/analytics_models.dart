import 'dart:convert';

class AnalyticsEvent {
  const AnalyticsEvent({
    required this.clientEventId,
    required this.eventName,
    required this.occurredAt,
    this.surface,
    this.action,
    this.source,
    this.deviceId,
    this.clientSessionId,
    this.platform,
    this.appVersion,
    this.locale,
    this.timezone,
    this.properties = const <String, Object?>{},
  });

  final String clientEventId;
  final String eventName;
  final DateTime occurredAt;
  final String? surface;
  final String? action;
  final String? source;
  final String? deviceId;
  final String? clientSessionId;
  final String? platform;
  final String? appVersion;
  final String? locale;
  final String? timezone;
  final Map<String, Object?> properties;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'client_event_id': clientEventId,
      'event_name': eventName,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      if ((surface ?? '').trim().isNotEmpty) 'surface': surface,
      if ((action ?? '').trim().isNotEmpty) 'action': action,
      if ((source ?? '').trim().isNotEmpty) 'source': source,
      if ((deviceId ?? '').trim().isNotEmpty) 'device_id': deviceId,
      if ((clientSessionId ?? '').trim().isNotEmpty)
        'client_session_id': clientSessionId,
      if ((platform ?? '').trim().isNotEmpty) 'platform': platform,
      if ((appVersion ?? '').trim().isNotEmpty) 'app_version': appVersion,
      if ((locale ?? '').trim().isNotEmpty) 'locale': locale,
      if ((timezone ?? '').trim().isNotEmpty) 'timezone': timezone,
      'properties': properties,
    };
  }

  String encode() => jsonEncode(toJson());
}

class AnalyticsUploadResult {
  const AnalyticsUploadResult({
    required this.accepted,
    required this.received,
    required this.duplicates,
  });

  final int accepted;
  final int received;
  final int duplicates;

  factory AnalyticsUploadResult.fromJson(Map<String, dynamic> json) {
    return AnalyticsUploadResult(
      accepted: _asInt(json['accepted']),
      received: _asInt(json['received']),
      duplicates: _asInt(json['duplicates']),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('$value') ?? 0;
}
