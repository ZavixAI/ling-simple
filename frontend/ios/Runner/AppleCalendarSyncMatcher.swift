import Foundation

enum AppleCalendarSyncMatcher {
  static func eventsMatch(existing: [String: Any], draft: [String: Any]) -> Bool {
    let existingURL = AppleCalendarDateParser.normalizedURLString(existing["url"])
    let draftURL = AppleCalendarDateParser.normalizedURLString(draft["syncUrl"] ?? draft["url"])
    if let draftURL {
      if let existingURL {
        return draftURL == existingURL
      }
    }

    guard
      let existingTitle = existing["title"] as? String,
      let draftTitle = draft["title"] as? String,
      let existingStart = AppleCalendarDateParser.parseFlexibleDate(existing["startAt"]),
      let draftStart = AppleCalendarDateParser.parseFlexibleDate(draft["startAt"]),
      let existingEnd = AppleCalendarDateParser.parseFlexibleDate(existing["endAt"]),
      let draftEnd = AppleCalendarDateParser.parseFlexibleDate(draft["endAt"])
    else {
      return false
    }

    let normalizedExistingTitle = existingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedDraftTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalizedExistingTitle != normalizedDraftTitle {
      return false
    }
    if abs(existingStart.timeIntervalSince(draftStart)) >= 1 {
      return false
    }
    if abs(existingEnd.timeIntervalSince(draftEnd)) >= 1 {
      return false
    }

    let existingNotes = (existing["notes"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let draftNotes = (draft["notes"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if existingNotes != draftNotes {
      return false
    }

    let existingLocation = (existing["location"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let draftLocation = (draft["location"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if existingLocation != draftLocation {
      return false
    }

    let existingRecurrence = AppleCalendarRecurrenceCodec.normalizedSignature(
      from: existing["rawRRules"] ?? existing["recurrence"]
    )
    let draftRecurrence = AppleCalendarRecurrenceCodec.normalizedSignature(from: draft["recurrence"])
    return existingRecurrence == draftRecurrence
  }
}
