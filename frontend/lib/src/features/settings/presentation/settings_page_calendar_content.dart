import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/calendar/models/apple_calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_integration_models.dart';
import 'package:ling/src/features/settings/presentation/settings_page_calendar_support.dart';
import 'package:ling/src/features/settings/presentation/settings_page_components.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/surface_group.dart';
import 'package:ling/src/shared/presentation/tap_haptics.dart';

enum _CalendarProviderMenuAction { refresh, disconnect }

const double _calendarProviderHorizontalPadding = 16;
const double _calendarProviderIconColumnWidth = 32;
const double _calendarProviderIconTextGap = 12;
const double _calendarProviderTextInset =
    _calendarProviderHorizontalPadding +
    _calendarProviderIconColumnWidth +
    _calendarProviderIconTextGap;

class CalendarSettingsContent extends StatelessWidget {
  const CalendarSettingsContent({
    super.key,
    required this.strings,
    required this.appleCalendarPermission,
    required this.calendarConnections,
    required this.calendarSyncSettings,
    required this.onOpenCalendarProviderApp,
    required this.onRefreshCalendarProvider,
    required this.onDisconnectCalendarProvider,
    required this.onOpenAppleCalendarSystemSettings,
    required this.onCalendarSyncSettingsChanged,
  });

  final LingStrings strings;
  final AppleCalendarPermissionState appleCalendarPermission;
  final List<CalendarConnectionSummary> calendarConnections;
  final CalendarSyncSettings calendarSyncSettings;
  final Future<void> Function(CalendarProviderId provider)
  onOpenCalendarProviderApp;
  final Future<void> Function(CalendarProviderId provider)
  onRefreshCalendarProvider;
  final Future<void> Function(CalendarProviderId provider)
  onDisconnectCalendarProvider;
  final Future<void> Function() onOpenAppleCalendarSystemSettings;
  final ValueChanged<CalendarSyncSettings> onCalendarSyncSettingsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _CalendarProviderSettingsSection(
          strings: strings,
          appleCalendarPermission: appleCalendarPermission,
          calendarConnections: calendarConnections,
          calendarSyncSettings: calendarSyncSettings,
          onOpenAppleCalendarSystemSettings: onOpenAppleCalendarSystemSettings,
          onOpenCalendarProviderApp: onOpenCalendarProviderApp,
          onRefreshCalendarProvider: onRefreshCalendarProvider,
          onDisconnectCalendarProvider: onDisconnectCalendarProvider,
          onCalendarSyncSettingsChanged: onCalendarSyncSettingsChanged,
        ),
      ],
    );
  }
}

class NotificationSettingsContent extends StatefulWidget {
  const NotificationSettingsContent({
    super.key,
    required this.strings,
    required this.calendarNotificationPermission,
    required this.calendarNotificationSettings,
    required this.onOpenCalendarNotificationSystemSettings,
    required this.onCalendarNotificationSettingsChanged,
    required this.formatCalendarNotificationModeLabel,
  });

  final LingStrings strings;
  final CalendarNotificationPermissionState calendarNotificationPermission;
  final CalendarNotificationSettings calendarNotificationSettings;
  final Future<void> Function() onOpenCalendarNotificationSystemSettings;
  final ValueChanged<CalendarNotificationSettings>
  onCalendarNotificationSettingsChanged;
  final String Function(CalendarNotificationDeliveryMode mode)
  formatCalendarNotificationModeLabel;

  @override
  State<NotificationSettingsContent> createState() =>
      _NotificationSettingsContentState();
}

class _NotificationSettingsContentState
    extends State<NotificationSettingsContent> {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final settings = widget.calendarNotificationSettings.copyWith(
      deliveryChannel: CalendarNotificationDeliveryChannel.lingLocal,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        LingSettingsSectionTitle(
          title: widget.strings.defaultNotificationStyleTitle,
        ),
        const SizedBox(height: 8),
        LingSurfaceGroup(
          hasBackground: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.strings.calendarNotificationEnabledTitle,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget
                                .strings
                                .calendarNotificationEnabledDescription,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    LingAdaptiveSwitch(
                      value: settings.enabled,
                      onChanged: (value) => unawaited(
                        _handleNotificationEnabledChanged(value, settings),
                      ),
                    ),
                  ],
                ),
              ),
              const LingSettingsGroupDivider(),
              LingSettingsCompactDropdownRow(
                title: widget.strings.calendarNotificationMethodTitle,
                dropdown: _buildNotificationModeDropdown(settings),
              ),
              const LingSettingsGroupDivider(),
              LingSettingsCompactDropdownRow(
                title: widget.strings.calendarNotificationLeadTimeTitle,
                dropdown: _buildNotificationMinutesDropdown(settings),
              ),
              const LingSettingsGroupDivider(),
              LingSettingsCompactDropdownRow(
                title: widget.strings.calendarNotificationAtStartTitle,
                dropdown: _buildNotificationAtStartDropdown(settings),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> _ensureCalendarNotificationPermissionAuthorized() async {
    if (widget.calendarNotificationPermission ==
        CalendarNotificationPermissionState.granted) {
      return true;
    }
    if (widget.calendarNotificationPermission ==
        CalendarNotificationPermissionState.unsupported) {
      return false;
    }

    final confirmed = await showLingAdaptiveConfirmationDialog(
      context: context,
      title: widget.strings.calendarNotificationPermissionRequiredTitle,
      message: widget.strings.calendarNotificationPermissionRequiredMessage,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      confirmLabel: widget.strings.openSystemSettings,
    );
    if (confirmed == true) {
      await widget.onOpenCalendarNotificationSystemSettings();
    }
    return false;
  }

  Widget _buildNotificationModeDropdown(CalendarNotificationSettings settings) {
    return LingSettingsSheetPickerButton<CalendarNotificationDeliveryMode>(
      key: ValueKey('calendar_notification_mode_${settings.deliveryMode.name}'),
      iconKey: const Key('settings_calendar_notification_mode_dropdown_icon'),
      sheetTitle: widget.strings.calendarNotificationMethodTitle,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      value: settings.deliveryMode,
      options: [
        for (final mode in CalendarNotificationDeliveryMode.values)
          LingSettingsPickerOption(
            value: mode,
            label: widget.formatCalendarNotificationModeLabel(mode),
          ),
      ],
      onChanged: (mode) {
        unawaited(_handleNotificationModeChanged(mode, settings));
      },
    );
  }

  Widget _buildNotificationMinutesDropdown(
    CalendarNotificationSettings settings,
  ) {
    return LingSettingsSheetPickerButton<int>(
      key: ValueKey('calendar_notification_minutes_${settings.minutesBefore}'),
      iconKey: const Key(
        'settings_calendar_notification_minutes_dropdown_icon',
      ),
      sheetTitle: widget.strings.calendarNotificationLeadTimeTitle,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      value: settings.minutesBefore,
      options: [
        for (final minutes in calendarNotificationMinuteOptions)
          LingSettingsPickerOption(
            value: minutes,
            label: widget.strings.notifyBeforeMinutes(minutes),
          ),
      ],
      onChanged: (minutes) {
        unawaited(_handleNotificationMinutesChanged(minutes, settings));
      },
    );
  }

  Widget _buildNotificationAtStartDropdown(
    CalendarNotificationSettings settings,
  ) {
    return LingSettingsSheetPickerButton<bool>(
      key: ValueKey('calendar_notification_at_start_${settings.notifyAtStart}'),
      iconKey: const Key(
        'settings_calendar_notification_at_start_dropdown_icon',
      ),
      sheetTitle: widget.strings.calendarNotificationAtStartTitle,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      value: settings.notifyAtStart,
      options: [
        LingSettingsPickerOption(
          value: true,
          label: _notificationAtStartLabel(true),
        ),
        LingSettingsPickerOption(
          value: false,
          label: _notificationAtStartLabel(false),
        ),
      ],
      onChanged: (value) {
        unawaited(_handleNotificationAtStartChanged(value, settings));
      },
    );
  }

  Future<void> _handleNotificationModeChanged(
    CalendarNotificationDeliveryMode mode,
    CalendarNotificationSettings settings,
  ) async {
    if (!await _ensureCalendarNotificationPermissionAuthorized()) {
      return;
    }
    widget.onCalendarNotificationSettingsChanged(
      settings.copyWith(deliveryMode: mode),
    );
  }

  Future<void> _handleNotificationEnabledChanged(
    bool value,
    CalendarNotificationSettings settings,
  ) async {
    if (value && !await _ensureCalendarNotificationPermissionAuthorized()) {
      return;
    }
    widget.onCalendarNotificationSettingsChanged(
      settings.copyWith(enabled: value),
    );
  }

  Future<void> _handleNotificationMinutesChanged(
    int minutes,
    CalendarNotificationSettings settings,
  ) async {
    if (!await _ensureCalendarNotificationPermissionAuthorized()) {
      return;
    }
    widget.onCalendarNotificationSettingsChanged(
      settings.copyWith(minutesBefore: minutes),
    );
  }

  Future<void> _handleNotificationAtStartChanged(
    bool value,
    CalendarNotificationSettings settings,
  ) async {
    if (!await _ensureCalendarNotificationPermissionAuthorized()) {
      return;
    }
    widget.onCalendarNotificationSettingsChanged(
      settings.copyWith(notifyAtStart: value),
    );
  }

  String _notificationAtStartLabel(bool value) {
    return value
        ? widget.strings.notificationOptionEnabled
        : widget.strings.notificationOptionDisabled;
  }
}

class _CalendarProviderSettingsSection extends StatelessWidget {
  const _CalendarProviderSettingsSection({
    required this.strings,
    required this.appleCalendarPermission,
    required this.calendarConnections,
    required this.calendarSyncSettings,
    required this.onOpenAppleCalendarSystemSettings,
    required this.onOpenCalendarProviderApp,
    required this.onRefreshCalendarProvider,
    required this.onDisconnectCalendarProvider,
    required this.onCalendarSyncSettingsChanged,
  });

  final LingStrings strings;
  final AppleCalendarPermissionState appleCalendarPermission;
  final List<CalendarConnectionSummary> calendarConnections;
  final CalendarSyncSettings calendarSyncSettings;
  final Future<void> Function() onOpenAppleCalendarSystemSettings;
  final Future<void> Function(CalendarProviderId provider)
  onOpenCalendarProviderApp;
  final Future<void> Function(CalendarProviderId provider)
  onRefreshCalendarProvider;
  final Future<void> Function(CalendarProviderId provider)
  onDisconnectCalendarProvider;
  final ValueChanged<CalendarSyncSettings> onCalendarSyncSettingsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final provider in visibleSettingsCalendarProviders) ...[
          _CalendarProviderGroup(
            provider: provider,
            title: settingsCalendarProviderTitle(strings, provider),
            child: _CalendarProviderCard(
              key: Key('calendar_provider_card_${provider.name}'),
              strings: strings,
              provider: provider,
              appleCalendarPermission: appleCalendarPermission,
              calendarConnections: calendarConnections,
              calendarSyncSettings: calendarSyncSettings,
              onAuthorizeTap: () => _openProvider(provider),
              onProviderLongPress: () =>
                  _showCalendarProviderMenu(context, provider),
              onWriteBackChanged: (value) =>
                  _handleWriteBackChanged(provider, value),
            ),
          ),
          if (provider != visibleSettingsCalendarProviders.last)
            const SizedBox(height: 18),
        ],
      ],
    );
  }

  void _openProvider(CalendarProviderId provider) {
    switch (provider) {
      case CalendarProviderId.appleLocal:
        unawaited(onOpenAppleCalendarSystemSettings());
      case CalendarProviderId.feishu:
      case CalendarProviderId.dingtalk:
        unawaited(onOpenCalendarProviderApp(provider));
    }
  }

  void _handleWriteBackChanged(CalendarProviderId provider, bool value) {
    switch (provider) {
      case CalendarProviderId.appleLocal:
        if (appleCalendarPermission != AppleCalendarPermissionState.granted) {
          unawaited(onOpenAppleCalendarSystemSettings());
          return;
        }
        onCalendarSyncSettingsChanged(
          calendarSyncSettings.copyWith(appleWriteBackEnabled: value),
        );
      case CalendarProviderId.feishu:
      case CalendarProviderId.dingtalk:
        return;
    }
  }

  Future<void> _showCalendarProviderMenu(
    BuildContext context,
    CalendarProviderId provider,
  ) async {
    final connection = settingsCalendarConnectionFor(
      calendarConnections,
      provider,
    );
    if (!shouldShowSettingsCalendarProviderMenu(connection)) {
      return;
    }
    final action =
        await showLingAdaptiveActionSheet<_CalendarProviderMenuAction>(
          context: context,
          title: settingsCalendarProviderTitle(strings, provider),
          cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
          actions: <LingAdaptiveActionSheetAction<_CalendarProviderMenuAction>>[
            LingAdaptiveActionSheetAction<_CalendarProviderMenuAction>(
              value: _CalendarProviderMenuAction.refresh,
              label:
                  connection!.status == 'error' ||
                      connection.status == 'action_required'
                  ? strings.retryCalendarProvider
                  : strings.refreshCalendarProvider,
              icon: Icons.sync_rounded,
            ),
            LingAdaptiveActionSheetAction<_CalendarProviderMenuAction>(
              value: _CalendarProviderMenuAction.disconnect,
              label: strings.disconnectCalendarProvider,
              icon: Icons.link_off_rounded,
              isDestructive: true,
            ),
          ],
        );
    if (!context.mounted || action == null) {
      return;
    }
    switch (action) {
      case _CalendarProviderMenuAction.refresh:
        await onRefreshCalendarProvider(provider);
        return;
      case _CalendarProviderMenuAction.disconnect:
        await onDisconnectCalendarProvider(provider);
        return;
    }
  }
}

class _CalendarProviderGroup extends StatelessWidget {
  const _CalendarProviderGroup({
    required this.provider,
    required this.title,
    required this.child,
  });

  final CalendarProviderId provider;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
          child: Row(
            children: [
              Icon(
                _providerIcon(provider),
                size: 15,
                color: palette.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _CalendarProviderCard extends StatelessWidget {
  const _CalendarProviderCard({
    super.key,
    required this.strings,
    required this.provider,
    required this.appleCalendarPermission,
    required this.calendarConnections,
    required this.calendarSyncSettings,
    required this.onAuthorizeTap,
    required this.onWriteBackChanged,
    this.onProviderLongPress,
  });

  final LingStrings strings;
  final CalendarProviderId provider;
  final AppleCalendarPermissionState appleCalendarPermission;
  final List<CalendarConnectionSummary> calendarConnections;
  final CalendarSyncSettings calendarSyncSettings;
  final VoidCallback onAuthorizeTap;
  final ValueChanged<bool> onWriteBackChanged;
  final VoidCallback? onProviderLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final authorized = _isAuthorized;
    final connection = settingsCalendarConnectionFor(
      calendarConnections,
      provider,
    );
    final supportsWriteBack = provider == CalendarProviderId.appleLocal;
    final writeBackEnabled =
        supportsWriteBack &&
        authorized &&
        calendarSyncSettings.appleWriteBackEnabled;

    return LingGlassSurface(
      tone: LingGlassSurfaceTone.elevated,
      quality: LingGlassQuality.standard,
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CalendarProviderAccessRow(
            key: Key('calendar_auth_row_${provider.name}'),
            title: strings.calendarProviderReadAccessTitle,
            subtitle: strings.calendarProviderSyncSubtitle,
            authorizationLabel: _authorizationLabel,
            authorizationLabelColor: authorized ? null : palette.danger,
            onTap: onAuthorizeTap,
            onLongPress: onProviderLongPress,
          ),
          if (authorized) ...[
            _CalendarProviderDiagnostics(
              strings: strings,
              connection: connection,
              eventCount: connection?.eventCount,
            ),
            _CalendarProviderRowDivider(),
            _CalendarProviderWriteBackRow(
              title: strings.calendarProviderWriteBackTitle,
              subtitle: _writeBackSubtitle(supportsWriteBack),
              enabled: writeBackEnabled,
              onChanged: supportsWriteBack
                  ? (value) => onWriteBackChanged(value)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  bool get _isAuthorized {
    if (provider == CalendarProviderId.appleLocal) {
      return appleCalendarPermission == AppleCalendarPermissionState.granted;
    }
    final connection = settingsCalendarConnectionFor(
      calendarConnections,
      provider,
    );
    return connection?.isConnected == true;
  }

  String get _authorizationLabel {
    return settingsCalendarAuthorizationStatusLabel(
      strings: strings,
      provider: provider,
      appleCalendarPermission: appleCalendarPermission,
      calendarConnections: calendarConnections,
    );
  }

  String _writeBackSubtitle(bool supportsWriteBack) {
    if (!supportsWriteBack) {
      return strings.calendarProviderWriteBackUnavailable;
    }
    return calendarSyncSettings.appleWriteBackEnabled
        ? strings.calendarProviderWriteBackOn
        : strings.calendarProviderWriteBackOff;
  }
}

class _CalendarProviderAccessRow extends StatelessWidget {
  const _CalendarProviderAccessRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.authorizationLabel,
    required this.onTap,
    this.authorizationLabelColor,
    this.onLongPress,
  });

  final String title;
  final String subtitle;
  final String authorizationLabel;
  final Color? authorizationLabelColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: LingTapHaptics.wrap(onTap),
      onLongPress: LingTapHaptics.wrap(onLongPress),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _calendarProviderHorizontalPadding,
          16,
          14,
          14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _calendarProviderIconColumnWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.event_available_outlined,
                  color: palette.textPrimary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: _calendarProviderIconTextGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.32,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: LingSettingsDisclosure(
                label: authorizationLabel,
                labelColor: authorizationLabelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarProviderWriteBackRow extends StatelessWidget {
  const _CalendarProviderWriteBackRow({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _calendarProviderHorizontalPadding,
        14,
        14,
        16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _calendarProviderIconColumnWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.sync_rounded,
                color: palette.textPrimary,
                size: 21,
              ),
            ),
          ),
          const SizedBox(width: _calendarProviderIconTextGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: LingAdaptiveSwitch(value: enabled, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class _CalendarProviderRowDivider extends StatelessWidget {
  const _CalendarProviderRowDivider();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(
        left: _calendarProviderTextInset,
        right: 14,
      ),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: palette.textSecondary.withValues(alpha: 0.16),
      ),
    );
  }
}

class _CalendarProviderDiagnostics extends StatelessWidget {
  const _CalendarProviderDiagnostics({
    required this.strings,
    required this.connection,
    required this.eventCount,
  });

  final LingStrings strings;
  final CalendarConnectionSummary? connection;
  final int? eventCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final items = <_CalendarProviderDiagnosticItem>[
      if ((connection?.accountLabel ?? '').trim().isNotEmpty)
        _CalendarProviderDiagnosticItem(
          label: strings.calendarProviderAccountLabel,
          value: connection!.accountLabel!.trim(),
          icon: Icons.account_circle_outlined,
        ),
      _CalendarProviderDiagnosticItem(
        label: strings.calendarProviderSyncedEvents,
        value: '${eventCount ?? 0}',
        icon: Icons.event_note_outlined,
      ),
      _CalendarProviderDiagnosticItem(
        label: strings.calendarProviderLastSyncedAt,
        value: _formatLastSyncedAt(context, connection?.lastSyncedAt),
        icon: Icons.sync_rounded,
      ),
      if ((connection?.lastError ?? '').trim().isNotEmpty)
        _CalendarProviderDiagnosticItem(
          label: strings.calendarProviderSyncError,
          value: connection!.lastError!.trim(),
          icon: Icons.error_outline_rounded,
          isError: true,
        ),
    ];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(_calendarProviderTextInset, 0, 14, 14),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final item in items)
            Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: item.isError
                    ? palette.danger.withValues(alpha: 0.10)
                    : palette.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    size: 14,
                    color: item.isError
                        ? palette.danger
                        : palette.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      '${item.label}: ${item.value}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.isError
                            ? palette.danger
                            : palette.textSecondary,
                        fontSize: 11,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatLastSyncedAt(BuildContext context, String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return strings.calendarProviderNeverSynced;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final local = parsed.toLocal();
    final material = MaterialLocalizations.of(context);
    final date = material.formatShortDate(local);
    final time = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '$date $time';
  }
}

class _CalendarProviderDiagnosticItem {
  const _CalendarProviderDiagnosticItem({
    required this.label,
    required this.value,
    required this.icon,
    this.isError = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isError;
}

IconData _providerIcon(CalendarProviderId provider) {
  return switch (provider) {
    CalendarProviderId.appleLocal => Icons.calendar_month_outlined,
    CalendarProviderId.feishu => Icons.work_outline_rounded,
    CalendarProviderId.dingtalk => Icons.business_center_outlined,
  };
}
