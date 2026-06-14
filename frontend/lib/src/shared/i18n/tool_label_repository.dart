import 'dart:async';

import 'package:ling/src/core/cache/json_cache_store.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/network/json_payload_codec.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';

class LingToolLabelBundle {
  const LingToolLabelBundle({
    required this.version,
    required this.locale,
    required this.labels,
  });

  final String version;
  final String locale;
  final Map<String, String> labels;

  factory LingToolLabelBundle.fromJson(Object? value) {
    final json = asJsonMap(value);
    final rawLabels = json['labels'];
    final labels = <String, String>{};
    if (rawLabels is Map) {
      rawLabels.forEach((key, value) {
        final labelKey = '$key'.trim();
        final labelValue = '$value'.trim();
        if (labelKey.isNotEmpty && labelValue.isNotEmpty) {
          labels[labelKey] = labelValue;
        }
      });
    }
    return LingToolLabelBundle(
      version: '${json['version'] ?? ''}'.trim(),
      locale: '${json['locale'] ?? ''}'.trim(),
      labels: Map<String, String>.unmodifiable(labels),
    );
  }

  Map<String, dynamic> toJson() {
    return {'version': version, 'locale': locale, 'labels': labels};
  }
}

class ToolLabelRepository {
  ToolLabelRepository({
    required ApiClient apiClient,
    required JsonCacheStore cacheStore,
  }) : _apiClient = apiClient,
       _cacheStore = cacheStore;

  static const String _cachePrefix = 'ling.cache.v1.tool_labels.';
  static const Duration _cacheTtl = Duration(days: 1);

  final ApiClient _apiClient;
  final JsonCacheStore _cacheStore;
  final Set<String> _activeRefreshes = <String>{};

  Future<LingToolLabelBundle> loadToolLabels(
    String localeCode, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = '$_cachePrefix${_localeCacheKey(localeCode)}';
    final bundle = await _cacheStore.getOrLoad<LingToolLabelBundle>(
      cacheKey,
      ttl: _cacheTtl,
      forceRefresh: forceRefresh,
      loader: () => _fetchToolLabels(localeCode),
      decoder: LingToolLabelBundle.fromJson,
      encoder: (value) => value.toJson(),
    );
    _apply(bundle);
    return bundle;
  }

  void refreshForMissingTool(String localeCode, String toolName) {
    final localeKey = _localeCacheKey(localeCode);
    final requestKey = '$localeKey:${toolName.trim()}';
    if (!_activeRefreshes.add(requestKey)) {
      return;
    }
    unawaited(() async {
      try {
        await loadToolLabels(localeCode, forceRefresh: true);
      } catch (error) {
        AppLogger.warn(
          '[Ling][ToolLabels] refresh failed locale=$localeCode tool=$toolName error=$error',
          category: 'i18n',
        );
      } finally {
        _activeRefreshes.remove(requestKey);
      }
    }());
  }

  Future<LingToolLabelBundle> _fetchToolLabels(String localeCode) async {
    final response = await _apiClient.get(
      '/app/tool-labels',
      queryParameters: {'locale': localeCode},
    );
    return LingToolLabelBundle.fromJson(response.data);
  }

  void _apply(LingToolLabelBundle bundle) {
    LingStrings.registerToolLabels(bundle.locale, bundle.labels);
  }

  String _localeCacheKey(String localeCode) {
    return localeCode.trim().toLowerCase().startsWith('zh') ? 'zh' : 'en';
  }
}
