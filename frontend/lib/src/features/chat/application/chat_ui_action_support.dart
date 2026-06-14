import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/features/chat/application/conversation_attachment.dart';
import 'package:ling/src/features/chat/data/apple_speech_recognition_bridge.dart';
import 'package:ling/src/features/chat/data/conversation_attachment_save_service.dart';

typedef ChatSpeechAuthorizationState = AppleSpeechAuthorizationState;
typedef ChatSpeechEvent = AppleSpeechEvent;
typedef ChatConversationAttachmentSaveStatus = ConversationAttachmentSaveStatus;

class ChatUiActionSupport {
  const ChatUiActionSupport({
    required AppleSpeechRecognitionBridge speechRecognitionBridge,
    required ConversationAttachmentSaveService attachmentSaveService,
  }) : _speechRecognitionBridge = speechRecognitionBridge,
       _attachmentSaveService = attachmentSaveService;

  final AppleSpeechRecognitionBridge _speechRecognitionBridge;
  final ConversationAttachmentSaveService _attachmentSaveService;

  Future<ChatSpeechAuthorizationState> getMicrophoneAuthorizationState() {
    return _speechRecognitionBridge.getAuthorizationState();
  }

  Future<void> openMicrophoneSystemSettings() {
    return _speechRecognitionBridge.openSystemSettings();
  }

  Future<Duration> getSpeechPreviewDuration(String path) {
    return _speechRecognitionBridge.getPreviewDuration(path: path);
  }

  Future<Duration> playSpeechPreview(String path) {
    return _speechRecognitionBridge.playPreview(path: path);
  }

  Future<void> stopSpeechPreview() {
    return _speechRecognitionBridge.stopPreview();
  }

  Future<ConversationAttachmentSaveResult> saveConversationAttachmentsToLocal(
    Iterable<LingConversationAttachment> attachments,
  ) {
    return _attachmentSaveService.saveAttachmentsToLocal(attachments);
  }
}

final chatUiActionSupportProvider = Provider<ChatUiActionSupport>((ref) {
  return ChatUiActionSupport(
    speechRecognitionBridge: ref.read(appleSpeechRecognitionBridgeProvider),
    attachmentSaveService: ref.read(conversationAttachmentSaveServiceProvider),
  );
});
