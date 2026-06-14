import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/features/chat/application/chat_composer_state.dart';
import 'package:ling/src/features/chat/application/chat_runtime_controller.dart';
import 'package:ling/src/features/chat/application/chat_session_controller.dart';
import 'package:ling/src/features/chat/application/chat_session_orchestrator.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';

class ChatQueueOrchestrator {
  const ChatQueueOrchestrator();

  bool enqueuePrompt({
    required String text,
    required String source,
    required Iterable<AttachmentDto> attachments,
    String? displayText,
    Map<String, dynamic> metadata = const <String, dynamic>{},
    bool isGuidance = false,
    required ChatRuntimeController runtime,
    required ChatSessionController controller,
  }) {
    final prompt = text.trim();
    final normalizedDisplayText = displayText?.trim();
    final normalizedAttachments = attachments.toList(growable: false);
    if (prompt.isEmpty && normalizedAttachments.isEmpty) {
      return false;
    }

    controller.enqueuePrompt(
      QueuedPromptState(
        id: runtime.nextQueuedPromptId(),
        text: prompt,
        source: source,
        displayText:
            normalizedDisplayText == null || normalizedDisplayText.isEmpty
            ? null
            : normalizedDisplayText,
        metadata: metadata,
        attachments: normalizedAttachments,
        isGuidance: isGuidance,
      ),
    );
    return true;
  }

  QueuedPromptState? beginQueuedPrompt({
    required bool isMounted,
    required bool isProcessingPromptQueue,
    required bool hasPendingPromptQueue,
    required ChatSessionController controller,
  }) {
    if (!isMounted) {
      controller.clearPendingPromptQueue();
      controller.setProcessingPromptQueue(false);
      return null;
    }
    if (isProcessingPromptQueue || !hasPendingPromptQueue) {
      return null;
    }

    final nextRequest = controller.dequeuePrompt();
    if (nextRequest == null) {
      return null;
    }
    controller.setProcessingPromptQueue(true);
    return nextRequest;
  }

  Future<bool> processPromptRequest({
    required QueuedPromptState request,
    required ChatRuntimeController runtime,
    required ChatSessionController controller,
    required ChatSessionOrchestrator sessionOrchestrator,
    required String? existingSessionId,
    required List<ConversationEntryDto> conversation,
    required String entryMode,
    required String selectedDate,
    required String timezone,
    required bool Function() isAppInForeground,
    required Iterable<ConversationEntryDto> Function() currentConversation,
    required int? Function() currentActivePromptRunId,
    required bool Function() isInterruptingActivePrompt,
    required void Function(ConversationEntryDto entry) appendConversationEntry,
    required Future<bool> Function(
      Object error,
      QueuedPromptState request,
      String userEntryId,
    )
    handlePromptExecutionError,
    required void Function(String sessionId) onSessionReady,
    required void Function(Map<String, dynamic> event) onConversationEvent,
    Future<QueuedPromptState> Function(
      QueuedPromptState request,
      ConversationEntryDto userEntry,
    )?
    prepareRequestForRun,
    Future<bool> Function({
      required ChatPromptExecutionResult promptResult,
      required QueuedPromptState request,
      required int localRunId,
    })?
    waitForRunCompletion,
    required void Function(Object error) showError,
    required void Function() settleStreamingConversationEntries,
    required void Function() notifyDockSurfaceChanged,
    required void Function(int completedRunId) drainPendingPromptQueue,
  }) async {
    final runId = runtime.nextPromptRunId();
    controller.setActivePromptRunId(runId);
    final userEntryMetadata = <String, dynamic>{
      ...request.metadata,
      if (request.displayText != null) ...{
        'agent_text': request.text,
        'display_text': request.displayText,
      },
    };

    final userEntry = sessionOrchestrator.buildUserConversationEntry(
      prompt: request.displayText ?? request.text,
      attachments: request.attachments,
      messageId: request.id,
      metadata: userEntryMetadata.isEmpty ? null : userEntryMetadata,
    );
    appendConversationEntry(userEntry);
    var runRequest = request;

    try {
      final prepare = prepareRequestForRun;
      if (prepare != null) {
        runRequest = await prepare(request, userEntry);
      }
      final promptResult = await sessionOrchestrator.executePromptRun(
        input: ChatPromptExecutionInput(
          runId: runId,
          request: runRequest,
          existingSessionId: existingSessionId,
          conversation: conversation,
          entryMode: entryMode,
          selectedDate: selectedDate,
          timezone: timezone,
        ),
        onSessionReady: onSessionReady,
        onEvent: onConversationEvent,
      );
      if (promptResult.wasInterrupted) {
        return false;
      }
      final completionWaiter =
          waitForRunCompletion ??
          ({
            required ChatPromptExecutionResult promptResult,
            required QueuedPromptState request,
            required int localRunId,
          }) async {
            return true;
          };
      return await completionWaiter(
        promptResult: promptResult,
        request: runRequest,
        localRunId: runId,
      );
    } catch (error) {
      if (sessionOrchestrator.isPromptRunInterrupted(runId)) {
        return false;
      }
      final handled = await handlePromptExecutionError(
        error,
        request,
        userEntry.id,
      );
      if (handled) {
        return false;
      }
      AppLogger.warn('[Ling][ChatQueue] 对话请求失败，已隐藏页面错误 error=$error');
      appendConversationEntry(sessionOrchestrator.buildPromptErrorEntry(error));
      return false;
    } finally {
      if (currentActivePromptRunId() == runId) {
        controller.setActivePromptRunId(null);
      }
      controller.setActiveRunRecord(null);
      sessionOrchestrator.completePromptRun(runId);
      settleStreamingConversationEntries();
      controller.setProcessingPromptQueue(false);
      notifyDockSurfaceChanged();
      if (!isInterruptingActivePrompt()) {
        drainPendingPromptQueue(runId);
      }
    }
  }
}

final chatQueueOrchestratorProvider = Provider<ChatQueueOrchestrator>((ref) {
  return const ChatQueueOrchestrator();
});
