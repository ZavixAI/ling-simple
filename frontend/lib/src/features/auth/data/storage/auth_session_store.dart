import 'package:ling/src/core/storage/secure_key_value_store.dart';

class RestoredAuthSession {
  const RestoredAuthSession({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

class AuthSessionStore {
  AuthSessionStore({required SecureKeyValueStore secureStore})
    : _secureStore = secureStore;
  static const String accessTokenKey = 'ling.secure.access_token';
  static const String refreshTokenKey = 'ling.secure.refresh_token';

  final SecureKeyValueStore _secureStore;

  Future<RestoredAuthSession?> restore() async {
    final secureAccessToken = (await _secureStore.read(accessTokenKey))?.trim();
    final secureRefreshToken = (await _secureStore.read(
      refreshTokenKey,
    ))?.trim();
    if ((secureAccessToken ?? '').isNotEmpty &&
        (secureRefreshToken ?? '').isNotEmpty) {
      return RestoredAuthSession(
        accessToken: secureAccessToken!,
        refreshToken: secureRefreshToken!,
      );
    }
    return null;
  }

  Future<void> persistTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStore.write(accessTokenKey, accessToken);
    await _secureStore.write(refreshTokenKey, refreshToken);
  }

  Future<void> clear() async {
    await _secureStore.delete(accessTokenKey);
    await _secureStore.delete(refreshTokenKey);
  }
}
