import CoreLocation
import Flutter
import Foundation
import UIKit

private final class DeviceContextManager: NSObject, CLLocationManagerDelegate {
  static let shared = DeviceContextManager()

  private let locationManager = CLLocationManager()
  private let geocoder = CLGeocoder()
  private let backendUploader = DeviceContextBackendUploader()

  private var lastLocation: CLLocation?
  private var lastPlacemark: CLPlacemark?
  private var lastGeocodedLocation: CLLocation?
  private var pendingRefreshCompletions: [([String: Any]) -> Void] = []
  private var refreshTimeoutWorkItem: DispatchWorkItem?
  private var isRefreshingLocation = false

  private override init() {
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = kCLDistanceFilterNone
    locationManager.activityType = .otherNavigation
    locationManager.pausesLocationUpdatesAutomatically = true
  }

  func latestSnapshot() -> [String: Any] {
    buildSnapshot()
  }

  func permissionStateRaw() -> String {
    guard CLLocationManager.locationServicesEnabled() else {
      return "unsupported"
    }
    let authorizationStatus: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      authorizationStatus = locationManager.authorizationStatus
    } else {
      authorizationStatus = CLLocationManager.authorizationStatus()
    }
    switch authorizationStatus {
    case .authorizedAlways:
      return "authorized_always"
    case .authorizedWhenInUse:
      return "authorized_when_in_use"
    case .notDetermined:
      return "not_determined"
    case .restricted:
      return "restricted"
    case .denied:
      return "denied"
    @unknown default:
      return "unknown"
    }
  }

  func refreshContext(completion: @escaping ([String: Any]) -> Void) {
    guard CLLocationManager.locationServicesEnabled() else {
      completion(buildSnapshot())
      return
    }

    let authorizationStatus: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      authorizationStatus = locationManager.authorizationStatus
    } else {
      authorizationStatus = CLLocationManager.authorizationStatus()
    }

    switch authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      if UIApplication.shared.applicationState == .active {
        enqueueRefresh(completion)
        requestSingleLocation()
      } else {
        completion(buildSnapshot())
      }
    case .notDetermined:
      enqueueRefresh(completion)
      locationManager.requestWhenInUseAuthorization()
    case .restricted, .denied:
      completion(buildSnapshot())
    @unknown default:
      completion(buildSnapshot())
    }
  }

  func requestForegroundContext(completion: @escaping ([String: Any]) -> Void) {
    guard CLLocationManager.locationServicesEnabled() else {
      completion(buildSnapshot())
      return
    }

    let authorizationStatus: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      authorizationStatus = locationManager.authorizationStatus
    } else {
      authorizationStatus = CLLocationManager.authorizationStatus()
    }

    switch authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      if UIApplication.shared.applicationState == .active {
        enqueueRefresh(completion)
        requestSingleLocation()
      } else {
        completion(buildSnapshot())
      }
    case .notDetermined:
      enqueueRefresh(completion)
      locationManager.requestWhenInUseAuthorization()
    case .restricted, .denied:
      completion(buildSnapshot())
    @unknown default:
      completion(buildSnapshot())
    }
  }

  func configureBackend(apiBaseUrl: String, apiPrefix: String) {
    backendUploader.configureBackend(apiBaseUrl: apiBaseUrl, apiPrefix: apiPrefix)
  }

  func persistPushToken(_ token: String) {
    backendUploader.persistPushToken(token)
  }

  func handleBackgroundRefresh(
    userInfo: [AnyHashable: Any],
    completion: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    guard (userInfo["kind"] as? String) == "refresh_device_context" else {
      completion(.noData)
      return
    }

    refreshContext { [weak self] snapshot in
      self?.backendUploader.uploadSnapshot(snapshot) { success in
        completion(success ? .newData : .noData)
      }
    }
  }

  private func enqueueRefresh(_ completion: @escaping ([String: Any]) -> Void) {
    pendingRefreshCompletions.append(completion)
  }

  private func requestSingleLocation() {
    if isRefreshingLocation {
      return
    }
    isRefreshingLocation = true

    refreshTimeoutWorkItem?.cancel()
    let timeoutWorkItem = DispatchWorkItem { [weak self] in
      self?.finishRefresh()
    }
    refreshTimeoutWorkItem = timeoutWorkItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeoutWorkItem)

    DispatchQueue.main.async { [weak self] in
      self?.locationManager.requestLocation()
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    handleAuthorizationChange()
  }

  func locationManager(
    _ manager: CLLocationManager,
    didChangeAuthorization status: CLAuthorizationStatus
  ) {
    handleAuthorizationChange()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else {
      finishRefresh()
      return
    }
    guard location.horizontalAccuracy >= 0 else {
      finishRefresh()
      return
    }

    lastLocation = location
    reverseGeocodeIfNeeded(location) { [weak self] in
      self?.finishRefresh()
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("[Ling][iOS][DeviceContext] location update failed: \(error)")
    finishRefresh()
  }

  private func reverseGeocodeIfNeeded(
    _ location: CLLocation,
    completion: @escaping () -> Void
  ) {
    if let previous = lastGeocodedLocation, location.distance(from: previous) < 250,
      lastPlacemark != nil
    {
      completion()
      return
    }
    if geocoder.isGeocoding {
      geocoder.cancelGeocode()
    }
    lastGeocodedLocation = location
    geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
      if let error {
        print("[Ling][iOS][DeviceContext] reverse geocode failed: \(error)")
      }
      self?.lastPlacemark = placemarks?.first
      completion()
    }
  }

  private func finishRefresh() {
    isRefreshingLocation = false
    refreshTimeoutWorkItem?.cancel()
    refreshTimeoutWorkItem = nil
    completeRefresh(with: buildSnapshot())
  }

  private func handleAuthorizationChange() {
    guard !pendingRefreshCompletions.isEmpty else {
      return
    }

    let authorizationStatus: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      authorizationStatus = locationManager.authorizationStatus
    } else {
      authorizationStatus = CLLocationManager.authorizationStatus()
    }

    switch authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      if UIApplication.shared.applicationState == .active {
        requestSingleLocation()
      } else {
        finishRefresh()
      }
    case .restricted, .denied:
      finishRefresh()
    case .notDetermined:
      break
    @unknown default:
      finishRefresh()
    }
  }

  private func completeRefresh(with snapshot: [String: Any]) {
    let completions = pendingRefreshCompletions
    pendingRefreshCompletions.removeAll()
    for completion in completions {
      completion(snapshot)
    }
  }

  private func buildSnapshot() -> [String: Any] {
    DeviceContextSnapshotBuilder.buildSnapshot(
      location: lastLocation,
      placemark: lastPlacemark
    )
  }
}

final class DeviceContextChannel: NSObject {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "ling/device_context", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getLatestContext":
      let args = call.arguments as? [String: Any]
      if (args?["startTracking"] as? Bool) == true {
        DeviceContextManager.shared.refreshContext { snapshot in
          DispatchQueue.main.async {
            result(snapshot)
          }
        }
        return
      }
      result(DeviceContextManager.shared.latestSnapshot())
    case "getLocationPermissionState":
      result(DeviceContextManager.shared.permissionStateRaw())
    case "requestForegroundLocationContext":
      DeviceContextManager.shared.requestForegroundContext { snapshot in
        DispatchQueue.main.async {
          result(snapshot)
        }
      }
    case "openSystemSettings":
      DispatchQueue.main.async {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          result(nil)
          return
        }
        UIApplication.shared.open(url, options: [:]) { _ in
          result(nil)
        }
      }
    case "startTracking":
      DeviceContextManager.shared.refreshContext { snapshot in
        DispatchQueue.main.async {
          result(snapshot)
        }
      }
    case "stopTracking":
      result(nil)
    case "configureBackend":
      let args = call.arguments as? [String: Any]
      let apiBaseUrl =
        (args?["apiBaseUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let apiPrefix =
        (args?["apiPrefix"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      DeviceContextManager.shared.configureBackend(
        apiBaseUrl: apiBaseUrl,
        apiPrefix: apiPrefix
      )
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func persistPushToken(_ token: String) {
    DeviceContextManager.shared.persistPushToken(token)
  }

  static func handleBackgroundRefresh(
    userInfo: [AnyHashable: Any],
    completion: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    DeviceContextManager.shared.handleBackgroundRefresh(
      userInfo: userInfo,
      completion: completion
    )
  }
}
