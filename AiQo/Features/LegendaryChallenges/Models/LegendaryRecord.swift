import Foundation

// MARK: - Legendary Challenge Record

struct LegendaryRecord: Identifiable, Codable, Hashable {
    let id: String
    let titleKey: String
    let targetValue: Double
    let unitKey: String
    let recordHolderKey: String
    let country: String
    let year: Int
    let category: ChallengeCategory
    let difficulty: ChallengeDifficulty
    let estimatedWeeks: Int
    let storyKey: String
    let requirementKeys: [String]
    let iconName: String

    // MARK: - Localised accessors

    var titleAr: String { L10n.t(titleKey) }
    var unit: String { L10n.t(unitKey) }
    var recordHolderAr: String { L10n.t(recordHolderKey) }
    var storyAr: String { L10n.t(storyKey) }
    var requirementsAr: [String] { requirementKeys.map { L10n.t($0) } }
}

// MARK: - Category

enum ChallengeCategory: String, Codable, CaseIterable {
    case strength = "قوة"
    case cardio = "كارديو"
    case endurance = "تحمّل"
    case clarity = "صفاء"

    var localizedTitle: String {
        switch self {
        case .strength:  return L10n.t("peaks.category.strength")
        case .cardio:    return L10n.t("peaks.category.cardio")
        case .endurance: return L10n.t("peaks.category.endurance")
        case .clarity:   return L10n.t("peaks.category.clarity")
        }
    }
}

// MARK: - Difficulty

enum ChallengeDifficulty: Int, Codable {
    case beginner = 1
    case advanced = 2
    case legendary = 3

    var labelAr: String {
        switch self {
        case .beginner:  return L10n.t("peaks.difficulty.beginner")
        case .advanced:  return L10n.t("peaks.difficulty.advanced")
        case .legendary: return L10n.t("peaks.difficulty.legendary")
        }
    }
}

// MARK: - Seed Data

extension LegendaryRecord {
    static let seedRecords: [LegendaryRecord] = [
        LegendaryRecord(
            id: "pushup_1min",
            titleKey: "peaks.record.pushup1min.title",
            targetValue: 152,
            unitKey: "peaks.unit.times",
            recordHolderKey: "peaks.record.pushup1min.holder",
            country: "🇯🇵",
            year: 2024,
            category: .strength,
            difficulty: .legendary,
            estimatedWeeks: 16,
            storyKey: "peaks.record.pushup1min.story",
            requirementKeys: [
                "peaks.record.pushup1min.req1",
                "peaks.record.pushup1min.req2",
                "peaks.record.pushup1min.req3",
            ],
            iconName: "figure.strengthtraining.traditional"
        ),
        LegendaryRecord(
            id: "plank_hold",
            titleKey: "peaks.record.plank.title",
            targetValue: 9.5,
            unitKey: "peaks.unit.hours",
            recordHolderKey: "peaks.record.plank.holder",
            country: "🇨🇿",
            year: 2024,
            category: .endurance,
            difficulty: .legendary,
            estimatedWeeks: 24,
            storyKey: "peaks.record.plank.story",
            requirementKeys: [
                "peaks.record.plank.req1",
                "peaks.record.plank.req2",
                "peaks.record.plank.req3",
            ],
            iconName: "figure.core.training"
        ),
        LegendaryRecord(
            id: "squats_1min",
            titleKey: "peaks.record.squats1min.title",
            targetValue: 70,
            unitKey: "peaks.unit.times",
            recordHolderKey: "peaks.record.squats1min.holder",
            country: "🇰🇼",
            year: 2023,
            category: .strength,
            difficulty: .advanced,
            estimatedWeeks: 10,
            storyKey: "peaks.record.squats1min.story",
            requirementKeys: [
                "peaks.record.squats1min.req1",
                "peaks.record.squats1min.req2",
            ],
            iconName: "figure.strengthtraining.functional"
        ),
        LegendaryRecord(
            id: "walk_24h",
            titleKey: "peaks.record.walk24h.title",
            targetValue: 228.93,
            unitKey: "peaks.unit.km",
            recordHolderKey: "peaks.record.walk24h.holder",
            country: "🇺🇸",
            year: 2024,
            category: .cardio,
            difficulty: .legendary,
            estimatedWeeks: 20,
            storyKey: "peaks.record.walk24h.story",
            requirementKeys: [
                "peaks.record.walk24h.req1",
                "peaks.record.walk24h.req2",
                "peaks.record.walk24h.req3",
            ],
            iconName: "figure.walk"
        ),
        LegendaryRecord(
            id: "burpees_1min",
            titleKey: "peaks.record.burpees1min.title",
            targetValue: 48,
            unitKey: "peaks.unit.times",
            recordHolderKey: "peaks.record.burpees1min.holder",
            country: "🇺🇸",
            year: 2023,
            category: .cardio,
            difficulty: .advanced,
            estimatedWeeks: 12,
            storyKey: "peaks.record.burpees1min.story",
            requirementKeys: [
                "peaks.record.burpees1min.req1",
                "peaks.record.burpees1min.req2",
                "peaks.record.burpees1min.req3",
            ],
            iconName: "figure.highintensity.intervaltraining"
        ),
        LegendaryRecord(
            id: "pullups_1min",
            titleKey: "peaks.record.pullups1min.title",
            targetValue: 62,
            unitKey: "peaks.unit.times",
            recordHolderKey: "peaks.record.pullups1min.holder",
            country: "🇺🇸",
            year: 2023,
            category: .strength,
            difficulty: .legendary,
            estimatedWeeks: 16,
            storyKey: "peaks.record.pullups1min.story",
            requirementKeys: [
                "peaks.record.pullups1min.req1",
                "peaks.record.pullups1min.req2",
            ],
            iconName: "figure.climbing"
        ),
        LegendaryRecord(
            id: "breath_hold",
            titleKey: "peaks.record.breathHold.title",
            targetValue: 24.37,
            unitKey: "peaks.unit.minutes",
            recordHolderKey: "peaks.record.breathHold.holder",
            country: "🇭🇷",
            year: 2021,
            category: .clarity,
            difficulty: .legendary,
            estimatedWeeks: 12,
            storyKey: "peaks.record.breathHold.story",
            requirementKeys: [
                "peaks.record.breathHold.req1",
                "peaks.record.breathHold.req2",
            ],
            iconName: "wind"
        ),
        LegendaryRecord(
            id: "steps_24h",
            titleKey: "peaks.record.steps24h.title",
            targetValue: 210_000,
            unitKey: "peaks.unit.steps",
            recordHolderKey: "peaks.record.steps24h.holder",
            country: "🇬🇧",
            year: 2023,
            category: .cardio,
            difficulty: .legendary,
            estimatedWeeks: 16,
            storyKey: "peaks.record.steps24h.story",
            requirementKeys: [
                "peaks.record.steps24h.req1",
                "peaks.record.steps24h.req2",
                "peaks.record.steps24h.req3",
            ],
            iconName: "shoeprints.fill"
        ),
    ]

    /// Formatted target value for display (e.g. "152" or "9.5" or "210,000")
    var formattedTarget: String {
        if targetValue == targetValue.rounded() && targetValue < 1_000 {
            return String(format: "%.0f", targetValue)
        } else if targetValue >= 1_000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = Locale(identifier: "ar")
            return formatter.string(from: NSNumber(value: targetValue)) ?? "\(targetValue)"
        } else {
            return String(format: "%.1f", targetValue)
        }
    }
}
