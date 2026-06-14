import Foundation

let lingCalendarNotificationPrefix = "ling.calendar."
let lingAgentCompletionNotificationPrefix = "ling.agent.completion."
let lingAPNsEnvironmentInfoKey = "LingAPNsEnvironment"

func isLingCalendarNotification(identifier: String, kind: String) -> Bool {
  let normalizedKind = kind.trimmingCharacters(in: .whitespacesAndNewlines)
  if normalizedKind == "app_notification" {
    return true
  }
  return identifier.hasPrefix(lingCalendarNotificationPrefix)
}

func isLingCalendarNotificationRequest(identifier: String, kind: String) -> Bool {
  return isLingCalendarNotification(identifier: identifier, kind: kind)
}

func isLingAgentCompletionNotification(identifier: String, kind: String) -> Bool {
  let normalizedKind = kind.trimmingCharacters(in: .whitespacesAndNewlines)
  if normalizedKind == "agent_completion" {
    return true
  }
  return identifier.hasPrefix(lingAgentCompletionNotificationPrefix)
}

func shouldPresentLingForegroundNotification(
  identifier: String,
  kind: String,
  foregroundNotificationContext: String
) -> Bool {
  if isLingCalendarNotification(identifier: identifier, kind: kind)
    || isLingAgentCompletionNotification(identifier: identifier, kind: kind)
  {
    return foregroundNotificationContext == "background"
  }
  return true
}

func shouldEmitLingForegroundNotificationEvent(identifier: String, kind: String) -> Bool {
  return isLingCalendarNotification(identifier: identifier, kind: kind)
    || isLingAgentCompletionNotification(identifier: identifier, kind: kind)
}

func lingNormalizedAPNsEnvironment(_ value: String?) -> String {
  #if targetEnvironment(simulator)
    return "development"
  #else
  let normalized = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
  return normalized.isEmpty ? "unknown" : normalized
  #endif
}

func lingPushTokenPrefix(_ token: String, visibleCount: Int = 12) -> String {
  let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !normalized.isEmpty else {
    return "empty"
  }
  return String(normalized.prefix(max(1, visibleCount)))
}

func lingCurrentAPNsEnvironment() -> String {
  let value = Bundle.main.object(forInfoDictionaryKey: lingAPNsEnvironmentInfoKey) as? String
  return lingNormalizedAPNsEnvironment(value)
}
