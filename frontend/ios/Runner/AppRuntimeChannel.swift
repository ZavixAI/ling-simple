import Flutter
import UIKit

final class AppRuntimeChannel {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "ling/app_runtime",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSimulator":
        #if targetEnvironment(simulator)
          result(true)
        #else
          result(false)
        #endif
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
