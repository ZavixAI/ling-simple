import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;

enum LingAgentFileKind {
  html,
  image,
  audio,
  markdown,
  text,
  code,
  pdf,
  json,
  other,
}

class LingAgentFileReference {
  const LingAgentFileReference({
    required this.title,
    required this.path,
    required this.isImageSyntax,
    required this.kind,
  });

  final String title;
  final String path;
  final bool isImageSyntax;
  final LingAgentFileKind kind;

  String get filename {
    final normalized = normalizeLingAgentFilePath(path);
    final name = p.posix.basename(normalized.replaceAll('\\', '/'));
    return name.isEmpty ? path : name;
  }
}

class LingAgentFileReferenceParseResult {
  const LingAgentFileReferenceParseResult({required this.references});

  final List<LingAgentFileReference> references;
}

class LingAgentFileReferenceSpan {
  const LingAgentFileReferenceSpan({
    required this.reference,
    required this.start,
    required this.end,
  });

  final LingAgentFileReference reference;
  final int start;
  final int end;
}

class LingAgentFileReferenceSpanParseResult {
  const LingAgentFileReferenceSpanParseResult({required this.spans});

  final List<LingAgentFileReferenceSpan> spans;
}

LingAgentFileReferenceParseResult parseLingAgentFileReferences(
  String markdown,
) {
  final references = <LingAgentFileReference>[];
  final seen = <String>{};
  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  final nodes = document.parseLines(markdown.split('\n'));
  for (final node in nodes) {
    _collectFileReferences(
      node,
      references: references,
      seen: seen,
      isInsideImage: false,
    );
  }
  return LingAgentFileReferenceParseResult(
    references: List<LingAgentFileReference>.unmodifiable(references),
  );
}

LingAgentFileReferenceSpanParseResult parseLingAgentFileReferenceSpans(
  String markdown,
) {
  final spans = <LingAgentFileReferenceSpan>[];
  var index = 0;
  var inFence = false;
  while (index < markdown.length) {
    if (_isFenceLineStart(markdown, index)) {
      inFence = !inFence;
      index = _nextLineStart(markdown, index);
      continue;
    }
    if (inFence) {
      index += 1;
      continue;
    }
    if (markdown.codeUnitAt(index) == 0x60) {
      index = _skipInlineCode(markdown, index);
      continue;
    }
    final isImageSyntax =
        markdown.codeUnitAt(index) == 0x21 &&
        index + 1 < markdown.length &&
        markdown.codeUnitAt(index + 1) == 0x5B;
    final linkStart = isImageSyntax ? index + 1 : index;
    if (markdown.codeUnitAt(linkStart) != 0x5B) {
      index += 1;
      continue;
    }
    final labelEnd = _findUnescaped(markdown, 0x5D, linkStart + 1);
    if (labelEnd < 0 ||
        labelEnd + 1 >= markdown.length ||
        markdown.codeUnitAt(labelEnd + 1) != 0x28) {
      index += 1;
      continue;
    }
    final targetEnd = _findUnescaped(markdown, 0x29, labelEnd + 2);
    if (targetEnd < 0) {
      index += 1;
      continue;
    }
    final rawTarget = _extractMarkdownLinkTarget(
      markdown.substring(labelEnd + 2, targetEnd),
    );
    final normalized = normalizeLingAgentFilePath(rawTarget);
    if (isLingAgentWorkspaceFileReference(normalized)) {
      final label = _plainMarkdownLabel(
        markdown.substring(linkStart + 1, labelEnd),
      );
      spans.add(
        LingAgentFileReferenceSpan(
          reference: LingAgentFileReference(
            title: label.isNotEmpty ? label : _filenameFromPath(normalized),
            path: normalized,
            isImageSyntax: isImageSyntax,
            kind: resolveLingAgentFileKind(normalized),
          ),
          start: index,
          end: targetEnd + 1,
        ),
      );
    }
    index = targetEnd + 1;
  }
  return LingAgentFileReferenceSpanParseResult(
    spans: List<LingAgentFileReferenceSpan>.unmodifiable(spans),
  );
}

void _collectFileReferences(
  md.Node node, {
  required List<LingAgentFileReference> references,
  required Set<String> seen,
  required bool isInsideImage,
}) {
  if (node is md.Element) {
    final isImage = node.tag == 'img';
    final target = isImage ? node.attributes['src'] : node.attributes['href'];
    if ((isImage || node.tag == 'a') && target != null) {
      _appendFileReference(
        rawTarget: target,
        rawLabel: isImage ? node.attributes['alt'] : _plainText(node),
        isImageSyntax: isImage || isInsideImage,
        references: references,
        seen: seen,
      );
    }
    for (final child in node.children ?? const <md.Node>[]) {
      _collectFileReferences(
        child,
        references: references,
        seen: seen,
        isInsideImage: isInsideImage || isImage,
      );
    }
  }
}

bool _isFenceLineStart(String markdown, int index) {
  if (index != 0 && markdown.codeUnitAt(index - 1) != 0x0A) {
    return false;
  }
  var cursor = index;
  while (cursor < markdown.length && markdown.codeUnitAt(cursor) == 0x20) {
    cursor += 1;
  }
  if (cursor + 2 >= markdown.length) {
    return false;
  }
  final first = markdown.codeUnitAt(cursor);
  if (first != 0x60 && first != 0x7E) {
    return false;
  }
  return markdown.codeUnitAt(cursor + 1) == first &&
      markdown.codeUnitAt(cursor + 2) == first;
}

int _nextLineStart(String markdown, int index) {
  final nextBreak = markdown.indexOf('\n', index);
  return nextBreak < 0 ? markdown.length : nextBreak + 1;
}

int _skipInlineCode(String markdown, int index) {
  var tickCount = 0;
  while (index + tickCount < markdown.length &&
      markdown.codeUnitAt(index + tickCount) == 0x60) {
    tickCount += 1;
  }
  final fence = '`' * tickCount;
  final close = markdown.indexOf(fence, index + tickCount);
  return close < 0 ? index + tickCount : close + tickCount;
}

int _findUnescaped(String value, int codeUnit, int start) {
  for (var index = start; index < value.length; index += 1) {
    if (value.codeUnitAt(index) != codeUnit) {
      continue;
    }
    var slashCount = 0;
    var cursor = index - 1;
    while (cursor >= 0 && value.codeUnitAt(cursor) == 0x5C) {
      slashCount += 1;
      cursor -= 1;
    }
    if (slashCount.isEven) {
      return index;
    }
  }
  return -1;
}

String _extractMarkdownLinkTarget(String raw) {
  final value = raw.trim();
  if (value.startsWith('<')) {
    final end = value.indexOf('>');
    if (end > 0) {
      return value.substring(0, end + 1);
    }
  }
  final space = value.indexOf(RegExp(r'\s'));
  return space < 0 ? value : value.substring(0, space);
}

String _plainMarkdownLabel(String raw) {
  return raw
      .replaceAll(r'\[', '[')
      .replaceAll(r'\]', ']')
      .replaceAll(r'\(', '(')
      .replaceAll(r'\)', ')')
      .replaceAll(RegExp(r'[`*~]+'), '')
      .trim();
}

void _appendFileReference({
  required String rawTarget,
  required String? rawLabel,
  required bool isImageSyntax,
  required List<LingAgentFileReference> references,
  required Set<String> seen,
}) {
  final normalized = normalizeLingAgentFilePath(rawTarget);
  if (!isLingAgentWorkspaceFileReference(normalized)) {
    return;
  }
  if (!seen.add(normalized)) {
    return;
  }
  final label = (rawLabel ?? '').trim();
  references.add(
    LingAgentFileReference(
      title: label.isNotEmpty ? label : _filenameFromPath(normalized),
      path: normalized,
      isImageSyntax: isImageSyntax,
      kind: resolveLingAgentFileKind(normalized),
    ),
  );
}

bool isLingAgentWorkspaceFileReference(String value) {
  final normalized = normalizeLingAgentFilePath(value);
  if (normalized.isEmpty) {
    return false;
  }
  final lower = normalized.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return false;
  }
  if (RegExp(r'^[a-z][a-z0-9+\-.]*:', caseSensitive: false).hasMatch(lower) &&
      !lower.startsWith('file:')) {
    return false;
  }
  if (lower.startsWith('/')) {
    return true;
  }
  if (lower.startsWith('./') || lower.startsWith('../')) {
    return false;
  }
  return lower.contains('/') || lower.contains('\\');
}

String normalizeLingAgentFilePath(String value) {
  var normalized = value.trim();
  if (normalized.startsWith('<') && normalized.endsWith('>')) {
    normalized = normalized.substring(1, normalized.length - 1).trim();
  }
  final sageDownloadPath = _extractSageWorkspaceDownloadPath(normalized);
  if (sageDownloadPath != null) {
    normalized = sageDownloadPath;
  }
  if (normalized.toLowerCase().startsWith('file://')) {
    final uri = Uri.tryParse(normalized);
    normalized =
        uri?.toFilePath() ??
        normalized.replaceFirst(RegExp(r'^file:///?'), '/');
  }
  try {
    normalized = Uri.decodeFull(normalized);
  } catch (_) {
    normalized = normalized.replaceAll('%20', ' ');
  }
  if (normalized.startsWith('/sage-workspace/')) {
    normalized = normalized.substring('/sage-workspace/'.length);
  } else if (normalized.startsWith('sage-workspace/')) {
    normalized = normalized.substring('sage-workspace/'.length);
  }
  return normalized;
}

String? _extractSageWorkspaceDownloadPath(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) {
    return null;
  }
  final lowerPath = uri.path.toLowerCase();
  if (!lowerPath.endsWith('/file_workspace/download')) {
    return null;
  }
  final filePath =
      uri.queryParameters['file_path'] ?? uri.queryParameters['path'];
  final normalized = filePath?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

LingAgentFileKind resolveLingAgentFileKind(String path) {
  final extension = p.extension(path).toLowerCase();
  return switch (extension) {
    '.html' || '.htm' => LingAgentFileKind.html,
    '.png' ||
    '.jpg' ||
    '.jpeg' ||
    '.webp' ||
    '.gif' ||
    '.svg' => LingAgentFileKind.image,
    '.mp3' || '.wav' || '.m4a' || '.aac' || '.caf' => LingAgentFileKind.audio,
    '.md' || '.markdown' => LingAgentFileKind.markdown,
    '.py' ||
    '.dart' ||
    '.js' ||
    '.jsx' ||
    '.ts' ||
    '.tsx' ||
    '.swift' ||
    '.kt' ||
    '.kts' ||
    '.java' ||
    '.go' ||
    '.rs' ||
    '.rb' ||
    '.php' ||
    '.c' ||
    '.cc' ||
    '.cpp' ||
    '.h' ||
    '.hpp' ||
    '.cs' ||
    '.sh' ||
    '.bash' ||
    '.zsh' ||
    '.fish' ||
    '.sql' ||
    '.css' ||
    '.scss' ||
    '.sass' => LingAgentFileKind.code,
    '.txt' || '.csv' || '.xml' || '.log' => LingAgentFileKind.text,
    '.json' || '.yaml' || '.yml' => LingAgentFileKind.json,
    '.pdf' => LingAgentFileKind.pdf,
    _ => LingAgentFileKind.other,
  };
}

bool isLingAgentFileKindInlinePreviewable(LingAgentFileKind kind) {
  return switch (kind) {
    LingAgentFileKind.html ||
    LingAgentFileKind.image ||
    LingAgentFileKind.audio ||
    LingAgentFileKind.markdown ||
    LingAgentFileKind.code ||
    LingAgentFileKind.text ||
    LingAgentFileKind.json => true,
    LingAgentFileKind.pdf || LingAgentFileKind.other => false,
  };
}

String _filenameFromPath(String path) {
  final name = p.posix.basename(path.replaceAll('\\', '/'));
  return name.isEmpty ? path : name;
}

String _plainText(md.Node node) {
  if (node is md.Text) {
    return node.text;
  }
  if (node is md.Element) {
    return (node.children ?? const <md.Node>[]).map(_plainText).join();
  }
  return '';
}
