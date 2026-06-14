import 'package:json_annotation/json_annotation.dart';

part 'user_models.g.dart';

@JsonSerializable(explicitToJson: true)
class UserPreferences {
  const UserPreferences({
    this.timezone,
    this.locale,
    this.themeMode,
    this.voiceInputEnabled,
    this.preferredInputMode,
    this.defaultCalendarProvider,
    this.calendarSync,
    this.calendarNotifications,
    this.devicePermissions,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  final String? timezone;
  final String? locale;
  @JsonKey(name: 'theme_mode')
  final String? themeMode;
  @JsonKey(name: 'voice_input_enabled')
  final bool? voiceInputEnabled;
  @JsonKey(name: 'preferred_input_mode')
  final String? preferredInputMode;
  @JsonKey(name: 'default_calendar_provider')
  final String? defaultCalendarProvider;
  @JsonKey(name: 'calendar_sync')
  final Map<String, dynamic>? calendarSync;
  @JsonKey(name: 'calendar_notifications')
  final Map<String, dynamic>? calendarNotifications;
  @JsonKey(name: 'device_permissions')
  final Map<String, dynamic>? devicePermissions;
  @JsonKey(name: 'quiet_hours_start')
  final String? quietHoursStart;
  @JsonKey(name: 'quiet_hours_end')
  final String? quietHoursEnd;

  UserPreferences copyWith({
    String? timezone,
    String? locale,
    String? themeMode,
    bool? voiceInputEnabled,
    String? preferredInputMode,
    String? defaultCalendarProvider,
    Map<String, dynamic>? calendarSync,
    Map<String, dynamic>? calendarNotifications,
    Map<String, dynamic>? devicePermissions,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) {
    return UserPreferences(
      timezone: timezone ?? this.timezone,
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      voiceInputEnabled: voiceInputEnabled ?? this.voiceInputEnabled,
      preferredInputMode: preferredInputMode ?? this.preferredInputMode,
      defaultCalendarProvider:
          defaultCalendarProvider ?? this.defaultCalendarProvider,
      calendarSync: calendarSync ?? this.calendarSync,
      calendarNotifications:
          calendarNotifications ?? this.calendarNotifications,
      devicePermissions: devicePermissions ?? this.devicePermissions,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      _$UserPreferencesFromJson(json);

  Map<String, dynamic> toJson() => _$UserPreferencesToJson(this);
}

class UserPreferencesPatch {
  const UserPreferencesPatch({
    this.timezone,
    this.locale,
    this.themeMode,
    this.voiceInputEnabled,
    this.preferredInputMode,
    this.defaultCalendarProvider,
    this.calendarSync,
    this.calendarNotifications,
    this.devicePermissions,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  final String? timezone;
  final String? locale;
  final String? themeMode;
  final bool? voiceInputEnabled;
  final String? preferredInputMode;
  final String? defaultCalendarProvider;
  final Map<String, dynamic>? calendarSync;
  final Map<String, dynamic>? calendarNotifications;
  final Map<String, dynamic>? devicePermissions;
  final String? quietHoursStart;
  final String? quietHoursEnd;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (timezone != null) 'timezone': timezone,
      if (locale != null) 'locale': locale,
      if (themeMode != null) 'theme_mode': themeMode,
      if (voiceInputEnabled != null) 'voice_input_enabled': voiceInputEnabled,
      if (preferredInputMode != null)
        'preferred_input_mode': preferredInputMode,
      if (defaultCalendarProvider != null)
        'default_calendar_provider': defaultCalendarProvider,
      if (calendarSync != null) 'calendar_sync': calendarSync,
      if (calendarNotifications != null)
        'calendar_notifications': calendarNotifications,
      if (devicePermissions != null) 'device_permissions': devicePermissions,
      if (quietHoursStart != null) 'quiet_hours_start': quietHoursStart,
      if (quietHoursEnd != null) 'quiet_hours_end': quietHoursEnd,
    };
  }
}

@JsonSerializable(explicitToJson: true)
class UserProfile {
  const UserProfile({
    required this.userId,
    this.username,
    this.nickname,
    this.email,
    this.phoneNumber,
    this.phoneAreaCode,
    this.role,
    this.avatarUrl,
    this.preferences,
  });

  @JsonKey(name: 'user_id')
  final String userId;
  final String? username;
  final String? nickname;
  final String? email;
  @JsonKey(name: 'phonenum')
  final String? phoneNumber;
  @JsonKey(name: 'phone_area_code')
  final String? phoneAreaCode;
  final String? role;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  final UserPreferences? preferences;

  String? get primaryContact {
    final phone = (phoneNumber ?? '').trim();
    if (phone.isNotEmpty) {
      return phone;
    }
    final value = (email ?? '').trim();
    return value.isEmpty ? null : value;
  }

  UserProfile copyWith({
    String? userId,
    String? username,
    String? nickname,
    String? email,
    String? phoneNumber,
    String? phoneAreaCode,
    String? role,
    String? avatarUrl,
    UserPreferences? preferences,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneAreaCode: phoneAreaCode ?? this.phoneAreaCode,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      preferences: preferences ?? this.preferences,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}

@JsonSerializable()
class UserIdentity {
  const UserIdentity({
    required this.identityId,
    required this.userId,
    required this.providerId,
    this.providerSubject,
    this.providerUsername,
    this.providerEmail,
    this.profile,
  });

  @JsonKey(name: 'identity_id')
  final String identityId;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'provider_id')
  final String providerId;
  @JsonKey(name: 'provider_subject')
  final String? providerSubject;
  @JsonKey(name: 'provider_username')
  final String? providerUsername;
  @JsonKey(name: 'provider_email')
  final String? providerEmail;
  final Map<String, dynamic>? profile;

  factory UserIdentity.fromJson(Map<String, dynamic> json) =>
      _$UserIdentityFromJson(json);

  Map<String, dynamic> toJson() => _$UserIdentityToJson(this);
}

@JsonSerializable()
class ChallengeResult {
  const ChallengeResult({
    this.challengeId,
    this.email,
    this.expireAt,
    this.resendAfterSeconds,
    this.providerId,
    this.grantType,
  });

  @JsonKey(name: 'challenge_id')
  final String? challengeId;
  final String? email;
  @JsonKey(name: 'expire_at')
  final String? expireAt;
  @JsonKey(name: 'resend_after_seconds')
  final int? resendAfterSeconds;
  @JsonKey(name: 'provider_id')
  final String? providerId;
  @JsonKey(name: 'grant_type')
  final String? grantType;

  factory ChallengeResult.fromJson(Map<String, dynamic> json) =>
      _$ChallengeResultFromJson(json);

  Map<String, dynamic> toJson() => _$ChallengeResultToJson(this);
}

@JsonSerializable(explicitToJson: true)
class AccountBundle {
  const AccountBundle({required this.profile, required this.identities});

  final UserProfile profile;
  final List<UserIdentity> identities;

  factory AccountBundle.fromJson(Map<String, dynamic> json) =>
      _$AccountBundleFromJson(json);

  Map<String, dynamic> toJson() => _$AccountBundleToJson(this);
}

@JsonSerializable(explicitToJson: true)
class AuthBundle {
  const AuthBundle({
    required this.accessToken,
    required this.refreshToken,
    required this.profile,
    required this.identities,
    this.deviceId,
    this.isNewUser = false,
    this.phoneAuth,
  });

  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'refresh_token')
  final String refreshToken;
  @JsonKey(name: 'device_id')
  final String? deviceId;
  @JsonKey(name: 'user')
  final UserProfile profile;
  final List<UserIdentity> identities;
  @JsonKey(name: 'is_new_user')
  final bool isNewUser;
  @JsonKey(name: 'phone_auth')
  final Map<String, dynamic>? phoneAuth;

  factory AuthBundle.fromJson(Map<String, dynamic> json) =>
      _$AuthBundleFromJson(json);

  Map<String, dynamic> toJson() => _$AuthBundleToJson(this);
}
