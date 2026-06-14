import Flutter
import UIKit

final class DeepLinkChannel {
  private let channel: FlutterMethodChannel
  private var isFlutterReady = false
  private var pendingDeepLink: [String: Any]?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "ling/deep_link",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "ready":
        self.isFlutterReady = true
        let payload = self.pendingDeepLink
        self.pendingDeepLink = nil
        result(payload)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func handleContinue(_ userActivity: NSUserActivity) -> Bool {
    guard
      userActivity.activityType == NSUserActivityTypeBrowsingWeb,
      let url = userActivity.webpageURL,
      let payload = Self.deepLinkPayload(from: url)
    else {
      return false
    }
    deliver(payload)
    return true
  }

  private func deliver(_ payload: [String: Any]) {
    if !isFlutterReady {
      pendingDeepLink = payload
      return
    }
    channel.invokeMethod("deepLinkOpened", arguments: payload)
  }

  private static func deepLinkPayload(from url: URL) -> [String: Any]? {
    return nil
  }
}
