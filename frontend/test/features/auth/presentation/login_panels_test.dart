import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/auth/presentation/login_panels.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/phone_country.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

void main() {
  testWidgets('email login panel resolves colors from dark theme', (
    tester,
  ) async {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    final codeFocusNode = FocusNode();
    addTearDown(emailController.dispose);
    addTearDown(codeController.dispose);
    addTearDown(codeFocusNode.dispose);

    await tester.pumpWidget(
      _ThemedHost(
        themeMode: ThemeMode.dark,
        child: LingCalendarEmailLoginPanel(
          isZh: false,
          title: 'Sign in',
          emailController: emailController,
          codeController: codeController,
          codeFocusNode: codeFocusNode,
          emailPlaceholder: 'Email',
          verificationCodeLabel: 'Verification code',
          sendCodeLabel: 'Send code',
          resendCodeLabel: 'Resend',
          signingInLabel: 'Signing in',
          loginActionLabel: 'Continue',
          emailCodeRequested: false,
          isSendingCode: false,
          isVerifyingCode: false,
          isAgreementAccepted: false,
          strings: LingStrings('en-US'),
          onSendCode: () {},
          onVerifyCode: () {},
          onAgreementChanged: (_) {},
          onOpenPrivacyAgreement: () {},
          onOpenSecurityAgreement: () {},
        ),
      ),
    );
    await tester.pump();

    final palette = AppTheme.dark().extension<LingPalette>()!;
    final title = tester.widget<Text>(find.text('Sign in'));
    final identityField = tester.widget<LingGlassTextField>(
      find.byKey(const Key('login_identity_field_container')),
    );
    final textField = tester.widget<TextField>(find.byType(TextField).first);
    final currentCodeSlot = tester.widget<LingGlassSurface>(
      find.byKey(const Key('login_code_slot_0')),
    );
    final currentCodeSlotBorder = tester.widget<DecoratedBox>(
      find.byKey(const Key('login_code_slot_border_0')),
    );
    final emptyCodeSlot = tester.widget<LingGlassSurface>(
      find.byKey(const Key('login_code_slot_1')),
    );
    final emptyCodeSlotBorder = tester.widget<DecoratedBox>(
      find.byKey(const Key('login_code_slot_border_1')),
    );
    final submitButton = tester.widget<LingGlassButton>(
      find.descendant(
        of: find.byKey(const Key('email_login_submit_button_container')),
        matching: find.byType(LingGlassButton),
      ),
    );

    expect(title.style?.color, palette.textPrimary);
    expect(identityField.textStyle?.color, palette.inputForeground);
    expect(identityField.placeholderStyle?.color, palette.inputPlaceholder);
    expect(identityField.radius, 16);
    expect(textField.style?.color, palette.inputForeground);
    expect(textField.cursorColor, palette.inputCursor);
    expect(
      currentCodeSlot.tintColor,
      palette.textPrimary.withValues(alpha: 0.10),
    );
    expect(
      _codeSlotBorderColor(currentCodeSlotBorder),
      palette.inputCursor.withValues(alpha: 0.48),
    );
    expect(emptyCodeSlot.tintColor, palette.inputBackground);
    expect(_codeSlotBorderColor(emptyCodeSlotBorder), palette.outlineSoft);
    expect(submitButton.tintColor, palette.primaryButtonBackground);
    expect(
      submitButton.foregroundColor,
      palette.primaryButtonDisabledForeground,
    );
  });

  testWidgets('login agreement footer resolves colors from dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      _ThemedHost(
        themeMode: ThemeMode.dark,
        child: LingLoginAgreementFooter(
          strings: LingStrings('en-US'),
          isAgreed: false,
          onChanged: (_) {},
          onOpenPrivacyAgreement: () {},
          onOpenSecurityAgreement: () {},
        ),
      ),
    );
    await tester.pump();

    final palette = AppTheme.dark().extension<LingPalette>()!;
    final checkbox = tester.widget<LingGlassSurface>(
      find.byKey(const Key('login_agreement_checkbox')),
    );
    final richText = tester.widget<RichText>(
      find.byKey(const Key('login_agreement_text')),
    );
    expect(checkbox.tintColor, palette.outlineSoft.withValues(alpha: 0.18));
    expect(
      (richText.text as TextSpan).style?.color,
      palette.textSecondary.withValues(alpha: 0.74),
    );
  });

  testWidgets('email login panel keeps light theme action colors neutral', (
    tester,
  ) async {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    final codeFocusNode = FocusNode();
    addTearDown(emailController.dispose);
    addTearDown(codeController.dispose);
    addTearDown(codeFocusNode.dispose);

    await tester.pumpWidget(
      _ThemedHost(
        themeMode: ThemeMode.light,
        child: LingCalendarEmailLoginPanel(
          isZh: false,
          title: 'Sign in',
          emailController: emailController,
          codeController: codeController..text = '1',
          codeFocusNode: codeFocusNode,
          emailPlaceholder: 'Email',
          verificationCodeLabel: 'Verification code',
          sendCodeLabel: 'Send code',
          resendCodeLabel: 'Resend',
          signingInLabel: 'Signing in',
          loginActionLabel: 'Continue',
          emailCodeRequested: true,
          isSendingCode: false,
          isVerifyingCode: false,
          isAgreementAccepted: false,
          strings: LingStrings('en-US'),
          onSendCode: () {},
          onVerifyCode: () {},
          onAgreementChanged: (_) {},
          onOpenPrivacyAgreement: () {},
          onOpenSecurityAgreement: () {},
        ),
      ),
    );
    await tester.pump();

    final palette = AppTheme.light().extension<LingPalette>()!;
    final currentCodeSlot = tester.widget<LingGlassSurface>(
      find.byKey(const Key('login_code_slot_1')),
    );
    final currentCodeSlotBorder = tester.widget<DecoratedBox>(
      find.byKey(const Key('login_code_slot_border_1')),
    );
    final filledCodeSlot = tester.widget<LingGlassSurface>(
      find.byKey(const Key('login_code_slot_0')),
    );
    final filledCodeSlotBorder = tester.widget<DecoratedBox>(
      find.byKey(const Key('login_code_slot_border_0')),
    );
    final identityField = tester.widget<LingGlassTextField>(
      find.byKey(const Key('login_identity_field_container')),
    );
    final submitButton = tester.widget<LingGlassButton>(
      find.descendant(
        of: find.byKey(const Key('email_login_submit_button_container')),
        matching: find.byType(LingGlassButton),
      ),
    );

    expect(identityField.textStyle?.color, palette.inputForeground);
    expect(identityField.placeholderStyle?.color, palette.inputPlaceholder);
    expect(identityField.radius, 16);
    expect(
      currentCodeSlot.tintColor,
      palette.textPrimary.withValues(alpha: 0.04),
    );
    expect(
      _codeSlotBorderColor(currentCodeSlotBorder),
      palette.textPrimary.withValues(alpha: 0.1),
    );
    expect(filledCodeSlot.tintColor, palette.primaryButtonBackground);
    expect(
      _codeSlotBorderColor(filledCodeSlotBorder),
      palette.primaryButtonBackground.withValues(alpha: 0.72),
    );
    expect(submitButton.tintColor, palette.primaryButtonBackground);
    expect(
      submitButton.foregroundColor,
      palette.primaryButtonDisabledForeground,
    );
  });

  testWidgets(
    'phone verification login uses semantic dark button and input colors',
    (tester) async {
      final phoneController = TextEditingController(text: '13800138000');
      final codeController = TextEditingController(text: '123456');
      final codeFocusNode = FocusNode();
      addTearDown(phoneController.dispose);
      addTearDown(codeController.dispose);
      addTearDown(codeFocusNode.dispose);

      await tester.pumpWidget(
        _ThemedHost(
          themeMode: ThemeMode.dark,
          child: LingCalendarEmailLoginPanel(
            isZh: true,
            title: '手机号登录',
            emailController: phoneController,
            codeController: codeController,
            codeFocusNode: codeFocusNode,
            emailPlaceholder: '请输入手机号',
            verificationCodeLabel: '验证码',
            sendCodeLabel: '获取验证码',
            resendCodeLabel: '重新获取',
            signingInLabel: '登录中',
            loginActionLabel: '登录',
            emailCodeRequested: true,
            isSendingCode: false,
            isVerifyingCode: false,
            isAgreementAccepted: true,
            strings: LingStrings('zh-CN'),
            selectedPhoneCountry: phoneCountries.first,
            onPhoneCountryChanged: (_) {},
            isPhoneLogin: true,
            onSendCode: () {},
            onVerifyCode: () {},
            onAgreementChanged: (_) {},
            onOpenPrivacyAgreement: () {},
            onOpenSecurityAgreement: () {},
          ),
        ),
      );
      await tester.pump();

      final palette = AppTheme.dark().extension<LingPalette>()!;
      final identityField = tester.widget<LingGlassTextField>(
        find.descendant(
          of: find.byKey(const Key('login_identity_field_container')),
          matching: find.byType(LingGlassTextField),
        ),
      );
      final submitButton = tester.widget<LingGlassButton>(
        find.descendant(
          of: find.byKey(const Key('email_login_submit_button_container')),
          matching: find.byType(LingGlassButton),
        ),
      );
      final filledCodeSlot = tester.widget<LingGlassSurface>(
        find.byKey(const Key('login_code_slot_0')),
      );

      expect(identityField.textStyle?.color, palette.inputForeground);
      expect(identityField.placeholderStyle?.color, palette.inputPlaceholder);
      expect(filledCodeSlot.tintColor, palette.primaryButtonBackground);
      expect(submitButton.tintColor, palette.primaryButtonBackground);
      expect(submitButton.foregroundColor, palette.primaryButtonForeground);
      expect(submitButton.foregroundColor, isNot(const Color(0xFF020407)));
    },
  );

  testWidgets('back to login methods button is tappable across its width', (
    tester,
  ) async {
    final phoneController = TextEditingController(text: '13800138000');
    final codeController = TextEditingController();
    final codeFocusNode = FocusNode();
    var backTapCount = 0;
    addTearDown(phoneController.dispose);
    addTearDown(codeController.dispose);
    addTearDown(codeFocusNode.dispose);

    await tester.pumpWidget(
      _ThemedHost(
        themeMode: ThemeMode.light,
        child: SizedBox(
          width: 420,
          child: LingCalendarEmailLoginPanel(
            isZh: true,
            title: '手机号登录',
            emailController: phoneController,
            codeController: codeController,
            codeFocusNode: codeFocusNode,
            emailPlaceholder: '请输入手机号',
            verificationCodeLabel: '验证码',
            sendCodeLabel: '获取验证码',
            resendCodeLabel: '重新获取',
            signingInLabel: '登录中',
            loginActionLabel: '登录',
            emailCodeRequested: false,
            isSendingCode: false,
            isVerifyingCode: false,
            isAgreementAccepted: true,
            strings: LingStrings('zh-CN'),
            backToMethodsLabel: '返回登录方式',
            selectedPhoneCountry: phoneCountries.first,
            onPhoneCountryChanged: (_) {},
            isPhoneLogin: true,
            onBackToMethods: () {
              backTapCount += 1;
            },
            onSendCode: () {},
            onVerifyCode: () {},
            onAgreementChanged: (_) {},
            onOpenPrivacyAgreement: () {},
            onOpenSecurityAgreement: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final buttonRect = tester.getRect(
      find.byKey(const Key('back_to_login_methods_button')),
    );
    await tester.tapAt(buttonRect.centerRight - const Offset(24, 0));
    await tester.pump();

    expect(backTapCount, 1);
  });

  testWidgets('phone country picker opens without a title and selects code', (
    tester,
  ) async {
    final phoneController = TextEditingController(text: '13800138000');
    final codeController = TextEditingController();
    final codeFocusNode = FocusNode();
    PhoneCountry selectedCountry = phoneCountries.first;
    addTearDown(phoneController.dispose);
    addTearDown(codeController.dispose);
    addTearDown(codeFocusNode.dispose);

    await tester.pumpWidget(
      _ThemedHost(
        themeMode: ThemeMode.light,
        child: StatefulBuilder(
          builder: (context, setState) {
            return LingCalendarEmailLoginPanel(
              isZh: true,
              title: '手机号登录',
              emailController: phoneController,
              codeController: codeController,
              codeFocusNode: codeFocusNode,
              emailPlaceholder: '请输入手机号',
              verificationCodeLabel: '验证码',
              sendCodeLabel: '获取验证码',
              resendCodeLabel: '重新获取',
              signingInLabel: '登录中',
              loginActionLabel: '登录',
              emailCodeRequested: false,
              isSendingCode: false,
              isVerifyingCode: false,
              isAgreementAccepted: true,
              strings: LingStrings('zh-CN'),
              selectedPhoneCountry: selectedCountry,
              onPhoneCountryChanged: (country) {
                setState(() {
                  selectedCountry = country;
                });
              },
              isPhoneLogin: true,
              onSendCode: () {},
              onVerifyCode: () {},
              onAgreementChanged: (_) {},
              onOpenPrivacyAgreement: () {},
              onOpenSecurityAgreement: () {},
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('请输入手机号'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login_phone_country_dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('请输入手机号'), findsOneWidget);
    expect(
      find.byKey(const Key('phone_country_code_search_field')),
      findsOneWidget,
    );
    final searchField = tester.widget<LingGlassTextField>(
      find.byKey(const Key('phone_country_code_search_field')),
    );
    expect(searchField.placeholder, 'Search country/region or code');
    expect(find.text('Mainland China'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('phone_country_code_search_field')),
        matching: find.byType(TextField),
      ),
      '+1',
    );
    await tester.pumpAndSettle();

    expect(find.text('United States / Canada'), findsOneWidget);
    expect(find.text('Mainland China'), findsNothing);

    await tester.tap(find.byKey(const Key('phone_country_code_row_US')));
    await tester.pumpAndSettle();

    expect(selectedCountry.code, 'US');
    expect(find.text('US +1'), findsOneWidget);
  });

  testWidgets('email send code action stays on the same row as the label', (
    tester,
  ) async {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    final codeFocusNode = FocusNode();
    addTearDown(emailController.dispose);
    addTearDown(codeController.dispose);
    addTearDown(codeFocusNode.dispose);

    await tester.pumpWidget(
      _ThemedHost(
        themeMode: ThemeMode.light,
        child: LingCalendarEmailLoginPanel(
          isZh: false,
          title: 'Sign in',
          emailController: emailController,
          codeController: codeController,
          codeFocusNode: codeFocusNode,
          emailPlaceholder: 'Email',
          verificationCodeLabel: 'Verification code',
          sendCodeLabel: 'Send code',
          resendCodeLabel: 'Resend',
          signingInLabel: 'Signing in',
          loginActionLabel: 'Continue',
          emailCodeRequested: false,
          isSendingCode: false,
          isVerifyingCode: false,
          isAgreementAccepted: false,
          strings: LingStrings('en-US'),
          onSendCode: () {},
          onVerifyCode: () {},
          onAgreementChanged: (_) {},
          onOpenPrivacyAgreement: () {},
          onOpenSecurityAgreement: () {},
        ),
      ),
    );
    await tester.pump();

    expect(
      (tester.getTopLeft(find.text('Send code')).dy -
              tester.getTopLeft(find.text('VERIFICATION CODE')).dy)
          .abs(),
      lessThan(8),
    );
  });

  testWidgets('email login identity field rejects non-email characters', (
    tester,
  ) async {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    final codeFocusNode = FocusNode();
    addTearDown(emailController.dispose);
    addTearDown(codeController.dispose);
    addTearDown(codeFocusNode.dispose);

    await tester.pumpWidget(
      _ThemedHost(
        themeMode: ThemeMode.light,
        child: LingCalendarEmailLoginPanel(
          isZh: false,
          title: 'Sign in',
          emailController: emailController,
          codeController: codeController,
          codeFocusNode: codeFocusNode,
          emailPlaceholder: 'Email',
          verificationCodeLabel: 'Verification code',
          sendCodeLabel: 'Send code',
          resendCodeLabel: 'Resend',
          signingInLabel: 'Signing in',
          loginActionLabel: 'Continue',
          emailCodeRequested: false,
          isSendingCode: false,
          isVerifyingCode: false,
          isAgreementAccepted: false,
          strings: LingStrings('en-US'),
          onSendCode: () {},
          onVerifyCode: () {},
          onAgreementChanged: (_) {},
          onOpenPrivacyAgreement: () {},
          onOpenSecurityAgreement: () {},
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextField).first,
      'ling中文 user@example.com',
    );

    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(emailController.text, 'linguser@example.com');
    expect(textField.keyboardType, TextInputType.emailAddress);
    expect(textField.autocorrect, isFalse);
    expect(textField.enableSuggestions, isFalse);
  });

  testWidgets('phone login identity field accepts digits only', (tester) async {
    final phoneController = TextEditingController();
    final codeController = TextEditingController();
    final codeFocusNode = FocusNode();
    addTearDown(phoneController.dispose);
    addTearDown(codeController.dispose);
    addTearDown(codeFocusNode.dispose);

    await tester.pumpWidget(
      _ThemedHost(
        themeMode: ThemeMode.light,
        child: LingCalendarEmailLoginPanel(
          isZh: false,
          title: 'Sign in',
          emailController: phoneController,
          codeController: codeController,
          codeFocusNode: codeFocusNode,
          emailPlaceholder: 'Phone',
          verificationCodeLabel: 'Verification code',
          sendCodeLabel: 'Send code',
          resendCodeLabel: 'Resend',
          signingInLabel: 'Signing in',
          loginActionLabel: 'Continue',
          emailCodeRequested: false,
          isSendingCode: false,
          isVerifyingCode: false,
          isAgreementAccepted: false,
          strings: LingStrings('en-US'),
          isPhoneLogin: true,
          onSendCode: () {},
          onVerifyCode: () {},
          onAgreementChanged: (_) {},
          onOpenPrivacyAgreement: () {},
          onOpenSecurityAgreement: () {},
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, '13a8中-00');

    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(phoneController.text, '13800');
    expect(textField.keyboardType, TextInputType.number);
    expect(textField.autocorrect, isFalse);
    expect(textField.enableSuggestions, isFalse);
  });

  testWidgets('other login methods stay icon-only in both themes', (
    tester,
  ) async {
    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _ThemedHost(
          themeMode: themeMode,
          child: LingCalendarLoginMethodPanel(
            prepared: true,
            canStartOneClick: true,
            showAppleSignIn: true,
            showWeChatSignIn: true,
            isSigningIn: false,
            isAppleSigningIn: false,
            isWeChatSigningIn: false,
            isAuthBusy: false,
            oneClickLabel: 'Phone',
            appleLabel: 'Apple',
            wechatLabel: 'WeChat',
            emailLabel: 'Email',
            preparingLabel: 'Preparing',
            authingLabel: 'Signing in',
            appleAuthingLabel: 'Signing in',
            wechatAuthingLabel: 'Signing in',
            statusMessage: '',
            isAgreementAccepted: true,
            strings: LingStrings('en-US'),
            onStartOneClick: () {},
            onStartAppleSignIn: () {},
            onStartWeChatSignIn: () {},
            onAgreementChanged: (_) {},
            onAgreementRequired: () {},
            onSelectPhoneLogin: () {},
            onSelectEmailLogin: () {},
            onOpenPrivacyAgreement: () {},
            onOpenSecurityAgreement: () {},
          ),
        ),
      );
      await tester.pump();

      final palette = themeMode == ThemeMode.dark
          ? AppTheme.dark().extension<LingPalette>()!
          : AppTheme.light().extension<LingPalette>()!;
      final oneClickButton = tester.widget<LingGlassButton>(
        find.descendant(
          of: find.byKey(const Key('one_click_phone_button')),
          matching: find.byType(LingGlassButton),
        ),
      );
      expect(oneClickButton.tintColor, palette.primaryButtonBackground);
      expect(oneClickButton.foregroundColor, palette.primaryButtonForeground);

      for (final key in [
        const Key('phone_sign_in_button'),
        const Key('login_method_email_button'),
        const Key('apple_sign_in_button'),
        const Key('wechat_sign_in_button'),
      ]) {
        expect(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(LingGlassButton),
          ),
          findsNothing,
        );
        expect(find.byKey(key), findsOneWidget);
      }
    }
  });

  testWidgets('one-tap preparing state stays inside the primary button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _ThemedHost(
        themeMode: ThemeMode.light,
        child: LingCalendarLoginMethodPanel(
          prepared: false,
          canStartOneClick: false,
          showAppleSignIn: false,
          showWeChatSignIn: false,
          isSigningIn: false,
          isAppleSigningIn: false,
          isWeChatSigningIn: false,
          isAuthBusy: false,
          oneClickLabel: 'One-Tap Login',
          appleLabel: 'Apple',
          wechatLabel: 'WeChat',
          emailLabel: 'Email',
          preparingLabel: 'Preparing',
          authingLabel: 'Signing in',
          appleAuthingLabel: 'Signing in',
          wechatAuthingLabel: 'Signing in',
          statusMessage: '',
          isAgreementAccepted: true,
          strings: LingStrings('en-US'),
          onStartOneClick: () {},
          onStartAppleSignIn: () {},
          onStartWeChatSignIn: () {},
          onAgreementChanged: (_) {},
          onAgreementRequired: () {},
          onSelectPhoneLogin: () {},
          onSelectEmailLogin: () {},
          onOpenPrivacyAgreement: () {},
          onOpenSecurityAgreement: () {},
        ),
      ),
    );
    await tester.pump();

    final buttonText = find.descendant(
      of: find.byKey(const Key('one_click_phone_button')),
      matching: find.text('Preparing'),
    );

    expect(buttonText, findsOneWidget);
    expect(find.text('Preparing'), findsOneWidget);
  });
}

Color _codeSlotBorderColor(DecoratedBox box) {
  final decoration = box.decoration as ShapeDecoration;
  final shape = decoration.shape as RoundedRectangleBorder;
  return shape.side.color;
}

class _ThemedHost extends StatelessWidget {
  const _ThemedHost({required this.themeMode, required this.child});

  final ThemeMode themeMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: Scaffold(body: Center(child: child)),
    );
  }
}
