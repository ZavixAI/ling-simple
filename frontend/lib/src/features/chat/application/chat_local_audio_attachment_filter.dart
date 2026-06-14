import 'package:ling/src/features/chat/models/chat_session_models.dart';

typedef LocalPathExists = bool Function(String path);

ConversationEntryDto filterMissingLocalAudioAttachments(
  ConversationEntryDto entry, {
  required LocalPathExists exists,
}) {
  if (entry.attachments.isEmpty) {
    return entry;
  }
  final attachments = entry.attachments
      .where((attachment) {
        final content = attachment.messageContent;
        if ('${content['type'] ?? ''}'.trim() != 'input_audio') {
          return true;
        }
        final inputAudio = content['input_audio'];
        if (inputAudio is! Map || inputAudio['local'] != true) {
          return true;
        }
        final path = '${inputAudio['url'] ?? attachment.url}'.trim();
        return path.isNotEmpty && exists(path);
      })
      .toList(growable: false);
  if (attachments.length == entry.attachments.length) {
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
    text: entry.text,
    attachments: attachments,
    isStreaming: entry.isStreaming,
    status: entry.status,
    toolCallId: entry.toolCallId,
    toolName: entry.toolName,
    toolArguments: entry.toolArguments,
    toolResult: entry.toolResult,
    durationMs: entry.durationMs,
  );
}
