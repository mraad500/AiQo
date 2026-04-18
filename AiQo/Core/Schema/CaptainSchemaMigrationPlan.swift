import Foundation
import SwiftData

enum CaptainSchemaMigrationPlan: SchemaMigrationPlan {
    private struct PendingV4Payload {
        struct FactSeed {
            let id: UUID
            let storageKey: String
            let content: String
            let categoryRaw: String
            let confidence: Double
            let sourceRaw: String
            let firstMentionedAt: Date
            let lastConfirmedAt: Date
            let referenceCount: Int
            let isPII: Bool
            let isSensitive: Bool
        }

        struct EpisodeSeed {
            let id: UUID
            let sessionID: UUID
            let timestamp: Date
            let captainResponseTimestamp: Date?
            let userMessageID: UUID
            let captainResponseMessageID: UUID?
            let userMessage: String
            let captainResponse: String
            let captainSpotifyRecommendationData: Data?
        }

        var facts: [FactSeed] = []
        var episodes: [EpisodeSeed] = []
        var sourceMessageCount = 0
    }

    private static var pendingV4Payload = PendingV4Payload()

    static var schemas: [any VersionedSchema.Type] {
        [
            CaptainSchemaV1.self,
            CaptainSchemaV2.self,
            CaptainSchemaV3.self,
            MemorySchemaV4.self
        ]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4]
    }

    /// V1 -> V2 is purely additive (two new models). Lightweight migration is safe.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: CaptainSchemaV1.self,
        toVersion: CaptainSchemaV2.self
    )

    /// V2 -> V3 adds ConversationThreadEntry. Purely additive — lightweight migration is safe.
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: CaptainSchemaV2.self,
        toVersion: CaptainSchemaV3.self
    )

    static let migrateV3toV4 = MigrationStage.custom(
        fromVersion: CaptainSchemaV3.self,
        toVersion: MemorySchemaV4.self,
        willMigrate: { context in
            pendingV4Payload = PendingV4Payload()

            do {
                let oldFacts = try context.fetch(FetchDescriptor<CaptainMemory>())
                pendingV4Payload.facts = oldFacts.map { old in
                    PendingV4Payload.FactSeed(
                        id: old.id,
                        storageKey: old.key,
                        content: old.value,
                        categoryRaw: old.category,
                        confidence: old.confidence,
                        sourceRaw: old.source,
                        firstMentionedAt: old.createdAt,
                        lastConfirmedAt: old.updatedAt,
                        referenceCount: old.accessCount,
                        isPII: isPII(key: old.key, category: old.category),
                        isSensitive: isSensitive(category: old.category)
                    )
                }
                diag.info("Memory v3→v4 staged \(oldFacts.count) legacy facts")
            } catch {
                diag.error("Memory v3→v4 failed to read CaptainMemory", error: error)
            }

            do {
                let oldMessages = try context.fetch(FetchDescriptor<PersistentChatMessage>())
                pendingV4Payload.sourceMessageCount = oldMessages.count
                pendingV4Payload.episodes = pairMessages(oldMessages).map { pair in
                    let episodeID = pair.user?.messageID ?? pair.captain?.messageID ?? UUID()
                    return PendingV4Payload.EpisodeSeed(
                        id: episodeID,
                        sessionID: pair.sessionID,
                        timestamp: pair.user?.timestamp ?? pair.captain?.timestamp ?? Date(),
                        captainResponseTimestamp: pair.captain?.timestamp,
                        userMessageID: pair.user?.messageID ?? UUID(),
                        captainResponseMessageID: pair.captain?.messageID,
                        userMessage: pair.user?.text ?? "",
                        captainResponse: pair.captain?.text ?? "",
                        captainSpotifyRecommendationData: pair.captain?.spotifyRecommendationData
                    )
                }
                diag.info(
                    "Memory v3→v4 staged \(pendingV4Payload.episodes.count) episodes from \(oldMessages.count) legacy messages"
                )
            } catch {
                diag.error("Memory v3→v4 failed to read PersistentChatMessage", error: error)
            }
        },
        didMigrate: { context in
            defer {
                pendingV4Payload = PendingV4Payload()
            }

            do {
                let existingFactIDs = Set(try context.fetch(FetchDescriptor<SemanticFact>()).map(\.id))
                let existingEpisodeIDs = Set(try context.fetch(FetchDescriptor<EpisodicEntry>()).map(\.id))

                var insertedFacts = 0
                for seed in pendingV4Payload.facts where !existingFactIDs.contains(seed.id) {
                    let fact = SemanticFact(
                        id: seed.id,
                        storageKey: seed.storageKey,
                        content: seed.content,
                        category: mapFactCategory(seed.categoryRaw),
                        categoryRawOverride: seed.categoryRaw,
                        confidence: seed.confidence,
                        salience: 0.5,
                        source: mapFactSource(seed.sourceRaw),
                        sourceRawOverride: seed.sourceRaw,
                        firstMentionedAt: seed.firstMentionedAt,
                        lastConfirmedAt: seed.lastConfirmedAt,
                        mentionCount: 1,
                        referenceCount: seed.referenceCount,
                        isPII: seed.isPII,
                        isSensitive: seed.isSensitive
                    )
                    context.insert(fact)
                    insertedFacts += 1
                }

                var insertedEpisodes = 0
                for seed in pendingV4Payload.episodes where !existingEpisodeIDs.contains(seed.id) {
                    let episode = EpisodicEntry(
                        id: seed.id,
                        sessionID: seed.sessionID,
                        timestamp: seed.timestamp,
                        captainResponseTimestamp: seed.captainResponseTimestamp,
                        userMessageID: seed.userMessageID,
                        captainResponseMessageID: seed.captainResponseMessageID,
                        userMessage: seed.userMessage,
                        captainResponse: seed.captainResponse,
                        salienceScore: 0.5
                    )
                    episode.captainSpotifyRecommendationData = seed.captainSpotifyRecommendationData
                    context.insert(episode)
                    insertedEpisodes += 1
                }

                if insertedFacts > 0 || insertedEpisodes > 0 {
                    try context.save()
                }

                UserDefaults.standard.set(true, forKey: "memory.v4.migrated")
                diag.info(
                    "Memory schema v3→v4 migration complete. Migrated \(insertedFacts) facts, \(insertedEpisodes) episodes from \(pendingV4Payload.sourceMessageCount) messages"
                )
            } catch {
                diag.error("Memory v3→v4 destination write failed", error: error)
            }
        }
    )

    private static func mapFactCategory(_ rawCategory: String) -> FactCategory {
        switch rawCategory.lowercased() {
        case "health", "health_condition", "body", "sleep", "injury", "nutrition":
            return .health
        case "preference":
            return .preference
        case "goal", "objective", "active_record_project":
            return .goal
        case "relationship", "family":
            return .relationship
        case "work", "career":
            return .work
        case "habit":
            return .habit
        case "aspiration":
            return .aspiration
        case "fear":
            return .fear
        case "accomplishment", "insight", "workout_history":
            return .accomplishment
        default:
            return .other
        }
    }

    private static func mapFactSource(_ rawSource: String) -> FactSource {
        switch rawSource.lowercased() {
        case "user_explicit", "explicit":
            return .explicit
        case "inferred":
            return .inferred
        default:
            return .extracted
        }
    }

    private static func isPII(key: String, category: String) -> Bool {
        let piiKeys: Set<String> = ["user_name", "weight", "height", "age"]
        return piiKeys.contains(key.lowercased()) || category.lowercased() == "identity"
    }

    private static func isSensitive(category: String) -> Bool {
        let sensitiveCategories: Set<String> = [
            "health",
            "health_condition",
            "mental_health",
            "medical",
            "body",
            "sleep",
            "injury"
        ]
        return sensitiveCategories.contains(category.lowercased())
    }

    private static func pairMessages(_ messages: [PersistentChatMessage]) -> [(sessionID: UUID, user: PersistentChatMessage?, captain: PersistentChatMessage?)] {
        let grouped = Dictionary(grouping: messages, by: \.sessionID)
        let orderedSessions = grouped.keys.sorted { lhs, rhs in
            let lhsDate = grouped[lhs]?.map(\.timestamp).min() ?? .distantPast
            let rhsDate = grouped[rhs]?.map(\.timestamp).min() ?? .distantPast
            return lhsDate < rhsDate
        }

        var result: [(sessionID: UUID, user: PersistentChatMessage?, captain: PersistentChatMessage?)] = []

        for sessionID in orderedSessions {
            let sessionMessages = (grouped[sessionID] ?? []).sorted { $0.timestamp < $1.timestamp }
            var pendingUser: PersistentChatMessage?

            for message in sessionMessages {
                if message.isUser {
                    if let pendingUser {
                        result.append((sessionID, pendingUser, nil))
                    }
                    pendingUser = message
                } else if pendingUser != nil {
                    result.append((sessionID, pendingUser, message))
                    pendingUser = nil
                } else {
                    result.append((sessionID, nil, message))
                }
            }

            if let pendingUser {
                result.append((sessionID, pendingUser, nil))
            }
        }

        return result
    }
}
