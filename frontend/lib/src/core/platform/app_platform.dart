import 'package:flutter/foundation.dart';

import 'package:ling/src/config/app_environment.dart';

enum AppPlatform {
  web,
  ios,
  android,
  macos,
  windows,
  linux,
  fuchsia,
  ohos,
  unknown,
}

class AppPlatformInfo {
  const AppPlatformInfo._();

  static AppPlatform get current {
    if (AppEnvironment.platformHint.toLowerCase() == 'ohos') {
      return AppPlatform.ohos;
    }

    if (kIsWeb) {
      return AppPlatform.web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return AppPlatform.ios;
      case TargetPlatform.android:
        return AppPlatform.android;
      case TargetPlatform.macOS:
        return AppPlatform.macos;
      case TargetPlatform.windows:
        return AppPlatform.windows;
      case TargetPlatform.linux:
        return AppPlatform.linux;
      case TargetPlatform.fuchsia:
        return AppPlatform.fuchsia;
    }
  }

  static String get label {
    switch (current) {
      case AppPlatform.web:
        return 'Web';
      case AppPlatform.ios:
        return 'iOS';
      case AppPlatform.android:
        return 'Android';
      case AppPlatform.macos:
        return 'macOS';
      case AppPlatform.windows:
        return 'Windows';
      case AppPlatform.linux:
        return 'Linux';
      case AppPlatform.fuchsia:
        return 'Fuchsia';
      case AppPlatform.ohos:
        return 'HarmonyOS';
      case AppPlatform.unknown:
        return 'Unknown';
    }
  }
}

bool isNativeLingBridgeSupported({AppPlatform? platform}) {
  final current = platform ?? AppPlatformInfo.current;
  return current == AppPlatform.ios || current == AppPlatform.ohos;
}
