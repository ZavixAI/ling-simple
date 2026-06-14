import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  const AppPreferences._();

  static Future<SharedPreferences>? _instance;

  static Future<void> ensureInitialized() async {
    await instance;
  }

  static Future<SharedPreferences> get instance =>
      _instance ??= SharedPreferences.getInstance();
}
