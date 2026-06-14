import 'dart:async';

import 'package:ling/src/core/async/single_flight.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/core/platform/bridges/device_context_bridge.dart';
import 'package:ling/src/core/platform/models/notification_models.dart';
import 'package:ling/src/core/storage/preferences_store.dart';
import 'package:ling/src/core/storage/push_device_id_store.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/settings/application/services/settings_device_sync_support.dart';
import 'package:ling/src/features/settings/application/settings_state.dart';
import 'package:ling/src/features/settings/data/bridges/calendar_notification_bridge.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';

class SettingsDeviceSyncService {
  SettingsDeviceSyncService({
    required PreferencesStore preferencesStore,
    required PushDeviceIdStore pushDeviceIdStore,
    required DeviceContextBridge deviceContextBridge,
    required CalendarNotificationBridge notificationBridge,
    required Future<void> Function(PushDeviceRegistrationRequest request)
    registerPushDevice,
    required Future<void> Function(PushDeviceContextUpdateRequest request)
    updatePushDeviceContext,
  }) : _preferencesStore = preferencesStore,
       _pushDeviceIdStore = pushDeviceIdStore,
       _deviceContextBridge = deviceContextBridge,
       _notificationBridge = notificationBridge,
       _registerPushDevice = registerPushDevice,
       _updatePushDeviceContext = updatePushDeviceContext;

  static const String locationBackendSeededPreferenceKey =
      'ling.location_backend_seeded.v1';
  static const String pendingDeviceTimezonePreferenceKey =
      'ling.pending_device_timezone.v1';
  static const List<Duration> _pushRegistrationRetryDelays = <Duration>[
    Duration.zero,
    Duration(seconds: 1),
    Duration(seconds: 3),
  ];

  final PreferencesStore _preferencesStore;
  final PushDeviceIdStore _pushDeviceIdStore;
  final DeviceContextBridge _deviceContextBridge;
  final CalendarNotificationBridge _notificationBridge;
  final Future<void> Function(PushDeviceRegistrationRequest request)
  _registerPushDevice;
  final Future<void> Function(PushDeviceContextUpdateRequest request)
  _updatePushDeviceContext;

  final SingleFlight<DeviceContextSnapshot?> _deviceContextSingleFlight =
      SingleFlight<DeviceContextSnapshot?>();
  final SingleFlight<void> _authenticatedDeviceBootstrapSingleFlight =
      SingleFlight<void>();
  final SingleFlight<PushDeviceSyncResult> _pushDeviceRegistrationSingleFlight =
      SingleFlight<PushDeviceSyncResult>();
  final SingleFlight<bool> _deviceContextBackendSyncSingleFlight =
      SingleFlight<bool>();
  final SingleFlight<DeviceTimezoneSyncResult> _deviceTimezoneSyncSingleFlight =
      SingleFlight<DeviceTimezoneSyncResult>();

  // Device context
  Future<DeviceContextSnapshot?> refreshDeviceContext({
    bool startTracking = false,
    required void Function(String timezone) onTimezoneChanged,
  }) async {
    return _deviceContextSingleFlight.run(() async {
      try {
        final snapshot = await _deviceContextBridge.getLatestContext(
          startTracking: startTracking,
        );
        final timezone = (snapshot?.timezone ?? '').trim();
        if (timezone.isNotEmpty) {
          onTimezoneChanged(timezone);
        }
        return snapshot;
      } catch (error, stackTrace) {
        AppLogger.warn(
          '[Ling][Settings] 设备上下文刷新失败',
          category: 'settings',
          fields: <String, Object?>{'error': '$error'},
        );
        AppLogger.debug('$stackTrace', category: 'settings');
        return null;
      }
    });
  }

  // Device timezone preference sync
  Future<DeviceTimezoneSyncResult> syncDeviceTimezoneIfNeeded({
    required bool isAuthenticated,
    required UserProfile? currentProfile,
    required Future<UserProfile> Function(UserPreferencesPatch patch)
    syncPreferences,
    required Future<void> Function(UserProfile profile) persistAuthSession,
    required Future<DeviceContextSnapshot?> Function() resolveDeviceContext,
    DeviceContextSnapshot? deviceContext,
  }) async {
    if (!isAuthenticated) {
      return const DeviceTimezoneSyncResult(
        didChange: false,
        pendingRetry: false,
      );
    }
    return _deviceTimezoneSyncSingleFlight.run(() async {
      final resolvedDeviceContext =
          deviceContext ?? await resolveDeviceContext();
      final normalizedDeviceTimezone = (resolvedDeviceContext?.timezone ?? '')
          .trim();
      if (!_isValidPersistedTimezone(normalizedDeviceTimezone)) {
        return const DeviceTimezoneSyncResult(
          didChange: false,
          pendingRetry: false,
        );
      }
      if (currentProfile == null) {
        return const DeviceTimezoneSyncResult(
          didChange: false,
          pendingRetry: false,
        );
      }
      final currentProfileTimezone =
          (currentProfile.preferences?.timezone ?? '').trim();
      if (currentProfileTimezone == normalizedDeviceTimezone) {
        await _clearPendingDeviceTimezoneRetry();
        return const DeviceTimezoneSyncResult(
          didChange: false,
          pendingRetry: false,
        );
      }
      try {
        final updatedProfile = await syncPreferences(
          UserPreferencesPatch(timezone: normalizedDeviceTimezone),
        );
        await persistAuthSession(updatedProfile);
        await _clearPendingDeviceTimezoneRetry();
        return const DeviceTimezoneSyncResult(
          didChange: true,
          pendingRetry: false,
        );
      } catch (error, stackTrace) {
        AppLogger.warn(
          '[Ling][Settings] 设备时区同步失败',
          category: 'settings',
          fields: <String, Object?>{
            'timezone': normalizedDeviceTimezone,
            'error': '$error',
          },
        );
        AppLogger.debug('$stackTrace', category: 'settings');
        await _markPendingDeviceTimezoneRetry(normalizedDeviceTimezone);
        return const DeviceTimezoneSyncResult(
          didChange: false,
          pendingRetry: true,
        );
      }
    });
  }

  // Push device registration
  Future<PushDeviceSyncResult> syncRemotePushDeviceRegistration({
    required bool isAuthenticated,
    required String locale,
    required String fallbackTimezone,
    required Future<DeviceContextSnapshot?> Function() resolveDeviceContext,
    DeviceContextSnapshot? deviceContext,
    bool includeLocationData = false,
    RemoteNotificationRegistration? registration,
    String? deviceId,
    bool notificationsEnabled = true,
  }) async {
    if (!isAuthenticated) {
      return const PushDeviceSyncResult(
        registered: false,
        locationSeeded: false,
      );
    }
    return _pushDeviceRegistrationSingleFlight.run(() async {
      final resolvedDeviceId =
          (deviceId ?? await _pushDeviceIdStore.getOrCreate()).trim();
      if (resolvedDeviceId.isEmpty) {
        return const PushDeviceSyncResult(
          registered: false,
          locationSeeded: false,
        );
      }
      try {
        final resolvedDeviceContext =
            deviceContext ?? await resolveDeviceContext();
        final resolvedRegistration =
            await _resolveRemoteNotificationRegistration(registration);
        final pushToken = resolvedRegistration?.pushToken.trim() ?? '';
        if (pushToken.isEmpty || resolvedRegistration == null) {
          return const PushDeviceSyncResult(
            registered: false,
            locationSeeded: false,
          );
        }
        final shouldIncludeLocationData =
            includeLocationData && _hasLocationPayload(resolvedDeviceContext);
        final request = buildPushDeviceRegistrationRequest(
          deviceId: resolvedDeviceId,
          locale: locale,
          fallbackTimezone: fallbackTimezone,
          registration: resolvedRegistration,
          deviceContext: resolvedDeviceContext,
          includeLocationData: shouldIncludeLocationData,
          notificationsEnabled: notificationsEnabled,
        );
        await _registerPushDeviceWithRetry(request);
        if (includeLocationData && !shouldIncludeLocationData) {
          await _updatePushDeviceContext(
            PushDeviceContextUpdateRequest(
              deviceId: resolvedDeviceId,
              pushToken: pushToken,
              timezone: request.timezone,
              deviceModel: request.deviceModel,
            ),
          );
        }
        if (shouldIncludeLocationData) {
          await _markLocationBackendSeeded();
        }
        return PushDeviceSyncResult(
          registered: true,
          locationSeeded: shouldIncludeLocationData,
        );
      } catch (error, stackTrace) {
        AppLogger.warn(
          '[Ling][Settings] 推送设备注册失败',
          category: 'settings',
          fields: <String, Object?>{'error': '$error'},
        );
        AppLogger.debug('$stackTrace', category: 'settings');
        return const PushDeviceSyncResult(
          registered: false,
          locationSeeded: false,
        );
      }
    });
  }

  // Device context backend sync
  Future<bool> syncDeviceContextToBackend({
    required bool isAuthenticated,
    required String locale,
    required String fallbackTimezone,
    required Future<DeviceContextSnapshot?> Function({bool startTracking})
    resolveDeviceContext,
    bool startTracking = false,
    Duration? locationRefreshIfOlderThan,
    DeviceContextSnapshot? deviceContext,
    RemoteNotificationRegistration? registration,
    String? deviceId,
    bool registerDeviceIfNeeded = true,
    bool notificationsEnabled = true,
  }) async {
    if (!_supportsNativePushDeviceSync || !isAuthenticated) {
      return false;
    }
    return _deviceContextBackendSyncSingleFlight.run(() async {
      final resolvedDeviceId =
          (deviceId ?? await _pushDeviceIdStore.getOrCreate()).trim();
      if (resolvedDeviceId.isEmpty) {
        return false;
      }
      try {
        final resolvedDeviceContext =
            deviceContext ??
            await _resolveDeviceContextForBackendSync(
              resolveDeviceContext: resolveDeviceContext,
              startTracking: startTracking,
              locationRefreshIfOlderThan: locationRefreshIfOlderThan,
            );
        final resolvedRegistration =
            registration ??
            await _notificationBridge.registerRemoteNotifications();
        final pushToken = resolvedRegistration?.pushToken.trim() ?? '';
        if (resolvedRegistration == null || pushToken.isEmpty) {
          return false;
        }

        if (registerDeviceIfNeeded) {
          await _registerPushDevice(
            buildPushDeviceRegistrationRequest(
              deviceId: resolvedDeviceId,
              locale: locale,
              fallbackTimezone: fallbackTimezone,
              registration: resolvedRegistration,
              deviceContext: resolvedDeviceContext,
              includeLocationData: false,
              notificationsEnabled: notificationsEnabled,
            ),
          );
        }

        await _updatePushDeviceContext(
          PushDeviceContextUpdateRequest(
            deviceId: resolvedDeviceId,
            pushToken: pushToken,
            timezone: _hasUsableTimezone(resolvedDeviceContext)
                ? resolvedDeviceContext!.timezone.trim()
                : fallbackTimezone,
            deviceModel: resolvedDeviceContext?.deviceModel,
            formattedAddress: resolvedDeviceContext?.formattedAddress,
            name: resolvedDeviceContext?.name,
            thoroughfare: resolvedDeviceContext?.thoroughfare,
            subThoroughfare: resolvedDeviceContext?.subThoroughfare,
            subLocality: resolvedDeviceContext?.subLocality,
            locality: resolvedDeviceContext?.locality,
            subAdministrativeArea: resolvedDeviceContext?.subAdministrativeArea,
            city: resolvedDeviceContext?.city,
            administrativeArea: resolvedDeviceContext?.administrativeArea,
            postalCode: resolvedDeviceContext?.postalCode,
            country: resolvedDeviceContext?.country,
            isoCountryCode: resolvedDeviceContext?.isoCountryCode,
            areasOfInterest: resolvedDeviceContext?.areasOfInterest,
            latitude: resolvedDeviceContext?.latitude,
            longitude: resolvedDeviceContext?.longitude,
            accuracyMeters: resolvedDeviceContext?.accuracyMeters,
            capturedAt: resolvedDeviceContext?.capturedAt,
          ),
        );

        if (_hasLocationPayload(resolvedDeviceContext)) {
          await _markLocationBackendSeeded();
        }
        return true;
      } catch (error, stackTrace) {
        AppLogger.warn(
          '[Ling][Settings] 设备上下文同步到后端失败',
          category: 'settings',
          fields: <String, Object?>{'error': '$error'},
        );
        AppLogger.debug('$stackTrace', category: 'settings');
        return false;
      }
    });
  }

  // Authenticated device bootstrap
  Future<void> bootstrapAuthenticatedDeviceState({
    required bool isAuthenticated,
    required void Function(CalendarNotificationPermissionState permission)
    onPermissionResolved,
    required Future<DeviceContextSnapshot?> Function({bool startTracking})
    refreshDeviceContext,
    required Future<PushDeviceSyncResult> Function({
      required DeviceContextSnapshot? deviceContext,
      required bool includeLocationData,
      required RemoteNotificationRegistration registration,
      required String deviceId,
      required bool notificationsEnabled,
    })
    registerDevice,
    bool startTracking = true,
  }) async {
    if (!_supportsNativePushDeviceSync || !isAuthenticated) {
      return;
    }
    await _authenticatedDeviceBootstrapSingleFlight.run(() async {
      final deviceId = await _pushDeviceIdStore.getOrCreate();
      final deviceContext = await refreshDeviceContext(
        startTracking: startTracking,
      );
      final permission = await _notificationBridge.getPermissionState();
      onPermissionResolved(permission);
      final registration = await _resolveRemoteNotificationRegistration(null);
      final pushToken = registration?.pushToken.trim() ?? '';
      if (registration == null || pushToken.isEmpty) {
        return;
      }
      await registerDevice(
        deviceContext: deviceContext,
        includeLocationData: true,
        registration: registration,
        deviceId: deviceId,
        notificationsEnabled:
            permission == CalendarNotificationPermissionState.granted,
      );
    });
  }

  bool _hasLocationPayload(DeviceContextSnapshot? snapshot) {
    if (snapshot == null) {
      return false;
    }
    return (snapshot.formattedAddress?.trim().isNotEmpty ?? false) ||
        (snapshot.name?.trim().isNotEmpty ?? false) ||
        (snapshot.thoroughfare?.trim().isNotEmpty ?? false) ||
        (snapshot.subThoroughfare?.trim().isNotEmpty ?? false) ||
        (snapshot.subLocality?.trim().isNotEmpty ?? false) ||
        (snapshot.locality?.trim().isNotEmpty ?? false) ||
        (snapshot.subAdministrativeArea?.trim().isNotEmpty ?? false) ||
        (snapshot.city?.trim().isNotEmpty ?? false) ||
        (snapshot.administrativeArea?.trim().isNotEmpty ?? false) ||
        (snapshot.postalCode?.trim().isNotEmpty ?? false) ||
        (snapshot.country?.trim().isNotEmpty ?? false) ||
        (snapshot.isoCountryCode?.trim().isNotEmpty ?? false) ||
        (snapshot.areasOfInterest?.isNotEmpty ?? false) ||
        (snapshot.latitude != null && snapshot.longitude != null);
  }

  bool get _supportsNativePushDeviceSync =>
      AppPlatformInfo.current == AppPlatform.ios ||
      AppPlatformInfo.current == AppPlatform.ohos;

  Future<DeviceContextSnapshot?> _resolveDeviceContextForBackendSync({
    required Future<DeviceContextSnapshot?> Function({bool startTracking})
    resolveDeviceContext,
    required bool startTracking,
    required Duration? locationRefreshIfOlderThan,
  }) async {
    if (startTracking || locationRefreshIfOlderThan == null) {
      return resolveDeviceContext(startTracking: startTracking);
    }
    final latest = await resolveDeviceContext(startTracking: false);
    if (!_shouldRefreshLocation(latest, maxAge: locationRefreshIfOlderThan)) {
      return latest;
    }
    return resolveDeviceContext(startTracking: true);
  }

  bool _shouldRefreshLocation(
    DeviceContextSnapshot? snapshot, {
    required Duration maxAge,
  }) {
    final capturedAt = snapshot?.capturedAt;
    if (capturedAt == null) {
      return true;
    }
    return DateTime.now().difference(capturedAt) > maxAge;
  }

  Future<RemoteNotificationRegistration?>
  _resolveRemoteNotificationRegistration(
    RemoteNotificationRegistration? registration,
  ) async {
    final providedToken = registration?.pushToken.trim() ?? '';
    if (registration != null && providedToken.isNotEmpty) {
      return registration;
    }
    RemoteNotificationRegistration? latest;
    for (final delay in _pushRegistrationRetryDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      latest = await _notificationBridge.registerRemoteNotifications();
      final pushToken = latest?.pushToken.trim() ?? '';
      if (latest != null && pushToken.isNotEmpty) {
        return latest;
      }
    }
    return latest;
  }

  Future<void> _registerPushDeviceWithRetry(
    PushDeviceRegistrationRequest request,
  ) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (final delay in _pushRegistrationRetryDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      try {
        await _registerPushDevice(request);
        return;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        AppLogger.warn(
          '[Ling][Settings] 推送设备注册请求失败，准备重试',
          category: 'settings',
          fields: <String, Object?>{
            'device_id': request.deviceId,
            'error': '$error',
          },
        );
      }
    }
    Error.throwWithStackTrace(
      lastError ?? StateError('push registration failed'),
      lastStackTrace ?? StackTrace.current,
    );
  }

  bool _hasUsableTimezone(DeviceContextSnapshot? snapshot) {
    return (snapshot?.timezone.trim().isNotEmpty ?? false);
  }

  Future<void> _markLocationBackendSeeded() async {
    await _preferencesStore.writeString(
      locationBackendSeededPreferenceKey,
      '1',
    );
  }

  Future<void> _markPendingDeviceTimezoneRetry(String timezone) async {
    await _preferencesStore.writeString(
      pendingDeviceTimezonePreferenceKey,
      timezone,
    );
  }

  Future<void> _clearPendingDeviceTimezoneRetry() async {
    await _preferencesStore.remove(pendingDeviceTimezonePreferenceKey);
  }

  bool _isValidPersistedTimezone(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return false;
    }
    if (normalized == 'UTC') {
      return true;
    }
    if (normalized.startsWith('UTC+') || normalized.startsWith('UTC-')) {
      return false;
    }
    return normalized.contains('/');
  }
}
