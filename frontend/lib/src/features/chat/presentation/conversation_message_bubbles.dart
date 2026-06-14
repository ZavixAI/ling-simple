import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/chat/application/agent_file_reference.dart';
import 'package:ling/src/features/chat/application/conversation_entry.dart';
import 'package:ling/src/features/chat/application/object_reference.dart';
import 'package:ling/src/features/chat/presentation/agent_markdown_image.dart';
import 'package:ling/src/features/chat/presentation/conversation_agent_file_cards.dart';
import 'package:ling/src/features/chat/presentation/conversation_card_chrome.dart';
import 'package:ling/src/features/chat/presentation/conversation_message_text.dart';
import 'package:ling/src/features/chat/presentation/conversation_typing_indicator.dart';
import 'package:ling/src/features/chat/presentation/object_reference_card.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/font_size_preference.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

class LingUserMessageBubble extends StatelessWidget {
  const LingUserMessageBubble({
    super.key,
    required this.entry,
    required this.radius,
    required this.fontSizeLevel,
    this.onOpenObjectReference,
  });

  final LingConversationEntry entry;
  final BorderRadius radius;
  final LingFontSizeLevel fontSizeLevel;
  final ValueChanged<LingObjectReference>? onOpenObjectReference;

  static const double _horizontalPadding = 20;
  static const double _verticalPadding = 16;
  static const double _maxBubbleWidth = 360;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final parsed = LingObjectReferenceCodec.parse(entry.text);
    final textEntry = parsed.references.isEmpty
        ? entry
        : LingConversationEntry(
            id: '${entry.id}_object_reference_text',
            entryType: entry.entryType,
            role: entry.role,
            text: parsed.remainingText,
            attachments: entry.attachments,
            isStreaming: entry.isStreaming,
            status: entry.status,
            createdAt: entry.createdAt,
            sessionId: entry.sessionId,
            messageId: entry.messageId,
            messageType: entry.messageType,
            metadata: entry.metadata,
          );
    final textStyle = TextStyle(
      fontSize: scaleLingFontSize(fontSizeLevel, 15),
      height: 1.55,
      color: palette.textPrimary,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxBubbleWidth),
      child: LingConversationCardChrome(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: radius,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _horizontalPadding,
              vertical: _verticalPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final reference in parsed.references) ...[
                  LingObjectReferenceCard(
                    reference: reference,
                    compact: true,
                    onTap: onOpenObjectReference == null
                        ? null
                        : () => onOpenObjectReference!(reference),
                  ),
                  if (reference != parsed.references.last ||
                      parsed.remainingText.isNotEmpty)
                    const SizedBox(height: 10),
                ],
                if (parsed.remainingText.isNotEmpty)
                  LingSelectableMessageText(entry: textEntry, style: textStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LingQuestionnaireResponseBubble extends StatelessWidget {
  const LingQuestionnaireResponseBubble({super.key, required this.response});

  final LingQuestionnaireResponse response;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isTimeout =
        response.status == LingQuestionnaireResponseStatus.timeoutDefault;
    return LingGlassSurface(
      radius: 22,
      tone: LingGlassSurfaceTone.muted,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      tintColor: palette.glassMutedTint.withValues(
        alpha: context.isDarkMode ? 0.58 : 0.72,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTimeout
                ? Icons.schedule_rounded
                : Icons.check_circle_outline_rounded,
            size: 17,
            color: palette.accent,
          ),
          const SizedBox(width: 7),
          Text(
            isTimeout ? '自动提交了问卷默认回答' : '提交了问卷回答',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class LingAssistantMessageContent extends StatefulWidget {
  const LingAssistantMessageContent({
    super.key,
    required this.entry,
    required this.strings,
    required this.fontSizeLevel,
    this.onActionPrompt,
    this.onLingAction,
    this.onQuestionnaireSubmit,
    this.questionnaireResponses = const <String, LingQuestionnaireResponse>{},
    this.canSubmitQuestionnaire = false,
    this.onOpenObjectReference,
    this.canCopy = false,
    this.canRetry = false,
    this.onCopyEntry,
    this.onRetryEntry,
    this.onPlayAudioPreview,
    this.onLoadAudioPreviewDuration,
    this.onStopAudioPreview,
  });

  final LingConversationEntry entry;
  final LingStrings strings;
  final LingFontSizeLevel fontSizeLevel;
  final ValueChanged<String>? onActionPrompt;
  final ValueChanged<LingChatAction>? onLingAction;
  final FutureOr<void> Function(LingQuestionnaireSubmission submission)?
  onQuestionnaireSubmit;
  final Map<String, LingQuestionnaireResponse> questionnaireResponses;
  final bool canSubmitQuestionnaire;
  final ValueChanged<LingObjectReference>? onOpenObjectReference;
  final bool canCopy;
  final bool canRetry;
  final Future<void> Function(LingConversationEntry entry)? onCopyEntry;
  final Future<void> Function(LingConversationEntry entry)? onRetryEntry;
  final Future<Duration> Function(String path)? onPlayAudioPreview;
  final Future<Duration> Function(String path)? onLoadAudioPreviewDuration;
  final FutureOr<void> Function()? onStopAudioPreview;

  @override
  State<LingAssistantMessageContent> createState() =>
      _LingAssistantMessageContentState();
}

class _LingAssistantMessageContentState
    extends State<LingAssistantMessageContent> {
  @override
  Widget build(BuildContext context) {
    final parsedReferences = LingObjectReferenceCodec.parse(widget.entry.text);
    final messageText = parsedReferences.remainingText;
    Widget markdownContent() {
      Widget markdownFor(String markdown) {
        return _LingAssistantMarkdownWithFileCards(
          markdown: markdown,
          selectable: true,
          fontSizeLevel: widget.fontSizeLevel,
          onActionPrompt: widget.onActionPrompt,
          onLingAction: widget.onLingAction,
          onQuestionnaireSubmit: widget.onQuestionnaireSubmit,
          questionnaireResponses: widget.questionnaireResponses,
          canSubmitQuestionnaire: widget.canSubmitQuestionnaire,
          questionnaireKeyPrefix: widget.entry.id,
          debugSourceId: _questionnaireDebugSourceId(widget.entry),
          onOpenObjectReference: widget.onOpenObjectReference,
          onPlayAudioPreview: widget.onPlayAudioPreview,
          onLoadAudioPreviewDuration: widget.onLoadAudioPreviewDuration,
          onStopAudioPreview: widget.onStopAudioPreview,
        );
      }

      return _LingStreamingTextReveal(
        text: messageText,
        animate: widget.entry.isStreaming,
        builder: markdownFor,
      );
    }

    if (parsedReferences.references.isEmpty) {
      return markdownContent();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final reference in parsedReferences.references) ...[
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 4, bottom: 8),
            child: LingObjectReferenceCard(
              reference: reference,
              compact: true,
              onTap: widget.onOpenObjectReference == null
                  ? null
                  : () => widget.onOpenObjectReference!(reference),
            ),
          ),
        ],
        if (messageText.isNotEmpty) markdownContent(),
      ],
    );
  }
}

class _LingAssistantMarkdownWithFileCards extends StatelessWidget {
  const _LingAssistantMarkdownWithFileCards({
    required this.markdown,
    this.selectable = false,
    this.fontSizeLevel = LingFontSizeLevel.fallback,
    this.onActionPrompt,
    this.onLingAction,
    this.onQuestionnaireSubmit,
    this.questionnaireResponses = const <String, LingQuestionnaireResponse>{},
    this.canSubmitQuestionnaire = false,
    this.questionnaireKeyPrefix,
    this.debugSourceId,
    this.onOpenObjectReference,
    this.onPlayAudioPreview,
    this.onLoadAudioPreviewDuration,
    this.onStopAudioPreview,
  });

  final String markdown;
  final bool selectable;
  final LingFontSizeLevel fontSizeLevel;
  final ValueChanged<String>? onActionPrompt;
  final ValueChanged<LingChatAction>? onLingAction;
  final FutureOr<void> Function(LingQuestionnaireSubmission submission)?
  onQuestionnaireSubmit;
  final Map<String, LingQuestionnaireResponse> questionnaireResponses;
  final bool canSubmitQuestionnaire;
  final String? questionnaireKeyPrefix;
  final String? debugSourceId;
  final ValueChanged<LingObjectReference>? onOpenObjectReference;
  final Future<Duration> Function(String path)? onPlayAudioPreview;
  final Future<Duration> Function(String path)? onLoadAudioPreviewDuration;
  final FutureOr<void> Function()? onStopAudioPreview;

  @override
  Widget build(BuildContext context) {
    final spans = parseLingAgentFileReferenceSpans(
      markdown,
    ).spans.where(_shouldPromoteFileReference).toList(growable: false);
    if (spans.isEmpty) {
      return _markdown(markdown);
    }

    final children = <Widget>[];
    var cursor = 0;
    for (final span in spans) {
      final segment = _promotionSegmentFor(span);
      if (segment.start < cursor || segment.end > markdown.length) {
        continue;
      }
      _addMarkdownSegment(children, markdown.substring(cursor, segment.start));
      _addPromotedReference(children, segment.reference);
      cursor = segment.end;
    }
    _addMarkdownSegment(children, markdown.substring(cursor));

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  bool _shouldPromoteFileReference(LingAgentFileReferenceSpan span) {
    return true;
  }

  _PromotedFileReferenceSegment _promotionSegmentFor(
    LingAgentFileReferenceSpan span,
  ) {
    final lineStart = span.start == 0
        ? 0
        : markdown.lastIndexOf('\n', span.start - 1) + 1;
    final nextBreak = markdown.indexOf('\n', span.end);
    final lineContentEnd = nextBreak < 0 ? markdown.length : nextBreak;
    final lineEnd = nextBreak < 0 ? markdown.length : nextBreak + 1;
    final beforeLink = markdown.substring(lineStart, span.start);
    final afterLink = markdown.substring(span.end, lineContentEnd);
    final isBareListItem =
        RegExp(r'^[ \t]{0,3}(?:[-+*]|\d+[.)])[ \t]+$').hasMatch(beforeLink) &&
        afterLink.trim().isEmpty;
    if (isBareListItem) {
      return _PromotedFileReferenceSegment(
        reference: span.reference,
        start: lineStart,
        end: lineEnd,
      );
    }
    return _PromotedFileReferenceSegment(
      reference: span.reference,
      start: span.start,
      end: span.end,
    );
  }

  void _addMarkdownSegment(List<Widget> children, String segment) {
    final normalized = segment.trim();
    if (normalized.isEmpty) {
      return;
    }
    _addGap(children);
    children.add(_markdown(normalized));
  }

  void _addPromotedReference(
    List<Widget> children,
    LingAgentFileReference reference,
  ) {
    _addGap(children);
    if (reference.kind == LingAgentFileKind.image) {
      children.add(
        LingMarkdownAgentImage(path: reference.path, alt: reference.title),
      );
      return;
    }
    if (reference.kind == LingAgentFileKind.audio) {
      children.add(
        SelectionContainer.disabled(
          child: Padding(
            padding: const EdgeInsets.only(left: 6, right: 4),
            child: LingAgentAudioFileReferenceControl(
              reference: reference,
              onPlay: onPlayAudioPreview,
              onLoadDuration: onLoadAudioPreviewDuration,
              onStop: onStopAudioPreview,
            ),
          ),
        ),
      );
      return;
    }
    children.add(
      SelectionContainer.disabled(
        child: Padding(
          padding: const EdgeInsets.only(left: 6, right: 4),
          child: LingAgentFileReferenceCard(reference: reference),
        ),
      ),
    );
  }

  void _addGap(List<Widget> children) {
    if (children.isNotEmpty) {
      children.add(const SizedBox(height: 12));
    }
  }

  Widget _markdown(String value) {
    return LingAssistantMarkdown(
      markdown: value,
      selectable: selectable,
      fontSizeLevel: fontSizeLevel,
      onActionPrompt: onActionPrompt,
      onLingAction: onLingAction,
      onQuestionnaireSubmit: onQuestionnaireSubmit,
      questionnaireResponses: questionnaireResponses,
      canSubmitQuestionnaire: canSubmitQuestionnaire,
      questionnaireKeyPrefix: questionnaireKeyPrefix,
      debugSourceId: debugSourceId,
      onOpenObjectReference: onOpenObjectReference,
    );
  }
}

class _PromotedFileReferenceSegment {
  const _PromotedFileReferenceSegment({
    required this.reference,
    required this.start,
    required this.end,
  });

  final LingAgentFileReference reference;
  final int start;
  final int end;
}

class _LingStreamingTextReveal extends StatefulWidget {
  const _LingStreamingTextReveal({
    required this.text,
    required this.animate,
    required this.builder,
  });

  final String text;
  final bool animate;
  final Widget Function(String text) builder;

  @override
  State<_LingStreamingTextReveal> createState() =>
      _LingStreamingTextRevealState();
}

class _LingStreamingTextRevealState extends State<_LingStreamingTextReveal> {
  @override
  Widget build(BuildContext context) {
    return widget.builder(widget.text);
  }
}

class LingAssistantLoadingBubble extends StatelessWidget {
  const LingAssistantLoadingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('assistant_loading_indicator'),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: LingTypingIndicator(dotSize: 6),
    );
  }
}

String _questionnaireDebugSourceId(LingConversationEntry entry) {
  final sessionId = entry.sessionId?.trim();
  final messageType = entry.messageType?.trim();
  return [
    entry.id,
    if (sessionId != null && sessionId.isNotEmpty) 'session=$sessionId',
    if (messageType != null && messageType.isNotEmpty) 'type=$messageType',
    'role=${entry.role.name}',
    'entry=${entry.entryType.name}',
  ].join(' ');
}
