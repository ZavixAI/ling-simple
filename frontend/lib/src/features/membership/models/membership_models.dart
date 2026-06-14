import 'package:ling/src/config/constants.dart';

class MembershipSummary {
  const MembershipSummary({
    required this.tierCode,
    required this.accessState,
    required this.renewalType,
    required this.provider,
    required this.startedAt,
    required this.paidThroughAt,
    required this.cancelAtPeriodEnd,
    required this.dailyChatLimit,
    required this.dailyChatUsed,
    required this.dailyChatRemaining,
    required this.businessTimezone,
    required this.serverNow,
    required this.entitlements,
    required this.pointsBalance,
    this.activeProductCode,
    this.featureEntitlements = const <String>[],
    this.limits = const <String, dynamic>{},
    this.display = const <String, dynamic>{},
  });

  final String tierCode;
  final String accessState;
  final String? renewalType;
  final String? provider;
  final String? startedAt;
  final String? paidThroughAt;
  final bool cancelAtPeriodEnd;
  final int? dailyChatLimit;
  final int dailyChatUsed;
  final int? dailyChatRemaining;
  final String businessTimezone;
  final String serverNow;
  final List<String> entitlements;
  final List<String> featureEntitlements;
  final Map<String, dynamic> limits;
  final int pointsBalance;
  final String? activeProductCode;
  final Map<String, dynamic> display;

  bool get isActive => accessState == 'active';
  bool get isUnlimitedDailyChat => dailyChatLimit == null;
  bool get isMember => isActive && tierCode != 'free';
  bool get isFreeTier => tierCode == 'free' || !isActive;
  bool get shouldShowExpiry => (paidThroughAt ?? '').trim().isNotEmpty;

  bool hasEntitlement(String entitlementCode) {
    return entitlements.contains(entitlementCode);
  }

  bool hasFeatureEntitlement(String featureCode) {
    return featureEntitlements.contains(featureCode);
  }

  factory MembershipSummary.fromJson(Map<String, dynamic> json) {
    return MembershipSummary(
      tierCode: '${json['tier_code'] ?? 'free'}'.trim(),
      accessState: '${json['access_state'] ?? 'inactive'}'.trim(),
      renewalType: _normalizedNullable(json['renewal_type']),
      provider: _normalizedNullable(json['provider']),
      startedAt: _normalizedNullable(json['started_at']),
      paidThroughAt: _normalizedNullable(json['paid_through_at']),
      cancelAtPeriodEnd: json['cancel_at_period_end'] == true,
      dailyChatLimit: _asNullableInt(json['daily_chat_limit']),
      dailyChatUsed: _asNullableInt(json['daily_chat_used']) ?? 0,
      dailyChatRemaining: _asNullableInt(json['daily_chat_remaining']),
      businessTimezone:
          '${json['business_timezone'] ?? AppConstants.defaultTimezone}',
      serverNow: '${json['server_now'] ?? ''}',
      entitlements: (json['entitlements'] is List)
          ? (json['entitlements'] as List)
                .map((item) => '$item'.trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      featureEntitlements: _stringList(json['feature_entitlements']),
      limits: json['limits'] is Map
          ? Map<String, dynamic>.from(json['limits'] as Map)
          : const <String, dynamic>{},
      pointsBalance: _asNullableInt(json['points_balance']) ?? 0,
      activeProductCode: _normalizedNullable(json['active_product_code']),
      display: json['display'] is Map
          ? Map<String, dynamic>.from(json['display'] as Map)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tier_code': tierCode,
      'access_state': accessState,
      'renewal_type': renewalType,
      'provider': provider,
      'started_at': startedAt,
      'paid_through_at': paidThroughAt,
      'cancel_at_period_end': cancelAtPeriodEnd,
      'daily_chat_limit': dailyChatLimit,
      'daily_chat_used': dailyChatUsed,
      'daily_chat_remaining': dailyChatRemaining,
      'business_timezone': businessTimezone,
      'server_now': serverNow,
      'entitlements': entitlements,
      'feature_entitlements': featureEntitlements,
      'limits': limits,
      'points_balance': pointsBalance,
      'active_product_code': activeProductCode,
      'display': display,
    };
  }
}

class MembershipCatalogChannel {
  const MembershipCatalogChannel({
    required this.provider,
    required this.platform,
    required this.providerProductId,
    required this.currencyCode,
    required this.amountMinor,
    required this.marketingLabel,
    required this.metadata,
  });

  final String provider;
  final String platform;
  final String providerProductId;
  final String currencyCode;
  final int amountMinor;
  final String? marketingLabel;
  final Map<String, dynamic> metadata;

  factory MembershipCatalogChannel.fromJson(Map<String, dynamic> json) {
    return MembershipCatalogChannel(
      provider: '${json['provider'] ?? ''}'.trim(),
      platform: '${json['platform'] ?? 'all'}'.trim(),
      providerProductId: '${json['provider_product_id'] ?? ''}'.trim(),
      currencyCode: '${json['currency_code'] ?? 'CNY'}'.trim(),
      amountMinor: _asNullableInt(json['amount_minor']) ?? 0,
      marketingLabel: _normalizedNullable(json['marketing_label']),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }
}

class MembershipCatalogProduct {
  const MembershipCatalogProduct({
    required this.internalProductCode,
    required this.tierCode,
    required this.periodCode,
    required this.renewalType,
    required this.durationMonths,
    required this.displayName,
    required this.displaySubtitle,
    required this.marketingLabel,
    required this.dailyChatLimit,
    required this.entitlements,
    required this.metadata,
    required this.channels,
  });

  final String internalProductCode;
  final String tierCode;
  final String periodCode;
  final String renewalType;
  final int durationMonths;
  final String displayName;
  final String? displaySubtitle;
  final String? marketingLabel;
  final int? dailyChatLimit;
  final List<String> entitlements;
  final Map<String, dynamic> metadata;
  final List<MembershipCatalogChannel> channels;

  MembershipCatalogChannel? firstChannelForProvider(String provider) {
    for (final channel in channels) {
      if (channel.provider == provider) {
        return channel;
      }
    }
    return null;
  }

  factory MembershipCatalogProduct.fromJson(Map<String, dynamic> json) {
    return MembershipCatalogProduct(
      internalProductCode: '${json['internal_product_code'] ?? ''}'.trim(),
      tierCode: '${json['tier_code'] ?? 'free'}'.trim(),
      periodCode: '${json['period_code'] ?? 'month'}'.trim(),
      renewalType: '${json['renewal_type'] ?? 'one_time'}'.trim(),
      durationMonths: _asNullableInt(json['duration_months']) ?? 1,
      displayName: '${json['display_name'] ?? ''}'.trim(),
      displaySubtitle: _normalizedNullable(json['display_subtitle']),
      marketingLabel: _normalizedNullable(json['marketing_label']),
      dailyChatLimit: _asNullableInt(json['daily_chat_limit']),
      entitlements: (json['entitlements'] is List)
          ? (json['entitlements'] as List)
                .map((item) => '$item'.trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const <String, dynamic>{},
      channels: (json['channels'] is List)
          ? (json['channels'] as List)
                .whereType<Map<Object?, Object?>>()
                .map(
                  (item) => MembershipCatalogChannel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <MembershipCatalogChannel>[],
    );
  }
}

class MembershipCheckoutIntent {
  const MembershipCheckoutIntent({
    required this.orderNo,
    required this.provider,
    required this.checkoutPayload,
  });

  final String orderNo;
  final String provider;
  final MembershipCheckoutPayload checkoutPayload;

  factory MembershipCheckoutIntent.fromJson(Map<String, dynamic> json) {
    return MembershipCheckoutIntent(
      orderNo: '${json['order_no'] ?? ''}'.trim(),
      provider: '${json['provider'] ?? ''}'.trim(),
      checkoutPayload: MembershipCheckoutPayload.fromJson(
        json['checkout_payload'] is Map
            ? Map<String, dynamic>.from(json['checkout_payload'] as Map)
            : const <String, dynamic>{},
      ),
    );
  }
}

class MembershipCheckoutPayload {
  const MembershipCheckoutPayload({
    required this.providerProductId,
    required this.currencyCode,
    required this.amountMinor,
    required this.appAccountToken,
    required this.platform,
  });

  final String providerProductId;
  final String currencyCode;
  final int amountMinor;
  final String? appAccountToken;
  final String platform;

  factory MembershipCheckoutPayload.fromJson(Map<String, dynamic> json) {
    return MembershipCheckoutPayload(
      providerProductId: '${json['provider_product_id'] ?? ''}'.trim(),
      currencyCode: '${json['currency_code'] ?? 'CNY'}'.trim(),
      amountMinor: _asNullableInt(json['amount_minor']) ?? 0,
      appAccountToken: _normalizedNullable(json['app_account_token']),
      platform: '${json['platform'] ?? ''}'.trim(),
    );
  }
}

int? _asNullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  final raw = '$value'.trim();
  if (raw.isEmpty) {
    return null;
  }
  return int.tryParse(raw);
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _normalizedNullable(Object? value) {
  final raw = '$value'.trim();
  if (raw.isEmpty || raw == 'null') {
    return null;
  }
  return raw;
}
