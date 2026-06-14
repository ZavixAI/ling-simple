import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/chat/application/chat_composer_state.dart';
import 'package:ling/src/features/chat/application/chat_image_upload_service.dart';
import 'package:ling/src/features/chat/application/chat_prompt_execution_service.dart';
import 'package:ling/src/features/chat/application/chat_prompt_message_builder.dart';
import 'package:ling/src/features/chat/application/chat_runtime_controller.dart';
import 'package:ling/src/features/chat/application/chat_session_recovery_service.dart';
import 'package:ling/src/features/chat/data/chat_repository.dart';
import 'package:ling/src/features/chat/data/native_camera_picker_bridge.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';

export 'package:ling/src/features/chat/application/chat_image_upload_service.dart'
    show ChatImageUploadBatchResult, UploadedConversationImage;
export 'package:ling/src/features/chat/application/chat_prompt_execution_service.dart'
    show
        ChatPromptExecutionInput,
        ChatPromptExecutionResult,
        ChatPromptRunStartResult;
export 'package:ling/src/features/chat/application/chat_session_recovery_service.dart'
    show
        ChatLocalConversationRecoveryStatus,
        ChatPersistedConversationRestoreResult,
        ChatPersistedConversationRestoreStatus,
        ChatRecoverableSession,
        ChatRecoverableSessionSource,
        ChatRecoveredSessionConversation;

class ChatSessionOrchestrator {
  ChatSessionOrchestrator({
    required ChatRepository repository,
    required ChatRuntimeController runtime,
    NativeCameraPickerBridge? nativeCameraPickerBridge,
    ImagePicker? imagePicker,
    ChatPromptMessageBuilder promptMessageBuilder =
        const ChatPromptMessageBuilder(),
  }) : _runtime = runtime,
       _promptExecution = ChatPromptExecutionService(
         repository: repository,
         runtime: runtime,
         promptMessageBuilder: promptMessageBuilder,
       ),
       _sessionRecovery = ChatSessionRecoveryService(repository: repository),
       _imageUpload = ChatImageUploadService(
         repository: repository,
         nativeCameraPickerBridge: nativeCameraPickerBridge,
         imagePicker: imagePicker,
       );

  final ChatRuntimeController _runtime;
  final ChatPromptExecutionService _promptExecution;
  final ChatSessionRecoveryService _sessionRecovery;
  final ChatImageUploadService _imageUpload;

  bool isPromptRunInterrupted(int runId) =>
      _runtime.isPromptRunInterrupted(runId);

  Future<String> ensureSession({
    required String? existingSessionId,
    required String entryMode,
    required String selectedDate,
    required String timezone,
  }) {
    return _promptExecution.ensureSession(
      existingSessionId: existingSessionId,
      entryMode: entryMode,
      selectedDate: selectedDate,
      timezone: timezone,
    );
  }

  Map<String, dynamic> buildPromptMessage({
    required String prompt,
    required List<AttachmentDto> attachments,
    String? messageId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return _promptExecution.buildPromptMessage(
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
    return _promptExecution.buildReplayMessages(
      conversation: conversation,
      request: request,
    );
  }

  Future<({String payload, DateTime persistedAt})?>
  saveConversationStateIfChanged({
    required String storageScope,
    required String? sessionId,
    required List<ConversationEntryDto> conversation,
    ChatActiveRunRecord? activeRun,
    required String? previousPayload,
  }) {
    return _sessionRecovery.saveConversationStateIfChanged(
      storageScope: storageScope,
      sessionId: sessionId,
      conversation: conversation,
      activeRun: activeRun,
      previousPayload: previousPayload,
    );
  }

  Future<PersistedConversationCacheSnapshot?> readConversationState(
    String storageScope,
  ) {
    return _sessionRecovery.readConversationState(storageScope);
  }

  Future<List<ConversationEntryDto>> getSessionEntries(String sessionId) {
    return _sessionRecovery.getSessionEntries(sessionId);
  }

  Future<AgentSessionSummary?> getLatestSession() {
    return _sessionRecovery.getLatestSession();
  }

  Future<AgentSessionSummary?> getSession(String sessionId) {
    return _sessionRecovery.getSession(sessionId);
  }

  bool isSessionStale(DateTime? createdAt) {
    return _sessionRecovery.isSessionStale(createdAt);
  }

  String? resolveStorageScope({required UserProfile? profile}) {
    return _sessionRecovery.resolveStorageScope(profile: profile);
  }

  List<ConversationEntryDto> buildPersistableConversation(
    Iterable<ConversationEntryDto> conversation, {
    String? currentSessionId,
  }) {
    return _sessionRecovery.buildPersistableConversation(
      conversation,
      currentSessionId: currentSessionId,
    );
  }

  ConversationEntryDto buildUserConversationEntry({
    required String prompt,
    List<AttachmentDto> attachments = const <AttachmentDto>[],
    String? messageId,
    Map<String, dynamic>? metadata,
  }) {
    final createdAt = DateTime.now();
    final normalizedMessageId = messageId?.trim();
    return ConversationEntryDto(
      id: 'user_${createdAt.microsecondsSinceEpoch}',
      entryType: 'user_message',
      role: 'user',
      createdAt: createdAt,
      messageId: normalizedMessageId == null || normalizedMessageId.isEmpty
          ? null
          : normalizedMessageId,
      messageType: 'user_input',
      text: prompt,
      attachments: List<AttachmentDto>.unmodifiable(attachments),
      isStreaming: false,
      metadata: metadata == null ? null : Map<String, dynamic>.from(metadata),
      status: 'completed',
    );
  }

  ConversationEntryDto buildPromptErrorEntry(Object error) {
    return ConversationEntryDto(
      id: 'error_${DateTime.now().microsecondsSinceEpoch}',
      entryType: 'assistant_message',
      role: 'assistant',
      createdAt: DateTime.now(),
      messageType: 'assistant_notice',
      text: 'Ling的服务器出小差了，稍后再试。',
      attachments: const <AttachmentDto>[],
      isStreaming: false,
      status: 'completed',
    );
  }

  bool hasCompletedAssistantReply(Iterable<ConversationEntryDto> conversation) {
    return conversation.any(
      (entry) =>
          entry.entryType == 'assistant_message' &&
          entry.text.trim().isNotEmpty,
    );
  }

  Future<ChatPersistedConversationRestoreResult> restorePersistedConversation({
    required String storageScope,
    required Duration maxAge,
  }) {
    return _sessionRecovery.restorePersistedConversation(
      storageScope: storageScope,
      maxAge: maxAge,
    );
  }

  ChatLocalConversationRecoveryStatus assessLocalConversationRecoveryStatus(
    Iterable<ConversationEntryDto> conversation,
  ) {
    return _sessionRecovery.assessLocalConversationRecoveryStatus(conversation);
  }

  bool shouldUseFreshLocalConversationForRecovery({
    required Iterable<ConversationEntryDto> localConversation,
    required ChatRecoverableSessionSource sessionSource,
    required bool isProcessingPromptQueue,
    required int? activePromptRunId,
    required DateTime? persistedUpdatedAt,
    required Duration gracePeriod,
    bool allowFreshLocalConversationShortcut = true,
  }) {
    return _sessionRecovery.shouldUseFreshLocalConversationForRecovery(
      localConversation: localConversation,
      sessionSource: sessionSource,
      isProcessingPromptQueue: isProcessingPromptQueue,
      activePromptRunId: activePromptRunId,
      persistedUpdatedAt: persistedUpdatedAt,
      gracePeriod: gracePeriod,
      allowFreshLocalConversationShortcut: allowFreshLocalConversationShortcut,
    );
  }

  Future<ChatRecoveredSessionConversation> recoverSessionConversation(
    String sessionId,
  ) {
    return _sessionRecovery.recoverSessionConversation(sessionId);
  }

  Future<ChatSessionEntriesSnapshot> getOlderConversationEntries({
    required String currentSessionId,
    required ChatSessionEntriesCursor before,
    int? limit,
  }) {
    return _sessionRecovery.getOlderConversationEntries(
      currentSessionId: currentSessionId,
      before: before,
      limit: limit,
    );
  }

  Future<ChatImageUploadBatchResult> uploadConversationImages(
    List<XFile> pickedFiles,
  ) {
    return _imageUpload.uploadConversationImages(pickedFiles);
  }

  Future<AttachmentDto> uploadConversationAudio({
    required List<int> bytes,
    required String filename,
  }) {
    return _imageUpload.uploadConversationAudio(
      bytes: bytes,
      filename: filename,
    );
  }

  Future<List<XFile>> pickConversationImages({
    required ImageSource source,
    required AppPlatform platform,
  }) {
    return _imageUpload.pickConversationImages(
      source: source,
      platform: platform,
    );
  }

  Future<ChatPromptExecutionResult> executePromptRun({
    required ChatPromptExecutionInput input,
    required void Function(String sessionId) onSessionReady,
    required void Function(Map<String, dynamic> event) onEvent,
  }) {
    return _promptExecution.executePromptRun(
      input: input,
      onSessionReady: onSessionReady,
      onEvent: onEvent,
    );
  }

  Future<ChatPromptRunStartResult> startPromptRun({
    required int runId,
    required String sessionId,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> systemContext,
    required void Function(Map<String, dynamic> event) onEvent,
  }) {
    return _promptExecution.startPromptRun(
      runId: runId,
      sessionId: sessionId,
      messages: messages,
      systemContext: systemContext,
      onEvent: onEvent,
    );
  }

  Future<Map<String, dynamic>> injectUserMessage({
    required String sessionId,
    required Object content,
    required String guidanceId,
    Map<String, dynamic>? metadata,
  }) {
    return _promptExecution.injectUserMessage(
      sessionId: sessionId,
      content: content,
      guidanceId: guidanceId,
      metadata: metadata,
    );
  }

  Future<List<Map<String, dynamic>>> listPendingUserInjections(
    String sessionId,
  ) {
    return _promptExecution.listPendingUserInjections(sessionId);
  }

  Future<void> updatePendingUserInjection({
    required String sessionId,
    required String guidanceId,
    required Object content,
  }) {
    return _promptExecution.updatePendingUserInjection(
      sessionId: sessionId,
      guidanceId: guidanceId,
      content: content,
    );
  }

  Future<void> deletePendingUserInjection({
    required String sessionId,
    required String guidanceId,
  }) {
    return _promptExecution.deletePendingUserInjection(
      sessionId: sessionId,
      guidanceId: guidanceId,
    );
  }

  Future<void> interruptActivePrompt({
    required int? activeRunId,
    required String? sessionId,
  }) {
    return _promptExecution.interruptActivePrompt(
      activeRunId: activeRunId,
      sessionId: sessionId,
    );
  }

  void completePromptRun(int runId) {
    _promptExecution.completePromptRun(runId);
  }
}

final chatSessionOrchestratorProvider = Provider<ChatSessionOrchestrator>((
  ref,
) {
  return ChatSessionOrchestrator(
    repository: ref.read(chatRepositoryProvider),
    runtime: ref.read(chatRuntimeControllerProvider),
    nativeCameraPickerBridge: ref.read(nativeCameraPickerBridgeProvider),
    imagePicker: ref.read(imagePickerProvider),
  );
});
