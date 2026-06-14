import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ling/src/features/chat/application/chat_composer_controller.dart';
import 'package:ling/src/features/chat/application/chat_composer_state.dart';
import 'package:ling/src/features/chat/application/chat_conversation_controller.dart';
import 'package:ling/src/features/chat/application/chat_surface_controller.dart';
import 'package:ling/src/features/chat/application/chat_voice_controller.dart';
import 'package:ling/src/features/chat/application/object_reference.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';

class ChatSessionController {
  ChatSessionController(this._ref);

  final Ref _ref;

  ChatConversationController get _conversationController =>
      _ref.read(chatConversationControllerProvider.notifier);
  ChatComposerController get _composerController =>
      _ref.read(chatComposerControllerProvider.notifier);
  ChatVoiceController get _voiceController =>
      _ref.read(chatVoiceControllerProvider.notifier);
  ChatSurfaceController get _surfaceController =>
      _ref.read(chatSurfaceControllerProvider.notifier);

  void resetSessionSurface({
    List<ConversationEntryDto> conversation = const <ConversationEntryDto>[],
    int visibleConversationEntryCount = 10,
    bool hasMoreRemoteConversationEntries = false,
    String? olderConversationBeforeCreatedAt,
    String? olderConversationBeforeRecordId,
    DateTime? conversationStartedAt,
    bool isKeyboardComposerOpen = false,
    bool isUploadingImage = false,
  }) {
    _surfaceController.clear();
    _conversationController.reset(
      conversation: conversation,
      visibleConversationEntryCount: visibleConversationEntryCount,
      hasMoreRemoteConversationEntries: hasMoreRemoteConversationEntries,
      olderConversationBeforeCreatedAt: olderConversationBeforeCreatedAt,
      olderConversationBeforeRecordId: olderConversationBeforeRecordId,
      conversationStartedAt: conversationStartedAt,
    );
    resetTransientUiState(
      isKeyboardComposerOpen: isKeyboardComposerOpen,
      isUploadingImage: isUploadingImage,
    );
  }

  Future<bool> ensureMembershipReadyForChat({
    required bool isAuthenticated,
    required Future<bool> Function() ensureReady,
  }) {
    return _surfaceController.ensureMembershipReadyForChat(
      isAuthenticated: isAuthenticated,
      ensureReady: ensureReady,
    );
  }

  void setKeyboardComposerOpen(bool value) {
    _composerController.setKeyboardComposerOpen(value);
  }

  void appendPendingComposerAttachments(Iterable<AttachmentDto> attachments) {
    _composerController.appendPendingComposerAttachments(attachments);
  }

  void setPendingComposerAttachments(List<AttachmentDto> attachments) {
    _composerController.setPendingComposerAttachments(attachments);
  }

  void clearPendingComposerAttachments() {
    _composerController.clearPendingComposerAttachments();
  }

  void setPendingObjectReferences(List<LingObjectReference> references) {
    _composerController.setPendingObjectReferences(references);
  }

  void clearPendingObjectReferences() {
    _composerController.clearPendingObjectReferences();
  }

  void removePendingComposerAttachmentById(String attachmentId) {
    _composerController.removePendingComposerAttachmentById(attachmentId);
  }

  void clearPendingPromptQueue() {
    _composerController.clearPendingPromptQueue();
  }

  void enqueuePrompt(QueuedPromptState request) {
    _composerController.enqueuePrompt(request);
  }

  void insertPromptAt(int index, QueuedPromptState request) {
    _composerController.insertPromptAt(index, request);
  }

  QueuedPromptState? dequeuePrompt() {
    return _composerController.dequeuePrompt();
  }

  bool removeQueuedPromptById(String requestId) {
    return _composerController.removeQueuedPromptById(requestId);
  }

  ({QueuedPromptState request, int index})? takeQueuedPromptById(
    String requestId,
  ) {
    return _composerController.takeQueuedPromptById(requestId);
  }

  void setUploadingImage(bool value) {
    _composerController.setUploadingImage(value);
  }

  void setProcessingPromptQueue(bool value) {
    _composerController.setProcessingPromptQueue(value);
  }

  void setInterruptingActivePrompt(bool value) {
    _composerController.setInterruptingActivePrompt(value);
  }

  void setActivePromptRunId(int? value) {
    _composerController.setActivePromptRunId(value);
  }

  void setActiveRunRecord(ChatActiveRunRecord? value) {
    _composerController.setActiveRunRecord(value);
  }

  void setActiveQuickPromptIntent(ActiveQuickPromptIntentState? value) {
    _composerController.setActiveQuickPromptIntent(value);
  }

  void resetTransientUiState({
    bool isKeyboardComposerOpen = false,
    bool isUploadingImage = false,
  }) {
    _composerController.resetTransientUiState(
      isKeyboardComposerOpen: isKeyboardComposerOpen,
      isUploadingImage: isUploadingImage,
    );
    _voiceController.reset();
  }

  void prepareForConversationRestore({
    required bool preserveComposerDraft,
    bool preservePendingComposerAttachments = false,
    bool isUploadingImage = false,
  }) {
    _composerController.clearPendingPromptQueue();
    if (!preservePendingComposerAttachments) {
      _composerController.clearPendingComposerAttachments();
    }
    _composerController.setProcessingPromptQueue(false);
    _composerController.setInterruptingActivePrompt(false);
    _composerController.setActivePromptRunId(null);
    _composerController.setActiveRunRecord(null);
    _composerController.setKeyboardComposerOpen(preserveComposerDraft);
    _composerController.setUploadingImage(isUploadingImage);
    _voiceController.reset();
  }

  void updateVoiceState({
    bool? isStartingVoice,
    bool? isRecordingVoice,
    bool? isFinalizingVoice,
    bool? voiceStopRequested,
    String? voiceDraftTranscript,
    String? voiceDraftAudioPath,
    bool? voiceResultHandled,
  }) {
    _voiceController.updateVoiceState(
      isStartingVoice: isStartingVoice,
      isRecordingVoice: isRecordingVoice,
      isFinalizingVoice: isFinalizingVoice,
      voiceStopRequested: voiceStopRequested,
      voiceDraftTranscript: voiceDraftTranscript,
      voiceDraftAudioPath: voiceDraftAudioPath,
      voiceResultHandled: voiceResultHandled,
    );
  }

  void resetVoiceState() {
    _voiceController.reset();
  }

  void setSessionId(String? sessionId) {
    _conversationController.setSessionId(sessionId);
  }

  void setStorageScope(String? storageScope) {
    _conversationController.setStorageScope(storageScope);
  }

  void setLastPersistedConversationStateJson(String? json) {
    _conversationController.setLastPersistedConversationStateJson(json);
  }

  void setPersistedConversationUpdatedAt(DateTime? value) {
    _conversationController.setPersistedConversationUpdatedAt(value);
  }

  void setConversationStartedAt(DateTime? value) {
    _conversationController.setConversationStartedAt(value);
  }

  void clearConversationPersistenceSnapshot() {
    _conversationController.clearPersistenceSnapshot();
  }

  void increaseVisibleConversationEntryCount(int delta) {
    _conversationController.increaseVisibleConversationEntryCount(delta);
  }

  void replaceConversation(
    List<ConversationEntryDto> conversation, {
    int? visibleConversationEntryCount,
    bool? hasMoreRemoteConversationEntries,
    String? olderConversationBeforeCreatedAt,
    bool clearOlderConversationBeforeCreatedAt = false,
    String? olderConversationBeforeRecordId,
    bool clearOlderConversationBeforeRecordId = false,
    DateTime? conversationStartedAt,
  }) {
    _conversationController.replaceConversation(
      conversation,
      visibleConversationEntryCount: visibleConversationEntryCount,
      hasMoreRemoteConversationEntries: hasMoreRemoteConversationEntries,
      olderConversationBeforeCreatedAt: olderConversationBeforeCreatedAt,
      clearOlderConversationBeforeCreatedAt:
          clearOlderConversationBeforeCreatedAt,
      olderConversationBeforeRecordId: olderConversationBeforeRecordId,
      clearOlderConversationBeforeRecordId:
          clearOlderConversationBeforeRecordId,
      conversationStartedAt: conversationStartedAt,
    );
  }

  void setRemoteConversationPagination({
    required bool hasMore,
    String? beforeCreatedAt,
    String? beforeRecordId,
  }) {
    _conversationController.setRemoteConversationPagination(
      hasMore: hasMore,
      beforeCreatedAt: beforeCreatedAt,
      beforeRecordId: beforeRecordId,
    );
  }

  void appendConversationEntry(ConversationEntryDto entry) {
    _conversationController.appendConversationEntry(entry);
  }

  void upsertConversationEntry(ConversationEntryDto entry) {
    _conversationController.upsertConversationEntry(entry);
  }

  void removeConversationEntryById(String entryId) {
    _conversationController.removeConversationEntryById(entryId);
  }

  void settleStreamingConversationEntries() {
    _conversationController.settleStreamingConversationEntries();
  }

  void applyConversationEvent(Map<String, dynamic> event) {
    _conversationController.applyConversationEvent(event);
  }
}

final chatSessionControllerProvider = Provider<ChatSessionController>((ref) {
  return ChatSessionController(ref);
});
