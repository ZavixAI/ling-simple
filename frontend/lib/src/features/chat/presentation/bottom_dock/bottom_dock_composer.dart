part of '../bottom_dock.dart';

extension _BottomDockComposer on _LingCalendarBottomDockState {
  static const EdgeInsets _composerTextPadding = EdgeInsets.fromLTRB(
    14,
    13,
    12,
    13,
  );

  Widget _buildCollapsedComposerInput(
    BuildContext context,
    LingPalette palette, {
    required double height,
  }) {
    final canUseComposer = !widget.isConversationRestoring;
    final radius = height > _collapsedDockHeight + 8 ? 22.0 : 999.0;
    return KeyedSubtree(
      key: _collapsedComposerInputKey,
      child: _withDockControlBorder(
        context: context,
        palette: palette,
        radius: radius,
        child: LingGlassSurface(
          height: height,
          radius: radius,
          tone: LingGlassSurfaceTone.control,
          tintColor: _composerFillFor(context, palette),
          quality: LingGlassQuality.premium,
          useOwnLayer: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Padding(
                  padding: _composerTextPadding,
                  child: _buildComposerTextField(
                    palette,
                    height: height,
                    canUseComposer: canUseComposer,
                  ),
                ),
              ),
              if (!_usesOuterSendButton && _hasSendableDraft)
                if (!_canStopAgentReply)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SizedBox(
                      height: height,
                      child: Center(
                        child: _buildEmbeddedSendButton(palette, size: 34),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposerTextField(
    LingPalette palette, {
    required double height,
    required bool canUseComposer,
  }) {
    final controller = widget.composerController;
    return TextField(
      key: const Key('bottom_dock_collapsed_composer_text_field'),
      controller: controller,
      focusNode: widget.composerFocusNode,
      enabled: canUseComposer,
      cursorColor: palette.inputCursor,
      cursorWidth: 2,
      cursorRadius: const Radius.circular(999),
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.send,
      textAlignVertical: height <= _collapsedDockHeight
          ? TextAlignVertical.center
          : TextAlignVertical.top,
      minLines: null,
      maxLines: null,
      expands: true,
      style: TextStyle(
        fontSize: _composerFontSize,
        height: _composerHeightMultiplier,
        color: palette.inputForeground,
      ),
      strutStyle: const StrutStyle(
        fontSize: _composerFontSize,
        height: _composerHeightMultiplier,
        forceStrutHeight: true,
      ),
      decoration: InputDecoration(
        hintText: widget.composerPlaceholder,
        hintStyle: TextStyle(
          color: palette.inputPlaceholder,
          fontSize: 15,
          height: 1.1,
        ),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
      ),
      onTap: widget.onKeyboardTap,
      scrollController: widget.composerScrollController,
      scrollPadding: EdgeInsets.zero,
      scrollPhysics: const ClampingScrollPhysics(),
      clipBehavior: Clip.hardEdge,
      onSubmitted: (_) {
        if (_canSubmit && _hasSendableDraft) {
          widget.onSubmitText();
        }
      },
    );
  }

  Widget _buildEmbeddedSendButton(LingPalette palette, {required double size}) {
    return _LingPlainDockIconButton(
      buttonKey: const ValueKey('bottom_dock_send_button'),
      tooltip: widget.sendMessageTooltip,
      icon: Icons.send_rounded,
      onTap: _canSubmit ? widget.onSubmitText : null,
      size: size,
      iconSize: 19,
      iconColor: _canSubmit ? palette.accent : _mutedTextOnGlass(palette),
      disabledIconColor: palette.textSecondary,
    );
  }

  int _estimateComposerLineCount(BuildContext context, double maxWidth) {
    final text = widget.composerController.text;
    if (text.trim().isEmpty && widget.pendingObjectReferences.isEmpty) {
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
