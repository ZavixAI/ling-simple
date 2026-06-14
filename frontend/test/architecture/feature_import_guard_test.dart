import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const allowedPartFilesByRoot = <String, Set<String>>{
    'lib/src/features/chat/presentation/bottom_dock.dart': {
      'bottom_dock/bottom_dock_attachments.dart',
      'bottom_dock/bottom_dock_chrome.dart',
      'bottom_dock/bottom_dock_composer.dart',
      'bottom_dock/bottom_dock_quick_prompts.dart',
      'bottom_dock/bottom_dock_queue_status.dart',
      'bottom_dock/bottom_dock_voice.dart',
    },
  };

  test('feature layer does not depend on retired horizontal directories', () {
    const bannedSnippets = <String>[
      "package:ling/src/features/models/",
      "package:ling/src/features/repositories/",
      "package:ling/src/features/services/",
      "package:ling/src/features/providers.dart",
    ];

    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      for (final snippet in bannedSnippets) {
        expect(
          content.contains(snippet),
          isFalse,
          reason: '${file.path} still references $snippet',
        );
      }
    }
  });

  test('feature source files only use curated non-generated part directives', () {
    final dartFiles = Directory('lib/src/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith('.g.dart'));

    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      final normalizedPath = file.path.replaceAll('\\', '/');
      final matches = RegExp(
        r"^part\s+'(?!.*\.g\.dart';$)([^']+)';$",
        multiLine: true,
      ).allMatches(content);
      final actualPartFiles = matches
          .map((match) => match.group(1))
          .whereType<String>()
          .toSet();
      if (actualPartFiles.isEmpty) {
        continue;
      }

      expect(
        allowedPartFilesByRoot.containsKey(normalizedPath),
        isTrue,
        reason:
            '$normalizedPath contains non-generated part directives but is not an approved root file',
      );
      expect(
        actualPartFiles,
        allowedPartFilesByRoot[normalizedPath],
        reason: '$normalizedPath has an unexpected part file list',
      );

      final directory = file.parent.path.replaceAll('\\', '/');
      for (final partFile in actualPartFiles) {
        final sibling = File('$directory/$partFile');
        expect(
          sibling.existsSync(),
          isTrue,
          reason: '$normalizedPath declares missing part file $partFile',
        );
        expect(
          sibling.readAsStringSync().contains(
            RegExp(r"^part of ", multiLine: true),
          ),
          isTrue,
          reason: '${sibling.path} is missing a part-of directive',
        );
      }
    }
  });

  test('src app and features do not contain thin export-only dart files', () {
    final roots = <Directory>[
      Directory('lib/src/app'),
      Directory('lib/src/features'),
    ];

    for (final root in roots) {
      final dartFiles = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.endsWith('.g.dart'));

      for (final file in dartFiles) {
        final normalized = file
            .readAsStringSync()
            .replaceAll(RegExp(r'//.*'), '')
            .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (normalized.isEmpty) {
          continue;
        }
        final exportOnlyPattern = RegExp(
          r"^(export\s+'[^']+'(?:\s+show\s+[^;]+)?;\s*)+$",
        );
        expect(
          exportOnlyPattern.hasMatch(normalized),
          isFalse,
          reason: '${file.path} is a thin export-only file',
        );
      }
    }
  });

  test('presentation files do not import data-layer files', () {
    const allowedDataLayerImportsByFile = <String, Set<String>>{
      'lib/src/features/chat/presentation/agent_markdown_image.dart': {
        'package:ling/src/features/chat/data/agent_file_save_service.dart',
      },
      'lib/src/features/chat/presentation/chat_section.dart': {
        'package:ling/src/features/chat/data/chat_repository.dart',
        'package:ling/src/features/chat/data/shared_image_receive_bridge.dart',
      },
      'lib/src/features/chat/presentation/conversation_agent_file_cards.dart': {
        'package:ling/src/features/chat/data/agent_file_save_service.dart',
      },
      'lib/src/app/presentation/app_shell_page.dart': {
        'package:ling/src/features/settings/data/bridges/photo_library_permission_bridge.dart',
      },
      'lib/src/features/settings/presentation/settings_page_models.dart': {
        'package:ling/src/features/chat/data/apple_speech_recognition_bridge.dart',
        'package:ling/src/features/settings/data/bridges/photo_library_permission_bridge.dart',
      },
      'lib/src/features/settings/presentation/settings_page.dart': {
        'package:ling/src/features/chat/data/apple_speech_recognition_bridge.dart',
        'package:ling/src/features/settings/data/bridges/photo_library_permission_bridge.dart',
      },
      'lib/src/features/settings/presentation/settings_page_root_content.dart': {
        'package:ling/src/features/chat/data/apple_speech_recognition_bridge.dart',
        'package:ling/src/features/settings/data/bridges/photo_library_permission_bridge.dart',
      },
    };
    final roots = <Directory>[
      Directory('lib/src/app/presentation'),
      Directory('lib/src/features'),
    ];

    final importPattern = RegExp(
      r"(?:import|export)\s+'(package:ling/src/[^']+/data/[^']+)';",
    );

    for (final root in roots) {
      final dartFiles = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.endsWith('.g.dart'))
          .where(
            (file) =>
                file.path.replaceAll('\\', '/').contains('/presentation/'),
          );

      for (final file in dartFiles) {
        final normalizedPath = file.path.replaceAll('\\', '/');
        final content = file.readAsStringSync();
        final matches = importPattern
            .allMatches(content)
            .map((match) => match.group(1))
            .whereType<String>()
            .toSet();
        if (matches.isEmpty) {
          continue;
        }
        final unexpectedMatches = matches.difference(
          allowedDataLayerImportsByFile[normalizedPath] ?? const <String>{},
        );

        expect(
          unexpectedMatches,
          isEmpty,
          reason:
              '$normalizedPath imports data-layer files: ${unexpectedMatches.join(', ')}',
        );
      }
    }
  });
}
