import 'package:ling/src/features/chat/application/conversation_attachment.dart';
import 'package:ling/src/features/chat/application/conversation_entry.dart';
import 'package:ling/src/features/chat/application/object_reference.dart';
import 'package:ling/src/features/chat/application/pending_prompt_request.dart';

String buildLingQueuedPromptPreview({
  required LingPendingPromptRequest request,
  required String Function(int attachmentCount) queuedImageMessageBuilder,
  int maxCharacters = 18,
}) {
  final parsedPrompt = LingObjectReferenceCodec.parse(
    request.displayText ?? request.text,
  );
  final prompt = parsedPrompt.remainingText.trim();
  final referencePrefix = parsedPrompt.references.isEmpty ? '' : '引用 ';
  final baseText = prompt.isNotEmpty
      ? '$referencePrefix$prompt'
      : parsedPrompt.references.isNotEmpty
      ? '$referencePrefix${parsedPrompt.references.first.title}'
      : queuedImageMessageBuilder(request.attachments.length);
  if (baseText.length <= maxCharacters) {
    return baseText;
  }
  return '${baseText.substring(0, maxCharacters).trimRight()}...';
}

class LingConversationRetryRequest {
  const LingConversationRetryRequest({
    required this.text,
    required this.source,
    required this.attachments,
  });

  final String text;
  final String source;
  final List<LingConversationAttachment> attachments;
}

bool canCopyLingConversationEntry(LingConversationEntry entry) {
  return entry.entryType != LingConversationEntryType.toolCall &&
      entry.text.trim().isNotEmpty;
}

String buildLingConversationEntryCopyText(LingConversationEntry entry) {
  if (!canCopyLingConversationEntry(entry)) {
    return '';
  }
  final parsed = LingObjectReferenceCodec.parse(entry.text);
  if (parsed.references.isEmpty) {
    return entry.text;
  }
  final parts = <String>[
    for (final reference in parsed.references) _copyLabelFor(reference),
    parsed.remainingText,
  ].where((part) => part.trim().isNotEmpty).toList(growable: false);
  return parts.join('\n\n');
}

String _copyLabelFor(LingObjectReference reference) {
  final kindLabel = switch (reference.kind) {
    LingObjectReferenceKind.event => '日程引用',
  };
  final details = <String>[
    reference.subtitle ?? '',
    ...reference.summaryFields.values,
  ].where((value) => value.trim().isNotEmpty).toSet().take(2);
  final detailText = details.isEmpty ? '' : '\n${details.join(' · ')}';
  return '$kindLabel：${reference.title}$detailText';
}

bool canRetryLingConversationEntry(LingConversationEntry entry) {
  return entry.entryType == LingConversationEntryType.userMessage &&
      (entry.text.trim().isNotEmpty || entry.attachments.isNotEmpty);
}

LingConversationRetryRequest buildLingConversationRetryRequest(
  LingConversationEntry entry,
) {
  if (!canRetryLingConversationEntry(entry)) {
    throw ArgumentError.value(entry.id, 'entry', 'Entry cannot be retried.');
  }
  final attachments = List<LingConversationAttachment>.unmodifiable(
    entry.attachments,
  );
  final agentText = entry.metadata?['agent_text'];
  final retryText = agentText is String && agentText.trim().isNotEmpty
      ? agentText
      : entry.text;
  return LingConversationRetryRequest(
    text: retryText,
    source: attachments.isNotEmpty && retryText.trim().isEmpty
        ? 'image'
        : 'keyboard',
    attachments: attachments,
  );
}

bool shouldShowLingPendingAssistantBubble({
  required List<LingConversationEntry> conversation,
  required bool isProcessingPromptQueue,
}) {
  return isProcessingPromptQueue;
}

LingConversationEntry buildLingPendingAssistantBubbleEntry() {
  return LingConversationEntry.assistant(
    id: 'assistant_loading_placeholder',
    text: '',
    isStreaming: true,
    messageType: 'loading_placeholder',
  );
}

bool shouldKeepLingKeyboardComposerOpen({
  required List<LingConversationAttachment> pendingAttachments,
}) {
  return pendingAttachments.isNotEmpty;
}

bool shouldPreserveLingComposerDraftOnConversationRestore({
  required bool isKeyboardComposerOpen,
  required String draftText,
  required List<LingConversationAttachment> pendingAttachments,
}) {
  return isKeyboardComposerOpen ||
      draftText.trim().isNotEmpty ||
      pendingAttachments.isNotEmpty;
}
