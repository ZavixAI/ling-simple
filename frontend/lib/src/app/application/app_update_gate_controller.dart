import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/data/app_store_launcher.dart';
import 'package:ling/src/app/data/app_version_policy_repository.dart';
import 'package:ling/src/app/models/app_version_policy.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/core/platform/bridges/app_runtime_bridge.dart';
import 'package:ling/src/core/providers.dart';

enum AppUpdateGateStatus { checking, passed, required }

class AppUpdateGateState {
  const AppUpdateGateState({required this.status, this.policy});

  const AppUpdateGateState.checking()
    : status = AppUpdateGateStatus.checking,
      policy = null;

  const AppUpdateGateState.passed({this.policy})
    : status = AppUpdateGateStatus.passed;

  const AppUpdateGateState.required(this.policy)
    : status = AppUpdateGateStatus.required;

  final AppUpdateGateStatus status;
  final AppVersionPolicy? policy;

  bool get canEnterApp => status == AppUpdateGateStatus.passed;
}

final appVersionPolicyRepositoryProvider = Provider<AppVersionPolicyRepository>(
  (ref) => AppVersionPolicyRepository(apiClient: ref.read(apiClientProvider)),
);

final appStoreLauncherProvider = Provider<AppStoreLauncher>(
  (ref) => const UrlLauncherAppStoreLauncher(),
);

final appRuntimeBridgeProvider = Provider<AppRuntimeBridge>(
  (ref) => const MethodChannelAppRuntimeBridge(),
);

final appUpdateGateControllerProvider =
    NotifierProvider<AppUpdateGateController, AppUpdateGateState>(
      AppUpdateGateController.new,
    );

class AppUpdateGateController extends Notifier<AppUpdateGateState> {
  @override
  AppUpdateGateState build() => const AppUpdateGateState.checking();

  Future<void> check() async {
    state = const AppUpdateGateState.checking();
    try {
      if (await _isRunningOnSimulator()) {
        state = const AppUpdateGateState.passed();
        return;
      }
      final policy = await ref
          .read(appVersionPolicyRepositoryProvider)
          .getVersionPolicy(platform: AppPlatformInfo.current);
      state = policy.shouldBlockApp
          ? AppUpdateGateState.required(policy)
          : AppUpdateGateState.passed(policy: policy);
    } catch (error, stackTrace) {
      AppLogger.warn(
        '[Ling][AppUpdate] 版本策略检查失败，放行进入 app：$error',
        category: 'app_update',
        fields: <String, Object?>{'stack_trace': '$stackTrace'},
      );
      state = const AppUpdateGateState.passed();
    }
  }

  Future<bool> _isRunningOnSimulator() async {
    try {
      return await ref.read(appRuntimeBridgeProvider).isRunningOnSimulator();
    } catch (error, stackTrace) {
      AppLogger.warn(
        '[Ling][AppUpdate] 模拟器环境检查失败，继续执行版本策略：$error',
        category: 'app_update',
        fields: <String, Object?>{'stack_trace': '$stackTrace'},
      );
      return false;
    }
  }
}
