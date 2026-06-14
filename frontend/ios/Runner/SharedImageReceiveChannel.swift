import Flutter
import Foundation
import UIKit

final class SharedImageReceiveChannel {
  private let channel: FlutterMethodChannel
  private var isFlutterReady = false
  private var hasPendingAvailabilitySignal = false
  private var shouldImportPasteboardTextOnNextSignal = false
  private var shouldAutoSendOnNextSignal = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "ling/shared_image_receive",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getPendingSharedImages":
        do {
          let files = try LingSharedImageStore.pendingFiles()
          result(files.map { file in
            [
              "shareId": file.shareId,
              "path": file.path,
              "filename": file.filename
            ]
          })
        } catch {
          result(
            FlutterError(
              code: "read_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      case "consumeSharedImages":
        let arguments = call.arguments as? [String: Any]
        let paths = arguments?["paths"] as? [String] ?? []
        do {
          try LingSharedImageStore.consume(paths: paths)
          result(nil)
        } catch {
          result(
            FlutterError(
              code: "consume_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      case "getPendingSharedItemsAvailability":
        result(Self.availabilityArguments())
      case "consumeSharedPasteboardTextRequest":
        do {
          try LingSharedImageStore.consumePasteboardImportRequests()
          result(nil)
        } catch {
          result(
            FlutterError(
              code: "consume_pasteboard_request_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      case "ready":
        self.isFlutterReady = true
        if let arguments = self.takePendingAvailabilitySignalArguments() {
          result(arguments)
        } else {
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func handleOpenURLContexts(_ URLContexts: Set<UIOpenURLContext>) -> Bool {
    let didHandle = URLContexts.contains { context in
      let url = context.url
      guard url.scheme == "ling" && url.host == "share" else {
        return false
      }
      if Self.shouldImportPasteboard(from: url) {
        self.shouldImportPasteboardTextOnNextSignal = true
      }
      if Self.shouldAutoSend(from: url) {
        self.shouldAutoSendOnNextSignal = true
      }
      return true
    }
    if didHandle {
      signalSharedItemsAvailable()
    }
    return didHandle
  }

  func signalSharedItemsAvailable() {
    hasPendingAvailabilitySignal = true
    flushPendingAvailabilitySignal()
  }

  private func flushPendingAvailabilitySignal() {
    guard isFlutterReady && hasPendingAvailabilitySignal else {
      return
    }
    guard let arguments = takePendingAvailabilitySignalArguments() else {
      return
    }
    channel.invokeMethod("sharedItemsAvailable", arguments: arguments) { [weak self] _ in
      self?.hasPendingAvailabilitySignal = false
    }
  }

  private func takePendingAvailabilitySignalArguments() -> [String: Any]? {
    guard hasPendingAvailabilitySignal else {
      return nil
    }
    hasPendingAvailabilitySignal = false
    let arguments = Self.availabilityArguments(
      shouldImportPasteboardText: shouldImportPasteboardTextOnNextSignal,
      shouldAutoSend: shouldAutoSendOnNextSignal
    )
    shouldImportPasteboardTextOnNextSignal = false
    shouldAutoSendOnNextSignal = false
    return arguments
  }

  private static func shouldImportPasteboard(from url: URL) -> Bool {
    queryFlag(named: "pasteboard", in: url)
  }

  private static func shouldAutoSend(from url: URL) -> Bool {
    queryFlag(named: "send", in: url)
  }

  private static func queryFlag(named name: String, in url: URL) -> Bool {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?
      .contains { item in
        item.name == name && item.value == "1"
      } ?? false
  }

  private static func availabilityArguments(
    shouldImportPasteboardText transientPasteboardSignal: Bool = false,
    shouldAutoSend transientAutoSendSignal: Bool = false
  ) -> [String: Any] {
    let availability = try? LingSharedImageStore.pendingAvailability()
    return [
      "hasPendingFiles": availability?.hasPendingFiles == true,
      "shouldImportPasteboardText": transientPasteboardSignal ||
        availability?.shouldImportPasteboardText == true,
      "shouldAutoSend": transientAutoSendSignal
    ]
  }
}
