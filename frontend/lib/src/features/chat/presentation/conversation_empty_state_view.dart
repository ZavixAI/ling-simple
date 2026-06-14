import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';

class LingConversationStarterTask {
  const LingConversationStarterTask({
    required this.label,
    required this.subtitle,
    required this.prompt,
  });

  final String label;
  final String subtitle;
  final String prompt;
}

class LingCalendarConversationEmptyStateView extends StatelessWidget {
  const LingCalendarConversationEmptyStateView({
    super.key,
    required this.welcomeLead,
    required this.welcomeBrand,
    required this.description,
    this.contextSummary,
    this.starterTasks = const <LingConversationStarterTask>[],
    this.onStarterTaskTap,
  });

  final String welcomeLead;
  final String welcomeBrand;
  final String description;
  final String? contextSummary;
  final List<LingConversationStarterTask> starterTasks;
  final ValueChanged<String>? onStarterTaskTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - 48)
                  .clamp(0.0, double.infinity)
                  .toDouble()
            : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420, minHeight: minHeight),
              child: Center(
                child: Semantics(
                  container: true,
                  child: Column(
                    key: const Key('conversation_empty_state'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        key: const Key('conversation_empty_logo'),
                        width: 92,
                        height: 92,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.surface,
                          border: Border.all(color: palette.outlineSoft),
                          boxShadow: [
                            BoxShadow(
                              color: palette.shadow,
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/branding/logo-circle.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  color: palette.accentSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  color: palette.accent,
                                  size: 36,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text.rich(
                        TextSpan(
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(text: '$welcomeLead '),
                            TextSpan(
                              text: welcomeBrand,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: palette.textSecondary,
                          height: 1.7,
                        ),
                      ),
                      if ((contextSummary ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          contextSummary!.trim(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.textSecondary.withValues(
                              alpha: 0.72,
                            ),
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (starterTasks.isNotEmpty &&
                          onStarterTaskTap != null) ...[
                        const SizedBox(height: 22),
                        LingConversationStarterTaskList(
                          starterTasks: starterTasks,
                          onStarterTaskTap: onStarterTaskTap!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class LingConversationStarterTaskList extends StatelessWidget {
  const LingConversationStarterTaskList({
    super.key,
    required this.starterTasks,
    required this.onStarterTaskTap,
  });

  final List<LingConversationStarterTask> starterTasks;
  final ValueChanged<String> onStarterTaskTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('conversation_starter_tasks'),
      children: [
        for (var index = 0; index < starterTasks.length; index++) ...[
          _StarterTaskCard(
            task: starterTasks[index],
            onTap: () => onStarterTaskTap(starterTasks[index].prompt),
          ),
          if (index != starterTasks.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _StarterTaskCard extends StatelessWidget {
  const _StarterTaskCard({required this.task, required this.onTap});

  final LingConversationStarterTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('conversation_starter_task_${task.label}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surfaceMuted.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.outlineSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        task.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
