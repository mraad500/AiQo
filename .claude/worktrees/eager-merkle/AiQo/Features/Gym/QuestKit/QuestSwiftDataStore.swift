import Foundation
import SwiftData

@MainActor
protocol PlayerStatsSyncing: AnyObject {
    func syncPlayerStats(level: Int, currentLevelXP: Int, totalXP: Int)
    func syncTotalAura(_ totalAura: Double)
}

@MainActor
final class QuestPersistenceController: PlayerStatsSyncing {
    static let shared = QuestPersistenceController()

    let container: ModelContainer

    private let defaults: UserDefaults
    private let evaluator = QuestEvaluator()
    private let legacyProgressStore: UserDefaultsQuestProgressStore
    private let definitionsByID: [String: QuestDefinition]

    private init(
        inMemory: Bool = false,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.legacyProgressStore = UserDefaultsQuestProgressStore(defaults: defaults)
        self.definitionsByID = Dictionary(uniqueKeysWithValues: QuestDefinitions.all.map { ($0.id, $0) })

        let schema = Schema([
            PlayerStats.self,
            QuestStage.self,
            QuestRecord.self,
            Reward.self
        ])
        let configuration = ModelConfiguration(
            "QuestLootEngine",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Fallback to in-memory store to avoid a production crash
            let fallback = ModelConfiguration(
                "QuestLootEngine-Fallback",
                schema: schema,
                isStoredInMemoryOnly: true
            )
            do {
                container = try ModelContainer(for: schema, configurations: fallback)
            } catch {
                // In-memory ModelContainer creation should never fail.
                // If it does, this is a fundamental framework bug.
                fatalError("Failed to create even an in-memory Quest ModelContainer: \(error)")
            }
        }

        bootstrapIfNeeded()
    }

    func installQuestPersistence(into engine: QuestEngine? = nil) {
        bootstrapIfNeeded()
        let resolvedEngine = engine ?? QuestEngine.shared
        let store = SwiftDataQuestProgressStore(
            modelContext: container.mainContext,
            definitionsByID: definitionsByID
        )
        resolvedEngine.configure(progressStore: store)
    }

    func syncPlayerStats(level: Int, currentLevelXP: Int, totalXP: Int) {
        let stats = fetchOrCreatePlayerStats()
        stats.currentLevel = max(1, level)
        stats.currentLevelXP = max(0, currentLevelXP)
        stats.totalXP = max(0, totalXP)
        stats.updatedAt = Date()
        saveContextIfNeeded()
    }

    func syncTotalAura(_ totalAura: Double) {
        let stats = fetchOrCreatePlayerStats()
        stats.totalAura = max(0, totalAura)
        stats.updatedAt = Date()
        saveContextIfNeeded()
    }

    private func bootstrapIfNeeded() {
        let stageByIndex = upsertStages()
        upsertQuestRecords(stageByIndex: stageByIndex)
        upsertRewards()
        _ = fetchOrCreatePlayerStats()
        saveContextIfNeeded()
    }

    @discardableResult
    private func fetchOrCreatePlayerStats() -> PlayerStats {
        let descriptor = FetchDescriptor<PlayerStats>()
        let existing = (try? container.mainContext.fetch(descriptor)) ?? []

        if let stats = existing.first(where: { $0.profileID == PlayerStats.primaryID }) {
            return stats
        }

        let level = max(defaults.integer(forKey: "aiqo.user.level"), 1)
        let currentLevelXP = defaults.integer(forKey: "aiqo.user.currentXP")
        let totalXP = defaults.integer(forKey: "aiqo.user.totalXP")
        let stats = PlayerStats(
            currentLevel: level,
            currentLevelXP: currentLevelXP,
            totalXP: totalXP,
            totalAura: 0
        )
        container.mainContext.insert(stats)
        return stats
    }

    private func upsertStages() -> [Int: QuestStage] {
        let descriptor = FetchDescriptor<QuestStage>(sortBy: [SortDescriptor(\.stageIndex)])
        let existingStages = (try? container.mainContext.fetch(descriptor)) ?? []
        var stageByIndex = Dictionary(uniqueKeysWithValues: existingStages.map { ($0.stageIndex, $0) })

        for stage in QuestDefinitions.stageModels() {
            if let existing = stageByIndex[stage.id] {
                existing.titleKey = stage.titleKey
                existing.tabTitleKey = stage.tabTitleKey
                existing.sortOrder = stage.id
                existing.updatedAt = Date()
            } else {
                let created = QuestStage(
                    stageIndex: stage.id,
                    titleKey: stage.titleKey,
                    tabTitleKey: stage.tabTitleKey,
                    sortOrder: stage.id
                )
                container.mainContext.insert(created)
                stageByIndex[stage.id] = created
            }
        }

        return stageByIndex
    }

    private func upsertQuestRecords(stageByIndex: [Int: QuestStage]) {
        let descriptor = FetchDescriptor<QuestRecord>(sortBy: [
            SortDescriptor(\.stageIndex),
            SortDescriptor(\.questIndex)
        ])
        let existing = (try? container.mainContext.fetch(descriptor)) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.questID, $0) })
        let legacyRecords = existing.isEmpty ? legacyProgressStore.load() : [:]
        let now = Date()

        for definition in QuestDefinitions.all {
            let progress = legacyRecords[definition.id] ?? evaluator.initialRecord(for: definition.id, now: now)
            let stage = stageByIndex[definition.stageIndex]

            if let record = existingByID[definition.id] {
                record.apply(definition: definition, progress: record.progressRecord, stage: stage)
            } else {
                let created = QuestRecord(
                    definition: definition,
                    progress: progress,
                    stage: stage
                )
                container.mainContext.insert(created)
            }
        }
    }

    private func upsertRewards() {
        let descriptor = FetchDescriptor<Reward>(sortBy: [SortDescriptor(\.displayOrder)])
        let existing = (try? container.mainContext.fetch(descriptor)) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.rewardID, $0) })

        for seed in RewardSeed.defaultCatalog {
            if let reward = existingByID[seed.rewardID] {
                reward.title = seed.title
                reward.subtitle = seed.subtitle
                reward.iconSystemName = seed.iconSystemName
                reward.tintHex = seed.tintHex
                reward.kind = seed.kind
                reward.targetValue = max(seed.targetValue, 1)
                reward.sourceQuestID = seed.sourceQuestID
                reward.stageIndex = seed.stageIndex
                reward.isFeatured = seed.isFeatured
                reward.displayOrder = seed.displayOrder
                reward.updatedAt = Date()
            } else {
                container.mainContext.insert(seed.makeModel())
            }
        }
    }

    private func saveContextIfNeeded() {
        guard container.mainContext.hasChanges else { return }

        do {
            try container.mainContext.save()
        } catch {
            #if DEBUG
            print("Failed to save Quest & Loot SwiftData context: \(error)")
            #endif
        }
    }
}

@MainActor
final class SwiftDataQuestProgressStore: QuestProgressStore {
    private let modelContext: ModelContext
    private let definitionsByID: [String: QuestDefinition]

    init(
        modelContext: ModelContext,
        definitionsByID: [String: QuestDefinition]
    ) {
        self.modelContext = modelContext
        self.definitionsByID = definitionsByID
    }

    func load() -> [String: QuestProgressRecord] {
        let descriptor = FetchDescriptor<QuestRecord>(sortBy: [
            SortDescriptor(\.stageIndex),
            SortDescriptor(\.questIndex)
        ])
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: records.map { ($0.questID, $0.progressRecord) })
    }

    func save(_ records: [String: QuestProgressRecord]) {
        let stageDescriptor = FetchDescriptor<QuestStage>()
        let stages = (try? modelContext.fetch(stageDescriptor)) ?? []
        let stageByIndex = Dictionary(uniqueKeysWithValues: stages.map { ($0.stageIndex, $0) })

        let recordDescriptor = FetchDescriptor<QuestRecord>()
        let persisted = (try? modelContext.fetch(recordDescriptor)) ?? []
        let persistedByID = Dictionary(uniqueKeysWithValues: persisted.map { ($0.questID, $0) })

        for (questID, progress) in records {
            let stage = stageByIndex[definitionsByID[questID]?.stageIndex ?? persistedByID[questID]?.stageIndex ?? 0]

            if let existing = persistedByID[questID] {
                if let definition = definitionsByID[questID] {
                    existing.apply(definition: definition, progress: progress, stage: stage)
                } else {
                    existing.apply(progress: progress)
                    existing.stage = stage ?? existing.stage
                }
            } else if let definition = definitionsByID[questID] {
                let created = QuestRecord(
                    definition: definition,
                    progress: progress,
                    stage: stage
                )
                modelContext.insert(created)
            }
        }

        guard modelContext.hasChanges else { return }

        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Failed to save QuestRecord models to SwiftData: \(error)")
            #endif
        }
    }
}

private struct RewardSeed {
    let rewardID: String
    let title: String
    let subtitle: String
    let iconSystemName: String
    let tintHex: String
    let kind: RewardKind
    let targetValue: Double
    let sourceQuestID: String?
    let stageIndex: Int?
    let isFeatured: Bool
    let displayOrder: Int

    func makeModel() -> Reward {
        Reward(
            rewardID: rewardID,
            title: title,
            subtitle: subtitle,
            iconSystemName: iconSystemName,
            tintHex: tintHex,
            kind: kind,
            currentValue: 0,
            targetValue: targetValue,
            isUnlocked: false,
            sourceQuestID: sourceQuestID,
            stageIndex: stageIndex,
            isFeatured: isFeatured,
            displayOrder: displayOrder
        )
    }

    static let defaultCatalog: [RewardSeed] = [
        RewardSeed(
            rewardID: "reward.streak.7day",
            title: "7-Day Streak",
            subtitle: "Train 7 days total",
            iconSystemName: "flame.fill",
            tintHex: "#FFC739",
            kind: .badge,
            targetValue: 7,
            sourceQuestID: "s5q1",
            stageIndex: 5,
            isFeatured: false,
            displayOrder: 0
        ),
        RewardSeed(
            rewardID: "reward.heart.hero",
            title: "Heart Hero",
            subtitle: "Hit target BPM 3 times",
            iconSystemName: "heart.fill",
            tintHex: "#FF668C",
            kind: .badge,
            targetValue: 3,
            sourceQuestID: nil,
            stageIndex: nil,
            isFeatured: false,
            displayOrder: 1
        ),
        RewardSeed(
            rewardID: "reward.step.master",
            title: "Step Master",
            subtitle: "10k steps in one day",
            iconSystemName: "figure.walk",
            tintHex: "#59D9A6",
            kind: .badge,
            targetValue: 1,
            sourceQuestID: "s4q1",
            stageIndex: 4,
            isFeatured: false,
            displayOrder: 2
        ),
        RewardSeed(
            rewardID: "reward.gratitude.mode",
            title: "Gratitude Mode",
            subtitle: "Log gratitude 5 times",
            iconSystemName: "sparkles",
            tintHex: "#B399F2",
            kind: .badge,
            targetValue: 5,
            sourceQuestID: "s2q4",
            stageIndex: 2,
            isFeatured: false,
            displayOrder: 3
        ),
        RewardSeed(
            rewardID: "reward.weekly.chest",
            title: "Weekly Chest",
            subtitle: "Complete 3 workouts this week",
            iconSystemName: "gift.fill",
            tintHex: "#C4F0DB",
            kind: .chest,
            targetValue: 3,
            sourceQuestID: nil,
            stageIndex: nil,
            isFeatured: true,
            displayOrder: 4
        )
    ]
}
