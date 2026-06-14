import 'package:ling/src/features/chat/application/chat_composer_state.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';

class ChatPromptMessageBuilder {
  const ChatPromptMessageBuilder();

  Map<String, dynamic> buildPromptMessage({
    required String prompt,
    required List<AttachmentDto> attachments,
    String? messageId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    final message = <String, dynamic>{
      'role': 'user',
      'content': attachments.isEmpty
          ? prompt
          : _buildMessageContent(prompt, attachments),
    };
    final normalizedMessageId = messageId?.trim();
    if (normalizedMessageId != null && normalizedMessageId.isNotEmpty) {
      message['message_id'] = normalizedMessageId;
    }
    if (metadata.isNotEmpty) {
      message['metadata'] = metadata;
    }
    return message;
  }

  List<Map<String, dynamic>> buildReplayMessages({
    required List<ConversationEntryDto> conversation,
    required QueuedPromptState request,
  }) {
    final messages = <Map<String, dynamic>>[];
    for (final entry in conversation) {
      if (entry.isStreaming) {
        continue;
      }
      final content = _buildConversationEntryContent(entry);
      if (content == null) {
        continue;
      }
      messages.add({
        'role': entry.role == 'user' ? 'user' : 'assistant',
        'content': content,
      });
    }
    messages.add(
      buildPromptMessage(
        prompt: request.text,
        attachments: request.attachments,
        messageId: request.id,
        metadata: request.metadata,
      ),
    );
    return messages;
  }

  List<Map<String, dynamic>> _buildMessageContent(
    String prompt,
    List<AttachmentDto> attachments,
  ) {
    final messageContent = <Map<String, dynamic>>[];
    if (prompt.isNotEmpty) {
      messageContent.add({'type': 'text', 'text': prompt});
    }
    for (final attachment in attachments) {
      if (_isLocalOnlyAttachment(attachment)) {
        continue;
      }
      messageContent.add(attachment.messageContent);
    }
    return messageContent;
  }

  Object? _buildConversationEntryContent(ConversationEntryDto entry) {
    if (entry.entryType == 'tool_call') {
      return null;
    }
    final prompt = _entryAgentText(entry).trim();
    final structured = <Map<String, dynamic>>[];
    if (prompt.isNotEmpty) {
      structured.add({'type': 'text', 'text': prompt});
    }
    if (entry.role == 'user') {
      for (final attachment in entry.attachments) {
        if (_isLocalOnlyAttachment(attachment)) {
          continue;
        }
        structured.add(attachment.messageContent);
      }
    }
    if (structured.isEmpty) {
      return null;
    }
    if (structured.length == 1 && entry.attachments.isEmpty) {
      return prompt;
    }
    return structured;
  }

  bool _isLocalOnlyAttachment(AttachmentDto attachment) {
    final inputAudio = attachment.messageContent['input_audio'];
    if (inputAudio is Map) {
      return inputAudio['local'] == true;
    }
    return false;
  }

  String _entryAgentText(ConversationEntryDto entry) {
    if (entry.role != 'user') {
      return entry.text;
    }
    final agentText = entry.metadata?['agent_text'];
    if (agentText is String && agentText.trim().isNotEmpty) {
      return agentText;
    }
    return entry.text;
  }
}
