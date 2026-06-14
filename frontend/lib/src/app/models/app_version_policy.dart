class AppVersionPolicy {
  const AppVersionPolicy({
    required this.platform,
    required this.minimumVersion,
    required this.minimumBuild,
    required this.currentVersion,
    required this.currentBuild,
    required this.updateRequired,
    required this.updateUrl,
  });

  final String platform;
  final String minimumVersion;
  final int minimumBuild;
  final String currentVersion;
  final int currentBuild;
  final bool updateRequired;
  final String? updateUrl;

  String? get appStoreUrl => updateUrl;

  bool get shouldBlockApp =>
      updateRequired && (updateUrl ?? '').trim().isNotEmpty;

  factory AppVersionPolicy.fromJson(Map<String, dynamic> json) {
    return AppVersionPolicy(
      platform: '${json['platform'] ?? ''}'.trim(),
      minimumVersion: '${json['minimum_version'] ?? '0.0.0'}'.trim(),
      minimumBuild: _normalizedInt(json['minimum_build']),
      currentVersion: '${json['current_version'] ?? ''}'.trim(),
      currentBuild: _normalizedInt(json['current_build']),
      updateRequired: json['update_required'] == true,
      updateUrl:
          _normalizedNullable(json['update_url']) ??
          _normalizedNullable(json['app_store_url']),
    );
  }
}

String? _normalizedNullable(Object? value) {
  final normalized = '${value ?? ''}'.trim();
  return normalized.isEmpty ? null : normalized;
}

int _normalizedInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse('${value ?? ''}'.trim()) ?? 0;
}
