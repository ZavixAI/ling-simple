import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/features/auth/application/auth_state.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/calendar/models/apple_calendar_models.dart';
import 'package:ling/src/features/chat/application/chat_composer_state.dart';
import 'package:ling/src/features/chat/application/chat_local_audio_attachment_filter.dart';
import 'package:ling/src/features/chat/application/chat_queue_orchestrator.dart';
import 'package:ling/src/features/chat/application/chat_runtime_controller.dart';
import 'package:ling/src/features/chat/application/chat_session_controller.dart';
import 'package:ling/src/features/chat/application/chat_session_orchestrator.dart';
import 'package:ling/src/features/chat/application/chat_session_state.dart';
import 'package:ling/src/features/chat/application/chat_ui_action_support.dart';
import 'package:ling/src/features/chat/application/chat_voice_orchestrator.dart';
import 'package:ling/src/features/chat/application/chat_voice_transcript_normalizer.dart';
import 'package:ling/src/features/chat/application/conversation_attachment.dart';
import 'package:ling/src/features/chat/application/conversation_entry.dart';
import 'package:ling/src/features/chat/application/object_reference.dart';
import 'package:ling/src/features/chat/application/pending_prompt_request.dart';
import 'package:ling/src/features/chat/application/shared_item_text_sanitizer.dart';
import 'package:ling/src/features/chat/application/user_context_digest_debug.dart';
import 'package:ling/src/features/chat/data/chat_repository.dart';
import 'package:ling/src/features/chat/data/shared_image_receive_bridge.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';
import 'package:ling/src/features/chat/models/quick_prompt_models.dart';
import 'package:ling/src/features/chat/models/user_context_digest_models.dart';
import 'package:ling/src/features/chat/presentation/chat_section_view.dart';
import 'package:ling/src/features/chat/presentation/conversation_attachment_view.dart';
import 'package:ling/src/features/chat/presentation/conversation_empty_state_view.dart';
import 'package:ling/src/features/chat/presentation/conversation_entry_actions.dart';
import 'package:ling/src/features/chat/presentation/conversation_entry_view.dart';
import 'package:ling/src/features/chat/presentation/conversation_tool_call_display.dart';
import 'package:ling/src/features/chat/presentation/conversation_viewport.dart';
import 'package:ling/src/features/chat/presentation/object_reference_editing_controller.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/font_size_preference.dart';
import 'package:ling/src/shared/models/preferred_input_mode.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/notice.dart';
import 'package:path/path.dart' as p;

const Set<String> _directSubmitQuickPromptIds = {
  'plan_today',
  'organize_recent_ideas_web',
  'today_image',
  'future_letter',
  'one_minute_podcast',
  'private_ritual',
  'dream_poster',
  'today_narration',
  'daily_hot_brief',
  'ai_news',
  'trend_radar',
  'hot_web_report',
  'products_today',
  'inspiration_board',
};
const int _fallbackQuickPromptLimit = 6;

class LingCalendarChatSectionViewModel {
  const LingCalendarChatSectionViewModel({
    required this.isCalendarOpen,
    required this.isAuthenticated,
    required this.isAppInForeground,
    required this.selectedDate,
    required this.timezone,
    required this.localeCode,
    required this.fontSizeLevel,
    required this.profile,
    required this.currentAuthSession,
    required this.applePermission,
    required this.appleEvents,
    this.isBootstrappingConversation = false,
    required this.hasUnreadCalendarBadge,
    required this.strings,
  });

  final bool isCalendarOpen;
  final bool isAuthenticated;
  final bool isAppInForeground;
  final String selectedDate;
  final String timezone;
  final String localeCode;
  final LingFontSizeLevel fontSizeLevel;
  final UserProfile? profile;
  final AuthSession? currentAuthSession;
  final AppleCalendarPermissionState applePermission;
  final List<AppleCalendarEvent> appleEvents;
  final bool isBootstrappingConversation;
  final bool hasUnreadCalendarBadge;
  final LingStrings strings;
}

class LingCalendarChatSectionCallbacks {
  const LingCalendarChatSectionCallbacks({
    required this.onAvatarTap,
    required this.onCalendarTap,
    required this.onCalendarMutationToolResult,
    required this.onOpenLingEvent,
    required this.onEnsureMembershipReadyForChat,
    required this.onHandleLocalChatGate,
    required this.onHandlePromptExecutionError,
    required this.onBeforePromptSubmit,
    required this.onLingAction,
    required this.onPromptSubmitted,
  });

  final VoidCallback onAvatarTap;
  final VoidCallback onCalendarTap;
  final Future<void> Function(ConversationEntryDto entry)
  onCalendarMutationToolResult;
  final Future<void> Function(String eventId) onOpenLingEvent;
  final Future<bool> Function() onEnsureMembershipReadyForChat;
  final Future<bool> Function(BuildContext context) onHandleLocalChatGate;
  final Future<bool> Function(BuildContext context, Object error)
  onHandlePromptExecutionError;
  final Future<bool> Function(BuildContext context) onBeforePromptSubmit;
  final Future<void> Function(BuildContext context, LingChatAction action)
  onLingAction;
  final VoidCallback onPromptSubmitted;
}

const Duration _conversationPersistenceDebounce = Duration(milliseconds: 240);
const Duration _persistedConversationRestoreTtl = Duration(days: 7);
const Duration _conversationRemoteRecoveryGracePeriod = Duration(minutes: 2);
const int _conversationInitialPageSize = 30;
const int _conversationRemotePaginationPageSize = 30;
const double _conversationBottomSnapThreshold = 32;

class LingCalendarChatSection extends ConsumerStatefulWidget {
  const LingCalendarChatSection({
    super.key,
    required this.stateView,
    required this.actions,
  });

  final LingCalendarChatSectionViewModel stateView;
  final LingCalendarChatSectionCallbacks actions;

  bool get isCalendarOpen => stateView.isCalendarOpen;
  bool get isAuthenticated => stateView.isAuthenticated;
  bool get isAppInForeground => stateView.isAppInForeground;
  String get selectedDate => stateView.selectedDate;
  String get timezone => stateView.timezone;
  String get localeCode => stateView.localeCode;
  LingFontSizeLevel get fontSizeLevel => stateView.fontSizeLevel;
  UserProfile? get profile => stateView.profile;
  AuthSession? get currentAuthSession => stateView.currentAuthSession;
  AppleCalendarPermissionState get applePermission => stateView.applePermission;
  List<AppleCalendarEvent> get appleEvents => stateView.appleEvents;
  bool get isBootstrappingConversation => stateView.isBootstrappingConversation;
  bool get hasUnreadCalendarBadge => stateView.hasUnreadCalendarBadge;
  LingStrings get strings => stateView.strings;

  VoidCallback get onAvatarTap => actions.onAvatarTap;
  VoidCallback get onCalendarTap => actions.onCalendarTap;
  Future<void> Function(ConversationEntryDto entry)
  get onCalendarMutationToolResult => actions.onCalendarMutationToolResult;

  @override
  ConsumerState<LingCalendarChatSection> createState() =>
      LingCalendarChatSectionState();
}

class LingCalendarChatSectionState
    extends ConsumerState<LingCalendarChatSection> {
  static const _voiceTranscriptRefreshDelay = Duration(milliseconds: 24);

  late ProviderContainer _providerContainer;
  late final ChatQueueOrchestrator _chatQueueOrchestrator;
  late final ChatUiActionSupport _chatPresentationSupport;
  late final ChatRuntimeController _chatRuntime;
  late final ChatSessionController _chatSessionController;
  late final ChatSessionOrchestrator _chatSessionOrchestrator;
  late final ChatVoiceOrchestrator _chatVoiceOrchestrator;
  late final SharedImageReceiveBridge _sharedImageReceiveBridge;

  final LingObjectReferenceEditingController _composerController =
      LingObjectReferenceEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final ScrollController _composerScrollController = ScrollController();
  final ScrollController _conversationScrollController = ScrollController();

  StreamSubscription<ChatSpeechEvent>? _speechEventSubscription;
  Timer? _voiceFinalizeFallbackTimer;
  Timer? _voiceTranscriptUiTimer;
  Timer? _conversationPersistenceTimer;
  Timer? _keyboardComposerScrollTimer;
  int _inputPanelScrollFrameToken = 0;
  int? _voiceComposerReplaceStart;
  int? _voiceComposerReplaceEnd;
  int? _voiceComposerCursorOffset;

  ChatRecoverableSessionSource _recoverableSessionSource =
      ChatRecoverableSessionSource.localState;
  bool _conversationScrollQueued = false;
  bool _conversationScrollQueuedForce = false;
  int _conversationScrollQueuedRemainingFrames = 0;
  bool _conversationAutoScrollEnabled = true;
  bool _isDrainingPendingPromptQueue = false;
  bool _isFlushingPendingGuidance = false;
  final Set<int> _runIdsWithoutPendingGuidanceFlush = <int>{};
  bool _isDisposing = false;
  bool _isPagingOlderConversationEntries = false;
  bool _isLoadingRemoteConversationEntries = false;
  final Set<String> _transientLoadedConversationEntryKeys = <String>{};
  bool _isInputPanelExpandedByUser = false;
  bool _isProgrammaticConversationScrollActive = false;
  bool _showScrollToBottomButton = false;
  bool _scrollConversationToLatestOnNextViewEntry = true;
  bool _debugContextDigestAlwaysVisible = false;
  bool _debugEmptyStateQuickPromptsVisible = false;
  bool _showQuickPromptsAfterActiveIntentCancel = false;
  bool _isVoiceStartRequestInFlight = false;
  bool _isVoiceFinishRequestInFlight = false;
  bool _isImportingSharedItems = false;
  bool _isImportingSharedImages = false;
  bool _ignoreVoiceEventsUntilNextStart = false;
  String? _lastQuickPromptDebugLogKey;
  UserContextDigestSummary? _contextDigest;
  List<ChatQuickPromptOption> _quickPromptOptions =
      const <ChatQuickPromptOption>[];
  String? _quickPromptLocaleCode;
  final Map<String, Completer<bool>> _activeRunCompletionByServerRunId =
      <String, Completer<bool>>{};
  final Map<String, bool> _completedRunResultByServerRunId = <String, bool>{};

  ChatSessionState get _chatState =>
      _providerContainer.read(chatSessionStateProvider);
  bool get _isAwaitingMembershipSummary =>
      _chatState.isAwaitingMembershipSummary;

  String? get _sessionId => _chatState.sessionId;
  String? get _contextDigestSummary {
    final summary = _contextDigest?.display.summary.trim();
    if (summary != null && summary.isNotEmpty) {
      return summary;
    }
    if (_debugContextDigestAlwaysVisible) {
      return widget.localeCode.toLowerCase().startsWith('en')
          ? 'Next: Product review'
          : '下一件事：产品讨论';
    }
    return null;
  }

  List<LingConversationEntry> get _conversation => _chatState.conversation
      .map(
        (entry) =>
            filterMissingLocalAudioAttachments(entry, exists: _localFileExists),
      )
      .map(LingConversationEntry.fromDto)
      .toList(growable: false);
  List<LingPendingPromptRequest> get _pendingPromptQueue => _chatState
      .pendingPromptQueue
      .map<LingPendingPromptRequest>(LingPendingPromptRequest.fromState)
      .toList(growable: false);
  List<LingPendingPromptRequest> get _pendingGuidanceQueue =>
      _pendingPromptQueue
          .where((item) => item.isGuidance)
          .toList(growable: false);
  List<LingConversationAttachment> get _pendingComposerAttachments => _chatState
      .pendingComposerAttachments
      .map(LingConversationAttachment.fromDto)
      .toList(growable: false);
  List<LingObjectReference> get _pendingObjectReferences =>
      _chatState.pendingObjectReferences;
  int get _visibleConversationEntryCount =>
      _chatState.visibleConversationEntryCount;
  DateTime? get _conversationStartedAt => _chatState.conversationStartedAt;
  String? get _conversationStorageScope => _chatState.storageScope;
  DateTime? get _persistedConversationUpdatedAt =>
      _chatState.persistedConversationUpdatedAt;
  bool get _isProcessingPromptQueue => _chatState.isProcessingPromptQueue;
  bool get _isInterruptingActivePrompt => _chatState.isInterruptingActivePrompt;
  int? get _activePromptRunId => _chatState.activePromptRunId;
  ChatActiveRunRecord? get _activeRunRecord => _chatState.activeRunRecord;
  ActiveQuickPromptIntentState? get _activeQuickPromptIntent =>
      _chatState.activeQuickPromptIntent;
  bool get _isKeyboardComposerOpen => _chatState.isKeyboardComposerOpen;
  bool get _isUploadingImage => _chatState.isUploadingImage;
  bool get _hasActivePromptRun =>
      _isProcessingPromptQueue || _activePromptRunId != null;
  bool get _isStartingVoice => _chatState.isStartingVoice;
  bool get _isRecordingVoice => _chatState.isRecordingVoice;
  bool get _isFinalizingVoice => _chatState.isFinalizingVoice;
  bool get _voiceStopRequested => _chatState.voiceStopRequested;
  String get _voiceDraftTranscript => _chatState.voiceDraftTranscript;
  String get _voiceDraftAudioPath => _chatState.voiceDraftAudioPath;
  bool get _voiceResultHandled => _chatState.voiceResultHandled;

  bool get _isVoiceInteractionActive =>
      _isStartingVoice || _isRecordingVoice || _isFinalizingVoice;
  bool get _hasVoiceDraftReview =>
      !_isVoiceInteractionActive &&
      _voiceResultHandled &&
      _voiceDraftTranscript.trim().isNotEmpty;
  bool get _isInputPanelExpanded =>
      _isInputPanelExpandedByUser ||
      _isVoiceInteractionActive ||
      _isKeyboardComposerOpen;
  bool get _canTapVoiceButton {
    if (_isStartingVoice || _isRecordingVoice) {
      return !_voiceStopRequested && !_isVoiceFinishRequestInFlight;
    }
    return !_isUploadingImage &&
        !_isAwaitingMembershipSummary &&
        !_isFinalizingVoice &&
        !_voiceStopRequested &&
        !_isVoiceFinishRequestInFlight &&
        !_isVoiceStartRequestInFlight;
  }

  bool get _isDockBusy => _isUploadingImage || _isAwaitingMembershipSummary;
  bool get hasConversationEntries => _chatState.conversation.isNotEmpty;
  bool get hasResolvedSessionId {
    final normalizedSessionId = _sessionId?.trim();
    return normalizedSessionId != null && normalizedSessionId.isNotEmpty;
  }

  bool get shouldTriggerEmptyStateWarmStart =>
      !hasConversationEntries && !hasResolvedSessionId;

  bool _localFileExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  String get _dockBusyLabel {
    if (_isAwaitingMembershipSummary) {
      return widget.strings.sageStreaming;
    }
    if (_isUploadingImage) {
      return widget.strings.imageUploadInProgress;
    }
    return widget.strings.sageStreaming;
  }

  @override
  void initState() {
    super.initState();
    _chatQueueOrchestrator = ref.read(chatQueueOrchestratorProvider);
    _chatPresentationSupport = ref.read(chatUiActionSupportProvider);
    _chatRuntime = ref.read(chatRuntimeControllerProvider);
    _chatSessionController = ref.read(chatSessionControllerProvider);
    _chatSessionOrchestrator = ref.read(chatSessionOrchestratorProvider);
    _chatVoiceOrchestrator = ref.read(chatVoiceOrchestratorProvider);
    _sharedImageReceiveBridge = ref.read(sharedImageReceiveBridgeProvider);
    _sharedImageReceiveBridge.setSharedItemsAvailableHandler((availability) {
      unawaited(_importSharedItems(availability));
    });
    _composerFocusNode.addListener(_handleComposerFocusChanged);
    _conversationScrollController.addListener(_handleConversationScrollChanged);
    _debugContextDigestAlwaysVisible =
        UserContextDigestDebugPreview.enabled.value;
    _debugEmptyStateQuickPromptsVisible =
        EmptyStateQuickPromptsDebugPreview.enabled.value;

    UserContextDigestDebugPreview.enabled.addListener(
      _handleContextDigestDebugChanged,
    );
    EmptyStateQuickPromptsDebugPreview.enabled.addListener(
      _handleEmptyStateQuickPromptsDebugChanged,
    );
    unawaited(UserContextDigestDebugPreview.load());
    unawaited(EmptyStateQuickPromptsDebugPreview.load());
    _speechEventSubscription = _chatVoiceOrchestrator.subscribeToEvents(
      _handleSpeechEvent,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _refreshContextDigest();
      unawaited(_refreshQuickPrompts());
      unawaited(_markSharedItemsReadyAndImportPendingItems());
      final normalizedSessionId = _sessionId?.trim();
      if (_chatState.conversation.isEmpty &&
          (normalizedSessionId == null || normalizedSessionId.isEmpty)) {
        _mutateChatSurface(() {
          _chatSessionController.resetSessionSurface(
            conversation: const <ConversationEntryDto>[],
            visibleConversationEntryCount: _conversationInitialPageSize,
          );
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant LingCalendarChatSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timezone != widget.timezone ||
        oldWidget.localeCode != widget.localeCode ||
        oldWidget.isAuthenticated != widget.isAuthenticated) {
      unawaited(_refreshContextDigest());
      unawaited(_refreshQuickPrompts());
    }
    if (!oldWidget.isAppInForeground && widget.isAppInForeground) {
      unawaited(_flushPendingGuidanceIfIdle());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _providerContainer = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    _isDisposing = true;
    for (final completer in _activeRunCompletionByServerRunId.values) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }
    _activeRunCompletionByServerRunId.clear();
    _completedRunResultByServerRunId.clear();
    unawaited(flushConversationState());
    _voiceFinalizeFallbackTimer?.cancel();
    _voiceTranscriptUiTimer?.cancel();
    _conversationPersistenceTimer?.cancel();
    _keyboardComposerScrollTimer?.cancel();
    _speechEventSubscription?.cancel();
    _sharedImageReceiveBridge.setSharedItemsAvailableHandler(null);
    unawaited(_chatVoiceOrchestrator.cancelRecognition());
    _chatRuntime.reset();
    UserContextDigestDebugPreview.enabled.removeListener(
      _handleContextDigestDebugChanged,
    );
    EmptyStateQuickPromptsDebugPreview.enabled.removeListener(
      _handleEmptyStateQuickPromptsDebugChanged,
    );
    _composerFocusNode.removeListener(_handleComposerFocusChanged);
    _conversationScrollController.removeListener(
      _handleConversationScrollChanged,
    );
    _conversationScrollController.dispose();
    _composerController.dispose();
    _composerFocusNode.dispose();
    _composerScrollController.dispose();
    super.dispose();
  }

  Future<void> _markSharedItemsReadyAndImportPendingItems() async {
    final initialAvailability = await _sharedImageReceiveBridge.markReady();
    if (!mounted) {
      return;
    }
    if (initialAvailability != null &&
        (initialAvailability.hasSharedItems ||
            initialAvailability.shouldAutoSend)) {
      await _importSharedItems(initialAvailability);
    }
  }

  void _handleContextDigestDebugChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _debugContextDigestAlwaysVisible =
          UserContextDigestDebugPreview.enabled.value;
    });
  }

  void _handleEmptyStateQuickPromptsDebugChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _debugEmptyStateQuickPromptsVisible =
          EmptyStateQuickPromptsDebugPreview.enabled.value;
    });
  }

  void _handleConversationBackgroundTap() {
    _closeKeyboardComposer();
    _collapseInputPanel();
  }

  Future<void> _refreshContextDigest() async {
    if (!mounted ||
        !widget.isAuthenticated ||
        widget.currentAuthSession == null) {
      return;
    }
    try {
      final digest = await ref
          .read(chatRepositoryProvider)
          .getUserContextDigest(
            timezone: widget.timezone,
            locale: widget.localeCode,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _contextDigest = digest;
      });
    } catch (error, stackTrace) {
      AppLogger.debug(
        '[Ling][ChatSection] 用户上下文摘要加载失败',
        fields: <String, Object?>{'error': '$error'},
      );
      AppLogger.debug('$stackTrace');
    }
  }

  Future<void> _refreshQuickPrompts({bool forceRefresh = false}) async {
    if (!mounted ||
        !widget.isAuthenticated ||
        widget.currentAuthSession == null) {
      return;
    }
    final localeCode = widget.localeCode;
    if (!forceRefresh &&
        _quickPromptOptions.isNotEmpty &&
        _quickPromptLocaleCode == localeCode) {
      return;
    }
    try {
      final bundle = await ref
          .read(chatRepositoryProvider)
          .getQuickPrompts(localeCode: localeCode, forceRefresh: forceRefresh);
      if (!mounted || localeCode != widget.localeCode) {
        return;
      }
      setState(() {
        _quickPromptOptions = bundle.prompts;
        _quickPromptLocaleCode = localeCode;
      });
    } catch (error, stackTrace) {
      AppLogger.debug(
        '[Ling][ChatSection] 快捷按钮配置加载失败，使用本地兜底',
        fields: <String, Object?>{'error': '$error'},
      );
      AppLogger.debug('$stackTrace');
    }
  }

  void _handleComposerFocusChanged() {
    if (!mounted) {
      return;
    }
    final hasFocus = _composerFocusNode.hasFocus;
    if (hasFocus == _isKeyboardComposerOpen) {
      if (hasFocus) {
        _scheduleConversationScrollAfterInputPanelTransition();
      }
      return;
    }
    _mutateDockSurface(() {
      _chatSessionController.setKeyboardComposerOpen(hasFocus);
    });
    if (hasFocus) {
      _scheduleConversationScrollAfterInputPanelTransition();
    }
  }

  Future<void> flushConversationState() => _flushConversationStateImpl();

  Future<void> prepareForBackgroundTransition() =>
      _prepareForBackgroundTransitionImpl();

  Future<void> restorePersistedConversationState() =>
      _restorePersistedConversationStateImpl();

  Future<void> recoverActiveSessionFromServer({
    bool allowFreshLocalConversationShortcut = true,
  }) => _recoverActiveSessionFromServerImpl(
    allowFreshLocalConversationShortcut: allowFreshLocalConversationShortcut,
  );

  Future<void> recoverConversationSessionFromServer(String sessionId) =>
      _recoverSessionConversationFromServerImpl(
        ChatRecoverableSession(
          sessionId: sessionId,
          source: ChatRecoverableSessionSource.latestServerSession,
        ),
        allowFreshLocalConversationShortcut: false,
      );

  bool get shouldDeferConversationRealtimeSync =>
      _isProcessingPromptQueue || _activePromptRunId != null;

  bool canApplyRealtimeConversationEvent(String sessionId) =>
      sessionId.trim().isNotEmpty && sessionId.trim() == _sessionId;

  void applyRealtimeConversationEvent(Map<String, dynamic> event) =>
      _applyConversationEvent(event);

  void resetSessionSurface() => _resetSessionSurfaceImpl();

  void dismissKeyboardComposer({bool clearText = false}) =>
      _dismissKeyboardComposerImpl(clearText: clearText);

  void prefillKeyboardComposerDraft(String text) =>
      _prefillKeyboardComposerDraftImpl(text);

  void prefillKeyboardComposerWithObjectReference(
    LingObjectReference reference,
  ) => _prefillKeyboardComposerWithObjectReferenceImpl(reference);

  Future<void> startVoiceRecording() => _startVoiceRecording();

  @override
  Widget build(BuildContext context) {
    ref.watch(chatSessionStateProvider);

    _consumePendingConversationEntryScroll();

    final viewport = _buildConversationViewportForCurrentState();
    final renderedItems =
        shouldShowLingPendingAssistantBubble(
          conversation: viewport.visibleEntries,
          isProcessingPromptQueue: _isProcessingPromptQueue,
        )
        ? [
            ...viewport.renderedItems,
            LingConversationRenderItem.entry(
              id: 'assistant_loading_placeholder',
              entry: buildLingPendingAssistantBubbleEntry(),
            ),
          ]
        : viewport.renderedItems;
    final pendingGuidanceQueue = _pendingGuidanceQueue;
    final firstQueuedPrompt = pendingGuidanceQueue.isEmpty
        ? null
        : pendingGuidanceQueue.first;

    final isConversationEmpty =
        renderedItems.isEmpty && !viewport.hasOlderEntries;
    final hasRemoteOlderConversationEntries = _hasOlderConversationEntries();
    final hasUserMessage = _chatState.conversation.any(
      _isCurrentSessionUserEntryDto,
    );
    final isAgentReplying =
        _isProcessingPromptQueue || _activePromptRunId != null;
    final activeQuickPromptIntent = _activeQuickPromptIntent;
    final keepQuickPromptsVisibleWithText =
        activeQuickPromptIntent == null &&
        _showQuickPromptsAfterActiveIntentCancel;
    final shouldShowQuickPrompts =
        _debugEmptyStateQuickPromptsVisible ||
        keepQuickPromptsVisibleWithText ||
        activeQuickPromptIntent != null ||
        (hasUserMessage &&
            !isConversationEmpty &&
            _composerController.userText.trim().isEmpty &&
            !isAgentReplying);
    final quickPrompts = shouldShowQuickPrompts
        ? _buildEmptyStateQuickPrompts()
        : const <String>[];
    final shouldShowStarterTasks =
        !hasUserMessage &&
        !isAgentReplying &&
        (isConversationEmpty || viewport.visibleEntries.length <= 3);
    final starterTasks = shouldShowStarterTasks
        ? _buildConversationStarterTasks()
        : const <LingConversationStarterTask>[];
    _logQuickPromptPreviewState(
      isConversationEmpty: isConversationEmpty,
      renderedItemCount: renderedItems.length,
      hasOlderEntries: viewport.hasOlderEntries,
      quickPromptCount: quickPrompts.length,
      isAgentReplying: isAgentReplying,
      shouldShowQuickPrompts: shouldShowQuickPrompts,
    );

    return LingChatSectionView(
      data: LingChatSectionViewData(
        isConversationEmpty: isConversationEmpty,
        renderedConversationItems: renderedItems,
        showContextSummaryInConversationList:
            _debugContextDigestAlwaysVisible && renderedItems.isNotEmpty,
        isLoadingOlderConversationEntries: _isLoadingRemoteConversationEntries,
        isPagingOlderConversationEntries: _isPagingOlderConversationEntries,
        transientConversationEntryKeys: Set<String>.unmodifiable(
          _transientLoadedConversationEntryKeys,
        ),
        hasOlderConversationEntries: hasRemoteOlderConversationEntries,
        hiddenConversationEntryCount: viewport.hiddenEntryCount,
        isDockBusy: _isDockBusy,
        isConversationRestoring: widget.isBootstrappingConversation,
        dockBusyLabel: _dockBusyLabel,
        queuedCount: pendingGuidanceQueue.length,
        queuedLabel: pendingGuidanceQueue.isEmpty
            ? null
            : widget.strings.guidanceQueueCount(pendingGuidanceQueue.length),
        queuedPreviewText: firstQueuedPrompt == null
            ? null
            : buildLingQueuedPromptPreview(
                request: firstQueuedPrompt,
                queuedImageMessageBuilder: widget.strings.queuedImageMessage,
              ),
        queuedOverflowCount: pendingGuidanceQueue.length > 1
            ? pendingGuidanceQueue.length - 1
            : 0,
        isRecording: _isStartingVoice || _isRecordingVoice,
        isFinalizingVoice: _isFinalizingVoice,
        isVoiceActive: _isStartingVoice || _isRecordingVoice,
        hasVoiceDraftReview: _hasVoiceDraftReview,
        voiceDraftTranscript:
            (_chatRuntime.pendingVoiceDraftTranscript ?? _voiceDraftTranscript)
                .trim(),
        voiceDraftAudioPath: _voiceDraftAudioPath,
        isAgentReplying: isAgentReplying,
        isInterruptingAgentReply: _isInterruptingActivePrompt,
        isKeyboardComposerOpen: _isKeyboardComposerOpen,
        isInputPanelExpanded: _isInputPanelExpanded,
        preferVoiceInput: prefersVoiceInput(
          widget.profile?.preferences?.preferredInputMode,
        ),
        composerController: _composerController,
        composerFocusNode: _composerFocusNode,
        composerScrollController: _composerScrollController,
        composerCursorPreviewOffset: _voiceComposerCursorPreviewOffset,
        composerPlaceholder: activeQuickPromptIntent?.hint ?? '',
        quickPrompts: quickPrompts,
        activeQuickPromptLabel: activeQuickPromptIntent?.label,
        activeQuickPromptHint: activeQuickPromptIntent?.hint,
        starterTasks: starterTasks,
        forceQuickPromptsVisible: _debugEmptyStateQuickPromptsVisible,
        keepQuickPromptsVisibleWithText: keepQuickPromptsVisibleWithText,
        pendingAttachments: _pendingComposerAttachments,
        pendingObjectReferences: _pendingObjectReferences,
        canVoiceTap: _canTapVoiceButton,
        voiceTooltip: _isStartingVoice || _isRecordingVoice
            ? widget.strings.tapToStopRecording
            : widget.strings.tapToRecord,
        addImageTooltip: widget.strings.addImage,
        keyboardTooltip: widget.strings.typeToLing,
        photoLibraryTooltip: widget.strings.photoLibrary,
        cameraTooltip: widget.strings.takePhoto,
        sendMessageTooltip: widget.strings.sendMessage,
        stopAgentReplyTooltip: widget.strings.cancel,
        deleteQueuedMessageTooltip: widget.strings.deleteQueuedMessage,
        applyQueuedMessageNowTooltip: widget.strings.applyQueuedMessageNow,
        editQueuedMessageTooltip: widget.strings.editAction,
        hasUnreadCalendarBadge: widget.hasUnreadCalendarBadge,
        showScrollToBottomButton: _showScrollToBottomButton,
        strings: widget.strings,
        fontSizeLevel: widget.fontSizeLevel,
        conversationScrollController: _conversationScrollController,
        contextSummary: _contextDigestSummary,
        currentSessionId: _sessionId,
      ),
      callbacks: LingChatSectionViewCallbacks(
        onConversationBackgroundTap: _handleConversationBackgroundTap,
        onConversationUserScroll: _handleConversationUserScroll,
        onLoadMoreConversationEntries: _showMoreConversationEntries,
        onPreviewAttachment: (attachment) {
          unawaited(_openAttachmentPreview(attachment));
        },
        onOpenLingEvent: (eventId) {
          unawaited(
            _trackChatEvent(
              'chat.generated_card.open',
              action: 'generated_card_open',
              source: 'calendar_event',
            ),
          );
          unawaited(widget.actions.onOpenLingEvent(eventId));
        },
        onCopyEntry: _copyConversationEntry,
        onRetryEntry: _retryConversationEntry,
        onActionPrompt: (prompt) {
          unawaited(_submitActionPrompt(prompt));
        },
        onLingAction: (action) {
          unawaited(_handleLingAction(action));
        },
        onQuestionnaireSubmit: (submission) {
          unawaited(_submitQuestionnaireResponse(submission));
        },
        onExpandInputPanel: _expandInputPanel,
        onCollapseInputPanel: _collapseInputPanel,
        onVoiceTap: _isStartingVoice || _isRecordingVoice
            ? () {
                unawaited(_finishVoiceRecording());
              }
            : _isFinalizingVoice || _voiceStopRequested
            ? () {}
            : () {
                unawaited(_startVoiceRecording());
              },
        onAddImageTap: () {
          unawaited(_openDockImageSourceSheet());
        },
        onKeyboardTap: () => _openKeyboardComposer(),
        onDismissKeyboardTap: _closeKeyboardComposer,
        onPhotoLibraryTap: () {
          unawaited(_handleDockImageSourceTap(ImageSource.gallery));
        },
        onCameraTap: () {
          unawaited(_handleDockImageSourceTap(ImageSource.camera));
        },
        onRemoveAttachment: _removePendingComposerAttachment,
        onRemoveObjectReference: _removePendingObjectReference,
        onReorderAttachments: _reorderPendingComposerAttachments,
        onViewQueuedMessages: () {
          unawaited(_openQueuedPromptSheet());
        },
        onDeleteQueuedMessage: () {
          final pendingGuidanceQueue = _pendingGuidanceQueue;
          final nextQueuedPrompt = pendingGuidanceQueue.isEmpty
              ? null
              : pendingGuidanceQueue.first;
          if (nextQueuedPrompt == null) {
            return;
          }
          unawaited(_removeQueuedPrompt(nextQueuedPrompt.id));
        },
        onApplyQueuedMessageNow: () {
          final pendingGuidanceQueue = _pendingGuidanceQueue;
          final nextQueuedPrompt = pendingGuidanceQueue.isEmpty
              ? null
              : pendingGuidanceQueue.first;
          if (nextQueuedPrompt == null) {
            return;
          }
          unawaited(_applyQueuedPromptNow(nextQueuedPrompt));
        },
        onEditQueuedMessage: () {
          final pendingGuidanceQueue = _pendingGuidanceQueue;
          final nextQueuedPrompt = pendingGuidanceQueue.isEmpty
              ? null
              : pendingGuidanceQueue.first;
          if (nextQueuedPrompt == null) {
            return;
          }
          unawaited(_editQueuedPrompt(nextQueuedPrompt));
        },
        onCancelVoiceDraft: _cancelVoiceDraftReview,
        onPlayVoiceDraftPreview: _playVoiceDraftPreview,
        onLoadVoiceDraftPreviewDuration: _loadVoiceDraftPreviewDuration,
        onStopVoiceDraftPreview: _stopVoiceDraftPreview,
        onStopAgentReply: () {
          unawaited(_interruptActivePromptFromDock());
        },
        onScrollToBottom: _animateConversationToBottom,
        onQuickPromptTap: (prompt) {
          unawaited(_submitQuickPrompt(prompt));
        },
        onQuickPromptRefresh: () => _refreshQuickPrompts(forceRefresh: true),
        onCancelActiveQuickPrompt: _clearActiveQuickPromptIntent,
        onSubmitText: () {
          unawaited(_submitKeyboardComposerText());
        },
        onAvatarTap: () {
          _handleConversationBackgroundTap();
          widget.onAvatarTap();
        },
        onCalendarTap: () {
          _handleConversationBackgroundTap();
          widget.onCalendarTap();
        },
      ),
    );
  }

  void _openKeyboardComposer({bool requestFocus = true}) {
    if (_isDockBusy) {
      return;
    }
    if (mounted && !_isKeyboardComposerOpen) {
      _mutateDockSurface(() {
        _chatSessionController.setKeyboardComposerOpen(true);
      });
    }
    if (!requestFocus) {
      _scheduleConversationScrollToBottom();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _composerFocusNode.requestFocus();
      _scheduleConversationScrollAfterInputPanelTransition();
    });
  }

  void _closeKeyboardComposer({bool clearText = false}) {
    FocusScope.of(context).unfocus();
    _composerFocusNode.unfocus(disposition: UnfocusDisposition.scope);
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    if (clearText) {
      _clearKeyboardComposerText();
    }
    if (!mounted || !_isKeyboardComposerOpen) {
      return;
    }
    _mutateDockSurface(() {
      _chatSessionController.setKeyboardComposerOpen(false);
    });
  }

  void _clearKeyboardComposerText() {
    _composerController.clear();
    _isInputPanelExpandedByUser = false;
    _notifyDockSurfaceChanged(scrollToBottom: true);
  }

  void _closeKeyboardComposerForVoiceStart() {
    final canRequestFocus = _composerFocusNode.canRequestFocus;
    _composerFocusNode.canRequestFocus = false;
    _closeKeyboardComposer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _composerFocusNode.canRequestFocus = canRequestFocus;
    });
  }

  void _expandInputPanel() {
    if (!mounted || _isInputPanelExpandedByUser) {
      return;
    }
    setState(() {
      _isInputPanelExpandedByUser = true;
    });
    _scheduleConversationScrollToBottom();
    _scheduleConversationScrollAfterInputPanelTransition();
  }

  void _collapseInputPanel() {
    if (!mounted || !_isInputPanelExpandedByUser) {
      return;
    }
    setState(() {
      _isInputPanelExpandedByUser = false;
    });
  }

  void _queuePendingComposerAttachments(
    Iterable<LingConversationAttachment> attachments,
  ) {
    final normalizedAttachments = attachments.toList(growable: false);
    if (!mounted || normalizedAttachments.isEmpty) {
      return;
    }
    _mutateDockSurface(() {
      _chatSessionController.appendPendingComposerAttachments(
        normalizedAttachments.map((attachment) => attachment.toDto()),
      );
    }, scrollToBottom: true);
  }

  String _voiceComposerSeparatorFor(String text) {
    final visibleText =
        LingObjectReferenceEditingController.stripObjectReferenceMarkers(text);
    if (visibleText.isEmpty || visibleText.endsWith('\n')) {
      return '';
    }
    final trailing = visibleText[visibleText.length - 1];
    if (RegExp(r'\s').hasMatch(trailing)) {
      return '';
    }
    return '\n';
  }

  int? get _voiceComposerCursorPreviewOffset {
    if (!_isVoiceInteractionActive) {
      return null;
    }
    final textLength = _composerController.text.length;
    final cursorOffset =
        _voiceComposerCursorOffset ??
        _voiceComposerReplaceEnd ??
        _voiceComposerReplaceStart;
    if (cursorOffset == null) {
      return null;
    }
    return cursorOffset.clamp(0, textLength);
  }

  void _prepareVoiceComposerInsertionRange() {
    final textLength = _composerController.text.length;
    final selection = _composerController.selection;
    final baseOffset = selection.isValid
        ? selection.baseOffset.clamp(0, textLength)
        : textLength;
    final extentOffset = selection.isValid
        ? selection.extentOffset.clamp(0, textLength)
        : textLength;
    _voiceComposerReplaceStart = math.min(baseOffset, extentOffset);
    _voiceComposerReplaceEnd = math.max(baseOffset, extentOffset);
    _voiceComposerCursorOffset = _voiceComposerReplaceStart;
  }

  ({String text, int replaceStart, int replaceEnd, String voiceTranscript})
  _buildVoiceComposerUpdate({
    required String currentText,
    required String nextTranscript,
    int? voiceReplaceStart,
    int? voiceReplaceEnd,
  }) {
    final normalizedNext = ChatVoiceTranscriptNormalizer.collapseRepeated(
      nextTranscript,
    );
    final hasVoiceRange =
        voiceReplaceStart != null &&
        voiceReplaceEnd != null &&
        voiceReplaceStart >= 0 &&
        voiceReplaceStart <= voiceReplaceEnd &&
        voiceReplaceEnd <= currentText.length;

    if (hasVoiceRange) {
      return (
        text: currentText.replaceRange(
          voiceReplaceStart,
          voiceReplaceEnd,
          normalizedNext,
        ),
        replaceStart: voiceReplaceStart,
        replaceEnd: voiceReplaceEnd,
        voiceTranscript: normalizedNext,
      );
    }

    if (normalizedNext.isEmpty) {
      return (
        text: currentText,
        replaceStart: currentText.length,
        replaceEnd: currentText.length,
        voiceTranscript: '',
      );
    }

    final separator = _voiceComposerSeparatorFor(currentText);
    return (
      text: '$currentText$separator$normalizedNext',
      replaceStart: currentText.length,
      replaceEnd: currentText.length,
      voiceTranscript: normalizedNext,
    );
  }

  ({String voiceTranscript, String composerText})?
  _applyVoiceTranscriptToComposerUpdate(String transcript) {
    final nextTranscript = transcript.trim();
    if (!mounted || nextTranscript.isEmpty) {
      return null;
    }
    final currentText = _composerController.text;
    final update = _buildVoiceComposerUpdate(
      currentText: currentText,
      nextTranscript: nextTranscript,
      voiceReplaceStart: _voiceComposerReplaceStart,
      voiceReplaceEnd: _voiceComposerReplaceEnd,
    );
    if (update.text == currentText) {
      return (
        voiceTranscript: update.voiceTranscript,
        composerText: update.text,
      );
    }

    final nextCursorOffset =
        (update.replaceStart + update.voiceTranscript.length).clamp(
          0,
          update.text.length,
        );
    final nextSelection = TextSelection.collapsed(offset: nextCursorOffset);

    _composerController.value = TextEditingValue(
      text: update.text,
      selection: nextSelection,
      composing: TextRange.empty,
    );
    _voiceComposerReplaceStart = update.replaceStart;
    _voiceComposerReplaceEnd =
        update.replaceStart + update.voiceTranscript.length;
    _voiceComposerCursorOffset = nextCursorOffset;
    _scrollVoiceComposerToLatest();
    _notifyDockSurfaceChanged(scrollToBottom: true);
    return (voiceTranscript: update.voiceTranscript, composerText: update.text);
  }

  String? _applyVoiceTranscriptToComposer(String transcript) {
    final update = _applyVoiceTranscriptToComposerUpdate(transcript);
    if (update == null) {
      return null;
    }
    return update.voiceTranscript;
  }

  void _scrollVoiceComposerToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_composerScrollController.hasClients) {
        return;
      }
      final position = _composerScrollController.position;
      if (position.maxScrollExtent <= 0) {
        return;
      }
      _composerScrollController.jumpTo(position.maxScrollExtent);
    });
  }

  void _removePendingComposerAttachment(LingConversationAttachment attachment) {
    if (!mounted) {
      return;
    }
    _mutateDockSurface(() {
      _chatSessionController.removePendingComposerAttachmentById(
        attachment.attachmentId,
      );
    }, scrollToBottom: true);
  }

  void _removePendingObjectReference(LingObjectReference reference) {
    if (!mounted) {
      return;
    }
    final nextReferences = _pendingObjectReferences
        .where(
          (item) =>
              item.kind != reference.kind ||
              item.id.trim() != reference.id.trim(),
        )
        .toList(growable: false);
    _mutateDockSurface(() {
      _chatSessionController.setPendingObjectReferences(nextReferences);
    }, scrollToBottom: true);
  }

  void _reorderPendingComposerAttachments(
    List<LingConversationAttachment> attachments,
  ) {
    if (!mounted) {
      return;
    }
    _mutateDockSurface(() {
      _chatSessionController.setPendingComposerAttachments(
        attachments.map((attachment) => attachment.toDto()).toList(),
      );
    }, scrollToBottom: true);
  }

  Future<bool> _maybeBlockPromptSubmission({
    required String text,
    required List<LingConversationAttachment> attachments,
  }) async {
    if (text.trim().isEmpty && attachments.isEmpty) {
      return false;
    }
    if (!await _ensureMembershipReadyForChat()) {
      return true;
    }
    if (!mounted) {
      return true;
    }
    return widget.actions.onHandleLocalChatGate(context);
  }

  Future<bool> _ensureMembershipReadyForChat() async {
    return _chatSessionController.ensureMembershipReadyForChat(
      isAuthenticated: widget.isAuthenticated,
      ensureReady: widget.actions.onEnsureMembershipReadyForChat,
    );
  }

  void _restoreQueuedPromptDraft(QueuedPromptState request) {
    if (!mounted) {
      return;
    }
    final parsedDraft = LingObjectReferenceCodec.parse(
      request.displayText ?? request.text,
    );
    final draftText = parsedDraft.remainingText;
    _composerController
      ..text = draftText
      ..selection = TextSelection.collapsed(offset: draftText.length);
    _mutateDockSurface(() {
      _chatSessionController.clearPendingComposerAttachments();
      _chatSessionController.setPendingObjectReferences(
        parsedDraft.references.take(1).toList(growable: false),
      );
      if (request.attachments.isNotEmpty) {
        _chatSessionController.appendPendingComposerAttachments(
          request.attachments,
        );
      }
      _chatSessionController.setKeyboardComposerOpen(true);
    }, scrollToBottom: true);
    _openKeyboardComposer();
  }

  void _cancelVoiceDraftReview() {
    if (!mounted) {
      return;
    }
    _ignoreVoiceEventsUntilNextStart = true;
    unawaited(_stopVoiceDraftPreview());
    final text = _composerController.text;
    final draft = _voiceDraftTranscript.trim();
    final replaceStart = _voiceComposerReplaceStart;
    final replaceEnd = _voiceComposerReplaceEnd;

    var nextText = text;
    var nextSelectionOffset = 0;
    final hasValidVoiceRange =
        replaceStart != null &&
        replaceEnd != null &&
        replaceStart >= 0 &&
        replaceStart <= replaceEnd &&
        replaceEnd <= text.length;
    if (hasValidVoiceRange) {
      nextText = text.replaceRange(replaceStart, replaceEnd, '');
      nextSelectionOffset = replaceStart.clamp(0, nextText.length);
    } else if (draft.isNotEmpty && text.trim() == draft) {
      nextText = '';
    } else if (draft.isNotEmpty && text.contains(draft)) {
      final draftStart = text.lastIndexOf(draft);
      nextText = text.replaceRange(draftStart, draftStart + draft.length, '');
      nextSelectionOffset = draftStart.clamp(0, nextText.length);
    }

    _composerController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextSelectionOffset),
      composing: TextRange.empty,
    );
    _resetVoiceState(clearTranscript: true, resetResultHandled: true);
    _notifyDockSurfaceChanged(scrollToBottom: true);
  }

  void _clearSubmittedVoiceDraftFromComposer(String transcript) {
    if (!mounted) {
      return;
    }
    final draft = transcript.trim();
    final text = _composerController.text;
    final replaceStart = _voiceComposerReplaceStart;
    final replaceEnd = _voiceComposerReplaceEnd;

    var nextText = text;
    var nextSelectionOffset = _composerController.selection.isValid
        ? _composerController.selection.extentOffset.clamp(0, text.length)
        : text.length;
    final hasValidVoiceRange =
        replaceStart != null &&
        replaceEnd != null &&
        replaceStart >= 0 &&
        replaceStart <= replaceEnd &&
        replaceEnd <= text.length;
    if (hasValidVoiceRange) {
      nextText = text.replaceRange(replaceStart, replaceEnd, '');
      nextSelectionOffset = replaceStart.clamp(0, nextText.length);
    } else if (draft.isNotEmpty && text.trim() == draft) {
      nextText = '';
      nextSelectionOffset = 0;
    } else if (draft.isNotEmpty && text.contains(draft)) {
      final draftStart = text.lastIndexOf(draft);
      nextText = text.replaceRange(draftStart, draftStart + draft.length, '');
      nextSelectionOffset = draftStart.clamp(0, nextText.length);
    }

    if (nextText != text) {
      _composerController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextSelectionOffset),
        composing: TextRange.empty,
      );
      _notifyDockSurfaceChanged(scrollToBottom: true);
    }
  }

  Future<Duration> _loadVoiceDraftPreviewDuration(String path) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      return Duration.zero;
    }
    try {
      return await _chatPresentationSupport.getSpeechPreviewDuration(
        normalizedPath,
      );
    } catch (_) {
      return Duration.zero;
    }
  }

  Future<Duration> _playVoiceDraftPreview(String path) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      return Duration.zero;
    }
    try {
      return await _chatPresentationSupport.playSpeechPreview(normalizedPath);
    } catch (error) {
      _showError(error);
      return Duration.zero;
    }
  }

  Future<void> _stopVoiceDraftPreview() async {
    try {
      await _chatPresentationSupport.stopSpeechPreview();
    } catch (_) {
      // Preview playback is disposable UI state.
    }
  }

  LingConversationAttachment? _buildLocalVoiceDraftAttachment(
    String audioPath,
  ) {
    final normalizedPath = audioPath.trim();
    if (normalizedPath.isEmpty) {
      return null;
    }
    final basename = p.basename(normalizedPath);
    final filename = basename.isEmpty ? 'voice.caf' : basename;
    final format = p.extension(filename).replaceFirst('.', '').trim();
    return LingConversationAttachment(
      attachmentId:
          'local_voice_${DateTime.now().microsecondsSinceEpoch.toString()}',
      filename: filename,
      url: normalizedPath,
      messageContent: {
        'type': 'input_audio',
        'input_audio': {
          'url': normalizedPath,
          'format': format.isEmpty ? 'caf' : format,
          'filename': filename,
          'local': true,
        },
      },
    );
  }

  ({String agentText, String displayText}) _wrapActiveQuickPromptInput(
    String userInput,
  ) {
    final intent = _activeQuickPromptIntent;
    final normalizedInput = userInput.trim();
    if (intent == null || normalizedInput.isEmpty) {
      return (agentText: normalizedInput, displayText: normalizedInput);
    }
    final instruction = intent.instruction.trim();
    final agentText = '任务指令：$instruction\n\n用户补充输入：$normalizedInput';
    final displayText = '${intent.label.trim()}\n$normalizedInput';
    return (agentText: agentText, displayText: displayText);
  }

  void _clearActiveQuickPromptIntent({bool restoreQuickPrompts = true}) {
    if (_activeQuickPromptIntent == null) {
      return;
    }
    _showQuickPromptsAfterActiveIntentCancel = restoreQuickPrompts;
    _mutateDockSurface(() {
      _chatSessionController.setActiveQuickPromptIntent(null);
    }, scrollToBottom: true);
  }

  Future<void> _submitKeyboardComposerText({String? userTextOverride}) async {
    final text = (userTextOverride ?? _composerController.userText).trim();
    final objectReferences = List<LingObjectReference>.from(
      _pendingObjectReferences.take(1),
      growable: false,
    );
    final promptText = LingObjectReferenceCodec.composeText(
      references: objectReferences,
      userText: text,
    );
    final attachments = List<LingConversationAttachment>.from(
      _pendingComposerAttachments,
    );
    final voiceAudioPath = _voiceDraftAudioPath.trim();
    final isVoiceSubmission =
        voiceAudioPath.isNotEmpty ||
        _voiceResultHandled ||
        _voiceDraftTranscript.trim().isNotEmpty;
    final voiceAttachment = _buildLocalVoiceDraftAttachment(voiceAudioPath);
    if (voiceAttachment != null) {
      attachments.add(voiceAttachment);
    }
    if (promptText.isEmpty && attachments.isEmpty) {
      if (_hasActivePromptRun) {
        await _interruptActivePromptFromDock();
      }
      return;
    }
    if (await _maybeBlockPromptSubmission(
      text: promptText,
      attachments: attachments,
    )) {
      return;
    }
    if (mounted) {
      _mutateDockSurface(() {
        _chatSessionController.clearPendingComposerAttachments();
        _chatSessionController.clearPendingObjectReferences();
      });
    }
    unawaited(_stopVoiceDraftPreview());
    _closeKeyboardComposer(clearText: true);
    if (_voiceResultHandled || _voiceDraftTranscript.trim().isNotEmpty) {
      _ignoreVoiceEventsUntilNextStart = true;
      _resetVoiceState(clearTranscript: true, resetResultHandled: true);
    }
    final wrappedPrompt = _wrapActiveQuickPromptInput(promptText);
    final submitted = await _submitPrompt(
      wrappedPrompt.agentText,
      source: isVoiceSubmission
          ? 'voice'
          : attachments.isNotEmpty && text.isEmpty
          ? 'image'
          : 'keyboard',
      displayText: wrappedPrompt.displayText,
      attachments: attachments,
      skipLocalMembershipGate: true,
      skipQueueMembershipReadinessCheck: true,
      enqueueAsGuidanceWhenActive: true,
    );
    if (submitted) {
      _showQuickPromptsAfterActiveIntentCancel = false;
      _clearActiveQuickPromptIntent(restoreQuickPrompts: false);
      _scheduleConversationScrollAfterInputPanelTransition(force: true);
    }
  }

  List<String> _buildEmptyStateQuickPrompts() {
    final basePrompts = _effectiveQuickPromptOptions()
        .map((prompt) => prompt.label)
        .toList(growable: false);
    switch (_contextDigest?.display.starterHint.primaryTask) {
      case 'arrange_ideas':
        return _dedupeQuickPrompts(<String>[
          _quickPromptLabelById('arrange_ideas'),
          ...basePrompts,
        ]);
      case 'capture_idea':
        return _dedupeQuickPrompts(<String>[
          _quickPromptLabelById('capture_idea'),
          ...basePrompts,
        ]);
      case 'plan_today':
        return _dedupeQuickPrompts(basePrompts);
    }
    return _dedupeQuickPrompts(basePrompts);
  }

  List<ChatQuickPromptOption> _effectiveQuickPromptOptions() {
    if (_quickPromptOptions.isNotEmpty) {
      return _quickPromptOptions;
    }
    return _fallbackQuickPromptOptions();
  }

  String _quickPromptLabelById(String id) {
    for (final option in _effectiveQuickPromptOptions()) {
      if (option.id == id) {
        return option.label;
      }
    }
    return '';
  }

  List<ChatQuickPromptOption> _fallbackQuickPromptOptions() {
    return <ChatQuickPromptOption>[
      ChatQuickPromptOption(
        id: 'plan_today',
        label: widget.strings.quickPromptPlanToday,
        mode: ChatQuickPromptMode.direct,
        prompt: widget.strings.quickPromptPlanTodaySubmit,
        hint: widget.strings.isZh ? '整理今天的安排' : 'Plan today',
      ),
      ChatQuickPromptOption(
        id: 'add_reminder',
        label: widget.strings.quickPromptAddReminder,
        mode: ChatQuickPromptMode.needsInput,
        prompt: widget.strings.quickPromptAddReminderSubmit,
        hint: widget.strings.isZh ? '说清提醒内容和时间' : 'Say what and when',
      ),
      ChatQuickPromptOption(
        id: 'capture_idea',
        label: widget.strings.quickPromptCaptureIdea,
        mode: ChatQuickPromptMode.needsInput,
        prompt: widget.strings.quickPromptCaptureIdeaSubmit,
        hint: widget.strings.isZh ? '说出想记录的想法' : 'Say the idea to save',
      ),
      ChatQuickPromptOption(
        id: 'organize_recent_ideas_web',
        label: widget.strings.quickPromptOrganizeRecentIdeasWeb,
        mode: ChatQuickPromptMode.direct,
        prompt: widget.strings.quickPromptOrganizeRecentIdeasWebSubmit,
        hint: widget.strings.isZh ? '生成想法网页' : 'Generate ideas page',
      ),
      ChatQuickPromptOption(
        id: 'merge_ideas',
        label: widget.strings.quickPromptMergeIdeas,
        mode: ChatQuickPromptMode.direct,
        prompt: widget.strings.quickPromptMergeIdeasSubmit,
        hint: widget.strings.isZh ? '整理近期想法' : 'Organize recent ideas',
      ),
      ChatQuickPromptOption(
        id: 'today_image',
        label: widget.strings.quickPromptTodayImage,
        mode: ChatQuickPromptMode.direct,
        prompt: widget.strings.quickPromptTodayImageSubmit,
        hint: widget.strings.isZh ? '直接生成今日画面' : 'Generate today image',
      ),
      ChatQuickPromptOption(
        id: 'daily_hot_brief',
        label: widget.strings.quickPromptDailyHotBrief,
        mode: ChatQuickPromptMode.direct,
        prompt: widget.strings.quickPromptDailyHotBriefSubmit,
        hint: widget.strings.isZh ? '搜索今日热点' : 'Search today hot news',
      ),
      ChatQuickPromptOption(
        id: 'hot_web_report',
        label: widget.strings.quickPromptHotWebReport,
        mode: ChatQuickPromptMode.direct,
        prompt: widget.strings.quickPromptHotWebReportSubmit,
        hint: widget.strings.isZh ? '生成网页报告' : 'Generate web report',
      ),
    ].take(_fallbackQuickPromptLimit).toList(growable: false);
  }

  List<String> _dedupeQuickPrompts(List<String> prompts) {
    final seen = <String>{};
    final deduped = <String>[];
    for (final prompt in prompts) {
      final normalized = prompt.trim();
      if (normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      deduped.add(normalized);
    }
    return deduped;
  }

  List<LingConversationStarterTask> _buildConversationStarterTasks() {
    final planToday = LingConversationStarterTask(
      label: widget.strings.starterTaskPlanToday,
      subtitle: widget.strings.starterTaskPlanTodaySubtitle,
      prompt: widget.strings.starterTaskPlanTodaySubmit,
    );
    final arrangeIdeas = LingConversationStarterTask(
      label: widget.strings.starterTaskArrangeIdeas,
      subtitle: widget.strings.starterTaskArrangeIdeasSubtitle,
      prompt: widget.strings.starterTaskArrangeIdeasSubmit,
    );
    final addReminder = LingConversationStarterTask(
      label: widget.strings.starterTaskAddReminder,
      subtitle: widget.strings.starterTaskAddReminderSubtitle,
      prompt: widget.strings.starterTaskAddReminderSubmit,
    );
    final captureIdea = LingConversationStarterTask(
      label: widget.strings.starterTaskCaptureIdea,
      subtitle: widget.strings.starterTaskCaptureIdeaSubtitle,
      prompt: widget.strings.starterTaskCaptureIdeaSubmit,
    );
    switch (_contextDigest?.display.starterHint.primaryTask) {
      case 'arrange_ideas':
        return <LingConversationStarterTask>[
          arrangeIdeas,
          planToday,
          addReminder,
        ];
      case 'capture_idea':
        return <LingConversationStarterTask>[
          captureIdea,
          addReminder,
          planToday,
        ];
      case 'plan_today':
        return <LingConversationStarterTask>[
          planToday,
          arrangeIdeas,
          addReminder,
        ];
    }
    return <LingConversationStarterTask>[planToday, arrangeIdeas, addReminder];
  }

  void _logQuickPromptPreviewState({
    required bool isConversationEmpty,
    required int renderedItemCount,
    required bool hasOlderEntries,
    required int quickPromptCount,
    required bool isAgentReplying,
    required bool shouldShowQuickPrompts,
  }) {
    final logKey = [
      _debugEmptyStateQuickPromptsVisible,
      isConversationEmpty,
      renderedItemCount,
      hasOlderEntries,
      quickPromptCount,
      isAgentReplying,
      shouldShowQuickPrompts,
      _isDockBusy,
      _isVoiceInteractionActive,
      _composerController.userText.trim().isNotEmpty,
      _pendingComposerAttachments.length,
    ].join('|');
    if (_lastQuickPromptDebugLogKey == logKey) {
      return;
    }
    _lastQuickPromptDebugLogKey = logKey;
  }

  Future<void> _submitQuickPrompt(String prompt) async {
    final promptId = _quickPromptAnalyticsId(prompt);
    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.isEmpty || _isDockBusy) {
      return;
    }
    _showQuickPromptsAfterActiveIntentCancel = false;
    unawaited(
      _trackChatEvent(
        'chat.quick_prompt.tap',
        action: 'quick_prompt_tap',
        source: 'quick_prompt',
        properties: <String, Object?>{'prompt_id': promptId},
      ),
    );
    unawaited(_recordQuickPromptUse(promptId));
    if (!_isKnownQuickPromptLabel(normalizedPrompt)) {
      _closeKeyboardComposer(clearText: true);
      await _submitPrompt(
        normalizedPrompt,
        source: 'quick_prompt',
        enqueueAsGuidanceWhenActive: true,
      );
      return;
    }
    final intent = _resolveQuickPromptIntent(normalizedPrompt);
    if (intent == null) {
      return;
    }
    if (_isDirectQuickPromptIntent(intent.id)) {
      _closeKeyboardComposer(clearText: true);
      await _submitPrompt(
        intent.instruction,
        source: 'quick_prompt',
        enqueueAsGuidanceWhenActive: true,
      );
      return;
    }
    _composerController.clear();
    _mutateDockSurface(() {
      _chatSessionController.setActiveQuickPromptIntent(intent);
    }, scrollToBottom: true);
    _openKeyboardComposer();
  }

  ActiveQuickPromptIntentState? _resolveQuickPromptIntent(String prompt) {
    final normalized = prompt.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final configured = _quickPromptOptionByLabel(normalized);
    if (configured != null) {
      return ActiveQuickPromptIntentState(
        id: configured.id,
        label: normalized,
        instruction: configured.prompt,
        hint: configured.hint.isEmpty
            ? (widget.strings.isZh ? '输入或说出具体内容' : 'Type or say the details')
            : configured.hint,
        source: 'quick_prompt',
      );
    }
    final quickPromptIntents = <String, ActiveQuickPromptIntentState>{
      widget.strings.quickPromptPlanToday: ActiveQuickPromptIntentState(
        id: 'plan_today',
        label: normalized,
        instruction: widget.strings.quickPromptPlanTodaySubmit,
        hint: widget.strings.isZh ? '整理今天的安排' : 'Plan today',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptAddReminder: ActiveQuickPromptIntentState(
        id: 'add_reminder',
        label: normalized,
        instruction: widget.strings.isZh
            ? '根据用户补充输入创建提醒；如果仍缺少必要的提醒内容或时间，只追问缺少的必要信息，信息齐了就直接创建。'
            : 'Create a reminder from the user input. If the reminder content or time is still missing, ask only for the missing required detail; once complete, create it.',
        hint: widget.strings.isZh ? '说清提醒内容和时间' : 'Say what and when',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptFindTime: ActiveQuickPromptIntentState(
        id: 'find_time',
        label: normalized,
        instruction: widget.strings.isZh
            ? '根据用户补充输入为这件事寻找合适空档；优先结合已有日程判断时间，并在需要时只追问必要信息。'
            : 'Find a suitable time slot for the user input. Prefer using the current schedule, and ask only for required missing details when needed.',
        hint: widget.strings.isZh ? '说要安排什么和时长' : 'Say what and how long',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptCaptureIdea: ActiveQuickPromptIntentState(
        id: 'capture_idea',
        label: normalized,
        instruction: widget.strings.isZh
            ? '把用户补充输入记录为一个 Ling 想法；主动判断合适的想法类型，不要强行安排到日历。'
            : 'Save the user input as a Ling idea. Choose the appropriate idea type, and do not force it onto the calendar.',
        hint: widget.strings.isZh ? '说出想记录的想法' : 'Say the idea to save',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptOrganizeRecentIdeasWeb:
          ActiveQuickPromptIntentState(
            id: 'organize_recent_ideas_web',
            label: normalized,
            instruction: widget.strings.quickPromptOrganizeRecentIdeasWebSubmit,
            hint: widget.strings.isZh ? '生成想法网页' : 'Generate ideas page',
            source: 'quick_prompt',
          ),
      widget.strings.quickPromptMergeIdeas: ActiveQuickPromptIntentState(
        id: 'merge_ideas',
        label: normalized,
        instruction: widget.strings.quickPromptMergeIdeasSubmit,
        hint: widget.strings.isZh ? '整理近期想法' : 'Organize recent ideas',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptArrangeIdeas: ActiveQuickPromptIntentState(
        id: 'arrange_ideas',
        label: normalized,
        instruction: widget.strings.isZh
            ? '根据用户补充输入和当前待处理想法，挑出适合推进的事项并安排下一步；如果用户补充的是新想法，先记录或更新想法，再判断是否需要安排。'
            : 'Use the user input and pending ideas to pick suitable items to move forward and plan the next step. If the input is a new idea, save or update it first, then decide whether it should be scheduled.',
        hint: widget.strings.isZh ? '说想安排哪个想法' : 'Say which idea to plan',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptOpenSchedule: ActiveQuickPromptIntentState(
        id: 'open_schedule',
        label: normalized,
        instruction: widget.strings.isZh
            ? '根据用户补充输入查看相关日程，并用简短列表告诉用户重点。'
            : 'Review the schedule related to the user input and summarize the key points in a short list.',
        hint: widget.strings.isZh ? '说想查看哪段时间' : 'Say which time to review',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptReviewWeek: ActiveQuickPromptIntentState(
        id: 'review_week',
        label: normalized,
        instruction: widget.strings.isZh
            ? '根据用户补充输入回顾本周，结合本周安排、已完成或需要跟进事项，给出简短总结和可执行调整。'
            : 'Review the week based on the user input, using this week’s schedule, completed items, and follow-ups to provide a short summary and actionable adjustments.',
        hint: widget.strings.isZh ? '说想回顾的重点' : 'Say what to review',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptTodayImage: ActiveQuickPromptIntentState(
        id: 'today_image',
        label: normalized,
        instruction: widget.strings.quickPromptTodayImageSubmit,
        hint: widget.strings.isZh ? '直接生成今日画面' : 'Generate today image',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptFutureLetter: ActiveQuickPromptIntentState(
        id: 'future_letter',
        label: normalized,
        instruction: widget.strings.quickPromptFutureLetterSubmit,
        hint: widget.strings.isZh ? '直接写未来来信' : 'Write the letter',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptOneMinutePodcast: ActiveQuickPromptIntentState(
        id: 'one_minute_podcast',
        label: normalized,
        instruction: widget.strings.quickPromptOneMinutePodcastSubmit,
        hint: widget.strings.isZh ? '生成口播和语音' : 'Create script and audio',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptPrivateRitual: ActiveQuickPromptIntentState(
        id: 'private_ritual',
        label: normalized,
        instruction: widget.strings.quickPromptPrivateRitualSubmit,
        hint: widget.strings.isZh ? '直接设计仪式' : 'Design the ritual',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptDreamPoster: ActiveQuickPromptIntentState(
        id: 'dream_poster',
        label: normalized,
        instruction: widget.strings.quickPromptDreamPosterSubmit,
        hint: widget.strings.isZh ? '生成梦境海报' : 'Generate dream poster',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptTodayNarration: ActiveQuickPromptIntentState(
        id: 'today_narration',
        label: normalized,
        instruction: widget.strings.quickPromptTodayNarrationSubmit,
        hint: widget.strings.isZh ? '直接写今日旁白' : 'Write today narration',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptReadImage: ActiveQuickPromptIntentState(
        id: 'read_image',
        label: normalized,
        instruction: widget.strings.quickPromptReadImageSubmit,
        hint: widget.strings.isZh
            ? '上传图片或说想看什么'
            : 'Upload an image or say what to inspect',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptSummarizeContent: ActiveQuickPromptIntentState(
        id: 'summarize_content',
        label: normalized,
        instruction: widget.strings.quickPromptSummarizeContentSubmit,
        hint: widget.strings.isZh ? '粘贴要总结的内容' : 'Paste what to summarize',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptMakeDecision: ActiveQuickPromptIntentState(
        id: 'make_decision',
        label: normalized,
        instruction: widget.strings.quickPromptMakeDecisionSubmit,
        hint: widget.strings.isZh
            ? '说出选项和限制'
            : 'Say the options and constraints',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptDraftMessage: ActiveQuickPromptIntentState(
        id: 'draft_message',
        label: normalized,
        instruction: widget.strings.quickPromptDraftMessageSubmit,
        hint: widget.strings.isZh
            ? '说对象、语气和目的'
            : 'Say audience, tone, and goal',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptDailyHotBrief: ActiveQuickPromptIntentState(
        id: 'daily_hot_brief',
        label: normalized,
        instruction: widget.strings.quickPromptDailyHotBriefSubmit,
        hint: widget.strings.isZh ? '生成热点简报' : 'Generate hot brief',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptAiNews: ActiveQuickPromptIntentState(
        id: 'ai_news',
        label: normalized,
        instruction: widget.strings.quickPromptAiNewsSubmit,
        hint: widget.strings.isZh ? '生成 AI 动态' : 'Generate AI brief',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptTrendRadar: ActiveQuickPromptIntentState(
        id: 'trend_radar',
        label: normalized,
        instruction: widget.strings.quickPromptTrendRadarSubmit,
        hint: widget.strings.isZh ? '生成趋势雷达' : 'Generate trend radar',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptHotWebReport: ActiveQuickPromptIntentState(
        id: 'hot_web_report',
        label: normalized,
        instruction: widget.strings.quickPromptHotWebReportSubmit,
        hint: widget.strings.isZh ? '生成网页报告' : 'Generate web report',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptProductsToday: ActiveQuickPromptIntentState(
        id: 'products_today',
        label: normalized,
        instruction: widget.strings.quickPromptProductsTodaySubmit,
        hint: widget.strings.isZh ? '生成产品雷达' : 'Generate product radar',
        source: 'quick_prompt',
      ),
      widget.strings.quickPromptInspirationBoard: ActiveQuickPromptIntentState(
        id: 'inspiration_board',
        label: normalized,
        instruction: widget.strings.quickPromptInspirationBoardSubmit,
        hint: widget.strings.isZh ? '生成灵感看板' : 'Generate inspiration board',
        source: 'quick_prompt',
      ),
    };
    return quickPromptIntents[normalized] ??
        ActiveQuickPromptIntentState(
          id: 'custom',
          label: normalized,
          instruction: normalized,
          hint: widget.strings.isZh ? '输入或说出具体内容' : 'Type or say the details',
          source: 'quick_prompt',
        );
  }

  bool _isKnownQuickPromptLabel(String prompt) {
    final normalized = prompt.trim();
    if (_quickPromptOptionByLabel(normalized) != null) {
      return true;
    }
    return {
      widget.strings.quickPromptPlanToday,
      widget.strings.quickPromptAddReminder,
      widget.strings.quickPromptFindTime,
      widget.strings.quickPromptCaptureIdea,
      widget.strings.quickPromptOrganizeRecentIdeasWeb,
      widget.strings.quickPromptMergeIdeas,
      widget.strings.quickPromptArrangeIdeas,
      widget.strings.quickPromptOpenSchedule,
      widget.strings.quickPromptReviewWeek,
      widget.strings.quickPromptTodayImage,
      widget.strings.quickPromptFutureLetter,
      widget.strings.quickPromptOneMinutePodcast,
      widget.strings.quickPromptPrivateRitual,
      widget.strings.quickPromptDreamPoster,
      widget.strings.quickPromptTodayNarration,
      widget.strings.quickPromptReadImage,
      widget.strings.quickPromptSummarizeContent,
      widget.strings.quickPromptMakeDecision,
      widget.strings.quickPromptDraftMessage,
      widget.strings.quickPromptDailyHotBrief,
      widget.strings.quickPromptAiNews,
      widget.strings.quickPromptTrendRadar,
      widget.strings.quickPromptHotWebReport,
      widget.strings.quickPromptProductsToday,
      widget.strings.quickPromptInspirationBoard,
    }.contains(normalized);
  }

  ChatQuickPromptOption? _quickPromptOptionByLabel(String label) {
    final normalized = label.trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final option in _effectiveQuickPromptOptions()) {
      if (option.label.trim() == normalized) {
        return option;
      }
    }
    return null;
  }

  ChatQuickPromptOption? _quickPromptOptionById(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final option in _effectiveQuickPromptOptions()) {
      if (option.id == normalized) {
        return option;
      }
    }
    return null;
  }

  bool _isDirectQuickPromptIntent(String id) {
    final option = _quickPromptOptionById(id);
    if (option != null) {
      return option.mode == ChatQuickPromptMode.direct;
    }
    return _directSubmitQuickPromptIds.contains(id);
  }

  String _quickPromptAnalyticsId(String prompt) {
    final normalized = prompt.trim();
    final configured = _quickPromptOptionByLabel(normalized);
    if (configured != null) {
      return configured.id;
    }
    final quickPromptIds = <String, String>{
      widget.strings.quickPromptPlanToday: 'plan_today',
      widget.strings.quickPromptAddReminder: 'add_reminder',
      widget.strings.quickPromptFindTime: 'find_time',
      widget.strings.quickPromptCaptureIdea: 'capture_idea',
      widget.strings.quickPromptOrganizeRecentIdeasWeb:
          'organize_recent_ideas_web',
      widget.strings.quickPromptMergeIdeas: 'merge_ideas',
      widget.strings.quickPromptArrangeIdeas: 'arrange_ideas',
      widget.strings.quickPromptOpenSchedule: 'open_schedule',
      widget.strings.quickPromptReviewWeek: 'review_week',
      widget.strings.quickPromptTodayImage: 'today_image',
      widget.strings.quickPromptFutureLetter: 'future_letter',
      widget.strings.quickPromptOneMinutePodcast: 'one_minute_podcast',
      widget.strings.quickPromptPrivateRitual: 'private_ritual',
      widget.strings.quickPromptDreamPoster: 'dream_poster',
      widget.strings.quickPromptTodayNarration: 'today_narration',
      widget.strings.quickPromptReadImage: 'read_image',
      widget.strings.quickPromptSummarizeContent: 'summarize_content',
      widget.strings.quickPromptMakeDecision: 'make_decision',
      widget.strings.quickPromptDraftMessage: 'draft_message',
      widget.strings.quickPromptDailyHotBrief: 'daily_hot_brief',
      widget.strings.quickPromptAiNews: 'ai_news',
      widget.strings.quickPromptTrendRadar: 'trend_radar',
      widget.strings.quickPromptHotWebReport: 'hot_web_report',
      widget.strings.quickPromptProductsToday: 'products_today',
      widget.strings.quickPromptInspirationBoard: 'inspiration_board',
    };
    return quickPromptIds[normalized] ?? 'custom';
  }

  Future<void> _recordQuickPromptUse(String promptId) async {
    if (promptId.trim().isEmpty || promptId == 'custom') {
      return;
    }
    try {
      await ref
          .read(chatRepositoryProvider)
          .recordQuickPromptUse(promptId: promptId);
    } catch (error, stackTrace) {
      AppLogger.debug(
        '[Ling][ChatSection] 快捷按钮使用记录上报失败',
        fields: <String, Object?>{'prompt_id': promptId, 'error': '$error'},
      );
      AppLogger.debug('$stackTrace');
    }
  }

  Future<void> _submitActionPrompt(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty || _isDockBusy) {
      return;
    }
    unawaited(
      _trackChatEvent(
        'chat.assistant_prompt.tap',
        action: 'assistant_prompt_tap',
        source: 'ling_action',
      ),
    );
    _closeKeyboardComposer(clearText: true);
    await _submitPrompt(
      text,
      source: 'ling_action',
      skipLocalMembershipGate: true,
      skipQueueMembershipReadinessCheck: true,
      enqueueAsGuidanceWhenActive: true,
    );
  }

  Future<void> _handleLingAction(LingChatAction action) async {
    if (action.kind == LingChatActionKind.prompt) {
      final prompt = action.prompt?.trim() ?? '';
      if (prompt.isNotEmpty) {
        await _submitActionPrompt(prompt);
      }
      return;
    }
    unawaited(
      _trackChatEvent(
        'chat.assistant_action.tap',
        action: 'assistant_action_tap',
        source: action.kind.name,
        properties: <String, Object?>{'target': action.target?.name ?? 'none'},
      ),
    );
    await widget.actions.onLingAction(context, action);
  }

  Future<void> _submitQuestionnaireResponse(
    LingQuestionnaireSubmission submission,
  ) async {
    if (_isDockBusy) {
      return;
    }
    unawaited(
      _trackChatEvent(
        'chat.questionnaire.submit',
        action: 'questionnaire_submit',
        source:
            submission.status == LingQuestionnaireResponseStatus.timeoutDefault
            ? 'timeout_default'
            : 'user',
        properties: <String, Object?>{
          'questionnaire_id': submission.questionnaire.id,
          'question_count': submission.questionnaire.questions.length,
        },
      ),
    );
    await _submitPrompt(
      submission.agentText,
      source: 'questionnaire',
      displayText: submission.displayText,
      skipLocalMembershipGate: true,
      skipQueueMembershipReadinessCheck: true,
      enqueueAsGuidanceWhenActive: true,
    );
  }

  // Lifecycle and recovery entry points.
  Future<void> _flushConversationStateImpl() async {
    if (_isDisposing) {
      return;
    }
    _conversationPersistenceTimer?.cancel();
    _conversationPersistenceTimer = null;
    final storageScope = _ensureConversationStateStorageScope();
    if (storageScope == null) {
      AppLogger.warn(
        '[Ling][ChatSection] 跳过立即持久化保存：storageScope 为空 '
        'sessionId=$_sessionId conversationCount=${_chatState.conversation.length}',
      );
      return;
    }
    await _persistConversationState(storageScope);
  }

  Future<void> _prepareForBackgroundTransitionImpl() async {
    AppLogger.info(
      '[Ling][ChatSection] 准备进入后台 '
      'sessionId=$_sessionId activeRunId=$_activePromptRunId '
      'isProcessing=$_isProcessingPromptQueue',
    );
    if (_isVoiceInteractionActive) {
      _cancelVoiceUiTimers();
      _chatRuntime.setPendingVoiceDraftTranscript(null);
      _chatSessionController.updateVoiceState(
        isStartingVoice: false,
        isRecordingVoice: false,
        isFinalizingVoice: false,
        voiceStopRequested: false,
        voiceDraftTranscript: '',
        voiceDraftAudioPath: '',
        voiceResultHandled: false,
      );
      await _chatVoiceOrchestrator.cancelRecognition();
    }
    await _flushConversationStateImpl();
  }

  Future<void> _restorePersistedConversationStateImpl() async {
    final storageScope = _ensureConversationStateStorageScope();
    if (storageScope == null) {
      AppLogger.warn(
        '[Ling][ChatSection] 跳过持久化恢复：storageScope 为空 '
        'profileUserId=${widget.profile?.userId} '
        'sessionUserId=${widget.currentAuthSession?.profile.userId}',
      );
      return;
    }
    AppLogger.info(
      '[Ling][ChatSection] 正在恢复持久化对话 '
      'storageScope=$storageScope sessionId=$_sessionId',
    );
    final restored = await _chatSessionOrchestrator
        .restorePersistedConversation(
          storageScope: storageScope,
          maxAge: _persistedConversationRestoreTtl,
        );
    if (restored.status == ChatPersistedConversationRestoreStatus.missing) {
      _recoverableSessionSource = ChatRecoverableSessionSource.localState;
      _chatSessionController.setLastPersistedConversationStateJson(null);
      _chatSessionController.setPersistedConversationUpdatedAt(null);
      return;
    }

    try {
      _chatSessionController.setPersistedConversationUpdatedAt(
        restored.updatedAt,
      );
      final preserveComposerDraft =
          shouldPreserveLingComposerDraftOnConversationRestore(
            isKeyboardComposerOpen: _isKeyboardComposerOpen,
            draftText: _composerController.userText,
            pendingAttachments: _pendingComposerAttachments,
          );
      AppLogger.info(
        '[Ling][ChatSection] 持久化恢复结果 '
        'status=${restored.status.name} '
        'sessionId=${restored.sessionId} '
        'count=${restored.conversation.length}',
      );
      if (restored.status == ChatPersistedConversationRestoreStatus.stale) {
        _chatSessionController.setLastPersistedConversationStateJson(null);
        _setRecoverableSessionId(
          restored.sessionId,
          source: ChatRecoverableSessionSource.localState,
        );
        return;
      }
      final restoredConversation = settleLingRecoveredConversationEntries(
        conversation: restored.conversation
            .map(LingConversationEntry.fromDto)
            .toList(growable: false),
      );
      if (!mounted) {
        return;
      }
      _mutateChatSurface(() {
        _setRecoverableSessionId(
          restored.sessionId,
          source: ChatRecoverableSessionSource.localState,
        );
        _chatSessionController.prepareForConversationRestore(
          preserveComposerDraft: preserveComposerDraft,
          preservePendingComposerAttachments: preserveComposerDraft,
          isUploadingImage: preserveComposerDraft && _isUploadingImage,
        );
        if (!preserveComposerDraft) {
          _composerController.clear();
        }
        _chatRuntime.setPendingVoiceDraftTranscript(null);
        _transientLoadedConversationEntryKeys.clear();
        _chatSessionController.replaceConversation(
          restoredConversation
              .map((entry) => entry.toDto())
              .toList(growable: false),
          visibleConversationEntryCount: _conversationInitialPageSize,
          conversationStartedAt:
              resolveLingConversationStartedAt(restoredConversation) ??
              _conversationStartedAt,
        );
        _restoreActiveRunRecord(restored.activeRun);
      }, scrollToBottom: true);
      _chatSessionController.setLastPersistedConversationStateJson(
        restored.persistedPayload,
      );
      unawaited(_flushPendingGuidanceIfIdle());
    } catch (_) {
      // Ignore malformed persisted chat state and keep the in-memory default.
    }
  }

  Future<void> _recoverActiveSessionFromServerImpl({
    bool allowFreshLocalConversationShortcut = true,
  }) async {
    if (!widget.isAuthenticated) {
      AppLogger.warn(
        '[Ling][ChatSection] 跳过服务端恢复 '
        'isAuthenticated=${widget.isAuthenticated} sessionId=$_sessionId',
      );
      return;
    }
    ChatRecoverableSession? recoverableSession;
    try {
      recoverableSession = await _resolveRecoverableSession();
    } catch (error, stackTrace) {
      AppLogger.warn(
        '[Ling][ChatSection] 解析可恢复会话失败 '
        'sessionId=$_sessionId error=$error stackTrace=$stackTrace',
      );
      return;
    }
    final sessionId = recoverableSession?.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      AppLogger.warn('[Ling][ChatSection] 跳过服务端恢复：没有可恢复会话');
      return;
    }
    final allowFreshLocalShortcut =
        allowFreshLocalConversationShortcut &&
        _hasRemoteConversationPaginationCursor();
    if (_chatSessionOrchestrator.shouldUseFreshLocalConversationForRecovery(
      localConversation: _chatState.conversation,
      sessionSource: recoverableSession!.source,
      isProcessingPromptQueue: _isProcessingPromptQueue,
      activePromptRunId: _activePromptRunId,
      persistedUpdatedAt: _persistedConversationUpdatedAt,
      gracePeriod: _conversationRemoteRecoveryGracePeriod,
      allowFreshLocalConversationShortcut: allowFreshLocalShortcut,
    )) {
      AppLogger.info(
        '[Ling][ChatSection] 跳过服务端恢复：本地对话仍然较新 '
        'sessionId=$sessionId localCount=${_conversation.length} '
        'source=${recoverableSession.source.name}',
      );
      return;
    }

    await _recoverSessionConversationFromServerImpl(
      recoverableSession,
      allowFreshLocalConversationShortcut: false,
    );
  }

  void _restoreActiveRunRecord(ChatActiveRunRecord? activeRun) {
    if (activeRun == null) {
      _chatSessionController.setActiveRunRecord(null);
      _chatSessionController.setActivePromptRunId(null);
      _chatSessionController.setProcessingPromptQueue(false);
      return;
    }
    final localRunId = activeRun.localRunId ?? _chatRuntime.nextPromptRunId();
    final restored = activeRun.copyWith(
      localRunId: localRunId,
      status: activeRun.status.trim().isEmpty ? 'active' : activeRun.status,
    );
    _chatSessionController.setActivePromptRunId(localRunId);
    _chatSessionController.setActiveRunRecord(restored);
    _chatSessionController.setProcessingPromptQueue(true);
  }

  Future<void> _recoverSessionConversationFromServerImpl(
    ChatRecoverableSession recoverableSession, {
    required bool allowFreshLocalConversationShortcut,
    bool drainAfterRecovery = true,
  }) async {
    final sessionId = recoverableSession.sessionId;
    if (sessionId.isEmpty) {
      return;
    }
    final allowFreshLocalShortcut =
        allowFreshLocalConversationShortcut &&
        _hasRemoteConversationPaginationCursor();
    if (_chatSessionOrchestrator.shouldUseFreshLocalConversationForRecovery(
      localConversation: _chatState.conversation,
      sessionSource: recoverableSession.source,
      isProcessingPromptQueue: _isProcessingPromptQueue,
      activePromptRunId: _activePromptRunId,
      persistedUpdatedAt: _persistedConversationUpdatedAt,
      gracePeriod: _conversationRemoteRecoveryGracePeriod,
      allowFreshLocalConversationShortcut: allowFreshLocalShortcut,
    )) {
      AppLogger.info(
        '[Ling][ChatSection] 跳过服务端恢复：本地对话仍然较新 '
        'sessionId=$sessionId localCount=${_conversation.length} '
        'source=${recoverableSession.source.name}',
      );
      return;
    }

    try {
      AppLogger.info(
        '[Ling][ChatSection] 正在从服务端恢复对话 '
        'sessionId=$sessionId localCount=${_conversation.length} '
        'source=${recoverableSession.source.name}',
      );
      if (sessionId != _sessionId) {
        _setRecoverableSessionId(sessionId, source: recoverableSession.source);
      }
      final recovery = await _chatSessionOrchestrator
          .recoverSessionConversation(sessionId);
      if (!mounted || sessionId != _sessionId) {
        AppLogger.warn(
          '[Ling][ChatSection] 丢弃服务端恢复结果：widget 已过期 '
          'requestedSessionId=$sessionId currentSessionId=$_sessionId',
        );
        return;
      }
      final restoredEntries = recovery.conversation
          .map(LingConversationEntry.fromDto)
          .toList(growable: false);
      final recoveredEntries = recovery.hasStreamingEntry
          ? restoredEntries
          : settleLingRecoveredConversationEntries(
              conversation: restoredEntries,
            );
      final localActiveRun = _activeRunRecord;
      final mergedRecoveredEntries =
          _mergeRecoveredConversationWithLocalOptimisticUsers(
            recoveredEntries: recoveredEntries,
            sessionId: sessionId,
            localActiveRun: localActiveRun,
            shouldPreserve:
                recovery.activeRun != null ||
                localActiveRun != null ||
                _isProcessingPromptQueue,
          );
      AppLogger.info(
        '[Ling][ChatSection] 服务端恢复结果 '
        'sessionId=$sessionId count=${mergedRecoveredEntries.length} '
        'hasStreaming=${recovery.hasStreamingEntry} '
        'activeRun=${recovery.activeRun?.serverRunId ?? ''}',
      );
      final activeRunStateMayChange =
          recovery.activeRun != null ||
          _activeRunRecord != null ||
          _activePromptRunId != null ||
          _isProcessingPromptQueue;
      if (!activeRunStateMayChange &&
          !shouldApplyLingRecoveredConversation(
            currentConversation: _conversation,
            recoveredConversation: mergedRecoveredEntries,
            currentHasMoreRemoteConversationEntries:
                _chatState.hasMoreRemoteConversationEntries,
            recoveredHasMoreRemoteConversationEntries:
                recovery.hasMoreRemoteEntries,
            currentOlderConversationBeforeCreatedAt:
                _chatState.olderConversationBeforeCreatedAt,
            recoveredOlderConversationBeforeCreatedAt:
                recovery.olderCursor?.beforeCreatedAt,
            currentOlderConversationBeforeRecordId:
                _chatState.olderConversationBeforeRecordId,
            recoveredOlderConversationBeforeRecordId:
                recovery.olderCursor?.beforeRecordId,
          )) {
        AppLogger.info(
          '[Ling][ChatSection] 跳过服务端恢复应用：会话状态未变化 '
          'sessionId=$sessionId localCount=${_conversation.length}',
        );
        return;
      }
      _mutateConversationSurface(() {
        _recoverableSessionSource = ChatRecoverableSessionSource.localState;
        _chatSessionController.setInterruptingActivePrompt(false);
        if (recovery.activeRun != null) {
          _restoreActiveRunRecord(recovery.activeRun);
        } else {
          _completeActiveRunFromSnapshot(sessionId);
        }
        _transientLoadedConversationEntryKeys.clear();
        _chatSessionController.replaceConversation(
          mergedRecoveredEntries
              .map((entry) => entry.toDto())
              .toList(growable: false),
          visibleConversationEntryCount: _conversationInitialPageSize,
          hasMoreRemoteConversationEntries: recovery.hasMoreRemoteEntries,
          olderConversationBeforeCreatedAt:
              recovery.olderCursor?.beforeCreatedAt,
          clearOlderConversationBeforeCreatedAt:
              recovery.olderCursor?.beforeCreatedAt == null,
          olderConversationBeforeRecordId: recovery.olderCursor?.beforeRecordId,
          clearOlderConversationBeforeRecordId:
              recovery.olderCursor?.beforeRecordId == null,
          conversationStartedAt:
              resolveLingConversationStartedAt(mergedRecoveredEntries) ??
              _conversationStartedAt,
        );
      }, scrollToBottom: true);
      _notifyDockSurfaceChanged();
      if (drainAfterRecovery) {
        _drainOrFlushPendingAfterCompletion();
      }
    } catch (_) {
      // Recovery is best-effort when the app returns from background.
    }
  }

  List<LingConversationEntry>
  _mergeRecoveredConversationWithLocalOptimisticUsers({
    required List<LingConversationEntry> recoveredEntries,
    required String sessionId,
    required ChatActiveRunRecord? localActiveRun,
    required bool shouldPreserve,
  }) {
    if (!shouldPreserve || _conversation.isEmpty) {
      return recoveredEntries;
    }
    final recoveredKeys = <String>{};
    final recoveredUserMessageIds = <String>{};
    DateTime? latestRecoveredCreatedAt;
    for (final entry in recoveredEntries) {
      recoveredKeys.add(_conversationEntryIdentity(entry.toDto()));
      final createdAt = entry.createdAt;
      if (createdAt != null &&
          (latestRecoveredCreatedAt == null ||
              createdAt.isAfter(latestRecoveredCreatedAt))) {
        latestRecoveredCreatedAt = createdAt;
      }
      if (entry.role == LingConversationRole.user) {
        final messageId = entry.messageId?.trim();
        if (messageId != null && messageId.isNotEmpty) {
          recoveredUserMessageIds.add(messageId);
        }
      }
    }

    final activeUserMessageId = localActiveRun?.userMessageId?.trim();
    final merged = recoveredEntries.toList(growable: true);
    for (final entry in _conversation) {
      if (entry.role != LingConversationRole.user) {
        continue;
      }
      if (!_entryBelongsToSession(entry, sessionId)) {
        continue;
      }
      final messageId = entry.messageId?.trim();
      if (messageId == null || messageId.isEmpty) {
        continue;
      }
      final key = _conversationEntryIdentity(entry.toDto());
      if (recoveredKeys.contains(key) ||
          recoveredUserMessageIds.contains(messageId)) {
        continue;
      }
      final isActiveUserMessage =
          activeUserMessageId != null &&
          activeUserMessageId.isNotEmpty &&
          messageId == activeUserMessageId;
      final createdAt = entry.createdAt;
      final isNewerThanSnapshot =
          createdAt != null &&
          (latestRecoveredCreatedAt == null ||
              createdAt.isAfter(latestRecoveredCreatedAt));
      if (!isActiveUserMessage && !isNewerThanSnapshot) {
        continue;
      }
      merged.insert(_conversationEntryInsertIndex(merged, entry), entry);
      recoveredKeys.add(key);
      recoveredUserMessageIds.add(messageId);
    }
    return List<LingConversationEntry>.unmodifiable(merged);
  }

  bool _entryBelongsToSession(LingConversationEntry entry, String sessionId) {
    final entrySessionId = entry.sessionId?.trim();
    return entrySessionId == null ||
        entrySessionId.isEmpty ||
        entrySessionId == sessionId;
  }

  int _conversationEntryInsertIndex(
    List<LingConversationEntry> conversation,
    LingConversationEntry incoming,
  ) {
    final incomingCreatedAt = incoming.createdAt;
    if (incomingCreatedAt == null) {
      return conversation.length;
    }
    for (var index = conversation.length - 1; index >= 0; index -= 1) {
      final entryCreatedAt = conversation[index].createdAt;
      if (entryCreatedAt == null ||
          !entryCreatedAt.isAfter(incomingCreatedAt)) {
        return index + 1;
      }
    }
    return 0;
  }

  Future<ChatRecoverableSession?> _resolveRecoverableSession() async {
    Future<ChatRecoverableSession> activateFreshSession(
      AgentSessionSummary session, {
      required String previousSessionId,
    }) async {
      final freshSessionId = await _chatSessionOrchestrator.ensureSession(
        existingSessionId: null,
        entryMode: session.entryMode,
        selectedDate: session.selectedDate ?? widget.selectedDate,
        timezone: session.timezone,
      );
      if (mounted) {
        _chatSessionController.resetSessionSurface(
          visibleConversationEntryCount: _conversationInitialPageSize,
        );
        _transientLoadedConversationEntryKeys.clear();
        _chatSessionController.clearConversationPersistenceSnapshot();
        _chatSessionController.setLastPersistedConversationStateJson(null);
        _chatSessionController.setPersistedConversationUpdatedAt(null);
        _setRecoverableSessionId(
          freshSessionId,
          source: ChatRecoverableSessionSource.localState,
        );
      }
      AppLogger.info(
        '[Ling][ChatSection] 已轮换过期会话 sessionId=$previousSessionId '
        'newSessionId=$freshSessionId',
      );
      return ChatRecoverableSession(
        sessionId: freshSessionId,
        source: ChatRecoverableSessionSource.localState,
      );
    }

    final existingSessionId = _sessionId;
    if (existingSessionId != null && existingSessionId.isNotEmpty) {
      try {
        final session = await _chatSessionOrchestrator.getSession(
          existingSessionId,
        );
        if (session != null &&
            _chatSessionOrchestrator.isSessionStale(session.createdAt)) {
          return activateFreshSession(
            session,
            previousSessionId: existingSessionId,
          );
        }
      } catch (error) {
        AppLogger.warn(
          '[Ling][ChatSection] 检查现有会话失败 '
          'sessionId=$existingSessionId error=$error',
        );
      }
      return ChatRecoverableSession(
        sessionId: existingSessionId,
        source: _recoverableSessionSource,
      );
    }

    AppLogger.info('[Ling][ChatSection] 本地缺少 sessionId，正在从服务端获取最新会话');
    final latestSession = await _chatSessionOrchestrator.getLatestSession();
    final latestSessionId = latestSession?.sessionId.trim();
    if (latestSessionId == null || latestSessionId.isEmpty) {
      return null;
    }
    if (latestSession != null &&
        _chatSessionOrchestrator.isSessionStale(latestSession.createdAt)) {
      return activateFreshSession(
        latestSession,
        previousSessionId: latestSessionId,
      );
    }
    if (mounted) {
      _setRecoverableSessionId(
        latestSessionId,
        source: ChatRecoverableSessionSource.latestServerSession,
      );
    }
    AppLogger.info(
      '[Ling][ChatSection] 已解析用于恢复的最新会话 sessionId=$latestSessionId',
    );
    return ChatRecoverableSession(
      sessionId: latestSessionId,
      source: ChatRecoverableSessionSource.latestServerSession,
    );
  }

  void _resetSessionSurfaceImpl() {
    _conversationPersistenceTimer?.cancel();
    _conversationPersistenceTimer = null;
    _recoverableSessionSource = ChatRecoverableSessionSource.localState;
    _isInputPanelExpandedByUser = false;
    _cancelVoiceUiTimers();
    _chatRuntime.setPendingVoiceDraftTranscript(null);
    _composerController.clear();
    _transientLoadedConversationEntryKeys.clear();
    _chatSessionController.resetSessionSurface(
      conversation: const <ConversationEntryDto>[],
      visibleConversationEntryCount: _conversationInitialPageSize,
      conversationStartedAt: DateTime.now(),
    );
  }

  void _dismissKeyboardComposerImpl({bool clearText = false}) {
    if (clearText) {
      _clearKeyboardComposerText();
      if (_isKeyboardComposerOpen && !_composerFocusNode.hasFocus) {
        _openKeyboardComposer();
      }
      return;
    }
    _closeKeyboardComposer(clearText: clearText);
  }

  void _prefillKeyboardComposerDraftImpl(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty || _isDockBusy) {
      return;
    }
    _composerController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    _isInputPanelExpandedByUser = false;
    _mutateDockSurface(() {
      _chatSessionController.clearPendingObjectReferences();
    }, scrollToBottom: true);
    _openKeyboardComposer();
    _notifyDockSurfaceChanged(scrollToBottom: true);
  }

  void _prefillKeyboardComposerWithObjectReferenceImpl(
    LingObjectReference reference,
  ) {
    if (_isDockBusy) {
      return;
    }
    _mutateDockSurface(() {
      _chatSessionController.setPendingObjectReferences(<LingObjectReference>[
        reference,
      ]);
      _chatSessionController.setKeyboardComposerOpen(true);
    }, scrollToBottom: true);
    _openKeyboardComposer();
  }

  // Surface mutation helpers.
  void _notifyChatSurfaceChanged({
    bool scrollToBottom = false,
    bool forceScrollToBottom = false,
    bool persistConversation = true,
  }) {
    if (!mounted) {
      return;
    }
    if (persistConversation) {
      _schedulePersistedConversationStateSave();
    }
    if (scrollToBottom) {
      _scheduleConversationScrollToBottom(force: forceScrollToBottom);
    }
  }

  void _notifyDockSurfaceChanged({
    bool scrollToBottom = false,
    bool forceScrollToBottom = false,
  }) {
    _notifyChatSurfaceChanged(
      scrollToBottom: scrollToBottom,
      forceScrollToBottom: forceScrollToBottom,
      persistConversation: false,
    );
  }

  void _mutateChatSurface(
    VoidCallback mutation, {
    bool scrollToBottom = false,
    bool forceScrollToBottom = false,
  }) {
    if (!mounted) {
      return;
    }
    mutation();
    _notifyChatSurfaceChanged(
      scrollToBottom: scrollToBottom,
      forceScrollToBottom: forceScrollToBottom,
    );
  }

  void _mutateConversationSurface(
    VoidCallback mutation, {
    bool scrollToBottom = false,
    bool forceScrollToBottom = false,
    bool persistConversation = true,
  }) {
    if (!mounted) {
      return;
    }
    mutation();
    _notifyChatSurfaceChanged(
      scrollToBottom: scrollToBottom,
      forceScrollToBottom: forceScrollToBottom,
      persistConversation: persistConversation,
    );
  }

  void _mutateDockSurface(
    VoidCallback mutation, {
    bool scrollToBottom = false,
    bool forceScrollToBottom = false,
  }) {
    if (!mounted) {
      return;
    }
    mutation();
    _notifyDockSurfaceChanged(
      scrollToBottom: scrollToBottom,
      forceScrollToBottom: forceScrollToBottom,
    );
  }

  void _mutateConversationViewport(VoidCallback mutation) {
    if (!mounted) {
      return;
    }
    mutation();
  }

  // Conversation scroll and pagination helpers.
  void _scheduleConversationScrollToBottom({bool force = false}) {
    if (!force && !_conversationAutoScrollEnabled) {
      return;
    }
    _queueConversationScrollToBottom(force: force);
  }

  void _explicitScrollConversationToLatest() {
    _conversationAutoScrollEnabled = true;
    _setShowScrollToBottomButton(false);
    _queueConversationScrollToBottom(force: true);
  }

  void _animateConversationToBottom() {
    _conversationAutoScrollEnabled = true;
    _inputPanelScrollFrameToken += 1;
    if (_conversationScrollController.hasClients) {
      final position = _conversationScrollController.position;
      final target = position.maxScrollExtent;
      if ((target - position.pixels).abs() > 0.5) {
        _isProgrammaticConversationScrollActive = true;
        try {
          _conversationScrollController.jumpTo(target);
        } finally {
          _isProgrammaticConversationScrollActive = false;
        }
      }
    }
    _setShowScrollToBottomButton(false);
    _queueConversationScrollToBottom(force: true);
  }

  void _queueConversationScrollToBottom({
    bool force = false,
    int? remainingFrames,
  }) {
    final nextRemainingFrames = remainingFrames ?? (force ? 3 : 0);
    if (_conversationScrollQueued) {
      _conversationScrollQueuedForce = _conversationScrollQueuedForce || force;
      if (nextRemainingFrames > _conversationScrollQueuedRemainingFrames) {
        _conversationScrollQueuedRemainingFrames = nextRemainingFrames;
      }
      return;
    }
    _conversationScrollQueued = true;
    _conversationScrollQueuedForce = force;
    _conversationScrollQueuedRemainingFrames = nextRemainingFrames;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shouldForce = _conversationScrollQueuedForce;
      final remainingFrames = _conversationScrollQueuedRemainingFrames;
      _conversationScrollQueued = false;
      _conversationScrollQueuedForce = false;
      _conversationScrollQueuedRemainingFrames = 0;
      if (!mounted || !_conversationScrollController.hasClients) {
        if (mounted && shouldForce && remainingFrames > 0) {
          _queueConversationScrollToBottom(
            force: true,
            remainingFrames: remainingFrames - 1,
          );
        }
        return;
      }
      if (!shouldExecuteLingQueuedConversationScrollToBottom(
        isForced: shouldForce,
        autoScrollEnabled: _conversationAutoScrollEnabled,
        isPagingOlderEntries: _isPagingOlderConversationEntries,
      )) {
        return;
      }
      final position = _conversationScrollController.position;
      final target = position.maxScrollExtent;
      final isAtBottom = (target - position.pixels).abs() <= 0.5;
      if (isAtBottom) {
        if (shouldForce && remainingFrames > 0) {
          _queueConversationScrollToBottom(
            force: true,
            remainingFrames: remainingFrames - 1,
          );
        }
        return;
      }
      _isProgrammaticConversationScrollActive = true;
      try {
        _conversationScrollController.jumpTo(target);
      } finally {
        _isProgrammaticConversationScrollActive = false;
      }
      if (shouldForce && remainingFrames > 0) {
        _queueConversationScrollToBottom(
          force: true,
          remainingFrames: remainingFrames - 1,
        );
      }
    });
  }

  void _cancelQueuedConversationScrollToBottom() {
    _conversationScrollQueued = false;
    _conversationScrollQueuedForce = false;
    _conversationScrollQueuedRemainingFrames = 0;
  }

  void _handleConversationScrollChanged() {
    if (!_conversationScrollController.hasClients) {
      return;
    }
    final wasAutoScrollEnabled = _conversationAutoScrollEnabled;
    _conversationAutoScrollEnabled = _isConversationNearBottom();
    _setShowScrollToBottomButton(!_conversationAutoScrollEnabled);
    if (wasAutoScrollEnabled &&
        !_conversationAutoScrollEnabled &&
        !_isProgrammaticConversationScrollActive) {
      _inputPanelScrollFrameToken += 1;
      _cancelQueuedConversationScrollToBottom();
    }
  }

  void _handleConversationUserScroll() {
    if (_isProgrammaticConversationScrollActive) {
      return;
    }
    _inputPanelScrollFrameToken += 1;
    _cancelQueuedConversationScrollToBottom();
  }

  bool _isConversationNearBottom() {
    if (!_conversationScrollController.hasClients) {
      return true;
    }
    final position = _conversationScrollController.position;
    return position.maxScrollExtent - position.pixels <=
        _conversationBottomSnapThreshold;
  }

  bool _hasOlderConversationEntries() {
    return _hasRemoteConversationPaginationCursor();
  }

  bool _hasRemoteConversationPaginationCursor() {
    return (_chatState.olderConversationBeforeCreatedAt?.trim().isNotEmpty ??
            false) &&
        (_chatState.olderConversationBeforeRecordId?.trim().isNotEmpty ??
            false);
  }

  bool _isHistoricalConversationEntry(ConversationEntryDto entry) {
    final entrySessionId = entry.sessionId?.trim();
    final currentSessionId = _sessionId?.trim();
    return entrySessionId != null &&
        entrySessionId.isNotEmpty &&
        currentSessionId != null &&
        currentSessionId.isNotEmpty &&
        entrySessionId != currentSessionId;
  }

  bool _isCurrentSessionUserEntryDto(ConversationEntryDto entry) {
    if (entry.role != 'user') {
      return false;
    }
    final entrySessionId = entry.sessionId?.trim();
    final currentSessionId = _sessionId?.trim();
    return entrySessionId == null ||
        entrySessionId.isEmpty ||
        currentSessionId == null ||
        currentSessionId.isEmpty ||
        entrySessionId == currentSessionId;
  }

  LingConversationViewport _buildConversationViewportForCurrentState() {
    final conversation = _chatState.conversation;
    final visibleDtos = <ConversationEntryDto>[];
    var renderableCount = 0;
    for (var index = conversation.length - 1; index >= 0; index -= 1) {
      final entry = conversation[index];
      if (!_isRenderableConversationEntryDto(entry)) {
        continue;
      }
      renderableCount += 1;
      if (visibleDtos.length < _visibleConversationEntryCount) {
        visibleDtos.add(entry);
      }
    }
    final visibleEntries = visibleDtos.reversed
        .map(_buildVisibleConversationEntry)
        .toList(growable: false);
    final renderedItems = buildLingConversationRenderItems(
      visibleEntries: visibleEntries,
    );
    final hiddenEntryCount = renderableCount - visibleEntries.length;
    return LingConversationViewport(
      visibleEntries: visibleEntries,
      renderedItems: renderedItems,
      hasOlderEntries: hiddenEntryCount > 0,
      hiddenEntryCount: hiddenEntryCount,
      itemCount: renderedItems.length + (hiddenEntryCount > 0 ? 1 : 0),
    );
  }

  LingConversationEntry _buildVisibleConversationEntry(
    ConversationEntryDto entry,
  ) {
    return LingConversationEntry.fromDto(
      filterMissingLocalAudioAttachments(entry, exists: _localFileExists),
    );
  }

  bool _isRenderableConversationEntryDto(ConversationEntryDto entry) {
    return !isLingHiddenConversationErrorMessageType(entry.messageType);
  }

  void _setShowScrollToBottomButton(bool value) {
    if (_showScrollToBottomButton == value || !mounted) {
      return;
    }
    setState(() {
      _showScrollToBottomButton = value;
    });
  }

  void _consumePendingConversationEntryScroll() {
    if (widget.isCalendarOpen ||
        _isPagingOlderConversationEntries ||
        !_scrollConversationToLatestOnNextViewEntry) {
      return;
    }
    _scrollConversationToLatestOnNextViewEntry = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.isCalendarOpen) {
        return;
      }
      _scheduleConversationScrollToBottom();
    });
  }

  void _scheduleConversationScrollAfterInputPanelTransition({
    bool force = false,
  }) {
    if (!force && !_conversationAutoScrollEnabled) {
      return;
    }
    final frameToken = ++_inputPanelScrollFrameToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || frameToken != _inputPanelScrollFrameToken) {
        return;
      }
      if (force) {
        _explicitScrollConversationToLatest();
        return;
      }
      _queueConversationScrollToBottom(force: true);
    });
    _keyboardComposerScrollTimer?.cancel();
    _keyboardComposerScrollTimer = Timer(const Duration(milliseconds: 320), () {
      _keyboardComposerScrollTimer = null;
      if (frameToken != _inputPanelScrollFrameToken) {
        return;
      }
      if (force) {
        _explicitScrollConversationToLatest();
        return;
      }
      _scheduleConversationScrollToBottom();
    });
  }

  void _showMoreConversationEntries(LingConversationScrollAnchor? anchor) {
    unawaited(_showMoreConversationEntriesAsync(anchor: anchor));
  }

  Future<void> _showMoreConversationEntriesAsync({
    LingConversationScrollAnchor? anchor,
  }) async {
    if (_isPagingOlderConversationEntries) {
      return;
    }
    final sessionId = _sessionId;
    final cursor =
        _chatState.olderConversationBeforeCreatedAt == null ||
            _chatState.olderConversationBeforeRecordId == null
        ? null
        : ChatSessionEntriesCursor(
            beforeCreatedAt: _chatState.olderConversationBeforeCreatedAt!,
            beforeRecordId: _chatState.olderConversationBeforeRecordId!,
          );
    if (sessionId == null || sessionId.trim().isEmpty || cursor == null) {
      _chatSessionController.setRemoteConversationPagination(hasMore: false);
      return;
    }
    _cancelQueuedConversationScrollToBottom();
    _isPagingOlderConversationEntries = true;
    _conversationAutoScrollEnabled = false;
    _setLoadingRemoteConversationEntries(true);
    try {
      final snapshot = await _chatSessionOrchestrator
          .getOlderConversationEntries(
            currentSessionId: sessionId,
            before: cursor,
            limit: _conversationRemotePaginationPageSize,
          );
      if (!mounted || sessionId != _sessionId) {
        _isLoadingRemoteConversationEntries = false;
        _finishPagingOlderConversationEntries();
        return;
      }
      final loadedEntries = _settleLoadedOlderConversationEntries(
        snapshot.entries,
      );
      _transientLoadedConversationEntryKeys.addAll(
        loadedEntries.map(_conversationEntryIdentity),
      );
      final mergedConversation = _prependConversationEntries(
        olderEntries: loadedEntries,
        currentEntries: _chatState.conversation,
      );
      final mergedRenderableCount = _countRenderableConversationEntries(
        mergedConversation,
      );
      _isLoadingRemoteConversationEntries = false;
      _mutateConversationViewport(() {
        _chatSessionController.replaceConversation(
          mergedConversation,
          visibleConversationEntryCount: mergedRenderableCount,
          hasMoreRemoteConversationEntries:
              snapshot.hasMore && snapshot.olderCursor != null,
          olderConversationBeforeCreatedAt:
              snapshot.olderCursor?.beforeCreatedAt,
          clearOlderConversationBeforeCreatedAt:
              snapshot.olderCursor?.beforeCreatedAt == null,
          olderConversationBeforeRecordId: snapshot.olderCursor?.beforeRecordId,
          clearOlderConversationBeforeRecordId:
              snapshot.olderCursor?.beforeRecordId == null,
        );
      });
      _restorePagedConversationScrollOffset(anchor: anchor);
    } catch (error) {
      AppLogger.warn('[Ling][ChatSection] 加载更早对话失败 error=$error');
      _setLoadingRemoteConversationEntries(false);
      _finishPagingOlderConversationEntries();
    }
  }

  void _finishPagingOlderConversationEntries() {
    if (!_isPagingOlderConversationEntries) {
      return;
    }
    if (!mounted) {
      _isPagingOlderConversationEntries = false;
      return;
    }
    setState(() {
      _isPagingOlderConversationEntries = false;
    });
  }

  int _countRenderableConversationEntries(
    Iterable<ConversationEntryDto> conversation,
  ) {
    var renderableCount = 0;
    for (final entry in conversation) {
      if (_isRenderableConversationEntryDto(entry)) {
        renderableCount += 1;
      }
    }
    return renderableCount;
  }

  List<ConversationEntryDto> _settleLoadedOlderConversationEntries(
    List<ConversationEntryDto> entries,
  ) {
    return List<ConversationEntryDto>.unmodifiable(
      entries.map((entry) {
        if (!entry.isStreaming && entry.status == 'completed') {
          return entry;
        }
        return ConversationEntryDto(
          id: entry.id,
          sessionId: entry.sessionId,
          entryType: entry.entryType,
          role: entry.role,
          createdAt: entry.createdAt,
          messageId: entry.messageId,
          messageType: entry.messageType,
          text: entry.text,
          attachments: entry.attachments,
          isStreaming: false,
          toolCallId: entry.toolCallId,
          toolName: entry.toolName,
          toolArguments: entry.toolArguments,
          toolResult: entry.toolResult,
          durationMs: entry.durationMs,
          metadata: entry.metadata,
          status: 'completed',
        );
      }),
    );
  }

  void _setLoadingRemoteConversationEntries(bool value) {
    if (_isLoadingRemoteConversationEntries == value) {
      return;
    }
    if (!mounted) {
      _isLoadingRemoteConversationEntries = value;
      return;
    }
    setState(() {
      _isLoadingRemoteConversationEntries = value;
    });
  }

  List<ConversationEntryDto> _prependConversationEntries({
    required List<ConversationEntryDto> olderEntries,
    required List<ConversationEntryDto> currentEntries,
  }) {
    final seen = <String>{};
    final merged = <ConversationEntryDto>[];
    for (final entry in [...olderEntries, ...currentEntries]) {
      final key = _conversationEntryIdentity(entry);
      if (seen.add(key)) {
        merged.add(entry);
      }
    }
    return List<ConversationEntryDto>.unmodifiable(merged);
  }

  String _conversationEntryIdentity(ConversationEntryDto entry) {
    final sessionId = entry.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      return entry.id;
    }
    return '$sessionId:${entry.id}';
  }

  void _restorePagedConversationScrollOffset({
    required LingConversationScrollAnchor? anchor,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_conversationScrollController.hasClients) {
        _finishPagingOlderConversationEntries();
        return;
      }
      if (anchor == null) {
        AppLogger.warn('[Ling][ChatSection] 分页后跳过位置校正：缺少锚点');
        _finishPagingOlderConversationEntries();
        return;
      }
      _stabilizePagedConversationAnchor(anchor, remainingFrames: 2);
    });
  }

  double? _restorePagedConversationAnchorOnly(
    LingConversationScrollAnchor? anchor,
  ) {
    final anchorContext = anchor?.itemKey.currentContext;
    final anchorRenderObject = anchorContext?.findRenderObject();
    if (anchor == null ||
        anchorRenderObject is! RenderBox ||
        !anchorRenderObject.attached) {
      return null;
    }
    final position = _conversationScrollController.position;
    final currentDy =
        anchorRenderObject.localToGlobal(Offset.zero).dy +
        anchorRenderObject.size.height;
    final distance = currentDy - anchor.globalDy;
    final targetOffset = (position.pixels + currentDy - anchor.globalDy)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((targetOffset - position.pixels).abs() > 0.25) {
      _conversationScrollController.jumpTo(targetOffset);
    }
    return distance.abs();
  }

  void _stabilizePagedConversationAnchor(
    LingConversationScrollAnchor anchor, {
    required int remainingFrames,
  }) {
    if (remainingFrames <= 0) {
      _finishPagingOlderConversationEntries();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_conversationScrollController.hasClients) {
        _finishPagingOlderConversationEntries();
        return;
      }
      final distance = _restorePagedConversationAnchorOnly(anchor);
      if (distance != null && distance <= 0.75) {
        _finishPagingOlderConversationEntries();
        return;
      }
      _stabilizePagedConversationAnchor(
        anchor,
        remainingFrames: remainingFrames - 1,
      );
    });
  }

  // Conversation persistence helpers.
  String? _ensureConversationStateStorageScope() {
    final effectiveProfile =
        widget.profile ?? widget.currentAuthSession?.profile;
    final scope =
        _conversationStorageScope ??
        _chatSessionOrchestrator.resolveStorageScope(profile: effectiveProfile);
    if (scope == null) {
      return null;
    }
    _chatSessionController.setStorageScope(scope);
    return scope;
  }

  void _setRecoverableSessionId(
    String? sessionId, {
    required ChatRecoverableSessionSource source,
  }) {
    _recoverableSessionSource = source;
    _chatSessionController.setSessionId(sessionId);
  }

  void _schedulePersistedConversationStateSave() {
    final storageScope = _ensureConversationStateStorageScope();
    if (storageScope == null) {
      AppLogger.warn(
        '[Ling][ChatSection] 跳过安排持久化保存：storageScope 为空 '
        'sessionId=$_sessionId conversationCount=${_chatState.conversation.length}',
      );
      return;
    }
    AppLogger.info(
      '[Ling][ChatSection] 安排持久化保存 '
      'storageScope=$storageScope sessionId=$_sessionId '
      'conversationCount=${_chatState.conversation.length}',
    );
    _conversationPersistenceTimer?.cancel();
    _conversationPersistenceTimer = Timer(_conversationPersistenceDebounce, () {
      _conversationPersistenceTimer = null;
      unawaited(_persistConversationState(storageScope));
    });
  }

  Future<void> _persistConversationState(String storageScope) async {
    final chatState = _chatState;
    final sessionId = chatState.sessionId;
    final previousPayload = chatState.lastPersistedConversationStateJson;
    final conversation = chatState.conversation;
    final persistableConversation =
        _transientLoadedConversationEntryKeys.isEmpty
        ? conversation
        : conversation
              .where(
                (entry) => !_transientLoadedConversationEntryKeys.contains(
                  _conversationEntryIdentity(entry),
                ),
              )
              .toList(growable: false);
    final visibleEntries = _chatSessionOrchestrator
        .buildPersistableConversation(
          persistableConversation,
          currentSessionId: sessionId,
        );
    AppLogger.info(
      '[Ling][ChatSection] 持久化对话状态 '
      'storageScope=$storageScope sessionId=$sessionId '
      'totalCount=${conversation.length} '
      'persistableCount=${visibleEntries.length}',
    );
    final persistedState = await _chatSessionOrchestrator
        .saveConversationStateIfChanged(
          storageScope: storageScope,
          sessionId: sessionId,
          conversation: visibleEntries,
          activeRun: chatState.activeRunRecord,
          previousPayload: previousPayload,
        );
    if (persistedState == null) {
      AppLogger.info(
        '[Ling][ChatSection] 跳过持久化：payload 未变化 '
        'storageScope=$storageScope sessionId=$sessionId',
      );
      return;
    }
    AppLogger.info(
      '[Ling][ChatSection] 持久化对话已保存 '
      'storageScope=$storageScope sessionId=$sessionId',
    );
    if (!mounted) {
      return;
    }
    _chatSessionController.setLastPersistedConversationStateJson(
      persistedState.payload,
    );
    _chatSessionController.setPersistedConversationUpdatedAt(
      persistedState.persistedAt,
    );
  }

  Future<void> _openImagePicker(ImageSource source) async {
    if (_isDockBusy) {
      return;
    }
    if (source == ImageSource.camera &&
        AppPlatformInfo.current == AppPlatform.ios) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) {
        return;
      }
    }

    try {
      final pickedFiles = await _chatSessionOrchestrator.pickConversationImages(
        source: source,
        platform: AppPlatformInfo.current,
      );
      if (pickedFiles.isEmpty) {
        return;
      }

      if (mounted) {
        _mutateDockSurface(() {
          _chatSessionController.setUploadingImage(true);
        });
      }

      final uploadResult = await _chatSessionOrchestrator
          .uploadConversationImages(pickedFiles);
      if (mounted) {
        _mutateDockSurface(() {
          _chatSessionController.setUploadingImage(false);
        });
      }
      _queuePendingComposerAttachments(
        uploadResult.uploads
            .map(
              (upload) => LingConversationAttachment.fromDto(
                upload.attachment,
              ).copyWithBytes(upload.bytes),
            )
            .toList(growable: false),
      );
      unawaited(
        _trackChatEvent(
          uploadResult.error == null
              ? 'chat.image.upload_success'
              : 'chat.image.upload_partial_failure',
          action: uploadResult.error == null
              ? 'image_upload_success'
              : 'image_upload_partial_failure',
          source: source.name,
          properties: <String, Object?>{
            'picked_count': pickedFiles.length,
            'uploaded_count': uploadResult.uploads.length,
          },
        ),
      );
      if (uploadResult.error case final error?) {
        _showError(error);
      }
    } catch (error) {
      unawaited(
        _trackChatEvent(
          'chat.image.upload_failure',
          action: 'image_upload_failure',
          source: source.name,
          properties: <String, Object?>{
            'error_type': error.runtimeType.toString(),
          },
        ),
      );
      _showError(error);
    } finally {
      if (mounted && _isUploadingImage) {
        _mutateDockSurface(() {
          _chatSessionController.setUploadingImage(false);
        });
      }
    }
  }

  Future<List<LingConversationAttachment>> _importPendingSharedImages({
    bool queueForComposer = true,
    bool openComposer = true,
  }) async {
    if (_isImportingSharedImages || _isDockBusy || !mounted) {
      return const <LingConversationAttachment>[];
    }
    _isImportingSharedImages = true;
    var didSetUploading = false;
    Object? firstError;
    final importedAttachments = <LingConversationAttachment>[];
    final consumedImages = <SharedImageFile>[];

    try {
      final pendingImages = await _sharedImageReceiveBridge
          .getPendingSharedImages();
      if (pendingImages.isEmpty || !mounted) {
        return const <LingConversationAttachment>[];
      }
      _mutateDockSurface(() {
        _chatSessionController.setUploadingImage(true);
      });
      didSetUploading = true;

      for (final image in pendingImages) {
        try {
          final uploadResult = await _chatSessionOrchestrator
              .uploadConversationImages([
                XFile(image.path, name: image.filename),
              ]);
          if (uploadResult.uploads.isNotEmpty) {
            final upload = uploadResult.uploads.first;
            importedAttachments.add(
              LingConversationAttachment.fromDto(
                upload.attachment,
              ).copyWithBytes(upload.bytes),
            );
            consumedImages.add(image);
          }
          firstError ??= uploadResult.error;
        } catch (error) {
          firstError ??= error;
        }
      }

      if (consumedImages.isNotEmpty) {
        await _sharedImageReceiveBridge.consumeSharedImages(consumedImages);
      }
      if (!mounted) {
        return importedAttachments;
      }
      if (didSetUploading) {
        _mutateDockSurface(() {
          _chatSessionController.setUploadingImage(false);
        });
        didSetUploading = false;
      }
      if (queueForComposer) {
        _queuePendingComposerAttachments(importedAttachments);
      }
      if (queueForComposer && openComposer && importedAttachments.isNotEmpty) {
        _openKeyboardComposer(requestFocus: false);
      }
      if (firstError case final error?) {
        _showError(error);
      }
      return importedAttachments;
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
      return const <LingConversationAttachment>[];
    } finally {
      _isImportingSharedImages = false;
      if (mounted && didSetUploading) {
        _mutateDockSurface(() {
          _chatSessionController.setUploadingImage(false);
        });
      }
    }
  }

  Future<void> _importSharedItems(SharedItemsAvailability availability) async {
    if (_isImportingSharedItems) {
      return;
    }
    _isImportingSharedItems = true;
    try {
      final sharedText = availability.shouldImportPasteboardText
          ? await _takeSharedPasteboardText()
          : null;
      final importedAttachments = availability.hasPendingFiles
          ? await _importPendingSharedImages(
              queueForComposer: !availability.shouldAutoSend,
              openComposer: !availability.shouldAutoSend,
            )
          : const <LingConversationAttachment>[];
      final sanitizedSharedText = sanitizeSharedTextForImportedAttachments(
        sharedText,
        hasSharedImageFiles:
            availability.hasPendingFiles || importedAttachments.isNotEmpty,
      );

      if (!mounted) {
        return;
      }
      if (availability.shouldAutoSend) {
        await _sendImportedSharedItems(
          text: sanitizedSharedText,
          attachments: importedAttachments,
        );
        return;
      }
      if (sanitizedSharedText.isNotEmpty) {
        _insertTextIntoComposer(sanitizedSharedText);
        _openKeyboardComposer();
      }
    } finally {
      _isImportingSharedItems = false;
    }
  }

  Future<String?> _takeSharedPasteboardText() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) {
        return null;
      }
      final text = data?.text?.trim();
      return text == null || text.isEmpty ? null : text;
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
      return null;
    } finally {
      await _sharedImageReceiveBridge.consumeSharedPasteboardTextRequest();
    }
  }

  Future<void> _sendImportedSharedItems({
    required String? text,
    required List<LingConversationAttachment> attachments,
  }) async {
    final prompt = text?.trim() ?? '';
    if (prompt.isEmpty && attachments.isEmpty) {
      return;
    }
    final didSend = await _submitPrompt(
      prompt,
      source: 'share',
      attachments: attachments,
      skipQueueMembershipReadinessCheck: true,
    );
    if (!mounted) {
      return;
    }
    if (!didSend) {
      if (prompt.isNotEmpty) {
        _insertTextIntoComposer(prompt);
      }
      _queuePendingComposerAttachments(attachments);
      _openKeyboardComposer(requestFocus: false);
      return;
    }
    _explicitScrollConversationToLatest();
    _scheduleConversationScrollAfterInputPanelTransition(force: true);
  }

  void _insertTextIntoComposer(String text) {
    final currentText = _composerController.text;
    final selection = _composerController.selection;
    final start = selection.isValid
        ? math
              .min(selection.baseOffset, selection.extentOffset)
              .clamp(0, currentText.length)
        : currentText.length;
    final end = selection.isValid
        ? math
              .max(selection.baseOffset, selection.extentOffset)
              .clamp(0, currentText.length)
        : currentText.length;
    final prefix = start == currentText.length
        ? _voiceComposerSeparatorFor(currentText)
        : '';
    final insertedText = '$prefix$text';
    final nextText = currentText.replaceRange(start, end, insertedText);
    final nextOffset = start + insertedText.length;
    _composerController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
      composing: TextRange.empty,
    );
    _notifyDockSurfaceChanged(scrollToBottom: true);
  }

  Future<void> _openDockImageSourceSheet() async {
    if (_isDockBusy) {
      return;
    }
    final source = await showLingAdaptiveActionSheet<ImageSource>(
      context: context,
      title: widget.strings.chooseImageSource,
      cancelLabel: widget.strings.cancel,
      actions: [
        LingAdaptiveActionSheetAction<ImageSource>(
          value: ImageSource.gallery,
          label: widget.strings.photoLibrary,
          icon: Icons.photo_library_outlined,
        ),
        LingAdaptiveActionSheetAction<ImageSource>(
          value: ImageSource.camera,
          label: widget.strings.takePhoto,
          icon: Icons.photo_camera_outlined,
        ),
      ],
    );
    if (!mounted || source == null) {
      return;
    }

    await _handleDockImageSourceTap(source);
  }

  Future<void> _handleDockImageSourceTap(ImageSource source) async {
    final hadFocus = _composerFocusNode.hasFocus;
    _composerFocusNode.unfocus();
    if (hadFocus) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) {
        return;
      }
    }
    await _openImagePicker(source);
  }

  Future<bool> _submitPrompt(
    String text, {
    required String source,
    String? displayText,
    List<LingConversationAttachment> attachments = const [],
    bool skipLocalMembershipGate = false,
    bool skipQueueMembershipReadinessCheck = false,
    bool enqueueAsGuidanceWhenActive = false,
    bool waitForCompletion = false,
    bool explicitScrollToLatest = true,
    Map<String, dynamic>? inputMetadata,
  }) async {
    final normalizedAttachments = List<LingConversationAttachment>.from(
      attachments,
      growable: false,
    );
    final metadata = inputMetadata ?? _inputMetadataForPromptSource(source);
    var skipMembershipReadinessForQueuedPrompt =
        skipQueueMembershipReadinessCheck;
    if (!skipLocalMembershipGate) {
      if (await _maybeBlockPromptSubmission(
        text: text,
        attachments: normalizedAttachments,
      )) {
        return false;
      }
      skipMembershipReadinessForQueuedPrompt = true;
    }
    if (!mounted) {
      return false;
    }
    if (!await widget.actions.onBeforePromptSubmit(context)) {
      return false;
    }
    final shouldInterruptActiveRun = _hasActivePromptRun;
    if (shouldInterruptActiveRun && enqueueAsGuidanceWhenActive) {
      unawaited(
        _trackChatEvent(
          'chat.prompt.submit',
          action: 'prompt_submit',
          source: source,
          properties: _promptAnalyticsProperties(
            attachments: normalizedAttachments,
            queued: true,
            interruptedActiveRun: false,
          ),
        ),
      );
      await _injectPendingGuidance(
        text,
        source: source,
        displayText: displayText,
        attachments: normalizedAttachments,
        metadata: metadata,
      );
      return true;
    }
    if (shouldInterruptActiveRun) {
      final interrupted = await _interruptActivePromptForImmediateSend();
      if (!interrupted) {
        return false;
      }
    }
    final didQueue = _chatQueueOrchestrator.enqueuePrompt(
      text: text,
      source: source,
      displayText: displayText,
      metadata: metadata,
      attachments: normalizedAttachments.map(
        (attachment) => attachment.toDto(),
      ),
      runtime: _chatRuntime,
      controller: _chatSessionController,
    );
    if (!didQueue) {
      return false;
    }
    unawaited(
      _trackChatEvent(
        'chat.prompt.submit',
        action: 'prompt_submit',
        source: source,
        properties: _promptAnalyticsProperties(
          attachments: normalizedAttachments,
          queued: false,
          interruptedActiveRun: shouldInterruptActiveRun,
        ),
      ),
    );
    widget.actions.onPromptSubmitted();
    _notifyDockSurfaceChanged();
    if (explicitScrollToLatest) {
      _explicitScrollConversationToLatest();
    }
    if (waitForCompletion) {
      return await _drainPendingPromptQueueAsync(
        skipMembershipReadinessCheck: skipMembershipReadinessForQueuedPrompt,
        waitForProcessing: true,
      );
    }
    _drainPendingPromptQueue(
      skipMembershipReadinessCheck: skipMembershipReadinessForQueuedPrompt,
    );
    return true;
  }

  Map<String, dynamic> _inputMetadataForPromptSource(String source) {
    return source == 'voice'
        ? const <String, dynamic>{'input_source': 'voice_transcript'}
        : const <String, dynamic>{};
  }

  Future<void> _injectPendingGuidance(
    String text, {
    required String source,
    String? displayText,
    required List<LingConversationAttachment> attachments,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final prompt = text.trim();
    final normalizedDisplayText = displayText?.trim();
    final attachmentDtos = attachments
        .map((attachment) => attachment.toDto())
        .toList(growable: false);
    if (prompt.isEmpty && attachmentDtos.isEmpty) {
      return;
    }
    final guidanceId = _chatRuntime.nextQueuedPromptId();
    final request = QueuedPromptState(
      id: guidanceId,
      text: prompt,
      source: source,
      displayText:
          normalizedDisplayText == null || normalizedDisplayText.isEmpty
          ? null
          : normalizedDisplayText,
      metadata: metadata,
      attachments: attachmentDtos,
      isGuidance: true,
    );
    _chatSessionController.enqueuePrompt(request);
    widget.actions.onPromptSubmitted();
    _notifyDockSurfaceChanged();
  }

  Future<void> _editQueuedPrompt(LingPendingPromptRequest request) async {
    final consumed = _chatSessionController.takeQueuedPromptById(request.id);
    if (consumed == null) {
      return;
    }
    _restoreQueuedPromptDraft(consumed.request);
  }

  Future<void> _removeQueuedPrompt(String requestId) async {
    if (!_chatSessionController.removeQueuedPromptById(requestId)) {
      return;
    }
    _notifyDockSurfaceChanged();
  }

  Future<void> _applyQueuedPromptNow(LingPendingPromptRequest request) async {
    final consumed = _chatSessionController.takeQueuedPromptById(request.id);
    if (consumed == null) {
      return;
    }
    final consumedRequestState = consumed.request;
    final consumedRequest = LingPendingPromptRequest.fromState(
      consumedRequestState,
    );
    final prompt = consumedRequest.text.trim();
    final attachments = List<LingConversationAttachment>.from(
      consumedRequest.attachments,
      growable: false,
    );
    void restoreConsumedRequest() {
      final alreadyQueued = _pendingPromptQueue.any(
        (item) => item.id == consumedRequest.id,
      );
      if (alreadyQueued) {
        return;
      }
      _chatSessionController.insertPromptAt(
        consumed.index,
        consumedRequestState,
      );
      _notifyDockSurfaceChanged();
    }

    _notifyDockSurfaceChanged();
    if (prompt.isEmpty && attachments.isEmpty) {
      return;
    }
    if (await _maybeBlockPromptSubmission(
      text: prompt,
      attachments: attachments,
    )) {
      restoreConsumedRequest();
      return;
    }
    if (_hasActivePromptRun) {
      final interrupted = await _interruptActivePromptForImmediateSend();
      if (!interrupted) {
        restoreConsumedRequest();
        return;
      }
    }
    _explicitScrollConversationToLatest();
    final sessionId = _sessionId;
    if (sessionId == null || !consumedRequest.isGuidance) {
      if (!mounted) {
        return;
      }
      if (await widget.actions.onHandleLocalChatGate(context)) {
        restoreConsumedRequest();
        return;
      }
      _chatSessionController.setProcessingPromptQueue(true);
      await _processPromptRequest(consumedRequest);
      return;
    }
    await _runImmediateGuidancePrompt(
      sessionId: sessionId,
      request: consumedRequest,
      prompt: prompt,
      attachments: attachments,
      flushPendingGuidanceAfterCompletion: false,
    );
  }

  Future<void> _runImmediateGuidancePrompt({
    required String sessionId,
    required LingPendingPromptRequest request,
    required String prompt,
    required List<LingConversationAttachment> attachments,
    bool flushPendingGuidanceAfterCompletion = true,
  }) async {
    var runRequest = request.toState();
    final attachmentDtos = attachments
        .map((attachment) => attachment.toDto())
        .toList(growable: false);
    final runId = _chatRuntime.nextPromptRunId();
    if (!flushPendingGuidanceAfterCompletion) {
      _runIdsWithoutPendingGuidanceFlush.add(runId);
    }
    _chatSessionController.setActivePromptRunId(runId);
    _chatSessionController.setProcessingPromptQueue(true);
    final userEntry = _chatSessionOrchestrator.buildUserConversationEntry(
      prompt: request.displayText ?? prompt,
      attachments: attachmentDtos,
      messageId: request.id,
      metadata: {
        ...request.metadata,
        'guidance_id': request.id,
        if (request.displayText != null) ...{
          'agent_text': prompt,
          'display_text': request.displayText,
        },
      },
    );
    _mutateConversationSurface(() {
      _chatSessionController.appendConversationEntry(userEntry);
    }, scrollToBottom: true);
    widget.actions.onPromptSubmitted();
    _notifyDockSurfaceChanged();

    try {
      runRequest = await _uploadLocalAudioAttachmentsForQueuedRequest(
        runRequest,
        userEntry,
      );
      final runStart = await _chatSessionOrchestrator.startPromptRun(
        runId: runId,
        sessionId: sessionId,
        messages: [
          _chatSessionOrchestrator.buildPromptMessage(
            prompt: prompt,
            attachments: runRequest.attachments,
            messageId: request.id,
            metadata: runRequest.metadata,
          ),
        ],
        systemContext: const <String, dynamic>{
          'rerun_from_edit_last_user_message': true,
          'rerun_from_guidance': true,
        },
        onEvent: _applyConversationEvent,
      );
      await _waitForPromptRunCompletion(
        promptResult: ChatPromptExecutionResult(
          sessionId: sessionId,
          serverRunId: runStart.serverRunId,
        ),
        request: runRequest,
        localRunId: runId,
      );
    } catch (error) {
      if (_chatSessionOrchestrator.isPromptRunInterrupted(runId)) {
        return;
      }
      final handled = mounted
          ? await widget.actions.onHandlePromptExecutionError(context, error)
          : false;
      if (handled) {
        if (mounted) {
          _mutateConversationSurface(() {
            _chatSessionController.removeConversationEntryById(userEntry.id);
          }, scrollToBottom: true);
        }
        _restoreQueuedPromptDraft(runRequest);
        return;
      }
      AppLogger.warn('[Ling][ChatSection] 重新发送请求失败，已隐藏页面错误 error=$error');
      _mutateConversationSurface(() {
        _chatSessionController.appendConversationEntry(
          _chatSessionOrchestrator.buildPromptErrorEntry(error),
        );
      }, scrollToBottom: true);
    } finally {
      if (_activePromptRunId == runId) {
        _chatSessionController.setActivePromptRunId(null);
      }
      _chatSessionOrchestrator.completePromptRun(runId);
      _mutateConversationSurface(() {
        _chatSessionController.settleStreamingConversationEntries();
      }, scrollToBottom: true);
      _chatSessionController.setProcessingPromptQueue(false);
      _chatSessionController.setActiveRunRecord(null);
      _schedulePersistedConversationStateSave();
      _notifyDockSurfaceChanged();
      if (!_isInterruptingActivePrompt) {
        _drainOrFlushPendingAfterCompletion(
          flushPendingGuidance: _shouldFlushPendingGuidanceAfterRun(runId),
        );
      }
      _runIdsWithoutPendingGuidanceFlush.remove(runId);
    }
  }

  Future<bool> _interruptActivePromptForImmediateSend() async {
    final runId = _activePromptRunId;
    if (runId != null &&
        _chatSessionOrchestrator.isPromptRunInterrupted(runId)) {
      return true;
    }
    final activeRun = _activeRunRecord;
    final activeServerRunId = _normalizeRunId(activeRun?.serverRunId);
    final activeSessionId = _normalizeRunId(activeRun?.sessionId ?? _sessionId);
    if (runId != null) {
      _runIdsWithoutPendingGuidanceFlush.add(runId);
    }
    _chatSessionController.setInterruptingActivePrompt(true);
    var settledBeforeNextRun = false;
    try {
      _mutateConversationSurface(() {
        _chatSessionController.settleStreamingConversationEntries();
      }, scrollToBottom: true);
      _notifyDockSurfaceChanged();
      await _chatSessionOrchestrator.interruptActivePrompt(
        activeRunId: runId,
        sessionId: _sessionId,
      );
      settledBeforeNextRun = await _waitForInterruptedRunToRenderBeforeNextRun(
        sessionId: activeSessionId,
        serverRunId: activeServerRunId,
      );
      if (!settledBeforeNextRun) {
        return false;
      }
      return true;
    } catch (error) {
      if (runId != null) {
        _runIdsWithoutPendingGuidanceFlush.remove(runId);
      }
      _showError(error);
      return false;
    } finally {
      if (runId != null) {
        _chatSessionOrchestrator.completePromptRun(runId);
      }
      if (!settledBeforeNextRun) {
        if (runId != null && _activePromptRunId == runId) {
          _chatSessionController.setActivePromptRunId(null);
        }
        _completeCurrentActiveRunLocally(completed: false);
        _chatSessionController.setProcessingPromptQueue(false);
      }
      _chatSessionController.setInterruptingActivePrompt(false);
      _notifyDockSurfaceChanged();
    }
  }

  Future<bool> _waitForInterruptedRunToRenderBeforeNextRun({
    required String sessionId,
    required String serverRunId,
  }) async {
    if (serverRunId.isNotEmpty) {
      final completer = _activeRunCompletionByServerRunId[serverRunId];
      if (completer != null && !completer.isCompleted) {
        await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => false,
        );
      }
    }
    if (!_isSameActiveRun(sessionId: sessionId, serverRunId: serverRunId)) {
      return true;
    }
    if (sessionId.isEmpty || !mounted) {
      return serverRunId.isEmpty;
    }
    await _recoverSessionConversationFromServerImpl(
      ChatRecoverableSession(
        sessionId: sessionId,
        source: ChatRecoverableSessionSource.localState,
      ),
      allowFreshLocalConversationShortcut: false,
      drainAfterRecovery: false,
    );
    return !_isSameActiveRun(sessionId: sessionId, serverRunId: serverRunId);
  }

  bool _isSameActiveRun({
    required String sessionId,
    required String serverRunId,
  }) {
    final activeRun = _activeRunRecord;
    if (activeRun == null) {
      return false;
    }
    final activeServerRunId = _normalizeRunId(activeRun.serverRunId);
    if (serverRunId.isNotEmpty && activeServerRunId.isNotEmpty) {
      return activeServerRunId == serverRunId;
    }
    final activeSessionId = _normalizeRunId(activeRun.sessionId ?? _sessionId);
    return sessionId.isNotEmpty && activeSessionId == sessionId;
  }

  Future<void> _interruptActivePromptFromDock() async {
    if (_isInterruptingActivePrompt) {
      return;
    }
    final runId = _activePromptRunId;
    if (runId != null &&
        _chatSessionOrchestrator.isPromptRunInterrupted(runId)) {
      return;
    }
    _chatSessionController.setInterruptingActivePrompt(true);
    try {
      _mutateConversationSurface(() {
        _chatSessionController.settleStreamingConversationEntries();
      }, scrollToBottom: true);
      _notifyDockSurfaceChanged();
      await _chatSessionOrchestrator.interruptActivePrompt(
        activeRunId: runId,
        sessionId: _sessionId,
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (runId != null && _activePromptRunId == runId) {
        _chatSessionController.setActivePromptRunId(null);
      }
      if (runId != null) {
        _chatSessionOrchestrator.completePromptRun(runId);
      }
      _completeCurrentActiveRunLocally(completed: false);
      _chatSessionController.setProcessingPromptQueue(false);
      _chatSessionController.setInterruptingActivePrompt(false);
      _notifyDockSurfaceChanged();
      _drainOrFlushPendingAfterCompletion();
    }
  }

  Future<void> _openQueuedPromptSheet() async {
    final queuedItems = _pendingGuidanceQueue;
    if (queuedItems.length <= 1) {
      return;
    }
    await showLingQueuedPromptSheet(
      context: context,
      queuedItems: queuedItems,
      title: widget.strings.guidanceQueueCount(queuedItems.length),
      cancelLabel: widget.strings.cancel,
      applyNowTooltip: widget.strings.applyQueuedMessageNow,
      deleteTooltip: widget.strings.deleteQueuedMessage,
      editTooltip: widget.strings.editAction,
      previewBuilder: (request) => buildLingQueuedPromptPreview(
        request: request,
        queuedImageMessageBuilder: widget.strings.queuedImageMessage,
        maxCharacters: 48,
      ),
      queuedImageLabelBuilder: widget.strings.queuedImageMessage,
      onDelete: (request) => unawaited(_removeQueuedPrompt(request.id)),
      onApplyNow: (request) => unawaited(_applyQueuedPromptNow(request)),
      onEdit: (request) => unawaited(_editQueuedPrompt(request)),
    );
  }

  void _drainPendingPromptQueue({bool skipMembershipReadinessCheck = false}) {
    unawaited(
      _drainPendingPromptQueueAsync(
        skipMembershipReadinessCheck: skipMembershipReadinessCheck,
      ),
    );
  }

  Future<bool> _drainPendingPromptQueueAsync({
    bool skipMembershipReadinessCheck = false,
    bool waitForProcessing = false,
  }) async {
    if (_isDrainingPendingPromptQueue) {
      return false;
    }
    _isDrainingPendingPromptQueue = true;
    try {
      if (!widget.isAppInForeground) {
        if (_pendingPromptQueue.isNotEmpty) {
          AppLogger.info(
            '[Ling][ChatSection] 应用在后台，跳过处理 prompt 队列 '
            'pendingCount=${_pendingPromptQueue.length} sessionId=$_sessionId',
          );
        }
        return false;
      }
      if (_isProcessingPromptQueue || _pendingPromptQueue.isEmpty) {
        return false;
      }
      final hasUserPrompt = _pendingPromptQueue.any(
        (request) => !request.isGuidance,
      );
      if (!hasUserPrompt) {
        return false;
      }
      if (!skipMembershipReadinessCheck &&
          !await _ensureMembershipReadyForChat()) {
        return false;
      }
      final nextRequestState = _chatQueueOrchestrator.beginQueuedPrompt(
        isMounted: mounted,
        isProcessingPromptQueue: _isProcessingPromptQueue,
        hasPendingPromptQueue: _pendingPromptQueue.isNotEmpty,
        controller: _chatSessionController,
      );
      if (nextRequestState == null) {
        return false;
      }
      final nextRequest = LingPendingPromptRequest.fromState(nextRequestState);
      if (!mounted) {
        return false;
      }
      if (await widget.actions.onHandleLocalChatGate(context)) {
        _chatSessionController.setProcessingPromptQueue(false);
        _notifyDockSurfaceChanged();
        _restoreQueuedPromptDraft(nextRequestState);
        return false;
      }
      _notifyDockSurfaceChanged();
      if (waitForProcessing) {
        return await _processPromptRequest(nextRequest);
      }
      unawaited(_processPromptRequest(nextRequest));
      return true;
    } finally {
      _isDrainingPendingPromptQueue = false;
    }
  }

  Future<bool> _processPromptRequest(LingPendingPromptRequest request) async {
    return _chatQueueOrchestrator.processPromptRequest(
      request: request.toState(),
      runtime: _chatRuntime,
      controller: _chatSessionController,
      sessionOrchestrator: _chatSessionOrchestrator,
      existingSessionId: _sessionId,
      conversation: _chatState.conversation,
      entryMode: request.source,
      selectedDate: widget.selectedDate,
      timezone: widget.timezone,
      isAppInForeground: () => widget.isAppInForeground,
      currentConversation: () => _chatState.conversation,
      currentActivePromptRunId: () => _activePromptRunId,
      isInterruptingActivePrompt: () => _isInterruptingActivePrompt,
      appendConversationEntry: (entry) {
        if (!mounted) {
          return;
        }
        _mutateConversationSurface(() {
          _chatSessionController.appendConversationEntry(entry);
        }, scrollToBottom: true);
      },
      handlePromptExecutionError: (error, queuedRequest, userEntryId) async {
        final wasHandled = mounted
            ? await widget.actions.onHandlePromptExecutionError(context, error)
            : false;
        if (!wasHandled) {
          return false;
        }
        if (mounted) {
          _mutateConversationSurface(() {
            _chatSessionController.removeConversationEntryById(userEntryId);
          }, scrollToBottom: true);
        }
        _restoreQueuedPromptDraft(queuedRequest);
        return true;
      },
      onSessionReady: (sessionId) {
        AppLogger.info(
          '[Ling][ChatSection] 会话已就绪 sessionId=$sessionId '
          'previousSessionId=$_sessionId',
        );
        _setRecoverableSessionId(
          sessionId,
          source: ChatRecoverableSessionSource.localState,
        );
        _schedulePersistedConversationStateSave();
      },
      onConversationEvent: _applyConversationEvent,
      prepareRequestForRun: _uploadLocalAudioAttachmentsForQueuedRequest,
      waitForRunCompletion:
          ({required promptResult, required request, required localRunId}) =>
              _waitForPromptRunCompletion(
                promptResult: promptResult,
                request: request,
                localRunId: localRunId,
              ),
      showError: _showError,
      settleStreamingConversationEntries: () {
        if (!mounted) {
          return;
        }
        _mutateConversationSurface(() {
          _chatSessionController.settleStreamingConversationEntries();
        }, scrollToBottom: true);
        _schedulePersistedConversationStateSave();
      },
      notifyDockSurfaceChanged: _notifyDockSurfaceChanged,
      drainPendingPromptQueue: (completedRunId) {
        _drainOrFlushPendingAfterCompletion(
          flushPendingGuidance: _shouldFlushPendingGuidanceAfterRun(
            completedRunId,
          ),
        );
      },
    );
  }

  Future<QueuedPromptState> _uploadLocalAudioAttachmentsForQueuedRequest(
    QueuedPromptState request,
    ConversationEntryDto userEntry,
  ) async {
    if (request.attachments.isEmpty) {
      return request;
    }
    final uploadedAttachments = <AttachmentDto>[];
    var changed = false;
    for (final attachment in request.attachments) {
      if (!_isLocalAudioAttachment(attachment)) {
        uploadedAttachments.add(attachment);
        continue;
      }
      final path = _localAudioAttachmentPath(attachment);
      if (path.isEmpty) {
        uploadedAttachments.add(attachment);
        continue;
      }
      try {
        final file = File(path);
        final bytes = await file.readAsBytes();
        final filename = attachment.filename.trim().isNotEmpty
            ? attachment.filename.trim()
            : p.basename(path);
        final uploaded = await _chatSessionOrchestrator.uploadConversationAudio(
          bytes: bytes,
          filename: filename.isEmpty ? 'voice.caf' : filename,
        );
        uploadedAttachments.add(uploaded);
        changed = true;
      } catch (error) {
        AppLogger.warn(
          '[Ling][ChatSection] 语音附件上传失败，将继续发送文字 '
          'requestId=${request.id} error=$error',
        );
        uploadedAttachments.add(attachment);
      }
    }
    if (!changed) {
      return request;
    }
    final preparedRequest = request.copyWith(
      attachments: List<AttachmentDto>.unmodifiable(uploadedAttachments),
    );
    if (mounted) {
      _mutateConversationSurface(() {
        _chatSessionController.upsertConversationEntry(
          _copyConversationEntryWithAttachments(
            userEntry,
            preparedRequest.attachments,
          ),
        );
      }, scrollToBottom: true);
      _schedulePersistedConversationStateSave();
    }
    return preparedRequest;
  }

  bool _isLocalAudioAttachment(AttachmentDto attachment) {
    final content = attachment.messageContent;
    if ('${content['type'] ?? ''}'.trim() != 'input_audio') {
      return false;
    }
    final inputAudio = content['input_audio'];
    return inputAudio is Map && inputAudio['local'] == true;
  }

  String _localAudioAttachmentPath(AttachmentDto attachment) {
    final inputAudio = attachment.messageContent['input_audio'];
    if (inputAudio is Map) {
      final path = '${inputAudio['url'] ?? ''}'.trim();
      if (path.isNotEmpty) {
        return path;
      }
    }
    return attachment.url.trim();
  }

  ConversationEntryDto _copyConversationEntryWithAttachments(
    ConversationEntryDto entry,
    List<AttachmentDto> attachments,
  ) {
    return ConversationEntryDto(
      id: entry.id,
      entryType: entry.entryType,
      role: entry.role,
      createdAt: entry.createdAt,
      sessionId: entry.sessionId,
      messageId: entry.messageId,
      messageType: entry.messageType,
      text: entry.text,
      attachments: List<AttachmentDto>.unmodifiable(attachments),
      isStreaming: entry.isStreaming,
      status: entry.status,
      toolCallId: entry.toolCallId,
      toolName: entry.toolName,
      toolArguments: entry.toolArguments,
      toolResult: entry.toolResult,
      durationMs: entry.durationMs,
      metadata: entry.metadata,
    );
  }

  Future<bool> _waitForPromptRunCompletion({
    required ChatPromptExecutionResult promptResult,
    required QueuedPromptState request,
    required int localRunId,
  }) async {
    final serverRunId = _normalizeRunId(promptResult.serverRunId);
    if (serverRunId.isEmpty) {
      return false;
    }
    final activeRun = ChatActiveRunRecord(
      localRunId: localRunId,
      serverRunId: serverRunId,
      sessionId: promptResult.sessionId,
      userMessageId: request.id,
      queuedPromptId: request.id,
      status: 'active',
      startedAt: DateTime.now(),
    );
    _chatSessionController.setActivePromptRunId(localRunId);
    _chatSessionController.setActiveRunRecord(activeRun);
    _chatSessionController.setProcessingPromptQueue(true);
    _schedulePersistedConversationStateSave();

    final completedResult = _completedRunResultByServerRunId.remove(
      serverRunId,
    );
    if (completedResult != null) {
      return completedResult;
    }

    final completer = Completer<bool>();
    _activeRunCompletionByServerRunId[serverRunId] = completer;
    return completer.future;
  }

  String _normalizeRunId(Object? value) => '${value ?? ''}'.trim();

  bool _shouldFlushPendingGuidanceAfterRun(int? runId) {
    return runId == null || !_runIdsWithoutPendingGuidanceFlush.contains(runId);
  }

  bool _eventMatchesActiveRun(String eventRunId, String eventSessionId) {
    final activeRun = _activeRunRecord;
    if (activeRun == null) {
      return false;
    }
    final activeServerRunId = _normalizeRunId(activeRun.serverRunId);
    if (activeServerRunId.isNotEmpty) {
      return eventRunId == activeServerRunId;
    }
    final activeSessionId = _normalizeRunId(activeRun.sessionId);
    return eventSessionId.isNotEmpty && eventSessionId == activeSessionId;
  }

  void _completeActiveRunFromSnapshot(String sessionId) {
    final activeRun = _activeRunRecord;
    final activeSessionId = _normalizeRunId(activeRun?.sessionId ?? _sessionId);
    if (activeRun == null || activeSessionId != sessionId) {
      _chatSessionController.setProcessingPromptQueue(false);
      _chatSessionController.setActivePromptRunId(null);
      return;
    }
    final serverRunId = _normalizeRunId(activeRun.serverRunId);
    if (serverRunId.isNotEmpty) {
      final completer = _activeRunCompletionByServerRunId.remove(serverRunId);
      if (completer != null && !completer.isCompleted) {
        completer.complete(true);
      } else {
        _completedRunResultByServerRunId[serverRunId] = true;
      }
    }
    _chatSessionController.setActiveRunRecord(null);
    _chatSessionController.setActivePromptRunId(null);
    _chatSessionController.setProcessingPromptQueue(false);
  }

  void _completeCurrentActiveRunLocally({required bool completed}) {
    final activeRun = _activeRunRecord;
    final serverRunId = _normalizeRunId(activeRun?.serverRunId);
    if (serverRunId.isNotEmpty) {
      final completer = _activeRunCompletionByServerRunId.remove(serverRunId);
      if (completer != null && !completer.isCompleted) {
        completer.complete(completed);
      } else {
        _completedRunResultByServerRunId[serverRunId] = completed;
      }
    }
    _chatSessionController.setActiveRunRecord(null);
    _chatSessionController.setActivePromptRunId(null);
  }

  void _applyRunLifecycleEvent(Map<String, dynamic> event, String eventType) {
    final serverRunId = _normalizeRunId(event['run_id']);
    final sessionId = _normalizeRunId(event['session_id']);
    if (serverRunId.isEmpty || !canApplyRealtimeConversationEvent(sessionId)) {
      return;
    }
    if (eventType == 'run_started') {
      final activeRun = _activeRunRecord;
      if (_eventMatchesActiveRun(serverRunId, sessionId) && activeRun != null) {
        _chatSessionController.setActiveRunRecord(
          activeRun.copyWith(status: 'active'),
        );
        _schedulePersistedConversationStateSave();
      }
      return;
    }
    if (eventType != 'run_completed' && eventType != 'run_stopped') {
      return;
    }
    final completed = eventType == 'run_completed';
    final completer = _activeRunCompletionByServerRunId.remove(serverRunId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(completed);
    } else {
      _completedRunResultByServerRunId[serverRunId] = completed;
    }
    if (!_eventMatchesActiveRun(serverRunId, sessionId)) {
      return;
    }
    final activeRun = _activeRunRecord;
    final wasInterruptingActivePrompt = _isInterruptingActivePrompt;
    final flushPendingGuidance = activeRun == null
        ? true
        : _shouldFlushPendingGuidanceAfterRun(activeRun.localRunId);
    _chatSessionController.setActiveRunRecord(null);
    _chatSessionController.setActivePromptRunId(null);
    _chatSessionController.setProcessingPromptQueue(false);
    _chatSessionController.setInterruptingActivePrompt(false);
    _mutateConversationSurface(() {
      _chatSessionController.settleStreamingConversationEntries();
    }, scrollToBottom: true);
    _schedulePersistedConversationStateSave();
    _notifyDockSurfaceChanged();
    if (!wasInterruptingActivePrompt) {
      _drainOrFlushPendingAfterCompletion(
        flushPendingGuidance: flushPendingGuidance,
      );
    }
  }

  void _applyConversationEvent(Map<String, dynamic> event) {
    if (!mounted) {
      return;
    }
    final eventType = '${event['type'] ?? ''}'.trim();
    if (eventType == 'run_started' ||
        eventType == 'run_completed' ||
        eventType == 'run_stopped') {
      _applyRunLifecycleEvent(event, eventType);
      return;
    }
    final itemValue = event['item'];
    final item = itemValue is Map<String, dynamic>
        ? itemValue
        : itemValue is Map
        ? Map<String, dynamic>.from(itemValue)
        : <String, dynamic>{};
    final entry = item.isEmpty ? null : ConversationEntryDto.fromJson(item);
    final guidanceId = entry?.role == 'user'
        ? '${entry?.metadata?['guidance_id'] ?? ''}'.trim()
        : '';
    _mutateConversationSurface(
      () {
        if (guidanceId.isNotEmpty) {
          _chatSessionController.removeQueuedPromptById(guidanceId);
        }
        _chatSessionController.applyConversationEvent(event);
      },
      scrollToBottom: true,
      persistConversation: false,
    );
    if (entry == null) {
      return;
    }
    if (!entry.isStreaming) {
      _schedulePersistedConversationStateSave();
    }
    if (isLingCalendarMutationToolResultEntry(entry)) {
      unawaited(widget.onCalendarMutationToolResult(entry));
    }
  }

  Future<void> _flushPendingGuidanceIfIdle() async {
    if (!_hasActivePromptRun && !_isProcessingPromptQueue) {
      await _flushPendingGuidanceAfterCompletionAsync();
    }
  }

  void _drainOrFlushPendingAfterCompletion({bool flushPendingGuidance = true}) {
    unawaited(
      _drainOrFlushPendingAfterCompletionAsync(
        flushPendingGuidance: flushPendingGuidance,
      ),
    );
  }

  Future<void> _drainOrFlushPendingAfterCompletionAsync({
    bool flushPendingGuidance = true,
  }) async {
    if (_isDrainingPendingPromptQueue) {
      return;
    }
    await _drainPendingPromptQueueAsync();
    if (flushPendingGuidance &&
        !_hasActivePromptRun &&
        !_isProcessingPromptQueue) {
      await _flushPendingGuidanceAfterCompletionAsync();
    }
  }

  bool _isPendingGuidanceStillSendable(LingPendingPromptRequest guidance) {
    return _isPendingGuidanceStillLocallyQueued(guidance);
  }

  bool _isPendingGuidanceStillLocallyQueued(LingPendingPromptRequest guidance) {
    return _pendingPromptQueue.any(
      (item) => item.isGuidance && item.id == guidance.id,
    );
  }

  List<LingPendingPromptRequest> _filterSendablePendingGuidances({
    required List<LingPendingPromptRequest> guidances,
  }) {
    return guidances
        .where(_isPendingGuidanceStillSendable)
        .toList(growable: false);
  }

  ({
    String prompt,
    List<LingConversationAttachment> attachments,
    Map<String, dynamic> metadata,
  })
  _buildPendingGuidanceSubmitPayload(List<LingPendingPromptRequest> guidances) {
    final hasVoiceTranscript = guidances.any(
      (item) => item.metadata['input_source'] == 'voice_transcript',
    );
    return (
      prompt: guidances
          .map((item) => item.text.trim())
          .where((text) => text.isNotEmpty)
          .join('\n\n'),
      attachments: <LingConversationAttachment>[
        for (final item in guidances) ...item.attachments,
      ],
      metadata: hasVoiceTranscript
          ? const <String, dynamic>{'input_source': 'voice_transcript'}
          : const <String, dynamic>{},
    );
  }

  Future<void> _flushPendingGuidanceAfterCompletionAsync() async {
    if (_isFlushingPendingGuidance || _hasActivePromptRun) {
      return;
    }
    final sessionId = _sessionId;
    if (sessionId == null || !widget.isAppInForeground) {
      return;
    }
    _isFlushingPendingGuidance = true;
    var pendingGuidances = <LingPendingPromptRequest>[];
    var consumedGuidances = <LingPendingPromptRequest>[];
    try {
      pendingGuidances = _pendingPromptQueue
          .where((item) => item.isGuidance)
          .toList(growable: false);
      pendingGuidances = _filterSendablePendingGuidances(
        guidances: pendingGuidances,
      );
      if (pendingGuidances.isEmpty) {
        return;
      }
      var payload = _buildPendingGuidanceSubmitPayload(pendingGuidances);
      if (payload.prompt.isEmpty && payload.attachments.isEmpty) {
        for (final guidance in pendingGuidances) {
          _chatSessionController.removeQueuedPromptById(guidance.id);
        }
        _notifyDockSurfaceChanged();
        return;
      }
      if (await _maybeBlockPromptSubmission(
        text: payload.prompt,
        attachments: payload.attachments,
      )) {
        return;
      }
      consumedGuidances = _filterSendablePendingGuidances(
        guidances: pendingGuidances,
      );
      if (consumedGuidances.isEmpty) {
        return;
      }
      payload = _buildPendingGuidanceSubmitPayload(consumedGuidances);
      if (payload.prompt.isEmpty && payload.attachments.isEmpty) {
        for (final guidance in consumedGuidances) {
          _chatSessionController.removeQueuedPromptById(guidance.id);
        }
        _notifyDockSurfaceChanged();
        return;
      }
      var removedAny = false;
      for (final guidance in consumedGuidances) {
        removedAny =
            _chatSessionController.removeQueuedPromptById(guidance.id) ||
            removedAny;
      }
      if (removedAny) {
        _notifyDockSurfaceChanged();
      }
      payload = _buildPendingGuidanceSubmitPayload(consumedGuidances);
      await _submitPrompt(
        payload.prompt,
        source: 'guidance',
        attachments: payload.attachments,
        skipLocalMembershipGate: true,
        skipQueueMembershipReadinessCheck: true,
        waitForCompletion: true,
        explicitScrollToLatest: false,
        inputMetadata: payload.metadata,
      );
    } catch (error) {
      _showError(error);
      if (consumedGuidances.isNotEmpty) {
        await _restorePendingGuidancesAfterAutoSend(
          guidances: consumedGuidances,
        );
      }
    } finally {
      _isFlushingPendingGuidance = false;
      _notifyDockSurfaceChanged();
    }
  }

  Future<void> _restorePendingGuidancesAfterAutoSend({
    required List<LingPendingPromptRequest> guidances,
  }) async {
    for (final guidance in guidances) {
      final alreadyQueued = _pendingPromptQueue.any(
        (item) => item.id == guidance.id,
      );
      if (!alreadyQueued) {
        _chatSessionController.enqueuePrompt(guidance.toState());
      }
    }
    _notifyDockSurfaceChanged();
  }

  Future<void> _startVoiceRecording() async {
    if (_isVoiceStartRequestInFlight || _isVoiceInteractionActive) {
      return;
    }
    _isVoiceStartRequestInFlight = true;
    _ignoreVoiceEventsUntilNextStart = false;
    try {
      if (!await _ensureMicrophonePermissionAuthorized()) {
        unawaited(
          _trackChatEvent(
            'chat.voice.start_failure',
            action: 'voice_start_failure',
            source: 'permission',
          ),
        );
        return;
      }
      _prepareVoiceComposerInsertionRange();
      await _chatVoiceOrchestrator.startRecording(
        isDockBusy: _isDockBusy,
        isVoiceInteractionActive: _isVoiceInteractionActive,
        platform: AppPlatformInfo.current,
        localeCode: widget.localeCode,
        unsupportedMessage: widget.strings.voiceUnsupported,
        closeKeyboardComposer: _closeKeyboardComposerForVoiceStart,
        updateVoiceState:
            ({
              bool? isStartingVoice,
              bool? isRecordingVoice,
              bool? isFinalizingVoice,
              bool? voiceStopRequested,
              String? voiceDraftTranscript,
              String? voiceDraftAudioPath,
              bool? voiceResultHandled,
            }) {
              _mutateDockSurface(() {
                _chatSessionController.updateVoiceState(
                  isStartingVoice: isStartingVoice,
                  isRecordingVoice: isRecordingVoice,
                  isFinalizingVoice: isFinalizingVoice,
                  voiceStopRequested: voiceStopRequested,
                  voiceDraftTranscript: voiceDraftTranscript,
                  voiceDraftAudioPath: voiceDraftAudioPath,
                  voiceResultHandled: voiceResultHandled,
                );
              });
            },
        setPendingVoiceDraftTranscript:
            _chatRuntime.setPendingVoiceDraftTranscript,
        stopVoiceRecognitionAfterStart: _stopVoiceRecognitionAfterStart,
        resetVoiceState: _resetVoiceState,
        showError: _handleVoiceStartError,
        showMessage: _showMessage,
      );
      unawaited(
        _trackChatEvent(
          'chat.voice.start_success',
          action: 'voice_start_success',
        ),
      );
    } finally {
      _isVoiceStartRequestInFlight = false;
    }
  }

  Future<bool> _ensureMicrophonePermissionAuthorized() async {
    final authorization = await _chatPresentationSupport
        .getMicrophoneAuthorizationState();
    switch (authorization) {
      case ChatSpeechAuthorizationState.granted:
        return true;
      case ChatSpeechAuthorizationState.unsupported:
        _showMessage(widget.strings.voiceUnsupported);
        return false;
      case ChatSpeechAuthorizationState.restricted:
        _showMessage(widget.strings.voicePermissionRestrictedMessage);
        return false;
      case ChatSpeechAuthorizationState.denied:
        await _promptVoicePermissionSettings();
        return false;
      case ChatSpeechAuthorizationState.unknown:
      case ChatSpeechAuthorizationState.notDetermined:
        return true;
    }
  }

  Future<void> _promptVoicePermissionSettings() async {
    if (!mounted) {
      return;
    }
    final confirmed = await showLingAdaptiveConfirmationDialog(
      context: context,
      title: widget.strings.voicePermissionRequiredTitle,
      message: widget.strings.voicePermissionRequiredMessage,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      confirmLabel: widget.strings.openSystemSettings,
    );
    if (confirmed == true) {
      await _chatPresentationSupport.openMicrophoneSystemSettings();
    }
  }

  void _handleVoiceStartError(Object error) {
    if (error is ApiException) {
      _showMessage(widget.strings.voiceRecognitionErrorMessage);
      return;
    }
    if (error is PlatformException) {
      switch (error.code) {
        case 'microphone_denied':
          unawaited(_promptVoicePermissionSettings());
          return;
        case 'microphone_unavailable':
        case 'locale_unsupported':
          _showMessage(widget.strings.voicePermissionRestrictedMessage);
          return;
        case 'asr_unconfigured':
        case 'asr_error':
          _showMessage(widget.strings.voiceRecognitionErrorMessage);
          return;
      }
      _showMessage(widget.strings.voiceRecognitionErrorMessage);
      return;
    }
    _showError(error);
  }

  Future<void> _finishVoiceRecording() async {
    if (_isVoiceFinishRequestInFlight ||
        _voiceStopRequested ||
        (!_isStartingVoice && !_isRecordingVoice)) {
      return;
    }
    _isVoiceFinishRequestInFlight = true;
    try {
      await _chatVoiceOrchestrator.finishRecording(
        isStartingVoice: _isStartingVoice,
        isRecordingVoice: _isRecordingVoice,
        isFinalizingVoice: _isFinalizingVoice,
        voiceResultHandled: _voiceResultHandled,
        updateVoiceState:
            ({
              bool? isStartingVoice,
              bool? isRecordingVoice,
              bool? isFinalizingVoice,
              bool? voiceStopRequested,
              String? voiceDraftTranscript,
              String? voiceDraftAudioPath,
              bool? voiceResultHandled,
            }) {
              if (!mounted) {
                return;
              }
              _mutateDockSurface(() {
                _chatSessionController.updateVoiceState(
                  isStartingVoice: isStartingVoice,
                  isRecordingVoice: isRecordingVoice,
                  isFinalizingVoice: isFinalizingVoice,
                  voiceStopRequested: voiceStopRequested,
                  voiceDraftTranscript: voiceDraftTranscript,
                  voiceDraftAudioPath: voiceDraftAudioPath,
                  voiceResultHandled: voiceResultHandled,
                );
              });
            },
        resetVoiceState: _resetVoiceState,
        showError: _showError,
      );
      if (mounted && _isFinalizingVoice) {
        _scheduleVoiceFinalizeFallback();
      }
    } finally {
      _isVoiceFinishRequestInFlight = false;
    }
  }

  void _handleSpeechEvent(ChatSpeechEvent event) {
    if (!mounted) {
      return;
    }
    if (_ignoreVoiceEventsUntilNextStart) {
      return;
    }
    _chatVoiceOrchestrator.handleSpeechEvent(
      event: event,
      voiceResultHandled: _voiceResultHandled,
      isStartingVoice: _isStartingVoice,
      isRecordingVoice: _isRecordingVoice,
      isFinalizingVoice: _isFinalizingVoice,
      voiceDraftTranscript: _voiceDraftTranscript,
      pendingVoiceDraftTranscript: _chatRuntime.pendingVoiceDraftTranscript,
      updateVoiceState:
          ({
            bool? isStartingVoice,
            bool? isRecordingVoice,
            bool? isFinalizingVoice,
            bool? voiceStopRequested,
            String? voiceDraftTranscript,
            String? voiceDraftAudioPath,
            bool? voiceResultHandled,
          }) {
            _mutateDockSurface(() {
              _chatSessionController.updateVoiceState(
                isStartingVoice: isStartingVoice,
                isRecordingVoice: isRecordingVoice,
                isFinalizingVoice: isFinalizingVoice,
                voiceStopRequested: voiceStopRequested,
                voiceDraftTranscript: voiceDraftTranscript,
                voiceDraftAudioPath: voiceDraftAudioPath,
                voiceResultHandled: voiceResultHandled,
              );
            });
          },
      scheduleVoiceDraftTranscriptRefresh: _scheduleVoiceDraftTranscriptRefresh,
      scheduleVoiceFinalizeFallback: _scheduleVoiceFinalizeFallback,
      submitRecognizedVoiceTranscript: (transcript) {
        unawaited(_submitRecognizedVoiceTranscript(transcript));
      },
      resetVoiceState:
          ({bool clearTranscript = true, bool resetResultHandled = true}) {
            _resetVoiceState(
              clearTranscript: clearTranscript,
              resetResultHandled: resetResultHandled,
            );
          },
      showMessage: (_) {
        _showMessage(widget.strings.voiceRecognitionErrorMessage);
      },
    );
  }

  void _cancelVoiceUiTimers() {
    _voiceFinalizeFallbackTimer?.cancel();
    _voiceTranscriptUiTimer?.cancel();
    _voiceTranscriptUiTimer = null;
  }

  void _resetVoiceState({
    bool clearTranscript = true,
    bool resetResultHandled = true,
  }) {
    if (!mounted) {
      return;
    }
    _cancelVoiceUiTimers();
    _chatRuntime.setPendingVoiceDraftTranscript(null);
    if (clearTranscript) {
      _voiceComposerReplaceStart = null;
      _voiceComposerReplaceEnd = null;
      _voiceComposerCursorOffset = null;
    }
    _mutateDockSurface(() {
      _chatSessionController.updateVoiceState(
        isStartingVoice: false,
        isRecordingVoice: false,
        isFinalizingVoice: false,
        voiceStopRequested: false,
        voiceResultHandled: resetResultHandled ? false : _voiceResultHandled,
        voiceDraftTranscript: clearTranscript ? '' : _voiceDraftTranscript,
        voiceDraftAudioPath: clearTranscript ? '' : _voiceDraftAudioPath,
      );
    });
  }

  void _scheduleVoiceDraftTranscriptRefresh(String transcript) {
    final normalizedTranscript = transcript.trim();
    if (!mounted || normalizedTranscript.isEmpty) {
      return;
    }
    _chatRuntime.setPendingVoiceDraftTranscript(normalizedTranscript);
    if (_voiceTranscriptUiTimer != null) {
      return;
    }
    _voiceTranscriptUiTimer = Timer(_voiceTranscriptRefreshDelay, () {
      _voiceTranscriptUiTimer = null;
      final nextTranscript = (_chatRuntime.pendingVoiceDraftTranscript ?? '')
          .trim();
      _chatRuntime.setPendingVoiceDraftTranscript(null);
      if (!mounted ||
          nextTranscript.isEmpty ||
          nextTranscript == _voiceDraftTranscript) {
        return;
      }
      final appliedTranscript = _applyVoiceTranscriptToComposer(nextTranscript);
      _mutateDockSurface(() {
        _chatSessionController.updateVoiceState(
          voiceDraftTranscript: appliedTranscript ?? nextTranscript,
        );
      });
    });
    _notifyDockSurfaceChanged(scrollToBottom: true);
  }

  void _scheduleVoiceFinalizeFallback() {
    _voiceFinalizeFallbackTimer?.cancel();
    _voiceFinalizeFallbackTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted || _voiceResultHandled || !_isFinalizingVoice) {
        return;
      }
      unawaited(
        _submitRecognizedVoiceTranscript(
          (_chatRuntime.pendingVoiceDraftTranscript ?? _voiceDraftTranscript)
              .trim(),
        ),
      );
    });
  }

  Future<void> _submitRecognizedVoiceTranscript(String transcript) async {
    final previousVoiceDraftTranscript = _voiceDraftTranscript;
    final voiceAudioPath = _voiceDraftAudioPath.trim();
    var queuedWhileAgentReplying = false;
    await _chatVoiceOrchestrator.submitRecognizedTranscript(
      transcript: transcript,
      voiceResultHandled: _voiceResultHandled,
      voiceDraftTranscript: previousVoiceDraftTranscript,
      pendingVoiceDraftTranscript: _chatRuntime.pendingVoiceDraftTranscript,
      updateVoiceState:
          ({
            bool? isStartingVoice,
            bool? isRecordingVoice,
            bool? isFinalizingVoice,
            bool? voiceStopRequested,
            String? voiceDraftTranscript,
            String? voiceDraftAudioPath,
            bool? voiceResultHandled,
          }) {
            _chatSessionController.updateVoiceState(
              isStartingVoice: isStartingVoice,
              isRecordingVoice: isRecordingVoice,
              isFinalizingVoice: isFinalizingVoice,
              voiceStopRequested: voiceStopRequested,
              voiceDraftTranscript: voiceDraftTranscript,
              voiceDraftAudioPath: voiceDraftAudioPath,
              voiceResultHandled: voiceResultHandled,
            );
          },
      cancelVoiceUiTimers: _cancelVoiceUiTimers,
      setPendingVoiceDraftTranscript:
          _chatRuntime.setPendingVoiceDraftTranscript,
      resetVoiceState:
          ({bool clearTranscript = true, bool resetResultHandled = true}) {
            _resetVoiceState(
              clearTranscript: clearTranscript,
              resetResultHandled: resetResultHandled,
            );
          },
      applyRecognizedTranscript: (prompt) async {
        if (_hasActivePromptRun) {
          final wrappedPrompt = _wrapActiveQuickPromptInput(prompt);
          final attachments = List<LingConversationAttachment>.from(
            _pendingComposerAttachments,
          );
          final voiceAttachment = _buildLocalVoiceDraftAttachment(
            voiceAudioPath,
          );
          if (voiceAttachment != null) {
            attachments.add(voiceAttachment);
          }
          await _injectPendingGuidance(
            wrappedPrompt.agentText,
            source: 'voice',
            displayText: wrappedPrompt.displayText,
            attachments: attachments,
          );
          _clearSubmittedVoiceDraftFromComposer(prompt);
          _mutateDockSurface(() {
            _chatSessionController.clearPendingComposerAttachments();
            _chatSessionController.clearPendingObjectReferences();
          });
          _showQuickPromptsAfterActiveIntentCancel = false;
          _clearActiveQuickPromptIntent(restoreQuickPrompts: false);
          queuedWhileAgentReplying = true;
          return;
        }
        final appliedTranscript = _applyVoiceTranscriptToComposerUpdate(prompt);
        if (appliedTranscript != null &&
            appliedTranscript.voiceTranscript != prompt) {
          _chatSessionController.updateVoiceState(
            voiceDraftTranscript: appliedTranscript.voiceTranscript,
          );
        }
        final submittedText = _composerController.userText.trim().isNotEmpty
            ? _composerController.userText.trim()
            : appliedTranscript?.composerText.trim() ?? prompt;
        await _submitKeyboardComposerText(userTextOverride: submittedText);
      },
    );
    if (queuedWhileAgentReplying) {
      _ignoreVoiceEventsUntilNextStart = true;
      _resetVoiceState(clearTranscript: true, resetResultHandled: true);
      _notifyDockSurfaceChanged(scrollToBottom: true);
    }
  }

  Future<void> _stopVoiceRecognitionAfterStart() async {
    unawaited(_trackChatEvent('chat.voice.stop', action: 'voice_stop'));
    await _chatVoiceOrchestrator.stopRecognitionAfterStart(
      voiceStopRequested: _voiceStopRequested,
      updateVoiceState:
          ({
            bool? isStartingVoice,
            bool? isRecordingVoice,
            bool? isFinalizingVoice,
            bool? voiceStopRequested,
            String? voiceDraftTranscript,
            String? voiceDraftAudioPath,
            bool? voiceResultHandled,
          }) {
            if (!mounted) {
              return;
            }
            _mutateDockSurface(() {
              _chatSessionController.updateVoiceState(
                isStartingVoice: isStartingVoice,
                isRecordingVoice: isRecordingVoice,
                isFinalizingVoice: isFinalizingVoice,
                voiceStopRequested: voiceStopRequested,
                voiceDraftTranscript: voiceDraftTranscript,
                voiceDraftAudioPath: voiceDraftAudioPath,
                voiceResultHandled: voiceResultHandled,
              );
            });
          },
    );
  }

  Future<void> _openAttachmentPreview(
    LingConversationAttachment attachment,
  ) async {
    if (!mounted) {
      return;
    }
    if (attachment.isAudio) {
      await _playVoiceDraftPreview(attachment.audioUrl);
      return;
    }
    await showLingConversationAttachmentPreview(
      context: context,
      attachment: attachment,
      downloadTooltip: widget.strings.downloadToLocal,
      onDownload: () => _saveConversationAttachmentsToLocal([attachment]),
    );
  }

  void _showError(Object error) {
    final message = switch (error) {
      ApiException(:final message) => message,
      PlatformException(:final message?) when message.trim().isNotEmpty =>
        message,
      _ => error.toString(),
    };
    if (!mounted) {
      return;
    }
    showLingTopNotice(context, message);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    showLingTopNotice(context, message);
  }

  Future<void> _trackChatEvent(
    String eventName, {
    required String action,
    String? source,
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    return ref
        .read(analyticsTrackerProvider)
        .track(
          eventName,
          surface: 'chat',
          action: action,
          source: source,
          locale: widget.localeCode,
          timezone: widget.timezone,
          properties: properties,
        );
  }

  Map<String, Object?> _promptAnalyticsProperties({
    required List<LingConversationAttachment> attachments,
    required bool queued,
    required bool interruptedActiveRun,
  }) {
    return <String, Object?>{
      'attachment_count': attachments.length,
      'attachment_types': attachments
          .map(_analyticsAttachmentType)
          .toSet()
          .toList(growable: false),
      'queued': queued,
      'interrupted_active_run': interruptedActiveRun,
    };
  }

  String _analyticsAttachmentType(LingConversationAttachment attachment) {
    if (attachment.isAudio) {
      return 'audio';
    }
    final contentType = '${attachment.messageContent['type'] ?? ''}'.trim();
    final filename = attachment.filename.toLowerCase();
    if (contentType.contains('image') ||
        filename.endsWith('.png') ||
        filename.endsWith('.jpg') ||
        filename.endsWith('.jpeg') ||
        filename.endsWith('.webp')) {
      return 'image';
    }
    return 'file';
  }

  Future<void> _copyConversationEntry(LingConversationEntry entry) async {
    if (!canCopyLingConversationEntry(entry)) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: buildLingConversationEntryCopyText(entry)),
    );
    if (!mounted) {
      return;
    }
    _showMessage(widget.strings.copied);
  }

  Future<void> _retryConversationEntry(LingConversationEntry entry) async {
    if (!canRetryLingConversationEntry(entry) ||
        _isHistoricalConversationEntry(entry.toDto())) {
      return;
    }
    final request = buildLingConversationRetryRequest(entry);
    await _submitPrompt(
      request.text,
      source: request.source,
      attachments: request.attachments,
    );
  }

  Future<void> _saveConversationAttachmentsToLocal(
    Iterable<LingConversationAttachment> attachments,
  ) async {
    try {
      final result = await _chatPresentationSupport
          .saveConversationAttachmentsToLocal(attachments);
      if (!mounted) {
        return;
      }
      switch (result.status) {
        case ChatConversationAttachmentSaveStatus.success:
          _showMessage(
            AppPlatformInfo.current == AppPlatform.ios
                ? widget.strings.savedToPhotos
                : widget.strings.savedToLocal,
          );
        case ChatConversationAttachmentSaveStatus.unsupported:
          _showMessage(widget.strings.saveUnsupported);
        case ChatConversationAttachmentSaveStatus.failed:
          _showMessage(widget.strings.saveFailed);
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        '[Ling][ChatSection] 保存附件到本地失败 '
        'error=$error stackTrace=$stackTrace',
      );
      _showMessage(widget.strings.saveFailed);
    }
  }
}
