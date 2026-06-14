enum CalendarProviderId { appleLocal, feishu, dingtalk }

CalendarProviderId calendarProviderIdFromRaw(String value) {
  switch (value.trim().toLowerCase()) {
    case 'apple_local':
      return CalendarProviderId.appleLocal;
    case 'feishu':
      return CalendarProviderId.feishu;
    case 'dingtalk':
      return CalendarProviderId.dingtalk;
    default:
      return CalendarProviderId.appleLocal;
  }
}

String calendarProviderIdToRaw(CalendarProviderId value) {
  switch (value) {
    case CalendarProviderId.appleLocal:
      return 'apple_local';
    case CalendarProviderId.feishu:
      return 'feishu';
    case CalendarProviderId.dingtalk:
      return 'dingtalk';
  }
}

enum CalendarConnectionAction { authorize, refresh, retry, manageSystem }

class CalendarConnectionSummary {
  const CalendarConnectionSummary({
    required this.providerId,
    required this.providerName,
    required this.kind,
    required this.status,
    required this.isEnabled,
    required this.isConnected,
    required this.eventCount,
    this.lastSyncedAt,
    this.lastError,
    this.accountLabel,
    this.metadata = const <String, dynamic>{},
  });

  final CalendarProviderId providerId;
  final String providerName;
  final String kind;
  final String status;
  final bool isEnabled;
  final bool isConnected;
  final int eventCount;
  final String? lastSyncedAt;
  final String? lastError;
  final String? accountLabel;
  final Map<String, dynamic> metadata;

  bool get isAppleLocal => providerId == CalendarProviderId.appleLocal;

  factory CalendarConnectionSummary.fromJson(Map<String, dynamic> json) {
    return CalendarConnectionSummary(
      providerId: calendarProviderIdFromRaw('${json['provider_id'] ?? ''}'),
      providerName: '${json['provider_name'] ?? ''}',
      kind: '${json['kind'] ?? ''}',
      status: '${json['status'] ?? ''}',
      isEnabled: json['is_enabled'] != false,
      isConnected: json['is_connected'] == true,
      eventCount: json['event_count'] is int
          ? json['event_count'] as int
          : int.tryParse('${json['event_count'] ?? ''}') ?? 0,
      lastSyncedAt: json['last_synced_at']?.toString(),
      lastError: json['last_error']?.toString(),
      accountLabel: json['account_label']?.toString(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }
}

class CalendarOAuthStartResponse {
  const CalendarOAuthStartResponse({
    required this.providerId,
    required this.authorizeUrl,
    required this.callbackScheme,
  });

  final CalendarProviderId providerId;
  final String authorizeUrl;
  final String callbackScheme;

  factory CalendarOAuthStartResponse.fromJson(Map<String, dynamic> json) {
    return CalendarOAuthStartResponse(
      providerId: calendarProviderIdFromRaw('${json['provider_id'] ?? ''}'),
      authorizeUrl: '${json['authorize_url'] ?? ''}',
      callbackScheme: '${json['callback_scheme'] ?? ''}',
    );
  }
}

class CalendarOAuthCompleteRequest {
  const CalendarOAuthCompleteRequest({required this.callbackUrl});

  final String callbackUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'callback_url': callbackUrl,
  };
}
