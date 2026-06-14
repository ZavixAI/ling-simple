import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/app.dart';
import 'package:ling/src/config/app_environment.dart';
import 'package:ling/src/core/database/app_database.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/platform/bridges/device_context_bridge.dart';
import 'package:ling/src/core/providers.dart';
import 'package:ling/src/core/storage/app_preferences.dart';
import 'package:ling/src/core/storage/preferences_store.dart';
import 'package:ling/src/features/settings/application/settings_controller.dart';
import 'package:ling/src/shared/i18n/ling_locale.dart';
import 'package:ling/src/shared/models/font_size_preference.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

Future<void> bootstrap() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
      await AppPreferences.ensureInitialized();
      final appDatabase = AppDatabase();
      AppLogger.info('[Ling][Bootstrap] bootstrap() 开始', category: 'bootstrap');
      await _lockApplePortraitOrientation();
      AppEnvironment.validateConfiguration();
      final preferencesStore = const PreferencesStore();
      final savedLocaleCode = await preferencesStore.readString(
        lingLocalePreferenceKey,
      );
      final initialLocaleCode = resolveInitialLingLocaleCode(
        savedLocaleCode: savedLocaleCode,
      );
      final initialFontSizeLevel =
          deserializeLingFontSizeLevel(
            await preferencesStore.readString(lingFontSizeLevelPreferenceKey),
          ) ??
          LingFontSizeLevel.fallback;
      if (savedLocaleCode?.trim() != initialLocaleCode) {
        await preferencesStore.writeString(
          lingLocalePreferenceKey,
          initialLocaleCode,
        );
      }
      AppLogger.info(
        '[Ling][Bootstrap] WidgetsFlutterBinding 已初始化',
        category: 'bootstrap',
      );
      AppLogger.info(
        '[Ling][Bootstrap] 环境 app=${AppEnvironment.appName} '
        'flavor=${AppEnvironment.flavor} '
        'baseUrl=${AppEnvironment.apiBaseUrl} '
        'prefix=${AppEnvironment.apiPrefix}',
        category: 'bootstrap',
      );
      AppLogger.info(
        '[Ling][Bootstrap] 语言 saved=$savedLocaleCode '
        'initial=$initialLocaleCode',
        category: 'bootstrap',
      );
      await MethodChannelDeviceContextBridge().configureBackend(
        apiBaseUrl: AppEnvironment.apiBaseUrl,
        apiPrefix: AppEnvironment.apiPrefix,
      );

      FlutterError.onError = (details) {
        AppLogger.error(
          '[Ling][Bootstrap] FlutterError：${details.exceptionAsString()}',
          category: 'error',
          stackTrace: details.stack,
        );
        FlutterError.presentError(details);
      };
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        AppLogger.error(
          '[Ling][Bootstrap] 平台错误：$error',
          category: 'error',
          stackTrace: stackTrace,
        );
        return false;
      };

      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppLogger.debug('[Ling][Bootstrap] 首帧已渲染', category: 'bootstrap');
      });

      AppLogger.info('[Ling][Bootstrap] 调用 runApp()', category: 'bootstrap');
      runApp(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: true,
          child: ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWith((ref) {
                ref.onDispose(appDatabase.close);
                return appDatabase;
              }),
              initialLingLocaleCodeProvider.overrideWithValue(
                initialLocaleCode,
              ),
              initialLingFontSizeLevelProvider.overrideWithValue(
                initialFontSizeLevel,
              ),
            ],
            child: const LingApp(),
          ),
        ),
      );
      AppLogger.debug('[Ling][Bootstrap] runApp() 已返回', category: 'bootstrap');
    },
    (error, stackTrace) {
      AppLogger.error(
        '[Ling][Bootstrap] 未处理的应用错误：$error',
        category: 'error',
        stackTrace: stackTrace,
      );
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        if (!AppLogger.isWritingToConsole &&
            !_looksLikeAppLoggerConsoleLine(line)) {
          AppLogger.captureConsoleLine(line, category: 'zone');
        }
        parent.print(zone, line);
      },
    ),
  );
}

Future<void> _lockApplePortraitOrientation() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }

  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  AppLogger.info('[Ling][Bootstrap] 已将 iOS 方向锁定为竖屏', category: 'bootstrap');
}

bool _looksLikeAppLoggerConsoleLine(String line) {
  return line.startsWith('[DEBUG] ') ||
      line.startsWith('[INFO] ') ||
      line.startsWith('[WARN] ') ||
      line.startsWith('[ERROR] ');
}
