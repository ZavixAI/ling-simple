// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConversationEntryDto _$ConversationEntryDtoFromJson(
  Map<String, dynamic> json,
) => ConversationEntryDto(
  id: json['id'] as String,
  entryType: json['entry_type'] as String,
  role: json['role'] as String,
  text: json['text'] as String,
  attachments: (json['attachments'] as List<dynamic>)
      .map((e) => AttachmentDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  isStreaming: json['is_streaming'] as bool,
  status: json['status'] as String,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  sessionId: json['session_id'] as String?,
  messageId: json['message_id'] as String?,
  messageType: json['message_type'] as String?,
  toolCallId: json['tool_call_id'] as String?,
  toolName: json['tool_name'] as String?,
  toolArguments: json['tool_arguments'] as String?,
  toolResult: json['tool_result'] as String?,
  durationMs: (json['duration_ms'] as num?)?.toInt(),
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ConversationEntryDtoToJson(
  ConversationEntryDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'session_id': instance.sessionId,
  'entry_type': instance.entryType,
  'role': instance.role,
  'created_at': instance.createdAt?.toIso8601String(),
  'message_id': instance.messageId,
  'message_type': instance.messageType,
  'text': instance.text,
  'attachments': instance.attachments.map((e) => e.toJson()).toList(),
  'is_streaming': instance.isStreaming,
  'tool_call_id': instance.toolCallId,
  'tool_name': instance.toolName,
  'tool_arguments': instance.toolArguments,
  'tool_result': instance.toolResult,
  'duration_ms': instance.durationMs,
  'metadata': instance.metadata,
  'status': instance.status,
};

ChatActiveRunRecord _$ChatActiveRunRecordFromJson(Map<String, dynamic> json) =>
    ChatActiveRunRecord(
      localRunId: (json['local_run_id'] as num?)?.toInt(),
      serverRunId: json['run_id'] as String?,
      sessionId: json['session_id'] as String?,
      userMessageId: json['user_message_id'] as String?,
      queuedPromptId: json['queued_prompt_id'] as String?,
      status: json['status'] as String? ?? 'active',
      startedAt: json['started_at'] == null
          ? null
          : DateTime.parse(json['started_at'] as String),
      heartbeatAt: json['heartbeat_at'] == null
          ? null
          : DateTime.parse(json['heartbeat_at'] as String),
    );

Map<String, dynamic> _$ChatActiveRunRecordToJson(
  ChatActiveRunRecord instance,
) => <String, dynamic>{
  'local_run_id': instance.localRunId,
  'run_id': instance.serverRunId,
  'session_id': instance.sessionId,
  'user_message_id': instance.userMessageId,
  'queued_prompt_id': instance.queuedPromptId,
  'status': instance.status,
  'started_at': instance.startedAt?.toIso8601String(),
  'heartbeat_at': instance.heartbeatAt?.toIso8601String(),
};

AgentSessionSummary _$AgentSessionSummaryFromJson(Map<String, dynamic> json) =>
    AgentSessionSummary(
      sessionId: json['session_id'] as String,
      entryMode: json['entry_mode'] as String,
      timezone: json['timezone'] as String,
      selectedDate: json['selected_date'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$AgentSessionSummaryToJson(
  AgentSessionSummary instance,
) => <String, dynamic>{
  'session_id': instance.sessionId,
  'entry_mode': instance.entryMode,
  'timezone': instance.timezone,
  'selected_date': instance.selectedDate,
  'created_at': instance.createdAt?.toIso8601String(),
};

PersistedConversationState _$PersistedConversationStateFromJson(
  Map<String, dynamic> json,
) => PersistedConversationState(
  storageScope: json['storageScope'] as String,
  conversation: (json['conversation'] as List<dynamic>)
      .map((e) => ConversationEntryDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  sessionId: json['session_id'] as String?,
  activeRun: json['active_run'] == null
      ? null
      : ChatActiveRunRecord.fromJson(
          json['active_run'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$PersistedConversationStateToJson(
  PersistedConversationState instance,
) => <String, dynamic>{
  'storageScope': instance.storageScope,
  'session_id': instance.sessionId,
  'conversation': instance.conversation.map((e) => e.toJson()).toList(),
  'active_run': instance.activeRun?.toJson(),
};
