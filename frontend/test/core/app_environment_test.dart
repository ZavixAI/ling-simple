import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/config/app_environment.dart';

void main() {
  test(
    'validateConfiguration rejects insecure HTTP base URL in release mode',
    () {
      expect(
        () => AppEnvironment.validateConfiguration(
          apiBaseUrlOverride: 'http://api.example.com',
          isDebugBuild: false,
          flavorOverride: 'production',
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'validateConfiguration allows insecure HTTP base URL in local flavor',
    () {
      expect(
        () => AppEnvironment.validateConfiguration(
          apiBaseUrlOverride: 'http://127.0.0.1:8000',
          isDebugBuild: false,
          flavorOverride: 'local',
        ),
        returnsNormally,
      );
    },
  );

  test('validateConfiguration allows secure HTTPS base URL everywhere', () {
    expect(
      () => AppEnvironment.validateConfiguration(
        apiBaseUrlOverride: 'https://api.withling.top',
        isDebugBuild: false,
        flavorOverride: 'production',
      ),
      returnsNormally,
    );
  });
}
