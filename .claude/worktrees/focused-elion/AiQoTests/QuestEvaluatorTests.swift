import XCTest
@testable import AiQo

final class QuestEvaluatorTests: XCTestCase {
    private var calendar: Calendar!
    private var evaluator: QuestEvaluator!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 3 * 3600) ?? .current
        self.calendar = calendar
        self.evaluator = QuestEvaluator(calendar: calendar)
    }

    func testDailyResetClearsMetricsOnNewDay() {
        let definition = QuestDefinition(
            id: "daily.quest",
            stageIndex: 1,
            questIndex: 1,
            title: "daily",
            type: .daily,
            source: .manual,
            tiers: [
                .singleMetric(value: 1, unit: .count),
                .singleMetric(value: 2, unit: .count),
                .singleMetric(value: 3, unit: .count)
            ],
            deepLinkAction: nil,
            metricAKey: .manualCount,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        )

        var record = QuestProgressRecord(questId: definition.id)
        record.metricAValue = 42
        record.metricBValue = 11
        record.currentTier = 3
        record.resetKeyDaily = "2026-02-25"

        let now = date(2026, 2, 26)
        evaluator.applyPeriodResets(definition: definition, record: &record, now: now)

        XCTAssertEqual(record.metricAValue, 0)
        XCTAssertEqual(record.metricBValue, 0)
        XCTAssertEqual(record.currentTier, 0)
        XCTAssertEqual(record.resetKeyDaily, "2026-02-26")
    }

    func testStreakIncrementAndResetWhenBroken() {
        let definition = QuestDefinition(
            id: "streak.quest",
            stageIndex: 1,
            questIndex: 1,
            title: "streak",
            type: .streak,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 1, unit: .days),
                .singleMetric(value: 2, unit: .days),
                .singleMetric(value: 3, unit: .days)
            ],
            deepLinkAction: nil,
            metricAKey: .comboStreakDays,
            metricBKey: .none,
            streakDailyTargetA: 10,
            streakDailyTargetB: nil
        )

        var record = QuestProgressRecord(questId: definition.id)
        record.streakCount = 2
        record.lastStreakDate = date(2026, 2, 25)

        evaluator.updateStreak(definition: definition, record: &record, qualifiedToday: true, now: date(2026, 2, 26))

        XCTAssertEqual(record.streakCount, 3)
        XCTAssertEqual(record.metricAValue, 3)

        evaluator.updateStreak(definition: definition, record: &record, qualifiedToday: false, now: date(2026, 2, 28))
        XCTAssertEqual(record.streakCount, 0)
        XCTAssertEqual(record.metricAValue, 0)
    }

    func testTierEvaluationDualMetricAndCombo() {
        let cameraDefinition = QuestDefinition(
            id: "camera.quest",
            stageIndex: 2,
            questIndex: 1,
            title: "camera",
            type: .oneTime,
            source: .camera,
            tiers: [
                .dualMetric(valueA: 10, unitA: .count, valueB: 70, unitB: .percent),
                .dualMetric(valueA: 15, unitA: .count, valueB: 85, unitB: .percent),
                .dualMetric(valueA: 20, unitA: .count, valueB: 100, unitB: .percent)
            ],
            deepLinkAction: nil,
            metricAKey: .pushupReps,
            metricBKey: .cameraAccuracy,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        )

        let tier = evaluator.evaluateTier(for: cameraDefinition, metricA: 18, metricB: 90)
        XCTAssertEqual(tier, 2)

        let comboDefinition = QuestDefinition(
            id: "combo.quest",
            stageIndex: 10,
            questIndex: 3,
            title: "combo",
            type: .combo,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 2, unit: .days),
                .singleMetric(value: 3, unit: .days),
                .singleMetric(value: 4, unit: .days)
            ],
            deepLinkAction: nil,
            metricAKey: .comboStreakDays,
            metricBKey: .none,
            streakDailyTargetA: 7,
            streakDailyTargetB: 2.5
        )

        var record = QuestProgressRecord(questId: comboDefinition.id)
        evaluator.updateStreak(definition: comboDefinition, record: &record, qualifiedToday: true, now: date(2026, 2, 24))
        evaluator.updateStreak(definition: comboDefinition, record: &record, qualifiedToday: true, now: date(2026, 2, 25))
        evaluator.updateStreak(definition: comboDefinition, record: &record, qualifiedToday: true, now: date(2026, 2, 26))

        evaluator.evaluateAndAssignTier(definition: comboDefinition, record: &record, now: date(2026, 2, 26))
        XCTAssertEqual(record.currentTier, 2)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(calendar: calendar, year: year, month: month, day: day, hour: 12)
        return calendar.date(from: components) ?? Date()
    }
}
