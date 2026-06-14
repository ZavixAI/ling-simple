import 'package:ling/src/features/chat/application/object_reference.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';

class ActiveQuickPromptIntentState {
  const ActiveQuickPromptIntentState({
    required this.id,
    required this.label,
    required this.instruction,
    required this.hint,
    required this.source,
  });

  final String id;
  final String label;
  final String instruction;
  final String hint;
  final String source;
}

class QueuedPromptState {
  const QueuedPromptState({
    required this.id,
    required this.text,
    required this.source,
    this.displayText,
    this.attachments = const <AttachmentDto>[],
    this.metadata = const <String, dynamic>{},
    this.isGuidance = false,
  });

  final String id;
  final String text;
  final String source;
  final String? displayText;
  final List<AttachmentDto> attachments;
  final Map<String, dynamic> metadata;
  final bool isGuidance;

  QueuedPromptState copyWith({
    String? id,
    String? text,
    String? source,
    String? displayText,
    bool clearDisplayText = false,
    List<AttachmentDto>? attachments,
    Map<String, dynamic>? metadata,
    bool? isGuidance,
  }) {
    return QueuedPromptState(
      id: id ?? this.id,
      text: text ?? this.text,
      source: source ?? this.source,
      displayText: clearDisplayText ? null : (displayText ?? this.displayText),
      attachments: attachments ?? this.attachments,
      metadata: metadata ?? this.metadata,
      isGuidance: isGuidance ?? this.isGuidance,
    );
  }
}

class ChatComposerState {
  const ChatComposerState({
    this.pendingPromptQueue = const <QueuedPromptState>[],
    this.pendingComposerAttachments = const <AttachmentDto>[],
    this.pendingObjectReferences = const <LingObjectReference>[],
    this.isProcessingPromptQueue = false,
    this.isInterruptingActivePrompt = false,
    this.activePromptRunId,
    this.activeRunRecord,
    this.activeQuickPromptIntent,
    this.isKeyboardComposerOpen = false,
    this.isUploadingImage = false,
  });

  final List<QueuedPromptState> pendingPromptQueue;
  final List<AttachmentDto> pendingComposerAttachments;
  final List<LingObjectReference> pendingObjectReferences;
  final bool isProcessingPromptQueue;
  final bool isInterruptingActivePrompt;
  final int? activePromptRunId;
  final ChatActiveRunRecord? activeRunRecord;
  final ActiveQuickPromptIntentState? activeQuickPromptIntent;
  final bool isKeyboardComposerOpen;
  final bool isUploadingImage;

  ChatComposerState copyWith({
    List<QueuedPromptState>? pendingPromptQueue,
    List<AttachmentDto>? pendingComposerAttachments,
    List<LingObjectReference>? pendingObjectReferences,
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
  }) {
    return ChatComposerState(
      pendingPromptQueue: pendingPromptQueue ?? this.pendingPromptQueue,
      pendingComposerAttachments:
          pendingComposerAttachments ?? this.pendingComposerAttachments,
      pendingObjectReferences:
          pendingObjectReferences ?? this.pendingObjectReferences,
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
    );
  }
}
