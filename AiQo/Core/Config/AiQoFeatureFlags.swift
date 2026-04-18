import Foundation

/// Central registry of in-app feature flags sourced from `Info.plist`.
///
/// Prefer the `@FeatureFlag` property wrapper on `FeatureFlags` entries over the
/// lower-level `FeatureFlag` struct or direct `Bundle.main.object` lookups.
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

/// Property wrapper form. Reads fresh from Info.plist each access (no caching) so
/// test injection of bundled Info.plist values takes effect immediately.
@propertyWrapper
struct FeatureFlag {
    let key: String
    let defaultValue: Bool

    init(_ key: String, default defaultValue: Bool = false) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: Bool {
        AiQoFeatureFlags.boolFlag(named: key, default: defaultValue)
    }

    /// Legacy accessor for call sites that used the old struct shape `FeatureFlag(key:defaultValue:).value`.
    /// New code should read the property directly via `@FeatureFlag`.
    var value: Bool { wrappedValue }
}

enum FeatureFlags {
    @FeatureFlag("MEMORY_V4_ENABLED", default: false)
    static var memoryV4Enabled: Bool

    @FeatureFlag("CAPTAIN_BRAIN_V2_ENABLED", default: false)
    static var brainV2Enabled: Bool

    @FeatureFlag("HAMOUDI_BLEND_ENABLED", default: false)
    static var hamoudiBlendEnabled: Bool

    @FeatureFlag("TRIBE_SUBSCRIPTION_GATE_ENABLED", default: false)
    static var tribeSubscriptionGateEnabled: Bool
}
