import 'package:ling/src/features/chat/application/conversation_entry.dart';
import 'package:ling/src/features/chat/application/tool_call_result_mapper.dart';
import 'package:ling/src/features/chat/presentation/conversation_tool_call_display.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';

const int _maxExpandedToolCardsPerAssistantTurn = 3;

enum LingConversationRenderItemType { timestamp, entry, toolFlow }

class LingToolFlowGroup {
  const LingToolFlowGroup({
    required this.id,
    required this.entries,
    required this.isArchived,
    this.expandedToolCardEntryIds = const <String>{},
    this.startedAt,
    this.completedAt,
    this.isElapsedRunning = false,
  });

  final String id;
  final List<LingConversationEntry> entries;
  final bool isArchived;
  final Set<String> expandedToolCardEntryIds;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool isElapsedRunning;
}

class LingConversationRenderItem {
  const LingConversationRenderItem.timestamp({
    required this.id,
    required this.timestamp,
    required this.sourceEntryId,
  }) : type = LingConversationRenderItemType.timestamp,
       entry = null,
       toolFlowGroup = null;

  const LingConversationRenderItem.entry({
    required this.id,
    required this.entry,
  }) : type = LingConversationRenderItemType.entry,
       sourceEntryId = null,
       timestamp = null,
       toolFlowGroup = null;

  const LingConversationRenderItem.toolFlow({
    required this.id,
    required this.toolFlowGroup,
  }) : type = LingConversationRenderItemType.toolFlow,
       sourceEntryId = null,
       timestamp = null,
       entry = null;

  final String id;
  final String? sourceEntryId;
  final LingConversationRenderItemType type;
  final DateTime? timestamp;
  final LingConversationEntry? entry;
  final LingToolFlowGroup? toolFlowGroup;

  bool get isTimestamp => type == LingConversationRenderItemType.timestamp;
  bool get isEntry => type == LingConversationRenderItemType.entry;
  bool get isToolFlow => type == LingConversationRenderItemType.toolFlow;
}

class LingConversationViewport {
  const LingConversationViewport({
    required this.visibleEntries,
    required this.renderedItems,
    required this.hasOlderEntries,
    required this.hiddenEntryCount,
    required this.itemCount,
  });

  final List<LingConversationEntry> visibleEntries;
  final List<LingConversationRenderItem> renderedItems;
  final bool hasOlderEntries;
  final int hiddenEntryCount;
  final int itemCount;

  List<LingConversationEntry> get renderedEntries => renderedItems
      .map((item) => item.entry)
      .whereType<LingConversationEntry>()
      .toList(growable: false);
}

class _LingToolCardCandidate {
  const _LingToolCardCandidate({
    required this.entry,
    required this.display,
    required this.index,
  });

  final LingConversationEntry entry;
  final LingToolCallDisplayState display;
  final int index;
}

List<LingConversationEntry> buildLingVisibleConversationEntries({
  required List<LingConversationEntry> conversation,
  required int visibleConversationEntryCount,
}) {
  if (conversation.length <= visibleConversationEntryCount) {
    return List<LingConversationEntry>.from(conversation, growable: false);
  }
  final startIndex = conversation.length - visibleConversationEntryCount;
  return conversation.sublist(startIndex);
}

LingConversationViewport buildLingConversationViewport({
  required List<LingConversationEntry> conversation,
  required int visibleConversationEntryCount,
}) {
  final renderableConversation = conversation
      .where((entry) => !entry.isHiddenError)
      .toList(growable: false);
  final visibleEntries = buildLingVisibleConversationEntries(
    conversation: renderableConversation,
    visibleConversationEntryCount: visibleConversationEntryCount,
  );
  final hasOlderEntries = renderableConversation.length > visibleEntries.length;
  final renderedItems = buildLingConversationRenderItems(
    visibleEntries: visibleEntries,
  );
  final hiddenEntryCount =
      renderableConversation.length - visibleEntries.length;
  final itemCount = renderedItems.length + (hasOlderEntries ? 1 : 0);
  return LingConversationViewport(
    visibleEntries: visibleEntries,
    renderedItems: renderedItems,
    hasOlderEntries: hasOlderEntries,
    hiddenEntryCount: hiddenEntryCount,
    itemCount: itemCount,
  );
}

List<LingConversationRenderItem> buildLingConversationRenderItems({
  required List<LingConversationEntry> visibleEntries,
}) {
  final renderedItems = <LingConversationRenderItem>[];
  final itemIdCounts = <String, int>{};
  DateTime? currentRoundStartedAt;
  for (var index = 0; index < visibleEntries.length; index += 1) {
    final entry = visibleEntries[index];
    if (_isLingIgnoredToolEntry(entry)) {
      continue;
    }
    final timestamp = resolveLingConversationRoundStartedAt(entry);
    if (timestamp != null) {
      currentRoundStartedAt = timestamp;
      renderedItems.add(
        LingConversationRenderItem.timestamp(
          id: _reserveLingConversationRenderItemId(
            'timestamp_${entry.id}',
            itemIdCounts,
          ),
          timestamp: timestamp,
          sourceEntryId: entry.id,
        ),
      );
    }
    if (_isLingAssistantWorkEntry(entry)) {
      var nextIndex = index + 1;
      while (nextIndex < visibleEntries.length &&
          _isLingAssistantWorkEntry(visibleEntries[nextIndex])) {
        nextIndex += 1;
      }
      _appendLingAssistantWorkSegment(
        renderedItems: renderedItems,
        entries: visibleEntries.sublist(index, nextIndex),
        roundStartedAt: currentRoundStartedAt,
        itemIdCounts: itemIdCounts,
      );
      index = nextIndex - 1;
      continue;
    }
    renderedItems.add(
      LingConversationRenderItem.entry(
        id: _reserveLingConversationRenderItemId(entry.id, itemIdCounts),
        entry: entry,
      ),
    );
  }
  return List<LingConversationRenderItem>.unmodifiable(renderedItems);
}

bool _isLingAssistantWorkEntry(LingConversationEntry entry) {
  if (_isLingIgnoredToolEntry(entry)) {
    return false;
  }
  return entry.entryType == LingConversationEntryType.toolCall ||
      entry.entryType == LingConversationEntryType.assistantMessage;
}

bool _isLingIgnoredToolEntry(LingConversationEntry entry) {
  if (entry.entryType != LingConversationEntryType.toolCall) {
    return false;
  }
  final functionName =
      resolveLingToolCallResultFunctionName(entry.toolResult) ?? entry.toolName;
  return isLingIgnoredToolFunctionName(functionName);
}

void _appendLingAssistantWorkSegment({
  required List<LingConversationRenderItem> renderedItems,
  required List<LingConversationEntry> entries,
  required DateTime? roundStartedAt,
  required Map<String, int> itemIdCounts,
}) {
  final hasToolCall = entries.any(
    (entry) => entry.entryType == LingConversationEntryType.toolCall,
  );
  if (!hasToolCall) {
    for (final entry in entries) {
      renderedItems.add(
        LingConversationRenderItem.entry(
          id: _reserveLingConversationRenderItemId(entry.id, itemIdCounts),
          entry: entry,
        ),
      );
    }
    return;
  }

  final finalAssistantTextIndex = _resolveFinalAssistantTextIndex(entries);
  final expandedToolCardEntries = _resolveExpandedToolCardEntriesForUserTurn(
    entries,
  );
  final foldedEntries = <LingConversationEntry>[];
  for (var index = 0; index < entries.length; index += 1) {
    final entry = entries[index];
    if (entry.entryType == LingConversationEntryType.toolCall) {
      foldedEntries.add(entry);
      continue;
    }
    if (index != finalAssistantTextIndex && entry.text.trim().isNotEmpty) {
      foldedEntries.add(entry);
    }
  }

  if (foldedEntries.isNotEmpty) {
    final ids = foldedEntries.map((item) => item.id).join('_');
    final itemId = _reserveLingConversationRenderItemId(
      'tool_flow_$ids',
      itemIdCounts,
    );
    final isElapsedRunning = entries.any(_isLingEntryStillRunning);
    renderedItems.add(
      LingConversationRenderItem.toolFlow(
        id: itemId,
        toolFlowGroup: LingToolFlowGroup(
          id: itemId,
          entries: List<LingConversationEntry>.unmodifiable(foldedEntries),
          isArchived: finalAssistantTextIndex != null && !isElapsedRunning,
          expandedToolCardEntryIds: expandedToolCardEntries
              .map((entry) => entry.id)
              .toSet(),
          startedAt: roundStartedAt ?? _resolveEarliestEntryCreatedAt(entries),
          completedAt: finalAssistantTextIndex == null || isElapsedRunning
              ? null
              : _resolveLatestEntryCreatedAt(entries),
          isElapsedRunning: isElapsedRunning || finalAssistantTextIndex == null,
        ),
      ),
    );
  }

  for (final entry in entries) {
    if (entry.entryType != LingConversationEntryType.toolCall) {
      continue;
    }
    _appendLingToolResultEntry(
      renderedItems: renderedItems,
      toolEntry: entry,
      expandedToolCardEntries: expandedToolCardEntries,
      itemIdCounts: itemIdCounts,
    );
  }

  for (var index = 0; index < entries.length; index += 1) {
    final entry = entries[index];
    if (entry.entryType == LingConversationEntryType.toolCall) {
      continue;
    }
    if (index == finalAssistantTextIndex ||
        (entry.text.trim().isEmpty && entry.attachments.isNotEmpty)) {
      renderedItems.add(
        LingConversationRenderItem.entry(
          id: _reserveLingConversationRenderItemId(entry.id, itemIdCounts),
          entry: entry,
        ),
      );
    }
  }
}

String _reserveLingConversationRenderItemId(
  String baseId,
  Map<String, int> itemIdCounts,
) {
  final count = (itemIdCounts[baseId] ?? 0) + 1;
  itemIdCounts[baseId] = count;
  if (count == 1) {
    return baseId;
  }
  return '$baseId#$count';
}

bool _isLingEntryStillRunning(LingConversationEntry entry) {
  if (entry.isStreaming) {
    return true;
  }
  final status = entry.status.trim().toLowerCase();
  return status == 'running' || status == 'queued';
}

DateTime? _resolveEarliestEntryCreatedAt(List<LingConversationEntry> entries) {
  DateTime? earliest;
  for (final entry in entries) {
    final createdAt = entry.createdAt;
    if (createdAt == null) {
      continue;
    }
    if (earliest == null || createdAt.isBefore(earliest)) {
      earliest = createdAt;
    }
  }
  return earliest;
}

DateTime? _resolveLatestEntryCreatedAt(List<LingConversationEntry> entries) {
  DateTime? latest;
  for (final entry in entries) {
    final createdAt = entry.createdAt;
    if (createdAt == null) {
      continue;
    }
    if (latest == null || createdAt.isAfter(latest)) {
      latest = createdAt;
    }
  }
  return latest;
}

int? _resolveFinalAssistantTextIndex(List<LingConversationEntry> entries) {
  var lastToolCallIndex = -1;
  for (var index = entries.length - 1; index >= 0; index -= 1) {
    if (entries[index].entryType == LingConversationEntryType.toolCall) {
      lastToolCallIndex = index;
      break;
    }
  }
  for (var index = entries.length - 1; index >= 0; index -= 1) {
    if (index < lastToolCallIndex) {
      break;
    }
    final entry = entries[index];
    if (entry.entryType == LingConversationEntryType.assistantMessage &&
        entry.text.trim().isNotEmpty) {
      return index;
    }
  }
  for (var index = entries.length - 1; index >= 0; index -= 1) {
    final entry = entries[index];
    if (entry.entryType == LingConversationEntryType.assistantMessage &&
        entry.text.trim().isNotEmpty) {
      return index;
    }
  }
  return null;
}

void _appendLingToolResultEntry({
  required List<LingConversationRenderItem> renderedItems,
  required LingConversationEntry toolEntry,
  required Set<LingConversationEntry> expandedToolCardEntries,
  required Map<String, int> itemIdCounts,
}) {
  final display = buildLingToolCallDisplayState(toolEntry);
  if (display.variant == LingToolCallDisplayVariant.hidden) {
    return;
  }
  final cardProfile = display.cardProfile;
  if (cardProfile != null &&
      (!cardProfile.defaultExpanded ||
          !expandedToolCardEntries.contains(toolEntry))) {
    return;
  }
  renderedItems.add(
    LingConversationRenderItem.entry(
      id: _reserveLingConversationRenderItemId(
        'tool_result_${toolEntry.id}',
        itemIdCounts,
      ),
      entry: toolEntry,
    ),
  );
}

bool shouldApplyLingRecoveredConversation({
  required List<LingConversationEntry> currentConversation,
  required List<LingConversationEntry> recoveredConversation,
  bool currentHasMoreRemoteConversationEntries = false,
  bool recoveredHasMoreRemoteConversationEntries = false,
  String? currentOlderConversationBeforeCreatedAt,
  String? recoveredOlderConversationBeforeCreatedAt,
  String? currentOlderConversationBeforeRecordId,
  String? recoveredOlderConversationBeforeRecordId,
}) {
  if (recoveredConversation.isEmpty) {
    return currentConversation.isEmpty;
  }
  if (currentHasMoreRemoteConversationEntries !=
          recoveredHasMoreRemoteConversationEntries ||
      currentOlderConversationBeforeCreatedAt !=
          recoveredOlderConversationBeforeCreatedAt ||
      currentOlderConversationBeforeRecordId !=
          recoveredOlderConversationBeforeRecordId) {
    return true;
  }
  if (currentConversation.length != recoveredConversation.length) {
    return true;
  }
  for (var index = 0; index < currentConversation.length; index += 1) {
    if (!_isSameLingConversationEntry(
      currentConversation[index],
      recoveredConversation[index],
    )) {
      return true;
    }
  }
  return false;
}

bool _isSameLingConversationEntry(
  LingConversationEntry current,
  LingConversationEntry recovered,
) {
  return _isSameJsonLikeMap(
    current.toDto().toJson(),
    recovered.toDto().toJson(),
  );
}

bool _isSameJsonLikeMap(
  Map<String, dynamic>? current,
  Map<String, dynamic>? recovered,
) {
  if (current == null || recovered == null) {
    return current == recovered;
  }
  if (current.length != recovered.length) {
    return false;
  }
  for (final entry in current.entries) {
    if (!recovered.containsKey(entry.key) ||
        !_isSameJsonLikeValue(entry.value, recovered[entry.key])) {
      return false;
    }
  }
  return true;
}

bool _isSameJsonLikeValue(Object? current, Object? recovered) {
  if (current is Map && recovered is Map) {
    return _isSameJsonLikeMap(
      current.map((key, value) => MapEntry('$key', value)),
      recovered.map((key, value) => MapEntry('$key', value)),
    );
  }
  if (current is List && recovered is List) {
    if (current.length != recovered.length) {
      return false;
    }
    for (var index = 0; index < current.length; index += 1) {
      if (!_isSameJsonLikeValue(current[index], recovered[index])) {
        return false;
      }
    }
    return true;
  }
  return current == recovered;
}

List<LingConversationEntry> settleLingRecoveredConversationEntries({
  required List<LingConversationEntry> conversation,
}) {
  final settled = <LingConversationEntry>[];
  for (final entry in conversation) {
    final hasToolResult = (entry.toolResult?.trim().isNotEmpty ?? false);
    if (entry.entryType == LingConversationEntryType.toolCall &&
        entry.isStreaming &&
        !hasToolResult) {
      continue;
    }
    if (!entry.isStreaming) {
      settled.add(entry);
      continue;
    }
    settled.add(
      LingConversationEntry(
        id: entry.id,
        entryType: entry.entryType,
        role: entry.role,
        createdAt: entry.createdAt,
        messageId: entry.messageId,
        messageType: entry.messageType,
        text: entry.text,
        attachments: entry.attachments,
        isStreaming: false,
        status: 'completed',
        toolCallId: entry.toolCallId,
        toolName: entry.toolName,
        toolArguments: entry.toolArguments,
        toolResult: entry.toolResult,
      ),
    );
  }
  return List<LingConversationEntry>.unmodifiable(settled);
}

bool shouldAutoPageLingConversation({
  required bool hasOlderEntries,
  required bool isPagingOlderEntries,
  required double scrollOffset,
  double minScrollOffset = 0,
  double topPaginationThreshold = 24,
}) {
  return hasOlderEntries &&
      !isPagingOlderEntries &&
      scrollOffset - minScrollOffset <= topPaginationThreshold;
}

bool shouldExecuteLingQueuedConversationScrollToBottom({
  required bool isForced,
  required bool autoScrollEnabled,
  required bool isPagingOlderEntries,
}) {
  if (isPagingOlderEntries) {
    return false;
  }
  return isForced || autoScrollEnabled;
}

double resolveLingPagedConversationScrollOffset({
  required double previousOffset,
  required double previousMaxScrollExtent,
  required double nextMaxScrollExtent,
  required double minScrollExtent,
  required double maxScrollExtent,
}) {
  final delta = nextMaxScrollExtent - previousMaxScrollExtent;
  return (previousOffset + delta)
      .clamp(minScrollExtent, maxScrollExtent)
      .toDouble();
}

DateTime? resolveLingConversationRoundStartedAt(LingConversationEntry entry) {
  if (entry.entryType == LingConversationEntryType.userMessage) {
    return entry.createdAt;
  }
  return null;
}

DateTime? resolveLingConversationStartedAt(
  List<LingConversationEntry> conversation,
) {
  for (final entry in conversation) {
    if (entry.role == LingConversationRole.user && entry.createdAt != null) {
      return entry.createdAt;
    }
  }
  for (final entry in conversation) {
    if (entry.createdAt != null) {
      return entry.createdAt;
    }
  }
  return null;
}

String formatLingConversationStartedAtLabel({
  required LingStrings strings,
  required DateTime startedAt,
  DateTime? now,
}) {
  final localStartedAt = startedAt.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  final startOfToday = DateTime(localNow.year, localNow.month, localNow.day);
  final startOfStartedDay = DateTime(
    localStartedAt.year,
    localStartedAt.month,
    localStartedAt.day,
  );
  final dayDifference = startOfToday.difference(startOfStartedDay).inDays;
  final timeLabel = _formatLingClockLabel(
    strings: strings,
    value: localStartedAt,
  );
  if (dayDifference <= 0) {
    return timeLabel;
  }
  if (dayDifference == 1) {
    return strings.isZh ? '昨天 $timeLabel' : 'Yesterday $timeLabel';
  }
  if (dayDifference < 7) {
    return '${strings.weekdayShort(localStartedAt.weekday)} $timeLabel';
  }
  if (strings.isZh) {
    return '${localStartedAt.month}月${localStartedAt.day}日 $timeLabel';
  }
  return '${_englishMonthAbbreviation(localStartedAt.month)} '
      '${localStartedAt.day} $timeLabel';
}

Set<LingConversationEntry> _resolveExpandedToolCardEntriesForUserTurn(
  List<LingConversationEntry> userTurnAssistantEntries,
) {
  final latestEntryByToolCardKey = <String, _LingToolCardCandidate>{};
  for (var index = 0; index < userTurnAssistantEntries.length; index += 1) {
    final entry = userTurnAssistantEntries[index];
    if (entry.entryType != LingConversationEntryType.toolCall) {
      continue;
    }
    if (entry.isStreaming || entry.status == 'running') {
      continue;
    }
    final display = buildLingToolCallDisplayState(entry);
    final cardProfile = display.cardProfile;
    if (cardProfile == null || !cardProfile.defaultExpanded) {
      continue;
    }
    latestEntryByToolCardKey[cardProfile.presentationKey] =
        _LingToolCardCandidate(entry: entry, display: display, index: index);
  }
  final candidates = latestEntryByToolCardKey.values.toList(growable: false)
    ..sort((left, right) {
      final priorityCompare = _toolCardPriority(
        right.display,
      ).compareTo(_toolCardPriority(left.display));
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return right.index.compareTo(left.index);
    });
  return candidates
      .take(_maxExpandedToolCardsPerAssistantTurn)
      .map((candidate) => candidate.entry)
      .toSet();
}

int _toolCardPriority(LingToolCallDisplayState display) {
  return display.cardProfile?.priority ?? 0;
}

String _formatLingClockLabel({
  required LingStrings strings,
  required DateTime value,
}) {
  if (strings.isZh) {
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.hour}:$minute';
  }
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _englishMonthAbbreviation(int month) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}
