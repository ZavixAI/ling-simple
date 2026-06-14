import EventKit
import Foundation

enum LingCalendarConfiguration {
  static let title = "Ling"

  static func matchesTitle(_ value: String) -> Bool {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
      .compare(
        title,
        options: [.caseInsensitive, .diacriticInsensitive]
      ) == .orderedSame
  }

  static func supportsSourceType(_ sourceType: EKSourceType) -> Bool {
    switch sourceType {
    case .local, .calDAV, .exchange, .mobileMe:
      return true
    case .subscribed, .birthdays:
      return false
    @unknown default:
      return false
    }
  }

  static func preferredSourceType(
    defaultSourceType: EKSourceType?,
    availableSourceTypes: [EKSourceType]
  ) -> EKSourceType? {
    if let defaultSourceType, supportsSourceType(defaultSourceType) {
      return defaultSourceType
    }
    return availableSourceTypes.first(where: supportsSourceType)
  }
}
