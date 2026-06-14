import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/shared/presentation/notice.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  BuildContext noticeContext(WidgetTester tester) {
    return tester.element(find.byKey(const Key('notice_harness')));
  }

  Future<void> pumpNoticeHarness(WidgetTester tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 24),
        ),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  SizedBox.expand(key: const Key('notice_harness')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('top notice renders near the safe-area top edge', (tester) async {
    await pumpNoticeHarness(tester);

    showLingTopNotice(noticeContext(tester), '第一条提示');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final noticeRect = tester.getRect(find.byType(GlassToast));
    final scaffoldRect = tester.getRect(find.byType(Scaffold));

    expect(find.text('第一条提示'), findsOneWidget);
    expect(noticeRect.top, lessThan(scaffoldRect.height / 3));
    expect(noticeRect.top, greaterThanOrEqualTo(24));
    final notice = tester.widget<GlassToast>(find.byType(GlassToast));
    expect(notice.position, GlassToastPosition.top);
    expect(notice.type, GlassToastType.info);
    final textContext = tester.element(find.text('第一条提示'));
    expect(
      DefaultTextStyle.of(textContext).style.decoration,
      TextDecoration.none,
    );
  });

  testWidgets('showing a second notice replaces the previous one', (
    tester,
  ) async {
    await pumpNoticeHarness(tester);

    showLingTopNotice(noticeContext(tester), '第一条提示');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('第一条提示'), findsOneWidget);

    showLingTopNotice(noticeContext(tester), '第二条提示');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byType(GlassToast), findsOneWidget);
    expect(find.text('第一条提示'), findsNothing);
    expect(find.text('第二条提示'), findsOneWidget);
  });

  testWidgets('swiping a top notice removes the dismissible immediately', (
    tester,
  ) async {
    await pumpNoticeHarness(tester);

    showLingTopNotice(noticeContext(tester), '可滑走提示');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    await tester.drag(
      find.byKey(const Key('ling_top_notice_dismissible')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();

    expect(find.text('可滑走提示'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
