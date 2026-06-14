import 'package:flutter/services.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/platform/app_platform.dart';

enum MembershipApplePurchaseStatus {
  success,
  cancelled,
  pending,
  unsupported,
  error,
}

class MembershipApplePurchaseResult {
  const MembershipApplePurchaseResult({
    required this.status,
    this.message = '',
    this.providerProductId,
    this.transactionId,
    this.originalTransactionId,
    this.purchaseDate,
    this.expirationDate,
    this.signedTransactionInfo,
    this.rawPayload = const <String, dynamic>{},
  });

  final MembershipApplePurchaseStatus status;
  final String message;
  final String? providerProductId;
  final String? transactionId;
  final String? originalTransactionId;
  final String? purchaseDate;
  final String? expirationDate;
  final String? signedTransactionInfo;
  final Map<String, dynamic> rawPayload;

  bool get isSuccess =>
      status == MembershipApplePurchaseStatus.success &&
      (transactionId ?? '').trim().isNotEmpty;

  factory MembershipApplePurchaseResult.fromJson(Map<Object?, Object?> json) {
    final payload = Map<String, dynamic>.fromEntries(
      json.entries.map((entry) => MapEntry('${entry.key}', entry.value)),
    );
    return MembershipApplePurchaseResult(
      status: _statusFromRaw('${json['status'] ?? ''}'),
      message: '${json['message'] ?? ''}',
      providerProductId: _normalizedNullable(json['providerProductId']),
      transactionId: _normalizedNullable(json['transactionId']),
      originalTransactionId: _normalizedNullable(json['originalTransactionId']),
      purchaseDate: _normalizedNullable(json['purchaseDate']),
      expirationDate: _normalizedNullable(json['expirationDate']),
      signedTransactionInfo: _normalizedNullable(json['signedTransactionInfo']),
      rawPayload: payload,
    );
  }

  static MembershipApplePurchaseStatus _statusFromRaw(String raw) {
    switch (raw.trim()) {
      case 'success':
        return MembershipApplePurchaseStatus.success;
      case 'cancelled':
        return MembershipApplePurchaseStatus.cancelled;
      case 'pending':
        return MembershipApplePurchaseStatus.pending;
      case 'unsupported':
        return MembershipApplePurchaseStatus.unsupported;
      default:
        return MembershipApplePurchaseStatus.error;
    }
  }
}

abstract interface class MembershipPaymentBridge {
  Future<MembershipApplePurchaseResult> purchaseAppleProduct({
    required String providerProductId,
    String? appAccountToken,
  });

  Future<void> finishAppleTransaction({required String transactionId});

  Future<List<MembershipApplePurchaseResult>> restoreApplePurchases();

  Future<void> openAppleSubscriptionManagement();
}

class MethodChannelMembershipPaymentBridge implements MembershipPaymentBridge {
  MethodChannelMembershipPaymentBridge();

  static const MethodChannel _channel = MethodChannel(
    'ling/membership_payment',
  );

  bool get _supportsApplePayment => AppPlatformInfo.current == AppPlatform.ios;

  @override
  Future<MembershipApplePurchaseResult> purchaseAppleProduct({
    required String providerProductId,
    String? appAccountToken,
  }) async {
    if (!_supportsApplePayment) {
      return const MembershipApplePurchaseResult(
        status: MembershipApplePurchaseStatus.unsupported,
      );
    }
    AppLogger.info(
      '[Ling][iOS][Membership] purchase request productId=$providerProductId '
      'hasAppAccountToken=${(appAccountToken ?? '').trim().isNotEmpty}',
      category: 'membership',
    );
    final response = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'purchaseAppleProduct',
      <String, Object?>{
        'providerProductId': providerProductId,
        'appAccountToken': appAccountToken,
      },
    );
    final purchase = MembershipApplePurchaseResult.fromJson(
      response ?? const {},
    );
    AppLogger.info(
      '[Ling][iOS][Membership] purchase response '
      'status=${purchase.status.name} '
      'providerProductId=${purchase.providerProductId ?? ''} '
      'message=${purchase.message} '
      'rawPayload=${purchase.rawPayload}',
      category: 'membership',
    );
    return purchase;
  }

  @override
  Future<void> finishAppleTransaction({required String transactionId}) async {
    if (!_supportsApplePayment || transactionId.trim().isEmpty) {
      return;
    }
    await _channel.invokeMethod<void>(
      'finishAppleTransaction',
      <String, Object?>{'transactionId': transactionId},
    );
  }

  @override
  Future<List<MembershipApplePurchaseResult>> restoreApplePurchases() async {
    if (!_supportsApplePayment) {
      return const <MembershipApplePurchaseResult>[
        MembershipApplePurchaseResult(
          status: MembershipApplePurchaseStatus.unsupported,
        ),
      ];
    }
    final response = await _channel.invokeMethod<List<dynamic>>(
      'restoreApplePurchases',
    );
    if (response == null) {
      AppLogger.info(
        '[Ling][iOS][Membership] restore response count=0',
        category: 'membership',
      );
      return const <MembershipApplePurchaseResult>[];
    }
    final restored = response
        .whereType<Map<Object?, Object?>>()
        .map(MembershipApplePurchaseResult.fromJson)
        .toList(growable: false);
    AppLogger.info(
      '[Ling][iOS][Membership] restore response count=${restored.length} '
      'productIds=${restored.map((item) => item.providerProductId ?? '').where((id) => id.isNotEmpty).join(',')}',
      category: 'membership',
    );
    return restored;
  }

  @override
  Future<void> openAppleSubscriptionManagement() async {
    if (!_supportsApplePayment) {
      return;
    }
    await _channel.invokeMethod<void>('openAppleSubscriptionManagement');
  }
}

String? _normalizedNullable(Object? value) {
  final raw = '$value'.trim();
  if (raw.isEmpty || raw == 'null') {
    return null;
  }
  return raw;
}
