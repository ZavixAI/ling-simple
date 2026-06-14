import AuthenticationServices
import Flutter
import UIKit

final class ExternalCalendarOAuthChannel: NSObject, ASWebAuthenticationPresentationContextProviding
{
  private let channel: FlutterMethodChannel
  private let presentationAnchorProvider: () -> UIWindow?
  private var pendingResult: FlutterResult?
  private var pendingCallbackScheme: String?
  private var session: ASWebAuthenticationSession?

  init(
    messenger: FlutterBinaryMessenger,
    presentationAnchorProvider: @escaping () -> UIWindow?
  ) {
    self.presentationAnchorProvider = presentationAnchorProvider
    channel = FlutterMethodChannel(
      name: "ling/external_calendar_oauth",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    presentationAnchorProvider() ?? ASPresentationAnchor()
  }

  func handleOpenURLContexts(_ urlContexts: Set<UIOpenURLContext>) -> Bool {
    guard let callbackScheme = pendingCallbackScheme?.lowercased() else {
      return false
    }
    guard let url = urlContexts.first?.url else {
      return false
    }
    if url.scheme?.lowercased() != callbackScheme {
      return false
    }
    finish(
      with: [
        "status": "success",
        "callbackUrl": url.absoluteString
      ]
    )
    return true
  }

  func handleContinue(_ userActivity: NSUserActivity) -> Bool {
    guard
      let callbackScheme = pendingCallbackScheme?.lowercased(),
      let url = userActivity.webpageURL
    else {
      return false
    }
    if url.scheme?.lowercased() != callbackScheme {
      return false
    }
    finish(
      with: [
        "status": "success",
        "callbackUrl": url.absoluteString
      ]
    )
    return true
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authorize":
      authorize(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func authorize(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard pendingResult == nil else {
      result(
        FlutterError(
          code: "busy",
          message: "Another external calendar authorization is already in progress.",
          details: nil
        )
      )
      return
    }
    guard let args = call.arguments as? [String: Any] else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "Missing authorization arguments.",
          details: nil
        )
      )
      return
    }
    let authorizeUrlString = (args["authorizeUrl"] as? String ?? "").trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    let callbackScheme = (args["callbackScheme"] as? String ?? "").trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    guard let authorizeUrl = URL(string: authorizeUrlString), !callbackScheme.isEmpty else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "authorizeUrl or callbackScheme is invalid.",
          details: nil
        )
      )
      return
    }

    pendingResult = result
    pendingCallbackScheme = callbackScheme
    let session = ASWebAuthenticationSession(
      url: authorizeUrl,
      callbackURLScheme: callbackScheme
    ) { [weak self] callbackURL, error in
      DispatchQueue.main.async {
        guard let self else {
          return
        }
        if let callbackURL {
          self.finish(
            with: [
              "status": "success",
              "callbackUrl": callbackURL.absoluteString
            ]
          )
          return
        }
        if let error = error as? ASWebAuthenticationSessionError,
          error.code == .canceledLogin
        {
          self.finish(with: ["status": "cancelled"])
          return
        }
        self.finish(
          with: [
            "status": "error",
            "message": error?.localizedDescription ?? "Authorization failed."
          ]
        )
      }
    }
    session.presentationContextProvider = self
    if #available(iOS 13.0, *) {
      session.prefersEphemeralWebBrowserSession = false
    }
    self.session = session
    if !session.start() {
      finish(
        with: [
          "status": "error",
          "message": "Unable to start authorization session."
        ]
      )
    }
  }

  private func finish(with payload: [String: Any]) {
    session?.cancel()
    session = nil
    pendingCallbackScheme = nil
    let result = pendingResult
    pendingResult = nil
    result?(payload)
  }
}
