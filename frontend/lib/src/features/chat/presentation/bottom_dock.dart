import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/chat/application/conversation_attachment.dart';
import 'package:ling/src/features/chat/application/object_reference.dart';
import 'package:ling/src/features/chat/presentation/object_reference_editing_controller.dart';
import 'package:ling/src/features/chat/presentation/voice_preview_control.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/shared_controls.dart';
import 'package:ling/src/shared/presentation/tap_haptics.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

part 'bottom_dock/bottom_dock_attachments.dart';
part 'bottom_dock/bottom_dock_chrome.dart';
part 'bottom_dock/bottom_dock_composer.dart';
part 'bottom_dock/bottom_dock_quick_prompts.dart';
part 'bottom_dock/bottom_dock_queue_status.dart';
part 'bottom_dock/bottom_dock_voice.dart';

const double _collapsedDockHeight = 64;
const double _maxDockWidth = 420;
const double _attachmentDrawerHeight = 96;
const double _attachmentDrawerDockGap = 8;
const double _quickPromptDockGap = 6;
const double _inlineAttachmentSize = 44;
const double _attachmentThumbnailSize = 76;
const double _composerFontSize = 17;
const double _composerHeightMultiplier = 1.12;
const double _composerVerticalPadding = 26;
const double _quickPromptStripHeight = 48;
const double _quickPromptTagHeight = 40;
const double _quickPromptTagFontSize = 14;
const double _quickPromptRefreshOverscrollThreshold = 36;
const int _composerMaxLines = 10;
const int _collapsedComposerMinLines = 1;
const double _dockIconButtonSize = _collapsedDockHeight;
const double _dockContentBottomPadding = 0;
const Duration _panelCollapseAnimationDuration = Duration(milliseconds: 260);
const Duration _quickPromptComposerSettleDuration = Duration(milliseconds: 450);

String _composerUserText(TextEditingController controller) {
  return controller is LingObjectReferenceEditingController
      ? controller.userText
      : controller.text;
}

bool _composerHasUserTextOrComposing(TextEditingController controller) {
  final composing = controller.value.composing;
  return _composerUserText(controller).trim().isNotEmpty ||
      (composing.isValid && !composing.isCollapsed);
}

class LingCalendarBottomDock extends StatefulWidget {
  const LingCalendarBottomDock({
    super.key,
    required this.isBusy,
    this.isConversationRestoring = false,
    required this.busyLabel,
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
    required this.isExpanded,
    this.preferVoiceInput = false,
    required this.composerController,
    required this.composerFocusNode,
    required this.composerScrollController,
    this.composerCursorPreviewOffset,
    required this.composerPlaceholder,
    this.quickPrompts = const <String>[],
    this.activeQuickPromptLabel,
    this.activeQuickPromptHint,
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
    required this.onExpand,
    required this.onCollapse,
    required this.onVoiceTap,
    required this.onAddImageTap,
    required this.onKeyboardTap,
    required this.onDismissKeyboardTap,
    required this.onPhotoLibraryTap,
    required this.onCameraTap,
    required this.onRemoveAttachment,
    required this.onPreviewAttachment,
    required this.onReorderAttachments,
    required this.deleteQueuedMessageTooltip,
    required this.applyQueuedMessageNowTooltip,
    required this.editQueuedMessageTooltip,
    required this.onViewQueuedMessages,
    required this.onDeleteQueuedMessage,
    required this.onApplyQueuedMessageNow,
    required this.onEditQueuedMessage,
    required this.onCancelVoiceDraft,
    required this.onPlayVoiceDraftPreview,
    required this.onLoadVoiceDraftPreviewDuration,
    required this.onStopVoiceDraftPreview,
    required this.onStopAgentReply,
    this.onQuickPromptTap,
    this.onQuickPromptRefresh,
    this.onCancelActiveQuickPrompt,
    this.onRemoveObjectReference,
    required this.onSubmitText,
  });

  final bool isBusy;
  final bool isConversationRestoring;
  final String busyLabel;
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
  final bool isExpanded;
  final bool preferVoiceInput;
  final TextEditingController composerController;
  final FocusNode composerFocusNode;
  final ScrollController composerScrollController;
  final int? composerCursorPreviewOffset;
  final String composerPlaceholder;
  final List<String> quickPrompts;
  final String? activeQuickPromptLabel;
  final String? activeQuickPromptHint;
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
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final VoidCallback onVoiceTap;
  final VoidCallback onAddImageTap;
  final VoidCallback onKeyboardTap;
  final VoidCallback onDismissKeyboardTap;
  final VoidCallback onPhotoLibraryTap;
  final VoidCallback onCameraTap;
  final ValueChanged<LingConversationAttachment> onRemoveAttachment;
  final ValueChanged<LingConversationAttachment> onPreviewAttachment;
  final ValueChanged<List<LingConversationAttachment>> onReorderAttachments;
  final String deleteQueuedMessageTooltip;
  final String applyQueuedMessageNowTooltip;
  final String editQueuedMessageTooltip;
  final VoidCallback onViewQueuedMessages;
  final VoidCallback onDeleteQueuedMessage;
  final VoidCallback onApplyQueuedMessageNow;
  final VoidCallback onEditQueuedMessage;
  final VoidCallback onCancelVoiceDraft;
  final Future<Duration> Function(String path) onPlayVoiceDraftPreview;
  final Future<Duration> Function(String path) onLoadVoiceDraftPreviewDuration;
  final FutureOr<void> Function() onStopVoiceDraftPreview;
  final VoidCallback onStopAgentReply;
  final ValueChanged<String>? onQuickPromptTap;
  final FutureOr<void> Function()? onQuickPromptRefresh;
  final VoidCallback? onCancelActiveQuickPrompt;
  final ValueChanged<LingObjectReference>? onRemoveObjectReference;
  final VoidCallback onSubmitText;

  @override
  State<LingCalendarBottomDock> createState() => _LingCalendarBottomDockState();
}

class _LingCalendarBottomDockState extends State<LingCalendarBottomDock> {
  final ScrollController _quickPromptScrollController = ScrollController();
  final List<GlobalKey> _quickPromptKeys = <GlobalKey>[];
  String? _lastQuickPromptVisibilityLogKey;
  Timer? _quickPromptRevealTimer;
  Timer? _quickPromptComposerSettleTimer;
  DateTime? _lastQuickPromptRefreshAt;
  double _quickPromptRefreshOverscroll = 0;
  bool _deferQuickPromptsUntilCollapsed = false;
  bool _suppressQuickPromptsUntilComposerSettles = false;
  final GlobalKey _collapsedComposerInputKey = GlobalKey(
    debugLabel: 'bottom_dock_collapsed_composer_input',
  );
  bool _isVoiceMode = false;
  bool _isAttachmentDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    _isVoiceMode = widget.preferVoiceInput;
    _syncObjectReferenceEditingController();
    widget.composerController.addListener(_handleComposerControllerChanged);
    widget.composerFocusNode.addListener(_handleComposerFocusChanged);
  }

  bool get _hasDraft =>
      _composerUserText(widget.composerController).trim().isNotEmpty;
  bool get _hasSendableDraft =>
      _hasDraft ||
      widget.pendingObjectReferences.isNotEmpty ||
      widget.pendingAttachments.isNotEmpty ||
      widget.voiceDraftAudioPath.trim().isNotEmpty;
  bool get _usesOuterSendButton =>
      (_hasDraft || widget.pendingObjectReferences.isNotEmpty) &&
      !widget.hasVoiceDraftReview &&
      !widget.isVoiceActive;
  bool get _canStopAgentReply =>
      widget.isAgentReplying &&
      !widget.isInterruptingAgentReply &&
      !_hasSendableDraft;

  bool get _canSubmit =>
      !widget.isBusy &&
      !widget.isConversationRestoring &&
      !widget.isVoiceActive &&
      (_hasSendableDraft || _canStopAgentReply);

  bool get _isEffectivelyExpanded =>
      widget.hasVoiceDraftReview ||
      widget.isVoiceActive ||
      _isAttachmentDrawerOpen ||
      widget.pendingObjectReferences.isNotEmpty ||
      _composerUserText(widget.composerController).trim().isNotEmpty;

  bool _isExpandedForWidget(LingCalendarBottomDock value) =>
      value.hasVoiceDraftReview ||
      value.isVoiceActive ||
      value.pendingObjectReferences.isNotEmpty ||
      _composerUserText(value.composerController).trim().isNotEmpty;

  @override
  void didUpdateWidget(covariant LingCalendarBottomDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.composerController != widget.composerController) {
      oldWidget.composerController.removeListener(
        _handleComposerControllerChanged,
      );
      _syncObjectReferenceEditingController();
      widget.composerController.addListener(_handleComposerControllerChanged);
      _quickPromptComposerSettleTimer?.cancel();
      _quickPromptComposerSettleTimer = null;
      _suppressQuickPromptsUntilComposerSettles =
          _composerHasUserTextOrComposing(widget.composerController);
    } else if (oldWidget.pendingObjectReferences !=
            widget.pendingObjectReferences ||
        oldWidget.onRemoveObjectReference != widget.onRemoveObjectReference) {
      _syncObjectReferenceEditingController();
    }
    if (oldWidget.composerFocusNode != widget.composerFocusNode) {
      oldWidget.composerFocusNode.removeListener(_handleComposerFocusChanged);
      widget.composerFocusNode.addListener(_handleComposerFocusChanged);
    }
    if (widget.isVoiceActive && !_isVoiceMode) {
      _isVoiceMode = true;
    }
    if (oldWidget.preferVoiceInput != widget.preferVoiceInput &&
        _canApplyPreferredInputMode) {
      _isVoiceMode = widget.preferVoiceInput;
    }
    if (widget.isKeyboardComposerOpen &&
        _isVoiceMode &&
        !widget.isVoiceActive) {
      _isVoiceMode = false;
    }
    if (widget.pendingAttachments.length <= 1 && _isAttachmentDrawerOpen) {
      _isAttachmentDrawerOpen = false;
    }
    final wasExpanded = _isExpandedForWidget(oldWidget);
    final isExpanded = _isExpandedForWidget(widget);
    if (wasExpanded && !isExpanded) {
      _deferQuickPromptsUntilCollapsed = true;
      _quickPromptRevealTimer?.cancel();
      _quickPromptRevealTimer = Timer(_panelCollapseAnimationDuration, () {
        if (!mounted) {
          return;
        }
        setState(() {
          _deferQuickPromptsUntilCollapsed = false;
        });
      });
      return;
    }
    if (!wasExpanded && isExpanded) {
      _quickPromptRevealTimer?.cancel();
      _quickPromptRevealTimer = null;
      _deferQuickPromptsUntilCollapsed = false;
    }
  }

  bool get _canApplyPreferredInputMode =>
      !widget.isVoiceActive &&
      !widget.hasVoiceDraftReview &&
      !widget.isKeyboardComposerOpen &&
      _composerUserText(widget.composerController).trim().isEmpty;

  @override
  void dispose() {
    widget.composerController.removeListener(_handleComposerControllerChanged);
    widget.composerFocusNode.removeListener(_handleComposerFocusChanged);
    _quickPromptRevealTimer?.cancel();
    _quickPromptComposerSettleTimer?.cancel();
    _quickPromptScrollController.dispose();
    super.dispose();
  }

  void _showVoiceMode() {
    if (_isVoiceMode) {
      return;
    }
    setState(() {
      _isVoiceMode = true;
    });
    widget.onCollapse();
  }

  void _showTextMode() {
    if (!_isVoiceMode) {
      widget.onKeyboardTap();
      return;
    }
    setState(() {
      _isVoiceMode = false;
    });
  }

  void _handleComposerControllerChanged() {
    if (!mounted) {
      return;
    }
    final controller = widget.composerController;
    if (controller is LingObjectReferenceEditingController &&
        widget.pendingObjectReferences.isNotEmpty &&
        !controller.hasObjectReferenceMarker) {
      final onRemove = widget.onRemoveObjectReference;
      if (onRemove != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          for (final reference in widget.pendingObjectReferences) {
            onRemove(reference);
          }
        });
      }
    }
    _syncQuickPromptComposerEditSuppression();
    setState(() {});
  }

  void _handleComposerFocusChanged() {
    if (!mounted) {
      return;
    }
    if (!widget.composerFocusNode.hasFocus &&
        _suppressQuickPromptsUntilComposerSettles) {
      _quickPromptComposerSettleTimer?.cancel();
      _quickPromptComposerSettleTimer = null;
      setState(() {
        _suppressQuickPromptsUntilComposerSettles = false;
      });
    }
  }

  void _syncQuickPromptComposerEditSuppression() {
    if (widget.forceQuickPromptsVisible ||
        widget.keepQuickPromptsVisibleWithText) {
      _quickPromptComposerSettleTimer?.cancel();
      _quickPromptComposerSettleTimer = null;
      _suppressQuickPromptsUntilComposerSettles = false;
      return;
    }
    if (_composerHasUserTextOrComposing(widget.composerController)) {
      _quickPromptComposerSettleTimer?.cancel();
      _quickPromptComposerSettleTimer = null;
      _suppressQuickPromptsUntilComposerSettles = true;
      return;
    }
    if (!_suppressQuickPromptsUntilComposerSettles) {
      return;
    }
    _quickPromptComposerSettleTimer?.cancel();
    _quickPromptComposerSettleTimer = Timer(
      _quickPromptComposerSettleDuration,
      () {
        if (!mounted ||
            _composerHasUserTextOrComposing(widget.composerController)) {
          return;
        }
        setState(() {
          _suppressQuickPromptsUntilComposerSettles = false;
        });
      },
    );
  }

  void _syncObjectReferenceEditingController() {
    final controller = widget.composerController;
    if (controller is! LingObjectReferenceEditingController) {
      return;
    }
    controller.setObjectReferences(
      widget.pendingObjectReferences,
      onRemove: widget.onRemoveObjectReference,
    );
  }

  Widget _buildCollapsedDock(
    BuildContext context,
    LingPalette palette, {
    required double height,
  }) {
    return SizedBox(
      key: const Key('bottom_dock_panel'),
      width: _maxDockWidth,
      height: height,
      child: _buildDockActionRow(palette, expanded: false, height: height),
    );
  }

  Widget _buildDockMiddleContent(
    LingPalette palette, {
    required double actionSize,
  }) {
    if (widget.hasVoiceDraftReview) {
      return _buildVoiceDraftReviewPill(palette, height: actionSize);
    }
    if (widget.isVoiceActive || _isVoiceMode) {
      return _buildVoiceInputPill(palette, height: actionSize);
    }
    return _buildCollapsedComposerInput(context, palette, height: actionSize);
  }

  Widget _buildModeOrSendControl(
    LingPalette palette, {
    required double actionSize,
  }) {
    if (widget.hasVoiceDraftReview) {
      return _LingDockEmbeddedIconButton(
        buttonKey: const Key('bottom_dock_send_voice_draft_button'),
        tooltip: widget.sendMessageTooltip,
        icon: Icons.send_rounded,
        onTap: _canSubmit ? widget.onSubmitText : null,
        palette: palette,
        size: actionSize,
        iconColor: _canSubmit ? palette.accent : _mutedTextOnGlass(palette),
        disabledIconColor: palette.textSecondary,
        tintColor: _transparentButtonTintFor(context, palette),
      );
    }
    if (widget.isVoiceActive) {
      return _LingDockStopRecordingButton(
        buttonKey: const Key('bottom_dock_mode_button'),
        tooltip: widget.voiceTooltip,
        onTap: widget.canVoiceTap ? widget.onVoiceTap : null,
        palette: palette,
        size: actionSize,
      );
    }
    if (_canStopAgentReply) {
      return _LingDockStopRecordingButton(
        buttonKey: const Key('bottom_dock_mode_button'),
        tooltip: widget.stopAgentReplyTooltip,
        onTap: widget.onStopAgentReply,
        palette: palette,
        size: actionSize,
      );
    }
    if (_usesOuterSendButton) {
      return _LingDockEmbeddedIconButton(
        buttonKey: const ValueKey('bottom_dock_send_button'),
        tooltip: widget.sendMessageTooltip,
        icon: Icons.send_rounded,
        onTap: _canSubmit ? widget.onSubmitText : null,
        palette: palette,
        size: actionSize,
        iconColor: _canSubmit ? palette.accent : _mutedTextOnGlass(palette),
        disabledIconColor: palette.textSecondary,
        tintColor: _transparentButtonTintFor(context, palette),
      );
    }
    final icon = widget.isVoiceActive || _isVoiceMode
        ? Icons.keyboard_rounded
        : Icons.mic_rounded;
    final tooltip = widget.isVoiceActive || _isVoiceMode
        ? widget.keyboardTooltip
        : widget.voiceTooltip;
    final onTap = widget.isVoiceActive || _isVoiceMode
        ? _showTextMode
        : widget.canVoiceTap
        ? _showVoiceMode
        : null;
    return _LingDockEmbeddedIconButton(
      buttonKey: const Key('bottom_dock_mode_button'),
      tooltip: tooltip,
      icon: icon,
      onTap: onTap,
      palette: palette,
      size: actionSize,
      iconColor: _textOnGlass(palette),
      tintColor: _transparentButtonTintFor(context, palette),
    );
  }

  Widget _buildBusyModeControl(LingPalette palette, {required double size}) {
    return _withDockControlBorder(
      context: context,
      palette: palette,
      radius: size / 2,
      child: LingGlassSurface(
        key: const Key('bottom_dock_busy_mode_indicator'),
        width: size,
        height: size,
        radius: size / 2,
        tone: LingGlassSurfaceTone.control,
        tintColor: _transparentButtonTintFor(context, palette),
        quality: LingGlassQuality.premium,
        useOwnLayer: false,
        child: const Center(
          child: GlassProgressIndicator.circular(size: 18, strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildDockActionRow(
    LingPalette palette, {
    required bool expanded,
    double? height,
  }) {
    const actionSize = _dockIconButtonSize;
    final rowHeight = height ?? _collapsedDockHeight;
    final middleHeight = math.max(
      actionSize,
      rowHeight - _dockContentBottomPadding * 2,
    );
    return LingGlassLayer(
      tone: LingGlassSurfaceTone.control,
      tintColor: _transparentButtonTintFor(context, palette),
      quality: LingGlassQuality.premium,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: expanded ? 0 : 2),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: _dockContentBottomPadding,
                ),
                child: _LingDockEmbeddedIconButton(
                  buttonKey: const Key('bottom_dock_image_button'),
                  tooltip: widget.addImageTooltip,
                  icon: Icons.add_photo_alternate_rounded,
                  onTap:
                      widget.isBusy ||
                          widget.isConversationRestoring ||
                          widget.isVoiceActive
                      ? null
                      : widget.onAddImageTap,
                  palette: palette,
                  size: actionSize,
                  iconColor: _textOnGlass(palette),
                  disabledIconColor: widget.isVoiceActive
                      ? _recordingDisabledIconFor(context, palette)
                      : null,
                  disabledOpacity: widget.isVoiceActive ? 1 : 0.45,
                  tintColor: _transparentButtonTintFor(context, palette),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                key: const Key('bottom_dock_middle_slot'),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildDockMiddleContent(
                    palette,
                    actionSize: middleHeight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: _dockContentBottomPadding,
                ),
                child: SizedBox(
                  key: const Key('bottom_dock_send_slot'),
                  width: actionSize,
                  height: actionSize,
                  child:
                      (widget.isBusy || widget.isConversationRestoring) &&
                          !widget.isVoiceActive &&
                          !_canStopAgentReply
                      ? _buildBusyModeControl(palette, size: actionSize)
                      : _buildModeOrSendControl(
                          palette,
                          actionSize: actionSize,
                        ),
                ),
              ),
              SizedBox(width: expanded ? 0 : 2),
            ],
          ),
        ),
      ),
    );
  }

  double _resolveDockHeight(BuildContext context) {
    if (widget.hasVoiceDraftReview || widget.isVoiceActive || _isVoiceMode) {
      return _resolveDefaultCollapsedComposerDockHeight();
    }
    return _resolveCollapsedComposerDockHeight(context);
  }

  double _resolveDefaultCollapsedComposerDockHeight() {
    final lineHeight = _composerFontSize * _composerHeightMultiplier;
    final composerHeight =
        _composerVerticalPadding + lineHeight * _collapsedComposerMinLines;
    return math.max(_collapsedDockHeight, composerHeight + 8);
  }

  double _resolveCollapsedComposerDockHeight(BuildContext context) {
    final dockWidth = math.min(
      _maxDockWidth,
      MediaQuery.sizeOf(context).width - 36,
    );
    final horizontalChrome = _usesOuterSendButton ? 180.0 : 220.0;
    final textMaxWidth = math.max(120.0, dockWidth - horizontalChrome);
    final lineCount = math.max(
      1,
      _estimateComposerLineCount(context, textMaxWidth),
    );
    final lineHeight = _composerFontSize * _composerHeightMultiplier;
    final composerHeight = _composerVerticalPadding + lineHeight * lineCount;
    return math.max(_collapsedDockHeight, composerHeight + 8);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final safeAreaBottom = mediaQuery.padding.bottom;
    final bottomInset = math.max(keyboardInset, safeAreaBottom);
    final isExpanded = _isEffectivelyExpanded;
    final hasFloatingAttachments =
        widget.pendingAttachments.isNotEmpty &&
        !widget.forceQuickPromptsVisible;
    final dockHeight = _resolveDockHeight(context);
    final shouldDeferQuickPrompts =
        _deferQuickPromptsUntilCollapsed && !widget.forceQuickPromptsVisible;
    if (hasFloatingAttachments || shouldDeferQuickPrompts) {
      _syncQuickPromptAutoScroll(promptCount: 0);
    }

    final strings = LingStrings(
      Localizations.localeOf(context).toLanguageTag(),
    );
    return Container(
      key: const Key('bottom_dock_container'),
      padding: EdgeInsets.fromLTRB(18, 8, 18, 18 + bottomInset),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.queuedCount > 0)
                _buildQueuedPromptCard(context, palette),
              if (widget.isBusy) _buildBusyCard(context, palette),
              if (hasFloatingAttachments) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxDockWidth),
                  child: _buildAttachmentDrawer(context, palette),
                ),
                const SizedBox(height: _attachmentDrawerDockGap),
              ] else if (shouldDeferQuickPrompts) ...[
                const SizedBox.shrink(),
              ] else ...[
                _buildQuickPromptStrip(
                  context,
                  palette,
                  isExpanded: isExpanded,
                ),
                if ((_activeQuickPromptLabel != null ||
                        widget.quickPrompts.isNotEmpty) &&
                    (widget.forceQuickPromptsVisible ||
                        _activeQuickPromptLabel != null ||
                        (!widget.isBusy &&
                            !widget.isConversationRestoring &&
                            !widget.isVoiceActive &&
                            !widget.hasVoiceDraftReview &&
                            (widget.keepQuickPromptsVisibleWithText ||
                                (!_suppressQuickPromptsUntilComposerSettles &&
                                    !_composerHasUserTextOrComposing(
                                      widget.composerController,
                                    ))))))
                  const SizedBox(height: _quickPromptDockGap),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxDockWidth),
                child: AnimatedSwitcher(
                  duration: Duration.zero,
                  reverseDuration: Duration.zero,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.bottomCenter,
                      children: [...previousChildren, ?currentChild],
                    );
                  },
                  transitionBuilder: (child, animation) => child,
                  child: KeyedSubtree(
                    key: const ValueKey('bottom_dock_collapsed'),
                    child: _buildCollapsedDock(
                      context,
                      palette,
                      height: dockHeight,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: -14,
            left: 0,
            right: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxDockWidth),
              child: Text(
                strings.aiGeneratedNotice,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textTertiary.withValues(
                    alpha: context.isDarkMode ? 0.46 : 0.42,
                  ),
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? get _activeQuickPromptLabel {
    final label = widget.activeQuickPromptLabel?.trim();
    if (label == null || label.isEmpty) {
      return null;
    }
    return label;
  }

  String? get _activeQuickPromptHint {
    final hint = widget.activeQuickPromptHint?.trim();
    if (hint == null || hint.isEmpty) {
      return null;
    }
    return hint;
  }
}
