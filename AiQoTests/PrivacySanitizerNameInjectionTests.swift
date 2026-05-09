import XCTest
@testable import AiQo

/// Regression coverage for the Apple v1.1 rejection fix (submission 49728905,
/// Guideline 4.0.0). Before v1.1, `injectUserName` both replaced placeholder
/// tokens AND prepended the user's first name to any reply that didn't start
/// with one — which produced "John, Got it. 60kg is a solid baseline…" in
/// Apple's screenshot. v1.1 removes the prepend path entirely; only explicit
/// tokens are replaced now.
final class PrivacySanitizerNameInjectionTests: XCTestCase {

    private let sanitizer = PrivacySanitizer()

    // MARK: - Happy path

    func test_injectUserName_withExplicitToken_replacesToken() {
        let out = sanitizer.injectUserName(
            into: "Hey [USER_NAME], you nailed it today.",
            userName: "Mohammed"
        )
        XCTAssertEqual(out, "Hey Mohammed, you nailed it today.")
    }

    // MARK: - Critical regression

    /// The bug Apple flagged: no token in the reply → the sanitizer must NOT
    /// prepend the user's name. If this test ever fails, we have re-introduced
    /// the "John, Got it." behavior that triggered the rejection.
    func test_injectUserName_withoutToken_doesNotPrepend() {
        let reply = "Got it. 60kg is a solid baseline — we'll build on that."
        let out = sanitizer.injectUserName(into: reply, userName: "John")
        XCTAssertEqual(out, reply, "injectUserName must never prepend a name; only explicit tokens may be replaced.")
        XCTAssertFalse(out.hasPrefix("John"))
        XCTAssertFalse(out.contains("John,"))
    }

    // MARK: - Placeholder variants

    func test_injectUserName_allPlaceholderVariants() {
        let cases: [(input: String, expected: String)] = [
            ("Hi [USER_NAME]!",        "Hi Ahmed!"),
            ("Hi {{userName}}!",       "Hi Ahmed!"),
            ("Hi {{user_name}}!",      "Hi Ahmed!"),
            ("Hi {USER_NAME}!",        "Hi Ahmed!"),
            ("Hi %USER_NAME%!",        "Hi Ahmed!")
        ]
        for (input, expected) in cases {
            let out = sanitizer.injectUserName(into: input, userName: "Ahmed")
            XCTAssertEqual(out, expected, "Placeholder \(input) should be replaced with the first name")
        }
    }

    // MARK: - Empty-name path (equivalent to nil — the API takes non-optional String)

    /// When `userName` is empty or whitespace-only the sanitizer must leave
    /// placeholder tokens untouched — it cannot substitute nothing for a
    /// placeholder, and it must not silently drop the token.
    func test_injectUserName_nilUserName_leavesTokensIntact() {
        let reply = "Welcome back, [USER_NAME]!"
        let outEmpty = sanitizer.injectUserName(into: reply, userName: "")
        let outWhitespace = sanitizer.injectUserName(into: reply, userName: "   ")
        XCTAssertEqual(outEmpty, reply)
        XCTAssertEqual(outWhitespace, reply)
        XCTAssertTrue(outEmpty.contains("[USER_NAME]"))
        XCTAssertTrue(outWhitespace.contains("[USER_NAME]"))
    }
}
