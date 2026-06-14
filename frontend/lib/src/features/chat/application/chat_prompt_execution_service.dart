import 'dart:async';

import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/features/chat/application/chat_composer_state.dart';
import 'package:ling/src/features/chat/application/chat_prompt_message_builder.dart';
import 'package:ling/src/features/chat/application/chat_runtime_controller.dart';
import 'package:ling/src/features/chat/data/chat_repository.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';

class ChatPromptRunStartResult {
  const ChatPromptRunStartResult({this.serverRunId});

  final String? serverRunId;
}

class ChatPromptExecutionInput {
  const ChatPromptExecutionInput({
    required this.runId,
    required this.request,
    required this.existingSessionId,
    required this.conversation,
    required this.entryMode,
    required this.selectedDate,
    required this.timezone,
  });

  final int runId;
  final QueuedPromptState request;
  final String? existingSessionId;
  final List<ConversationEntryDto> conversation;
  final String entryMode;
  final String selectedDate;
  final String timezone;
}

class ChatPromptExecutionResult {
  const ChatPromptExecutionResult({
    required this.sessionId,
    this.wasInterrupted = false,
    this.serverRunId,
  });

  final String sessionId;
  final bool wasInterrupted;
  final String? serverRunId;
}

class ChatPromptExecutionService {
  ChatPromptExecutionService({
    required ChatRepository repository,
    required ChatRuntimeController runtime,
    ChatPromptMessageBuilder promptMessageBuilder =
        const ChatPromptMessageBuilder(),
  }) : _repository = repository,
       _runtime = runtime,
       _promptMessageBuilder = promptMessageBuilder;

  final ChatRepository _repository;
  final ChatRuntimeController _runtime;
  final ChatPromptMessageBuilder _promptMessageBuilder;

  Future<String> ensureSession({
    required String? existingSessionId,
    required String entryMode,
    required String selectedDate,
    required String timezone,
  }) async {
    final normalizedSessionId = existingSessionId?.trim();
    if (normalizedSessionId != null && normalizedSessionId.isNotEmpty) {
      try {
        final existingSession = await _repository.getSession(
          normalizedSessionId,
        );
        if (existingSession != null &&
            !isSessionStale(existingSession.createdAt)) {
          return normalizedSessionId;
        }
      } catch (error) {
        AppLogger.warn(
          '[Ling][ChatPromptExecution] 检查会话失败 '
          'sessionId=$normalizedSessionId error=$error',
        );
        return normalizedSessionId;
      }
    }
    final session = await _repository.createSession(
      entryMode: entryMode,
      selectedDate: selectedDate,
      timezone: timezone,
    );
    return session.sessionId;
  }

  Map<String, dynamic> buildPromptMessage({
    required String prompt,
    required List<AttachmentDto> attachments,
    String? messageId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return _promptMessageBuilder.buildPromptMessage(
      prompt: prompt,
      attachments: attachments,
      messageId: messageId,
      metadata: metadata,
    );
  }

  List<Map<String, dynamic>> buildReplayMessages({
    required List<ConversationEntryDto> conversation,
    required QueuedPromptState request,
  }) {
    return _promptMessageBuilder.buildReplayMessages(
      conversation: conversation,
      request: request,
    );
  }

  Future<ChatPromptExecutionResult> executePromptRun({
    required ChatPromptExecutionInput input,
    required void Function(String sessionId) onSessionReady,
    required void Function(Map<String, dynamic> event) onEvent,
  }) async {
    final normalizedExistingSessionId = input.existingSessionId?.trim();
    final sessionId = await ensureSession(
      existingSessionId:
          normalizedExistingSessionId == null ||
              normalizedExistingSessionId.isEmpty
          ? null
          : normalizedExistingSessionId,
      entryMode: input.entryMode,
      selectedDate: input.selectedDate,
      timezone: input.timezone,
    );
    final replayMessages =
        normalizedExistingSessionId == null ||
            normalizedExistingSessionId.isEmpty
        ? buildReplayMessages(
            conversation: input.conversation,
            request: input.request,
          )
        : null;
    if (sessionId != normalizedExistingSessionId) {
      onSessionReady(sessionId);
    }
    if (_runtime.isPromptRunInterrupted(input.runId)) {
      return ChatPromptExecutionResult(
        sessionId: sessionId,
        wasInterrupted: true,
      );
    }
    final runStart = await startPromptRun(
      runId: input.runId,
      sessionId: sessionId,
      messages:
          replayMessages ??
          [
            buildPromptMessage(
              prompt: input.request.text,
              attachments: input.request.attachments,
              messageId: input.request.id,
              metadata: input.request.metadata,
            ),
          ],
      systemContext: const <String, dynamic>{},
      onEvent: onEvent,
    );
    return ChatPromptExecutionResult(
      sessionId: sessionId,
      serverRunId: runStart.serverRunId,
    );
  }

  Future<ChatPromptRunStartResult> startPromptRun({
    required int runId,
    required String sessionId,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> systemContext,
    required void Function(Map<String, dynamic> event) onEvent,
  }) async {
    // Realtime updates arrive through the app-level agent events SSE.
    final _ = onEvent;
    final response = await _repository.startSessionRun(
      sessionId: sessionId,
      messages: messages,
      systemContext: systemContext,
    );
    AppLogger.info(
      '[Ling][ChatRun] sessionId=$sessionId localRunId=$runId '
      'serverRunId=${response['run_id'] ?? ''} status=${response['status'] ?? ''}',
    );
    return ChatPromptRunStartResult(
      serverRunId: '${response['run_id'] ?? ''}'.trim(),
    );
  }

  Future<Map<String, dynamic>> injectUserMessage({
    required String sessionId,
    required Object content,
    required String guidanceId,
    Map<String, dynamic>? metadata,
  }) {
    return _repository.injectUserMessage(
      sessionId: sessionId,
      content: content,
      guidanceId: guidanceId,
      metadata: metadata,
    );
  }

  Future<List<Map<String, dynamic>>> listPendingUserInjections(
    String sessionId,
  ) {
    return _repository.listPendingUserInjections(sessionId);
  }

  Future<void> updatePendingUserInjection({
    required String sessionId,
    required String guidanceId,
    required Object content,
  }) {
    return _repository.updatePendingUserInjection(
      sessionId: sessionId,
      guidanceId: guidanceId,
      content: content,
    );
  }

  Future<void> deletePendingUserInjection({
    required String sessionId,
    required String guidanceId,
  }) {
    return _repository.deletePendingUserInjection(
      sessionId: sessionId,
      guidanceId: guidanceId,
    );
  }

  Future<void> interruptActivePrompt({
    required int? activeRunId,
    required String? sessionId,
  }) async {
    if (activeRunId != null) {
      _runtime.markPromptRunInterrupted(activeRunId);
    }
    final interruptFuture = sessionId != null && sessionId.trim().isNotEmpty
        ? _repository.interruptSession(sessionId)
        : null;
    if (interruptFuture != null) {
      await interruptFuture;
    }
  }

  void completePromptRun(int runId) {
    _runtime.clearInterruptedPromptRun(runId);
  }

  bool isSessionStale(DateTime? createdAt) {
    final createdAtValue = createdAt?.toLocal();
    if (createdAtValue == null) {
      return false;
    }
    final now = DateTime.now().toLocal();
    final todayStart = DateTime(now.year, now.month, now.day);
    return createdAtValue.isBefore(todayStart);
  }
}
