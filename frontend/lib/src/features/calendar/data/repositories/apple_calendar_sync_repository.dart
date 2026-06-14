import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/network/json_payload_codec.dart';
import 'package:ling/src/features/calendar/models/apple_calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';

class AppleCalendarContextUploadResult {
  const AppleCalendarContextUploadResult({
    required this.didMutateEvents,
    required this.insertedCount,
    required this.updatedCount,
    required this.deactivatedCount,
  });

  final bool didMutateEvents;
  final int insertedCount;
  final int updatedCount;
  final int deactivatedCount;

  factory AppleCalendarContextUploadResult.fromJson(Map<String, dynamic> json) {
    int readInt(String key) {
      final value = json[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      return int.tryParse('$value') ?? 0;
    }

    return AppleCalendarContextUploadResult(
      didMutateEvents: json['did_mutate_events'] == true,
      insertedCount: readInt('inserted_count'),
      updatedCount: readInt('updated_count'),
      deactivatedCount: readInt('deactivated_count'),
    );
  }
}

class AppleCalendarSyncRepository {
  AppleCalendarSyncRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<void> linkAppleEvent(AppleEventLinkRequest payload) async {
    await _apiClient.post(
      '/integrations/apple/event-links',
      body: payload.toJson(),
    );
  }

  Future<List<AppleManagedEventLink>> getManagedAppleLinks(
    String deviceId,
  ) async {
    final response = await _apiClient.get(
      '/integrations/apple/managed-links',
      queryParameters: <String, Object?>{'device_id': deviceId},
    );
    final data = asJsonMap(response.data);
    final items = data['items'];
    if (items is! List) {
      return const <AppleManagedEventLink>[];
    }
    return items
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) =>
              AppleManagedEventLink.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<void> deleteManagedAppleLinks(String deviceId) async {
    await _apiClient.delete(
      '/integrations/apple/managed-links',
      queryParameters: <String, Object?>{'device_id': deviceId},
    );
  }

  Future<AppleCalendarContextUploadResult> uploadAppleCalendarContext(
    AppleCalendarContextUploadRequest payload,
  ) async {
    final response = await _apiClient.post(
      '/integrations/apple/calendar-context',
      body: payload.toJson(),
    );
    return AppleCalendarContextUploadResult.fromJson(asJsonMap(response.data));
  }
}
