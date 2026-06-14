import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presentation color literals are classified', () {
    final root = Directory('lib/src');
    final colorPattern = RegExp(
      r'Color\(0x[0-9A-Fa-f]{8}\)|Colors\.(black|white|grey|gray)',
    );
    final allowedFiles = <String>{
      'lib/src/core/theme/app_theme.dart',
      'lib/src/features/calendar/presentation/calendar_event_hero_chrome.dart',
      'lib/src/features/calendar/presentation/event_details_sheet.dart',
      'lib/src/features/calendar/presentation/schedule_agenda_card.dart',
      'lib/src/features/calendar/presentation/schedule_formatters.dart',
      'lib/src/features/calendar/presentation/schedule_header.dart',
      'lib/src/features/chat/presentation/bottom_dock/bottom_dock_attachments.dart',
      'lib/src/features/chat/presentation/chat_section_view.dart',
      'lib/src/features/chat/presentation/chat_shell.dart',
      'lib/src/features/chat/presentation/conversation_tool_call_cards.dart',
      'lib/src/shared/presentation/brand_palettes.dart',
      'lib/src/shared/presentation/adaptive_controls.dart',
    };
    final allowedLineFragmentsByFile = <String, List<String>>{
      'lib/src/shared/presentation/liquid_glass.dart': [
        'Colors.white.withValues(alpha: 0.22)',
        'Colors.white.withValues(alpha: 0.44)',
      ],
      'lib/src/shared/presentation/notice.dart': [
        'Colors.white.withValues(alpha: 0.18)',
      ],
      'lib/src/features/calendar/presentation/schedule_agenda_card.dart': [
        'color: Colors.white.withValues(',
        'color: Colors.white,',
        'const Color(0xFF111820)',
        'const Color(0xFFF8FAFC).withValues(alpha: 0.98)',
      ],
      'lib/src/features/calendar/presentation/event_editor_sheet.dart': [
        'const Color(0xFFF8FAFC).withValues(alpha: 0.98)',
      ],
      'lib/src/features/chat/presentation/bottom_dock/bottom_dock_chrome.dart':
          [
            'Colors.white.withValues(alpha: 0.08)',
            'Colors.white.withValues(alpha: 0.16)',
            'Colors.white.withValues(alpha: 0.20)',
          ],
      'lib/src/features/membership/presentation/membership_subscription_panel.dart':
          [
            'Color(0xFF1B7F46).withValues(alpha: 0.68)',
            'Color(0xFF2A6FF2).withValues(alpha: 0.62)',
          ],
    };
    final violations = <String>[];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final relativePath = entity.path;
      final isUiFile =
          relativePath.contains('/presentation/') ||
          relativePath == 'lib/src/core/theme/app_theme.dart';
      if (!isUiFile) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        if (!colorPattern.hasMatch(line)) {
          continue;
        }
        final allowedFragments =
            allowedLineFragmentsByFile[relativePath] ?? const <String>[];
        if (allowedFiles.contains(relativePath) ||
            allowedFragments.any(line.contains)) {
          continue;
        }
        violations.add('${entity.path}:${index + 1}: ${line.trim()}');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Theme-aware UI colors must use LingPalette. Classify any intentional literal before adding it.\n${violations.join('\n')}',
    );
  });

  test('buttons and inputs use semantic theme colors', () {
    final root = Directory('lib/src');
    final riskyLinePatterns = <RegExp>[
      RegExp(r'foregroundColor:\s*palette\.(background|surface|onAccent)\b'),
      RegExp(r'cursorColor:\s*palette\.accent\b'),
      RegExp(r'fillColor:\s*palette\.(surfaceFrost|surfaceMuted)\b'),
      RegExp(r'hintStyle:\s*TextStyle\(color:\s*palette\.textSecondary\b'),
    ];
    final allowedLineFragmentsByFile = <String, List<String>>{
      'lib/src/features/calendar/presentation/event_editor_sheet.dart': [
        'todayForegroundColor:',
      ],
    };
    final violations = <String>[];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final relativePath = entity.path;
      if (!relativePath.contains('/presentation/')) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        if (!riskyLinePatterns.any((pattern) => pattern.hasMatch(line))) {
          continue;
        }
        final allowedFragments =
            allowedLineFragmentsByFile[relativePath] ?? const <String>[];
        if (allowedFragments.any(line.contains)) {
          continue;
        }
        violations.add('${entity.path}:${index + 1}: ${line.trim()}');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Buttons and inputs must use semantic LingPalette colors such as '
          'primaryButtonForeground, inputPlaceholder, and inputCursor.\n'
          '${violations.join('\n')}',
    );
  });

  test('disabled buttons do not rely on low global opacity', () {
    final file = File('lib/src/shared/presentation/liquid_glass.dart');
    final contents = file.readAsStringSync();
    final buttonStart = contents.indexOf('class LingGlassButton');
    final chipStart = contents.indexOf('class LingGlassChip');
    final buttonSection = contents.substring(buttonStart, chipStart);

    expect(
      buttonSection.contains('opacity: enabled ? 1 : 0.55'),
      isFalse,
      reason:
          'Disabled buttons should stay readable in dark mode. Use semantic '
          'disabled foreground/background tokens instead of fading the entire '
          'button.',
    );
  });

  test('business UI uses shared liquid glass button wrappers', () {
    final root = Directory('lib/src');
    final directGlassButtonPattern = RegExp(
      r'\bGlass(Button|IconButton|Chip)\b',
    );
    final allowedFiles = <String>{
      'lib/src/shared/presentation/liquid_glass.dart',
    };
    final violations = <String>[];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final relativePath = entity.path;
      if (allowedFiles.contains(relativePath)) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        if (directGlassButtonPattern.hasMatch(line)) {
          violations.add('${entity.path}:${index + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Liquid glass buttons must go through LingGlassButton, '
          'LingGlassIconButton, or LingGlassChip so light/dark glass settings '
          'and chrome are tested in one place.\n${violations.join('\n')}',
    );
  });

  test('floating glass switches use the shared wrapper', () {
    final root = Directory('lib/src');
    final directFloatingSwitchPattern = RegExp(r'\bGlassBottomBar\b');
    final violations = <String>[];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        if (directFloatingSwitchPattern.hasMatch(line)) {
          violations.add('${entity.path}:${index + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Floating liquid glass switches should use LingGlassFloatingSwitch '
          'so the Workbench-style single-layer glass treatment stays shared.\n'
          '${violations.join('\n')}',
    );
  });

  test('schedule mode switch uses the shared floating glass switch', () {
    final file = File(
      'lib/src/features/calendar/presentation/schedule_header.dart',
    );
    final source = file.readAsStringSync();

    expect(
      source,
      contains('LingGlassFloatingSwitch<LingCalendarScheduleMode>'),
      reason:
          'The week/month schedule switch should share the same Liquid Glass '
          'floating switch implementation as the other switch controls.',
    );
    expect(
      source,
      isNot(contains('_ScheduleModeSegment')),
      reason: 'Do not reintroduce the old custom segmented switch.',
    );
    expect(
      source,
      isNot(contains('AnimatedAlign')),
      reason:
          'Schedule mode switching should inherit shared Liquid Glass motion '
          'from LingGlassFloatingSwitch.',
    );
  });

  test('bottom dock action glass uses shared button and chip wrappers', () {
    final quickPrompts = File(
      'lib/src/features/chat/presentation/bottom_dock/bottom_dock_quick_prompts.dart',
    ).readAsStringSync();
    final voice = File(
      'lib/src/features/chat/presentation/bottom_dock/bottom_dock_voice.dart',
    ).readAsStringSync();
    final chrome = File(
      'lib/src/features/chat/presentation/bottom_dock/bottom_dock_chrome.dart',
    ).readAsStringSync();

    expect(
      quickPrompts,
      isNot(contains('LingGlassSurface')),
      reason:
          'Bottom dock quick prompt chips should use LingGlassChip directly, '
          'without a second custom glass surface or border.',
    );
    expect(
      voice,
      contains('LingGlassButton'),
      reason:
          'The bottom dock voice pill should use LingGlassButton so dark-mode '
          'glass chrome stays aligned with other buttons.',
    );
    expect(
      chrome,
      isNot(contains('child: LingGlassSurface')),
      reason:
          'Outer dock icon actions should use LingGlassIconButton rather than '
          'hand-rolled LingGlassSurface + IconButton controls.',
    );
  });

  test('light theme avoids gray block background tokens', () {
    final file = File('lib/src/core/theme/app_theme.dart');
    final lines = file.readAsLinesSync();
    final grayBackgroundTokens = <String>[
      '0xFFF6F7F9',
      '0xFFEFF2F5',
      '0xFFF2F3F5',
      '0xFFF3F4F6',
      '0xFFF5F5F7',
      '0x75F6F7F9',
      '0x47F6F7F9',
      '0xE6F6F7F9',
      '0xD6F6F7F9',
    ];
    final violations = <String>[];

    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      if (!grayBackgroundTokens.any(line.contains)) {
        continue;
      }
      violations.add('${file.path}:${index + 1}: ${line.trim()}');
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Light Frost Mono surfaces should stay white or transparent. Use '
          'outline/shadow tokens for hierarchy instead of gray fill blocks.\n'
          '${violations.join('\n')}',
    );
  });
}
