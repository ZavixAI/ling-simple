import Flutter
import UIKit

final class NativeShareChannel: NSObject {
  private let channel: FlutterMethodChannel
  private weak var presenter: UIViewController?
  private var pendingSharedFileURLs: [URL] = []

  init(messenger: FlutterBinaryMessenger, presenter: UIViewController) {
    self.presenter = presenter
    channel = FlutterMethodChannel(
      name: "ling/native_share",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "shareText":
      shareText(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func shareText(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(
        FlutterError(
          code: "invalid_args",
          message: "Missing share arguments.",
          details: nil
        )
      )
      return
    }
    let text = (arguments["text"] as? String ?? "").trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    guard !text.isEmpty else {
      result(
        FlutterError(
          code: "invalid_args",
          message: "Share text is required.",
          details: nil
        )
      )
      return
    }
    guard let presenter = presenter else {
      result(
        FlutterError(
          code: "presentation_unavailable",
          message: "Unable to show the share sheet.",
          details: nil
        )
      )
      return
    }

    let activityController = UIActivityViewController(
      activityItems: shareItems(
        text: text,
        images: arguments["images"] as? [[String: Any]]
      ),
      applicationActivities: nil
    )
    if let popover = activityController.popoverPresentationController {
      popover.sourceView = presenter.view
      popover.sourceRect = CGRect(
        x: presenter.view.bounds.midX,
        y: presenter.view.bounds.midY,
        width: 1,
        height: 1
      )
      popover.permittedArrowDirections = []
    }
    activityController.completionWithItemsHandler = { _, completed, _, error in
      DispatchQueue.main.async {
        self.cleanupPendingSharedFiles()
        if let error = error {
          result(
            FlutterError(
              code: "share_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }
        result([
          "status": completed ? "success" : "cancelled",
          "message": ""
        ])
      }
    }
    presenter.present(activityController, animated: true)
  }

  private func shareItems(text: String, images: [[String: Any]]?) -> [Any] {
    var items: [Any] = [text]
    guard let images else {
      return items
    }
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ling_native_share", isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
    } catch {
      return items
    }

    for (index, image) in images.enumerated() {
      guard
        let typedData = image["bytes"] as? FlutterStandardTypedData,
        !typedData.data.isEmpty
      else {
        continue
      }
      let filename = safeFilename(image["filename"] as? String, index: index)
      let fileURL = uniqueFileURL(in: directory, filename: filename)
      do {
        try typedData.data.write(to: fileURL, options: .atomic)
        pendingSharedFileURLs.append(fileURL)
        items.append(fileURL)
      } catch {
        continue
      }
    }
    return items
  }

  private func safeFilename(_ value: String?, index: Int) -> String {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let fallback = trimmed.isEmpty ? "ling-moment-\(index + 1).png" : trimmed
    let invalid = CharacterSet(charactersIn: "/\\:")
      .union(.controlCharacters)
    return fallback
      .components(separatedBy: invalid)
      .joined(separator: "-")
  }

  private func uniqueFileURL(in directory: URL, filename: String) -> URL {
    let baseURL = directory.appendingPathComponent(filename)
    if !FileManager.default.fileExists(atPath: baseURL.path) {
      return baseURL
    }
    let baseName = (filename as NSString).deletingPathExtension
    let extensionName = (filename as NSString).pathExtension
    for index in 1...999 {
      let candidateName = extensionName.isEmpty
        ? "\(baseName)-\(index)"
        : "\(baseName)-\(index).\(extensionName)"
      let candidate = directory.appendingPathComponent(candidateName)
      if !FileManager.default.fileExists(atPath: candidate.path) {
        return candidate
      }
    }
    return directory.appendingPathComponent(UUID().uuidString + "-" + filename)
  }

  private func cleanupPendingSharedFiles() {
    let urls = pendingSharedFileURLs
    pendingSharedFileURLs.removeAll()
    for url in urls {
      try? FileManager.default.removeItem(at: url)
    }
  }
}
