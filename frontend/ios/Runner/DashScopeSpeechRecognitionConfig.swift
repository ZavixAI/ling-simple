import Foundation

enum DashScopeSpeechRecognitionConfig {
  static let model = "qwen3-asr-flash-realtime"
  static let endpoint = "wss://dashscope.aliyuncs.com/api-ws/v1/realtime"

  static func recognitionURL() -> URL? {
    guard var components = URLComponents(string: endpoint) else {
      return nil
    }
    components.queryItems = [
      URLQueryItem(name: "model", value: model),
    ]
    return components.url
  }

  static func language(from locale: String) -> String {
    let normalized = locale
      .replacingOccurrences(of: "_", with: "-")
      .lowercased()
    if normalized.hasPrefix("zh-hk") ||
      normalized.hasPrefix("zh-mo") ||
      normalized.hasPrefix("zh-yue") ||
      normalized.hasPrefix("yue")
    {
      return "yue"
    }
    let supportedPrefixes = [
      "zh", "ja", "ko", "de", "ru", "fr", "pt", "ar", "it", "es", "hi", "id", "th",
      "tr", "uk", "vi", "cs", "da", "fi", "is", "ms", "no", "pl", "sv"
    ]
    for prefix in supportedPrefixes where normalized.hasPrefix(prefix) {
      return prefix
    }
    if normalized.hasPrefix("fil") || normalized.hasPrefix("tl") {
      return "fil"
    }
    return "en"
  }

  static func makeProtocolID() -> String {
    UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
  }
}
