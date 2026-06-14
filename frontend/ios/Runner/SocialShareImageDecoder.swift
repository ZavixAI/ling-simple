import Flutter
import UIKit

enum SocialShareImageDecoder {
  static func decodedFlutterImages(from arguments: [String: Any]) -> [UIImage] {
    guard let imageItems = arguments["images"] as? [[String: Any]] else {
      return []
    }
    return imageItems.compactMap { item in
      guard let bytes = item["bytes"] as? FlutterStandardTypedData else {
        return nil
      }
      return UIImage(data: bytes.data)
    }
  }

  static func compressedImageData(_ image: UIImage, maxBytes: Int) -> Data? {
    var quality: CGFloat = 0.92
    while quality >= 0.26 {
      if let data = image.jpegData(compressionQuality: quality), data.count <= maxBytes {
        return data
      }
      quality -= 0.12
    }
    return nil
  }
}
