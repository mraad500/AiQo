import Foundation

enum ChallengeType: String, Codable {
    case automatic
    case manual
}

enum ChallengeMetricType: String, Codable {
    case steps
    case plankSeconds
    case pushups
    case sleepHours
    case activeCalories
    case distanceKilometers
    case questCompletions

    var progressUnit: String {
        switch self {
        case .steps:
            return "steps"
        case .plankSeconds:
            return "sec"
        case .pushups:
            return "reps"
        case .sleepHours:
            return "h"
        case .activeCalories:
            return "kcal"
        case .distanceKilometers:
            return "km"
        case .questCompletions:
            return "quests"
        }
    }

    var proofKey: String {
        switch self {
        case .steps:
            return "steps"
        case .plankSeconds:
            return "plankTotal"
        case .pushups:
            return "pushups"
        case .sleepHours:
            return "sleep"
        case .activeCalories:
            return "activeKcal"
        case .distanceKilometers:
            return "distanceKm"
        case .questCompletions:
            return "questsCompleted"
        }
    }

    func displayValue(_ value: Double) -> String {
        switch self {
        case .sleepHours:
            return String(format: "%.1f", value)
        case .distanceKilometers:
            return String(format: "%.1f", value)
        default:
            return String(Int(value.rounded()))
        }
    }
}

struct Challenge: Identifiable, Codable, Hashable {
    let id: String
    let stageNumber: Int
    let titleKey: String
    let subtitleKey: String
    let descriptionKey: String
    let type: ChallengeType
    let metricType: ChallengeMetricType
    let goalValue: Double
    let awardImageName: String
    let goalTextKey: String
    let verifyTextKey: String
    let isBoss: Bool

    var title: String { L10n.t(titleKey) }
    var subtitle: String { L10n.t(subtitleKey) }
    var description: String { L10n.t(descriptionKey) }
    var goalText: String { L10n.t(goalTextKey) }
    var verifyText: String { L10n.t(verifyTextKey) }

    var isAutomatic: Bool { type == .automatic }
    var isHealthKitBacked: Bool {
        switch metricType {
        case .steps, .sleepHours, .activeCalories, .distanceKilometers:
            return true
        case .plankSeconds, .pushups, .questCompletions:
            return false
        }
    }

    static let stage1: [Challenge] = [
        Challenge(
            id: "steps_10k",
            stageNumber: 1,
            titleKey: "quests.challenge.steps.title",
            subtitleKey: "quests.challenge.steps.subtitle",
            descriptionKey: "quests.challenge.steps.description",
            type: .automatic,
            metricType: .steps,
            goalValue: 10_000,
            awardImageName: "10K.Steps.Award",
            goalTextKey: "quests.challenge.steps.goal",
            verifyTextKey: "quests.challenge.steps.verify",
            isBoss: false
        ),
        Challenge(
            id: "plank_ladder",
            stageNumber: 1,
            titleKey: "quests.challenge.plank.title",
            subtitleKey: "quests.challenge.plank.subtitle",
            descriptionKey: "quests.challenge.plank.description",
            type: .manual,
            metricType: .plankSeconds,
            goalValue: 180,
            awardImageName: "Plank.Ladder",
            goalTextKey: "quests.challenge.plank.goal",
            verifyTextKey: "quests.challenge.plank.verify",
            isBoss: false
        ),
        Challenge(
            id: "pushups_60",
            stageNumber: 1,
            titleKey: "quests.challenge.pushups.title",
            subtitleKey: "quests.challenge.pushups.subtitle",
            descriptionKey: "quests.challenge.pushups.description",
            type: .manual,
            metricType: .pushups,
            goalValue: 60,
            awardImageName: "Push.ups.Builder.60",
            goalTextKey: "quests.challenge.pushups.goal",
            verifyTextKey: "quests.challenge.pushups.verify",
            isBoss: false
        ),
        Challenge(
            id: "sleep_8h",
            stageNumber: 1,
            titleKey: "quests.challenge.sleep.title",
            subtitleKey: "quests.challenge.sleep.subtitle",
            descriptionKey: "quests.challenge.sleep.description",
            type: .automatic,
            metricType: .sleepHours,
            goalValue: 8,
            awardImageName: "8.hour.sleep.award",
            goalTextKey: "quests.challenge.sleep.goal",
            verifyTextKey: "quests.challenge.sleep.verify",
            isBoss: false
        ),
        Challenge(
            id: "active_kcal_600",
            stageNumber: 1,
            titleKey: "quests.challenge.active.title",
            subtitleKey: "quests.challenge.active.subtitle",
            descriptionKey: "quests.challenge.active.description",
            type: .automatic,
            metricType: .activeCalories,
            goalValue: 600,
            awardImageName: "Award.for.burning.600.active.calories",
            goalTextKey: "quests.challenge.active.goal",
            verifyTextKey: "quests.challenge.active.verify",
            isBoss: false
        )
    ]

    static let stage2Daily: [Challenge] = [
        Challenge(
            id: "s2_steps_11k",
            stageNumber: 2,
            titleKey: "quests.challenge.s2.steps.title",
            subtitleKey: "quests.challenge.s2.steps.subtitle",
            descriptionKey: "quests.challenge.s2.steps.description",
            type: .automatic,
            metricType: .steps,
            goalValue: 11_000,
            awardImageName: "Challenge_1_Stage_2_Prize",
            goalTextKey: "quests.challenge.s2.steps.goal",
            verifyTextKey: "quests.challenge.s2.steps.verify",
            isBoss: false
        ),
        Challenge(
            id: "s2_active_kcal_650",
            stageNumber: 2,
            titleKey: "quests.challenge.s2.active.title",
            subtitleKey: "quests.challenge.s2.active.subtitle",
            descriptionKey: "quests.challenge.s2.active.description",
            type: .automatic,
            metricType: .activeCalories,
            goalValue: 650,
            awardImageName: "Challenge_2_Stage_2_Prize",
            goalTextKey: "quests.challenge.s2.active.goal",
            verifyTextKey: "quests.challenge.s2.active.verify",
            isBoss: false
        ),
        Challenge(
            id: "s2_pushups_70",
            stageNumber: 2,
            titleKey: "quests.challenge.s2.pushups.title",
            subtitleKey: "quests.challenge.s2.pushups.subtitle",
            descriptionKey: "quests.challenge.s2.pushups.description",
            type: .manual,
            metricType: .pushups,
            goalValue: 70,
            awardImageName: "Challenge_3_Stage_2_Prize",
            goalTextKey: "quests.challenge.s2.pushups.goal",
            verifyTextKey: "quests.challenge.s2.pushups.verify",
            isBoss: false
        ),
        Challenge(
            id: "s2_plank_240",
            stageNumber: 2,
            titleKey: "quests.challenge.s2.plank.title",
            subtitleKey: "quests.challenge.s2.plank.subtitle",
            descriptionKey: "quests.challenge.s2.plank.description",
            type: .manual,
            metricType: .plankSeconds,
            goalValue: 240,
            awardImageName: "Challenge_4_Stage_2_Prize",
            goalTextKey: "quests.challenge.s2.plank.goal",
            verifyTextKey: "quests.challenge.s2.plank.verify",
            isBoss: false
        ),
        Challenge(
            id: "s2_move_5km",
            stageNumber: 2,
            titleKey: "quests.challenge.s2.move.title",
            subtitleKey: "quests.challenge.s2.move.subtitle",
            descriptionKey: "quests.challenge.s2.move.description",
            type: .automatic,
            metricType: .distanceKilometers,
            goalValue: 5.0,
            awardImageName: "Challenge_5_Stage_2_Prize",
            goalTextKey: "quests.challenge.s2.move.goal",
            verifyTextKey: "quests.challenge.s2.move.verify",
            isBoss: false
        )
    ]

    static let stage2Boss = Challenge(
        id: "s2_boss_4_of_5",
        stageNumber: 2,
        titleKey: "quests.challenge.s2.boss.title",
        subtitleKey: "quests.challenge.s2.boss.subtitle",
        descriptionKey: "quests.challenge.s2.boss.description",
        type: .automatic,
        metricType: .questCompletions,
        goalValue: 4,
        awardImageName: "Challenge_5_Stage_2_Prize",
        goalTextKey: "quests.challenge.s2.boss.goal",
        verifyTextKey: "quests.challenge.s2.boss.verify",
        isBoss: true
    )

    static let stage2: [Challenge] = stage2Daily + [stage2Boss]
    static let all: [Challenge] = stage1 + stage2

    static func forStage(_ stageNumber: Int) -> [Challenge] {
        switch stageNumber {
        case 1:
            return stage1
        case 2:
            return stage2
        default:
            return []
        }
    }
}
