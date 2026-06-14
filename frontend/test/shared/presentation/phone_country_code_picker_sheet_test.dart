import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/shared/models/phone_country.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/phone_country_code_picker_sheet.dart';

Widget _host(Widget child, {Locale locale = const Locale('zh')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('zh'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.light(),
    home: Scaffold(
      body: LingGlassLayer(child: Center(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async {
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('filters phone countries by dial code, code, and chinese name', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(PhoneCountryCodePickerSheet(selected: phoneCountries.first)),
    );

    final searchField = find.descendant(
      of: find.byKey(const Key('phone_country_code_search_field')),
      matching: find.byType(TextField),
    );

    expect(find.text('搜索国家/地区或区号'), findsOneWidget);
    expect(find.text('中国大陆'), findsOneWidget);
    expect(find.text('+86'), findsOneWidget);

    await tester.enterText(searchField, '86');
    await tester.pump();
    expect(find.text('中国大陆'), findsOneWidget);
    expect(find.text('美国 / 加拿大'), findsNothing);

    await tester.enterText(searchField, 'CN');
    await tester.pump();
    expect(find.text('中国大陆'), findsOneWidget);

    await tester.enterText(searchField, '中国');
    await tester.pump();
    expect(find.text('中国大陆'), findsOneWidget);

    await tester.enterText(searchField, '+1');
    await tester.pump();
    expect(find.text('美国 / 加拿大'), findsOneWidget);
    expect(find.text('中国大陆'), findsNothing);

    await tester.enterText(searchField, 'zzzzz');
    await tester.pump();
    expect(
      find.byKey(const Key('phone_country_code_empty_text')),
      findsOneWidget,
    );
  });

  testWidgets('localizes phone country picker text in english', (tester) async {
    await tester.pumpWidget(
      _host(
        PhoneCountryCodePickerSheet(selected: phoneCountries.first),
        locale: const Locale('en'),
      ),
    );

    expect(find.text('Search country/region or code'), findsOneWidget);
    expect(find.text('Mainland China'), findsOneWidget);
    expect(find.text('中国大陆'), findsNothing);

    final searchField = find.descendant(
      of: find.byKey(const Key('phone_country_code_search_field')),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, 'zzzzz');
    await tester.pump();
    expect(find.text('No matching country code'), findsOneWidget);
  });

  testWidgets('returns selected phone country from bottom sheet', (
    tester,
  ) async {
    PhoneCountry? selected;

    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return LingGlassButton(
              onPressed: () async {
                selected = await showPhoneCountryCodePickerSheet(
                  context: context,
                  selected: phoneCountries.first,
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('请输入手机号'), findsNothing);
    expect(
      find.byKey(const Key('phone_country_code_search_field')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('phone_country_code_row_HK')));
    await tester.pumpAndSettle();

    expect(selected?.code, 'HK');
    expect(selected?.dialCode, '+852');
  });

  testWidgets('bottom sheet gives the country picker more vertical room', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return LingGlassButton(
              onPressed: () {
                showPhoneCountryCodePickerSheet(
                  context: context,
                  selected: phoneCountries.first,
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final hostContext = tester.element(find.text('Open'));
    final availableHeight = MediaQuery.sizeOf(hostContext).height;
    final sheetRect = tester.getRect(
      find.byKey(const Key('phone_country_code_picker_modal')),
    );
    expect(sheetRect.height, lessThanOrEqualTo(availableHeight * 0.80));
    expect(sheetRect.height, greaterThan(availableHeight * 0.75));
  });
}
