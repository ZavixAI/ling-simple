import Flutter
import UIKit

#if LING_DOUYIN_SDK
import DouyinOpenSDK
#endif

final class SocialShareSDKChannel: NSObject {
  private let douyinChannel: FlutterMethodChannel
  private let weiboChannel: FlutterMethodChannel
  private let photoLibraryWriter = SocialSharePhotoLibraryWriter()
  private var isWeiboRegistered = false

  init(messenger: FlutterBinaryMessenger) {
    douyinChannel = FlutterMethodChannel(
      name: "ling/douyin_share",
      binaryMessenger: messenger
    )
    weiboChannel = FlutterMethodChannel(
      name: "ling/weibo_share",
      binaryMessenger: messenger
    )
    super.init()

    douyinChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, platform: .douyin, result: result)
    }
    weiboChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, platform: .weibo, result: result)
    }
  }

  func handleOpenURLContexts(_ urlContexts: Set<UIOpenURLContext>) -> Bool {
    var handled = false
#if LING_DOUYIN_SDK
    if let url = urlContexts.first?.url {
      handled = DouyinOpenSDKApplicationDelegate.sharedInstance().application(
        nil,
        open: url,
        sourceApplication: nil,
        annotation: nil
      ) || handled
    }
#endif
#if LING_WEIBO_SDK
    for context in urlContexts {
      handled = WeiboSDK.handleOpen(context.url, delegate: self) || handled
    }
#endif
    return handled
  }

  func handleContinue(_ userActivity: NSUserActivity) -> Bool {
    var handled = false
#if LING_WEIBO_SDK
    handled = WeiboSDK.handleOpenUniversalLink(userActivity, delegate: self) || handled
#endif
    return handled
  }

  private func handle(
    _ call: FlutterMethodCall,
    platform: SocialSharePlatform,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "shareImageText":
      shareImageText(call: call, platform: platform, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func shareImageText(
    call: FlutterMethodCall,
    platform: SocialSharePlatform,
    result: @escaping FlutterResult
  ) {
    guard call.arguments is [String: Any] else {
      result(terminalResult(status: "error", message: "Missing share arguments."))
      return
    }
    if platform == .weibo {
      shareToWeibo(call: call, result: result)
      return
    }
    if platform == .douyin {
      shareToDouyin(call: call, result: result)
      return
    }
    result(
      terminalResult(
        status: "unsupported",
        message: "\(platform.displayName) SDK bridge is ready, but share request wiring requires the approved SDK package."
      )
    )
  }

  private func terminalResult(status: String, message: String = "") -> [String: Any] {
    [
      "status": status,
      "message": message
    ]
  }

  private func shareToWeibo(call: FlutterMethodCall, result: @escaping FlutterResult) {
#if LING_WEIBO_SDK
    shareToWeiboWithSDK(call: call, result: result)
#else
    result(
      terminalResult(
        status: "unsupported",
        message: "Weibo SDK is not installed in this build."
      )
    )
#endif
  }

  private func shareToDouyin(call: FlutterMethodCall, result: @escaping FlutterResult) {
#if LING_DOUYIN_SDK
    guard let arguments = call.arguments as? [String: Any] else {
      result(terminalResult(status: "error", message: "Missing share arguments."))
      return
    }
    guard let appId = SocialSharePlatform.configuredString(forKey: "DouyinAppID") else {
      result(
        terminalResult(
          status: "unsupported",
          message: "Douyin sharing is not configured."
        )
      )
      return
    }
    DouyinOpenSDKApplicationDelegate.sharedInstance().application(
      UIApplication.shared,
      didFinishLaunchingWithOptions: nil
    )
    guard DouyinOpenSDKApplicationDelegate.sharedInstance().registerAppId(appId) else {
      result(
        terminalResult(
          status: "unsupported",
          message: "Douyin sharing failed to initialize."
        )
      )
      return
    }
    let images = SocialShareImageDecoder.decodedFlutterImages(from: arguments)
    guard !images.isEmpty else {
      result(terminalResult(status: "error", message: "Douyin sharing requires images."))
      return
    }
    photoLibraryWriter.saveImages(images) { [weak self] identifiersResult in
      guard let self else {
        return
      }
      switch identifiersResult {
      case .failure(let error):
        result(
          self.terminalResult(
            status: "error",
            message: error.localizedDescription
          )
        )
      case .success(let identifiers):
        self.sendDouyinImageShareRequest(
          identifiers: identifiers,
          arguments: arguments,
          result: result
        )
      }
    }
#else
    result(
      terminalResult(
        status: "unsupported",
        message: "Douyin SDK is not installed in this build."
      )
    )
#endif
  }

#if LING_DOUYIN_SDK
  private func sendDouyinImageShareRequest(
    identifiers: [String],
    arguments: [String: Any],
    result: @escaping FlutterResult
  ) {
    let request = DouyinOpenSDKShareRequest()
    request.shareAction = DouyinOpenSDKShareAction(rawValue: 0)!
    request.mediaType = DouyinOpenSDKShareMediaType(rawValue: 0)!
    request.localIdentifiers = identifiers
    request.landedPageType = DouyinOpenSDKLandedPageType(rawValue: 2)!
    request.publishStory = false
    request.imageAlbumMode = identifiers.count > 1
    request.state = UUID().uuidString

    let titleText = (arguments["title"] as? String ?? "").trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    let bodyText = (arguments["text"] as? String ?? "").trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    if !titleText.isEmpty || !bodyText.isEmpty {
      let shareTitle = DouyinOpenSDKShareTitle()
      shareTitle.shortTitle = titleText
      shareTitle.text = bodyText
      request.title = shareTitle
    }

    let didSend = request.sendShareRequest(
      withCompleteBlock: { [weak self] (response: DouyinOpenSDKShareResponse?) in
      guard let self else {
        return
      }
      guard let response else {
        result(
          self.terminalResult(
            status: "error",
            message: "Douyin sharing returned no response."
          )
        )
        return
      }
      let status: String
      let shareState = response.shareState.rawValue
      if response.isSucceed ||
        shareState == 20000 ||
        shareState == 20015
      {
        status = "success"
      } else if shareState == 20013 {
        status = "cancelled"
      } else {
        status = "error"
      }
      result(
        self.terminalResult(
          status: status,
          message: response.errString ?? "\(shareState)"
        )
      )
    })
    if !didSend {
      result(
        terminalResult(
          status: "error",
          message: "Unable to start Douyin sharing."
        )
      )
    }
  }
#endif

#if LING_WEIBO_SDK
  private func shareToWeiboWithSDK(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(terminalResult(status: "error", message: "Missing share arguments."))
      return
    }
    guard let configuration = weiboConfiguration() else {
      result(
        terminalResult(
          status: "unsupported",
          message: "Weibo sharing is not configured."
        )
      )
      return
    }
    guard registerWeiboIfNeeded(configuration: configuration) else {
      result(
        terminalResult(
          status: "unsupported",
          message: "Weibo sharing failed to initialize."
        )
      )
      return
    }
    guard WeiboSDK.isWeiboAppInstalled(), WeiboSDK.isCanShareInWeiboAPP() else {
      result(
        terminalResult(
          status: "unsupported",
          message: "Weibo is not installed or does not support sharing."
        )
      )
      return
    }

    let text = (arguments["text"] as? String ?? "").trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    guard !text.isEmpty else {
      result(terminalResult(status: "error", message: "Share text is required."))
      return
    }

    guard let message = WBMessageObject.message() as? WBMessageObject else {
      result(terminalResult(status: "error", message: "Unable to create Weibo message."))
      return
    }
    message.text = text
    let images = decodedShareImages(from: arguments)
    if !images.isEmpty, let imageObject = WBImageObject.object() as? WBImageObject {
      if images.count == 1,
        let data = SocialShareImageDecoder.compressedImageData(
          images[0],
          maxBytes: 10 * 1024 * 1024
        )
      {
        imageObject.imageData = data
      } else {
        imageObject.add(images)
      }
      message.imageObject = imageObject
    }

    guard let request = WBSendMessageToWeiboRequest.request(withMessage: message)
      as? WBSendMessageToWeiboRequest
    else {
      result(terminalResult(status: "error", message: "Unable to create Weibo share request."))
      return
    }

    WeiboSDK.send(request) { [weak self] success in
      guard let self else {
        return
      }
      result(
        self.terminalResult(
          status: success ? "success" : "error",
          message: success ? "" : "Unable to start Weibo sharing."
        )
      )
    }
  }

  private struct WeiboConfiguration {
    let appKey: String
    let universalLink: String
  }

  private func weiboConfiguration() -> WeiboConfiguration? {
    guard
      let appKey = SocialSharePlatform.configuredString(forKey: "WeiboAppKey"),
      let universalLink = SocialSharePlatform.configuredString(
        forKey: "WeiboUniversalLink"
      )
    else {
      return nil
    }
    return WeiboConfiguration(appKey: appKey, universalLink: universalLink)
  }

  private func registerWeiboIfNeeded(configuration: WeiboConfiguration) -> Bool {
    if isWeiboRegistered {
      return true
    }
    isWeiboRegistered = WeiboSDK.registerApp(
      configuration.appKey,
      universalLink: configuration.universalLink
    )
    return isWeiboRegistered
  }

  private func decodedShareImages(from arguments: [String: Any]) -> [UIImage] {
    SocialShareImageDecoder.decodedFlutterImages(from: arguments)
  }
#endif
}

#if LING_WEIBO_SDK
extension SocialShareSDKChannel: WeiboSDKDelegate {
  func didReceiveWeiboRequest(_ request: WBBaseRequest?) {}

  func didReceiveWeiboResponse(_ response: WBBaseResponse?) {}
}
#endif

private enum SocialSharePlatform {
  case douyin
  case weibo

  var displayName: String {
    switch self {
    case .douyin:
      return "Douyin"
    case .weibo:
      return "Weibo"
    }
  }

  var isConfigured: Bool {
    switch self {
    case .douyin:
      return Self.configuredString(forKey: "DouyinAppID") != nil
    case .weibo:
      return Self.configuredString(forKey: "WeiboAppKey") != nil &&
        Self.configuredString(forKey: "WeiboUniversalLink") != nil
    }
  }

  var isSDKAvailable: Bool {
    switch self {
    case .douyin:
#if LING_DOUYIN_SDK
      return true
#else
      return false
#endif
    case .weibo:
#if LING_WEIBO_SDK
      return true
#else
      return false
#endif
    }
  }

  fileprivate static func configuredString(forKey key: String) -> String? {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
      return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
