import 'dart:convert';

import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/chat/data/chat_repository.dart';
import 'package:ling/src/features/chat/data/conversation_persistence_sanitizer.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';

const String _conversationStorageScopeVersion = 'chat_v2';

enum ChatRecoverableSessionSource { localState, latestServerSession }

class ChatRecoverableSession {
  const ChatRecoverableSession({required this.sessionId, required this.source});

  final String sessionId;
  final ChatRecoverableSessionSource source;
}

enum ChatPersistedConversationRestoreStatus { missing, stale, restored }

class ChatPersistedConversationRestoreResult {
  const ChatPersistedConversationRestoreResult({
    required this.status,
    this.updatedAt,
    this.sessionId,
    this.conversation = const <ConversationEntryDto>[],
    this.persistedPayload,
    this.activeRun,
  });

  final ChatPersistedConversationRestoreStatus status;
  final DateTime? updatedAt;
  final String? sessionId;
  final List<ConversationEntryDto> conversation;
  final String? persistedPayload;
  final ChatActiveRunRecord? activeRun;
}

class ChatRecoveredSessionConversation {
  const ChatRecoveredSessionConversation({
    required this.conversation,
    required this.hasStreamingEntry,
    required this.isSessionActive,
    required this.hasMoreRemoteEntries,
    this.activeRun,
    this.olderCursor,
  });

  final List<ConversationEntryDto> conversation;
  final bool hasStreamingEntry;
  final bool isSessionActive;
  final bool hasMoreRemoteEntries;
  final ChatActiveRunRecord? activeRun;
  final ChatSessionEntriesCursor? olderCursor;
}

enum ChatLocalConversationRecoveryStatus { incomplete, complete }

class ChatSessionRecoveryService {
  const ChatSessionRecoveryService({required ChatRepository repository})
    : _repository = repository;

  final ChatRepository _repository;

  Future<({String payload, DateTime persistedAt})?>
  saveConversationStateIfChanged({
    required String storageScope,
    required String? sessionId,
    required List<ConversationEntryDto> conversation,
    ChatActiveRunRecord? activeRun,
    required String? previousPayload,
  }) async {
    final state = PersistedConversationState(
      storageScope: storageScope,
      sessionId: sessionId,
      conversation: conversation,
      activeRun: activeRun,
    );
    final payload = jsonEncode(state.toJson());
    if (payload == previousPayload) {
      return null;
    }
    await _repository.saveConversationState(state);
    return (payload: payload, persistedAt: DateTime.now());
  }

  Future<PersistedConversationCacheSnapshot?> readConversationState(
    String storageScope,
  ) {
    return _repository.readConversationState(storageScope);
  }

  Future<List<ConversationEntryDto>> getSessionEntries(String sessionId) {
    return _repository.getSessionEntries(sessionId);
  }

  Future<AgentSessionSummary?> getLatestSession() {
    return _repository.getLatestSession();
  }

  Future<AgentSessionSummary?> getSession(String sessionId) {
    return _repository.getSession(sessionId);
  }

  bool isSessionStale(DateTime? createdAt) {
    final createdAtValue = createdAt?.toLocal();
    if (createdAtValue == null) {
      return false;
    }
    final now = DateTime.now().toLocal();
    final todayStart = DateTime(now.year, now.month, now.day);
    return createdAtValue.isBefore(todayStart);
  }

  bool isSessionIdStale(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return false;
    }
    final suffixStart = normalizedSessionId.length - 8;
    if (suffixStart <= 0 ||
        normalizedSessionId.codeUnitAt(suffixStart - 1) != '_'.codeUnitAt(0)) {
      return false;
    }
    final suffix = normalizedSessionId.substring(suffixStart);
    if (int.tryParse(suffix) == null) {
      return false;
    }
    final now = DateTime.now().toLocal();
    final todayKey =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return suffix != todayKey;
  }

  String? resolveStorageScope({required UserProfile? profile}) {
    String? normalize(Object? value, {bool lowercase = true}) {
      final raw = '${value ?? ''}'.trim();
      if (raw.isEmpty) {
        return null;
      }
      return lowercase ? raw.toLowerCase() : raw;
    }

    final candidates = <String?>[
      normalize(profile?.userId, lowercase: false),
      normalize(profile?.phoneNumber),
      normalize(profile?.email),
    ];
    for (final candidate in candidates) {
      if (candidate != null) {
        return Uri.encodeComponent(
          '$_conversationStorageScopeVersion:$candidate',
        );
      }
    }
    return null;
  }

  List<ConversationEntryDto> buildPersistableConversation(
    Iterable<ConversationEntryDto> conversation, {
    String? currentSessionId,
  }) {
    final normalizedSessionId = currentSessionId?.trim();
    final currentSessionConversation = conversation.where((entry) {
      final entrySessionId = entry.sessionId?.trim();
      if (entrySessionId == null || entrySessionId.isEmpty) {
        return true;
      }
      return normalizedSessionId != null &&
          normalizedSessionId.isNotEmpty &&
          entrySessionId == normalizedSessionId;
    });
    return sanitizeLingConversationForLocalPersistence(
      currentSessionConversation.where((entry) => !entry.isStreaming),
    );
  }

  Future<ChatPersistedConversationRestoreResult> restorePersistedConversation({
    required String storageScope,
    required Duration maxAge,
  }) async {
    final snapshot = await readConversationState(storageScope);
    if (snapshot == null) {
      return const ChatPersistedConversationRestoreResult(
        status: ChatPersistedConversationRestoreStatus.missing,
      );
    }

    final state = snapshot.state;
    final restoredSessionId = (state.sessionId ?? '').trim();
    final normalizedSessionId = restoredSessionId.isEmpty
        ? null
        : restoredSessionId;

    if (!snapshot.isFresh(maxAge) || isSessionIdStale(normalizedSessionId)) {
      return ChatPersistedConversationRestoreResult(
        status: ChatPersistedConversationRestoreStatus.stale,
        updatedAt: snapshot.updatedAt,
        sessionId: normalizedSessionId,
      );
    }

    final restoredConversation = buildPersistableConversation(
      state.conversation,
      currentSessionId: normalizedSessionId,
    );
    final restoredState = PersistedConversationState(
      storageScope: state.storageScope,
      sessionId: normalizedSessionId,
      conversation: restoredConversation,
      activeRun: state.activeRun,
    );
    return ChatPersistedConversationRestoreResult(
      status: ChatPersistedConversationRestoreStatus.restored,
      updatedAt: snapshot.updatedAt,
      sessionId: normalizedSessionId,
      conversation: restoredConversation,
      persistedPayload: jsonEncode(restoredState.toJson()),
      activeRun: state.activeRun,
    );
  }

  ChatLocalConversationRecoveryStatus assessLocalConversationRecoveryStatus(
    Iterable<ConversationEntryDto> conversation,
  ) {
    final entries = conversation.toList(growable: false);
    if (entries.isEmpty || entries.any((entry) => entry.isStreaming)) {
      return ChatLocalConversationRecoveryStatus.incomplete;
    }
    final lastEntry = _lastMeaningfulConversationEntry(entries);
    if (lastEntry == null ||
        !_isCompletedConversationTerminalEntry(lastEntry)) {
      return ChatLocalConversationRecoveryStatus.incomplete;
    }
    return ChatLocalConversationRecoveryStatus.complete;
  }

  bool shouldUseFreshLocalConversationForRecovery({
    required Iterable<ConversationEntryDto> localConversation,
    required ChatRecoverableSessionSource sessionSource,
    required bool isProcessingPromptQueue,
    required int? activePromptRunId,
    required DateTime? persistedUpdatedAt,
    required Duration gracePeriod,
    bool allowFreshLocalConversationShortcut = true,
  }) {
    final entries = localConversation.toList(growable: false);
    if (!allowFreshLocalConversationShortcut ||
        sessionSource == ChatRecoverableSessionSource.latestServerSession ||
        entries.isEmpty ||
        isProcessingPromptQueue ||
        activePromptRunId != null ||
        persistedUpdatedAt == null ||
        DateTime.now().difference(persistedUpdatedAt) > gracePeriod) {
      return false;
    }
    return assessLocalConversationRecoveryStatus(entries) ==
        ChatLocalConversationRecoveryStatus.complete;
  }

  Future<ChatRecoveredSessionConversation> recoverSessionConversation(
    String sessionId,
  ) async {
    final snapshot = await _repository.getConversationEntriesSnapshot(
      currentSessionId: sessionId,
    );
    final conversation = snapshot.entries;
    final hasStreamingEntry =
        snapshot.isActive && conversation.any((entry) => entry.isStreaming);
    return ChatRecoveredSessionConversation(
      conversation: conversation,
      hasStreamingEntry: hasStreamingEntry,
      isSessionActive: snapshot.isActive,
      hasMoreRemoteEntries: snapshot.hasMore || snapshot.olderCursor != null,
      activeRun: snapshot.activeRun,
      olderCursor: snapshot.olderCursor,
    );
  }

  Future<ChatSessionEntriesSnapshot> getOlderConversationEntries({
    required String currentSessionId,
    required ChatSessionEntriesCursor before,
    int? limit,
  }) {
    return _repository.getConversationEntriesSnapshot(
      currentSessionId: currentSessionId,
      before: before,
      limit: limit ?? 80,
    );
  }

  ConversationEntryDto? _lastMeaningfulConversationEntry(
    List<ConversationEntryDto> conversation,
  ) {
    for (var index = conversation.length - 1; index >= 0; index -= 1) {
      final entry = conversation[index];
      if (_isMeaningfulConversationEntry(entry)) {
        return entry;
      }
    }
    return null;
  }

  bool _isMeaningfulConversationEntry(ConversationEntryDto entry) {
    final hasText = entry.text.trim().isNotEmpty;
    final hasAttachments = entry.attachments.isNotEmpty;
    final hasToolResult = entry.toolResult?.trim().isNotEmpty ?? false;
    final hasToolMetadata =
        (entry.toolName?.trim().isNotEmpty ?? false) ||
        (entry.toolArguments?.trim().isNotEmpty ?? false) ||
        (entry.toolCallId?.trim().isNotEmpty ?? false);
    return hasText || hasAttachments || hasToolResult || hasToolMetadata;
  }

  bool _isCompletedConversationTerminalEntry(ConversationEntryDto entry) {
    if (entry.isStreaming) {
      return false;
    }
    final status = entry.status.trim().toLowerCase();
    if (status.isNotEmpty && status != 'completed') {
      return false;
    }
    if (entry.entryType == 'tool_call') {
      return (entry.toolResult?.trim().isNotEmpty ?? false) ||
          (entry.toolName?.trim().isNotEmpty ?? false) ||
          (entry.toolCallId?.trim().isNotEmpty ?? false);
    }
    if (entry.role != 'assistant') {
      return false;
    }
    return entry.text.trim().isNotEmpty || entry.attachments.isNotEmpty;
  }
}
