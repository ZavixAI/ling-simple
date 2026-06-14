import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/chat/application/conversation_attachment.dart';
import 'package:ling/src/features/chat/presentation/conversation_card_chrome.dart';
import 'package:ling/src/features/chat/presentation/conversation_image_preview_surface.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

Future<void> showLingConversationAttachmentPreview({
  required BuildContext context,
  required LingConversationAttachment attachment,
  String? downloadTooltip,
  Future<void> Function()? onDownload,
}) {
  final palette = context.palette;
  final aspectRatio = attachment.bytes == null
      ? Future<double?>.value()
      : decodeLingConversationImageAspectRatio(attachment.bytes!);
  return showDialog<void>(
    context: context,
    barrierColor: palette.scrim.withValues(alpha: 0.88),
    builder: (context) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: FutureBuilder<double?>(
            future: aspectRatio,
            builder: (context, snapshot) {
              return LingConversationImagePreviewSurface(
                aspectRatio: snapshot.data,
                image: attachment.bytes != null
                    ? Image.memory(attachment.bytes!, fit: BoxFit.contain)
                    : attachment.url.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: attachment.url,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const SizedBox.shrink(),
                        errorWidget: (context, url, error) =>
                            const SizedBox.shrink(),
                      )
                    : const SizedBox.shrink(),
                controls: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onDownload != null) ...[
                      LingGlassIconButton(
                        key: const Key('attachment_preview_download_button'),
                        onPressed: () => unawaited(onDownload()),
                        icon: Icons.download_rounded,
                        semanticLabel: downloadTooltip,
                      ),
                      const SizedBox(width: 10),
                    ],
                    LingGlassIconButton(
                      key: const Key('attachment_preview_close_button'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icons.close_rounded,
                      semanticLabel: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

class LingConversationAttachmentCard extends StatelessWidget {
  const LingConversationAttachmentCard({
    super.key,
    required this.attachment,
    required this.showFilename,
    this.compact = false,
    this.size = 72,
    this.isHighlighted = false,
    required this.onTap,
  });

  final LingConversationAttachment attachment;
  final bool showFilename;
  final bool compact;
  final double size;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = compact ? 14.0 : 22.0;
    final effectiveShowFilename = showFilename && !compact;

    return Material(
      key: Key('conversation_attachment_${attachment.attachmentId}'),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: LingConversationCardChrome(
          borderRadius: BorderRadius.circular(radius),
          child: LingGlassSurface(
            width: compact ? size : 168,
            height: compact ? size : null,
            radius: radius,
            tone: LingGlassSurfaceTone.elevated,
            tintColor: isHighlighted
                ? palette.accent.withValues(alpha: 0.28)
                : null,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: compact ? size : 124,
                  width: double.infinity,
                  child: _LingAttachmentImage(attachment: attachment),
                ),
                if (effectiveShowFilename)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Text(
                      attachment.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LingAttachmentImage extends StatelessWidget {
  const _LingAttachmentImage({required this.attachment});

  final LingConversationAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (attachment.bytes != null) {
      return Image.memory(attachment.bytes!, fit: BoxFit.cover);
    }
    if (attachment.url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: attachment.url,
        fit: BoxFit.cover,
        placeholder: (context, url) => ColoredBox(color: palette.surfaceMuted),
        errorWidget: (context, url, error) =>
            ColoredBox(color: palette.surfaceMuted),
      );
    }
    return ColoredBox(color: palette.surfaceMuted);
  }
}
