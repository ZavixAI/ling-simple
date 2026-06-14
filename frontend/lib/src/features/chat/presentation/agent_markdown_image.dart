import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/chat/application/agent_file_data.dart';
import 'package:ling/src/features/chat/data/agent_file_save_service.dart';
import 'package:ling/src/features/chat/presentation/conversation_image_preview_surface.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/notice.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

final _agentFileDataProvider = FutureProvider.autoDispose
    .family<LingAgentFileData, String>((ref, path) {
      final link = ref.keepAlive();
      Timer? disposeTimer;
      ref.onCancel(() {
        disposeTimer = Timer(const Duration(minutes: 5), link.close);
      });
      ref.onResume(() {
        disposeTimer?.cancel();
        disposeTimer = null;
      });
      ref.onDispose(() {
        disposeTimer?.cancel();
      });
      return ref.read(agentFileRepositoryProvider).getFileData(path);
    });

class LingMarkdownAgentImage extends ConsumerWidget {
  const LingMarkdownAgentImage({
    super.key,
    required this.path,
    this.alt,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.fit = BoxFit.contain,
    this.minPreviewAspectRatio,
  });

  final String path;
  final String? alt;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final double? minPreviewAspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final fileData = ref.watch(_agentFileDataProvider(path));
    return fileData.when(
      loading: () {
        return Container(
          key: ValueKey<String>('ling_markdown_agent_image_loading_$path'),
          constraints: const BoxConstraints(minHeight: 120),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const GlassProgressIndicator.circular(
            size: 18,
            strokeWidth: 2,
          ),
        );
      },
      error: (_, _) => Container(
        key: ValueKey<String>('ling_markdown_agent_image_error_$path'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          alt?.isNotEmpty == true ? alt! : path,
          style: TextStyle(color: palette.textTertiary, fontSize: 13),
        ),
      ),
      data: (data) {
        final isSvg = data.filename.toLowerCase().endsWith('.svg');
        final rawImage = isSvg
            ? SvgPicture.memory(data.bytes, semanticsLabel: alt, fit: fit)
            : Image.memory(
                data.bytes,
                semanticLabel: alt,
                fit: fit,
                gaplessPlayback: true,
              );
        final image = minPreviewAspectRatio == null || isSvg
            ? rawImage
            : FutureBuilder<double?>(
                future: decodeLingConversationImageAspectRatio(data.bytes),
                builder: (context, snapshot) {
                  final originalAspectRatio = snapshot.data;
                  final previewAspectRatio =
                      originalAspectRatio == null || originalAspectRatio <= 0
                      ? minPreviewAspectRatio!
                      : math.max(originalAspectRatio, minPreviewAspectRatio!);
                  return AspectRatio(
                    aspectRatio: previewAspectRatio,
                    child: rawImage,
                  );
                },
              );
        final hasRoundedCorners = borderRadius != BorderRadius.zero;
        return GestureDetector(
          key: ValueKey<String>('ling_markdown_agent_image_tap_$path'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _showMarkdownImagePreview(context, ref, data, alt),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: KeyedSubtree(
              key: ValueKey<String>('ling_markdown_agent_image_$path'),
              child: hasRoundedCorners
                  ? ClipRRect(borderRadius: borderRadius, child: image)
                  : image,
            ),
          ),
        );
      },
    );
  }
}

Future<void> _showMarkdownImagePreview(
  BuildContext context,
  WidgetRef ref,
  LingAgentFileData data,
  String? alt,
) {
  final palette = context.palette;
  final isSvg = data.filename.toLowerCase().endsWith('.svg');
  final aspectRatio = isSvg
      ? Future<double?>.value()
      : decodeLingConversationImageAspectRatio(data.bytes);
  return showDialog<void>(
    context: context,
    barrierColor: palette.scrim.withValues(alpha: 0.88),
    builder: (dialogContext) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: FutureBuilder<double?>(
            future: aspectRatio,
            builder: (context, snapshot) {
              return LingConversationImagePreviewSurface(
                aspectRatio: snapshot.data,
                image: isSvg
                    ? SvgPicture.memory(
                        data.bytes,
                        semanticsLabel: alt,
                        fit: BoxFit.contain,
                      )
                    : Image.memory(
                        data.bytes,
                        semanticLabel: alt,
                        fit: BoxFit.contain,
                      ),
                controls: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LingMarkdownImageDownloadButton(data: data, ref: ref),
                    const SizedBox(width: 10),
                    LingGlassIconButton(
                      key: const Key('markdown_image_preview_close_button'),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: Icons.close_rounded,
                      semanticLabel: MaterialLocalizations.of(
                        dialogContext,
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

class _LingMarkdownImageDownloadButton extends StatefulWidget {
  const _LingMarkdownImageDownloadButton({
    required this.data,
    required this.ref,
  });

  final LingAgentFileData data;
  final WidgetRef ref;

  @override
  State<_LingMarkdownImageDownloadButton> createState() =>
      _LingMarkdownImageDownloadButtonState();
}

class _LingMarkdownImageDownloadButtonState
    extends State<_LingMarkdownImageDownloadButton> {
  bool _isDownloading = false;

  Future<void> _download() async {
    if (_isDownloading) {
      return;
    }
    setState(() => _isDownloading = true);
    try {
      final result = await widget.ref
          .read(agentFileSaveServiceProvider)
          .saveFileToLocal(widget.data);
      if (!mounted) {
        return;
      }
      final strings = _stringsFor(context);
      switch (result.status) {
        case AgentFileSaveStatus.success:
          showLingTopNotice(context, strings.savedToLocal);
        case AgentFileSaveStatus.unsupported:
          showLingTopNotice(context, strings.saveUnsupported);
        case AgentFileSaveStatus.failed:
          showLingTopNotice(context, strings.saveFailed);
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[Ling][MarkdownImagePreview] failed to save '
        '${widget.data.path}: $error\n$stackTrace',
      );
      if (mounted) {
        showLingTopNotice(context, _stringsFor(context).saveFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LingGlassIconButton(
      key: const Key('markdown_image_preview_download_button'),
      onPressed: _isDownloading ? null : () => unawaited(_download()),
      icon: _isDownloading ? Icons.more_horiz_rounded : Icons.download_rounded,
      semanticLabel: _stringsFor(context).downloadToLocal,
    );
  }
}

LingStrings _stringsFor(BuildContext context) {
  return LingStrings(Localizations.localeOf(context).toLanguageTag());
}
