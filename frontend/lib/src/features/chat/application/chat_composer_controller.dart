import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ling/src/features/chat/application/chat_composer_state.dart';
import 'package:ling/src/features/chat/application/object_reference.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';

class ChatComposerController extends Notifier<ChatComposerState> {
  @override
  ChatComposerState build() => const ChatComposerState();

  void clearPendingPromptQueue() {
    if (state.pendingPromptQueue.isEmpty) {
      return;
    }
    setPendingPromptQueue(const <QueuedPromptState>[]);
  }

  void setPendingPromptQueue(List<QueuedPromptState> queue) {
    state = state.copyWith(
      pendingPromptQueue: List<QueuedPromptState>.unmodifiable(queue),
    );
  }

  void enqueuePrompt(QueuedPromptState request) {
    final nextQueue = state.pendingPromptQueue.toList(growable: true)
      ..add(request);
    setPendingPromptQueue(nextQueue);
  }

  void insertPromptAt(int index, QueuedPromptState request) {
    final nextQueue = state.pendingPromptQueue.toList(growable: true);
    final safeIndex = index.clamp(0, nextQueue.length);
    nextQueue.insert(safeIndex, request);
    setPendingPromptQueue(nextQueue);
  }

  QueuedPromptState? dequeuePrompt() {
    if (state.pendingPromptQueue.isEmpty) {
      return null;
    }
    final nextQueue = state.pendingPromptQueue.toList(growable: true);
    final index = nextQueue.indexWhere((request) => !request.isGuidance);
    if (index < 0) {
      return null;
    }
    final nextRequest = nextQueue.removeAt(index);
    setPendingPromptQueue(nextQueue);
    return nextRequest;
  }

  bool removeQueuedPromptById(String requestId) {
    final nextQueue = state.pendingPromptQueue.toList(growable: true);
    final index = nextQueue.indexWhere((request) => request.id == requestId);
    if (index < 0) {
      return false;
    }
    nextQueue.removeAt(index);
    setPendingPromptQueue(nextQueue);
    return true;
  }

  ({QueuedPromptState request, int index})? takeQueuedPromptById(
    String requestId,
  ) {
    final nextQueue = state.pendingPromptQueue.toList(growable: true);
    final index = nextQueue.indexWhere((request) => request.id == requestId);
    if (index < 0) {
      return null;
    }
    final request = nextQueue.removeAt(index);
    setPendingPromptQueue(nextQueue);
    return (request: request, index: index);
  }

  void setPendingComposerAttachments(List<AttachmentDto> attachments) {
    state = state.copyWith(
      pendingComposerAttachments: List<AttachmentDto>.unmodifiable(attachments),
    );
  }

  void clearPendingComposerAttachments() {
    if (state.pendingComposerAttachments.isEmpty) {
      return;
    }
    setPendingComposerAttachments(const <AttachmentDto>[]);
  }

  void setPendingObjectReferences(List<LingObjectReference> references) {
    state = state.copyWith(
      pendingObjectReferences: List<LingObjectReference>.unmodifiable(
        references.take(1),
      ),
    );
  }

  void clearPendingObjectReferences() {
    if (state.pendingObjectReferences.isEmpty) {
      return;
    }
    setPendingObjectReferences(const <LingObjectReference>[]);
  }

  void appendPendingComposerAttachments(Iterable<AttachmentDto> attachments) {
    final normalizedAttachments = attachments.toList(growable: false);
    if (normalizedAttachments.isEmpty) {
      return;
    }
    final nextAttachments = state.pendingComposerAttachments.toList(
      growable: true,
    )..addAll(normalizedAttachments);
    setPendingComposerAttachments(nextAttachments);
  }

  bool removePendingComposerAttachmentById(String attachmentId) {
    final nextAttachments = state.pendingComposerAttachments.toList(
      growable: true,
    );
    final originalLength = nextAttachments.length;
    nextAttachments.removeWhere(
      (attachment) => attachment.attachmentId == attachmentId,
    );
    if (nextAttachments.length == originalLength) {
      return false;
    }
    setPendingComposerAttachments(nextAttachments);
    return true;
  }

  void setProcessingPromptQueue(bool value) {
    state = state.copyWith(isProcessingPromptQueue: value);
  }

  void setInterruptingActivePrompt(bool value) {
    state = state.copyWith(isInterruptingActivePrompt: value);
  }

  void setActivePromptRunId(int? value) {
    state = state.copyWith(
      activePromptRunId: value,
      clearActivePromptRunId: value == null,
    );
  }

  void setActiveRunRecord(ChatActiveRunRecord? value) {
    state = state.copyWith(
      activeRunRecord: value,
      clearActiveRunRecord: value == null,
    );
  }

  void setActiveQuickPromptIntent(ActiveQuickPromptIntentState? value) {
    state = state.copyWith(
      activeQuickPromptIntent: value,
      clearActiveQuickPromptIntent: value == null,
    );
  }

  void setKeyboardComposerOpen(bool value) {
    state = state.copyWith(isKeyboardComposerOpen: value);
  }

  void setUploadingImage(bool value) {
    state = state.copyWith(isUploadingImage: value);
  }

  void resetTransientUiState({
    bool isKeyboardComposerOpen = false,
    bool isUploadingImage = false,
  }) {
    state = state.copyWith(
      pendingPromptQueue: const <QueuedPromptState>[],
      pendingComposerAttachments: const <AttachmentDto>[],
      pendingObjectReferences: const <LingObjectReference>[],
      isProcessingPromptQueue: false,
      isInterruptingActivePrompt: false,
      clearActivePromptRunId: true,
      clearActiveRunRecord: true,
      clearActiveQuickPromptIntent: true,
      isKeyboardComposerOpen: isKeyboardComposerOpen,
      isUploadingImage: isUploadingImage,
    );
  }
}

final chatComposerControllerProvider =
    NotifierProvider<ChatComposerController, ChatComposerState>(
      ChatComposerController.new,
    );
