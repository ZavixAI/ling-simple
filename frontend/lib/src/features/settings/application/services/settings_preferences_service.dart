import 'package:flutter/material.dart';
import 'package:ling/src/core/storage/preferences_store.dart';
import 'package:ling/src/features/auth/data/repositories/profile_repository.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/shared/i18n/ling_locale.dart';
import 'package:ling/src/shared/models/font_size_preference.dart';
import 'package:ling/src/shared/models/preferred_input_mode.dart';

class SettingsPreferencesService {
  const SettingsPreferencesService({
    required PreferencesStore preferencesStore,
    required ProfileRepository repository,
  }) : _preferencesStore = preferencesStore,
       _repository = repository;

  final PreferencesStore _preferencesStore;
  final ProfileRepository _repository;

  Future<void> persistFontSizeLevel(LingFontSizeLevel level) {
    return _preferencesStore.writeString(
      lingFontSizeLevelPreferenceKey,
      serializeLingFontSizeLevel(level),
    );
  }

  Future<void> persistLocaleCode(String localeCode) {
    return _preferencesStore.writeString(
      lingLocalePreferenceKey,
      normalizeLingLocaleCode(localeCode),
    );
  }

  UserProfile? optimisticThemeProfile(UserProfile? profile, ThemeMode mode) {
    return profile?.copyWith(
      preferences: (profile.preferences ?? const UserPreferences()).copyWith(
        themeMode: _serializeThemeModePreference(mode),
      ),
    );
  }

  UserProfile? optimisticLocaleProfile(
    UserProfile? profile,
    String localeCode,
  ) {
    final normalized = normalizeLingLocaleCode(localeCode);
    return profile?.copyWith(
      preferences: (profile.preferences ?? const UserPreferences()).copyWith(
        locale: normalized,
      ),
    );
  }

  UserProfile? optimisticPreferredInputModeProfile(
    UserProfile? profile,
    String mode,
  ) {
    final normalized = normalizePreferredInputMode(mode);
    return profile?.copyWith(
      preferences: (profile.preferences ?? const UserPreferences()).copyWith(
        preferredInputMode: normalized,
      ),
    );
  }

  Future<UserProfile> syncPreferences(UserPreferencesPatch patch) {
    return _repository.updatePreferences(patch);
  }
}

String _serializeThemeModePreference(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}
