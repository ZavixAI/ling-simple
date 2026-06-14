import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/network/json_payload_codec.dart';
import 'package:ling/src/features/calendar/models/calendar_integration_models.dart';

class CalendarIntegrationRepository {
  CalendarIntegrationRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<CalendarConnectionSummary>> listConnections() async {
    final response = await _apiClient.get('/integrations/calendar/connections');
    final data = asJsonMap(response.data);
    final items = data['items'];
    if (items is! List) {
      return const <CalendarConnectionSummary>[];
    }
    return items
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) => CalendarConnectionSummary.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<CalendarOAuthStartResponse> startOAuth(
    CalendarProviderId provider,
  ) async {
    final response = await _apiClient.post(
      '/integrations/calendar/oauth/${calendarProviderIdToRaw(provider)}/start',
    );
    return CalendarOAuthStartResponse.fromJson(asJsonMap(response.data));
  }

  Future<void> completeOAuth(
    CalendarProviderId provider,
    CalendarOAuthCompleteRequest payload,
  ) async {
    await _apiClient.post(
      '/integrations/calendar/oauth/${calendarProviderIdToRaw(provider)}/complete',
      body: payload.toJson(),
    );
  }

  Future<void> refreshConnection(CalendarProviderId provider) async {
    await _apiClient.post(
      '/integrations/calendar/connections/${calendarProviderIdToRaw(provider)}/sync',
    );
  }

  Future<void> disconnect(CalendarProviderId provider) async {
    await _apiClient.delete(
      '/integrations/calendar/connections/${calendarProviderIdToRaw(provider)}',
    );
  }
}
