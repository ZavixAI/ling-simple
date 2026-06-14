import UIKit

struct ShareExtensionSendRequest {
  let files: [(filename: String, data: Data)]
  let textPayload: String
}

enum ShareExtensionSendOutcome {
  case openedInExtension
  case completedWithApplicationFallback
  case failed
}

final class ShareExtensionSender {
  func send(
    request: ShareExtensionSendRequest,
    extensionContext: NSExtensionContext?,
    completion: @escaping (ShareExtensionSendOutcome) -> Void
  ) {
    var pasteboardRequestId: String?
    var shareId: String?
    do {
      try? LingSharedImageStore.discardAllPendingItems()
      if !request.textPayload.isEmpty {
        UIPasteboard.general.string = request.textPayload
        pasteboardRequestId = try LingSharedImageStore.createPasteboardImportRequest()
      }
      if !request.files.isEmpty {
        shareId = try LingSharedImageStore.createShare(files: request.files)
      }
      openLingApp(
        shareId: shareId,
        pasteboardRequestId: pasteboardRequestId,
        extensionContext: extensionContext,
        completion: completion
      )
    } catch {
      discardPendingArtifacts(
        shareId: shareId,
        pasteboardRequestId: pasteboardRequestId
      )
      completion(.failed)
    }
  }

  private func openLingApp(
    shareId: String?,
    pasteboardRequestId: String?,
    extensionContext: NSExtensionContext?,
    completion: @escaping (ShareExtensionSendOutcome) -> Void
  ) {
    var components = URLComponents()
    components.scheme = "ling"
    components.host = "share"
    components.queryItems = [
      URLQueryItem(name: "send", value: "1")
    ]
    if let shareId {
      components.queryItems?.append(URLQueryItem(name: "shareId", value: shareId))
    }
    if pasteboardRequestId != nil {
      components.queryItems?.append(URLQueryItem(name: "pasteboard", value: "1"))
    }
    guard let url = components.url else {
      discardPendingArtifacts(
        shareId: shareId,
        pasteboardRequestId: pasteboardRequestId
      )
      completion(.failed)
      return
    }
    extensionContext?.open(url) { [weak self] success in
      DispatchQueue.main.async {
        if success {
          completion(.openedInExtension)
        } else if self?.canOpenURLThroughApplication() == true {
          extensionContext?.completeRequest(returningItems: nil) { [weak self] _ in
            DispatchQueue.main.async {
              self?.openURLThroughApplication(url)
              completion(.completedWithApplicationFallback)
            }
          }
        } else {
          self?.discardPendingArtifacts(
            shareId: shareId,
            pasteboardRequestId: pasteboardRequestId
          )
          completion(.failed)
        }
      }
    }
  }

  private func canOpenURLThroughApplication() -> Bool {
    applicationObject()?.responds(
      to: NSSelectorFromString("openURL:options:completionHandler:")
    ) == true
  }

  private func openURLThroughApplication(_ url: URL) {
    guard let application = applicationObject() else {
      return
    }
    let selector = NSSelectorFromString("openURL:options:completionHandler:")
    guard application.responds(to: selector), let method = application.method(for: selector) else {
      return
    }
    typealias OpenURLFunction = @convention(c) (
      AnyObject,
      Selector,
      NSURL,
      NSDictionary,
      AnyObject?
    ) -> Void
    let function = unsafeBitCast(method, to: OpenURLFunction.self)
    function(application, selector, url as NSURL, NSDictionary(), nil)
  }

  private func applicationObject() -> NSObject? {
    guard let applicationClass = NSClassFromString("UIApplication") as? NSObject.Type else {
      return nil
    }
    let selector = NSSelectorFromString("sharedApplication")
    guard applicationClass.responds(to: selector) else {
      return nil
    }
    return applicationClass.perform(selector)?.takeUnretainedValue() as? NSObject
  }

  private func discardPendingArtifacts(shareId: String?, pasteboardRequestId: String?) {
    if let shareId {
      try? LingSharedImageStore.discardShare(shareId: shareId)
    }
    if let pasteboardRequestId {
      try? LingSharedImageStore.discardPasteboardImportRequest(requestId: pasteboardRequestId)
    }
  }
}
