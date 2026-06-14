import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/shared/i18n/ling_locale.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/i18n/ling_strings_en.dart';
import 'package:ling/src/shared/i18n/ling_strings_zh.dart';

void main() {
  test('maps simplified and traditional Chinese locales to Chinese', () {
    expect(
      resolveLingLocaleCodeFromLocales(<Locale>[
        const Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
      ]),
      lingChineseLocaleCode,
    );
    expect(
      resolveLingLocaleCodeFromLocales(<Locale>[
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
      ]),
      lingChineseLocaleCode,
    );
  });

  test('maps non-Chinese locales to English', () {
    expect(
      resolveLingLocaleCodeFromLocales(<Locale>[
        const Locale.fromSubtags(languageCode: 'en', countryCode: 'US'),
      ]),
      lingEnglishLocaleCode,
    );
    expect(
      resolveLingLocaleCodeFromLocales(<Locale>[
        const Locale.fromSubtags(languageCode: 'fr', countryCode: 'FR'),
      ]),
      lingEnglishLocaleCode,
    );
  });

  test('prefers saved locale over device locale on startup', () {
    expect(
      resolveInitialLingLocaleCode(
        savedLocaleCode: 'zh-Hant-TW',
        deviceLocales: const <Locale>[
          Locale.fromSubtags(languageCode: 'en', countryCode: 'US'),
        ],
      ),
      lingChineseLocaleCode,
    );
    expect(
      resolveInitialLingLocaleCode(
        savedLocaleCode: 'en-GB',
        deviceLocales: const <Locale>[
          Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
        ],
      ),
      lingEnglishLocaleCode,
    );
  });

  test('LingStrings reads static labels from language catalogs', () {
    const zh = LingStrings(lingChineseLocaleCode);
    const en = LingStrings(lingEnglishLocaleCode);

    expect(zh.loginBadge, 'AI 日历助理');
    expect(en.loginBadge, 'AI Calendar Copilot');
    expect(zh.calendarNotificationsTitle, '日历通知');
    expect(en.calendarNotificationsTitle, 'Calendar Notifications');
  });

  test('language catalogs expose the same static label keys', () {
    expect(lingZhStrings.keys.toSet(), lingEnStrings.keys.toSet());
  });
}
