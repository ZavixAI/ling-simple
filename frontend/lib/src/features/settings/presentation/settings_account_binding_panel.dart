import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/settings/application/settings_state.dart';
import 'package:ling/src/features/settings/models/account_binding_models.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/phone_country.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/notice.dart';
import 'package:ling/src/shared/presentation/phone_country_code_picker_sheet.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

final List<TextInputFormatter> _emailBindingInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9@._%+\-]')),
];

const int _settingsBindingCodeLength = 6;

class LingSettingsAccountBindingPanel extends StatefulWidget {
  const LingSettingsAccountBindingPanel({
    super.key,
    required this.target,
    required this.strings,
    required this.initialPhoneCountry,
    this.initialPhoneNumber,
    this.initialEmail,
    required this.bindingState,
    required this.onSendPhoneCode,
    required this.onSendEmailCode,
    required this.onBindPhone,
    required this.onBindEmail,
    required this.onCompleted,
  });

  final AccountBindingTarget target;
  final LingStrings strings;
  final PhoneCountry initialPhoneCountry;
  final String? initialPhoneNumber;
  final String? initialEmail;
  final SettingsBindingState bindingState;
  final Future<void> Function(String phone) onSendPhoneCode;
  final Future<void> Function(String email) onSendEmailCode;
  final Future<AccountBundle> Function({
    required String phone,
    required String challengeId,
    required String code,
  })
  onBindPhone;
  final Future<AccountBundle> Function({
    required String email,
    required String code,
  })
  onBindEmail;
  final Future<void> Function(AccountBundle result) onCompleted;

  @override
  State<LingSettingsAccountBindingPanel> createState() =>
      _LingSettingsAccountBindingPanelState();
}

class _LingSettingsAccountBindingPanelState
    extends State<LingSettingsAccountBindingPanel> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();

  late PhoneCountry _selectedPhoneCountry;
  Timer? _countdownTimer;
  DateTime _now = DateTime.now();
  String? _syncedPendingRecipient;

  LingStrings get s => widget.strings;
  bool get _isPhone => widget.target == AccountBindingTarget.phone;
  SettingsBindingState get _bindingState => widget.bindingState;
  bool get _hasPendingVerification => _bindingState.hasPendingVerification;
  bool get _hasUsablePendingVerification =>
      _hasPendingVerification && !_bindingState.isExpired;
  bool get _recipientMatchesPendingChallenge =>
      _hasUsablePendingVerification &&
      (_bindingState.pendingRecipient ?? '').trim().isNotEmpty &&
      _bindingState.pendingRecipient == _currentRecipient;
  bool get _phoneUnchangedFromInitial =>
      _isPhone &&
      _initialFormattedPhoneNumber.isNotEmpty &&
      _formattedPhoneNumber == _initialFormattedPhoneNumber;
  bool get _emailUnchangedFromInitial =>
      !_isPhone &&
      _initialNormalizedEmail.isNotEmpty &&
      _normalizedEmail == _initialNormalizedEmail;
  bool get _recipientUnchangedFromInitial =>
      _phoneUnchangedFromInitial || _emailUnchangedFromInitial;
  bool get _hasIdentityInput => _isPhone
      ? _phoneController.text.replaceAll(RegExp(r'\D'), '').isNotEmpty
      : _normalizedEmail.isNotEmpty;
  bool get _canSendCode =>
      !_bindingState.isSendingCode &&
      _cooldownSeconds == 0 &&
      !_recipientUnchangedFromInitial &&
      (_isPhone || _hasIdentityInput);
  bool get _canSubmitCode =>
      _recipientMatchesPendingChallenge &&
      _codeController.text.trim().length == _settingsBindingCodeLength &&
      !_bindingState.isBinding;

  int get _cooldownSeconds {
    if (_bindingState.isExpired) {
      return 0;
    }
    final resendAt = _bindingState.resendAvailableAt;
    if (resendAt == null || !resendAt.isAfter(_now)) {
      return 0;
    }
    return (resendAt.difference(_now).inMilliseconds / 1000).ceil();
  }

  String get _currentRecipient =>
      _isPhone ? _formattedPhoneNumber : _normalizedEmail;

  String get _normalizedEmail => _emailController.text.trim().toLowerCase();

  String get _initialNormalizedEmail =>
      (widget.initialEmail ?? '').trim().toLowerCase();

  String get _initialFormattedPhoneNumber {
    final initialPhone = (widget.initialPhoneNumber ?? '').trim();
    if (initialPhone.isEmpty) {
      return '';
    }
    return _normalizePhoneWithCountry(initialPhone, widget.initialPhoneCountry);
  }

  String get _formattedPhoneNumber {
    return _normalizePhoneWithCountry(
      _phoneController.text,
      _selectedPhoneCountry,
    );
  }

  String _normalizePhoneWithCountry(String value, PhoneCountry country) {
    final trimmed = value.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('+')) {
      return '+$digits';
    }
    return '${country.dialCode}$digits';
  }

  @override
  void initState() {
    super.initState();
    _selectedPhoneCountry = widget.initialPhoneCountry;
    _phoneController.text = (widget.initialPhoneNumber ?? '').trim();
    _emailController.text = (widget.initialEmail ?? '').trim();
    _phoneController.addListener(_handleInputChanged);
    _emailController.addListener(_handleInputChanged);
    _codeController.addListener(_handleInputChanged);
    _codeFocusNode.addListener(_handleInputChanged);
    _syncBindingState();
    _syncCountdownTimer();
  }

  @override
  void didUpdateWidget(covariant LingSettingsAccountBindingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPhoneNumber != widget.initialPhoneNumber &&
        _phoneController.text != (widget.initialPhoneNumber ?? '').trim()) {
      _phoneController.text = (widget.initialPhoneNumber ?? '').trim();
    }
    if (oldWidget.initialEmail != widget.initialEmail &&
        _emailController.text != (widget.initialEmail ?? '').trim()) {
      _emailController.text = (widget.initialEmail ?? '').trim();
    }
    if (oldWidget.initialPhoneCountry != widget.initialPhoneCountry) {
      _selectedPhoneCountry = widget.initialPhoneCountry;
    }
    if (oldWidget.bindingState != widget.bindingState) {
      _syncBindingState();
      _syncCountdownTimer();
      if (!oldWidget.bindingState.hasPendingVerification &&
          widget.bindingState.hasPendingVerification &&
          _recipientMatchesPendingChallenge) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _codeFocusNode.requestFocus();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.removeListener(_handleInputChanged);
    _emailController.removeListener(_handleInputChanged);
    _codeController.removeListener(_handleInputChanged);
    _codeFocusNode.removeListener(_handleInputChanged);
    _phoneController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_canSendCode || !_hasIdentityInput) {
      return;
    }
    try {
      if (_isPhone) {
        await widget.onSendPhoneCode(_formattedPhoneNumber);
      } else {
        await widget.onSendEmailCode(_normalizedEmail);
      }
    } catch (error) {
      _showError(error, action: AccountBindingErrorAction.sendCode);
    }
  }

  Future<void> _bind() async {
    if (!_recipientMatchesPendingChallenge || !_canSubmitCode) {
      return;
    }
    if (_isPhone && (_bindingState.challengeId?.trim().isEmpty ?? true)) {
      return;
    }

    try {
      final result = _isPhone
          ? await widget.onBindPhone(
              phone: _formattedPhoneNumber,
              challengeId: _bindingState.challengeId!,
              code: _codeController.text,
            )
          : await widget.onBindEmail(
              email: _normalizedEmail,
              code: _codeController.text,
            );
      if (!mounted) {
        return;
      }
      await widget.onCompleted(result);
    } catch (error) {
      _showError(error, action: AccountBindingErrorAction.bind);
    }
  }

  void _syncBindingState() {
    final pendingRecipient = _bindingState.pendingRecipient;
    if (pendingRecipient != _syncedPendingRecipient) {
      _syncedPendingRecipient = pendingRecipient;
      if (_codeController.text.isNotEmpty) {
        _codeController.clear();
      }
    }
  }

  void _syncCountdownTimer() {
    final shouldTick =
        (_bindingState.resendAvailableAt?.isAfter(_now) ?? false) ||
        (_bindingState.expireAt?.isAfter(_now) ?? false);
    if (!shouldTick) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      return;
    }
    _countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _now = DateTime.now();
      });
      _syncCountdownTimer();
    });
  }

  void _showError(Object error, {required AccountBindingErrorAction action}) {
    final message = localizeAccountBindingError(
      error: error,
      strings: s,
      target: widget.target,
      action: action,
    );
    if (!mounted) {
      return;
    }
    showLingTopNotice(context, message);
  }

  Future<void> _selectPhoneCountry() async {
    final country = await showPhoneCountryCodePickerSheet(
      context: context,
      selected: _selectedPhoneCountry,
    );
    if (country == null || !mounted) {
      return;
    }
    setState(() {
      _selectedPhoneCountry = country;
    });
  }

  void _handleInputChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Widget _buildPhoneField(LingPalette palette) {
    return Row(
      children: [
        SizedBox(
          width: 116,
          child: LingGlassPicker(
            value: _selectedPhoneCountry.label,
            onTap: _selectPhoneCountry,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LingGlassTextField(
            key: const Key('settings_binding_phone_input'),
            controller: _phoneController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            placeholder: s.phonePlaceholder,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildBindingPanel(LingPalette palette) {
    final showCodeField = _recipientMatchesPendingChallenge;
    final showSendButton = !showCodeField;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _isPhone
            ? _buildPhoneField(palette)
            : LingGlassTextField(
                key: const Key('settings_binding_email_input'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                inputFormatters: _emailBindingInputFormatters,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                placeholder: s.emailPlaceholder,
              ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: showCodeField
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    _LingBindingVerificationCodeField(
                      fieldKey: Key(
                        'settings_binding_code_input_${widget.target.name}',
                      ),
                      controller: _codeController,
                      focusNode: _codeFocusNode,
                      semanticLabel: s.verificationCode,
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        if (showSendButton) ...[
          const SizedBox(height: 16),
          LingAdaptiveFilledButton(
            key: Key('settings_binding_send_${widget.target.name}'),
            onPressed: _canSendCode ? _sendCode : null,
            minHeight: 52,
            child: _bindingState.isSendingCode
                ? GlassProgressIndicator.circular(
                    size: 22,
                    strokeWidth: 2.4,
                    color: palette.primaryButtonForeground,
                  )
                : Text(_sendCodeButtonLabel),
          ),
        ],
        if (showCodeField) ...[
          const SizedBox(height: 16),
          LingAdaptiveFilledButton(
            key: Key('settings_binding_submit_${widget.target.name}'),
            onPressed: _canSubmitCode ? _bind : null,
            minHeight: 52,
            child: _bindingState.isBinding
                ? GlassProgressIndicator.circular(
                    size: 22,
                    strokeWidth: 2.4,
                    color: palette.primaryButtonForeground,
                  )
                : Text(s.completeBinding),
          ),
        ],
      ],
    );
  }

  String get _sendCodeButtonLabel {
    if (_bindingState.isSendingCode) {
      return s.sending;
    }
    if (_cooldownSeconds > 0) {
      return s.bindingRetryInSeconds(_cooldownSeconds);
    }
    return _isPhone ? s.sendPhoneVerificationCode : s.sendEmailVerificationCode;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _buildBindingPanel(palette);
  }
}

class _LingBindingVerificationCodeField extends StatelessWidget {
  const _LingBindingVerificationCodeField({
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.semanticLabel,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      textField: true,
      label: semanticLabel,
      child: SizedBox(
        height: 56,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Material(
              type: MaterialType.transparency,
              child: TextField(
                key: fieldKey,
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_settingsBindingCodeLength),
                ],
                autocorrect: false,
                enableSuggestions: false,
                cursorColor: Colors.transparent,
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  counterText: '',
                ),
              ),
            ),
            IgnorePointer(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final code = value.text;
                  return Row(
                    children: [
                      for (
                        var index = 0;
                        index < _settingsBindingCodeLength;
                        index++
                      )
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(
                              end: index == _settingsBindingCodeLength - 1
                                  ? 0
                                  : 8,
                            ),
                            child: _LingBindingCodeCell(
                              digit: index < code.length ? code[index] : '',
                              active:
                                  focusNode.hasFocus &&
                                  index ==
                                      code.length.clamp(
                                        0,
                                        _settingsBindingCodeLength - 1,
                                      ),
                              palette: palette,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LingBindingCodeCell extends StatelessWidget {
  const _LingBindingCodeCell({
    required this.digit,
    required this.active,
    required this.palette,
  });

  final String digit;
  final bool active;
  final LingPalette palette;

  @override
  Widget build(BuildContext context) {
    final borderColor = active ? palette.inputCursor : palette.fieldBorder;
    final tint = active
        ? palette.accentSoft.withValues(alpha: context.isDarkMode ? 0.30 : 0.88)
        : palette.inputBackground;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: active ? 1.4 : 1),
        ),
      ),
      child: LingGlassSurface(
        height: 56,
        radius: 16,
        tone: LingGlassSurfaceTone.muted,
        tintColor: tint,
        alignment: Alignment.center,
        child: Text(
          digit,
          style: TextStyle(
            color: palette.inputForeground,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

enum AccountBindingErrorAction { sendCode, bind }

String localizeAccountBindingError({
  required Object error,
  required LingStrings strings,
  required AccountBindingTarget target,
  required AccountBindingErrorAction action,
}) {
  if (error is! ApiException) {
    return _defaultBindingErrorMessage(strings, target, action);
  }

  final normalizedText = _collectBindingErrorText(error).toLowerCase();
  if (_isBindingAlreadyInUse(error, normalizedText)) {
    return _alreadyInUseBindingMessage(strings, target);
  }
  if (_isBindingVerificationCodeError(normalizedText)) {
    return strings.bindingVerificationCodeInvalid;
  }
  if (_isBindingTooFrequent(error, normalizedText)) {
    return strings.bindingRequestTooFrequent;
  }
  return _defaultBindingErrorMessage(strings, target, action);
}

String _defaultBindingErrorMessage(
  LingStrings strings,
  AccountBindingTarget target,
  AccountBindingErrorAction action,
) {
  if (action == AccountBindingErrorAction.sendCode) {
    return switch (target) {
      AccountBindingTarget.phone => strings.phoneVerificationCodeSendFailed,
      AccountBindingTarget.email => strings.emailVerificationCodeSendFailed,
      AccountBindingTarget.apple => strings.appleIdentityBindingFailed,
      AccountBindingTarget.wechat => strings.wechatIdentityBindingFailed,
    };
  }

  return switch (target) {
    AccountBindingTarget.phone => strings.phoneBindingFailed,
    AccountBindingTarget.email => strings.emailBindingFailed,
    AccountBindingTarget.apple => strings.appleIdentityBindingFailed,
    AccountBindingTarget.wechat => strings.wechatIdentityBindingFailed,
  };
}

String _alreadyInUseBindingMessage(
  LingStrings strings,
  AccountBindingTarget target,
) {
  return switch (target) {
    AccountBindingTarget.phone => strings.phoneAlreadyInUse,
    AccountBindingTarget.email => strings.emailAlreadyInUse,
    AccountBindingTarget.apple => strings.appleIdentityAlreadyInUse,
    AccountBindingTarget.wechat => strings.wechatIdentityAlreadyInUse,
  };
}

bool _isBindingAlreadyInUse(ApiException error, String normalizedText) {
  if (error.statusCode == 409) {
    return true;
  }
  return _bindingErrorContainsAny(normalizedText, const <String>[
    'already bound',
    'already linked',
    'already exists',
    'already in use',
    'has been bound',
    'has been linked',
    'duplicate',
    'conflict',
    'exists already',
    '绑定',
    '已存在',
    '已绑定',
    '重复',
  ]);
}

bool _isBindingVerificationCodeError(String normalizedText) {
  return _bindingErrorContainsAny(normalizedText, const <String>[
    'invalid code',
    'invalid verification code',
    'verification code is invalid',
    'verification code invalid',
    'code expired',
    'expired code',
    'challenge expired',
    'invalid challenge',
    '验证码错误',
    '验证码无效',
    '验证码已过期',
    '验证码过期',
  ]);
}

bool _isBindingTooFrequent(ApiException error, String normalizedText) {
  if (error.statusCode == 429) {
    return true;
  }
  return _bindingErrorContainsAny(normalizedText, const <String>[
    'too many requests',
    'too many attempts',
    'rate limit',
    'try again later',
    '操作频繁',
    '过于频繁',
  ]);
}

bool _bindingErrorContainsAny(String haystack, List<String> needles) {
  for (final needle in needles) {
    if (haystack.contains(needle)) {
      return true;
    }
  }
  return false;
}

String _collectBindingErrorText(ApiException error) {
  final buffer = StringBuffer(error.message);
  _appendBindingErrorObject(buffer, error.cause);
  return buffer.toString();
}

void _appendBindingErrorObject(StringBuffer buffer, Object? value) {
  if (value == null) {
    return;
  }
  if (value is String) {
    buffer.write(' ');
    buffer.write(value);
    return;
  }
  if (value is Map) {
    for (final entry in value.entries) {
      _appendBindingErrorObject(buffer, entry.key);
      _appendBindingErrorObject(buffer, entry.value);
    }
    return;
  }
  if (value is Iterable) {
    for (final item in value) {
      _appendBindingErrorObject(buffer, item);
    }
    return;
  }
  buffer.write(' ');
  buffer.write(value.toString());
}
