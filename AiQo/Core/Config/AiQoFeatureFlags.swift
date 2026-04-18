import Foundation

/// Central registry of in-app feature flags sourced from `Info.plist`.
/// Kept as a lightweight scaffold — new flags should land here so callers
/// never read `Bundle.main.object(forInfoDictionaryKey:)` directly.
enum AiQoFeatureFlags {
}
