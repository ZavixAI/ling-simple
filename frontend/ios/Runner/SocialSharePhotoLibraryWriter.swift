import Photos
import UIKit

final class SocialSharePhotoLibraryWriter {
  func saveImages(
    _ images: [UIImage],
    completion: @escaping (Result<[String], Error>) -> Void
  ) {
    PHPhotoLibrary.requestAuthorization { status in
      guard Self.canWriteToPhotoLibrary(status) else {
        DispatchQueue.main.async {
          completion(
            .failure(
              NSError(
                domain: "LingDouyinShare",
                code: 1,
                userInfo: [
                  NSLocalizedDescriptionKey: "Photo library permission is required for Douyin sharing."
                ]
              )
            )
          )
        }
        return
      }
      var placeholders: [PHObjectPlaceholder] = []
      PHPhotoLibrary.shared().performChanges {
        for image in images {
          let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
          if let placeholder = request.placeholderForCreatedAsset {
            placeholders.append(placeholder)
          }
        }
      } completionHandler: { success, error in
        DispatchQueue.main.async {
          if let error {
            completion(.failure(error))
            return
          }
          guard success else {
            completion(
              .failure(
                NSError(
                  domain: "LingDouyinShare",
                  code: 2,
                  userInfo: [
                    NSLocalizedDescriptionKey: "Unable to save images for Douyin sharing."
                  ]
                )
              )
            )
            return
          }
          completion(.success(placeholders.map(\.localIdentifier)))
        }
      }
    }
  }

  private static func canWriteToPhotoLibrary(_ status: PHAuthorizationStatus) -> Bool {
    if status == .authorized {
      return true
    }
    if #available(iOS 14, *) {
      return status == .limited
    }
    return false
  }
}
