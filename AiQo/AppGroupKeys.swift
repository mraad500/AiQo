import Foundation

struct AppGroupKeys {
    // المجموعة المشتركة فعلياً بين التطبيق والـ widgets والساعة
    static let appGroupID = "group.aiqo"
    static let legacyAppGroupID = "group.com.aiqo.kernel2"
    
    static let isEnabled = "isProtectionEnabled"
    static let savedSelection = "savedSelection"
    static let userCoins = "userCoins"

    /// Kernel (digital-wellbeing) shared state blob — a single JSON-encoded
    /// `KernelState` read/written by the app and all three Kernel extensions.
    static let kernelState = "kernel.state"

    static func defaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func legacyDefaults() -> UserDefaults? {
        UserDefaults(suiteName: legacyAppGroupID)
    }
}
