import Foundation

/// Single source of truth for fact category / source / privacy classification.
///
/// This logic was previously duplicated verbatim in `MemoryStore` (the live
/// write path) and `CaptainSchemaMigrationPlan` (the V3→V4 migration path).
/// Drift between the two would silently misclassify migrated facts — e.g. a
/// PII fact marked cloud-safe — so the privacy-bearing rules live here once.
nonisolated enum FactClassification {

    static func category(for rawCategory: String) -> FactCategory {
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

    static func source(for rawSource: String) -> FactSource {
        switch rawSource.lowercased() {
        case "user_explicit", "explicit":
            return .explicit
        case "inferred":
            return .inferred
        default:
            return .extracted
        }
    }

    static func isPII(key: String, category: String) -> Bool {
        let piiKeys: Set<String> = ["user_name", "weight", "height", "age"]
        return piiKeys.contains(key.lowercased()) || category.lowercased() == "identity"
    }

    static func isSensitive(category: String) -> Bool {
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
}
