import Foundation

/// Central registry of in-app feature flags sourced from `Info.plist`.
/// Kept as a lightweight scaffold — new flags should land here so callers
/// never read `Bundle.main.object(forInfoDictionaryKey:)` directly.
enum AiQoFeatureFlags {
    static func boolFlag(named key: String, default defaultValue: Bool) -> Bool {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: key)

        if let boolValue = rawValue as? Bool {
            return boolValue
        }

        if let stringValue = rawValue as? String {
            switch stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1":
                return true
            case "false", "no", "0":
                return false
            default:
                break
            }
        }

        return defaultValue
    }
}

struct FeatureFlag {
    let key: String
    let defaultValue: Bool

    var value: Bool {
        AiQoFeatureFlags.boolFlag(named: key, default: defaultValue)
    }
}

enum FeatureFlags {
    static let memoryV4Enabled = FeatureFlag(
        key: "MEMORY_V4_ENABLED",
        defaultValue: false
    )
}
