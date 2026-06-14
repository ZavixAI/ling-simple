import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/application/app_session_lifecycle_coordinator.dart';
import 'package:ling/src/app/application/app_shell_controller.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/app/presentation/authenticated_shell.dart';
import 'package:ling/src/core/async/single_flight.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/platform/bridges/deep_link_bridge.dart';
import 'package:ling/src/core/platform/models/notification_models.dart';
import 'package:ling/src/core/providers.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/auth/application/auth_controller.dart';
import 'package:ling/src/features/auth/application/auth_state.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/auth/presentation/login_flow.dart';
import 'package:ling/src/features/calendar/application/calendar_controller.dart';
import 'package:ling/src/features/calendar/application/schedule_event_actions.dart';
import 'package:ling/src/features/calendar/application/schedule_surface_controller.dart';
import 'package:ling/src/features/calendar/models/apple_calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_event_editor_models.dart';
import 'package:ling/src/features/calendar/models/calendar_integration_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/presentation/event_details_sheet.dart';
import 'package:ling/src/features/calendar/presentation/schedule_section.dart';
import 'package:ling/src/features/chat/application/object_reference.dart';
import 'package:ling/src/features/chat/data/apple_speech_recognition_bridge.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';
import 'package:ling/src/features/chat/presentation/chat_section.dart';
import 'package:ling/src/features/chat/presentation/conversation_entry_view.dart';
import 'package:ling/src/features/membership/application/membership_controller.dart';
import 'package:ling/src/features/membership/application/membership_gate.dart';
import 'package:ling/src/features/membership/presentation/membership_gate_sheet.dart';
import 'package:ling/src/features/membership/presentation/membership_subscription_panel.dart';
import 'package:ling/src/features/settings/application/settings_controller.dart';
import 'package:ling/src/features/settings/application/settings_identity_binding_coordinator.dart';
import 'package:ling/src/features/settings/application/settings_state.dart';
import 'package:ling/src/features/settings/data/bridges/photo_library_permission_bridge.dart';
import 'package:ling/src/features/settings/models/account_binding_models.dart';
import 'package:ling/src/features/settings/models/settings_navigation_models.dart';
import 'package:ling/src/features/settings/presentation/settings_page.dart';
import 'package:ling/src/shared/i18n/calendar_notification_formatters.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';
import 'package:ling/src/shared/models/phone_country.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/edge_swipe_back.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/notice.dart';

@visibleForTesting
bool shouldSuppressAppShellErrorNotice(Object error) {
  if (error is! ApiException) {
    return false;
  }
  final message = error.message.trim().toLowerCase();
  return message == 'device session required' ||
      message == 'device session revoked' ||
      message == 'device invoked';
}

enum _ScheduleSurfaceRefreshTarget { calendar }

_ScheduleSurfaceRefreshTarget? _scheduleSurfaceRefreshTargetFromWire(
  Object? value,
) {
  return switch ('$value'.trim()) {
    'calendar' => _ScheduleSurfaceRefreshTarget.calendar,
    _ => null,
  };
}

class _PermissionGuideRow extends StatelessWidget {
  const _PermissionGuideRow({
    required this.icon,
    required this.title,
    required this.enabled,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final bool enabled;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LingGlassSurface(
      tone: LingGlassSurfaceTone.muted,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: palette.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          LingGlassButton(
            expand: false,
            width: 112,
            minHeight: 40,
            radius: 18,
            tone: enabled
                ? LingGlassSurfaceTone.muted
                : LingGlassSurfaceTone.accent,
            onPressed: onPressed,
            child: _PermissionGuideButtonLabel(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _PermissionGuideButtonLabel extends StatelessWidget {
  const _PermissionGuideButtonLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(decoration: TextDecoration.none),
        ),
      ),
    );
  }
}

class LingCalendarHomePage extends ConsumerStatefulWidget {
  const LingCalendarHomePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.nowProvider,
  });

  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode mode) onThemeModeChanged;
  final DateTime Function()? nowProvider;

  @override
  ConsumerState<LingCalendarHomePage> createState() =>
      _LingCalendarHomePageState();
}

class _LingCalendarHomePageState extends ConsumerState<LingCalendarHomePage>
    with WidgetsBindingObserver {
  static const Duration _screenTransitionDuration = Duration(milliseconds: 320);
  static const String _firstPromptPermissionGuidePreferencePrefix =
      'ling.first_prompt_permission_guide_shown.v2';
  static const String _loginNotificationPromptPreferencePrefix =
      'ling.login_notification_permission_prompt_shown.v1';
  static const Duration _conversationEventWatchdogInterval = Duration(
    seconds: 20,
  );
  static const Duration _conversationEventWatchdogTimeout = Duration(
    seconds: 70,
  );
  static const Offset _calendarPageHiddenOffsetLeft = Offset(-1.12, 0);
  static const Offset _calendarPageHiddenOffsetRight = Offset(1.12, 0);
  static const Offset _settingsPageHiddenOffsetLeft = Offset(-1.02, 0);
  static const Offset _settingsPageHiddenOffsetRight = Offset(1.02, 0);

  final GlobalKey<LingCalendarChatSectionState> _chatSectionKey =
      GlobalKey<LingCalendarChatSectionState>();
  final SingleFlight<void> _appResumeRefreshSingleFlight = SingleFlight<void>();
  final SingleFlight<void> _foregroundNotificationRefreshSingleFlight =
      SingleFlight<void>();
  final SingleFlight<void> _conversationEventRefreshSingleFlight =
      SingleFlight<void>();
  final SingleFlight<void> _scheduleSurfaceEventRefreshSingleFlight =
      SingleFlight<void>();
  final SingleFlight<void> _activeSessionRecoverySingleFlight =
      SingleFlight<void>();
  final LingDeepLinkBridge _deepLinkBridge =
      const MethodChannelLingDeepLinkBridge();

  ProviderSubscription<AuthState>? _authStateSubscription;
  StreamSubscription<ForegroundRemoteNotificationEvent>?
  _foregroundNotificationSubscription;
  StreamSubscription<Map<String, dynamic>>? _conversationEventSubscription;
  Completer<void>? _conversationEventAbortCompleter;

  bool _isCalendarOpen = false;
  bool _isSettingsOpen = false;
  bool _isAppInForeground = true;
  bool _didPrepareChatForCurrentBackgroundTransition = false;
  bool _isBootstrappingAuthenticatedSurface = false;
  bool _hasUnreadCalendarBadge = false;
  bool _skipNextScreenTransition = false;
  bool _shouldCloseCalendarViewToLeft = false;
  bool _shouldCloseSettingsPageToRight = false;
  LingSettingsPageId _settingsInitialPage = LingSettingsPageId.root;
  LingSettingsPageId _currentSettingsPage = LingSettingsPageId.root;
  String? _activeAuthUserId;
  String? _lastConversationEventId;
  String? _pendingConversationEventSessionId;
  final Set<_ScheduleSurfaceRefreshTarget> _pendingScheduleSurfaceRefreshes =
      <_ScheduleSurfaceRefreshTarget>{};
  Offset _calendarHiddenOffset = _calendarPageHiddenOffsetRight;
  Offset _settingsHiddenOffset = _settingsPageHiddenOffsetLeft;
  Timer? _foregroundNotificationRecoveryTimer;
  Timer? _conversationEventReconnectTimer;
  Timer? _conversationEventDebounceTimer;
  Timer? _conversationEventWatchdogTimer;
  Timer? _scheduleSurfaceEventDebounceTimer;
  int _conversationEventReconnectAttempt = 0;
  bool _isConversationEventStopRequested = false;
  DateTime? _lastConversationEventActivityAt;

  DateTime _now() => widget.nowProvider?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isAppInForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    final initialAuthState = ref.read(authControllerProvider);
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final calendarNotificationBridge = ref.read(
      calendarNotificationBridgeProvider,
    );
    _authStateSubscription = ref.listenManual<AuthState>(
      authControllerProvider,
      (previous, next) {
        unawaited(_handleAuthStateChanged(previous, next));
      },
    );
    _foregroundNotificationSubscription = calendarNotificationBridge
        .foregroundRemoteNotificationEvents()
        .listen(_handleForegroundRemoteNotification);
    _deepLinkBridge.setListener(_handleDeepLink);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_consumePendingDeepLink());
      unawaited(_handleAuthStateChanged(null, initialAuthState));
      unawaited(
        settingsController.refreshDeviceContext(
          onTimezoneChanged: _updateCalendarTimezone,
        ),
      );
      unawaited(settingsController.syncDevicePermissionStates());
      unawaited(_syncForegroundNotificationContext());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authStateSubscription?.close();
    _foregroundNotificationRecoveryTimer?.cancel();
    _conversationEventReconnectTimer?.cancel();
    _conversationEventDebounceTimer?.cancel();
    _conversationEventWatchdogTimer?.cancel();
    _scheduleSurfaceEventDebounceTimer?.cancel();
    _stopConversationEventSubscription();
    _deepLinkBridge.setListener(null);
    unawaited(_foregroundNotificationSubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _isAppInForeground;
    final isForeground = state == AppLifecycleState.resumed;
    if (isForeground) {
      _didPrepareChatForCurrentBackgroundTransition = false;
    }
    if (_isAppInForeground != isForeground) {
      if (mounted) {
        setState(() {
          _isAppInForeground = isForeground;
        });
      } else {
        _isAppInForeground = isForeground;
      }
    }
    unawaited(
      _trackAppEvent(
        'app.lifecycle.change',
        surface: 'app',
        action: 'lifecycle_change',
        properties: <String, Object?>{'state': state.name},
      ),
    );
    _syncConversationEventSubscription();
    if (_shouldPrepareChatForBackground(state)) {
      if (!_didPrepareChatForCurrentBackgroundTransition) {
        _didPrepareChatForCurrentBackgroundTransition = true;
        unawaited(
          _chatSectionKey.currentState?.prepareForBackgroundTransition() ??
              Future<void>.value(),
        );
      }
    } else if (!_isAppInForeground &&
        !_didPrepareChatForCurrentBackgroundTransition) {
      unawaited(
        _chatSectionKey.currentState?.flushConversationState() ??
            Future<void>.value(),
      );
    }
    unawaited(_syncForegroundNotificationContext());
    if (!wasForeground && _isAppInForeground) {
      unawaited(_handleAppResumed());
    }
  }

  bool _shouldPrepareChatForBackground(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        return true;
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        return false;
    }
  }

  AuthSession? get _currentAuthSession =>
      ref.read(authControllerProvider).session;
  HomeSurfaceController get _homeSurfaceController =>
      ref.read(homeSurfaceControllerProvider.notifier);

  String get _currentLocaleCode =>
      ref.read(settingsControllerProvider).localeCode;
  String get _currentTimezone => ref.read(settingsControllerProvider).timezone;
  UserProfile? get _currentProfile =>
      ref.read(settingsControllerProvider).profile;

  bool get _isAuthenticated {
    return _hasAuthenticatedSession(_currentAuthSession);
  }

  LingStrings get s => LingStrings(_currentLocaleCode);

  bool _hasAuthenticatedSession(AuthSession? session) {
    return (session?.accessToken.trim() ?? '').isNotEmpty;
  }

  Future<void> _consumePendingDeepLink() async {
    final link = await _deepLinkBridge.ready();
    if (link != null) {
      _handleDeepLink(link);
    }
  }

  void _handleDeepLink(LingDeepLink link) {
    link.kind;
  }

  Future<void> _promptCalendarPermissionSettings() async {
    if (!mounted) {
      return;
    }
    final confirmed = await showLingAdaptiveConfirmationDialog(
      context: context,
      title: s.appleCalendarPermissionPromptTitle,
      message: s.appleCalendarFirstLaunchSettingsMessage,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      confirmLabel: s.oneTapEnablePermissions,
    );
    if (confirmed == true) {
      await _homeSurfaceController.openAppleCalendarSystemSettings();
    }
  }

  Future<void> _maybePromptNotificationPermissionAfterLogin() async {
    if (!_isAuthenticated || !mounted) {
      return;
    }
    final key = _userScopedPreferenceKey(
      _loginNotificationPromptPreferencePrefix,
    );
    final preferences = ref.read(preferencesProvider);
    final alreadyShown = (await preferences.readString(key))?.trim() == '1';
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final permission = await settingsController
        .prepareCalendarNotificationPermission(syncBackend: false);
    await settingsController.syncDevicePermissionStates();
    if (permission == CalendarNotificationPermissionState.granted ||
        permission == CalendarNotificationPermissionState.unsupported ||
        alreadyShown ||
        !mounted) {
      return;
    }
    final confirmed = await showLingAdaptiveConfirmationDialog(
      context: context,
      title: s.isZh ? '开启通知' : 'Enable Notifications',
      message: s.isZh
          ? 'Ling 需要通知权限，才能及时提醒日程变化。'
          : 'Ling needs notification access to deliver schedule reminders.',
      cancelLabel: s.cancel,
      confirmLabel: permission == CalendarNotificationPermissionState.denied
          ? s.openSystemSettings
          : s.calendarNotificationEnablePermission,
    );
    await preferences.writeString(key, '1');
    if (confirmed != true || !mounted) {
      await settingsController.syncDevicePermissionStates();
      return;
    }
    if (permission == CalendarNotificationPermissionState.denied) {
      await settingsController.openCalendarNotificationSystemSettings();
    } else {
      await settingsController.prepareCalendarNotificationPermission(
        requestIfNeeded: true,
        strings: s,
      );
    }
    await settingsController.syncDevicePermissionStates();
  }

  Future<bool> _handleBeforeChatPromptSubmit(BuildContext gateContext) async {
    if (!_isAuthenticated) {
      return true;
    }
    await _syncDevicePermissionStatesSafely();
    final key = _userScopedPreferenceKey(
      _firstPromptPermissionGuidePreferencePrefix,
    );
    final preferences = ref.read(preferencesProvider);
    final alreadyShown = (await preferences.readString(key))?.trim() == '1';
    if (alreadyShown) {
      return true;
    }
    if (!gateContext.mounted) {
      return true;
    }
    final shouldContinue = await _showFirstPromptPermissionGuide(gateContext);
    if (shouldContinue) {
      await preferences.writeString(key, '1');
    }
    await _syncDevicePermissionStatesSafely();
    return shouldContinue;
  }

  Future<void> _handleLingChatAction(
    BuildContext actionContext,
    LingChatAction action,
  ) async {
    switch (action.kind) {
      case LingChatActionKind.prompt:
        return;
      case LingChatActionKind.settings:
        _openSettingsForLingAction(action);
        return;
      case LingChatActionKind.permission:
        await _handlePermissionLingAction(actionContext, action.target);
        return;
    }
  }

  void _openSettingsForLingAction(LingChatAction action) {
    switch (action.target) {
      case LingChatActionTarget.notification:
        _toggleSettingsPage(true, page: LingSettingsPageId.permissions);
        return;
      case LingChatActionTarget.calendar:
        _toggleSettingsPage(true, page: LingSettingsPageId.calendar);
        return;
      case LingChatActionTarget.location:
      case null:
        return;
    }
  }

  Future<void> _handlePermissionLingAction(
    BuildContext actionContext,
    LingChatActionTarget? target,
  ) async {
    switch (target) {
      case LingChatActionTarget.notification:
        await _confirmAndRequestNotificationPermission(actionContext);
        return;
      case LingChatActionTarget.calendar:
        await _confirmAndRequestCalendarPermission(actionContext);
        return;
      case LingChatActionTarget.location:
        await _confirmAndRequestLocationPermission(actionContext);
        return;
      case null:
        return;
    }
  }

  Future<void> _syncDevicePermissionStatesSafely({
    DeviceContextSnapshot? deviceContext,
  }) async {
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .syncDevicePermissionStates(deviceContext: deviceContext);
    } catch (error, stackTrace) {
      AppLogger.debug(
        '[Ling][Permissions] 权限状态同步失败',
        fields: <String, Object?>{'error': '$error'},
      );
      AppLogger.debug('$stackTrace');
    }
  }

  String _userScopedPreferenceKey(String prefix) {
    final userId = _currentProfile?.userId.trim() ?? '';
    return userId.isEmpty ? prefix : '$prefix.$userId';
  }

  Future<bool> _showFirstPromptPermissionGuide(BuildContext gateContext) async {
    final settingsController = ref.read(settingsControllerProvider.notifier);
    var notificationPermission = await settingsController
        .prepareCalendarNotificationPermission(syncBackend: false);
    var locationPermission = await ref
        .read(deviceContextBridgeProvider)
        .getLocationPermissionState();
    var applePermission = await _homeSurfaceController
        .getAppleCalendarPermissionState();
    if (_isNotificationAuthorized(notificationPermission) &&
        _isLocationAuthorized(locationPermission) &&
        _isAppleCalendarAuthorized(applePermission)) {
      return true;
    }
    if (!gateContext.mounted) {
      return true;
    }
    final result = await showModalBottomSheet<bool>(
      context: gateContext,
      backgroundColor: Colors.transparent,
      barrierColor: gateContext.palette.scrim.withValues(alpha: 0.18),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> refreshStates({
              DeviceContextSnapshot? snapshot,
            }) async {
              await _syncDevicePermissionStatesSafely(deviceContext: snapshot);
              notificationPermission = await settingsController
                  .prepareCalendarNotificationPermission(syncBackend: false);
              locationPermission = await ref
                  .read(deviceContextBridgeProvider)
                  .getLocationPermissionState();
              applePermission = await _homeSurfaceController
                  .getAppleCalendarPermissionState();
              if (context.mounted) {
                setSheetState(() {});
              }
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: LingGlassSurface(
                  radius: 32,
                  tone: LingGlassSurfaceTone.elevated,
                  quality: LingGlassQuality.premium,
                  tintColor: lingGlassPanelTintFor(context, context.palette),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.isZh
                                  ? '让 Ling 更懂当前任务'
                                  : 'Let Ling Read the Context',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          LingGlassIconButton(
                            icon: Icons.close,
                            semanticLabel: s.cancel,
                            onPressed: () => Navigator.of(context).pop(false),
                            tone: LingGlassSurfaceTone.control,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _PermissionGuideRow(
                        icon: Icons.notifications_active_outlined,
                        title: s.isZh ? '通知' : 'Notifications',
                        enabled: _isNotificationAuthorized(
                          notificationPermission,
                        ),
                        actionLabel: _permissionActionLabel(
                          enabled: _isNotificationAuthorized(
                            notificationPermission,
                          ),
                          denied:
                              notificationPermission ==
                              CalendarNotificationPermissionState.denied,
                        ),
                        onPressed:
                            _isNotificationAuthorized(notificationPermission)
                            ? null
                            : () {
                                unawaited(() async {
                                  if (notificationPermission ==
                                      CalendarNotificationPermissionState
                                          .denied) {
                                    await settingsController
                                        .openCalendarNotificationSystemSettings();
                                  } else {
                                    await settingsController
                                        .prepareCalendarNotificationPermission(
                                          requestIfNeeded: true,
                                          strings: s,
                                        );
                                  }
                                  await refreshStates();
                                }());
                              },
                      ),
                      const SizedBox(height: 10),
                      _PermissionGuideRow(
                        icon: Icons.location_on_outlined,
                        title: s.isZh ? '定位' : 'Location',
                        enabled: _isLocationAuthorized(locationPermission),
                        actionLabel: _permissionActionLabel(
                          enabled: _isLocationAuthorized(locationPermission),
                          denied:
                              locationPermission ==
                                  DeviceLocationPermissionState.denied ||
                              locationPermission ==
                                  DeviceLocationPermissionState.restricted,
                        ),
                        onPressed: _isLocationAuthorized(locationPermission)
                            ? null
                            : () {
                                unawaited(() async {
                                  if (locationPermission ==
                                          DeviceLocationPermissionState
                                              .denied ||
                                      locationPermission ==
                                          DeviceLocationPermissionState
                                              .restricted) {
                                    await ref
                                        .read(deviceContextBridgeProvider)
                                        .openSystemSettings();
                                  } else {
                                    final snapshot = await ref
                                        .read(deviceContextBridgeProvider)
                                        .requestForegroundLocationContext();
                                    final timezone =
                                        snapshot?.timezone.trim() ?? '';
                                    if (timezone.isNotEmpty) {
                                      _updateCalendarTimezone(timezone);
                                    }
                                    await refreshStates(snapshot: snapshot);
                                  }
                                }());
                              },
                      ),
                      const SizedBox(height: 10),
                      _PermissionGuideRow(
                        icon: Icons.calendar_month_outlined,
                        title: 'Apple Calendar',
                        enabled: _isAppleCalendarAuthorized(applePermission),
                        actionLabel: _permissionActionLabel(
                          enabled: _isAppleCalendarAuthorized(applePermission),
                          denied:
                              applePermission ==
                              AppleCalendarPermissionState.denied,
                        ),
                        onPressed: _isAppleCalendarAuthorized(applePermission)
                            ? null
                            : () {
                                unawaited(() async {
                                  if (applePermission ==
                                      AppleCalendarPermissionState.denied) {
                                    await _homeSurfaceController
                                        .openAppleCalendarSystemSettings();
                                  } else {
                                    final nextPermission =
                                        await _homeSurfaceController
                                            .requestAppleCalendarPermission();
                                    if (nextPermission ==
                                        AppleCalendarPermissionState.denied) {
                                      await _promptCalendarPermissionSettings();
                                    }
                                  }
                                  await _refreshAppleCalendarSurfaces();
                                  await refreshStates();
                                }());
                              },
                      ),
                      const SizedBox(height: 18),
                      LingGlassButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: _PermissionGuideButtonLabel(
                          s.isZh ? '继续发送' : 'Continue Sending',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    return result ?? false;
  }

  bool _isNotificationAuthorized(CalendarNotificationPermissionState state) {
    return state == CalendarNotificationPermissionState.granted ||
        state == CalendarNotificationPermissionState.unsupported;
  }

  bool _isLocationAuthorized(DeviceLocationPermissionState state) {
    return state == DeviceLocationPermissionState.authorizedAlways ||
        state == DeviceLocationPermissionState.authorizedWhenInUse ||
        state == DeviceLocationPermissionState.unsupported;
  }

  bool _isAppleCalendarAuthorized(AppleCalendarPermissionState state) {
    return state == AppleCalendarPermissionState.granted ||
        state == AppleCalendarPermissionState.unsupported;
  }

  String _permissionActionLabel({required bool enabled, required bool denied}) {
    if (enabled) {
      return s.isZh ? '已开启' : 'Enabled';
    }
    if (denied) {
      return s.openSystemSettings;
    }
    return s.isZh ? '开启' : 'Enable';
  }

  void _showError(Object error) {
    if (shouldSuppressAppShellErrorNotice(error)) {
      return;
    }
    final message = error is ApiException ? error.message : error.toString();
    _showMessage(message);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    showLingTopNotice(context, message);
  }

  Future<void> _trackAppEvent(
    String eventName, {
    required String surface,
    required String action,
    String? source,
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    return ref
        .read(analyticsTrackerProvider)
        .track(
          eventName,
          surface: surface,
          action: action,
          source: source,
          locale: _currentLocaleCode,
          timezone: _currentTimezone,
          properties: properties,
        );
  }

  void _updateCalendarTimezone(String timezone) {
    ref.read(calendarControllerProvider.notifier).updateTimezone(timezone);
  }

  Future<void> _syncCalendarNotificationSchedule({
    bool rethrowOnFailure = false,
  }) {
    final settingsState = ref.read(settingsControllerProvider);
    return ref
        .read(appSessionLifecycleCoordinatorProvider)
        .syncCalendarNotificationSchedule(
          isAuthenticated: _isAuthenticated,
          timezone: settingsState.timezone,
          permission: settingsState.calendarNotificationPermission,
          settings: settingsState.calendarNotificationSettings,
          strings: s,
          rethrowOnFailure: rethrowOnFailure,
        );
  }

  Future<bool> _ensureMembershipReadyForChat() {
    return ref
        .read(appSessionLifecycleCoordinatorProvider)
        .ensureMembershipReadyForChat(
          isAuthenticated: _isAuthenticated,
          onError: _showError,
        );
  }

  Future<bool> _handleLocalChatGate(BuildContext gateContext) async {
    final gate = ref
        .read(membershipControllerProvider.notifier)
        .localChatGateResult();
    return _handleMembershipGate(gateContext, gate);
  }

  Future<bool> _handleChatPromptExecutionError(
    BuildContext gateContext,
    Object error,
  ) {
    return _handleMembershipGate(
      gateContext,
      membershipGateResultFromError(error),
    );
  }

  Future<bool> _handleMembershipGate(
    BuildContext gateContext,
    MembershipGateResult gate,
  ) async {
    if (!gate.shouldBlock) {
      return false;
    }
    unawaited(
      _trackAppEvent(
        'membership.gate.show',
        surface: 'membership',
        action: 'gate_show',
        properties: <String, Object?>{
          'reason': gate.reason.name,
          'daily_limit': gate.summary?.dailyChatLimit,
        },
      ),
    );
    ref
        .read(appSessionLifecycleCoordinatorProvider)
        .applyQuotaSummary(gate.summary);
    if (!gateContext.mounted) {
      return true;
    }
    await showLingMembershipGateSheet(
      context: gateContext,
      strings: s,
      gate: gate,
    );
    return true;
  }

  void _handleChatPromptSubmitted() {
    if (!_isAuthenticated) {
      return;
    }
    unawaited(() async {
      final locationPermission = await ref
          .read(deviceContextBridgeProvider)
          .getLocationPermissionState();
      final notificationPermission = ref
          .read(settingsControllerProvider)
          .calendarNotificationPermission;
      await ref
          .read(settingsControllerProvider.notifier)
          .syncDeviceContextToBackend(
            startTracking: false,
            locationRefreshIfOlderThan:
                _isLocationAuthorized(locationPermission)
                ? const Duration(minutes: 5)
                : null,
            notificationsEnabled:
                notificationPermission ==
                CalendarNotificationPermissionState.granted,
          );
    }());
  }

  Future<void> _openLingEventDetails(String eventId) async {
    final normalizedEventId = eventId.trim();
    if (normalizedEventId.isEmpty) {
      return;
    }
    try {
      final event = await ref
          .read(calendarRepositoryProvider)
          .getEventById(normalizedEventId);
      if (!mounted) {
        return;
      }
      await showLingEventDetailsSheet(
        context: context,
        strings: s,
        event: event,
        heroTag: 'ling_calendar_event_$normalizedEventId',
        useHeroTransition: true,
        editActionLabel: s.editAction,
        deleteActionLabel: event.isDeletable ? s.deleteAction : null,
        onSubmitLingEventEdit: _saveChatLingEventEdit,
        onDeleteLingEvent: event.isDeletable
            ? (event) => unawaited(_confirmDeleteChatLingEvent(event))
            : null,
        onReferenceLingEvent: _handleObjectReferenceSelected,
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<bool> _saveChatLingEventEdit(
    LingEvent event,
    LingCalendarEventEditorResult result,
  ) async {
    final draft = result.draft;
    if (draft == null || event.eventId.trim().isEmpty) {
      return false;
    }
    final mutationScope =
        scheduleEventMutationScopeFromApiValue(result.mutationScope) ??
        ScheduleEventMutationScope.series;
    try {
      await ref
          .read(scheduleEventActionsProvider)
          .updateEvent(
            event: event,
            draft: draft,
            mutationScope: mutationScope,
            timezone: _currentTimezone,
            strings: s,
            calendarNotificationSettings: ref
                .read(settingsControllerProvider)
                .calendarNotificationSettings,
            refreshAppleCalendar: _refreshAppleCalendarForDetails,
          );
      await _syncCalendarNotificationSchedule();
      _showMessage(s.updatedEvent(draft.title));
      return true;
    } catch (error) {
      _showError(error);
      return false;
    }
  }

  Future<void> _confirmDeleteChatLingEvent(LingEvent event) async {
    final title = event.title.trim().isEmpty ? s.untitled : event.title.trim();
    final confirmed = await showLingAdaptiveConfirmationDialog(
      context: context,
      title: s.deleteEventAction,
      message: s.deleteEventConfirmMessage(title),
      cancelLabel: s.cancel,
      confirmLabel: s.deleteAction,
      isDestructive: true,
    );
    if (confirmed != true || event.eventId.trim().isEmpty) {
      return;
    }
    try {
      await ref
          .read(scheduleEventActionsProvider)
          .deleteLingEvent(
            event: event,
            mutationScope: ScheduleEventMutationScope.series,
            timezone: _currentTimezone,
            strings: s,
            refreshAppleCalendar: _refreshAppleCalendarForDetails,
          );
      await _syncCalendarNotificationSchedule();
      _showMessage(s.deletedEvent(title));
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _refreshAppleCalendarForDetails({
    bool forceRefresh = false,
  }) async {
    await _refreshAppleCalendarSurfaces();
  }

  void _dismissActiveInputs() {
    FocusManager.instance.primaryFocus?.unfocus();
    _chatSectionKey.currentState?.dismissKeyboardComposer();
  }

  void _toggleCalendarView(bool open) {
    final nextUnreadCalendarBadge = open ? false : _hasUnreadCalendarBadge;
    if (_isCalendarOpen == open &&
        (!open || !_isSettingsOpen) &&
        _hasUnreadCalendarBadge == nextUnreadCalendarBadge) {
      return;
    }
    _dismissActiveInputs();
    setState(() {
      _calendarHiddenOffset = open
          ? _calendarPageHiddenOffsetRight
          : (_shouldCloseCalendarViewToLeft
                ? _calendarPageHiddenOffsetLeft
                : _calendarPageHiddenOffsetRight);
      _shouldCloseCalendarViewToLeft = false;
      _isCalendarOpen = open;
      if (open) {
        _isSettingsOpen = false;
        _settingsHiddenOffset = _settingsPageHiddenOffsetLeft;
        _shouldCloseSettingsPageToRight = false;
      }
      _hasUnreadCalendarBadge = nextUnreadCalendarBadge;
    });
    unawaited(_syncForegroundNotificationContext());
    unawaited(
      _trackAppEvent(
        open ? 'calendar.surface.open' : 'calendar.surface.close',
        surface: 'calendar',
        action: open ? 'surface_open' : 'surface_close',
      ),
    );
    if (open) {
      unawaited(
        Future.wait<void>([
          _ensureSchedulePageDataLoaded(),
          _syncApplicationBadge(),
        ]),
      );
    }
  }

  void _toggleSettingsPage(
    bool open, {
    LingSettingsPageId page = LingSettingsPageId.root,
  }) {
    if (_isSettingsOpen == open && (!open || !_isCalendarOpen)) {
      if (open && _settingsInitialPage != page) {
        setState(() {
          _settingsInitialPage = page;
          _currentSettingsPage = page;
        });
        unawaited(_ensureSettingsPageDataLoaded());
      }
      return;
    }
    _dismissActiveInputs();
    setState(() {
      if (open) {
        _settingsInitialPage = page;
        _currentSettingsPage = page;
      } else {
        _currentSettingsPage = LingSettingsPageId.root;
      }
      _settingsHiddenOffset = open
          ? _settingsPageHiddenOffsetLeft
          : (_shouldCloseSettingsPageToRight
                ? _settingsPageHiddenOffsetRight
                : _settingsPageHiddenOffsetLeft);
      _shouldCloseSettingsPageToRight = false;
      _isSettingsOpen = open;
      if (open) {
        _isCalendarOpen = false;
        _calendarHiddenOffset = _calendarPageHiddenOffsetRight;
        _shouldCloseCalendarViewToLeft = false;
      }
    });
    unawaited(_syncForegroundNotificationContext());
    unawaited(
      _trackAppEvent(
        open ? 'settings.surface.open' : 'settings.surface.close',
        surface: 'settings',
        action: open ? 'surface_open' : 'surface_close',
        properties: <String, Object?>{'page': page.name},
      ),
    );
    if (open) {
      unawaited(_ensureSettingsPageDataLoaded());
    }
  }

  void _handleCalendarBackSwipeDirectionCompleted(
    LingEdgeSwipeDirection direction,
  ) {
    _shouldCloseCalendarViewToLeft =
        direction == LingEdgeSwipeDirection.rightToLeft;
    _prepareToSkipNextScreenTransition();
  }

  void _handleSettingsRootBackSwipeDirectionCompleted(
    LingEdgeSwipeDirection direction,
  ) {
    _shouldCloseSettingsPageToRight =
        direction == LingEdgeSwipeDirection.leftToRight;
    _prepareToSkipNextScreenTransition();
  }

  void _prepareToSkipNextScreenTransition() {
    if (_skipNextScreenTransition) {
      return;
    }
    if (!mounted) {
      _skipNextScreenTransition = true;
    } else {
      setState(() {
        _skipNextScreenTransition = true;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_skipNextScreenTransition) {
        return;
      }
      setState(() {
        _skipNextScreenTransition = false;
      });
    });
  }

  Future<void> _syncForegroundNotificationContext() async {
    await _homeSurfaceController.syncForegroundNotificationContext(
      isAppInForeground: _isAppInForeground,
      isCalendarOpen: _isCalendarOpen,
      isSettingsOpen: _isSettingsOpen,
    );
  }

  void _handleObjectReferenceSelected(LingObjectReference reference) {
    _toggleCalendarView(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _chatSectionKey.currentState?.prefillKeyboardComposerWithObjectReference(
        reference,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final homeSurfaceState = ref.watch(homeSurfaceControllerProvider);
    final authSession = authState.session;
    final hasAuthenticatedSession = _hasAuthenticatedSession(authSession);
    final isAuthenticated = hasAuthenticatedSession;
    final isRestoringAuthSession = authState is AuthStateRestoring;
    final palette = context.palette;
    final (:localeCode, :timezone) = ref.watch(
      settingsControllerProvider.select(
        (state) => (localeCode: state.localeCode, timezone: state.timezone),
      ),
    );
    final shellStrings = LingStrings(localeCode);
    final body = isRestoringAuthSession && !hasAuthenticatedSession
        ? const SizedBox.shrink()
        : isAuthenticated
        ? Stack(
            fit: StackFit.expand,
            children: [
              LingCalendarAuthenticatedShell(
                isCalendarOpen: _isCalendarOpen,
                isSettingsOpen: _isSettingsOpen,
                calendarHiddenOffset: _calendarHiddenOffset,
                settingsHiddenOffset: _settingsHiddenOffset,
                screenTransitionDuration: _skipNextScreenTransition
                    ? Duration.zero
                    : _screenTransitionDuration,
                chatView: Consumer(
                  builder: (context, ref, _) {
                    final selectedDate = ref.watch(
                      calendarControllerProvider.select(
                        (state) => state.selectedDate,
                      ),
                    );
                    final (
                      :localeCode,
                      :timezone,
                      :fontSizeLevel,
                      :profile,
                    ) = ref.watch(
                      settingsControllerProvider.select(
                        (state) => (
                          localeCode: state.localeCode,
                          timezone: state.timezone,
                          fontSizeLevel: state.fontSizeLevel,
                          profile: state.profile,
                        ),
                      ),
                    );
                    return LingCalendarChatSection(
                      key: _chatSectionKey,
                      stateView: LingCalendarChatSectionViewModel(
                        isCalendarOpen: _isCalendarOpen,
                        isAuthenticated: _isAuthenticated,
                        isAppInForeground: _isAppInForeground,
                        selectedDate: selectedDate,
                        timezone: timezone,
                        localeCode: localeCode,
                        fontSizeLevel: fontSizeLevel,
                        profile: profile,
                        currentAuthSession: _currentAuthSession,
                        applePermission: homeSurfaceState.applePermission,
                        appleEvents: homeSurfaceState.appleEvents,
                        isBootstrappingConversation:
                            _isBootstrappingAuthenticatedSurface,
                        hasUnreadCalendarBadge: _hasUnreadCalendarBadge,
                        strings: LingStrings(localeCode),
                      ),
                      actions: LingCalendarChatSectionCallbacks(
                        onAvatarTap: () => _toggleSettingsPage(true),
                        onCalendarTap: () => _toggleCalendarView(true),
                        onCalendarMutationToolResult:
                            _handleCalendarMutationToolResult,
                        onOpenLingEvent: _openLingEventDetails,
                        onEnsureMembershipReadyForChat:
                            _ensureMembershipReadyForChat,
                        onHandleLocalChatGate: _handleLocalChatGate,
                        onHandlePromptExecutionError:
                            _handleChatPromptExecutionError,
                        onBeforePromptSubmit: _handleBeforeChatPromptSubmit,
                        onLingAction: _handleLingChatAction,
                        onPromptSubmitted: _handleChatPromptSubmitted,
                      ),
                    );
                  },
                ),
                scheduleSection: Consumer(
                  builder: (context, ref, _) {
                    final (
                      :selectedDate,
                      :isLoadingCalendar,
                      :lingEvents,
                      :monthData,
                    ) = ref.watch(
                      calendarControllerProvider.select(
                        (state) => (
                          selectedDate: state.selectedDate,
                          isLoadingCalendar: state.isLoading,
                          lingEvents: state.events,
                          monthData: state.monthSnapshot,
                        ),
                      ),
                    );
                    final (
                      :localeCode,
                      :timezone,
                      :calendarNotificationSettings,
                    ) = ref.watch(
                      settingsControllerProvider.select(
                        (state) => (
                          localeCode: state.localeCode,
                          timezone: state.timezone,
                          calendarNotificationSettings:
                              state.calendarNotificationSettings,
                        ),
                      ),
                    );
                    return LingCalendarScheduleSection(
                      key: const ValueKey('schedule'),
                      isOpen: _isCalendarOpen,
                      selectedDate: selectedDate,
                      isLoadingCalendar: isLoadingCalendar,
                      lingEvents: lingEvents,
                      monthData: monthData,
                      timezone: timezone,
                      appleEvents: homeSurfaceState.appleEvents,
                      calendarNotificationSettings:
                          calendarNotificationSettings,
                      strings: LingStrings(localeCode),
                      onClose: () => _toggleCalendarView(false),
                      onRefreshAppleCalendarData: _ensureSchedulePageDataLoaded,
                      onSyncCalendarNotificationSchedule:
                          _syncCalendarNotificationSchedule,
                      onBackSwipeCompleted: _prepareToSkipNextScreenTransition,
                      onBackSwipeDirectionCompleted:
                          _handleCalendarBackSwipeDirectionCompleted,
                      onObjectReferenceSelected: _handleObjectReferenceSelected,
                    );
                  },
                ),
                settingsPage: Consumer(
                  builder: (context, ref, _) {
                    final (
                      :localeCode,
                      :timezone,
                      :profile,
                      :calendarNotificationPermission,
                      :locationPermission,
                      :microphonePermission,
                      :photoLibraryPermission,
                      :calendarNotificationSettings,
                      :calendarSyncSettings,
                      :fontSizeLevel,
                      :phoneBinding,
                      :emailBinding,
                      :localImageCacheBytes,
                      :isClearingLocalImageCache,
                    ) = ref.watch(
                      settingsControllerProvider.select(
                        (state) => (
                          localeCode: state.localeCode,
                          timezone: state.timezone,
                          fontSizeLevel: state.fontSizeLevel,
                          profile: state.profile,
                          calendarNotificationPermission:
                              state.calendarNotificationPermission,
                          locationPermission: state.locationPermission,
                          microphonePermission: state.microphonePermission,
                          photoLibraryPermission: state.photoLibraryPermission,
                          calendarNotificationSettings:
                              state.calendarNotificationSettings,
                          calendarSyncSettings: state.calendarSyncSettings,
                          phoneBinding: state.phoneBinding,
                          emailBinding: state.emailBinding,
                          localImageCacheBytes: state.localImageCacheBytes,
                          isClearingLocalImageCache:
                              state.isClearingLocalImageCache,
                        ),
                      ),
                    );
                    final strings = LingStrings(localeCode);
                    final membershipSummary = ref.watch(
                      membershipControllerProvider.select(
                        (state) => state.summary,
                      ),
                    );
                    final preferences = profile?.preferences;
                    return LingSettingsPage(
                      isOpen: _isSettingsOpen,
                      initialPage: _settingsInitialPage,
                      data: LingSettingsPageViewModel(
                        appearance: LingSettingsAppearanceData(
                          themeMode: widget.themeMode,
                          localeCode: localeCode,
                          timezone: timezone,
                          fontSizeLevel: fontSizeLevel,
                          preferredInputMode:
                              preferences?.preferredInputMode ?? 'text',
                          localImageCacheBytes: localImageCacheBytes,
                          isClearingLocalImageCache: isClearingLocalImageCache,
                        ),
                        membership: LingSettingsMembershipData(
                          summary: membershipSummary,
                        ),
                        account: LingSettingsAccountData(
                          profile: profile,
                          identities:
                              _currentAuthSession?.identities ?? const [],
                          phoneBindingState: phoneBinding,
                          emailBindingState: emailBinding,
                          initialPhoneCountry: phoneCountries.first,
                        ),
                        calendar: LingSettingsCalendarData(
                          appleCalendarPermission:
                              homeSurfaceState.applePermission,
                          connections: homeSurfaceState.calendarConnections,
                          syncSettings: calendarSyncSettings,
                          notificationPermission:
                              calendarNotificationPermission,
                          notificationSettings: calendarNotificationSettings,
                        ),
                        locationPermission: locationPermission,
                        microphonePermission: microphonePermission,
                        photoLibraryPermission: photoLibraryPermission,
                        about: const LingSettingsAboutData(),
                        strings: strings,
                      ),
                      actions: LingSettingsPageCallbacks(
                        shell: LingSettingsShellCallbacks(
                          onClose: () => _toggleSettingsPage(false),
                          onPageChanged: (page) {
                            _handleSettingsPageChanged(page);
                            unawaited(
                              _trackAppEvent(
                                'settings.page.open',
                                surface: 'settings',
                                action: 'page_open',
                                source: page,
                              ),
                            );
                          },
                          onRootBackSwipeDirectionCompleted:
                              _handleSettingsRootBackSwipeDirectionCompleted,
                        ),
                        preferences: LingSettingsPreferenceCallbacks(
                          onThemeModeChanged: (mode) =>
                              unawaited(_changeThemeMode(mode)),
                          onLocaleChanged: (localeCode) =>
                              unawaited(_changeLocale(localeCode)),
                          onPreferredInputModeChanged: (mode) => unawaited(
                            ref
                                .read(settingsControllerProvider.notifier)
                                .syncPreferredInputMode(mode),
                          ),
                          onFontSizeLevelChanged: (level) => unawaited(
                            ref
                                .read(settingsControllerProvider.notifier)
                                .syncFontSizeLevelPreference(level),
                          ),
                          onClearLocalImageCache: _clearLocalImageCache,
                        ),
                        account: LingSettingsAccountCallbacks(
                          onSignOut: _confirmSignOut,
                          onDeleteAccount: _confirmDeleteAccount,
                          onSendPhoneBindingCode: (phone) async {
                            await ref
                                .read(settingsControllerProvider.notifier)
                                .requestPhoneBindingChallenge(phone);
                          },
                          onSendEmailBindingCode: (email) async {
                            await ref
                                .read(settingsControllerProvider.notifier)
                                .requestEmailBindingChallenge(email);
                          },
                          onBindPhone:
                              ({
                                required phone,
                                required challengeId,
                                required code,
                              }) => ref
                                  .read(settingsControllerProvider.notifier)
                                  .bindPhone(
                                    phone: phone,
                                    challengeId: challengeId,
                                    code: code,
                                  ),
                          onBindEmail: ({required email, required code}) => ref
                              .read(settingsControllerProvider.notifier)
                              .bindEmail(email: email, code: code),
                          onBindApple: () => _bindAppleIdentity(ref),
                          onBindWeChat: () => _bindWeChatIdentity(ref),
                          onBindingCompleted: _handleBindingCompleted,
                        ),
                        calendar: LingSettingsCalendarCallbacks(
                          onOpenCalendarProviderApp: _openCalendarProviderApp,
                          onAuthorizeCalendarProvider:
                              _authorizeCalendarProvider,
                          onRefreshCalendarProvider: _refreshCalendarProvider,
                          onDisconnectCalendarProvider:
                              _disconnectCalendarProvider,
                          onOpenAppleCalendarSystemSettings:
                              _openAppleCalendarSystemSettings,
                          onOpenCalendarNotificationSystemSettings:
                              _openCalendarNotificationSystemSettings,
                          onCalendarSyncSettingsChanged: (settings) =>
                              unawaited(_persistCalendarSyncSettings(settings)),
                          onCalendarNotificationSettingsChanged: (settings) =>
                              unawaited(
                                _persistCalendarNotificationSettings(settings),
                              ),
                          formatCalendarNotificationPermissionLabel:
                              (permission) =>
                                  formatCalendarNotificationPermissionLabel(
                                    strings,
                                    permission,
                                  ),
                          formatCalendarNotificationModeLabel: (mode) =>
                              formatCalendarNotificationModeLabel(
                                strings,
                                mode,
                              ),
                          formatCalendarNotificationSummary: (settings) =>
                              formatCalendarNotificationSummary(
                                strings,
                                settings,
                              ),
                        ),
                        permissions: LingSettingsPermissionCallbacks(
                          onRequestNotificationPermission:
                              _requestNotificationPermissionFromSettings,
                          onRequestLocationPermission:
                              _requestLocationPermissionFromSettings,
                          onRequestMicrophonePermission:
                              _requestMicrophonePermissionFromSettings,
                          onRequestPhotoLibraryPermission:
                              _requestPhotoLibraryPermissionFromSettings,
                          onOpenNotificationSystemSettings:
                              _openCalendarNotificationSystemSettings,
                          onOpenLocationSystemSettings:
                              _openLocationSystemSettings,
                        ),
                        membership: LingSettingsMembershipCallbacks(
                          onOpenMembershipPlans: (membershipContext) {
                            unawaited(
                              showLingMembershipSubscriptionPage(
                                context: membershipContext,
                                strings: strings,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          )
        : LingCalendarLoginFlow(strings: shellStrings);
    return Scaffold(
      backgroundColor: palette.background,
      resizeToAvoidBottomInset: false,
      body: isAuthenticated
          ? DecoratedBox(
              decoration: context.isDarkMode
                  ? BoxDecoration(color: palette.background)
                  : BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          palette.backgroundElevated,
                          palette.background,
                        ],
                      ),
                    ),
              child: SafeArea(top: true, bottom: false, child: body),
            )
          : body,
    );
  }

  Future<void> _handleAppResumed() async {
    if (!_isAuthenticated) {
      return;
    }
    await _appResumeRefreshSingleFlight.run(() async {
      final settingsController = ref.read(settingsControllerProvider.notifier);
      final timezoneSyncResult = await _syncDeviceTimezoneAndRefresh();
      final locationPermission = await ref
          .read(deviceContextBridgeProvider)
          .getLocationPermissionState();
      final refreshTasks = <Future<void>>[
        settingsController.prepareCalendarNotificationPermission(
          strings: s,
          syncBackend: false,
        ),
        settingsController.syncDevicePermissionStates(),
        settingsController.bootstrapAuthenticatedDeviceState(
          startTracking: false,
        ),
        settingsController.syncDeviceContextToBackend(
          locationRefreshIfOlderThan: _isLocationAuthorized(locationPermission)
              ? const Duration(minutes: 15)
              : null,
          notificationsEnabled:
              ref
                  .read(settingsControllerProvider)
                  .calendarNotificationPermission ==
              CalendarNotificationPermissionState.granted,
        ),
        _refreshMembershipSummary(forceRefresh: true),
      ];
      if (_isCalendarOpen &&
          !timezoneSyncResult.didChange &&
          !timezoneSyncResult.pendingRetry) {
        refreshTasks.add(_ensureSchedulePageDataLoaded(forceRefresh: true));
      }
      if (_isSettingsOpen &&
          !timezoneSyncResult.didChange &&
          !timezoneSyncResult.pendingRetry) {
        refreshTasks.add(_ensureSettingsPageDataLoaded(forceRefresh: true));
      }
      await Future.wait(refreshTasks);
      await _recoverActiveSessionFromServer(
        allowFreshLocalConversationShortcut: false,
      );
      await _refreshApplicationBadgeForCurrentSurface();
    });
  }

  Future<void> _refreshApplicationBadgeForCurrentSurface() {
    if (_isCalendarOpen || _isSettingsOpen) {
      return _syncApplicationBadge();
    }
    return _markAllBadgeNotificationsRead();
  }

  Future<void> _syncApplicationBadge() {
    return ref
        .read(appSessionLifecycleCoordinatorProvider)
        .syncApplicationBadge(isAuthenticated: _isAuthenticated);
  }

  Future<void> _markAllBadgeNotificationsRead() {
    return ref
        .read(appSessionLifecycleCoordinatorProvider)
        .markAllBadgeNotificationsRead(isAuthenticated: _isAuthenticated);
  }

  Future<void> _handleAuthStateChanged(
    AuthState? previous,
    AuthState next,
  ) async {
    final session = next.session;
    if (session == null || session.accessToken.trim().isEmpty) {
      _activeAuthUserId = null;
      _lastConversationEventId = null;
      _pendingConversationEventSessionId = null;
      _stopConversationEventSubscription();
      if (previous?.session != null || _currentProfile != null) {
        _resetLocalSessionState();
      }
      return;
    }

    final userId = session.profile.userId.trim();
    final previousUserId = previous?.session?.profile.userId.trim();
    final isSwitchingAuthenticatedUser =
        previousUserId != null &&
        previousUserId.isNotEmpty &&
        previousUserId != userId;
    if (isSwitchingAuthenticatedUser) {
      _resetLocalSessionState();
    }

    await _applySessionProfile(session.profile);
    unawaited(
      _trackAppEvent(
        'auth.session.authenticated',
        surface: 'auth',
        action: 'session_authenticated',
        properties: <String, Object?>{
          'is_new_user': session.isNewUser,
          'restore': previous == null,
        },
      ),
    );
    await _restoreLastConversationEventId(userId);
    final shouldBootstrap = _shouldBootstrapAuthenticatedSurface(
      isBootstrappingAuthenticatedSurface: _isBootstrappingAuthenticatedSurface,
      activeAuthUserId: _activeAuthUserId,
      nextUserId: userId,
      hadPreviousSession: previous?.session != null,
    );
    if (!shouldBootstrap) {
      _syncConversationEventSubscription();
      return;
    }

    _activeAuthUserId = userId;
    _setBootstrappingAuthenticatedSurface(true);
    try {
      await _loadAuthenticatedState(session.profile);
    } finally {
      _setBootstrappingAuthenticatedSurface(false);
    }
    unawaited(_maybePromptNotificationPermissionAfterLogin());
    _syncConversationEventSubscription();
  }

  Future<void> _restoreLastConversationEventId(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      _lastConversationEventId = null;
      return;
    }
    if (_activeAuthUserId == normalizedUserId &&
        (_lastConversationEventId?.trim().isNotEmpty ?? false)) {
      return;
    }
    try {
      _lastConversationEventId = await ref
          .read(chatRepositoryProvider)
          .readLastConversationEventId(normalizedUserId);
    } catch (error, stackTrace) {
      AppLogger.debug(
        '[Ling][AgentEvents] 恢复本地事件游标失败 userId=$normalizedUserId error=$error',
        category: 'agent_events',
      );
      AppLogger.debug('$stackTrace', category: 'agent_events');
    }
  }

  void _setBootstrappingAuthenticatedSurface(bool value) {
    if (_isBootstrappingAuthenticatedSurface == value) {
      return;
    }
    if (!mounted) {
      _isBootstrappingAuthenticatedSurface = value;
      return;
    }
    setState(() {
      _isBootstrappingAuthenticatedSurface = value;
    });
  }

  Future<void> _applySessionProfile(UserProfile profile) async {
    ref.read(settingsControllerProvider.notifier).applyProfile(profile);
    final preferredTheme = deserializeThemeModePreference(
      profile.preferences?.themeMode,
    );
    if (preferredTheme != null && preferredTheme != widget.themeMode) {
      await widget.onThemeModeChanged(preferredTheme);
    }
  }

  bool _shouldBootstrapAuthenticatedSurface({
    required bool isBootstrappingAuthenticatedSurface,
    required String? activeAuthUserId,
    required String nextUserId,
    required bool hadPreviousSession,
  }) {
    if (isBootstrappingAuthenticatedSurface) {
      return false;
    }
    return activeAuthUserId != nextUserId || !hadPreviousSession;
  }

  void _resetLocalSessionState() {
    final timezone = _currentTimezone;

    void mutate() {
      _isSettingsOpen = false;
      _isCalendarOpen = false;
      _hasUnreadCalendarBadge = false;
      _skipNextScreenTransition = false;
      _shouldCloseCalendarViewToLeft = false;
      _calendarHiddenOffset = _calendarPageHiddenOffsetRight;
      _shouldCloseSettingsPageToRight = false;
      _settingsHiddenOffset = _settingsPageHiddenOffsetLeft;
      _settingsInitialPage = LingSettingsPageId.root;
    }

    if (!mounted) {
      mutate();
    } else {
      setState(mutate);
    }
    _homeSurfaceController.clear();
    _stopConversationEventSubscription();
    _lastConversationEventId = null;
    _pendingConversationEventSessionId = null;
    _chatSectionKey.currentState?.resetSessionSurface();
    unawaited(
      ref
          .read(appSessionLifecycleCoordinatorProvider)
          .syncApplicationBadge(isAuthenticated: false),
    );
    final settingsController = ref.read(settingsControllerProvider.notifier);
    unawaited(
      ref
          .read(appSessionLifecycleCoordinatorProvider)
          .clearUserScopedLocalCaches(),
    );
    settingsController.clear();
    ref.read(calendarControllerProvider.notifier).reset(timezone: timezone);
    ref.read(membershipControllerProvider.notifier).clear();
  }

  Future<void> _loadAuthenticatedState(UserProfile fallbackProfile) async {
    await _waitForAuthenticatedSurface();
    final chatSectionState = _chatSectionKey.currentState;
    if (chatSectionState == null) {
      return;
    }
    await chatSectionState.restorePersistedConversationState();
    if (chatSectionState.hasConversationEntries) {
      unawaited(
        _recoverActiveSessionFromServer(
          allowFreshLocalConversationShortcut: true,
        ),
      );
    } else {
      await chatSectionState.recoverActiveSessionFromServer();
    }
    unawaited(_bootstrapAuthenticatedBackgroundState(fallbackProfile));
    unawaited(_refreshApplicationBadgeForCurrentSurface());
  }

  Future<void> _bootstrapAuthenticatedBackgroundState(
    UserProfile fallbackProfile,
  ) async {
    try {
      final settingsController = ref.read(settingsControllerProvider.notifier);
      final result = await settingsController.bootstrapAuthenticatedSession(
        sessionProfile: fallbackProfile,
        strings: s,
      );
      if (result.preferredTheme != null &&
          result.preferredTheme != widget.themeMode) {
        await widget.onThemeModeChanged(result.preferredTheme!);
      }
      final timezoneSyncResult = await _syncDeviceTimezoneAndRefresh();
      final locationPermission = await ref
          .read(deviceContextBridgeProvider)
          .getLocationPermissionState();
      await Future.wait<void>([
        settingsController.bootstrapAuthenticatedDeviceState(
          startTracking: _isLocationAuthorized(locationPermission),
        ),
        settingsController.syncDevicePermissionStates(),
        if (!timezoneSyncResult.didChange && !timezoneSyncResult.pendingRetry)
          _ensureSchedulePageDataLoaded(forceRefresh: true),
        _refreshMembershipSummary(forceRefresh: true, silent: true),
      ]);
    } catch (_) {
      // Best-effort: background bootstrap should not block chat recovery.
    }
  }

  Future<DeviceTimezoneSyncResult> _syncDeviceTimezoneAndRefresh({
    bool startTracking = false,
  }) async {
    if (!_isAuthenticated) {
      return const DeviceTimezoneSyncResult(
        didChange: false,
        pendingRetry: false,
      );
    }
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final deviceContext = await settingsController.refreshDeviceContext(
      startTracking: startTracking,
    );
    final result = await settingsController.syncDeviceTimezoneIfNeeded(
      deviceContext: deviceContext,
    );
    if (!result.didChange) {
      return result;
    }
    await ref
        .read(appSessionLifecycleCoordinatorProvider)
        .clearUserScopedLocalCaches();
    await Future.wait<void>([
      _ensureSchedulePageDataLoaded(forceRefresh: true),
      _syncCalendarNotificationSchedule(),
      if (_isSettingsOpen) _ensureSettingsPageDataLoaded(forceRefresh: true),
    ]);
    return result;
  }

  Future<void> _signOut() async {
    await ref
        .read(appSessionLifecycleCoordinatorProvider)
        .cleanupBeforeSessionEnd(isAuthenticated: _isAuthenticated);
    await ref
        .read(settingsControllerProvider.notifier)
        .signOutAuthenticatedSession();
    _resetLocalSessionState();
  }

  Future<void> _refreshMembershipSummary({
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    if (!_isAuthenticated) {
      ref.read(membershipControllerProvider.notifier).clear();
      return;
    }
    try {
      await ref
          .read(membershipControllerProvider.notifier)
          .bootstrapAuthenticatedSession(forceRefresh: forceRefresh);
    } catch (error) {
      if (!silent) {
        _showError(error);
      }
    }
  }

  Future<void> _recoverActiveSessionFromServer({
    bool allowFreshLocalConversationShortcut = true,
  }) async {
    await _activeSessionRecoverySingleFlight.run(() async {
      await _waitForAuthenticatedSurface();
      await _chatSectionKey.currentState?.recoverActiveSessionFromServer(
        allowFreshLocalConversationShortcut:
            allowFreshLocalConversationShortcut,
      );
    });
  }

  bool get _shouldRunConversationEventSubscription =>
      mounted && _isAuthenticated && _isAppInForeground;

  void _syncConversationEventSubscription() {
    if (!_shouldRunConversationEventSubscription) {
      _stopConversationEventSubscription();
      return;
    }
    _startConversationEventSubscription();
  }

  void _startConversationEventSubscription() {
    if (_conversationEventSubscription != null ||
        _conversationEventReconnectTimer != null) {
      return;
    }
    _isConversationEventStopRequested = false;
    final abortCompleter = Completer<void>();
    _conversationEventAbortCompleter = abortCompleter;
    _markConversationEventStreamActivity();
    _conversationEventSubscription = ref
        .read(chatRepositoryProvider)
        .streamConversationEvents(
          lastEventId: _lastConversationEventId,
          abortTrigger: abortCompleter.future,
        )
        .listen(
          _handleConversationEventStreamPayload,
          onError: (_) => _handleConversationEventStreamClosed(),
          onDone: _handleConversationEventStreamClosed,
          cancelOnError: true,
        );
  }

  void _stopConversationEventSubscription() {
    _isConversationEventStopRequested = true;
    _conversationEventReconnectTimer?.cancel();
    _conversationEventReconnectTimer = null;
    _conversationEventDebounceTimer?.cancel();
    _conversationEventDebounceTimer = null;
    _conversationEventWatchdogTimer?.cancel();
    _conversationEventWatchdogTimer = null;
    _lastConversationEventActivityAt = null;
    final abortCompleter = _conversationEventAbortCompleter;
    _conversationEventAbortCompleter = null;
    if (abortCompleter != null && !abortCompleter.isCompleted) {
      abortCompleter.complete();
    }
    final subscription = _conversationEventSubscription;
    _conversationEventSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  void _handleConversationEventStreamClosed() {
    _conversationEventWatchdogTimer?.cancel();
    _conversationEventWatchdogTimer = null;
    _lastConversationEventActivityAt = null;
    _conversationEventSubscription = null;
    _conversationEventAbortCompleter = null;
    if (_isConversationEventStopRequested ||
        !_shouldRunConversationEventSubscription) {
      return;
    }
    unawaited(
      _recoverActiveSessionFromServer(
        allowFreshLocalConversationShortcut: false,
      ),
    );
    final delayOptions = <Duration>[
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
      const Duration(seconds: 8),
      const Duration(seconds: 15),
    ];
    final delayIndex = _conversationEventReconnectAttempt >= delayOptions.length
        ? delayOptions.length - 1
        : _conversationEventReconnectAttempt;
    final delay = delayOptions[delayIndex];
    _conversationEventReconnectAttempt += 1;
    _conversationEventReconnectTimer?.cancel();
    _conversationEventReconnectTimer = Timer(delay, () {
      _conversationEventReconnectTimer = null;
      _startConversationEventSubscription();
    });
  }

  void _handleConversationEventStreamPayload(Map<String, dynamic> payload) {
    _markConversationEventStreamActivity();
    final wasReconnecting = _conversationEventReconnectAttempt > 0;
    _conversationEventReconnectAttempt = 0;
    final eventId = '${payload['id'] ?? ''}'.trim();
    if (eventId.isNotEmpty) {
      _lastConversationEventId = eventId;
      unawaited(_persistLastConversationEventId(eventId));
    }
    final eventName = '${payload['event'] ?? ''}'.trim();
    if (eventName == 'sse_comment') {
      if (wasReconnecting) {
        unawaited(
          _recoverActiveSessionFromServer(
            allowFreshLocalConversationShortcut: false,
          ),
        );
      }
      return;
    }
    if (eventName != 'agent_event' &&
        eventName != 'conversation_entry_changed') {
      return;
    }
    if (wasReconnecting) {
      unawaited(
        _recoverActiveSessionFromServer(
          allowFreshLocalConversationShortcut: false,
        ),
      );
    }
    final dataValue = payload['data'];
    final data = dataValue is Map<String, dynamic>
        ? dataValue
        : dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : const <String, dynamic>{};
    final eventType = '${data['type'] ?? ''}'.trim();
    if (eventType == 'calendar_changed') {
      _handleScheduleSurfaceChangedEvent(data);
      return;
    }
    final sessionId = '${data['session_id'] ?? ''}'.trim();
    if (sessionId.isNotEmpty) {
      _pendingConversationEventSessionId = sessionId;
    }
    final chatSectionState = _chatSectionKey.currentState;
    final hasDirectConversationEntry = data['item'] is Map;
    if (hasDirectConversationEntry &&
        sessionId.isNotEmpty &&
        chatSectionState != null &&
        chatSectionState.canApplyRealtimeConversationEvent(sessionId)) {
      chatSectionState.applyRealtimeConversationEvent(data);
      _pendingConversationEventSessionId = null;
      return;
    }
    if (eventType == 'run_started' ||
        eventType == 'run_completed' ||
        eventType == 'run_stopped') {
      if (sessionId.isNotEmpty &&
          chatSectionState != null &&
          chatSectionState.canApplyRealtimeConversationEvent(sessionId)) {
        chatSectionState.applyRealtimeConversationEvent(data);
        _pendingConversationEventSessionId = null;
      }
      return;
    }
    _scheduleConversationEventRefresh(const Duration(milliseconds: 150));
  }

  void _markConversationEventStreamActivity() {
    _lastConversationEventActivityAt = _now();
    _conversationEventWatchdogTimer?.cancel();
    if (!_shouldRunConversationEventSubscription) {
      _conversationEventWatchdogTimer = null;
      return;
    }
    _conversationEventWatchdogTimer = Timer(
      _conversationEventWatchdogInterval,
      _checkConversationEventStreamHealth,
    );
  }

  void _checkConversationEventStreamHealth() {
    _conversationEventWatchdogTimer = null;
    if (_isConversationEventStopRequested ||
        !_shouldRunConversationEventSubscription ||
        _conversationEventSubscription == null) {
      return;
    }
    final lastActivityAt = _lastConversationEventActivityAt;
    if (lastActivityAt == null) {
      _markConversationEventStreamActivity();
      return;
    }
    final idleDuration = _now().difference(lastActivityAt);
    if (idleDuration < _conversationEventWatchdogTimeout) {
      _conversationEventWatchdogTimer = Timer(
        _conversationEventWatchdogInterval,
        _checkConversationEventStreamHealth,
      );
      return;
    }
    AppLogger.warn(
      '[Ling][AgentEvents] 事件流心跳超时，准备重连 idleMs=${idleDuration.inMilliseconds}',
      category: 'agent_events',
    );
    final abortCompleter = _conversationEventAbortCompleter;
    if (abortCompleter != null && !abortCompleter.isCompleted) {
      abortCompleter.complete();
    }
    unawaited(
      _recoverActiveSessionFromServer(
        allowFreshLocalConversationShortcut: false,
      ),
    );
  }

  Future<void> _persistLastConversationEventId(String eventId) async {
    final userId = _currentAuthSession?.profile.userId.trim();
    if (userId == null || userId.isEmpty) {
      return;
    }
    try {
      await ref
          .read(chatRepositoryProvider)
          .saveLastConversationEventId(userId: userId, eventId: eventId);
    } catch (error, stackTrace) {
      AppLogger.debug(
        '[Ling][AgentEvents] 保存本地事件游标失败 userId=$userId eventId=$eventId error=$error',
        category: 'agent_events',
      );
      AppLogger.debug('$stackTrace', category: 'agent_events');
    }
  }

  void _handleScheduleSurfaceChangedEvent(Map<String, dynamic> data) {
    final eventUserId = '${data['user_id'] ?? ''}'.trim();
    final currentUserId = _currentAuthSession?.profile.userId.trim();
    if (eventUserId.isNotEmpty &&
        currentUserId != null &&
        eventUserId != currentUserId) {
      return;
    }
    final surface = _scheduleSurfaceRefreshTargetFromWire(data['surface']);
    if (surface == null) {
      return;
    }
    _pendingScheduleSurfaceRefreshes.add(surface);
    _scheduleSurfaceEventDebounceTimer?.cancel();
    _scheduleSurfaceEventDebounceTimer = Timer(
      const Duration(milliseconds: 150),
      () {
        _scheduleSurfaceEventDebounceTimer = null;
        unawaited(_flushScheduleSurfaceEventRefresh());
      },
    );
  }

  Future<void> _flushScheduleSurfaceEventRefresh() {
    return _scheduleSurfaceEventRefreshSingleFlight.run(() async {
      try {
        if (!mounted || !_isAuthenticated) {
          _pendingScheduleSurfaceRefreshes.clear();
          return;
        }
        final pending = Set<_ScheduleSurfaceRefreshTarget>.from(
          _pendingScheduleSurfaceRefreshes,
        );
        _pendingScheduleSurfaceRefreshes.clear();
        final surfaceController = ref.read(
          scheduleSurfaceControllerProvider.notifier,
        );
        final tasks = <Future<void>>[];
        if (pending.contains(_ScheduleSurfaceRefreshTarget.calendar)) {
          tasks.add(
            ref
                .read(calendarControllerProvider.notifier)
                .load(forceRefresh: true),
          );
          tasks.add(
            surfaceController.refreshWindowEvents(
              timezone: _currentTimezone,
              forceRefresh: true,
            ),
          );
        }
        if (tasks.isEmpty) {
          return;
        }
        await Future.wait<void>(tasks);
      } catch (error, stackTrace) {
        AppLogger.warn(
          '[Ling][AgentEvents] Schedule surface refresh failed',
          category: 'agent_events',
          fields: <String, Object?>{'error': '$error', 'stack': '$stackTrace'},
        );
      } finally {
        if (mounted && _pendingScheduleSurfaceRefreshes.isNotEmpty) {
          _scheduleSurfaceEventDebounceTimer?.cancel();
          _scheduleSurfaceEventDebounceTimer = Timer(Duration.zero, () {
            _scheduleSurfaceEventDebounceTimer = null;
            unawaited(_flushScheduleSurfaceEventRefresh());
          });
        }
      }
    });
  }

  void _scheduleConversationEventRefresh(Duration delay) {
    _conversationEventDebounceTimer?.cancel();
    _conversationEventDebounceTimer = Timer(delay, () {
      _conversationEventDebounceTimer = null;
      unawaited(_flushConversationEventRefresh());
    });
  }

  Future<void> _flushConversationEventRefresh() {
    return _conversationEventRefreshSingleFlight.run(() async {
      if (!_shouldRunConversationEventSubscription) {
        return;
      }
      final chatSectionState = _chatSectionKey.currentState;
      if (chatSectionState == null) {
        return;
      }
      if (chatSectionState.shouldDeferConversationRealtimeSync) {
        _scheduleConversationEventRefresh(const Duration(seconds: 1));
        return;
      }
      final sessionId = _pendingConversationEventSessionId;
      _pendingConversationEventSessionId = null;
      if (sessionId != null && sessionId.isNotEmpty) {
        await chatSectionState.recoverConversationSessionFromServer(sessionId);
        return;
      }
      await chatSectionState.recoverActiveSessionFromServer(
        allowFreshLocalConversationShortcut: false,
      );
    });
  }

  void _handleForegroundRemoteNotification(
    ForegroundRemoteNotificationEvent event,
  ) {
    if (!mounted || !_isAuthenticated || !_isAppInForeground) {
      return;
    }
    _foregroundNotificationRecoveryTimer?.cancel();
    _foregroundNotificationRecoveryTimer = Timer(
      const Duration(milliseconds: 180),
      () {
        _foregroundNotificationRecoveryTimer = null;
        unawaited(
          _foregroundNotificationRefreshSingleFlight.run(() async {
            if (!mounted || !_isAuthenticated) {
              return;
            }
            final notificationId = event.notificationId;
            if (notificationId != null && notificationId.isNotEmpty) {
              await ref
                  .read(appSessionLifecycleCoordinatorProvider)
                  .markNotificationOpened(
                    isAuthenticated: _isAuthenticated,
                    notificationId: notificationId,
                  );
            } else {
              await _syncApplicationBadge();
            }
            await _recoverActiveSessionFromServer(
              allowFreshLocalConversationShortcut: false,
            );
          }),
        );
      },
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showLingAdaptiveConfirmationDialog(
      context: context,
      title: s.signOut,
      message: s.signOutConfirmMessage,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      confirmLabel: s.signOut,
      isDestructive: true,
    );
    if (confirmed != true) {
      return;
    }

    try {
      await _signOut();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _changeThemeMode(ThemeMode mode) async {
    if (widget.themeMode == mode) {
      return;
    }

    await widget.onThemeModeChanged(mode);
    if (!mounted) {
      return;
    }
    await ref
        .read(settingsControllerProvider.notifier)
        .syncThemeModePreference(mode);
    unawaited(
      _trackAppEvent(
        'settings.preference.change',
        surface: 'settings',
        action: 'preference_change',
        source: 'theme_mode',
        properties: <String, Object?>{
          'value': serializeThemeModePreference(mode),
        },
      ),
    );
  }

  Future<void> _changeLocale(String localeCode) async {
    if (_currentLocaleCode == localeCode) {
      return;
    }
    await ref
        .read(settingsControllerProvider.notifier)
        .syncLocaleCodePreference(localeCode);
    unawaited(
      _trackAppEvent(
        'settings.preference.change',
        surface: 'settings',
        action: 'preference_change',
        source: 'locale',
        properties: <String, Object?>{'value': localeCode},
      ),
    );
  }

  void _handleSettingsPageChanged(String page) {
    _currentSettingsPage = LingSettingsPageId.values.byName(page);
    unawaited(_ensureSettingsPageDataLoaded());
  }

  Future<void> _ensureGeneralSettingsDataLoaded() async {
    await ref
        .read(settingsControllerProvider.notifier)
        .refreshLocalImageCacheUsage();
  }

  Future<void> _applyAccountBundle(AccountBundle bundle) async {
    final preferredTheme = await ref
        .read(settingsControllerProvider.notifier)
        .applyAccountBundle(bundle);
    if (preferredTheme != null && preferredTheme != widget.themeMode) {
      await widget.onThemeModeChanged(preferredTheme);
    }
  }

  Future<void> _handleBindingCompleted(
    AccountBindingTarget target,
    AccountBundle result,
  ) async {
    await _applyAccountBundle(result);
    if (!mounted) {
      return;
    }
    _showMessage(switch (target) {
      AccountBindingTarget.phone => s.phoneBoundSuccess,
      AccountBindingTarget.email => s.emailBoundSuccess,
      AccountBindingTarget.apple => s.appleIdentityBoundSuccess,
      AccountBindingTarget.wechat => s.wechatIdentityBoundSuccess,
    });
  }

  Future<AccountBundle> _bindAppleIdentity(WidgetRef ref) async {
    return ref
        .read(settingsIdentityBindingCoordinatorProvider)
        .bindAppleIdentity(strings: s);
  }

  Future<AccountBundle> _bindWeChatIdentity(WidgetRef ref) async {
    return ref
        .read(settingsIdentityBindingCoordinatorProvider)
        .bindWeChatIdentity(strings: s);
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showLingAdaptiveConfirmationDialog(
      context: context,
      title: s.deleteAccountTitle,
      message: s.deleteAccountConfirmMessage,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      confirmLabel: s.deleteAccountAction,
      isDestructive: true,
    );
    if (confirmed != true) {
      return;
    }

    try {
      await ref
          .read(appSessionLifecycleCoordinatorProvider)
          .cleanupBeforeSessionEnd(
            isAuthenticated: _isAuthenticated,
            removeRemotePushDevice: false,
          );
      await ref
          .read(settingsControllerProvider.notifier)
          .deleteAuthenticatedAccount();
      _resetLocalSessionState();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openCalendarNotificationSystemSettings() async {
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .openCalendarNotificationSystemSettings();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _requestNotificationPermissionFromSettings() async {
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .prepareCalendarNotificationPermission(
            requestIfNeeded: true,
            strings: s,
          );
      await _syncDevicePermissionStatesSafely();
      unawaited(
        _trackAppEvent(
          'settings.permission.request_success',
          surface: 'settings',
          action: 'permission_request_success',
          source: 'notification',
        ),
      );
    } catch (error) {
      unawaited(
        _trackAppEvent(
          'settings.permission.request_failure',
          surface: 'settings',
          action: 'permission_request_failure',
          source: 'notification',
          properties: <String, Object?>{
            'error_type': error.runtimeType.toString(),
          },
        ),
      );
      _showError(error);
    }
  }

  Future<DeviceContextSnapshot?>
  _requestLocationPermissionFromSettings() async {
    try {
      final permission = await ref
          .read(deviceContextBridgeProvider)
          .getLocationPermissionState();
      if (permission == DeviceLocationPermissionState.denied ||
          permission == DeviceLocationPermissionState.restricted) {
        await _openLocationSystemSettings();
        await _syncDevicePermissionStatesSafely();
        return null;
      }
      final snapshot = await ref
          .read(deviceContextBridgeProvider)
          .requestForegroundLocationContext();
      final timezone = snapshot?.timezone.trim() ?? '';
      if (timezone.isNotEmpty) {
        _updateCalendarTimezone(timezone);
      }
      await _syncDevicePermissionStatesSafely(deviceContext: snapshot);
      unawaited(
        _trackAppEvent(
          'settings.permission.request_success',
          surface: 'settings',
          action: 'permission_request_success',
          source: 'location',
        ),
      );
      return snapshot;
    } catch (error) {
      unawaited(
        _trackAppEvent(
          'settings.permission.request_failure',
          surface: 'settings',
          action: 'permission_request_failure',
          source: 'location',
          properties: <String, Object?>{
            'error_type': error.runtimeType.toString(),
          },
        ),
      );
      _showError(error);
      return null;
    }
  }

  Future<void> _requestMicrophonePermissionFromSettings() async {
    try {
      final bridge = ref.read(appleSpeechRecognitionBridgeProvider);
      final permission = await bridge.getAuthorizationState();
      if (permission == SpeechAuthorizationState.denied ||
          permission == SpeechAuthorizationState.restricted) {
        await bridge.openSystemSettings();
        await _syncDevicePermissionStatesSafely();
        return;
      }
      if (permission == SpeechAuthorizationState.granted ||
          permission == SpeechAuthorizationState.unsupported) {
        await _syncDevicePermissionStatesSafely();
        return;
      }
      await bridge.requestMicrophonePermission();
      await _syncDevicePermissionStatesSafely();
      unawaited(
        _trackAppEvent(
          'settings.permission.request_success',
          surface: 'settings',
          action: 'permission_request_success',
          source: 'microphone',
        ),
      );
    } catch (error) {
      unawaited(
        _trackAppEvent(
          'settings.permission.request_failure',
          surface: 'settings',
          action: 'permission_request_failure',
          source: 'microphone',
          properties: <String, Object?>{
            'error_type': error.runtimeType.toString(),
          },
        ),
      );
      _showError(error);
    }
  }

  Future<void> _requestPhotoLibraryPermissionFromSettings() async {
    try {
      final bridge = ref.read(photoLibraryPermissionBridgeProvider);
      final permission = await bridge.getPermissionState();
      if (permission == PhotoLibraryPermissionState.denied ||
          permission == PhotoLibraryPermissionState.restricted) {
        await bridge.openSystemSettings();
        await _syncDevicePermissionStatesSafely();
        return;
      }
      if (permission == PhotoLibraryPermissionState.granted ||
          permission == PhotoLibraryPermissionState.unsupported) {
        await _syncDevicePermissionStatesSafely();
        return;
      }
      await bridge.requestPermission();
      await _syncDevicePermissionStatesSafely();
      unawaited(
        _trackAppEvent(
          'settings.permission.request_success',
          surface: 'settings',
          action: 'permission_request_success',
          source: 'photo_library',
        ),
      );
    } catch (error) {
      unawaited(
        _trackAppEvent(
          'settings.permission.request_failure',
          surface: 'settings',
          action: 'permission_request_failure',
          source: 'photo_library',
          properties: <String, Object?>{
            'error_type': error.runtimeType.toString(),
          },
        ),
      );
      _showError(error);
    }
  }

  Future<void> _openLocationSystemSettings() async {
    try {
      await ref.read(deviceContextBridgeProvider).openSystemSettings();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _confirmAndRequestNotificationPermission(
    BuildContext actionContext,
  ) async {
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final permission = await settingsController
        .prepareCalendarNotificationPermission(syncBackend: false);
    if (!actionContext.mounted) {
      return;
    }
    final confirmed = await showLingAdaptiveConfirmationDialog(
      context: actionContext,
      title: s.calendarNotificationPermissionTitle,
      message: s.calendarNotificationPermissionDescription,
      cancelLabel: s.cancel,
      confirmLabel: permission == CalendarNotificationPermissionState.denied
          ? s.openSystemSettings
          : s.calendarNotificationEnablePermission,
    );
    if (confirmed != true) {
      return;
    }
    if (permission == CalendarNotificationPermissionState.denied) {
      await _openCalendarNotificationSystemSettings();
    } else {
      await _requestNotificationPermissionFromSettings();
    }
  }

  Future<void> _confirmAndRequestCalendarPermission(
    BuildContext actionContext,
  ) async {
    final permission = await _homeSurfaceController
        .getAppleCalendarPermissionState();
    if (!actionContext.mounted ||
        permission == AppleCalendarPermissionState.granted ||
        permission == AppleCalendarPermissionState.unsupported) {
      return;
    }
    final confirmed = await showLingAdaptiveConfirmationDialog(
      context: actionContext,
      title: s.appleCalendarPermissionPromptTitle,
      message: permission == AppleCalendarPermissionState.denied
          ? s.appleCalendarPermissionSettingsMessage
          : s.appleCalendarPermissionPromptMessage,
      cancelLabel: s.cancel,
      confirmLabel: permission == AppleCalendarPermissionState.denied
          ? s.openSystemSettings
          : s.enableAppleCalendar,
    );
    if (confirmed != true) {
      return;
    }
    await _openAppleCalendarSystemSettings();
  }

  Future<void> _confirmAndRequestLocationPermission(
    BuildContext actionContext,
  ) async {
    final permission = await ref
        .read(deviceContextBridgeProvider)
        .getLocationPermissionState();
    if (!actionContext.mounted || _isLocationAuthorized(permission)) {
      return;
    }
    final confirmed = await showLingAdaptiveConfirmationDialog(
      context: actionContext,
      title: s.locationPermissionTitle,
      message: s.isZh
          ? '允许 Ling 获取当前位置，用于出行、天气和地点相关任务。'
          : 'Allow Ling to use your current location for travel, weather, and place-aware tasks.',
      cancelLabel: s.cancel,
      confirmLabel:
          permission == DeviceLocationPermissionState.denied ||
              permission == DeviceLocationPermissionState.restricted
          ? s.openSystemSettings
          : (s.isZh ? '开启' : 'Enable'),
    );
    if (confirmed != true) {
      return;
    }
    if (permission == DeviceLocationPermissionState.denied ||
        permission == DeviceLocationPermissionState.restricted) {
      await _openLocationSystemSettings();
      return;
    }
    await _requestLocationPermissionFromSettings();
  }

  Future<void> _persistCalendarNotificationSettings(
    CalendarNotificationSettings next,
  ) async {
    final settingsState = ref.read(settingsControllerProvider);
    final previousSettings = settingsState.calendarNotificationSettings;
    final previousProfile = settingsState.profile;
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .persistCalendarNotificationSettings(next, strings: s);
      await _syncCalendarNotificationSchedule(rethrowOnFailure: true);
    } catch (error) {
      ref
          .read(settingsControllerProvider.notifier)
          .restoreCalendarNotificationSettings(
            settings: previousSettings,
            profile: previousProfile,
          );
      _showError(error);
    }
  }

  Future<void> _persistCalendarSyncSettings(CalendarSyncSettings next) async {
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .persistCalendarSyncSettings(next);
      await _ensureSchedulePageDataLoaded(forceRefresh: true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _handleCalendarMutationToolResult(
    ConversationEntryDto entry,
  ) async {
    try {
      final shouldShowUnreadBadge = await _homeSurfaceController
          .handleCalendarMutationToolResult(
            entry: entry,
            isAuthenticated: _isAuthenticated,
            timezone: _currentTimezone,
            calendarNotificationPermission: ref
                .read(settingsControllerProvider)
                .calendarNotificationPermission,
            calendarNotificationSettings: ref
                .read(settingsControllerProvider)
                .calendarNotificationSettings,
            strings: s,
            isCalendarOpen: _isCalendarOpen,
            hasUnreadCalendarBadge: _hasUnreadCalendarBadge,
          );
      await ref
          .read(scheduleSurfaceControllerProvider.notifier)
          .refreshWindowEvents(timezone: _currentTimezone, forceRefresh: true);
      if (!mounted || !shouldShowUnreadBadge) {
        return;
      }
      setState(() {
        _hasUnreadCalendarBadge = true;
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _ensureSchedulePageDataLoaded({
    bool forceRefresh = false,
  }) async {
    try {
      await _homeSurfaceController.ensureSchedulePageDataLoaded(
        isAuthenticated: _isAuthenticated,
        timezone: _currentTimezone,
        calendarNotificationSettings: ref
            .read(settingsControllerProvider)
            .calendarNotificationSettings,
        calendarSyncSettings: ref
            .read(settingsControllerProvider)
            .calendarSyncSettings,
        forceRefresh: forceRefresh,
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _ensureSettingsPageDataLoaded({
    bool forceRefresh = false,
  }) async {
    try {
      switch (_currentSettingsPage) {
        case LingSettingsPageId.general:
          await _ensureGeneralSettingsDataLoaded();
        case LingSettingsPageId.calendar:
          await _homeSurfaceController.ensureSettingsPageDataLoaded(
            isAuthenticated: _isAuthenticated,
            timezone: _currentTimezone,
            forceRefresh: forceRefresh,
          );
        case LingSettingsPageId.root ||
            LingSettingsPageId.accountSecurity ||
            LingSettingsPageId.notifications ||
            LingSettingsPageId.permissions ||
            LingSettingsPageId.signInMethods ||
            LingSettingsPageId.accountSafety ||
            LingSettingsPageId.bindPhone ||
            LingSettingsPageId.bindEmail ||
            LingSettingsPageId.appearance ||
            LingSettingsPageId.fontSize ||
            LingSettingsPageId.language ||
            LingSettingsPageId.preferredInputMode ||
            LingSettingsPageId.timezoneInfo ||
            LingSettingsPageId.aboutLing ||
            LingSettingsPageId.privacy ||
            LingSettingsPageId.security:
          return;
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _clearLocalImageCache() async {
    try {
      final settingsController = ref.read(settingsControllerProvider.notifier);
      await settingsController.clearLocalImageCache();
      await settingsController.refreshLocalImageCacheUsage();
      _showMessage(s.localImageCacheCleared);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _authorizeCalendarProvider(CalendarProviderId provider) async {
    try {
      await _homeSurfaceController.authorizeCalendarProvider(
        provider: provider,
        shouldRefreshScheduleData:
            ref.read(homeSurfaceControllerProvider).hasLoadedSchedulePageData ||
            _isCalendarOpen,
        isAuthenticated: _isAuthenticated,
        timezone: _currentTimezone,
        calendarNotificationSettings: ref
            .read(settingsControllerProvider)
            .calendarNotificationSettings,
      );
      unawaited(
        _trackAppEvent(
          'settings.calendar_provider.authorize_success',
          surface: 'settings',
          action: 'calendar_provider_authorize_success',
          source: provider.name,
        ),
      );
    } on UnsupportedError {
      _showMessage(s.iosOnly);
    } catch (error) {
      unawaited(
        _trackAppEvent(
          'settings.calendar_provider.authorize_failure',
          surface: 'settings',
          action: 'calendar_provider_authorize_failure',
          source: provider.name,
          properties: <String, Object?>{
            'error_type': error.runtimeType.toString(),
          },
        ),
      );
      _showError(error);
    }
  }

  Future<void> _openCalendarProviderApp(CalendarProviderId provider) async {
    try {
      final opened = await _homeSurfaceController.openCalendarProviderApp(
        provider,
      );
      if (opened) {
        return;
      }
      await _authorizeCalendarProvider(provider);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _refreshCalendarProvider(CalendarProviderId provider) async {
    try {
      await _homeSurfaceController.refreshCalendarProvider(
        provider: provider,
        shouldRefreshScheduleData:
            ref.read(homeSurfaceControllerProvider).hasLoadedSchedulePageData ||
            _isCalendarOpen,
        isAuthenticated: _isAuthenticated,
        timezone: _currentTimezone,
        calendarNotificationSettings: ref
            .read(settingsControllerProvider)
            .calendarNotificationSettings,
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _disconnectCalendarProvider(CalendarProviderId provider) async {
    try {
      await _homeSurfaceController.disconnectCalendarProvider(
        provider: provider,
        shouldRefreshScheduleData:
            ref.read(homeSurfaceControllerProvider).hasLoadedSchedulePageData ||
            _isCalendarOpen,
        isAuthenticated: _isAuthenticated,
        timezone: _currentTimezone,
        calendarNotificationSettings: ref
            .read(settingsControllerProvider)
            .calendarNotificationSettings,
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openAppleCalendarSystemSettings() async {
    try {
      final permission = await _homeSurfaceController
          .getAppleCalendarPermissionState();
      if (!mounted) {
        return;
      }
      switch (permission) {
        case AppleCalendarPermissionState.notDetermined:
          final nextPermission = await _homeSurfaceController
              .requestAppleCalendarPermission();
          await _refreshAppleCalendarSurfaces();
          if (nextPermission == AppleCalendarPermissionState.denied) {
            await _promptCalendarPermissionSettings();
          }
          return;
        case AppleCalendarPermissionState.granted:
        case AppleCalendarPermissionState.denied:
          await _homeSurfaceController.openAppleCalendarSystemSettings();
          return;
        case AppleCalendarPermissionState.unsupported:
          return;
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _refreshAppleCalendarSurfaces() async {
    await _ensureSettingsPageDataLoaded(forceRefresh: true);
    final hasLoadedSchedulePageData = ref
        .read(homeSurfaceControllerProvider)
        .hasLoadedSchedulePageData;
    if (_isCalendarOpen || hasLoadedSchedulePageData) {
      await _ensureSchedulePageDataLoaded(forceRefresh: true);
    }
  }

  Future<void> _waitForAuthenticatedSurface() async {
    for (var attempt = 0; attempt < 4; attempt += 1) {
      if (!mounted || _chatSectionKey.currentState != null) {
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
    }
  }
}
