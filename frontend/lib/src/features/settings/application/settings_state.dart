import 'package:flutter/material.dart';
import 'package:ling/src/core/platform/models/notification_models.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/chat/data/apple_speech_recognition_bridge.dart';
import 'package:ling/src/features/settings/data/bridges/photo_library_permission_bridge.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';
import 'package:ling/src/shared/models/font_size_preference.dart';

class SettingsBootstrapResult {
  const SettingsBootstrapResult({this.preferredTheme});

  final ThemeMode? preferredTheme;
}

class PushDeviceSyncResult {
  const PushDeviceSyncResult({
    required this.registered,
    required this.locationSeeded,
  });

  final bool registered;
  final bool locationSeeded;
}

class DeviceTimezoneSyncResult {
  const DeviceTimezoneSyncResult({
    required this.didChange,
    required this.pendingRetry,
  });

  final bool didChange;
  final bool pendingRetry;
}

class SettingsBindingState {
  const SettingsBindingState({
    this.challengeId,
    this.pendingRecipient,
    this.expireAt,
    this.resendAvailableAt,
    this.emailCodeRequested = false,
    this.isSendingCode = false,
    this.isBinding = false,
  });

  final String? challengeId;
  final String? pendingRecipient;
  final DateTime? expireAt;
  final DateTime? resendAvailableAt;
  final bool emailCodeRequested;
  final bool isSendingCode;
  final bool isBinding;

  bool get hasPendingVerification =>
      (challengeId?.trim().isNotEmpty ?? false) || emailCodeRequested;

  bool get isExpired {
    final expires = expireAt;
    return expires != null && !DateTime.now().isBefore(expires);
  }

  SettingsBindingState copyWith({
    String? challengeId,
    bool clearChallengeId = false,
    String? pendingRecipient,
    bool clearPendingRecipient = false,
    DateTime? expireAt,
    bool clearExpireAt = false,
    DateTime? resendAvailableAt,
    bool clearResendAvailableAt = false,
    bool? emailCodeRequested,
    bool? isSendingCode,
    bool? isBinding,
  }) {
    return SettingsBindingState(
      challengeId: clearChallengeId ? null : (challengeId ?? this.challengeId),
      pendingRecipient: clearPendingRecipient
          ? null
          : (pendingRecipient ?? this.pendingRecipient),
      expireAt: clearExpireAt ? null : (expireAt ?? this.expireAt),
      resendAvailableAt: clearResendAvailableAt
          ? null
          : (resendAvailableAt ?? this.resendAvailableAt),
      emailCodeRequested: emailCodeRequested ?? this.emailCodeRequested,
      isSendingCode: isSendingCode ?? this.isSendingCode,
      isBinding: isBinding ?? this.isBinding,
    );
  }
}

class SettingsState {
  const SettingsState({
    this.profile,
    this.localeCode = 'zh-CN',
    this.timezone = 'UTC',
    this.fontSizeLevel = LingFontSizeLevel.fallback,
    this.calendarNotificationPermission =
        CalendarNotificationPermissionState.notDetermined,
    DeviceLocationPermissionState? locationPermission,
    SpeechAuthorizationState? microphonePermission,
    PhotoLibraryPermissionState? photoLibraryPermission,
    this.calendarNotificationSettings = const CalendarNotificationSettings(),
    this.calendarSyncSettings = const CalendarSyncSettings(),
    this.phoneBinding = const SettingsBindingState(),
    this.emailBinding = const SettingsBindingState(),
    this.localImageCacheBytes,
    this.isClearingLocalImageCache = false,
  }) : _locationPermission = locationPermission,
       _microphonePermission = microphonePermission,
       _photoLibraryPermission = photoLibraryPermission;

  final UserProfile? profile;
  final String localeCode;
  final String timezone;
  final LingFontSizeLevel fontSizeLevel;
  final CalendarNotificationPermissionState calendarNotificationPermission;
  final DeviceLocationPermissionState? _locationPermission;
  final SpeechAuthorizationState? _microphonePermission;
  final PhotoLibraryPermissionState? _photoLibraryPermission;
  final CalendarNotificationSettings calendarNotificationSettings;
  final CalendarSyncSettings calendarSyncSettings;
  final SettingsBindingState phoneBinding;
  final SettingsBindingState emailBinding;
  final int? localImageCacheBytes;
  final bool isClearingLocalImageCache;

  DeviceLocationPermissionState get locationPermission =>
      _locationPermission ?? DeviceLocationPermissionState.unknown;
  SpeechAuthorizationState get microphonePermission =>
      _microphonePermission ?? SpeechAuthorizationState.unknown;
  PhotoLibraryPermissionState get photoLibraryPermission =>
      _photoLibraryPermission ?? PhotoLibraryPermissionState.unknown;

  SettingsState copyWith({
    UserProfile? profile,
    bool clearProfile = false,
    String? localeCode,
    String? timezone,
    LingFontSizeLevel? fontSizeLevel,
    CalendarNotificationPermissionState? calendarNotificationPermission,
    DeviceLocationPermissionState? locationPermission,
    SpeechAuthorizationState? microphonePermission,
    PhotoLibraryPermissionState? photoLibraryPermission,
    CalendarNotificationSettings? calendarNotificationSettings,
    CalendarSyncSettings? calendarSyncSettings,
    SettingsBindingState? phoneBinding,
    SettingsBindingState? emailBinding,
    int? localImageCacheBytes,
    bool clearLocalImageCacheBytes = false,
    bool? isClearingLocalImageCache,
  }) {
    return SettingsState(
      profile: clearProfile ? null : (profile ?? this.profile),
      localeCode: localeCode ?? this.localeCode,
      timezone: timezone ?? this.timezone,
      fontSizeLevel: fontSizeLevel ?? this.fontSizeLevel,
      calendarNotificationPermission:
          calendarNotificationPermission ?? this.calendarNotificationPermission,
      locationPermission: locationPermission ?? this.locationPermission,
      microphonePermission: microphonePermission ?? this.microphonePermission,
      photoLibraryPermission:
          photoLibraryPermission ?? this.photoLibraryPermission,
      calendarNotificationSettings:
          calendarNotificationSettings ?? this.calendarNotificationSettings,
      calendarSyncSettings: calendarSyncSettings ?? this.calendarSyncSettings,
      phoneBinding: phoneBinding ?? this.phoneBinding,
      emailBinding: emailBinding ?? this.emailBinding,
      localImageCacheBytes: clearLocalImageCacheBytes
          ? null
          : (localImageCacheBytes ?? this.localImageCacheBytes),
      isClearingLocalImageCache:
          isClearingLocalImageCache ?? this.isClearingLocalImageCache,
    );
  }
}
