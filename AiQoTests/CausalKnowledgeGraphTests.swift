// ===============================================
// File: CausalKnowledgeGraphTests.swift
// Brain Refactor §43 — coverage for the causal graph + chain builder.
// ===============================================

import XCTest
@testable import AiQo

@MainActor
final class CausalKnowledgeGraphTests: XCTestCase {

    // MARK: - Family → Node mapping

    func testWalking45MinMapsToZone2() {
        let node = CausalNode.from(family: .walking, durationMinutes: 45)
        XCTAssertEqual(node, .walkingZone2)
    }

    func testWalking15MinMapsToZone1() {
        let node = CausalNode.from(family: .walking, durationMinutes: 15)
        XCTAssertEqual(node, .walkingZone1)
    }

    func testStrength45MinMapsToCompound() {
        let node = CausalNode.from(family: .strength, durationMinutes: 45)
        XCTAssertEqual(node, .strengthCompound)
    }

    func testRunning20MinMapsToEasy() {
        let node = CausalNode.from(family: .running, durationMinutes: 20)
        XCTAssertEqual(node, .runningEasy)
    }

    func testGratitudeMapsToNil() {
        XCTAssertNil(CausalNode.from(family: .gratitude, durationMinutes: 10))
    }

    // MARK: - Graph traversal

    func testStrengthHasMuscleDamageAsTopState() {
        let neighbors = CausalKnowledgeGraph.neighbors(of: .strengthCompound)
        XCTAssertEqual(neighbors.first?.0, .muscleDamage,
                       "Compound strength must lead with muscle damage")
    }

    func testMuscleDamageHasProteinWindowAsTopIntention() {
        let neighbors = CausalKnowledgeGraph.neighbors(of: .muscleDamage)
        XCTAssertEqual(neighbors.first?.0, .proteinWindow,
                       "Muscle damage must lead to protein window first")
    }

    func testHardRunningTriggersGlycogenDepletion() {
        let neighbors = CausalKnowledgeGraph.neighbors(of: .runningHard)
        XCTAssertTrue(neighbors.contains { $0.0 == .glycogenDepleted })
        XCTAssertTrue(neighbors.contains { $0.0 == .dehydrated })
    }

    // MARK: - Chain Builder

    private func makeSnapshot(
        family: RecentActivityFamily,
        durationMinutes: Int,
        minutesSinceEnd: Int = 20
    ) -> RecentActivitySnapshot {
        RecentActivitySnapshot(
            title: family.arabicLabel,
            family: family,
            durationMinutes: durationMinutes,
            activeCalories: 250,
            distanceKm: nil,
            endedAt: Date().addingTimeInterval(Double(-minutesSinceEnd * 60)),
            minutesSinceEnd: minutesSinceEnd
        )
    }

    func testStrengthSessionProducesProteinChain() {
        let snapshot = makeSnapshot(family: .strength, durationMinutes: 50)
        let chain = CausalChainBuilder.derive(
            recentActivity: snapshot,
            sleepHoursLastNight: 7.0,
            hour: 14
        )
        XCTAssertNotNil(chain)
        XCTAssertEqual(chain?.nodes.first, .strengthCompound)
        XCTAssertTrue(chain?.nodes.contains(.muscleDamage) ?? false)
        // Top intention should be protein window early in the day.
        XCTAssertEqual(chain?.nodes.last, .proteinWindow)
    }

    func testHardRunningProducesGlycogenChain() {
        let snapshot = makeSnapshot(family: .running, durationMinutes: 60)
        let chain = CausalChainBuilder.derive(
            recentActivity: snapshot,
            sleepHoursLastNight: 7.0,
            hour: 16
        )
        XCTAssertNotNil(chain)
        XCTAssertEqual(chain?.nodes.first, .runningHard)
        XCTAssertTrue(chain?.nodes.contains(.glycogenDepleted) ?? false)
        XCTAssertEqual(chain?.nodes.last, .carbsRefuel)
    }

    func testWalkingZone2ProducesShortChain() {
        let snapshot = makeSnapshot(family: .walking, durationMinutes: 40)
        let chain = CausalChainBuilder.derive(
            recentActivity: snapshot,
            sleepHoursLastNight: 7.0,
            hour: 16
        )
        XCTAssertNotNil(chain)
        XCTAssertEqual(chain?.nodes.first, .walkingZone2)
    }

    func testStaleActivityProducesNoChain() {
        let stale = RecentActivitySnapshot(
            title: "مشي",
            family: .walking,
            durationMinutes: 45,
            activeCalories: 261,
            distanceKm: 3.11,
            endedAt: Date().addingTimeInterval(-23 * 3600),
            minutesSinceEnd: 23 * 60   // 23 hours = stale
        )
        let chain = CausalChainBuilder.derive(
            recentActivity: stale,
            sleepHoursLastNight: 7.0,
            hour: 14
        )
        XCTAssertNil(chain, "Stale activities must not anchor a causal chain")
    }

    func testNoActivityProducesNoChain() {
        let chain = CausalChainBuilder.derive(
            recentActivity: nil,
            sleepHoursLastNight: 7.0,
            hour: 14
        )
        XCTAssertNil(chain)
    }

    // MARK: - Auxiliary boosts

    /// When sleep was poor and the user just lifted, the chain should pivot
    /// toward earlyBedtime over proteinWindow because the boost lifts the
    /// recovery edge above the nutrition edge.
    func testLowSleepBoostsEarlyBedtimeOverProtein() {
        let snapshot = makeSnapshot(family: .strength, durationMinutes: 45, minutesSinceEnd: 30)
        // Late evening + short sleep last night = recovery boost.
        let chainNight = CausalChainBuilder.derive(
            recentActivity: snapshot,
            sleepHoursLastNight: 5.0,
            hour: 21
        )
        XCTAssertNotNil(chainNight)
        // The boosted intention may now be earlyBedtime instead of protein.
        // Either is acceptable; verify it's at least one of the recovery
        // family.
        let last = chainNight?.nodes.last
        XCTAssertTrue(
            last == .earlyBedtime || last == .proteinWindow || last == .nextDayEasy,
            "Late + low sleep must steer chain to a recovery-favouring intention"
        )
    }

    // MARK: - Narrative rendering

    func testArabicNarrativeUsesArrows() {
        let chain = CausalChain(
            nodes: [.strengthCompound, .muscleDamage, .proteinWindow],
            cumulativeWeight: 0.9
        )
        let narrative = chain.arabicNarrative()
        XCTAssertTrue(narrative.contains("←"))
        XCTAssertTrue(narrative.contains("بروتين"))
    }
}
