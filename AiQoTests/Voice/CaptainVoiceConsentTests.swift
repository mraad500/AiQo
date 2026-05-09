import XCTest
@testable import AiQo

/// Covers the dedicated cloud-voice consent gate. Every test uses its own
/// isolated `UserDefaults` suite so production state on the simulator is
/// never mutated.
@MainActor
final class CaptainVoiceConsentTests: XCTestCase {

    // MARK: - Initial state

    func test_initialState_notGranted_noTimestamps() {
        let (defaults, suiteName) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let consent = CaptainVoiceConsent(defaults: defaults)
        XCTAssertFalse(consent.isGranted)
        XCTAssertNil(consent.grantedAt)
        XCTAssertNil(consent.revokedAt)
    }

    // MARK: - Grant

    func test_grant_flipsStateAndStampsGrantedAt() {
        let (defaults, suiteName) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let consent = CaptainVoiceConsent(defaults: defaults)
        let before = Date()
        consent.grant()
        let after = Date()

        XCTAssertTrue(consent.isGranted)
        XCTAssertNil(consent.revokedAt, "Grant must clear any previous revoke timestamp.")

        guard let grantedAt = consent.grantedAt else {
            return XCTFail("grantedAt should be set after grant()")
        }
        XCTAssertGreaterThanOrEqual(grantedAt, before)
        XCTAssertLessThanOrEqual(grantedAt, after)
    }

    func test_grant_persistsAcrossInstances() {
        let (defaults, suiteName) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        CaptainVoiceConsent(defaults: defaults).grant()

        let reloaded = CaptainVoiceConsent(defaults: defaults)
        XCTAssertTrue(reloaded.isGranted)
        XCTAssertNotNil(reloaded.grantedAt)
    }

    // MARK: - Revoke

    func test_revoke_flipsStateAndStampsRevokedAt() {
        let (defaults, suiteName) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let consent = CaptainVoiceConsent(defaults: defaults)
        consent.grant()

        let before = Date()
        consent.revoke()
        let after = Date()

        XCTAssertFalse(consent.isGranted)
        XCTAssertNotNil(consent.grantedAt, "revoke() keeps grantedAt so audit UI can show the last-grant timestamp.")

        guard let revokedAt = consent.revokedAt else {
            return XCTFail("revokedAt should be set after revoke()")
        }
        XCTAssertGreaterThanOrEqual(revokedAt, before)
        XCTAssertLessThanOrEqual(revokedAt, after)
    }

    func test_revoke_persistsAcrossInstances() {
        let (defaults, suiteName) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let consent = CaptainVoiceConsent(defaults: defaults)
        consent.grant()
        consent.revoke()

        let reloaded = CaptainVoiceConsent(defaults: defaults)
        XCTAssertFalse(reloaded.isGranted)
        XCTAssertNotNil(reloaded.revokedAt)
    }

    func test_revoke_postsNotification() {
        let (defaults, suiteName) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let consent = CaptainVoiceConsent(defaults: defaults)
        let expectation = expectation(
            forNotification: .captainVoiceConsentRevoked,
            object: nil,
            handler: nil
        )

        consent.grant()
        consent.revoke()

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Grant → revoke → grant cycle

    func test_regrant_clearsRevokedAt() {
        let (defaults, suiteName) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let consent = CaptainVoiceConsent(defaults: defaults)
        consent.grant()
        consent.revoke()
        XCTAssertNotNil(consent.revokedAt)

        consent.grant()
        XCTAssertTrue(consent.isGranted)
        XCTAssertNil(consent.revokedAt, "Re-granting must clear the previous revoke timestamp.")
    }

    // MARK: - Helpers

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "CaptainVoiceConsentTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Unable to create test UserDefaults suite.")
        }
        return (defaults, suiteName)
    }
}
