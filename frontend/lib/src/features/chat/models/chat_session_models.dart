import 'package:json_annotation/json_annotation.dart';
import 'package:ling/src/shared/models/attachment_models.dart';

export 'package:ling/src/shared/models/attachment_models.dart';

part 'chat_session_models.g.dart';

@JsonSerializable(explicitToJson: true)
class ConversationEntryDto {
  const ConversationEntryDto({
    required this.id,
    required this.entryType,
    required this.role,
    required this.text,
    required this.attachments,
    required this.isStreaming,
    required this.status,
    this.createdAt,
    this.sessionId,
    this.messageId,
    this.messageType,
    this.toolCallId,
    this.toolName,
    this.toolArguments,
    this.toolResult,
    this.durationMs,
    this.metadata,
  });

  final String id;
  @JsonKey(name: 'session_id')
  final String? sessionId;
  @JsonKey(name: 'entry_type')
  final String entryType;
  final String role;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'message_id')
  final String? messageId;
  @JsonKey(name: 'message_type')
  final String? messageType;
  final String text;
  final List<AttachmentDto> attachments;
  @JsonKey(name: 'is_streaming')
  final bool isStreaming;
  @JsonKey(name: 'tool_call_id')
  final String? toolCallId;
  @JsonKey(name: 'tool_name')
  final String? toolName;
  @JsonKey(name: 'tool_arguments')
  final String? toolArguments;
  @JsonKey(name: 'tool_result')
  final String? toolResult;
  @JsonKey(name: 'duration_ms')
  final int? durationMs;
  final Map<String, dynamic>? metadata;
  final String status;

  factory ConversationEntryDto.fromJson(Map<String, dynamic> json) =>
      _$ConversationEntryDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ConversationEntryDtoToJson(this);
}

@JsonSerializable()
class ChatActiveRunRecord {
  const ChatActiveRunRecord({
    this.localRunId,
    this.serverRunId,
    this.sessionId,
    this.userMessageId,
    this.queuedPromptId,
    this.status = 'active',
    this.startedAt,
    this.heartbeatAt,
  });

  @JsonKey(name: 'local_run_id')
  final int? localRunId;
  @JsonKey(name: 'run_id')
  final String? serverRunId;
  @JsonKey(name: 'session_id')
  final String? sessionId;
  @JsonKey(name: 'user_message_id')
  final String? userMessageId;
  @JsonKey(name: 'queued_prompt_id')
  final String? queuedPromptId;
  final String status;
  @JsonKey(name: 'started_at')
  final DateTime? startedAt;
  @JsonKey(name: 'heartbeat_at')
  final DateTime? heartbeatAt;

  factory ChatActiveRunRecord.fromJson(Map<String, dynamic> json) =>
      _$ChatActiveRunRecordFromJson(json);

  Map<String, dynamic> toJson() => _$ChatActiveRunRecordToJson(this);

  ChatActiveRunRecord copyWith({
    int? localRunId,
    bool clearLocalRunId = false,
    String? serverRunId,
    bool clearServerRunId = false,
    String? sessionId,
    bool clearSessionId = false,
    String? userMessageId,
    bool clearUserMessageId = false,
    String? queuedPromptId,
    bool clearQueuedPromptId = false,
    String? status,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? heartbeatAt,
    bool clearHeartbeatAt = false,
  }) {
    return ChatActiveRunRecord(
      localRunId: clearLocalRunId ? null : (localRunId ?? this.localRunId),
      serverRunId: clearServerRunId ? null : (serverRunId ?? this.serverRunId),
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      userMessageId: clearUserMessageId
          ? null
          : (userMessageId ?? this.userMessageId),
      queuedPromptId: clearQueuedPromptId
          ? null
          : (queuedPromptId ?? this.queuedPromptId),
      status: status ?? this.status,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      heartbeatAt: clearHeartbeatAt ? null : (heartbeatAt ?? this.heartbeatAt),
    );
  }
}

@JsonSerializable()
class AgentSessionSummary {
  const AgentSessionSummary({
    required this.sessionId,
    required this.entryMode,
    required this.timezone,
    this.selectedDate,
    this.createdAt,
  });

  @JsonKey(name: 'session_id')
  final String sessionId;
  @JsonKey(name: 'entry_mode')
  final String entryMode;
  final String timezone;
  @JsonKey(name: 'selected_date')
  final String? selectedDate;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  factory AgentSessionSummary.fromJson(Map<String, dynamic> json) =>
      _$AgentSessionSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$AgentSessionSummaryToJson(this);
}

@JsonSerializable(explicitToJson: true)
class PersistedConversationState {
  const PersistedConversationState({
    required this.storageScope,
    required this.conversation,
    this.sessionId,
    this.activeRun,
  });

  final String storageScope;
  @JsonKey(name: 'session_id')
  final String? sessionId;
  final List<ConversationEntryDto> conversation;
  @JsonKey(name: 'active_run')
  final ChatActiveRunRecord? activeRun;

  factory PersistedConversationState.fromJson(Map<String, dynamic> json) =>
      _$PersistedConversationStateFromJson(json);

  Map<String, dynamic> toJson() => _$PersistedConversationStateToJson(this);
}

class PersistedConversationCacheSnapshot {
  const PersistedConversationCacheSnapshot({
    required this.state,
    required this.updatedAt,
  });

  final PersistedConversationState state;
  final DateTime updatedAt;

  bool isFresh(Duration maxAge) =>
      DateTime.now().difference(updatedAt) <= maxAge;
}
