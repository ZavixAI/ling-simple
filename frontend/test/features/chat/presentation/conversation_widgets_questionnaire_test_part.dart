part of 'conversation_widgets_test.dart';

void registerConversationWidgetQuestionnaireTests(LingStrings strings) {
  testWidgets('assistant markdown renders questionnaire and submits JSON', (
    tester,
  ) async {
    final submissions = <LingQuestionnaireSubmission>[];
    await _pumpConversationSurface(
      tester,
      SingleChildScrollView(
        child: LingAssistantMarkdown(
          markdown:
              '想确认一下。\n'
              '<ling-questionnaire>{"title":"今日状态","questions":[{"type":"single_choice","text":"今天能量怎么样？","options":["低","高"],"default":"低"},{"type":"multi_choice","text":"想让 Ling 帮你看什么？","options":["安排","想法"],"allow_other":true},{"type":"free_text","text":"还有什么想补充？","default":"先轻一点"}]}</ling-questionnaire>',
          questionnaireKeyPrefix: 'assistant_q',
          canSubmitQuestionnaire: true,
          onQuestionnaireSubmit: submissions.add,
        ),
      ),
    );

    expect(find.text('想确认一下。'), findsOneWidget);
    expect(find.text('今日状态'), findsOneWidget);
    expect(find.text('今天能量怎么样？'), findsOneWidget);
    expect(find.text('想让 Ling 帮你看什么？'), findsNothing);
    expect(find.textContaining('<ling-questionnaire'), findsNothing);

    await tester.tap(find.text('高'));
    await tester.tap(find.text('继续'));
    await tester.pump();
    expect(find.text('想让 Ling 帮你看什么？'), findsOneWidget);
    await tester.tap(find.text('安排'));
    await tester.tap(find.text('其他'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '材料');
    await tester.tap(find.text('继续'));
    await tester.pump();
    expect(find.text('还有什么想补充？'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '下午再说');
    await tester.tap(find.text('提交'));
    await tester.pump();

    expect(submissions, hasLength(1));
    final payload = submissions.single.agentText;
    expect(payload, contains('<ling-questionnaire-response>'));
    expect(payload, contains('"answer"'));
    expect(payload, isNot(contains('"label"')));
    expect(payload, isNot(contains('"value"')));
    final response = LingQuestionnaireResponse.fromAgentText(payload);
    expect(response?.questionnaireId, 'assistant_q_q1');
    expect(response?.status, LingQuestionnaireResponseStatus.submitted);
    expect(response?.answers, hasLength(3));
    expect(response?.answers[0].value, '高');
    expect(response?.answers[1].values, containsAll(<String>['安排']));
    expect(response?.answers[1].otherText, '材料');
    expect(response?.answers[2].text, '下午再说');
    expect(submissions.single.displayText, contains('问卷回答'));
    expect(submissions.single.displayText, contains('高'));
  });

  testWidgets('questionnaire timeout submits default answers', (tester) async {
    final submissions = <LingQuestionnaireSubmission>[];
    await _pumpConversationSurface(
      tester,
      LingAssistantMarkdown(
        markdown:
            '<ling-questionnaire timeout_seconds="1">{"questions":[{"type":"single_choice","text":"今天能量怎么样？","options":["低","高"],"default":"低"},{"type":"free_text","text":"还有什么想补充？","default":"先轻一点"}]}</ling-questionnaire>',
        canSubmitQuestionnaire: true,
        onQuestionnaireSubmit: submissions.add,
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(submissions, hasLength(1));
    expect(
      submissions.single.status,
      LingQuestionnaireResponseStatus.timeoutDefault,
    );
    expect(submissions.single.answers[0].value, '低');
    expect(submissions.single.answers[1].text, '先轻一点');
  });

  testWidgets('questionnaire without timeout waits for user submit', (
    tester,
  ) async {
    final submissions = <LingQuestionnaireSubmission>[];
    await _pumpConversationSurface(
      tester,
      LingAssistantMarkdown(
        markdown:
            '<ling-questionnaire>{"questions":[{"type":"single_choice","text":"今天能量怎么样？","options":["低","高"],"default":"低"}]}</ling-questionnaire>',
        canSubmitQuestionnaire: true,
        onQuestionnaireSubmit: submissions.add,
      ),
    );

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();

    expect(submissions, isEmpty);
    expect(find.text('提交'), findsOneWidget);
  });

  testWidgets(
    'questionnaire remains submittable after later assistant entry',
    (tester) async {
      final submissions = <LingQuestionnaireSubmission>[];
      await _pumpChatSectionView(
        tester,
        items: [
          LingConversationRenderItem.entry(
            id: 'assistant-questionnaire',
            entry: LingConversationEntry.assistant(
              id: 'assistant-questionnaire',
              sessionId: 'current-session',
              text:
                  '<ling-questionnaire>{"questions":[{"type":"single_choice","text":"今天能量怎么样？","options":["低","高"],"default":"低"}]}</ling-questionnaire>',
            ),
          ),
          LingConversationRenderItem.entry(
            id: 'assistant-reminder',
            entry: LingConversationEntry.assistant(
              id: 'assistant-reminder',
              sessionId: 'current-session',
              text: '顺手提醒一下，下午记得喝水。',
            ),
          ),
        ],
        onQuestionnaireSubmit: submissions.add,
      );

      expect(find.text('顺手提醒一下，下午记得喝水。'), findsOneWidget);
      expect(find.text('今天能量怎么样？'), findsOneWidget);

      await tester.tap(find.text('高'));
      await tester.tap(find.text('提交'));
      await tester.pump();

      expect(submissions, hasLength(1));
      expect(submissions.single.questionnaire.id, 'assistant-questionnaire_q1');
      expect(submissions.single.answers.single.value, '高');
    },
  );

  testWidgets(
    'questionnaire is not submittable after later normal assistant entry',
    (tester) async {
      final submissions = <LingQuestionnaireSubmission>[];
      await _pumpChatSectionView(
        tester,
        items: [
          LingConversationRenderItem.entry(
            id: 'assistant-questionnaire',
            entry: LingConversationEntry.assistant(
              id: 'assistant-questionnaire',
              sessionId: 'current-session',
              text:
                  '<ling-questionnaire>{"questions":[{"type":"single_choice","text":"今天能量怎么样？","options":["低","高"],"default":"低"}]}</ling-questionnaire>',
            ),
          ),
          LingConversationRenderItem.entry(
            id: 'assistant-followup',
            entry: LingConversationEntry.assistant(
              id: 'assistant-followup',
              sessionId: 'current-session',
              text: '我又接着说了一句。',
            ),
          ),
        ],
        onQuestionnaireSubmit: submissions.add,
      );

      expect(find.text('我又接着说了一句。'), findsOneWidget);
      expect(find.text('已过期'), findsOneWidget);
      expect(find.text('提交'), findsNothing);

      expect(submissions, isEmpty);
    },
  );

  testWidgets('assistant markdown parses multiline questionnaire payload', (
    tester,
  ) async {
    await _pumpConversationSurface(
      tester,
      const LingAssistantMarkdown(
        markdown: '''
<ling-questionnaire>
{
  "questions": [
    {
      "type": "single_choice",
      "text": "今天能量怎么样？",
      "options": ["低", "高"]
    }
  ]
}
</ling-questionnaire>
''',
      ),
    );

    expect(find.text('今天能量怎么样？'), findsOneWidget);
    expect(find.textContaining('<ling-questionnaire'), findsNothing);
  });

  testWidgets('assistant markdown renders questionnaire at tag position', (
    tester,
  ) async {
    await _pumpConversationSurface(
      tester,
      const SingleChildScrollView(
        child: LingAssistantMarkdown(
          markdown:
              '好的，来测试一下问卷功能！这是一个关于「今日状态」的小问卷：\n\n'
              '<ling-questionnaire>{"title":"今日状态小调查","questions":[{"type":"single_choice","text":"今天能量怎么样？","options":["低","中","高"],"default":"中"},{"type":"multi_choice","text":"想让 Ling 帮你看什么？","options":["日程","想法","关注"],"allow_other":true},{"type":"free_text","text":"还有什么想补充的？","default":""}]}</ling-questionnaire>\n\n'
              '你可以直接填写并提交，看看前端如何渲染和收集结构化回答～',
        ),
      ),
    );

    expect(find.text('今日状态小调查'), findsOneWidget);
    expect(find.textContaining('<ling-questionnaire'), findsNothing);

    final cardTop = tester.getTopLeft(find.text('今日状态小调查')).dy;
    final trailingTextTop = tester
        .getTopLeft(find.textContaining('你可以直接填写并提交'))
        .dy;
    expect(cardTop, lessThan(trailingTextTop));
  });

  testWidgets('assistant entry renders questionnaire through message view', (
    tester,
  ) async {
    await _pumpConversationSurface(
      tester,
      SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: LingConversationEntryView(
            entry: LingConversationEntry.assistant(
              id: 'assistant-questionnaire-entry',
              text:
                  '好的，来测试一下问卷功能！这是一个关于「今日状态」的小问卷：\n\n'
                  '<ling-questionnaire>{"title":"今日状态小调查","questions":[{"type":"single_choice","text":"今天能量怎么样？","options":["低","中","高"],"default":"中"},{"type":"multi_choice","text":"想让 Ling 帮你看什么？","options":["日程","想法","关注"],"allow_other":true},{"type":"free_text","text":"还有什么想补充的？","default":""}]}</ling-questionnaire>\n\n'
                  '你可以直接填写并提交，看看前端如何渲染和收集结构化回答～',
            ),
            strings: strings,
            onPreviewAttachment: (_) {},
            canSubmitQuestionnaire: true,
            onQuestionnaireSubmit: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(
        const ValueKey<String>(
          'ling_questionnaire_assistant-questionnaire-entry_q1',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('今日状态小调查'), findsOneWidget);
    expect(find.textContaining('<ling-questionnaire'), findsNothing);
  });

  testWidgets('assistant do_subtask_result renders questionnaire', (
    tester,
  ) async {
    await _pumpConversationSurface(
      tester,
      SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: LingConversationEntryView(
            entry: LingConversationEntry.assistant(
              id: 'assistant-do-subtask-questionnaire',
              sessionId: 'history-session',
              messageType: 'do_subtask_result',
              text:
                  '好的，来测试一下问卷功能！这是一个关于「今日状态」的小问卷： '
                  '<ling-questionnaire>{"title":"今日状态小调查","questions":[{"type":"single_choice","text":"今天能量怎么样？","options":["低","中","高"],"default":"中"},{"type":"multi_choice","text":"想让 Ling 帮你看什么？","options":["日程","想法","关注"],"allow_other":true},{"type":"free_text","text":"还有什么想补充的？","default":""}]}</ling-questionnaire> '
                  '你可以直接填写并提交，看看前端如何渲染和收集结构化回答～',
            ),
            strings: strings,
            onPreviewAttachment: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('今日状态小调查'), findsOneWidget);
    expect(find.text('今天能量怎么样？'), findsOneWidget);
    expect(find.textContaining('<ling-questionnaire'), findsNothing);
  });

  testWidgets('assistant markdown parses html entity questionnaire payload', (
    tester,
  ) async {
    await _pumpConversationSurface(
      tester,
      const SingleChildScrollView(
        child: LingAssistantMarkdown(
          markdown:
              '&lt;ling-questionnaire&gt;{&quot;title&quot;:&quot;今日状态小调查&quot;,&quot;questions&quot;:[{&quot;type&quot;:&quot;single_choice&quot;,&quot;text&quot;:&quot;今天能量怎么样？&quot;,&quot;options&quot;:[&quot;低&quot;,&quot;中&quot;,&quot;高&quot;],&quot;default&quot;:&quot;中&quot;}]}&lt;/ling-questionnaire&gt;',
        ),
      ),
    );

    expect(find.text('今日状态小调查'), findsOneWidget);
    expect(find.text('今天能量怎么样？'), findsOneWidget);
    expect(find.textContaining('ling-questionnaire'), findsNothing);
  });

  testWidgets('assistant markdown parses escaped questionnaire payload', (
    tester,
  ) async {
    await _pumpConversationSurface(
      tester,
      const SingleChildScrollView(
        child: LingAssistantMarkdown(
          markdown:
              r'<ling-questionnaire>{\"title\":\"今日状态小调查\",\"questions\":[{\"type\":\"single_choice\",\"text\":\"今天能量怎么样？\",\"options\":[\"低\",\"中\",\"高\"],\"default\":\"中\"},{\"type\":\"multi_choice\",\"text\":\"想让 Ling 帮你看什么？\",\"options\":[\"日程\",\"想法\",\"关注\"],\"allow_other\":true},{\"type\":\"free_text\",\"text\":\"还有什么想补充的？\",\"default\":\"\"}]}</ling-questionnaire>',
        ),
      ),
    );

    expect(find.text('今日状态小调查'), findsOneWidget);
    expect(find.text('今天能量怎么样？'), findsOneWidget);
    expect(find.text('想让 Ling 帮你看什么？'), findsNothing);
    await tester.tap(find.text('继续'));
    await tester.pump();
    expect(find.text('想让 Ling 帮你看什么？'), findsOneWidget);
    expect(find.textContaining('<ling-questionnaire'), findsNothing);
  });

  testWidgets('assistant markdown parses escaped questionnaire closing tag', (
    tester,
  ) async {
    await _pumpConversationSurface(
      tester,
      const SingleChildScrollView(
        child: LingAssistantMarkdown(
          markdown:
              r'<ling-questionnaire>{"title":"今日状态小调查","questions":[{"type":"single_choice","text":"今天能量怎么样？","options":["低","中","高"],"default":"中"}]}<\/ling-questionnaire>',
        ),
      ),
    );

    expect(find.text('今日状态小调查'), findsOneWidget);
    expect(find.text('今天能量怎么样？'), findsOneWidget);
    expect(find.textContaining('<ling-questionnaire'), findsNothing);
  });

  testWidgets('assistant markdown parses transport encoded questionnaire text', (
    tester,
  ) async {
    await _pumpConversationSurface(
      tester,
      const SingleChildScrollView(
        child: LingAssistantMarkdown(
          markdown:
              '"好的，来测试一下问卷功能！这是一个关于「今日状态」的小问卷：\\n\\n<ling-questionnaire>{\\"title\\":\\"今日状态小调查\\",\\"questions\\":[{\\"type\\":\\"single_choice\\",\\"text\\":\\"今天能量怎么样？\\",\\"options\\":[\\"低\\",\\"中\\",\\"高\\"],\\"default\\":\\"中\\"},{\\"type\\":\\"multi_choice\\",\\"text\\":\\"想让 Ling 帮你看什么？\\",\\"options\\":[\\"日程\\",\\"想法\\",\\"关注\\"],\\"allow_other\\":true},{\\"type\\":\\"free_text\\",\\"text\\":\\"还有什么想补充的？\\",\\"default\\":\\"\\"}]}</ling-questionnaire>\\n\\n你可以直接填写并提交，看看前端如何渲染和收集结构化回答～"',
        ),
      ),
    );

    expect(find.text('今日状态小调查'), findsOneWidget);
    expect(find.text('今天能量怎么样？'), findsOneWidget);
    expect(find.text('想让 Ling 帮你看什么？'), findsNothing);
    await tester.tap(find.text('继续'));
    await tester.pump();
    expect(find.text('想让 Ling 帮你看什么？'), findsOneWidget);
    expect(find.textContaining(r'\"title\"'), findsNothing);
    expect(find.textContaining('<ling-questionnaire'), findsNothing);
  });

  testWidgets('questionnaire response renders read only selection', (
    tester,
  ) async {
    final response = LingQuestionnaireResponse.fromAgentText(
      '<ling-questionnaire-response>{"type":"ling_questionnaire_response","questionnaire_id":"assistant_done_q1","status":"submitted","answers":[{"question":"今天能量怎么样？","type":"single_choice","answer":"高"}]}</ling-questionnaire-response>',
    );

    await _pumpConversationSurface(
      tester,
      LingAssistantMarkdown(
        markdown:
            '<ling-questionnaire>{"questions":[{"type":"single_choice","text":"今天能量怎么样？","options":["低","高"]}]}</ling-questionnaire>',
        questionnaireKeyPrefix: 'assistant_done',
        canSubmitQuestionnaire: true,
        questionnaireResponses: <String, LingQuestionnaireResponse>{
          'assistant_done_q1': response!,
        },
        onQuestionnaireSubmit: (_) {},
      ),
    );

    expect(find.text('已提交'), findsOneWidget);
    expect(find.text('今天能量怎么样？'), findsOneWidget);
    expect(find.text('高'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('ling_questionnaire_submit_assistant_done_q1'),
      ),
      findsNothing,
    );
  });

  testWidgets('questionnaire timeout response shows automatic submit status', (
    tester,
  ) async {
    final response = LingQuestionnaireResponse.fromAgentText(
      '<ling-questionnaire-response>{"type":"ling_questionnaire_response","questionnaire_id":"assistant_timeout_q1","status":"timeout_default","answers":[{"question":"今天能量怎么样？","type":"single_choice","answer":"低"}]}</ling-questionnaire-response>',
    );

    await _pumpConversationSurface(
      tester,
      LingAssistantMarkdown(
        markdown:
            '<ling-questionnaire>{"questions":[{"type":"single_choice","text":"今天能量怎么样？","options":["低","高"],"default":"低"}]}</ling-questionnaire>',
        questionnaireKeyPrefix: 'assistant_timeout',
        canSubmitQuestionnaire: true,
        questionnaireResponses: <String, LingQuestionnaireResponse>{
          'assistant_timeout_q1': response!,
        },
        onQuestionnaireSubmit: (_) {},
      ),
    );

    expect(find.text('已自动提交'), findsOneWidget);
    expect(find.text('已提交'), findsNothing);
    expect(find.text('低'), findsOneWidget);
  });
}
