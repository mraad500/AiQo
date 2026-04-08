import Foundation
import StoreKit

/// يتحقق من الإيصالات مع السيرفر — يمنع التلاعب بالاشتراكات
/// الكلاينت يرسل الـ transaction للسيرفر والسيرفر يتحقق ويرجع النتيجة
actor ReceiptValidator {
    static let shared = ReceiptValidator()

    enum ValidationResult: Sendable {
        case valid(expiresAt: Date)
        case invalid(reason: String)
        case networkError(String)
    }

    /// يتحقق من الشراء مع السيرفر
    func validate(transaction: Transaction) async -> ValidationResult {
        let transactionId = String(transaction.id)
        let productId = transaction.productID
        let originalPurchaseDate = ISO8601DateFormatter().string(from: transaction.originalPurchaseDate)
        let purchaseDate = ISO8601DateFormatter().string(from: transaction.purchaseDate)
        let appAccountToken = transaction.appAccountToken?.uuidString

        let payload: [String: String?] = [
            "transactionId": transactionId,
            "productId": productId,
            "originalPurchaseDate": originalPurchaseDate,
            "purchaseDate": purchaseDate,
            "appAccountToken": appAccountToken
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload.compactMapValues({ $0 })) else {
            return .invalid(reason: "Failed to encode receipt payload")
        }

        let validationEndpoint = await MainActor.run {
            K.Supabase.functionsURL?.appending(path: "validate-receipt")
        }

        guard let url = validationEndpoint else {
            return .invalid(reason: "Invalid validation URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .invalid(reason: "Invalid response")
            }

            guard httpResponse.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("🧾 Receipt validation failed with status \(httpResponse.statusCode): \(body)")
                return .invalid(reason: "Server returned \(httpResponse.statusCode)")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .invalid(reason: "Invalid JSON response")
            }

            let valid = json["valid"] as? Bool ?? false
            if valid {
                let expiresAtString = json["expiresAt"] as? String ?? ""
                let expiresAt = ISO8601DateFormatter().date(from: expiresAtString) ?? Date()
                return .valid(expiresAt: expiresAt)
            } else {
                let reason = json["reason"] as? String ?? "Unknown"
                return .invalid(reason: reason)
            }
        } catch {
            print("🧾 Receipt validation network error: \(error.localizedDescription)")
            return .networkError(error.localizedDescription)
        }
    }

    /// يتحقق من كل الـ transactions الحالية
    func validateAllCurrentTransactions() async {
        for await verification in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification else { continue }
            let result = await validate(transaction: transaction)

            switch result {
            case .valid(let expiresAt):
                print("🧾 Transaction \(transaction.productID) validated. Expires: \(expiresAt)")
            case .invalid(let reason):
                print("🧾 Transaction \(transaction.productID) INVALID: \(reason)")
                await MainActor.run {
                    AnalyticsService.shared.track(AnalyticsEvent("receipt_validation_failed", properties: [
                        "product_id": transaction.productID,
                        "reason": reason
                    ]))
                }
            case .networkError:
                print("🧾 Could not validate \(transaction.productID) — network issue, falling back to local")
            }
        }
    }
}
