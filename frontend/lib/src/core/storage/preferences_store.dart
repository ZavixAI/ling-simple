import 'package:ling/src/core/storage/app_preferences.dart';

class PreferencesStore {
  const PreferencesStore();

  Future<String?> readString(String key) async {
    final prefs = await AppPreferences.instance;
    return prefs.getString(key);
  }

  Future<void> writeString(String key, String value) async {
    final prefs = await AppPreferences.instance;
    await prefs.setString(key, value);
  }

  Future<void> remove(String key) async {
    final prefs = await AppPreferences.instance;
    await prefs.remove(key);
  }

  Future<Set<String>> getKeys() async {
    final prefs = await AppPreferences.instance;
    return prefs.getKeys();
  }
}
