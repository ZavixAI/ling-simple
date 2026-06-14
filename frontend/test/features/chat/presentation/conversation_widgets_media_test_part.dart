part of 'conversation_widgets_test.dart';

void registerConversationWidgetMediaTests(LingStrings strings) {
  testWidgets('assistant markdown ignores ling action tags inside code', (
    tester,
  ) async {
    final prompts = <String>[];
    await _pumpConversationSurface(
      tester,
      LingAssistantMarkdown(
        markdown:
            '```md\n<ling-action label="补充地点" prompt="请补充地点。" />\n```\n'
            '正文 ` <ling-action label="内联代码" prompt="不要解析" /> `',
        onActionPrompt: prompts.add,
      ),
    );

    expect(find.text('补充地点'), findsNothing);
    expect(find.text('内联代码'), findsNothing);
    expect(prompts, isEmpty);
  });

  testWidgets('assistant markdown decodes escaped action attributes', (
    tester,
  ) async {
    final prompts = <String>[];
    await _pumpConversationSurface(
      tester,
      LingAssistantMarkdown(
        markdown:
            '<ling-action label="补充&quot;地点&quot;" prompt="请补充 &quot;地点&quot; &amp; 参会人。" />',
        onActionPrompt: prompts.add,
      ),
    );

    await tester.tap(find.text('补充"地点"'));
    expect(prompts, <String>['请补充 "地点" & 参会人。']);
  });

  testWidgets('assistant markdown web link is tappable externally', (
    tester,
  ) async {
    await _pumpConversationSurface(
      tester,
      const LingAssistantMarkdown(markdown: '[官网](https://example.com)'),
    );

    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.onTapLink, isNotNull);
    expect(
      markdown.styleSheet?.a?.color,
      AppTheme.light().extension<LingPalette>()!.accent,
    );
    expect(markdown.styleSheet?.a?.decoration, TextDecoration.underline);
  });

  testWidgets('assistant markdown web link asks before opening', (
    tester,
  ) async {
    await _pumpConversationSurface(
      tester,
      const LingAssistantMarkdown(markdown: '[官网](https://example.com)'),
    );

    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    markdown.onTapLink?.call('官网', 'https://example.com', '');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('ling_adaptive_confirmation_dialog')),
      findsOneWidget,
    );
    expect(find.text('打开链接'), findsOneWidget);
    expect(find.text('https://example.com'), findsOneWidget);
    expect(find.text('Ling 将在系统浏览器中打开此链接，请确认来源可信。'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('ling_adaptive_confirmation_cancel_label')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ling_adaptive_confirmation_dialog')),
      findsNothing,
    );
  });

  testWidgets('assistant markdown link tap opens safety confirmation', (
    tester,
  ) async {
    await _pumpConversationSurface(
      tester,
      const LingAssistantMarkdown(markdown: '[官网](https://example.com)'),
    );

    await tester.tap(find.text('官网'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('ling_adaptive_confirmation_dialog')),
      findsOneWidget,
    );
    expect(find.text('打开链接'), findsOneWidget);
    expect(find.text('https://example.com'), findsOneWidget);
    expect(find.text('Ling 将在系统浏览器中打开此链接，请确认来源可信。'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('ling_adaptive_confirmation_cancel_label')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ling_adaptive_confirmation_dialog')),
      findsNothing,
    );
  });

  testWidgets('assistant markdown renders agent file image URI', (
    tester,
  ) async {
    const path =
        '/app/agents/u_f00924f8e59841268a376ca804f799a2/agent_56adf26d/upload_files/daughter_4m11d_20260522.jpg';
    final repository = _RecordingAgentFileRepository(
      LingAgentFileData(
        path: path,
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        ),
        filename: 'daughter_4m11d_20260522.jpg',
        contentType: 'image/jpeg',
      ),
    );

    await _pumpConversationSurface(
      tester,
      const LingAssistantMarkdown(
        markdown:
            '![女儿 4 个月 11 天](file:///app/agents/u_f00924f8e59841268a376ca804f799a2/agent_56adf26d/upload_files/daughter_4m11d_20260522.jpg)',
      ),
      overrides: [agentFileRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pump();

    expect(repository.requestedPaths, <String>[path]);
    expect(
      find.byKey(const ValueKey<String>('ling_markdown_agent_image_$path')),
      findsOneWidget,
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('assistant markdown image does not render duplicate file card', (
    tester,
  ) async {
    const path =
        '/app/agents/u_f00924f8e59841268a376ca804f799a2/agent_56adf26d/upload_files/daughter_4m11d_20260522.jpg';
    final repository = _RecordingAgentFileRepository(
      LingAgentFileData(
        path: path,
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        ),
        filename: 'daughter_4m11d_20260522.jpg',
        contentType: 'image/jpeg',
      ),
    );

    await _pumpConversationSurface(
      tester,
      LingConversationEntryView(
        entry: LingConversationEntry.assistant(
          id: 'assistant-image-file-card-1',
          text:
              '照片已保存：![女儿 4 个月 11 天](file:///app/agents/u_f00924f8e59841268a376ca804f799a2/agent_56adf26d/upload_files/daughter_4m11d_20260522.jpg)',
        ),
        strings: strings,
        onPreviewAttachment: (_) {},
      ),
      overrides: [agentFileRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pump();

    expect(repository.requestedPaths, <String>[path]);
    expect(
      find.byKey(const ValueKey<String>('ling_markdown_agent_image_$path')),
      findsOneWidget,
    );
    expect(find.byType(LingAgentFileReferenceList), findsNothing);
    expect(find.byKey(Key('agent_file_card_$path')), findsNothing);
  });

  testWidgets('assistant markdown audio link renders voice control', (
    tester,
  ) async {
    const path =
        '/app/agents/u_f00924f8e59841268a376ca804f799a2/agent_56adf26d/voice/reassurance.wav';
    final repository = _RecordingAgentFileRepository(
      LingAgentFileData(
        path: path,
        bytes: Uint8List.fromList(<int>[82, 73, 70, 70, 0, 0, 0, 0]),
        filename: 'reassurance.wav',
        contentType: 'audio/wav',
      ),
    );

    await _pumpConversationSurface(
      tester,
      LingConversationEntryView(
        entry: LingConversationEntry.assistant(
          id: 'assistant-audio-link-1',
          text: '我留了一句语音：[听 Ling 说一句](file://$path)',
        ),
        strings: strings,
        onPreviewAttachment: (_) {},
        onStopAudioPreview: () {},
      ),
      overrides: [agentFileRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.byKey(Key('agent_file_card_$path')), findsNothing);
    expect(find.byType(LingVoicePreviewControl), findsOneWidget);

    final preview = tester.widget<LingVoicePreviewControl>(
      find.byType(LingVoicePreviewControl),
    );
    expect(preview.source, path);
  });

  testWidgets('assistant markdown image link renders inline image', (
    tester,
  ) async {
    const path =
        '/app/agents/u_f00924f8e59841268a376ca804f799a2/agent_56adf26d/upload_files/minimaxiposharev2.png';
    final repository = _RecordingAgentFileRepository(
      LingAgentFileData(
        path: path,
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        ),
        filename: 'minimaxiposharev2.png',
        contentType: 'image/png',
      ),
    );

    await _pumpConversationSurface(
      tester,
      LingConversationEntryView(
        entry: LingConversationEntry.assistant(
          id: 'assistant-image-link-1',
          text: '素材链接：\n\n- 图片：[minimaxiposharev2.png](file://$path)',
        ),
        strings: strings,
        onPreviewAttachment: (_) {},
      ),
      overrides: [agentFileRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pump();

    expect(repository.requestedPaths, <String>[path]);
    expect(
      find.byKey(const ValueKey<String>('ling_markdown_agent_image_$path')),
      findsOneWidget,
    );
    expect(find.byKey(Key('agent_file_card_$path')), findsNothing);
    expect(find.text('minimaxiposharev2.png'), findsNothing);
  });

  testWidgets('assistant markdown image syntax for markdown renders file card', (
    tester,
  ) async {
    const path =
        '/app/agents/u_12cda7fa1f0947c5908befccc65d8a26/agent_56adf26d/temp/llm_tech_landscape_2026.md';
    final repository = _RecordingAgentFileRepository(
      LingAgentFileData(
        path: path,
        bytes: Uint8List.fromList(
          utf8.encode('# LLM 技术格局 2026\n\n- 模型能力继续演进。'),
        ),
        filename: 'llm_tech_landscape_2026.md',
        contentType: 'text/markdown; charset=utf-8',
      ),
    );

    await _pumpConversationSurface(
      tester,
      LingConversationEntryView(
        entry: LingConversationEntry.assistant(
          id: 'assistant-markdown-image-syntax-file-card-1',
          text: '报告已生成：![LLM 技术格局](file://$path)',
        ),
        strings: strings,
        onPreviewAttachment: (_) {},
      ),
      overrides: [agentFileRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pump();

    expect(repository.requestedPaths, <String>[path]);
    expect(
      find.byKey(ValueKey<String>('ling_markdown_agent_image_$path')),
      findsNothing,
    );
    expect(find.byKey(Key('agent_file_card_$path')), findsOneWidget);
    expect(find.text('Markdown 文档'), findsOneWidget);
  });

  testWidgets('assistant markdown image opens preview with download action', (
    tester,
  ) async {
    const path =
        '/app/agents/u_f00924f8e59841268a376ca804f799a2/agent_56adf26d/upload_files/daughter_4m11d_20260522.jpg';
    final saveBridge = _FakeAgentFileSaveBridge();
    final repository = _RecordingAgentFileRepository(
      LingAgentFileData(
        path: path,
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        ),
        filename: 'daughter_4m11d_20260522.jpg',
        contentType: 'image/jpeg',
      ),
    );

    await _pumpConversationSurface(
      tester,
      LingConversationEntryView(
        entry: LingConversationEntry.assistant(
          id: 'assistant-image-preview-1',
          text:
              '照片已保存：![女儿 4 个月 11 天](file:///app/agents/u_f00924f8e59841268a376ca804f799a2/agent_56adf26d/upload_files/daughter_4m11d_20260522.jpg)',
        ),
        strings: strings,
        onPreviewAttachment: (_) {},
      ),
      overrides: [
        agentFileRepositoryProvider.overrideWithValue(repository),
        agentFileSaveBridgeProvider.overrideWithValue(saveBridge),
      ],
    );
    await tester.pump();

    tester
        .widget<GestureDetector>(
          find.byKey(ValueKey<String>('ling_markdown_agent_image_tap_$path')),
        )
        .onTap
        ?.call();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('markdown_image_preview_download_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('markdown_image_preview_close_button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('markdown_image_preview_download_button')),
    );
    await tester.pumpAndSettle();

    expect(saveBridge.savedFiles, hasLength(1));
    expect(
      saveBridge.savedFiles.single.filename,
      'daughter_4m11d_20260522.jpg',
    );
  });

  testWidgets('assistant markdown image preview closes on background tap', (
    tester,
  ) async {
    const path =
        '/app/agents/u_f00924f8e59841268a376ca804f799a2/agent_56adf26d/upload_files/daughter_4m11d_20260522.jpg';
    final repository = _RecordingAgentFileRepository(
      LingAgentFileData(
        path: path,
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        ),
        filename: 'daughter_4m11d_20260522.jpg',
        contentType: 'image/jpeg',
      ),
    );

    await _pumpConversationSurface(
      tester,
      LingConversationEntryView(
        entry: LingConversationEntry.assistant(
          id: 'assistant-image-preview-dismiss-1',
          text: '照片：![女儿](file://$path)',
        ),
        strings: strings,
        onPreviewAttachment: (_) {},
      ),
      overrides: [agentFileRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pump();

    tester
        .widget<GestureDetector>(
          find.byKey(ValueKey<String>('ling_markdown_agent_image_tap_$path')),
        )
        .onTap
        ?.call();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('markdown_image_preview_close_button')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(24, 560));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('markdown_image_preview_close_button')),
      findsNothing,
    );
  });

  testWidgets('assistant markdown keeps normal network images', (tester) async {
    await _pumpConversationSurface(
      tester,
      const LingAssistantMarkdown(markdown: '普通文本'),
    );

    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    final image = markdown.imageBuilder?.call(
      Uri.parse('https://example.com/photo.jpg'),
      null,
      '远程图',
    );

    expect(image, isA<Image>());
    expect((image as Image).image, isA<NetworkImage>());
  });

  testWidgets('selectable markdown preview still renders agent images', (
    tester,
  ) async {
    const path =
        '/app/agents/u_f00924f8e59841268a376ca804f799a2/agent_56adf26d/upload_files/daughter_4m11d_20260522.jpg';
    final repository = _RecordingAgentFileRepository(
      LingAgentFileData(
        path: path,
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        ),
        filename: 'daughter_4m11d_20260522.jpg',
        contentType: 'image/jpeg',
      ),
    );

    await _pumpConversationSurface(
      tester,
      const LingAssistantMarkdown(
        markdown:
            '# 今日照片\n![女儿 4 个月 11 天](file:///app/agents/u_f00924f8e59841268a376ca804f799a2/agent_56adf26d/upload_files/daughter_4m11d_20260522.jpg)',
        selectable: true,
      ),
      overrides: [agentFileRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pump();

    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.selectable, isFalse);
    expect(repository.requestedPaths, <String>[path]);
    expect(
      find.byKey(const ValueKey<String>('ling_markdown_agent_image_$path')),
      findsOneWidget,
    );
  });

  testWidgets('assistant markdown file link renders file card', (tester) async {
    await _pumpConversationSurface(
      tester,
      LingConversationEntryView(
        entry: LingConversationEntry.assistant(
          id: 'assistant-file-1',
          text: '报告已生成：[明天的日程报告](reports/daily-report.html)',
        ),
        strings: strings,
        onPreviewAttachment: (_) {},
      ),
      overrides: [
        agentFileRepositoryProvider.overrideWithValue(
          _FakeAgentFileRepository(
            LingAgentFileData(
              path: 'reports/daily-report.html',
              bytes: Uint8List.fromList(
                utf8.encode(
                  '<html><head><title>明天的日程报告</title></head>'
                  '<body><h1>明天的日程报告</h1></body></html>',
                ),
              ),
              filename: 'daily-report.html',
              contentType: 'text/html',
            ),
          ),
        ),
      ],
    );

    expect(find.byType(LingAssistantMarkdown), findsOneWidget);
    expect(
      find.byKey(const Key('agent_file_card_reports/daily-report.html')),
      findsOneWidget,
    );
    expect(find.text('明天的日程报告'), findsWidgets);
    expect(find.text('HTML 报告'), findsOneWidget);
  });

  testWidgets('html report card uses native thumbnail in conversation list', (
    tester,
  ) async {
    await _pumpConversationSurface(
      tester,
      LingConversationEntryView(
        entry: LingConversationEntry.assistant(
          id: 'assistant-file-preview-1',
          text: '报告已生成：[今日整理报告](reports/daily-report.html)',
        ),
        strings: strings,
        onPreviewAttachment: (_) {},
      ),
      overrides: [
        agentFileRepositoryProvider.overrideWithValue(
          _FakeAgentFileRepository(
            LingAgentFileData(
              path: 'reports/daily-report.html',
              bytes: Uint8List.fromList(
                utf8.encode(
                  '<html><head><title>今日整理报告</title></head>'
                  '<body><h1>今日整理报告</h1><p>今日 0 个日程，4 个待推进想法</p></body></html>',
                ),
              ),
              filename: 'daily-report.html',
              contentType: 'text/html',
            ),
          ),
        ),
      ],
    );
    await tester.pump();

    expect(find.byKey(const Key('agent_file_html_thumbnail')), findsOneWidget);
    expect(find.text('今日整理报告'), findsWidgets);
    expect(find.text('今日 0 个日程，4 个待推进想法'), findsOneWidget);
  });

  testWidgets('html report card handles long title and dense preview', (
    tester,
  ) async {
    await _pumpConversationSurface(
      tester,
      LingConversationEntryView(
        entry: LingConversationEntry.assistant(
          id: 'assistant-file-preview-long-report',
          text: '报告已生成：[OpenClaw报告](reports/openclaw-report.html)',
        ),
        strings: strings,
        onPreviewAttachment: (_) {},
      ),
      themeMode: ThemeMode.dark,
      overrides: [
        agentFileRepositoryProvider.overrideWithValue(
          _FakeAgentFileRepository(
            LingAgentFileData(
              path: 'reports/openclaw-report.html',
              bytes: Uint8List.fromList(
                utf8.encode(
                  '<html><head><title>OpenClaw AI Agent 深度调研报告</title></head>'
                  '<body>'
                  '<h1>OpenClaw AI Agent 深度调研报告</h1>'
                  '<p>AI Agent 深度调研报告：OpenClaw</p>'
                  '<p>开源AI Agent框架 · 本地优先架构 · 2026年现象级产品</p>'
                  '<p>调研日期：2026年6月13日</p>'
                  '<p>开源框架</p>'
                  '</body></html>',
                ),
              ),
              filename: 'openclaw-report.html',
              contentType: 'text/html',
            ),
          ),
        ),
      ],
    );
    await tester.pump();

    expect(find.byKey(const Key('agent_file_html_thumbnail')), findsOneWidget);
    expect(find.text('OpenClaw AI Agent 深度调研报告'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('html report card keeps a visible dark edge', (tester) async {
    await _pumpConversationSurface(
      tester,
      LingConversationEntryView(
        entry: LingConversationEntry.assistant(
          id: 'assistant-file-preview-dark-edge',
          text: '报告已生成：[今日整理报告](reports/daily-report.html)',
        ),
        strings: strings,
        onPreviewAttachment: (_) {},
      ),
      themeMode: ThemeMode.dark,
      overrides: [
        agentFileRepositoryProvider.overrideWithValue(
          _FakeAgentFileRepository(
            LingAgentFileData(
              path: 'reports/daily-report.html',
              bytes: Uint8List.fromList(
                utf8.encode(
                  '<html><head><title>今日整理报告</title></head>'
                  '<body><h1>今日整理报告</h1><p>今日 0 个日程，4 个待推进想法</p></body></html>',
                ),
              ),
              filename: 'daily-report.html',
              contentType: 'text/html',
            ),
          ),
        ),
      ],
    );
    await tester.pump();

    final edge = tester.widget<DecoratedBox>(
      find.byKey(const Key('agent_file_report_card_edge')),
    );
    final decoration = edge.decoration as BoxDecoration;
    final border = decoration.border as Border;

    expect(border.top.color, Colors.white.withValues(alpha: 0.261));
    expect(border.top.width, 0.7);
  });

  testWidgets('html file preview opens webview', (tester) async {
    await _pumpConversationSurface(
      tester,
      LingConversationEntryView(
        entry: LingConversationEntry.assistant(
          id: 'assistant-file-preview-2',
          text: '页面已生成：[网页预览](reports/interactive-page.html)',
        ),
        strings: strings,
        onPreviewAttachment: (_) {},
      ),
      overrides: [
        agentFileRepositoryProvider.overrideWithValue(
          _FakeAgentFileRepository(
            LingAgentFileData(
              path: 'reports/interactive-page.html',
              bytes: Uint8List.fromList(
                utf8.encode(
                  '<html><head><title>Interactive Page</title></head>'
                  '<body><main><button>Run</button></main></body></html>',
                ),
              ),
              filename: 'interactive-page.html',
              contentType: 'text/html',
            ),
          ),
        ),
      ],
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('agent_file_card_reports/interactive-page.html')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agent_file_html_webview')), findsOneWidget);
    expect(find.byKey(const Key('fake_webview_widget')), findsOneWidget);
  });

  testWidgets('unpreviewable agent file link renders a file card', (
    tester,
  ) async {
    await _pumpConversationSurface(
      tester,
      LingConversationEntryView(
        entry: LingConversationEntry.assistant(
          id: 'assistant-file-preview-download',
          text: '报告已生成：[今日整理报告](reports/daily-report.pdf)',
        ),
        strings: strings,
        onPreviewAttachment: (_) {},
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('agent_file_card_reports/daily-report.pdf')),
      findsOneWidget,
    );
  });

  testWidgets('agent file card stays visible when preview data cannot load', (
    tester,
  ) async {
    await _pumpConversationSurface(
      tester,
      LingConversationEntryView(
        entry: LingConversationEntry.assistant(
          id: 'assistant-file-preview-load-failure',
          text: '报告已生成：[今日整理报告](reports/missing-report.md)',
        ),
        strings: strings,
        onPreviewAttachment: (_) {},
      ),
      overrides: [
        agentFileRepositoryProvider.overrideWithValue(
          const _ThrowingAgentFileRepository(),
        ),
      ],
    );
    await tester.pump();

    expect(
      find.byKey(const Key('agent_file_card_reports/missing-report.md')),
      findsOneWidget,
    );
  });
}
