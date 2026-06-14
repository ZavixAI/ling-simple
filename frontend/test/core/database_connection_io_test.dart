import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/database/database_connection_io.dart';

void main() {
  test('resolveLingDatabaseDirectoryPath uses HOME on Apple platforms', () {
    final directoryPath = resolveLingDatabaseDirectoryPath(
      environment: const {
        'HOME': '/var/mobile/Containers/Data/Application/app',
      },
      isApplePlatform: true,
    );

    expect(
      directoryPath,
      '/var/mobile/Containers/Data/Application/app/Library/Application Support',
    );
  });

  test(
    'resolveLingDatabaseDirectoryPath falls back to TMPDIR when home is unavailable',
    () {
      final directoryPath = resolveLingDatabaseDirectoryPath(
        environment: const {
          'TMPDIR': '/var/mobile/Containers/Data/Application/app/tmp',
        },
        isApplePlatform: true,
      );

      expect(
        directoryPath,
        '/var/mobile/Containers/Data/Application/app/Library/Application Support',
      );
    },
  );

  test(
    'resolveLingDatabaseDirectoryPath falls back to system temp when environment is unavailable',
    () {
      final directoryPath = resolveLingDatabaseDirectoryPath(
        environment: const <String, String>{},
        isApplePlatform: true,
        systemTempPath: '/var/mobile/Containers/Data/Application/app/tmp',
      );

      expect(
        directoryPath,
        '/var/mobile/Containers/Data/Application/app/Library/Application Support',
      );
    },
  );

  test('resolveLingDatabaseDirectoryPath skips non-Apple platforms', () {
    final directoryPath = resolveLingDatabaseDirectoryPath(
      environment: const {'HOME': '/tmp/example'},
      isApplePlatform: false,
    );

    expect(directoryPath, isEmpty);
  });
}
