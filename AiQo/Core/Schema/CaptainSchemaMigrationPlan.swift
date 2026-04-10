import Foundation
import SwiftData

enum CaptainSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CaptainSchemaV1.self, CaptainSchemaV2.self, CaptainSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
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
}
