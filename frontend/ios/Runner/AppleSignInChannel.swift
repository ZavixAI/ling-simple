import AuthenticationServices
import Flutter
import UIKit

final class AppleSignInChannel: NSObject {
  private let channel: FlutterMethodChannel
  private let presentationAnchorProvider: () -> ASPresentationAnchor?
  private var pendingResult: FlutterResult?

  init(
    messenger: FlutterBinaryMessenger,
    presentationAnchorProvider: @escaping () -> ASPresentationAnchor?
  ) {
    self.presentationAnchorProvider = presentationAnchorProvider
    channel = FlutterMethodChannel(
      name: "ling/apple_sign_in",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "signIn":
      startSignIn(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startSignIn(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard self.pendingResult == nil else {
        result(
          self.terminalResult(
            status: "error",
            message: "Apple sign in is already in progress."
          )
        )
        return
      }

      guard self.resolvedPresentationAnchor() != nil else {
        result(
          self.terminalResult(
            status: "error",
            message: "Unable to present Apple sign in."
          )
        )
        return
      }

      let provider = ASAuthorizationAppleIDProvider()
      let request = provider.createRequest()
      request.requestedScopes = [.fullName, .email]

      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = self
      controller.presentationContextProvider = self
      self.pendingResult = result
      controller.performRequests()
    }
  }

  private func resolvedPresentationAnchor() -> ASPresentationAnchor? {
    if let anchor = presentationAnchorProvider() {
      return anchor
    }
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
  }

  private func compactFullName(_ fullName: PersonNameComponents?) -> [String: String] {
    guard let fullName else {
      return [:]
    }
    var payload: [String: String] = [:]
    if let givenName = fullName.givenName?.trimmingCharacters(in: .whitespacesAndNewlines),
      !givenName.isEmpty
    {
      payload["given_name"] = givenName
    }
    if let familyName = fullName.familyName?.trimmingCharacters(in: .whitespacesAndNewlines),
      !familyName.isEmpty
    {
      payload["family_name"] = familyName
    }
    if let middleName = fullName.middleName?.trimmingCharacters(in: .whitespacesAndNewlines),
      !middleName.isEmpty
    {
      payload["middle_name"] = middleName
    }
    if let nickname = fullName.nickname?.trimmingCharacters(in: .whitespacesAndNewlines),
      !nickname.isEmpty
    {
      payload["nickname"] = nickname
    }
    return payload
  }

  private func terminalResult(
    status: String,
    identityToken: String? = nil,
    authorizationCode: String? = nil,
    fullName: [String: String]? = nil,
    message: String = ""
  ) -> [String: Any] {
    var payload: [String: Any] = [
      "status": status,
      "message": message
    ]
    if let identityToken, !identityToken.isEmpty {
      payload["identityToken"] = identityToken
    }
    if let authorizationCode, !authorizationCode.isEmpty {
      payload["authorizationCode"] = authorizationCode
    }
    if let fullName, !fullName.isEmpty {
      payload["fullName"] = fullName
    }
    return payload
  }

  private func finish(with payload: [String: Any]) {
    DispatchQueue.main.async {
      guard let result = self.pendingResult else {
        return
      }
      self.pendingResult = nil
      result(payload)
    }
  }
}

extension AppleSignInChannel: ASAuthorizationControllerDelegate {
  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      finish(
        with: terminalResult(
          status: "error",
          message: "Apple sign in returned an unsupported credential."
        )
      )
      return
    }

    guard
      let tokenData = credential.identityToken,
      let identityToken = String(data: tokenData, encoding: .utf8),
      !identityToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      finish(
        with: terminalResult(
          status: "error",
          message: "Apple sign in did not return an identity token."
        )
      )
      return
    }

    let authorizationCode = credential.authorizationCode.flatMap {
      String(data: $0, encoding: .utf8)
    }

    finish(
      with: terminalResult(
        status: "success",
        identityToken: identityToken,
        authorizationCode: authorizationCode,
        fullName: compactFullName(credential.fullName)
      )
    )
  }

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Error
  ) {
    let nsError = error as NSError
    if nsError.domain == ASAuthorizationError.errorDomain,
      nsError.code == ASAuthorizationError.canceled.rawValue
    {
      finish(
        with: terminalResult(
          status: "cancelled",
          message: error.localizedDescription
        )
      )
      return
    }

    finish(
      with: terminalResult(
        status: "error",
        message: error.localizedDescription
      )
    )
  }
}

extension AppleSignInChannel: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    resolvedPresentationAnchor() ?? UIWindow()
  }
}
