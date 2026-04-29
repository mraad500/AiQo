import XCTest
@testable import AiQo

final class HydrationEvaluatorTests: XCTestCase {

    // MARK: - Test Helpers

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(hour: Int, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 4
        comps.day = 22
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps)!
    }

    private func settings(
        enabled: Bool = true,
        goal: Double = 2000,
        wakeStart: Int = 8,
        wakeEnd: Int = 24,
        quietStart: Int = 22,
        quietEnd: Int = 7,
        cooldown: Int = 25
    ) -> HydrationSettings {
        HydrationSettings(
            smartTrackingEnabled: enabled,
            goalML: goal,
            wakeStartHour: wakeStart,
            wakeEndHour: wakeEnd,
            quietStartHour: quietStart,
            quietEndHour: quietEnd,
            cooldownMinutes: cooldown
        )
    }

    // MARK: - expectedByNow

    func testExpectedByNow_zeroBeforeWakeWindow() {
        let expected = HydrationEvaluator.expectedByNowML(
            now: date(hour: 7),
            settings: settings(),
            calendar: calendar
        )
        XCTAssertEqual(expected, 0, accuracy: 0.01)
    }

    func testExpectedByNow_fullAfterWakeWindow() {
        let expected = HydrationEvaluator.expectedByNowML(
            now: date(hour: 23, minute: 59),
            settings: settings(wakeEnd: 23),
            calendar: calendar
        )
        XCTAssertEqual(expected, 2000, accuracy: 0.01)
    }

    func testExpectedByNow_halfwayThroughWindow() {
        // Window 8→24 is 16h. Halfway = 16:00.
        let expected = HydrationEvaluator.expectedByNowML(
            now: date(hour: 16),
            settings: settings(),
            calendar: calendar
        )
        XCTAssertEqual(expected, 1000, accuracy: 0.01)
    }

    // MARK: - Pace classification

    func testPaceStatus_aheadWhenConsumedExceedsExpected() {
        let pace = HydrationEvaluator.paceStatus(consumedML: 1200, expectedByNowML: 1000)
        XCTAssertEqual(pace, .ahead)
    }

    func testPaceStatus_onTrackWithin10PercentBand() {
        XCTAssertEqual(HydrationEvaluator.paceStatus(consumedML: 950, expectedByNowML: 1000), .onTrack)
        XCTAssertEqual(HydrationEvaluator.paceStatus(consumedML: 1050, expectedByNowML: 1000), .onTrack)
    }

    func testPaceStatus_behindBetween60And90Percent() {
        XCTAssertEqual(HydrationEvaluator.paceStatus(consumedML: 800, expectedByNowML: 1000), .behind)
        XCTAssertEqual(HydrationEvaluator.paceStatus(consumedML: 650, expectedByNowML: 1000), .behind)
    }

    func testPaceStatus_veryBehindBelow60Percent() {
        XCTAssertEqual(HydrationEvaluator.paceStatus(consumedML: 500, expectedByNowML: 1000), .veryBehind)
        XCTAssertEqual(HydrationEvaluator.paceStatus(consumedML: 0, expectedByNowML: 1000), .veryBehind)
    }

    func testPaceStatus_zeroExpectedIsOnTrack() {
        // Before wake window starts — no expectation, so onTrack (never behind).
        XCTAssertEqual(HydrationEvaluator.paceStatus(consumedML: 0, expectedByNowML: 0), .onTrack)
    }

    // MARK: - Quiet hours

    func testQuietHours_overnightWindow() {
        let s = settings()
        XCTAssertTrue(HydrationEvaluator.isQuietHours(now: date(hour: 23), settings: s, calendar: calendar))
        XCTAssertTrue(HydrationEvaluator.isQuietHours(now: date(hour: 3), settings: s, calendar: calendar))
        XCTAssertFalse(HydrationEvaluator.isQuietHours(now: date(hour: 10), settings: s, calendar: calendar))
    }

    // MARK: - Evaluate — suppression rules

    func testEvaluate_suppressesWhenDisabled() {
        let state = HydrationDailyState.zero
        let result = HydrationEvaluator.evaluate(
            state: state,
            now: date(hour: 10),
            settings: settings(enabled: false),
            calendar: calendar
        )
        XCTAssertEqual(result, .suppress(reason: .trackingDisabled))
    }

    func testEvaluate_suppressesBeforeWakeWindow() {
        let state = HydrationDailyState.zero
        let result = HydrationEvaluator.evaluate(
            state: state,
            now: date(hour: 6),
            settings: settings(),
            calendar: calendar
        )
        XCTAssertEqual(result, .suppress(reason: .beforeWakeWindow))
    }

    func testEvaluate_suppressesDuringQuietHours() {
        let state = HydrationEvaluator.dailyState(
            consumedML: 0,
            lastDrinkDate: nil,
            lastDrinkSource: nil,
            now: date(hour: 23),
            settings: settings(),
            calendar: calendar
        )
        let result = HydrationEvaluator.evaluate(
            state: state,
            now: date(hour: 23),
            settings: settings(),
            calendar: calendar
        )
        XCTAssertEqual(result, .suppress(reason: .quietHours))
    }

    func testEvaluate_suppressesWhenRecentDrink() {
        let now = date(hour: 16)
        let recentDrink = now.addingTimeInterval(-10 * 60) // 10 min ago
        let state = HydrationEvaluator.dailyState(
            consumedML: 200, // very behind at midday
            lastDrinkDate: recentDrink,
            lastDrinkSource: .manual,
            now: now,
            settings: settings(),
            calendar: calendar
        )
        let result = HydrationEvaluator.evaluate(
            state: state,
            now: now,
            settings: settings(),
            calendar: calendar
        )
        XCTAssertEqual(result, .suppress(reason: .recentDrink))
    }

    func testEvaluate_suppressesWhenOnTrack() {
        let now = date(hour: 16) // expect 1000 mL
        let state = HydrationEvaluator.dailyState(
            consumedML: 1000,
            lastDrinkDate: now.addingTimeInterval(-60 * 60),
            lastDrinkSource: .appleHealth,
            now: now,
            settings: settings(),
            calendar: calendar
        )
        let result = HydrationEvaluator.evaluate(
            state: state,
            now: now,
            settings: settings(),
            calendar: calendar
        )
        XCTAssertEqual(result, .suppress(reason: .paceOK))
    }

    // MARK: - Evaluate — reminder triggers

    func testEvaluate_remindsGentlyWhenBehind() {
        let now = date(hour: 16)
        let state = HydrationEvaluator.dailyState(
            consumedML: 800, // 80% of expected 1000 → behind
            lastDrinkDate: now.addingTimeInterval(-90 * 60),
            lastDrinkSource: .manual,
            now: now,
            settings: settings(),
            calendar: calendar
        )
        let result = HydrationEvaluator.evaluate(
            state: state,
            now: now,
            settings: settings(),
            calendar: calendar
        )
        XCTAssertEqual(result, .remind(intensity: .gentle))
    }

    func testEvaluate_remindsStronglyWhenVeryBehind() {
        let now = date(hour: 16)
        let state = HydrationEvaluator.dailyState(
            consumedML: 300, // 30% of expected 1000 → very behind
            lastDrinkDate: nil,
            lastDrinkSource: nil,
            now: now,
            settings: settings(),
            calendar: calendar
        )
        let result = HydrationEvaluator.evaluate(
            state: state,
            now: now,
            settings: settings(),
            calendar: calendar
        )
        XCTAssertEqual(result, .remind(intensity: .stronger))
    }

    // MARK: - Localization phrase selection

    func testPhraseSelection_gentleArabic() {
        let phrase = HydrationPhrases.phrase(for: .gentle, language: .arabic)
        XCTAssertFalse(phrase.title.isEmpty)
        XCTAssertFalse(phrase.body.isEmpty)
        // Iraqi-dialect soft reminder — no medical terms
        XCTAssertFalse(phrase.body.lowercased().contains("liter"))
        XCTAssertFalse(phrase.body.contains("لتر"))
    }

    func testPhraseSelection_strongerEnglish() {
        let phrase = HydrationPhrases.phrase(for: .stronger, language: .english)
        XCTAssertFalse(phrase.title.isEmpty)
        XCTAssertFalse(phrase.body.isEmpty)
    }

    func testPhraseSelection_distinctBetweenGentleAndStronger() {
        let gentle = HydrationPhrases.phrase(for: .gentle, language: .arabic)
        let stronger = HydrationPhrases.phrase(for: .stronger, language: .arabic)
        XCTAssertNotEqual(gentle.body, stronger.body)
    }

    // MARK: - DailyState remaining / progress

    func testDailyState_remainingNeverNegative() {
        let state = HydrationDailyState(
            goalML: 2000,
            consumedML: 2500,
            expectedByNowML: 1000,
            lastDrinkDate: nil,
            lastDrinkSource: nil,
            paceStatus: .ahead
        )
        XCTAssertEqual(state.remainingML, 0)
        XCTAssertEqual(state.progressFraction, 1.0, accuracy: 0.001)
    }

    // MARK: - Dedup (single canonical source)

    func testDailyState_singleCanonicalConsumedValue() {
        // HealthKit is the single source of truth: both manual writes (via
        // logWater) and Apple Health-originated samples are summed by
        // HKStatisticsQuery with options: .cumulativeSum. The evaluator never
        // sees duplicates because consumedML is always the summed total.
        // This test documents the invariant that dailyState trusts the input.
        let state = HydrationEvaluator.dailyState(
            consumedML: 1500,
            lastDrinkDate: Date(),
            lastDrinkSource: .manual,
            now: date(hour: 16),
            settings: settings(),
            calendar: calendar
        )
        XCTAssertEqual(state.consumedML, 1500, accuracy: 0.01)
    }
}
