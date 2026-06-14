import 'package:ling/src/features/chat/models/chat_session_models.dart';

List<ConversationEntryDto> sanitizeLingConversationForLocalPersistence(
  Iterable<ConversationEntryDto> conversation,
) {
  return conversation
      .map(sanitizeLingConversationEntryForLocalPersistence)
      .toList(growable: false);
}

PersistedConversationState
sanitizeLingPersistedConversationStateForLocalPersistence(
  PersistedConversationState state,
) {
  return PersistedConversationState(
    storageScope: state.storageScope,
    sessionId: state.sessionId,
    activeRun: state.activeRun,
    conversation: sanitizeLingConversationForLocalPersistence(
      state.conversation,
    ),
  );
}

ConversationEntryDto sanitizeLingConversationEntryForLocalPersistence(
  ConversationEntryDto entry,
) {
  if (entry.entryType != 'tool_call') {
    return entry;
  }
  return ConversationEntryDto(
    id: entry.id,
    entryType: entry.entryType,
    role: entry.role,
    createdAt: entry.createdAt,
    sessionId: entry.sessionId,
    messageId: entry.messageId,
    messageType: entry.messageType,
    text: '',
    attachments: const <AttachmentDto>[],
    isStreaming: entry.isStreaming,
    status: entry.status,
    toolCallId: _normalizedString(entry.toolCallId),
    toolName: _normalizedString(entry.toolName),
    toolArguments: null,
    toolResult: _shouldKeepToolResult(entry)
        ? _normalizedString(entry.toolResult)
        : null,
    durationMs: entry.durationMs,
  );
}

bool _shouldKeepToolResult(ConversationEntryDto entry) {
  final toolName = _normalizedString(entry.toolName);
  if (toolName == null) {
    return false;
  }
  return toolName.startsWith('calendar_') || toolName.startsWith('intent_');
}

String? _normalizedString(Object? value) {
  final normalized = '$value'.trim();
  if (value == null || normalized.isEmpty || normalized == 'null') {
    return null;
  }
  return normalized;
}
