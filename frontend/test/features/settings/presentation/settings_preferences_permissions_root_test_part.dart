part of 'settings_preferences_permissions_test.dart';

void registerSettingsRootTests(LingStrings zhStrings) {
  testWidgets('settings root keeps subtle Powered by Sage footer at bottom', (
    tester,
  ) async {
    await _pumpSettingsPage(tester, calendarConnections: const []);

    final footerFinder = find.byKey(
      const Key('settings_powered_by_sage_footer'),
    );
    expect(footerFinder, findsOneWidget);
    expect(find.text(zhStrings.settingsPoweredBySage), findsOneWidget);
    expect(tester.getBottomLeft(footerFinder).dy, greaterThan(1120));
  });
}
