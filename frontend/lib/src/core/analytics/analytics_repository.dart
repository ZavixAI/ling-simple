import 'dart:convert';

import 'package:ling/src/core/analytics/analytics_models.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/network/json_payload_codec.dart';

class AnalyticsRepository {
  const AnalyticsRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AnalyticsUploadResult> uploadEvents(
    Iterable<AnalyticsEvent> events,
  ) async {
    final response = await _apiClient.post(
      '/analytics/events',
      body: {
        'events': events.map((event) => event.toJson()).toList(growable: false),
      },
    );
    return AnalyticsUploadResult.fromJson(asJsonMap(response.data));
  }

  AnalyticsEvent decode(String payload) {
    final json = jsonDecode(payload);
    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json as Map);
    return AnalyticsEvent(
      clientEventId: '${map['client_event_id'] ?? ''}',
      eventName: '${map['event_name'] ?? ''}',
      occurredAt:
          DateTime.tryParse('${map['occurred_at'] ?? ''}') ?? DateTime.now(),
      surface: map['surface']?.toString(),
      action: map['action']?.toString(),
      source: map['source']?.toString(),
      deviceId: map['device_id']?.toString(),
      clientSessionId: map['client_session_id']?.toString(),
      platform: map['platform']?.toString(),
      appVersion: map['app_version']?.toString(),
      locale: map['locale']?.toString(),
      timezone: map['timezone']?.toString(),
      properties: asJsonMap(map['properties']),
    );
  }
}
