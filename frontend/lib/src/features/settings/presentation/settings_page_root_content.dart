import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ling/src/config/feature_flags.dart';
import 'package:ling/src/core/platform/models/notification_models.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/chat/data/apple_speech_recognition_bridge.dart';
import 'package:ling/src/features/membership/models/membership_models.dart';
import 'package:ling/src/features/membership/presentation/membership_status_card.dart';
import 'package:ling/src/features/settings/data/bridges/photo_library_permission_bridge.dart';
import 'package:ling/src/features/settings/models/account_binding_models.dart';
import 'package:ling/src/features/settings/models/settings_navigation_models.dart';
import 'package:ling/src/features/settings/presentation/settings_identity_support.dart';
import 'package:ling/src/features/settings/presentation/settings_menu_row.dart';
import 'package:ling/src/features/settings/presentation/settings_page_components.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';
import 'package:ling/src/shared/presentation/surface_group.dart';

class SettingsRootContent extends StatelessWidget {
  const SettingsRootContent({
    super.key,
    required this.strings,
    required this.membershipSummary,
    required this.onOpenPage,
    required this.onOpenMembershipPlans,
    required this.onReview,
  });

  final LingStrings strings;
  final MembershipSummary? membershipSummary;
  final ValueChanged<LingSettingsPageId> onOpenPage;
  final void Function(BuildContext context)? onOpenMembershipPlans;
  final Future<void> Function() onReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        LingMembershipStatusCard(
          summary: membershipSummary,
          strings: strings,
          onTap: () => onOpenMembershipPlans?.call(context),
        ),
        const SizedBox(height: 20),
        LingSettingsRowSection(
          rows: [
            LingSettingsRootRowData(
              icon: Icons.shield_outlined,
              title: strings.accountSecuritySectionTitle,
              subtitle: null,
              trailingLabel: null,
              onTap: () => onOpenPage(LingSettingsPageId.accountSecurity),
            ),
            LingSettingsRootRowData(
              icon: Icons.notifications_active_outlined,
              title: strings.notificationsTitle,
              subtitle: null,
              trailingLabel: null,
              onTap: () => onOpenPage(LingSettingsPageId.notifications),
            ),
            LingSettingsRootRowData(
              icon: Icons.calendar_month_outlined,
              title: strings.calendarSectionTitle,
              subtitle: null,
              trailingLabel: null,
              onTap: () => onOpenPage(LingSettingsPageId.calendar),
            ),
            LingSettingsRootRowData(
              icon: Icons.privacy_tip_outlined,
              title: strings.permissionsTitle,
              subtitle: null,
              trailingLabel: null,
              onTap: () => onOpenPage(LingSettingsPageId.permissions),
            ),
            LingSettingsRootRowData(
              icon: Icons.tune_rounded,
              title: strings.generalSectionTitle,
              subtitle: null,
              trailingLabel: null,
              onTap: () => onOpenPage(LingSettingsPageId.general),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _AboutSupportSection(
          strings: strings,
          onOpenPage: onOpenPage,
          onReview: onReview,
        ),
        const Spacer(),
        const SizedBox(height: 28),
        _SettingsPoweredBySageFooter(label: strings.settingsPoweredBySage),
        const SizedBox(height: 8),
      ],
    );
  }
}

class PermissionsSettingsContent extends StatelessWidget {
  const PermissionsSettingsContent({
    super.key,
    required this.strings,
    required this.notificationPermission,
    required this.locationPermission,
    required this.microphonePermission,
    required this.photoLibraryPermission,
    required this.onRequestNotificationPermission,
    required this.onRequestLocationPermission,
    required this.onRequestMicrophonePermission,
    required this.onRequestPhotoLibraryPermission,
    required this.onOpenNotificationSystemSettings,
    required this.onOpenLocationSystemSettings,
  });

  final LingStrings strings;
  final CalendarNotificationPermissionState notificationPermission;
  final DeviceLocationPermissionState locationPermission;
  final SpeechAuthorizationState microphonePermission;
  final PhotoLibraryPermissionState photoLibraryPermission;
  final Future<void> Function() onRequestNotificationPermission;
  final Future<DeviceContextSnapshot?> Function() onRequestLocationPermission;
  final Future<void> Function() onRequestMicrophonePermission;
  final Future<void> Function() onRequestPhotoLibraryPermission;
  final Future<void> Function() onOpenNotificationSystemSettings;
  final Future<void> Function() onOpenLocationSystemSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        LingSurfaceGroup(
          hasBackground: false,
          child: Column(
            children: [
              LingSettingsMenuRow(
                icon: Icons.notifications_outlined,
                title: strings.calendarNotificationPermissionTitle,
                trailing: LingSettingsDisclosure(label: _notificationLabel()),
                onTap: () => _handleNotificationTap(),
              ),
              const LingSettingsGroupDivider(),
              LingSettingsMenuRow(
                icon: Icons.location_on_outlined,
                title: strings.locationPermissionTitle,
                trailing: LingSettingsDisclosure(label: _locationLabel()),
                onTap: () => _handleLocationTap(),
              ),
              const LingSettingsGroupDivider(),
              LingSettingsMenuRow(
                key: const Key('settings_microphone_permission_row'),
                icon: Icons.mic_none_rounded,
                title: strings.microphonePermissionTitle,
                trailing: LingSettingsDisclosure(label: _microphoneLabel()),
                onTap: () => onRequestMicrophonePermission(),
              ),
              const LingSettingsGroupDivider(),
              LingSettingsMenuRow(
                key: const Key('settings_photo_library_permission_row'),
                icon: Icons.photo_library_outlined,
                title: strings.photoPermissionTitle,
                trailing: LingSettingsDisclosure(label: _photoLibraryLabel()),
                onTap: () => onRequestPhotoLibraryPermission(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleNotificationTap() async {
    if (notificationPermission == CalendarNotificationPermissionState.denied) {
      await onOpenNotificationSystemSettings();
      return;
    }
    if (notificationPermission != CalendarNotificationPermissionState.granted &&
        notificationPermission !=
            CalendarNotificationPermissionState.unsupported) {
      await onRequestNotificationPermission();
    }
  }

  Future<void> _handleLocationTap() async {
    if (locationPermission == DeviceLocationPermissionState.denied ||
        locationPermission == DeviceLocationPermissionState.restricted) {
      await onOpenLocationSystemSettings();
      return;
    }
    if (locationPermission != DeviceLocationPermissionState.authorizedAlways &&
        locationPermission !=
            DeviceLocationPermissionState.authorizedWhenInUse &&
        locationPermission != DeviceLocationPermissionState.unsupported) {
      await onRequestLocationPermission();
    }
  }

  String _notificationLabel() {
    switch (notificationPermission) {
      case CalendarNotificationPermissionState.granted:
        return strings.notificationPermissionGranted;
      case CalendarNotificationPermissionState.denied:
        return strings.notificationPermissionDenied;
      case CalendarNotificationPermissionState.notDetermined:
        return strings.notificationPermissionNotDetermined;
      case CalendarNotificationPermissionState.unsupported:
        return strings.notificationPermissionUnsupported;
    }
  }

  String _locationLabel() {
    switch (locationPermission) {
      case DeviceLocationPermissionState.authorizedAlways:
      case DeviceLocationPermissionState.authorizedWhenInUse:
        return strings.notificationPermissionGranted;
      case DeviceLocationPermissionState.denied:
      case DeviceLocationPermissionState.restricted:
        return strings.notificationPermissionDenied;
      case DeviceLocationPermissionState.notDetermined:
        return strings.notificationPermissionNotDetermined;
      case DeviceLocationPermissionState.unsupported:
        return strings.notificationPermissionUnsupported;
      case DeviceLocationPermissionState.unknown:
        return strings.notificationPermissionUnauthorized;
    }
  }

  String _microphoneLabel() {
    switch (microphonePermission) {
      case SpeechAuthorizationState.granted:
        return strings.notificationPermissionGranted;
      case SpeechAuthorizationState.denied:
      case SpeechAuthorizationState.restricted:
        return strings.notificationPermissionDenied;
      case SpeechAuthorizationState.notDetermined:
        return strings.notificationPermissionNotDetermined;
      case SpeechAuthorizationState.unsupported:
        return strings.notificationPermissionUnsupported;
      case SpeechAuthorizationState.unknown:
        return strings.notificationPermissionUnauthorized;
    }
  }

  String _photoLibraryLabel() {
    switch (photoLibraryPermission) {
      case PhotoLibraryPermissionState.granted:
        return strings.notificationPermissionGranted;
      case PhotoLibraryPermissionState.denied:
      case PhotoLibraryPermissionState.restricted:
        return strings.notificationPermissionDenied;
      case PhotoLibraryPermissionState.notDetermined:
        return strings.notificationPermissionNotDetermined;
      case PhotoLibraryPermissionState.unsupported:
        return strings.notificationPermissionUnsupported;
      case PhotoLibraryPermissionState.unknown:
        return strings.notificationPermissionUnauthorized;
    }
  }
}

class AccountSecurityContent extends StatelessWidget {
  const AccountSecurityContent({
    super.key,
    required this.strings,
    required this.profile,
    required this.identities,
    required this.showsNativeIdentityRows,
    required this.onOpenBindingPage,
    required this.onStartNativeIdentityBinding,
    required this.onSignOut,
    required this.onDeleteAccount,
    this.includeSignInMethods = true,
    this.includeAccountSafety = true,
  });

  final LingStrings strings;
  final UserProfile? profile;
  final List<UserIdentity> identities;
  final bool showsNativeIdentityRows;
  final ValueChanged<AccountBindingTarget> onOpenBindingPage;
  final ValueChanged<AccountBindingTarget> onStartNativeIdentityBinding;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onDeleteAccount;
  final bool includeSignInMethods;
  final bool includeAccountSafety;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (includeSignInMethods) ...[
          const SizedBox(height: 20),
          LingSettingsSectionTitle(title: strings.signInMethodsTitle),
          const SizedBox(height: 8),
          _SignInMethodsSection(
            strings: strings,
            profile: profile,
            identities: identities,
            showsNativeIdentityRows: showsNativeIdentityRows,
            onOpenBindingPage: onOpenBindingPage,
            onStartNativeIdentityBinding: onStartNativeIdentityBinding,
          ),
        ],
        if (includeSignInMethods && includeAccountSafety)
          const SizedBox(height: 24),
        if (includeAccountSafety) ...[
          LingSettingsSectionTitle(title: strings.accountSafety),
          const SizedBox(height: 8),
          _AccountSafetySection(
            strings: strings,
            onSignOut: onSignOut,
            onDeleteAccount: onDeleteAccount,
          ),
        ],
      ],
    );
  }
}

class _AboutSupportSection extends StatelessWidget {
  const _AboutSupportSection({
    required this.strings,
    required this.onOpenPage,
    required this.onReview,
  });

  final LingStrings strings;
  final ValueChanged<LingSettingsPageId> onOpenPage;
  final Future<void> Function() onReview;

  @override
  Widget build(BuildContext context) {
    return LingSurfaceGroup(
      hasBackground: false,
      child: Column(
        children: [
          LingSettingsMenuRow(
            key: const Key('settings_about_link'),
            icon: Icons.info_outline_rounded,
            title: strings.aboutLingTitle,
            trailing: const LingSettingsDisclosure(),
            onTap: () => onOpenPage(LingSettingsPageId.aboutLing),
          ),
          const LingSettingsGroupDivider(),
          LingSettingsMenuRow(
            key: const Key('settings_root_review_button'),
            icon: Icons.favorite_border_rounded,
            title: strings.aboutLingReviewAction,
            onTap: () => unawaited(onReview()),
          ),
        ],
      ),
    );
  }
}

class _SettingsPoweredBySageFooter extends StatelessWidget {
  const _SettingsPoweredBySageFooter({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Text(
        label,
        key: const Key('settings_powered_by_sage_footer'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: palette.textSecondary.withValues(alpha: isDark ? 0.52 : 0.46),
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _SignInMethodsSection extends StatelessWidget {
  const _SignInMethodsSection({
    required this.strings,
    required this.profile,
    required this.identities,
    required this.showsNativeIdentityRows,
    required this.onOpenBindingPage,
    required this.onStartNativeIdentityBinding,
  });

  final LingStrings strings;
  final UserProfile? profile;
  final List<UserIdentity> identities;
  final bool showsNativeIdentityRows;
  final ValueChanged<AccountBindingTarget> onOpenBindingPage;
  final ValueChanged<AccountBindingTarget> onStartNativeIdentityBinding;

  @override
  Widget build(BuildContext context) {
    final phone = (profile?.phoneNumber ?? '').trim();
    final email = (profile?.email ?? '').trim();
    final appleIdentity = settingsIdentityForProvider(identities, 'apple');
    final weChatIdentity = LingFeatureFlags.weChatAuth
        ? settingsIdentityForProvider(identities, 'wechat')
        : null;

    return LingSurfaceGroup(
      hasBackground: false,
      child: Column(
        children: [
          LingSettingsMenuRow(
            key: const Key('settings_phone_binding_row'),
            icon: Icons.phone_iphone_rounded,
            leading: const LingSettingsBindingMethodIcon(
              target: AccountBindingTarget.phone,
            ),
            title: strings.phoneNumber,
            trailing: LingSettingsDisclosure(
              label: phone.isEmpty ? strings.unboundStatus : phone,
            ),
            onTap: () => onOpenBindingPage(AccountBindingTarget.phone),
          ),
          const LingSettingsGroupDivider(),
          LingSettingsMenuRow(
            key: const Key('settings_email_binding_row'),
            icon: Icons.alternate_email_rounded,
            leading: const LingSettingsBindingMethodIcon(
              target: AccountBindingTarget.email,
            ),
            title: strings.emailAddress,
            trailing: LingSettingsDisclosure(
              label: email.isEmpty ? strings.unboundStatus : email,
            ),
            onTap: () => onOpenBindingPage(AccountBindingTarget.email),
          ),
          if (showsNativeIdentityRows) ...[
            const LingSettingsGroupDivider(),
            LingSettingsMenuRow(
              icon: Icons.verified_user_outlined,
              leading: const LingSettingsBindingMethodIcon(
                target: AccountBindingTarget.apple,
              ),
              title: strings.appleSignInMethodTitle,
              trailing: LingSettingsDisclosure(
                label: settingsIdentitySubtitle(strings, appleIdentity),
              ),
              onTap: appleIdentity == null
                  ? () =>
                        onStartNativeIdentityBinding(AccountBindingTarget.apple)
                  : null,
            ),
            if (LingFeatureFlags.weChatAuth) ...[
              const LingSettingsGroupDivider(),
              LingSettingsMenuRow(
                key: const Key('settings_wechat_binding_row'),
                icon: Icons.chat_bubble_outline_rounded,
                leading: const LingSettingsBindingMethodIcon(
                  target: AccountBindingTarget.wechat,
                ),
                title: strings.wechatSignInMethodTitle,
                trailing: LingSettingsDisclosure(
                  label: settingsIdentitySubtitle(strings, weChatIdentity),
                ),
                onTap: weChatIdentity == null
                    ? () => onStartNativeIdentityBinding(
                        AccountBindingTarget.wechat,
                      )
                    : null,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AccountSafetySection extends StatelessWidget {
  const _AccountSafetySection({
    required this.strings,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final LingStrings strings;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LingSettingsActionButton(
          key: const Key('settings_sign_out_button'),
          icon: Icons.logout_rounded,
          label: strings.signOut,
          onPressed: () => unawaited(onSignOut()),
        ),
        const SizedBox(height: 12),
        LingSettingsActionButton(
          key: const Key('settings_delete_account_button'),
          icon: Icons.delete_outline_rounded,
          label: strings.deleteAccountTitle,
          destructive: true,
          onPressed: () => unawaited(onDeleteAccount()),
        ),
      ],
    );
  }
}
