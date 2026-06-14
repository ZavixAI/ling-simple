enum LocalDataSensitivity { secret, privateEphemeral, nonSensitive }

enum LocalPersistenceTarget { secureStore, protectedDatabase, preferences }

class LocalPersistencePolicy {
  const LocalPersistencePolicy({this.allowPrivateProtectedPersistence = true});

  final bool allowPrivateProtectedPersistence;

  LocalPersistenceTarget targetFor(LocalDataSensitivity sensitivity) {
    return switch (sensitivity) {
      LocalDataSensitivity.secret => LocalPersistenceTarget.secureStore,
      LocalDataSensitivity.privateEphemeral =>
        allowPrivateProtectedPersistence
            ? LocalPersistenceTarget.protectedDatabase
            : LocalPersistenceTarget.preferences,
      LocalDataSensitivity.nonSensitive => LocalPersistenceTarget.preferences,
    };
  }

  bool canPersistToSecureStore(LocalDataSensitivity sensitivity) {
    return targetFor(sensitivity) == LocalPersistenceTarget.secureStore;
  }

  bool canPersistToProtectedDatabase(LocalDataSensitivity sensitivity) {
    return targetFor(sensitivity) == LocalPersistenceTarget.protectedDatabase;
  }

  bool canPersistToPreferences(LocalDataSensitivity sensitivity) {
    return targetFor(sensitivity) == LocalPersistenceTarget.preferences;
  }

  bool requiresAppleProtectedContainer(LocalDataSensitivity sensitivity) {
    return sensitivity == LocalDataSensitivity.privateEphemeral;
  }
}
