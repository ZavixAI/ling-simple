String sanitizeSharedTextForImportedAttachments(
  String? text, {
  required bool hasSharedImageFiles,
}) {
  final normalizedText = text?.trim();
  if (normalizedText == null || normalizedText.isEmpty) {
    return '';
  }
  if (!hasSharedImageFiles) {
    return normalizedText;
  }

  final filteredLines = normalizedText
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .where((line) => !_isLocalImageFileReference(line.trim()))
      .toList(growable: false);
  return filteredLines.join('\n').trim().replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

bool _isLocalImageFileReference(String value) {
  var normalized = value.trim();
  if (normalized.isEmpty) {
    return false;
  }
  if (normalized.startsWith('<') && normalized.endsWith('>')) {
    normalized = normalized.substring(1, normalized.length - 1).trim();
  }

  final lower = normalized.toLowerCase();
  final String path;
  if (lower.startsWith('file://')) {
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.scheme.toLowerCase() != 'file') {
      return false;
    }
    path = Uri.decodeComponent(uri.path);
  } else {
    path = normalized;
  }

  final pathLower = path.toLowerCase();
  final isIOSContainerPath =
      pathLower.startsWith('/var/mobile/containers/') ||
      pathLower.startsWith('/private/var/mobile/containers/') ||
      pathLower.contains('/mmimagepicker/temp/');
  if (!isIOSContainerPath) {
    return false;
  }

  return const {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.heic',
    '.heif',
    '.webp',
    '.bmp',
    '.tif',
    '.tiff',
  }.any(pathLower.endsWith);
}
