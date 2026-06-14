import Flutter
import UIKit

final class AliyunNumberAuthChannel: NSObject {
  private let channel: FlutterMethodChannel
  private lazy var handler: TXCommonHandler = {
    print("[Ling][iOS][AliyunNumberAuth] initializing TXCommonHandler")
    return TXCommonHandler.sharedInstance()
  }()
  private var isConfigured = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "ling/aliyun_number_auth",
      binaryMessenger: messenger
    )
    super.init()
    print("[Ling][iOS][AliyunNumberAuth] channel ready")
    channel.setMethodCallHandler(handle)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "prepareLogin":
      Task {
        result(await prepareLogin())
      }
    case "startLogin":
      let arguments = call.arguments as? [String: Any]
      let prefersDarkMode = arguments?["prefersDarkMode"] as? Bool ?? false
      startLogin(result: result, prefersDarkMode: prefersDarkMode)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func prepareLogin() async -> [String: Any] {
    let configResult = await configureSDKIfNeeded()
    if configResult["status"] as? String != "available" {
      return configResult
    }

    let envResult = await checkLoginEnvironment()
    if envResult["status"] as? String == "available" {
      _ = await accelerateLoginPage()
    }
    return envResult
  }

  private func startLogin(result: @escaping FlutterResult, prefersDarkMode: Bool) {
    Task {
      let capability = await prepareLogin()
      if capability["status"] as? String != "available" {
        result(
          terminalResult(
            status: "error",
            message: (capability["message"] as? String) ?? "One-click phone auth unavailable"
          )
        )
        return
      }

      guard let presenter = topViewController() else {
        result(
          terminalResult(
            status: "error",
            message: "Unable to find a presenter for one-click phone auth"
          )
        )
        return
      }

      let model = AliyunNumberAuthModelFactory.make(
        prefersDarkMode: prefersDarkMode,
        termsURL: configuredString(forKey: "AliyunNumberAuthTermsURL"),
        privacyURL: configuredString(forKey: "AliyunNumberAuthPrivacyURL"),
        keyWindow: { AliyunNumberAuthChannel.keyWindow }
      )
      var hasFinished = false

      handler.getLoginToken(
        withTimeout: 5.0,
        controller: presenter,
        model: model
      ) { [weak self] response in
        guard let self, !hasFinished else {
          return
        }

        let code = self.resultCode(response)
        switch code {
        case "600000":
          hasFinished = true
          self.handler.cancelLoginVC(animated: true, complete: nil)
          result(
            self.terminalResult(
              status: "success",
              token: response["token"] as? String,
              message: self.resultMessage(response)
            )
          )
        case "700001":
          hasFinished = true
          self.handler.cancelLoginVC(animated: true, complete: nil)
          result(
            self.terminalResult(
              status: "fallback",
              message: "Switched to another phone number"
            )
          )
        case "700000":
          hasFinished = true
          self.handler.cancelLoginVC(animated: true, complete: nil)
          result(
            self.terminalResult(
              status: "cancelled",
              message: self.resultMessage(response)
            )
          )
        case "600002", "600011", "600013", "600014", "600015":
          hasFinished = true
          self.handler.cancelLoginVC(animated: true, complete: nil)
          result(
            self.terminalResult(
              status: "error",
              message: self.resultMessage(response)
            )
          )
        default:
          break
        }
      }
    }
  }

  private func configureSDKIfNeeded() async -> [String: Any] {
    if isConfigured {
      return capabilityResult(status: "available")
    }

    guard let sdkInfo = configuredString(forKey: "AliyunNumberAuthSDKInfo") else {
      return capabilityResult(
        status: "unconfigured",
        message: "Aliyun number auth is not configured"
      )
    }

    print(
      "[Ling][iOS][AliyunNumberAuth] configureSDK bundleId=\(Bundle.main.bundleIdentifier ?? "unknown") sdkInfoLength=\(sdkInfo.count)"
    )

    let response = await awaitDictionary { completion in
      handler.setAuthSDKInfo(sdkInfo) { dictionary in
        completion(dictionary)
      }
    }

    if resultCode(response) == "600000" {
      isConfigured = true
      return capabilityResult(status: "available")
    }

    return capabilityResult(
      status: "unconfigured",
      message: configurationFailureMessage(response)
    )
  }

  private func checkLoginEnvironment() async -> [String: Any] {
    let response = await awaitDictionary { completion in
      handler.checkEnvAvailable(with: .loginToken, complete: { dictionary in
        completion(dictionary)
      })
    }

    if resultCode(response) == "600000" {
      return capabilityResult(status: "available")
    }

    return capabilityResult(
      status: "unavailable",
      message: diagnosticResultMessage(response)
    )
  }

  private func accelerateLoginPage() async -> [String: Any] {
    let response = await awaitDictionary { completion in
      handler.accelerateLoginPage(withTimeout: 3.0) { dictionary in
        completion(dictionary)
      }
    }

    if resultCode(response) == "600000" {
      return capabilityResult(status: "available")
    }

    return capabilityResult(
      status: "unavailable",
      message: diagnosticResultMessage(response)
    )
  }

  private func configuredString(forKey key: String) -> String? {
    guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
      return nil
    }
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.isEmpty || (value.hasPrefix("$(") && value.hasSuffix(")")) {
      return nil
    }
    return value
  }

  private func capabilityResult(status: String, message: String = "") -> [String: Any] {
    [
      "status": status,
      "message": message,
      "sdkVersion": handler.getVersion()
    ]
  }

  private func terminalResult(
    status: String,
    token: String? = nil,
    message: String = ""
  ) -> [String: Any] {
    var result: [String: Any] = [
      "status": status,
      "message": message
    ]
    if let token, !token.isEmpty {
      result["token"] = token
    }
    return result
  }

  private func resultCode(_ response: [AnyHashable: Any]?) -> String {
    if let code = response?["resultCode"] {
      return "\(code)"
    }
    return ""
  }

  private func resultMessage(_ response: [AnyHashable: Any]?) -> String {
    if let message = response?["msg"] as? String, !message.isEmpty {
      return message
    }
    if let message = response?["message"] as? String, !message.isEmpty {
      return message
    }
    return "One-click phone auth failed"
  }

  private func diagnosticResultMessage(_ response: [AnyHashable: Any]?) -> String {
    let message = resultMessage(response)
    let code = resultCode(response)
    if code.isEmpty {
      return message
    }
    return "[\(code)] \(message)"
  }

  private func configurationFailureMessage(_ response: [AnyHashable: Any]?) -> String {
    let diagnostic = diagnosticResultMessage(response)
    let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
    let code = resultCode(response)
    if code == "600017" {
      return
        "Aliyun SDKInfo is invalid for bundle id \(bundleId). \(diagnostic)"
    }
    return "Aliyun number auth configuration failed for bundle id \(bundleId). \(diagnostic)"
  }

  private func awaitDictionary(
    _ work: (@escaping ([AnyHashable: Any]?) -> Void) -> Void
  ) async -> [AnyHashable: Any]? {
    await withCheckedContinuation { continuation in
      work { response in
        continuation.resume(returning: response)
      }
    }
  }

  private func topViewController(
    from root: UIViewController? = AliyunNumberAuthChannel.keyWindow?.rootViewController
  ) -> UIViewController? {
    if let navigationController = root as? UINavigationController {
      return topViewController(from: navigationController.visibleViewController)
    }
    if let tabBarController = root as? UITabBarController {
      return topViewController(from: tabBarController.selectedViewController)
    }
    if let presentedController = root?.presentedViewController {
      return topViewController(from: presentedController)
    }
    return root
  }

  private static var keyWindow: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
  }
}
