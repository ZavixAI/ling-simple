import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/network/json_payload_codec.dart';
import 'package:ling/src/features/membership/models/membership_models.dart';

enum QuotaExhaustedReason { dailyLimitReached, membershipRequired, unknown }

class MembershipGateResult {
  const MembershipGateResult({
    required this.shouldBlock,
    this.reason = QuotaExhaustedReason.unknown,
    this.summary,
  });

  final bool shouldBlock;
  final QuotaExhaustedReason reason;
  final MembershipSummary? summary;
}

const String membershipQuotaExhaustedErrorCode = 'membership_quota_exhausted';
const String membershipEntitlementRequiredErrorCode =
    'membership_entitlement_required';

MembershipGateResult membershipGateResultFromSummary(
  MembershipSummary? summary,
) {
  if (summary == null) {
    return const MembershipGateResult(shouldBlock: false);
  }
  final remaining = summary.dailyChatRemaining;
  if (remaining == null || remaining > 0) {
    return MembershipGateResult(shouldBlock: false, summary: summary);
  }
  return MembershipGateResult(
    shouldBlock: true,
    reason: QuotaExhaustedReason.dailyLimitReached,
    summary: summary,
  );
}

MembershipGateResult membershipGateResultFromError(Object error) {
  if (error is! ApiException || error.cause is! Map) {
    return const MembershipGateResult(shouldBlock: false);
  }
  final payload = asJsonMap(error.cause);
  final data = payload['data'];
  if (data is! Map) {
    return const MembershipGateResult(shouldBlock: false);
  }
  final normalizedData = Map<String, dynamic>.from(data);
  final errorCode = '${normalizedData['error_code'] ?? ''}'.trim();
  final detail = normalizedData['error_detail'];
  final normalizedDetail = detail is Map
      ? Map<String, dynamic>.from(detail)
      : const <String, dynamic>{};
  final summaryValue = normalizedDetail['summary'];
  final summary = summaryValue is Map
      ? MembershipSummary.fromJson(Map<String, dynamic>.from(summaryValue))
      : null;
  if (errorCode == membershipQuotaExhaustedErrorCode) {
    final reasonRaw = '${normalizedDetail['reason'] ?? ''}'.trim();
    return MembershipGateResult(
      shouldBlock: true,
      reason: reasonRaw == 'daily_limit_reached'
          ? QuotaExhaustedReason.dailyLimitReached
          : QuotaExhaustedReason.unknown,
      summary: summary,
    );
  }
  if (errorCode == membershipEntitlementRequiredErrorCode) {
    return MembershipGateResult(
      shouldBlock: true,
      reason: QuotaExhaustedReason.membershipRequired,
      summary: summary,
    );
  }
  return const MembershipGateResult(shouldBlock: false);
}

DateTime? parseMembershipUtc(String? value) {
  final normalized = (value ?? '').trim();
  if (normalized.isEmpty) {
    return null;
  }
  return DateTime.tryParse(normalized)?.toUtc();
}

String formatMembershipGmt8Label(DateTime? value) {
  if (value == null) {
    return '';
  }
  final gmt8 = value.toUtc().add(const Duration(hours: 8));
  String twoDigits(int input) => input.toString().padLeft(2, '0');
  return '${gmt8.year}-${twoDigits(gmt8.month)}-${twoDigits(gmt8.day)} '
      '${twoDigits(gmt8.hour)}:${twoDigits(gmt8.minute)} GMT+8';
}
