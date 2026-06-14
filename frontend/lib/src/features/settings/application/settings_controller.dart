import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/core/platform/bridges/device_context_bridge.dart';
import 'package:ling/src/core/platform/models/notification_models.dart';
import 'package:ling/src/core/providers.dart';
import 'package:ling/src/core/storage/preferences_store.dart';
import 'package:ling/src/core/storage/private_asset_cache_store.dart';
import 'package:ling/src/core/storage/push_device_id_store.dart';
import 'package:ling/src/features/auth/application/auth_controller.dart';
import 'package:ling/src/features/auth/data/repositories/profile_repository.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/calendar/models/apple_calendar_models.dart';
import 'package:ling/src/features/chat/data/apple_speech_recognition_bridge.dart';
import 'package:ling/src/features/settings/application/services/settings_account_binding_service.dart';
import 'package:ling/src/features/settings/application/services/settings_device_sync_service.dart';
import 'package:ling/src/features/settings/application/services/settings_preferences_service.dart';
import 'package:ling/src/features/settings/application/settings_calendar_notification_preferences.dart';
import 'package:ling/src/features/settings/application/settings_state.dart';
import 'package:ling/src/features/settings/data/bridges/calendar_notification_bridge.dart';
import 'package:ling/src/features/settings/data/bridges/photo_library_permission_bridge.dart';
import 'package:ling/src/shared/i18n/ling_locale.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';
import 'package:ling/src/shared/models/font_size_preference.dart';
import 'package:ling/src/shared/models/preferred_input_mode.dart';

String serializeThemeModePreference(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

ThemeMode? deserializeThemeModePreference(dynamic value) {
  switch ('$value') {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    default:
      return null;
  }
}

String serializeCalendarNotificationPermissionState(
  CalendarNotificationPermissionState state,
) {
  switch (state) {
    case CalendarNotificationPermissionState.granted:
      return 'granted';
    case CalendarNotificationPermissionState.denied:
      return 'denied';
    case CalendarNotificationPermissionState.notDetermined:
      return 'not_determined';
    case CalendarNotificationPermissionState.unsupported:
      return 'unsupported';
  }
}

String serializeAppleCalendarPermissionState(
  AppleCalendarPermissionState state,
) {
  switch (state) {
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

final initialLingLocaleCodeProvider = Provider<String>(
  (ref) => resolveSystemLingLocaleCode(),
);

final initialLingFontSizeLevelProvider = Provider<LingFontSizeLevel>(
  (ref) => LingFontSizeLevel.fallback,
);

class SettingsController extends Notifier<SettingsState> {
  PreferencesStore get _preferencesStore => ref.read(preferencesProvider);
  ProfileRepository get _repository => ref.read(profileRepositoryProvider);
  CalendarNotificationBridge get _calendarNotificationBridge =>
      ref.read(calendarNotificationBridgeProvider);
  DeviceContextBridge get _deviceContextBridge =>
      ref.read(deviceContextBridgeProvider);
  AppleSpeechRecognitionBridge get _speechRecognitionBridge =>
      ref.read(appleSpeechRecognitionBridgeProvider);
  PhotoLibraryPermissionBridge get _photoLibraryPermissionBridge =>
      ref.read(photoLibraryPermissionBridgeProvider);
  PushDeviceIdStore get _pushDeviceIdStore =>
      ref.read(pushDeviceIdStoreProvider);
  PrivateAssetCacheStore get _privateAssetCacheStore =>
      ref.read(privateAssetCacheStoreProvider);
  SettingsPreferencesService? _preferencesServiceCache;
  SettingsAccountBindingService? _accountBindingServiceCache;
  SettingsDeviceSyncService? _deviceSyncServiceCache;

  SettingsPreferencesService get _preferencesService =>
      _preferencesServiceCache ??= SettingsPreferencesService(
        preferencesStore: _preferencesStore,
        repository: _repository,
      );

  SettingsAccountBindingService get _accountBindingService =>
      _accountBindingServiceCache ??= SettingsAccountBindingService(
        repository: _repository,
      );

  SettingsDeviceSyncService get _deviceSyncService =>
      _deviceSyncServiceCache ??= SettingsDeviceSyncService(
        preferencesStore: _preferencesStore,
        pushDeviceIdStore: _pushDeviceIdStore,
        deviceContextBridge: _deviceContextBridge,
        notificationBridge: _calendarNotificationBridge,
        registerPushDevice: _repository.registerPushDevice,
        updatePushDeviceContext: _repository.updatePushDeviceContext,
      );

  @override
  SettingsState build() => SettingsState(
    localeCode: normalizeLingLocaleCode(
      ref.read(initialLingLocaleCodeProvider),
    ),
    fontSizeLevel: ref.read(initialLingFontSizeLevelProvider),
  );

  void applyProfile(UserProfile? profile) {
    if (profile == null) {
      return;
    }
    final preferences = profile.preferences;
    final rawLocaleCode = (preferences?.locale ?? '').trim();
    final timezone = (preferences?.timezone ?? '').trim();
    state = state.copyWith(
      profile: profile,
      localeCode: rawLocaleCode.isEmpty
          ? state.localeCode
          : normalizeLingLocaleCode(rawLocaleCode),
      timezone: timezone.isEmpty ? state.timezone : timezone,
      calendarNotificationSettings: calendarNotificationSettingsFromProfile(
        profile,
      ),
      calendarSyncSettings: calendarSyncSettingsFromProfile(profile),
    );
  }

  void updateLocaleCode(String localeCode) {
    final normalized = normalizeLingLocaleCode(localeCode);
    state = state.copyWith(localeCode: normalized);
  }

  void updateTimezone(String timezone) {
    final normalized = timezone.trim();
    if (normalized.isEmpty) {
      return;
    }
    state = state.copyWith(timezone: normalized);
  }

  void updateFontSizeLevel(LingFontSizeLevel level) {
    if (state.fontSizeLevel == level) {
      return;
    }
    state = state.copyWith(fontSizeLevel: level);
  }

  Future<void> syncFontSizeLevelPreference(LingFontSizeLevel level) async {
    updateFontSizeLevel(level);
    await _preferencesService.persistFontSizeLevel(level);
  }

  void setCalendarNotificationPermission(
    CalendarNotificationPermissionState value,
  ) {
    state = state.copyWith(calendarNotificationPermission: value);
  }

  void setLocationPermission(DeviceLocationPermissionState value) {
    state = state.copyWith(locationPermission: value);
  }

  void setMicrophonePermission(SpeechAuthorizationState value) {
    state = state.copyWith(microphonePermission: value);
  }

  void setPhotoLibraryPermission(PhotoLibraryPermissionState value) {
    state = state.copyWith(photoLibraryPermission: value);
  }

  SettingsBindingState bindingStateForPhone(bool isPhone) {
    return isPhone ? state.phoneBinding : state.emailBinding;
  }

  void resetBindingState({required bool isPhone}) {
    state = state.copyWith(
      phoneBinding: isPhone ? const SettingsBindingState() : null,
      emailBinding: isPhone ? null : const SettingsBindingState(),
    );
  }

  Future<UserProfile> refreshProfile({bool forceRefresh = false}) async {
    final profile = await _repository.getProfile(forceRefresh: forceRefresh);
    applyProfile(profile);
    return profile;
  }

  Future<UserProfile> syncPreferences(UserPreferencesPatch patch) async {
    final profile = await _preferencesService.syncPreferences(patch);
    applyProfile(profile);
    return profile;
  }

  Future<UserProfile> syncPreferredInputMode(String mode) async {
    final normalized = normalizePreferredInputMode(mode);
    final nextProfile = _preferencesService.optimisticPreferredInputModeProfile(
      state.profile,
      normalized,
    );
    if (nextProfile != null) {
      applyProfile(nextProfile);
      await _persistAuthSession(nextProfile);
    }
    try {
      final updatedProfile = await syncPreferences(
        UserPreferencesPatch(preferredInputMode: normalized),
      );
      await _persistAuthSession(updatedProfile);
      return updatedProfile;
    } catch (_) {
      if (nextProfile != null) {
        return nextProfile;
      }
      rethrow;
    }
  }

  Future<UserProfile> syncQuietHours({
    required String start,
    required String end,
  }) async {
    final updatedProfile = await syncPreferences(
      UserPreferencesPatch(quietHoursStart: start, quietHoursEnd: end),
    );
    await _persistAuthSession(updatedProfile);
    return updatedProfile;
  }

  Future<int> refreshLocalImageCacheUsage() async {
    final size = await _privateAssetCacheStore.sizeBytes();
    state = state.copyWith(localImageCacheBytes: size);
    return size;
  }

  Future<void> clearLocalImageCache() async {
    if (state.isClearingLocalImageCache) {
      return;
    }
    state = state.copyWith(isClearingLocalImageCache: true);
    try {
      await _privateAssetCacheStore.clear();
      state = state.copyWith(localImageCacheBytes: 0);
    } finally {
      state = state.copyWith(isClearingLocalImageCache: false);
    }
  }

  Future<ChallengeResult> requestPhoneBindingChallenge(String phone) {
    return _requestBindingChallenge(
      isPhone: true,
      recipient: phone.trim(),
      loader: () => _accountBindingService.requestPhoneChallenge(phone),
    );
  }

  Future<ChallengeResult> requestEmailBindingChallenge(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    return _requestBindingChallenge(
      isPhone: false,
      recipient: normalizedEmail,
      loader: () => _accountBindingService.requestEmailChallenge(email),
    );
  }

  Future<AccountBundle> bindPhone({
    required String phone,
    required String challengeId,
    required String code,
  }) async {
    return _bind(
      isPhone: true,
      loader: () => _accountBindingService.bindPhone(
        phone: phone,
        challengeId: challengeId,
        code: code,
      ),
    );
  }

  Future<AccountBundle> bindEmail({
    required String email,
    required String code,
  }) async {
    return _bind(
      isPhone: false,
      loader: () => _accountBindingService.bindEmail(email: email, code: code),
    );
  }

  Future<AccountBundle> bindAppleIdentity({
    required String identityToken,
    String? authorizationCode,
    Map<String, dynamic>? fullName,
  }) async {
    final bundle = await _accountBindingService.bindAppleIdentity(
      identityToken: identityToken,
      authorizationCode: authorizationCode,
      fullName: fullName,
    );
    applyProfile(bundle.profile);
    await ref.read(authControllerProvider.notifier).updateAccountBundle(bundle);
    return bundle;
  }

  Future<AccountBundle> bindWeChatIdentity({required String authCode}) async {
    final bundle = await _accountBindingService.bindWeChatIdentity(
      authCode: authCode,
    );
    applyProfile(bundle.profile);
    await ref.read(authControllerProvider.notifier).updateAccountBundle(bundle);
    return bundle;
  }

  Future<void> registerPushDevice(PushDeviceRegistrationRequest request) {
    return _repository.registerPushDevice(request);
  }

  Future<void> updatePushDeviceContext(PushDeviceContextUpdateRequest request) {
    return _repository.updatePushDeviceContext(request);
  }

  Future<void> deletePushDevice(String deviceId) {
    return _repository.deletePushDevice(deviceId);
  }

  Future<void> deleteAccount() {
    return _repository.deleteAccount();
  }

  Future<ThemeMode?> syncThemeModePreference(ThemeMode mode) async {
    final currentProfile = state.profile;
    final nextProfile = _preferencesService.optimisticThemeProfile(
      currentProfile,
      mode,
    );
    if (nextProfile != null) {
      applyProfile(nextProfile);
      await _persistAuthSession(nextProfile);
    }
    if (ref.read(authControllerProvider).session == null) {
      return deserializeThemeModePreference(
        nextProfile?.preferences?.themeMode,
      );
    }
    try {
      final updatedProfile = await syncPreferences(
        UserPreferencesPatch(themeMode: serializeThemeModePreference(mode)),
      );
      await _persistAuthSession(updatedProfile);
      return deserializeThemeModePreference(
        updatedProfile.preferences?.themeMode,
      );
    } catch (_) {
      return deserializeThemeModePreference(
        nextProfile?.preferences?.themeMode,
      );
    }
  }

  Future<void> syncLocaleCodePreference(String localeCode) async {
    final normalized = normalizeLingLocaleCode(localeCode);
    final nextProfile = _preferencesService.optimisticLocaleProfile(
      state.profile,
      normalized,
    );
    updateLocaleCode(normalized);
    await _preferencesService.persistLocaleCode(normalized);
    if (nextProfile != null) {
      applyProfile(nextProfile);
      await _persistAuthSession(nextProfile);
    }
    if (ref.read(authControllerProvider).session == null) {
      return;
    }
    try {
      final updatedProfile = await syncPreferences(
        UserPreferencesPatch(locale: normalized),
      );
      applyProfile(updatedProfile);
      await _persistAuthSession(updatedProfile);
    } catch (_) {
      // Keep optimistic locale update.
    }
  }

  Future<DeviceContextSnapshot?> refreshDeviceContext({
    bool startTracking = false,
    void Function(String timezone)? onTimezoneChanged,
  }) async {
    return _deviceSyncService.refreshDeviceContext(
      startTracking: startTracking,
      onTimezoneChanged: (timezone) {
        updateTimezone(timezone);
        onTimezoneChanged?.call(timezone);
      },
    );
  }

  Future<DeviceTimezoneSyncResult> syncDeviceTimezoneIfNeeded({
    DeviceContextSnapshot? deviceContext,
  }) async {
    return _deviceSyncService.syncDeviceTimezoneIfNeeded(
      isAuthenticated: ref.read(authControllerProvider).session != null,
      currentProfile: state.profile,
      syncPreferences: syncPreferences,
      persistAuthSession: _persistAuthSession,
      resolveDeviceContext: refreshDeviceContext,
      deviceContext: deviceContext,
    );
  }

  Future<CalendarNotificationPermissionState>
  prepareCalendarNotificationPermission({
    bool requestIfNeeded = false,
    LingStrings? strings,
    bool syncBackend = true,
  }) async {
    final current = await _calendarNotificationBridge.getPermissionState();
    final permission =
        requestIfNeeded &&
            current == CalendarNotificationPermissionState.notDetermined
        ? await _calendarNotificationBridge.requestPermission()
        : current;
    setCalendarNotificationPermission(permission);
    if (syncBackend &&
        ref.read(authControllerProvider).session != null &&
        strings != null) {
      await syncRemotePushDeviceRegistration(
        notificationsEnabled:
            permission == CalendarNotificationPermissionState.granted,
      );
    }
    return permission;
  }

  Future<Map<String, dynamic>> syncDevicePermissionStates({
    DeviceContextSnapshot? deviceContext,
  }) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) {
      return const <String, dynamic>{};
    }
    final deviceId =
        (session.deviceId ?? await _pushDeviceIdStore.getOrCreate()).trim();
    final updatedAt = DateTime.now().toUtc().toIso8601String();
    final notificationPermission = await _calendarNotificationBridge
        .getPermissionState();
    setCalendarNotificationPermission(notificationPermission);

    final locationPermission = await _deviceContextBridge
        .getLocationPermissionState();
    setLocationPermission(locationPermission);
    final microphonePermission = await _speechRecognitionBridge
        .getAuthorizationState();
    setMicrophonePermission(microphonePermission);
    final photoLibraryPermission = await _photoLibraryPermissionBridge
        .getPermissionState();
    setPhotoLibraryPermission(photoLibraryPermission);
    final applePermission = await ref
        .read(appleCalendarBridgeProvider)
        .getPermissionState();
    final payload = <String, dynamic>{
      'notifications': _devicePermissionPayload(
        state: serializeCalendarNotificationPermissionState(
          notificationPermission,
        ),
        deviceId: deviceId,
        updatedAt: updatedAt,
      ),
      'location': _devicePermissionPayload(
        state: serializeDeviceLocationPermissionState(locationPermission),
        deviceId: deviceId,
        updatedAt: updatedAt,
      ),
      'microphone': _devicePermissionPayload(
        state: serializeSpeechAuthorizationState(microphonePermission),
        deviceId: deviceId,
        updatedAt: updatedAt,
      ),
      'photo_library': _devicePermissionPayload(
        state: serializePhotoLibraryPermissionState(photoLibraryPermission),
        deviceId: deviceId,
        updatedAt: updatedAt,
      ),
      'apple_calendar': _devicePermissionPayload(
        state: serializeAppleCalendarPermissionState(applePermission),
        deviceId: deviceId,
        updatedAt: updatedAt,
      ),
    };
    final notificationsEnabled =
        notificationPermission == CalendarNotificationPermissionState.granted;
    final permissionPayloadChanged =
        !_devicePermissionPayloadMatchesCurrentState(
          persisted: state.profile?.preferences?.devicePermissions,
          current: payload,
        );
    var registeredDuringPermissionSync = false;
    if (permissionPayloadChanged) {
      try {
        final updatedProfile = await syncPreferences(
          UserPreferencesPatch(devicePermissions: payload),
        );
        await _persistAuthSession(updatedProfile);
      } catch (_) {
        // Permission state sync should not block the current user flow.
      }
      final syncResult = await syncRemotePushDeviceRegistration(
        deviceContext: deviceContext,
        notificationsEnabled: notificationsEnabled,
      );
      registeredDuringPermissionSync = syncResult.registered;
    }
    if (_shouldSyncLocationContext(
      permission: locationPermission,
      deviceContext: deviceContext,
    )) {
      await syncDeviceContextToBackend(
        deviceContext: deviceContext,
        registerDeviceIfNeeded: !registeredDuringPermissionSync,
        notificationsEnabled: notificationsEnabled,
      );
    }
    return payload;
  }

  bool _shouldSyncLocationContext({
    required DeviceLocationPermissionState permission,
    required DeviceContextSnapshot? deviceContext,
  }) {
    if (permission != DeviceLocationPermissionState.authorizedAlways &&
        permission != DeviceLocationPermissionState.authorizedWhenInUse) {
      return false;
    }
    return (deviceContext?.formattedAddress?.trim().isNotEmpty ?? false) ||
        (deviceContext?.name?.trim().isNotEmpty ?? false) ||
        (deviceContext?.thoroughfare?.trim().isNotEmpty ?? false) ||
        (deviceContext?.subThoroughfare?.trim().isNotEmpty ?? false) ||
        (deviceContext?.subLocality?.trim().isNotEmpty ?? false) ||
        (deviceContext?.locality?.trim().isNotEmpty ?? false) ||
        (deviceContext?.subAdministrativeArea?.trim().isNotEmpty ?? false) ||
        (deviceContext?.city?.trim().isNotEmpty ?? false) ||
        (deviceContext?.administrativeArea?.trim().isNotEmpty ?? false) ||
        (deviceContext?.postalCode?.trim().isNotEmpty ?? false) ||
        (deviceContext?.country?.trim().isNotEmpty ?? false) ||
        (deviceContext?.isoCountryCode?.trim().isNotEmpty ?? false) ||
        (deviceContext?.areasOfInterest?.isNotEmpty ?? false) ||
        (deviceContext?.latitude != null && deviceContext?.longitude != null);
  }

  bool _devicePermissionPayloadMatchesCurrentState({
    required Map<String, dynamic>? persisted,
    required Map<String, dynamic> current,
  }) {
    if (persisted == null) {
      return false;
    }
    for (final entry in current.entries) {
      final currentValue = entry.value;
      final persistedValue = persisted[entry.key];
      if (currentValue is! Map || persistedValue is! Map) {
        return false;
      }
      if (!_devicePermissionEntryMatchesCurrentState(
        persisted: persistedValue,
        current: currentValue,
      )) {
        return false;
      }
    }
    return true;
  }

  bool _devicePermissionEntryMatchesCurrentState({
    required Map<dynamic, dynamic> persisted,
    required Map<dynamic, dynamic> current,
  }) {
    const stableFields = <String>['state', 'source', 'platform', 'device_id'];
    for (final field in stableFields) {
      if ('${persisted[field] ?? ''}' != '${current[field] ?? ''}') {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> _devicePermissionPayload({
    required String state,
    required String deviceId,
    required String updatedAt,
  }) {
    return <String, dynamic>{
      'state': state,
      'source': 'system',
      'platform': AppPlatformInfo.current.name,
      'device_id': deviceId,
      'updated_at': updatedAt,
    };
  }

  Future<void> openCalendarNotificationSystemSettings() {
    return _calendarNotificationBridge.openSystemSettings();
  }

  Future<void> persistCalendarNotificationSettings(
    CalendarNotificationSettings next, {
    required LingStrings strings,
  }) async {
    final previousSettings = state.calendarNotificationSettings;
    final previousProfile = state.profile;
    final nextProfile = profileWithCalendarNotificationSettings(
      state.profile,
      next,
    );
    state = state.copyWith(calendarNotificationSettings: next);
    if (nextProfile != null) {
      applyProfile(nextProfile);
    }
    try {
      if (ref.read(authControllerProvider).session != null) {
        final updatedProfile = await syncPreferences(
          UserPreferencesPatch(calendarNotifications: next.toJson()),
        );
        await _persistAuthSession(updatedProfile);
      }
      if (next.enabled &&
          state.calendarNotificationPermission ==
              CalendarNotificationPermissionState.notDetermined) {
        await prepareCalendarNotificationPermission(
          requestIfNeeded: true,
          strings: strings,
          syncBackend: false,
        );
      }
    } catch (error) {
      state = state.copyWith(calendarNotificationSettings: previousSettings);
      if (previousProfile != null) {
        applyProfile(previousProfile);
      }
      rethrow;
    }
  }

  Future<void> persistCalendarSyncSettings(CalendarSyncSettings next) async {
    final previousSettings = state.calendarSyncSettings;
    final previousProfile = state.profile;
    final nextProfile = profileWithCalendarSyncSettings(state.profile, next);
    state = state.copyWith(calendarSyncSettings: next);
    if (nextProfile != null) {
      applyProfile(nextProfile);
    }
    try {
      if (ref.read(authControllerProvider).session != null) {
        final updatedProfile = await syncPreferences(
          UserPreferencesPatch(calendarSync: next.toJson()),
        );
        await _persistAuthSession(updatedProfile);
      }
    } catch (_) {
      state = state.copyWith(calendarSyncSettings: previousSettings);
      if (previousProfile != null) {
        applyProfile(previousProfile);
      }
      rethrow;
    }
  }

  void restoreCalendarNotificationSettings({
    required CalendarNotificationSettings settings,
    UserProfile? profile,
  }) {
    state = state.copyWith(calendarNotificationSettings: settings);
    if (profile != null) {
      applyProfile(profile);
    }
  }

  Future<PushDeviceSyncResult> syncRemotePushDeviceRegistration({
    DeviceContextSnapshot? deviceContext,
    bool includeLocationData = false,
    RemoteNotificationRegistration? registration,
    String? deviceId,
    bool notificationsEnabled = true,
  }) async {
    final sessionDeviceId = ref.read(authControllerProvider).session?.deviceId;
    return _deviceSyncService.syncRemotePushDeviceRegistration(
      isAuthenticated: ref.read(authControllerProvider).session != null,
      locale: state.localeCode,
      fallbackTimezone: state.timezone,
      resolveDeviceContext: refreshDeviceContext,
      deviceContext: deviceContext,
      includeLocationData: includeLocationData,
      registration: registration,
      deviceId: deviceId ?? sessionDeviceId,
      notificationsEnabled: notificationsEnabled,
    );
  }

  Future<bool> syncDeviceContextToBackend({
    bool startTracking = false,
    Duration? locationRefreshIfOlderThan,
    DeviceContextSnapshot? deviceContext,
    RemoteNotificationRegistration? registration,
    String? deviceId,
    bool registerDeviceIfNeeded = true,
    bool notificationsEnabled = true,
  }) async {
    final sessionDeviceId = ref.read(authControllerProvider).session?.deviceId;
    return _deviceSyncService.syncDeviceContextToBackend(
      isAuthenticated: ref.read(authControllerProvider).session != null,
      locale: state.localeCode,
      fallbackTimezone: state.timezone,
      resolveDeviceContext: ({bool startTracking = false}) =>
          refreshDeviceContext(startTracking: startTracking),
      startTracking: startTracking,
      locationRefreshIfOlderThan: locationRefreshIfOlderThan,
      deviceContext: deviceContext,
      registration: registration,
      deviceId: deviceId ?? sessionDeviceId,
      registerDeviceIfNeeded: registerDeviceIfNeeded,
      notificationsEnabled: notificationsEnabled,
    );
  }

  Future<void> bootstrapAuthenticatedDeviceState({
    bool startTracking = false,
  }) async {
    await _deviceSyncService.bootstrapAuthenticatedDeviceState(
      isAuthenticated: ref.read(authControllerProvider).session != null,
      onPermissionResolved: setCalendarNotificationPermission,
      refreshDeviceContext: ({bool startTracking = false}) =>
          refreshDeviceContext(startTracking: startTracking),
      registerDevice:
          ({
            required deviceContext,
            required includeLocationData,
            required registration,
            required deviceId,
            required notificationsEnabled,
          }) => syncRemotePushDeviceRegistration(
            deviceContext: deviceContext,
            includeLocationData: includeLocationData,
            registration: registration,
            deviceId: deviceId,
            notificationsEnabled: notificationsEnabled,
          ),
      startTracking: startTracking,
    );
  }

  Future<SettingsBootstrapResult> bootstrapAuthenticatedSession({
    required UserProfile sessionProfile,
    bool allowFallbackProfile = true,
    LingStrings? strings,
  }) async {
    UserProfile? resolvedProfile;
    try {
      resolvedProfile = await refreshProfile();
    } catch (_) {
      if (!allowFallbackProfile) {
        rethrow;
      }
      resolvedProfile = sessionProfile;
      applyProfile(sessionProfile);
    }
    await _persistAuthSession(resolvedProfile);
    if (strings != null) {
      await prepareCalendarNotificationPermission(
        strings: strings,
        syncBackend: false,
      );
    }
    return SettingsBootstrapResult(
      preferredTheme: deserializeThemeModePreference(
        resolvedProfile.preferences?.themeMode,
      ),
    );
  }

  Future<ThemeMode?> applyAccountBundle(AccountBundle bundle) async {
    applyProfile(bundle.profile);
    await ref.read(authControllerProvider.notifier).updateAccountBundle(bundle);
    return deserializeThemeModePreference(
      bundle.profile.preferences?.themeMode,
    );
  }

  Future<void> signOutAuthenticatedSession() async {
    clear();
    await ref.read(authControllerProvider.notifier).signOut();
  }

  Future<void> deleteAuthenticatedAccount() async {
    await deleteAccount();
    clear();
    await ref.read(authControllerProvider.notifier).signOut();
  }

  void clear() {
    state = SettingsState(
      localeCode: state.localeCode,
      timezone: state.timezone,
    );
  }

  Future<void> _persistAuthSession(UserProfile profile) {
    return ref.read(authControllerProvider.notifier).updateProfile(profile);
  }

  Future<ChallengeResult> _requestBindingChallenge({
    required bool isPhone,
    required String recipient,
    required Future<ChallengeResult> Function() loader,
  }) async {
    _updateBindingState(
      isPhone: isPhone,
      value: bindingStateForPhone(isPhone).copyWith(isSendingCode: true),
    );
    try {
      final data = await loader();
      final now = DateTime.now();
      final resendSeconds = data.resendAfterSeconds ?? 30;
      final normalizedRecipient = isPhone
          ? recipient
          : (data.email ?? recipient).trim().toLowerCase();
      _updateBindingState(
        isPhone: isPhone,
        value: isPhone
            ? bindingStateForPhone(isPhone).copyWith(
                challengeId: data.challengeId,
                pendingRecipient: normalizedRecipient,
                expireAt: _parseServerDateTime(data.expireAt),
                resendAvailableAt: now.add(Duration(seconds: resendSeconds)),
                isSendingCode: false,
              )
            : bindingStateForPhone(isPhone).copyWith(
                emailCodeRequested: true,
                pendingRecipient: normalizedRecipient,
                expireAt: _parseServerDateTime(data.expireAt),
                resendAvailableAt: now.add(Duration(seconds: resendSeconds)),
                isSendingCode: false,
              ),
      );
      return data;
    } catch (_) {
      _updateBindingState(
        isPhone: isPhone,
        value: bindingStateForPhone(isPhone).copyWith(isSendingCode: false),
      );
      rethrow;
    }
  }

  Future<AccountBundle> _bind({
    required bool isPhone,
    required Future<AccountBundle> Function() loader,
  }) async {
    _updateBindingState(
      isPhone: isPhone,
      value: bindingStateForPhone(isPhone).copyWith(isBinding: true),
    );
    try {
      final bundle = await loader();
      applyProfile(bundle.profile);
      await ref
          .read(authControllerProvider.notifier)
          .updateAccountBundle(bundle);
      _updateBindingState(
        isPhone: isPhone,
        value: const SettingsBindingState(),
      );
      return bundle;
    } catch (_) {
      _updateBindingState(
        isPhone: isPhone,
        value: bindingStateForPhone(isPhone).copyWith(isBinding: false),
      );
      rethrow;
    }
  }

  void _updateBindingState({
    required bool isPhone,
    required SettingsBindingState value,
  }) {
    state = state.copyWith(
      phoneBinding: isPhone ? value : state.phoneBinding,
      emailBinding: isPhone ? state.emailBinding : value,
    );
  }

  DateTime? _parseServerDateTime(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
