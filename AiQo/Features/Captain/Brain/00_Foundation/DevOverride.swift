import Foundation

/// Dev-only feature unlock. Reads from Info.plist key `AIQO_DEV_UNLOCK_ALL`.
/// MUST be `<false/>` in production builds.
///
/// In RELEASE builds this helper is hard-coded to return `false` regardless of
/// the Info.plist value, so the locked default path is always the one that
/// runs in shipped binaries.
enum DevOverride {
    static let infoPlistKey = "AIQO_DEV_UNLOCK_ALL"

    /// When `true`, every subscription-gated feature behaves as if the user is on the
    /// highest paid tier. Read via Info.plist on every call so toggling the plist flag
    /// takes effect without rebuilding logic — there is intentionally no caching.
    static var unlockAllFeatures: Bool {
        #if DEBUG
        return Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? Bool ?? false
        #else
        return false
        #endif
    }

    /// Logs a loud warning on app launch when the override is active, so there is
    /// no chance of shipping a build that has it accidentally left on.
    static func warnIfActive() {
        let plistValue = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? Bool ?? false
        let compiledAsDebug: Bool = {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }()

        print("---- DevOverride diagnostic ----")
        print("  Info.plist AIQO_DEV_UNLOCK_ALL = \(plistValue)")
        print("  Compiled #if DEBUG              = \(compiledAsDebug)")
        print("  unlockAllFeatures (effective)   = \(unlockAllFeatures)")
        print("--------------------------------")

        guard unlockAllFeatures else { return }
        let banner = "⚠️⚠️⚠️ DEV_OVERRIDE ACTIVE — All paid features unlocked. DO NOT SHIP. ⚠️⚠️⚠️"
        print(banner)
        diag.warning(banner)
    }
}
