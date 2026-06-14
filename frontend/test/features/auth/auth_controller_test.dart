import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/config/constants.dart';
import 'package:ling/src/core/cache/json_cache_store.dart';
import 'package:ling/src/core/database/app_database.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/platform/bridges/device_context_bridge.dart';
import 'package:ling/src/core/platform/models/notification_models.dart';
import 'package:ling/src/core/providers.dart';
import 'package:ling/src/core/storage/preferences_store.dart';
import 'package:ling/src/core/storage/private_asset_cache_store.dart';
import 'package:ling/src/core/storage/push_device_id_store.dart';
import 'package:ling/src/core/storage/secure_key_value_store.dart';
import 'package:ling/src/features/auth/application/auth_controller.dart';
import 'package:ling/src/features/auth/application/auth_state.dart';
import 'package:ling/src/features/auth/data/repositories/auth_repository.dart';
import 'package:ling/src/features/auth/data/repositories/profile_repository.dart';
import 'package:ling/src/features/auth/data/storage/auth_session_store.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/settings/data/bridges/calendar_notification_bridge.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('restoreSession authenticates with secure tokens', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final secureStore = InMemorySecureKeyValueStore();
    await secureStore.write(AuthSessionStore.accessTokenKey, 'secure_access');
    await secureStore.write(AuthSessionStore.refreshTokenKey, 'secure_refresh');

    final profileRepository = _FakeProfileRepository(
      database: database,
      bundle: AccountBundle(
        profile: _profile(userId: 'secure-user'),
        identities: const [
          UserIdentity(
            identityId: 'identity-1',
            userId: 'secure-user',
            providerId: 'local',
          ),
        ],
      ),
    );

    final container = _createContainer(
      database: database,
      secureStore: secureStore,
      profileRepository: profileRepository,
      authRepository: _FakeAuthRepository(),
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).restoreSession();

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthStateAuthenticated>());
    expect(state.session?.accessToken, 'secure_access');
    expect(state.session?.profile.userId, 'secure-user');
    expect(profileRepository.accountBundleFetchCount, 1);
  });

  test(
    'restoreSession keeps cached session when profile refresh fails',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final secureStore = InMemorySecureKeyValueStore();
      await secureStore.write(AuthSessionStore.accessTokenKey, 'secure_access');
      await secureStore.write(
        AuthSessionStore.refreshTokenKey,
        'secure_refresh',
      );
      await database.saveProfilePayload(
        jsonEncode(_profile(userId: 'cached-user').toJson()),
      );

      final profileRepository = _FakeProfileRepository(
        database: database,
        bundle: AccountBundle(
          profile: _profile(userId: 'unused-user'),
          identities: const [],
        ),
      )..accountBundleError = ApiException(message: 'network unavailable');

      final container = _createContainer(
        database: database,
        secureStore: secureStore,
        profileRepository: profileRepository,
        authRepository: _FakeAuthRepository(),
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).restoreSession();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthStateAuthenticated>());
      expect(state.session?.accessToken, 'secure_access');
      expect(state.session?.profile.userId, 'cached-user');
      expect(
        await secureStore.read(AuthSessionStore.accessTokenKey),
        'secure_access',
      );
    },
  );

  test('restoreSession reconciles push device id from access token', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PushDeviceIdStore.defaultStorageKey: 'stale-device',
    });
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final secureStore = InMemorySecureKeyValueStore();
    final accessToken = _accessTokenWithDeviceId('session-device');
    await secureStore.write(AuthSessionStore.accessTokenKey, accessToken);
    await secureStore.write(AuthSessionStore.refreshTokenKey, 'secure_refresh');

    final container = _createContainer(
      database: database,
      secureStore: secureStore,
      profileRepository: _FakeProfileRepository(
        database: database,
        bundle: AccountBundle(
          profile: _profile(userId: 'secure-user'),
          identities: const [],
        ),
      ),
      authRepository: _FakeAuthRepository(),
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).restoreSession();

    final state = container.read(authControllerProvider);
    expect(state.session?.deviceId, 'session-device');
    expect(
      await container.read(pushDeviceIdStoreProvider).read(),
      'session-device',
    );
  });

  test('restoreSession ignores legacy preferences session payload', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final secureStore = InMemorySecureKeyValueStore();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ling.auth_session': '{"access_token":"legacy_access"}',
    });

    final container = _createContainer(
      database: database,
      secureStore: secureStore,
      profileRepository: _FakeProfileRepository(
        database: database,
        bundle: AccountBundle(
          profile: _profile(userId: 'legacy-user'),
          identities: const [],
        ),
      ),
      authRepository: _FakeAuthRepository(),
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).restoreSession();

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthStateUnauthenticated>());
    expect(await secureStore.read(AuthSessionStore.accessTokenKey), isNull);
    expect(await secureStore.read(AuthSessionStore.refreshTokenKey), isNull);
  });

  test('refreshSession updates the authenticated session on success', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final secureStore = InMemorySecureKeyValueStore();
    final authRepository = _FakeAuthRepository()
      ..refreshResult = AuthBundle(
        accessToken: 'fresh_access',
        refreshToken: 'fresh_refresh',
        profile: _profile(userId: 'fresh-user'),
        identities: const [],
      );
    final container = _createContainer(
      database: database,
      secureStore: secureStore,
      profileRepository: _FakeProfileRepository(
        database: database,
        bundle: AccountBundle(
          profile: _profile(userId: 'fresh-user'),
          identities: const [],
        ),
      ),
      authRepository: authRepository,
    );
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .completeSignIn(
          AuthBundle(
            accessToken: 'old_access',
            refreshToken: 'old_refresh',
            profile: _profile(userId: 'old-user'),
            identities: const [],
          ),
        );
    await container.read(authControllerProvider.notifier).refreshSession();

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthStateAuthenticated>());
    expect(state.session?.accessToken, 'fresh_access');
    expect(
      await secureStore.read(AuthSessionStore.accessTokenKey),
      'fresh_access',
    );
  });

  test('refreshSession keeps failure state when refresh fails', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final secureStore = InMemorySecureKeyValueStore();
    final authRepository = _FakeAuthRepository()
      ..refreshError = ApiException(message: 'refresh failed', statusCode: 401);
    final container = _createContainer(
      database: database,
      secureStore: secureStore,
      profileRepository: _FakeProfileRepository(
        database: database,
        bundle: AccountBundle(
          profile: _profile(userId: 'old-user'),
          identities: const [],
        ),
      ),
      authRepository: authRepository,
    );
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .completeSignIn(
          AuthBundle(
            accessToken: 'old_access',
            refreshToken: 'old_refresh',
            profile: _profile(userId: 'old-user'),
            identities: const [],
          ),
        );
    await container.read(authControllerProvider.notifier).refreshSession();

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthStateFailure>());
    expect(state.session?.accessToken, 'old_access');
    expect(await secureStore.read(AuthSessionStore.accessTokenKey), isNull);
  });

  test('signOut clears secure tokens and drift user data', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final secureStore = InMemorySecureKeyValueStore();
    final profileRepository = _FakeProfileRepository(
      database: database,
      bundle: AccountBundle(
        profile: _profile(userId: 'signout-user'),
        identities: const [],
      ),
    );
    final container = _createContainer(
      database: database,
      secureStore: secureStore,
      profileRepository: profileRepository,
      authRepository: _FakeAuthRepository(),
    );
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .completeSignIn(
          AuthBundle(
            accessToken: 'signout_access',
            refreshToken: 'signout_refresh',
            profile: _profile(userId: 'signout-user'),
            identities: const [],
          ),
        );
    await database.saveProfilePayload(
      jsonEncode(_profile(userId: 'cached').toJson()),
    );

    await container.read(authControllerProvider.notifier).signOut();

    expect(
      container.read(authControllerProvider),
      isA<AuthStateUnauthenticated>(),
    );
    expect(await secureStore.read(AuthSessionStore.accessTokenKey), isNull);
    expect(await database.readProfilePayload(), isNull);
    expect(profileRepository.clearUserDataCallCount, 2);
  });

  test(
    'completeSignIn clears stale local user data before persisting new session',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final secureStore = InMemorySecureKeyValueStore();
      final profileRepository = _FakeProfileRepository(
        database: database,
        bundle: AccountBundle(
          profile: _profile(userId: 'new-user'),
          identities: const [],
        ),
      );
      final container = _createContainer(
        database: database,
        secureStore: secureStore,
        profileRepository: profileRepository,
        authRepository: _FakeAuthRepository(),
      );
      addTearDown(container.dispose);

      await database.saveProfilePayload(
        jsonEncode(_profile(userId: 'old-user').toJson()),
      );
      await database.saveCalendarDayPayload(
        date: '2026-04-16',
        timezone: AppConstants.defaultTimezone,
        payload: '[{"event_id":"old-event"}]',
      );
      await database.saveConversationState(
        storageScope: 'user:old-user',
        sessionId: 'old-session',
        conversation: const <StoredConversationEntryRecord>[
          StoredConversationEntryRecord(
            id: 'old-entry',
            isStreaming: false,
            payload: '{}',
          ),
        ],
      );

      await container
          .read(authControllerProvider.notifier)
          .completeSignIn(
            AuthBundle(
              accessToken: 'new_access',
              refreshToken: 'new_refresh',
              profile: _profile(userId: 'new-user'),
              identities: const [],
            ),
          );

      final storedProfile = await database.readProfilePayload();
      expect(storedProfile, isNotNull);
      expect(
        UserProfile.fromJson(
          jsonDecode(storedProfile!.payload) as Map<String, dynamic>,
        ).userId,
        'new-user',
      );
      expect(
        await database.readCalendarDayPayload(
          date: '2026-04-16',
          timezone: AppConstants.defaultTimezone,
        ),
        isNull,
      );
      expect(await database.readConversationState('user:old-user'), isNull);
      expect(profileRepository.clearUserDataCallCount, 1);
      expect(
        await secureStore.read(AuthSessionStore.accessTokenKey),
        'new_access',
      );
    },
  );

  test('signInWithEmailCode sends required push device payload', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final secureStore = InMemorySecureKeyValueStore();
    final authRepository = _FakeAuthRepository()
      ..emailResult = AuthBundle(
        accessToken: 'email_access',
        refreshToken: 'email_refresh',
        profile: _profile(userId: 'email-user'),
        identities: const [],
      );
    final container = _createContainer(
      database: database,
      secureStore: secureStore,
      profileRepository: _FakeProfileRepository(
        database: database,
        bundle: AccountBundle(
          profile: _profile(userId: 'email-user'),
          identities: const [],
        ),
      ),
      authRepository: authRepository,
      notificationBridge: _FakeCalendarNotificationBridge(
        registration: const RemoteNotificationRegistration(
          pushToken: 'push-token',
          appBundleId: 'com.ling.test',
          apnsEnvironment: 'development',
        ),
      ),
      deviceContextBridge: _FakeDeviceContextBridge(
        snapshot: const DeviceContextSnapshot(
          timezone: AppConstants.defaultTimezone,
          city: 'Shanghai',
        ),
      ),
      pushDeviceIdStore: PushDeviceIdStore(
        preferencesStore: const PreferencesStore(),
        storageKey: 'ling.test.push_device_id.email',
        idGenerator: () => 'device-login',
      ),
    );
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .signInWithEmailCode(email: 'a@example.com', code: '123456');

    expect(authRepository.emailPushDevice?.deviceId, 'device-login');
    expect(authRepository.emailPushDevice?.pushToken, 'push-token');
    expect(authRepository.emailPushDevice?.appBundleId, 'com.ling.test');
    expect(authRepository.emailPushDevice?.apnsEnvironment, 'development');
    expect(
      authRepository.emailPushDevice?.timezone,
      AppConstants.defaultTimezone,
    );
    expect(authRepository.emailPushDevice?.city, 'Shanghai');
    expect(
      await secureStore.read(AuthSessionStore.accessTokenKey),
      'email_access',
    );
  });

  test('all direct sign-in methods send push device payload', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final secureStore = InMemorySecureKeyValueStore();
    final authRepository = _FakeAuthRepository();
    final container = _createContainer(
      database: database,
      secureStore: secureStore,
      profileRepository: _FakeProfileRepository(
        database: database,
        bundle: AccountBundle(
          profile: _profile(userId: 'login-user'),
          identities: const [],
        ),
      ),
      authRepository: authRepository,
      notificationBridge: _FakeCalendarNotificationBridge(
        registration: const RemoteNotificationRegistration(
          pushToken: 'push-token',
          appBundleId: 'com.ling.test',
        ),
      ),
      deviceContextBridge: _FakeDeviceContextBridge(
        snapshot: const DeviceContextSnapshot(
          timezone: AppConstants.defaultTimezone,
        ),
      ),
      pushDeviceIdStore: PushDeviceIdStore(
        preferencesStore: const PreferencesStore(),
        storageKey: 'ling.test.push_device_id.direct',
        idGenerator: () => 'device-login',
      ),
    );
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);

    await controller.signInWithAliyunOneClickToken('one-click-token');
    await controller.signInWithAppleIdentityToken(identityToken: 'apple-token');
    await controller.signInWithWeChatAuthCode('wechat-code');

    expect(authRepository.aliyunPushDevice?.deviceId, 'device-login');
    expect(authRepository.applePushDevice?.deviceId, 'device-login');
    expect(authRepository.wechatPushDevice?.deviceId, 'device-login');
    expect(authRepository.aliyunPushDevice?.pushToken, 'push-token');
    expect(authRepository.applePushDevice?.pushToken, 'push-token');
    expect(authRepository.wechatPushDevice?.pushToken, 'push-token');
  });

  test(
    'signInWithEmailCode fails before token exchange when APNs token is empty',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final secureStore = InMemorySecureKeyValueStore();
      final authRepository = _FakeAuthRepository();
      final container = _createContainer(
        database: database,
        secureStore: secureStore,
        profileRepository: _FakeProfileRepository(
          database: database,
          bundle: AccountBundle(
            profile: _profile(userId: 'email-user'),
            identities: const [],
          ),
        ),
        authRepository: authRepository,
        notificationBridge: _FakeCalendarNotificationBridge(
          registration: const RemoteNotificationRegistration(pushToken: ''),
        ),
        deviceContextBridge: _FakeDeviceContextBridge(),
        pushDeviceIdStore: PushDeviceIdStore(
          preferencesStore: const PreferencesStore(),
          idGenerator: () => 'device-login',
        ),
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .signInWithEmailCode(email: 'a@example.com', code: '123456'),
        throwsA(isA<ApiException>()),
      );

      expect(authRepository.emailPushDevice, isNull);
      expect(await secureStore.read(AuthSessionStore.accessTokenKey), isNull);
    },
  );
}

String _accessTokenWithDeviceId(String deviceId) {
  String encodePart(Map<String, Object?> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  return [
    encodePart(<String, Object?>{'alg': 'HS256', 'typ': 'JWT'}),
    encodePart(<String, Object?>{'device_id': deviceId}),
    'signature',
  ].join('.');
}

ProviderContainer _createContainer({
  required AppDatabase database,
  required InMemorySecureKeyValueStore secureStore,
  required ProfileRepository profileRepository,
  required AuthRepository authRepository,
  CalendarNotificationBridge? notificationBridge,
  DeviceContextBridge? deviceContextBridge,
  PushDeviceIdStore? pushDeviceIdStore,
}) {
  final apiClient = ApiClient(httpClient: _NeverHttpClient());
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      apiClientProvider.overrideWithValue(apiClient),
      secureStorageProvider.overrideWithValue(secureStore),
      profileRepositoryProvider.overrideWithValue(profileRepository),
      authRepositoryProvider.overrideWithValue(authRepository),
      preferencesProvider.overrideWithValue(const PreferencesStore()),
      if (notificationBridge != null)
        calendarNotificationBridgeProvider.overrideWithValue(
          notificationBridge,
        ),
      if (deviceContextBridge != null)
        deviceContextBridgeProvider.overrideWithValue(deviceContextBridge),
      if (pushDeviceIdStore != null)
        pushDeviceIdStoreProvider.overrideWithValue(pushDeviceIdStore),
    ],
  );
}

UserProfile _profile({required String userId}) {
  return UserProfile(userId: userId, email: '$userId@example.com');
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository()
    : super(apiClient: ApiClient(httpClient: _NeverHttpClient()));

  AuthBundle? refreshResult;
  AuthBundle? emailResult;
  Object? refreshError;
  PushDeviceRegistrationRequest? emailPushDevice;
  PushDeviceRegistrationRequest? aliyunPushDevice;
  PushDeviceRegistrationRequest? applePushDevice;
  PushDeviceRegistrationRequest? wechatPushDevice;

  @override
  Future<AuthBundle> exchangeEmailCode({
    required String email,
    required String code,
    required PushDeviceRegistrationRequest pushDevice,
  }) async {
    emailPushDevice = pushDevice;
    return emailResult ??
        AuthBundle(
          accessToken: 'email_access',
          refreshToken: 'email_refresh',
          profile: _profile(userId: 'email-user'),
          identities: const [],
        );
  }

  @override
  Future<AuthBundle> exchangeAliyunOneClickToken(
    String token, {
    required PushDeviceRegistrationRequest pushDevice,
  }) async {
    aliyunPushDevice = pushDevice;
    return AuthBundle(
      accessToken: 'aliyun_access',
      refreshToken: 'aliyun_refresh',
      profile: _profile(userId: 'aliyun-user'),
      identities: const [],
    );
  }

  @override
  Future<AuthBundle> exchangeAppleIdentityToken({
    required String identityToken,
    required PushDeviceRegistrationRequest pushDevice,
    String? authorizationCode,
    Map<String, dynamic>? fullName,
  }) async {
    applePushDevice = pushDevice;
    return AuthBundle(
      accessToken: 'apple_access',
      refreshToken: 'apple_refresh',
      profile: _profile(userId: 'apple-user'),
      identities: const [],
    );
  }

  @override
  Future<AuthBundle> exchangeWeChatAuthCode(
    String authCode, {
    required PushDeviceRegistrationRequest pushDevice,
  }) async {
    wechatPushDevice = pushDevice;
    return AuthBundle(
      accessToken: 'wechat_access',
      refreshToken: 'wechat_refresh',
      profile: _profile(userId: 'wechat-user'),
      identities: const [],
    );
  }

  @override
  Future<AuthBundle> refreshToken(String refreshToken) async {
    if (refreshError case final ApiException error) {
      throw error;
    }
    if (refreshError != null) {
      throw ApiException(message: '$refreshError');
    }
    return refreshResult ??
        AuthBundle(
          accessToken: 'access',
          refreshToken: 'refresh',
          profile: _profile(userId: 'user'),
          identities: const [],
        );
  }
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository({required super.database, required this.bundle})
    : super(
        apiClient: ApiClient(httpClient: _NeverHttpClient()),
        cacheStore: JsonCacheStore(),
        privateAssetCacheStore: const _NoopPrivateAssetCacheStore(),
      );

  final AccountBundle bundle;
  Object? accountBundleError;
  int profileFetchCount = 0;
  int accountBundleFetchCount = 0;
  int clearUserDataCallCount = 0;

  @override
  Future<UserProfile> getProfile({bool forceRefresh = false}) async {
    profileFetchCount += 1;
    return bundle.profile;
  }

  @override
  Future<AccountBundle> getAccountBundle({bool forceRefresh = false}) async {
    accountBundleFetchCount += 1;
    final error = accountBundleError;
    if (error != null) {
      throw error;
    }
    return bundle;
  }

  @override
  Future<void> clearUserData() async {
    clearUserDataCallCount += 1;
    await super.clearUserData();
  }
}

class _NeverHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }
}

class _NoopPrivateAssetCacheStore implements PrivateAssetCacheStore {
  const _NoopPrivateAssetCacheStore();

  @override
  Future<int> sizeBytes() async => 0;

  @override
  Future<void> clear() async {}
}

class _FakeCalendarNotificationBridge implements CalendarNotificationBridge {
  _FakeCalendarNotificationBridge({this.registration});

  final RemoteNotificationRegistration? registration;

  @override
  Future<void> cancelAllNotifications() async {}

  @override
  Stream<ForegroundRemoteNotificationEvent>
  foregroundRemoteNotificationEvents() {
    return const Stream<ForegroundRemoteNotificationEvent>.empty();
  }

  @override
  Future<CalendarNotificationPermissionState> getPermissionState() async {
    return CalendarNotificationPermissionState.granted;
  }

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<RemoteNotificationRegistration?> registerRemoteNotifications() async {
    return registration;
  }

  @override
  Future<CalendarNotificationPermissionState> requestPermission() async {
    return CalendarNotificationPermissionState.granted;
  }

  @override
  Future<void> setApplicationBadgeCount(int count) async {}

  @override
  Future<void> setForegroundNotificationContext(String context) async {}

  @override
  Future<void> syncNotifications(
    List<CalendarNotificationRequest> notifications,
  ) async {}
}

class _FakeDeviceContextBridge implements DeviceContextBridge {
  _FakeDeviceContextBridge({this.snapshot});

  final DeviceContextSnapshot? snapshot;

  @override
  Future<void> configureBackend({
    required String apiBaseUrl,
    required String apiPrefix,
  }) async {}

  @override
  Future<DeviceContextSnapshot?> getLatestContext({
    bool startTracking = false,
  }) async {
    return snapshot;
  }

  @override
  Future<DeviceLocationPermissionState> getLocationPermissionState() async {
    return DeviceLocationPermissionState.notDetermined;
  }

  @override
  Future<DeviceContextSnapshot?> requestForegroundLocationContext() async {
    return snapshot;
  }

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<void> startTracking() async {}

  @override
  Future<void> stopTracking() async {}
}
