import Flutter
import StoreKit
import UIKit

final class ReviewRequestChannel: NSObject {
  private let channel: FlutterMethodChannel
  private let windowProvider: () -> UIWindow?

  init(
    messenger: FlutterBinaryMessenger,
    windowProvider: @escaping () -> UIWindow?
  ) {
    self.windowProvider = windowProvider
    channel = FlutterMethodChannel(
      name: "ling/review_request",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestReview":
      requestReview(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestReview(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        result(false)
        return
      }
      if #available(iOS 14.0, *) {
        guard let windowScene = self.windowProvider()?.windowScene else {
          result(false)
          return
        }
        SKStoreReviewController.requestReview(in: windowScene)
      } else {
        SKStoreReviewController.requestReview()
      }
      result(true)
    }
  }
}
