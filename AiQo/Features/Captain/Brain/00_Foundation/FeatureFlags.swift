import Foundation

// AiQo Brain OS — 00_Foundation
// Status: SCAFFOLDING (P1.1)
// TODO(P1.3): extend with validation + defaults.

public enum FeatureFlags {
    public static var captainBrainV2Enabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "CAPTAIN_BRAIN_V2_ENABLED") as? Bool ?? false
    }

    public static var notificationBrainEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NOTIFICATION_BRAIN_ENABLED") as? Bool ?? false
    }

    public static var memoryV4Enabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "MEMORY_V4_ENABLED") as? Bool ?? false
    }
}
