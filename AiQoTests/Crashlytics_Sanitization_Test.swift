import XCTest
@testable import AiQo

/// Verifies `PrivacySanitizer.sanitizeError(_:)` strips PII before
/// the error is forwarded to Firebase Crashlytics. The sanitizer is
/// the only thing between Crashlytics and a leaked email/phone — these
/// tests guard that contract.
final class Crashlytics_Sanitization_Test: XCTestCase {

    private let sanitizer = PrivacySanitizer()

    // MARK: - localizedDescription scrubbing

    func testEmailInLocalizedDescriptionIsRedacted() {
        let dirty = NSError(
            domain: "test.domain",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Sign-in failed for mohammed@example.com"]
        )

        let clean = sanitizer.sanitizeError(dirty)
        let cleanDescription = clean.userInfo[NSLocalizedDescriptionKey] as? String ?? ""

        XCTAssertFalse(cleanDescription.contains("mohammed@example.com"),
                       "Raw email survived sanitization: \(cleanDescription)")
        XCTAssertTrue(cleanDescription.contains("[REDACTED]"),
                      "Sanitizer should leave a [REDACTED] marker.")
    }

    func testPhoneNumberInDescriptionIsRedacted() {
        let dirty = NSError(
            domain: "test.domain",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not call +1-415-555-0142"]
        )

        let clean = sanitizer.sanitizeError(dirty)
        let cleanDescription = clean.userInfo[NSLocalizedDescriptionKey] as? String ?? ""

        XCTAssertFalse(cleanDescription.contains("415-555-0142"),
                       "Phone number survived sanitization: \(cleanDescription)")
    }

    // MARK: - userInfo whitelist

    func testNonWhitelistedUserInfoKeysAreDropped() {
        let dirty = NSError(
            domain: "test.domain",
            code: 1,
            userInfo: [
                "AiQoSecretToken": "sk-abc123def456",
                "RawUserPayload": "name=mohammed,email=m@x.com",
                NSLocalizedDescriptionKey: "Something went wrong"
            ]
        )

        let clean = sanitizer.sanitizeError(dirty)

        XCTAssertNil(clean.userInfo["AiQoSecretToken"],
                     "Non-whitelisted custom keys must be dropped.")
        XCTAssertNil(clean.userInfo["RawUserPayload"],
                     "Non-whitelisted custom keys must be dropped.")
        XCTAssertNotNil(clean.userInfo[NSLocalizedDescriptionKey],
                        "Whitelisted localizedDescription must be retained.")
    }

    func testWhitelistedURLKeyIsScrubbed() {
        let urlWithEmail = URL(string: "https://api.example.com/lookup?email=mohammed@example.com")!
        let dirty = NSError(
            domain: NSURLErrorDomain,
            code: -1000,
            userInfo: [
                NSURLErrorFailingURLErrorKey: urlWithEmail,
                NSLocalizedDescriptionKey: "Bad URL"
            ]
        )

        let clean = sanitizer.sanitizeError(dirty)
        let urlString = clean.userInfo[NSURLErrorFailingURLErrorKey] as? String ?? ""

        XCTAssertFalse(urlString.contains("mohammed@example.com"),
                       "Email in URL query params must be scrubbed: \(urlString)")
        XCTAssertTrue(urlString.contains("[REDACTED]"),
                      "Sanitizer should leave a [REDACTED] marker on the scrubbed URL.")
    }

    func testUnderlyingErrorIsRecursivelySanitized() {
        let inner = NSError(
            domain: "inner.domain",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Inner failure for user@aiqo.com"]
        )
        let outer = NSError(
            domain: "outer.domain",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Outer failure",
                NSUnderlyingErrorKey: inner
            ]
        )

        let clean = sanitizer.sanitizeError(outer)
        let cleanInner = clean.userInfo[NSUnderlyingErrorKey] as? NSError
        let innerDescription = cleanInner?.userInfo[NSLocalizedDescriptionKey] as? String ?? ""

        XCTAssertNotNil(cleanInner, "Underlying error must be retained.")
        XCTAssertFalse(innerDescription.contains("user@aiqo.com"),
                       "Email in underlying error survived sanitization: \(innerDescription)")
    }

    // MARK: - Domain & code preservation

    func testDomainAndCodePreserved() {
        let dirty = NSError(domain: "preserve.me", code: 42, userInfo: [:])
        let clean = sanitizer.sanitizeError(dirty)

        XCTAssertEqual(clean.domain, "preserve.me")
        XCTAssertEqual(clean.code, 42)
    }

    // MARK: - sk-prefixed API keys

    func testAPIKeyInDescriptionIsRedacted() {
        let dirty = NSError(
            domain: "test.domain",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Auth header was sk-abc1234567def890ghi"]
        )

        let clean = sanitizer.sanitizeError(dirty)
        let cleanDescription = clean.userInfo[NSLocalizedDescriptionKey] as? String ?? ""

        XCTAssertFalse(cleanDescription.contains("sk-abc1234567def890ghi"),
                       "API key survived sanitization: \(cleanDescription)")
    }
}
