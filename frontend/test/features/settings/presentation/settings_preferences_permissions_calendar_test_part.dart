part of 'settings_preferences_permissions_test.dart';

void registerSettingsCalendarPermissionTests(LingStrings zhStrings) {
  testWidgets('settings hides Feishu and DingTalk calendar rows', (
    tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final integrationRepository = _FakeCalendarIntegrationRepository(
      connections: const <CalendarConnectionSummary>[
        CalendarConnectionSummary(
          providerId: CalendarProviderId.appleLocal,
          providerName: 'Apple Calendar',
          kind: 'system_permission',
          status: 'connected',
          isEnabled: true,
          isConnected: true,
          eventCount: 0,
        ),
        CalendarConnectionSummary(
          providerId: CalendarProviderId.feishu,
          providerName: 'Feishu',
          kind: 'oauth',
          status: 'connected',
          isEnabled: true,
          isConnected: true,
          eventCount: 3,
        ),
        CalendarConnectionSummary(
          providerId: CalendarProviderId.dingtalk,
          providerName: 'DingTalk',
          kind: 'oauth',
          status: 'not_connected',
          isEnabled: true,
          isConnected: false,
          eventCount: 0,
        ),
      ],
    );
    try {
      await _pumpAuthenticatedApp(
        tester,
        calendarIntegrationRepository: integrationRepository,
        overrides: <Override>[
          appleCalendarBridgeProvider.overrideWithValue(
            _FakeAppleCalendarBridge(
              permission: AppleCalendarPermissionState.granted,
            ),
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('topbar_avatar_button')));
      await tester.pumpAndSettle();

      final calendarAndNotifications = find.text(
        zhStrings.calendarSectionTitle,
      );
      await tester.ensureVisible(calendarAndNotifications);
      await tester.tap(calendarAndNotifications.hitTestable());
      await tester.pumpAndSettle();

      expect(find.text('系统通知'), findsNothing);
      expect(find.text('第三方日历'), findsNothing);
      expect(find.text('Apple日历'), findsOneWidget);
      expect(find.text('飞书日历'), findsNothing);
      expect(find.text('钉钉日历'), findsNothing);
      expect(find.byKey(const Key('calendar_auth_row_feishu')), findsNothing);
      expect(find.byKey(const Key('calendar_auth_row_dingtalk')), findsNothing);
      expect(find.text('读取日程'), findsWidgets);
      expect(find.text('日历授权'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  testWidgets('tapping Apple calendar row opens system settings directly', (
    tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final appleCalendarBridge = _FakeAppleCalendarBridge(
      permission: AppleCalendarPermissionState.granted,
    );
    final integrationRepository = _FakeCalendarIntegrationRepository(
      connections: const <CalendarConnectionSummary>[],
    );
    try {
      await _pumpAuthenticatedApp(
        tester,
        calendarIntegrationRepository: integrationRepository,
        overrides: <Override>[
          appleCalendarBridgeProvider.overrideWithValue(appleCalendarBridge),
        ],
      );

      await tester.tap(find.byKey(const Key('topbar_avatar_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(zhStrings.calendarSectionTitle).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('calendar_auth_row_appleLocal')).hitTestable(),
      );
      await tester.pumpAndSettle();

      expect(appleCalendarBridge.openSystemSettingsCalls, 1);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  testWidgets(
    'tapping Apple calendar row requests permission when not determined',
    (tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final appleCalendarBridge = _FakeAppleCalendarBridge(
        permission: AppleCalendarPermissionState.notDetermined,
        requestPermissionResult: AppleCalendarPermissionState.granted,
      );
      final preferencesStore = _FakePreferencesStore(
        initialValues: <String, String>{
          _calendarPermissionPromptShownPreferenceKey: '1',
        },
      );
      final integrationRepository = _FakeCalendarIntegrationRepository(
        connections: const <CalendarConnectionSummary>[],
      );
      try {
        await _pumpAuthenticatedApp(
          tester,
          calendarIntegrationRepository: integrationRepository,
          overrides: <Override>[
            appleCalendarBridgeProvider.overrideWithValue(appleCalendarBridge),
            preferencesProvider.overrideWithValue(preferencesStore),
          ],
        );

        await tester.tap(find.byKey(const Key('topbar_avatar_button')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(zhStrings.calendarSectionTitle).hitTestable(),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('calendar_auth_row_appleLocal')).hitTestable(),
        );
        await tester.pumpAndSettle();

        expect(appleCalendarBridge.requestPermissionCalls, 1);
        expect(appleCalendarBridge.openSystemSettingsCalls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    },
  );

  testWidgets('hidden Feishu row does not start external calendar OAuth', (
    tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final appLauncher = _FakeCalendarProviderAppLauncher(openResult: false);
    final oauthBridge = _FakeExternalCalendarOAuthBridge();
    final integrationRepository = _FakeCalendarIntegrationRepository(
      connections: const <CalendarConnectionSummary>[
        CalendarConnectionSummary(
          providerId: CalendarProviderId.feishu,
          providerName: 'Feishu',
          kind: 'oauth',
          status: 'not_connected',
          isEnabled: true,
          isConnected: false,
          eventCount: 0,
        ),
      ],
    );
    try {
      await _pumpAuthenticatedApp(
        tester,
        calendarIntegrationRepository: integrationRepository,
        overrides: <Override>[
          calendarProviderAppLauncherProvider.overrideWithValue(appLauncher),
          externalCalendarOAuthBridgeProvider.overrideWithValue(oauthBridge),
        ],
      );

      await tester.tap(find.byKey(const Key('topbar_avatar_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(zhStrings.calendarSectionTitle).hitTestable());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calendar_auth_row_feishu')), findsNothing);
      expect(appLauncher.openedProviders, isEmpty);
      expect(integrationRepository.startOAuthProviders, isEmpty);
      expect(oauthBridge.authorizeCalls, 0);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  testWidgets('hidden DingTalk row does not show sync actions', (tester) async {
    await _pumpSettingsPage(
      tester,
      calendarConnections: const <CalendarConnectionSummary>[
        CalendarConnectionSummary(
          providerId: CalendarProviderId.dingtalk,
          providerName: 'DingTalk',
          kind: 'oauth',
          status: 'connected',
          isEnabled: true,
          isConnected: true,
          eventCount: 2,
        ),
      ],
    );

    await tester.tap(find.text(zhStrings.calendarSectionTitle).hitTestable());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar_auth_row_dingtalk')), findsNothing);
    expect(find.text('立即同步'), findsNothing);
    expect(find.text('断开连接'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden Feishu row does not show retry action', (tester) async {
    await _pumpSettingsPage(
      tester,
      calendarConnections: const <CalendarConnectionSummary>[
        CalendarConnectionSummary(
          providerId: CalendarProviderId.feishu,
          providerName: 'Feishu',
          kind: 'oauth',
          status: 'error',
          isEnabled: true,
          isConnected: true,
          eventCount: 2,
        ),
      ],
    );

    await tester.tap(find.text(zhStrings.calendarSectionTitle).hitTestable());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar_auth_row_feishu')), findsNothing);
    expect(find.text('重试同步'), findsNothing);
    expect(find.text('断开连接'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'first launch does not prompt calendar permission when not determined',
    (tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final appleCalendarBridge = _FakeAppleCalendarBridge(
        permission: AppleCalendarPermissionState.notDetermined,
        requestPermissionResult: AppleCalendarPermissionState.granted,
      );
      final preferencesStore = _FakePreferencesStore();
      try {
        await _pumpAuthenticatedApp(
          tester,
          overrides: <Override>[
            appleCalendarBridgeProvider.overrideWithValue(appleCalendarBridge),
            calendarNotificationBridgeProvider.overrideWithValue(
              _FakeCalendarNotificationBridge(),
            ),
            preferencesProvider.overrideWithValue(preferencesStore),
          ],
        );

        expect(
          find.text(zhStrings.appleCalendarFirstLaunchPermissionPromptTitle),
          findsNothing,
        );
        expect(
          find.text(zhStrings.appleCalendarFirstLaunchPermissionPromptMessage),
          findsNothing,
        );
        expect(appleCalendarBridge.requestPermissionCalls, 0);
        expect(appleCalendarBridge.openSystemSettingsCalls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    },
  );

  testWidgets(
    'first launch does not open settings flow when calendar permission denied',
    (tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final appleCalendarBridge = _FakeAppleCalendarBridge(
        permission: AppleCalendarPermissionState.denied,
      );
      try {
        await _pumpAuthenticatedApp(
          tester,
          overrides: <Override>[
            appleCalendarBridgeProvider.overrideWithValue(appleCalendarBridge),
            calendarNotificationBridgeProvider.overrideWithValue(
              _FakeCalendarNotificationBridge(),
            ),
            preferencesProvider.overrideWithValue(_FakePreferencesStore()),
          ],
        );

        expect(
          find.text(zhStrings.appleCalendarPermissionPromptTitle),
          findsNothing,
        );
        expect(
          find.text(zhStrings.appleCalendarFirstLaunchSettingsMessage),
          findsNothing,
        );
        expect(appleCalendarBridge.requestPermissionCalls, 0);
        expect(appleCalendarBridge.openSystemSettingsCalls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    },
  );

  testWidgets(
    'calendar notification settings show local notification controls',
    (tester) async {
      await _pumpAuthenticatedApp(tester);

      await tester.tap(find.byKey(const Key('topbar_avatar_button')));
      await tester.pumpAndSettle();
      final calendarAndNotifications = find.text(zhStrings.notificationsTitle);
      await tester.ensureVisible(calendarAndNotifications);
      await tester.tap(calendarAndNotifications.hitTestable());
      await tester.pumpAndSettle();

      expect(
        find.text(zhStrings.calendarNotificationChannelTitle),
        findsNothing,
      );
      expect(
        find.text(zhStrings.calendarNotificationMethodTitle),
        findsOneWidget,
      );
      expect(
        find.text(zhStrings.defaultNotificationStyleTitle),
        findsOneWidget,
      );
      expect(
        find.text(zhStrings.calendarNotificationEnabledDescription),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
