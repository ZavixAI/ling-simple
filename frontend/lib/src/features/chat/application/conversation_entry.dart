import 'package:ling/src/features/chat/application/conversation_attachment.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';

enum LingConversationRole { user, assistant }

enum LingConversationEntryType { userMessage, assistantMessage, toolCall }

const List<String> _hiddenSkillTags = <String>[
  '<skill>schedule-management</skill>',
  '<skill>trip-planning</skill>',
  '<skill>travel-resources</skill>',
];

class LingConversationEntry {
  LingConversationEntry({
    required this.id,
    required this.entryType,
    required this.role,
    required String text,
    required this.attachments,
    required this.isStreaming,
    required this.status,
    this.createdAt,
    this.sessionId,
    this.messageId,
    this.messageType,
    this.metadata,
    this.toolCallId,
    this.toolName,
    this.toolArguments,
    this.toolResult,
    this.durationMs,
  }) : text = _normalizeDisplayText(text);

  factory LingConversationEntry.fromDto(ConversationEntryDto dto) {
    return LingConversationEntry(
      id: dto.id,
      entryType: switch (dto.entryType) {
        'user_message' => LingConversationEntryType.userMessage,
        'tool_call' => LingConversationEntryType.toolCall,
        _ =>
          dto.role == 'user'
              ? LingConversationEntryType.userMessage
              : LingConversationEntryType.assistantMessage,
      },
      role: dto.role == 'user'
          ? LingConversationRole.user
          : LingConversationRole.assistant,
      createdAt: dto.createdAt,
      sessionId: dto.sessionId,
      text: dto.text,
      attachments: dto.attachments
          .map(LingConversationAttachment.fromDto)
          .toList(growable: false),
      isStreaming: dto.isStreaming,
      status: dto.status,
      messageId: dto.messageId,
      messageType: dto.messageType,
      metadata: dto.metadata,
      toolCallId: dto.toolCallId,
      toolName: dto.toolName,
      toolArguments: dto.toolArguments,
      toolResult: dto.toolResult,
      durationMs: dto.durationMs,
    );
  }

  factory LingConversationEntry.assistant({
    required String id,
    required String text,
    bool isStreaming = false,
    DateTime? createdAt,
    String? sessionId,
    String? messageId,
    String? messageType,
    Map<String, dynamic>? metadata,
  }) {
    return LingConversationEntry(
      id: id,
      entryType: LingConversationEntryType.assistantMessage,
      role: LingConversationRole.assistant,
      createdAt: createdAt,
      sessionId: sessionId,
      messageId: messageId,
      messageType: messageType,
      metadata: metadata,
      text: text,
      attachments: const <LingConversationAttachment>[],
      isStreaming: isStreaming,
      status: 'completed',
    );
  }

  final String id;
  final LingConversationEntryType entryType;
  final LingConversationRole role;
  final DateTime? createdAt;
  final String? sessionId;
  final String? messageId;
  final String? messageType;
  final Map<String, dynamic>? metadata;
  String text;
  final List<LingConversationAttachment> attachments;
  bool isStreaming;
  String status;
  String? toolCallId;
  String? toolName;
  String? toolArguments;
  String? toolResult;
  int? durationMs;

  bool get isAgentExecutionError =>
      (messageType ?? '').trim() == 'agent_execution_error';

  bool get isHiddenError =>
      isLingHiddenConversationErrorMessageType(messageType);

  static String _normalizeDisplayText(String text) {
    var normalized = text.trimLeft();
    var changed = false;
    while (true) {
      String? tag;
      for (final candidate in _hiddenSkillTags) {
        if (normalized.startsWith(candidate)) {
          tag = candidate;
          break;
        }
      }
      if (tag == null) {
        break;
      }
      normalized = normalized.substring(tag.length).trimLeft();
      changed = true;
    }
    return changed ? normalized : text;
  }

  ConversationEntryDto toDto() {
    return ConversationEntryDto(
      id: id,
      entryType: switch (entryType) {
        LingConversationEntryType.userMessage => 'user_message',
        LingConversationEntryType.assistantMessage => 'assistant_message',
        LingConversationEntryType.toolCall => 'tool_call',
      },
      role: role == LingConversationRole.user ? 'user' : 'assistant',
      createdAt: createdAt,
      sessionId: sessionId,
      messageId: messageId,
      messageType: messageType,
      metadata: metadata,
      text: text,
      attachments: attachments
          .map((attachment) => attachment.toDto())
          .toList(growable: false),
      isStreaming: isStreaming,
      toolCallId: toolCallId,
      toolName: toolName,
      toolArguments: toolArguments,
      toolResult: toolResult,
      durationMs: durationMs,
      status: status,
    );
  }
}

bool isLingHiddenConversationErrorMessageType(String? messageType) {
  final normalized = (messageType ?? '').trim();
  return normalized == 'error' || normalized == 'agent_execution_error';
}
