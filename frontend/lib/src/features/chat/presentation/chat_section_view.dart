import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderProxyBox, ScrollCacheExtent, ScrollDirection;
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/chat/application/conversation_attachment.dart';
import 'package:ling/src/features/chat/application/conversation_entry.dart';
import 'package:ling/src/features/chat/application/object_reference.dart';
import 'package:ling/src/features/chat/presentation/bottom_dock.dart';
import 'package:ling/src/features/chat/presentation/chat_shell.dart';
import 'package:ling/src/features/chat/presentation/conversation_empty_state_view.dart';
import 'package:ling/src/features/chat/presentation/conversation_entry_view.dart';
import 'package:ling/src/features/chat/presentation/conversation_viewport.dart';
import 'package:ling/src/features/chat/presentation/object_reference_editing_controller.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/font_size_preference.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/shared_controls.dart';

String _chatSectionComposerUserText(TextEditingController controller) {
  return controller is LingObjectReferenceEditingController
      ? controller.userText
      : controller.text;
}

class LingChatSectionViewData {
  const LingChatSectionViewData({
    required this.isConversationEmpty,
    required this.renderedConversationItems,
    required this.showContextSummaryInConversationList,
    this.isLoadingOlderConversationEntries = false,
    this.isPagingOlderConversationEntries = false,
    this.transientConversationEntryKeys = const <String>{},
    required this.hasOlderConversationEntries,
    required this.hiddenConversationEntryCount,
    required this.isDockBusy,
    this.isConversationRestoring = false,
    required this.dockBusyLabel,
    required this.queuedCount,
    required this.queuedLabel,
    required this.queuedPreviewText,
    required this.queuedOverflowCount,
    required this.isRecording,
    required this.isFinalizingVoice,
    required this.isVoiceActive,
    required this.hasVoiceDraftReview,
    required this.voiceDraftTranscript,
    required this.voiceDraftAudioPath,
    required this.isAgentReplying,
    required this.isInterruptingAgentReply,
    required this.isKeyboardComposerOpen,
    required this.isInputPanelExpanded,
    this.preferVoiceInput = false,
    required this.composerController,
    required this.composerFocusNode,
    required this.composerScrollController,
    this.composerCursorPreviewOffset,
    required this.composerPlaceholder,
    this.quickPrompts = const <String>[],
    this.activeQuickPromptLabel,
    this.activeQuickPromptHint,
    this.starterTasks = const <LingConversationStarterTask>[],
    this.forceQuickPromptsVisible = false,
    this.keepQuickPromptsVisibleWithText = false,
    required this.pendingAttachments,
    this.pendingObjectReferences = const <LingObjectReference>[],
    required this.canVoiceTap,
    required this.voiceTooltip,
    required this.addImageTooltip,
    required this.keyboardTooltip,
    required this.photoLibraryTooltip,
    required this.cameraTooltip,
    required this.sendMessageTooltip,
    required this.stopAgentReplyTooltip,
    required this.deleteQueuedMessageTooltip,
    required this.applyQueuedMessageNowTooltip,
    required this.editQueuedMessageTooltip,
    required this.hasUnreadCalendarBadge,
    required this.showScrollToBottomButton,
    required this.strings,
    required this.fontSizeLevel,
    required this.conversationScrollController,
    this.currentSessionId,
    this.contextSummary,
  });

  final bool isConversationEmpty;
  final List<LingConversationRenderItem> renderedConversationItems;
  final bool showContextSummaryInConversationList;
  final bool isLoadingOlderConversationEntries;
  final bool isPagingOlderConversationEntries;
  final Set<String> transientConversationEntryKeys;
  final bool hasOlderConversationEntries;
  final int hiddenConversationEntryCount;
  final bool isDockBusy;
  final bool isConversationRestoring;
  final String dockBusyLabel;
  final int queuedCount;
  final String? queuedLabel;
  final String? queuedPreviewText;
  final int queuedOverflowCount;
  final bool isRecording;
  final bool isFinalizingVoice;
  final bool isVoiceActive;
  final bool hasVoiceDraftReview;
  final String voiceDraftTranscript;
  final String voiceDraftAudioPath;
  final bool isAgentReplying;
  final bool isInterruptingAgentReply;
  final bool isKeyboardComposerOpen;
  final bool isInputPanelExpanded;
  final bool preferVoiceInput;
  final TextEditingController composerController;
  final FocusNode composerFocusNode;
  final ScrollController composerScrollController;
  final int? composerCursorPreviewOffset;
  final String composerPlaceholder;
  final List<String> quickPrompts;
  final String? activeQuickPromptLabel;
  final String? activeQuickPromptHint;
  final List<LingConversationStarterTask> starterTasks;
  final bool forceQuickPromptsVisible;
  final bool keepQuickPromptsVisibleWithText;
  final List<LingConversationAttachment> pendingAttachments;
  final List<LingObjectReference> pendingObjectReferences;
  final bool canVoiceTap;
  final String voiceTooltip;
  final String addImageTooltip;
  final String keyboardTooltip;
  final String photoLibraryTooltip;
  final String cameraTooltip;
  final String sendMessageTooltip;
  final String stopAgentReplyTooltip;
  final String deleteQueuedMessageTooltip;
  final String applyQueuedMessageNowTooltip;
  final String editQueuedMessageTooltip;
  final bool hasUnreadCalendarBadge;
  final bool showScrollToBottomButton;
  final LingStrings strings;
  final LingFontSizeLevel fontSizeLevel;
  final ScrollController conversationScrollController;
  final String? currentSessionId;
  final String? contextSummary;
}

class LingChatSectionViewCallbacks {
  const LingChatSectionViewCallbacks({
    required this.onConversationBackgroundTap,
    this.onConversationUserScroll,
    required this.onLoadMoreConversationEntries,
    required this.onPreviewAttachment,
    required this.onOpenLingEvent,
    required this.onCopyEntry,
    required this.onRetryEntry,
    this.onActionPrompt,
    this.onLingAction,
    this.onQuestionnaireSubmit,
    required this.onExpandInputPanel,
    required this.onCollapseInputPanel,
    required this.onVoiceTap,
    required this.onAddImageTap,
    required this.onKeyboardTap,
    required this.onDismissKeyboardTap,
    required this.onPhotoLibraryTap,
    required this.onCameraTap,
    required this.onRemoveAttachment,
    required this.onReorderAttachments,
    required this.onViewQueuedMessages,
    required this.onDeleteQueuedMessage,
    required this.onApplyQueuedMessageNow,
    required this.onEditQueuedMessage,
    required this.onCancelVoiceDraft,
    required this.onPlayVoiceDraftPreview,
    required this.onLoadVoiceDraftPreviewDuration,
    required this.onStopVoiceDraftPreview,
    required this.onStopAgentReply,
    required this.onScrollToBottom,
    this.onQuickPromptTap,
    this.onQuickPromptRefresh,
    this.onCancelActiveQuickPrompt,
    this.onRemoveObjectReference,
    required this.onSubmitText,
    required this.onAvatarTap,
    required this.onCalendarTap,
  });

  final VoidCallback onConversationBackgroundTap;
  final VoidCallback? onConversationUserScroll;
  final void Function(LingConversationScrollAnchor? anchor)
  onLoadMoreConversationEntries;
  final ValueChanged<LingConversationAttachment> onPreviewAttachment;
  final ValueChanged<String> onOpenLingEvent;
  final Future<void> Function(LingConversationEntry entry) onCopyEntry;
  final Future<void> Function(LingConversationEntry entry) onRetryEntry;
  final ValueChanged<String>? onActionPrompt;
  final ValueChanged<LingChatAction>? onLingAction;
  final FutureOr<void> Function(LingQuestionnaireSubmission submission)?
  onQuestionnaireSubmit;
  final VoidCallback onExpandInputPanel;
  final VoidCallback onCollapseInputPanel;
  final VoidCallback onVoiceTap;
  final VoidCallback onAddImageTap;
  final VoidCallback onKeyboardTap;
  final VoidCallback onDismissKeyboardTap;
  final VoidCallback onPhotoLibraryTap;
  final VoidCallback onCameraTap;
  final ValueChanged<LingConversationAttachment> onRemoveAttachment;
  final ValueChanged<List<LingConversationAttachment>> onReorderAttachments;
  final VoidCallback onViewQueuedMessages;
  final VoidCallback onDeleteQueuedMessage;
  final VoidCallback onApplyQueuedMessageNow;
  final VoidCallback onEditQueuedMessage;
  final VoidCallback onCancelVoiceDraft;
  final Future<Duration> Function(String path) onPlayVoiceDraftPreview;
  final Future<Duration> Function(String path) onLoadVoiceDraftPreviewDuration;
  final FutureOr<void> Function() onStopVoiceDraftPreview;
  final VoidCallback onStopAgentReply;
  final VoidCallback onScrollToBottom;
  final ValueChanged<String>? onQuickPromptTap;
  final FutureOr<void> Function()? onQuickPromptRefresh;
  final VoidCallback? onCancelActiveQuickPrompt;
  final ValueChanged<LingObjectReference>? onRemoveObjectReference;
  final VoidCallback onSubmitText;
  final VoidCallback onAvatarTap;
  final VoidCallback onCalendarTap;
}

class LingConversationScrollAnchor {
  const LingConversationScrollAnchor({
    required this.itemId,
    required this.itemKey,
    required this.globalDy,
  });

  final String itemId;
  final GlobalKey itemKey;
  final double globalDy;
}

class LingChatSectionView extends StatefulWidget {
  const LingChatSectionView({
    super.key,
    required this.data,
    required this.callbacks,
  });

  final LingChatSectionViewData data;
  final LingChatSectionViewCallbacks callbacks;

  @override
  State<LingChatSectionView> createState() => _LingChatSectionViewState();
}

class _LingChatSectionViewState extends State<LingChatSectionView> {
  static const double _composerFontSize = 17;
  static const double _composerHeightMultiplier = 1.12;
  static const double _composerVerticalPadding = 26;
  static const double _attachmentDrawerHeight = 96;
  static const double _attachmentDrawerDockGap = 8;
  static const double _conversationActionReserveHeight = 34;
  static const double _measuredBottomDockClearance = 8;
  static const double _bottomSnapThreshold = 32;
  static const int _composerMaxLines = 10;
  static const int _collapsedComposerMinLines = 1;
  static const double _collapsedDockHeight = 64;
  final GlobalKey _currentConversationSliverKey = GlobalKey();
  final GlobalKey _loadMoreButtonMeasureKey = GlobalKey();
  final Map<String, GlobalKey> _conversationItemMeasureKeys =
      <String, GlobalKey>{};
  double? _measuredBottomDockHeight;
  double? _measuredBottomDockInset;
  double? _lastBottomDockBuildInset;

  LingChatSectionViewData get data => widget.data;
  LingChatSectionViewCallbacks get callbacks => widget.callbacks;

  @override
  void didUpdateWidget(covariant LingChatSectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pruneConversationItemMeasureKeys();
  }

  @override
  Widget build(BuildContext context) {
    _pruneConversationItemMeasureKeys();
    final bottomContentInset = _resolveConversationBottomContentInset(context);
    _lastBottomDockBuildInset = _resolveBottomInset(context);
    final useCenteredHistoryLayout =
        data.hasOlderConversationEntries ||
        data.transientConversationEntryKeys.isNotEmpty;
    final showEmptyConversationLoading =
        data.isConversationEmpty &&
        !data.hasOlderConversationEntries &&
        (data.isConversationRestoring ||
            data.isLoadingOlderConversationEntries);

    return LingCalendarChatShell(
      conversationList: NotificationListener<UserScrollNotification>(
        onNotification: _handleConversationUserScrollNotification,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: data.isConversationEmpty && !data.hasOlderConversationEntries
              ? GestureDetector(
                  key: const ValueKey('conversation_empty_state_layer'),
                  behavior: HitTestBehavior.opaque,
                  onTap: callbacks.onConversationBackgroundTap,
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          LingCalendarChatShell.topContentInset,
                          20,
                          bottomContentInset,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: LingCalendarConversationEmptyStateView(
                                welcomeLead: data.strings.emptyConversationLead,
                                welcomeBrand:
                                    data.strings.emptyConversationBrand,
                                description:
                                    data.strings.emptyConversationDescription,
                                contextSummary: data.contextSummary,
                                starterTasks: data.starterTasks,
                                onStarterTaskTap: callbacks.onQuickPromptTap,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showEmptyConversationLoading)
                        const Positioned(
                          top: LingCalendarChatShell.topContentInset,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: _ConversationHistoryLoadingIndicator(),
                          ),
                        ),
                    ],
                  ),
                )
              : GestureDetector(
                  key: const ValueKey('conversation_items'),
                  behavior: HitTestBehavior.opaque,
                  onTap: callbacks.onConversationBackgroundTap,
                  child: Stack(
                    children: [
                      useCenteredHistoryLayout
                          ? CustomScrollView(
                              controller: data.conversationScrollController,
                              scrollCacheExtent: const ScrollCacheExtent.pixels(
                                520,
                              ),
                              center: _currentConversationSliverKey,
                              slivers: [
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    LingCalendarChatShell.topContentInset,
                                    20,
                                    0,
                                  ),
                                  sliver: SliverList(
                                    delegate:
                                        _buildOlderConversationSliverDelegate(),
                                  ),
                                ),
                                SliverPadding(
                                  key: _currentConversationSliverKey,
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    0,
                                  ).copyWith(bottom: bottomContentInset),
                                  sliver: SliverList(
                                    delegate:
                                        _buildCurrentConversationSliverDelegate(),
                                  ),
                                ),
                              ],
                            )
                          : CustomScrollView(
                              controller: data.conversationScrollController,
                              scrollCacheExtent: const ScrollCacheExtent.pixels(
                                520,
                              ),
                              slivers: [
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                    20,
                                    LingCalendarChatShell.topContentInset,
                                    20,
                                    bottomContentInset,
                                  ),
                                  sliver: SliverList(
                                    delegate:
                                        _buildCurrentConversationSliverDelegate(),
                                  ),
                                ),
                              ],
                            ),
                      if (data.isLoadingOlderConversationEntries)
                        const Positioned(
                          top: LingCalendarChatShell.topContentInset,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: _ConversationHistoryLoadingIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
      bottomOverlay: null,
      bottomFloatingControl: data.showScrollToBottomButton
          ? _ScrollToBottomButton(
              onPressed: callbacks.onScrollToBottom,
              semanticLabel: data.strings.scrollToBottom,
            )
          : null,
      bottomFloatingControlOffset: _resolveScrollToBottomButtonOffset(context),
      onBottomOverlayDismissed: callbacks.onConversationBackgroundTap,
      bottomDock: _MeasureSize(
        onChange: _handleBottomDockSizeChanged,
        child: RepaintBoundary(
          child: LingCalendarBottomDock(
            isBusy: data.isDockBusy,
            isConversationRestoring: data.isConversationRestoring,
            busyLabel: data.dockBusyLabel,
            queuedCount: data.queuedCount,
            queuedLabel: data.queuedLabel,
            queuedPreviewText: data.queuedPreviewText,
            queuedOverflowCount: data.queuedOverflowCount,
            isRecording: data.isRecording,
            isFinalizingVoice: data.isFinalizingVoice,
            isVoiceActive: data.isVoiceActive,
            hasVoiceDraftReview: data.hasVoiceDraftReview,
            voiceDraftTranscript: data.voiceDraftTranscript,
            voiceDraftAudioPath: data.voiceDraftAudioPath,
            isAgentReplying: data.isAgentReplying,
            isInterruptingAgentReply: data.isInterruptingAgentReply,
            isKeyboardComposerOpen: data.isKeyboardComposerOpen,
            isExpanded: data.isInputPanelExpanded,
            preferVoiceInput: data.preferVoiceInput,
            composerController: data.composerController,
            composerFocusNode: data.composerFocusNode,
            composerScrollController: data.composerScrollController,
            composerCursorPreviewOffset: data.composerCursorPreviewOffset,
            composerPlaceholder: data.composerPlaceholder,
            quickPrompts: data.quickPrompts,
            activeQuickPromptLabel: data.activeQuickPromptLabel,
            activeQuickPromptHint: data.activeQuickPromptHint,
            forceQuickPromptsVisible: data.forceQuickPromptsVisible,
            keepQuickPromptsVisibleWithText:
                data.keepQuickPromptsVisibleWithText,
            pendingAttachments: data.pendingAttachments,
            pendingObjectReferences: data.pendingObjectReferences,
            canVoiceTap: data.canVoiceTap,
            voiceTooltip: data.voiceTooltip,
            addImageTooltip: data.addImageTooltip,
            keyboardTooltip: data.keyboardTooltip,
            photoLibraryTooltip: data.photoLibraryTooltip,
            cameraTooltip: data.cameraTooltip,
            sendMessageTooltip: data.sendMessageTooltip,
            stopAgentReplyTooltip: data.stopAgentReplyTooltip,
            onExpand: callbacks.onExpandInputPanel,
            onCollapse: callbacks.onCollapseInputPanel,
            onVoiceTap: callbacks.onVoiceTap,
            onAddImageTap: callbacks.onAddImageTap,
            onKeyboardTap: callbacks.onKeyboardTap,
            onDismissKeyboardTap: callbacks.onDismissKeyboardTap,
            onPhotoLibraryTap: callbacks.onPhotoLibraryTap,
            onCameraTap: callbacks.onCameraTap,
            onRemoveAttachment: callbacks.onRemoveAttachment,
            onPreviewAttachment: callbacks.onPreviewAttachment,
            onReorderAttachments: callbacks.onReorderAttachments,
            deleteQueuedMessageTooltip: data.deleteQueuedMessageTooltip,
            applyQueuedMessageNowTooltip: data.applyQueuedMessageNowTooltip,
            editQueuedMessageTooltip: data.editQueuedMessageTooltip,
            onViewQueuedMessages: callbacks.onViewQueuedMessages,
            onDeleteQueuedMessage: callbacks.onDeleteQueuedMessage,
            onApplyQueuedMessageNow: callbacks.onApplyQueuedMessageNow,
            onEditQueuedMessage: callbacks.onEditQueuedMessage,
            onCancelVoiceDraft: callbacks.onCancelVoiceDraft,
            onPlayVoiceDraftPreview: callbacks.onPlayVoiceDraftPreview,
            onLoadVoiceDraftPreviewDuration:
                callbacks.onLoadVoiceDraftPreviewDuration,
            onStopVoiceDraftPreview: callbacks.onStopVoiceDraftPreview,
            onStopAgentReply: callbacks.onStopAgentReply,
            onQuickPromptTap: callbacks.onQuickPromptTap,
            onQuickPromptRefresh: callbacks.onQuickPromptRefresh,
            onCancelActiveQuickPrompt: callbacks.onCancelActiveQuickPrompt,
            onRemoveObjectReference: callbacks.onRemoveObjectReference,
            onSubmitText: callbacks.onSubmitText,
          ),
        ),
      ),
      onAvatarTap: callbacks.onAvatarTap,
      onCalendarTap: callbacks.onCalendarTap,
      hasUnreadCalendarBadge: data.hasUnreadCalendarBadge,
    );
  }

  bool _handleConversationUserScrollNotification(
    UserScrollNotification notification,
  ) {
    if (notification.direction != ScrollDirection.idle) {
      callbacks.onConversationUserScroll?.call();
    }
    return false;
  }

  GlobalKey _measureKeyForConversationItem(String itemId) {
    return _conversationItemMeasureKeys.putIfAbsent(itemId, GlobalKey.new);
  }

  SliverChildDelegate _buildOlderConversationSliverDelegate() {
    if (!_hasCurrentConversationSliverChildren) {
      return SliverChildBuilderDelegate((_, _) => null, childCount: 0);
    }
    final olderItems = data.renderedConversationItems
        .where(_isTransientConversationRenderItem)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    final buttonCount = data.hasOlderConversationEntries ? 1 : 0;
    final latestAssistantActionEntryId = _resolveLatestAssistantActionEntryId(
      data.renderedConversationItems,
      currentSessionId: data.currentSessionId,
    );
    final questionnaireResponses = _resolveQuestionnaireResponses(
      data.renderedConversationItems,
    );
    return SliverChildBuilderDelegate((context, index) {
      if (data.hasOlderConversationEntries && index == olderItems.length) {
        return _buildLoadMoreButton();
      }
      return _buildConversationRenderItem(
        olderItems[index],
        latestAssistantActionEntryId: latestAssistantActionEntryId,
        questionnaireResponses: questionnaireResponses,
      );
    }, childCount: buttonCount + olderItems.length);
  }

  SliverChildDelegate _buildCurrentConversationSliverDelegate() {
    if (!_hasCurrentConversationSliverChildren) {
      return _buildEmptyCurrentConversationSliverDelegate();
    }
    final currentItems = data.renderedConversationItems
        .where((item) => !_isTransientConversationRenderItem(item))
        .toList(growable: false);
    final contextDigestCount = data.showContextSummaryInConversationList
        ? 1
        : 0;
    final starterTasksCount = _shouldShowStarterTasksInConversationList ? 1 : 0;
    final starterTaskInsertIndex = starterTasksCount == 0
        ? -1
        : _starterTaskInsertIndex(currentItems);
    final latestAssistantActionEntryId = _resolveLatestAssistantActionEntryId(
      data.renderedConversationItems,
      currentSessionId: data.currentSessionId,
    );
    final questionnaireResponses = _resolveQuestionnaireResponses(
      data.renderedConversationItems,
    );
    return SliverChildBuilderDelegate(
      (context, index) {
        if (data.showContextSummaryInConversationList && index == 0) {
          return _ConversationContextDigestStrip(summary: data.contextSummary);
        }
        final currentItemIndex = index - contextDigestCount;
        if (starterTaskInsertIndex >= 0 &&
            currentItemIndex == starterTaskInsertIndex) {
          return _buildStarterTasksInConversationList();
        }
        final adjustedItemIndex =
            starterTaskInsertIndex >= 0 &&
                currentItemIndex > starterTaskInsertIndex
            ? currentItemIndex - 1
            : currentItemIndex;
        if (adjustedItemIndex < currentItems.length) {
          return _buildConversationRenderItem(
            currentItems[adjustedItemIndex],
            latestAssistantActionEntryId: latestAssistantActionEntryId,
            questionnaireResponses: questionnaireResponses,
          );
        }
        return _buildStarterTasksInConversationList();
      },
      childCount: contextDigestCount + currentItems.length + starterTasksCount,
    );
  }

  int _starterTaskInsertIndex(List<LingConversationRenderItem> currentItems) {
    return currentItems.length;
  }

  Widget _buildStarterTasksInConversationList() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LingConversationStarterTaskList(
        starterTasks: data.starterTasks,
        onStarterTaskTap: (prompt) => callbacks.onQuickPromptTap?.call(prompt),
      ),
    );
  }

  SliverChildDelegate _buildEmptyCurrentConversationSliverDelegate() {
    final buttonCount = data.hasOlderConversationEntries ? 1 : 0;
    final latestAssistantActionEntryId = _resolveLatestAssistantActionEntryId(
      data.renderedConversationItems,
      currentSessionId: data.currentSessionId,
    );
    final questionnaireResponses = _resolveQuestionnaireResponses(
      data.renderedConversationItems,
    );
    return SliverChildBuilderDelegate((context, index) {
      if (data.hasOlderConversationEntries && index == 0) {
        return _buildLoadMoreButton();
      }
      return _buildConversationRenderItem(
        data.renderedConversationItems[index - buttonCount],
        latestAssistantActionEntryId: latestAssistantActionEntryId,
        questionnaireResponses: questionnaireResponses,
      );
    }, childCount: buttonCount + data.renderedConversationItems.length);
  }

  Widget _buildLoadMoreButton() {
    return KeyedSubtree(
      key: _loadMoreButtonMeasureKey,
      child: _ConversationHistoryLoadMoreButton(
        label: data.strings.loadMoreConversationEntries,
        onPressed:
            data.isLoadingOlderConversationEntries ||
                data.isPagingOlderConversationEntries
            ? null
            : () => callbacks.onLoadMoreConversationEntries(
                _captureConversationScrollAnchor(),
              ),
      ),
    );
  }

  bool get _hasCurrentConversationSliverChildren {
    if (data.showContextSummaryInConversationList ||
        _shouldShowStarterTasksInConversationList) {
      return true;
    }
    return data.renderedConversationItems.any(
      (item) => !_isTransientConversationRenderItem(item),
    );
  }

  Widget _buildConversationRenderItem(
    LingConversationRenderItem item, {
    required String? latestAssistantActionEntryId,
    required Map<String, LingQuestionnaireResponse> questionnaireResponses,
  }) {
    if (item.isTimestamp) {
      return KeyedSubtree(
        key: ValueKey(item.id),
        child: RepaintBoundary(
          child: LingConversationStartedAtLabel(
            strings: data.strings,
            startedAt: item.timestamp!,
          ),
        ),
      );
    }
    if (item.isToolFlow) {
      return KeyedSubtree(
        key: ValueKey(item.id),
        child: KeyedSubtree(
          key: _measureKeyForConversationItem(item.id),
          child: RepaintBoundary(
            child: SelectionArea(
              child: LingToolFlowGroupView(
                group: item.toolFlowGroup!,
                strings: data.strings,
                onOpenLingEvent: callbacks.onOpenLingEvent,
              ),
            ),
          ),
        ),
      );
    }
    final entry = item.entry!;
    final isHistoricalEntry = _isHistoricalConversationEntry(
      entry,
      currentSessionId: data.currentSessionId,
    );
    final canShowAssistantActions =
        !isHistoricalEntry && entry.id == latestAssistantActionEntryId;
    final canSubmitQuestionnaire = canShowAssistantActions && !data.isDockBusy;
    return KeyedSubtree(
      key: ValueKey(item.id),
      child: KeyedSubtree(
        key: _measureKeyForConversationItem(item.id),
        child: RepaintBoundary(
          child: SelectionArea(
            child: LingConversationEntryView(
              entry: entry,
              strings: data.strings,
              fontSizeLevel: data.fontSizeLevel,
              onPreviewAttachment: callbacks.onPreviewAttachment,
              onPlayAudioPreview: callbacks.onPlayVoiceDraftPreview,
              onLoadAudioPreviewDuration:
                  callbacks.onLoadVoiceDraftPreviewDuration,
              onStopAudioPreview: callbacks.onStopVoiceDraftPreview,
              onOpenLingEvent: callbacks.onOpenLingEvent,
              onCopyEntry: callbacks.onCopyEntry,
              onRetryEntry: isHistoricalEntry ? null : callbacks.onRetryEntry,
              onActionPrompt: canShowAssistantActions
                  ? callbacks.onActionPrompt
                  : null,
              onLingAction: canShowAssistantActions
                  ? callbacks.onLingAction
                  : null,
              onQuestionnaireSubmit: canSubmitQuestionnaire
                  ? callbacks.onQuestionnaireSubmit
                  : null,
              questionnaireResponses: questionnaireResponses,
              canSubmitQuestionnaire: canSubmitQuestionnaire,
            ),
          ),
        ),
      ),
    );
  }

  bool _isTransientConversationRenderItem(LingConversationRenderItem item) {
    if (item.isEntry) {
      return _isTransientConversationEntry(item.entry!);
    }
    if (item.isToolFlow) {
      final entries = item.toolFlowGroup!.entries;
      return entries.isNotEmpty && entries.every(_isTransientConversationEntry);
    }
    if (item.isTimestamp) {
      const prefix = 'timestamp_';
      final sourceEntryId = item.sourceEntryId;
      if (sourceEntryId != null && sourceEntryId.isNotEmpty) {
        return data.transientConversationEntryKeys.any(
          (key) => key == sourceEntryId || key.endsWith(':$sourceEntryId'),
        );
      }
      if (!item.id.startsWith(prefix)) {
        return false;
      }
      final entryId = item.id.substring(prefix.length);
      return data.transientConversationEntryKeys.any(
        (key) => key == entryId || key.endsWith(':$entryId'),
      );
    }
    return false;
  }

  bool _isTransientConversationEntry(LingConversationEntry entry) {
    final sessionId = entry.sessionId?.trim();
    final key = sessionId == null || sessionId.isEmpty
        ? entry.id
        : '$sessionId:${entry.id}';
    return data.transientConversationEntryKeys.contains(key) ||
        data.transientConversationEntryKeys.contains(entry.id);
  }

  void _pruneConversationItemMeasureKeys() {
    final visibleItemIds = data.renderedConversationItems
        .map((item) => item.id)
        .toSet();
    _conversationItemMeasureKeys.removeWhere(
      (itemId, _) => !visibleItemIds.contains(itemId),
    );
  }

  void _handleBottomDockSizeChanged(Size size) {
    if (!mounted || size.height <= 0) {
      return;
    }
    final measuredInset = _lastBottomDockBuildInset;
    if (measuredInset == null) {
      return;
    }
    final previousHeight = _measuredBottomDockHeight;
    final previousInset = _measuredBottomDockInset;
    if (previousHeight != null &&
        (previousHeight - size.height).abs() <= 0.5 &&
        previousInset != null &&
        (previousInset - measuredInset).abs() <= 0.5) {
      return;
    }
    final shouldKeepBottom = _isConversationNearBottom();
    setState(() {
      _measuredBottomDockHeight = size.height;
      _measuredBottomDockInset = measuredInset;
    });
    if (shouldKeepBottom) {
      _jumpConversationToBottomAfterLayout();
    }
  }

  bool _isConversationNearBottom() {
    if (!data.conversationScrollController.hasClients) {
      return true;
    }
    final position = data.conversationScrollController.position;
    return position.maxScrollExtent - position.pixels <= _bottomSnapThreshold;
  }

  void _jumpConversationToBottomAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !data.conversationScrollController.hasClients) {
        return;
      }
      final position = data.conversationScrollController.position;
      final target = position.maxScrollExtent;
      if ((target - position.pixels).abs() <= 0.5) {
        return;
      }
      data.conversationScrollController.jumpTo(target);
    });
  }

  LingConversationScrollAnchor? _captureConversationScrollAnchor() {
    final viewRenderObject = context.findRenderObject();
    if (viewRenderObject is! RenderBox || !viewRenderObject.attached) {
      return null;
    }
    final viewTop = viewRenderObject.localToGlobal(Offset.zero).dy;
    final viewBottom = viewTop + viewRenderObject.size.height;
    final entryAnchor = _captureConversationScrollAnchorFromItems(
      viewTop: viewTop,
      viewBottom: viewBottom,
      items: data.renderedConversationItems.where((item) => item.isEntry),
    );
    if (entryAnchor != null) {
      return entryAnchor;
    }
    final renderedMessageAnchor = _captureConversationScrollAnchorFromItems(
      viewTop: viewTop,
      viewBottom: viewBottom,
      items: data.renderedConversationItems.where((item) => !item.isTimestamp),
    );
    if (renderedMessageAnchor != null) {
      return renderedMessageAnchor;
    }
    if (_hasConversationEntryItems) {
      return null;
    }
    return _captureLoadMoreButtonScrollAnchor(viewTop, viewBottom);
  }

  LingConversationScrollAnchor? _captureConversationScrollAnchorFromItems({
    required double viewTop,
    required double viewBottom,
    required Iterable<LingConversationRenderItem> items,
  }) {
    LingConversationScrollAnchor? candidate;
    double? candidateDy;
    for (final item in items) {
      final itemKey = _conversationItemMeasureKeys[item.id];
      final itemContext = itemKey?.currentContext;
      final itemRenderObject = itemContext?.findRenderObject();
      if (itemKey == null ||
          itemRenderObject is! RenderBox ||
          !itemRenderObject.attached) {
        continue;
      }
      final itemTop = itemRenderObject.localToGlobal(Offset.zero).dy;
      final itemBottom = itemTop + itemRenderObject.size.height;
      if (itemBottom <= viewTop || itemTop >= viewBottom) {
        continue;
      }
      if (candidateDy == null || itemBottom > candidateDy) {
        candidateDy = itemBottom;
        candidate = LingConversationScrollAnchor(
          itemId: item.id,
          itemKey: itemKey,
          globalDy: itemBottom,
        );
      }
    }
    return candidate;
  }

  LingConversationScrollAnchor? _captureLoadMoreButtonScrollAnchor(
    double viewTop,
    double viewBottom,
  ) {
    final buttonContext = _loadMoreButtonMeasureKey.currentContext;
    final buttonRenderObject = buttonContext?.findRenderObject();
    if (buttonRenderObject is! RenderBox || !buttonRenderObject.attached) {
      return null;
    }
    final buttonTop = buttonRenderObject.localToGlobal(Offset.zero).dy;
    final buttonBottom = buttonTop + buttonRenderObject.size.height;
    if (buttonBottom <= viewTop || buttonTop >= viewBottom) {
      return null;
    }
    return LingConversationScrollAnchor(
      itemId: 'conversation-history-load-more',
      itemKey: _loadMoreButtonMeasureKey,
      globalDy: buttonBottom,
    );
  }

  double _resolveConversationBottomContentInset(BuildContext context) {
    final measuredBottomDockHeight = _resolveMeasuredBottomDockHeight(context);
    if (measuredBottomDockHeight != null) {
      return measuredBottomDockHeight + _measuredBottomDockClearance;
    }
    return _resolveEstimatedBottomDockObstruction(context) +
        _conversationActionReserveHeight;
  }

  double _resolveScrollToBottomButtonOffset(BuildContext context) {
    final measuredBottomDockHeight = _resolveMeasuredBottomDockHeight(context);
    if (measuredBottomDockHeight != null) {
      return measuredBottomDockHeight + 4;
    }
    return _resolveEstimatedBottomDockObstruction(context) + 30;
  }

  double? _resolveMeasuredBottomDockHeight(BuildContext context) {
    final measuredHeight = _measuredBottomDockHeight;
    final measuredInset = _measuredBottomDockInset;
    if (measuredHeight == null || measuredInset == null) {
      return null;
    }
    final currentInset = _resolveBottomInset(context);
    if ((currentInset - measuredInset).abs() > 0.5) {
      return null;
    }
    return measuredHeight;
  }

  double _resolveEstimatedBottomDockObstruction(BuildContext context) {
    final bottomInset = _resolveBottomInset(context);
    final dockHeight = _resolveDockHeight(context);
    final floatingAttachmentsHeight = data.pendingAttachments.isEmpty
        ? 0.0
        : _attachmentDrawerHeight + _attachmentDrawerDockGap;
    final quickPromptHeight = _resolveQuickPromptHeight();

    return dockHeight +
        floatingAttachmentsHeight +
        quickPromptHeight +
        bottomInset;
  }

  double _resolveBottomInset(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return math.max(mediaQuery.padding.bottom, mediaQuery.viewInsets.bottom);
  }

  bool get _shouldShowStarterTasksInConversationList {
    return !data.isConversationEmpty &&
        data.starterTasks.isNotEmpty &&
        callbacks.onQuickPromptTap != null;
  }

  bool get _hasConversationEntryItems {
    return data.renderedConversationItems.any((item) => item.isEntry);
  }

  double _resolveQuickPromptHeight() {
    if ((data.activeQuickPromptLabel ?? '').trim().isNotEmpty) {
      return 48;
    }
    if (data.quickPrompts.where((item) => item.trim().isNotEmpty).isEmpty) {
      return 0;
    }
    if (data.forceQuickPromptsVisible) {
      return 48;
    }
    if (data.isDockBusy ||
        data.isVoiceActive ||
        data.hasVoiceDraftReview ||
        (!data.keepQuickPromptsVisibleWithText &&
            _chatSectionComposerUserText(
              data.composerController,
            ).trim().isNotEmpty) ||
        data.pendingAttachments.isNotEmpty) {
      return 0;
    }
    return 48;
  }

  double _resolveDockComposerTextMaxWidth(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final panelWidth = math.min(420.0, mediaQuery.size.width - 36);
    final hasDraft = _chatSectionComposerUserText(
      data.composerController,
    ).trim().isNotEmpty;
    final horizontalChrome = hasDraft ? 180.0 : 220.0;
    return math.max(120.0, panelWidth - horizontalChrome);
  }

  double _resolveDockComposerInputHeight(BuildContext context) {
    final lineCount = _estimateComposerLineCount(
      context,
      _resolveDockComposerTextMaxWidth(context),
    );
    final visibleLineCount = math.max(1, lineCount).clamp(1, _composerMaxLines);
    final lineHeight = _composerFontSize * _composerHeightMultiplier;
    return _composerVerticalPadding + lineHeight * visibleLineCount;
  }

  double _resolveDockHeight(BuildContext context) {
    if (data.hasVoiceDraftReview || data.isVoiceActive) {
      return _resolveDefaultCollapsedComposerDockHeight();
    }
    final inputHeight = _resolveDockComposerInputHeight(context);
    return math.max(_collapsedDockHeight, inputHeight + 8);
  }

  double _resolveDefaultCollapsedComposerDockHeight() {
    final lineHeight = _composerFontSize * _composerHeightMultiplier;
    final composerHeight =
        _composerVerticalPadding + lineHeight * _collapsedComposerMinLines;
    return math.max(_collapsedDockHeight, composerHeight + 8);
  }

  int _estimateComposerLineCount(BuildContext context, double maxWidth) {
    final text = _chatSectionComposerUserText(data.composerController);
    if (text.trim().isEmpty) {
      return 0;
    }
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: _composerFontSize,
          height: _composerHeightMultiplier,
        ),
      ),
      textDirection: Directionality.of(context),
      maxLines: _composerMaxLines,
    )..layout(maxWidth: math.max(120, maxWidth));
    return textPainter
        .computeLineMetrics()
        .length
        .clamp(1, _composerMaxLines)
        .toInt();
  }
}

class _ConversationHistoryLoadMoreButton extends StatelessWidget {
  const _ConversationHistoryLoadMoreButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: LingGlassButton(
          onPressed: onPressed,
          minHeight: 38,
          width: 188,
          expand: false,
          radius: 19,
          tone: LingGlassSurfaceTone.muted,
          showBorder: false,
          foregroundColor: palette.textSecondary,
          disabledForegroundColor: palette.textSecondary.withValues(
            alpha: 0.54,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _ConversationHistoryLoadingIndicator extends StatelessWidget {
  const _ConversationHistoryLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      key: const Key('conversation_history_loading_indicator'),
      height: 32,
      child: Center(
        child: SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: palette.textSecondary.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _ScrollToBottomButton extends StatelessWidget {
  const _ScrollToBottomButton({
    required this.onPressed,
    required this.semanticLabel,
  });

  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final iconColor = context.isDarkMode ? Colors.white : palette.accent;
    final tintColor = lingFloatingControlTintFor(context, palette);
    return Semantics(
      key: const Key('conversation_scroll_to_bottom_button'),
      button: true,
      label: semanticLabel,
      child: LingGlassSurface(
        width: 46,
        height: 46,
        radius: 23,
        tone: LingGlassSurfaceTone.control,
        tintColor: tintColor,
        quality: LingGlassQuality.premium,
        child: IconButton(
          key: const Key('conversation_scroll_to_bottom_tap_target'),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 46, height: 46),
          splashRadius: 23,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 28,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

bool _isHistoricalConversationEntry(
  LingConversationEntry entry, {
  required String? currentSessionId,
}) {
  final entrySessionId = entry.sessionId?.trim();
  final activeSessionId = currentSessionId?.trim();
  return entrySessionId != null &&
      entrySessionId.isNotEmpty &&
      activeSessionId != null &&
      activeSessionId.isNotEmpty &&
      entrySessionId != activeSessionId;
}

String? _resolveLatestAssistantActionEntryId(
  List<LingConversationRenderItem> items, {
  required String? currentSessionId,
}) {
  for (final item in items.reversed) {
    if (!item.isEntry) {
      continue;
    }
    final entry = item.entry!;
    if (_isHistoricalConversationEntry(
      entry,
      currentSessionId: currentSessionId,
    )) {
      continue;
    }
    if (entry.entryType == LingConversationEntryType.assistantMessage &&
        entry.text.trim().isNotEmpty) {
      return entry.id;
    }
  }
  return null;
}

Map<String, LingQuestionnaireResponse> _resolveQuestionnaireResponses(
  List<LingConversationRenderItem> items,
) {
  final responses = <String, LingQuestionnaireResponse>{};
  for (final item in items) {
    if (!item.isEntry) {
      continue;
    }
    final response = _questionnaireResponseForEntry(item.entry!);
    if (response != null) {
      responses[response.questionnaireId] = response;
    }
  }
  return Map<String, LingQuestionnaireResponse>.unmodifiable(responses);
}

LingQuestionnaireResponse? _questionnaireResponseForEntry(
  LingConversationEntry entry,
) {
  if (entry.role != LingConversationRole.user) {
    return null;
  }
  final agentText = entry.metadata?['agent_text'];
  if (agentText is String) {
    final response = LingQuestionnaireResponse.fromAgentText(agentText);
    if (response != null) {
      return response;
    }
  }
  return LingQuestionnaireResponse.fromAgentText(entry.text);
}

class _ConversationContextDigestStrip extends StatelessWidget {
  const _ConversationContextDigestStrip({required this.summary});

  final String? summary;

  @override
  Widget build(BuildContext context) {
    final text = (summary ?? '').trim();
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    final palette = Theme.of(context).extension<LingPalette>();
    final textColor =
        palette?.textSecondary.withValues(alpha: 0.72) ??
        Theme.of(context).textTheme.bodySmall?.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.center,
        child: Text(
          text,
          key: const Key('conversation_context_digest_strip'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MeasureSizeRenderObject(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this.onChange);

  ValueChanged<Size> onChange;
  Size? _reportedSize;
  Size? _pendingSize;
  bool _callbackScheduled = false;

  @override
  void performLayout() {
    super.performLayout();
    if (_reportedSize == size) {
      return;
    }
    _reportedSize = size;
    _pendingSize = size;
    if (_callbackScheduled) {
      return;
    }
    _callbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _callbackScheduled = false;
      final pendingSize = _pendingSize;
      if (pendingSize == null) {
        return;
      }
      onChange(pendingSize);
    });
  }
}
