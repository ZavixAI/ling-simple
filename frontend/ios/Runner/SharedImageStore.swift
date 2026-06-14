import Foundation

struct LingSharedImageFile {
  let shareId: String
  let path: String
  let filename: String
}

struct LingSharedItemsAvailability {
  let hasPendingFiles: Bool
  let shouldImportPasteboardText: Bool
}

enum LingSharedImageStore {
  private static let rootDirectoryName = "SharedImages"
  private static let manifestDirectoryName = "Manifests"
  private static let filesDirectoryName = "Files"
  private static let pasteboardRequestDirectoryName = "PasteboardRequests"

  static var appGroupIdentifier: String? {
    Bundle.main.object(forInfoDictionaryKey: "LingAppGroupIdentifier") as? String
  }

  static func createShare(files: [(filename: String, data: Data)]) throws -> String {
    let shareId = UUID().uuidString
    let rootURL = try rootDirectoryURL()
    let filesURL = rootURL
      .appendingPathComponent(filesDirectoryName, isDirectory: true)
      .appendingPathComponent(shareId, isDirectory: true)
    let manifestsURL = rootURL.appendingPathComponent(manifestDirectoryName, isDirectory: true)
    try FileManager.default.createDirectory(
      at: filesURL,
      withIntermediateDirectories: true,
      attributes: nil
    )
    try FileManager.default.createDirectory(
      at: manifestsURL,
      withIntermediateDirectories: true,
      attributes: nil
    )

    let manifestFiles = try files.enumerated().map { index, file in
      let filename = safeFilename(file.filename, fallback: "shared-image-\(index + 1).jpg")
      let fileURL = uniqueFileURL(in: filesURL, filename: filename)
      try file.data.write(to: fileURL, options: .atomic)
      return [
        "path": fileURL.path,
        "filename": fileURL.lastPathComponent
      ]
    }
    let manifest: [String: Any] = [
      "shareId": shareId,
      "createdAt": ISO8601DateFormatter().string(from: Date()),
      "files": manifestFiles
    ]
    let manifestData = try JSONSerialization.data(
      withJSONObject: manifest,
      options: [.prettyPrinted, .sortedKeys]
    )
    try manifestData.write(
      to: manifestURL(for: shareId, manifestsURL: manifestsURL),
      options: .atomic
    )
    return shareId
  }

  static func createPasteboardImportRequest() throws -> String {
    let requestId = UUID().uuidString
    let requestsURL = try pasteboardRequestsDirectoryURL()
    let request: [String: Any] = [
      "requestId": requestId,
      "createdAt": ISO8601DateFormatter().string(from: Date())
    ]
    let data = try JSONSerialization.data(
      withJSONObject: request,
      options: [.prettyPrinted, .sortedKeys]
    )
    try data.write(
      to: requestsURL.appendingPathComponent("\(requestId).json", isDirectory: false),
      options: .atomic
    )
    return requestId
  }

  static func discardShare(shareId: String) throws {
    let normalizedShareId = safeFilename(shareId, fallback: "")
    guard !normalizedShareId.isEmpty else {
      return
    }
    let rootURL = try rootDirectoryURL()
    let manifestURL = rootURL
      .appendingPathComponent(manifestDirectoryName, isDirectory: true)
      .appendingPathComponent("\(normalizedShareId).json", isDirectory: false)
    let filesURL = rootURL
      .appendingPathComponent(filesDirectoryName, isDirectory: true)
      .appendingPathComponent(normalizedShareId, isDirectory: true)
    try? FileManager.default.removeItem(at: manifestURL)
    try? FileManager.default.removeItem(at: filesURL)
  }

  static func discardPasteboardImportRequest(requestId: String) throws {
    let normalizedRequestId = safeFilename(requestId, fallback: "")
    guard !normalizedRequestId.isEmpty else {
      return
    }
    let requestURL = try pasteboardRequestsDirectoryURL()
      .appendingPathComponent("\(normalizedRequestId).json", isDirectory: false)
    try? FileManager.default.removeItem(at: requestURL)
  }

  static func discardAllPendingItems() throws {
    let rootURL = try rootDirectoryURL()
    let manifestsURL = rootURL.appendingPathComponent(manifestDirectoryName, isDirectory: true)
    let filesURL = rootURL.appendingPathComponent(filesDirectoryName, isDirectory: true)
    let requestsURL = rootURL.appendingPathComponent(pasteboardRequestDirectoryName, isDirectory: true)
    try? FileManager.default.removeItem(at: manifestsURL)
    try? FileManager.default.removeItem(at: filesURL)
    try? FileManager.default.removeItem(at: requestsURL)
  }

  static func pendingAvailability() throws -> LingSharedItemsAvailability {
    let files = try pendingFiles()
    let hasPendingFiles = !files.isEmpty
    let shouldImportPasteboardText = try hasPendingPasteboardImportRequests()
    return LingSharedItemsAvailability(
      hasPendingFiles: hasPendingFiles,
      shouldImportPasteboardText: shouldImportPasteboardText
    )
  }

  static func pendingFiles() throws -> [LingSharedImageFile] {
    let manifestsURL = try rootDirectoryURL()
      .appendingPathComponent(manifestDirectoryName, isDirectory: true)
    guard let manifestURLs = try? FileManager.default.contentsOfDirectory(
      at: manifestsURL,
      includingPropertiesForKeys: [.creationDateKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    return manifestURLs
      .filter { $0.pathExtension == "json" }
      .sorted { left, right in
        let leftDate = creationDate(for: left) ?? .distantPast
        let rightDate = creationDate(for: right) ?? .distantPast
        return leftDate < rightDate
      }
      .flatMap { files(inManifestURL: $0) }
  }

  static func consume(paths: [String]) throws {
    let normalizedPaths = Set(paths.map { URL(fileURLWithPath: $0).standardizedFileURL.path })
    if normalizedPaths.isEmpty {
      return
    }
    let rootURL = try rootDirectoryURL()
    let manifestsURL = rootURL.appendingPathComponent(manifestDirectoryName, isDirectory: true)
    let manifestURLs = (try? FileManager.default.contentsOfDirectory(
      at: manifestsURL,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )) ?? []

    for manifestURL in manifestURLs where manifestURL.pathExtension == "json" {
      let files = files(inManifestURL: manifestURL)
      let consumed = files.filter { normalizedPaths.contains(URL(fileURLWithPath: $0.path).standardizedFileURL.path) }
      guard !consumed.isEmpty else {
        continue
      }
      for file in consumed {
        try? FileManager.default.removeItem(atPath: file.path)
      }
      let remaining = files.filter { !normalizedPaths.contains(URL(fileURLWithPath: $0.path).standardizedFileURL.path) }
      if remaining.isEmpty {
        try? FileManager.default.removeItem(at: manifestURL)
        let shareDirectory = rootURL
          .appendingPathComponent(filesDirectoryName, isDirectory: true)
          .appendingPathComponent(files.first?.shareId ?? "", isDirectory: true)
        try? FileManager.default.removeItem(at: shareDirectory)
      } else {
        let manifest: [String: Any] = [
          "shareId": remaining.first?.shareId ?? manifestURL.deletingPathExtension().lastPathComponent,
          "updatedAt": ISO8601DateFormatter().string(from: Date()),
          "files": remaining.map { ["path": $0.path, "filename": $0.filename] }
        ]
        let data = try JSONSerialization.data(
          withJSONObject: manifest,
          options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: manifestURL, options: .atomic)
      }
    }
  }

  static func consumePasteboardImportRequests() throws {
    let requestsURL = try pasteboardRequestsDirectoryURL()
    let requestURLs = (try? FileManager.default.contentsOfDirectory(
      at: requestsURL,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )) ?? []
    for requestURL in requestURLs where requestURL.pathExtension == "json" {
      try? FileManager.default.removeItem(at: requestURL)
    }
  }

  private static func rootDirectoryURL() throws -> URL {
    guard
      let appGroupIdentifier,
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupIdentifier
      )
    else {
      throw NSError(
        domain: "LingSharedImageStore",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "App Group container is unavailable."]
      )
    }
    let rootURL = containerURL.appendingPathComponent(rootDirectoryName, isDirectory: true)
    try FileManager.default.createDirectory(
      at: rootURL,
      withIntermediateDirectories: true,
      attributes: nil
    )
    return rootURL
  }

  private static func pasteboardRequestsDirectoryURL() throws -> URL {
    let requestsURL = try rootDirectoryURL()
      .appendingPathComponent(pasteboardRequestDirectoryName, isDirectory: true)
    try FileManager.default.createDirectory(
      at: requestsURL,
      withIntermediateDirectories: true,
      attributes: nil
    )
    return requestsURL
  }

  private static func hasPendingPasteboardImportRequests() throws -> Bool {
    let requestsURL = try pasteboardRequestsDirectoryURL()
    let requestURLs = (try? FileManager.default.contentsOfDirectory(
      at: requestsURL,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )) ?? []
    return requestURLs.contains { $0.pathExtension == "json" }
  }

  private static func manifestURL(for shareId: String, manifestsURL: URL) -> URL {
    manifestsURL.appendingPathComponent("\(shareId).json", isDirectory: false)
  }

  private static func files(inManifestURL url: URL) -> [LingSharedImageFile] {
    guard
      let data = try? Data(contentsOf: url),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let files = object["files"] as? [[String: Any]]
    else {
      return []
    }
    let shareId = (object["shareId"] as? String) ?? url.deletingPathExtension().lastPathComponent
    return files.compactMap { file in
      guard let path = file["path"] as? String else {
        return nil
      }
      let filename = (file["filename"] as? String) ?? URL(fileURLWithPath: path).lastPathComponent
      guard FileManager.default.fileExists(atPath: path) else {
        return nil
      }
      return LingSharedImageFile(shareId: shareId, path: path, filename: filename)
    }
  }

  private static func creationDate(for url: URL) -> Date? {
    (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
  }

  private static func safeFilename(_ value: String, fallback: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let filename = trimmed.isEmpty ? fallback : trimmed
    let invalid = CharacterSet(charactersIn: "/\\:")
      .union(.controlCharacters)
    let cleanedScalars = filename.unicodeScalars.map { scalar in
      invalid.contains(scalar) ? "_" : String(scalar)
    }
    let cleaned = cleanedScalars.joined()
    return cleaned.isEmpty ? fallback : cleaned
  }

  private static func uniqueFileURL(in directory: URL, filename: String) -> URL {
    let baseURL = directory.appendingPathComponent(filename, isDirectory: false)
    if !FileManager.default.fileExists(atPath: baseURL.path) {
      return baseURL
    }
    let extensionName = baseURL.pathExtension
    let baseName = baseURL.deletingPathExtension().lastPathComponent
    for index in 1...999 {
      let nextName: String
      if extensionName.isEmpty {
        nextName = "\(baseName)-\(index)"
      } else {
        nextName = "\(baseName)-\(index).\(extensionName)"
      }
      let nextURL = directory.appendingPathComponent(nextName, isDirectory: false)
      if !FileManager.default.fileExists(atPath: nextURL.path) {
        return nextURL
      }
    }
    return directory.appendingPathComponent(UUID().uuidString, isDirectory: false)
  }
}
