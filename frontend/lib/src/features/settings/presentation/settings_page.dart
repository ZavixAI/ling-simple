import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ling/src/features/settings/models/account_binding_models.dart';
import 'package:ling/src/features/settings/models/settings_navigation_models.dart';
import 'package:ling/src/features/settings/presentation/settings_account_binding_panel.dart';
import 'package:ling/src/features/settings/presentation/settings_font_size_widgets.dart';
import 'package:ling/src/features/settings/presentation/settings_menu_row.dart';
import 'package:ling/src/features/settings/presentation/settings_page_about_content.dart';
import 'package:ling/src/features/settings/presentation/settings_page_calendar_content.dart';
import 'package:ling/src/features/settings/presentation/settings_page_chrome.dart';
import 'package:ling/src/features/settings/presentation/settings_page_components.dart';
import 'package:ling/src/features/settings/presentation/settings_page_models.dart';
import 'package:ling/src/features/settings/presentation/settings_page_root_content.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/font_size_preference.dart';
import 'package:ling/src/shared/presentation/legal_documents.dart';
import 'package:ling/src/shared/presentation/notice.dart';
import 'package:ling/src/shared/presentation/surface_group.dart';

export 'settings_page_calendar_support.dart'
    show
        settingsCalendarAuthorizationStatusLabel,
        shouldShowSettingsCalendarProviderMenu,
        visibleSettingsCalendarProviders;
export 'settings_page_models.dart';

const String _lingAppVersion = String.fromEnvironment(
  'LING_APP_VERSION',
  defaultValue: '1.0.1+2026040902',
);

class LingSettingsPage extends StatefulWidget {
  const LingSettingsPage({
    super.key,
    required this.data,
    required this.actions,
    this.isOpen = true,
    this.initialPage = LingSettingsPageId.root,
  });

  final LingSettingsPageViewModel data;
  final LingSettingsPageCallbacks actions;
  final bool isOpen;
  final LingSettingsPageId initialPage;

  LingStrings get strings => data.strings;

  @override
  State<LingSettingsPage> createState() => _LingSettingsPageState();
}

class _LingSettingsPageState extends State<LingSettingsPage> {
  late LingSettingsPageId _page;
  late LingFontSizeLevel _fontSizeLevel;

  LingStrings get s => widget.strings;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _fontSizeLevel = widget.data.fontSizeLevel;
  }

  @override
  void didUpdateWidget(covariant LingSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isOpen && oldWidget.initialPage != widget.initialPage) {
      _page = widget.initialPage;
    }
    if (oldWidget.data.fontSizeLevel != widget.data.fontSizeLevel) {
      _fontSizeLevel = widget.data.fontSizeLevel;
    }
  }

  void _setPage(LingSettingsPageId page) {
    if (_page == page) {
      return;
    }
    setState(() => _page = page);
    widget.actions.onPageChanged?.call(page.name);
  }

  void _back() {
    if (_page == LingSettingsPageId.root) {
      widget.actions.onClose();
      return;
    }
    _setPage(lingSettingsBackTargetFor(_page));
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageChrome(
      title: _titleForPage(),
      canGoBack: _page != LingSettingsPageId.root,
      onBack: _back,
      body: KeyedSubtree(
        key: ValueKey<String>('settings_page_${_page.name}'),
        child: _buildPage(context),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    return switch (_page) {
      LingSettingsPageId.root => _settingsScroll(
        SettingsRootContent(
          strings: s,
          membershipSummary: widget.data.membershipSummary,
          onOpenPage: _setPage,
          onOpenMembershipPlans: widget.actions.onOpenMembershipPlans,
          onReview: () async {},
        ),
        fillHeight: true,
      ),
      LingSettingsPageId.accountSecurity => _settingsScroll(
        AccountSecurityContent(
          strings: s,
          profile: widget.data.profile,
          identities: widget.data.identities,
          showsNativeIdentityRows: true,
          onOpenBindingPage: _openBindingPage,
          onStartNativeIdentityBinding: _startNativeIdentityBinding,
          onSignOut: widget.actions.onSignOut,
          onDeleteAccount: widget.actions.onDeleteAccount,
        ),
      ),
      LingSettingsPageId.signInMethods => _settingsScroll(
        AccountSecurityContent(
          strings: s,
          profile: widget.data.profile,
          identities: widget.data.identities,
          showsNativeIdentityRows: true,
          onOpenBindingPage: _openBindingPage,
          onStartNativeIdentityBinding: _startNativeIdentityBinding,
          onSignOut: widget.actions.onSignOut,
          onDeleteAccount: widget.actions.onDeleteAccount,
          includeAccountSafety: false,
        ),
      ),
      LingSettingsPageId.accountSafety => _settingsScroll(
        AccountSecurityContent(
          strings: s,
          profile: widget.data.profile,
          identities: widget.data.identities,
          showsNativeIdentityRows: true,
          onOpenBindingPage: _openBindingPage,
          onStartNativeIdentityBinding: _startNativeIdentityBinding,
          onSignOut: widget.actions.onSignOut,
          onDeleteAccount: widget.actions.onDeleteAccount,
          includeSignInMethods: false,
        ),
      ),
      LingSettingsPageId.bindPhone => _bindingPanel(AccountBindingTarget.phone),
      LingSettingsPageId.bindEmail => _bindingPanel(AccountBindingTarget.email),
      LingSettingsPageId.calendar => _settingsScroll(
        CalendarSettingsContent(
          strings: s,
          appleCalendarPermission: widget.data.appleCalendarPermission,
          calendarConnections: widget.data.calendarConnections,
          calendarSyncSettings: widget.data.calendarSyncSettings,
          onOpenCalendarProviderApp: widget.actions.onOpenCalendarProviderApp,
          onRefreshCalendarProvider: widget.actions.onRefreshCalendarProvider,
          onDisconnectCalendarProvider:
              widget.actions.onDisconnectCalendarProvider,
          onOpenAppleCalendarSystemSettings:
              widget.actions.onOpenAppleCalendarSystemSettings,
          onCalendarSyncSettingsChanged:
              widget.actions.onCalendarSyncSettingsChanged,
        ),
      ),
      LingSettingsPageId.notifications => _settingsScroll(
        NotificationSettingsContent(
          strings: s,
          calendarNotificationPermission:
              widget.data.calendarNotificationPermission,
          calendarNotificationSettings:
              widget.data.calendarNotificationSettings,
          onOpenCalendarNotificationSystemSettings:
              widget.actions.onOpenCalendarNotificationSystemSettings,
          onCalendarNotificationSettingsChanged:
              widget.actions.onCalendarNotificationSettingsChanged,
          formatCalendarNotificationModeLabel:
              widget.actions.formatCalendarNotificationModeLabel,
        ),
      ),
      LingSettingsPageId.permissions => _settingsScroll(
        PermissionsSettingsContent(
          strings: s,
          notificationPermission: widget.data.calendarNotificationPermission,
          locationPermission: widget.data.locationPermission,
          microphonePermission: widget.data.microphonePermission,
          photoLibraryPermission: widget.data.photoLibraryPermission,
          onRequestNotificationPermission:
              widget.actions.onRequestNotificationPermission,
          onRequestLocationPermission:
              widget.actions.onRequestLocationPermission,
          onRequestMicrophonePermission:
              widget.actions.onRequestMicrophonePermission,
          onRequestPhotoLibraryPermission:
              widget.actions.onRequestPhotoLibraryPermission,
          onOpenNotificationSystemSettings:
              widget.actions.onOpenCalendarNotificationSystemSettings,
          onOpenLocationSystemSettings:
              widget.actions.onOpenLocationSystemSettings,
        ),
      ),
      LingSettingsPageId.general => _settingsScroll(_generalContent()),
      LingSettingsPageId.appearance => _settingsScroll(_appearanceContent()),
      LingSettingsPageId.fontSize => _settingsScroll(_fontSizeContent()),
      LingSettingsPageId.language => _settingsScroll(_languageContent()),
      LingSettingsPageId.preferredInputMode => _settingsScroll(
        _preferredInputModeContent(),
      ),
      LingSettingsPageId.timezoneInfo => _settingsScroll(
        _infoContent(
          icon: Icons.schedule_outlined,
          title: s.timezoneTitle,
          value: widget.data.timezone,
        ),
      ),
      LingSettingsPageId.aboutLing => _settingsScroll(
        AboutLingContent(
          strings: s,
          appVersion: _lingAppVersion,
          onOpenPage: _setPage,
        ),
        fillHeight: true,
      ),
      LingSettingsPageId.privacy => LegalDocumentContent(
        strings: s,
        type: LingLegalDocumentType.privacy,
      ),
      LingSettingsPageId.security => LegalDocumentContent(
        strings: s,
        type: LingLegalDocumentType.security,
      ),
    };
  }

  Widget _settingsScroll(Widget child, {bool fillHeight = false}) {
    if (!fillHeight) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: child,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - 28),
            ),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }

  Widget _generalContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        LingSettingsRowSection(
          rows: [
            LingSettingsRootRowData(
              icon: Icons.palette_outlined,
              title: s.appearance,
              subtitle: null,
              trailingLabel: _themeModeLabel(widget.data.themeMode),
              onTap: () => _setPage(LingSettingsPageId.appearance),
            ),
            LingSettingsRootRowData(
              icon: Icons.language_rounded,
              title: s.languageTitle,
              subtitle: null,
              trailingLabel: widget.data.localeCode.startsWith('zh')
                  ? '简体中文'
                  : 'English',
              onTap: () => _setPage(LingSettingsPageId.language),
            ),
            LingSettingsRootRowData(
              icon: Icons.text_fields_rounded,
              title: settingsFontSizeTitle(s),
              subtitle: null,
              trailingLabel: settingsFontSizeLevelLabel(s, _fontSizeLevel),
              onTap: () => _setPage(LingSettingsPageId.fontSize),
            ),
            LingSettingsRootRowData(
              icon: Icons.keyboard_voice_outlined,
              title: s.preferredInputModeTitle,
              subtitle: null,
              trailingLabel: _inputModeLabel(widget.data.preferredInputMode),
              onTap: () => _setPage(LingSettingsPageId.preferredInputMode),
            ),
            LingSettingsRootRowData(
              icon: Icons.schedule_outlined,
              title: s.timezoneTitle,
              subtitle: null,
              trailingLabel: widget.data.timezone,
              onTap: () => _setPage(LingSettingsPageId.timezoneInfo),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LingSettingsActionButton(
          icon: Icons.cleaning_services_outlined,
          label: s.clearLocalImageCacheAction,
          onPressed: widget.actions.onClearLocalImageCache == null
              ? null
              : () => unawaited(widget.actions.onClearLocalImageCache!()),
        ),
      ],
    );
  }

  Widget _appearanceContent() {
    return _choiceSection([
      _choiceRow(
        icon: Icons.brightness_auto_rounded,
        title: s.followSystem,
        selected: widget.data.themeMode == ThemeMode.system,
        onTap: () => widget.actions.onThemeModeChanged(ThemeMode.system),
      ),
      _choiceRow(
        icon: Icons.light_mode_outlined,
        title: s.lightTheme,
        selected: widget.data.themeMode == ThemeMode.light,
        onTap: () => widget.actions.onThemeModeChanged(ThemeMode.light),
      ),
      _choiceRow(
        icon: Icons.dark_mode_outlined,
        title: s.darkTheme,
        selected: widget.data.themeMode == ThemeMode.dark,
        onTap: () => widget.actions.onThemeModeChanged(ThemeMode.dark),
      ),
    ]);
  }

  Widget _fontSizeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        LingSettingsFontSizeControl(
          level: _fontSizeLevel,
          onChanged: (level) {
            setState(() => _fontSizeLevel = level);
            widget.actions.onFontSizeLevelChanged?.call(level);
            showLingTopNotice(context, s.savedToLocal);
          },
        ),
        const SizedBox(height: 14),
        LingSettingsFontSizePreview(
          level: _fontSizeLevel,
          previewText: settingsFontSizePreviewText(s),
        ),
      ],
    );
  }

  Widget _languageContent() {
    return _choiceSection([
      _choiceRow(
        icon: Icons.translate_rounded,
        title: '简体中文',
        selected: widget.data.localeCode.startsWith('zh'),
        onTap: () => widget.actions.onLocaleChanged('zh-CN'),
      ),
      _choiceRow(
        icon: Icons.translate_rounded,
        title: 'English',
        selected: widget.data.localeCode.startsWith('en'),
        onTap: () => widget.actions.onLocaleChanged('en'),
      ),
    ]);
  }

  Widget _preferredInputModeContent() {
    return _choiceSection([
      _choiceRow(
        icon: Icons.keyboard_rounded,
        title: s.preferredInputModeText,
        selected: widget.data.preferredInputMode == 'text',
        onTap: () => widget.actions.onPreferredInputModeChanged('text'),
      ),
      _choiceRow(
        icon: Icons.mic_none_rounded,
        title: s.preferredInputModeVoice,
        selected: widget.data.preferredInputMode == 'voice',
        onTap: () => widget.actions.onPreferredInputModeChanged('voice'),
      ),
    ]);
  }

  Widget _choiceSection(List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        LingSurfaceGroup(
          hasBackground: false,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i != rows.length - 1) const LingSettingsGroupDivider(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _choiceRow({
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return LingSettingsMenuRow(
      icon: icon,
      title: title,
      trailing: selected ? const Icon(Icons.check_rounded) : null,
      onTap: onTap,
    );
  }

  Widget _infoContent({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        const SizedBox(height: 20),
        LingSettingsRowSection(
          rows: [
            LingSettingsRootRowData(
              icon: icon,
              title: title,
              subtitle: null,
              trailingLabel: value,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _bindingPanel(AccountBindingTarget target) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        LingSettingsAccountBindingPanel(
          target: target,
          strings: s,
          initialPhoneCountry: widget.data.initialPhoneCountry,
          initialPhoneNumber: widget.data.profile?.phoneNumber,
          initialEmail: widget.data.profile?.email,
          bindingState: target == AccountBindingTarget.phone
              ? widget.data.phoneBindingState
              : widget.data.emailBindingState,
          onSendPhoneCode: widget.actions.onSendPhoneBindingCode,
          onSendEmailCode: widget.actions.onSendEmailBindingCode,
          onBindPhone: widget.actions.onBindPhone,
          onBindEmail: widget.actions.onBindEmail,
          onCompleted: (result) =>
              widget.actions.onBindingCompleted(target, result),
        ),
      ],
    );
  }

  void _openBindingPage(AccountBindingTarget target) {
    switch (target) {
      case AccountBindingTarget.phone:
        _setPage(LingSettingsPageId.bindPhone);
      case AccountBindingTarget.email:
        _setPage(LingSettingsPageId.bindEmail);
      case AccountBindingTarget.apple:
      case AccountBindingTarget.wechat:
        _startNativeIdentityBinding(target);
    }
  }

  void _startNativeIdentityBinding(AccountBindingTarget target) {
    switch (target) {
      case AccountBindingTarget.apple:
        unawaited(
          widget.actions.onBindApple().then(
            (result) => widget.actions.onBindingCompleted(target, result),
          ),
        );
      case AccountBindingTarget.wechat:
        unawaited(
          widget.actions.onBindWeChat().then(
            (result) => widget.actions.onBindingCompleted(target, result),
          ),
        );
      case AccountBindingTarget.phone:
      case AccountBindingTarget.email:
        _openBindingPage(target);
    }
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => s.followSystem,
      ThemeMode.light => s.lightTheme,
      ThemeMode.dark => s.darkTheme,
    };
  }

  String _inputModeLabel(String mode) {
    return mode == 'voice'
        ? s.preferredInputModeVoice
        : s.preferredInputModeText;
  }

  String _titleForPage() {
    return switch (_page) {
      LingSettingsPageId.root => s.settingsTitle,
      LingSettingsPageId.accountSecurity => s.accountSecuritySectionTitle,
      LingSettingsPageId.signInMethods => s.signInMethodsTitle,
      LingSettingsPageId.accountSafety => s.accountSafety,
      LingSettingsPageId.bindPhone => s.phoneNumber,
      LingSettingsPageId.bindEmail => s.emailAddress,
      LingSettingsPageId.calendar => s.calendarSectionTitle,
      LingSettingsPageId.notifications => s.notificationsTitle,
      LingSettingsPageId.permissions => s.permissionsTitle,
      LingSettingsPageId.general => s.generalSectionTitle,
      LingSettingsPageId.appearance => s.appearance,
      LingSettingsPageId.fontSize => settingsFontSizeTitle(s),
      LingSettingsPageId.language => s.languageTitle,
      LingSettingsPageId.preferredInputMode => s.preferredInputModeTitle,
      LingSettingsPageId.timezoneInfo => s.timezoneTitle,
      LingSettingsPageId.aboutLing => s.aboutLingTitle,
      LingSettingsPageId.privacy => s.privacyAgreementTitle,
      LingSettingsPageId.security => s.securityAgreementTitle,
    };
  }
}
