import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/config/constants.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/features/membership/application/membership_gate.dart';
import 'package:ling/src/features/membership/models/membership_models.dart';

void main() {
  test(
    'membershipGateResultFromSummary blocks when daily quota reaches zero',
    () {
      final gate = membershipGateResultFromSummary(
        const MembershipSummary(
          tierCode: 'free',
          accessState: 'inactive',
          renewalType: null,
          provider: null,
          startedAt: null,
          paidThroughAt: null,
          cancelAtPeriodEnd: false,
          dailyChatLimit: 5,
          dailyChatUsed: 5,
          dailyChatRemaining: 0,
          businessTimezone: AppConstants.defaultTimezone,
          serverNow: '2026-04-12T10:00:00+00:00',
          entitlements: <String>['chat_daily_limit'],
          pointsBalance: 0,
        ),
      );

      expect(gate.shouldBlock, isTrue);
      expect(gate.reason, QuotaExhaustedReason.dailyLimitReached);
    },
  );

  test('membershipGateResultFromError parses typed quota payload', () {
    final gate = membershipGateResultFromError(
      ApiException(
        message: 'Daily chat quota exhausted',
        statusCode: 402,
        cause: <String, dynamic>{
          'code': 402,
          'message': 'Daily chat quota exhausted',
          'data': <String, dynamic>{
            'error_code': membershipQuotaExhaustedErrorCode,
            'error_detail': <String, dynamic>{
              'reason': 'daily_limit_reached',
              'summary': <String, dynamic>{
                'tier_code': 'free',
                'access_state': 'inactive',
                'daily_chat_limit': 5,
                'daily_chat_used': 5,
                'daily_chat_remaining': 0,
                'business_timezone': AppConstants.defaultTimezone,
                'server_now': '2026-04-12T10:00:00+00:00',
                'entitlements': <String>['chat_daily_limit'],
                'points_balance': 0,
              },
            },
          },
        },
      ),
    );

    expect(gate.shouldBlock, isTrue);
    expect(gate.reason, QuotaExhaustedReason.dailyLimitReached);
    expect(gate.summary?.dailyChatRemaining, 0);
  });
}
