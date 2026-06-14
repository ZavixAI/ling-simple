import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/phone_country.dart';

UserIdentity? settingsIdentityForProvider(
  Iterable<UserIdentity> identities,
  String providerId,
) {
  for (final identity in identities) {
    if (identity.providerId == providerId) {
      return identity;
    }
  }
  return null;
}

String settingsIdentitySubtitle(LingStrings strings, UserIdentity? identity) {
  if (identity == null) {
    return strings.unboundStatus;
  }
  final providerEmail = (identity.providerEmail ?? '').trim();
  if (providerEmail.isNotEmpty) {
    return providerEmail;
  }
  final providerUsername = (identity.providerUsername ?? '').trim();
  if (providerUsername.isNotEmpty) {
    return providerUsername;
  }
  final profile = identity.profile ?? const <String, dynamic>{};
  final nickname = '${profile['nickname'] ?? ''}'.trim();
  if (nickname.isNotEmpty) {
    return nickname;
  }
  final email = '${profile['email'] ?? ''}'.trim();
  if (email.isNotEmpty) {
    return email;
  }
  return strings.boundStatus;
}

PhoneCountry settingsInitialPhoneCountry({
  required PhoneCountry fallbackCountry,
  required String? areaCode,
}) {
  final normalizedAreaCode = (areaCode ?? '').trim();
  if (normalizedAreaCode.isEmpty) {
    return fallbackCountry;
  }
  for (final country in phoneCountries) {
    if (country.dialCode == normalizedAreaCode) {
      return country;
    }
  }
  return fallbackCountry;
}
