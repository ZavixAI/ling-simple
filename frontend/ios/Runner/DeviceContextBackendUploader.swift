import Foundation

enum DeviceContextDefaultsKey {
  static let apiBaseUrl = "ling.device_context.api_base_url"
  static let apiPrefix = "ling.device_context.api_prefix"
  static let pushToken = "ling.device_context.push_token"
  static let pushDeviceId = "ling.push_device_id"
}

final class DeviceContextBackendUploader {
  private let defaults: UserDefaults
  private let session: URLSession

  init(
    defaults: UserDefaults = .standard,
    session: URLSession = URLSession(configuration: .ephemeral)
  ) {
    self.defaults = defaults
    self.session = session
  }

  func configureBackend(apiBaseUrl: String, apiPrefix: String) {
    defaults.set(apiBaseUrl, forKey: DeviceContextDefaultsKey.apiBaseUrl)
    defaults.set(apiPrefix, forKey: DeviceContextDefaultsKey.apiPrefix)
  }

  func persistPushToken(_ token: String) {
    defaults.set(token, forKey: DeviceContextDefaultsKey.pushToken)
  }

  func uploadSnapshot(
    _ snapshot: [String: Any],
    completion: @escaping (Bool) -> Void
  ) {
    let deviceID =
      (defaults.string(forKey: DeviceContextDefaultsKey.pushDeviceId) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let pushToken =
      (defaults.string(forKey: DeviceContextDefaultsKey.pushToken) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !deviceID.isEmpty, !pushToken.isEmpty else {
      completion(false)
      return
    }

    let apiBaseUrl =
      (defaults.string(forKey: DeviceContextDefaultsKey.apiBaseUrl) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let apiPrefix =
      (defaults.string(forKey: DeviceContextDefaultsKey.apiPrefix) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedBaseUrl = apiBaseUrl.isEmpty ? "https://api.withling.top" : apiBaseUrl
    let normalizedPrefix = normalizeApiPrefix(apiPrefix.isEmpty ? "/ling-api" : apiPrefix)
    let endpoint = "\(normalizedBaseUrl)\(normalizedPrefix)/push-devices/context"
    guard let url = URL(string: endpoint) else {
      completion(false)
      return
    }

    var body = snapshot
    body["device_id"] = deviceID
    body["push_token"] = pushToken

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 12
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
    } catch {
      print("[Ling][iOS][DeviceContext] encode upload failed: \(error)")
      completion(false)
      return
    }

    let task = session.dataTask(with: request) { _, response, error in
      if let error {
        print("[Ling][iOS][DeviceContext] upload snapshot failed: \(error)")
        completion(false)
        return
      }
      let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
      completion((200..<300).contains(statusCode))
    }
    task.resume()
  }

  private func normalizeApiPrefix(_ value: String) -> String {
    if value.isEmpty {
      return ""
    }
    if value.hasPrefix("/") {
      if value.count > 1 && value.hasSuffix("/") {
        return String(value.dropLast())
      }
      return value
    }
    return "/\(value)"
  }
}
