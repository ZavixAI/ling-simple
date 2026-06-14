import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/chat/application/pending_prompt_request.dart';
import 'package:ling/src/features/chat/presentation/conversation_card_chrome.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

class LingConversationLoadMoreButton extends StatelessWidget {
  const LingConversationLoadMoreButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Center(
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: lingConversationFloatingEdgeBorderFor(
              context,
              palette,
              strength: 0.64,
            ),
          ),
          child: LingGlassButton(
            onPressed: onPressed,
            expand: false,
            minHeight: 44,
            radius: 999,
            tone: LingGlassSurfaceTone.muted,
            foregroundColor: palette.textSecondary,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.expand_less_rounded, size: 18),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showLingQueuedPromptSheet({
  required BuildContext context,
  required List<LingPendingPromptRequest> queuedItems,
  required String title,
  required String cancelLabel,
  required String applyNowTooltip,
  required String deleteTooltip,
  required String editTooltip,
  required String Function(LingPendingPromptRequest request) previewBuilder,
  required String Function(int attachmentCount) queuedImageLabelBuilder,
  required ValueChanged<LingPendingPromptRequest> onDelete,
  required ValueChanged<LingPendingPromptRequest> onApplyNow,
  required ValueChanged<LingPendingPromptRequest> onEdit,
}) {
  return showLingAdaptiveSheet<void>(
    context: context,
    builder: (sheetContext) {
      final palette = sheetContext.palette;
      final theme = Theme.of(sheetContext);
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title, style: theme.textTheme.titleMedium),
                      ),
                      LingGlassButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        expand: false,
                        minHeight: 40,
                        radius: 999,
                        tone: LingGlassSurfaceTone.muted,
                        foregroundColor: palette.textSecondary,
                        child: Text(cancelLabel),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    itemCount: queuedItems.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: palette.outlineSoft),
                    itemBuilder: (context, index) {
                      final request = queuedItems[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        leading: LingGlassSurface(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          radius: 999,
                          tone: LingGlassSurfaceTone.muted,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          previewBuilder(request),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LingGlassIconButton(
                              semanticLabel: applyNowTooltip,
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                onApplyNow(request);
                              },
                              icon: Icons.keyboard_return_rounded,
                              size: 34,
                              iconSize: 18,
                            ),
                            LingGlassIconButton(
                              semanticLabel: deleteTooltip,
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                onDelete(request);
                              },
                              icon: Icons.delete_outline_rounded,
                              size: 34,
                              iconSize: 18,
                            ),
                            LingGlassIconButton(
                              semanticLabel: editTooltip,
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                onEdit(request);
                              },
                              icon: Icons.edit_rounded,
                              size: 34,
                              iconSize: 18,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
