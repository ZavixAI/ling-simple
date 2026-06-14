import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/chat/application/conversation_entry.dart';
import 'package:ling/src/features/chat/presentation/conversation_tool_call_cards.dart';
import 'package:ling/src/features/chat/presentation/conversation_tool_call_display.dart';
import 'package:ling/src/features/chat/presentation/conversation_viewport.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';

class LingToolFlowGroupView extends StatefulWidget {
  const LingToolFlowGroupView({
    super.key,
    required this.group,
    required this.strings,
    this.onOpenLingEvent,
  });

  final LingToolFlowGroup group;
  final LingStrings strings;
  final ValueChanged<String>? onOpenLingEvent;

  @override
  State<LingToolFlowGroupView> createState() => _LingToolFlowGroupViewState();
}

class _LingToolFlowGroupViewState extends State<LingToolFlowGroupView> {
  late bool _isExpanded;
  final Set<String> _expandedInlineToolCards = <String>{};

  @override
  void initState() {
    super.initState();
    _isExpanded = !widget.group.isArchived;
  }

  @override
  void didUpdateWidget(covariant LingToolFlowGroupView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.id != widget.group.id) {
      _isExpanded = !widget.group.isArchived;
      _expandedInlineToolCards.clear();
      return;
    }
    if (!oldWidget.group.isArchived && widget.group.isArchived) {
      _isExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.group.entries;
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final summaries = _buildGroupedSummaries(
      strings: widget.strings,
      entries: entries,
      externallyExpandedToolCardEntryIds: widget.group.expandedToolCardEntryIds,
    );
    final collapsedTitle = widget.group.isArchived
        ? widget.strings.toolFlowCollapsedTitle
        : widget.strings.toolFlowRunningTitle;

    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LingToolFlowTitle(
                    title: collapsedTitle,
                    startedAt: widget.group.startedAt,
                    completedAt: widget.group.completedAt,
                    isRunning: widget.group.isElapsedRunning,
                    isExpanded: _isExpanded,
                    strings: widget.strings,
                    maxLines: _isExpanded ? 3 : 1,
                  ),
                  if (_isExpanded) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(summaries.length, (index) {
                          final item = summaries[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: _LingCompactToolCallRow(
                              kind: item.kind,
                              status: item.status,
                              summary: item.summary,
                              durationLabel: widget.strings.formatToolDuration(
                                item.durationMs,
                              ),
                              display: item.display,
                              isExpanded: item.entryId == null
                                  ? false
                                  : _expandedInlineToolCards.contains(
                                      item.entryId,
                                    ),
                              onToggleExpanded:
                                  item.entryId == null || item.display == null
                                  ? null
                                  : () => setState(() {
                                      if (!_expandedInlineToolCards.add(
                                        item.entryId!,
                                      )) {
                                        _expandedInlineToolCards.remove(
                                          item.entryId,
                                        );
                                      }
                                    }),
                              onOpenLingEvent: widget.onOpenLingEvent,
                              hasLeadingConnector: index > 0,
                              hasTrailingConnector:
                                  index < summaries.length - 1,
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LingToolFlowTitle extends StatefulWidget {
  const _LingToolFlowTitle({
    required this.title,
    required this.startedAt,
    required this.completedAt,
    required this.isRunning,
    required this.isExpanded,
    required this.strings,
    required this.maxLines,
  });

  final String title;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool isRunning;
  final bool isExpanded;
  final LingStrings strings;
  final int maxLines;

  @override
  State<_LingToolFlowTitle> createState() => _LingToolFlowTitleState();
}

class _LingToolFlowTitleState extends State<_LingToolFlowTitle> {
  Timer? _timer;
  DateTime? _settledAt;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _settledAt = widget.isRunning ? null : widget.completedAt;
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _LingToolFlowTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) {
      _settledAt = widget.isRunning ? null : widget.completedAt;
    } else if (oldWidget.isRunning && !widget.isRunning) {
      _settledAt = widget.completedAt ?? DateTime.now();
    } else if (!widget.isRunning && _settledAt == null) {
      _settledAt = widget.completedAt;
    }
    _now = DateTime.now();
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    if (!widget.isRunning) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _now = DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final elapsedLabel = _formatToolFlowElapsedLabel(
      strings: widget.strings,
      startedAt: widget.startedAt,
      endedAt: widget.isRunning ? _now : _settledAt ?? widget.completedAt,
    );
    final titleText = elapsedLabel == null
        ? widget.title
        : '${widget.title} · $elapsedLabel';

    return Text.rich(
      TextSpan(
        text: titleText,
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w500,
        ),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(
                widget.isExpanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.chevron_right_rounded,
                size: 13,
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

String? _formatToolFlowElapsedLabel({
  required LingStrings strings,
  required DateTime? startedAt,
  required DateTime? endedAt,
}) {
  if (startedAt == null || endedAt == null) {
    return null;
  }
  final elapsedSeconds = endedAt.difference(startedAt).inSeconds;
  final clampedSeconds = elapsedSeconds < 0 ? 0 : elapsedSeconds;
  return strings.toolFlowElapsedSeconds(clampedSeconds);
}

List<_LingToolFlowSummaryItem> _buildGroupedSummaries({
  required LingStrings strings,
  required List<LingConversationEntry> entries,
  required Set<String> externallyExpandedToolCardEntryIds,
}) {
  final summaries = <_LingToolFlowSummaryItem>[];
  for (final entry in entries) {
    if (entry.entryType == LingConversationEntryType.assistantMessage) {
      final textSummary = _extractAssistantTextSummary(entry.text);
      if (textSummary != null) {
        summaries.add(
          _LingToolFlowSummaryItem(
            kind: _LingToolFlowSummaryKind.content,
            status: _LingToolFlowStatus.completed,
            toolName: '__assistant_text__',
            isRunning: false,
            count: 1,
            durationMs: null,
            summary: textSummary,
          ),
        );
      }
      continue;
    }
    final toolName = (entry.toolName ?? '').trim();
    final status = _resolveToolFlowStatus(entry);
    final isRunning = status == _LingToolFlowStatus.running;
    final durationMs = entry.durationMs;
    final display = buildLingToolCallDisplayState(entry);
    if (display.hasCard &&
        !externallyExpandedToolCardEntryIds.contains(entry.id)) {
      summaries.add(
        _LingToolFlowSummaryItem(
          kind: _LingToolFlowSummaryKind.toolCard,
          status: status,
          toolName: toolName,
          isRunning: isRunning,
          count: 1,
          durationMs: durationMs,
          summary: _toolCardCollapsedSummary(
            strings: strings,
            display: display,
            fallbackToolName: toolName,
          ),
          entryId: entry.id,
          display: display,
        ),
      );
      continue;
    }
    if (summaries.isNotEmpty) {
      final previous = summaries.last;
      if (previous.kind == _LingToolFlowSummaryKind.tool &&
          previous.toolName == toolName &&
          previous.status == status) {
        final nextCount = previous.count + 1;
        final nextDurationMs = (previous.durationMs ?? 0) + (durationMs ?? 0);
        summaries[summaries.length - 1] = previous.copyWith(
          count: nextCount,
          durationMs: nextDurationMs == 0 ? null : nextDurationMs,
          summary: strings.toolCallGroupedSummary(
            toolName,
            count: nextCount,
            isRunning: isRunning,
          ),
        );
        continue;
      }
    }
    summaries.add(
      _LingToolFlowSummaryItem(
        kind: _LingToolFlowSummaryKind.tool,
        status: status,
        toolName: toolName,
        isRunning: isRunning,
        count: 1,
        durationMs: durationMs,
        summary: strings.toolCallGroupedSummary(
          toolName,
          count: 1,
          isRunning: isRunning,
        ),
      ),
    );
  }
  return summaries;
}

String? _extractAssistantTextSummary(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final singleLine = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (singleLine.isEmpty) {
    return null;
  }
  return singleLine.length > 96
      ? '${singleLine.substring(0, 96)}...'
      : singleLine;
}

String _toolCardCollapsedSummary({
  required LingStrings strings,
  required LingToolCallDisplayState display,
  required String fallbackToolName,
}) {
  final calendar = display.calendarData;
  if (calendar != null) {
    return [
      strings.isZh ? '日程' : 'Calendar',
      calendar.title,
      if (calendar.startAt.isNotEmpty) _compactDateTime(calendar.startAt),
      if (calendar.location.isNotEmpty) calendar.location,
    ].where((item) => item.trim().isNotEmpty).join(' · ');
  }

  final weather = display.weatherData;
  if (weather != null && weather.forecasts.isNotEmpty) {
    final today = weather.forecasts.first;
    final city = weather.city.isEmpty
        ? (strings.isZh ? '天气' : 'Weather')
        : (strings.isZh ? '${weather.city}天气' : 'Weather in ${weather.city}');
    final forecastCount = weather.forecasts.length;
    final forecastLabel = strings.isZh
        ? '$forecastCount 天预报'
        : '$forecastCount-day forecast';
    return [
      city,
      if (today.dayWeather.isNotEmpty) today.dayWeather,
      _weatherTempRange(today),
      forecastLabel,
    ].where((item) => item.trim().isNotEmpty).join(' · ');
  }

  final flights = display.travelFlightData;
  if (flights != null) {
    if (flights.flights.isNotEmpty) {
      final first = flights.flights.first;
      return [
        strings.isZh ? '航班选项' : 'Flight options',
        if (first.airline.isNotEmpty || first.flightNo.isNotEmpty)
          [
            first.airline,
            first.flightNo,
          ].where((item) => item.trim().isNotEmpty).join(' '),
        if (first.routeLabel.isNotEmpty) first.routeLabel,
        if (first.priceLabel.isNotEmpty)
          strings.isZh ? '${first.priceLabel} 起' : 'from ${first.priceLabel}',
      ].where((item) => item.trim().isNotEmpty).join(' · ');
    }
  }

  final hotels = display.travelHotelData;
  if (hotels != null) {
    final first = hotels.hotels.isEmpty ? null : hotels.hotels.first;
    return [
      strings.isZh ? '酒店选项' : 'Hotel options',
      if (first?.name.trim().isNotEmpty ?? false) first!.name,
      if (first?.priceLabel.trim().isNotEmpty ?? false) first!.priceLabel,
    ].where((item) => item.trim().isNotEmpty).join(' · ');
  }

  return strings.toolCallDisplayName(fallbackToolName);
}

String _compactDateTime(String value) {
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2})[T\s](\d{2}:\d{2})',
  ).firstMatch(value);
  if (match == null) {
    return value;
  }
  return '${match.group(1)} ${match.group(2)}';
}

String _weatherTempRange(LingWeatherForecastDay forecast) {
  final low = forecast.nightTemp;
  final high = forecast.dayTemp;
  if (low.isEmpty && high.isEmpty) {
    return '';
  }
  if (low.isEmpty) {
    return '$high°';
  }
  if (high.isEmpty) {
    return '$low°';
  }
  return '$low°-$high°';
}

_LingToolFlowStatus _resolveToolFlowStatus(LingConversationEntry entry) {
  if (entry.isStreaming || entry.status.trim() == 'running') {
    return _LingToolFlowStatus.running;
  }
  final status = entry.status.trim().toLowerCase();
  if (status.contains('fail') ||
      status.contains('error') ||
      status.contains('cancel')) {
    return _LingToolFlowStatus.failed;
  }
  return _LingToolFlowStatus.completed;
}

class _LingCompactToolCallRow extends StatelessWidget {
  const _LingCompactToolCallRow({
    required this.kind,
    required this.status,
    required this.summary,
    required this.durationLabel,
    required this.display,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onOpenLingEvent,
    required this.hasLeadingConnector,
    required this.hasTrailingConnector,
  });

  final _LingToolFlowSummaryKind kind;
  final _LingToolFlowStatus status;
  final String summary;
  final String durationLabel;
  final LingToolCallDisplayState? display;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;
  final ValueChanged<String>? onOpenLingEvent;
  final bool hasLeadingConnector;
  final bool hasTrailingConnector;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = durationLabel.isEmpty ? summary : '$summary · $durationLabel';
    final isToolCard = kind == _LingToolFlowSummaryKind.toolCard;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 14,
          child: Column(
            children: [
              SizedBox(
                height: 14,
                child: Align(
                  alignment: Alignment.center,
                  child:
                      kind == _LingToolFlowSummaryKind.tool ||
                          kind == _LingToolFlowSummaryKind.toolCard
                      ? Icon(
                          isToolCard
                              ? (isExpanded
                                    ? Icons.keyboard_arrow_down_rounded
                                    : Icons.chevron_right_rounded)
                              : switch (status) {
                                  _LingToolFlowStatus.completed =>
                                    Icons.check_circle_rounded,
                                  _LingToolFlowStatus.failed =>
                                    Icons.warning_amber_rounded,
                                  _LingToolFlowStatus.running =>
                                    Icons.circle_rounded,
                                },
                          size: isToolCard
                              ? 13
                              : status == _LingToolFlowStatus.running
                              ? 7
                              : 11,
                          color: isToolCard
                              ? palette.textSecondary.withValues(alpha: 0.78)
                              : switch (status) {
                                  _LingToolFlowStatus.completed =>
                                    palette.success,
                                  _LingToolFlowStatus.failed => palette.warning,
                                  _LingToolFlowStatus.running =>
                                    palette.textSecondary.withValues(
                                      alpha: 0.42,
                                    ),
                                },
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              _LingToolFlowConnector(
                visible: hasLeadingConnector || hasTrailingConnector,
                color: palette.textSecondary.withValues(alpha: 0.10),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Padding(
            padding: EdgeInsets.only(
              top: kind == _LingToolFlowSummaryKind.tool ? 0 : 0.5,
            ),
            child: Text(
              text,
              style: TextStyle(
                color: kind == _LingToolFlowSummaryKind.content
                    ? palette.textSecondary.withValues(alpha: 0.82)
                    : palette.textSecondary,
                fontSize: kind == _LingToolFlowSummaryKind.content ? 10 : 11,
                height: kind == _LingToolFlowSummaryKind.content ? 1.35 : 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(left: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onToggleExpanded == null)
            row
          else
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onToggleExpanded,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: row,
              ),
            ),
          if (isExpanded && display != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 4),
              child: LingToolCallEntryCard(
                display: display!,
                onOpenLingEvent: onOpenLingEvent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LingToolFlowConnector extends StatelessWidget {
  const _LingToolFlowConnector({required this.visible, required this.color});

  final bool visible;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox(height: 0);
    }
    return Container(
      width: 1,
      height: 6,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

enum _LingToolFlowSummaryKind { tool, content, toolCard }

enum _LingToolFlowStatus { running, completed, failed }

class _LingToolFlowSummaryItem {
  const _LingToolFlowSummaryItem({
    required this.kind,
    required this.status,
    required this.toolName,
    required this.isRunning,
    required this.count,
    required this.durationMs,
    required this.summary,
    this.entryId,
    this.display,
  });

  final _LingToolFlowSummaryKind kind;
  final _LingToolFlowStatus status;
  final String toolName;
  final bool isRunning;
  final int count;
  final int? durationMs;
  final String summary;
  final String? entryId;
  final LingToolCallDisplayState? display;

  _LingToolFlowSummaryItem copyWith({
    _LingToolFlowSummaryKind? kind,
    _LingToolFlowStatus? status,
    String? toolName,
    bool? isRunning,
    int? count,
    int? durationMs,
    String? summary,
    String? entryId,
    LingToolCallDisplayState? display,
  }) {
    return _LingToolFlowSummaryItem(
      kind: kind ?? this.kind,
      status: status ?? this.status,
      toolName: toolName ?? this.toolName,
      isRunning: isRunning ?? this.isRunning,
      count: count ?? this.count,
      durationMs: durationMs ?? this.durationMs,
      summary: summary ?? this.summary,
      entryId: entryId ?? this.entryId,
      display: display ?? this.display,
    );
  }
}
