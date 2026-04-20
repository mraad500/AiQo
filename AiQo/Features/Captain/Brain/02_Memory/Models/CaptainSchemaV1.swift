import Foundation
import SwiftData

/// Frozen snapshot of the Captain ModelContainer schema as it shipped before the
/// Trial Journey + Weekly Memory work. DO NOT modify this file. It represents
/// historical truth for migration.
enum CaptainSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CaptainMemory.self,
            CaptainPersonalizationProfile.self,
            PersistentChatMessage.self,
            RecordProject.self,
            WeeklyLog.self
        ]
    }
}
