import EventKit
import Foundation

struct AppleCalendarEventMutationResult {
  let eventIdentifier: String
  let calendarIdentifier: String
  let calendarItemIdentifier: String

  var payload: [String: Any] {
    [
      "eventIdentifier": eventIdentifier,
      "calendarIdentifier": calendarIdentifier,
      "calendarItemIdentifier": calendarItemIdentifier
    ]
  }
}

final class AppleCalendarStore {
  private let eventStore: EKEventStore

  init(eventStore: EKEventStore = EKEventStore()) {
    self.eventStore = eventStore
  }

  func permissionStateRaw() -> String {
    if #available(iOS 17.0, *) {
      switch EKEventStore.authorizationStatus(for: .event) {
      case .fullAccess, .writeOnly:
        return "granted"
      case .notDetermined:
        return "not_determined"
      case .denied, .restricted:
        return "denied"
      @unknown default:
        return "denied"
      }
    } else {
      switch EKEventStore.authorizationStatus(for: .event) {
      case .authorized, .fullAccess, .writeOnly:
        return "granted"
      case .notDetermined:
        return "not_determined"
      case .denied, .restricted:
        return "denied"
      @unknown default:
        return "denied"
      }
    }
  }

  func requestPermission(completion: @escaping (Result<String, Error>) -> Void) {
    if #available(iOS 17.0, *) {
      eventStore.requestFullAccessToEvents { [weak self] granted, error in
        if let error {
          completion(.failure(error))
          return
        }
        completion(.success(granted ? "granted" : self?.permissionStateRaw() ?? "denied"))
      }
    } else {
      eventStore.requestAccess(to: .event) { [weak self] granted, error in
        if let error {
          completion(.failure(error))
          return
        }
        completion(.success(granted ? "granted" : self?.permissionStateRaw() ?? "denied"))
      }
    }
  }

  func listCalendars() -> [[String: Any]] {
    let defaultCalendarId = eventStore.defaultCalendarForNewEvents?.calendarIdentifier
    return eventStore.calendars(for: .event).map { calendar in
      [
        "identifier": calendar.calendarIdentifier,
        "title": calendar.title,
        "isDefault": calendar.calendarIdentifier == defaultCalendarId
      ]
    }
  }

  func listEvents(startAt: Date, endAt: Date) -> [[String: Any]] {
    let predicate = eventStore.predicateForEvents(withStart: startAt, end: endAt, calendars: nil)
    return eventStore.events(matching: predicate)
      .sorted(by: { $0.startDate < $1.startDate })
      .map(serializeEvent)
  }

  func createEvent(args: [String: Any]) throws -> AppleCalendarEventMutationResult {
    let event = findExistingEventForCreate(args: args) ?? EKEvent(eventStore: eventStore)
    try applyDraft(args, to: event)
    try eventStore.save(event, span: .thisEvent, commit: true)
    return mutationResult(for: event)
  }

  func updateEvent(args: [String: Any]) throws -> AppleCalendarEventMutationResult {
    guard let event = resolveEvent(from: args) else {
      throw AppleCalendarStoreError.notFound
    }
    try applyDraft(args, to: event)
    try eventStore.save(event, span: resolvedSpan(for: event, args: args), commit: true)
    return mutationResult(for: event)
  }

  func deleteEvent(args: [String: Any]) throws {
    guard let event = resolveEvent(from: args) else {
      return
    }
    try eventStore.remove(event, span: resolvedSpan(for: event, args: args), commit: true)
  }

  func deleteManagedEvents(items: [[String: Any]]) throws {
    var errors: [String] = []
    for item in items {
      guard let event = resolveEvent(from: item) else {
        continue
      }
      let span: EKSpan = (item["span"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased() == "futureevents"
        ? .futureEvents
        : resolvedSpan(for: event, args: item)
      do {
        try eventStore.remove(event, span: span, commit: true)
      } catch {
        errors.append(error.localizedDescription)
      }
    }

    if !errors.isEmpty {
      throw AppleCalendarStoreError.deleteManagedFailed(errors: errors)
    }
  }

  private func mutationResult(for event: EKEvent) -> AppleCalendarEventMutationResult {
    AppleCalendarEventMutationResult(
      eventIdentifier: event.eventIdentifier ?? "",
      calendarIdentifier: event.calendar.calendarIdentifier,
      calendarItemIdentifier: event.calendarItemIdentifier
    )
  }

  private func applyDraft(_ args: [String: Any], to event: EKEvent) throws {
    let eventTimeZone = try parseTimeZone(args["timezone"])
    guard
      let title = args["title"] as? String,
      let startAt = AppleCalendarDateParser.eventDate(args["startAt"], timeZone: eventTimeZone),
      let endAt = AppleCalendarDateParser.eventDate(args["endAt"], timeZone: eventTimeZone)
    else {
      throw AppleCalendarStoreError.invalidDraft(message: "title, startAt and endAt are required")
    }

    if
      let calendarIdentifier = normalizedOptionalString(args["calendarIdentifier"]),
      let calendar = eventStore.calendars(for: .event).first(where: { $0.calendarIdentifier == calendarIdentifier })
    {
      event.calendar = calendar
    }
    if event.calendar == nil {
      event.calendar = resolveLingCalendarForSync()
    }

    event.title = title
    event.startDate = startAt
    event.endDate = endAt
    event.url = AppleCalendarDateParser.normalizedURLString(args["syncUrl"] ?? args["url"])
      .flatMap(URL.init(string:))
    event.notes = normalizedOptionalString(args["notes"])
    event.location = normalizedOptionalString(args["location"])
    if args.keys.contains("timezone") {
      event.timeZone = eventTimeZone
    }
    if args.keys.contains("alarms") {
      event.alarms = try parseAlarms(args["alarms"])
    }
    if args.keys.contains("recurrence") {
      if let rule = try AppleCalendarRecurrenceCodec.recurrenceRule(from: args["recurrence"]) {
        event.recurrenceRules = [rule]
      } else {
        event.recurrenceRules = nil
      }
    }
  }

  private func resolveLingCalendarForSync() -> EKCalendar? {
    if
      let defaultCalendar = eventStore.defaultCalendarForNewEvents,
      defaultCalendar.allowsContentModifications,
      LingCalendarConfiguration.matchesTitle(defaultCalendar.title)
    {
      return defaultCalendar
    }

    if let existingCalendar = eventStore.calendars(for: .event).first(where: {
      $0.allowsContentModifications && LingCalendarConfiguration.matchesTitle($0.title)
    }) {
      return existingCalendar
    }

    if let createdCalendar = createLingCalendar() {
      return createdCalendar
    }

    return eventStore.defaultCalendarForNewEvents
  }

  private func existingLingCalendarForSync() -> EKCalendar? {
    if
      let defaultCalendar = eventStore.defaultCalendarForNewEvents,
      defaultCalendar.allowsContentModifications,
      LingCalendarConfiguration.matchesTitle(defaultCalendar.title)
    {
      return defaultCalendar
    }

    return eventStore.calendars(for: .event).first(where: {
      $0.allowsContentModifications && LingCalendarConfiguration.matchesTitle($0.title)
    })
  }

  private func candidateCalendarForDraft(_ args: [String: Any]) -> EKCalendar? {
    if
      let calendarIdentifier = normalizedOptionalString(args["calendarIdentifier"]),
      let calendar = eventStore.calendars(for: .event).first(where: {
        $0.calendarIdentifier == calendarIdentifier
      })
    {
      return calendar
    }
    return existingLingCalendarForSync() ?? eventStore.defaultCalendarForNewEvents
  }

  private func canonicalEventForSync(_ event: EKEvent) -> EKEvent {
    guard
      let itemIdentifier = normalizedOptionalString(event.calendarItemIdentifier),
      let canonical = eventStore.calendarItem(withIdentifier: itemIdentifier) as? EKEvent
    else {
      return event
    }
    return canonical
  }

  private func findExistingEventForCreate(args: [String: Any]) -> EKEvent? {
    guard
      let startAt = AppleCalendarDateParser.parseFlexibleDate(args["startAt"]),
      let endAt = AppleCalendarDateParser.parseFlexibleDate(args["endAt"])
    else {
      return nil
    }

    let windowStart = startAt.addingTimeInterval(-24 * 60 * 60)
    let windowEnd = endAt.addingTimeInterval(24 * 60 * 60)
    let calendars = candidateCalendarForDraft(args).map { [$0] }
    let predicate = eventStore.predicateForEvents(
      withStart: windowStart,
      end: windowEnd,
      calendars: calendars
    )
    let matched = eventStore.events(matching: predicate)
      .filter { AppleCalendarSyncMatcher.eventsMatch(existing: serializeEvent($0), draft: args) }
      .sorted { lhs, rhs in
        let lhsDelta = abs(lhs.startDate.timeIntervalSince(startAt))
        let rhsDelta = abs(rhs.startDate.timeIntervalSince(startAt))
        return lhsDelta < rhsDelta
      }
    guard let event = matched.first else {
      return nil
    }
    return canonicalEventForSync(event)
  }

  private func createLingCalendar() -> EKCalendar? {
    guard let source = preferredLingCalendarSource() else {
      return nil
    }

    let calendar = EKCalendar(for: .event, eventStore: eventStore)
    calendar.title = LingCalendarConfiguration.title
    calendar.source = source

    do {
      try eventStore.saveCalendar(calendar, commit: true)
      return calendar
    } catch {
      return nil
    }
  }

  private func preferredLingCalendarSource() -> EKSource? {
    let sources = eventStore.sources
    let preferredSourceType = LingCalendarConfiguration.preferredSourceType(
      defaultSourceType: eventStore.defaultCalendarForNewEvents?.source.sourceType,
      availableSourceTypes: sources.map(\.sourceType)
    )
    guard let preferredSourceType else {
      return nil
    }
    return sources.first(where: { $0.sourceType == preferredSourceType })
  }

  private func normalizedOptionalString(_ value: Any?) -> String? {
    guard let raw = value as? String else {
      return nil
    }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return nil
    }
    return trimmed
  }

  private func parseTimeZone(_ value: Any?) throws -> TimeZone? {
    guard let raw = normalizedOptionalString(value) else {
      return nil
    }
    guard let timeZone = TimeZone(identifier: raw) else {
      throw AppleCalendarStoreError.invalidDraft(message: "timezone is invalid")
    }
    return timeZone
  }

  private func parseAlarms(_ value: Any?) throws -> [EKAlarm]? {
    guard let rawAlarms = value as? [Any] else {
      if value == nil {
        return nil
      }
      throw AppleCalendarStoreError.invalidDraft(message: "alarms must be an array")
    }
    var seenOffsets = Set<Double>()
    var alarms: [EKAlarm] = []
    for rawAlarm in rawAlarms {
      guard
        let alarm = rawAlarm as? [String: Any],
        let relativeOffset = parseDouble(alarm["relativeOffsetSeconds"])
      else {
        throw AppleCalendarStoreError.invalidDraft(
          message: "relativeOffsetSeconds is required for alarms"
        )
      }
      if seenOffsets.insert(relativeOffset).inserted {
        alarms.append(EKAlarm(relativeOffset: relativeOffset))
      }
    }
    alarms.sort { $0.relativeOffset < $1.relativeOffset }
    return alarms.isEmpty ? nil : alarms
  }

  private func parseDouble(_ value: Any?) -> Double? {
    switch value {
    case let number as NSNumber:
      number.doubleValue
    case let raw as String:
      Double(raw)
    default:
      nil
    }
  }

  private func serializeEvent(_ event: EKEvent) -> [String: Any] {
    let recurrenceRules = recurrenceRules(for: event)
    let rawRRules = recurrenceRules.map(AppleCalendarRecurrenceCodec.rawRRuleString(from:))
    var payload: [String: Any] = [
      "identifier": event.eventIdentifier ?? "",
      "calendarIdentifier": event.calendar.calendarIdentifier,
      "calendarItemIdentifier": event.calendarItemIdentifier,
      "calendarTitle": event.calendar.title,
      "title": event.title ?? "",
      "startAt": AppleCalendarDateParser.iso8601String(event.startDate),
      "endAt": AppleCalendarDateParser.iso8601String(event.endDate),
      "timezone": event.timeZone?.identifier ?? TimeZone.current.identifier,
      "url": event.url?.absoluteString ?? "",
      "notes": event.notes ?? "",
      "location": event.location ?? "",
      "isAllDay": event.isAllDay,
      "kind": classifyEventKind(for: event),
      "isDetached": event.isDetached,
      "isRecurring": AppleCalendarRecurrenceCodec.eventIsRecurring(
        occurrenceDate: event.occurrenceDate,
        recurrenceRules: recurrenceRules
      ),
      "rawRRules": rawRRules
    ]
    if let occurrenceDate = event.occurrenceDate {
      payload["occurrenceDate"] = AppleCalendarDateParser.iso8601String(occurrenceDate)
    }
    if let recurrenceRule = recurrenceRules.first {
      payload["recurrence"] = AppleCalendarRecurrenceCodec.payload(from: recurrenceRule)
    }
    return payload
  }

  private func recurrenceRules(for event: EKEvent) -> [EKRecurrenceRule] {
    if let rules = event.recurrenceRules, !rules.isEmpty {
      return rules
    }
    guard
      let item = eventStore.calendarItem(withIdentifier: event.calendarItemIdentifier) as? EKEvent,
      let rules = item.recurrenceRules
    else {
      return []
    }
    return rules
  }

  private func resolveEvent(from args: [String: Any]) -> EKEvent? {
    let calendarItemIdentifier = normalizedOptionalString(args["calendarItemIdentifier"])
    let occurrenceDate = AppleCalendarDateParser.parseFlexibleDate(args["occurrenceDate"])
    if
      let calendarItemIdentifier,
      let occurrenceDate,
      let occurrenceEvent = resolveOccurrenceEvent(
        calendarItemIdentifier: calendarItemIdentifier,
        occurrenceDate: occurrenceDate
      )
    {
      return occurrenceEvent
    }
    if
      let identifier = normalizedOptionalString(args["eventIdentifier"]),
      let event = eventStore.event(withIdentifier: identifier)
    {
      return event
    }
    if
      let calendarItemIdentifier,
      let event = eventStore.calendarItem(withIdentifier: calendarItemIdentifier) as? EKEvent
    {
      return event
    }
    return nil
  }

  private func resolveOccurrenceEvent(
    calendarItemIdentifier: String,
    occurrenceDate: Date
  ) -> EKEvent? {
    let windowStart = occurrenceDate.addingTimeInterval(-48 * 60 * 60)
    let windowEnd = occurrenceDate.addingTimeInterval(48 * 60 * 60)
    let predicate = eventStore.predicateForEvents(
      withStart: windowStart,
      end: windowEnd,
      calendars: nil
    )
    let matchedEvents = eventStore.events(matching: predicate)
      .filter { event in
        event.calendarItemIdentifier == calendarItemIdentifier &&
          abs((event.occurrenceDate ?? event.startDate).timeIntervalSince(occurrenceDate)) < 60
      }
      .sorted { lhs, rhs in
        let lhsDelta = abs((lhs.occurrenceDate ?? lhs.startDate).timeIntervalSince(occurrenceDate))
        let rhsDelta = abs((rhs.occurrenceDate ?? rhs.startDate).timeIntervalSince(occurrenceDate))
        return lhsDelta < rhsDelta
      }
    return matchedEvents.first
  }

  private func resolvedSpan(for event: EKEvent, args: [String: Any]) -> EKSpan {
    let requested = AppleCalendarRecurrenceCodec.span(from: args["span"])
    if requested == .futureEvents, !(event.hasRecurrenceRules || event.occurrenceDate != nil) {
      return .thisEvent
    }
    return requested
  }

  private func classifyEventKind(for event: EKEvent) -> String {
    if looksLikeHoliday(event.calendar.title) || looksLikeHoliday(event.title ?? "") {
      return "holiday"
    }
    return "event"
  }

  private func looksLikeHoliday(_ value: String) -> Bool {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalized.isEmpty {
      return false
    }
    return normalized.contains("holiday") ||
      normalized.contains("holidays") ||
      normalized.contains("节假日") ||
      normalized.contains("假期") ||
      normalized.contains("法定假日") ||
      normalized.contains("放假")
  }
}

enum AppleCalendarStoreError: Error, LocalizedError {
  case invalidDraft(message: String)
  case notFound
  case deleteManagedFailed(errors: [String])

  var errorDescription: String? {
    switch self {
    case .invalidDraft(let message):
      return message
    case .notFound:
      return "eventIdentifier is invalid"
    case .deleteManagedFailed(let errors):
      return errors.joined(separator: " | ")
    }
  }

  var flutterCode: String {
    switch self {
    case .deleteManagedFailed:
      return "delete_managed_failed"
    case .invalidDraft, .notFound:
      return "invalid_args"
    }
  }

  var details: Any? {
    switch self {
    case .deleteManagedFailed(let errors):
      return ["error_count": errors.count]
    case .invalidDraft, .notFound:
      return nil
    }
  }
}
