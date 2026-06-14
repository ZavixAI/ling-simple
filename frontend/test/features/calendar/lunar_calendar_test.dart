import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/models/lunar_calendar.dart';
import 'package:ling/src/features/calendar/presentation/calendar_month_grid.dart';

void main() {
  test('formats lunar month and day labels', () {
    expect(formatLingLunarDate(DateTime(2026, 2, 17)), '正月');
    expect(formatLingLunarDate(DateTime(2026, 2, 18)), '初二');
    expect(formatLingLunarDate(DateTime(2026, 4, 5)), '十八');
  });

  testWidgets('month grid shows lunar labels without plain day glass shells', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: LingCalendarMonthGrid(
            weekdayHeaders: const <String>['一', '二', '三', '四', '五', '六', '日'],
            selectedDate: '2026-02-17',
            appleCountByDate: const <String, int>{},
            monthDays: const <CalendarMonthDay>[
              CalendarMonthDay(
                date: '2026-02-17',
                inCurrentMonth: true,
                isToday: false,
                isSelected: true,
                eventCount: 1,
                hasFocusEvent: false,
              ),
              CalendarMonthDay(
                date: '2026-02-18',
                inCurrentMonth: true,
                isToday: false,
                isSelected: false,
                eventCount: 0,
                hasFocusEvent: false,
              ),
            ],
            onSelectDate: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('正月'), findsOneWidget);
    expect(find.text('初二'), findsOneWidget);

    final selectedContainer = tester.widget<AnimatedContainer>(
      find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('calendar_month_day_2026-02-17'),
            ),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final plainContainer = tester.widget<AnimatedContainer>(
      find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('calendar_month_day_2026-02-18'),
            ),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );

    expect(
      (selectedContainer.decoration! as BoxDecoration).color,
      isNot(Colors.transparent),
    );
    expect(
      (plainContainer.decoration! as BoxDecoration).color,
      Colors.transparent,
    );
  });
}
