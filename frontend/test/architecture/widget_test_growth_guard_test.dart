import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy widget_test.dart stays deleted or empty', () {
    final widgetTest = File('test/widget_test.dart');
    if (!widgetTest.existsSync()) {
      return;
    }

    final content = widgetTest.readAsStringSync();
    final testCount = RegExp(
      r'\btest(?:Widgets)?\s*\(',
    ).allMatches(content).length;

    expect(
      testCount,
      0,
      reason:
          'Do not recreate test/widget_test.dart as an aggregate test file. '
          'Move tests into test/features/<feature>/... or test/app/... instead.',
    );
  });
}
