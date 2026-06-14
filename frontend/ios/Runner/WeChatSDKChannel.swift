import Flutter
import UIKit

#if canImport(WechatOpenSDK)
import WechatOpenSDK
#endif

final class WeChatSDKChannel: NSObject {
  private let channel: FlutterMethodChannel
  private let shareChannel: FlutterMethodChannel
  private var pendingAuthResult: FlutterResult?
  private var pendingShareResult: FlutterResult?
  private var isRegistered = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "ling/wechat_login",
      binaryMessenger: messenger
    )
    shareChannel = FlutterMethodChannel(
      name: "ling/wechat_share",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler(handle)
    shareChannel.setMethodCallHandler(handleShare)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startLogin":
      startLogin(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleShare(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "shareText":
      shareText(call: call, result: result)
    case "shareWebpage":
      shareWebpage(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func handleOpenURLContexts(_ urlContexts: Set<UIOpenURLContext>) -> Bool {
#if canImport(WechatOpenSDK)
    var handled = false
    for context in urlContexts {
      handled = WXApi.handleOpen(context.url, delegate: self) || handled
    }
    return handled
#else
    return false
#endif
  }

  func handleContinue(_ userActivity: NSUserActivity) -> Bool {
#if canImport(WechatOpenSDK)
    WXApi.handleOpenUniversalLink(userActivity, delegate: self)
#else
    false
#endif
  }

  private func startLogin(result: @escaping FlutterResult) {
#if canImport(WechatOpenSDK)
    guard pendingAuthResult == nil, pendingShareResult == nil else {
      result(
        terminalResult(
          status: "error",
          message: "A WeChat operation is already in progress."
        )
      )
      return
    }

    guard let configuration = currentConfiguration() else {
      result(
        terminalResult(
          status: "unsupported",
          message: "WeChat sign in is not configured for this build."
        )
      )
      return
    }

    guard registerAppIfNeeded(configuration: configuration) else {
      result(
        terminalResult(
          status: "unsupported",
          message: "WeChat sign in failed to initialize."
        )
      )
      return
    }

    guard WXApi.isWXAppInstalled() else {
      result(
        terminalResult(
          status: "error",
          message: "WeChat is not installed on this device."
        )
      )
      return
    }

    let request = SendAuthReq()
    request.scope = "snsapi_userinfo"
    request.state = "ling_wechat_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"

    pendingAuthResult = result
    WXApi.send(request, completion: { [weak self] success in
      guard let self, !success else {
        return
      }
      self.finishAuth(
        with: self.terminalResult(
          status: "error",
          message: "Unable to start WeChat authorization."
        )
      )
    })
#else
    result(
      terminalResult(
        status: "unsupported",
        message: "WeChat SDK is not installed in this build."
      )
    )
#endif
  }

  private func shareText(call: FlutterMethodCall, result: @escaping FlutterResult) {
#if canImport(WechatOpenSDK)
    guard pendingAuthResult == nil, pendingShareResult == nil else {
      result(
        terminalResult(
          status: "error",
          message: "A WeChat operation is already in progress."
        )
      )
      return
    }

    guard let arguments = call.arguments as? [String: Any] else {
      result(
        terminalResult(
          status: "error",
          message: "Missing share arguments."
        )
      )
      return
    }
    let text = (arguments["text"] as? String ?? "").trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    guard !text.isEmpty else {
      result(
        terminalResult(
          status: "error",
          message: "Share text is required."
        )
      )
      return
    }

    guard let configuration = currentConfiguration() else {
      result(
        terminalResult(
          status: "unsupported",
          message: "WeChat sharing is not configured for this build."
        )
      )
      return
    }

    guard registerAppIfNeeded(configuration: configuration) else {
      result(
        terminalResult(
          status: "unsupported",
          message: "WeChat sharing failed to initialize."
        )
      )
      return
    }

    guard WXApi.isWXAppInstalled() else {
      result(
        terminalResult(
          status: "unsupported",
          message: "WeChat is not installed on this device."
        )
      )
      return
    }

    let request = SendMessageToWXReq()
    request.bText = true
    request.text = text
    request.scene = sceneValue(arguments["scene"] as? String)

    pendingShareResult = result
    WXApi.send(request, completion: { [weak self] success in
      guard let self else {
        return
      }
      if success {
        self.finishShare(
          with: self.terminalResult(
            status: "success",
            message: ""
          )
        )
        return
      }
      self.finishShare(
        with: self.terminalResult(
          status: "error",
          message: "Unable to start WeChat sharing."
        )
      )
    })
#else
    result(
      terminalResult(
        status: "unsupported",
        message: "WeChat SDK is not installed in this build."
      )
    )
#endif
  }

  private func shareWebpage(call: FlutterMethodCall, result: @escaping FlutterResult) {
#if canImport(WechatOpenSDK)
    guard pendingAuthResult == nil, pendingShareResult == nil else {
      result(
        terminalResult(
          status: "error",
          message: "A WeChat operation is already in progress."
        )
      )
      return
    }

    guard let arguments = call.arguments as? [String: Any] else {
      result(
        terminalResult(
          status: "error",
          message: "Missing share arguments."
        )
      )
      return
    }
    let title = (arguments["title"] as? String ?? "").trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    let description = (arguments["description"] as? String ?? "").trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    let webpageUrl = (arguments["webpageUrl"] as? String ?? "").trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    guard !title.isEmpty, !webpageUrl.isEmpty else {
      result(
        terminalResult(
          status: "error",
          message: "Share title and URL are required."
        )
      )
      return
    }

    guard let configuration = currentConfiguration() else {
      result(
        terminalResult(
          status: "unsupported",
          message: "WeChat sharing is not configured for this build."
        )
      )
      return
    }

    guard registerAppIfNeeded(configuration: configuration) else {
      result(
        terminalResult(
          status: "unsupported",
          message: "WeChat sharing failed to initialize."
        )
      )
      return
    }

    guard WXApi.isWXAppInstalled() else {
      result(
        terminalResult(
          status: "unsupported",
          message: "WeChat is not installed on this device."
        )
      )
      return
    }

    let webpageObject = WXWebpageObject()
    webpageObject.webpageUrl = webpageUrl

    let message = WXMediaMessage()
    message.title = title
    message.description = description
    message.mediaObject = webpageObject
    if let thumbData = appIconThumbData() {
      message.thumbData = thumbData
    }

    let request = SendMessageToWXReq()
    request.bText = false
    request.message = message
    request.scene = sceneValue(arguments["scene"] as? String)

    pendingShareResult = result
    WXApi.send(request, completion: { [weak self] success in
      guard let self else {
        return
      }
      if success {
        self.finishShare(
          with: self.terminalResult(
            status: "success",
            message: ""
          )
        )
        return
      }
      self.finishShare(
        with: self.terminalResult(
          status: "error",
          message: "Unable to start WeChat sharing."
        )
      )
    })
#else
    result(
      terminalResult(
        status: "unsupported",
        message: "WeChat SDK is not installed in this build."
      )
    )
#endif
  }

  private func terminalResult(
    status: String,
    authCode: String? = nil,
    message: String = ""
  ) -> [String: Any] {
    var payload: [String: Any] = [
      "status": status,
      "message": message
    ]
    if let authCode, !authCode.isEmpty {
      payload["authCode"] = authCode
    }
    return payload
  }

  private func finishAuth(with payload: [String: Any]) {
    DispatchQueue.main.async {
      guard let result = self.pendingAuthResult else {
        return
      }
      self.pendingAuthResult = nil
      result(payload)
    }
  }

  private func finishShare(with payload: [String: Any]) {
    DispatchQueue.main.async {
      guard let result = self.pendingShareResult else {
        return
      }
      self.pendingShareResult = nil
      result(payload)
    }
  }

  private func configuredString(forKey key: String) -> String? {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
      return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func appIconThumbData() -> Data? {
    guard
      let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
      let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
      let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String]
    else {
      return nil
    }

    for iconName in iconFiles.reversed() {
      guard let image = UIImage(named: iconName) else {
        continue
      }
      let targetSize = CGSize(width: 120, height: 120)
      let renderer = UIGraphicsImageRenderer(size: targetSize)
      let resized = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: targetSize))
      }
      var quality: CGFloat = 0.82
      while quality >= 0.34 {
        if let data = resized.jpegData(compressionQuality: quality), data.count <= 32 * 1024 {
          return data
        }
        quality -= 0.12
      }
    }
    return nil
  }
}

#if canImport(WechatOpenSDK)
private extension WeChatSDKChannel {
  struct WeChatConfiguration {
    let appId: String
    let universalLink: String
  }

  func currentConfiguration() -> WeChatConfiguration? {
    guard
      let appId = configuredString(forKey: "WeChatAppID"),
      let universalLink = configuredString(forKey: "WeChatUniversalLink")
    else {
      return nil
    }
    return WeChatConfiguration(appId: appId, universalLink: universalLink)
  }

  func registerAppIfNeeded(configuration: WeChatConfiguration) -> Bool {
    if isRegistered {
      return true
    }
    let didRegister = WXApi.registerApp(
      configuration.appId,
      universalLink: configuration.universalLink
    )
    isRegistered = didRegister
    return didRegister
  }

  func sceneValue(_ rawValue: String?) -> Int32 {
    let normalized = (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    if normalized == "timeline" {
      return Int32(WXSceneTimeline.rawValue)
    }
    return Int32(WXSceneSession.rawValue)
  }
}

extension WeChatSDKChannel: WXApiDelegate {
  func onReq(_ req: BaseReq) {}

  func onResp(_ resp: BaseResp) {
    if let authResp = resp as? SendAuthResp {
      handleAuthResponse(authResp)
      return
    }
    if let shareResp = resp as? SendMessageToWXResp {
      handleShareResponse(shareResp)
      return
    }
    if pendingAuthResult != nil {
      finishAuth(
        with: terminalResult(
          status: "error",
          message: "WeChat returned an unsupported response."
        )
      )
      return
    }
    if pendingShareResult != nil {
      finishShare(
        with: terminalResult(
          status: "error",
          message: "WeChat returned an unsupported sharing response."
        )
      )
    }
  }

  private func handleAuthResponse(_ authResp: SendAuthResp) {
    guard pendingAuthResult != nil else {
      return
    }
    switch Int(authResp.errCode) {
    case 0:
      let authCode = (authResp.code ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      guard !authCode.isEmpty else {
        finishAuth(
          with: terminalResult(
            status: "error",
            message: "WeChat did not return an authorization code."
          )
        )
        return
      }
      finishAuth(
        with: terminalResult(
          status: "success",
          authCode: authCode,
          message: authResp.errStr
        )
      )
    case -2:
      finishAuth(
        with: terminalResult(
          status: "cancelled",
          message: authResp.errStr
        )
      )
    default:
      finishAuth(
        with: terminalResult(
          status: "error",
          message: authResp.errStr.isEmpty
            ? "WeChat authorization failed."
            : authResp.errStr
        )
      )
    }
  }

  private func handleShareResponse(_ shareResp: SendMessageToWXResp) {
    guard pendingShareResult != nil else {
      return
    }
    switch Int(shareResp.errCode) {
    case 0:
      finishShare(
        with: terminalResult(
          status: "success",
          message: shareResp.errStr
        )
      )
    case -2:
      finishShare(
        with: terminalResult(
          status: "cancelled",
          message: shareResp.errStr
        )
      )
    default:
      finishShare(
        with: terminalResult(
          status: "error",
          message: shareResp.errStr.isEmpty
            ? "WeChat sharing failed."
            : shareResp.errStr
        )
      )
    }
  }
}
#endif
