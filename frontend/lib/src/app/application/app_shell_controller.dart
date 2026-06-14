import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/application/app_session_lifecycle_coordinator.dart';
import 'package:ling/src/app/application/app_shell_state.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/async/single_flight.dart';
import 'package:ling/src/core/storage/push_device_id_store.dart';
import 'package:ling/src/features/calendar/application/calendar_controller.dart';
import 'package:ling/src/features/calendar/application/calendar_notification_support.dart';
import 'package:ling/src/features/calendar/data/bridges/apple_calendar_bridge.dart';
import 'package:ling/src/features/calendar/data/bridges/calendar_provider_app_launcher.dart';
import 'package:ling/src/features/calendar/data/bridges/external_calendar_oauth_bridge.dart';
import 'package:ling/src/features/calendar/data/repositories/apple_calendar_sync_repository.dart';
import 'package:ling/src/features/calendar/data/repositories/calendar_integration_repository.dart';
import 'package:ling/src/features/calendar/data/repositories/calendar_repository.dart';
import 'package:ling/src/features/calendar/models/calendar_integration_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/models/calendar_time.dart';
import 'package:ling/src/features/chat/application/tool_call_result_mapper.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';
import 'package:ling/src/features/settings/data/bridges/calendar_notification_bridge.dart';
import 'package:ling/src/features/settings/data/bridges/review_request_bridge.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';

class AppleCalendarSyncResult {
  const AppleCalendarSyncResult({
    required this.permission,
    required this.events,
    required this.didMutateEvents,
    required this.insertedCount,
    required this.updatedCount,
    required this.deactivatedCount,
  });

  final AppleCalendarPermissionState permission;
  final List<AppleCalendarEvent> events;
  final bool didMutateEvents;
  final int insertedCount;
  final int updatedCount;
  final int deactivatedCount;
}

class HomeSurfaceController extends Notifier<HomeSurfaceState> {
  final SingleFlight<void> _appleCalendarMirrorSingleFlight =
      SingleFlight<void>();
  final SingleFlight<void> _schedulePageDataSingleFlight = SingleFlight<void>();
  final SingleFlight<void> _schedulePageRefreshSingleFlight =
      SingleFlight<void>();
  final SingleFlight<void> _settingsPageDataSingleFlight = SingleFlight<void>();
  final SingleFlight<void> _settingsPageRefreshSingleFlight =
      SingleFlight<void>();
  final Map<String, SingleFlight<AppleCalendarSyncResult>>
  _appleCalendarContextSyncFlights =
      <String, SingleFlight<AppleCalendarSyncResult>>{};

  AppleCalendarBridge get _appleCalendarBridge =>
      ref.read(appleCalendarBridgeProvider);
  CalendarNotificationBridge get _calendarNotificationBridge =>
      ref.read(calendarNotificationBridgeProvider);
  CalendarRepository get _calendarRepository =>
      ref.read(calendarRepositoryProvider);
  AppleCalendarSyncRepository get _appleCalendarSyncRepository =>
      ref.read(appleCalendarSyncRepositoryProvider);
  CalendarIntegrationRepository get _calendarIntegrationRepository =>
      ref.read(calendarIntegrationRepositoryProvider);
  PushDeviceIdStore get _pushDeviceIdStore =>
      ref.read(pushDeviceIdStoreProvider);
  ExternalCalendarOAuthBridge get _externalCalendarOAuthBridge =>
      ref.read(externalCalendarOAuthBridgeProvider);
  CalendarProviderAppLauncher get _calendarProviderAppLauncher =>
      ref.read(calendarProviderAppLauncherProvider);
  ReviewRequestBridge get _reviewRequestBridge =>
      ref.read(reviewRequestBridgeProvider);
  CalendarController get _calendarController =>
      ref.read(calendarControllerProvider.notifier);

  @override
  HomeSurfaceState build() => const HomeSurfaceState();

  void clear() {
    state = const HomeSurfaceState();
  }

  Future<bool> requestReview() {
    return _reviewRequestBridge.requestReview();
  }

  Future<void> syncForegroundNotificationContext({
    required bool isAppInForeground,
    required bool isCalendarOpen,
    required bool isSettingsOpen,
  }) async {
    final context = !isAppInForeground
        ? 'background'
        : (isCalendarOpen || isSettingsOpen ? 'other' : 'chat');
    try {
      await _calendarNotificationBridge.setForegroundNotificationContext(
        context,
      );
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> ensureSchedulePageDataLoaded({
    required bool isAuthenticated,
    required String timezone,
    required CalendarNotificationSettings calendarNotificationSettings,
    CalendarSyncSettings calendarSyncSettings = const CalendarSyncSettings(),
    bool forceRefresh = false,
  }) async {
    if (!isAuthenticated) {
      return;
    }
    if (!forceRefresh && state.hasLoadedSchedulePageData) {
      return;
    }

    Future<void> load() async {
      await _calendarController.load(forceRefresh: forceRefresh);
      final (startAt, endAt) = _appleCalendarSyncWindow(timezone);
      await _mirrorLingEventsToAppleCalendar(
        startAt: startAt,
        endAt: endAt,
        timezone: timezone,
        calendarNotificationSettings: calendarNotificationSettings,
        calendarSyncSettings: calendarSyncSettings,
      );
      final appleSyncResult = await _syncAppleCalendarContext(
        timezone: timezone,
      );
      if (_shouldReloadScheduleAfterAppleSync(appleSyncResult)) {
        // Apple mirroring/import can mutate Ling-facing rows and links; reload
        // once more when the Apple-facing source of truth actually changed.
        await _calendarController.load(forceRefresh: true);
      }
      state = state.copyWith(
        applePermission: appleSyncResult.permission,
        appleEvents: appleSyncResult.events,
        hasLoadedSchedulePageData: true,
      );
    }

    if (forceRefresh) {
      await _schedulePageRefreshSingleFlight.run(load);
      return;
    }
    await _schedulePageDataSingleFlight.run(load);
  }

  Future<void> ensureSettingsPageDataLoaded({
    required bool isAuthenticated,
    required String timezone,
    bool forceRefresh = false,
  }) async {
    if (!isAuthenticated) {
      return;
    }

    Future<void> refreshAppleSurface() async {
      final appleSyncResult = await _syncAppleCalendarContext(
        timezone: timezone,
      );
      state = state.copyWith(
        applePermission: appleSyncResult.permission,
        appleEvents: appleSyncResult.events,
      );
    }

    await refreshAppleSurface();

    if (!forceRefresh && state.hasLoadedSettingsPageData) {
      return;
    }

    Future<void> load() async {
      final items = await _calendarIntegrationRepository.listConnections();
      state = state.copyWith(
        calendarConnections: items,
        hasLoadedSettingsPageData: true,
      );
    }

    if (forceRefresh) {
      await _settingsPageRefreshSingleFlight.run(load);
      return;
    }
    await _settingsPageDataSingleFlight.run(load);
  }

  Future<void> authorizeCalendarProvider({
    required CalendarProviderId provider,
    required bool shouldRefreshScheduleData,
    required bool isAuthenticated,
    required String timezone,
    required CalendarNotificationSettings calendarNotificationSettings,
  }) async {
    final oauthStart = await _calendarIntegrationRepository.startOAuth(
      provider,
    );
    final result = await _externalCalendarOAuthBridge.authorize(
      authorizeUrl: oauthStart.authorizeUrl,
      callbackScheme: oauthStart.callbackScheme,
    );
    switch (result.status) {
      case ExternalCalendarOAuthStatus.success:
        final callbackUrl = (result.callbackUrl ?? '').trim();
        if (callbackUrl.isEmpty) {
          throw StateError(result.message);
        }
        await _calendarIntegrationRepository.completeOAuth(
          provider,
          CalendarOAuthCompleteRequest(callbackUrl: callbackUrl),
        );
        await ensureSettingsPageDataLoaded(
          isAuthenticated: isAuthenticated,
          timezone: timezone,
          forceRefresh: true,
        );
        if (shouldRefreshScheduleData) {
          await ensureSchedulePageDataLoaded(
            isAuthenticated: isAuthenticated,
            timezone: timezone,
            calendarNotificationSettings: calendarNotificationSettings,
            forceRefresh: true,
          );
        }
        return;
      case ExternalCalendarOAuthStatus.cancelled:
        return;
      case ExternalCalendarOAuthStatus.unsupported:
        throw UnsupportedError('unsupported');
      case ExternalCalendarOAuthStatus.error:
        throw StateError(result.message);
    }
  }

  Future<bool> openCalendarProviderApp(CalendarProviderId provider) {
    return _calendarProviderAppLauncher.open(provider);
  }

  Future<void> refreshCalendarProvider({
    required CalendarProviderId provider,
    required bool shouldRefreshScheduleData,
    required bool isAuthenticated,
    required String timezone,
    required CalendarNotificationSettings calendarNotificationSettings,
  }) async {
    await _calendarIntegrationRepository.refreshConnection(provider);
    await ensureSettingsPageDataLoaded(
      isAuthenticated: isAuthenticated,
      timezone: timezone,
      forceRefresh: true,
    );
    if (shouldRefreshScheduleData) {
      await ensureSchedulePageDataLoaded(
        isAuthenticated: isAuthenticated,
        timezone: timezone,
        calendarNotificationSettings: calendarNotificationSettings,
        forceRefresh: true,
      );
    }
  }

  Future<void> disconnectCalendarProvider({
    required CalendarProviderId provider,
    required bool shouldRefreshScheduleData,
    required bool isAuthenticated,
    required String timezone,
    required CalendarNotificationSettings calendarNotificationSettings,
  }) async {
    await _calendarIntegrationRepository.disconnect(provider);
    await ensureSettingsPageDataLoaded(
      isAuthenticated: isAuthenticated,
      timezone: timezone,
      forceRefresh: true,
    );
    if (shouldRefreshScheduleData) {
      await ensureSchedulePageDataLoaded(
        isAuthenticated: isAuthenticated,
        timezone: timezone,
        calendarNotificationSettings: calendarNotificationSettings,
        forceRefresh: true,
      );
    }
  }

  Future<void> openAppleCalendarSystemSettings() {
    return _appleCalendarBridge.openSystemSettings();
  }

  Future<AppleCalendarPermissionState> getAppleCalendarPermissionState() {
    return _appleCalendarBridge.getPermissionState();
  }

  Future<AppleCalendarPermissionState> requestAppleCalendarPermission() {
    return _appleCalendarBridge.requestPermission();
  }

  Future<bool> handleCalendarMutationToolResult({
    required ConversationEntryDto entry,
    required bool isAuthenticated,
    required String timezone,
    required CalendarNotificationPermissionState calendarNotificationPermission,
    required CalendarNotificationSettings calendarNotificationSettings,
    required LingStrings strings,
    required bool isCalendarOpen,
    required bool hasUnreadCalendarBadge,
  }) async {
    await _executeCalendarClientAction(entry);
    await ensureSchedulePageDataLoaded(
      isAuthenticated: isAuthenticated,
      timezone: timezone,
      calendarNotificationSettings: calendarNotificationSettings,
      forceRefresh: true,
    );
    await ref
        .read(appSessionLifecycleCoordinatorProvider)
        .syncCalendarNotificationSchedule(
          isAuthenticated: isAuthenticated,
          timezone: timezone,
          permission: calendarNotificationPermission,
          settings: calendarNotificationSettings,
          strings: strings,
        );
    return !isCalendarOpen && !hasUnreadCalendarBadge;
  }

  Future<void> _mirrorLingEventsToAppleCalendar({
    required DateTime startAt,
    required DateTime endAt,
    required String timezone,
    required CalendarNotificationSettings calendarNotificationSettings,
    required CalendarSyncSettings calendarSyncSettings,
  }) async {
    await _appleCalendarMirrorSingleFlight.run(() async {
      if (!calendarSyncSettings.appleWriteBackEnabled) {
        return;
      }
      final permission = await _appleCalendarBridge.getPermissionState();
      if (permission != AppleCalendarPermissionState.granted) {
        return;
      }
      final normalizedTimezone = timezone.trim().isEmpty
          ? 'UTC'
          : timezone.trim();
      final lingEvents = await _calendarRepository.getEventsInWindow(
        startAt: formatLingDateTimeWithTimezone(startAt, normalizedTimezone),
        endAt: formatLingDateTimeWithTimezone(endAt, normalizedTimezone),
        timezone: normalizedTimezone,
        forceRefresh: true,
      );
      final deviceId = await _pushDeviceIdStore.getOrCreate();
      final mirroredSeriesIds = <String>{};
      for (final event in lingEvents) {
        if (event.source != 'ling') {
          continue;
        }
        if (event.isPoint) {
          continue;
        }
        final dedupeKey = event.isRecurring
            ? (event.seriesId ?? event.eventId)
            : event.eventId;
        if (!mirroredSeriesIds.add(dedupeKey)) {
          continue;
        }
        await _syncLingEventToAppleCalendar(
          event: event,
          deviceId: deviceId,
          calendarNotificationSettings: calendarNotificationSettings,
        );
      }
    });
  }

  Future<void> _syncLingEventToAppleCalendar({
    required LingEvent event,
    required String deviceId,
    required CalendarNotificationSettings calendarNotificationSettings,
  }) async {
    if (event.isPoint) {
      return;
    }
    final appleLink = event.appleLink;
    final eventIdentifier = appleLink?.eventIdentifier?.trim() ?? '';
    final draft = buildAppleCalendarDraftFromLingEvent(
      event: event,
      alarms: buildAppleCalendarAlarmPayload(
        calendarNotificationSettings,
        event: event,
        syncingToAppleCalendar: true,
      ),
      fallbackTitle: event.title.trim().isEmpty ? 'Untitled' : event.title,
      useRecurrenceAnchors: true,
    );
    try {
      Map<String, dynamic> response;
      if (eventIdentifier.isEmpty) {
        response = await _appleCalendarBridge.createEvent(draft);
      } else {
        try {
          response = await _appleCalendarBridge.updateEvent(
            AppleCalendarMutationOptions(
              eventIdentifier: eventIdentifier,
              calendarItemIdentifier: appleLink?.calendarItemIdentifier,
            ),
            draft,
          );
        } on PlatformException catch (error) {
          if (error.code != 'not_found') {
            rethrow;
          }
          response = await _appleCalendarBridge.createEvent(draft);
        }
      }
      await _linkAppleCalendarEventIfNeeded(
        event: event,
        deviceId: deviceId,
        previousLink: appleLink,
        response: response,
      );
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _linkAppleCalendarEventIfNeeded({
    required LingEvent event,
    required String deviceId,
    required AppleEventLink? previousLink,
    required Map<String, dynamic> response,
  }) async {
    final eventIdentifier =
        '${response['eventIdentifier'] ?? previousLink?.eventIdentifier ?? ''}'
            .trim();
    final calendarIdentifier =
        '${response['calendarIdentifier'] ?? previousLink?.calendarIdentifier ?? ''}'
            .trim();
    final calendarItemIdentifier =
        '${response['calendarItemIdentifier'] ?? previousLink?.calendarItemIdentifier ?? ''}'
            .trim();
    if (eventIdentifier.isEmpty || calendarIdentifier.isEmpty) {
      return;
    }
    final previousDeviceId = previousLink?.deviceId?.trim() ?? '';
    final previousEventIdentifier = previousLink?.eventIdentifier?.trim() ?? '';
    final previousCalendarIdentifier =
        previousLink?.calendarIdentifier?.trim() ?? '';
    final previousCalendarItemIdentifier =
        previousLink?.calendarItemIdentifier?.trim() ?? '';
    if (previousDeviceId == deviceId &&
        previousEventIdentifier == eventIdentifier &&
        previousCalendarIdentifier == calendarIdentifier &&
        previousCalendarItemIdentifier == calendarItemIdentifier) {
      return;
    }
    await _appleCalendarSyncRepository.linkAppleEvent(
      AppleEventLinkRequest(
        lingEventId: event.eventId,
        deviceId: deviceId,
        calendarIdentifier: calendarIdentifier,
        eventIdentifier: eventIdentifier,
        syncState: 'linked',
        metadata: <String, dynamic>{
          if (calendarItemIdentifier.isNotEmpty)
            'calendar_item_identifier': calendarItemIdentifier,
        },
      ),
    );
  }

  Future<AppleCalendarSyncResult> _syncAppleCalendarContext({
    required String timezone,
  }) async {
    final normalizedTimezone = _normalizedAppleCalendarSyncTimezone(timezone);
    final syncFlight = _appleCalendarContextSyncFlights.putIfAbsent(
      normalizedTimezone,
      () => SingleFlight<AppleCalendarSyncResult>(),
    );
    return syncFlight.run(
      () => _performAppleCalendarContextSync(timezone: normalizedTimezone),
    );
  }

  Future<AppleCalendarSyncResult> _performAppleCalendarContextSync({
    required String timezone,
  }) async {
    final permission = await _appleCalendarBridge.getPermissionState();
    if (permission == AppleCalendarPermissionState.unsupported) {
      return const AppleCalendarSyncResult(
        permission: AppleCalendarPermissionState.unsupported,
        events: <AppleCalendarEvent>[],
        didMutateEvents: false,
        insertedCount: 0,
        updatedCount: 0,
        deactivatedCount: 0,
      );
    }
    final (startAt, endAt) = _appleCalendarSyncWindow(timezone);
    final events = permission == AppleCalendarPermissionState.granted
        ? await _appleCalendarBridge.listEvents(startAt: startAt, endAt: endAt)
        : const <AppleCalendarEvent>[];
    final deviceId = await _pushDeviceIdStore.getOrCreate();
    final uploadResult = await _appleCalendarSyncRepository
        .uploadAppleCalendarContext(
          AppleCalendarContextUploadRequest(
            deviceId: deviceId,
            windowStart: startAt.toUtc().toIso8601String(),
            windowEnd: endAt.toUtc().toIso8601String(),
            permissionState: _applePermissionRaw(permission),
            timezone: timezone,
            events: events
                .map((event) => event.toSummaryJson())
                .toList(growable: false),
          ),
        );
    return AppleCalendarSyncResult(
      permission: permission,
      events: events,
      didMutateEvents: uploadResult.didMutateEvents,
      insertedCount: uploadResult.insertedCount,
      updatedCount: uploadResult.updatedCount,
      deactivatedCount: uploadResult.deactivatedCount,
    );
  }

  String _normalizedAppleCalendarSyncTimezone(String timezone) {
    final trimmed = timezone.trim();
    return trimmed.isEmpty ? 'UTC' : trimmed;
  }

  bool _shouldReloadScheduleAfterAppleSync(AppleCalendarSyncResult result) {
    return result.permission == AppleCalendarPermissionState.granted &&
        result.didMutateEvents;
  }

  (DateTime, DateTime) _appleCalendarSyncWindow(String timezone) {
    final now = currentLingDateTime(timezone);
    final startAt = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 7));
    final endAt = startAt.add(const Duration(days: 52));
    return (startAt, endAt);
  }

  Future<void> _executeCalendarClientAction(ConversationEntryDto entry) async {
    final clientAction = decodeLingCalendarClientAction(entry.toolResult);
    if (clientAction == null) {
      return;
    }
    final kind = '${clientAction['kind'] ?? ''}'.trim();
    if (kind != 'apple_calendar_mutation') {
      return;
    }
    final permission = await _appleCalendarBridge.getPermissionState();
    if (permission != AppleCalendarPermissionState.granted) {
      return;
    }
    final operation = '${clientAction['operation'] ?? ''}'.trim();
    final draftValue = clientAction['draft'];
    final mutationOptionsValue = clientAction['mutation_options'];
    final draft = draftValue is Map<String, dynamic>
        ? Map<String, dynamic>.from(draftValue)
        : draftValue is Map
        ? Map<String, dynamic>.from(draftValue)
        : <String, dynamic>{};
    final mutationOptions = mutationOptionsValue is Map<String, dynamic>
        ? Map<String, dynamic>.from(mutationOptionsValue)
        : mutationOptionsValue is Map
        ? Map<String, dynamic>.from(mutationOptionsValue)
        : <String, dynamic>{};

    switch (operation) {
      case 'create':
        await _appleCalendarBridge.createEvent(draft);
        return;
      case 'update':
        await _appleCalendarBridge.updateEvent(
          _appleMutationOptionsFromJson(mutationOptions),
          draft,
        );
        return;
      case 'delete':
        await _appleCalendarBridge.deleteEvent(
          _appleMutationOptionsFromJson(mutationOptions),
        );
        return;
      default:
        return;
    }
  }

  AppleCalendarMutationOptions _appleMutationOptionsFromJson(
    Map<String, dynamic> payload,
  ) {
    AppleCalendarMutationSpan span = AppleCalendarMutationSpan.thisEvent;
    final rawSpan = '${payload['span'] ?? ''}'.trim().toLowerCase();
    if (rawSpan == 'futureevents' ||
        rawSpan == 'future_events' ||
        rawSpan == 'series') {
      span = AppleCalendarMutationSpan.futureEvents;
    }
    final occurrenceDateRaw = '${payload['occurrenceDate'] ?? ''}'.trim();
    return AppleCalendarMutationOptions(
      eventIdentifier: '${payload['eventIdentifier'] ?? ''}'.trim(),
      calendarItemIdentifier:
          '${payload['calendarItemIdentifier'] ?? ''}'.trim().isEmpty
          ? null
          : '${payload['calendarItemIdentifier'] ?? ''}'.trim(),
      occurrenceDate: occurrenceDateRaw.isEmpty
          ? null
          : DateTime.tryParse(occurrenceDateRaw),
      span: span,
    );
  }

  String _applePermissionRaw(AppleCalendarPermissionState permission) {
    switch (permission) {
      case AppleCalendarPermissionState.granted:
        return 'granted';
      case AppleCalendarPermissionState.denied:
        return 'denied';
      case AppleCalendarPermissionState.notDetermined:
        return 'not_determined';
      case AppleCalendarPermissionState.unsupported:
        return 'unsupported';
    }
  }
}

final homeSurfaceControllerProvider =
    NotifierProvider<HomeSurfaceController, HomeSurfaceState>(
      HomeSurfaceController.new,
    );
