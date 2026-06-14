import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/chat/application/object_reference.dart';

const String _objectReferenceMarker = '\uFFFC';

class LingObjectReferenceEditingController extends TextEditingController {
  LingObjectReferenceEditingController({super.text});

  List<LingObjectReference> _objectReferences = const <LingObjectReference>[];
  ValueChanged<LingObjectReference>? _onRemove;

  List<LingObjectReference> get objectReferences => _objectReferences;

  String get userText => stripObjectReferenceMarkers(text);

  bool get hasObjectReferenceMarker => text.contains(_objectReferenceMarker);

  void setObjectReferences(
    List<LingObjectReference> references, {
    ValueChanged<LingObjectReference>? onRemove,
  }) {
    final nextReferences = List<LingObjectReference>.unmodifiable(
      references.take(1),
    );
    _onRemove = onRemove;
    final oldPrefixLength = _leadingMarkerLength(text);
    final draft = stripObjectReferenceMarkers(text);
    final nextPrefix = _markerPrefixFor(nextReferences);
    final nextText = '$nextPrefix$draft';
    final sameReferences = _sameReferences(_objectReferences, nextReferences);
    _objectReferences = nextReferences;
    if (text == nextText && sameReferences) {
      return;
    }
    final selectionOffset = selection.isValid
        ? selection.extentOffset.clamp(0, text.length)
        : text.length;
    final draftOffset = (selectionOffset - oldPrefixLength).clamp(
      0,
      draft.length,
    );
    final nextOffset = (nextPrefix.length + draftOffset).clamp(
      0,
      nextText.length,
    );
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
      composing: TextRange.empty,
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_objectReferences.isEmpty || !text.contains(_objectReferenceMarker)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final spans = <InlineSpan>[];
    var referenceIndex = 0;
    var plainStart = 0;
    for (var index = 0; index < text.length; index++) {
      if (text[index] != _objectReferenceMarker ||
          referenceIndex >= _objectReferences.length) {
        continue;
      }
      if (plainStart < index) {
        spans.add(TextSpan(text: text.substring(plainStart, index)));
      }
      final reference = _objectReferences[referenceIndex];
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _InlineObjectReferenceToken(
            reference: reference,
            onRemove: _onRemove == null ? null : () => _onRemove!(reference),
          ),
        ),
      );
      referenceIndex += 1;
      plainStart = index + 1;
    }
    if (plainStart < text.length) {
      spans.add(TextSpan(text: text.substring(plainStart)));
    }
    return TextSpan(style: style, children: spans);
  }

  static String stripObjectReferenceMarkers(String value) {
    var draft = value;
    while (draft.startsWith(_objectReferenceMarker)) {
      draft = draft.substring(_objectReferenceMarker.length);
    }
    return draft;
  }

  static int _leadingMarkerLength(String value) {
    var length = 0;
    while (value.startsWith(_objectReferenceMarker, length)) {
      length += _objectReferenceMarker.length;
    }
    return length;
  }

  static String _markerPrefixFor(List<LingObjectReference> references) {
    return List<String>.filled(
      references.length,
      _objectReferenceMarker,
    ).join();
  }

  static bool _sameReferences(
    List<LingObjectReference> a,
    List<LingObjectReference> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index].kind != b[index].kind || a[index].id != b[index].id) {
        return false;
      }
    }
    return true;
  }
}

class _InlineObjectReferenceToken extends StatelessWidget {
  const _InlineObjectReferenceToken({required this.reference, this.onRemove});

  final LingObjectReference reference;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = _kindColor(reference.kind, palette);
    return Container(
      key: Key('ling_object_reference_pill_${reference.kind.wireName}'),
      height: 24,
      constraints: const BoxConstraints(maxWidth: 96),
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.only(left: 6, right: 2),
      decoration: BoxDecoration(
        color: palette.surfaceMuted.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.outline.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_kindIcon(reference.kind), size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${_shortKindLabel(reference.kind)} ${reference.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onRemove != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: palette.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _shortKindLabel(LingObjectReferenceKind kind) {
    return switch (kind) {
      LingObjectReferenceKind.event => '日程',
    };
  }

  IconData _kindIcon(LingObjectReferenceKind kind) {
    return switch (kind) {
      LingObjectReferenceKind.event => Icons.event_rounded,
    };
  }

  Color _kindColor(LingObjectReferenceKind kind, LingPalette palette) {
    return switch (kind) {
      LingObjectReferenceKind.event => palette.accent,
    };
  }
}
