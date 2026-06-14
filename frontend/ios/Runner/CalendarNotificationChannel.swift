import Flutter
import UIKit
import UserNotifications

final class CalendarNotificationChannel: NSObject, FlutterStreamHandler, UNUserNotificationCenterDelegate {
  private struct NotificationRequest {
    let identifier: String
    let scheduledAt: Date
    let content: UNMutableNotificationContent
  }

  private let channel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private let center = UNUserNotificationCenter.current()
  private static var sharedChannel: CalendarNotificationChannel?
  private static let isoFormatterWithFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()
  private static let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()
  private var pendingRemoteRegistrationResult: FlutterResult?
  private var foregroundNotificationContext: String = "other"
  private var eventSink: FlutterEventSink?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "ling/calendar_notifications",
      binaryMessenger: messenger
    )
    eventChannel = FlutterEventChannel(
      name: "ling/calendar_notifications/events",
      binaryMessenger: messenger
    )
    super.init()
    Self.sharedChannel = self
    center.delegate = self
    channel.setMethodCallHandler(handle)
    eventChannel.setStreamHandler(self)
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPermissionState":
      getPermissionState(result: result)
    case "requestPermission":
      requestPermission(result: result)
    case "openSystemSettings":
      openSystemSettings(result: result)
    case "syncNotifications":
      syncNotifications(call: call, result: result)
    case "cancelAllNotifications":
      cancelAllNotifications(result: result)
    case "registerRemoteNotifications":
      registerRemoteNotifications(result: result)
    case "setApplicationBadgeCount":
      setApplicationBadgeCount(call: call, result: result)
    case "setForegroundNotificationContext":
      setForegroundNotificationContext(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func getPermissionState(result: @escaping FlutterResult) {
    center.getNotificationSettings { settings in
      DispatchQueue.main.async {
        result(self.permissionStateRaw(settings.authorizationStatus))
      }
    }
  }

  private func requestPermission(result: @escaping FlutterResult) {
    center.requestAuthorization(options: [.alert, .badge, .sound]) { _, error in
      if let error {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "notification_permission_error",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
        return
      }
      self.getPermissionState(result: result)
    }
  }

  private func openSystemSettings(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let settingsUrlString: String
      if #available(iOS 16.0, *) {
        settingsUrlString = UIApplication.openNotificationSettingsURLString
      } else {
        settingsUrlString = UIApplication.openSettingsURLString
      }
      guard let url = URL(string: settingsUrlString) else {
        result(nil)
        return
      }
      UIApplication.shared.open(url, options: [:]) { _ in
        result(nil)
      }
    }
  }

  private func syncNotifications(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let rawNotifications = args["notifications"] as? [Any]
    else {
      result(
        FlutterError(
          code: "invalid_args",
          message: "notifications are required",
          details: nil
        )
      )
      return
    }

    let notifications = rawNotifications
      .compactMap { $0 as? [String: Any] }
      .compactMap(buildNotificationRequest)
      .sorted(by: { $0.scheduledAt < $1.scheduledAt })

    clearLingNotifications {
      let limited = Array(notifications.prefix(64))
      if limited.isEmpty {
        result(nil)
        return
      }

      let group = DispatchGroup()
      var schedulingError: Error?
      for notification in limited {
        group.enter()
        let triggerDate = Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute, .second],
          from: notification.scheduledAt
        )
        let request = UNNotificationRequest(
          identifier: notification.identifier,
          content: notification.content,
          trigger: UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        )
        self.center.add(request) { error in
          if schedulingError == nil {
            schedulingError = error
          }
          group.leave()
        }
      }

      group.notify(queue: .main) {
        if let schedulingError {
          result(
            FlutterError(
              code: "notification_schedule_failed",
              message: schedulingError.localizedDescription,
              details: nil
            )
          )
          return
        }
        result(nil)
      }
    }
  }

  private func cancelAllNotifications(result: @escaping FlutterResult) {
    clearLingNotifications {
      result(nil)
    }
  }

  private func registerRemoteNotifications(result: @escaping FlutterResult) {
    if pendingRemoteRegistrationResult != nil {
      result(
        FlutterError(
          code: "busy",
          message: "Remote notification registration is already in progress.",
          details: nil
        )
      )
      return
    }

    pendingRemoteRegistrationResult = result
    let bundleID = Bundle.main.bundleIdentifier ?? ""
    let apsEnvironment = lingCurrentAPNsEnvironment()
    print(
      "[Ling][iOS][Push] registerRemoteNotifications requested " +
        "bundle_id=\(bundleID) aps_environment=\(apsEnvironment)"
    )
    DispatchQueue.main.async {
      UIApplication.shared.registerForRemoteNotifications()
    }
  }

  private func setApplicationBadgeCount(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    let args = call.arguments as? [String: Any]
    let rawCount = args?["count"] as? Int ?? 0
    DispatchQueue.main.async {
      UIApplication.shared.applicationIconBadgeNumber = max(0, rawCount)
      result(nil)
    }
  }

  private func setForegroundNotificationContext(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    let args = call.arguments as? [String: Any]
    let value =
      (args?["context"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "other"
    foregroundNotificationContext = value.isEmpty ? "other" : value
    result(nil)
  }

  private func remoteNotificationPayload(token: String) -> [String: Any] {
    [
      "push_token": token,
      "app_bundle_id": Bundle.main.bundleIdentifier ?? "",
      "apns_environment": lingCurrentAPNsEnvironment()
    ]
  }

  private func completeRemoteRegistration(result: Any?) {
    guard let pendingRemoteRegistrationResult else {
      return
    }
    self.pendingRemoteRegistrationResult = nil
    DispatchQueue.main.async {
      pendingRemoteRegistrationResult(result)
    }
  }

  private func handleRemoteRegistrationSuccess(deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    let bundleID = Bundle.main.bundleIdentifier ?? ""
    let apsEnvironment = lingCurrentAPNsEnvironment()
    let tokenPrefix = lingPushTokenPrefix(token)
    print(
      "[Ling][iOS][Push] remote notification registration succeeded " +
        "bundle_id=\(bundleID) token_prefix=\(tokenPrefix) aps_environment=\(apsEnvironment)"
    )
    completeRemoteRegistration(result: remoteNotificationPayload(token: token))
  }

  private func handleRemoteRegistrationFailure(_ error: Error) {
    completeRemoteRegistration(
      result: FlutterError(
        code: "remote_notification_registration_failed",
        message: error.localizedDescription,
        details: nil
      )
    )
  }

  static func didRegisterForRemoteNotifications(deviceToken: Data) {
    sharedChannel?.handleRemoteRegistrationSuccess(deviceToken: deviceToken)
  }

  static func didFailToRegisterForRemoteNotifications(error: Error) {
    sharedChannel?.handleRemoteRegistrationFailure(error)
  }

  private func buildNotificationRequest(_ json: [String: Any]) -> NotificationRequest? {
    guard
      let identifier = json["identifier"] as? String,
      let title = json["title"] as? String,
      let body = json["body"] as? String,
      let scheduledAtRaw = json["scheduledAt"] as? String,
      let scheduledAt = parseDate(scheduledAtRaw),
      scheduledAt.timeIntervalSinceNow > 1
    else {
      return nil
    }

    let mode = (json["mode"] as? String) ?? "banner_sound"
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.threadIdentifier = "ling.calendar.notifications"
    content.categoryIdentifier = "ling.calendar.notification"
    content.userInfo = [
      "source": "ling",
      "mode": mode,
      "kind": "app_notification"
    ]
    content.sound = mode == "banner_sound" ? .default : nil

    if #available(iOS 15.0, *) {
      switch mode {
      case "silent":
        content.interruptionLevel = .passive
      default:
        content.interruptionLevel = .active
      }
    }

    return NotificationRequest(
      identifier: identifier,
      scheduledAt: scheduledAt,
      content: content
    )
  }

  private func clearLingNotifications(completion: @escaping () -> Void) {
    center.getPendingNotificationRequests { requests in
      let pendingIds = requests
        .map(\.identifier)
        .filter { $0.hasPrefix(lingCalendarNotificationPrefix) }
      self.center.getDeliveredNotifications { notifications in
        let deliveredIds = notifications
          .map(\.request.identifier)
          .filter { $0.hasPrefix(lingCalendarNotificationPrefix) }
        let identifiers = Array(Set(pendingIds + deliveredIds))
        if !identifiers.isEmpty {
          self.center.removePendingNotificationRequests(withIdentifiers: identifiers)
          self.center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
        DispatchQueue.main.async {
          completion()
        }
      }
    }
  }

  private func permissionStateRaw(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized, .provisional:
      return "granted"
    case .ephemeral:
      return "granted"
    case .notDetermined:
      return "not_determined"
    case .denied:
      return "denied"
    @unknown default:
      return "denied"
    }
  }

  private func parseDate(_ value: String) -> Date? {
    if let date = Self.isoFormatterWithFractionalSeconds.date(from: value) {
      return date
    }
    return Self.isoFormatter.date(from: value)
  }

  private func emitForegroundRemoteNotificationEvent(
    identifier: String,
    kind: String,
    userInfo: [AnyHashable: Any]
  ) {
    guard shouldEmitLingForegroundNotificationEvent(identifier: identifier, kind: kind) else {
      return
    }
    let target = userInfo["target"] as? [String: Any]
    let payload: [String: Any] = [
      "identifier": identifier,
      "kind": kind,
      "mode": userInfo["mode"] as? String ?? "",
      "notification_id": userInfo["notification_id"] as? String ?? "",
      "target_type": target?["type"] as? String ?? "",
      "target_id": target?["id"] as? String ?? "",
      "target_action": target?["action"] as? String ?? ""
    ]
    DispatchQueue.main.async {
      self.eventSink?(payload)
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let request = notification.request
    let userInfo = request.content.userInfo
    let identifier = request.identifier
    let kind = userInfo["kind"] as? String ?? ""
    emitForegroundRemoteNotificationEvent(
      identifier: identifier,
      kind: kind,
      userInfo: userInfo
    )
    let shouldPresent = shouldPresentLingForegroundNotification(
      identifier: identifier,
      kind: kind,
      foregroundNotificationContext: foregroundNotificationContext
    )
    print(
      "[Ling][iOS][Notifications] willPresent identifier=\(identifier) " +
        "kind=\(kind) context=\(foregroundNotificationContext) " +
        "shouldPresent=\(shouldPresent)"
    )
    if !shouldPresent {
      completionHandler([])
      return
    }
    let mode = request.content.userInfo["mode"] as? String ?? "banner_sound"
    if #available(iOS 14.0, *) {
      var options: UNNotificationPresentationOptions = [.banner, .list]
      if mode == "banner_sound" {
        options.insert(.sound)
      }
      completionHandler(options)
      return
    }

    var options: UNNotificationPresentationOptions = [.alert]
    if mode == "banner_sound" {
      options.insert(.sound)
    }
    completionHandler(options)
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let request = response.notification.request
    let userInfo = request.content.userInfo
    let identifier = request.identifier
    let kind = userInfo["kind"] as? String ?? ""
    emitForegroundRemoteNotificationEvent(
      identifier: identifier,
      kind: kind,
      userInfo: userInfo
    )
    completionHandler()
  }
}
