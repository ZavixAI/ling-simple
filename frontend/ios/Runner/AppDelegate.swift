import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("[Ling][iOS][AppDelegate] didFinishLaunching begin")
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    AppleDataProtectionCoordinator().applyDefaultProtection()
    print("[Ling][iOS][AppDelegate] didFinishLaunching end result=\(result)")
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    print("[Ling][iOS][AppDelegate] didInitializeImplicitFlutterEngine begin")
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    print("[Ling][iOS][AppDelegate] didInitializeImplicitFlutterEngine end")
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("[Ling][iOS][AppDelegate] didRegisterForRemoteNotifications")
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    DeviceContextChannel.persistPushToken(token)
    CalendarNotificationChannel.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[Ling][iOS][AppDelegate] didFailToRegisterForRemoteNotifications error=\(error)")
    CalendarNotificationChannel.didFailToRegisterForRemoteNotifications(error: error)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if (userInfo["kind"] as? String) == "refresh_device_context" {
      DeviceContextChannel.handleBackgroundRefresh(
        userInfo: userInfo,
        completion: completionHandler
      )
      return
    }
    super.application(
      application,
      didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: completionHandler
    )
  }
}

private final class AppleDataProtectionCoordinator {
  private let fileManager = FileManager.default
  private let protectionAttributes: [FileAttributeKey: Any] = [
    .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
  ]

  func applyDefaultProtection() {
    for directoryURL in protectedDirectoryURLs() {
      applyProtectionRecursively(at: directoryURL)
    }
  }

  private func protectedDirectoryURLs() -> [URL] {
    var urls = [URL]()
    let searchPathDirectories: [FileManager.SearchPathDirectory] = [
      .documentDirectory,
      .applicationSupportDirectory,
      .cachesDirectory
    ]
    for directory in searchPathDirectories {
      if let url = fileManager.urls(for: directory, in: .userDomainMask).first {
        urls.append(url)
      }
    }

    let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    if !temporaryDirectory.path.isEmpty {
      urls.append(temporaryDirectory)
    }
    return urls
  }

  private func applyProtectionRecursively(at directoryURL: URL) {
    do {
      try fileManager.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true,
        attributes: nil
      )
    } catch {
      print(
        "[Ling][iOS][Protection] create directory failed path=\(directoryURL.path) error=\(error)"
      )
      return
    }

    applyProtection(to: directoryURL)

    guard let enumerator = fileManager.enumerator(
      at: directoryURL,
      includingPropertiesForKeys: nil
    ) else {
      return
    }

    for case let childURL as URL in enumerator {
      applyProtection(to: childURL)
    }
  }

  private func applyProtection(to url: URL) {
    do {
      try fileManager.setAttributes(protectionAttributes, ofItemAtPath: url.path)
    } catch {
      print(
        "[Ling][iOS][Protection] set attributes failed path=\(url.path) error=\(error)"
      )
    }
  }
}
