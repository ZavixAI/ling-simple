import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/features/membership/application/membership_gate.dart';
import 'package:ling/src/features/membership/application/membership_state.dart';
import 'package:ling/src/features/membership/data/bridges/membership_payment_bridge.dart';
import 'package:ling/src/features/membership/data/repositories/membership_repository.dart';
import 'package:ling/src/features/membership/models/membership_models.dart';

enum MembershipActionStatus { success, cancelled, pending, unsupported, idle }

class MembershipActionResult {
  const MembershipActionResult({
    required this.status,
    this.summary,
    this.message = '',
  });

  final MembershipActionStatus status;
  final MembershipSummary? summary;
  final String message;
}

class MembershipController extends Notifier<MembershipState> {
  MembershipRepository get _repository =>
      ref.read(membershipRepositoryProvider);
  MembershipPaymentBridge get _paymentBridge =>
      ref.read(membershipPaymentBridgeProvider);

  @override
  MembershipState build() => const MembershipState();

  Future<void> bootstrapAuthenticatedSession({
    bool forceRefresh = false,
  }) async {
    await refreshSummary(forceRefresh: forceRefresh);
  }

  Future<MembershipSummary?> refreshSummary({bool forceRefresh = false}) async {
    AppLogger.info(
      '[Ling][Membership] loading summary forceRefresh=$forceRefresh',
      category: 'membership',
    );
    state = state.copyWith(isLoadingSummary: true, summaryLoadFailed: false);
    try {
      final summary = await _repository.getSummary();
      AppLogger.info(
        '[Ling][Membership] summary loaded tier=${summary.tierCode} access=${summary.accessState}',
        category: 'membership',
        fields: <String, Object?>{
          'has_membership_state_card':
              summary.display['membership_state_card'] is Map,
          'display_keys': summary.display.keys.join(','),
        },
      );
      state = state.copyWith(
        summary: summary,
        isLoadingSummary: false,
        summaryLoadFailed: false,
      );
      return summary;
    } catch (error, stackTrace) {
      AppLogger.error(
        '[Ling][Membership] summary load failed error=$error',
        category: 'membership',
        stackTrace: stackTrace,
      );
      state = state.copyWith(isLoadingSummary: false, summaryLoadFailed: true);
      rethrow;
    }
  }

  Future<List<MembershipCatalogProduct>> ensureCatalogLoaded({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && state.catalog.isNotEmpty) {
      AppLogger.info(
        '[Ling][Membership] catalog cache hit products=${state.catalog.length}',
        category: 'membership',
      );
      return state.catalog;
    }
    AppLogger.info(
      '[Ling][Membership] loading catalog forceRefresh=$forceRefresh',
      category: 'membership',
    );
    state = state.copyWith(isLoadingCatalog: true, catalogLoadFailed: false);
    try {
      final catalog = await _repository.getCatalog();
      state = state.copyWith(
        catalog: catalog,
        isLoadingCatalog: false,
        hasLoadedCatalog: true,
        catalogLoadFailed: false,
      );
      return catalog;
    } catch (error, stackTrace) {
      AppLogger.error(
        '[Ling][Membership] catalog load failed error=$error',
        category: 'membership',
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        isLoadingCatalog: false,
        hasLoadedCatalog: true,
        catalogLoadFailed: true,
      );
      rethrow;
    }
  }

  Future<MembershipActionResult> purchaseAppleProduct(
    MembershipCatalogProduct product,
  ) async {
    state = state.copyWith(isPurchasing: true);
    try {
      final checkoutIntent = await _repository.prepareCheckout(
        internalProductCode: product.internalProductCode,
        provider: 'apple',
        platform: AppPlatformInfo.current.name,
      );
      final purchase = await _paymentBridge.purchaseAppleProduct(
        providerProductId: checkoutIntent.checkoutPayload.providerProductId,
        appAccountToken: checkoutIntent.checkoutPayload.appAccountToken,
      );
      switch (purchase.status) {
        case MembershipApplePurchaseStatus.success:
          final summary = await _repository.confirmApplePurchase(
            orderNo: checkoutIntent.orderNo,
            purchase: purchase,
          );
          await _finishAppleTransactionAfterDelivery(purchase);
          state = state.copyWith(summary: summary, isPurchasing: false);
          return MembershipActionResult(
            status: MembershipActionStatus.success,
            summary: summary,
          );
        case MembershipApplePurchaseStatus.cancelled:
          state = state.copyWith(isPurchasing: false);
          return const MembershipActionResult(
            status: MembershipActionStatus.cancelled,
          );
        case MembershipApplePurchaseStatus.pending:
          state = state.copyWith(isPurchasing: false);
          return MembershipActionResult(
            status: MembershipActionStatus.pending,
            message: purchase.message,
          );
        case MembershipApplePurchaseStatus.unsupported:
          state = state.copyWith(isPurchasing: false);
          return MembershipActionResult(
            status: MembershipActionStatus.unsupported,
            message: purchase.message,
          );
        case MembershipApplePurchaseStatus.error:
          throw ApiException(
            message: purchase.message.isEmpty
                ? 'Apple 购买失败。'
                : purchase.message,
          );
      }
    } catch (_) {
      state = state.copyWith(isPurchasing: false);
      rethrow;
    }
  }

  Future<MembershipActionResult> restoreApplePurchases() async {
    state = state.copyWith(isRestoring: true);
    try {
      final restored = await _paymentBridge.restoreApplePurchases();
      MembershipSummary? latestSummary = state.summary;
      var restoredAny = false;
      for (final purchase in restored) {
        switch (purchase.status) {
          case MembershipApplePurchaseStatus.success:
            if (!purchase.isSuccess) {
              continue;
            }
            latestSummary = await _repository.confirmApplePurchase(
              purchase: purchase,
            );
            await _finishAppleTransactionAfterDelivery(purchase);
            restoredAny = true;
            break;
          case MembershipApplePurchaseStatus.unsupported:
            state = state.copyWith(isRestoring: false);
            return MembershipActionResult(
              status: MembershipActionStatus.unsupported,
              message: purchase.message,
              summary: latestSummary,
            );
          case MembershipApplePurchaseStatus.pending:
            state = state.copyWith(isRestoring: false);
            return MembershipActionResult(
              status: MembershipActionStatus.pending,
              message: purchase.message,
              summary: latestSummary,
            );
          case MembershipApplePurchaseStatus.cancelled:
            state = state.copyWith(isRestoring: false);
            return MembershipActionResult(
              status: MembershipActionStatus.cancelled,
              message: purchase.message,
              summary: latestSummary,
            );
          case MembershipApplePurchaseStatus.error:
            throw ApiException(
              message: purchase.message.isEmpty
                  ? 'Apple 恢复购买失败。'
                  : purchase.message,
            );
        }
      }
      if (latestSummary != null) {
        state = state.copyWith(summary: latestSummary, isRestoring: false);
      } else {
        state = state.copyWith(isRestoring: false);
      }
      return MembershipActionResult(
        status: restoredAny
            ? MembershipActionStatus.success
            : MembershipActionStatus.idle,
        summary: latestSummary,
      );
    } catch (_) {
      state = state.copyWith(isRestoring: false);
      rethrow;
    }
  }

  Future<void> openAppleSubscriptionManagement() {
    return _paymentBridge.openAppleSubscriptionManagement();
  }

  Future<void> _finishAppleTransactionAfterDelivery(
    MembershipApplePurchaseResult purchase,
  ) async {
    final transactionId = (purchase.transactionId ?? '').trim();
    if (transactionId.isEmpty) {
      return;
    }
    try {
      await _paymentBridge.finishAppleTransaction(transactionId: transactionId);
    } catch (error, stackTrace) {
      AppLogger.warn(
        '[Ling][Membership] Apple transaction finish failed error=$error',
        category: 'membership',
        fields: <String, Object?>{
          'transaction_id': transactionId,
          'stack_trace': stackTrace.toString(),
        },
      );
    }
  }

  void applyQuotaSummary(MembershipSummary summary) {
    state = state.copyWith(summary: summary);
  }

  MembershipGateResult localChatGateResult() {
    return membershipGateResultFromSummary(state.summary);
  }

  void clear() {
    state = const MembershipState();
  }
}

final membershipControllerProvider =
    NotifierProvider<MembershipController, MembershipState>(
      MembershipController.new,
    );
