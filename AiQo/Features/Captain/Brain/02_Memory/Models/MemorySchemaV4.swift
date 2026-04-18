import Foundation
import SwiftData

/// V4 replaces flat key/value and per-message chat persistence with richer memory primitives.
enum MemorySchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

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
            WeeklyLog.self
        ]
    }
}
