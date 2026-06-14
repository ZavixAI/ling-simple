import EventKit
import Foundation

enum AppleCalendarRecurrenceCodec {
  private static let rruleUtcFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
    return formatter
  }()

  private static let rruleDateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd"
    return formatter
  }()

  private static let lingWeekdaysByEventKitWeekday: [EKWeekday: String] = [
    .sunday: "SU",
    .monday: "MO",
    .tuesday: "TU",
    .wednesday: "WE",
    .thursday: "TH",
    .friday: "FR",
    .saturday: "SA"
  ]

  private static let eventKitWeekdaysByLingWeekday: [String: EKWeekday] = [
    "SU": .sunday,
    "MO": .monday,
    "TU": .tuesday,
    "WE": .wednesday,
    "TH": .thursday,
    "FR": .friday,
    "SA": .saturday
  ]

  static func span(from raw: Any?) -> EKSpan {
    guard let normalized = (raw as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    else {
      return .thisEvent
    }
    switch normalized {
    case "futureevents", "future_events", "series":
      return .futureEvents
    default:
      return .thisEvent
    }
  }

  static func eventIsRecurring(
    occurrenceDate: Date?,
    recurrenceRules: [EKRecurrenceRule]
  ) -> Bool {
    _ = occurrenceDate
    return !recurrenceRules.isEmpty
  }

  static func rawRRuleString(from rule: EKRecurrenceRule) -> String {
    var components = ["FREQ=\(frequencyName(rule.frequency).uppercased())"]
    if rule.interval > 1 {
      components.append("INTERVAL=\(rule.interval)")
    }
    if let end = rule.recurrenceEnd {
      if end.occurrenceCount > 0 {
        components.append("COUNT=\(end.occurrenceCount)")
      } else if let endDate = end.endDate {
        components.append("UNTIL=\(rruleUtcFormatter.string(from: endDate))")
      }
    }
    let weekdays = (rule.daysOfTheWeek ?? []).compactMap {
      lingWeekdaysByEventKitWeekday[$0.dayOfTheWeek]
    }
    if !weekdays.isEmpty {
      components.append("BYDAY=\(weekdays.joined(separator: ","))")
    }
    if let monthDays = rule.daysOfTheMonth, !monthDays.isEmpty {
      components.append(
        "BYMONTHDAY=\(monthDays.map(\.stringValue).joined(separator: ","))"
      )
    }
    if let months = rule.monthsOfTheYear, !months.isEmpty {
      components.append("BYMONTH=\(months.map(\.stringValue).joined(separator: ","))")
    }
    return components.joined(separator: ";")
  }

  static func payload(from rawRRule: String) -> [String: Any]? {
    let trimmed = rawRRule.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return nil
    }
    var components: [String: String] = [:]
    for segment in trimmed.split(separator: ";") {
      let parts = segment.split(separator: "=", maxSplits: 1).map(String.init)
      guard parts.count == 2 else {
        continue
      }
      components[parts[0].uppercased()] = parts[1]
    }
    guard let frequencyRaw = components["FREQ"]?.lowercased(), !frequencyRaw.isEmpty else {
      return nil
    }
    var payload: [String: Any] = [
      "frequency": frequencyRaw,
      "raw_rrule": trimmed
    ]
    if let intervalRaw = components["INTERVAL"], let interval = Int(intervalRaw), interval > 0 {
      payload["interval"] = interval
    }
    if let countRaw = components["COUNT"], let count = Int(countRaw), count > 0 {
      payload["count"] = count
    }
    if let untilRaw = components["UNTIL"], let untilDate = parseRRuleDate(untilRaw) {
      payload["until"] = AppleCalendarDateParser.iso8601String(untilDate)
    }
    if let byDayRaw = components["BYDAY"] {
      let weekdays = byDayRaw
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
        .filter { !$0.isEmpty }
      if !weekdays.isEmpty {
        payload["by_weekday"] = weekdays
      }
    }
    if let monthDaysRaw = components["BYMONTHDAY"] {
      let days = monthDaysRaw
        .split(separator: ",")
        .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
      if !days.isEmpty {
        payload["by_month_day"] = days
      }
    }
    if let monthsRaw = components["BYMONTH"] {
      let months = monthsRaw
        .split(separator: ",")
        .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
      if !months.isEmpty {
        payload["by_month"] = months
      }
    }
    return payload
  }

  static func payload(from rule: EKRecurrenceRule) -> [String: Any] {
    var payload: [String: Any] = [
      "frequency": frequencyName(rule.frequency),
      "interval": max(1, rule.interval),
      "raw_rrule": rawRRuleString(from: rule)
    ]
    if let end = rule.recurrenceEnd {
      if end.occurrenceCount > 0 {
        payload["count"] = end.occurrenceCount
      } else if let endDate = end.endDate {
        payload["until"] = AppleCalendarDateParser.iso8601String(endDate)
      }
    }
    let weekdays = (rule.daysOfTheWeek ?? []).compactMap {
      lingWeekdaysByEventKitWeekday[$0.dayOfTheWeek]
    }
    if !weekdays.isEmpty {
      payload["by_weekday"] = weekdays
    }
    if let monthDays = rule.daysOfTheMonth, !monthDays.isEmpty {
      payload["by_month_day"] = monthDays.map(\.intValue)
    }
    if let months = rule.monthsOfTheYear, !months.isEmpty {
      payload["by_month"] = months.map(\.intValue)
    }
    return payload
  }

  static func recurrenceRule(from raw: Any?) throws -> EKRecurrenceRule? {
    if raw == nil || raw is NSNull {
      return nil
    }
    guard let rawRecurrence = raw as? [String: Any] else {
      throw NSError(domain: "AppleCalendarRecurrenceCodec", code: 5, userInfo: [
        NSLocalizedDescriptionKey: "recurrence must be an object"
      ])
    }

    var recurrence = rawRecurrence
    let rawRRule = (recurrence["raw_rrule"] as? String) ??
      (recurrence["rawRrule"] as? String) ??
      ((recurrence["raw_rrules"] as? [Any])?.compactMap { $0 as? String }.first) ??
      ((recurrence["rawRRules"] as? [Any])?.compactMap { $0 as? String }.first)
    if let rawRRule, let parsed = payload(from: rawRRule) {
      for (key, value) in parsed where recurrence[key] == nil {
        recurrence[key] = value
      }
    }

    guard
      let frequencyRaw = (recurrence["frequency"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased(),
      let frequency = frequency(from: frequencyRaw)
    else {
      throw NSError(domain: "AppleCalendarRecurrenceCodec", code: 6, userInfo: [
        NSLocalizedDescriptionKey: "recurrence.frequency is required"
      ])
    }

    let interval = max(1, integer(from: recurrence["interval"]) ?? 1)
    let count = integer(from: recurrence["count"])
    let untilDate = AppleCalendarDateParser.parseFlexibleDate(recurrence["until"])

    let weekdays = stringArray(from: recurrence["by_weekday"] ?? recurrence["byWeekday"])
      .compactMap { eventKitWeekdaysByLingWeekday[$0.uppercased()] }
      .map { EKRecurrenceDayOfWeek($0) }
    let monthDays = integerArray(from: recurrence["by_month_day"] ?? recurrence["byMonthDay"])
      .map(NSNumber.init(value:))
    let months = integerArray(from: recurrence["by_month"] ?? recurrence["byMonth"])
      .map(NSNumber.init(value:))

    let recurrenceEnd: EKRecurrenceEnd?
    if let count, count > 0 {
      recurrenceEnd = EKRecurrenceEnd(occurrenceCount: count)
    } else if let untilDate {
      recurrenceEnd = EKRecurrenceEnd(end: untilDate)
    } else {
      recurrenceEnd = nil
    }

    return EKRecurrenceRule(
      recurrenceWith: frequency,
      interval: interval,
      daysOfTheWeek: weekdays.isEmpty ? nil : weekdays,
      daysOfTheMonth: monthDays.isEmpty ? nil : monthDays,
      monthsOfTheYear: months.isEmpty ? nil : months,
      weeksOfTheYear: nil,
      daysOfTheYear: nil,
      setPositions: nil,
      end: recurrenceEnd
    )
  }

  static func normalizedSignature(from raw: Any?) -> String? {
    if let value = raw as? String {
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
      return trimmed.isEmpty ? nil : trimmed
    }
    if let values = raw as? [Any] {
      let normalized = values.compactMap(normalizedSignature(from:))
      return normalized.isEmpty ? nil : normalized.joined(separator: "|")
    }
    guard let recurrence = raw as? [String: Any] else {
      return nil
    }

    if let rawRRule = normalizedSignature(
      from: recurrence["raw_rrule"] ?? recurrence["rawRrule"]
    ) {
      return rawRRule
    }
    if let rawRRules = normalizedSignature(
      from: recurrence["raw_rrules"] ?? recurrence["rawRRules"]
    ) {
      return rawRRules
    }

    guard
      let frequency = (recurrence["frequency"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased(),
      !frequency.isEmpty
    else {
      return nil
    }

    var parts = ["FREQ=\(frequency.uppercased())"]
    let interval = max(1, integer(from: recurrence["interval"]) ?? 1)
    if interval > 1 {
      parts.append("INTERVAL=\(interval)")
    }
    if let count = integer(from: recurrence["count"]), count > 0 {
      parts.append("COUNT=\(count)")
    } else if let until = AppleCalendarDateParser.parseFlexibleDate(recurrence["until"]) {
      parts.append("UNTIL=\(rruleUtcFormatter.string(from: until))")
    }

    let byWeekday = stringArray(
      from: recurrence["by_weekday"] ?? recurrence["byWeekday"]
    )
      .map { $0.uppercased() }
      .sorted()
    if !byWeekday.isEmpty {
      parts.append("BYDAY=\(byWeekday.joined(separator: ","))")
    }

    let byMonthDay = integerArray(
      from: recurrence["by_month_day"] ?? recurrence["byMonthDay"]
    ).sorted()
    if !byMonthDay.isEmpty {
      parts.append("BYMONTHDAY=\(byMonthDay.map(String.init).joined(separator: ","))")
    }

    let byMonth = integerArray(
      from: recurrence["by_month"] ?? recurrence["byMonth"]
    ).sorted()
    if !byMonth.isEmpty {
      parts.append("BYMONTH=\(byMonth.map(String.init).joined(separator: ","))")
    }

    return parts.joined(separator: ";")
  }

  private static func parseRRuleDate(_ raw: String) -> Date? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return nil
    }
    if let date = rruleUtcFormatter.date(from: trimmed) {
      return date
    }
    if let date = rruleDateOnlyFormatter.date(from: trimmed) {
      return date
    }
    return AppleCalendarDateParser.parseFlexibleDate(trimmed)
  }

  private static func frequencyName(_ frequency: EKRecurrenceFrequency) -> String {
    switch frequency {
    case .daily:
      return "daily"
    case .weekly:
      return "weekly"
    case .monthly:
      return "monthly"
    case .yearly:
      return "yearly"
    @unknown default:
      return "daily"
    }
  }

  private static func frequency(from raw: String) -> EKRecurrenceFrequency? {
    switch raw {
    case "daily":
      return .daily
    case "weekly":
      return .weekly
    case "monthly":
      return .monthly
    case "yearly":
      return .yearly
    default:
      return nil
    }
  }

  private static func integer(from raw: Any?) -> Int? {
    switch raw {
    case let number as NSNumber:
      return number.intValue
    case let string as String:
      return Int(string)
    default:
      return nil
    }
  }

  private static func stringArray(from raw: Any?) -> [String] {
    guard let items = raw as? [Any] else {
      return []
    }
    return items.compactMap { item in
      let value = "\(item)".trimmingCharacters(in: .whitespacesAndNewlines)
      return value.isEmpty ? nil : value
    }
  }

  private static func integerArray(from raw: Any?) -> [Int] {
    guard let items = raw as? [Any] else {
      return []
    }
    return items.compactMap(integer(from:))
  }
}
