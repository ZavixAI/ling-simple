// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserPreferences _$UserPreferencesFromJson(Map<String, dynamic> json) =>
    UserPreferences(
      timezone: json['timezone'] as String?,
      locale: json['locale'] as String?,
      themeMode: json['theme_mode'] as String?,
      voiceInputEnabled: json['voice_input_enabled'] as bool?,
      preferredInputMode: json['preferred_input_mode'] as String?,
      defaultCalendarProvider: json['default_calendar_provider'] as String?,
      calendarSync: json['calendar_sync'] as Map<String, dynamic>?,
      calendarNotifications:
          json['calendar_notifications'] as Map<String, dynamic>?,
      devicePermissions: json['device_permissions'] as Map<String, dynamic>?,
      quietHoursStart: json['quiet_hours_start'] as String?,
      quietHoursEnd: json['quiet_hours_end'] as String?,
    );

Map<String, dynamic> _$UserPreferencesToJson(UserPreferences instance) =>
    <String, dynamic>{
      'timezone': instance.timezone,
      'locale': instance.locale,
      'theme_mode': instance.themeMode,
      'voice_input_enabled': instance.voiceInputEnabled,
      'preferred_input_mode': instance.preferredInputMode,
      'default_calendar_provider': instance.defaultCalendarProvider,
      'calendar_sync': instance.calendarSync,
      'calendar_notifications': instance.calendarNotifications,
      'device_permissions': instance.devicePermissions,
      'quiet_hours_start': instance.quietHoursStart,
      'quiet_hours_end': instance.quietHoursEnd,
    };

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  userId: json['user_id'] as String,
  username: json['username'] as String?,
  nickname: json['nickname'] as String?,
  email: json['email'] as String?,
  phoneNumber: json['phonenum'] as String?,
  phoneAreaCode: json['phone_area_code'] as String?,
  role: json['role'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  preferences: json['preferences'] == null
      ? null
      : UserPreferences.fromJson(json['preferences'] as Map<String, dynamic>),
);

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'username': instance.username,
      'nickname': instance.nickname,
      'email': instance.email,
      'phonenum': instance.phoneNumber,
      'phone_area_code': instance.phoneAreaCode,
      'role': instance.role,
      'avatar_url': instance.avatarUrl,
      'preferences': instance.preferences?.toJson(),
    };

UserIdentity _$UserIdentityFromJson(Map<String, dynamic> json) => UserIdentity(
  identityId: json['identity_id'] as String,
  userId: json['user_id'] as String,
  providerId: json['provider_id'] as String,
  providerSubject: json['provider_subject'] as String?,
  providerUsername: json['provider_username'] as String?,
  providerEmail: json['provider_email'] as String?,
  profile: json['profile'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$UserIdentityToJson(UserIdentity instance) =>
    <String, dynamic>{
      'identity_id': instance.identityId,
      'user_id': instance.userId,
      'provider_id': instance.providerId,
      'provider_subject': instance.providerSubject,
      'provider_username': instance.providerUsername,
      'provider_email': instance.providerEmail,
      'profile': instance.profile,
    };

ChallengeResult _$ChallengeResultFromJson(Map<String, dynamic> json) =>
    ChallengeResult(
      challengeId: json['challenge_id'] as String?,
      email: json['email'] as String?,
      expireAt: json['expire_at'] as String?,
      resendAfterSeconds: (json['resend_after_seconds'] as num?)?.toInt(),
      providerId: json['provider_id'] as String?,
      grantType: json['grant_type'] as String?,
    );

Map<String, dynamic> _$ChallengeResultToJson(ChallengeResult instance) =>
    <String, dynamic>{
      'challenge_id': instance.challengeId,
      'email': instance.email,
      'expire_at': instance.expireAt,
      'resend_after_seconds': instance.resendAfterSeconds,
      'provider_id': instance.providerId,
      'grant_type': instance.grantType,
    };

AccountBundle _$AccountBundleFromJson(Map<String, dynamic> json) =>
    AccountBundle(
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      identities: (json['identities'] as List<dynamic>)
          .map((e) => UserIdentity.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AccountBundleToJson(AccountBundle instance) =>
    <String, dynamic>{
      'profile': instance.profile.toJson(),
      'identities': instance.identities.map((e) => e.toJson()).toList(),
    };

AuthBundle _$AuthBundleFromJson(Map<String, dynamic> json) => AuthBundle(
  accessToken: json['access_token'] as String,
  refreshToken: json['refresh_token'] as String,
  profile: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
  identities: (json['identities'] as List<dynamic>)
      .map((e) => UserIdentity.fromJson(e as Map<String, dynamic>))
      .toList(),
  deviceId: json['device_id'] as String?,
  isNewUser: json['is_new_user'] as bool? ?? false,
  phoneAuth: json['phone_auth'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$AuthBundleToJson(AuthBundle instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'refresh_token': instance.refreshToken,
      'device_id': instance.deviceId,
      'user': instance.profile.toJson(),
      'identities': instance.identities.map((e) => e.toJson()).toList(),
      'is_new_user': instance.isNewUser,
      'phone_auth': instance.phoneAuth,
    };
