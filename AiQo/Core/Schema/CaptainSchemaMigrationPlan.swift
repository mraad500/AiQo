import Foundation
import SwiftData

enum CaptainSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CaptainSchemaV1.self, CaptainSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// V1 -> V2 is purely additive (two new models). Lightweight migration is safe.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: CaptainSchemaV1.self,
        toVersion: CaptainSchemaV2.self
    )
}
