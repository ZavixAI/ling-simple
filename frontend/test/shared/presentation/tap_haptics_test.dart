import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/settings/application/settings_state.dart';
import 'package:ling/src/features/settings/models/account_binding_models.dart';
import 'package:ling/src/features/settings/presentation/settings_account_binding_panel.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/phone_country.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platformCalls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> pumpSurface(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  setUp(() async {
    platformCalls.clear();
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      methodCall,
    ) async {
      if (methodCall.method == 'HapticFeedback.vibrate') {
        platformCalls.add(methodCall);
      }
      return null;
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('adaptive filled button triggers selection haptic once', (
    tester,
  ) async {
    var tapped = 0;

    await pumpSurface(
      tester,
      Center(
        child: LingAdaptiveFilledButton(
          onPressed: () {
            tapped += 1;
          },
          child: const Text('继续'),
        ),
      ),
    );

    await tester.tap(find.text('继续'));
    await tester.pump();

    expect(tapped, 1);
    expect(platformCalls, hasLength(1));
    expect(platformCalls.single.method, 'HapticFeedback.vibrate');
    expect(platformCalls.single.arguments, 'HapticFeedbackType.selectionClick');
  });

  testWidgets('disabled adaptive filled button does not trigger haptics', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      const Center(
        child: LingAdaptiveFilledButton(onPressed: null, child: Text('继续')),
      ),
    );

    await tester.tap(find.text('继续'), warnIfMissed: false);
    await tester.pump();

    expect(platformCalls, isEmpty);
  });

  testWidgets('adaptive segmented control triggers one selection haptic', (
    tester,
  ) async {
    String? selectedValue;

    await pumpSurface(
      tester,
      Center(
        child: LingAdaptiveSegmentedControl<String>(
          groupValue: 'system',
          onValueChanged: (value) {
            selectedValue = value;
          },
          segments: const [
            LingAdaptiveSegmentOption<String>(
              value: 'system',
              child: Text('系统'),
            ),
            LingAdaptiveSegmentOption<String>(value: 'dark', child: Text('深色')),
          ],
        ),
      ),
    );

    await tester.tap(find.text('深色'));
    await tester.pump();

    expect(selectedValue, 'dark');
    expect(platformCalls, hasLength(1));
    expect(platformCalls.single.arguments, 'HapticFeedbackType.selectionClick');
  });

  testWidgets('account binding CTA triggers selection haptic once', (
    tester,
  ) async {
    var sendPhoneCodeCalls = 0;

    await pumpSurface(
      tester,
      LingSettingsAccountBindingPanel(
        target: AccountBindingTarget.phone,
        strings: LingStrings('zh-CN'),
        initialPhoneCountry: phoneCountries.first,
        bindingState: const SettingsBindingState(),
        onSendPhoneCode: (_) async {
          sendPhoneCodeCalls += 1;
        },
        onSendEmailCode: (_) async {},
        onBindPhone:
            ({
              required String phone,
              required String challengeId,
              required String code,
            }) async {
              return const AccountBundle(
                profile: UserProfile(userId: 'user-1'),
                identities: [],
              );
            },
        onBindEmail: ({required String email, required String code}) async {
          return const AccountBundle(
            profile: UserProfile(userId: 'user-1'),
            identities: [],
          );
        },
        onCompleted: (_) async {},
      ),
    );

    await tester.enterText(
      find.byKey(const Key('settings_binding_phone_input')),
      '13800138000',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('settings_binding_send_phone')));
    await tester.pump();

    expect(sendPhoneCodeCalls, 1);
    expect(platformCalls, hasLength(1));
    expect(platformCalls.single.arguments, 'HapticFeedbackType.selectionClick');
  });
}
