import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/app/app.dart';

void main() {
  test(
    'parseLingAppThemeMode defaults to system when preference is missing',
    () {
      expect(parseLingAppThemeMode(null), ThemeMode.system);
      expect(parseLingAppThemeMode('unknown'), ThemeMode.system);
    },
  );

  test('parseLingAppThemeMode restores explicit saved theme preference', () {
    expect(parseLingAppThemeMode('light'), ThemeMode.light);
    expect(parseLingAppThemeMode('dark'), ThemeMode.dark);
    expect(parseLingAppThemeMode('system'), ThemeMode.system);
  });

  test('serializeLingAppThemeMode writes all supported preferences', () {
    expect(serializeLingAppThemeMode(ThemeMode.light), 'light');
    expect(serializeLingAppThemeMode(ThemeMode.dark), 'dark');
    expect(serializeLingAppThemeMode(ThemeMode.system), 'system');
  });
}
