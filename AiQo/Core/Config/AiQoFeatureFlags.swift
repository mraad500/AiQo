import Foundation

enum AiQoFeatureFlags {
    static var hamoudiBlendEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "HAMOUDI_BLEND_ENABLED") as? Bool ?? false
    }
}
