import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/features/chat/application/agent_file_reference.dart';

void main() {
  group('parseLingAgentFileReferences', () {
    test('extracts relative workspace file links', () {
      final result = parseLingAgentFileReferences(
        '报告：[明天的日程报告](reports/daily-report.html)',
      );

      expect(result.references, hasLength(1));
      expect(result.references.first.title, '明天的日程报告');
      expect(result.references.first.path, 'reports/daily-report.html');
      expect(result.references.first.kind, LingAgentFileKind.html);
    });

    test('extracts image references and keeps http links out', () {
      final result = parseLingAgentFileReferences(
        '![图表](outputs/chart.png)\n[官网](https://example.com/report.html)',
      );

      expect(result.references, hasLength(1));
      expect(result.references.first.isImageSyntax, isTrue);
      expect(result.references.first.kind, LingAgentFileKind.image);
    });

    test('deduplicates repeated paths', () {
      final result = parseLingAgentFileReferences(
        '[报告](reports/a.html)\n[同一个报告](reports/a.html)',
      );

      expect(result.references, hasLength(1));
    });

    test('normalizes file urls', () {
      final result = parseLingAgentFileReferences(
        '[报告](file:///tmp/sage/agents/a/reports/a.html)',
      );

      expect(result.references, hasLength(1));
      expect(result.references.first.path, '/tmp/sage/agents/a/reports/a.html');
    });

    test('extracts paths with spaces from markdown angle links', () {
      final result = parseLingAgentFileReferences(
        '[报告](<reports/May 11/report.html>)',
      );

      expect(result.references, hasLength(1));
      expect(result.references.first.path, 'reports/May 11/report.html');
    });

    test('normalizes Sage workspace download image urls', () {
      final result = parseLingAgentFileReferences(
        '![照片](https://sage.example.com/api/agent/agent-1/file_workspace/download?file_path=upload_files/demo.jpg)',
      );

      expect(result.references, hasLength(1));
      expect(result.references.first.path, 'upload_files/demo.jpg');
      expect(result.references.first.isImageSyntax, isTrue);
      expect(result.references.first.kind, LingAgentFileKind.image);
    });

    test('treats source code files as inline previewable references', () {
      final result = parseLingAgentFileReferences(
        '[脚本](file:///app/agents/u/agent/data/quicksort_visualizer.py)',
      );

      expect(result.references, hasLength(1));
      expect(result.references.first.title, '脚本');
      expect(result.references.first.path, endsWith('quicksort_visualizer.py'));
      expect(result.references.first.kind, LingAgentFileKind.code);
      expect(
        isLingAgentFileKindInlinePreviewable(result.references.first.kind),
        isTrue,
      );
    });

    test('treats audio files as inline previewable references', () {
      final result = parseLingAgentFileReferences(
        '[听 Ling 说一句](voice/goodnight.wav)',
      );

      expect(result.references, hasLength(1));
      expect(result.references.first.title, '听 Ling 说一句');
      expect(result.references.first.path, 'voice/goodnight.wav');
      expect(result.references.first.kind, LingAgentFileKind.audio);
      expect(
        isLingAgentFileKindInlinePreviewable(result.references.first.kind),
        isTrue,
      );
    });
  });

  group('parseLingAgentFileReferenceSpans', () {
    test('returns source range for replacing a file link in place', () {
      const markdown = '报告已生成：[查看完整复盘](reports/minimax-review.md)\n继续聊。';
      final result = parseLingAgentFileReferenceSpans(markdown);

      expect(result.spans, hasLength(1));
      expect(result.spans.first.start, markdown.indexOf('[查看完整复盘]'));
      expect(
        markdown.substring(result.spans.first.start, result.spans.first.end),
        '[查看完整复盘](reports/minimax-review.md)',
      );
      expect(result.spans.first.reference.title, '查看完整复盘');
      expect(result.spans.first.reference.kind, LingAgentFileKind.markdown);
    });

    test('returns source range for code file link labels with slashes', () {
      const markdown =
          '文件入口：[data/quicksort_visualizer.py](file:///app/agents/u_79a7893d9cb7420b8d7c43e79dcbeb63/agent_56afd26d/data/quicksort_visualizer.py)';
      final result = parseLingAgentFileReferenceSpans(markdown);

      expect(result.spans, hasLength(1));
      expect(
        markdown.substring(result.spans.first.start, result.spans.first.end),
        '[data/quicksort_visualizer.py](file:///app/agents/u_79a7893d9cb7420b8d7c43e79dcbeb63/agent_56afd26d/data/quicksort_visualizer.py)',
      );
      expect(
        result.spans.first.reference.title,
        'data/quicksort_visualizer.py',
      );
      expect(result.spans.first.reference.kind, LingAgentFileKind.code);
    });

    test('keeps markdown image syntax metadata for inline image rendering', () {
      final result = parseLingAgentFileReferenceSpans(
        '![照片](file:///app/agents/u1/upload_files/demo.jpg)',
      );

      expect(result.spans, hasLength(1));
      expect(result.spans.first.reference.isImageSyntax, isTrue);
      expect(result.spans.first.reference.kind, LingAgentFileKind.image);
    });

    test('returns source range for audio file links', () {
      const markdown = '我轻声说了一句：[听一下](voice/reassurance.m4a)';
      final result = parseLingAgentFileReferenceSpans(markdown);

      expect(result.spans, hasLength(1));
      expect(result.spans.first.reference.path, 'voice/reassurance.m4a');
      expect(result.spans.first.reference.kind, LingAgentFileKind.audio);
    });

    test('ignores links in inline code and fenced code blocks', () {
      final result = parseLingAgentFileReferenceSpans(
        '`[报告](reports/a.md)`\n'
        '```md\n'
        '[报告](reports/b.md)\n'
        '```\n'
        '[报告](reports/c.md)',
      );

      expect(result.spans, hasLength(1));
      expect(result.spans.first.reference.path, 'reports/c.md');
    });
  });
}
