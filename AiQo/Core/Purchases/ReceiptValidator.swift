import Foundation
import StoreKit

/// يتحقق من الإيصالات مع السيرفر — يمنع التلاعب بالاشتراكات
/// الكلاينت يرسل الـ transaction للسيرفر والسيرفر يتحقق ويرجع النتيجة
actor ReceiptValidator {
    static let shared = ReceiptValidator()

    /// عنوان الـ API — يحتاج يتغير حسب السيرفر الحقيقي
    private let validationEndpoint = "https://zidbsrepqpbucqzxnwgk.supabase.co/functions/v1/validate-receipt"

    enum ValidationResult {
        case valid(expiresAt: Date)
        case invalid(reason: String)
        case networkError(Error)
    }

    /// يتحقق من الشراء مع السيرفر
    func validate(transaction: Transaction) async -> ValidationResult {
        let payload = ReceiptPayload(
            transactionId: String(transaction.id),
            productId: transaction.productID,
            originalPurchaseDate: transaction.originalPurchaseDate.iso8601String,
            purchaseDate: transaction.purchaseDate.iso8601String,
            environment: transaction.environment.rawValue,
            appAccountToken: transaction.appAccountToken?.uuidString
        )

        guard let bodyData = try? JSONEncoder().encode(payload) else {
            return .invalid(reason: "Failed to encode receipt payload")
        }

        guard let url = URL(string: validationEndpoint) else {
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

            let result = try JSONDecoder().decode(ValidationResponse.self, from: data)

            if result.valid {
                let expiresAt = ISO8601DateFormatter().date(from: result.expiresAt ?? "") ?? Date()
                return .valid(expiresAt: expiresAt)
            } else {
                return .invalid(reason: result.reason ?? "Unknown")
            }
        } catch {
            print("🧾 Receipt validation network error: \(error.localizedDescription)")
            // عند فشل الشبكة، نثق بالـ StoreKit محلياً (graceful degradation)
            return .networkError(error)
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
                // لا نعاقب المستخدم على مشاكل الشبكة
                print("🧾 Could not validate \(transaction.productID) — network issue, falling back to local")
            }
        }
    }
}

// MARK: - Models

private struct ReceiptPayload: Codable {
    let transactionId: String
    let productId: String
    let originalPurchaseDate: String
    let purchaseDate: String
    let environment: String
    let appAccountToken: String?
}

private struct ValidationResponse: Codable {
    let valid: Bool
    let expiresAt: String?
    let reason: String?
}

private extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}

private extension Transaction.EnvironmentValues {
    var rawValue: String {
        if self == .production { return "production" }
        if self == .sandbox { return "sandbox" }
        return "xcode"
    }
}
