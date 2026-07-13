import Foundation

/// Three-layer decision gate for the Memory V4 schema. Read sites should use this
/// instead of `FeatureFlags.memoryV4Enabled` directly so the kill switch + the
/// local migration-failure fallback are always respected.
///
/// Precedence (first that fires wins):
///   1. **Remote kill switch** — `RemoteFlags.shared.memoryV4GloballyDisabled`.
///      Flipping the Supabase row globally disables V4 on the next cold launch
///      (or sooner if the BG refresh races first).
///   2. **Local fallback flag** — `UserDefaults` key
///      `aiqo.memory.v4.disabled.fallback`. Set automatically by
///      `recordMigrationFailure(_:)` when the V3→V4 SwiftData migration fails for
///      this user. Sticky until the user deletes the app or we ship a build that
///      clears it.
///   3. **Info.plist feature flag** — `FeatureFlags.memoryV4Enabled`.
enum MemoryV4Gate {
    static let fallbackUserDefaultsKey = "aiqo.memory.v4.disabled.fallback"
    static let migratedUserDefaultsKey = "aiqo.memory.v3_to_v4.migrated.v1"

    static var isOn: Bool {
        if RemoteFlags.shared.memoryV4GloballyDisabled { return false }
        if UserDefaults.standard.bool(forKey: fallbackUserDefaultsKey) { return false }
        return FeatureFlags.memoryV4Enabled
    }

    /// Storage mode mirror so `MemoryStore.configure` sees a consistent answer.
    static var storageMode: MemoryStore.StorageMode {
        isOn ? .schemaV4 : .legacyV3
    }

    /// Sets the local fallback flag and routes the failure to crash reporting.
    /// Subsequent cold launches will use the V3 schema for this user even if the
    /// Info.plist feature flag is ON and the remote kill switch is OFF.
    static func recordMigrationFailure(_ error: Error, context: String) {
        UserDefaults.standard.set(true, forKey: fallbackUserDefaultsKey)
        CrashReporter.shared.recordError(error, context: context)
        diag.error("MemoryV4Gate: forcing V3 fallback after migration failure (\(context))", error: error)
    }

    /// Manual clear — exposed for support-mode resets if a user reports being stuck on V3.
    /// Not currently surfaced in UI.
    static func clearFallbackFlag() {
        UserDefaults.standard.removeObject(forKey: fallbackUserDefaultsKey)
    }
}
