import Flutter
import UIKit

final class AppleCalendarChannel: NSObject {
  private let store: AppleCalendarStore
  private let channel: FlutterMethodChannel
  private let eventStoreQueue = DispatchQueue(
    label: "ling.apple_calendar.event_store",
    qos: .userInitiated
  )

  init(messenger: FlutterBinaryMessenger, store: AppleCalendarStore = AppleCalendarStore()) {
    self.store = store
    channel = FlutterMethodChannel(name: "ling/apple_calendar", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler(handle)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPermissionState":
      result(store.permissionStateRaw())
    case "requestPermission":
      requestPermission(result: result)
    case "openSystemSettings":
      openSystemSettings(result: result)
    case "listCalendars":
      performEventStoreRead(result: result) {
        self.store.listCalendars()
      }
    case "listEvents":
      listEvents(call: call, result: result)
    case "createEvent":
      createEvent(call: call, result: result)
    case "updateEvent":
      updateEvent(call: call, result: result)
    case "deleteEvent":
      deleteEvent(call: call, result: result)
    case "deleteManagedEvents":
      deleteManagedEvents(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestPermission(result: @escaping FlutterResult) {
    eventStoreQueue.async {
      self.store.requestPermission { outcome in
        DispatchQueue.main.async {
          switch outcome {
          case .success(let state):
            result(state)
          case .failure(let error):
            result(
              FlutterError(
                code: "calendar_permission_error",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        }
      }
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

  private func listEvents(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let startAt = AppleCalendarDateParser.parseFlexibleDate(args["startAt"]),
      let endAt = AppleCalendarDateParser.parseFlexibleDate(args["endAt"])
    else {
      result(FlutterError(code: "invalid_args", message: "startAt and endAt are required", details: nil))
      return
    }
    performEventStoreRead(result: result) {
      self.store.listEvents(startAt: startAt, endAt: endAt)
    }
  }

  private func createEvent(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "invalid_args", message: "arguments are required", details: nil))
      return
    }
    eventStoreQueue.async {
      do {
        let payload = try self.store.createEvent(args: args).payload
        DispatchQueue.main.async {
          result(payload)
        }
      } catch {
        DispatchQueue.main.async {
          result(self.flutterError(code: "create_failed", error: error))
        }
      }
    }
  }

  private func updateEvent(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "not_found", message: "eventIdentifier is invalid", details: nil))
      return
    }
    eventStoreQueue.async {
      do {
        let payload = try self.store.updateEvent(args: args).payload
        DispatchQueue.main.async {
          result(payload)
        }
      } catch AppleCalendarStoreError.notFound {
        DispatchQueue.main.async {
          result(FlutterError(code: "not_found", message: "eventIdentifier is invalid", details: nil))
        }
      } catch {
        DispatchQueue.main.async {
          result(self.flutterError(code: "update_failed", error: error))
        }
      }
    }
  }

  private func deleteEvent(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(nil)
      return
    }
    eventStoreQueue.async {
      do {
        try self.store.deleteEvent(args: args)
        DispatchQueue.main.async {
          result(nil)
        }
      } catch {
        DispatchQueue.main.async {
          result(self.flutterError(code: "delete_failed", error: error))
        }
      }
    }
  }

  private func deleteManagedEvents(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(nil)
      return
    }
    let items = (args["items"] as? [Any] ?? []).compactMap { $0 as? [String: Any] }
    guard !items.isEmpty else {
      result(nil)
      return
    }
    eventStoreQueue.async {
      do {
        try self.store.deleteManagedEvents(items: items)
        DispatchQueue.main.async {
          result(nil)
        }
      } catch let error as AppleCalendarStoreError {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: error.flutterCode,
              message: error.localizedDescription,
              details: error.details
            )
          )
        }
      } catch {
        DispatchQueue.main.async {
          result(self.flutterError(code: "delete_managed_failed", error: error))
        }
      }
    }
  }

  private func performEventStoreRead<T>(
    result: @escaping FlutterResult,
    operation: @escaping () -> T
  ) {
    eventStoreQueue.async {
      let payload = operation()
      DispatchQueue.main.async {
        result(payload)
      }
    }
  }

  private func flutterError(code: String, error: Error) -> FlutterError {
    FlutterError(code: code, message: error.localizedDescription, details: nil)
  }
}
