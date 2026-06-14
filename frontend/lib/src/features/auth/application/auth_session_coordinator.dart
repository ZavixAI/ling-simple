import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/providers.dart';
import 'package:ling/src/core/storage/push_device_id_store.dart';
import 'package:ling/src/features/auth/application/auth_state.dart';
import 'package:ling/src/features/auth/application/auth_token_claims.dart';
import 'package:ling/src/features/auth/data/repositories/auth_repository.dart';
import 'package:ling/src/features/auth/data/repositories/profile_repository.dart';
import 'package:ling/src/features/auth/data/storage/auth_session_store.dart';
import 'package:ling/src/features/auth/models/user_models.dart';

class AuthSessionCoordinator {
  AuthSessionCoordinator({
    required AuthSessionStore sessionStore,
    required ApiClient apiClient,
    required AuthRepository authRepository,
    required ProfileRepository profileRepository,
    required PushDeviceIdStore pushDeviceIdStore,
  }) : _sessionStore = sessionStore,
       _apiClient = apiClient,
       _authRepository = authRepository,
       _profileRepository = profileRepository,
       _pushDeviceIdStore = pushDeviceIdStore {
    _apiClient.setTokenRefreshHandler(_handleTokenRefresh);
  }

  final AuthSessionStore _sessionStore;
  final ApiClient _apiClient;
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final PushDeviceIdStore _pushDeviceIdStore;

  VoidCallback? onAutoRefreshFailed;

  Future<AuthState> restore() async {
    final restored = await _sessionStore.restore();
    if (restored == null) {
      _apiClient.setAccessToken(null);
      return const AuthStateUnauthenticated();
    }

    await _syncPushDeviceIdFromAccessToken(restored.accessToken);
    _apiClient.setAccessToken(restored.accessToken);
    try {
      return AuthStateAuthenticated(
        await _hydrateSession(
          accessToken: restored.accessToken,
          refreshToken: restored.refreshToken,
        ),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401 && restored.refreshToken.isNotEmpty) {
        return refresh(
          currentState: const AuthStateUnauthenticated(),
          refreshTokenOverride: restored.refreshToken,
        );
      }
      final cachedProfile = await _profileRepository.restoreCachedProfile();
      if (cachedProfile != null) {
        return AuthStateAuthenticated(
          AuthSession(
            accessToken: restored.accessToken,
            refreshToken: restored.refreshToken,
            profile: cachedProfile,
            identities: const [],
            deviceId:
                extractDeviceIdFromAccessToken(restored.accessToken) ??
                await _pushDeviceIdStore.getOrCreate(),
          ),
        );
      }
      return AuthStateFailure(message: error.message);
    }
  }

  Future<AuthState> completeSignIn(AuthBundle bundle) async {
    await _profileRepository.clearUserData();
    await _sessionStore.persistTokens(
      accessToken: bundle.accessToken,
      refreshToken: bundle.refreshToken,
    );
    await _profileRepository.cacheProfile(bundle.profile);
    final deviceId = await _syncPushDeviceId(
      accessToken: bundle.accessToken,
      deviceId: bundle.deviceId,
    );
    _apiClient.setAccessToken(bundle.accessToken);
    return AuthStateAuthenticated(
      AuthSession(
        accessToken: bundle.accessToken,
        refreshToken: bundle.refreshToken,
        profile: bundle.profile,
        identities: bundle.identities,
        deviceId: deviceId,
        isNewUser: bundle.isNewUser,
      ),
    );
  }

  Future<AuthState> refresh({
    required AuthState currentState,
    String? refreshTokenOverride,
  }) async {
    final currentSession = currentState.session;
    final refreshToken =
        (refreshTokenOverride ?? currentSession?.refreshToken ?? '').trim();
    if (refreshToken.isEmpty) {
      await signOut();
      return const AuthStateUnauthenticated();
    }

    try {
      final bundle = await _authRepository.refreshToken(refreshToken);
      await _sessionStore.persistTokens(
        accessToken: bundle.accessToken,
        refreshToken: bundle.refreshToken,
      );
      final deviceId = await _syncPushDeviceId(
        accessToken: bundle.accessToken,
        deviceId: bundle.deviceId,
      );
      _apiClient.setAccessToken(bundle.accessToken);
      final profile = bundle.profile.preferences == null
          ? await _profileRepository.getProfile(forceRefresh: true)
          : bundle.profile;
      await _profileRepository.cacheProfile(profile);
      return AuthStateAuthenticated(
        AuthSession(
          accessToken: bundle.accessToken,
          refreshToken: bundle.refreshToken,
          profile: profile,
          identities: bundle.identities,
          deviceId: deviceId,
        ),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        _apiClient.setAccessToken(null);
        await _sessionStore.clear();
      }
      return AuthStateFailure(
        message: error.message,
        previousSession: currentSession,
      );
    }
  }

  Future<void> signOut() async {
    _apiClient.setAccessToken(null);
    await _sessionStore.clear();
    await _profileRepository.clearUserData();
  }

  Future<String> _handleTokenRefresh() async {
    final restored = await _sessionStore.restore();
    if (restored == null || restored.refreshToken.isEmpty) {
      _apiClient.setAccessToken(null);
      await _sessionStore.clear();
      onAutoRefreshFailed?.call();
      throw Exception('No refresh token available');
    }

    try {
      final bundle = await _authRepository.refreshToken(restored.refreshToken);
      await _sessionStore.persistTokens(
        accessToken: bundle.accessToken,
        refreshToken: bundle.refreshToken,
      );
      await _syncPushDeviceId(
        accessToken: bundle.accessToken,
        deviceId: bundle.deviceId,
      );
      _apiClient.setAccessToken(bundle.accessToken);
      return bundle.accessToken;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        _apiClient.setAccessToken(null);
        await _sessionStore.clear();
        onAutoRefreshFailed?.call();
      }
      rethrow;
    }
  }

  Future<AuthSession> _hydrateSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    final bundle = await _profileRepository.getAccountBundle(
      forceRefresh: true,
    );
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      profile: bundle.profile,
      identities: bundle.identities,
      deviceId:
          extractDeviceIdFromAccessToken(accessToken) ??
          await _pushDeviceIdStore.getOrCreate(),
    );
  }

  Future<String?> _syncPushDeviceId({
    required String accessToken,
    String? deviceId,
  }) async {
    final resolvedDeviceId =
        (deviceId ?? extractDeviceIdFromAccessToken(accessToken))?.trim();
    if (resolvedDeviceId == null || resolvedDeviceId.isEmpty) {
      return null;
    }
    await _pushDeviceIdStore.replace(resolvedDeviceId);
    return resolvedDeviceId;
  }

  Future<String?> _syncPushDeviceIdFromAccessToken(String accessToken) {
    return _syncPushDeviceId(accessToken: accessToken);
  }
}

final authSessionCoordinatorProvider = Provider<AuthSessionCoordinator>((ref) {
  return AuthSessionCoordinator(
    sessionStore: ref.read(authSessionStoreProvider),
    apiClient: ref.read(apiClientProvider),
    authRepository: ref.read(authRepositoryProvider),
    profileRepository: ref.read(profileRepositoryProvider),
    pushDeviceIdStore: ref.read(pushDeviceIdStoreProvider),
  );
});
