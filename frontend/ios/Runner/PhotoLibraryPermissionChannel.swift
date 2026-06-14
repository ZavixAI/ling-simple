import Flutter
import Photos
import UIKit

final class PhotoLibraryPermissionChannel {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "ling/photo_library_permission",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPermissionState":
      result(Self.permissionStateString())
    case "requestPermission":
      requestPermission(result: result)
    case "openSystemSettings":
      openSystemSettings(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestPermission(result: @escaping FlutterResult) {
    if #available(iOS 14, *) {
      let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
      switch status {
      case .authorized, .limited:
        result("granted")
      case .denied:
        result("denied")
      case .restricted:
        result("restricted")
      case .notDetermined:
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { nextStatus in
          DispatchQueue.main.async {
            result(Self.permissionStateString(nextStatus))
          }
        }
      @unknown default:
        result("restricted")
      }
      return
    }

    let status = PHPhotoLibrary.authorizationStatus()
    switch status {
    case .authorized:
      result("granted")
    case .denied:
      result("denied")
    case .restricted:
      result("restricted")
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization { nextStatus in
        DispatchQueue.main.async {
          result(Self.permissionStateString(nextStatus))
        }
      }
    @unknown default:
      result("restricted")
    }
  }

  private func openSystemSettings(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(nil)
        return
      }
      UIApplication.shared.open(url, options: [:]) { _ in
        result(nil)
      }
    }
  }

  private static func permissionStateString() -> String {
    if #available(iOS 14, *) {
      return permissionStateString(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }
    return permissionStateString(PHPhotoLibrary.authorizationStatus())
  }

  private static func permissionStateString(_ status: PHAuthorizationStatus) -> String {
    if #available(iOS 14, *), status == .limited {
      return "granted"
    }
    switch status {
    case .authorized:
      return "granted"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    case .notDetermined:
      return "not_determined"
    @unknown default:
      return "restricted"
    }
  }
}
