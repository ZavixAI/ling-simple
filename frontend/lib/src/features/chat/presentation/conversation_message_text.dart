import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/chat/application/agent_file_reference.dart';
import 'package:ling/src/features/chat/application/conversation_entry.dart';
import 'package:ling/src/features/chat/application/object_reference.dart';
import 'package:ling/src/features/chat/presentation/agent_markdown_image.dart';
import 'package:ling/src/features/chat/presentation/object_reference_card.dart';
import 'package:ling/src/shared/models/font_size_preference.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/notice.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

final RegExp _conversationWebUrlPattern = RegExp(
  r'''(?:(?:https?:\/\/)|(?:www\.))[^\s<>()\[\]{}"'，。！？；：、）《》「」『』]+''',
  caseSensitive: false,
);

const String _trailingLinkPunctuation = '.,!?;:，。！？；：、）)]}》」』';

Uri? _normalizeConversationWebUri(String? rawLink) {
  final value = rawLink?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  final normalized = value.toLowerCase().startsWith('www.')
      ? 'https://$value'
      : value;
  final uri = Uri.tryParse(normalized);
  if (uri == null) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return null;
  }
  return uri;
}

Future<void> _openConversationWebLink(
  BuildContext context,
  String? rawLink,
) async {
  final uri = _normalizeConversationWebUri(rawLink);
  if (uri == null) {
    return;
  }
  final confirmed = await showLingAdaptiveConfirmationDialog(
    context: context,
    title: '打开链接',
    message: uri.toString(),
    detailMessage: 'Ling 将在系统浏览器中打开此链接，请确认来源可信。',
    cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
    confirmLabel: '打开',
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showLingTopNotice(context, '无法打开链接');
    }
  } catch (_) {
    if (context.mounted) {
      showLingTopNotice(context, '无法打开链接');
    }
  }
}

({String link, String trailing}) _splitTrailingLinkPunctuation(String rawLink) {
  var link = rawLink;
  var trailing = '';
  while (link.isNotEmpty &&
      _trailingLinkPunctuation.contains(link.characters.last)) {
    trailing = '${link.characters.last}$trailing';
    link = link.characters.skipLast(1).toString();
  }
  return (link: link, trailing: trailing);
}

class LingSelectableMessageText extends StatefulWidget {
  const LingSelectableMessageText({
    super.key,
    required this.entry,
    required this.style,
  });

  final LingConversationEntry entry;
  final TextStyle style;

  @override
  State<LingSelectableMessageText> createState() =>
      _LingSelectableMessageTextState();
}

class _LingSelectableMessageTextState extends State<LingSelectableMessageText> {
  final List<TapGestureRecognizer> _linkRecognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _clearLinkRecognizers();
    super.dispose();
  }

  void _clearLinkRecognizers() {
    for (final recognizer in _linkRecognizers) {
      recognizer.dispose();
    }
    _linkRecognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(
      context,
    ).style.merge(widget.style);
    _clearLinkRecognizers();
    final textChild = SelectableText.rich(
      TextSpan(
        children: _buildTextSpans(
          context,
          text: widget.entry.text,
          style: effectiveStyle,
          enableLinks: true,
        ),
      ),
      key: Key('conversation_message_text_${widget.entry.id}'),
      style: effectiveStyle,
      textWidthBasis: TextWidthBasis.longestLine,
    );
    return textChild;
  }

  List<InlineSpan> _buildTextSpans(
    BuildContext context, {
    required String text,
    required TextStyle style,
    required bool enableLinks,
  }) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    final linkStyle = style.copyWith(
      color: context.palette.accent,
      decoration: TextDecoration.underline,
      decorationColor: context.palette.accent,
    );
    for (final match in _conversationWebUrlPattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final rawLink = match.group(0)!;
      final split = _splitTrailingLinkPunctuation(rawLink);
      if (split.link.isEmpty) {
        spans.add(TextSpan(text: rawLink));
      } else {
        TapGestureRecognizer? recognizer;
        if (enableLinks) {
          recognizer = TapGestureRecognizer()
            ..onTap = () => _openConversationWebLink(context, split.link);
          _linkRecognizers.add(recognizer);
        }
        spans.add(
          TextSpan(text: split.link, style: linkStyle, recognizer: recognizer),
        );
        if (split.trailing.isNotEmpty) {
          spans.add(TextSpan(text: split.trailing));
        }
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }
    return spans;
  }
}

class LingAssistantMarkdown extends StatelessWidget {
  const LingAssistantMarkdown({
    super.key,
    required this.markdown,
    this.selectable = false,
    this.fontSizeLevel = LingFontSizeLevel.fallback,
    this.onActionPrompt,
    this.onLingAction,
    this.onQuestionnaireSubmit,
    this.questionnaireResponses = const <String, LingQuestionnaireResponse>{},
    this.canSubmitQuestionnaire = false,
    this.questionnaireKeyPrefix,
    this.debugSourceId,
    this.onOpenObjectReference,
    this.contentBeforeActions,
  });

  final String markdown;
  final bool selectable;
  final LingFontSizeLevel fontSizeLevel;
  final ValueChanged<String>? onActionPrompt;
  final ValueChanged<LingChatAction>? onLingAction;
  final FutureOr<void> Function(LingQuestionnaireSubmission submission)?
  onQuestionnaireSubmit;
  final Map<String, LingQuestionnaireResponse> questionnaireResponses;
  final bool canSubmitQuestionnaire;
  final String? questionnaireKeyPrefix;
  final String? debugSourceId;
  final ValueChanged<LingObjectReference>? onOpenObjectReference;
  final Widget? contentBeforeActions;

  static final RegExp _horizontalRulePattern = RegExp(
    r'^[ ]{0,3}((\*\s*){3,}|(-\s*){3,}|(_\s*){3,})$',
    multiLine: true,
  );
  static const int _parseCacheLimit = 64;
  static final Map<
    ({String markdown, String? questionnaireKeyPrefix}),
    _LingAssistantMarkdownParsedContent
  >
  _parseCache =
      <
        ({String markdown, String? questionnaireKeyPrefix}),
        _LingAssistantMarkdownParsedContent
      >{};

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final parsedContent = _parseMarkdownContent(
      markdown: markdown,
      questionnaireKeyPrefix: questionnaireKeyPrefix,
    );
    final parsedReferences = parsedContent.parsedReferences;
    final parsedActions = parsedContent.parsedActions;
    final normalizedMarkdown = parsedContent.normalizedMarkdown;
    _logQuestionnaireDebugIfNeeded(
      markdown: parsedContent.effectiveMarkdown,
      rawMarkdown: markdown,
      sourceId: debugSourceId ?? questionnaireKeyPrefix,
      parsedActions: parsedActions,
      canSubmit: canSubmitQuestionnaire,
    );
    final effectiveSelectable =
        selectable && !parsedContent.containsMarkdownImage;
    final isDark = context.isDarkMode;
    final bodyLineHeight = context.isCompactPhoneWidth ? 1.6 : 1.7;
    final markdownStyleSheet = MarkdownStyleSheet.fromTheme(Theme.of(context))
        .copyWith(
          p: TextStyle(
            fontSize: scaleLingFontSize(fontSizeLevel, 15),
            height: bodyLineHeight,
            color: palette.textPrimary,
          ),
          a: TextStyle(
            color: palette.accent,
            decoration: TextDecoration.underline,
            decorationColor: palette.accent,
          ),
          code: TextStyle(
            fontFamily: 'monospace',
            fontSize: scaleLingFontSize(fontSizeLevel, 13),
            color: palette.textPrimary,
          ),
          codeblockDecoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(16),
          ),
          blockquote: TextStyle(
            fontSize: scaleLingFontSize(fontSizeLevel, 15),
            height: bodyLineHeight,
            color: palette.textSecondary,
          ),
          blockquotePadding: isDark
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
              : EdgeInsets.zero,
          blockquoteDecoration: BoxDecoration(
            color: isDark
                ? palette.surfaceMuted.withValues(alpha: 0.34)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(isDark ? 12 : 0),
          ),
          strong: TextStyle(
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final reference in parsedReferences.references) ...[
            SelectionContainer.disabled(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom:
                      normalizedMarkdown.isNotEmpty ||
                          contentBeforeActions != null ||
                          parsedActions.actions.isNotEmpty ||
                          parsedActions.cards.isNotEmpty ||
                          parsedActions.questionnaires.isNotEmpty
                      ? 8
                      : 0,
                ),
                child: LingObjectReferenceCard(
                  reference: reference,
                  compact: true,
                  onTap: onOpenObjectReference == null
                      ? null
                      : () => onOpenObjectReference!(reference),
                ),
              ),
            ),
          ],
          if (normalizedMarkdown.isNotEmpty ||
              parsedActions.questionnaires.isNotEmpty)
            ..._buildMarkdownQuestionnaireFlow(
              context: context,
              markdown: normalizedMarkdown,
              questionnaires: parsedActions.questionnaires,
              selectable: effectiveSelectable,
              styleSheet: markdownStyleSheet,
            ),
          ?contentBeforeActions,
          if (parsedActions.actions.isNotEmpty &&
              (onActionPrompt != null || onLingAction != null)) ...[
            if (normalizedMarkdown.isNotEmpty || contentBeforeActions != null)
              const SizedBox(height: 8),
            SelectionContainer.disabled(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final action in parsedActions.actions)
                    _LingMarkdownActionButton(
                      action: action,
                      onPressed: () {
                        if (onLingAction != null) {
                          onLingAction?.call(action);
                          return;
                        }
                        final prompt = action.prompt;
                        if (prompt != null) {
                          onActionPrompt?.call(prompt);
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
          if (parsedActions.cards.isNotEmpty) ...[
            if (normalizedMarkdown.isNotEmpty ||
                contentBeforeActions != null ||
                parsedActions.actions.isNotEmpty)
              const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  static _LingAssistantMarkdownParsedContent _parseMarkdownContent({
    required String markdown,
    required String? questionnaireKeyPrefix,
  }) {
    final cacheKey = (
      markdown: markdown,
      questionnaireKeyPrefix: questionnaireKeyPrefix,
    );
    final cached = _parseCache.remove(cacheKey);
    if (cached != null) {
      _parseCache[cacheKey] = cached;
      return cached;
    }

    final effectiveMarkdown = _normalizeTransportEncodedMarkdown(markdown);
    final parsedReferences = LingObjectReferenceCodec.parse(effectiveMarkdown);
    final parsedActions = _LingMarkdownActionParseResult.parse(
      parsedReferences.remainingText,
      questionnaireKeyPrefix:
          questionnaireKeyPrefix ??
          _defaultQuestionnaireKeyPrefix(effectiveMarkdown),
    );
    final normalizedMarkdown = _hideIncompleteStreamingAgentImage(
      parsedActions.markdownWithoutActions,
    ).replaceAll(_horizontalRulePattern, '').trim();
    final parsedContent = _LingAssistantMarkdownParsedContent(
      effectiveMarkdown: effectiveMarkdown,
      parsedReferences: parsedReferences,
      parsedActions: parsedActions,
      normalizedMarkdown: normalizedMarkdown,
      containsMarkdownImage: _containsMarkdownImage(normalizedMarkdown),
    );
    _parseCache[cacheKey] = parsedContent;
    if (_parseCache.length > _parseCacheLimit) {
      _parseCache.remove(_parseCache.keys.first);
    }
    return parsedContent;
  }

  List<Widget> _buildMarkdownQuestionnaireFlow({
    required BuildContext context,
    required String markdown,
    required List<LingQuestionnaire> questionnaires,
    required bool selectable,
    required MarkdownStyleSheet styleSheet,
  }) {
    final widgets = <Widget>[];
    var remaining = markdown;
    for (final questionnaire in questionnaires) {
      final placeholder = questionnaire.placeholder;
      if (placeholder == null) {
        continue;
      }
      final placeholderIndex = remaining.indexOf(placeholder);
      if (placeholderIndex < 0) {
        continue;
      }
      _addMarkdownSegment(
        widgets,
        context: context,
        markdown: remaining.substring(0, placeholderIndex).trim(),
        selectable: selectable,
        styleSheet: styleSheet,
      );
      _addQuestionnaireCard(widgets, questionnaire);
      remaining = remaining.substring(placeholderIndex + placeholder.length);
    }
    _addMarkdownSegment(
      widgets,
      context: context,
      markdown: remaining.trim(),
      selectable: selectable,
      styleSheet: styleSheet,
    );
    for (final questionnaire in questionnaires) {
      if (questionnaire.placeholder == null ||
          !markdown.contains(questionnaire.placeholder!)) {
        _addQuestionnaireCard(widgets, questionnaire);
      }
    }
    return widgets;
  }

  void _addMarkdownSegment(
    List<Widget> widgets, {
    required BuildContext context,
    required String markdown,
    required bool selectable,
    required MarkdownStyleSheet styleSheet,
  }) {
    if (markdown.isEmpty) {
      return;
    }
    if (widgets.isNotEmpty) {
      widgets.add(const SizedBox(height: 12));
    }
    widgets.add(
      MarkdownBody(
        data: markdown,
        selectable: selectable,
        softLineBreak: true,
        styleSheet: styleSheet,
        onTapLink: (_, href, _) => _openConversationWebLink(context, href),
        builders: <String, MarkdownElementBuilder>{
          'pre': _LingMarkdownCodeBlockBuilder(
            codeStyle: styleSheet.code,
            codeBlockPadding: styleSheet.codeblockPadding,
            selectable: selectable,
          ),
        },
        imageBuilder: (uri, title, alt) {
          final raw = uri.toString();
          if (!isLingAgentWorkspaceFileReference(raw)) {
            return Image.network(raw, semanticLabel: alt, fit: BoxFit.contain);
          }
          final path = normalizeLingAgentFilePath(raw);
          if (resolveLingAgentFileKind(path) != LingAgentFileKind.image) {
            return const SizedBox.shrink();
          }
          return LingMarkdownAgentImage(path: path, alt: alt);
        },
      ),
    );
  }

  void _addQuestionnaireCard(
    List<Widget> widgets,
    LingQuestionnaire questionnaire,
  ) {
    _debugLogQuestionnaire(
      '[Ling][QuestionnaireDebug] add card '
      'id=${questionnaire.id} title=${_debugCompact(questionnaire.title)} '
      'questions=${questionnaire.questions.length} '
      'canSubmit=$canSubmitQuestionnaire '
      'hasSubmitCallback=${onQuestionnaireSubmit != null} '
      'hasResponse=${questionnaireResponses.containsKey(questionnaire.id)} '
      'widgetsBefore=${widgets.length}',
    );
    if (widgets.isNotEmpty) {
      widgets.add(const SizedBox(height: 12));
    }
    widgets.add(
      SelectionContainer.disabled(
        child: SizedBox(
          width: double.infinity,
          child: LingQuestionnaireCard(
            questionnaire: questionnaire,
            response: questionnaireResponses[questionnaire.id],
            canSubmit: canSubmitQuestionnaire && onQuestionnaireSubmit != null,
            onSubmit: onQuestionnaireSubmit,
          ),
        ),
      ),
    );
  }
}

class _LingAssistantMarkdownParsedContent {
  const _LingAssistantMarkdownParsedContent({
    required this.effectiveMarkdown,
    required this.parsedReferences,
    required this.parsedActions,
    required this.normalizedMarkdown,
    required this.containsMarkdownImage,
  });

  final String effectiveMarkdown;
  final LingObjectReferenceParseResult parsedReferences;
  final _LingMarkdownActionParseResult parsedActions;
  final String normalizedMarkdown;
  final bool containsMarkdownImage;
}

void _logQuestionnaireDebugIfNeeded({
  required String markdown,
  required String rawMarkdown,
  required String? sourceId,
  required _LingMarkdownActionParseResult parsedActions,
  required bool canSubmit,
}) {
  if (!_looksLikeQuestionnaireDebugCandidate(markdown) &&
      !_looksLikeQuestionnaireDebugCandidate(rawMarkdown)) {
    return;
  }
  final snippet = _questionnaireDebugSnippet(markdown);
  final rawChanged = rawMarkdown != markdown;
  final message =
      '[Ling][QuestionnaireDebug] markdown parse '
      'source=${_debugCompact(sourceId ?? '')} '
      'len=${markdown.length} rawLen=${rawMarkdown.length} '
      'transportDecoded=$rawChanged hash=${markdown.hashCode} '
      'parsed=${parsedActions.questionnaires.length} '
      'actions=${parsedActions.actions.length} cards=${parsedActions.cards.length} '
      'failures=${parsedActions.questionnaireFailures.length} '
      'canSubmit=$canSubmit '
      'plainOpen=${markdown.contains('<ling-questionnaire')} '
      'plainClose=${markdown.contains('</ling-questionnaire')} '
      'escapedClose=${markdown.contains(r'<\/ling-questionnaire')} '
      'htmlOpen=${markdown.contains('&lt;ling-questionnaire')} '
      'htmlClose=${markdown.contains('&lt;/ling-questionnaire')} '
      'response=${markdown.contains('ling-questionnaire-response')} '
      'failure=${_debugCompact(parsedActions.questionnaireFailures.join(' | '), maxLength: 220)} '
      'snippet=${_debugCompact(snippet, maxLength: 260)}';
  _debugLogQuestionnaire(
    message,
    fields: <String, Object?>{
      'source_id': sourceId,
      'length': markdown.length,
      'raw_length': rawMarkdown.length,
      'hash': markdown.hashCode,
      'raw_hash': rawMarkdown.hashCode,
      'transport_decoded': rawChanged,
      'parsed_questionnaires': parsedActions.questionnaires.length,
      'questionnaire_failures': parsedActions.questionnaireFailures,
      'parsed_actions': parsedActions.actions.length,
      'parsed_cards': parsedActions.cards.length,
      'can_submit': canSubmit,
      'contains_plain_open': markdown.contains('<ling-questionnaire'),
      'contains_plain_close': markdown.contains('</ling-questionnaire'),
      'contains_escaped_close': markdown.contains(r'<\/ling-questionnaire'),
      'contains_html_open': markdown.contains('&lt;ling-questionnaire'),
      'contains_html_close': markdown.contains('&lt;/ling-questionnaire'),
      'contains_response': markdown.contains('ling-questionnaire-response'),
      'snippet': snippet,
      'raw_snippet': rawMarkdown == markdown
          ? null
          : _questionnaireDebugSnippet(rawMarkdown),
    },
  );
}

void _debugLogQuestionnaire(
  String message, {
  Map<String, Object?> fields = const <String, Object?>{},
}) {
  assert(() {
    AppLogger.debug(message, category: 'chat', fields: fields);
    return true;
  }());
}

String _normalizeTransportEncodedMarkdown(String markdown) {
  final value = markdown.trim();
  if (value.length < 2 || !value.startsWith('"') || !value.endsWith('"')) {
    return markdown;
  }
  if (!value.contains(r'\"') &&
      !value.contains(r'\n') &&
      !value.contains('ling-questionnaire')) {
    return markdown;
  }
  try {
    final decoded = jsonDecode(value);
    if (decoded is String && decoded.trim().isNotEmpty) {
      return decoded;
    }
  } catch (_) {
    return markdown;
  }
  return markdown;
}

bool _looksLikeQuestionnaireDebugCandidate(String markdown) {
  final lower = markdown.toLowerCase();
  return lower.contains('ling-questionnaire') || markdown.contains('问卷');
}

String _questionnaireDebugSnippet(String markdown) {
  final lower = markdown.toLowerCase();
  var index = lower.indexOf('ling-questionnaire');
  if (index < 0) {
    index = markdown.indexOf('问卷');
  }
  if (index < 0) {
    return markdown.characters.take(220).toString();
  }
  final start = (index - 80).clamp(0, markdown.length).toInt();
  final end = (index + 220).clamp(0, markdown.length).toInt();
  return markdown.substring(start, end);
}

String _debugCompact(String value, {int maxLength = 120}) {
  final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= maxLength) {
    return compact;
  }
  return '${compact.substring(0, maxLength)}...';
}

bool _containsMarkdownImage(String markdown) {
  if (markdown.isEmpty) {
    return false;
  }
  return RegExp(
    r'!\[[^\]]*\]\([^)]+\)|<img\s',
    caseSensitive: false,
  ).hasMatch(markdown);
}

String _hideIncompleteStreamingAgentImage(String markdown) {
  if (markdown.isEmpty) {
    return markdown;
  }
  final imageStart = markdown.lastIndexOf('![');
  if (imageStart < 0) {
    return markdown;
  }
  final altEnd = markdown.indexOf('](', imageStart + 2);
  if (altEnd < 0) {
    return markdown;
  }
  final targetStart = altEnd + 2;
  final closingParen = markdown.indexOf(')', targetStart);
  if (closingParen >= 0) {
    return markdown;
  }
  final target = markdown.substring(targetStart).trimLeft();
  if (!_looksLikeStreamingAgentImageTarget(target)) {
    return markdown;
  }
  return markdown.substring(0, imageStart).trimRight();
}

bool _looksLikeStreamingAgentImageTarget(String target) {
  if (target.isEmpty) {
    return false;
  }
  final lower = target.toLowerCase();
  const prefixes = <String>[
    'file:///app/agents/',
    'file://app/agents/',
    '/app/agents/',
    '/sage-workspace/',
    'sage-workspace/',
  ];
  for (final prefix in prefixes) {
    if (lower.startsWith(prefix) || prefix.startsWith(lower)) {
      return true;
    }
  }
  return false;
}

String _defaultQuestionnaireKeyPrefix(String markdown) {
  return 'inline_${markdown.length}_${markdown.hashCode & 0x7fffffff}';
}

enum LingChatActionKind { prompt, permission, settings }

enum LingChatActionTarget { notification, calendar, location }

class LingChatAction {
  const LingChatAction._({
    required this.label,
    required this.kind,
    this.target,
    this.prompt,
  });

  final String label;
  final LingChatActionKind kind;
  final LingChatActionTarget? target;
  final String? prompt;

  String get keySuffix {
    final targetName = target?.name ?? 'none';
    final promptValue = prompt ?? '';
    return '${label}_${kind.name}_${targetName}_$promptValue';
  }

  static LingChatAction? fromAttributes(Map<String, String> attrs) {
    final label = (attrs['label'] ?? '').trim();
    if (label.isEmpty) {
      return null;
    }

    final prompt = (attrs['prompt'] ?? '').trim();
    final rawType = (attrs['type'] ?? '').trim().toLowerCase();
    if (rawType.isEmpty || rawType == 'prompt') {
      if (prompt.isEmpty) {
        return null;
      }
      return LingChatAction._(
        label: label,
        kind: LingChatActionKind.prompt,
        prompt: prompt,
      );
    }

    final target = _parseTarget(attrs['target']);
    if (target == null) {
      return null;
    }

    switch (rawType) {
      case 'permission':
        return LingChatAction._(
          label: label,
          kind: LingChatActionKind.permission,
          target: target,
        );
      case 'settings':
        if (target == LingChatActionTarget.location) {
          return null;
        }
        return LingChatAction._(
          label: label,
          kind: LingChatActionKind.settings,
          target: target,
        );
      default:
        return null;
    }
  }

  static LingChatActionTarget? _parseTarget(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'notification':
      case 'notifications':
        return LingChatActionTarget.notification;
      case 'calendar':
      case 'apple_calendar':
      case 'apple-calendar':
        return LingChatActionTarget.calendar;
      case 'location':
        return LingChatActionTarget.location;
      default:
        return null;
    }
  }
}

class _LingMarkdownActionParseResult {
  const _LingMarkdownActionParseResult({
    required this.markdownWithoutActions,
    required this.actions,
    required this.cards,
    required this.questionnaires,
    required this.questionnaireFailures,
  });

  final String markdownWithoutActions;
  final List<LingChatAction> actions;
  final List<LingChatCard> cards;
  final List<LingQuestionnaire> questionnaires;
  final List<String> questionnaireFailures;

  static final RegExp _actionTagPattern = RegExp(
    r'<ling-action\s+([^>]*?)\/>',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _cardTagPattern = RegExp(
    r'<ling-card\s+([^>]*?)\/>',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _questionnaireOpenTagPattern = RegExp(
    r'<ling-questionnaire(?:\s+([^>]*?))?>',
    caseSensitive: false,
  );
  static const String _questionnairePlaceholderPrefix =
      '\uE000ling_questionnaire_';
  static final RegExp _incompleteActionTagPattern = RegExp(
    r'<ling-action\b[^>]*$',
    caseSensitive: false,
  );
  static final RegExp _incompleteCardTagPattern = RegExp(
    r'<ling-card\b[^>]*$',
    caseSensitive: false,
  );
  static final RegExp _incompleteQuestionnaireTagPattern = RegExp(
    r'<ling-questionnaire\b[\s\S]*$',
    caseSensitive: false,
  );
  static final RegExp _attributePattern = RegExp(
    r'([a-zA-Z_][a-zA-Z0-9_-]*)="([^"]*)"',
  );
  static final RegExp _fencePattern = RegExp(r'^\s*(```|~~~)');

  static _LingMarkdownActionParseResult parse(
    String markdown, {
    required String questionnaireKeyPrefix,
  }) {
    final actions = <LingChatAction>[];
    final cards = <LingChatCard>[];
    final questionnaires = <LingQuestionnaire>[];
    final questionnaireFailures = <String>[];
    final lines = _normalizeLingProtocolHtmlEntities(markdown).split('\n');
    var inCodeFence = false;
    StringBuffer? questionnaireBuffer;
    final parsedLines = <String>[];
    for (final line in lines) {
      if (_fencePattern.hasMatch(line)) {
        inCodeFence = !inCodeFence;
        parsedLines.add(line);
        continue;
      }
      if (inCodeFence) {
        parsedLines.add(line);
        continue;
      }
      if (questionnaireBuffer != null) {
        questionnaireBuffer
          ..writeln()
          ..write(line);
        if (_containsQuestionnaireCloseTag(line)) {
          parsedLines.add(
            _parseActionsOutsideInlineCode(
              questionnaireBuffer.toString(),
              actions,
              cards,
              questionnaires,
              questionnaireFailures,
              questionnaireKeyPrefix,
            ),
          );
          questionnaireBuffer = null;
        }
        continue;
      }
      if (line.toLowerCase().contains('<ling-questionnaire') &&
          !_containsQuestionnaireCloseTag(line)) {
        questionnaireBuffer = StringBuffer(line);
        continue;
      }
      parsedLines.add(
        _parseActionsOutsideInlineCode(
          line,
          actions,
          cards,
          questionnaires,
          questionnaireFailures,
          questionnaireKeyPrefix,
        ),
      );
    }
    return _LingMarkdownActionParseResult(
      markdownWithoutActions: parsedLines.join('\n'),
      actions: List<LingChatAction>.unmodifiable(actions),
      cards: List<LingChatCard>.unmodifiable(cards),
      questionnaires: List<LingQuestionnaire>.unmodifiable(questionnaires),
      questionnaireFailures: List<String>.unmodifiable(questionnaireFailures),
    );
  }

  static String _parseActionsOutsideInlineCode(
    String line,
    List<LingChatAction> actions,
    List<LingChatCard> cards,
    List<LingQuestionnaire> questionnaires,
    List<String> questionnaireFailures,
    String questionnaireKeyPrefix,
  ) {
    final buffer = StringBuffer();
    final segments = line.split('`');
    for (var index = 0; index < segments.length; index++) {
      if (index.isOdd) {
        buffer
          ..write('`')
          ..write(segments[index])
          ..write('`');
        continue;
      }
      var segment = segments[index];
      var questionnaireMatched = false;
      segment = segment.replaceAllMapped(_cardTagPattern, (match) {
        final attrs = _decodeAttributes(match.group(1)!);
        final card = LingChatCard.fromAttributes(attrs);
        if (card != null) {
          cards.add(card);
        }
        return '';
      });
      final beforeQuestionnaireReplace = segment;
      segment = _replaceQuestionnaireTags(
        segment,
        questionnaires: questionnaires,
        questionnaireFailures: questionnaireFailures,
        questionnaireKeyPrefix: questionnaireKeyPrefix,
      );
      questionnaireMatched = beforeQuestionnaireReplace != segment;
      if (!questionnaireMatched &&
          segment.toLowerCase().contains('<ling-questionnaire')) {
        questionnaireFailures.add(
          'tag_extract_no_match open=${segment.toLowerCase().indexOf('<ling-questionnaire')} close=${_indexOfQuestionnaireCloseTag(segment)} raw=${_debugQuestionnaireTagExcerpt(segment)}',
        );
      }
      segment = segment.replaceAllMapped(_actionTagPattern, (match) {
        if (actions.length >= 3) {
          return '';
        }
        final attrs = _decodeAttributes(match.group(1)!);
        final action = LingChatAction.fromAttributes(attrs);
        if (action != null) {
          actions.add(action);
        }
        return '';
      });
      buffer.write(
        segment
            .replaceAll(_incompleteActionTagPattern, '')
            .replaceAll(_incompleteCardTagPattern, '')
            .replaceAll(_incompleteQuestionnaireTagPattern, ''),
      );
    }
    return buffer.toString();
  }

  static String _replaceQuestionnaireTags(
    String segment, {
    required List<LingQuestionnaire> questionnaires,
    required List<String> questionnaireFailures,
    required String questionnaireKeyPrefix,
  }) {
    final buffer = StringBuffer();
    var cursor = 0;
    while (cursor < segment.length) {
      final openMatch = _questionnaireOpenTagPattern.matchAsPrefix(
        segment,
        cursor,
      );
      final nextOpen =
          openMatch ??
          _questionnaireOpenTagPattern.firstMatch(segment.substring(cursor));
      if (nextOpen == null) {
        buffer.write(segment.substring(cursor));
        break;
      }
      final openStart = openMatch != null ? cursor : cursor + nextOpen.start;
      final openEnd = openMatch != null ? openMatch.end : cursor + nextOpen.end;
      buffer.write(segment.substring(cursor, openStart));
      final closeStart = _indexOfQuestionnaireCloseTag(segment, start: openEnd);
      if (closeStart < 0) {
        questionnaireFailures.add(
          'close_tag_not_found open=$openStart raw=${_debugQuestionnaireTagExcerpt(segment)}',
        );
        buffer.write(segment.substring(openStart));
        break;
      }
      final closeEnd = _endOfQuestionnaireCloseTag(segment, closeStart);
      final rawJson = segment.substring(openEnd, closeStart);
      final generatedId =
          '${questionnaireKeyPrefix}_q${questionnaires.length + 1}';
      final questionnaire = LingQuestionnaire.fromPayload(
        attrs: _decodeAttributes(nextOpen.group(1) ?? ''),
        rawJson: rawJson,
        generatedId: generatedId,
        placeholder:
            '${_LingMarkdownActionParseResult._questionnairePlaceholderPrefix}${questionnaires.length + 1}',
        onFailure: (reason) {
          questionnaireFailures.add(
            '$generatedId:$reason len=${rawJson.length} raw=${_debugCompact(rawJson, maxLength: 180)}',
          );
        },
      );
      if (questionnaire == null) {
        buffer.write(
          _escapeHtmlForMarkdownText(segment.substring(openStart, closeEnd)),
        );
      } else {
        questionnaires.add(questionnaire);
        buffer.write(questionnaire.placeholder ?? '');
      }
      cursor = closeEnd;
    }
    return buffer.toString();
  }

  static Map<String, String> _decodeAttributes(String raw) {
    final attrs = <String, String>{};
    for (final attrMatch in _attributePattern.allMatches(raw)) {
      attrs[attrMatch.group(1)!] = _decodeAttribute(attrMatch.group(2) ?? '');
    }
    return attrs;
  }

  static String _decodeAttribute(String value) {
    return _decodeBasicHtmlEntities(value);
  }
}

bool _containsQuestionnaireCloseTag(String value) {
  return _indexOfQuestionnaireCloseTag(value) >= 0;
}

int _indexOfQuestionnaireCloseTag(String value, {int start = 0}) {
  final lower = value.toLowerCase();
  final plain = lower.indexOf('</ling-questionnaire', start);
  final escaped = lower.indexOf(r'<\/ling-questionnaire', start);
  if (plain < 0) {
    return escaped;
  }
  if (escaped < 0) {
    return plain;
  }
  return plain < escaped ? plain : escaped;
}

int _endOfQuestionnaireCloseTag(String value, int closeStart) {
  final closeEnd = value.indexOf('>', closeStart);
  return closeEnd < 0 ? value.length : closeEnd + 1;
}

String _debugQuestionnaireTagExcerpt(String value) {
  final lower = value.toLowerCase();
  var index = lower.indexOf('<ling-questionnaire');
  if (index < 0) {
    index = _indexOfQuestionnaireCloseTag(value);
  }
  if (index < 0) {
    return _debugCompact(value, maxLength: 220);
  }
  final closeIndex = _indexOfQuestionnaireCloseTag(value, start: index);
  final end = closeIndex < 0
      ? (index + 260).clamp(0, value.length).toInt()
      : (_endOfQuestionnaireCloseTag(value, closeIndex) + 80)
            .clamp(0, value.length)
            .toInt();
  return _debugCompact(value.substring(index, end), maxLength: 320);
}

String _normalizeLingProtocolHtmlEntities(String value) {
  if (!value.contains('&lt;ling-questionnaire') &&
      !value.contains('&lt;/ling-questionnaire')) {
    return value;
  }
  return _decodeBasicHtmlEntities(value);
}

String _decodeBasicHtmlEntities(String value) {
  return value
      .replaceAll('&quot;', '"')
      .replaceAll('&#34;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}

String _escapeHtmlForMarkdownText(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

sealed class LingChatCard {
  const LingChatCard();

  static LingChatCard? fromAttributes(Map<String, String> attrs) {
    return null;
  }
}

enum LingQuestionnaireQuestionType { singleChoice, multiChoice, freeText }

class LingQuestionnaire {
  const LingQuestionnaire({
    required this.id,
    required this.title,
    required this.questions,
    this.placeholder,
    this.timeout = Duration.zero,
  });

  final String id;
  final String title;
  final List<LingQuestionnaireQuestion> questions;
  final String? placeholder;
  final Duration timeout;

  static LingQuestionnaire? fromPayload({
    required Map<String, String> attrs,
    required String rawJson,
    required String generatedId,
    String? placeholder,
    ValueChanged<String>? onFailure,
  }) {
    final id = generatedId.trim();
    if (id.isEmpty) {
      onFailure?.call('empty_generated_id');
      return null;
    }
    final decoded = _decodeJsonObject(rawJson);
    if (decoded == null) {
      onFailure?.call('json_decode_failed');
      return null;
    }
    final questionsRaw = decoded['questions'];
    if (questionsRaw is! List) {
      onFailure?.call('questions_not_list type=${questionsRaw.runtimeType}');
      return null;
    }
    final questions = questionsRaw.indexed
        .map((item) {
          final rawQuestion = item.$2;
          if (rawQuestion is! Map) {
            onFailure?.call(
              'question_${item.$1 + 1}_not_map type=${rawQuestion.runtimeType}',
            );
            return null;
          }
          final question = LingQuestionnaireQuestion.fromJson(
            Map<String, Object?>.from(rawQuestion),
            generatedId: 'q${item.$1 + 1}',
          );
          if (question == null) {
            onFailure?.call(
              'question_${item.$1 + 1}_invalid raw=${_debugCompact(rawQuestion.toString(), maxLength: 160)}',
            );
          }
          return question;
        })
        .nonNulls
        .toList(growable: false);
    if (questions.isEmpty) {
      onFailure?.call('no_valid_questions count=${questionsRaw.length}');
      return null;
    }
    final rawTimeout =
        _asInt(attrs['timeout_seconds']) ?? _asInt(decoded['timeout_seconds']);
    final timeout = rawTimeout == null || rawTimeout <= 0
        ? Duration.zero
        : Duration(seconds: rawTimeout);
    return LingQuestionnaire(
      id: id,
      title: _asString(decoded['title']).trim(),
      questions: questions,
      placeholder: placeholder,
      timeout: timeout,
    );
  }

  static Map<String, Object?>? _decodeJsonObject(String rawJson) {
    for (final candidate in _jsonDecodeCandidates(rawJson)) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map) {
          return Map<String, Object?>.from(decoded);
        }
        if (decoded is String) {
          final nestedDecoded = jsonDecode(decoded);
          if (nestedDecoded is Map) {
            return Map<String, Object?>.from(nestedDecoded);
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static List<String> _jsonDecodeCandidates(String rawJson) {
    final normalized = rawJson.trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    final htmlDecoded = _decodeBasicHtmlEntities(normalized);
    final unescaped = normalized
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t');
    final htmlDecodedUnescaped = htmlDecoded
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t');
    return <String>{
      normalized,
      unescaped,
      htmlDecoded,
      htmlDecodedUnescaped,
      _normalizeSmartJsonQuotes(normalized),
      _normalizeSmartJsonQuotes(unescaped),
      _normalizeSmartJsonQuotes(htmlDecoded),
      _normalizeSmartJsonQuotes(htmlDecodedUnescaped),
    }.toList(growable: false);
  }
}

String _normalizeSmartJsonQuotes(String value) {
  return value
      .replaceAll('\u201c', '"')
      .replaceAll('\u201d', '"')
      .replaceAll('\u2018', "'")
      .replaceAll('\u2019', "'");
}

class LingQuestionnaireQuestion {
  const LingQuestionnaireQuestion({
    required this.id,
    required this.type,
    required this.text,
    this.options = const <LingQuestionnaireOption>[],
    this.allowOther = false,
    this.defaultValue,
    this.defaultValues = const <String>[],
    this.defaultText = '',
  });

  final String id;
  final LingQuestionnaireQuestionType type;
  final String text;
  final List<LingQuestionnaireOption> options;
  final bool allowOther;
  final String? defaultValue;
  final List<String> defaultValues;
  final String defaultText;

  static LingQuestionnaireQuestion? fromJson(
    Map<String, Object?> json, {
    required String generatedId,
  }) {
    final id = _asString(json['id']).trim().isNotEmpty
        ? _asString(json['id']).trim()
        : generatedId;
    final text = _asString(json['text']).trim();
    if (id.isEmpty || text.isEmpty) {
      return null;
    }
    final type = switch (_asString(json['type']).trim()) {
      'single_choice' => LingQuestionnaireQuestionType.singleChoice,
      'multi_choice' => LingQuestionnaireQuestionType.multiChoice,
      'free_text' => LingQuestionnaireQuestionType.freeText,
      _ => null,
    };
    if (type == null) {
      return null;
    }
    final rawOptions = json['options'];
    final optionItems = rawOptions is List ? rawOptions : const <Object?>[];
    final options = optionItems
        .map(LingQuestionnaireOption.fromJsonValue)
        .nonNulls
        .toList(growable: false);
    if (type != LingQuestionnaireQuestionType.freeText && options.isEmpty) {
      return null;
    }
    return LingQuestionnaireQuestion(
      id: id,
      type: type,
      text: text,
      options: options,
      allowOther: json['allow_other'] == true,
      defaultValue:
          _asNullableString(json['default'])?.trim() ??
          _asNullableString(json['default_value'])?.trim(),
      defaultValues: _asStringList(
        json.containsKey('default') ? json['default'] : json['default_values'],
      ),
      defaultText: _asString(json['default']).trim().isNotEmpty
          ? _asString(json['default']).trim()
          : _asString(json['default_text']).trim(),
    );
  }
}

class LingQuestionnaireOption {
  const LingQuestionnaireOption({required this.value, required this.label});

  final String value;
  final String label;

  static LingQuestionnaireOption? fromJsonValue(Object? raw) {
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty) {
        return null;
      }
      return LingQuestionnaireOption(value: value, label: value);
    }
    if (raw is! Map) {
      return null;
    }
    final json = Map<String, Object?>.from(raw);
    final label = _asString(json['label']).trim();
    final value = _asString(json['value']).trim().isNotEmpty
        ? _asString(json['value']).trim()
        : label;
    if (value.isEmpty || label.isEmpty) {
      return null;
    }
    return LingQuestionnaireOption(value: value, label: label);
  }
}

class LingQuestionnaireSubmission {
  const LingQuestionnaireSubmission({
    required this.questionnaire,
    required this.answers,
    required this.status,
  });

  final LingQuestionnaire questionnaire;
  final List<LingQuestionnaireAnswer> answers;
  final LingQuestionnaireResponseStatus status;

  String get agentText {
    final payload = <String, Object?>{
      'type': 'ling_questionnaire_response',
      'questionnaire_id': questionnaire.id,
      'status': status == LingQuestionnaireResponseStatus.timeoutDefault
          ? 'timeout_default'
          : 'submitted',
      'answers': answers.map((answer) => answer.toJson()).toList(),
    };
    return '<ling-questionnaire-response>${jsonEncode(payload)}</ling-questionnaire-response>';
  }

  String get displayText {
    final buffer = StringBuffer('问卷回答');
    for (final answer in answers) {
      buffer
        ..writeln()
        ..write(answer.questionText)
        ..write('：')
        ..write(answer.displayValue);
    }
    return buffer.toString();
  }
}

enum LingQuestionnaireResponseStatus { submitted, timeoutDefault }

class LingQuestionnaireResponse {
  const LingQuestionnaireResponse({
    required this.questionnaireId,
    required this.status,
    required this.answers,
  });

  final String questionnaireId;
  final LingQuestionnaireResponseStatus status;
  final List<LingQuestionnaireAnswer> answers;

  static final RegExp _responsePattern = RegExp(
    r'<ling-questionnaire-response>(.*?)<\/ling-questionnaire-response\s*>',
    caseSensitive: false,
    dotAll: true,
  );

  static LingQuestionnaireResponse? fromAgentText(String text) {
    final match = _responsePattern.firstMatch(text);
    if (match == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(match.group(1) ?? '');
      if (decoded is! Map) {
        return null;
      }
      final payload = Map<String, Object?>.from(decoded);
      if (_asString(payload['type']) != 'ling_questionnaire_response') {
        return null;
      }
      final questionnaireId = _asString(payload['questionnaire_id']).trim();
      final answersRaw = payload['answers'];
      if (questionnaireId.isEmpty || answersRaw is! List) {
        return null;
      }
      final answers = answersRaw
          .whereType<Map<Object?, Object?>>()
          .map(
            (answer) => LingQuestionnaireAnswer.fromJson(
              Map<String, Object?>.from(answer),
            ),
          )
          .nonNulls
          .toList(growable: false);
      return LingQuestionnaireResponse(
        questionnaireId: questionnaireId,
        status:
            _asString(payload['status']) == 'timeout_default' ||
                _asString(payload['status']) == 'timeoutDefault'
            ? LingQuestionnaireResponseStatus.timeoutDefault
            : LingQuestionnaireResponseStatus.submitted,
        answers: answers,
      );
    } catch (_) {
      return null;
    }
  }
}

class LingQuestionnaireAnswer {
  const LingQuestionnaireAnswer({
    required this.questionId,
    required this.questionText,
    required this.type,
    this.value,
    this.values = const <String>[],
    this.label,
    this.labels = const <String>[],
    this.text = '',
    this.otherText = '',
  });

  final String questionId;
  final String questionText;
  final LingQuestionnaireQuestionType type;
  final String? value;
  final List<String> values;
  final String? label;
  final List<String> labels;
  final String text;
  final String otherText;

  String get displayValue {
    if (type == LingQuestionnaireQuestionType.freeText) {
      return text.trim().isEmpty ? '未填写' : text.trim();
    }
    final parts = type == LingQuestionnaireQuestionType.singleChoice
        ? <String>[if ((label ?? '').trim().isNotEmpty) label!.trim()]
        : labels.where((item) => item.trim().isNotEmpty).toList();
    if (otherText.trim().isNotEmpty) {
      parts.add(otherText.trim());
    }
    return parts.isEmpty ? '未选择' : parts.join('、');
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'question': questionText,
      'type': switch (type) {
        LingQuestionnaireQuestionType.singleChoice => 'single_choice',
        LingQuestionnaireQuestionType.multiChoice => 'multi_choice',
        LingQuestionnaireQuestionType.freeText => 'free_text',
      },
      'answer': switch (type) {
        LingQuestionnaireQuestionType.singleChoice => value ?? '',
        LingQuestionnaireQuestionType.multiChoice => values,
        LingQuestionnaireQuestionType.freeText => text.trim(),
      },
      if (otherText.trim().isNotEmpty) 'other_text': otherText.trim(),
    };
  }

  static LingQuestionnaireAnswer? fromJson(Map<String, Object?> json) {
    final questionId = _asString(json['question_id']).trim();
    final questionText = _asString(json['question']).trim();
    final type = switch (_asString(json['type']).trim()) {
      'single_choice' => LingQuestionnaireQuestionType.singleChoice,
      'multi_choice' => LingQuestionnaireQuestionType.multiChoice,
      'free_text' => LingQuestionnaireQuestionType.freeText,
      _ => null,
    };
    if ((questionId.isEmpty && questionText.isEmpty) || type == null) {
      return null;
    }
    final answer = json['answer'];
    final answerList = _asStringList(answer);
    final answerText = _asString(answer);
    return LingQuestionnaireAnswer(
      questionId: questionId,
      questionText: questionText,
      type: type,
      value: _asNullableString(json['value']) ?? answerText,
      values: _asStringList(json['values']).isNotEmpty
          ? _asStringList(json['values'])
          : answerList,
      label: _asNullableString(json['label']) ?? answerText,
      labels: _asStringList(json['labels']).isNotEmpty
          ? _asStringList(json['labels'])
          : answerList,
      text: _asString(json['text']).isNotEmpty
          ? _asString(json['text'])
          : answerText,
      otherText: _asString(json['other_text']),
    );
  }
}

String _asString(Object? value) => value is String ? value : '';

String? _asNullableString(Object? value) => value is String ? value : null;

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

List<String> _asStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.whereType<String>().map((item) => item.trim()).toList();
}

class LingQuestionnaireCard extends StatefulWidget {
  const LingQuestionnaireCard({
    super.key,
    required this.questionnaire,
    this.response,
    this.canSubmit = false,
    this.onSubmit,
  });

  final LingQuestionnaire questionnaire;
  final LingQuestionnaireResponse? response;
  final bool canSubmit;
  final FutureOr<void> Function(LingQuestionnaireSubmission submission)?
  onSubmit;

  @override
  State<LingQuestionnaireCard> createState() => _LingQuestionnaireCardState();
}

class _LingQuestionnaireCardState extends State<LingQuestionnaireCard> {
  static const String _otherValue = '__ling_other__';

  final Map<String, String> _singleValues = <String, String>{};
  final Map<String, Set<String>> _multiValues = <String, Set<String>>{};
  final Map<String, TextEditingController> _otherControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _textControllers =
      <String, TextEditingController>{};
  Timer? _timeoutTimer;
  int _currentQuestionIndex = 0;
  bool _isSubmitting = false;

  bool get _isReadOnly => widget.response != null || !widget.canSubmit;

  @override
  void initState() {
    super.initState();
    _resetDraft();
    _scheduleTimeout();
  }

  @override
  void didUpdateWidget(LingQuestionnaireCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionnaire.id != widget.questionnaire.id) {
      _disposeControllers();
      _resetDraft();
      _currentQuestionIndex = 0;
    }
    if (oldWidget.canSubmit != widget.canSubmit ||
        oldWidget.response != widget.response ||
        oldWidget.questionnaire.timeout != widget.questionnaire.timeout) {
      _scheduleTimeout();
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final controller in _otherControllers.values) {
      controller.dispose();
    }
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _otherControllers.clear();
    _textControllers.clear();
  }

  void _resetDraft() {
    _singleValues.clear();
    _multiValues.clear();
    for (final question in widget.questionnaire.questions) {
      switch (question.type) {
        case LingQuestionnaireQuestionType.singleChoice:
          final defaultValue = _validSingleDefault(question);
          if (defaultValue != null) {
            _singleValues[question.id] = defaultValue;
          }
        case LingQuestionnaireQuestionType.multiChoice:
          _multiValues[question.id] = _validMultiDefaults(question);
        case LingQuestionnaireQuestionType.freeText:
          _textControllers[question.id] = TextEditingController(
            text: question.defaultText,
          );
      }
      if (question.allowOther) {
        _otherControllers[question.id] = TextEditingController();
      }
    }
  }

  String? _validSingleDefault(LingQuestionnaireQuestion question) {
    final value = question.defaultValue?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value == _otherValue && question.allowOther) {
      return value;
    }
    return question.options.any((option) => option.value == value)
        ? value
        : null;
  }

  Set<String> _validMultiDefaults(LingQuestionnaireQuestion question) {
    final optionValues = question.options.map((option) => option.value).toSet();
    return question.defaultValues
        .where(
          (value) =>
              optionValues.contains(value) ||
              (value == _otherValue && question.allowOther),
        )
        .toSet();
  }

  void _scheduleTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    if (!widget.canSubmit ||
        widget.response != null ||
        widget.questionnaire.timeout <= Duration.zero) {
      return;
    }
    _timeoutTimer = Timer(widget.questionnaire.timeout, () {
      if (!mounted || widget.response != null || !widget.canSubmit) {
        return;
      }
      unawaited(_submit(LingQuestionnaireResponseStatus.timeoutDefault));
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    final response = widget.response;
    final questions = widget.questionnaire.questions;
    final currentIndex = questions.isEmpty
        ? 0
        : _currentQuestionIndex.clamp(0, questions.length - 1).toInt();
    final currentQuestion = questions.isEmpty ? null : questions[currentIndex];
    final isLastQuestion = currentIndex >= questions.length - 1;
    _debugLogQuestionnaire(
      '[Ling][QuestionnaireDebug] card build '
      'id=${widget.questionnaire.id} '
      'title=${_debugCompact(widget.questionnaire.title)} '
      'questions=${widget.questionnaire.questions.length} '
      'canSubmit=${widget.canSubmit} readOnly=$_isReadOnly '
      'hasResponse=${response != null} isSubmitting=$_isSubmitting',
    );
    final cardTint = palette.glassElevatedTint.withValues(
      alpha: isDark ? 0.82 : 0.94,
    );
    return LingGlassSurface(
      key: ValueKey<String>('ling_questionnaire_${widget.questionnaire.id}'),
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      tone: LingGlassSurfaceTone.elevated,
      tintColor: cardTint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.questionnaire.title.trim().isNotEmpty)
                Expanded(
                  child: Text(
                    widget.questionnaire.title.trim(),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.22,
                    ),
                  ),
                )
              else
                const Spacer(),
              if (response != null)
                _QuestionnaireStatusPill(status: response.status)
              else if (questions.length > 1)
                Text(
                  '${currentIndex + 1}/${questions.length}',
                  style: TextStyle(
                    color: palette.textSecondary.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
            ],
          ),
          if (questions.length > 1) ...[
            const SizedBox(height: 10),
            _QuestionnaireProgressBar(
              progress: response != null
                  ? 1
                  : (currentIndex + 1) / questions.length,
            ),
          ],
          if (response != null) ...[
            const SizedBox(height: 12),
            _QuestionnaireResponseView(response: response),
          ] else if (currentQuestion != null) ...[
            const SizedBox(height: 14),
            _QuestionnaireQuestionView(
              question: currentQuestion,
              readOnly: _isReadOnly || _isSubmitting,
              singleValue: _singleValues[currentQuestion.id],
              multiValues: _multiValues[currentQuestion.id] ?? const <String>{},
              otherController: _otherControllers[currentQuestion.id],
              textController: _textControllers[currentQuestion.id],
              otherValue: _otherValue,
              onSingleChanged: (value) {
                setState(() {
                  _singleValues[currentQuestion.id] = value;
                });
              },
              onMultiChanged: (value, selected) {
                setState(() {
                  final values = _multiValues.putIfAbsent(
                    currentQuestion.id,
                    () => <String>{},
                  );
                  if (selected) {
                    values.add(value);
                  } else {
                    values.remove(value);
                  }
                });
              },
            ),
            const SizedBox(height: 14),
            _QuestionnaireActionBar(
              questionnaireId: widget.questionnaire.id,
              canGoBack: currentIndex > 0 && !_isSubmitting,
              canGoNext: !isLastQuestion && !_isSubmitting,
              canSubmit:
                  isLastQuestion &&
                  !_isReadOnly &&
                  !_isSubmitting &&
                  widget.onSubmit != null,
              readOnly: _isReadOnly,
              isSubmitting: _isSubmitting,
              onBack: () {
                setState(() {
                  _currentQuestionIndex = (_currentQuestionIndex - 1)
                      .clamp(0, questions.length - 1)
                      .toInt();
                });
              },
              onNext: () {
                setState(() {
                  _currentQuestionIndex = (_currentQuestionIndex + 1)
                      .clamp(0, questions.length - 1)
                      .toInt();
                });
              },
              onSubmit: () =>
                  unawaited(_submit(LingQuestionnaireResponseStatus.submitted)),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              '暂无问题',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit(LingQuestionnaireResponseStatus status) async {
    if (_isSubmitting || widget.response != null) {
      return;
    }
    final onSubmit = widget.onSubmit;
    if (onSubmit == null) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      await onSubmit(
        LingQuestionnaireSubmission(
          questionnaire: widget.questionnaire,
          answers: _buildAnswers(),
          status: status,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  List<LingQuestionnaireAnswer> _buildAnswers() {
    return widget.questionnaire.questions
        .map((question) {
          switch (question.type) {
            case LingQuestionnaireQuestionType.singleChoice:
              final value = _singleValues[question.id];
              final option = question.options
                  .where((option) => option.value == value)
                  .firstOrNull;
              final otherText = value == _otherValue
                  ? _otherControllers[question.id]?.text.trim() ?? ''
                  : '';
              return LingQuestionnaireAnswer(
                questionId: question.id,
                questionText: question.text,
                type: question.type,
                value: value,
                label: option?.label ?? (value == _otherValue ? '其他' : null),
                otherText: otherText,
              );
            case LingQuestionnaireQuestionType.multiChoice:
              final values = (_multiValues[question.id] ?? const <String>{})
                  .toList(growable: false);
              final labels = <String>[];
              for (final value in values) {
                final option = question.options
                    .where((option) => option.value == value)
                    .firstOrNull;
                if (option != null) {
                  labels.add(option.label);
                } else if (value == _otherValue) {
                  labels.add('其他');
                }
              }
              return LingQuestionnaireAnswer(
                questionId: question.id,
                questionText: question.text,
                type: question.type,
                values: values,
                labels: labels,
                otherText: values.contains(_otherValue)
                    ? _otherControllers[question.id]?.text.trim() ?? ''
                    : '',
              );
            case LingQuestionnaireQuestionType.freeText:
              return LingQuestionnaireAnswer(
                questionId: question.id,
                questionText: question.text,
                type: question.type,
                text: _textControllers[question.id]?.text.trim() ?? '',
              );
          }
        })
        .toList(growable: false);
  }
}

class _QuestionnaireProgressBar extends StatelessWidget {
  const _QuestionnaireProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final clamped = progress.clamp(0, 1).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.textTertiary.withValues(alpha: 0.18),
              ),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: clamped,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.82),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionnaireStatusPill extends StatelessWidget {
  const _QuestionnaireStatusPill({required this.status});

  final LingQuestionnaireResponseStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isTimeout = status == LingQuestionnaireResponseStatus.timeoutDefault;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: isTimeout ? 0.10 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: palette.accent.withValues(alpha: isTimeout ? 0.30 : 0.46),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTimeout
                  ? Icons.schedule_rounded
                  : Icons.check_circle_outline_rounded,
              size: 14,
              color: palette.accent,
            ),
            const SizedBox(width: 4),
            Text(
              isTimeout ? '已自动提交' : '已提交',
              style: TextStyle(
                color: palette.accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionnaireActionBar extends StatelessWidget {
  const _QuestionnaireActionBar({
    required this.questionnaireId,
    required this.canGoBack,
    required this.canGoNext,
    required this.canSubmit,
    required this.readOnly,
    required this.isSubmitting,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  final String questionnaireId;
  final bool canGoBack;
  final bool canGoNext;
  final bool canSubmit;
  final bool readOnly;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        LingGlassButton(
          minHeight: 36,
          width: 42,
          expand: false,
          radius: 18,
          tone: LingGlassSurfaceTone.muted,
          foregroundColor: palette.textPrimary,
          onPressed: canGoBack ? onBack : null,
          child: const Icon(Icons.chevron_left_rounded, size: 23),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LingGlassButton(
            key: ValueKey<String>('ling_questionnaire_submit_$questionnaireId'),
            minHeight: 40,
            radius: 20,
            tone: canGoNext
                ? LingGlassSurfaceTone.regular
                : LingGlassSurfaceTone.accent,
            foregroundColor: canGoNext ? palette.textPrimary : null,
            onPressed: isSubmitting
                ? null
                : canGoNext
                ? onNext
                : canSubmit
                ? onSubmit
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isSubmitting
                      ? '提交中'
                      : canGoNext
                      ? '继续'
                      : readOnly
                      ? '已过期'
                      : '提交',
                ),
                if (!isSubmitting && canGoNext) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionnaireQuestionView extends StatelessWidget {
  const _QuestionnaireQuestionView({
    required this.question,
    required this.readOnly,
    required this.singleValue,
    required this.multiValues,
    required this.otherController,
    required this.textController,
    required this.otherValue,
    required this.onSingleChanged,
    required this.onMultiChanged,
  });

  final LingQuestionnaireQuestion question;
  final bool readOnly;
  final String? singleValue;
  final Set<String> multiValues;
  final TextEditingController? otherController;
  final TextEditingController? textController;
  final String otherValue;
  final ValueChanged<String> onSingleChanged;
  final void Function(String value, bool selected) onMultiChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question.text,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            height: 1.32,
          ),
        ),
        const SizedBox(height: 10),
        switch (question.type) {
          LingQuestionnaireQuestionType.singleChoice => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in question.options)
                    _ChoiceChip(
                      label: option.label,
                      selected: singleValue == option.value,
                      readOnly: readOnly,
                      multi: false,
                      onTap: () => onSingleChanged(option.value),
                    ),
                  if (question.allowOther)
                    _ChoiceChip(
                      label: '其他',
                      selected: singleValue == otherValue,
                      readOnly: readOnly,
                      multi: false,
                      onTap: () => onSingleChanged(otherValue),
                    ),
                ],
              ),
              if (question.allowOther && singleValue == otherValue)
                _QuestionnaireTextField(
                  controller: otherController,
                  readOnly: readOnly,
                ),
            ],
          ),
          LingQuestionnaireQuestionType.multiChoice => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in question.options)
                    _ChoiceChip(
                      label: option.label,
                      selected: multiValues.contains(option.value),
                      readOnly: readOnly,
                      multi: true,
                      onTap: () => onMultiChanged(
                        option.value,
                        !multiValues.contains(option.value),
                      ),
                    ),
                  if (question.allowOther)
                    _ChoiceChip(
                      label: '其他',
                      selected: multiValues.contains(otherValue),
                      readOnly: readOnly,
                      multi: true,
                      onTap: () => onMultiChanged(
                        otherValue,
                        !multiValues.contains(otherValue),
                      ),
                    ),
                ],
              ),
              if (question.allowOther && multiValues.contains(otherValue))
                _QuestionnaireTextField(
                  controller: otherController,
                  readOnly: readOnly,
                ),
            ],
          ),
          LingQuestionnaireQuestionType.freeText => _QuestionnaireTextField(
            controller: textController,
            readOnly: readOnly,
            minLines: 2,
          ),
        },
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.readOnly,
    required this.multi,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool readOnly;
  final bool multi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = readOnly
        ? palette.textTertiary
        : selected
        ? palette.accent
        : palette.textPrimary;
    final background = selected
        ? palette.accent.withValues(alpha: readOnly ? 0.10 : 0.14)
        : palette.surfaceMuted.withValues(alpha: 0.38);
    final borderColor = selected
        ? palette.accent.withValues(alpha: readOnly ? 0.34 : 0.58)
        : palette.textTertiary.withValues(alpha: 0.24);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: readOnly ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              multi
                  ? selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded
                  : selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 17,
              color: foreground,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionnaireTextField extends StatelessWidget {
  const _QuestionnaireTextField({
    required this.controller,
    required this.readOnly,
    this.minLines = 1,
  });

  final TextEditingController? controller;
  final bool readOnly;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        minLines: minLines,
        maxLines: 4,
        style: TextStyle(color: palette.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: palette.inputBackground.withValues(alpha: 0.58),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: palette.textTertiary.withValues(alpha: 0.26),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: palette.textTertiary.withValues(alpha: 0.24),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: palette.accent, width: 1.2),
          ),
        ),
      ),
    );
  }
}

class _QuestionnaireResponseView extends StatelessWidget {
  const _QuestionnaireResponseView({required this.response});

  final LingQuestionnaireResponse response;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final answer in response.answers) ...[
          Text(
            answer.questionText,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer.displayValue,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LingMarkdownActionButton extends StatelessWidget {
  const _LingMarkdownActionButton({
    required this.action,
    required this.onPressed,
  });

  final LingChatAction action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = lingGlassPromptActionTintFor(context, palette);
    final foreground = palette.textPrimary;
    return Semantics(
      button: true,
      label: action.label,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: context.isDarkMode
                ? palette.accent.withValues(alpha: 0.26)
                : palette.accent.withValues(alpha: 0.30),
            width: 1,
          ),
          boxShadow: context.isDarkMode
              ? [
                  BoxShadow(
                    color: palette.accentGlow.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: palette.shadow.withValues(alpha: 0.055),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: LingGlassButton(
          key: ValueKey<String>('ling_action_${action.keySuffix}'),
          onPressed: onPressed,
          minHeight: 36,
          width: _actionButtonWidth(action.label),
          expand: false,
          radius: 18,
          tone: LingGlassSurfaceTone.regular,
          foregroundColor: foreground,
          tintColor: tint,
          glowColor: palette.accentGlow,
          settings: lingGlassPromptActionSettingsFor(context, tintColor: tint),
          quality: LingGlassQuality.premium,
          child: Padding(
            padding: const EdgeInsets.only(left: 7, right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: context.isDarkMode
                      ? palette.primaryButtonForeground
                      : palette.primaryButtonBackground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _actionButtonWidth(String label) {
    final estimated = 52 + label.characters.length * 12.5;
    return estimated.clamp(96, 220).toDouble();
  }
}

class _LingMarkdownCodeBlockBuilder extends MarkdownElementBuilder {
  _LingMarkdownCodeBlockBuilder({
    required this.codeStyle,
    required this.codeBlockPadding,
    required this.selectable,
  });

  final TextStyle? codeStyle;
  final EdgeInsets? codeBlockPadding;
  final bool selectable;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final palette = context.palette;
    final code = element.textContent.replaceAll(RegExp(r'\n$'), '');
    final textWidget = selectable
        ? SelectableText(code, style: codeStyle, maxLines: null)
        : Text(code, style: codeStyle, softWrap: true);
    return Padding(
      padding: codeBlockPadding ?? EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            Padding(padding: const EdgeInsets.only(top: 28), child: textWidget),
            Positioned(
              top: 0,
              right: 0,
              child: SelectionContainer.disabled(
                child: Tooltip(
                  message: '复制代码',
                  child: IconButton(
                    key: const Key('assistant_markdown_code_copy_button'),
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    color: palette.textSecondary,
                    onPressed: () => _copyCodeBlock(context, code),
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyCodeBlock(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      showLingTopNotice(context, '已复制代码');
    }
  }
}
