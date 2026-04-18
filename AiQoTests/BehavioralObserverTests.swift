import XCTest
@testable import AiQo

final class BehavioralObserverTests: XCTestCase {

    func testRecordAppendsEventWithoutCrashing() async {
        let observer = BehavioralObserver()
        await observer.record(.appOpened)
        await observer.record(.captainChatStarted)
        let count = await observer.bufferedEventCount()
        XCTAssertEqual(count, 2)
    }

    func testBufferDropsOldestEventsWhenFull() async {
        let observer = BehavioralObserver(maxEventBuffer: 5)
        for _ in 0..<10 {
            await observer.record(.appOpened)
        }
        let count = await observer.bufferedEventCount()
        XCTAssertEqual(count, 5, "buffer should be capped at maxEventBuffer")
    }

    func testMineWithNoEventsReturnsZero() async {
        let observer = BehavioralObserver()
        let count = await observer.mineAndNominate()
        XCTAssertEqual(count, 0)
    }

    func testMineBelowThresholdProducesNoPatterns() async {
        let observer = BehavioralObserver()
        // 2 workouts < 3 threshold
        await observer.record(.workoutStarted(kind: "running"))
        await observer.record(.workoutStarted(kind: "running"))
        let count = await observer.mineAndNominate()
        XCTAssertEqual(count, 0)
    }
}

final class ContextSensorTests: XCTestCase {

    func testCaptureReturnsCoherentContext() async {
        let stubMetrics = CaptainDailyHealthMetrics(
            stepCount: 4500,
            activeEnergyKilocalories: 200,
            averageOrCurrentHeartRateBPM: 68,
            sleepHours: 7.2
        )
        let bioEngine = BioStateEngine(fetchMetrics: { stubMetrics })
        let observer = BehavioralObserver()
        await observer.record(.appOpened)
        await observer.record(.captainChatStarted)

        let sensor = ContextSensor(bioEngine: bioEngine, behavioralObserver: observer)
        let ctx = await sensor.capture()

        XCTAssertEqual(ctx.bio.stepsBucketed, 4500)
        XCTAssertTrue((1...7).contains(ctx.dayOfWeek))
        XCTAssertEqual(ctx.recentEventCount, 2)
        XCTAssertFalse(ctx.needsRecovery, "7.2h sleep + nil HRV should not require recovery")
        XCTAssertLessThan(ctx.capturedAt.timeIntervalSinceNow, 1.0)
    }
}

final class BackgroundCoordinatorTests: XCTestCase {

    func testNightlyTaskIDMatchesInfoPlistPermittedIdentifier() {
        XCTAssertEqual(BackgroundCoordinator.nightlyTaskID, "aiqo.brain.nightly")
    }

    func testNext3amFromMiddayReturnsTomorrow3am() {
        let calendar = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 4
        comps.day = 19
        comps.hour = 12
        comps.minute = 0
        guard let noon = calendar.date(from: comps) else {
            XCTFail("failed to construct midday reference date")
            return
        }

        let next = BackgroundCoordinator.next3am(after: noon)
        let nextComps = calendar.dateComponents([.day, .hour], from: next)
        XCTAssertEqual(nextComps.hour, 3)
        XCTAssertEqual(nextComps.day, 20, "3am at midday should roll over to tomorrow")
    }

    func testNext3amFromEarlyMorningReturnsToday3am() {
        let calendar = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 4
        comps.day = 19
        comps.hour = 1
        comps.minute = 0
        guard let earlyMorning = calendar.date(from: comps) else {
            XCTFail("failed to construct early-morning reference date")
            return
        }

        let next = BackgroundCoordinator.next3am(after: earlyMorning)
        let nextComps = calendar.dateComponents([.day, .hour], from: next)
        XCTAssertEqual(nextComps.hour, 3)
        XCTAssertEqual(nextComps.day, 19, "3am at 1am should be later today, not tomorrow")
    }
}
