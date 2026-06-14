import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/config/constants.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/calendar/models/calendar_event_editor_models.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/presentation/event_editor_sheet.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/surface_group.dart';

class _TestNavigatorObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount += 1;
    super.didPop(route, previousRoute);
  }
}

class _EventEditorSheetLauncher extends StatefulWidget {
  const _EventEditorSheetLauncher();

  @override
  State<_EventEditorSheetLauncher> createState() =>
      _EventEditorSheetLauncherState();
}

class _EventEditorSheetLauncherState extends State<_EventEditorSheetLauncher> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) {
      return;
    }
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      showLingAdaptiveSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return LingCalendarEventEditorSheet(
            strings: const LingStrings('zh-CN'),
            sheetTitle: '修改日程',
            initialStartAt: DateTime(2026, 4, 18, 8),
            initialEndAt: DateTime(2026, 4, 18, 9),
            timezone: AppConstants.defaultTimezone,
            notificationLabel: '提前 10 分钟',
            submitLabel: '保存修改',
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.expand());
  }
}

class _EventEditorResultLauncher extends StatefulWidget {
  const _EventEditorResultLauncher({super.key});

  @override
  State<_EventEditorResultLauncher> createState() =>
      _EventEditorResultLauncherState();
}

class _EventEditorResultLauncherState
    extends State<_EventEditorResultLauncher> {
  LingCalendarEventEditorResult? result;
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) {
      return;
    }
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final nextResult = await Navigator.of(context)
          .push<LingCalendarEventEditorResult>(
            MaterialPageRoute<LingCalendarEventEditorResult>(
              builder: (context) {
                return Scaffold(
                  body: LingCalendarEventEditorSheet(
                    strings: const LingStrings('zh-CN'),
                    sheetTitle: '修改日程',
                    initialTitle: '早餐提醒',
                    initialLocation: '厨房',
                    initialStartAt: DateTime(2026, 4, 18, 8),
                    initialEndAt: DateTime(2026, 4, 18, 9),
                    timezone: AppConstants.defaultTimezone,
                    notificationLabel: '提前 10 分钟',
                    submitLabel: '保存修改',
                  ),
                );
              },
            ),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        result = nextResult;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.expand());
  }
}

void main() {
  testWidgets('edit sheet shows end date and end time instead of duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('zh', 'CN'),
        home: Scaffold(
          body: LingCalendarEventEditorSheet(
            strings: const LingStrings('zh-CN'),
            sheetTitle: '修改日程',
            initialStartAt: DateTime(2026, 4, 18, 8),
            initialEndAt: DateTime(2026, 4, 19, 21),
            timezone: AppConstants.defaultTimezone,
            notificationLabel: '提前 10 分钟',
            submitLabel: '保存修改',
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byKey(const Key('quick_add_end_date_tile')), findsOneWidget);
    expect(find.byKey(const Key('quick_add_end_time_tile')), findsOneWidget);
    expect(find.text('结束日期'), findsOneWidget);
    expect(find.text('结束时间'), findsOneWidget);
    expect(find.text('2026-04-19'), findsOneWidget);
    expect(find.text('21:00'), findsOneWidget);
    expect(find.byKey(const Key('quick_add_duration_2220')), findsNothing);
  });

  testWidgets('start time wheel updates submitted start time', (tester) async {
    final launcherKey = GlobalKey<_EventEditorResultLauncherState>();
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('zh', 'CN'),
        home: _EventEditorResultLauncher(key: launcherKey),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_add_time_tile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick_add_start_time_picker')), findsWidgets);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();

    final hourWheel = find.byType(ListWheelScrollView).first;
    await tester.drag(hourWheel, const Offset(0, -96));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quick_add_create_button')));
    await tester.pumpAndSettle();

    final result = launcherKey.currentState!.result;
    expect(result, isNotNull);
    expect(result!.draft!.startAt.hour, greaterThan(8));
  });

  testWidgets('event editor sheet shows editable recurrence controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('zh', 'CN'),
        home: Scaffold(
          body: LingCalendarEventEditorSheet(
            strings: const LingStrings('zh-CN'),
            sheetTitle: '修改日程',
            initialStartAt: DateTime(2026, 4, 6, 9),
            initialEndAt: DateTime(2026, 4, 6, 9, 30),
            timezone: AppConstants.defaultTimezone,
            notificationLabel: '提前 10 分钟',
            submitLabel: '保存修改',
            initialRecurrence: const LingEventRecurrence(
              frequency: 'weekly',
              byWeekday: <String>['MO', 'WE'],
            ),
            initialMutationScope: 'series',
            allowMutationScopeSelection: true,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(
      find.byKey(const Key('quick_add_recurrence_banner')),
      findsOneWidget,
    );
    expect(find.text('每周一、三重复'), findsOneWidget);
    expect(find.byKey(const Key('quick_add_scope_occurrence')), findsOneWidget);
    expect(find.byKey(const Key('quick_add_scope_series')), findsOneWidget);
    expect(
      find.byKey(const Key('quick_add_recurrence_weekly')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('quick_add_weekday_MO')), findsOneWidget);
    expect(find.byKey(const Key('quick_add_weekday_WE')), findsOneWidget);
  });

  testWidgets('edit sheet uses fixed chrome without description or divider', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('zh', 'CN'),
        home: Scaffold(
          body: LingCalendarEventEditorSheet(
            strings: const LingStrings('zh-CN'),
            sheetTitle: '修改日程',
            initialStartAt: DateTime(2026, 4, 18, 8),
            initialEndAt: DateTime(2026, 4, 18, 9),
            timezone: AppConstants.defaultTimezone,
            notificationLabel: '提前 10 分钟',
            submitLabel: '保存修改',
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byKey(const Key('quick_add_edit_header')), findsOneWidget);
    expect(
      find.byKey(const Key('quick_add_edit_header_drag_handle')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('quick_add_edit_footer')), findsOneWidget);
    expect(find.byType(LingSurfaceGroup), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('edit sheet drag dismiss pops route without extra delay', (
    tester,
  ) async {
    final observer = _TestNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('zh', 'CN'),
        navigatorObservers: [observer],
        home: const _EventEditorSheetLauncher(),
      ),
    );

    await tester.pumpAndSettle();

    final header = find.byKey(const Key('quick_add_edit_header'));
    expect(header, findsOneWidget);

    await tester.drag(header, const Offset(0, 220));
    await tester.pump();

    expect(observer.popCount, 1);
  });

  testWidgets(
    'event editor sheet locks recurrence editor when occurrence scope is selected',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('zh', 'CN'),
          home: Scaffold(
            body: LingCalendarEventEditorSheet(
              strings: const LingStrings('zh-CN'),
              sheetTitle: '修改日程',
              initialStartAt: DateTime(2026, 4, 6, 9),
              initialEndAt: DateTime(2026, 4, 6, 9, 30),
              timezone: AppConstants.defaultTimezone,
              notificationLabel: '提前 10 分钟',
              submitLabel: '保存修改',
              initialRecurrence: const LingEventRecurrence(
                frequency: 'weekly',
                byWeekday: <String>['MO', 'WE'],
              ),
              initialMutationScope: 'series',
              allowMutationScopeSelection: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('quick_add_scope_occurrence')),
      );
      await tester.tap(find.byKey(const Key('quick_add_scope_occurrence')));
      await tester.pumpAndSettle();

      expect(find.text('当前选择“仅这一次”，不会修改整个系列的重复规则。'), findsAtLeastNWidgets(1));
    },
  );
}
