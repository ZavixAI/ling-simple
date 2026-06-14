part of 'settings_preferences_permissions_test.dart';

void registerSettingsPermissionTests(LingStrings zhStrings) {
  testWidgets('permissions page shows microphone and photo status labels', (
    tester,
  ) async {
    await _pumpSettingsPage(
      tester,
      calendarConnections: const [],
      microphonePermission: SpeechAuthorizationState.granted,
      photoLibraryPermission: PhotoLibraryPermissionState.notDetermined,
    );

    await tester.tap(find.text(zhStrings.permissionsTitle).hitTestable());
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('settings_microphone_permission_row')),
        matching: find.text(zhStrings.notificationPermissionGranted),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('settings_photo_library_permission_row')),
        matching: find.text(zhStrings.notificationPermissionNotDetermined),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping denied microphone permission row opens system settings',
    (tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final speechBridge = _FakeAppleSpeechRecognitionBridge(
        authorizationState: AppleSpeechAuthorizationState.denied,
      );
      final calendarNotificationBridge = _FakeCalendarNotificationBridge()
        ..permission = CalendarNotificationPermissionState.granted;
      final deviceContextBridge = _TrackingDeviceContextBridge();
      final photoLibraryBridge = _FakePhotoLibraryPermissionBridge(
        permission: PhotoLibraryPermissionState.granted,
      );
      final appleCalendarBridge = _FakeAppleCalendarBridge(
        permission: AppleCalendarPermissionState.granted,
      );
      try {
        await _pumpAuthenticatedApp(
          tester,
          overrides: <Override>[
            appleSpeechRecognitionBridgeProvider.overrideWithValue(
              speechBridge,
            ),
            calendarNotificationBridgeProvider.overrideWithValue(
              calendarNotificationBridge,
            ),
            deviceContextBridgeProvider.overrideWithValue(deviceContextBridge),
            photoLibraryPermissionBridgeProvider.overrideWithValue(
              photoLibraryBridge,
            ),
            appleCalendarBridgeProvider.overrideWithValue(appleCalendarBridge),
          ],
        );

        await tester.tap(find.byKey(const Key('topbar_avatar_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(zhStrings.permissionsTitle).hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(zhStrings.microphonePermissionTitle).hitTestable(),
        );
        await tester.pumpAndSettle();

        expect(speechBridge.openSystemSettingsCalls, 1);
        expect(speechBridge.requestMicrophonePermissionCalls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    },
  );

  testWidgets(
    'tapping not determined microphone permission row requests permission',
    (tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final speechBridge = _FakeAppleSpeechRecognitionBridge(
        authorizationState: AppleSpeechAuthorizationState.notDetermined,
      );
      final calendarNotificationBridge = _FakeCalendarNotificationBridge()
        ..permission = CalendarNotificationPermissionState.granted;
      final deviceContextBridge = _TrackingDeviceContextBridge();
      final photoLibraryBridge = _FakePhotoLibraryPermissionBridge(
        permission: PhotoLibraryPermissionState.granted,
      );
      final appleCalendarBridge = _FakeAppleCalendarBridge(
        permission: AppleCalendarPermissionState.granted,
      );
      try {
        await _pumpAuthenticatedApp(
          tester,
          overrides: <Override>[
            appleSpeechRecognitionBridgeProvider.overrideWithValue(
              speechBridge,
            ),
            calendarNotificationBridgeProvider.overrideWithValue(
              calendarNotificationBridge,
            ),
            deviceContextBridgeProvider.overrideWithValue(deviceContextBridge),
            photoLibraryPermissionBridgeProvider.overrideWithValue(
              photoLibraryBridge,
            ),
            appleCalendarBridgeProvider.overrideWithValue(appleCalendarBridge),
          ],
        );

        await tester.tap(find.byKey(const Key('topbar_avatar_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(zhStrings.permissionsTitle).hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(zhStrings.microphonePermissionTitle).hitTestable(),
        );
        await tester.pumpAndSettle();

        expect(speechBridge.requestMicrophonePermissionCalls, 1);
        expect(speechBridge.openSystemSettingsCalls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    },
  );
}
