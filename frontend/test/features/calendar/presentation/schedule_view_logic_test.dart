import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/config/constants.dart';
import 'package:ling/src/features/calendar/data/bridges/apple_calendar_bridge.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';
import 'package:ling/src/features/calendar/presentation/schedule_view_models.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';

void main() {
  test(
    'buildLingScheduleDayBuckets groups, sorts, and de-dupes Apple events',
    () {
      final strings = LingStrings('zh-CN');
      final buckets = buildLingScheduleDayBuckets(
        strings: strings,
        startDate: DateTime(2026, 4, 5),
        lingEvents: <LingEvent>[
          _event(
            'focus',
            'Focus Sprint',
            DateTime(2026, 4, 5, 10),
            appleIdentifier: 'apple-dup',
          ),
          _event('standup', 'Standup', DateTime(2026, 4, 5, 9)),
          _event('doctor', 'Doctor', DateTime(2026, 4, 6, 13)),
        ],
        appleEvents: <AppleCalendarEvent>[
          AppleCalendarEvent(
            identifier: 'apple-breakfast',
            calendarIdentifier: 'cal-1',
            title: 'Apple Breakfast',
            startAt: DateTime(2026, 4, 5, 8),
            endAt: DateTime(2026, 4, 5, 8, 30),
            timezone: AppConstants.defaultTimezone,
          ),
          AppleCalendarEvent(
            identifier: 'apple-dup',
            calendarIdentifier: 'cal-1',
            title: 'Duplicated',
            startAt: DateTime(2026, 4, 5, 10),
            endAt: DateTime(2026, 4, 5, 11),
            timezone: AppConstants.defaultTimezone,
          ),
          AppleCalendarEvent(
            identifier: 'apple-design',
            calendarIdentifier: 'cal-2',
            title: 'Design Review',
            startAt: DateTime(2026, 4, 7, 15),
            endAt: DateTime(2026, 4, 7, 16),
            timezone: AppConstants.defaultTimezone,
          ),
          AppleCalendarEvent(
            identifier: 'apple-holiday',
            calendarIdentifier: 'cal-holiday',
            calendarTitle: '中国大陆节假日',
            title: '清明节',
            startAt: DateTime(2026, 4, 8),
            endAt: DateTime(2026, 4, 9),
            timezone: AppConstants.defaultTimezone,
            isAllDay: true,
            kind: AppleCalendarEventKind.holiday,
          ),
        ],
      );

      expect(buckets, hasLength(7));
      expect(
        buckets.first.items.map((item) => item.title).toList(growable: false),
        <String>['Apple Breakfast', 'Standup', 'Focus Sprint'],
      );
      expect(buckets.first.items.first.sourceLabel, strings.sourceApple);
      expect(
        buckets[1].items.map((item) => item.title).toList(growable: false),
        <String>['Doctor'],
      );
      expect(
        buckets[2].items.map((item) => item.title).toList(growable: false),
        <String>['Design Review'],
      );
      expect(buckets[3].items.single.sourceLabel, '中国大陆节假日');
      expect(buckets[3].items.single.timeLabel, strings.allDay);
      expect(buckets.skip(4).every((bucket) => bucket.items.isEmpty), isTrue);
    },
  );

  test('point Ling events render as single-time agenda items', () {
    final strings = LingStrings('zh-CN');
    final items = buildLingScheduleAgendaItems(
      strings: strings,
      selectedDate: '2026-04-05',
      lingEvents: <LingEvent>[
        _event(
          'reminder',
          '给爸妈打电话',
          DateTime(2026, 4, 5, 20),
          timeShape: 'point',
        ),
      ],
      appleEvents: const <AppleCalendarEvent>[],
    );

    expect(items, hasLength(1));
    expect(items.single.isPoint, isTrue);
    expect(items.single.timeLabel, '20:00');
    expect(items.single.durationLabel, isEmpty);
  });

  test('zero-duration Ling events render as single-time agenda items', () {
    final strings = LingStrings('zh-CN');
    final items = buildLingScheduleAgendaItems(
      strings: strings,
      selectedDate: '2026-04-05',
      lingEvents: <LingEvent>[
        LingEvent(
          eventId: 'legacy-point',
          userId: 'user-1',
          title: '交材料',
          startAt: DateTime(2026, 4, 5, 15, 30),
          endAt: DateTime(2026, 4, 5, 15, 30),
          timezone: AppConstants.defaultTimezone,
          timeShape: 'span',
        ),
      ],
      appleEvents: const <AppleCalendarEvent>[],
    );

    expect(items, hasLength(1));
    expect(items.single.isPoint, isTrue);
    expect(items.single.timeLabel, '15:30');
    expect(items.single.durationLabel, isEmpty);
  });

  test(
    'holiday Apple events fall back to generic source label when type is absent',
    () {
      final strings = LingStrings('zh-CN');
      final buckets = buildLingScheduleDayBuckets(
        strings: strings,
        startDate: DateTime(2026, 4, 5),
        lingEvents: const <LingEvent>[],
        appleEvents: <AppleCalendarEvent>[
          AppleCalendarEvent(
            identifier: 'apple-holiday',
            calendarIdentifier: 'cal-holiday',
            title: 'Holiday',
            startAt: DateTime(2026, 4, 5),
            endAt: DateTime(2026, 4, 6),
            timezone: AppConstants.defaultTimezone,
            isAllDay: true,
            kind: AppleCalendarEventKind.holiday,
          ),
        ],
      );

      expect(
        buckets.first.items.single.sourceLabel,
        strings.sourceAppleHoliday,
      );
    },
  );

  test(
    'resolveLingScheduleWindowEvents falls back to today events only before first window load',
    () {
      final todayEvent = _event(
        'today',
        'Today Event',
        DateTime(2026, 4, 5, 9),
      );
      final otherDayEvent = _event(
        'other',
        'Other Day Event',
        DateTime(2026, 4, 6, 11),
      );

      final fallbackEvents = resolveLingScheduleWindowEvents(
        windowStartDate: DateTime(2026, 4, 5),
        hasLoadedWindowEvents: false,
        windowEvents: const <LingEvent>[],
        selectedDayEvents: <LingEvent>[todayEvent, otherDayEvent],
      );
      expect(
        fallbackEvents.map((event) => event.eventId).toList(growable: false),
        <String>['today'],
      );

      final loadedEmptyEvents = resolveLingScheduleWindowEvents(
        windowStartDate: DateTime(2026, 4, 5),
        hasLoadedWindowEvents: true,
        windowEvents: const <LingEvent>[],
        selectedDayEvents: <LingEvent>[todayEvent],
      );
      expect(loadedEmptyEvents, isEmpty);
    },
  );

  test(
    'buildLingScheduleAgendaItems exposes recurring labels for Ling and Apple events',
    () {
      final strings = LingStrings('zh-CN');
      final items = buildLingScheduleAgendaItems(
        strings: strings,
        selectedDate: '2026-04-06',
        lingEvents: <LingEvent>[
          LingEvent(
            eventId: 'series-1',
            userId: 'user-1',
            title: '晨跑',
            startAt: DateTime(2026, 4, 6, 7),
            endAt: DateTime(2026, 4, 6, 8),
            timezone: AppConstants.defaultTimezone,
            isRecurring: true,
            recurrence: const LingEventRecurrence(
              frequency: 'weekly',
              byWeekday: <String>['MO', 'WE'],
            ),
          ),
        ],
        appleEvents: <AppleCalendarEvent>[
          AppleCalendarEvent(
            identifier: 'apple-recurring',
            calendarIdentifier: 'apple-cal',
            title: 'Apple Standup',
            startAt: DateTime(2026, 4, 6, 9),
            endAt: DateTime(2026, 4, 6, 9, 30),
            timezone: AppConstants.defaultTimezone,
            isRecurring: true,
            recurrence: const LingEventRecurrence(frequency: 'daily'),
          ),
        ],
      );

      expect(items, hasLength(2));
      expect(items.first.title, '晨跑');
      expect(items.first.recurrenceLabel, '每周一、三');
      expect(items.last.title, 'Apple Standup');
      expect(items.last.recurrenceLabel, '每天');
    },
  );

  test(
    'buildLingScheduleAgendaItems keeps Apple occurrence-only rows non-recurring across both data sources',
    () {
      final strings = LingStrings('zh-CN');
      final items = buildLingScheduleAgendaItems(
        strings: strings,
        selectedDate: '2026-04-06',
        lingEvents: <LingEvent>[
          LingEvent(
            eventId: 'apple:item-1:2026-04-06',
            userId: 'user-1',
            title: 'Stored Apple Occurrence',
            startAt: DateTime(2026, 4, 6, 9),
            endAt: DateTime(2026, 4, 6, 9, 30),
            timezone: AppConstants.defaultTimezone,
            source: 'apple',
            provider: 'apple_local',
            isRecurring: false,
            occurrenceStartAt: DateTime(2026, 4, 6, 9),
            metadata: const <String, dynamic>{
              'calendar_title': 'Apple Calendar',
              'kind': 'event',
            },
          ),
        ],
        appleEvents: <AppleCalendarEvent>[
          AppleCalendarEvent(
            identifier: 'apple-occurrence-only',
            calendarIdentifier: 'apple-cal',
            title: 'Native Apple Occurrence',
            startAt: DateTime(2026, 4, 6, 10),
            endAt: DateTime(2026, 4, 6, 10, 30),
            timezone: AppConstants.defaultTimezone,
            occurrenceDate: DateTime(2026, 4, 6, 10),
            isRecurring: false,
          ),
        ],
      );

      expect(items, hasLength(2));
      expect(items.first.title, 'Stored Apple Occurrence');
      expect(items.first.recurrenceLabel, isEmpty);
      expect(items.last.title, 'Native Apple Occurrence');
      expect(items.last.recurrenceLabel, isEmpty);
    },
  );

  test('buildLingScheduleAgendaItems resolves theme-aware accents', () {
    final strings = LingStrings('zh-CN');
    final lightItems = buildLingScheduleAgendaItems(
      strings: strings,
      selectedDate: '2026-04-06',
      lingEvents: <LingEvent>[
        _event('focus', 'Focus', DateTime(2026, 4, 6, 9), category: 'focus'),
      ],
      appleEvents: <AppleCalendarEvent>[
        AppleCalendarEvent(
          identifier: 'apple-holiday',
          calendarIdentifier: 'apple-cal',
          title: 'Holiday',
          startAt: DateTime(2026, 4, 6),
          endAt: DateTime(2026, 4, 7),
          timezone: AppConstants.defaultTimezone,
          isAllDay: true,
          kind: AppleCalendarEventKind.holiday,
        ),
      ],
    );
    final darkItems = buildLingScheduleAgendaItems(
      strings: strings,
      selectedDate: '2026-04-06',
      lingEvents: <LingEvent>[
        _event('focus', 'Focus', DateTime(2026, 4, 6, 9), category: 'focus'),
      ],
      appleEvents: <AppleCalendarEvent>[
        AppleCalendarEvent(
          identifier: 'apple-holiday',
          calendarIdentifier: 'apple-cal',
          title: 'Holiday',
          startAt: DateTime(2026, 4, 6),
          endAt: DateTime(2026, 4, 7),
          timezone: AppConstants.defaultTimezone,
          isAllDay: true,
          kind: AppleCalendarEventKind.holiday,
        ),
      ],
      brightness: Brightness.dark,
    );

    final lightFocus = lightItems.singleWhere((item) => item.title == 'Focus');
    final darkFocus = darkItems.singleWhere((item) => item.title == 'Focus');
    final lightHoliday = lightItems.singleWhere(
      (item) => item.title == 'Holiday',
    );
    final darkHoliday = darkItems.singleWhere(
      (item) => item.title == 'Holiday',
    );

    expect(lightFocus.accent, const Color(0xFF3B82F6));
    expect(darkFocus.accent, const Color(0xFF7DD3FC));
    expect(lightHoliday.accent, const Color(0xFFD97706));
    expect(darkHoliday.accent, const Color(0xFFFBBF24));
  });

  test(
    'buildLingScheduleDayBuckets splits cross-day events into daily segments',
    () {
      final strings = LingStrings('zh-CN');
      final buckets = buildLingScheduleDayBuckets(
        strings: strings,
        startDate: DateTime(2026, 4, 18),
        lingEvents: <LingEvent>[
          LingEvent(
            eventId: 'trip',
            userId: 'user-1',
            title: '武夷山行程',
            startAt: DateTime(2026, 4, 18, 8),
            endAt: DateTime(2026, 4, 19, 21),
            timezone: AppConstants.defaultTimezone,
          ),
        ],
        appleEvents: const <AppleCalendarEvent>[],
      );

      expect(buckets.first.items, hasLength(1));
      expect(buckets.first.items.single.title, '武夷山行程');
      expect(buckets.first.items.single.startTimeLabel, '08:00');
      expect(buckets.first.items.single.endTimeLabel, '24:00');
      expect(buckets.first.items.single.timeLabel, '08:00 - 24:00');
      expect(buckets.first.items.single.durationLabel, '16小时');

      expect(buckets[1].items, hasLength(1));
      expect(buckets[1].items.single.startTimeLabel, '00:00');
      expect(buckets[1].items.single.endTimeLabel, '21:00');
      expect(buckets[1].items.single.timeLabel, '00:00 - 21:00');
      expect(buckets[1].items.single.durationLabel, '21小时');
    },
  );
}

LingEvent _event(
  String id,
  String title,
  DateTime startAt, {
  String? appleIdentifier,
  String category = 'personal',
  String timeShape = 'span',
}) {
  return LingEvent(
    eventId: id,
    userId: 'user-1',
    title: title,
    startAt: startAt,
    endAt: timeShape == 'point'
        ? startAt
        : startAt.add(const Duration(hours: 1)),
    timezone: AppConstants.defaultTimezone,
    category: category,
    timeShape: timeShape,
    appleLink: appleIdentifier == null
        ? null
        : AppleEventLink(
            eventIdentifier: appleIdentifier,
            calendarIdentifier: 'cal-1',
            deviceId: 'device-1',
          ),
  );
}
