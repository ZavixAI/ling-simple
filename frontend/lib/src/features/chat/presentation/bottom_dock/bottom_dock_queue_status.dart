part of '../bottom_dock.dart';

extension _BottomDockQueueStatus on _LingCalendarBottomDockState {
  Color _queuedGuidanceBorderFor(BuildContext context, LingPalette palette) {
    return context.isDarkMode
        ? palette.glassBorder
        : palette.outlineSoft.withValues(alpha: 0.92);
  }

  List<BoxShadow> _queuedGuidanceShadowFor(
    BuildContext context,
    LingPalette palette,
  ) {
    if (context.isDarkMode) {
      return [
        BoxShadow(
          color: palette.shadow.withValues(alpha: 0.20),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
    }
    return [
      BoxShadow(
        color: palette.shadow.withValues(alpha: 0.045),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];
  }

  Widget _buildQueueActionButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    required LingPalette palette,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: LingLongPressScale(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(icon, size: 17, color: _mutedTextOnGlass(palette)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQueuedPromptCard(BuildContext context, LingPalette palette) {
    final previewText = widget.queuedPreviewText;
    if (widget.queuedCount <= 0 || previewText == null || previewText.isEmpty) {
      return const SizedBox.shrink();
    }
    final canViewQueue = widget.queuedOverflowCount > 0;
    final label = widget.queuedLabel;

    return Container(
      width: 340,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: _queuedGuidanceShadowFor(context, palette),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _queuedGuidanceBorderFor(context, palette),
          width: context.isDarkMode ? 0.9 : 0.7,
        ),
      ),
      child: LingGlassSurface(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        radius: 24,
        tone: LingGlassSurfaceTone.elevated,
        tintColor: lingGlassPanelTintFor(context, palette),
        child: Row(
          children: [
            Icon(Icons.schedule_send_rounded, color: palette.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canViewQueue ? widget.onViewQueuedMessages : null,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (label != null && label.isNotEmpty) ...[
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                previewText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _mutedTextOnGlass(palette),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (widget.queuedOverflowCount > 0) ...[
                              const SizedBox(width: 8),
                              LingGlassSurface(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                radius: 999,
                                tintColor: _surfaceFillFor(context, palette),
                                child: Text(
                                  '+${widget.queuedOverflowCount}',
                                  style: TextStyle(
                                    color: _mutedTextOnGlass(palette),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _buildQueueActionButton(
              tooltip: widget.applyQueuedMessageNowTooltip,
              icon: Icons.keyboard_return_rounded,
              onTap: widget.onApplyQueuedMessageNow,
              palette: palette,
            ),
            _buildQueueActionButton(
              tooltip: widget.deleteQueuedMessageTooltip,
              icon: Icons.delete_outline_rounded,
              onTap: widget.onDeleteQueuedMessage,
              palette: palette,
            ),
            _buildQueueActionButton(
              tooltip: widget.editQueuedMessageTooltip,
              icon: Icons.edit_rounded,
              onTap: widget.onEditQueuedMessage,
              palette: palette,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusyCard(BuildContext context, LingPalette palette) {
    return LingGlassSurface(
      width: 340,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 24,
      tintColor: _surfaceFillFor(context, palette),
      child: Row(
        children: [
          const GlassProgressIndicator.circular(size: 18, strokeWidth: 2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.busyLabel,
              style: TextStyle(
                color: _mutedTextOnGlass(palette),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
