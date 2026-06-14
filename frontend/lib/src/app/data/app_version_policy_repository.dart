import 'package:ling/src/app/models/app_version_policy.dart';
import 'package:ling/src/config/app_environment.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/network/json_payload_codec.dart';
import 'package:ling/src/core/platform/app_platform.dart';

class AppVersionPolicyRepository {
  AppVersionPolicyRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AppVersionPolicy> getVersionPolicy({
    required AppPlatform platform,
    String? version,
  }) async {
    final response = await _apiClient.get(
      '/app/version-policy',
      queryParameters: <String, Object?>{
        'platform': platform.name,
        'version': version ?? AppEnvironment.appVersion,
      },
    );
    return AppVersionPolicy.fromJson(asJsonMap(response.data));
  }
}
