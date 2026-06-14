import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ling/src/config/constants.dart';
import 'package:ling/src/core/cache/json_cache_store.dart';
import 'package:ling/src/core/database/app_database.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/storage/private_asset_cache_store.dart';
import 'package:ling/src/features/auth/data/repositories/profile_repository.dart';
import 'package:ling/src/features/auth/models/user_models.dart';

void main() {
  test('updatePreferences persists the latest profile bundle', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final cacheStore = JsonCacheStore();
    final repository = ProfileRepository(
      apiClient: ApiClient(
        httpClient: _FakeHttpClient(
          responses: <_FakeResponse>[
            _FakeResponse(
              method: 'PATCH',
              path: '/ling-api/me',
              body: <String, Object?>{
                'profile': <String, Object?>{
                  'user_id': 'user-1',
                  'nickname': 'Ling',
                  'email': 'ling@example.com',
                  'phonenum': '+8613800138000',
                  'avatar_url': '/uploads/avatar.png',
                  'preferences': <String, Object?>{'locale': 'en-US'},
                },
                'identities': const <Object?>[],
              },
            ),
          ],
        ),
      ),
      cacheStore: cacheStore,
      database: database,
    );
    final existingProfile = const UserProfile(
      userId: 'user-1',
      nickname: 'Ling',
      email: 'ling@example.com',
      phoneNumber: '+8613800138000',
      avatarUrl: '/uploads/avatar.png',
      preferences: UserPreferences(
        timezone: AppConstants.defaultTimezone,
        locale: 'zh-CN',
        themeMode: 'dark',
      ),
    );
    await database.saveProfilePayload(jsonEncode(existingProfile.toJson()));

    final updated = await repository.updatePreferences(
      const UserPreferencesPatch(locale: 'en-US'),
    );

    expect(updated.userId, 'user-1');
    expect(updated.nickname, 'Ling');
    expect(updated.email, 'ling@example.com');
    expect(updated.phoneNumber, '+8613800138000');
    expect(updated.avatarUrl, '/uploads/avatar.png');
    expect(updated.preferences?.locale, 'en-US');
    final stored = await database.readProfilePayload();
    expect(stored, isNotNull);
    final persisted = UserProfile.fromJson(
      jsonDecode(stored!.payload) as Map<String, dynamic>,
    );
    expect(persisted.email, 'ling@example.com');
    expect(persisted.preferences?.locale, 'en-US');
  });

  test('clearUserData clears drift data and private asset caches', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final privateAssetCacheStore = _FakePrivateAssetCacheStore();
    final repository = ProfileRepository(
      apiClient: ApiClient(httpClient: _FakeHttpClient(responses: const [])),
      cacheStore: JsonCacheStore(),
      database: database,
      privateAssetCacheStore: privateAssetCacheStore,
    );
    await database.saveProfilePayload(
      jsonEncode(
        const UserProfile(userId: 'user-1', email: 'ling@example.com').toJson(),
      ),
    );

    await repository.clearUserData();

    expect(await database.readProfilePayload(), isNull);
    expect(privateAssetCacheStore.clearCallCount, 1);
  });

  test(
    'clearUserData rethrows objective_c cache clear failures after deleting local data',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final privateAssetCacheStore = _ThrowingPrivateAssetCacheStore(
        ArgumentError(
          "Couldn't resolve native function 'DOBJC_initializeApi' in "
          "'package:objective_c/objective_c.dylib'",
        ),
      );
      final repository = ProfileRepository(
        apiClient: ApiClient(httpClient: _FakeHttpClient(responses: const [])),
        cacheStore: JsonCacheStore(),
        database: database,
        privateAssetCacheStore: privateAssetCacheStore,
      );
      await database.saveProfilePayload(
        jsonEncode(
          const UserProfile(
            userId: 'user-1',
            email: 'ling@example.com',
          ).toJson(),
        ),
      );

      await expectLater(repository.clearUserData(), throwsArgumentError);

      expect(await database.readProfilePayload(), isNull);
      expect(privateAssetCacheStore.clearCallCount, 1);
    },
  );

  test('clearUserData rethrows unrelated cache clear failures', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final privateAssetCacheStore = _ThrowingPrivateAssetCacheStore(
      StateError('unexpected cache error'),
    );
    final repository = ProfileRepository(
      apiClient: ApiClient(httpClient: _FakeHttpClient(responses: const [])),
      cacheStore: JsonCacheStore(),
      database: database,
      privateAssetCacheStore: privateAssetCacheStore,
    );

    await expectLater(repository.clearUserData(), throwsStateError);
    expect(privateAssetCacheStore.clearCallCount, 1);
  });
}

class _FakeResponse {
  const _FakeResponse({
    required this.method,
    required this.path,
    required this.body,
  });

  final String method;
  final String path;
  final Object? body;
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient({required List<_FakeResponse> responses})
    : _responses = List<_FakeResponse>.from(responses);

  final List<_FakeResponse> _responses;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_responses.isEmpty) {
      throw StateError(
        'No fake response configured for ${request.method} ${request.url.path}',
      );
    }
    final next = _responses.removeAt(0);
    expect(request.method, next.method);
    expect(request.url.path, next.path);
    final payload = jsonEncode(<String, Object?>{
      'code': 200,
      'message': 'ok',
      'data': next.body,
      'timestamp': '2026-04-05T00:00:00Z',
    });
    final bytes = utf8.encode(payload);
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}

class _FakePrivateAssetCacheStore implements PrivateAssetCacheStore {
  int clearCallCount = 0;

  @override
  Future<int> sizeBytes() async => 0;

  @override
  Future<void> clear() async {
    clearCallCount += 1;
  }
}

class _ThrowingPrivateAssetCacheStore implements PrivateAssetCacheStore {
  _ThrowingPrivateAssetCacheStore(this.error);

  final Object error;
  int clearCallCount = 0;

  @override
  Future<int> sizeBytes() async => 0;

  @override
  Future<void> clear() async {
    clearCallCount += 1;
    throw error;
  }
}
