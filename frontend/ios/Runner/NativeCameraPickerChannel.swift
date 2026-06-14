import AVFoundation
import Flutter
import UIKit

final class NativeCameraPickerChannel: NSObject, UIImagePickerControllerDelegate,
  UINavigationControllerDelegate
{
  private let channel: FlutterMethodChannel
  private weak var presenter: UIViewController?
  private var pendingResult: FlutterResult?
  private var pendingMaxWidth: CGFloat?
  private var pendingCompressionQuality: CGFloat = 0.88

  init(messenger: FlutterBinaryMessenger, presenter: UIViewController) {
    self.presenter = presenter
    channel = FlutterMethodChannel(
      name: "ling/native_camera_picker",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickImage":
      pickImage(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func pickImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard pendingResult == nil else {
      result(FlutterError(code: "busy", message: "Camera picker is already active.", details: nil))
      return
    }
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      result(FlutterError(code: "unavailable", message: "Camera is not available.", details: nil))
      return
    }
    guard let presenter = topPresenter() else {
      result(
        FlutterError(
          code: "no_presenter",
          message: "Unable to find a view controller to present the camera.",
          details: nil
        )
      )
      return
    }

    let args = call.arguments as? [String: Any]
    pendingMaxWidth = (args?["maxWidth"] as? NSNumber).map { CGFloat(truncating: $0) }
    if let quality = (args?["imageQuality"] as? NSNumber)?.doubleValue {
      pendingCompressionQuality = max(0.1, min(CGFloat(quality) / 100.0, 1.0))
    } else {
      pendingCompressionQuality = 0.88
    }
    pendingResult = result

    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      presentCamera(from: presenter)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        DispatchQueue.main.async {
          guard let self else {
            result(
              FlutterError(
                code: "camera_picker_deallocated",
                message: "Camera picker was released before permission resolved.",
                details: nil
              )
            )
            return
          }
          if granted {
            self.presentCamera(from: presenter)
          } else {
            self.finishPendingRequest(
              with: FlutterError(
                code: "camera_denied",
                message: "Camera access was denied.",
                details: nil
              )
            )
          }
        }
      }
    case .denied, .restricted:
      finishPendingRequest(
        with: FlutterError(
          code: "camera_denied",
          message: "Camera access was denied.",
          details: nil
        )
      )
    @unknown default:
      finishPendingRequest(
        with: FlutterError(
          code: "camera_denied",
          message: "Camera access is unavailable.",
          details: nil
        )
      )
    }
  }

  private func presentCamera(from presenter: UIViewController) {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.cameraCaptureMode = .photo
    picker.allowsEditing = false
    picker.modalPresentationStyle = .fullScreen
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  private func topPresenter() -> UIViewController? {
    var controller = presenter

    while let current = controller {
      if let navigation = current as? UINavigationController {
        controller = navigation.visibleViewController ?? navigation
        continue
      }
      if let tabBar = current as? UITabBarController {
        controller = tabBar.selectedViewController ?? tabBar
        continue
      }
      if let presented = current.presentedViewController {
        controller = presented
        continue
      }
      return current
    }

    return nil
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true) { [weak self] in
      self?.finishPendingRequest(with: nil)
    }
  }

  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    let pending = takePendingRequest()
    picker.dismiss(animated: true) { [weak self] in
      guard let pending else {
        return
      }
      guard let image = info[.originalImage] as? UIImage else {
        pending.result(
          FlutterError(
            code: "capture_failed",
            message: "Camera did not return an image.",
            details: nil
          )
        )
        return
      }
      self?.persistCapturedImage(
        image,
        maxWidth: pending.maxWidth,
        compressionQuality: pending.compressionQuality,
        result: pending.result
      )
    }
  }

  private func persistCapturedImage(
    _ image: UIImage,
    maxWidth: CGFloat?,
    compressionQuality: CGFloat,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      let normalized = Self.normalizedImage(from: image)
      let outputImage = Self.resizedImageIfNeeded(normalized, maxWidth: maxWidth)
      guard let data = outputImage.jpegData(compressionQuality: compressionQuality) else {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "encode_failed",
              message: "Unable to encode captured image.",
              details: nil
            )
          )
        }
        return
      }

      let fileUrl = FileManager.default.temporaryDirectory.appendingPathComponent(
        "ling_camera_\(UUID().uuidString).jpg"
      )
      do {
        try data.write(to: fileUrl, options: .atomic)
        DispatchQueue.main.async {
          result(fileUrl.path)
        }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "write_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }

  private func finishPendingRequest(with value: Any?) {
    guard let result = pendingResult else {
      clearPendingRequest()
      return
    }
    clearPendingRequest()
    result(value)
  }

  private func takePendingRequest() -> (
    result: FlutterResult, maxWidth: CGFloat?, compressionQuality: CGFloat
  )? {
    guard let result = pendingResult else {
      return nil
    }
    let pending = (
      result: result,
      maxWidth: pendingMaxWidth,
      compressionQuality: pendingCompressionQuality
    )
    clearPendingRequest()
    return pending
  }

  private func clearPendingRequest() {
    pendingResult = nil
    pendingMaxWidth = nil
    pendingCompressionQuality = 0.88
  }

  private static func resizedImageIfNeeded(_ image: UIImage, maxWidth: CGFloat?) -> UIImage {
    guard let maxWidth, maxWidth > 0, image.size.width > maxWidth else {
      return image
    }
    let scale = maxWidth / image.size.width
    let targetSize = CGSize(width: maxWidth, height: image.size.height * scale)
    let rendererFormat = UIGraphicsImageRendererFormat.default()
    rendererFormat.opaque = true
    rendererFormat.scale = 1
    return UIGraphicsImageRenderer(size: targetSize, format: rendererFormat).image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }

  private static func normalizedImage(from image: UIImage) -> UIImage {
    guard image.imageOrientation != .up else {
      return image
    }
    let rendererFormat = UIGraphicsImageRendererFormat.default()
    rendererFormat.opaque = true
    rendererFormat.scale = image.scale
    return UIGraphicsImageRenderer(size: image.size, format: rendererFormat).image { _ in
      image.draw(in: CGRect(origin: .zero, size: image.size))
    }
  }
}
