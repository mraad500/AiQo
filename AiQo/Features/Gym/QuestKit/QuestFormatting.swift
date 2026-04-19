import Foundation

func questAppLocale() -> Locale {
    AppSettingsStore.shared.appLanguage == .arabic
        ? Locale(identifier: "ar_AE")
        : Locale(identifier: "en_US_POSIX")
}

func questIsArabicLanguage() -> Bool {
    AppSettingsStore.shared.appLanguage == .arabic
}

func questLocalizedText(_ key: String) -> String {
    let lang = AppSettingsStore.shared.appLanguage.rawValue
    if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        let localized = bundle.localizedString(forKey: key, value: nil, table: nil)
        if localized != key {
            return localized
        }
    }

    return NSLocalizedString(key, comment: "")
}

func questFormatValue(_ value: Double, unit: QuestMetricUnit) -> String {
    let numericText: String
    switch unit {
    case .liters, .hours, .kilometers:
        numericText = value.aiqoMetricString
    case .count, .none:
        return Int(value.rounded()).arabicFormatted
    default:
        numericText = Int(value.rounded()).arabicFormatted
    }

    guard let unitKey = questUnitKey(for: unit) else {
        return numericText
    }

    return numericText + questLocalizedText(unitKey)
}

func questFormatValueArabic(_ value: Double, unit: QuestMetricUnit) -> String {
    questFormatValue(value, unit: unit)
}

func questCompletionStatusText(isCompleted: Bool) -> String {
    questLocalizedText(
        isCompleted
            ? "gym.quest.status.completed"
            : "gym.quest.status.notCompleted"
    )
}

func questSourceBadgeText(for quest: QuestDefinition) -> String {
    let sourceKey: String
    switch quest.source {
    case .healthkit:
        sourceKey = "gym.quest.source.appleHealth"
    case .camera:
        sourceKey = "gym.quest.source.visionCamera"
    case .water:
        sourceKey = "gym.quest.source.waterEntry"
    case .timer:
        sourceKey = "gym.quest.source.sessionTimer"
    case .workout:
        sourceKey = "gym.quest.source.cardioLog"
    case .manual:
        sourceKey = "gym.quest.source.userConfirmed"
    case .social:
        sourceKey = "gym.quest.source.arena"
    case .kitchen:
        sourceKey = "gym.quest.source.kitchen"
    case .share:
        sourceKey = "gym.quest.source.share"
    case .learning:
        sourceKey = "gym.quest.source.learning"
    }

    return String(
        format: questLocalizedText("gym.quest.source.format"),
        locale: questAppLocale(),
        questLocalizedText(sourceKey)
    )
}

struct Stage1QuestFormatter {
    private let calendar = Calendar.current

    private let lri = "\u{2066}"
    private let pdi = "\u{2069}"

    func tiersText(for quest: QuestDefinition) -> String {
        switch quest.id {
        case "s1q2":
            return joinedTokens([
                isolated(displayValue(3.0, unit: .liters)),
                isolated(displayValue(2.5, unit: .liters)),
                isolated(displayValue(2.0, unit: .liters))
            ])
        case "s1q3":
            return joinedTokens([
                isolated(displayValue(8.0, unit: .hours)),
                isolated(displayValue(7.5, unit: .hours)),
                isolated(displayValue(7.0, unit: .hours))
            ])
        case "s1q4":
            return joinedTokens([
                isolated(displayValue(40.0, unit: .minutes)),
                isolated(displayValue(30.0, unit: .minutes)),
                isolated(displayValue(20.0, unit: .minutes))
            ])
        case "s1q1", QuestDefinition.learningSparkQuestID:
            return centerText(for: 1)
        default:
            return questLocalizedText(quest.localizedLevelsKey)
        }
    }

    func center(fromTier tier: Int) -> Int {
        switch tier {
        case 3:
            return 1
        case 2:
            return 2
        case 1:
            return 3
        default:
            return 0
        }
    }

    func centerText(for center: Int) -> String {
        guard center > 0 else {
            return questCompletionStatusText(isCompleted: false)
        }

        if questIsArabicLanguage() {
            return String(
                format: questLocalizedText("gym.quest.center.format"),
                locale: questAppLocale(),
                center.arabicFormatted
            )
        }

        let key = center == 1 ? "gym.quest.point.single" : "gym.quest.point.plural"
        return String(
            format: questLocalizedText(key),
            locale: questAppLocale(),
            center
        )
    }

    func centerPillText(for progress: QuestCardProgressModel) -> String {
        let currentCenter = center(fromTier: progress.tier)
        guard currentCenter > 0 else {
            return questCompletionStatusText(isCompleted: false)
        }
        return centerText(for: currentCenter)
    }

    func progressLine(for quest: QuestDefinition, progress: QuestCardProgressModel) -> String {
        let current = max(progress.metricAValue, 0)
        let target = max(progress.targetAValue, 0)

        switch quest.id {
        case "s1q2":
            return "\(isolated(displayValue(current, unit: .liters))) / \(isolated(displayValue(target, unit: .liters)))"
        case "s1q3":
            return "\(isolated(displayValue(current, unit: .hours))) / \(isolated(displayValue(target, unit: .hours)))"
        case "s1q4":
            return "\(isolated(displayValue(current, unit: .minutes))) / \(isolated(displayValue(target, unit: .minutes)))"
        default:
            return "\(isolated(Int(current.rounded()).arabicFormatted)) / \(isolated(Int(target.rounded()).arabicFormatted))"
        }
    }

    func nextTargetText(for quest: QuestDefinition, progress: QuestCardProgressModel) -> String? {
        switch quest.id {
        case "s1q2":
            return nextTargetCopy(
                current: progress.metricAValue,
                thresholds: [2.0, 2.5, 3.0],
                formatter: { displayValue($0, unit: .liters) }
            )
        case "s1q3":
            return nextTargetCopy(
                current: progress.metricAValue,
                thresholds: [7.0, 7.5, 8.0],
                formatter: { displayValue($0, unit: .hours) }
            )
        case "s1q4":
            return nextTargetCopy(
                current: progress.metricAValue,
                thresholds: [20.0, 30.0, 40.0],
                formatter: { displayValue($0, unit: .minutes) }
            )
        default:
            return nil
        }
    }

    func contextText(for quest: QuestDefinition, now: Date) -> String? {
        switch quest.id {
        case "s1q2":
            return String(
                format: questLocalizedText("gym.quest.resetsAt"),
                locale: questAppLocale(),
                isolated(questLocalizedText("gym.quest.time.midnight")),
                timeRemainingUntilMidnight(from: now)
            )
        case "s1q3":
            return String(
                format: questLocalizedText("gym.quest.lastNightWindow"),
                locale: questAppLocale(),
                isolated(questLocalizedText("gym.quest.time.lastNight.start")),
                isolated(questLocalizedText("gym.quest.time.lastNight.end"))
            )
        default:
            return nil
        }
    }

    private func nextTargetCopy(
        current: Double,
        thresholds: [Double],
        formatter: (Double) -> String
    ) -> String {
        guard thresholds.count == 3 else {
            return questLocalizedText("gym.quest.nextTarget.unavailable")
        }

        let nextValue: String
        if current < thresholds[0] {
            nextValue = formatter(thresholds[0])
        } else if current < thresholds[1] {
            nextValue = formatter(thresholds[1])
        } else if current < thresholds[2] {
            nextValue = formatter(thresholds[2])
        } else {
            nextValue = questCompletionStatusText(isCompleted: true)
        }

        return String(
            format: questLocalizedText("gym.quest.nextTarget.format"),
            locale: questAppLocale(),
            isolated(nextValue)
        )
    }

    private func timeRemainingUntilMidnight(from now: Date) -> String {
        let startOfToday = calendar.startOfDay(for: now)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let components = calendar.dateComponents([.hour, .minute], from: now, to: nextMidnight)
        let hours = max(components.hour ?? 0, 0)
        let minutes = max(components.minute ?? 0, 0)
        let hoursText = isolated(displayValue(Double(hours), unit: .hours))
        let minutesText = isolated(displayValue(Double(minutes), unit: .minutes))
        return "\(hoursText) \(minutesText)"
    }

    private func displayValue(_ value: Double, unit: QuestMetricUnit) -> String {
        questIsArabicLanguage()
            ? questFormatValueArabic(value, unit: unit)
            : questFormatValue(value, unit: unit)
    }

    private func isolated(_ text: String) -> String {
        "\(lri)\(text)\(pdi)"
    }

    private func joinedTokens(_ tokens: [String]) -> String {
        tokens.joined(separator: " / ")
    }
}

let stage1QuestFormatter = Stage1QuestFormatter()

func questLevelsText(for quest: QuestDefinition) -> String {
    if quest.stageIndex == 1 {
        return stage1QuestFormatter.tiersText(for: quest)
    }

    let text = questLocalizedText(quest.localizedLevelsKey)
    if questStageNeedsLTRDisplay(quest.stageIndex) {
        return questForceLTR(text)
    }
    return text
}

func questStageOneCenter(fromTier tier: Int) -> Int {
    stage1QuestFormatter.center(fromTier: tier)
}

func questStageOneCenter(for progress: QuestCardProgressModel) -> Int {
    questStageOneCenter(fromTier: progress.tier)
}

func questStageOneCenterText(_ center: Int) -> String {
    stage1QuestFormatter.centerText(for: center)
}

func questStageOneCenterPillText(for progress: QuestCardProgressModel) -> String {
    stage1QuestFormatter.centerPillText(for: progress)
}

func questProgressText(for quest: QuestDefinition, progress: QuestCardProgressModel) -> String {
    if quest.stageIndex == 1 {
        return stage1QuestFormatter.progressLine(for: quest, progress: progress)
    }

    let maxTargets = questTierMaxTargets(for: quest)
    let targetA = questDisplayTargetA(for: quest, defaultTarget: progress.targetAValue)
    let targetB = progress.targetBValue

    let maxA = max(targetA, maxTargets.a)
    let maxB = max(targetB, maxTargets.b)

    let currentA = min(max(progress.metricAValue, 0), maxA)
    let currentB = min(max(progress.metricBValue, 0), maxB)

    let line: String
    if targetB > 0 {
        line = "\(questDisplayValue(currentA, unit: progress.metricAUnit, quest: quest))/\(questDisplayValue(targetA, unit: progress.metricAUnit, quest: quest)) • \(questDisplayValue(currentB, unit: progress.metricBUnit, quest: quest))/\(questDisplayValue(targetB, unit: progress.metricBUnit, quest: quest))"
    } else {
        line = "\(questDisplayValue(currentA, unit: progress.metricAUnit, quest: quest)) / \(questDisplayValue(targetA, unit: progress.metricAUnit, quest: quest))"
    }

    if questStageNeedsLTRDisplay(quest.stageIndex) {
        return questForceLTR(line)
    }
    return line
}

func questStageOneNextTargetText(for quest: QuestDefinition, progress: QuestCardProgressModel) -> String? {
    stage1QuestFormatter.nextTargetText(for: quest, progress: progress)
}

func questStageOneContextText(for quest: QuestDefinition, now: Date = Date()) -> String? {
    stage1QuestFormatter.contextText(for: quest, now: now)
}

func questStageOneSourceBadgeText(for quest: QuestDefinition) -> String {
    questSourceBadgeText(for: quest)
}

private func questDisplayTargetA(for quest: QuestDefinition, defaultTarget: Double) -> Double {
    switch quest.id {
    case "s3q5":
        return 2
    case "s5q5":
        return 3
    default:
        return defaultTarget
    }
}

private func questTierMaxTargets(for quest: QuestDefinition) -> (a: Double, b: Double) {
    guard let requirement = quest.tiers.last else {
        return (0, 0)
    }

    switch requirement {
    case let .singleMetric(value, _):
        return (value, 0)
    case let .dualMetric(valueA, _, valueB, _):
        return (valueA, valueB)
    }
}

private func questDisplayValue(_ value: Double, unit: QuestMetricUnit, quest: QuestDefinition) -> String {
    questFormatValue(value, unit: unit)
}

private func questStageNeedsLTRDisplay(_ stageIndex: Int) -> Bool {
    AppSettingsStore.shared.appLanguage == .english && (2...6).contains(stageIndex)
}

private func questUnitKey(for unit: QuestMetricUnit) -> String? {
    switch unit {
    case .liters:
        return "gym.quest.unit.litersShort"
    case .hours:
        return "gym.quest.unit.hoursShort"
    case .minutes:
        return "gym.quest.unit.minutesShort"
    case .seconds:
        return "gym.quest.unit.secondsShort"
    case .kilometers:
        return "gym.quest.unit.kilometersShort"
    case .percent:
        return "gym.quest.unit.percentShort"
    case .days:
        return "gym.quest.unit.daysShort"
    case .count, .none:
        return nil
    }
}

private func questForceLTR(_ text: String) -> String {
    "\u{2066}\(text)\u{2069}"
}
