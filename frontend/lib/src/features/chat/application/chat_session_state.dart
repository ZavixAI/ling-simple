import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ling/src/features/chat/application/chat_composer_controller.dart';
import 'package:ling/src/features/chat/application/chat_composer_state.dart';
import 'package:ling/src/features/chat/application/chat_conversation_controller.dart';
import 'package:ling/src/features/chat/application/chat_conversation_state.dart';
import 'package:ling/src/features/chat/application/chat_surface_controller.dart';
import 'package:ling/src/features/chat/application/chat_voice_controller.dart';
import 'package:ling/src/features/chat/application/object_reference.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';

class ChatSessionState {
  const ChatSessionState({
    this.sessionId,
    this.conversation = const <ConversationEntryDto>[],
    this.pendingPromptQueue = const <QueuedPromptState>[],
    this.pendingComposerAttachments = const <AttachmentDto>[],
    this.pendingObjectReferences = const <LingObjectReference>[],
    this.visibleConversationEntryCount = 10,
    this.hasMoreRemoteConversationEntries = false,
    this.olderConversationBeforeCreatedAt,
    this.olderConversationBeforeRecordId,
    this.conversationStartedAt,
    this.storageScope,
    this.lastPersistedConversationStateJson,
    this.persistedConversationUpdatedAt,
    this.isProcessingPromptQueue = false,
    this.isInterruptingActivePrompt = false,
    this.activePromptRunId,
    this.activeRunRecord,
    this.activeQuickPromptIntent,
    this.isKeyboardComposerOpen = false,
    this.isUploadingImage = false,
    this.isStartingVoice = false,
    this.isRecordingVoice = false,
    this.isFinalizingVoice = false,
    this.voiceStopRequested = false,
    this.voiceDraftTranscript = '',
    this.voiceDraftAudioPath = '',
    this.voiceResultHandled = false,
    this.isAwaitingMembershipSummary = false,
  });

  final String? sessionId;
  final List<ConversationEntryDto> conversation;
  final List<QueuedPromptState> pendingPromptQueue;
  final List<AttachmentDto> pendingComposerAttachments;
  final List<LingObjectReference> pendingObjectReferences;
  final int visibleConversationEntryCount;
  final bool hasMoreRemoteConversationEntries;
  final String? olderConversationBeforeCreatedAt;
  final String? olderConversationBeforeRecordId;
  final DateTime? conversationStartedAt;
  final String? storageScope;
  final String? lastPersistedConversationStateJson;
  final DateTime? persistedConversationUpdatedAt;
  final bool isProcessingPromptQueue;
  final bool isInterruptingActivePrompt;
  final int? activePromptRunId;
  final ChatActiveRunRecord? activeRunRecord;
  final ActiveQuickPromptIntentState? activeQuickPromptIntent;
  final bool isKeyboardComposerOpen;
  final bool isUploadingImage;
  final bool isStartingVoice;
  final bool isRecordingVoice;
  final bool isFinalizingVoice;
  final bool voiceStopRequested;
  final String voiceDraftTranscript;
  final String voiceDraftAudioPath;
  final bool voiceResultHandled;
  final bool isAwaitingMembershipSummary;

  ChatSessionState copyWith({
    String? sessionId,
    bool clearSessionId = false,
    List<ConversationEntryDto>? conversation,
    List<QueuedPromptState>? pendingPromptQueue,
    List<AttachmentDto>? pendingComposerAttachments,
    List<LingObjectReference>? pendingObjectReferences,
    int? visibleConversationEntryCount,
    bool? hasMoreRemoteConversationEntries,
    String? olderConversationBeforeCreatedAt,
    bool clearOlderConversationBeforeCreatedAt = false,
    String? olderConversationBeforeRecordId,
    bool clearOlderConversationBeforeRecordId = false,
    DateTime? conversationStartedAt,
    bool clearConversationStartedAt = false,
    String? storageScope,
    bool clearStorageScope = false,
    String? lastPersistedConversationStateJson,
    bool clearLastPersistedConversationStateJson = false,
    DateTime? persistedConversationUpdatedAt,
    bool clearPersistedConversationUpdatedAt = false,
    bool? isProcessingPromptQueue,
    bool? isInterruptingActivePrompt,
    int? activePromptRunId,
    bool clearActivePromptRunId = false,
    ChatActiveRunRecord? activeRunRecord,
    bool clearActiveRunRecord = false,
    ActiveQuickPromptIntentState? activeQuickPromptIntent,
    bool clearActiveQuickPromptIntent = false,
    bool? isKeyboardComposerOpen,
    bool? isUploadingImage,
    bool? isStartingVoice,
    bool? isRecordingVoice,
    bool? isFinalizingVoice,
    bool? voiceStopRequested,
    String? voiceDraftTranscript,
    String? voiceDraftAudioPath,
    bool? voiceResultHandled,
    bool? isAwaitingMembershipSummary,
  }) {
    return ChatSessionState(
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      conversation: conversation ?? this.conversation,
      pendingPromptQueue: pendingPromptQueue ?? this.pendingPromptQueue,
      pendingComposerAttachments:
          pendingComposerAttachments ?? this.pendingComposerAttachments,
      pendingObjectReferences:
          pendingObjectReferences ?? this.pendingObjectReferences,
      visibleConversationEntryCount:
          visibleConversationEntryCount ?? this.visibleConversationEntryCount,
      hasMoreRemoteConversationEntries:
          hasMoreRemoteConversationEntries ??
          this.hasMoreRemoteConversationEntries,
      olderConversationBeforeCreatedAt: clearOlderConversationBeforeCreatedAt
          ? null
          : (olderConversationBeforeCreatedAt ??
                this.olderConversationBeforeCreatedAt),
      olderConversationBeforeRecordId: clearOlderConversationBeforeRecordId
          ? null
          : (olderConversationBeforeRecordId ??
                this.olderConversationBeforeRecordId),
      conversationStartedAt: clearConversationStartedAt
          ? null
          : (conversationStartedAt ?? this.conversationStartedAt),
      storageScope: clearStorageScope
          ? null
          : (storageScope ?? this.storageScope),
      lastPersistedConversationStateJson:
          clearLastPersistedConversationStateJson
          ? null
          : (lastPersistedConversationStateJson ??
                this.lastPersistedConversationStateJson),
      persistedConversationUpdatedAt: clearPersistedConversationUpdatedAt
          ? null
          : (persistedConversationUpdatedAt ??
                this.persistedConversationUpdatedAt),
      isProcessingPromptQueue:
          isProcessingPromptQueue ?? this.isProcessingPromptQueue,
      isInterruptingActivePrompt:
          isInterruptingActivePrompt ?? this.isInterruptingActivePrompt,
      activePromptRunId: clearActivePromptRunId
          ? null
          : (activePromptRunId ?? this.activePromptRunId),
      activeRunRecord: clearActiveRunRecord
          ? null
          : (activeRunRecord ?? this.activeRunRecord),
      activeQuickPromptIntent: clearActiveQuickPromptIntent
          ? null
          : (activeQuickPromptIntent ?? this.activeQuickPromptIntent),
      isKeyboardComposerOpen:
          isKeyboardComposerOpen ?? this.isKeyboardComposerOpen,
      isUploadingImage: isUploadingImage ?? this.isUploadingImage,
      isStartingVoice: isStartingVoice ?? this.isStartingVoice,
      isRecordingVoice: isRecordingVoice ?? this.isRecordingVoice,
      isFinalizingVoice: isFinalizingVoice ?? this.isFinalizingVoice,
      voiceStopRequested: voiceStopRequested ?? this.voiceStopRequested,
      voiceDraftTranscript: voiceDraftTranscript ?? this.voiceDraftTranscript,
      voiceDraftAudioPath: voiceDraftAudioPath ?? this.voiceDraftAudioPath,
      voiceResultHandled: voiceResultHandled ?? this.voiceResultHandled,
      isAwaitingMembershipSummary:
          isAwaitingMembershipSummary ?? this.isAwaitingMembershipSummary,
    );
  }
}

final chatSessionStateProvider = Provider<ChatSessionState>((ref) {
  final conversation = ref.watch(chatConversationControllerProvider);
  final composer = ref.watch(chatComposerControllerProvider);
  final voice = ref.watch(chatVoiceControllerProvider);
  final surface = ref.watch(chatSurfaceControllerProvider);
  return buildChatSessionState(
    conversation: conversation,
    composer: composer,
    voice: voice,
    surface: surface,
  );
});

ChatSessionState buildChatSessionState({
  required ChatConversationState conversation,
  required ChatComposerState composer,
  required ChatVoiceState voice,
  required ChatSurfaceState surface,
}) {
  return ChatSessionState(
    sessionId: conversation.sessionId,
    conversation: conversation.conversation,
    pendingPromptQueue: composer.pendingPromptQueue,
    pendingComposerAttachments: composer.pendingComposerAttachments,
    pendingObjectReferences: composer.pendingObjectReferences,
    visibleConversationEntryCount: conversation.visibleConversationEntryCount,
    hasMoreRemoteConversationEntries:
        conversation.hasMoreRemoteConversationEntries,
    olderConversationBeforeCreatedAt:
        conversation.olderConversationBeforeCreatedAt,
    olderConversationBeforeRecordId:
        conversation.olderConversationBeforeRecordId,
    conversationStartedAt: conversation.conversationStartedAt,
    storageScope: conversation.storageScope,
    lastPersistedConversationStateJson:
        conversation.lastPersistedConversationStateJson,
    persistedConversationUpdatedAt: conversation.persistedConversationUpdatedAt,
    isProcessingPromptQueue: composer.isProcessingPromptQueue,
    isInterruptingActivePrompt: composer.isInterruptingActivePrompt,
    activePromptRunId: composer.activePromptRunId,
    activeRunRecord: composer.activeRunRecord,
    activeQuickPromptIntent: composer.activeQuickPromptIntent,
    isKeyboardComposerOpen: composer.isKeyboardComposerOpen,
    isUploadingImage: composer.isUploadingImage,
    isStartingVoice: voice.isStartingVoice,
    isRecordingVoice: voice.isRecordingVoice,
    isFinalizingVoice: voice.isFinalizingVoice,
    voiceStopRequested: voice.voiceStopRequested,
    voiceDraftTranscript: voice.voiceDraftTranscript,
    voiceDraftAudioPath: voice.voiceDraftAudioPath,
    voiceResultHandled: voice.voiceResultHandled,
    isAwaitingMembershipSummary: surface.isAwaitingMembershipSummary,
  );
}
