import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/calendar/models/calendar_event_editor_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/presentation/calendar_event_hero_chrome.dart';
import 'package:ling/src/features/calendar/presentation/event_editor_sheet.dart';
import 'package:ling/src/features/calendar/presentation/schedule_formatters.dart';
import 'package:ling/src/features/chat/application/agent_file_reference.dart';
import 'package:ling/src/features/chat/application/object_reference.dart';
import 'package:ling/src/features/chat/presentation/agent_markdown_image.dart';
import 'package:ling/src/features/chat/presentation/conversation_agent_file_cards.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/edge_swipe_back.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

typedef LingEventEditSubmit =
    Future<bool> Function(
      LingEvent event,
      LingCalendarEventEditorResult result,
    );

const double _eventDetailsExpandedHeroHeight = 390;
const double _eventDetailsCollapsedHeroContentHeight = 96;
const double _eventDetailsSwipeActivationWidth = 120;
const double _eventDetailsHeroNavButtonSize = 48;
const double _eventDetailsHeroNavHorizontalInset = 16;

LingObjectReference buildLingEventObjectReference(
  LingEvent event,
  LingStrings strings,
) {
  final summary = <String, String>{};
  summary['time'] = _formatEventSheetTimeRange(
    strings,
    event.startAt,
    event.endAt,
    isPoint: event.timeShape == 'point',
  );
  final location = (event.location ?? '').trim();
  final meetingUrl = (event.meetingUrl ?? '').trim();
  if (location.isNotEmpty) {
    summary['location'] = location;
  } else if (meetingUrl.isNotEmpty) {
    summary['meeting'] = meetingUrl;
  }
  if (event.isRecurring && event.occurrenceStartAt != null) {
    summary['occurrence'] = strings.isZh ? '重复日程实例' : 'Recurring instance';
  }
  return LingObjectReference(
    kind: LingObjectReferenceKind.event,
    id: event.eventId,
    title: event.title.trim().isEmpty ? strings.untitled : event.title.trim(),
    subtitle: summary['time'],
    summaryFields: summary,
    createdFromRoute: 'event_details',
  );
}

Future<void> showLingEventDetailsSheet({
  required BuildContext context,
  required LingStrings strings,
  required LingEvent event,
  String? heroTag,
  bool useHeroTransition = false,
  String? editActionLabel,
  String? deleteActionLabel,
  ValueChanged<LingEvent>? onEditLingEvent,
  LingEventEditSubmit? onSubmitLingEventEdit,
  ValueChanged<LingEvent>? onDeleteLingEvent,
  ValueChanged<LingObjectReference>? onReferenceLingEvent,
}) {
  if (useHeroTransition) {
    return _pushLingEventDetailsHeroRoute(
      context: context,
      strings: strings,
      event: event,
      heroTag: heroTag ?? _eventDetailsHeroTag(event.eventId),
      editActionLabel: editActionLabel,
      deleteActionLabel: deleteActionLabel,
      onEditLingEvent: onEditLingEvent,
      onSubmitLingEventEdit: onSubmitLingEventEdit,
      onDeleteLingEvent: onDeleteLingEvent,
      onReferenceLingEvent: onReferenceLingEvent,
    );
  }

  return showLingAdaptiveSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _LingEventDetailsSheet(
      strings: strings,
      event: event,
      editActionLabel: editActionLabel,
      deleteActionLabel: deleteActionLabel,
      onEditLingEvent: onEditLingEvent,
      onDeleteLingEvent: onDeleteLingEvent,
      onReferenceLingEvent: onReferenceLingEvent,
    ),
  );
}

Future<void> _pushLingEventDetailsHeroRoute({
  required BuildContext context,
  required LingStrings strings,
  required LingEvent event,
  required String heroTag,
  String? editActionLabel,
  String? deleteActionLabel,
  ValueChanged<LingEvent>? onEditLingEvent,
  LingEventEditSubmit? onSubmitLingEventEdit,
  ValueChanged<LingEvent>? onDeleteLingEvent,
  ValueChanged<LingObjectReference>? onReferenceLingEvent,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (routeContext, animation, secondaryAnimation) {
        return _LingEventDetailsHeroRoute(
          strings: strings,
          event: event,
          heroTag: heroTag,
          editActionLabel: editActionLabel,
          deleteActionLabel: deleteActionLabel,
          onEditLingEvent: onEditLingEvent,
          onSubmitLingEventEdit: onSubmitLingEventEdit,
          onDeleteLingEvent: onDeleteLingEvent,
          onReferenceLingEvent: onReferenceLingEvent,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
          child: child,
        );
      },
    ),
  );
}

class _LingEventDetailsHeroRoute extends StatelessWidget {
  const _LingEventDetailsHeroRoute({
    required this.strings,
    required this.event,
    required this.heroTag,
    this.editActionLabel,
    this.deleteActionLabel,
    this.onEditLingEvent,
    this.onSubmitLingEventEdit,
    this.onDeleteLingEvent,
    this.onReferenceLingEvent,
  });

  final LingStrings strings;
  final LingEvent event;
  final String heroTag;
  final String? editActionLabel;
  final String? deleteActionLabel;
  final ValueChanged<LingEvent>? onEditLingEvent;
  final LingEventEditSubmit? onSubmitLingEventEdit;
  final ValueChanged<LingEvent>? onDeleteLingEvent;
  final ValueChanged<LingObjectReference>? onReferenceLingEvent;

  @override
  Widget build(BuildContext context) {
    return _LingEventDetailsPage(
      strings: strings,
      event: event,
      heroTag: heroTag,
      editActionLabel: editActionLabel,
      deleteActionLabel: deleteActionLabel,
      onEditLingEvent: onEditLingEvent,
      onSubmitLingEventEdit: onSubmitLingEventEdit,
      onDeleteLingEvent: onDeleteLingEvent,
      onReferenceLingEvent: onReferenceLingEvent,
    );
  }
}

class _LingEventDetailsPage extends StatefulWidget {
  const _LingEventDetailsPage({
    required this.strings,
    required this.event,
    required this.heroTag,
    this.editActionLabel,
    this.deleteActionLabel,
    this.onEditLingEvent,
    this.onSubmitLingEventEdit,
    this.onDeleteLingEvent,
    this.onReferenceLingEvent,
  });

  final LingStrings strings;
  final LingEvent event;
  final String heroTag;
  final String? editActionLabel;
  final String? deleteActionLabel;
  final ValueChanged<LingEvent>? onEditLingEvent;
  final LingEventEditSubmit? onSubmitLingEventEdit;
  final ValueChanged<LingEvent>? onDeleteLingEvent;
  final ValueChanged<LingObjectReference>? onReferenceLingEvent;

  @override
  State<_LingEventDetailsPage> createState() => _LingEventDetailsPageState();
}

class _LingEventDetailsPageState extends State<_LingEventDetailsPage> {
  late final ScrollController _detailsScrollController;
  late LingEvent _event;
  bool _isSavingEdit = false;

  @override
  void initState() {
    super.initState();
    _detailsScrollController = ScrollController();
    _event = widget.event;
  }

  @override
  void dispose() {
    _detailsScrollController.dispose();
    super.dispose();
  }

  Future<void> _openEditSheet() async {
    final onSubmit = widget.onSubmitLingEventEdit;
    if (onSubmit == null || _isSavingEdit) {
      return;
    }
    final result = await showLingAdaptiveSheet<LingCalendarEventEditorResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return LingCalendarEventEditorSheet(
          strings: widget.strings,
          sheetTitle: widget.strings.editEvent,
          initialTitle: _event.title,
          initialLocation: (_event.location ?? '').trim(),
          initialMeetingUrl: (_event.meetingUrl ?? '').trim(),
          initialTimeShape: _event.timeShape,
          initialStartAt: _event.startAt,
          initialEndAt: _event.endAt,
          timezone: _event.timezone,
          notificationLabel: widget.strings.quickAddNoNotification,
          submitLabel: widget.strings.saveEventChanges,
          initialRecurrence: _event.recurrence,
          initialMutationScope: 'series',
          allowMutationScopeSelection:
              _event.isRecurring && _event.occurrenceStartAt != null,
        );
      },
    );
    if (result == null || !mounted) {
      return;
    }
    await _submitEdit(result);
  }

  Future<void> _submitEdit(LingCalendarEventEditorResult result) async {
    final onSubmit = widget.onSubmitLingEventEdit;
    if (onSubmit == null || _isSavingEdit) {
      return;
    }
    setState(() {
      _isSavingEdit = true;
    });
    final saved = await onSubmit(_event, result);
    if (!mounted) {
      return;
    }
    if (saved) {
      final draft = result.draft;
      if (draft != null) {
        _event = _event.copyWith(
          title: draft.title,
          startAt: draft.startAt,
          endAt: draft.endAt,
          timeShape: draft.timeShape,
          location: draft.location,
          clearLocation: draft.location == null,
          meetingUrl: draft.meetingUrl,
          clearMeetingUrl: draft.meetingUrl == null,
          recurrence: draft.recurrence,
          isRecurring: draft.recurrence != null,
        );
      }
    }
    setState(() {
      _isSavingEdit = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasEdit =
        widget.onSubmitLingEventEdit != null &&
        (widget.editActionLabel?.isNotEmpty ?? false);
    final collapsedHeroHeight =
        MediaQuery.paddingOf(context).top +
        _eventDetailsCollapsedHeroContentHeight;
    final heroCollapseRange =
        _eventDetailsExpandedHeroHeight - collapsedHeroHeight;

    return Material(
      color: palette.background,
      child: SafeArea(
        top: false,
        bottom: false,
        child: LingEdgeSwipeBackContainer(
          edgeActivationWidth: _eventDetailsSwipeActivationWidth,
          swipeDirections: const <LingEdgeSwipeDirection>{
            LingEdgeSwipeDirection.leftToRight,
          },
          keepCompletedOffsetUntilBack: true,
          onBack: () => Navigator.of(context).pop(),
          child: DecoratedBox(
            decoration: BoxDecoration(color: palette.background),
            child: AnimatedBuilder(
              animation: _detailsScrollController,
              builder: (context, child) {
                final scrollOffset = _detailsScrollController.hasClients
                    ? _detailsScrollController.offset
                    : 0.0;
                final collapseProgress = heroCollapseRange <= 0
                    ? 1.0
                    : (scrollOffset / heroCollapseRange).clamp(0.0, 1.0);
                final heroHeight =
                    lerpDouble(
                      _eventDetailsExpandedHeroHeight,
                      collapsedHeroHeight,
                      collapseProgress.toDouble(),
                    ) ??
                    _eventDetailsExpandedHeroHeight;
                return Stack(
                  children: [
                    Positioned.fill(
                      top: heroHeight,
                      child: SingleChildScrollView(
                        controller: _detailsScrollController,
                        child: _buildDetailsView(context),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _EventDetailsHero(
                        strings: widget.strings,
                        event: _event,
                        heroTag: widget.heroTag,
                        accentColor: lingCalendarEventHeroAccentColor(
                          palette,
                          category: _event.category,
                          status: _event.status,
                        ),
                        height: heroHeight,
                        collapseProgress: collapseProgress.toDouble(),
                        expanded: true,
                        editActionLabel: widget.editActionLabel,
                        onEnterEditMode: hasEdit ? _openEditSheet : null,
                        deleteActionLabel:
                            widget.onDeleteLingEvent != null &&
                                (widget.deleteActionLabel?.isNotEmpty ?? false)
                            ? widget.deleteActionLabel
                            : null,
                        onDeleteEvent: widget.onDeleteLingEvent != null
                            ? () {
                                Navigator.of(context).pop();
                                widget.onDeleteLingEvent!(_event);
                              }
                            : null,
                      ),
                    ),
                    if (widget.onReferenceLingEvent != null)
                      Positioned(
                        right: 20,
                        bottom: MediaQuery.paddingOf(context).bottom + 16,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: (MediaQuery.sizeOf(context).width - 40)
                                .clamp(190.0, 218.0)
                                .toDouble(),
                          ),
                          child: _EventDetailsReferenceBar(
                            label: widget.strings.isZh
                                ? '跟 Ling 聊这个日程'
                                : 'Chat with Ling about this',
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onReferenceLingEvent!(
                                buildLingEventObjectReference(
                                  _event,
                                  widget.strings,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsView(BuildContext context) {
    final palette = context.palette;
    final recurrenceLabel = formatLingRecurrenceDetailLabel(
      widget.strings,
      isRecurring: _event.isRecurring,
      recurrence: _event.recurrence,
      anchorStartAt: _event.startAt,
    );
    final location = (_event.location ?? '').trim();
    final meetingUrl = (_event.meetingUrl ?? '').trim();
    final subtitle = (_event.subtitle ?? '').trim();
    final metadataMarkdown = _metadataMarkdown(_event.metadata);
    final insights = _ScheduleInsights.fromMetadata(_event.metadata);
    final preparation = _SchedulePreparation.fromMetadata(_event.metadata);
    final moreLines = _eventMoreLines(widget.strings, _event);
    final bottomPadding = widget.onReferenceLingEvent == null ? 28.0 : 118.0;
    return Padding(
      key: ValueKey('event_details_view_${_event.eventId}'),
      padding: EdgeInsets.fromLTRB(20, 22, 20, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EventDetailsPanel(
            title: widget.strings.eventDetails,
            child: Column(
              children: [
                _EventDetailsInfoLine(
                  icon: Icons.schedule_rounded,
                  label: widget.strings.eventTimeLabel,
                  value: _formatEventSheetTimeRange(
                    widget.strings,
                    _event.startAt,
                    _event.endAt,
                    isPoint: _event.isPoint,
                  ).replaceAll('\n', ' · '),
                ),
                const SizedBox(height: 12),
                _EventDetailsInfoLine(
                  icon: Icons.sell_outlined,
                  label: widget.strings.eventCategoryLabel,
                  value: widget.strings.calendarToolCallCategoryLabel(
                    _event.category,
                  ),
                ),
                const SizedBox(height: 12),
                _EventDetailsInfoLine(
                  icon: Icons.info_outline_rounded,
                  label: widget.strings.eventStatusLabel,
                  value: _formatEventStatus(widget.strings, _event.status),
                ),
                const SizedBox(height: 12),
                _EventDetailsInfoLine(
                  icon: Icons.timeline_rounded,
                  label: widget.strings.eventTimeShapeLabel,
                  value: _formatEventTimeShape(widget.strings, _event),
                ),
                if (recurrenceLabel != null) ...[
                  const SizedBox(height: 12),
                  _EventDetailsInfoLine(
                    icon: Icons.repeat_rounded,
                    label: widget.strings.eventRepeatsLabel,
                    value: recurrenceLabel,
                  ),
                ],
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _EventDetailsInfoLine(
                    icon: Icons.place_outlined,
                    label: widget.strings.eventLocationLabel,
                    value: location,
                  ),
                ],
                if (meetingUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _EventDetailsInfoLine(
                    icon: Icons.video_call_outlined,
                    label: widget.strings.eventMeetingLabel,
                    value: meetingUrl,
                  ),
                ],
              ],
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 12),
            _EventDetailsPanel(
              title: widget.strings.eventDescriptionLabel,
              child: Text(
                subtitle,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
            ),
          ],
          if (metadataMarkdown.isNotEmpty && metadataMarkdown != subtitle) ...[
            const SizedBox(height: 12),
            _EventDetailsPanel(
              title: widget.strings.eventRecordLabel,
              child: _DetailsMarkdownBox(markdown: metadataMarkdown),
            ),
          ],
          if (insights.hasContent) ...[
            const SizedBox(height: 12),
            _EventDetailsPanel(
              title: widget.strings.eventInsightsLabel,
              child: _ScheduleInsightsView(
                strings: widget.strings,
                insights: insights,
              ),
            ),
          ],
          if (preparation.hasContent) ...[
            const SizedBox(height: 12),
            _EventDetailsPanel(
              title: widget.strings.eventPreparationLabel,
              child: _SchedulePreparationView(preparation: preparation),
            ),
          ],
          if (moreLines.isNotEmpty) ...[
            const SizedBox(height: 12),
            _EventDetailsPanel(
              title: widget.strings.eventMoreLabel,
              child: Column(
                children: [
                  for (var index = 0; index < moreLines.length; index++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: index == moreLines.length - 1 ? 0 : 8,
                      ),
                      child: moreLines[index],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LingEventDetailsSheet extends StatelessWidget {
  const _LingEventDetailsSheet({
    required this.strings,
    required this.event,
    this.editActionLabel,
    this.deleteActionLabel,
    this.onEditLingEvent,
    this.onDeleteLingEvent,
    this.onReferenceLingEvent,
  });

  final LingStrings strings;
  final LingEvent event;
  final String? editActionLabel;
  final String? deleteActionLabel;
  final ValueChanged<LingEvent>? onEditLingEvent;
  final ValueChanged<LingEvent>? onDeleteLingEvent;
  final ValueChanged<LingObjectReference>? onReferenceLingEvent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final insights = _ScheduleInsights.fromMetadata(event.metadata);
    final preparation = _SchedulePreparation.fromMetadata(event.metadata);
    final recurrenceLabel = formatLingRecurrenceDetailLabel(
      strings,
      isRecurring: event.isRecurring,
      recurrence: event.recurrence,
      anchorStartAt: event.startAt,
    );
    final location = (event.location ?? '').trim();
    final meetingUrl = (event.meetingUrl ?? '').trim();
    final placeMeetingTitle = location.isNotEmpty && meetingUrl.isNotEmpty
        ? strings.eventPlaceMeetingLabel
        : location.isNotEmpty
        ? strings.eventLocationLabel
        : strings.eventMeetingLabel;
    final moreLines = _eventMoreLines(strings, event);
    final hasEdit =
        onEditLingEvent != null && (editActionLabel?.isNotEmpty ?? false);
    final hasDelete =
        onDeleteLingEvent != null && (deleteActionLabel?.isNotEmpty ?? false);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EventDetailsSheetHeader(strings: strings, event: event),
                  const SizedBox(height: 18),
                  _EventDetailsPanel(
                    title: strings.eventTimeLabel,
                    child: Text(
                      _formatEventSheetTimeRange(
                        strings,
                        event.startAt,
                        event.endAt,
                        isPoint: event.isPoint,
                      ),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _EventDetailsPanel(
                    title: strings.eventCategoryLabel,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                          label: strings.calendarToolCallCategoryLabel(
                            event.category,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (recurrenceLabel != null) ...[
                    const SizedBox(height: 10),
                    _EventDetailsPanel(
                      title: strings.eventRepeatsLabel,
                      child: Text(
                        recurrenceLabel,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                  if (location.isNotEmpty || meetingUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _EventDetailsPanel(
                      title: placeMeetingTitle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (location.isNotEmpty)
                            Text(
                              location,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 15,
                                height: 1.45,
                              ),
                            ),
                          if (meetingUrl.isNotEmpty) ...[
                            if (location.isNotEmpty) const SizedBox(height: 8),
                            Text(
                              meetingUrl,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 15,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if ((event.subtitle ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _EventDetailsPanel(
                      title: strings.eventDescriptionLabel,
                      child: Text(
                        event.subtitle!.trim(),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                  if (insights.hasContent) ...[
                    const SizedBox(height: 10),
                    _EventDetailsPanel(
                      title: strings.eventInsightsLabel,
                      child: _ScheduleInsightsView(
                        strings: strings,
                        insights: insights,
                      ),
                    ),
                  ],
                  if (preparation.hasContent) ...[
                    const SizedBox(height: 10),
                    _EventDetailsPanel(
                      title: strings.eventPreparationLabel,
                      child: _SchedulePreparationView(preparation: preparation),
                    ),
                  ],
                  if (moreLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _EventDetailsPanel(
                      title: strings.eventMoreLabel,
                      child: Column(
                        children: [
                          for (var index = 0; index < moreLines.length; index++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: index == moreLines.length - 1 ? 0 : 8,
                              ),
                              child: moreLines[index],
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (hasEdit || hasDelete) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (hasEdit)
                          Expanded(
                            child: _SecondaryActionButton(
                              child: LingAdaptiveFilledButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  onEditLingEvent!(event);
                                },
                                minHeight: 48,
                                backgroundColor: palette.surfaceMuted,
                                foregroundColor: palette.textPrimary,
                                borderRadius: BorderRadius.circular(18),
                                child: Text(editActionLabel!),
                              ),
                            ),
                          ),
                        if (hasEdit && hasDelete) const SizedBox(width: 10),
                        if (hasDelete)
                          Expanded(
                            child: LingAdaptiveFilledButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                onDeleteLingEvent!(event);
                              },
                              minHeight: 48,
                              backgroundColor:
                                  palette.destructiveButtonBackground,
                              foregroundColor:
                                  palette.destructiveButtonForeground,
                              borderRadius: BorderRadius.circular(18),
                              child: Text(deleteActionLabel!),
                            ),
                          ),
                      ],
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

class _EventDetailsSheetHeader extends StatelessWidget {
  const _EventDetailsSheetHeader({required this.strings, required this.event});

  final LingStrings strings;
  final LingEvent event;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final title = event.title.trim().isEmpty
        ? strings.untitled
        : event.title.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.eventDetails,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 22,
                  height: 1.18,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        LingGlassIconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icons.close_rounded,
          semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
          iconColor: palette.textSecondary,
        ),
      ],
    );
  }
}

class _EventDetailsHero extends StatelessWidget {
  const _EventDetailsHero({
    required this.strings,
    required this.event,
    required this.accentColor,
    this.heroTag,
    this.height = 260,
    this.expanded = false,
    this.collapseProgress = 0,
    this.editActionLabel,
    this.onEnterEditMode,
    this.deleteActionLabel,
    this.onDeleteEvent,
  });

  final LingStrings strings;
  final LingEvent event;
  final Color accentColor;
  final String? heroTag;
  final double height;
  final bool expanded;
  final double collapseProgress;
  final String? editActionLabel;
  final VoidCallback? onEnterEditMode;
  final String? deleteActionLabel;
  final VoidCallback? onDeleteEvent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    final location = (event.location ?? '').trim();
    final categoryLabel = strings.calendarToolCallCategoryLabel(event.category);
    final title = event.title.trim().isEmpty
        ? strings.untitled
        : event.title.trim();
    final topInset = MediaQuery.paddingOf(context).top;
    final progress = collapseProgress.clamp(0.0, 1.0);
    final expandedOpacity = 1.0 - progress;
    final compactOpacity = (progress * 1.25).clamp(0.0, 1.0);
    final bottomPaddingTop = lerpDouble(46, 22, progress) ?? 46;
    final bottomHorizontalPadding =
        lerpDouble(
          18,
          _eventDetailsHeroNavHorizontalInset +
              _eventDetailsHeroNavButtonSize +
              18,
          progress,
        ) ??
        18;
    final titleFontSize = lerpDouble(24, 18, progress) ?? 24;
    final titleLineHeight = lerpDouble(1.08, 1.12, progress) ?? 1.08;
    final eyebrowHeight = lerpDouble(14, 0, progress) ?? 14;
    final isCompact = progress > 0.62;

    final borderRadius = expanded
        ? BorderRadius.zero
        : BorderRadius.circular(32);
    final overlayBorderRadius = expanded
        ? BorderRadius.zero
        : const BorderRadius.vertical(bottom: Radius.circular(32));

    final hero = ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: lingCalendarEventHeroGradientColors(
                    palette: palette,
                    isDark: isDark,
                    accentColor: accentColor,
                  ),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -42,
              right: -24,
              child: Opacity(
                opacity: expandedOpacity,
                child: Icon(
                  Icons.calendar_month_rounded,
                  size: 220,
                  color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.16),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: isDark ? 0.62 : 0.54),
                    ],
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              left: expanded ? 22 : 18,
              top: expanded ? topInset + 76 : 24,
              child: IgnorePointer(
                child: Opacity(
                  opacity: expandedOpacity,
                  child: _EventHeroDateTile(event: event),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: expanded ? topInset + 12 : 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _EventHeroNavButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    semanticLabel: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _EventDetailsMoreMenu(
                        strings: strings,
                        editActionLabel: editActionLabel,
                        onEnterEditMode: onEnterEditMode,
                        deleteActionLabel: deleteActionLabel,
                        onDeleteEvent: onDeleteEvent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: overlayBorderRadius,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.68),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        bottomHorizontalPadding,
                        expanded ? bottomPaddingTop : 34,
                        bottomHorizontalPadding,
                        18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: eyebrowHeight,
                            child: Opacity(
                              opacity: expandedOpacity,
                              child: Text(
                                strings.eventDetails,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: isCompact ? 0 : 7),
                          Text(
                            title,
                            maxLines: isCompact ? 1 : (expanded ? 3 : 2),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleFontSize,
                              height: titleLineHeight,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Plus Jakarta Sans',
                            ),
                          ),
                          SizedBox(height: lerpDouble(12, 6, progress) ?? 12),
                          if (!isCompact)
                            Opacity(
                              opacity: expanded ? expandedOpacity : 1,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _EventHeroChip(
                                    icon: Icons.schedule_rounded,
                                    label: _formatEventHeroTimeRange(event),
                                  ),
                                  _EventHeroChip(
                                    icon: Icons.sell_outlined,
                                    label: categoryLabel,
                                  ),
                                  if (location.isNotEmpty)
                                    _EventHeroChip(
                                      icon: Icons.place_outlined,
                                      label: location,
                                    ),
                                ],
                              ),
                            )
                          else
                            Opacity(
                              opacity: compactOpacity,
                              child: Text(
                                _formatEventHeroTimeRange(event),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.76),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final resolvedHeroTag = heroTag?.trim();
    if (resolvedHeroTag == null || resolvedHeroTag.isEmpty) {
      return hero;
    }
    return Hero(
      tag: resolvedHeroTag,
      flightShuttleBuilder:
          (context, animation, direction, fromContext, toContext) {
            return Material(
              color: Colors.transparent,
              child: direction == HeroFlightDirection.push
                  ? toContext.widget
                  : fromContext.widget,
            );
          },
      child: hero,
    );
  }
}

class _EventDetailsMoreMenu extends StatefulWidget {
  const _EventDetailsMoreMenu({
    required this.strings,
    this.editActionLabel,
    this.onEnterEditMode,
    this.deleteActionLabel,
    this.onDeleteEvent,
  });

  final LingStrings strings;
  final String? editActionLabel;
  final VoidCallback? onEnterEditMode;
  final String? deleteActionLabel;
  final VoidCallback? onDeleteEvent;

  @override
  State<_EventDetailsMoreMenu> createState() => _EventDetailsMoreMenuState();
}

class _EventDetailsMoreMenuState extends State<_EventDetailsMoreMenu> {
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _menuOverlay;

  bool get _hasEdit =>
      widget.onEnterEditMode != null &&
      (widget.editActionLabel?.isNotEmpty ?? false);
  bool get _hasDelete =>
      widget.onDeleteEvent != null &&
      (widget.deleteActionLabel?.isNotEmpty ?? false);
  bool get _hasActions => _hasEdit || _hasDelete;

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  void _toggleMenu() {
    if (_menuOverlay != null) {
      _hideMenu();
      return;
    }
    _showMenu();
  }

  void _hideMenu() {
    _menuOverlay?.remove();
    _menuOverlay = null;
  }

  void _showMenu() {
    if (!_hasActions) {
      return;
    }
    final overlay = Overlay.maybeOf(context);
    final renderBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlay == null || renderBox == null || !renderBox.hasSize) {
      return;
    }
    final triggerOffset = renderBox.localToGlobal(Offset.zero);
    final triggerSize = renderBox.size;
    const menuWidth = 150.0;
    const menuTopGap = 8.0;
    final left = triggerOffset.dx + triggerSize.width - menuWidth;
    final top = triggerOffset.dy + triggerSize.height + menuTopGap;

    _menuOverlay = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideMenu,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              child: _EventDetailsDropdownMenu(
                actions: [
                  if (_hasEdit)
                    _EventDetailsDropdownAction(
                      label: widget.editActionLabel!,
                      icon: Icons.edit_rounded,
                      onTap: () {
                        _hideMenu();
                        widget.onEnterEditMode!();
                      },
                    ),
                  if (_hasDelete)
                    _EventDetailsDropdownAction(
                      label: widget.deleteActionLabel!,
                      icon: Icons.delete_outline_rounded,
                      isDestructive: true,
                      onTap: () {
                        _hideMenu();
                        widget.onDeleteEvent!();
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_menuOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasActions) {
      return _EventHeroNavButton(
        icon: Icons.more_horiz_rounded,
        semanticLabel: widget.strings.isZh ? '更多' : 'More',
        onTap: () {},
      );
    }

    return KeyedSubtree(
      key: _triggerKey,
      child: _EventHeroNavButton(
        icon: Icons.more_horiz_rounded,
        semanticLabel: widget.strings.isZh ? '更多' : 'More',
        onTap: _toggleMenu,
      ),
    );
  }
}

class _EventDetailsDropdownMenu extends StatelessWidget {
  const _EventDetailsDropdownMenu({required this.actions});

  final List<_EventDetailsDropdownAction> actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: palette.textPrimary,
      fontWeight: FontWeight.w700,
    );
    final iconColor = palette.textPrimary.withValues(alpha: 0.9);
    final glassSettings = LiquidGlassSettings(
      glassColor: Colors.white.withValues(alpha: isDark ? 0.10 : 0.12),
      thickness: isDark ? 18 : 20,
      blur: isDark ? 8 : 7,
      lightIntensity: isDark ? 0.44 : 0.62,
      ambientStrength: isDark ? 0.16 : 0.18,
      chromaticAberration: isDark ? 0.002 : 0.006,
      refractiveIndex: isDark ? 1.08 : 1.12,
      saturation: isDark ? 1.02 : 1.06,
    );

    return Material(
      color: Colors.transparent,
      child: GlassCard(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        shape: const LiquidRoundedSuperellipse(borderRadius: 22),
        settings: glassSettings,
        useOwnLayer: true,
        quality: GlassQuality.standard,
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < actions.length; index++) ...[
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: actions[index].onTap,
                child: SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(
                          actions[index].icon,
                          size: 20,
                          color: actions[index].isDestructive
                              ? palette.danger
                              : iconColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            actions[index].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle?.copyWith(
                              color: actions[index].isDestructive
                                  ? palette.danger
                                  : titleStyle.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (index != actions.length - 1) const SizedBox(height: 2),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventDetailsDropdownAction {
  const _EventDetailsDropdownAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
}

class _EventHeroNavButton extends StatelessWidget {
  const _EventHeroNavButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Material(
            color: Colors.black.withValues(alpha: 0.28),
            child: InkWell(
              onTap: onTap,
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.94),
                size: 22,
                semanticLabel: semanticLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventDetailsReferenceBar extends StatelessWidget {
  const _EventDetailsReferenceBar({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    final tint = Color.lerp(Colors.black, palette.accent, 0.34) ?? Colors.black;
    final foreground = isDark ? Colors.white : palette.textPrimary;
    final foregroundSubtle = foreground.withValues(alpha: isDark ? 0.80 : 0.66);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: palette.shadow.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: LingGlassSurface(
        height: 48,
        radius: 18,
        tone: LingGlassSurfaceTone.control,
        tintColor: tint.withValues(alpha: 0.42),
        quality: LingGlassQuality.premium,
        child: Stack(
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 6, 7, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                            width: 0.7,
                          ),
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: foreground.withValues(alpha: 0.96),
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground.withValues(alpha: 0.96),
                            fontSize: 14,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: foregroundSubtle,
                        size: 19,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!isDark)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: palette.outlineSoft.withValues(alpha: 0.74),
                        width: 0.9,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventHeroDateTile extends StatelessWidget {
  const _EventHeroDateTile({required this.event});

  final LingEvent event;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: context.isDarkMode ? 0.12 : 0.22),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: SizedBox(
        width: 98,
        height: 98,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _eventMonthLabel(event.startAt.month),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              event.startAt.day.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                height: 0.95,
                fontWeight: FontWeight.w900,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventHeroChip extends StatelessWidget {
  const _EventHeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 292),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.78)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventDetailsPanel extends StatelessWidget {
  const _EventDetailsPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return LingGlassPanel(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      radius: 20,
      tone: LingGlassSurfaceTone.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _EventDetailsInfoLine extends StatelessWidget {
  const _EventDetailsInfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 17, color: palette.textSecondary),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LingGlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      radius: 999,
      tone: LingGlassSurfaceTone.muted,
      child: Text(
        label,
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailsMarkdownBox extends StatelessWidget {
  const _DetailsMarkdownBox({required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final baseText = TextStyle(
      color: palette.textPrimary,
      fontSize: 15,
      height: 1.55,
      fontWeight: FontWeight.w500,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceMuted.withValues(
          alpha: context.isDarkMode ? 0.42 : 0.62,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: palette.outlineSoft.withValues(
            alpha: context.isDarkMode ? 0.34 : 0.62,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: MarkdownBody(
          data: markdown,
          selectable: false,
          softLineBreak: true,
          onTapLink: (text, href, title) =>
              _openDetailsMarkdownLink(context, text: text, href: href),
          imageBuilder: (uri, title, alt) {
            final raw = uri.toString();
            if (!isLingAgentWorkspaceFileReference(raw)) {
              return Image.network(
                raw,
                semanticLabel: alt,
                fit: BoxFit.contain,
              );
            }
            return LingMarkdownAgentImage(
              path: normalizeLingAgentFilePath(raw),
              alt: alt,
            );
          },
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: baseText,
            h1: baseText.copyWith(
              fontSize: 19,
              height: 1.3,
              fontWeight: FontWeight.w800,
            ),
            h2: baseText.copyWith(
              fontSize: 17,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
            h3: baseText.copyWith(
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w800,
            ),
            listBullet: baseText.copyWith(color: palette.textSecondary),
            blockquote: baseText.copyWith(color: palette.textSecondary),
            code: TextStyle(
              color: palette.textPrimary,
              fontSize: 13,
              height: 1.45,
              fontFamily: 'monospace',
            ),
            codeblockDecoration: BoxDecoration(
              color: palette.surface.withValues(
                alpha: context.isDarkMode ? 0.38 : 0.68,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

void _openDetailsMarkdownLink(
  BuildContext context, {
  required String? text,
  required String? href,
}) {
  final target = normalizeLingAgentFilePath(href ?? '');
  if (!isLingAgentWorkspaceFileReference(target)) {
    return;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  final reference = LingAgentFileReference(
    title: (text ?? '').trim().isNotEmpty
        ? (text ?? '').trim()
        : LingAgentFileReference(
            title: target,
            path: target,
            isImageSyntax: false,
            kind: resolveLingAgentFileKind(target),
          ).filename,
    path: target,
    isImageSyntax: false,
    kind: resolveLingAgentFileKind(target),
  );
  showLingAgentFilePreview(
    context: context,
    loadFileData: container.read(agentFileRepositoryProvider).getFileData,
    saveFileToLocal: container
        .read(agentFileSaveServiceProvider)
        .saveFileToLocal,
    reference: reference,
  );
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: palette.outlineSoft.withValues(
                    alpha: context.isDarkMode ? 0.54 : 0.92,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScheduleInsightsView extends StatelessWidget {
  const _ScheduleInsightsView({required this.strings, required this.insights});

  final LingStrings strings;
  final _ScheduleInsights insights;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (insights.summary.isNotEmpty)
          Text(
            insights.summary,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (insights.prepHints.isNotEmpty) ...[
          if (insights.summary.isNotEmpty) const SizedBox(height: 10),
          _InsightChipGroup(
            label: strings.eventInsightPrepHintsLabel,
            values: insights.prepHints,
            icon: Icons.checklist_rounded,
          ),
        ],
        if (insights.riskFlags.isNotEmpty) ...[
          if (insights.summary.isNotEmpty || insights.prepHints.isNotEmpty)
            const SizedBox(height: 10),
          _InsightChipGroup(
            label: strings.eventInsightRiskFlagsLabel,
            values: insights.riskFlags,
            icon: Icons.info_outline_rounded,
          ),
        ],
      ],
    );
  }
}

class _InsightChipGroup extends StatelessWidget {
  const _InsightChipGroup({
    required this.label,
    required this.values,
    required this.icon,
  });

  final String label;
  final List<String> values;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: palette.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final value in values) _InfoPill(label: value)],
        ),
      ],
    );
  }
}

class _SchedulePreparationView extends StatelessWidget {
  const _SchedulePreparationView({required this.preparation});

  final _SchedulePreparation preparation;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final material in preparation.materials)
          LingAgentFileReferenceCard(reference: material.reference),
      ],
    );
  }
}

class _SchedulePreparation {
  const _SchedulePreparation({required this.materials});

  final List<_SchedulePreparationMaterial> materials;

  bool get hasContent => materials.isNotEmpty;

  static _SchedulePreparation fromMetadata(Map<String, dynamic> metadata) {
    final raw = metadata['schedule_preparation'];
    if (raw is! List) {
      return const _SchedulePreparation(
        materials: <_SchedulePreparationMaterial>[],
      );
    }
    final materials = <_SchedulePreparationMaterial>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final title = '${item['title'] ?? ''}'.trim();
      final path = normalizeLingAgentFilePath('${item['path'] ?? ''}');
      if (title.isEmpty || !isLingAgentWorkspaceFileReference(path)) {
        continue;
      }
      materials.add(_SchedulePreparationMaterial(title: title, path: path));
    }
    return _SchedulePreparation(
      materials: List<_SchedulePreparationMaterial>.unmodifiable(materials),
    );
  }
}

class _SchedulePreparationMaterial {
  const _SchedulePreparationMaterial({required this.title, required this.path});

  final String title;
  final String path;

  LingAgentFileReference get reference {
    return LingAgentFileReference(
      title: title,
      path: path,
      isImageSyntax: false,
      kind: resolveLingAgentFileKind(path),
    );
  }
}

class _ScheduleInsights {
  const _ScheduleInsights({
    required this.summary,
    required this.prepHints,
    required this.riskFlags,
  });

  final String summary;
  final List<String> prepHints;
  final List<String> riskFlags;

  bool get hasContent =>
      summary.isNotEmpty || prepHints.isNotEmpty || riskFlags.isNotEmpty;

  static _ScheduleInsights fromMetadata(Map<String, dynamic> metadata) {
    final raw = metadata['schedule_insights'];
    if (raw is! Map) {
      return const _ScheduleInsights(
        summary: '',
        prepHints: <String>[],
        riskFlags: <String>[],
      );
    }
    return _ScheduleInsights(
      summary: '${raw['summary'] ?? ''}'.trim(),
      prepHints: _stringList(raw['prep_hints']),
      riskFlags: _riskFlagLabels(raw['risk_flags']),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .take(4)
        .toList(growable: false);
  }

  static List<String> _riskFlagLabels(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) {
          if (item is Map) {
            return '${item['label'] ?? ''}'.trim();
          }
          return '$item'.trim();
        })
        .where((item) => item.isNotEmpty)
        .take(4)
        .toList(growable: false);
  }
}

String _eventDetailsHeroTag(String eventId) {
  return 'ling_calendar_event_${eventId.trim()}';
}

String _eventMonthLabel(int month) {
  const labels = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  if (month < 1 || month > labels.length) {
    return 'CAL';
  }
  return labels[month - 1];
}

String _formatEventHeroTimeRange(LingEvent event) {
  final start = _formatScheduleClock(event.startAt);
  if (event.isPoint) {
    return start;
  }
  return '$start - ${_formatScheduleClock(event.endAt)}';
}

String _formatEventSheetTimeRange(
  LingStrings strings,
  DateTime startAt,
  DateTime endAt, {
  required bool isPoint,
}) {
  final startDateLabel = formatLingScheduleDayTitle(strings, startAt);
  final startTimeLabel = _formatScheduleClock(startAt);
  if (isPoint) {
    return '$startDateLabel\n$startTimeLabel';
  }
  final endTimeLabel = _formatScheduleClock(endAt);
  return '$startDateLabel\n$startTimeLabel - $endTimeLabel';
}

List<_DetailLine> _eventMoreLines(LingStrings strings, LingEvent event) {
  final lines = <_DetailLine>[
    _DetailLine(
      label: strings.eventSourceLabel,
      value: _formatEventSource(strings, event),
    ),
    _DetailLine(label: strings.eventTimezoneLabel, value: event.timezone),
  ];
  final syncState = _formatEventSyncState(strings, event.syncState);
  if (syncState.isNotEmpty) {
    lines.add(_DetailLine(label: strings.eventSyncLabel, value: syncState));
  }
  if (event.isRecurring && event.occurrenceStartAt != null) {
    final occurrence = _formatDetailDateTime(
      strings,
      event.occurrenceStartAt!.toLocal(),
    );
    lines.add(
      _DetailLine(
        label: strings.eventOccurrenceLabel,
        value: event.isOccurrenceOverride
            ? (strings.isZh ? '$occurrence · 已单独修改' : '$occurrence · edited')
            : occurrence,
      ),
    );
  }
  final attendees = _formatAttendees(strings, event.attendees);
  if (attendees.isNotEmpty) {
    lines.add(
      _DetailLine(label: strings.eventAttendeesLabel, value: attendees),
    );
  }
  if (event.focusModeEnabled) {
    lines.add(
      _DetailLine(
        label: strings.eventFocusModeLabel,
        value: strings.isZh ? '已开启' : 'On',
      ),
    );
  }
  final createdAt = event.createdAt;
  if (createdAt != null) {
    lines.add(
      _DetailLine(
        label: strings.eventCreatedAtLabel,
        value: _formatDetailDateTime(strings, createdAt.toLocal()),
      ),
    );
  }
  final updatedAt = event.updatedAt;
  if (updatedAt != null) {
    lines.add(
      _DetailLine(
        label: strings.eventUpdatedAtLabel,
        value: _formatDetailDateTime(strings, updatedAt.toLocal()),
      ),
    );
  }
  return lines;
}

String _formatEventStatus(LingStrings strings, String value) {
  switch (value.trim().toLowerCase()) {
    case 'scheduled':
      return strings.isZh ? '已安排' : 'Scheduled';
    case 'completed':
      return strings.isZh ? '已完成' : 'Completed';
    case 'cancelled':
      return strings.isZh ? '已取消' : 'Cancelled';
    case '':
      return strings.tbd;
    default:
      return value.trim();
  }
}

String _formatEventTimeShape(LingStrings strings, LingEvent event) {
  if (event.isPoint) {
    return strings.isZh ? '时间点' : 'Point in time';
  }
  return strings.isZh ? '开始和结束' : 'Start and end';
}

String _formatEventSource(LingStrings strings, LingEvent event) {
  final calendarTitle = '${event.metadata['calendar_title'] ?? ''}'.trim();
  if (calendarTitle.isNotEmpty) {
    return calendarTitle;
  }
  final source = event.source.trim().toLowerCase();
  if (source.isEmpty || source == 'ling') {
    return strings.sourceLing;
  }
  if (source == 'apple') {
    return strings.sourceApple;
  }
  final provider = event.provider.trim();
  return provider.isNotEmpty && provider != source ? provider : source;
}

String _formatEventSyncState(LingStrings strings, String value) {
  switch (value.trim().toLowerCase()) {
    case 'pending':
      return strings.isZh ? '待同步' : 'Pending';
    case 'linked':
    case 'synced':
      return strings.isZh ? '已同步' : 'Synced';
    case 'imported':
      return strings.isZh ? '已导入' : 'Imported';
    case 'failed':
      return strings.isZh ? '同步失败' : 'Failed';
    case '':
      return '';
    default:
      return value.trim();
  }
}

String _formatAttendees(
  LingStrings strings,
  List<Map<String, dynamic>> attendees,
) {
  final labels = attendees
      .map(_attendeeLabel)
      .where((label) => label.isNotEmpty)
      .take(4)
      .toList(growable: false);
  if (labels.isEmpty) {
    return '';
  }
  final remaining = attendees.length - labels.length;
  if (remaining <= 0) {
    return labels.join(strings.isZh ? '、' : ', ');
  }
  final suffix = strings.isZh ? '等 $remaining 人' : '+$remaining more';
  return '${labels.join(strings.isZh ? '、' : ', ')} $suffix';
}

String _metadataMarkdown(Map<String, dynamic> metadata) {
  final value = metadata['markdown'];
  if (value is String) {
    return value.trim();
  }
  return '';
}

String _formatDetailDateTime(LingStrings strings, DateTime value) {
  return '${formatLingScheduleDayTitle(strings, value)} ${_formatScheduleClock(value)}';
}

String _attendeeLabel(Map<String, dynamic> attendee) {
  const keys = <String>[
    'name',
    'display_name',
    'displayName',
    'email',
    'address',
  ];
  for (final key in keys) {
    final value = '${attendee[key] ?? ''}'.trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

String _formatScheduleClock(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
