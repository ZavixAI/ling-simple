import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/chat/application/object_reference.dart';

class LingObjectReferenceCard extends StatelessWidget {
  const LingObjectReferenceCard({
    super.key,
    required this.reference,
    this.compact = false,
    this.onRemove,
    this.onTap,
  });

  final LingObjectReference reference;
  final bool compact;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = _kindLabel(reference.kind);
    final subtitle = _subtitle(reference);
    final radius = BorderRadius.circular(14);
    final content = Container(
      constraints: BoxConstraints(maxWidth: compact ? 360 : 430),
      padding: EdgeInsets.fromLTRB(12, compact ? 9 : 11, 8, compact ? 9 : 11),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: compact ? 30 : 34,
            height: compact ? 30 : 34,
            decoration: BoxDecoration(
              color: _kindColor(
                reference.kind,
                palette,
              ).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _kindIcon(reference.kind),
              size: compact ? 17 : 19,
              color: _kindColor(reference.kind, palette),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: compact ? 11.5 : 12,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  reference.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: compact ? 13.5 : 14.5,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: compact ? 11.5 : 12.5,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null && onRemove == null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: palette.textTertiary,
            ),
          ],
          if (onRemove != null) ...[
            const SizedBox(width: 6),
            IconButton(
              key: Key(
                'ling_object_reference_remove_${reference.kind.wireName}',
              ),
              tooltip: '移除引用',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: onRemove,
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: palette.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
    return Material(
      key: Key('ling_object_reference_${reference.kind.wireName}'),
      color: palette.surfaceMuted.withValues(alpha: 0.78),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: palette.outline.withValues(alpha: 0.35)),
          ),
          child: content,
        ),
      ),
    );
  }

  String _subtitle(LingObjectReference reference) {
    final explicit = (reference.subtitle ?? '').trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    return reference.summaryFields.values
        .where((value) => value.trim().isNotEmpty)
        .take(2)
        .join(' · ');
  }

  String _kindLabel(LingObjectReferenceKind kind) {
    return switch (kind) {
      LingObjectReferenceKind.event => '日程引用',
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

class LingObjectReferencePill extends StatelessWidget {
  const LingObjectReferencePill({
    super.key,
    required this.reference,
    this.onRemove,
  });

  final LingObjectReference reference;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = _shortKindLabel(reference.kind);
    return Container(
      key: Key('ling_object_reference_pill_${reference.kind.wireName}'),
      height: 28,
      constraints: const BoxConstraints(maxWidth: 104),
      decoration: BoxDecoration(
        color: palette.surfaceMuted.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.outline.withValues(alpha: 0.28)),
      ),
      padding: const EdgeInsets.only(left: 6, right: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _kindColor(
                reference.kind,
                palette,
              ).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              _kindIcon(reference.kind),
              size: 13,
              color: _kindColor(reference.kind, palette),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(
                    text: '$label ',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: reference.title),
                ],
              ),
            ),
          ),
          if (onRemove != null) ...[
            InkResponse(
              key: Key(
                'ling_object_reference_pill_remove_${reference.kind.wireName}',
              ),
              radius: 13,
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ],
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
