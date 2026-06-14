import 'dart:ui' as ui show PlatformDispatcher;

import 'package:flutter/widgets.dart';

const String lingLocalePreferenceKey = 'ling.locale_code';
const String lingChineseLocaleCode = 'zh-CN';
const String lingEnglishLocaleCode = 'en-US';

const List<Locale> lingSupportedLocales = <Locale>[
  Locale('zh', 'CN'),
  Locale('en', 'US'),
];

String normalizeLingLocaleCode(String? localeCode) {
  final normalized = (localeCode ?? '')
      .trim()
      .replaceAll('_', '-')
      .toLowerCase();
  if (normalized == 'zh' || normalized.startsWith('zh-')) {
    return lingChineseLocaleCode;
  }
  return lingEnglishLocaleCode;
}

String resolveLingLocaleCodeFromLocales(Iterable<Locale> locales) {
  for (final locale in locales) {
    if (normalizeLingLocaleCode(locale.toLanguageTag()) ==
        lingChineseLocaleCode) {
      return lingChineseLocaleCode;
    }
  }
  return lingEnglishLocaleCode;
}

String resolveSystemLingLocaleCode({Iterable<Locale>? locales}) {
  final resolvedLocales = locales ?? ui.PlatformDispatcher.instance.locales;
  if (resolvedLocales.isNotEmpty) {
    return resolveLingLocaleCodeFromLocales(resolvedLocales);
  }
  return normalizeLingLocaleCode(
    ui.PlatformDispatcher.instance.locale.toLanguageTag(),
  );
}

String resolveInitialLingLocaleCode({
  String? savedLocaleCode,
  Iterable<Locale>? deviceLocales,
}) {
  final normalizedSavedLocale = (savedLocaleCode ?? '').trim();
  if (normalizedSavedLocale.isNotEmpty) {
    return normalizeLingLocaleCode(normalizedSavedLocale);
  }
  return resolveSystemLingLocaleCode(locales: deviceLocales);
}

Locale localeFromLingLocaleCode(String localeCode) {
  return switch (normalizeLingLocaleCode(localeCode)) {
    lingChineseLocaleCode => const Locale('zh', 'CN'),
    _ => const Locale('en', 'US'),
  };
}
