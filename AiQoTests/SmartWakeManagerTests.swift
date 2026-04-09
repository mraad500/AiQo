import XCTest
@testable import AiQo

@MainActor
final class SmartWakeEngineTests: XCTestCase {
    private var originalLanguage: AppLanguage!

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    override func setUp() {
        super.setUp()
        originalLanguage = AppSettingsStore.shared.appLanguage
        LocalizationManager.shared.setLanguage(.arabic)
    }

    override func tearDown() {
        LocalizationManager.shared.setLanguage(originalLanguage)
        super.tearDown()
    }

    func testBedtimeRecommendationsUseNinetyMinuteCyclesWithSleepOnsetDelay() {
        let engine = SmartWakeEngine(calendar: calendar)
        let bedtime = date(year: 2026, month: 3, day: 7, hour: 22, minute: 30)

        let recommendations = engine.recommendations(fromBedtime: bedtime)

        XCTAssertEqual(recommendations.map(\.cycleCount), [6, 5, 4, 3])
        XCTAssertEqual(recommendations.map(\.wakeDate), [
            date(year: 2026, month: 3, day: 8, hour: 7, minute: 44),
            date(year: 2026, month: 3, day: 8, hour: 6, minute: 14),
            date(year: 2026, month: 3, day: 8, hour: 4, minute: 44),
            date(year: 2026, month: 3, day: 8, hour: 3, minute: 14)
        ])
        XCTAssertEqual(recommendations.first?.badge, "الأفضل")
        XCTAssertEqual(recommendations.first?.isBest, true)
    }

    func testWakeTimeRecommendationsChooseNearestCycleInsideWindow() {
        let engine = SmartWakeEngine(calendar: calendar)
        let bedtime = date(year: 2026, month: 3, day: 7, hour: 22, minute: 36)
        let latestWakeTime = date(year: 2026, month: 3, day: 8, hour: 6, minute: 30)

        let recommendations = engine.recommendations(
            latestWakeTime: latestWakeTime,
            window: .ten,
            referenceBedtime: bedtime
        )

        XCTAssertEqual(recommendations.first?.wakeDate, date(year: 2026, month: 3, day: 8, hour: 6, minute: 20))
        XCTAssertEqual(recommendations.first?.cycleCount, 5)
        XCTAssertEqual(recommendations.first?.badge, "الأفضل")
        XCTAssertEqual(recommendations.first?.isWithinSmartWindow, true)
    }

    func testWakeTimeRecommendationsFallbackToLatestWakeTimeWhenNoAlignedCycleExists() {
        let engine = SmartWakeEngine(calendar: calendar)
        let bedtime = date(year: 2026, month: 3, day: 7, hour: 22, minute: 30)
        let latestWakeTime = date(year: 2026, month: 3, day: 8, hour: 6, minute: 10)

        let recommendations = engine.recommendations(
            latestWakeTime: latestWakeTime,
            window: .ten,
            referenceBedtime: bedtime
        )

        XCTAssertEqual(recommendations.first?.wakeDate, latestWakeTime)
        XCTAssertEqual(recommendations.first?.badge, "الأفضل")
        XCTAssertEqual(recommendations.first?.isBest, true)
        XCTAssertEqual(recommendations.first?.isWithinSmartWindow, true)
    }

    func testRecommendationsUseEnglishLabelsWhenAppLanguageIsEnglish() throws {
        LocalizationManager.shared.setLanguage(.english)

        let engine = SmartWakeEngine(calendar: calendar)
        let bedtime = date(year: 2026, month: 3, day: 7, hour: 22, minute: 30)

        let recommendation = try XCTUnwrap(engine.recommendations(fromBedtime: bedtime).first)

        XCTAssertEqual(recommendation.badge, "Best")
        XCTAssertEqual(recommendation.confidenceLabel, "High confidence")
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return calendar.date(from: components) ?? Date()
    }
}
