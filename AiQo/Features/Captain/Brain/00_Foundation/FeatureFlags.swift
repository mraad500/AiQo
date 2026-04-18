import Foundation

// AiQo Brain OS — 00_Foundation
//
// Unified Info.plist feature flag reader with validation + defaults.
// Source of truth: Info.plist boolean keys. Each flag gives back a default
// value when the key is absent OR present as a non-boolean, so missing keys
// never throw and never accidentally flip a feature on.
public enum FeatureFlags {

    // MARK: - Brain OS flags

    public static let captainBrainV2Enabled = BoolFlag(
        key: "CAPTAIN_BRAIN_V2_ENABLED",
        default: false
    )

    public static let notificationBrainEnabled = BoolFlag(
        key: "NOTIFICATION_BRAIN_ENABLED",
        default: false
    )

    public static let memoryV4Enabled = BoolFlag(
        key: "MEMORY_V4_ENABLED",
        default: false
    )

    public static let proactiveTriggerMemoryCallback = BoolFlag(
        key: "PROACTIVE_MEMORY_CALLBACK_ENABLED",
        default: false
    )

    public static let proactiveTriggerEmotional = BoolFlag(
        key: "PROACTIVE_EMOTIONAL_ENABLED",
        default: false
    )

    public static let proactiveTriggerCultural = BoolFlag(
        key: "PROACTIVE_CULTURAL_ENABLED",
        default: false
    )

    public static let crisisDetectorEnabled = BoolFlag(
        key: "CRISIS_DETECTOR_ENABLED",
        default: false
    )

    // MARK: - Debug flags

    public static let brainDashboardEnabled = BoolFlag(
        key: "BRAIN_DASHBOARD_ENABLED",
        default: false
    )

    public static let auditLoggerVerbose = BoolFlag(
        key: "AUDIT_LOGGER_VERBOSE",
        default: false
    )

    // MARK: - Types

    public struct BoolFlag: Sendable {
        public let key: String
        public let defaultValue: Bool

        public init(key: String, default defaultValue: Bool) {
            self.key = key
            self.defaultValue = defaultValue
        }

        public var value: Bool {
            guard let raw = Bundle.main.object(forInfoDictionaryKey: key) else {
                return defaultValue
            }
            if let bool = raw as? Bool { return bool }
            if let str = raw as? String {
                return ["true", "yes", "1"].contains(str.lowercased())
            }
            if let num = raw as? NSNumber { return num.boolValue }
            return defaultValue
        }

        /// True when the Info.plist doesn't carry a value for this key — callers
        /// can surface "missing" in a developer panel.
        public var isDefault: Bool {
            Bundle.main.object(forInfoDictionaryKey: key) == nil
        }
    }

    // MARK: - Dump (debug helper)

    public static func dump() -> [String: Bool] {
        [
            captainBrainV2Enabled.key: captainBrainV2Enabled.value,
            notificationBrainEnabled.key: notificationBrainEnabled.value,
            memoryV4Enabled.key: memoryV4Enabled.value,
            proactiveTriggerMemoryCallback.key: proactiveTriggerMemoryCallback.value,
            proactiveTriggerEmotional.key: proactiveTriggerEmotional.value,
            proactiveTriggerCultural.key: proactiveTriggerCultural.value,
            crisisDetectorEnabled.key: crisisDetectorEnabled.value,
            brainDashboardEnabled.key: brainDashboardEnabled.value,
            auditLoggerVerbose.key: auditLoggerVerbose.value,
        ]
    }
}
