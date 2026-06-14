import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/features/chat/application/chat_composer_controller.dart';
import 'package:ling/src/features/chat/application/chat_composer_state.dart';
import 'package:ling/src/features/chat/application/chat_session_controller.dart';
import 'package:ling/src/features/chat/application/chat_voice_controller.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';

void main() {
  group('ChatSessionController', () {
    test(
      'prepareForConversationRestore preserves an active composer draft',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(chatSessionControllerProvider);

        controller.enqueuePrompt(
          const QueuedPromptState(
            id: 'queued-1',
            text: 'queued draft',
            source: 'keyboard',
          ),
        );
        controller.appendPendingComposerAttachments([
          const AttachmentDto(
            attachmentId: 'att-1',
            filename: 'image.png',
            url: '',
          ),
        ]);
        controller.setKeyboardComposerOpen(true);
        controller.setUploadingImage(true);
        controller.updateVoiceState(
          isRecordingVoice: true,
          voiceDraftTranscript: 'voice draft',
        );

        controller.prepareForConversationRestore(
          preserveComposerDraft: true,
          preservePendingComposerAttachments: true,
          isUploadingImage: true,
        );

        final composerState = container.read(chatComposerControllerProvider);
        final voiceState = container.read(chatVoiceControllerProvider);
        expect(composerState.pendingPromptQueue, isEmpty);
        expect(composerState.pendingComposerAttachments, hasLength(1));
        expect(composerState.isKeyboardComposerOpen, isTrue);
        expect(composerState.isUploadingImage, isTrue);
        expect(composerState.isProcessingPromptQueue, isFalse);
        expect(composerState.isInterruptingActivePrompt, isFalse);
        expect(composerState.activePromptRunId, isNull);
        expect(voiceState.isRecordingVoice, isFalse);
        expect(voiceState.voiceDraftTranscript, isEmpty);
      },
    );

    test(
      'prepareForConversationRestore clears composer draft when requested',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(chatSessionControllerProvider);

        controller.appendPendingComposerAttachments([
          const AttachmentDto(
            attachmentId: 'att-1',
            filename: 'image.png',
            url: '',
          ),
        ]);
        controller.setKeyboardComposerOpen(true);
        controller.setUploadingImage(true);

        controller.prepareForConversationRestore(preserveComposerDraft: false);

        final composerState = container.read(chatComposerControllerProvider);
        expect(composerState.pendingComposerAttachments, isEmpty);
        expect(composerState.isKeyboardComposerOpen, isFalse);
        expect(composerState.isUploadingImage, isFalse);
      },
    );
  });
}
