import Foundation

struct QuestEvaluator {
    let calendar: Calendar
    private let keyFactory: QuestDateKeyFactory

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.keyFactory = QuestDateKeyFactory(calendar: calendar)
    }

    func initialRecord(for questId: String, now: Date) -> QuestProgressRecord {
        QuestProgressRecord(questId: questId, lastUpdated: now)
    }

    func applyPeriodResets(
        definition: QuestDefinition,
        record: inout QuestProgressRecord,
        now: Date
    ) {
        let dailyKey = keyFactory.dailyKey(for: now)
        let weeklyKey = keyFactory.weeklyKey(for: now)

        switch definition.type {
        case .daily:
            if record.resetKeyDaily != dailyKey {
                record.metricAValue = 0
                record.metricBValue = 0
                record.currentTier = 0
                record.isCompleted = false
                record.completedAt = nil
                record.isStarted = false
                record.startedAt = nil
                record.resetKeyDaily = dailyKey
            }

        case .weekly:
            if record.resetKeyWeekly != weeklyKey {
                record.metricAValue = 0
                record.metricBValue = 0
                record.currentTier = 0
                record.isCompleted = false
                record.completedAt = nil
                record.streakCount = 0
                record.isStarted = false
                record.startedAt = nil
                record.resetKeyWeekly = weeklyKey
            }

        case .streak, .combo:
            if record.resetKeyDaily != dailyKey {
                if let lastStreakDate = record.lastStreakDate {
                    let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now
                    if !calendar.isDate(lastStreakDate, inSameDayAs: yesterday) {
                        record.streakCount = 0
                    }
                }
                record.resetKeyDaily = dailyKey
            }

        case .oneTime, .cumulative:
            break
        }

        record.lastUpdated = now
    }

    func evaluateTier(for definition: QuestDefinition, metricA: Double, metricB: Double) -> Int {
        var tier = 0

        for (index, requirement) in definition.tiers.enumerated() {
            switch requirement {
            case let .singleMetric(value, _):
                if metricA >= value {
                    tier = index + 1
                }

            case let .dualMetric(valueA, _, valueB, _):
                if metricA >= valueA, metricB >= valueB {
                    tier = index + 1
                }
            }
        }

        return tier
    }

    func evaluateAndAssignTier(
        definition: QuestDefinition,
        record: inout QuestProgressRecord,
        now: Date
    ) {
        if definition.isStageOneBooleanQuest {
            let completed = record.isCompleted || record.metricAValue >= 1
            record.isCompleted = completed

            if completed {
                record.metricAValue = 1
                record.metricBValue = 0
                record.currentTier = 3
                record.completedAt = record.completedAt ?? now
                record.lastCompletionDate = calendar.startOfDay(for: now)
            } else {
                record.metricAValue = 0
                record.metricBValue = 0
                record.currentTier = 0
                record.completedAt = nil
            }

            record.lastUpdated = now
            return
        }

        let maxTarget = maxTargetValues(definition: definition)
        record.metricAValue = min(max(record.metricAValue, 0), maxTarget.valueA)
        if maxTarget.valueB > 0 {
            record.metricBValue = min(max(record.metricBValue, 0), maxTarget.valueB)
        } else {
            record.metricBValue = max(record.metricBValue, 0)
        }

        let newTier = evaluateTier(for: definition, metricA: record.metricAValue, metricB: record.metricBValue)
        record.currentTier = newTier
        record.isCompleted = newTier >= 3

        if newTier >= 3 {
            record.completedAt = record.completedAt ?? now
            record.lastCompletionDate = calendar.startOfDay(for: now)
        }
    }

    func updateStreak(
        definition: QuestDefinition,
        record: inout QuestProgressRecord,
        qualifiedToday: Bool,
        now: Date
    ) {
        guard definition.type == .streak || definition.type == .combo else { return }

        let today = calendar.startOfDay(for: now)

        if qualifiedToday {
            if let lastDate = record.lastStreakDate, calendar.isDate(lastDate, inSameDayAs: today) {
                record.metricAValue = Double(record.streakCount)
                record.metricBValue = 0
                return
            }

            if let lastDate = record.lastStreakDate {
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
                if calendar.isDate(lastDate, inSameDayAs: yesterday) {
                    record.streakCount += 1
                } else {
                    record.streakCount = 1
                }
            } else {
                record.streakCount = 1
            }

            record.lastStreakDate = today
        } else {
            if let lastDate = record.lastStreakDate {
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
                if !calendar.isDate(lastDate, inSameDayAs: today) && !calendar.isDate(lastDate, inSameDayAs: yesterday) {
                    record.streakCount = 0
                }
            } else {
                record.streakCount = 0
            }
        }

        record.metricAValue = Double(record.streakCount)
        record.metricBValue = 0
        record.lastUpdated = now
    }

    func cardProgressModel(
        definition: QuestDefinition,
        record: QuestProgressRecord
    ) -> QuestCardProgressModel {
        let target = targetValuesForCurrentTier(definition: definition, currentTier: record.currentTier)
        let maxTarget = maxTargetValues(definition: definition)

        let maxDisplayA = target.valueA > 0 ? target.valueA : maxTarget.valueA
        let maxDisplayB = target.valueB > 0 ? target.valueB : maxTarget.valueB

        return QuestCardProgressModel(
            tier: min(max(record.currentTier, 0), 3),
            metricAValue: min(max(record.metricAValue, 0), maxDisplayA),
            metricBValue: min(max(record.metricBValue, 0), maxDisplayB),
            targetAValue: target.valueA,
            targetBValue: target.valueB,
            metricAUnit: target.unitA,
            metricBUnit: target.unitB
        )
    }

    func targetValuesForCurrentTier(definition: QuestDefinition, currentTier: Int) -> (valueA: Double, unitA: QuestMetricUnit, valueB: Double, unitB: QuestMetricUnit) {
        let index = max(0, min(currentTier, 2))

        let requirement = definition.tiers[index]

        switch requirement {
        case let .singleMetric(value, unit):
            return (value, unit, 0, .none)
        case let .dualMetric(valueA, unitA, valueB, unitB):
            return (valueA, unitA, valueB, unitB)
        }
    }

    func maxTargetValues(definition: QuestDefinition) -> (valueA: Double, unitA: QuestMetricUnit, valueB: Double, unitB: QuestMetricUnit) {
        guard let last = definition.tiers.last else {
            return (0, .none, 0, .none)
        }

        switch last {
        case let .singleMetric(value, unit):
            return (value, unit, 0, .none)
        case let .dualMetric(valueA, unitA, valueB, unitB):
            return (valueA, unitA, valueB, unitB)
        }
    }

    func weeklyRange(for date: Date) -> [Date] {
        let start = keyFactory.startOfWeek(for: date)

        var dates: [Date] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            dates.append(day)
        }

        return dates
    }
}
