import 'package:flutter/foundation.dart';

class AppEnvironment {
  const AppEnvironment._();

  static const String appName = String.fromEnvironment(
    'LING_APP_NAME',
    defaultValue: 'Ling',
  );

  static const String flavor = String.fromEnvironment(
    'LING_FLAVOR',
    defaultValue: 'local',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'LING_API_BASE_URL',
    defaultValue: 'https://api.withling.top',
  );

  static const String apiPrefix = String.fromEnvironment(
    'LING_API_PREFIX',
    defaultValue: '/ling-api',
  );

  static const String platformHint = String.fromEnvironment(
    'LING_TARGET_PLATFORM',
    defaultValue: '',
  );

  static const String appVersion = String.fromEnvironment(
    'LING_APP_VERSION',
    defaultValue: '1.0.1+2026060101',
  );

  static String get appVersionName {
    final separator = appVersion.indexOf('+');
    if (separator < 0) {
      return appVersion;
    }
    return appVersion.substring(0, separator);
  }

  static String get appBuildNumber {
    final separator = appVersion.indexOf('+');
    if (separator < 0 || separator >= appVersion.length - 1) {
      return '';
    }
    return appVersion.substring(separator + 1);
  }

  static bool get isLocalFlavor => flavor.trim().toLowerCase() == 'local';

  static bool allowsInsecureHttpBaseUrl({
    bool? isDebugBuild,
    String? flavorOverride,
  }) {
    final effectiveFlavor = (flavorOverride ?? flavor).trim().toLowerCase();
    return (isDebugBuild ?? kDebugMode) || effectiveFlavor == 'local';
  }

  static void validateConfiguration({
    String? apiBaseUrlOverride,
    bool? isDebugBuild,
    String? flavorOverride,
  }) {
    final normalizedBaseUrl = (apiBaseUrlOverride ?? apiBaseUrl).trim();
    if (!normalizedBaseUrl.toLowerCase().startsWith('http://')) {
      return;
    }
    if (allowsInsecureHttpBaseUrl(
      isDebugBuild: isDebugBuild,
      flavorOverride: flavorOverride,
    )) {
      return;
    }
    throw StateError(
      'LING_API_BASE_URL must use HTTPS outside local or debug builds.',
    );
  }

  static Uri endpoint(String path, {Map<String, Object?>? queryParameters}) {
    validateConfiguration();
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final resolved = Uri.parse(
      apiBaseUrl,
    ).resolve('$_normalizedPrefix$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return resolved;
    }

    final mergedParameters = <String, String>{
      ...resolved.queryParameters,
      for (final entry in queryParameters.entries)
        if (entry.value != null) entry.key: '${entry.value}',
    };
    return resolved.replace(
      queryParameters: mergedParameters.isEmpty ? null : mergedParameters,
    );
  }

  static Uri resolveUrl(String path) {
    validateConfiguration();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(apiBaseUrl).resolve(normalizedPath);
  }

  static String get _normalizedPrefix {
    if (apiPrefix.isEmpty) {
      return '';
    }

    if (apiPrefix.startsWith('/')) {
      return apiPrefix.endsWith('/') && apiPrefix.length > 1
          ? apiPrefix.substring(0, apiPrefix.length - 1)
          : apiPrefix;
    }

    return '/$apiPrefix';
  }
}
