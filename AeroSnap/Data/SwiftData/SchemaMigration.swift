import Foundation
import SwiftData

/// First versioned schema for the SwiftData store. Frozen — *do not
/// edit*. When the model shapes change, add a new V2 enum and append
/// a migration stage in `AeroSnapMigrationPlan` rather than mutating
/// V1 in place. SwiftData uses the version identifier to decide
/// whether the on-disk store needs migrating.
enum AeroSnapSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            FavoriteAD.self,
            AircraftCollection.self,
            AircraftCollectionItem.self,
            ADNote.self,
        ]
    }
}

/// Migration plan covering every schema version we've ever shipped.
/// Each future stage describes how to move from version N to N+1 —
/// either `lightweight` (SwiftData figures it out from the diff) or
/// `custom` (closure to transform rows manually).
///
/// Today there is only V1, so `stages` is empty. As soon as we ship
/// a V2 (e.g. add a field with a non-default value, rename a model,
/// change a relationship cardinality), add the stage here.
enum AeroSnapMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AeroSnapSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
