import 'dart:async';

import 'package:ling/src/core/logging/app_logger.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppLogger.setConsoleOutputEnabled(false);
  await testMain();
}
