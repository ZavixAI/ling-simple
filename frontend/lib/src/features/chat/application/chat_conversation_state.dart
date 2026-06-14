import 'package:ling/src/features/chat/models/chat_session_models.dart';

class ChatConversationState {
  const ChatConversationState({
    this.sessionId,
    this.conversation = const <ConversationEntryDto>[],
    this.visibleConversationEntryCount = 10,
    this.hasMoreRemoteConversationEntries = false,
    this.olderConversationBeforeCreatedAt,
    this.olderConversationBeforeRecordId,
    this.conversationStartedAt,
    this.storageScope,
    this.lastPersistedConversationStateJson,
    this.persistedConversationUpdatedAt,
  });

  final String? sessionId;
  final List<ConversationEntryDto> conversation;
  final int visibleConversationEntryCount;
  final bool hasMoreRemoteConversationEntries;
  final String? olderConversationBeforeCreatedAt;
  final String? olderConversationBeforeRecordId;
  final DateTime? conversationStartedAt;
  final String? storageScope;
  final String? lastPersistedConversationStateJson;
  final DateTime? persistedConversationUpdatedAt;

  ChatConversationState copyWith({
    String? sessionId,
    bool clearSessionId = false,
    List<ConversationEntryDto>? conversation,
    int? visibleConversationEntryCount,
    bool? hasMoreRemoteConversationEntries,
    String? olderConversationBeforeCreatedAt,
    bool clearOlderConversationBeforeCreatedAt = false,
    String? olderConversationBeforeRecordId,
    bool clearOlderConversationBeforeRecordId = false,
    DateTime? conversationStartedAt,
    bool clearConversationStartedAt = false,
    String? storageScope,
    bool clearStorageScope = false,
    String? lastPersistedConversationStateJson,
    bool clearLastPersistedConversationStateJson = false,
    DateTime? persistedConversationUpdatedAt,
    bool clearPersistedConversationUpdatedAt = false,
  }) {
    return ChatConversationState(
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      conversation: conversation ?? this.conversation,
      visibleConversationEntryCount:
          visibleConversationEntryCount ?? this.visibleConversationEntryCount,
      hasMoreRemoteConversationEntries:
          hasMoreRemoteConversationEntries ??
          this.hasMoreRemoteConversationEntries,
      olderConversationBeforeCreatedAt: clearOlderConversationBeforeCreatedAt
          ? null
          : (olderConversationBeforeCreatedAt ??
                this.olderConversationBeforeCreatedAt),
      olderConversationBeforeRecordId: clearOlderConversationBeforeRecordId
          ? null
          : (olderConversationBeforeRecordId ??
                this.olderConversationBeforeRecordId),
      conversationStartedAt: clearConversationStartedAt
          ? null
          : (conversationStartedAt ?? this.conversationStartedAt),
      storageScope: clearStorageScope
          ? null
          : (storageScope ?? this.storageScope),
      lastPersistedConversationStateJson:
          clearLastPersistedConversationStateJson
          ? null
          : (lastPersistedConversationStateJson ??
                this.lastPersistedConversationStateJson),
      persistedConversationUpdatedAt: clearPersistedConversationUpdatedAt
          ? null
          : (persistedConversationUpdatedAt ??
                this.persistedConversationUpdatedAt),
    );
  }
}
