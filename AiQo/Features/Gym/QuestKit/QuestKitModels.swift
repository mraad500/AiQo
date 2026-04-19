import Foundation

enum QuestType: String, Codable, CaseIterable {
    case daily
    case weekly
    case oneTime
    case streak
    case cumulative
    case combo
}

enum QuestSource: String, Codable, CaseIterable {
    case manual
    case water
    case healthkit
    case camera
    case timer
    case workout
    case social
    case kitchen
    case share
    case learning
}

enum QuestMetricUnit: String, Codable {
    case count
    case liters
    case hours
    case minutes
    case seconds
    case kilometers
    case percent
    case days
    case none
}

enum QuestMetricKey: String, Codable {
    case none
    case manualCount
    case waterLiters
    case sleepHours
    case zone2Minutes
    case cardioMinutes
    case steps
    case distanceKM
    case movePercent
    case timerSeconds
    case timerMinutes
    case pushupReps
    case cameraAccuracy
    case socialInteractions
    case kitchenPlans
    case shares
    case comboStreakDays
    case stepDaysInWeek
    case learningCertificate
}

enum QuestDeepLinkAction: String, Codable {
    case openKitchen
    case openArena
    case openShare
    case openLearningCourse
}

enum TierRequirement: Codable, Hashable {
    case singleMetric(value: Double, unit: QuestMetricUnit)
    case dualMetric(valueA: Double, unitA: QuestMetricUnit, valueB: Double, unitB: QuestMetricUnit)
}

struct QuestDefinition: Identifiable, Codable, Hashable {
    let id: String
    let stageIndex: Int
    let questIndex: Int
    let title: String
    let type: QuestType
    let source: QuestSource
    let tiers: [TierRequirement]
    let deepLinkAction: QuestDeepLinkAction?

    let metricAKey: QuestMetricKey
    let metricBKey: QuestMetricKey

    // For streak/combo quests where a day qualifies only above these values.
    let streakDailyTargetA: Double?
    let streakDailyTargetB: Double?
    let streakTierTargetsA: [Double]?
    let streakTierTargetsB: [Double]?

    // Allow a quest to display a specific asset decoupled from its questIndex —
    // used when display order changes but the reward badge must stay the same.
    let rewardImageOverride: String?

    // Decouple localization from (stageIndex, questIndex). Required when multiple
    // quest variants share the same slot (e.g. Learning Spark Stage 2 reuses the
    // Plank Ladder slot at (2, 3); each variant needs its own title/levels copy).
    let localizedTitleKeyOverride: String?
    let localizedLevelsKeyOverride: String?

    init(
        id: String,
        stageIndex: Int,
        questIndex: Int,
        title: String,
        type: QuestType,
        source: QuestSource,
        tiers: [TierRequirement],
        deepLinkAction: QuestDeepLinkAction?,
        metricAKey: QuestMetricKey,
        metricBKey: QuestMetricKey,
        streakDailyTargetA: Double?,
        streakDailyTargetB: Double?,
        streakTierTargetsA: [Double]? = nil,
        streakTierTargetsB: [Double]? = nil,
        rewardImageOverride: String? = nil,
        localizedTitleKeyOverride: String? = nil,
        localizedLevelsKeyOverride: String? = nil
    ) {
        self.id = id
        self.stageIndex = stageIndex
        self.questIndex = questIndex
        self.title = title
        self.type = type
        self.source = source
        self.tiers = tiers
        self.deepLinkAction = deepLinkAction
        self.metricAKey = metricAKey
        self.metricBKey = metricBKey
        self.streakDailyTargetA = streakDailyTargetA
        self.streakDailyTargetB = streakDailyTargetB
        self.streakTierTargetsA = streakTierTargetsA
        self.streakTierTargetsB = streakTierTargetsB
        self.rewardImageOverride = rewardImageOverride
        self.localizedTitleKeyOverride = localizedTitleKeyOverride
        self.localizedLevelsKeyOverride = localizedLevelsKeyOverride
    }

    var rewardImageName: String {
        rewardImageOverride ?? "\(stageIndex).\(questIndex)"
    }

    static let learningSparkQuestID = "s1qLearn"
    static let learningSparkStage2QuestID = "s2qLearn"
    static let stage2PlaceholderID = "s2q3_placeholder"

    var isStageOneBooleanQuest: Bool {
        stageIndex == 1 && (id == "s1q1" || id == QuestDefinition.learningSparkQuestID)
    }

    var localizedTitleKey: String {
        localizedTitleKeyOverride ?? "quests.stage.\(stageIndex).quest.\(questIndex).title"
    }

    var localizedLevelsKey: String {
        localizedLevelsKeyOverride ?? "quests.stage.\(stageIndex).quest.\(questIndex).levels"
    }

    var stageTitleKey: String {
        "quests.stage.\(stageIndex).title"
    }

    var stageTabKey: String {
        "quests.stage.\(stageIndex).tab"
    }

    var requiresDualMetric: Bool {
        tiers.contains {
            if case .dualMetric = $0 {
                return true
            }
            return false
        }
    }
}

struct QuestProgressRecord: Codable, Hashable {
    let questId: String
    var currentTier: Int
    var metricAValue: Double
    var metricBValue: Double
    var lastUpdated: Date
    var isStarted: Bool
    var startedAt: Date?
    var streakCount: Int
    var lastCompletionDate: Date?
    var lastStreakDate: Date?
    var resetKeyDaily: String?
    var resetKeyWeekly: String?
    var isCompleted: Bool
    var completedAt: Date?

    init(
        questId: String,
        currentTier: Int = 0,
        metricAValue: Double = 0,
        metricBValue: Double = 0,
        lastUpdated: Date = Date(),
        isStarted: Bool = false,
        startedAt: Date? = nil,
        streakCount: Int = 0,
        lastCompletionDate: Date? = nil,
        lastStreakDate: Date? = nil,
        resetKeyDaily: String? = nil,
        resetKeyWeekly: String? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.questId = questId
        self.currentTier = currentTier
        self.metricAValue = metricAValue
        self.metricBValue = metricBValue
        self.lastUpdated = lastUpdated
        self.isStarted = isStarted
        self.startedAt = startedAt
        self.streakCount = streakCount
        self.lastCompletionDate = lastCompletionDate
        self.lastStreakDate = lastStreakDate
        self.resetKeyDaily = resetKeyDaily
        self.resetKeyWeekly = resetKeyWeekly
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }

    private enum CodingKeys: String, CodingKey {
        case questId
        case currentTier
        case metricAValue
        case metricBValue
        case lastUpdated
        case isStarted
        case startedAt
        case streakCount
        case lastCompletionDate
        case lastStreakDate
        case resetKeyDaily
        case resetKeyWeekly
        case isCompleted
        case completedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        questId = try container.decode(String.self, forKey: .questId)
        currentTier = try container.decodeIfPresent(Int.self, forKey: .currentTier) ?? 0
        metricAValue = try container.decodeIfPresent(Double.self, forKey: .metricAValue) ?? 0
        metricBValue = try container.decodeIfPresent(Double.self, forKey: .metricBValue) ?? 0
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
        isStarted = try container.decodeIfPresent(Bool.self, forKey: .isStarted) ?? false
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        streakCount = try container.decodeIfPresent(Int.self, forKey: .streakCount) ?? 0
        lastCompletionDate = try container.decodeIfPresent(Date.self, forKey: .lastCompletionDate)
        lastStreakDate = try container.decodeIfPresent(Date.self, forKey: .lastStreakDate)
        resetKeyDaily = try container.decodeIfPresent(String.self, forKey: .resetKeyDaily)
        resetKeyWeekly = try container.decodeIfPresent(String.self, forKey: .resetKeyWeekly)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }
}

struct QuestStageViewModel: Identifiable, Hashable {
    let id: Int
    let titleKey: String
    let tabTitleKey: String
    let quests: [QuestDefinition]
}

enum QuestRefreshReason {
    case appLaunch
    case foreground
    case dataChanged
    case manualPull
}

enum QuestSessionResult {
    case manualConfirmed(count: Double)
    case waterLogged(liters: Double)
    case timerFinished(seconds: TimeInterval)
    case cameraFinished(reps: Int, accuracy: Double)
    case workoutLogged(minutes: Double)
    case socialInteraction(count: Int)
    case kitchenPlanSaved
    case shared
}

struct QuestCardProgressModel: Hashable {
    let tier: Int
    let metricAValue: Double
    let metricBValue: Double
    let targetAValue: Double
    let targetBValue: Double
    let metricAUnit: QuestMetricUnit
    let metricBUnit: QuestMetricUnit

    var completionFraction: Double {
        if targetAValue <= 0 {
            return 0
        }

        if targetBValue > 0 {
            let first = min(metricAValue / targetAValue, 1)
            let second = min(metricBValue / targetBValue, 1)
            return min((first + second) / 2, 1)
        }

        return min(metricAValue / targetAValue, 1)
    }
}
