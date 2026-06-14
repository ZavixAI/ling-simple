import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ling/src/app/app.dart';
import 'package:ling/src/app/application/app_update_gate_controller.dart';
import 'package:ling/src/app/data/app_store_launcher.dart';
import 'package:ling/src/app/data/app_version_policy_repository.dart';
import 'package:ling/src/app/models/app_version_policy.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/core/platform/bridges/app_runtime_bridge.dart';
import 'package:ling/src/features/auth/application/auth_controller.dart';
import 'package:ling/src/features/auth/application/auth_state.dart';
import 'package:ling/src/features/settings/application/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _FakeAuthController.restoreSessionCalls = 0;
  });

  testWidgets('shows force update page and skips session restore', (
    tester,
  ) async {
    final launcher = _FakeAppStoreLauncher();

    await _pumpLingApp(
      tester,
      repository: _FakeAppVersionPolicyRepository(
        policy: const AppVersionPolicy(
          platform: 'ios',
          minimumVersion: '1.0.2',
          minimumBuild: 2026060101,
          currentVersion: '1.0.1',
          currentBuild: 2026041101,
          updateRequired: true,
          updateUrl: 'https://testflight.apple.com/join/JfEr7hyq',
        ),
      ),
      launcher: launcher,
    );

    expect(find.byKey(const Key('force_update_title')), findsOneWidget);
    expect(find.byKey(const Key('test_home')), findsNothing);
    expect(_FakeAuthController.restoreSessionCalls, 0);

    await tester.tap(find.byKey(const Key('force_update_button')));
    await tester.pump();

    expect(launcher.openedUris, [
      Uri.parse('https://testflight.apple.com/join/JfEr7hyq'),
    ]);
  });

  testWidgets('enters app and restores session when update is not required', (
    tester,
  ) async {
    await _pumpLingApp(
      tester,
      repository: _FakeAppVersionPolicyRepository(
        policy: const AppVersionPolicy(
          platform: 'ios',
          minimumVersion: '1.0.1',
          minimumBuild: 2026041101,
          currentVersion: '1.0.1',
          currentBuild: 2026041101,
          updateRequired: false,
          updateUrl: 'https://testflight.apple.com/join/JfEr7hyq',
        ),
      ),
    );

    expect(find.byKey(const Key('test_home')), findsOneWidget);
    expect(find.byKey(const Key('force_update_title')), findsNothing);
    expect(_FakeAuthController.restoreSessionCalls, 1);
  });

  testWidgets('enters app and restores session when update check fails', (
    tester,
  ) async {
    await _pumpLingApp(
      tester,
      repository: _FakeAppVersionPolicyRepository(error: StateError('offline')),
    );

    expect(find.byKey(const Key('test_home')), findsOneWidget);
    expect(find.byKey(const Key('force_update_title')), findsNothing);
    expect(_FakeAuthController.restoreSessionCalls, 1);
  });

  testWidgets('skips force update on simulator', (tester) async {
    final repository = _FakeAppVersionPolicyRepository(
      policy: const AppVersionPolicy(
        platform: 'ios',
        minimumVersion: '9.9.9',
        minimumBuild: 1,
        currentVersion: '1.0.2',
        currentBuild: 2026060101,
        updateRequired: true,
        updateUrl: 'https://testflight.apple.com/join/JfEr7hyq',
      ),
    );

    await _pumpLingApp(
      tester,
      repository: repository,
      appRuntimeBridge: const _FakeAppRuntimeBridge(isSimulator: true),
    );

    expect(find.byKey(const Key('test_home')), findsOneWidget);
    expect(find.byKey(const Key('force_update_title')), findsNothing);
    expect(repository.getPolicyCalls, 0);
    expect(_FakeAuthController.restoreSessionCalls, 1);
  });
}

Future<void> _pumpLingApp(
  WidgetTester tester, {
  required _FakeAppVersionPolicyRepository repository,
  _FakeAppStoreLauncher? launcher,
  _FakeAppRuntimeBridge appRuntimeBridge = const _FakeAppRuntimeBridge(),
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          initialLingLocaleCodeProvider.overrideWithValue('zh-CN'),
          appVersionPolicyRepositoryProvider.overrideWithValue(repository),
          appStoreLauncherProvider.overrideWithValue(
            launcher ?? _FakeAppStoreLauncher(),
          ),
          appRuntimeBridgeProvider.overrideWithValue(appRuntimeBridge),
          authControllerProvider.overrideWith(_FakeAuthController.new),
        ],
        child: const LingApp(homeOverride: SizedBox(key: Key('test_home'))),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

class _FakeAppVersionPolicyRepository extends AppVersionPolicyRepository {
  _FakeAppVersionPolicyRepository({this.policy, this.error})
    : super(apiClient: ApiClient(httpClient: _NeverHttpClient()));

  final AppVersionPolicy? policy;
  final Object? error;
  int getPolicyCalls = 0;

  @override
  Future<AppVersionPolicy> getVersionPolicy({
    required AppPlatform platform,
    String? version,
  }) async {
    getPolicyCalls += 1;
    final thrown = error;
    if (thrown != null) {
      throw thrown;
    }
    return policy ??
        const AppVersionPolicy(
          platform: 'ios',
          minimumVersion: '0.0.0',
          minimumBuild: 0,
          currentVersion: '1.0.1',
          currentBuild: 2026041101,
          updateRequired: false,
          updateUrl: null,
        );
  }
}

class _FakeAppRuntimeBridge implements AppRuntimeBridge {
  const _FakeAppRuntimeBridge({this.isSimulator = false});

  final bool isSimulator;

  @override
  Future<bool> isRunningOnSimulator() async => isSimulator;
}

class _FakeAppStoreLauncher implements AppStoreLauncher {
  final openedUris = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    openedUris.add(uri);
    return true;
  }
}

class _FakeAuthController extends AuthController {
  static int restoreSessionCalls = 0;

  @override
  AuthState build() => const AuthStateUnauthenticated();

  @override
  Future<void> restoreSession() async {
    restoreSessionCalls += 1;
    state = const AuthStateUnauthenticated();
  }
}

class _NeverHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }
}
