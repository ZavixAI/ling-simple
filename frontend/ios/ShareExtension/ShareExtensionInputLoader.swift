import MobileCoreServices
import UIKit

struct ShareExtensionInputPayload {
  let files: [(filename: String, data: Data)]
  let textValues: [String]
}

final class ShareExtensionInputLoader {
  private static let maxSharedImageBytes = 5 * 1024 * 1024
  private static let jpegQualitySteps: [CGFloat] = [0.88, 0.82, 0.76, 0.70, 0.64, 0.58]

  func load(
    from extensionContext: NSExtensionContext?,
    completion: @escaping (ShareExtensionInputPayload) -> Void
  ) {
    let providers = extensionContext?.inputItems
      .compactMap { $0 as? NSExtensionItem }
      .flatMap { $0.attachments ?? [] } ?? []
    let imageProviders = providers.filter {
      $0.hasItemConformingToTypeIdentifier(kUTTypeImage as String)
    }
    let textProviders = providers.filter {
      $0.hasItemConformingToTypeIdentifier(kUTTypeURL as String)
        || $0.hasItemConformingToTypeIdentifier(kUTTypeText as String)
    }

    let group = DispatchGroup()
    let lock = NSLock()
    var files: [(filename: String, data: Data)] = []
    var textValues: [String] = []

    for provider in imageProviders {
      group.enter()
      provider.loadItem(
        forTypeIdentifier: kUTTypeImage as String,
        options: nil
      ) { item, _ in
        defer { group.leave() }
        guard let file = Self.imageFile(from: item, provider: provider) else {
          return
        }
        lock.lock()
        files.append(file)
        lock.unlock()
      }
    }

    for provider in textProviders {
      group.enter()
      loadPasteboardText(from: provider) { value in
        defer { group.leave() }
        guard let value, !value.isEmpty else {
          return
        }
        lock.lock()
        textValues.append(value)
        lock.unlock()
      }
    }

    group.notify(queue: .main) {
      completion(ShareExtensionInputPayload(files: files, textValues: textValues))
    }
  }

  private func loadPasteboardText(
    from provider: NSItemProvider,
    completion: @escaping (String?) -> Void
  ) {
    if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
      provider.loadItem(
        forTypeIdentifier: kUTTypeURL as String,
        options: nil
      ) { item, _ in
        completion(Self.pasteboardText(from: item))
      }
      return
    }
    provider.loadItem(
      forTypeIdentifier: kUTTypeText as String,
      options: nil
    ) { item, _ in
      completion(Self.pasteboardText(from: item))
    }
  }

  private static func pasteboardText(from item: NSSecureCoding?) -> String? {
    if let url = item as? URL {
      if isLocalImageFileReference(url) {
        return nil
      }
      return url.absoluteString
    }
    if let string = item as? String {
      let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines)
      if isLocalImageFileReference(normalized) {
        return nil
      }
      return normalized
    }
    if let data = item as? Data,
      let string = String(data: data, encoding: .utf8)
    {
      let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines)
      if isLocalImageFileReference(normalized) {
        return nil
      }
      return normalized
    }
    return nil
  }

  private static func isLocalImageFileReference(_ value: String) -> Bool {
    var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized.hasPrefix("<") && normalized.hasSuffix(">") && normalized.count > 2 {
      normalized = String(normalized.dropFirst().dropLast())
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let url = URL(string: normalized), url.isFileURL {
      return isLocalImageFileReference(url)
    }
    return false
  }

  private static func isLocalImageFileReference(_ url: URL) -> Bool {
    guard url.isFileURL else {
      return false
    }
    let path = url.path.lowercased()
    let isIOSContainerPath = path.hasPrefix("/var/mobile/containers/")
      || path.hasPrefix("/private/var/mobile/containers/")
      || path.contains("/mmimagepicker/temp/")
    guard isIOSContainerPath else {
      return false
    }
    let imageExtensions: Set<String> = [
      "jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "bmp", "tif", "tiff"
    ]
    return imageExtensions.contains(url.pathExtension.lowercased())
  }

  private static func imageFile(
    from item: NSSecureCoding?,
    provider: NSItemProvider
  ) -> (filename: String, data: Data)? {
    if let url = item as? URL, let data = try? Data(contentsOf: url) {
      return boundedImageFile(
        filename: url.lastPathComponent,
        data: data,
        fallbackFilename: suggestedFilename(provider: provider, fallbackExtension: "jpg")
      )
    }
    if let image = item as? UIImage {
      let filename = jpegFilename(
        from: suggestedFilename(provider: provider, fallbackExtension: "jpg")
      )
      guard let data = compressedImageData(image, maxBytes: maxSharedImageBytes) else {
        return nil
      }
      return (filename, data)
    }
    if let data = item as? Data {
      let filename = suggestedFilename(provider: provider, fallbackExtension: "jpg")
      return boundedImageFile(filename: filename, data: data, fallbackFilename: filename)
    }
    return nil
  }

  private static func boundedImageFile(
    filename: String,
    data: Data,
    fallbackFilename: String
  ) -> (filename: String, data: Data)? {
    if data.count <= maxSharedImageBytes {
      return (filename.isEmpty ? fallbackFilename : filename, data)
    }
    guard
      let image = UIImage(data: data),
      let compressed = compressedImageData(image, maxBytes: maxSharedImageBytes)
    else {
      return (filename.isEmpty ? fallbackFilename : filename, data)
    }
    return (jpegFilename(from: filename.isEmpty ? fallbackFilename : filename), compressed)
  }

  private static func compressedImageData(_ image: UIImage, maxBytes: Int) -> Data? {
    let normalized = normalizedImage(from: image)
    let originalData = normalized.jpegData(compressionQuality: jpegQualitySteps[0])
    let originalBytes = max(originalData?.count ?? maxBytes, 1)
    let initialScale = min(1.0, sqrt(CGFloat(maxBytes) / CGFloat(originalBytes)) * 0.95)

    for attempt in 0..<10 {
      let scaleDecay = CGFloat(pow(0.82, Double(attempt)))
      let scale = min(1.0, initialScale * scaleDecay)
      let candidateImage = resizedImage(normalized, scale: scale)
      for quality in jpegQualitySteps {
        if let data = candidateImage.jpegData(compressionQuality: quality),
          data.count <= maxBytes
        {
          return data
        }
      }
    }
    return nil
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

  private static func resizedImage(_ image: UIImage, scale: CGFloat) -> UIImage {
    guard scale < 1.0 else {
      return image
    }
    let targetSize = CGSize(
      width: max(1, image.size.width * scale),
      height: max(1, image.size.height * scale)
    )
    let rendererFormat = UIGraphicsImageRendererFormat.default()
    rendererFormat.opaque = true
    rendererFormat.scale = 1
    return UIGraphicsImageRenderer(size: targetSize, format: rendererFormat).image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }

  private static func jpegFilename(from filename: String) -> String {
    let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return "shared-image-\(UUID().uuidString).jpg"
    }
    let url = URL(fileURLWithPath: trimmed)
    let baseName = url.deletingPathExtension().lastPathComponent
    let resolvedBaseName = baseName.isEmpty ? "shared-image-\(UUID().uuidString)" : baseName
    return "\(resolvedBaseName).jpg"
  }

  private static func suggestedFilename(
    provider: NSItemProvider,
    fallbackExtension: String
  ) -> String {
    let suggestedName = provider.suggestedName?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if let suggestedName, !suggestedName.isEmpty {
      return suggestedName.contains(".") ? suggestedName : "\(suggestedName).\(fallbackExtension)"
    }
    return "shared-image-\(UUID().uuidString).\(fallbackExtension)"
  }
}
