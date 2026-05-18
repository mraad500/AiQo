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
            return Self.parseValidationResponse(data: data, response: response)
        } catch {
            diag.error("Receipt validation network error", error: error)
            return .networkError(error.localizedDescription)
        }
    }

    /// Pure mapping of the validate-receipt HTTP response → result. Kept
    /// `nonisolated static` so the revenue-critical decision logic is
    /// unit-testable without a StoreKit `Transaction` or a live round-trip.
    nonisolated static func parseValidationResponse(
        data: Data,
        response: URLResponse?
    ) -> ValidationResult {
        guard let httpResponse = response as? HTTPURLResponse else {
            return .invalid(reason: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            diag.warning("Receipt validation failed status=\(httpResponse.statusCode) body=\(body)")
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
    }

    /// يتحقق من كل الـ transactions الحالية
    func validateAllCurrentTransactions() async {
        for await verification in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification else { continue }
            let result = await validate(transaction: transaction)

            switch result {
            case .valid(let expiresAt):
                diag.info("Receipt validated product=\(transaction.productID) expires=\(expiresAt)")
            case .invalid(let reason):
                diag.warning("Receipt INVALID product=\(transaction.productID) reason=\(reason)")
                await MainActor.run {
                    AnalyticsService.shared.track(AnalyticsEvent("receipt_validation_failed", properties: [
                        "product_id": transaction.productID,
                        "reason": reason
                    ]))
                }
            case .networkError(let message):
                // Revenue path: production builds previously logged nothing here
                // (print is a release no-op) so silent validation outages were
                // invisible. Surface to os.log + analytics; caller still falls
                // back to local entitlement.
                diag.warning("Receipt unvalidated (network) product=\(transaction.productID) — fallback to local: \(message)")
                await MainActor.run {
                    AnalyticsService.shared.track(AnalyticsEvent("receipt_validation_network_error", properties: [
                        "product_id": transaction.productID
                    ]))
                }
            }
        }
    }
}
