import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ling/src/core/cache/json_cache_store.dart';
import 'package:ling/src/core/database/app_database.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/storage/local_persistence_policy.dart';
import 'package:ling/src/core/storage/preferences_store.dart';
import 'package:ling/src/core/storage/private_asset_cache_store.dart';
import 'package:ling/src/core/storage/secure_key_value_store.dart';

final preferencesProvider = Provider<PreferencesStore>(
  (ref) => const PreferencesStore(),
);

final secureStorageProvider = Provider<SecureKeyValueStore>(
  (ref) => FlutterSecureKeyValueStore(),
);

final localPersistencePolicyProvider = Provider<LocalPersistencePolicy>(
  (ref) => const LocalPersistencePolicy(),
);

final privateAssetCacheStoreProvider = Provider<PrivateAssetCacheStore>(
  (ref) => const DefaultPrivateAssetCacheStore(),
);

final jsonCacheStoreProvider = Provider<JsonCacheStore>(
  (ref) => JsonCacheStore(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dispose);
  return client;
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
