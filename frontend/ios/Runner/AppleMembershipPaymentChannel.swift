import Flutter
import StoreKit
import UIKit

final class AppleMembershipPaymentChannel: NSObject {
  private let channel: FlutterMethodChannel
  private var pendingTransactionFinishers: [UInt64: () async -> Void] = [:]
  private let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "ling/membership_payment",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "purchaseAppleProduct":
      purchaseAppleProduct(call: call, result: result)
    case "finishAppleTransaction":
      finishAppleTransaction(call: call, result: result)
    case "restoreApplePurchases":
      restoreApplePurchases(result: result)
    case "openAppleSubscriptionManagement":
      openAppleSubscriptionManagement(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func purchaseAppleProduct(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard #available(iOS 15.0, *) else {
      result(terminalPayload(status: "unsupported"))
      return
    }
    let arguments = call.arguments as? [String: Any]
    let providerProductId = (arguments?["providerProductId"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if providerProductId.isEmpty {
      result(
        terminalPayload(
          status: "error",
          message: "Missing Apple product id."
        )
      )
      return
    }
    let appAccountTokenRaw = (arguments?["appAccountToken"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
    NSLog(
      "[Ling][iOS][Membership] purchase request productId=%@ bundleId=%@ hasAppAccountToken=%@",
      providerProductId,
      bundleId,
      appAccountTokenRaw?.isEmpty == false ? "true" : "false"
    )

    Task { [weak self] in
      guard let self else {
        result(
          self?.terminalPayload(
            status: "error",
            message: "Membership payment channel is unavailable."
          ) ?? [:]
        )
        return
      }
      do {
        let products = try await Product.products(for: [providerProductId])
        NSLog(
          "[Ling][iOS][Membership] StoreKit products requested=%@ returned=%@ count=%ld bundleId=%@",
          providerProductId,
          products.map(\.id).joined(separator: ","),
          products.count,
          bundleId
        )
        guard let product = products.first else {
          result(
            self.terminalPayload(
              status: "error",
              message: "Unable to find Apple product \(providerProductId) for bundle \(bundleId).",
              details: [
                "requestedProductId": providerProductId,
                "bundleId": bundleId,
                "storeKitProductCount": products.count,
                "storeKitReturnedProductIds": products.map(\.id)
              ]
            )
          )
          return
        }

        var options: Set<Product.PurchaseOption> = []
        if let rawToken = appAccountTokenRaw, let token = UUID(uuidString: rawToken) {
          options.insert(.appAccountToken(token))
        }
        let purchaseResult = try await product.purchase(options: options)
        switch purchaseResult {
        case .success(let verification):
          let transaction = try self.checkVerified(verification)
          self.pendingTransactionFinishers[transaction.id] = {
            await transaction.finish()
          }
          let payload = self.transactionPayload(
            status: "success",
            transaction: transaction,
            signedTransactionInfo: verification.jwsRepresentation
          )
          result(payload)
        case .userCancelled:
          result(self.terminalPayload(status: "cancelled"))
        case .pending:
          result(
            self.terminalPayload(
              status: "pending",
              message: "Apple purchase is pending approval."
            )
          )
        @unknown default:
          result(
            self.terminalPayload(
              status: "error",
              message: "Apple purchase returned an unknown result."
            )
          )
        }
      } catch {
        NSLog(
          "[Ling][iOS][Membership] purchase failed productId=%@ bundleId=%@ error=%@",
          providerProductId,
          bundleId,
          error.localizedDescription
        )
        result(
          self.terminalPayload(
            status: "error",
            message: error.localizedDescription,
            details: [
              "requestedProductId": providerProductId,
              "bundleId": bundleId
            ]
          )
        )
      }
    }
  }

  private func finishAppleTransaction(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard #available(iOS 15.0, *) else {
      result(nil)
      return
    }
    let arguments = call.arguments as? [String: Any]
    let transactionIdRaw = (arguments?["transactionId"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard let transactionId = UInt64(transactionIdRaw) else {
      result(
        FlutterError(
          code: "invalid_transaction_id",
          message: "Missing Apple transaction id.",
          details: nil
        )
      )
      return
    }
    Task { [weak self] in
      guard let self else {
        result(nil)
        return
      }
      do {
        if let finish = self.pendingTransactionFinishers.removeValue(forKey: transactionId) {
          await finish()
          NSLog(
            "[Ling][iOS][Membership] finished transactionId=%llu",
            transactionId
          )
          result(nil)
          return
        }
        for await verification in Transaction.currentEntitlements {
          let transaction = try self.checkVerified(verification)
          if transaction.id == transactionId {
            await transaction.finish()
            NSLog(
              "[Ling][iOS][Membership] finished transactionId=%llu",
              transactionId
            )
            result(nil)
            return
          }
        }
        NSLog(
          "[Ling][iOS][Membership] finish skipped transactionId=%llu reason=not_unfinished",
          transactionId
        )
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "finish_failed",
            message: error.localizedDescription,
            details: ["transactionId": transactionIdRaw]
          )
        )
      }
    }
  }

  private func restoreApplePurchases(result: @escaping FlutterResult) {
    guard #available(iOS 15.0, *) else {
      result([terminalPayload(status: "unsupported")])
      return
    }
    Task { [weak self] in
      guard let self else {
        result([])
        return
      }
      do {
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        NSLog("[Ling][iOS][Membership] restore purchases bundleId=%@", bundleId)
        do {
          try await AppStore.sync()
        } catch {
          NSLog(
            "[Ling][iOS][Membership] AppStore.sync failed during restore bundleId=%@ error=%@",
            bundleId,
            error.localizedDescription
          )
        }
        var restoredPayloads: [[String: Any]] = []
        for await entitlement in Transaction.currentEntitlements {
          do {
            let transaction = try self.checkVerified(entitlement)
            restoredPayloads.append(
              self.transactionPayload(
                status: "success",
                transaction: transaction,
                signedTransactionInfo: entitlement.jwsRepresentation
              )
            )
          } catch {
            continue
          }
        }
        NSLog(
          "[Ling][iOS][Membership] restore entitlements count=%ld productIds=%@",
          restoredPayloads.count,
          restoredPayloads.compactMap { $0["providerProductId"] as? String }.joined(separator: ",")
        )
        result(restoredPayloads)
      } catch {
        result(
          [
            self.terminalPayload(
              status: "error",
              message: error.localizedDescription
            )
          ]
        )
      }
    }
  }

  private func openAppleSubscriptionManagement(result: @escaping FlutterResult) {
    guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else {
      result(
        FlutterError(
          code: "invalid_url",
          message: "Unable to build Apple subscription management URL.",
          details: nil
        )
      )
      return
    }
    DispatchQueue.main.async {
      UIApplication.shared.open(url) { success in
        if success {
          result(nil)
        } else {
          result(
            FlutterError(
              code: "open_failed",
              message: "Unable to open Apple subscription management.",
              details: nil
            )
          )
        }
      }
    }
  }

  @available(iOS 15.0, *)
  private func transactionPayload(
    status: String,
    transaction: StoreKit.Transaction,
    signedTransactionInfo: String
  ) -> [String: Any] {
    var payload: [String: Any] = [
      "status": status,
      "providerProductId": transaction.productID,
      "transactionId": String(transaction.id),
      "purchaseDate": isoFormatter.string(from: transaction.purchaseDate),
      "signedTransactionInfo": signedTransactionInfo,
      "rawPayload": [
        "product_id": transaction.productID,
        "transaction_id": String(transaction.id),
        "purchase_date": isoFormatter.string(from: transaction.purchaseDate),
        "signed_transaction_info": signedTransactionInfo
      ]
    ]
    if transaction.originalID != transaction.id {
      payload["originalTransactionId"] = String(transaction.originalID)
    } else {
      payload["originalTransactionId"] = String(transaction.originalID)
    }
    if let expirationDate = transaction.expirationDate {
      payload["expirationDate"] = isoFormatter.string(from: expirationDate)
      var rawPayload = payload["rawPayload"] as? [String: Any] ?? [:]
      rawPayload["expiration_date"] = isoFormatter.string(from: expirationDate)
      payload["rawPayload"] = rawPayload
    }
    if let appAccountToken = transaction.appAccountToken?.uuidString {
      var rawPayload = payload["rawPayload"] as? [String: Any] ?? [:]
      rawPayload["app_account_token"] = appAccountToken
      payload["rawPayload"] = rawPayload
    }
    return payload
  }

  private func terminalPayload(
    status: String,
    message: String = "",
    details: [String: Any] = [:]
  ) -> [String: Any] {
    var payload: [String: Any] = [
      "status": status,
      "message": message
    ]
    for (key, value) in details {
      payload[key] = value
    }
    return payload
  }

  @available(iOS 15.0, *)
  private func checkVerified<T>(
    _ result: VerificationResult<T>
  ) throws -> T {
    switch result {
    case .verified(let safe):
      return safe
    case .unverified(_, let error):
      throw error
    }
  }
}
