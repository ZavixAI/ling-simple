import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

String resolveLingDatabaseDirectoryPath({
  Map<String, String>? environment,
  bool? isApplePlatform,
  String? systemTempPath,
}) {
  final applePlatform = isApplePlatform ?? (Platform.isIOS || Platform.isMacOS);
  if (!applePlatform) {
    return '';
  }

  final resolvedEnvironment = environment ?? Platform.environment;
  final homeDirectoryCandidates = <String?>[
    resolvedEnvironment['HOME'],
    resolvedEnvironment['CFFIXED_USER_HOME'],
    _appleHomeDirectoryFromTemporaryPath(resolvedEnvironment['TMPDIR']),
    _appleHomeDirectoryFromTemporaryPath(
      systemTempPath ?? Directory.systemTemp.path,
    ),
  ];

  for (final candidate in homeDirectoryCandidates) {
    final normalizedHomeDirectory = _normalizeAppleHomeDirectory(candidate);
    if (normalizedHomeDirectory.isEmpty) {
      continue;
    }
    return path.join(normalizedHomeDirectory, 'Library', 'Application Support');
  }

  return '';
}

String _appleHomeDirectoryFromTemporaryPath(String? temporaryPath) {
  final normalizedTemporaryPath = temporaryPath?.trim() ?? '';
  if (normalizedTemporaryPath.isEmpty) {
    return '';
  }

  final cleanedTemporaryPath = path.normalize(normalizedTemporaryPath);
  if (path.basename(cleanedTemporaryPath) == 'tmp') {
    return path.dirname(cleanedTemporaryPath);
  }

  const cachesSuffix = 'Library/Caches';
  if (cleanedTemporaryPath.endsWith(cachesSuffix)) {
    return path.dirname(path.dirname(cleanedTemporaryPath));
  }

  return '';
}

String _normalizeAppleHomeDirectory(String? directoryPath) {
  final normalizedPath = directoryPath?.trim() ?? '';
  if (normalizedPath.isEmpty) {
    return '';
  }

  return path.normalize(normalizedPath);
}

QueryExecutor createDatabaseConnection() {
  return LazyDatabase(() async {
    final appleDirectoryPath = resolveLingDatabaseDirectoryPath();
    final directory = appleDirectoryPath.isNotEmpty
        ? await Directory(appleDirectoryPath).create(recursive: true)
        : await getApplicationSupportDirectory();
    final file = File(path.join(directory.path, 'ling_app.sqlite'));
    return NativeDatabase(file);
  });
}
