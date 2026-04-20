import Foundation

/// Lightweight consent gate for on-device certificate verification.
///
/// Even though no data leaves the device, Apple's Human Interface Guidelines recommend
/// explicit opt-in whenever AI analyses user-uploaded content. One UserDefaults bool —
/// no migration, no SwiftData row.
enum OnDeviceVerificationConsent {
    static let key = "hasConsentedToOnDeviceCertVerification"

    static var hasConsented: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static func grant() { hasConsented = true }
    static func revoke() { hasConsented = false }
}
