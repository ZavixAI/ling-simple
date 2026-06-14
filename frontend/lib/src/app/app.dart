import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/application/app_update_gate_controller.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/app/presentation/app_shell_page.dart';
import 'package:ling/src/app/presentation/app_update_gate_pages.dart';
import 'package:ling/src/config/app_environment.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/providers.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/auth/application/auth_controller.dart';
import 'package:ling/src/features/settings/application/settings_controller.dart';
import 'package:ling/src/shared/i18n/ling_locale.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

@visibleForTesting
ThemeMode parseLingAppThemeMode(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    default:
      return ThemeMode.system;
  }
}

@visibleForTesting
String serializeLingAppThemeMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

class LingApp extends ConsumerStatefulWidget {
  const LingApp({super.key, this.homeOverride});

  @visibleForTesting
  final Widget? homeOverride;

  @override
  ConsumerState<LingApp> createState() => _LingAppState();
}

class _LingAppState extends ConsumerState<LingApp> {
  static const String _themeModePreferenceKey = 'ling.theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  bool _didLogBuild = false;
  bool _didRequestSessionRestore = false;
  String? _lastToolLabelLocaleCode;

  @override
  void initState() {
    super.initState();
    AppLogger.info('[Ling][App] initState 开始');
    LingStrings.configureMissingToolLabelRefresh((localeCode, toolName) {
      ref
          .read(toolLabelRepositoryProvider)
          .refreshForMissingTool(localeCode, toolName);
    });
    _loadThemeMode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(appUpdateGateControllerProvider.notifier).check();
    });
  }

  @override
  void dispose() {
    LingStrings.configureMissingToolLabelRefresh(null);
    super.dispose();
  }

  Future<void> _loadThemeMode() async {
    AppLogger.debug('[Ling][App] _loadThemeMode 开始');
    final saved = await ref
        .read(preferencesProvider)
        .readString(_themeModePreferenceKey);
    if (!mounted) {
      AppLogger.warn('[Ling][App] _loadThemeMode 已中止：widget 未挂载');
      return;
    }
    final resolvedThemeMode = parseLingAppThemeMode(saved);
    if (_themeMode != resolvedThemeMode) {
      setState(() {
        _themeMode = resolvedThemeMode;
      });
    }
    AppLogger.debug(
      '[Ling][App] _loadThemeMode 完成 saved=$saved resolved=$resolvedThemeMode',
    );
  }

  Future<void> _handleThemeModeChanged(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    setState(() {
      _themeMode = mode;
    });
    await ref
        .read(preferencesProvider)
        .writeString(_themeModePreferenceKey, serializeLingAppThemeMode(mode));
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = ref.watch(
      settingsControllerProvider.select((state) => state.localeCode),
    );
    ref.read(apiClientProvider).setLocaleCode(localeCode);
    _refreshToolLabelsForLocale(localeCode);
    final updateGate = ref.watch(appUpdateGateControllerProvider);
    if (updateGate.canEnterApp && !_didRequestSessionRestore) {
      _didRequestSessionRestore = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(authControllerProvider.notifier).restoreSession();
      });
    }
    if (!_didLogBuild) {
      _didLogBuild = true;
      AppLogger.debug(
        '[Ling][App] build 执行 themeMode=$_themeMode localeCode=$localeCode',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppLogger.debug('[Ling][App] 首个 MaterialApp 帧已渲染');
      });
    }
    return MaterialApp(
      title: AppEnvironment.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      locale: localeFromLingLocaleCode(localeCode),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: lingSupportedLocales,
      builder: (context, child) {
        return GlassTheme(
          data: lingGlassThemeDataFor(context),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _buildHome(updateGate, localeCode),
    );
  }

  void _refreshToolLabelsForLocale(String localeCode) {
    if (_lastToolLabelLocaleCode == localeCode) {
      return;
    }
    _lastToolLabelLocaleCode = localeCode;
    unawaited(() async {
      try {
        await ref.read(toolLabelRepositoryProvider).loadToolLabels(localeCode);
      } catch (error) {
        AppLogger.warn(
          '[Ling][App] tool labels unavailable locale=$localeCode error=$error',
          category: 'i18n',
        );
      }
    }());
  }

  Widget _buildHome(AppUpdateGateState updateGate, String localeCode) {
    switch (updateGate.status) {
      case AppUpdateGateStatus.checking:
        return const AppUpdateCheckingPage();
      case AppUpdateGateStatus.required:
        return ForceUpdatePage(
          strings: LingStrings(localeCode),
          onUpdate: () {
            final rawUrl = updateGate.policy?.updateUrl?.trim() ?? '';
            final uri = Uri.tryParse(rawUrl);
            if (uri == null) {
              return;
            }
            unawaited(ref.read(appStoreLauncherProvider).open(uri));
          },
        );
      case AppUpdateGateStatus.passed:
        return widget.homeOverride ??
            LingCalendarHomePage(
              themeMode: _themeMode,
              onThemeModeChanged: _handleThemeModeChanged,
            );
    }
  }
}
