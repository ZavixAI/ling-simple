import 'package:ling/src/features/chat/application/chat_composer_state.dart';
import 'package:ling/src/features/chat/application/conversation_attachment.dart';

class LingPendingPromptRequest {
  LingPendingPromptRequest({
    required this.id,
    required this.text,
    required this.source,
    this.displayText,
    this.metadata = const <String, dynamic>{},
    this.isGuidance = false,
    required List<LingConversationAttachment> attachments,
  }) : attachments = List<LingConversationAttachment>.from(attachments);

  factory LingPendingPromptRequest.fromState(QueuedPromptState state) {
    return LingPendingPromptRequest(
      id: state.id,
      text: state.text,
      source: state.source,
      displayText: state.displayText,
      metadata: state.metadata,
      isGuidance: state.isGuidance,
      attachments: state.attachments
          .map(LingConversationAttachment.fromDto)
          .toList(growable: false),
    );
  }

  final String id;
  final String text;
  final String source;
  final String? displayText;
  final Map<String, dynamic> metadata;
  final bool isGuidance;
  final List<LingConversationAttachment> attachments;

  QueuedPromptState toState() {
    return QueuedPromptState(
      id: id,
      text: text,
      source: source,
      displayText: displayText,
      metadata: metadata,
      isGuidance: isGuidance,
      attachments: attachments
          .map((attachment) => attachment.toDto())
          .toList(growable: false),
    );
  }
}
