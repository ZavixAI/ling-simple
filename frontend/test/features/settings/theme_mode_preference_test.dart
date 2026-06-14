import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/features/settings/application/settings_controller.dart';

void main() {
  test('serializes theme mode preference', () {
    expect(serializeThemeModePreference(ThemeMode.light), 'light');
    expect(serializeThemeModePreference(ThemeMode.dark), 'dark');
    expect(serializeThemeModePreference(ThemeMode.system), 'system');
  });

  test('deserializes theme mode preference', () {
    expect(deserializeThemeModePreference('light'), ThemeMode.light);
    expect(deserializeThemeModePreference('dark'), ThemeMode.dark);
    expect(deserializeThemeModePreference('system'), ThemeMode.system);
    expect(deserializeThemeModePreference('unknown'), isNull);
  });
}
