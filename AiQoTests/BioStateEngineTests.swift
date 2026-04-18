import XCTest
@testable import AiQo

final class BioStateEngineTests: XCTestCase {

    func testCurrentReturnsSnapshotWithSaneFields() async {
        let engine = BioStateEngine()
        let snap = await engine.current()

        XCTAssertGreaterThanOrEqual(snap.stepsBucketed, 0)
        XCTAssertGreaterThanOrEqual(snap.caloriesBucketed, 0)
        XCTAssertTrue((1...7).contains(snap.dayOfWeek),
                      "dayOfWeek should be Calendar.weekday (1...7)")
    }

    func testCachedSnapshotReturnedWithinFreshnessWindow() async {
        let engine = BioStateEngine(freshnessWindow: 60)
        let first = await engine.current()
        let second = await engine.current()
        XCTAssertEqual(first.timestamp, second.timestamp,
                       "second call within freshness window should return cached snapshot")
    }

    func testRefreshProducesNewTimestamp() async {
        var tick: TimeInterval = 0
        let engine = BioStateEngine(clock: {
            tick += 10
            return Date(timeIntervalSince1970: tick)
        }, freshnessWindow: 1)

        let first = await engine.refresh()
        let second = await engine.refresh()
        XCTAssertNotEqual(first.timestamp, second.timestamp,
                          "refresh should bypass cache and produce a new timestamp")
    }

    func testBucketingFloorsStepsTo500() async {
        let engine = BioStateEngine()
        let snap = await engine.current()
        XCTAssertEqual(snap.stepsBucketed % 500, 0, "steps should be bucketed to 500")
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
        let engine = BioStateEngine()
        let fasting = await engine.isFasting()
        XCTAssertFalse(fasting, "Ramadan detection not yet implemented — defaults to false")
    }
}
