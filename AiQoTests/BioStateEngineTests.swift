import XCTest
@testable import AiQo

final class BioStateEngineTests: XCTestCase {

    private static let sampleMetrics = CaptainDailyHealthMetrics(
        stepCount: 6247,
        activeEnergyKilocalories: 342,
        averageOrCurrentHeartRateBPM: 73,
        sleepHours: 6.8
    )

    private func makeEngine(
        metrics: CaptainDailyHealthMetrics = sampleMetrics,
        clock: @escaping @Sendable () -> Date = Date.init,
        freshnessWindow: TimeInterval = 180
    ) -> BioStateEngine {
        BioStateEngine(
            fetchMetrics: { metrics },
            clock: clock,
            freshnessWindow: freshnessWindow
        )
    }

    func testCurrentReturnsSnapshotWithExactFields() async {
        let engine = makeEngine()
        let snap = await engine.current()

        // Vitals are stored EXACT (field names keep the `Bucketed` suffix only
        // for the Codable on-disk contract — no coarsening is applied).
        XCTAssertEqual(snap.stepsBucketed, 6247, "steps must be exact, not bucketed")
        XCTAssertEqual(snap.heartRateBucketed, 73, "heart rate must be exact, not bucketed")
        XCTAssertEqual(snap.sleepHoursBucketed, 6.8, "sleep hours must be exact, not bucketed")
        XCTAssertEqual(snap.caloriesBucketed, 342, "calories must be exact, not bucketed")
        XCTAssertTrue((1...7).contains(snap.dayOfWeek))
    }

    func testCachedSnapshotReturnedWithinFreshnessWindow() async {
        let engine = makeEngine(freshnessWindow: 60)
        let first = await engine.current()
        let second = await engine.current()
        XCTAssertEqual(first.timestamp, second.timestamp,
                       "second call within freshness window should return cached snapshot")
    }

    func testRefreshProducesNewTimestamp() async {
        var tick: TimeInterval = 0
        let engine = makeEngine(
            clock: {
                tick += 10
                return Date(timeIntervalSince1970: tick)
            },
            freshnessWindow: 1
        )

        let first = await engine.refresh()
        let second = await engine.refresh()
        XCTAssertNotEqual(first.timestamp, second.timestamp,
                          "refresh should bypass cache and produce a new timestamp")
    }

    func testTimeOfDayMapsAllHoursIntoValidBuckets() {
        for hour in 0..<24 {
            let calendar = Calendar(identifier: .gregorian)
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = hour
            components.minute = 0
            guard let date = calendar.date(from: components) else {
                XCTFail("Failed to construct date for hour \(hour)")
                continue
            }
            let bucket = BioSnapshot.TimeOfDay.current(clock: { date })
            XCTAssertTrue(
                Set<BioSnapshot.TimeOfDay>([.dawn, .morning, .midday, .afternoon, .evening, .night, .lateNight])
                    .contains(bucket),
                "hour \(hour) produced invalid bucket \(bucket)"
            )
        }
    }

    func testIsFastingReturnsFalseByDefault() async {
        let engine = makeEngine()
        let fasting = await engine.isFasting()
        XCTAssertFalse(fasting, "Ramadan detection not yet implemented — defaults to false")
    }

    func testNeedsRecoveryTrueOnShortSleep() async {
        let shortSleep = CaptainDailyHealthMetrics(
            stepCount: 3000,
            activeEnergyKilocalories: 100,
            averageOrCurrentHeartRateBPM: 72,
            sleepHours: 4.5
        )
        let engine = makeEngine(metrics: shortSleep)
        let recovery = await engine.needsRecovery()
        XCTAssertTrue(recovery, "4.5h sleep should trigger recovery flag")
    }

    func testNeedsRecoveryFalseOnHealthyNight() async {
        let healthyNight = CaptainDailyHealthMetrics(
            stepCount: 8000,
            activeEnergyKilocalories: 400,
            averageOrCurrentHeartRateBPM: 60,
            sleepHours: 8.0
        )
        let engine = makeEngine(metrics: healthyNight)
        let recovery = await engine.needsRecovery()
        XCTAssertFalse(recovery)
    }

    func testFailedFetchReturnsZeroedSnapshot() async {
        struct StubError: Error {}
        let engine = BioStateEngine(
            fetchMetrics: { throw StubError() }
        )
        let snap = await engine.current()
        XCTAssertEqual(snap.stepsBucketed, 0)
        XCTAssertEqual(snap.caloriesBucketed, 0)
        XCTAssertNil(snap.heartRateBucketed)
        XCTAssertNil(snap.sleepHoursBucketed)
    }
}
