import Foundation

enum AppleCalendarDateParser {
  private static let iso8601FormatterWithFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  private static let localDateFormatters: [DateFormatter] = {
    let formats = [
      "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
      "yyyy-MM-dd'T'HH:mm:ss.SSS",
      "yyyy-MM-dd'T'HH:mm:ss",
      "yyyy-MM-dd"
    ]
    return formats.map { format in
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone.current
      formatter.dateFormat = format
      return formatter
    }
  }()

  static func parseFlexibleDate(_ value: Any?) -> Date? {
    guard let raw = value as? String else {
      return nil
    }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return nil
    }
    if let date = iso8601FormatterWithFractionalSeconds.date(from: trimmed) {
      return date
    }
    if let date = iso8601Formatter.date(from: trimmed) {
      return date
    }
    for formatter in localDateFormatters {
      if let date = formatter.date(from: trimmed) {
        return date
      }
    }
    return nil
  }

  static func eventDate(_ value: Any?, timeZone: TimeZone?) -> Date? {
    guard let absoluteDate = parseFlexibleDate(value) else {
      return nil
    }
    guard let timeZone else {
      return absoluteDate
    }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second, .nanosecond],
      from: absoluteDate
    )
    return calendar.date(from: components)
  }

  static func iso8601String(_ date: Date) -> String {
    iso8601FormatterWithFractionalSeconds.string(from: date)
  }

  static func normalizedURLString(_ value: Any?) -> String? {
    guard let raw = value as? String else {
      return nil
    }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return nil
    }
    return URL(string: trimmed)?.absoluteString ?? trimmed
  }
}
