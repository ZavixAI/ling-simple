import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ling/src/features/chat/application/conversation_attachment.dart';
import 'package:ling/src/features/chat/application/conversation_entry.dart';
import 'package:ling/src/features/chat/application/object_reference.dart';
import 'package:ling/src/features/chat/presentation/conversation_attachment_view.dart';
import 'package:ling/src/features/chat/presentation/conversation_entry_actions.dart';
import 'package:ling/src/features/chat/presentation/conversation_message_bubbles.dart';
import 'package:ling/src/features/chat/presentation/conversation_message_text.dart';
import 'package:ling/src/features/chat/presentation/conversation_timestamp_view.dart';
import 'package:ling/src/features/chat/presentation/conversation_tool_call_cards.dart';
import 'package:ling/src/features/chat/presentation/conversation_tool_call_display.dart';
import 'package:ling/src/features/chat/presentation/voice_preview_control.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/font_size_preference.dart';

export 'conversation_message_text.dart'
    show
        LingAssistantMarkdown,
        LingChatAction,
        LingChatActionKind,
        LingChatActionTarget,
        LingQuestionnaireResponse,
        LingQuestionnaireResponseStatus,
        LingQuestionnaireSubmission,
        LingSelectableMessageText;
export 'conversation_queue_sheet.dart'
    show LingConversationLoadMoreButton, showLingQueuedPromptSheet;
export 'conversation_timestamp_view.dart' show LingConversationStartedAtLabel;
export 'conversation_tool_flow_view.dart' show LingToolFlowGroupView;
export 'conversation_typing_indicator.dart' show LingTypingIndicator;

class LingConversationEntryView extends StatelessWidget {
  const LingConversationEntryView({
    super.key,
    required this.entry,
    required this.strings,
    required this.onPreviewAttachment,
    this.onPlayAudioPreview,
    this.onLoadAudioPreviewDuration,
    this.onStopAudioPreview,
    this.fontSizeLevel = LingFontSizeLevel.fallback,
    this.onOpenLingEvent,
    this.onCopyEntry,
    this.onRetryEntry,
    this.onActionPrompt,
    this.onLingAction,
    this.onQuestionnaireSubmit,
    this.questionnaireResponses = const <String, LingQuestionnaireResponse>{},
    this.canSubmitQuestionnaire = false,
  });

  final LingConversationEntry entry;
  final LingStrings strings;
  final ValueChanged<LingConversationAttachment> onPreviewAttachment;
  final Future<Duration> Function(String path)? onPlayAudioPreview;
  final Future<Duration> Function(String path)? onLoadAudioPreviewDuration;
  final FutureOr<void> Function()? onStopAudioPreview;
  final LingFontSizeLevel fontSizeLevel;
  final ValueChanged<String>? onOpenLingEvent;
  final Future<void> Function(LingConversationEntry entry)? onCopyEntry;
  final Future<void> Function(LingConversationEntry entry)? onRetryEntry;
  final ValueChanged<String>? onActionPrompt;
  final ValueChanged<LingChatAction>? onLingAction;
  final FutureOr<void> Function(LingQuestionnaireSubmission submission)?
  onQuestionnaireSubmit;
  final Map<String, LingQuestionnaireResponse> questionnaireResponses;
  final bool canSubmitQuestionnaire;

  @override
  Widget build(BuildContext context) {
    final isUser = entry.role == LingConversationRole.user;
    final questionnaireResponse = isUser
        ? _questionnaireResponseForEntry(entry)
        : null;
    final toolCallDisplay =
        entry.entryType == LingConversationEntryType.toolCall
        ? buildLingToolCallDisplayState(entry)
        : null;
    final hasText = entry.text.trim().isNotEmpty;
    final audioAttachments = entry.attachments
        .where((attachment) => attachment.isAudio)
        .toList(growable: false);
    final visualAttachments = entry.attachments
        .where((attachment) => !attachment.isAudio)
        .toList(growable: false);
    final hasAttachments = entry.attachments.isNotEmpty;

    if (entry.entryType == LingConversationEntryType.toolCall) {
      if (toolCallDisplay?.variant == LingToolCallDisplayVariant.hidden) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: LingToolCallEntryCard(
          display: toolCallDisplay ?? const LingToolCallDisplayState.hidden(),
          onOpenLingEvent: onOpenLingEvent,
        ),
      );
    }

    final showsAssistantLoadingBubble =
        !isUser &&
        entry.entryType != LingConversationEntryType.toolCall &&
        entry.isStreaming &&
        entry.text.trim().isEmpty &&
        entry.attachments.isEmpty;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(30),
      topRight: const Radius.circular(30),
      bottomLeft: Radius.circular(isUser ? 30 : 10),
      bottomRight: Radius.circular(isUser ? 10 : 30),
    );
    final canCopy = canCopyLingConversationEntry(entry) && onCopyEntry != null;
    final canRetry =
        canRetryLingConversationEntry(entry) && onRetryEntry != null;
    void openObjectReference(LingObjectReference reference) {
      switch (reference.kind) {
        case LingObjectReferenceKind.event:
          onOpenLingEvent?.call(reference.id);
      }
    }

    final content = Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showsAssistantLoadingBubble)
            const LingAssistantLoadingBubble()
          else if (questionnaireResponse != null)
            LingQuestionnaireResponseBubble(response: questionnaireResponse)
          else if (hasText)
            isUser
                ? LingUserMessageBubble(
                    entry: entry,
                    radius: radius,
                    fontSizeLevel: fontSizeLevel,
                    onOpenObjectReference: openObjectReference,
                  )
                : LingAssistantMessageContent(
                    entry: entry,
                    strings: strings,
                    fontSizeLevel: fontSizeLevel,
                    onActionPrompt: onActionPrompt,
                    onLingAction: onLingAction,
                    onQuestionnaireSubmit: onQuestionnaireSubmit,
                    questionnaireResponses: questionnaireResponses,
                    canSubmitQuestionnaire: canSubmitQuestionnaire,
                    onOpenObjectReference: openObjectReference,
                    canCopy: canCopy,
                    canRetry: canRetry,
                    onCopyEntry: onCopyEntry,
                    onRetryEntry: onRetryEntry,
                    onPlayAudioPreview: onPlayAudioPreview,
                    onLoadAudioPreviewDuration: onLoadAudioPreviewDuration,
                    onStopAudioPreview: onStopAudioPreview,
                  ),
          if (audioAttachments.isNotEmpty) ...[
            if (hasText) const SizedBox(height: 8),
            SelectionContainer.disabled(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: isUser ? WrapAlignment.end : WrapAlignment.start,
                children: [
                  for (final attachment in audioAttachments)
                    SizedBox(
                      key: ValueKey(
                        'conversation_audio_attachment_${attachment.attachmentId}',
                      ),
                      child: LingVoicePreviewControl(
                        source: attachment.audioUrl,
                        compact: true,
                        embedded: isUser,
                        isHighlighted: false,
                        onPlay: (path) {
                          final callback = onPlayAudioPreview;
                          if (callback != null) {
                            return callback(path);
                          }
                          onPreviewAttachment(attachment);
                          return Future<Duration>.value(Duration.zero);
                        },
                        onLoadDuration: onLoadAudioPreviewDuration,
                        onStop: onStopAudioPreview ?? () {},
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (visualAttachments.isNotEmpty) ...[
            if (hasText || audioAttachments.isNotEmpty)
              const SizedBox(height: 12),
            SelectionContainer.disabled(
              child: isUser
                  ? _UserVisualAttachmentStrip(
                      attachments: visualAttachments,
                      isHighlighted: false,
                      onPreviewAttachment: onPreviewAttachment,
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: visualAttachments
                          .map(
                            (attachment) => LingConversationAttachmentCard(
                              attachment: attachment,
                              showFilename: true,
                              isHighlighted: false,
                              onTap: () => onPreviewAttachment(attachment),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
          if (entry.entryType != LingConversationEntryType.toolCall &&
              (hasText || hasAttachments || questionnaireResponse != null))
            SelectionContainer.disabled(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 6,
                  left: isUser ? 0 : 6,
                  right: isUser ? 2 : 0,
                ),
                child: LingConversationEntryMeta(
                  entry: entry,
                  isUser: isUser,
                  canCopy: canCopy,
                  canRetry: canRetry,
                  onCopy: onCopyEntry,
                  onRetry: onRetryEntry,
                ),
              ),
            ),
        ],
      ),
    );
    if (!isUser) {
      return content;
    }

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: content,
      ),
    );
  }
}

LingQuestionnaireResponse? _questionnaireResponseForEntry(
  LingConversationEntry entry,
) {
  final agentText = entry.metadata?['agent_text'];
  if (agentText is String) {
    final response = LingQuestionnaireResponse.fromAgentText(agentText);
    if (response != null) {
      return response;
    }
  }
  return LingQuestionnaireResponse.fromAgentText(entry.text);
}

class _UserVisualAttachmentStrip extends StatelessWidget {
  const _UserVisualAttachmentStrip({
    required this.attachments,
    required this.isHighlighted,
    required this.onPreviewAttachment,
  });

  static const double _thumbnailSize = 64;
  static const double _thumbnailGap = 8;

  final List<LingConversationAttachment> attachments;
  final bool isHighlighted;
  final ValueChanged<LingConversationAttachment> onPreviewAttachment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          key: const Key('conversation_user_attachment_strip'),
          height: _thumbnailSize,
          width: constraints.maxWidth,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var index = 0; index < attachments.length; index++) ...[
                    if (index > 0) const SizedBox(width: _thumbnailGap),
                    LingConversationAttachmentCard(
                      attachment: attachments[index],
                      showFilename: false,
                      compact: true,
                      size: _thumbnailSize,
                      isHighlighted: isHighlighted,
                      onTap: () => onPreviewAttachment(attachments[index]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
