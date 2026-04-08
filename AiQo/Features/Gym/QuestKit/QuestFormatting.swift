import Foundation

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
    switch unit {
    case .liters:
        return value.arabicFormatted + "L"
    case .hours:
        return value.arabicFormatted + "h"
    case .minutes:
        return Int(value.rounded()).arabicFormatted + "m"
    case .seconds:
        return Int(value.rounded()).arabicFormatted + "s"
    case .kilometers:
        return value.arabicFormatted + "km"
    case .percent:
        return Int(value.rounded()).arabicFormatted + "%"
    case .days:
        return Int(value.rounded()).arabicFormatted + "d"
    case .count:
        return Int(value.rounded()).arabicFormatted
    case .none:
        return Int(value.rounded()).arabicFormatted
    }
}

func questFormatValueArabic(_ value: Double, unit: QuestMetricUnit) -> String {
    switch unit {
    case .liters:
        return value.arabicFormatted + "ل"
    case .hours:
        return value.arabicFormatted + "س"
    case .minutes:
        return Int(value.rounded()).arabicFormatted + "د"
    case .seconds:
        return Int(value.rounded()).arabicFormatted + "ث"
    case .kilometers:
        return value.arabicFormatted + "كم"
    case .percent:
        return Int(value.rounded()).arabicFormatted + "٪"
    case .days:
        return Int(value.rounded()).arabicFormatted + "ي"
    case .count, .none:
        return Int(value.rounded()).arabicFormatted
    }
}

struct Stage1QuestFormatter {
    private let numberLocale = Locale(identifier: "en_US_POSIX")
    private let calendar = Calendar.current

    private let lri = "\u{2066}"
    private let pdi = "\u{2069}"

    func tiersText(for quest: QuestDefinition) -> String {
        switch quest.id {
        case "s1q2":
            return joinedTokens([
                isolated("3.0ل"),
                isolated("2.5ل"),
                isolated("2.0ل")
            ])
        case "s1q3":
            return joinedTokens([
                isolated("8س"),
                isolated("7.5س"),
                isolated("7س")
            ])
        case "s1q4":
            return joinedTokens([
                isolated("40د"),
                isolated("30د"),
                isolated("20د")
            ])
        case "s1q1", "s1q5":
            return "مركز 1"
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

    func centerPillText(for progress: QuestCardProgressModel) -> String {
        let currentCenter = center(fromTier: progress.tier)
        if currentCenter == 0 {
            return "غير مكتمل"
        }
        return "مركز \(currentCenter.arabicFormatted)"
    }

    func progressLine(for quest: QuestDefinition, progress: QuestCardProgressModel) -> String {
        let current = max(progress.metricAValue, 0)
        let target = max(progress.targetAValue, 0)

        switch quest.id {
        case "s1q2":
            return "\(isolated(formatted(current, digits: 2) + "ل")) / \(isolated(formatted(target, digits: 2) + "ل"))"
        case "s1q3":
            return "\(isolated(formatted(current, digits: 2) + "س")) / \(isolated(formatted(target, digits: 2) + "س"))"
        case "s1q4":
            return "\(isolated(Int(current.rounded()).arabicFormatted + "د")) / \(isolated(Int(target.rounded()).arabicFormatted + "د"))"
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
                formatter: { String(format: "%.1f", locale: numberLocale, $0) + "ل" }
            )
        case "s1q3":
            return nextTargetCopy(
                current: progress.metricAValue,
                thresholds: [7.0, 7.5, 8.0],
                formatter: { formatted($0, digits: 1) + "س" }
            )
        case "s1q4":
            return nextTargetCopy(
                current: progress.metricAValue,
                thresholds: [20.0, 30.0, 40.0],
                formatter: { "\(Int($0.rounded()))د" }
            )
        default:
            return nil
        }
    }

    func contextText(for quest: QuestDefinition, now: Date) -> String? {
        switch quest.id {
        case "s1q2":
            return "يصفّر \(isolated("12:00 ص")) • متبقي \(timeRemainingUntilMidnight(from: now))"
        case "s1q3":
            return "آخر ليلة (\(isolated("6:00م")) → \(isolated("12:00م")))"
        default:
            return nil
        }
    }

    func sourceBadgeText(for quest: QuestDefinition) -> String {
        switch quest.id {
        case "s1q2":
            return "المصدر: إدخال الماء"
        case "s1q3":
            return "المصدر: Apple Health"
        case "s1q4":
            return "المصدر: سجل الكارديو"
        case "s1q1", "s1q5":
            return "المصدر: تأكيد المستخدم"
        default:
            return "المصدر: —"
        }
    }

    private func nextTargetCopy(
        current: Double,
        thresholds: [Double],
        formatter: (Double) -> String
    ) -> String {
        guard thresholds.count == 3 else {
            return "هدفك الجاي: —"
        }

        if current < thresholds[0] {
            return "هدفك الجاي: \(isolated(formatter(thresholds[0])))"
        }
        if current < thresholds[1] {
            return "هدفك الجاي: \(isolated(formatter(thresholds[1])))"
        }
        if current < thresholds[2] {
            return "هدفك الجاي: \(isolated(formatter(thresholds[2])))"
        }
        return "هدفك الجاي: مكتمل مركز 1"
    }

    private func timeRemainingUntilMidnight(from now: Date) -> String {
        let startOfToday = calendar.startOfDay(for: now)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let components = calendar.dateComponents([.hour, .minute], from: now, to: nextMidnight)
        let hours = max(components.hour ?? 0, 0)
        let minutes = max(components.minute ?? 0, 0)
        return "\(isolated(hours.arabicFormatted + "س")) \(isolated(minutes.arabicFormatted + "د"))"
    }

    private func formatted(_ value: Double, digits: Int) -> String {
        switch digits {
        case 0:
            return String(Int(value.rounded()))
        case 1:
            let rounded = (value * 10).rounded() / 10
            if abs(rounded.rounded() - rounded) < 0.0001 {
                return String(Int(rounded.rounded()))
            }
            return String(format: "%.1f", locale: numberLocale, rounded)
        default:
            return String(format: "%.2f", locale: numberLocale, value)
        }
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
    if (2...6).contains(quest.stageIndex) {
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

    if (2...6).contains(quest.stageIndex) {
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
    stage1QuestFormatter.sourceBadgeText(for: quest)
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
    if (2...6).contains(quest.stageIndex) {
        switch unit {
        case .count:
            return Int(value.rounded()).arabicFormatted
        case .liters:
            return value.arabicFormatted + "L"
        case .hours:
            return value.arabicFormatted + "h"
        case .minutes:
            return Int(value.rounded()).arabicFormatted + "m"
        case .seconds:
            return Int(value.rounded()).arabicFormatted + "s"
        case .kilometers:
            return value.arabicFormatted + "km"
        case .percent:
            return Int(value.rounded()).arabicFormatted + "%"
        case .days:
            return Int(value.rounded()).arabicFormatted + "d"
        case .none:
            return Int(value.rounded()).arabicFormatted
        }
    }

    if quest.stageIndex == 1 {
        return questFormatValueArabic(value, unit: unit)
    }

    return questFormatValue(value, unit: unit)
}

private func questForceLTR(_ text: String) -> String {
    "\u{2066}\(text)\u{2069}"
}
