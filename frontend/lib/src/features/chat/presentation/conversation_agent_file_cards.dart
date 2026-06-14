import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/chat/application/agent_file_data.dart';
import 'package:ling/src/features/chat/application/agent_file_reference.dart';
import 'package:ling/src/features/chat/data/agent_file_save_service.dart';
import 'package:ling/src/features/chat/presentation/conversation_card_chrome.dart';
import 'package:ling/src/features/chat/presentation/conversation_message_text.dart';
import 'package:ling/src/features/chat/presentation/voice_preview_control.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/font_size_preference.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/notice.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const Key _agentFileReportCardEdgeKey = Key('agent_file_report_card_edge');

class LingAgentFileReferenceList extends StatelessWidget {
  const LingAgentFileReferenceList({super.key, required this.references});

  final List<LingAgentFileReference> references;

  @override
  Widget build(BuildContext context) {
    if (references.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 4, top: 14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final reference in references)
            LingAgentFileReferenceCard(reference: reference),
        ],
      ),
    );
  }
}

class LingAgentAudioFileReferenceControl extends ConsumerStatefulWidget {
  const LingAgentAudioFileReferenceControl({
    super.key,
    required this.reference,
    this.onPlay,
    this.onLoadDuration,
    this.onStop,
  });

  final LingAgentFileReference reference;
  final Future<Duration> Function(String path)? onPlay;
  final Future<Duration> Function(String path)? onLoadDuration;
  final FutureOr<void> Function()? onStop;

  @override
  ConsumerState<LingAgentAudioFileReferenceControl> createState() =>
      _LingAgentAudioFileReferenceControlState();
}

class _LingAgentAudioFileReferenceControlState
    extends ConsumerState<LingAgentAudioFileReferenceControl> {
  Future<String>? _localAudioPathFuture;

  @override
  void didUpdateWidget(LingAgentAudioFileReferenceControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference.path != widget.reference.path) {
      _localAudioPathFuture = null;
    }
  }

  Future<String> _localAudioPath() {
    return _localAudioPathFuture ??= _prepareLocalAudioPath();
  }

  Future<String> _prepareLocalAudioPath() async {
    final data = await ref
        .read(agentFileRepositoryProvider)
        .getFileData(widget.reference.path);
    final directory = Directory(
      p.join(
        (await getTemporaryDirectory()).path,
        'ling_agent_audio_preview_v1',
      ),
    );
    await directory.create(recursive: true);
    final extension = _safeAudioExtension(data.filename, widget.reference.path);
    final file = File(
      p.join(directory.path, '${_audioPreviewCacheKey(data.path)}$extension'),
    );
    if (!await file.exists() || await file.length() != data.bytes.length) {
      await file.writeAsBytes(data.bytes, flush: false);
    }
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    return LingVoicePreviewControl(
      key: ValueKey('agent_audio_file_reference_${widget.reference.path}'),
      source: widget.reference.path,
      compact: true,
      embedded: false,
      isHighlighted: false,
      onPlay: (_) async {
        final callback = widget.onPlay;
        if (callback == null) {
          return Duration.zero;
        }
        return callback(await _localAudioPath());
      },
      onLoadDuration: widget.onLoadDuration == null
          ? null
          : (_) async => widget.onLoadDuration!(await _localAudioPath()),
      onStop: widget.onStop ?? () {},
    );
  }
}

class LingAgentFileReferenceCard extends ConsumerStatefulWidget {
  const LingAgentFileReferenceCard({super.key, required this.reference});

  final LingAgentFileReference reference;

  @override
  ConsumerState<LingAgentFileReferenceCard> createState() =>
      _LingAgentFileReferenceCardState();
}

class _LingAgentFileReferenceCardState
    extends ConsumerState<LingAgentFileReferenceCard> {
  Future<LingAgentFileData>? _previewFuture;

  @override
  void initState() {
    super.initState();
    _refreshPreviewFuture();
  }

  @override
  void didUpdateWidget(LingAgentFileReferenceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference.path != widget.reference.path ||
        oldWidget.reference.kind != widget.reference.kind) {
      _refreshPreviewFuture();
    }
  }

  void _refreshPreviewFuture() {
    _previewFuture = ref
        .read(agentFileRepositoryProvider)
        .getFileData(widget.reference.path);
  }

  @override
  Widget build(BuildContext context) {
    final previewFuture = _previewFuture;
    if (previewFuture == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<LingAgentFileData>(
      future: previewFuture,
      builder: (context, snapshot) {
        return _buildPreviewableCard(
          context,
          previewFuture,
          previewError: snapshot.error,
        );
      },
    );
  }

  Widget _buildPreviewableCard(
    BuildContext context,
    Future<LingAgentFileData> previewFuture, {
    Object? previewError,
  }) {
    final palette = context.palette;
    final isReportCard = widget.reference.kind == LingAgentFileKind.html;
    final cardWidth = (MediaQuery.sizeOf(context).width - 58).clamp(
      260.0,
      336.0,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('agent_file_card_${widget.reference.path}'),
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          unawaited(
            ref
                .read(analyticsTrackerProvider)
                .track(
                  'chat.generated_card.open',
                  surface: 'chat',
                  action: 'generated_card_open',
                  source: 'agent_file',
                  properties: <String, Object?>{
                    'card_type': widget.reference.kind.name,
                  },
                ),
          );
          showLingAgentFilePreview(
            context: context,
            loadFileData: ref.read(agentFileRepositoryProvider).getFileData,
            saveFileToLocal: ref
                .read(agentFileSaveServiceProvider)
                .saveFileToLocal,
            reference: widget.reference,
          );
        },
        child: LingConversationCardChrome(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              LingGlassSurface(
                width: cardWidth,
                height: isReportCard ? 228 : 216,
                radius: 18,
                tone: LingGlassSurfaceTone.elevated,
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        child: _LingAgentFileCardPreview(
                          reference: widget.reference,
                          future: previewFuture,
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.isDarkMode
                            ? palette.surfaceHigh.withValues(alpha: 0.34)
                            : palette.surface.withValues(alpha: 0.88),
                        border: Border(
                          top: BorderSide(
                            color: palette.dividerMuted.withValues(
                              alpha: context.isDarkMode ? 0.42 : 0.62,
                            ),
                            width: 0.6,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(13, 10, 12, 11),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: palette.accentSoft.withValues(
                                  alpha: context.isDarkMode ? 0.42 : 1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _iconForKind(widget.reference.kind),
                                color: palette.accent,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.reference.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    previewError == null
                                        ? _kindLabel(widget.reference.kind)
                                        : '文件暂不可用',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.textTertiary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: palette.controlSurface.withValues(
                                  alpha: context.isDarkMode ? 0.62 : 0.82,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.open_in_full_rounded,
                                size: 15,
                                color: palette.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isReportCard && context.isDarkMode)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: _agentFileReportCardEdgeKey,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: lingConversationFloatingEdgeBorderFor(
                          context,
                          palette,
                          strength: 1.45,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LingAgentFileCardPreview extends StatelessWidget {
  const _LingAgentFileCardPreview({
    required this.reference,
    required this.future,
  });

  final LingAgentFileReference reference;
  final Future<LingAgentFileData> future;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return FutureBuilder<LingAgentFileData>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return DecoratedBox(
            decoration: BoxDecoration(color: palette.surfaceMuted),
            child: Center(
              child: snapshot.hasError
                  ? _LingAgentFileCardPreviewError(kind: reference.kind)
                  : const GlassProgressIndicator.circular(
                      size: 18,
                      strokeWidth: 2,
                    ),
            ),
          );
        }
        return switch (reference.kind) {
          LingAgentFileKind.html => _LingHtmlCardThumbnail(
            html: data.text,
            fallbackTitle: reference.title,
          ),
          LingAgentFileKind.image => DecoratedBox(
            decoration: BoxDecoration(color: palette.surfaceMuted),
            child: Center(
              child: data.filename.toLowerCase().endsWith('.svg')
                  ? SvgPicture.memory(data.bytes, fit: BoxFit.cover)
                  : Image.memory(
                      data.bytes,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          LingAgentFileKind.audio => DecoratedBox(
            decoration: BoxDecoration(color: palette.surfaceMuted),
            child: Center(
              child: Icon(
                Icons.graphic_eq_rounded,
                color: palette.textSecondary.withValues(alpha: 0.62),
                size: 34,
              ),
            ),
          ),
          LingAgentFileKind.markdown => DecoratedBox(
            decoration: BoxDecoration(color: palette.surfaceMuted),
            child: ClipRect(
              child: IgnorePointer(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
                  child: LingAssistantMarkdown(
                    markdown: data.text,
                    fontSizeLevel: LingFontSizeLevel.small,
                  ),
                ),
              ),
            ),
          ),
          LingAgentFileKind.json ||
          LingAgentFileKind.text ||
          LingAgentFileKind.code => DecoratedBox(
            decoration: BoxDecoration(color: palette.surfaceMuted),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  reference.kind == LingAgentFileKind.json
                      ? _prettyJsonOrOriginal(data.text)
                      : data.text,
                  maxLines: 6,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
          _ => DecoratedBox(
            decoration: BoxDecoration(color: palette.surfaceMuted),
            child: Center(
              child: Icon(
                _iconForKind(reference.kind),
                color: palette.textTertiary,
                size: 34,
              ),
            ),
          ),
        };
      },
    );
  }
}

class _LingHtmlCardThumbnail extends StatelessWidget {
  const _LingHtmlCardThumbnail({
    required this.html,
    required this.fallbackTitle,
  });

  final String html;
  final String fallbackTitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final title = _extractHtmlPreviewTitle(html, fallbackTitle);
    final previewLines = _extractHtmlPreviewLines(html, title).take(3).toList();
    final backgroundColor = _htmlPrefersDarkChrome(html)
        ? palette.background
        : palette.surface;
    final bodyColor = _htmlPrefersDarkChrome(html)
        ? palette.textSecondary.withValues(alpha: 0.78)
        : palette.textSecondary.withValues(alpha: 0.86);

    return DecoratedBox(
      key: const Key('agent_file_html_thumbnail'),
      decoration: BoxDecoration(color: backgroundColor),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: palette.accent.withValues(
                  alpha: context.isDarkMode ? 0.58 : 0.72,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 17,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final (index, line) in previewLines.indexed) ...[
              SizedBox(
                width: double.infinity,
                child: Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (index < previewLines.length - 1) const SizedBox(height: 5),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> showLingAgentFilePreview({
  required BuildContext context,
  required Future<LingAgentFileData> Function(String path) loadFileData,
  required Future<AgentFileSaveResult> Function(LingAgentFileData data)
  saveFileToLocal,
  required LingAgentFileReference reference,
}) {
  final palette = context.palette;
  return showDialog<void>(
    context: context,
    barrierColor: palette.scrim.withValues(alpha: 0.78),
    builder: (context) {
      return Dialog.fullscreen(
        backgroundColor: palette.background,
        child: SafeArea(
          child: FutureBuilder<LingAgentFileData>(
            future: loadFileData(reference.path),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint(
                  '[Ling][AgentFilePreview] failed to load '
                  '${reference.path}: ${snapshot.error}',
                );
              }
              final data = snapshot.data;
              final chrome = _LingAgentFilePreviewChrome.from(
                context,
                dark:
                    reference.kind == LingAgentFileKind.html &&
                    data != null &&
                    _htmlPrefersDarkChrome(data.text),
              );
              return ColoredBox(
                color: chrome.background,
                child: Column(
                  children: [
                    _LingAgentFilePreviewHeader(
                      title: reference.title,
                      subtitle: _kindLabel(reference.kind),
                      chrome: chrome,
                      onClose: () => Navigator.of(context).pop(),
                      data: data,
                      onDownload: saveFileToLocal,
                    ),
                    Expanded(
                      child: snapshot.connectionState == ConnectionState.waiting
                          ? const Center(
                              child: GlassProgressIndicator.circular(),
                            )
                          : snapshot.hasError
                          ? _LingAgentFilePreviewError(error: snapshot.error)
                          : _LingAgentFilePreviewBody(
                              reference: reference,
                              data: data!,
                            ),
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

class _LingAgentFileCardPreviewError extends StatelessWidget {
  const _LingAgentFileCardPreviewError({required this.kind});

  final LingAgentFileKind kind;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: palette.controlSurface.withValues(
              alpha: context.isDarkMode ? 0.72 : 0.92,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: palette.outlineSoft.withValues(
                alpha: context.isDarkMode ? 0.34 : 0.5,
              ),
              width: 0.6,
            ),
          ),
          child: Icon(
            _iconForKind(kind),
            color: palette.textTertiary,
            size: 23,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '暂时无法预览',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LingAgentFilePreviewHeader extends StatelessWidget {
  const _LingAgentFilePreviewHeader({
    required this.title,
    required this.subtitle,
    required this.chrome,
    required this.onClose,
    required this.data,
    required this.onDownload,
  });

  final String title;
  final String subtitle;
  final _LingAgentFilePreviewChrome chrome;
  final VoidCallback onClose;
  final LingAgentFileData? data;
  final Future<AgentFileSaveResult> Function(LingAgentFileData data) onDownload;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: chrome.header),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 10, 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: chrome.title,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: chrome.subtitle, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (data != null) ...[
              _LingAgentFileDownloadButton(
                data: data!,
                chrome: chrome,
                onDownload: onDownload,
              ),
              const SizedBox(width: 8),
            ],
            LingGlassIconButton(
              onPressed: onClose,
              icon: Icons.close_rounded,
              size: 44,
              iconColor: chrome.closeForeground,
              tintColor: chrome.closeBackground,
            ),
          ],
        ),
      ),
    );
  }
}

class _LingAgentFileDownloadButton extends StatefulWidget {
  const _LingAgentFileDownloadButton({
    required this.data,
    required this.chrome,
    required this.onDownload,
  });

  final LingAgentFileData data;
  final _LingAgentFilePreviewChrome chrome;
  final Future<AgentFileSaveResult> Function(LingAgentFileData data) onDownload;

  @override
  State<_LingAgentFileDownloadButton> createState() =>
      _LingAgentFileDownloadButtonState();
}

class _LingAgentFileDownloadButtonState
    extends State<_LingAgentFileDownloadButton> {
  bool _isDownloading = false;

  Future<void> _download() async {
    if (_isDownloading) {
      return;
    }
    setState(() => _isDownloading = true);
    try {
      final result = await widget.onDownload(widget.data);
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
        '[Ling][AgentFilePreview] failed to save '
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
      key: const Key('agent_file_preview_download_button'),
      onPressed: _isDownloading ? null : () => unawaited(_download()),
      icon: _isDownloading ? Icons.more_horiz_rounded : Icons.download_rounded,
      size: 44,
      iconColor: widget.chrome.closeForeground,
      tintColor: widget.chrome.closeBackground,
      semanticLabel: _stringsFor(context).downloadToLocal,
    );
  }
}

class _LingAgentFilePreviewChrome {
  const _LingAgentFilePreviewChrome({
    required this.background,
    required this.header,
    required this.title,
    required this.subtitle,
    required this.closeBackground,
    required this.closeForeground,
  });

  final Color background;
  final Color header;
  final Color title;
  final Color subtitle;
  final Color closeBackground;
  final Color closeForeground;

  factory _LingAgentFilePreviewChrome.from(
    BuildContext context, {
    required bool dark,
  }) {
    final palette = context.palette;
    if (!dark) {
      return _LingAgentFilePreviewChrome(
        background: palette.surface,
        header: palette.surface,
        title: palette.textPrimary,
        subtitle: palette.textTertiary,
        closeBackground: palette.controlSurface,
        closeForeground: palette.textSecondary,
      );
    }
    return _LingAgentFilePreviewChrome(
      background: palette.background,
      header: palette.backgroundElevated,
      title: palette.textPrimary,
      subtitle: palette.textTertiary,
      closeBackground: palette.controlSurface,
      closeForeground: palette.textPrimary,
    );
  }
}

class _LingAgentFilePreviewBody extends StatelessWidget {
  const _LingAgentFilePreviewBody({
    required this.reference,
    required this.data,
  });

  final LingAgentFileReference reference;
  final LingAgentFileData data;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (reference.kind == LingAgentFileKind.html) {
      return _LingHtmlPreview(
        html: data.text,
        backgroundColor: _htmlPrefersDarkChrome(data.text)
            ? palette.background
            : palette.surface,
      );
    }
    return switch (reference.kind) {
      LingAgentFileKind.image => InteractiveViewer(
        minScale: 0.8,
        maxScale: 4,
        child: Center(
          child: data.filename.toLowerCase().endsWith('.svg')
              ? SvgPicture.memory(data.bytes, fit: BoxFit.contain)
              : Image.memory(data.bytes, fit: BoxFit.contain),
        ),
      ),
      LingAgentFileKind.markdown => _LingMarkdownFilePreview(
        markdown: data.text,
      ),
      LingAgentFileKind.audio => _LingTextPreview(
        text: '音频文件：${data.filename}',
      ),
      LingAgentFileKind.json => _LingJsonFilePreview(text: data.text),
      LingAgentFileKind.code => _LingTextPreview(text: data.text),
      LingAgentFileKind.text => _LingTextPreview(text: data.text),
      _ => _LingExternalFilePreview(reference: reference, data: data),
    };
  }
}

class _LingHtmlPreview extends StatefulWidget {
  const _LingHtmlPreview({required this.html, required this.backgroundColor});

  final String html;
  final Color backgroundColor;

  @override
  State<_LingHtmlPreview> createState() => _LingHtmlPreviewState();
}

class _LingHtmlPreviewState extends State<_LingHtmlPreview> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.backgroundColor)
      ..loadHtmlString(widget.html);
  }

  @override
  void didUpdateWidget(covariant _LingHtmlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backgroundColor != widget.backgroundColor) {
      _controller.setBackgroundColor(widget.backgroundColor);
    }
    if (oldWidget.html != widget.html) {
      _controller.loadHtmlString(widget.html);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('agent_file_html_webview'),
      color: widget.backgroundColor,
      child: WebViewWidget(controller: _controller),
    );
  }
}

class _LingMarkdownFilePreview extends StatelessWidget {
  const _LingMarkdownFilePreview({required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 28),
      child: LingAssistantMarkdown(markdown: markdown, selectable: true),
    );
  }
}

class _LingJsonFilePreview extends StatelessWidget {
  const _LingJsonFilePreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _LingTextPreview(text: _prettyJsonOrOriginal(text));
  }
}

class _LingTextPreview extends StatelessWidget {
  const _LingTextPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: SelectableText(
        text,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 14,
          height: 1.55,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

String _prettyJsonOrOriginal(String text) {
  try {
    final decoded = jsonDecode(text);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return text;
  }
}

class _LingExternalFilePreview extends StatefulWidget {
  const _LingExternalFilePreview({required this.reference, required this.data});

  final LingAgentFileReference reference;
  final LingAgentFileData data;

  @override
  State<_LingExternalFilePreview> createState() =>
      _LingExternalFilePreviewState();
}

class _LingExternalFilePreviewState extends State<_LingExternalFilePreview> {
  bool _isOpening = false;

  Future<void> _openExternal() async {
    if (_isOpening) {
      return;
    }
    setState(() => _isOpening = true);
    try {
      final directory = await getTemporaryDirectory();
      final cacheDir = Directory('${directory.path}/ling_agent_files');
      await cacheDir.create(recursive: true);
      final file = File(
        '${cacheDir.path}/${_safeFilename(widget.data.filename)}',
      );
      await file.writeAsBytes(widget.data.bytes, flush: true);
      final opened = await launchUrl(
        file.uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _showNotice('没有找到可以打开这个文件的应用');
      }
    } catch (error) {
      if (mounted) {
        _showNotice('打开失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  void _showNotice(String message) {
    showLingTopNotice(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconForKind(widget.reference.kind),
              color: palette.textTertiary,
              size: 42,
            ),
            const SizedBox(height: 14),
            Text(
              '当前文件不支持内置预览',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.data.filename,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            LingGlassButton(
              onPressed: _isOpening ? null : _openExternal,
              expand: false,
              minHeight: 44,
              radius: 18,
              tone: LingGlassSurfaceTone.muted,
              foregroundColor: palette.textPrimary,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isOpening)
                    GlassProgressIndicator.circular(
                      size: 16,
                      strokeWidth: 2,
                      color: palette.textPrimary,
                    )
                  else
                    const Icon(Icons.open_in_new_rounded, size: 18),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      '用其它应用打开',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LingAgentFilePreviewError extends StatelessWidget {
  const _LingAgentFilePreviewError({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: LingGlassSurface(
            radius: 24,
            tone: LingGlassSurfaceTone.elevated,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: palette.controlSurface.withValues(
                        alpha: context.isDarkMode ? 0.72 : 0.94,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: palette.outlineSoft.withValues(
                          alpha: context.isDarkMode ? 0.34 : 0.55,
                        ),
                        width: 0.6,
                      ),
                    ),
                    child: Icon(
                      Icons.insert_drive_file_outlined,
                      color: palette.textSecondary,
                      size: 27,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '文件暂时无法打开',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _friendlyAgentFileErrorMessage(error),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  LingGlassButton(
                    onPressed: () => Navigator.of(context).pop(),
                    expand: false,
                    minHeight: 42,
                    radius: 18,
                    tone: LingGlassSurfaceTone.muted,
                    foregroundColor: palette.textPrimary,
                    child: const Text('知道了'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _friendlyAgentFileErrorMessage(Object? error) {
  if (error is ApiException) {
    final message = error.message.toLowerCase();
    final cause = '${error.cause}'.toLowerCase();
    if (error.statusCode == 404 ||
        message.contains('workspace') ||
        message.contains('路径') ||
        cause.contains('outside workspace')) {
      return '这份文件的访问路径暂时不可用。';
    }
  }
  return '请稍后再试，或重新生成这份文件。';
}

IconData _iconForKind(LingAgentFileKind kind) {
  return switch (kind) {
    LingAgentFileKind.html => Icons.article_outlined,
    LingAgentFileKind.image => Icons.image_outlined,
    LingAgentFileKind.audio => Icons.graphic_eq_rounded,
    LingAgentFileKind.markdown || LingAgentFileKind.text => Icons.notes_rounded,
    LingAgentFileKind.code => Icons.code_rounded,
    LingAgentFileKind.json => Icons.data_object_rounded,
    LingAgentFileKind.pdf => Icons.picture_as_pdf_outlined,
    LingAgentFileKind.other => Icons.insert_drive_file_outlined,
  };
}

String _kindLabel(LingAgentFileKind kind) {
  return switch (kind) {
    LingAgentFileKind.html => 'HTML 报告',
    LingAgentFileKind.image => '图片',
    LingAgentFileKind.audio => '语音',
    LingAgentFileKind.markdown => 'Markdown 文档',
    LingAgentFileKind.code => '代码文件',
    LingAgentFileKind.text => '文本文件',
    LingAgentFileKind.json => 'JSON 数据',
    LingAgentFileKind.pdf => 'PDF 文件',
    LingAgentFileKind.other => '文件',
  };
}

String _safeAudioExtension(String filename, String fallbackPath) {
  final extension = p.extension(filename).toLowerCase().trim();
  if (_isSupportedPreviewAudioExtension(extension)) {
    return extension;
  }
  final fallback = p.extension(fallbackPath).toLowerCase().trim();
  if (_isSupportedPreviewAudioExtension(fallback)) {
    return fallback;
  }
  return '.wav';
}

bool _isSupportedPreviewAudioExtension(String extension) {
  return switch (extension) {
    '.mp3' || '.wav' || '.m4a' || '.aac' || '.caf' => true,
    _ => false,
  };
}

String _audioPreviewCacheKey(String value) {
  return base64Url
      .encode(utf8.encode(value))
      .replaceAll('=', '')
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}

LingStrings _stringsFor(BuildContext context) {
  return LingStrings(Localizations.localeOf(context).toLanguageTag());
}

String _extractHtmlPreviewTitle(String html, String fallbackTitle) {
  final h1 = _firstHtmlCapture(html, 'h1');
  if (h1.isNotEmpty) {
    return h1;
  }
  final title = _firstHtmlCapture(html, 'title');
  if (title.isNotEmpty) {
    return title;
  }
  return fallbackTitle.trim().isEmpty ? 'HTML 报告' : fallbackTitle.trim();
}

List<String> _extractHtmlPreviewLines(String html, String title) {
  final plainText = _htmlToPreviewText(html);
  final normalizedTitle = title.trim();
  return plainText
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && line != normalizedTitle)
      .toList(growable: false);
}

String _firstHtmlCapture(String html, String tag) {
  final match = RegExp(
    '<$tag[^>]*>(.*?)</$tag>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html);
  if (match == null) {
    return '';
  }
  return _htmlToPreviewText(match.group(1) ?? '').replaceAll('\n', ' ').trim();
}

String _htmlToPreviewText(String html) {
  return html
      .replaceAll(RegExp(r'<script\b[^>]*>.*?</script>', dotAll: true), ' ')
      .replaceAll(RegExp(r'<style\b[^>]*>.*?</style>', dotAll: true), ' ')
      .replaceAll(
        RegExp(
          r'</?(p|div|section|article|header|footer|h[1-6]|li|br)\b[^>]*>',
          caseSensitive: false,
        ),
        '\n',
      )
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}

bool _htmlPrefersDarkChrome(String html) {
  final lowered = html.toLowerCase();
  if (lowered.contains('color-scheme: dark') ||
      lowered.contains('color-scheme:dark')) {
    return true;
  }
  final backgroundMatch = RegExp(
    r'background(?:-color)?\s*:\s*(#[0-9a-f]{3,8}|rgb\([^)]+\)|black)\b',
  ).firstMatch(lowered);
  if (backgroundMatch == null) {
    return false;
  }
  final value = backgroundMatch.group(1) ?? '';
  if (value == 'black') {
    return true;
  }
  if (value.startsWith('#')) {
    final hex = value.substring(1);
    final normalized = hex.length == 3
        ? hex.split('').map((char) => '$char$char').join()
        : hex.padRight(6, '0').substring(0, 6);
    final color = int.tryParse(normalized, radix: 16);
    if (color == null) {
      return false;
    }
    final red = (color >> 16) & 0xff;
    final green = (color >> 8) & 0xff;
    final blue = color & 0xff;
    return red + green + blue < 240;
  }
  if (value.startsWith('rgb(')) {
    final channels = RegExp(
      r'\d+',
    ).allMatches(value).map((match) => int.parse(match.group(0)!)).toList();
    return channels.length >= 3 &&
        channels[0] + channels[1] + channels[2] < 240;
  }
  return false;
}

String _safeFilename(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'[\\/:*?"<>|\r\n]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (sanitized.isEmpty || sanitized.startsWith('.')) {
    return 'agent-file';
  }
  return sanitized;
}
