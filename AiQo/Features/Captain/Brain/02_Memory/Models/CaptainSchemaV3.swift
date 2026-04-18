import Foundation
import SwiftData

/// V3 adds ConversationThreadEntry for the unified Captain interaction timeline.
/// Purely additive — lightweight migration from V2.
enum CaptainSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CaptainMemory.self,
            CaptainPersonalizationProfile.self,
            PersistentChatMessage.self,
            RecordProject.self,
            WeeklyLog.self,
            WeeklyMetricsBuffer.self,
            WeeklyReportEntry.self,
            ConversationThreadEntry.self
        ]
    }
}
