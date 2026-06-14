import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/features/chat/application/chat_conversation_state.dart';
import 'package:ling/src/features/chat/application/conversation_entry.dart';
import 'package:ling/src/features/chat/application/tool_call_result_mapper.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';

class ChatConversationController extends Notifier<ChatConversationState> {
  final Map<String, int> _entryIndexByKey = <String, int>{};

  @override
  ChatConversationState build() => const ChatConversationState();

  void reset({
    List<ConversationEntryDto> conversation = const <ConversationEntryDto>[],
    int visibleConversationEntryCount = 10,
    bool hasMoreRemoteConversationEntries = false,
    String? olderConversationBeforeCreatedAt,
    String? olderConversationBeforeRecordId,
    DateTime? conversationStartedAt,
  }) {
    final visibleConversation = _filterConversationEntries(conversation);
    _rebuildEntryIndex(visibleConversation);
    state = ChatConversationState(
      conversation: List<ConversationEntryDto>.unmodifiable(
        visibleConversation,
      ),
      visibleConversationEntryCount: visibleConversationEntryCount,
      hasMoreRemoteConversationEntries: hasMoreRemoteConversationEntries,
      olderConversationBeforeCreatedAt: olderConversationBeforeCreatedAt,
      olderConversationBeforeRecordId: olderConversationBeforeRecordId,
      conversationStartedAt:
          conversationStartedAt ??
          _resolveConversationStartedAt(visibleConversation) ??
          DateTime.now(),
    );
  }

  void replaceConversation(
    List<ConversationEntryDto> conversation, {
    int? visibleConversationEntryCount,
    bool? hasMoreRemoteConversationEntries,
    String? olderConversationBeforeCreatedAt,
    bool clearOlderConversationBeforeCreatedAt = false,
    String? olderConversationBeforeRecordId,
    bool clearOlderConversationBeforeRecordId = false,
    DateTime? conversationStartedAt,
  }) {
    final visibleConversation = _filterConversationEntries(conversation);
    _rebuildEntryIndex(visibleConversation);
    state = state.copyWith(
      conversation: List<ConversationEntryDto>.unmodifiable(
        visibleConversation,
      ),
      visibleConversationEntryCount:
          visibleConversationEntryCount ?? state.visibleConversationEntryCount,
      hasMoreRemoteConversationEntries: hasMoreRemoteConversationEntries,
      olderConversationBeforeCreatedAt: olderConversationBeforeCreatedAt,
      clearOlderConversationBeforeCreatedAt:
          clearOlderConversationBeforeCreatedAt,
      olderConversationBeforeRecordId: olderConversationBeforeRecordId,
      clearOlderConversationBeforeRecordId:
          clearOlderConversationBeforeRecordId,
      conversationStartedAt:
          conversationStartedAt ??
          _resolveConversationStartedAt(visibleConversation) ??
          state.conversationStartedAt,
    );
  }

  void upsertConversationEntry(ConversationEntryDto entry) {
    if (_shouldDropConversationEntry(entry)) {
      removeConversationEntryById(entry.id);
      return;
    }
    final nextConversation = state.conversation.toList(growable: true);
    var existingIndex = _entryIndexByKey[_conversationEntryKey(entry)] ?? -1;
    if (existingIndex < 0) {
      existingIndex = _findUserMessageEntryIndex(nextConversation, entry);
    }
    if (existingIndex >= 0) {
      final existingEntry = nextConversation[existingIndex];
      if (_conversationEntriesEqual(existingEntry, entry)) {
        return;
      }
      nextConversation[existingIndex] = entry;
    } else {
      nextConversation.insert(
        _conversationEntryInsertIndex(nextConversation, entry),
        entry,
      );
    }
    _logConversationEntry('upsert', entry);
    replaceConversation(nextConversation);
  }

  void appendConversationEntry(ConversationEntryDto entry) {
    if (_shouldDropConversationEntry(entry)) {
      return;
    }
    _logConversationEntry('append', entry);
    final nextConversation = state.conversation.toList(growable: true)
      ..add(entry);
    replaceConversation(nextConversation);
  }

  void removeConversationEntryById(String entryId) {
    final normalizedEntryId = entryId.trim();
    if (normalizedEntryId.isEmpty) {
      return;
    }
    final nextConversation = state.conversation
        .where((entry) => entry.id != normalizedEntryId)
        .toList(growable: false);
    if (nextConversation.length == state.conversation.length) {
      return;
    }
    replaceConversation(nextConversation);
  }

  void settleStreamingConversationEntries() {
    final nextConversation = state.conversation.toList(growable: true);
    for (var index = nextConversation.length - 1; index >= 0; index -= 1) {
      final entry = nextConversation[index];
      if (!entry.isStreaming) {
        continue;
      }
      final shouldKeepToolCallEntry = _shouldKeepToolCallEntry(entry);
      final hasMeaningfulContent =
          entry.text.trim().isNotEmpty ||
          entry.attachments.isNotEmpty ||
          (entry.toolResult?.trim().isNotEmpty ?? false) ||
          shouldKeepToolCallEntry;
      if (!hasMeaningfulContent) {
        nextConversation.removeAt(index);
        continue;
      }
      nextConversation[index] = ConversationEntryDto(
        id: entry.id,
        entryType: entry.entryType,
        role: entry.role,
        createdAt: entry.createdAt,
        sessionId: entry.sessionId,
        text: entry.text,
        attachments: entry.attachments,
        isStreaming: false,
        status: shouldKeepToolCallEntry ? 'completed' : entry.status,
        messageId: entry.messageId,
        messageType: entry.messageType,
        toolCallId: entry.toolCallId,
        toolName: entry.toolName,
        toolArguments: entry.toolArguments,
        toolResult: entry.toolResult,
      );
    }
    replaceConversation(nextConversation);
  }

  bool _shouldKeepToolCallEntry(ConversationEntryDto entry) {
    if (entry.entryType != 'tool_call') {
      return false;
    }
    if (isLingIgnoredToolCallEntry(entry)) {
      return false;
    }
    final hasToolMetadata =
        (entry.toolName?.trim().isNotEmpty ?? false) ||
        (entry.toolArguments?.trim().isNotEmpty ?? false) ||
        (entry.toolCallId?.trim().isNotEmpty ?? false);
    if (!hasToolMetadata) {
      return false;
    }
    return true;
  }

  List<ConversationEntryDto> _filterConversationEntries(
    List<ConversationEntryDto> entries,
  ) {
    return entries
        .where((entry) => !_shouldDropConversationEntry(entry))
        .toList(growable: false);
  }

  bool _shouldDropConversationEntry(ConversationEntryDto entry) {
    return isLingIgnoredToolCallEntry(entry) ||
        isLingHiddenConversationErrorMessageType(entry.messageType);
  }

  void applyConversationEvent(Map<String, dynamic> event) {
    final operation = '${event['op'] ?? 'upsert'}'.trim();
    if (operation != 'upsert') {
      return;
    }
    final itemValue = event['item'];
    final item = itemValue is Map<String, dynamic>
        ? itemValue
        : itemValue is Map
        ? Map<String, dynamic>.from(itemValue)
        : <String, dynamic>{};
    if (item.isEmpty) {
      return;
    }
    upsertConversationEntry(ConversationEntryDto.fromJson(item));
  }

  void _logConversationEntry(String operation, ConversationEntryDto entry) {
    if (entry.entryType != 'tool_call') {
      return;
    }
    final toolResult = entry.toolResult?.trim() ?? '';
    AppLogger.info(
      '[Ling][Conversation][$operation] '
      'id=${entry.id} '
      'toolCallId=${entry.toolCallId ?? ''} '
      'toolName=${entry.toolName ?? ''} '
      'status=${entry.status} '
      'streaming=${entry.isStreaming} '
      'hasResult=${toolResult.isNotEmpty} '
      'messageId=${entry.messageId ?? ''}',
    );
  }

  bool _conversationEntriesEqual(
    ConversationEntryDto left,
    ConversationEntryDto right,
  ) {
    return left.id == right.id &&
        left.sessionId == right.sessionId &&
        left.entryType == right.entryType &&
        left.role == right.role &&
        left.createdAt == right.createdAt &&
        left.messageId == right.messageId &&
        left.messageType == right.messageType &&
        left.text == right.text &&
        _attachmentsEqual(left.attachments, right.attachments) &&
        left.isStreaming == right.isStreaming &&
        left.toolCallId == right.toolCallId &&
        left.toolName == right.toolName &&
        left.toolArguments == right.toolArguments &&
        left.toolResult == right.toolResult &&
        left.durationMs == right.durationMs &&
        left.status == right.status;
  }

  void _rebuildEntryIndex(List<ConversationEntryDto> conversation) {
    _entryIndexByKey.clear();
    for (final item in conversation.indexed) {
      _entryIndexByKey.putIfAbsent(
        _conversationEntryKey(item.$2),
        () => item.$1,
      );
    }
  }

  String _conversationEntryKey(ConversationEntryDto entry) {
    final sessionId = entry.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      return entry.id;
    }
    return '$sessionId:${entry.id}';
  }

  int _conversationEntryInsertIndex(
    List<ConversationEntryDto> conversation,
    ConversationEntryDto incoming,
  ) {
    final incomingCreatedAt = incoming.createdAt;
    if (incomingCreatedAt == null) {
      return conversation.length;
    }
    for (var index = conversation.length - 1; index >= 0; index -= 1) {
      final entryCreatedAt = conversation[index].createdAt;
      if (entryCreatedAt == null ||
          !entryCreatedAt.isAfter(incomingCreatedAt)) {
        return index + 1;
      }
    }
    return 0;
  }

  int _findUserMessageEntryIndex(
    List<ConversationEntryDto> conversation,
    ConversationEntryDto incoming,
  ) {
    if (incoming.role != 'user') {
      return -1;
    }
    final messageId = incoming.messageId?.trim();
    if (messageId == null || messageId.isEmpty) {
      return -1;
    }
    final incomingSessionId = incoming.sessionId?.trim();
    for (final item in conversation.indexed) {
      final entry = item.$2;
      if (entry.role != 'user' || entry.messageId?.trim() != messageId) {
        continue;
      }
      final entrySessionId = entry.sessionId?.trim();
      if (incomingSessionId != null &&
          incomingSessionId.isNotEmpty &&
          entrySessionId != null &&
          entrySessionId.isNotEmpty &&
          entrySessionId != incomingSessionId) {
        continue;
      }
      return item.$1;
    }
    return -1;
  }

  bool _attachmentsEqual(List<AttachmentDto> left, List<AttachmentDto> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      final leftItem = left[index];
      final rightItem = right[index];
      if (leftItem.attachmentId != rightItem.attachmentId ||
          leftItem.filename != rightItem.filename ||
          leftItem.url != rightItem.url ||
          !_jsonLikeValuesEqual(
            leftItem.messageContent,
            rightItem.messageContent,
          )) {
        return false;
      }
    }
    return true;
  }

  bool _jsonLikeValuesEqual(Object? left, Object? right) {
    if (identical(left, right)) {
      return true;
    }
    if (left is Map && right is Map) {
      if (left.length != right.length) {
        return false;
      }
      for (final entry in left.entries) {
        if (!right.containsKey(entry.key) ||
            !_jsonLikeValuesEqual(entry.value, right[entry.key])) {
          return false;
        }
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) {
        return false;
      }
      for (var index = 0; index < left.length; index += 1) {
        if (!_jsonLikeValuesEqual(left[index], right[index])) {
          return false;
        }
      }
      return true;
    }
    return left == right;
  }

  void setSessionId(String? sessionId) {
    final normalized = sessionId?.trim();
    state = state.copyWith(
      sessionId: normalized == null || normalized.isEmpty ? null : normalized,
      clearSessionId: normalized == null || normalized.isEmpty,
    );
  }

  void setVisibleConversationEntryCount(int value) {
    state = state.copyWith(visibleConversationEntryCount: value);
  }

  void increaseVisibleConversationEntryCount(int delta) {
    if (delta == 0) {
      return;
    }
    state = state.copyWith(
      visibleConversationEntryCount:
          state.visibleConversationEntryCount + delta,
    );
  }

  void setRemoteConversationPagination({
    required bool hasMore,
    String? beforeCreatedAt,
    String? beforeRecordId,
  }) {
    final normalizedBeforeCreatedAt = beforeCreatedAt?.trim();
    final normalizedBeforeRecordId = beforeRecordId?.trim();
    state = state.copyWith(
      hasMoreRemoteConversationEntries: hasMore,
      olderConversationBeforeCreatedAt:
          normalizedBeforeCreatedAt == null || normalizedBeforeCreatedAt.isEmpty
          ? null
          : normalizedBeforeCreatedAt,
      clearOlderConversationBeforeCreatedAt:
          normalizedBeforeCreatedAt == null ||
          normalizedBeforeCreatedAt.isEmpty,
      olderConversationBeforeRecordId:
          normalizedBeforeRecordId == null || normalizedBeforeRecordId.isEmpty
          ? null
          : normalizedBeforeRecordId,
      clearOlderConversationBeforeRecordId:
          normalizedBeforeRecordId == null || normalizedBeforeRecordId.isEmpty,
    );
  }

  void setStorageScope(String? storageScope) {
    final normalized = storageScope?.trim();
    state = state.copyWith(
      storageScope: normalized == null || normalized.isEmpty
          ? null
          : normalized,
      clearStorageScope: normalized == null || normalized.isEmpty,
    );
  }

  void setLastPersistedConversationStateJson(String? json) {
    final normalized = json?.trim();
    state = state.copyWith(
      lastPersistedConversationStateJson:
          normalized == null || normalized.isEmpty ? null : normalized,
      clearLastPersistedConversationStateJson:
          normalized == null || normalized.isEmpty,
    );
  }

  void setPersistedConversationUpdatedAt(DateTime? value) {
    state = state.copyWith(
      persistedConversationUpdatedAt: value,
      clearPersistedConversationUpdatedAt: value == null,
    );
  }

  void clearPersistenceSnapshot() {
    state = state.copyWith(
      clearStorageScope: true,
      clearLastPersistedConversationStateJson: true,
      clearPersistedConversationUpdatedAt: true,
    );
  }

  void setConversationStartedAt(DateTime? value) {
    state = state.copyWith(
      conversationStartedAt: value,
      clearConversationStartedAt: value == null,
    );
  }

  DateTime? _resolveConversationStartedAt(
    List<ConversationEntryDto> conversation,
  ) {
    for (final entry in conversation) {
      if (entry.role == 'user' && entry.createdAt != null) {
        return entry.createdAt;
      }
    }
    for (final entry in conversation) {
      if (entry.createdAt != null) {
        return entry.createdAt;
      }
    }
    return null;
  }
}

final chatConversationControllerProvider =
    NotifierProvider<ChatConversationController, ChatConversationState>(
      ChatConversationController.new,
    );
