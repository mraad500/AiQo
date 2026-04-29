import XCTest
@testable import AiQo

/// Router-layer coverage for the hybrid voice architecture. Exercises tier
/// routing, feature flag kill switch, provider fallback on error, and
/// toast-throttling accounting for persistent MiniMax failures.
///
/// All tests run with mock providers so nothing touches `AVSpeechSynthesizer`
/// or the network — they are pure logic tests.
@MainActor
final class CaptainVoiceRouterTests: XCTestCase {

    // MARK: - Tier routing

    func test_realtimeTier_routesToAppleTTS() async {
        let apple = MockVoiceProvider(kind: .appleTTS)
        let miniMax = MockVoiceProvider(kind: .miniMax)
        let router = CaptainVoiceRouter(
            appleTTSProvider: apple,
            miniMaxProvider: miniMax,
            featureFlagEnabled: { true }
        )

        await router.speak(text: "hello", tier: .realtime)

        XCTAssertEqual(apple.speakCallCount, 1)
        XCTAssertEqual(miniMax.speakCallCount, 0)
        XCTAssertEqual(apple.spokenTexts, ["hello"])
    }

    func test_premiumTier_withMiniMaxAvailable_routesToMiniMax() async {
        let apple = MockVoiceProvider(kind: .appleTTS)
        let miniMax = MockVoiceProvider(kind: .miniMax)
        let router = CaptainVoiceRouter(
            appleTTSProvider: apple,
            miniMaxProvider: miniMax,
            featureFlagEnabled: { true }
        )

        await router.speak(text: "premium line", tier: .premium)

        XCTAssertEqual(miniMax.speakCallCount, 1)
        XCTAssertEqual(apple.speakCallCount, 0)
    }

    func test_premiumTier_withoutMiniMax_fallsBackToApple() async {
        let apple = MockVoiceProvider(kind: .appleTTS)
        let router = CaptainVoiceRouter(
            appleTTSProvider: apple,
            miniMaxProvider: nil,
            featureFlagEnabled: { true }
        )

        await router.speak(text: "premium but no cloud", tier: .premium)

        XCTAssertEqual(apple.speakCallCount, 1)
    }

    // MARK: - Feature flag kill switch

    func test_featureFlagDisabled_premiumRoutesToApple() async {
        let apple = MockVoiceProvider(kind: .appleTTS)
        let miniMax = MockVoiceProvider(kind: .miniMax)
        let router = CaptainVoiceRouter(
            appleTTSProvider: apple,
            miniMaxProvider: miniMax,
            featureFlagEnabled: { false }
        )

        await router.speak(text: "premium but flag off", tier: .premium)

        XCTAssertEqual(apple.speakCallCount, 1)
        XCTAssertEqual(miniMax.speakCallCount, 0, "Flag off must bypass MiniMax entirely — not just on failure.")
    }

    // MARK: - Fallback on silent errors (no failure accounting)

    func test_miniMaxConfigurationMissing_silentFallback_noToastAccounting() async {
        let apple = MockVoiceProvider(kind: .appleTTS)
        let miniMax = MockVoiceProvider(kind: .miniMax)
        miniMax.errorToThrow = VoiceProviderError.configurationMissing

        let router = CaptainVoiceRouter(
            appleTTSProvider: apple,
            miniMaxProvider: miniMax,
            featureFlagEnabled: { true }
        )

        await router.speak(text: "will fall back quietly", tier: .premium)

        XCTAssertEqual(miniMax.speakCallCount, 1)
        XCTAssertEqual(apple.speakCallCount, 1, "Apple TTS must cover the fallback.")
        XCTAssertEqual(router.miniMaxFailureTimestamps.count, 0, "Config errors must not count toward the failure window.")
        XCTAssertFalse(router.hasShownFallbackToastThisSession)
    }

    func test_miniMaxConsentMissing_silentFallback_noToastAccounting() async {
        let apple = MockVoiceProvider(kind: .appleTTS)
        let miniMax = MockVoiceProvider(kind: .miniMax)
        miniMax.errorToThrow = VoiceProviderError.consentMissing

        let router = CaptainVoiceRouter(
            appleTTSProvider: apple,
            miniMaxProvider: miniMax,
            featureFlagEnabled: { true }
        )

        await router.speak(text: "no consent yet", tier: .premium)

        XCTAssertEqual(miniMax.speakCallCount, 1)
        XCTAssertEqual(apple.speakCallCount, 1)
        XCTAssertEqual(router.miniMaxFailureTimestamps.count, 0)
        XCTAssertFalse(router.hasShownFallbackToastThisSession)
    }

    // MARK: - Network failure accounting

    func test_miniMaxNetworkFailed_singleFailure_fallsBackAndCountsButDoesNotToast() async {
        let apple = MockVoiceProvider(kind: .appleTTS)
        let miniMax = MockVoiceProvider(kind: .miniMax)
        miniMax.errorToThrow = VoiceProviderError.networkFailed

        let router = CaptainVoiceRouter(
            appleTTSProvider: apple,
            miniMaxProvider: miniMax,
            featureFlagEnabled: { true }
        )

        await router.speak(text: "first failure", tier: .premium)

        XCTAssertEqual(apple.speakCallCount, 1)
        XCTAssertEqual(router.miniMaxFailureTimestamps.count, 1)
        XCTAssertFalse(router.hasShownFallbackToastThisSession, "First failure shouldn't trip the toast.")
    }

    func test_miniMaxNetworkFailed_threeInWindow_tripsToastFlag() async {
        let apple = MockVoiceProvider(kind: .appleTTS)
        let miniMax = MockVoiceProvider(kind: .miniMax)
        miniMax.errorToThrow = VoiceProviderError.networkFailed

        let router = CaptainVoiceRouter(
            appleTTSProvider: apple,
            miniMaxProvider: miniMax,
            featureFlagEnabled: { true }
        )

        await router.speak(text: "a", tier: .premium)
        await router.speak(text: "b", tier: .premium)
        await router.speak(text: "c", tier: .premium)

        XCTAssertEqual(router.miniMaxFailureTimestamps.count, 3)
        XCTAssertTrue(router.hasShownFallbackToastThisSession)
    }

    func test_miniMaxNetworkFailed_toastStaysQuietAfterFirstToast() async {
        let apple = MockVoiceProvider(kind: .appleTTS)
        let miniMax = MockVoiceProvider(kind: .miniMax)
        miniMax.errorToThrow = VoiceProviderError.networkFailed

        let router = CaptainVoiceRouter(
            appleTTSProvider: apple,
            miniMaxProvider: miniMax,
            featureFlagEnabled: { true }
        )

        // Trip the toast once.
        await router.speak(text: "1", tier: .premium)
        await router.speak(text: "2", tier: .premium)
        await router.speak(text: "3", tier: .premium)
        XCTAssertTrue(router.hasShownFallbackToastThisSession)

        // Further failures must NOT re-arm the toast (it stays true but no
        // additional toast should fire — captured here as a state invariant;
        // the test proves the flag is sticky within a session).
        await router.speak(text: "4", tier: .premium)
        XCTAssertTrue(router.hasShownFallbackToastThisSession)
        XCTAssertEqual(router.miniMaxFailureTimestamps.count, 4)
    }

    // MARK: - Input hygiene

    func test_emptyText_doesNotInvokeAnyProvider() async {
        let apple = MockVoiceProvider(kind: .appleTTS)
        let miniMax = MockVoiceProvider(kind: .miniMax)
        let router = CaptainVoiceRouter(
            appleTTSProvider: apple,
            miniMaxProvider: miniMax,
            featureFlagEnabled: { true }
        )

        await router.speak(text: "   \n\t  ", tier: .premium)
        await router.speak(text: "", tier: .realtime)

        XCTAssertEqual(apple.speakCallCount, 0)
        XCTAssertEqual(miniMax.speakCallCount, 0)
    }

    // MARK: - stop()

    func test_stopInvokesBothProviders() async {
        let apple = MockVoiceProvider(kind: .appleTTS)
        let miniMax = MockVoiceProvider(kind: .miniMax)
        let router = CaptainVoiceRouter(
            appleTTSProvider: apple,
            miniMaxProvider: miniMax,
            featureFlagEnabled: { true }
        )

        router.stop()

        XCTAssertEqual(apple.stopCallCount, 1)
        XCTAssertEqual(miniMax.stopCallCount, 1)
    }
}

// MARK: - Mock provider

/// In-memory `VoiceProvider` for router tests. Captures call counts and
/// spoken texts; can be configured to throw on demand to exercise the
/// router's fallback branches.
@MainActor
final class MockVoiceProvider: VoiceProvider {
    let kind: VoiceProviderKind

    private(set) var spokenTexts: [String] = []
    private(set) var speakCallCount = 0
    private(set) var stopCallCount = 0

    /// If set, every `speak` call throws this error instead of recording
    /// the text. Resets after each call is NOT automatic — set to `nil`
    /// manually to stop throwing.
    var errorToThrow: Error?

    init(kind: VoiceProviderKind) {
        self.kind = kind
    }

    func speak(text: String) async throws {
        speakCallCount += 1
        if let error = errorToThrow {
            throw error
        }
        spokenTexts.append(text)
    }

    func stop() {
        stopCallCount += 1
    }
}
