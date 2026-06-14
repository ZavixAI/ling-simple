import 'dart:convert';

enum LingObjectReferenceKind {
  event;

  String get wireName => switch (this) {
    LingObjectReferenceKind.event => 'event',
  };

  static LingObjectReferenceKind? tryParse(Object? value) {
    switch ('$value'.trim()) {
      case 'event':
        return LingObjectReferenceKind.event;
    }
    return null;
  }
}

class LingObjectReference {
  const LingObjectReference({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
    this.summaryFields = const <String, String>{},
    this.createdFromRoute,
    this.version = 1,
  });

  final LingObjectReferenceKind kind;
  final String id;
  final String title;
  final String? subtitle;
  final Map<String, String> summaryFields;
  final String? createdFromRoute;
  final int version;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'kind': kind.wireName,
      'id': id,
      'title': title,
      if ((subtitle ?? '').trim().isNotEmpty) 'subtitle': subtitle!.trim(),
      if (summaryFields.isNotEmpty) 'summary': summaryFields,
      if ((createdFromRoute ?? '').trim().isNotEmpty)
        'created_from_route': createdFromRoute!.trim(),
    };
  }

  static LingObjectReference? fromJson(Map<String, dynamic> json) {
    final kind = LingObjectReferenceKind.tryParse(json['kind']);
    final id = '${json['id'] ?? ''}'.trim();
    final title = '${json['title'] ?? ''}'.trim();
    if (kind == null || id.isEmpty || title.isEmpty) {
      return null;
    }
    final rawSummary = json['summary'];
    final summary = <String, String>{};
    if (rawSummary is Map) {
      for (final entry in rawSummary.entries) {
        final key = '${entry.key}'.trim();
        final value = '${entry.value}'.trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          summary[key] = value;
        }
      }
    }
    return LingObjectReference(
      kind: kind,
      id: id,
      title: title,
      subtitle: '${json['subtitle'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['subtitle']}'.trim(),
      summaryFields: Map<String, String>.unmodifiable(summary),
      createdFromRoute: '${json['created_from_route'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['created_from_route']}'.trim(),
      version: int.tryParse('${json['version'] ?? 1}') ?? 1,
    );
  }
}

class LingObjectReferenceParseResult {
  const LingObjectReferenceParseResult({
    required this.references,
    required this.remainingText,
  });

  final List<LingObjectReference> references;
  final String remainingText;
}

class LingObjectReferenceCodec {
  const LingObjectReferenceCodec._();

  static const String startTag = '<ling-object-reference>';
  static const String endTag = '</ling-object-reference>';

  static String encode(LingObjectReference reference) {
    return '$startTag\n${jsonEncode(reference.toJson())}\n$endTag';
  }

  static String composeText({
    required List<LingObjectReference> references,
    required String userText,
  }) {
    final parts = <String>[
      for (final reference in references) encode(reference),
      userText.trim(),
    ].where((part) => part.trim().isNotEmpty).toList(growable: false);
    return parts.join('\n\n');
  }

  static LingObjectReferenceParseResult parse(String text) {
    final references = <LingObjectReference>[];
    final buffer = StringBuffer();
    var cursor = 0;
    while (cursor < text.length) {
      final start = text.indexOf(startTag, cursor);
      if (start < 0) {
        buffer.write(text.substring(cursor));
        break;
      }
      final end = text.indexOf(endTag, start + startTag.length);
      if (end < 0) {
        buffer.write(text.substring(cursor));
        break;
      }
      buffer.write(text.substring(cursor, start));
      final rawPayload = text.substring(start + startTag.length, end).trim();
      final reference = _tryDecode(rawPayload);
      if (reference == null) {
        buffer.write(text.substring(start, end + endTag.length));
      } else {
        references.add(reference);
      }
      cursor = end + endTag.length;
    }
    return LingObjectReferenceParseResult(
      references: List<LingObjectReference>.unmodifiable(references),
      remainingText: buffer.toString().trim(),
    );
  }

  static LingObjectReference? _tryDecode(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map) {
        return null;
      }
      return LingObjectReference.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}
