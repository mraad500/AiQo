import Foundation
import SwiftData

enum RewardKind: String, Codable, CaseIterable {
    case badge
    case chest
    case loot
}

@Model
final class PlayerStats {
    static let primaryID = "primary-player"

    @Attribute(.unique) var profileID: String
    var currentLevel: Int
    var currentLevelXP: Int
    var totalXP: Int
    var totalAura: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        profileID: String = PlayerStats.primaryID,
        currentLevel: Int = 1,
        currentLevelXP: Int = 0,
        totalXP: Int = 0,
        totalAura: Double = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.profileID = profileID
        self.currentLevel = max(1, currentLevel)
        self.currentLevelXP = max(0, currentLevelXP)
        self.totalXP = max(0, totalXP)
        self.totalAura = max(0, totalAura)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class QuestStage {
    @Attribute(.unique) var stageID: String
    var stageIndex: Int
    var titleKey: String
    var tabTitleKey: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \QuestRecord.stage)
    var records: [QuestRecord]

    init(
        stageIndex: Int,
        titleKey: String,
        tabTitleKey: String,
        sortOrder: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.stageID = "quest-stage-\(stageIndex)"
        self.stageIndex = stageIndex
        self.titleKey = titleKey
        self.tabTitleKey = tabTitleKey
        self.sortOrder = sortOrder ?? stageIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.records = []
    }
}

@Model
final class QuestRecord {
    @Attribute(.unique) var questID: String
    var stageIndex: Int
    var questIndex: Int
    var titleKey: String
    var fallbackTitle: String
    var questType: QuestType
    var questSource: QuestSource
    var metricAKey: QuestMetricKey
    var metricBKey: QuestMetricKey
    var deepLinkAction: QuestDeepLinkAction?

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

    var stage: QuestStage?

    init(
        definition: QuestDefinition,
        progress: QuestProgressRecord,
        stage: QuestStage? = nil
    ) {
        self.questID = definition.id
        self.stageIndex = definition.stageIndex
        self.questIndex = definition.questIndex
        self.titleKey = definition.localizedTitleKey
        self.fallbackTitle = definition.title
        self.questType = definition.type
        self.questSource = definition.source
        self.metricAKey = definition.metricAKey
        self.metricBKey = definition.metricBKey
        self.deepLinkAction = definition.deepLinkAction
        self.currentTier = progress.currentTier
        self.metricAValue = progress.metricAValue
        self.metricBValue = progress.metricBValue
        self.lastUpdated = progress.lastUpdated
        self.isStarted = progress.isStarted
        self.startedAt = progress.startedAt
        self.streakCount = progress.streakCount
        self.lastCompletionDate = progress.lastCompletionDate
        self.lastStreakDate = progress.lastStreakDate
        self.resetKeyDaily = progress.resetKeyDaily
        self.resetKeyWeekly = progress.resetKeyWeekly
        self.isCompleted = progress.isCompleted
        self.completedAt = progress.completedAt
        self.stage = stage
    }

    func apply(definition: QuestDefinition, progress: QuestProgressRecord, stage: QuestStage? = nil) {
        stageIndex = definition.stageIndex
        questIndex = definition.questIndex
        titleKey = definition.localizedTitleKey
        fallbackTitle = definition.title
        questType = definition.type
        questSource = definition.source
        metricAKey = definition.metricAKey
        metricBKey = definition.metricBKey
        deepLinkAction = definition.deepLinkAction
        self.stage = stage ?? self.stage
        apply(progress: progress)
    }

    func apply(progress: QuestProgressRecord) {
        currentTier = progress.currentTier
        metricAValue = progress.metricAValue
        metricBValue = progress.metricBValue
        lastUpdated = progress.lastUpdated
        isStarted = progress.isStarted
        startedAt = progress.startedAt
        streakCount = progress.streakCount
        lastCompletionDate = progress.lastCompletionDate
        lastStreakDate = progress.lastStreakDate
        resetKeyDaily = progress.resetKeyDaily
        resetKeyWeekly = progress.resetKeyWeekly
        isCompleted = progress.isCompleted
        completedAt = progress.completedAt
    }

    var progressRecord: QuestProgressRecord {
        QuestProgressRecord(
            questId: questID,
            currentTier: currentTier,
            metricAValue: metricAValue,
            metricBValue: metricBValue,
            lastUpdated: lastUpdated,
            isStarted: isStarted,
            startedAt: startedAt,
            streakCount: streakCount,
            lastCompletionDate: lastCompletionDate,
            lastStreakDate: lastStreakDate,
            resetKeyDaily: resetKeyDaily,
            resetKeyWeekly: resetKeyWeekly,
            isCompleted: isCompleted,
            completedAt: completedAt
        )
    }
}

@Model
final class Reward {
    @Attribute(.unique) var rewardID: String
    var title: String
    var subtitle: String
    var iconSystemName: String
    var tintHex: String
    var kind: RewardKind
    var currentValue: Double
    var targetValue: Double
    var isUnlocked: Bool
    var unlockedAt: Date?
    var sourceQuestID: String?
    var stageIndex: Int?
    var isFeatured: Bool
    var displayOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        rewardID: String,
        title: String,
        subtitle: String,
        iconSystemName: String,
        tintHex: String,
        kind: RewardKind = .badge,
        currentValue: Double = 0,
        targetValue: Double = 1,
        isUnlocked: Bool = false,
        unlockedAt: Date? = nil,
        sourceQuestID: String? = nil,
        stageIndex: Int? = nil,
        isFeatured: Bool = false,
        displayOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.rewardID = rewardID
        self.title = title
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
        self.tintHex = tintHex
        self.kind = kind
        self.currentValue = max(0, currentValue)
        self.targetValue = max(targetValue, 1)
        self.isUnlocked = isUnlocked
        self.unlockedAt = unlockedAt
        self.sourceQuestID = sourceQuestID
        self.stageIndex = stageIndex
        self.isFeatured = isFeatured
        self.displayOrder = displayOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var progressFraction: Double {
        guard targetValue > 0 else { return 0 }
        return min(max(currentValue / targetValue, 0), 1)
    }
}
