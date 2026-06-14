import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/chat/application/conversation_entry.dart';
import 'package:ling/src/features/chat/presentation/conversation_viewport.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/tap_haptics.dart';

class LingConversationStartedAtLabel extends StatelessWidget {
  const LingConversationStartedAtLabel({
    super.key,
    required this.strings,
    required this.startedAt,
  });

  final LingStrings strings;
  final DateTime startedAt;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LingTimestampDividerLine(color: palette.dividerMuted),
          const SizedBox(width: 14),
          Text(
            formatLingConversationStartedAtLabel(
              strings: strings,
              startedAt: startedAt,
            ),
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
              color: palette.textTertiary,
            ),
          ),
          const SizedBox(width: 14),
          _LingTimestampDividerLine(color: palette.dividerMuted),
        ],
      ),
    );
  }
}

class LingConversationEntryMeta extends StatelessWidget {
  const LingConversationEntryMeta({
    super.key,
    required this.entry,
    required this.isUser,
    required this.canCopy,
    required this.canRetry,
    this.onCopy,
    this.onRetry,
  });

  final LingConversationEntry entry;
  final bool isUser;
  final bool canCopy;
  final bool canRetry;
  final Future<void> Function(LingConversationEntry entry)? onCopy;
  final Future<void> Function(LingConversationEntry entry)? onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = _lingStringsOf(context);
    final timeLabel = isUser
        ? ''
        : _formatLingEntryMetaTime(strings: strings, value: entry.createdAt);
    final showCopyButton = canCopy && onCopy != null;
    final showRetryButton = isUser && canRetry && onRetry != null;
    if ((isUser && !showCopyButton && !showRetryButton) ||
        (timeLabel.isEmpty && !showCopyButton && !showRetryButton)) {
      return const SizedBox.shrink();
    }
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (timeLabel.isNotEmpty)
          Text(
            timeLabel,
            style: TextStyle(
              color: palette.textSecondary.withValues(alpha: 0.85),
              fontSize: 10,
              height: 1.2,
            ),
          ),
        if (timeLabel.isNotEmpty && (showCopyButton || showRetryButton))
          const SizedBox(width: 4),
        if (showCopyButton)
          _LingEntryMetaIconButton(
            key: Key('conversation_meta_copy_${entry.id}'),
            tooltip: strings.copyAction,
            icon: Icons.content_copy_rounded,
            color: palette.textSecondary.withValues(alpha: 0.72),
            onPressed: () => onCopy?.call(entry),
          ),
        if (showRetryButton)
          _LingEntryMetaIconButton(
            key: Key('conversation_meta_retry_${entry.id}'),
            tooltip: strings.retryAction,
            icon: Icons.refresh_rounded,
            color: palette.textSecondary.withValues(alpha: 0.72),
            onPressed: () => onRetry?.call(entry),
          ),
      ],
    );
  }
}

class _LingEntryMetaIconButton extends StatelessWidget {
  const _LingEntryMetaIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      enabled: onPressed != null,
      child: IconButton(
        onPressed: LingTapHaptics.wrap(onPressed),
        icon: Icon(icon),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        iconSize: 13,
        color: color,
        visualDensity: VisualDensity.compact,
        style: const ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
          shadowColor: WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
    );
  }
}

class _LingTimestampDividerLine extends StatelessWidget {
  const _LingTimestampDividerLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('conversation_timestamp_divider_line'),
      width: 38,
      height: 1.5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

String _formatLingEntryMetaTime({
  required LingStrings strings,
  required DateTime? value,
}) {
  if (value == null) {
    return '';
  }
  final local = value.toLocal();
  final now = DateTime.now().toLocal();
  final sameDay =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  final minute = local.minute.toString().padLeft(2, '0');
  final timeLabel = strings.isZh
      ? '${local.hour}:$minute'
      : '${(local.hour % 12 == 0 ? 12 : local.hour % 12)}:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  if (sameDay) {
    return timeLabel;
  }
  if (strings.isZh) {
    return '${local.month}/${local.day} $timeLabel';
  }
  return '${local.month}/${local.day} $timeLabel';
}

LingStrings _lingStringsOf(BuildContext context) {
  final locale = Localizations.localeOf(context);
  final countryCode = locale.countryCode;
  final localeCode = countryCode == null || countryCode.isEmpty
      ? locale.languageCode
      : '${locale.languageCode}-$countryCode';
  return LingStrings(localeCode);
}
