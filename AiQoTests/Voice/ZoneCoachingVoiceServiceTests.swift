import XCTest
@testable import AiQo

/// Coverage for the Zone 2 coaching voice service. Split into two groups:
///
/// - **Transition mapping**: the static `eventFor(from:to:...)` function is
///   exercised as a pure function — no router, no session, no subscribers.
/// - **Debouncing**: `canSpeak` / `recordSpoken` driven against an injected
///   `now` clock to verify the 30s per-category and 15s global cooldowns
///   without sleeping in real time.
@MainActor
final class ZoneCoachingVoiceServiceTests: XCTestCase {

    // MARK: - Transition mapping (pure)

    func test_transition_inactiveToWarmingUp_emitsWorkoutStart() {
        let event = ZoneCoachingVoiceService.eventFor(
            from: .neutral,
            to: .warmingUp,
            currentBPM: 100, targetMin: 120, targetMax: 140
        )
        XCTAssertEqual(event, .workoutStart)
    }

    func test_transition_warmingUpToZone2_emitsWarmupEnd() {
        let event = ZoneCoachingVoiceService.eventFor(
            from: .warmingUp,
            to: .zone2,
            currentBPM: 125, targetMin: 120, targetMax: 140
        )
        XCTAssertEqual(event, .warmupEnd)
    }

    func test_transition_zone2ToAboveZone2_emitsAboveZoneWithBPMAndMax() {
        let event = ZoneCoachingVoiceService.eventFor(
            from: .zone2,
            to: .aboveZone2,
            currentBPM: 155, targetMin: 120, targetMax: 140
        )
        XCTAssertEqual(event, .aboveZone(currentBPM: 155, targetMax: 140))
    }

    func test_transition_zone2ToBelowZone2_emitsBelowZoneWithBPMAndMin() {
        let event = ZoneCoachingVoiceService.eventFor(
            from: .zone2,
            to: .belowZone2,
            currentBPM: 105, targetMin: 120, targetMax: 140
        )
        XCTAssertEqual(event, .belowZone(currentBPM: 105, targetMin: 120))
    }

    func test_transition_aboveZone2ToZone2_emitsEnteredZone() {
        let event = ZoneCoachingVoiceService.eventFor(
            from: .aboveZone2,
            to: .zone2,
            currentBPM: 130, targetMin: 120, targetMax: 140
        )
        XCTAssertEqual(event, .enteredZone)
    }

    func test_transition_belowZone2ToZone2_emitsEnteredZone() {
        let event = ZoneCoachingVoiceService.eventFor(
            from: .belowZone2,
            to: .zone2,
            currentBPM: 130, targetMin: 120, targetMax: 140
        )
        XCTAssertEqual(event, .enteredZone)
    }

    func test_transition_zone2ToNeutral_emitsCooldownStart() {
        let event = ZoneCoachingVoiceService.eventFor(
            from: .zone2,
            to: .neutral,
            currentBPM: 90, targetMin: 120, targetMax: 140
        )
        XCTAssertEqual(event, .cooldownStart)
    }

    func test_transition_sameState_returnsNil() {
        let event = ZoneCoachingVoiceService.eventFor(
            from: .zone2,
            to: .zone2,
            currentBPM: 130, targetMin: 120, targetMax: 140
        )
        XCTAssertNil(event, "No transition = no event.")
    }

    func test_transition_neutralToNeutral_returnsNil() {
        let event = ZoneCoachingVoiceService.eventFor(
            from: .neutral,
            to: .neutral,
            currentBPM: 70, targetMin: 120, targetMax: 140
        )
        XCTAssertNil(event)
    }

    // MARK: - Debouncing

    func test_canSpeak_freshService_allowsFirstEvent() {
        let service = ZoneCoachingVoiceService(router: CaptainVoiceRouter(appleTTSProvider: MockVoiceProvider(kind: .appleTTS), miniMaxProvider: nil, featureFlagEnabled: { true }), autoSubscribe: false)
        let now = Date()
        service.now = { now }

        XCTAssertTrue(service.canSpeak(event: .workoutStart))
    }

    func test_canSpeak_withinGlobalCooldown_blocksDifferentCategories() {
        let service = ZoneCoachingVoiceService(router: CaptainVoiceRouter(appleTTSProvider: MockVoiceProvider(kind: .appleTTS), miniMaxProvider: nil, featureFlagEnabled: { true }), autoSubscribe: false)
        let t0 = Date()
        service.now = { t0 }

        service.recordSpoken(event: .workoutStart)

        // 5s later — within the 15s global cooldown.
        service.now = { t0.addingTimeInterval(5) }
        XCTAssertFalse(
            service.canSpeak(event: .aboveZone(currentBPM: 150, targetMax: 140)),
            "Global cooldown must suppress cross-category events within 15s."
        )
    }

    func test_canSpeak_afterGlobalCooldown_allowsDifferentCategory() {
        let service = ZoneCoachingVoiceService(router: CaptainVoiceRouter(appleTTSProvider: MockVoiceProvider(kind: .appleTTS), miniMaxProvider: nil, featureFlagEnabled: { true }), autoSubscribe: false)
        let t0 = Date()
        service.now = { t0 }

        service.recordSpoken(event: .workoutStart)

        // 16s later — past the 15s global cooldown. Different category,
        // so per-category cooldown doesn't apply.
        service.now = { t0.addingTimeInterval(16) }
        XCTAssertTrue(
            service.canSpeak(event: .aboveZone(currentBPM: 150, targetMax: 140))
        )
    }

    func test_canSpeak_samCategoryWithinPerCategoryCooldown_blocks() {
        let service = ZoneCoachingVoiceService(router: CaptainVoiceRouter(appleTTSProvider: MockVoiceProvider(kind: .appleTTS), miniMaxProvider: nil, featureFlagEnabled: { true }), autoSubscribe: false)
        let t0 = Date()
        service.now = { t0 }

        service.recordSpoken(event: .aboveZone(currentBPM: 150, targetMax: 140))

        // 20s later — past global 15s, but within per-category 30s for
        // "aboveZone". Must block.
        service.now = { t0.addingTimeInterval(20) }
        XCTAssertFalse(
            service.canSpeak(event: .aboveZone(currentBPM: 160, targetMax: 140)),
            "Per-category cooldown (30s) must suppress a second aboveZone event."
        )
    }

    func test_canSpeak_sameCategoryAfterPerCategoryCooldown_allows() {
        let service = ZoneCoachingVoiceService(router: CaptainVoiceRouter(appleTTSProvider: MockVoiceProvider(kind: .appleTTS), miniMaxProvider: nil, featureFlagEnabled: { true }), autoSubscribe: false)
        let t0 = Date()
        service.now = { t0 }

        service.recordSpoken(event: .aboveZone(currentBPM: 150, targetMax: 140))

        // 31s later — past both cooldowns.
        service.now = { t0.addingTimeInterval(31) }
        XCTAssertTrue(
            service.canSpeak(event: .aboveZone(currentBPM: 160, targetMax: 140))
        )
    }

    func test_aboveZone_argumentsSameCategoryRegardlessOfBPM() {
        let service = ZoneCoachingVoiceService(router: CaptainVoiceRouter(appleTTSProvider: MockVoiceProvider(kind: .appleTTS), miniMaxProvider: nil, featureFlagEnabled: { true }), autoSubscribe: false)
        let t0 = Date()
        service.now = { t0 }

        service.recordSpoken(event: .aboveZone(currentBPM: 150, targetMax: 140))

        // Different BPM, same category. Must still be debounced per category.
        service.now = { t0.addingTimeInterval(20) }
        XCTAssertFalse(
            service.canSpeak(event: .aboveZone(currentBPM: 170, targetMax: 140)),
            "aboveZone debouncing groups by category, not by BPM argument."
        )
    }

    func test_categoryKey_stableAcrossAssociatedValues() {
        XCTAssertEqual(
            ZoneCoachingVoiceService.categoryKey(for: .aboveZone(currentBPM: 150, targetMax: 140)),
            ZoneCoachingVoiceService.categoryKey(for: .aboveZone(currentBPM: 999, targetMax: 500))
        )
        XCTAssertEqual(
            ZoneCoachingVoiceService.categoryKey(for: .halfway(totalMinutes: 20)),
            ZoneCoachingVoiceService.categoryKey(for: .halfway(totalMinutes: 45))
        )
    }
}
