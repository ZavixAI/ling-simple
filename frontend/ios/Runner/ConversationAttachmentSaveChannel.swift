import Flutter
import Photos
import UIKit

final class ConversationAttachmentSaveChannel: NSObject {
  private let channel: FlutterMethodChannel
  private weak var presenter: UIViewController?
  private var pendingSharedFileURLs: [URL] = []

  init(messenger: FlutterBinaryMessenger, presenter: UIViewController) {
    channel = FlutterMethodChannel(
      name: "ling/conversation_attachment_save",
      binaryMessenger: messenger
    )
    self.presenter = presenter
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "saveImageToLocal":
      saveImageToLocal(call: call, result: result)
    case "saveFileToLocal":
      saveFileToLocal(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func saveImageToLocal(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let typedData = arguments["bytes"] as? FlutterStandardTypedData,
      !typedData.data.isEmpty
    else {
      result(
        FlutterError(
          code: "invalid_args",
          message: "Image bytes are required.",
          details: nil
        )
      )
      return
    }

    requestPhotoLibraryAccess { authorized in
      guard authorized else {
        result(
          FlutterError(
            code: "photo_library_denied",
            message: "Photo library access was denied.",
            details: nil
          )
        )
        return
      }

      PHPhotoLibrary.shared().performChanges({
        let creationRequest = PHAssetCreationRequest.forAsset()
        creationRequest.addResource(with: .photo, data: typedData.data, options: nil)
      }, completionHandler: { success, error in
        DispatchQueue.main.async {
          if success {
            result(nil)
            return
          }
          result(
            FlutterError(
              code: "save_failed",
              message: error?.localizedDescription ?? "Unable to save the image.",
              details: nil
            )
          )
        }
      })
    }
  }

  private func saveFileToLocal(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let typedData = arguments["bytes"] as? FlutterStandardTypedData,
      !typedData.data.isEmpty
    else {
      result(
        FlutterError(
          code: "invalid_args",
          message: "File bytes are required.",
          details: nil
        )
      )
      return
    }

    let filename = safeFilename(arguments["filename"] as? String)
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ling_agent_file_downloads", isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      let fileURL = uniqueFileURL(in: directory, filename: filename)
      try typedData.data.write(to: fileURL, options: .atomic)
      presentFileExport(fileURL: fileURL, result: result)
    } catch {
      result(
        FlutterError(
          code: "save_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func presentFileExport(fileURL: URL, result: @escaping FlutterResult) {
    guard let presenter = presenter else {
      result(
        FlutterError(
          code: "presentation_unavailable",
          message: "Unable to show the file save sheet.",
          details: nil
        )
      )
      return
    }

    pendingSharedFileURLs.append(fileURL)
    let activityController = UIActivityViewController(
      activityItems: [fileURL],
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
    activityController.completionWithItemsHandler = { [weak self] _, completed, _, error in
      DispatchQueue.main.async {
        self?.pendingSharedFileURLs.removeAll { $0 == fileURL }
        if let error = error {
          result(
            FlutterError(
              code: "save_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }
        if completed {
          result(nil)
          return
        }
        result(
          FlutterError(
            code: "save_cancelled",
            message: "File save was cancelled.",
            details: nil
          )
        )
      }
    }
    presenter.present(activityController, animated: true)
  }

  private func safeFilename(_ value: String?) -> String {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let fallback = trimmed.isEmpty ? "ling-file" : trimmed
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

  private func requestPhotoLibraryAccess(completion: @escaping (Bool) -> Void) {
    if #available(iOS 14, *) {
      let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
      switch status {
      case .authorized, .limited:
        completion(true)
      case .denied, .restricted:
        completion(false)
      case .notDetermined:
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { nextStatus in
          DispatchQueue.main.async {
            completion(nextStatus == .authorized || nextStatus == .limited)
          }
        }
      @unknown default:
        completion(false)
      }
      return
    }

    let status = PHPhotoLibrary.authorizationStatus()
    switch status {
    case .authorized:
      completion(true)
    case .denied, .restricted:
      completion(false)
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization { nextStatus in
        DispatchQueue.main.async {
          completion(nextStatus == .authorized)
        }
      }
    @unknown default:
      completion(false)
    }
  }
}
