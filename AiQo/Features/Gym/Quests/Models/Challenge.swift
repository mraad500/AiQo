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
        }
    }

    func displayValue(_ value: Double) -> String {
        switch self {
        case .sleepHours:
            return String(format: "%.1f", value)
        default:
            return String(Int(value.rounded()))
        }
    }
}

struct Challenge: Identifiable, Codable, Hashable {
    let id: String
    let titleKey: String
    let subtitleKey: String
    let descriptionKey: String
    let type: ChallengeType
    let metricType: ChallengeMetricType
    let goalValue: Double
    let awardImageName: String
    let goalTextKey: String
    let verifyTextKey: String

    var title: String { L10n.t(titleKey) }
    var subtitle: String { L10n.t(subtitleKey) }
    var description: String { L10n.t(descriptionKey) }
    var goalText: String { L10n.t(goalTextKey) }
    var verifyText: String { L10n.t(verifyTextKey) }

    var isAutomatic: Bool { type == .automatic }

    static let all: [Challenge] = [
        Challenge(
            id: "steps_10k",
            titleKey: "quests.challenge.steps.title",
            subtitleKey: "quests.challenge.steps.subtitle",
            descriptionKey: "quests.challenge.steps.description",
            type: .automatic,
            metricType: .steps,
            goalValue: 10_000,
            awardImageName: "10K.Steps.Award",
            goalTextKey: "quests.challenge.steps.goal",
            verifyTextKey: "quests.challenge.steps.verify"
        ),
        Challenge(
            id: "plank_ladder",
            titleKey: "quests.challenge.plank.title",
            subtitleKey: "quests.challenge.plank.subtitle",
            descriptionKey: "quests.challenge.plank.description",
            type: .manual,
            metricType: .plankSeconds,
            goalValue: 180,
            awardImageName: "Plank.Ladder",
            goalTextKey: "quests.challenge.plank.goal",
            verifyTextKey: "quests.challenge.plank.verify"
        ),
        Challenge(
            id: "pushups_60",
            titleKey: "quests.challenge.pushups.title",
            subtitleKey: "quests.challenge.pushups.subtitle",
            descriptionKey: "quests.challenge.pushups.description",
            type: .manual,
            metricType: .pushups,
            goalValue: 60,
            awardImageName: "Push.ups.Builder.60",
            goalTextKey: "quests.challenge.pushups.goal",
            verifyTextKey: "quests.challenge.pushups.verify"
        ),
        Challenge(
            id: "sleep_8h",
            titleKey: "quests.challenge.sleep.title",
            subtitleKey: "quests.challenge.sleep.subtitle",
            descriptionKey: "quests.challenge.sleep.description",
            type: .automatic,
            metricType: .sleepHours,
            goalValue: 8,
            awardImageName: "8.hour.sleep.award",
            goalTextKey: "quests.challenge.sleep.goal",
            verifyTextKey: "quests.challenge.sleep.verify"
        ),
        Challenge(
            id: "active_kcal_600",
            titleKey: "quests.challenge.active.title",
            subtitleKey: "quests.challenge.active.subtitle",
            descriptionKey: "quests.challenge.active.description",
            type: .automatic,
            metricType: .activeCalories,
            goalValue: 600,
            awardImageName: "Award.for.burning.600.active.calories",
            goalTextKey: "quests.challenge.active.goal",
            verifyTextKey: "quests.challenge.active.verify"
        )
    ]
}
