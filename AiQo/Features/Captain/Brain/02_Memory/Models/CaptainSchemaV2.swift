import Foundation
import SwiftData

/// V2 adds WeeklyMetricsBuffer and WeeklyReportEntry for the Trial Journey
/// and Weekly Memory Consolidation features. Purely additive.
enum CaptainSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CaptainMemory.self,
            CaptainPersonalizationProfile.self,
            PersistentChatMessage.self,
            RecordProject.self,
            WeeklyLog.self,
            WeeklyMetricsBuffer.self,
            WeeklyReportEntry.self
        ]
    }
}
