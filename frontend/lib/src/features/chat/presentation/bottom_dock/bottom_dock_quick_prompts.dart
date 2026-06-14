part of '../bottom_dock.dart';

extension _BottomDockQuickPrompts on _LingCalendarBottomDockState {
  void _syncQuickPromptAutoScroll({required int promptCount}) {
    _syncQuickPromptKeys(promptCount);
  }

  void _syncQuickPromptKeys(int promptCount) {
    while (_quickPromptKeys.length < promptCount) {
      _quickPromptKeys.add(
        GlobalKey(debugLabel: 'bottom_dock_quick_prompt_auto_scroll'),
      );
    }
    if (_quickPromptKeys.length > promptCount) {
      _quickPromptKeys.removeRange(promptCount, _quickPromptKeys.length);
    }
  }

  Widget _buildQuickPromptStrip(
    BuildContext context,
    LingPalette palette, {
    required bool isExpanded,
  }) {
    final activeLabel = _activeQuickPromptLabel;
    if (activeLabel != null) {
      _syncQuickPromptAutoScroll(promptCount: 0);
      return _buildActiveQuickPromptStrip(context, palette, activeLabel);
    }
    final prompts = widget.quickPrompts
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(24)
        .toList(growable: false);
    final hiddenReason = _quickPromptHiddenReason(
      prompts,
      isExpanded: isExpanded,
    );
    _logQuickPromptVisibility(
      prompts: prompts,
      hiddenReason: hiddenReason,
      isExpanded: isExpanded,
    );
    if (hiddenReason != null) {
      _syncQuickPromptAutoScroll(promptCount: prompts.length);
      return const SizedBox.shrink();
    }
    _syncQuickPromptAutoScroll(promptCount: prompts.length);
    return NotificationListener<ScrollNotification>(
      onNotification: _handleQuickPromptScrollNotification,
      child: Listener(
        onPointerDown: (_) => _quickPromptRefreshOverscroll = 0,
        onPointerMove: _handleQuickPromptPointerMove,
        onPointerUp: (_) => _quickPromptRefreshOverscroll = 0,
        onPointerCancel: (_) => _quickPromptRefreshOverscroll = 0,
        child: SizedBox(
          height: _quickPromptStripHeight,
          child: SingleChildScrollView(
            key: const Key('bottom_dock_quick_prompt_scroll'),
            controller: _quickPromptScrollController,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  for (var index = 0; index < prompts.length; index++) ...[
                    KeyedSubtree(
                      key: _quickPromptKeys[index],
                      child: LingGlassChip(
                        key: Key('bottom_dock_quick_prompt_$index'),
                        onPressed: () =>
                            widget.onQuickPromptTap?.call(prompts[index]),
                        label: prompts[index],
                        height: _quickPromptTagHeight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 12,
                        ),
                        textStyle: const TextStyle(
                          fontSize: _quickPromptTagFontSize,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                        foregroundColor: _quickPromptForegroundFor(
                          context,
                          palette,
                        ),
                        tintColor: _transparentButtonTintFor(context, palette),
                        quality: LingGlassQuality.premium,
                      ),
                    ),
                    if (index < prompts.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleQuickPromptPointerMove(PointerMoveEvent event) {
    if (widget.onQuickPromptRefresh == null ||
        !_quickPromptScrollController.hasClients) {
      return;
    }
    final position = _quickPromptScrollController.position;
    final atLeadingEdge = position.pixels <= position.minScrollExtent + 0.5;
    final atTrailingEdge = position.pixels >= position.maxScrollExtent - 0.5;
    final draggingPastLeading = atLeadingEdge && event.delta.dx > 0;
    final draggingPastTrailing = atTrailingEdge && event.delta.dx < 0;
    if (!draggingPastLeading && !draggingPastTrailing) {
      _quickPromptRefreshOverscroll = 0;
      return;
    }
    _accumulateQuickPromptRefreshDrag(event.delta.dx.abs());
  }

  bool _handleQuickPromptScrollNotification(ScrollNotification notification) {
    if (widget.onQuickPromptRefresh == null ||
        notification.metrics.axis != Axis.horizontal) {
      return false;
    }
    if (notification is ScrollStartNotification ||
        notification is ScrollEndNotification) {
      _quickPromptRefreshOverscroll = 0;
      return false;
    }
    if (notification is! OverscrollNotification) {
      return false;
    }
    final metrics = notification.metrics;
    final atLeadingEdge = metrics.pixels <= metrics.minScrollExtent;
    final atTrailingEdge = metrics.pixels >= metrics.maxScrollExtent;
    if (!atLeadingEdge && !atTrailingEdge) {
      _quickPromptRefreshOverscroll = 0;
      return false;
    }
    _accumulateQuickPromptRefreshDrag(notification.overscroll.abs());
    return false;
  }

  void _accumulateQuickPromptRefreshDrag(double delta) {
    _quickPromptRefreshOverscroll += delta;
    if (_quickPromptRefreshOverscroll <
        _quickPromptRefreshOverscrollThreshold) {
      return;
    }
    _quickPromptRefreshOverscroll = 0;
    final now = DateTime.now();
    final lastRefreshAt = _lastQuickPromptRefreshAt;
    if (lastRefreshAt != null &&
        now.difference(lastRefreshAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastQuickPromptRefreshAt = now;
    final refresh = widget.onQuickPromptRefresh!();
    if (refresh is Future<void>) {
      unawaited(refresh);
    }
  }

  Widget _buildActiveQuickPromptStrip(
    BuildContext context,
    LingPalette palette,
    String label,
  ) {
    final strings = LingStrings(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final hint =
        _activeQuickPromptHint ??
        (strings.isZh ? '输入或说出具体内容' : 'Type or say the details');
    return SizedBox(
      height: _quickPromptStripHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Flexible(
              flex: 0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: LingGlassChip(
                  key: const Key('bottom_dock_active_quick_prompt'),
                  onPressed: widget.onCancelActiveQuickPrompt,
                  label: label,
                  height: _quickPromptTagHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontSize: _quickPromptTagFontSize,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                  foregroundColor: _quickPromptForegroundFor(context, palette),
                  tintColor: _transparentButtonTintFor(context, palette),
                  quality: LingGlassQuality.premium,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _quickPromptForegroundFor(BuildContext context, LingPalette palette) {
    return palette.textPrimary;
  }

  String? _quickPromptHiddenReason(
    List<String> prompts, {
    required bool isExpanded,
  }) {
    if (prompts.isEmpty) {
      return 'empty_prompts';
    }
    if (widget.forceQuickPromptsVisible) {
      return null;
    }
    if (widget.isBusy || widget.isConversationRestoring) {
      return 'busy';
    }
    if (widget.isVoiceActive) {
      return 'voice_active';
    }
    if (widget.hasVoiceDraftReview) {
      return 'voice_draft_review';
    }
    if (!widget.keepQuickPromptsVisibleWithText &&
        (_suppressQuickPromptsUntilComposerSettles ||
            _composerHasUserTextOrComposing(widget.composerController))) {
      return 'composer_has_text';
    }
    if (widget.pendingAttachments.isNotEmpty) {
      return 'has_attachments';
    }
    return null;
  }

  void _logQuickPromptVisibility({
    required List<String> prompts,
    required String? hiddenReason,
    required bool isExpanded,
  }) {
    final logKey = [
      widget.forceQuickPromptsVisible,
      prompts.length,
      hiddenReason ?? 'visible',
      isExpanded,
      widget.isBusy,
      widget.isVoiceActive,
      _suppressQuickPromptsUntilComposerSettles ||
          _composerHasUserTextOrComposing(widget.composerController),
      widget.pendingAttachments.length,
    ].join('|');
    if (_lastQuickPromptVisibilityLogKey == logKey) {
      return;
    }
    _lastQuickPromptVisibilityLogKey = logKey;
  }
}
