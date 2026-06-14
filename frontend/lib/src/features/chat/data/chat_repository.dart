import 'dart:convert';

import 'package:ling/src/core/cache/json_cache_store.dart';
import 'package:ling/src/core/database/app_database.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/network/json_payload_codec.dart';
import 'package:ling/src/core/storage/app_preferences.dart';
import 'package:ling/src/core/storage/local_persistence_policy.dart';
import 'package:ling/src/features/chat/data/conversation_persistence_sanitizer.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';
import 'package:ling/src/features/chat/models/quick_prompt_models.dart';
import 'package:ling/src/features/chat/models/user_context_digest_models.dart';

class ChatSessionEntriesSnapshot {
  const ChatSessionEntriesSnapshot({
    required this.entries,
    required this.isActive,
    this.hasMore = false,
    this.messageLimit,
    this.olderCursor,
    this.activeRun,
  });

  final List<ConversationEntryDto> entries;
  final bool isActive;
  final bool hasMore;
  final int? messageLimit;
  final ChatSessionEntriesCursor? olderCursor;
  final ChatActiveRunRecord? activeRun;
}

class ChatSessionEntriesCursor {
  const ChatSessionEntriesCursor({
    required this.beforeCreatedAt,
    required this.beforeRecordId,
  });

  final String beforeCreatedAt;
  final String beforeRecordId;

  bool get isValid =>
      beforeCreatedAt.trim().isNotEmpty && beforeRecordId.trim().isNotEmpty;
}

class ChatRepository {
  ChatRepository({
    required ApiClient apiClient,
    required AppDatabase database,
    JsonCacheStore? cacheStore,
    LocalPersistencePolicy? localPersistencePolicy,
  }) : _apiClient = apiClient,
       _database = database,
       _cacheStore = cacheStore,
       _localPersistencePolicy =
           localPersistencePolicy ?? const LocalPersistencePolicy();

  final ApiClient _apiClient;
  final AppDatabase _database;
  JsonCacheStore? _cacheStore;
  final LocalPersistencePolicy _localPersistencePolicy;
  static const String _quickPromptCachePrefix = 'ling.cache.v1.quick_prompts.';
  static const String _conversationEventCursorPrefix =
      'ling.chat.conversation_events.last_id.v1.';
  static const Duration _quickPromptFallbackTtl = Duration(hours: 12);

  Future<AgentSessionSummary> createSession({
    required String entryMode,
    required String selectedDate,
    required String timezone,
  }) async {
    final response = await _apiClient.post(
      '/agent/sessions',
      body: {
        'entry_mode': entryMode,
        'selected_date': selectedDate,
        'timezone': timezone,
      },
    );
    return AgentSessionSummary.fromJson(asJsonMap(response.data));
  }

  Future<AgentSessionSummary?> getSession(String sessionId) async {
    final response = await _apiClient.get('/agent/sessions/$sessionId');
    return AgentSessionSummary.fromJson(asJsonMap(response.data));
  }

  Future<Map<String, dynamic>> startSessionRun({
    required String sessionId,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> systemContext,
  }) async {
    final response = await _apiClient.post(
      '/agent/sessions/$sessionId/runs',
      body: {'messages': messages, 'system_context': systemContext},
    );
    return asJsonMap(response.data);
  }

  Future<Map<String, dynamic>> injectUserMessage({
    required String sessionId,
    required Object content,
    required String guidanceId,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _apiClient.post(
      '/agent/sessions/$sessionId/inject-user-message',
      body: {
        'content': content,
        'guidance_id': guidanceId,
        'metadata': metadata,
      },
    );
    return asJsonMap(response.data);
  }

  Future<List<Map<String, dynamic>>> listPendingUserInjections(
    String sessionId,
  ) async {
    final response = await _apiClient.get(
      '/agent/sessions/$sessionId/inject-user-message',
    );
    final data = asJsonMap(response.data);
    final items = data['items'];
    if (items is! List) {
      return const <Map<String, dynamic>>[];
    }
    return items
        .whereType<Map<Object?, Object?>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> updatePendingUserInjection({
    required String sessionId,
    required String guidanceId,
    required Object content,
  }) async {
    await _apiClient.patch(
      '/agent/sessions/$sessionId/inject-user-message/$guidanceId',
      body: {'content': content},
    );
  }

  Future<void> deletePendingUserInjection({
    required String sessionId,
    required String guidanceId,
  }) async {
    await _apiClient.delete(
      '/agent/sessions/$sessionId/inject-user-message/$guidanceId',
    );
  }

  Stream<Map<String, dynamic>> streamConversationEvents({
    String? lastEventId,
    Future<void>? abortTrigger,
  }) {
    final normalizedLastEventId = lastEventId?.trim();
    return _apiClient.streamGetJsonEvents(
      '/agent/events',
      queryParameters:
          normalizedLastEventId == null || normalizedLastEventId.isEmpty
          ? null
          : <String, Object?>{'last_event_id': normalizedLastEventId},
      logPayloads: false,
      abortTrigger: abortTrigger,
    );
  }

  Future<String?> readLastConversationEventId(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return null;
    }
    final prefs = await AppPreferences.instance;
    final value = prefs
        .getString(_conversationEventCursorKey(normalizedUserId))
        ?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> saveLastConversationEventId({
    required String userId,
    required String eventId,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedEventId = eventId.trim();
    if (normalizedUserId.isEmpty || normalizedEventId.isEmpty) {
      return;
    }
    final prefs = await AppPreferences.instance;
    await prefs.setString(
      _conversationEventCursorKey(normalizedUserId),
      normalizedEventId,
    );
  }

  static String _conversationEventCursorKey(String userId) {
    return '$_conversationEventCursorPrefix$userId';
  }

  Future<ChatQuickPromptBundle> getQuickPrompts({
    String? localeCode,
    bool forceRefresh = false,
  }) async {
    final normalizedLocale = (localeCode ?? '').trim();
    final cacheKey =
        '$_quickPromptCachePrefix${normalizedLocale.isEmpty ? 'auto' : normalizedLocale}';
    final cacheStore = _cacheStore ??= JsonCacheStore();
    return cacheStore.getOrLoad<ChatQuickPromptBundle>(
      cacheKey,
      ttl: _quickPromptFallbackTtl,
      forceRefresh: forceRefresh,
      loader: () async {
        final response = await _apiClient.get(
          '/me/quick-prompts',
          queryParameters: <String, Object?>{
            'surface': 'chat',
            if (normalizedLocale.isNotEmpty) 'locale': normalizedLocale,
          },
        );
        return ChatQuickPromptBundle.fromJson(response.data);
      },
      decoder: ChatQuickPromptBundle.fromJson,
      encoder: (bundle) => bundle.toJson(),
    );
  }

  Future<void> recordQuickPromptUse({
    required String promptId,
    String surface = 'chat',
  }) async {
    final normalizedPromptId = promptId.trim();
    if (normalizedPromptId.isEmpty || normalizedPromptId == 'custom') {
      return;
    }
    await _apiClient.post(
      '/me/quick-prompts/$normalizedPromptId/use',
      body: {'surface': surface},
    );
  }

  Future<ChatSessionEntriesSnapshot> getSessionEntriesSnapshot(
    String sessionId, {
    int limit = 80,
    ChatSessionEntriesCursor? before,
  }) async {
    AppLogger.info('[Ling][ChatRepository] 正在获取会话记录 sessionId=$sessionId');
    final queryParameters = <String, Object?>{'limit': limit};
    if (before != null && before.isValid) {
      queryParameters['before_created_at'] = before.beforeCreatedAt;
      queryParameters['before_record_id'] = before.beforeRecordId;
    }
    final response = await _apiClient.get(
      '/agent/sessions/$sessionId/entries',
      queryParameters: queryParameters,
    );
    final snapshot = _parseSessionEntriesSnapshot(
      asJsonMap(response.data),
      contextLabel: '会话记录',
      sessionId: sessionId,
    );
    AppLogger.info(
      '[Ling][ChatRepository] 会话记录已获取 '
      'sessionId=$sessionId count=${snapshot.entries.length} '
      'isActive=${snapshot.isActive} hasMore=${snapshot.hasMore}',
    );
    return snapshot;
  }

  Future<ChatSessionEntriesSnapshot> getConversationEntriesSnapshot({
    required String? currentSessionId,
    int limit = 80,
    ChatSessionEntriesCursor? before,
  }) async {
    final normalizedSessionId = currentSessionId?.trim();
    AppLogger.info(
      '[Ling][ChatRepository] 正在获取对话时间线 currentSessionId=$normalizedSessionId',
    );
    final queryParameters = <String, Object?>{'limit': limit};
    if (normalizedSessionId != null && normalizedSessionId.isNotEmpty) {
      queryParameters['current_session_id'] = normalizedSessionId;
    }
    if (before != null && before.isValid) {
      queryParameters['before_created_at'] = before.beforeCreatedAt;
      queryParameters['before_record_id'] = before.beforeRecordId;
    }
    final response = await _apiClient.get(
      '/agent/conversation-entries',
      queryParameters: queryParameters,
    );
    final snapshot = _parseSessionEntriesSnapshot(
      asJsonMap(response.data),
      contextLabel: '对话时间线',
      sessionId: normalizedSessionId ?? '',
    );
    AppLogger.info(
      '[Ling][ChatRepository] 对话时间线已获取 '
      'currentSessionId=$normalizedSessionId count=${snapshot.entries.length} '
      'isActive=${snapshot.isActive} hasMore=${snapshot.hasMore}',
    );
    return snapshot;
  }

  ChatSessionEntriesSnapshot _parseSessionEntriesSnapshot(
    Map<String, dynamic> data, {
    required String contextLabel,
    required String sessionId,
  }) {
    final items = data['items'];
    final isActive = data['is_active'] == true;
    final activeRun = _parseActiveRun(data['active_run']);
    final hasMore = data['has_more'] == true;
    final messageLimit = data['message_limit'] is num
        ? (data['message_limit'] as num).toInt()
        : null;
    final olderCursor = _parseEntriesCursor(data['older_cursor']);
    if (items is! List) {
      AppLogger.warn(
        '[Ling][ChatRepository] $contextLabel响应缺少列表 '
        'sessionId=$sessionId payloadType=${items.runtimeType}',
      );
      return ChatSessionEntriesSnapshot(
        entries: const <ConversationEntryDto>[],
        isActive: isActive,
        hasMore: hasMore,
        messageLimit: messageLimit,
        olderCursor: olderCursor,
        activeRun: activeRun,
      );
    }
    final entries = items
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) =>
              ConversationEntryDto.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
    return ChatSessionEntriesSnapshot(
      entries: entries,
      isActive: isActive,
      hasMore: hasMore,
      messageLimit: messageLimit,
      olderCursor: olderCursor,
      activeRun: activeRun,
    );
  }

  ChatActiveRunRecord? _parseActiveRun(Object? value) {
    if (value is! Map) {
      return null;
    }
    final payload = Map<String, dynamic>.from(value);
    final serverRunId = '${payload['run_id'] ?? ''}'.trim();
    if (serverRunId.isEmpty) {
      return null;
    }
    return ChatActiveRunRecord.fromJson(payload);
  }

  ChatSessionEntriesCursor? _parseEntriesCursor(Object? value) {
    if (value is! Map) {
      return null;
    }
    final payload = Map<String, dynamic>.from(value);
    final beforeCreatedAt = '${payload['before_created_at'] ?? ''}'.trim();
    final beforeRecordId = '${payload['before_record_id'] ?? ''}'.trim();
    if (beforeCreatedAt.isEmpty || beforeRecordId.isEmpty) {
      return null;
    }
    return ChatSessionEntriesCursor(
      beforeCreatedAt: beforeCreatedAt,
      beforeRecordId: beforeRecordId,
    );
  }

  Future<List<ConversationEntryDto>> getSessionEntries(String sessionId) async {
    final snapshot = await getSessionEntriesSnapshot(sessionId);
    return snapshot.entries;
  }

  Future<AgentSessionSummary?> getLatestSession() async {
    AppLogger.info('[Ling][ChatRepository] 正在获取最新会话');
    final response = await _apiClient.get('/agent/sessions/latest');
    final data = asJsonMap(response.data);
    final item = data['item'];
    if (item is! Map) {
      AppLogger.info(
        '[Ling][ChatRepository] 最新会话不可用 itemType=${item.runtimeType}',
      );
      return null;
    }
    final session = AgentSessionSummary.fromJson(
      Map<String, dynamic>.from(item),
    );
    AppLogger.info(
      '[Ling][ChatRepository] 最新会话已获取 sessionId=${session.sessionId}',
    );
    return session;
  }

  Future<UserContextDigestSummary> getUserContextDigest({
    required String timezone,
    required String locale,
  }) async {
    final response = await _apiClient.get(
      '/agent/context-digest',
      queryParameters: {'timezone': timezone, 'locale': locale},
    );
    return UserContextDigestSummary.fromJson(asJsonMap(response.data));
  }

  Future<void> saveConversationState(
    PersistedConversationState state, {
    DateTime? updatedAtOverride,
  }) {
    if (!_localPersistencePolicy.canPersistToProtectedDatabase(
      LocalDataSensitivity.privateEphemeral,
    )) {
      return Future<void>.value();
    }
    final sanitizedState =
        sanitizeLingPersistedConversationStateForLocalPersistence(state);
    return _database.saveConversationState(
      storageScope: sanitizedState.storageScope,
      sessionId: sanitizedState.sessionId,
      updatedAtOverride: updatedAtOverride,
      conversation: sanitizedState.conversation
          .map(
            (entry) => StoredConversationEntryRecord(
              id: entry.id,
              isStreaming: entry.isStreaming,
              payload: jsonEncode(entry.toJson()),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<PersistedConversationCacheSnapshot?> readConversationState(
    String storageScope,
  ) async {
    if (!_localPersistencePolicy.canPersistToProtectedDatabase(
      LocalDataSensitivity.privateEphemeral,
    )) {
      return null;
    }
    final snapshot = await _database.readConversationState(storageScope);
    if (snapshot == null) {
      return null;
    }
    final storedState = PersistedConversationState(
      storageScope: snapshot.storageScope,
      sessionId: snapshot.sessionId,
      conversation: snapshot.conversation
          .map(
            (entry) =>
                ConversationEntryDto.fromJson(decodeStoredMap(entry.payload)),
          )
          .toList(growable: false),
    );
    final sanitizedState =
        sanitizeLingPersistedConversationStateForLocalPersistence(storedState);
    if (jsonEncode(storedState.toJson()) !=
        jsonEncode(sanitizedState.toJson())) {
      AppLogger.info(
        '[Ling][ChatRepository] 使用清理后的工具数据重写已持久化对话 '
        'storageScope=$storageScope sessionId=${snapshot.sessionId}',
      );
      await saveConversationState(
        sanitizedState,
        updatedAtOverride: snapshot.updatedAt,
      );
    }
    return PersistedConversationCacheSnapshot(
      state: sanitizedState,
      updatedAt: snapshot.updatedAt,
    );
  }

  Future<void> clearConversationState(String storageScope) {
    return _database.clearConversationState(storageScope);
  }

  Future<void> interruptSession(String sessionId) async {
    await _apiClient.post('/agent/sessions/$sessionId/interrupt');
  }

  Future<AttachmentDto> uploadConversationImage({
    required List<int> bytes,
    required String filename,
  }) async {
    final response = await _apiClient.postMultipart(
      '/agent/attachments/images',
      fileField: 'files',
      fileBytes: bytes,
      filename: filename,
    );
    final data = asJsonMap(response.data);
    final items = data['items'];
    if (items is! List || items.isEmpty) {
      throw ApiException(message: '图片上传成功，但返回内容为空。', cause: data);
    }

    final first = items.first;
    if (first is Map<String, dynamic>) {
      return AttachmentDto.fromJson(normalizeAttachmentJson(first));
    }
    if (first is Map) {
      return AttachmentDto.fromJson(
        normalizeAttachmentJson(Map<String, dynamic>.from(first)),
      );
    }
    throw ApiException(message: '图片上传返回格式异常。', cause: first);
  }

  Future<AttachmentDto> uploadConversationAudio({
    required List<int> bytes,
    required String filename,
  }) async {
    final response = await _apiClient.postMultipart(
      '/agent/attachments/audio',
      fileField: 'files',
      fileBytes: bytes,
      filename: filename,
    );
    final data = asJsonMap(response.data);
    final items = data['items'];
    if (items is! List || items.isEmpty) {
      throw ApiException(message: '语音上传成功，但返回内容为空。', cause: data);
    }

    final first = items.first;
    if (first is Map<String, dynamic>) {
      return AttachmentDto.fromJson(normalizeAttachmentJson(first));
    }
    if (first is Map) {
      return AttachmentDto.fromJson(
        normalizeAttachmentJson(Map<String, dynamic>.from(first)),
      );
    }
    throw ApiException(message: '语音上传返回格式异常。', cause: first);
  }
}
