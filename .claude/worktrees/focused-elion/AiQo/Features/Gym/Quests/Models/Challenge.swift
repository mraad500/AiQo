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
    case kindnessActs
    case zone2Minutes
    case mindfulnessSessions
    case sleepStreakDays

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
        case .kindnessActs:
            return "helps"
        case .zone2Minutes:
            return "min"
        case .mindfulnessSessions:
            return "sessions"
        case .sleepStreakDays:
            return "days"
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
        case .kindnessActs:
            return "kindnessActs"
        case .zone2Minutes:
            return "zone2Minutes"
        case .mindfulnessSessions:
            return "mindfulnessSessions"
        case .sleepStreakDays:
            return "sleepStreakDays"
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

    var manualIncrementOptions: [Int] {
        switch self {
        case .pushups:
            return [5, 10, 20]
        case .kindnessActs, .mindfulnessSessions, .sleepStreakDays:
            return [1]
        case .zone2Minutes:
            return [5, 10, 15]
        case .steps, .plankSeconds, .sleepHours, .activeCalories, .distanceKilometers, .questCompletions:
            return []
        }
    }

    var supportsManualCounter: Bool {
        !manualIncrementOptions.isEmpty
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
        case .plankSeconds, .pushups, .questCompletions, .kindnessActs, .zone2Minutes, .mindfulnessSessions, .sleepStreakDays:
            return false
        }
    }
    var opensVisionCoach: Bool {
        id == "pushups_60" || id == "s2_pushups_70"
    }

    var showsProgressOnCard: Bool {
        switch id {
        case "s1_help_3_strangers", "s1_gratitude_session":
            return false
        default:
            return true
        }
    }

    static let stage1: [Challenge] = [
        Challenge(
            id: "s1_help_3_strangers",
            stageNumber: 1,
            titleKey: "quests.challenge.s1.help.title",
            subtitleKey: "quests.challenge.s1.help.subtitle",
            descriptionKey: "quests.challenge.s1.help.description",
            type: .manual,
            metricType: .kindnessActs,
            goalValue: 3,
            awardImageName: "1.1.Quests",
            goalTextKey: "quests.challenge.s1.help.goal",
            verifyTextKey: "quests.challenge.s1.help.verify",
            isBoss: false
        ),
        Challenge(
            id: "s1_zone2_guardian",
            stageNumber: 1,
            titleKey: "quests.challenge.s1.zone2.title",
            subtitleKey: "quests.challenge.s1.zone2.subtitle",
            descriptionKey: "quests.challenge.s1.zone2.description",
            type: .manual,
            metricType: .zone2Minutes,
            goalValue: 30,
            awardImageName: "2.1.Quests",
            goalTextKey: "quests.challenge.s1.zone2.goal",
            verifyTextKey: "quests.challenge.s1.zone2.verify",
            isBoss: false
        ),
        Challenge(
            id: "s1_walk_5k",
            stageNumber: 1,
            titleKey: "quests.challenge.s1.walk.title",
            subtitleKey: "quests.challenge.s1.walk.subtitle",
            descriptionKey: "quests.challenge.s1.walk.description",
            type: .automatic,
            metricType: .distanceKilometers,
            goalValue: 5.0,
            awardImageName: "3.1.Quests",
            goalTextKey: "quests.challenge.s1.walk.goal",
            verifyTextKey: "quests.challenge.s1.walk.verify",
            isBoss: false
        ),
        Challenge(
            id: "s1_gratitude_session",
            stageNumber: 1,
            titleKey: "quests.challenge.s1.gratitude.title",
            subtitleKey: "quests.challenge.s1.gratitude.subtitle",
            descriptionKey: "quests.challenge.s1.gratitude.description",
            type: .manual,
            metricType: .mindfulnessSessions,
            goalValue: 1,
            awardImageName: "4.1.Quests",
            goalTextKey: "quests.challenge.s1.gratitude.goal",
            verifyTextKey: "quests.challenge.s1.gratitude.verify",
            isBoss: false
        ),
        Challenge(
            id: "s1_recovery_boss",
            stageNumber: 1,
            titleKey: "quests.challenge.s1.recovery.title",
            subtitleKey: "quests.challenge.s1.recovery.subtitle",
            descriptionKey: "quests.challenge.s1.recovery.description",
            type: .manual,
            metricType: .sleepStreakDays,
            goalValue: 3,
            awardImageName: "5.1.Quests",
            goalTextKey: "quests.challenge.s1.recovery.goal",
            verifyTextKey: "quests.challenge.s1.recovery.verify",
            isBoss: false
        )
    ]

    static let stage2: [Challenge] = [
        Challenge(
            id: "steps_10k",
            stageNumber: 2,
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
            stageNumber: 2,
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
            stageNumber: 2,
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
            stageNumber: 2,
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
            stageNumber: 2,
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

    static let stage3Daily: [Challenge] = [
        Challenge(
            id: "s2_steps_11k",
            stageNumber: 3,
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
            stageNumber: 3,
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
            stageNumber: 3,
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
            stageNumber: 3,
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
            stageNumber: 3,
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

    static let stage3Boss = Challenge(
        id: "s2_boss_4_of_5",
        stageNumber: 3,
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

    static let stage3: [Challenge] = stage3Daily + [stage3Boss]
    static let all: [Challenge] = stage1 + stage2 + stage3

    static var availableStageNumbers: [Int] {
        Array(Set(all.map(\.stageNumber))).sorted()
    }

    static func forStage(_ stageNumber: Int) -> [Challenge] {
        all.filter { $0.stageNumber == stageNumber }
    }

    static func nonBossChallenges(forStage stageNumber: Int) -> [Challenge] {
        forStage(stageNumber).filter { !$0.isBoss }
    }

    static func bossChallenge(forStage stageNumber: Int) -> Challenge? {
        forStage(stageNumber).first { $0.isBoss }
    }

    static func previousStage(before stageNumber: Int) -> Int? {
        let stages = availableStageNumbers
        guard let index = stages.firstIndex(of: stageNumber), index > 0 else {
            return nil
        }
        return stages[index - 1]
    }
}
