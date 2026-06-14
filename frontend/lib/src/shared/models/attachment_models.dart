import 'package:json_annotation/json_annotation.dart';

class AttachmentDto {
  const AttachmentDto({
    required this.attachmentId,
    required this.filename,
    required this.url,
    this.messageContent = const <String, dynamic>{},
  });

  factory AttachmentDto.fromJson(Map<String, dynamic> json) {
    final rawMessageContent = json['message_content'];
    return AttachmentDto(
      attachmentId: '${json['attachment_id'] ?? ''}',
      filename: '${json['filename'] ?? ''}',
      url: '${json['url'] ?? ''}',
      messageContent: rawMessageContent is Map<String, dynamic>
          ? rawMessageContent
          : rawMessageContent is Map
          ? Map<String, dynamic>.from(rawMessageContent)
          : const <String, dynamic>{},
    );
  }

  @JsonKey(name: 'attachment_id')
  final String attachmentId;
  final String filename;
  final String url;
  @JsonKey(name: 'message_content')
  final Map<String, dynamic> messageContent;

  Map<String, dynamic> toJson() {
    return {
      'attachment_id': attachmentId,
      'filename': filename,
      'url': url,
      'message_content': messageContent,
    };
  }
}
