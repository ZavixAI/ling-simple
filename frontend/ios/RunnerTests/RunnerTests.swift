import EventKit
import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testAliyunNumberAuthThemeMatchesLightLoginPalette() {
    let theme = AliyunNumberAuthTheme.resolve(prefersDarkMode: false)

    assertColor(theme.pageBackground, equalsARGB: 0xFFFFFFFF)
    assertColor(theme.sheetBackground, equalsARGB: 0xFFFFFFFF)
    assertColor(theme.sheetBorderColor, equalsARGB: 0xB3DCE3EA)
    assertColor(theme.primaryText, equalsARGB: 0xFF111318)
    assertColor(theme.buttonBackground, equalsARGB: 0xFF007AFF)
    assertColor(theme.buttonForeground, equalsARGB: 0xFFFFFFFF)
    assertColor(theme.disabledButtonBackground, equalsARGB: 0x4D64D2FF)
  }

  func testAliyunNumberAuthThemeMatchesDarkLoginPalette() {
    let theme = AliyunNumberAuthTheme.resolve(prefersDarkMode: true)

    assertColor(theme.pageBackground, equalsARGB: 0xFF020407)
    assertColor(theme.sheetBackground, equalsARGB: 0xFF020407)
    assertColor(theme.sheetBorderColor, equalsARGB: 0xFF303A49)
    assertColor(theme.primaryText, equalsARGB: 0xFFF8FAFC)
    assertColor(theme.buttonBackground, equalsARGB: 0xFF0A84FF)
    assertColor(theme.buttonForeground, equalsARGB: 0xFFF8FAFC)
    assertColor(theme.disabledButtonBackground, equalsARGB: 0xFF17324A)
  }

  func testLingCalendarTitleMatchingIgnoresCaseAndWhitespace() {
    XCTAssertTrue(LingCalendarConfiguration.matchesTitle("Ling"))
    XCTAssertTrue(LingCalendarConfiguration.matchesTitle(" ling "))
    XCTAssertTrue(LingCalendarConfiguration.matchesTitle("LING"))
    XCTAssertFalse(LingCalendarConfiguration.matchesTitle("Ling Team"))
  }

  func testSupportsLingCalendarSourceTypeRejectsReadOnlySources() {
    XCTAssertTrue(LingCalendarConfiguration.supportsSourceType(.local))
    XCTAssertTrue(LingCalendarConfiguration.supportsSourceType(.calDAV))
    XCTAssertTrue(LingCalendarConfiguration.supportsSourceType(.exchange))
    XCTAssertTrue(LingCalendarConfiguration.supportsSourceType(.mobileMe))
    XCTAssertFalse(LingCalendarConfiguration.supportsSourceType(.subscribed))
    XCTAssertFalse(LingCalendarConfiguration.supportsSourceType(.birthdays))
  }

  func testPreferredLingCalendarSourceTypePrefersDefaultWritableSource() {
    XCTAssertEqual(
      LingCalendarConfiguration.preferredSourceType(
        defaultSourceType: .exchange,
        availableSourceTypes: [.local, .exchange]
      ),
      .exchange
    )
  }

  func testPreferredLingCalendarSourceTypeFallsBackToFirstWritableSource() {
    XCTAssertEqual(
      LingCalendarConfiguration.preferredSourceType(
        defaultSourceType: .subscribed,
        availableSourceTypes: [.birthdays, .calDAV, .local]
      ),
      .calDAV
    )
  }

  func testPreferredLingCalendarSourceTypeReturnsNilWhenNoWritableSourceExists() {
    XCTAssertNil(
      LingCalendarConfiguration.preferredSourceType(
        defaultSourceType: .subscribed,
        availableSourceTypes: [.birthdays, .subscribed]
      )
    )
  }

  func testAppleCalendarRecurrencePayloadSerializesStructuredRule() {
    let rule = EKRecurrenceRule(
      recurrenceWith: .weekly,
      interval: 2,
      daysOfTheWeek: [
        EKRecurrenceDayOfWeek(.monday),
        EKRecurrenceDayOfWeek(.friday)
      ],
      daysOfTheMonth: nil,
      monthsOfTheYear: nil,
      weeksOfTheYear: nil,
      daysOfTheYear: nil,
      setPositions: nil,
      end: EKRecurrenceEnd(occurrenceCount: 5)
    )

    let payload = AppleCalendarRecurrenceCodec.payload(from: rule)

    XCTAssertEqual(payload["frequency"] as? String, "weekly")
    XCTAssertEqual(payload["interval"] as? Int, 2)
    XCTAssertEqual(payload["count"] as? Int, 5)
    XCTAssertEqual(payload["by_weekday"] as? [String], ["MO", "FR"])
    XCTAssertEqual(
      payload["raw_rrule"] as? String,
      "FREQ=WEEKLY;INTERVAL=2;COUNT=5;BYDAY=MO,FR"
    )
  }

  func testAppleCalendarRecurrencePayloadParsesRawRRule() {
    let payload = AppleCalendarRecurrenceCodec.payload(
      from: "FREQ=MONTHLY;INTERVAL=3;COUNT=4;BYMONTHDAY=1,15;BYMONTH=4"
    )

    XCTAssertEqual(payload?["frequency"] as? String, "monthly")
    XCTAssertEqual(payload?["interval"] as? Int, 3)
    XCTAssertEqual(payload?["count"] as? Int, 4)
    XCTAssertEqual(payload?["by_month_day"] as? [Int], [1, 15])
    XCTAssertEqual(payload?["by_month"] as? [Int], [4])
  }

  func testAppleCalendarRecurrenceRuleBuildsFromStructuredPayload() throws {
    let rule = try XCTUnwrap(
      AppleCalendarRecurrenceCodec.recurrenceRule(
        from: [
          "frequency": "weekly",
          "interval": 2,
          "count": 6,
          "by_weekday": ["MO", "WE"]
        ]
      )
    )

    XCTAssertEqual(rule.frequency, .weekly)
    XCTAssertEqual(rule.interval, 2)
    XCTAssertEqual(rule.recurrenceEnd?.occurrenceCount, 6)
    XCTAssertEqual(rule.daysOfTheWeek?.map(\.dayOfTheWeek), [.monday, .wednesday])
  }

  func testAppleCalendarRecurrenceRuleBuildsFromRawRRuleFallback() throws {
    let rule = try XCTUnwrap(
      AppleCalendarRecurrenceCodec.recurrenceRule(
        from: [
          "raw_rrule": "FREQ=YEARLY;BYMONTH=7;BYMONTHDAY=9"
        ]
      )
    )

    XCTAssertEqual(rule.frequency, .yearly)
    XCTAssertEqual(rule.monthsOfTheYear?.map(\.intValue), [7])
    XCTAssertEqual(rule.daysOfTheMonth?.map(\.intValue), [9])
  }

  func testAppleCalendarRecurrenceRuleFillsMissingWeekdaysFromRawRRule() throws {
    let rule = try XCTUnwrap(
      AppleCalendarRecurrenceCodec.recurrenceRule(
        from: [
          "frequency": "weekly",
          "interval": 1,
          "raw_rrule": "FREQ=WEEKLY;BYDAY=MO,WE,FR"
        ]
      )
    )

    XCTAssertEqual(rule.frequency, .weekly)
    XCTAssertEqual(rule.interval, 1)
    XCTAssertEqual(rule.daysOfTheWeek?.map(\.dayOfTheWeek), [.monday, .wednesday, .friday])
  }

  func testAppleCalendarSpanParsesFutureEvents() {
    XCTAssertEqual(AppleCalendarRecurrenceCodec.span(from: "futureEvents"), .futureEvents)
    XCTAssertEqual(AppleCalendarRecurrenceCodec.span(from: "thisEvent"), .thisEvent)
    XCTAssertEqual(AppleCalendarRecurrenceCodec.span(from: nil), .thisEvent)
  }

  func testAppleCalendarEventIsRecurringIgnoresOccurrenceDateWithoutRules() {
    XCTAssertFalse(
      AppleCalendarRecurrenceCodec.eventIsRecurring(
        occurrenceDate: Date(),
        recurrenceRules: []
      )
    )
  }

  func testAppleCalendarEventIsRecurringReturnsTrueWhenRulesExist() {
    let rule = EKRecurrenceRule(
      recurrenceWith: .daily,
      interval: 1,
      end: nil
    )

    XCTAssertTrue(
      AppleCalendarRecurrenceCodec.eventIsRecurring(
        occurrenceDate: Date(),
        recurrenceRules: [rule]
      )
    )
  }

  func testAppleCalendarEventsMatchForSyncUsesSyncURLWhenAvailable() {
    let existing: [String: Any] = [
      "title": "Daily Standup",
      "startAt": "2026-04-05T09:00:00+08:00",
      "endAt": "2026-04-05T09:30:00+08:00",
      "url": "ling://calendar-event/evt_1",
      "notes": "",
      "location": ""
    ]
    let draft: [String: Any] = [
      "title": "Daily Standup",
      "startAt": "2026-04-05T09:00:00+08:00",
      "endAt": "2026-04-05T09:30:00+08:00",
      "syncUrl": "ling://calendar-event/evt_1"
    ]

    XCTAssertTrue(AppleCalendarSyncMatcher.eventsMatch(existing: existing, draft: draft))
    XCTAssertFalse(
      AppleCalendarSyncMatcher.eventsMatch(
        existing: existing,
        draft: draft.merging(["syncUrl": "ling://calendar-event/evt_2"]) { _, new in new }
      )
    )
  }

  func testAppleCalendarEventsMatchForSyncFallsBackWhenDraftOmitsURL() {
    let existing: [String: Any] = [
      "title": "Daily Standup",
      "startAt": "2026-04-05T09:00:00+08:00",
      "endAt": "2026-04-05T09:30:00+08:00",
      "url": "ling://calendar-event/evt_1",
      "notes": "",
      "location": ""
    ]
    let draft: [String: Any] = [
      "title": "Daily Standup",
      "startAt": "2026-04-05T09:00:00+08:00",
      "endAt": "2026-04-05T09:30:00+08:00",
      "url": ""
    ]

    XCTAssertTrue(AppleCalendarSyncMatcher.eventsMatch(existing: existing, draft: draft))
  }

  func testAppleCalendarEventsMatchForSyncFallsBackToDraftSignature() {
    let existing: [String: Any] = [
      "title": "Planning",
      "startAt": "2026-04-05T09:00:00+08:00",
      "endAt": "2026-04-05T10:00:00+08:00",
      "url": "",
      "notes": "Room A",
      "location": "HQ",
      "rawRRules": ["FREQ=WEEKLY;BYDAY=MO,WE"]
    ]
    let draft: [String: Any] = [
      "title": "Planning",
      "startAt": "2026-04-05T09:00:00+08:00",
      "endAt": "2026-04-05T10:00:00+08:00",
      "notes": "Room A",
      "location": "HQ",
      "recurrence": [
        "raw_rrules": ["FREQ=WEEKLY;BYDAY=MO,WE"]
      ]
    ]

    XCTAssertTrue(AppleCalendarSyncMatcher.eventsMatch(existing: existing, draft: draft))
    XCTAssertFalse(
      AppleCalendarSyncMatcher.eventsMatch(
        existing: existing,
        draft: draft.merging(["location": "Remote"]) { _, new in new }
      )
    )
  }

  func testAppleCalendarEventDatePreservesWallClockForOffsetTimestamp() throws {
    let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
    let date = try XCTUnwrap(
      AppleCalendarDateParser.eventDate("2026-04-17T08:00:00+08:00", timeZone: timeZone)
    )
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

    XCTAssertEqual(components.year, 2026)
    XCTAssertEqual(components.month, 4)
    XCTAssertEqual(components.day, 17)
    XCTAssertEqual(components.hour, 8)
    XCTAssertEqual(components.minute, 0)
  }

  func testAppleCalendarEventDateNormalizesEquivalentUtcTimestampToWallClock() throws {
    let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
    let date = try XCTUnwrap(
      AppleCalendarDateParser.eventDate("2026-04-17T00:00:00Z", timeZone: timeZone)
    )
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

    XCTAssertEqual(components.year, 2026)
    XCTAssertEqual(components.month, 4)
    XCTAssertEqual(components.day, 17)
    XCTAssertEqual(components.hour, 8)
    XCTAssertEqual(components.minute, 0)
  }

  func testLingCalendarNotificationMatchesPrefixWithoutKind() {
    XCTAssertTrue(
      isLingCalendarNotification(
        identifier: "ling.calendar.event-1",
        kind: ""
      )
    )
    XCTAssertFalse(
      isLingCalendarNotification(
        identifier: "ling.agent.completion.1",
        kind: "agent_completion"
      )
    )
  }

  func testForegroundScheduleNotificationIsSuppressed() {
    XCTAssertFalse(
      shouldPresentLingForegroundNotification(
        identifier: "ling.calendar.event-1",
        kind: "",
        foregroundNotificationContext: "chat"
      )
    )
    XCTAssertFalse(
      shouldPresentLingForegroundNotification(
        identifier: "custom-id",
        kind: "app_notification",
        foregroundNotificationContext: "other"
      )
    )
  }

  func testForegroundAgentCompletionIsSuppressed() {
    XCTAssertFalse(
      shouldPresentLingForegroundNotification(
        identifier: "ling.agent.completion.1",
        kind: "agent_completion",
        foregroundNotificationContext: "chat"
      )
    )
    XCTAssertFalse(
      shouldPresentLingForegroundNotification(
        identifier: "ling.agent.completion.1",
        kind: "agent_completion",
        foregroundNotificationContext: "other"
      )
    )
  }

  func testForegroundRemoteNotificationEventStillEmitsWhenPresentationIsSuppressed() {
    XCTAssertFalse(
      shouldPresentLingForegroundNotification(
        identifier: "custom-id",
        kind: "app_notification",
        foregroundNotificationContext: "chat"
      )
    )
    XCTAssertTrue(
      shouldEmitLingForegroundNotificationEvent(
        identifier: "custom-id",
        kind: "app_notification"
      )
    )
    XCTAssertTrue(
      shouldEmitLingForegroundNotificationEvent(
        identifier: "ling.agent.completion.1",
        kind: "agent_completion"
      )
    )
    XCTAssertFalse(
      shouldEmitLingForegroundNotificationEvent(
        identifier: "custom-id",
        kind: "other"
      )
    )
  }

  func testLingNormalizedAPNsEnvironmentFallsBackToUnknown() {
    XCTAssertEqual(lingNormalizedAPNsEnvironment(nil), "unknown")
    XCTAssertEqual(lingNormalizedAPNsEnvironment(""), "unknown")
    XCTAssertEqual(lingNormalizedAPNsEnvironment(" production "), "production")
  }

  func testLingPushTokenPrefixRedactsToken() {
    XCTAssertEqual(lingPushTokenPrefix("abcdef1234567890"), "abcdef123456")
    XCTAssertEqual(lingPushTokenPrefix("  xyz  "), "xyz")
    XCTAssertEqual(lingPushTokenPrefix(""), "empty")
  }

  func testBackgroundScheduleNotificationAndAgentCompletionStillPresent() {
    XCTAssertTrue(
      shouldPresentLingForegroundNotification(
        identifier: "ling.calendar.event-1",
        kind: "app_notification",
        foregroundNotificationContext: "background"
      )
    )
    XCTAssertTrue(
      shouldPresentLingForegroundNotification(
        identifier: "ling.agent.completion.1",
        kind: "agent_completion",
        foregroundNotificationContext: "background"
      )
    )
  }

  private func assertColor(
    _ color: UIColor,
    equalsARGB expectedARGB: UInt32,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0

    XCTAssertTrue(
      color.getRed(&red, green: &green, blue: &blue, alpha: &alpha),
      file: file,
      line: line
    )
    XCTAssertEqual(
      Int((alpha * 255).rounded()),
      Int((expectedARGB >> 24) & 0xFF),
      file: file,
      line: line
    )
    XCTAssertEqual(
      Int((red * 255).rounded()),
      Int((expectedARGB >> 16) & 0xFF),
      file: file,
      line: line
    )
    XCTAssertEqual(
      Int((green * 255).rounded()),
      Int((expectedARGB >> 8) & 0xFF),
      file: file,
      line: line
    )
    XCTAssertEqual(
      Int((blue * 255).rounded()),
      Int(expectedARGB & 0xFF),
      file: file,
      line: line
    )
  }
}
