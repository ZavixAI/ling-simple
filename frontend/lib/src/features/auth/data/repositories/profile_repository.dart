import 'dart:convert';

import 'package:ling/src/core/cache/json_cache_store.dart';
import 'package:ling/src/core/database/app_database.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/network/json_payload_codec.dart';
import 'package:ling/src/core/platform/models/notification_models.dart';
import 'package:ling/src/core/storage/local_persistence_policy.dart';
import 'package:ling/src/core/storage/private_asset_cache_store.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/chat/data/agent_file_repository.dart';

class ProfileRepository {
  ProfileRepository({
    required ApiClient apiClient,
    required JsonCacheStore cacheStore,
    required AppDatabase database,
    LocalPersistencePolicy? localPersistencePolicy,
    PrivateAssetCacheStore? privateAssetCacheStore,
    AgentFileCacheStore? agentFileCacheStore,
  }) : _apiClient = apiClient,
       _cacheStore = cacheStore,
       _database = database,
       _localPersistencePolicy =
           localPersistencePolicy ?? const LocalPersistencePolicy(),
       _privateAssetCacheStore =
           privateAssetCacheStore ?? const DefaultPrivateAssetCacheStore(),
       _agentFileCacheStore = agentFileCacheStore;

  static const String profileCacheKey = 'ling.cache.v2.calendar.profile';
  static const Duration profileCacheTtl = Duration(minutes: 3);

  final ApiClient _apiClient;
  final JsonCacheStore _cacheStore;
  final AppDatabase _database;
  final LocalPersistencePolicy _localPersistencePolicy;
  final PrivateAssetCacheStore _privateAssetCacheStore;
  final AgentFileCacheStore? _agentFileCacheStore;

  Future<UserProfile> getProfile({bool forceRefresh = false}) {
    return _cacheStore.getOrLoad<UserProfile>(
      profileCacheKey,
      ttl: profileCacheTtl,
      forceRefresh: forceRefresh,
      loader: () async {
        if (!forceRefresh &&
            _localPersistencePolicy.canPersistToProtectedDatabase(
              LocalDataSensitivity.privateEphemeral,
            )) {
          final stored = await _database.readProfilePayload(
            maxAge: profileCacheTtl,
          );
          if (stored != null) {
            return UserProfile.fromJson(decodeStoredMap(stored.payload));
          }
        }
        final bundle = await getAccountBundle();
        return bundle.profile;
      },
      encoder: (profile) => profile.toJson(),
      decoder: (value) => UserProfile.fromJson(asJsonMap(value)),
    );
  }

  Future<AccountBundle> getAccountBundle({bool forceRefresh = false}) async {
    final response = await _apiClient.get('/me');
    final bundle = AccountBundle.fromJson(asJsonMap(response.data));
    await cacheProfile(bundle.profile);
    return bundle;
  }

  Future<void> cacheProfile(UserProfile profile) async {
    await _persistProfile(profile);
    await _cacheStore.write<UserProfile>(
      profileCacheKey,
      ttl: profileCacheTtl,
      value: profile,
      encoder: (value) => value.toJson(),
    );
  }

  Future<UserProfile?> restoreCachedProfile() async {
    final stored = await _database.readProfilePayload();
    if (stored == null) {
      return null;
    }
    return UserProfile.fromJson(decodeStoredMap(stored.payload));
  }

  Future<void> registerPushDevice(PushDeviceRegistrationRequest request) async {
    await _apiClient.post('/me/push-devices', body: request.toJson());
  }

  Future<void> updatePushDeviceContext(
    PushDeviceContextUpdateRequest request,
  ) async {
    await _apiClient.post('/push-devices/context', body: request.toJson());
  }

  Future<void> deletePushDevice(String deviceId) async {
    await _apiClient.delete('/me/push-devices/$deviceId');
  }

  Future<AppBadgeCount> getBadgeCount() async {
    final response = await _apiClient.get('/me/badge');
    return AppBadgeCount.fromJson(asJsonMap(response.data));
  }

  Future<AppBadgeCount> markAllBadgeNotificationsRead() async {
    final response = await _apiClient.post('/me/badge/read-all', body: null);
    return AppBadgeCount.fromJson(asJsonMap(response.data));
  }

  Future<AppBadgeCount> markNotificationOpened(String notificationId) async {
    final response = await _apiClient.post(
      '/notifications/$notificationId/open',
      body: null,
    );
    return AppBadgeCount.fromJson(asJsonMap(response.data));
  }

  Future<ChallengeResult> requestPhoneBindingChallenge(String phone) async {
    final response = await _apiClient.post(
      '/auth/sms/challenges',
      body: {'provider_id': 'local', 'phone': phone, 'purpose': 'bind_phone'},
    );
    return ChallengeResult.fromJson(asJsonMap(response.data));
  }

  Future<ChallengeResult> requestEmailBindingChallenge(String email) async {
    final response = await _apiClient.post(
      '/auth/email/challenges',
      body: {'provider_id': 'local', 'email': email, 'purpose': 'bind_email'},
    );
    return ChallengeResult.fromJson(asJsonMap(response.data));
  }

  Future<UserProfile> updatePreferences(UserPreferencesPatch patch) async {
    final response = await _apiClient.patch('/me', body: patch.toJson());
    final bundle = AccountBundle.fromJson(asJsonMap(response.data));
    await cacheProfile(bundle.profile);
    return bundle.profile;
  }

  Future<AccountBundle> bindPhone({
    required String phone,
    required String challengeId,
    required String code,
  }) async {
    final response = await _apiClient.post(
      '/me/bind-phone',
      body: {'phone': phone, 'challenge_id': challengeId, 'code': code},
    );
    final bundle = AccountBundle.fromJson(asJsonMap(response.data));
    await cacheProfile(bundle.profile);
    return bundle;
  }

  Future<AccountBundle> bindEmail({
    required String email,
    required String code,
  }) async {
    final response = await _apiClient.post(
      '/me/bind-email',
      body: {'email': email, 'code': code},
    );
    final bundle = AccountBundle.fromJson(asJsonMap(response.data));
    await cacheProfile(bundle.profile);
    return bundle;
  }

  Future<AccountBundle> bindAppleIdentity({
    required String identityToken,
    String? authorizationCode,
    Map<String, dynamic>? fullName,
  }) async {
    return _bindIdentity(
      body: {
        'provider_id': 'apple',
        'apple_identity_token': identityToken,
        if ((authorizationCode ?? '').trim().isNotEmpty)
          'apple_authorization_code': authorizationCode,
        if (fullName != null && fullName.isNotEmpty)
          'apple_full_name': fullName,
      },
    );
  }

  Future<AccountBundle> bindWeChatIdentity({required String authCode}) async {
    return _bindIdentity(
      body: {'provider_id': 'wechat', 'wechat_auth_code': authCode},
    );
  }

  Future<void> deleteAccount() async {
    await _apiClient.delete('/me');
    await clearUserData();
  }

  Future<void> clearUserData() async {
    await _cacheStore.invalidate(profileCacheKey);
    await _database.clearAllUserData();
    await _privateAssetCacheStore.clear();
    await _agentFileCacheStore?.clear();
  }

  Future<AccountBundle> _bindIdentity({
    required Map<String, dynamic> body,
  }) async {
    final response = await _apiClient.post('/me/bind-identity', body: body);
    final bundle = AccountBundle.fromJson(asJsonMap(response.data));
    await cacheProfile(bundle.profile);
    return bundle;
  }

  Future<void> _persistProfile(UserProfile profile) async {
    if (_localPersistencePolicy.canPersistToProtectedDatabase(
      LocalDataSensitivity.privateEphemeral,
    )) {
      await _database.saveProfilePayload(jsonEncode(profile.toJson()));
    }
  }
}
