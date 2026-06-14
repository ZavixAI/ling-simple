import Foundation
import Flutter

enum DashScopeAudioPreviewLoader {
  static func previewURL(from call: FlutterMethodCall) -> URL? {
    guard let args = call.arguments as? [String: Any],
      let path = args["path"] as? String
    else {
      return nil
    }
    let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalizedPath.isEmpty {
      return nil
    }
    if let url = URL(string: normalizedPath), url.scheme != nil {
      return url
    }
    return URL(fileURLWithPath: normalizedPath)
  }

  static func isRemotePreviewURL(_ url: URL) -> Bool {
    let scheme = url.scheme?.lowercased()
    return scheme == "http" || scheme == "https"
  }

  static func loadRemotePreviewData(
    url: URL,
    completion: @escaping (Result<Data, Error>) -> Void
  ) {
    URLSession.shared.dataTask(with: url) { data, response, error in
      DispatchQueue.main.async {
        if let error {
          completion(.failure(error))
          return
        }
        if let httpResponse = response as? HTTPURLResponse,
          !(200..<300).contains(httpResponse.statusCode)
        {
          completion(
            .failure(
              NSError(
                domain: "LingAudioPreview",
                code: httpResponse.statusCode,
                userInfo: [
                  NSLocalizedDescriptionKey: "Audio preview download failed."
                ]
              )
            )
          )
          return
        }
        completion(.success(data ?? Data()))
      }
    }.resume()
  }
}
