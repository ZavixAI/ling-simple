import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/network/json_payload_codec.dart';
import 'package:ling/src/core/platform/models/notification_models.dart';
import 'package:ling/src/features/auth/models/user_models.dart';

class AuthRepository {
  AuthRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ChallengeResult> requestSmsChallenge(
    String phone, {
    String? phoneAreaCode,
    String purpose = 'login',
  }) async {
    final response = await _apiClient.post(
      '/auth/sms/challenges',
      body: {
        'provider_id': 'local',
        'phone': phone,
        if ((phoneAreaCode ?? '').trim().isNotEmpty)
          'phone_area_code': phoneAreaCode,
        'purpose': purpose,
      },
    );
    return ChallengeResult.fromJson(asJsonMap(response.data));
  }

  Future<ChallengeResult> requestEmailChallenge(
    String email, {
    String purpose = 'login',
  }) async {
    final response = await _apiClient.post(
      '/auth/email/challenges',
      body: {'provider_id': 'local', 'email': email, 'purpose': purpose},
    );
    return ChallengeResult.fromJson(asJsonMap(response.data));
  }

  Future<AuthBundle> exchangeSmsCode({
    required String phone,
    String? phoneAreaCode,
    String? challengeId,
    required String code,
    required PushDeviceRegistrationRequest pushDevice,
  }) async {
    final response = await _apiClient.post(
      '/oauth2/token',
      body: {
        'provider_id': 'local',
        'grant_type': 'sms_code',
        if ((challengeId ?? '').trim().isNotEmpty) 'challenge_id': challengeId,
        'phone': phone,
        if ((phoneAreaCode ?? '').trim().isNotEmpty)
          'phone_area_code': phoneAreaCode,
        'code': code,
        'push_device': pushDevice.toJson(),
        'scope': 'openid profile calendar agent offline_access',
      },
    );
    return AuthBundle.fromJson(asJsonMap(response.data));
  }

  Future<AuthBundle> exchangeEmailCode({
    required String email,
    required String code,
    required PushDeviceRegistrationRequest pushDevice,
  }) async {
    final response = await _apiClient.post(
      '/oauth2/token',
      body: {
        'provider_id': 'local',
        'grant_type': 'email_code',
        'email': email,
        'code': code,
        'push_device': pushDevice.toJson(),
        'scope': 'openid profile calendar agent offline_access',
      },
    );
    return AuthBundle.fromJson(asJsonMap(response.data));
  }

  Future<AuthBundle> exchangeAliyunOneClickToken(
    String token, {
    required PushDeviceRegistrationRequest pushDevice,
  }) async {
    final response = await _apiClient.post(
      '/oauth2/token',
      body: {
        'provider_id': 'local',
        'grant_type': 'aliyun_one_click',
        'one_click_token': token,
        'push_device': pushDevice.toJson(),
        'scope': 'openid profile calendar agent offline_access',
      },
    );
    return AuthBundle.fromJson(asJsonMap(response.data));
  }

  Future<AuthBundle> exchangeAppleIdentityToken({
    required String identityToken,
    required PushDeviceRegistrationRequest pushDevice,
    String? authorizationCode,
    Map<String, dynamic>? fullName,
  }) async {
    final response = await _apiClient.post(
      '/oauth2/token',
      body: {
        'provider_id': 'apple',
        'grant_type': 'apple_identity_token',
        'apple_identity_token': identityToken,
        'push_device': pushDevice.toJson(),
        'scope': 'openid profile calendar agent offline_access',
        if ((authorizationCode ?? '').trim().isNotEmpty)
          'apple_authorization_code': authorizationCode,
        if (fullName != null && fullName.isNotEmpty)
          'apple_full_name': fullName,
      },
    );
    return AuthBundle.fromJson(asJsonMap(response.data));
  }

  Future<AuthBundle> exchangeWeChatAuthCode(
    String authCode, {
    required PushDeviceRegistrationRequest pushDevice,
  }) async {
    final response = await _apiClient.post(
      '/oauth2/token',
      body: {
        'provider_id': 'wechat',
        'grant_type': 'wechat_auth_code',
        'wechat_auth_code': authCode,
        'push_device': pushDevice.toJson(),
        'scope': 'openid profile calendar agent offline_access',
      },
    );
    return AuthBundle.fromJson(asJsonMap(response.data));
  }

  Future<AuthBundle> refreshToken(String refreshToken) async {
    final response = await _apiClient.post(
      '/oauth2/token',
      body: {
        'provider_id': 'local',
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );
    return AuthBundle.fromJson(asJsonMap(response.data));
  }
}
