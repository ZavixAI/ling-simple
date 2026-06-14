import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/network/json_payload_codec.dart';
import 'package:ling/src/features/membership/data/bridges/membership_payment_bridge.dart';
import 'package:ling/src/features/membership/models/membership_models.dart';

class MembershipRepository {
  MembershipRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<MembershipSummary> getSummary() async {
    AppLogger.info(
      '[Ling][Membership] --> GET /membership/summary',
      category: 'membership',
    );
    final response = await _apiClient.get('/membership/summary');
    final summary = MembershipSummary.fromJson(asJsonMap(response.data));
    AppLogger.info(
      '[Ling][Membership] <-- /membership/summary tier=${summary.tierCode} access=${summary.accessState}',
      category: 'membership',
      fields: <String, Object?>{
        'has_membership_state_card':
            summary.display['membership_state_card'] is Map,
        'display_keys': summary.display.keys.join(','),
      },
    );
    return summary;
  }

  Future<List<MembershipCatalogProduct>> getCatalog() async {
    AppLogger.info(
      '[Ling][Membership] --> GET /membership/catalog',
      category: 'membership',
    );
    final response = await _apiClient.get('/membership/catalog');
    final data = asJsonMap(response.data);
    final items = data['items'];
    if (items is! List) {
      AppLogger.warn(
        '[Ling][Membership] <-- /membership/catalog missing items list',
        category: 'membership',
        fields: <String, Object?>{'keys': data.keys.join(',')},
      );
      return const <MembershipCatalogProduct>[];
    }
    final catalog = items
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) => MembershipCatalogProduct.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
    AppLogger.info(
      '[Ling][Membership] <-- /membership/catalog products=${catalog.length}',
      category: 'membership',
      fields: <String, Object?>{
        'product_codes': catalog
            .map((item) => item.internalProductCode)
            .where((item) => item.isNotEmpty)
            .join(','),
        'has_subscription_sheet': catalog.any(
          (item) => item.metadata['subscription_sheet'] is Map,
        ),
      },
    );
    return catalog;
  }

  Future<MembershipCheckoutIntent> prepareCheckout({
    required String internalProductCode,
    required String provider,
    required String platform,
  }) async {
    final response = await _apiClient.post(
      '/membership/checkout/prepare',
      body: <String, Object?>{
        'internal_product_code': internalProductCode,
        'provider': provider,
        'platform': platform,
      },
    );
    return MembershipCheckoutIntent.fromJson(asJsonMap(response.data));
  }

  Future<MembershipSummary> confirmApplePurchase({
    String? orderNo,
    required MembershipApplePurchaseResult purchase,
  }) async {
    final response = await _apiClient.post(
      '/membership/apple/confirm',
      body: <String, Object?>{
        if ((orderNo ?? '').trim().isNotEmpty) 'order_no': orderNo,
        if ((purchase.providerProductId ?? '').trim().isNotEmpty)
          'provider_product_id': purchase.providerProductId,
        'transaction_id': purchase.transactionId,
        if ((purchase.originalTransactionId ?? '').trim().isNotEmpty)
          'original_transaction_id': purchase.originalTransactionId,
        if ((purchase.purchaseDate ?? '').trim().isNotEmpty)
          'purchase_date': purchase.purchaseDate,
        if ((purchase.expirationDate ?? '').trim().isNotEmpty)
          'expiration_date': purchase.expirationDate,
        if ((purchase.signedTransactionInfo ?? '').trim().isNotEmpty)
          'signed_transaction_info': purchase.signedTransactionInfo,
        'raw_payload': purchase.rawPayload,
      },
    );
    return MembershipSummary.fromJson(asJsonMap(response.data));
  }

  Future<void> cancelSubscription({
    required String subscriptionId,
    required String provider,
  }) async {
    await _apiClient.post(
      '/membership/subscriptions/$subscriptionId/cancel'
      '?provider=${Uri.encodeQueryComponent(provider)}',
      body: null,
    );
  }
}
