import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/storage/local_persistence_policy.dart';

void main() {
  test('secret data is restricted to secure storage', () {
    const policy = LocalPersistencePolicy();

    expect(
      policy.targetFor(LocalDataSensitivity.secret),
      LocalPersistenceTarget.secureStore,
    );
    expect(policy.canPersistToSecureStore(LocalDataSensitivity.secret), isTrue);
    expect(
      policy.canPersistToProtectedDatabase(LocalDataSensitivity.secret),
      isFalse,
    );
  });

  test('private data is routed to protected database persistence', () {
    const policy = LocalPersistencePolicy();

    expect(
      policy.targetFor(LocalDataSensitivity.privateEphemeral),
      LocalPersistenceTarget.protectedDatabase,
    );
    expect(
      policy.requiresAppleProtectedContainer(
        LocalDataSensitivity.privateEphemeral,
      ),
      isTrue,
    );
  });

  test('non-sensitive data is routed to preferences', () {
    const policy = LocalPersistencePolicy();

    expect(
      policy.targetFor(LocalDataSensitivity.nonSensitive),
      LocalPersistenceTarget.preferences,
    );
    expect(
      policy.canPersistToPreferences(LocalDataSensitivity.nonSensitive),
      isTrue,
    );
  });
}
