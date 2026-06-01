import Foundation
import SwiftData

/// V5 adds `LearnedDirective` — user-taught standing instructions the Captain
/// persists and executes. Purely additive over V4 (one new model, no changes to
/// existing models) → lightweight migration is safe, same as V1→V2 and V2→V3.
enum MemorySchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            EpisodicEntry.self,
            SemanticFact.self,
            ProceduralPattern.self,
            EmotionalMemory.self,
            Relationship.self,
            MonthlyReflection.self,
            ConsolidationDigest.self,
            CaptainPersonalizationProfile.self,
            WeeklyReportEntry.self,
            WeeklyMetricsBuffer.self,
            ConversationThreadEntry.self,
            RecordProject.self,
            WeeklyLog.self,
            LearnedDirective.self
        ]
    }
}
