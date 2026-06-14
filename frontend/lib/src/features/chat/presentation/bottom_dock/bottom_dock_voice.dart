part of '../bottom_dock.dart';

extension _BottomDockVoice on _LingCalendarBottomDockState {
  Widget _buildVoiceDraftReviewPill(
    LingPalette palette, {
    required double height,
  }) {
    return _withDockControlBorder(
      context: context,
      palette: palette,
      radius: 999,
      child: LingGlassSurface(
        key: const Key('bottom_dock_voice_draft_review_pill'),
        height: height,
        radius: 999,
        tone: LingGlassSurfaceTone.control,
        tintColor: _composerFillFor(context, palette),
        quality: LingGlassQuality.premium,
        useOwnLayer: false,
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: LingVoicePreviewControl(
                  source: widget.voiceDraftAudioPath,
                  compact: true,
                  embedded: true,
                  fillWidth: true,
                  onPlay: widget.onPlayVoiceDraftPreview,
                  onLoadDuration: widget.onLoadVoiceDraftPreviewDuration,
                  onStop: widget.onStopVoiceDraftPreview,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _LingPlainDockIconButton(
              buttonKey: const Key('bottom_dock_cancel_voice_draft_button'),
              tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
              icon: Icons.close_rounded,
              onTap: _handleCancelVoiceDraft,
              size: 40,
              iconSize: 24,
              iconColor: _textOnGlass(palette),
              disabledIconColor: palette.textSecondary,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineVoiceWaveform(
    LingPalette palette, {
    required double actionSize,
  }) {
    final waveformColor = widget.isRecording
        ? palette.accent
        : _mutedTextOnGlass(palette);
    final previewText = _latestVoicePreviewLine(widget.voiceDraftTranscript);
    return SizedBox(
      height: actionSize,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Center(
                child: _LingVoiceLevelBars(
                  key: const Key('bottom_dock_voice_waveform'),
                  active: widget.isRecording,
                  color: waveformColor,
                ),
              ),
            ),
            if (previewText.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                previewText,
                key: const Key('bottom_dock_voice_inline_transcript'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _mutedTextOnGlass(palette),
                  fontSize: 12,
                  height: 1.05,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceInputPill(LingPalette palette, {required double height}) {
    final canTap =
        widget.canVoiceTap &&
        (widget.isVoiceActive ||
            (!widget.isBusy && !widget.isConversationRestoring));
    final label = widget.voiceTooltip;
    final voiceForeground = _voiceInputForegroundFor(palette);
    final voiceIconColor = _voiceInputIconFor(palette);
    return LingGlassButton(
      key: const Key('bottom_dock_voice_input_pill'),
      onPressed: canTap ? widget.onVoiceTap : null,
      minHeight: height,
      radius: 999,
      tone: LingGlassSurfaceTone.control,
      foregroundColor: voiceForeground,
      tintColor: _transparentButtonTintFor(context, palette),
      glowColor: palette.glassHighlight,
      quality: LingGlassQuality.premium,
      interactionScale: canTap ? 1.01 : 1,
      stretch: canTap ? 0.04 : 0,
      child: Center(
        child: widget.isVoiceActive
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _buildInlineVoiceWaveform(palette, actionSize: height),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic_rounded, size: 18, color: voiceIconColor),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: voiceForeground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _latestVoicePreviewLine(String transcript) {
    final text = transcript.trim();
    if (text.isEmpty) {
      return '';
    }

    final sentenceMatch = RegExp(
      r'[^。！？.!?\n\r]+[。！？.!?]*\s*$',
    ).firstMatch(text);
    return sentenceMatch?.group(0)?.trim() ?? text;
  }

  void _handleCancelVoiceDraft() {
    widget.onCancelVoiceDraft();
  }
}

class _LingVoiceLevelBars extends StatefulWidget {
  const _LingVoiceLevelBars({
    super.key,
    required this.active,
    required this.color,
  });

  final bool active;
  final Color color;

  @override
  State<_LingVoiceLevelBars> createState() => _LingVoiceLevelBarsState();
}

class _LingVoiceLevelBarsState extends State<_LingVoiceLevelBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _LingVoiceLevelBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _controller.repeat();
      return;
    }
    if (oldWidget.active && !widget.active) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedWidth = constraints.maxWidth.isFinite;
          final availableWidth = hasBoundedWidth ? constraints.maxWidth : 60.0;
          final barCount = hasBoundedWidth
              ? math.max(1, (availableWidth / 4).floor())
              : 12;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.max,
                children: List<Widget>.generate(barCount, (index) {
                  final progress = _controller.value;
                  final phase = progress * math.pi * 2 + index * 0.38;
                  final normalized = (math.sin(phase) + 1) / 2;
                  final barHeight = widget.active ? 4 + normalized * 13 : 4.0;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == barCount - 1 ? 0 : 2,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 2,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              );
            },
          );
        },
      ),
    );
  }
}
