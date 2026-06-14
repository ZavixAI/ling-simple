import 'dart:typed_data';

import 'package:ling/src/features/chat/models/chat_session_models.dart';

class LingConversationAttachment {
  const LingConversationAttachment({
    required this.attachmentId,
    required this.filename,
    required this.url,
    required this.messageContent,
    this.bytes,
  });

  factory LingConversationAttachment.fromDto(AttachmentDto dto) {
    return LingConversationAttachment(
      attachmentId: dto.attachmentId,
      filename: dto.filename,
      url: dto.url,
      messageContent: dto.messageContent,
    );
  }

  final String attachmentId;
  final String filename;
  final String url;
  final Uint8List? bytes;
  final Map<String, dynamic> messageContent;

  bool get isAudio => '${messageContent['type'] ?? ''}'.trim() == 'input_audio';

  String get audioUrl {
    final inputAudio = messageContent['input_audio'];
    if (inputAudio is Map) {
      return '${inputAudio['url'] ?? ''}'.trim();
    }
    return url.trim();
  }

  LingConversationAttachment copyWithBytes(Uint8List? nextBytes) {
    return LingConversationAttachment(
      attachmentId: attachmentId,
      filename: filename,
      url: url,
      bytes: nextBytes,
      messageContent: messageContent,
    );
  }

  AttachmentDto toDto() {
    return AttachmentDto(
      attachmentId: attachmentId,
      filename: filename,
      url: url,
      messageContent: messageContent,
    );
  }
}
