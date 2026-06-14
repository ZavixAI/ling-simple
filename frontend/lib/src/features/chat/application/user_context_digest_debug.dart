import 'package:flutter/foundation.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/storage/app_preferences.dart';

class UserContextDigestDebugPreview {
  const UserContextDigestDebugPreview._();

  static const String prefsKey = 'ling_debug_context_digest_always_visible';
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  static Future<void> load() async {
    final prefs = await AppPreferences.instance;
    final nextEnabled = prefs.getBool(prefsKey) ?? false;
    AppLogger.info(
      '[Ling][DebugPreview] load context digest preview enabled=$nextEnabled',
      category: 'debug',
      fields: <String, Object?>{'prefsKey': prefsKey, 'enabled': nextEnabled},
    );
    if (enabled.value != nextEnabled) {
      enabled.value = nextEnabled;
    }
  }

  static Future<void> setEnabled(bool nextEnabled) async {
    final prefs = await AppPreferences.instance;
    await prefs.setBool(prefsKey, nextEnabled);
    AppLogger.info(
      '[Ling][DebugPreview] set context digest preview enabled=$nextEnabled',
      category: 'debug',
      fields: <String, Object?>{'prefsKey': prefsKey, 'enabled': nextEnabled},
    );
    if (enabled.value != nextEnabled) {
      enabled.value = nextEnabled;
    }
  }
}

class EmptyStateQuickPromptsDebugPreview {
  const EmptyStateQuickPromptsDebugPreview._();

  static const String prefsKey = 'ling_debug_empty_state_quick_prompts_visible';
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  static Future<void> load() async {
    final prefs = await AppPreferences.instance;
    final nextEnabled = prefs.getBool(prefsKey) ?? false;

    if (enabled.value != nextEnabled) {
      enabled.value = nextEnabled;
    }
  }

  static Future<void> setEnabled(bool nextEnabled) async {
    final prefs = await AppPreferences.instance;
    await prefs.setBool(prefsKey, nextEnabled);

    if (enabled.value != nextEnabled) {
      enabled.value = nextEnabled;
    }
  }
}
