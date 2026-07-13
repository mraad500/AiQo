import XCTest
@testable import AiQo

/// Covers the revenue-critical decision logic that maps the validate-receipt
/// HTTP response to a `ValidationResult`. This path was previously untestable
/// (needed a real StoreKit `Transaction` + live network); `parseValidationResponse`
/// is the extracted pure seam so the money path has deterministic coverage.
final class ReceiptValidatorTests: XCTestCase {

    private func httpResponse(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.test/validate-receipt")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    func testValidSubscriptionParsesExpiry() {
        let body = #"{"valid":true,"expiresAt":"2026-12-31T00:00:00Z"}"#.data(using: .utf8)!
        let result = ReceiptValidator.parseValidationResponse(data: body, response: httpResponse(200))

        guard case .valid(let expiresAt) = result else {
            return XCTFail("Expected .valid, got \(result)")
        }
        let expected = ISO8601DateFormatter().date(from: "2026-12-31T00:00:00Z")
        XCTAssertEqual(expiresAt, expected)
    }

    func testValidWithoutExpiryFallsBackToNonNilDate() {
        let body = #"{"valid":true}"#.data(using: .utf8)!
        let result = ReceiptValidator.parseValidationResponse(data: body, response: httpResponse(200))

        guard case .valid(let expiresAt) = result else {
            return XCTFail("Expected .valid, got \(result)")
        }
        // Missing expiresAt → "now" fallback; assert it is recent, not epoch.
        XCTAssertLessThan(abs(expiresAt.timeIntervalSinceNow), 5)
    }

    func testInvalidWithReasonIsPropagated() {
        let body = #"{"valid":false,"reason":"subscription_expired"}"#.data(using: .utf8)!
        let result = ReceiptValidator.parseValidationResponse(data: body, response: httpResponse(200))

        guard case .invalid(let reason) = result else {
            return XCTFail("Expected .invalid, got \(result)")
        }
        XCTAssertEqual(reason, "subscription_expired")
    }

    func testInvalidWithoutReasonDefaultsToUnknown() {
        let body = #"{"valid":false}"#.data(using: .utf8)!
        let result = ReceiptValidator.parseValidationResponse(data: body, response: httpResponse(200))

        guard case .invalid(let reason) = result else {
            return XCTFail("Expected .invalid, got \(result)")
        }
        XCTAssertEqual(reason, "Unknown")
    }

    func testNon200StatusIsInvalidNotValid() {
        // Critical: a server/auth failure must NEVER be treated as a valid
        // entitlement. Tampering or an outage should deny, not grant.
        let result = ReceiptValidator.parseValidationResponse(
            data: Data("forbidden".utf8),
            response: httpResponse(403)
        )
        guard case .invalid(let reason) = result else {
            return XCTFail("Expected .invalid for non-200, got \(result)")
        }
        XCTAssertEqual(reason, "Server returned 403")
    }

    func testMalformedJSONIsInvalid() {
        let result = ReceiptValidator.parseValidationResponse(
            data: Data("definitely not json".utf8),
            response: httpResponse(200)
        )
        guard case .invalid(let reason) = result else {
            return XCTFail("Expected .invalid for bad JSON, got \(result)")
        }
        XCTAssertEqual(reason, "Invalid JSON response")
    }

    func testNonHTTPResponseIsInvalid() {
        let nonHTTP = URLResponse(
            url: URL(string: "https://example.test")!,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )
        let result = ReceiptValidator.parseValidationResponse(data: Data(), response: nonHTTP)
        guard case .invalid(let reason) = result else {
            return XCTFail("Expected .invalid for non-HTTP, got \(result)")
        }
        XCTAssertEqual(reason, "Invalid response")
    }
}
