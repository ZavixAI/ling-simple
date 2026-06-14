part of '../bottom_dock.dart';

extension _BottomDockAttachments on _LingCalendarBottomDockState {
  Widget _buildAttachmentImage(
    BuildContext context,
    LingPalette palette,
    LingConversationAttachment attachment,
    double size,
  ) {
    final cacheSize = math.max(
      1,
      (size * MediaQuery.devicePixelRatioOf(context)).round(),
    );
    if (attachment.bytes != null) {
      return Image.memory(
        attachment.bytes!,
        fit: BoxFit.cover,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        filterQuality: FilterQuality.low,
      );
    }
    if (attachment.url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: attachment.url,
        fit: BoxFit.cover,
        memCacheWidth: cacheSize,
        memCacheHeight: cacheSize,
        placeholder: (context, url) => ColoredBox(color: palette.surfaceMuted),
        errorWidget: (context, url, error) =>
            ColoredBox(color: palette.surfaceMuted),
      );
    }
    return ColoredBox(color: palette.surfaceMuted);
  }

  Widget _buildAttachmentThumbnail(
    BuildContext context,
    LingPalette palette,
    LingConversationAttachment attachment, {
    required double size,
    required bool showRemove,
  }) {
    final deleteTooltip = MaterialLocalizations.of(context).deleteButtonTooltip;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                size <= _inlineAttachmentSize ? 12 : 14,
              ),
              border: Border.all(color: _attachmentBorderFor(context, palette)),
              boxShadow: _quickPromptTagShadowFor(context, palette),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                size <= _inlineAttachmentSize ? 11 : 13,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.onPreviewAttachment(attachment),
                  child: _buildAttachmentImage(
                    context,
                    palette,
                    attachment,
                    size,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showRemove)
          Positioned(
            top: -5,
            right: -5,
            child: _LingAttachmentRemoveButton(
              buttonKey: const Key('bottom_dock_remove_attachment_button'),
              tooltip: deleteTooltip,
              onTap: () => widget.onRemoveAttachment(attachment),
            ),
          ),
      ],
    );
  }

  Widget _buildAttachmentDrawer(BuildContext context, LingPalette palette) {
    return SizedBox(
      key: const Key('bottom_dock_attachment_drawer'),
      height: _attachmentDrawerHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: _composerFillFor(
            context,
            palette,
          ).withValues(alpha: context.isDarkMode ? 0.62 : 0.70),
          border: Border.all(color: _attachmentBorderFor(context, palette)),
          boxShadow: _dockControlShadowFor(context, palette),
        ),
        child: Center(
          child: SizedBox(
            height: _attachmentThumbnailSize,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ReorderableListView.builder(
                key: const Key('bottom_dock_attachment_reorder_list'),
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) {
                  return ScaleTransition(
                    scale: Tween<double>(begin: 1, end: 1.04).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: child,
                  );
                },
                itemCount: widget.pendingAttachments.length,
                onReorderItem: (oldIndex, newIndex) {
                  final nextAttachments = widget.pendingAttachments.toList(
                    growable: true,
                  );
                  final attachment = nextAttachments.removeAt(oldIndex);
                  nextAttachments.insert(newIndex, attachment);
                  widget.onReorderAttachments(nextAttachments);
                },
                itemBuilder: (context, index) {
                  final attachment = widget.pendingAttachments[index];
                  return Padding(
                    key: ValueKey(
                      'bottom_dock_attachment_${attachment.attachmentId}',
                    ),
                    padding: EdgeInsets.only(
                      right: index == widget.pendingAttachments.length - 1
                          ? 0
                          : 10,
                    ),
                    child: ReorderableDragStartListener(
                      index: index,
                      child: _buildAttachmentThumbnail(
                        context,
                        palette,
                        attachment,
                        size: _attachmentThumbnailSize,
                        showRemove: true,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LingAttachmentRemoveButton extends StatelessWidget {
  const _LingAttachmentRemoveButton({
    required this.buttonKey,
    required this.tooltip,
    required this.onTap,
  });

  final Key buttonKey;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return KeyedSubtree(
      key: buttonKey,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Tooltip(
          message: tooltip,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: LingTapHaptics.wrap(onTap),
            child: SizedBox.square(
              dimension: 28,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isDark ? 0.92 : 0.96),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.18 : 0.08,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.28 : 0.14,
                        ),
                        blurRadius: isDark ? 8 : 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: SizedBox.square(
                    dimension: 24,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.black.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
