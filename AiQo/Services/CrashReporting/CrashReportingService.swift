import Foundation
import FirebaseCore
import FirebaseCrashlytics

/// Minimum-viable Firebase Crashlytics wrapper.
/// Handles configure, user binding, non-fatal error recording, and custom keys.
/// No analytics events are tracked here — crash signal only.
@MainActor
final class CrashReportingService {
    static let shared = CrashReportingService()
    private init() {}

    // MARK: - Lifecycle

    /// Call once at app launch, before any other Firebase usage.
    func configure() {
        FirebaseApp.configure()
    }

    // MARK: - User Identity

    /// Binds a Supabase user ID to all subsequent crash reports.
    /// Call after sign-in and on every app launch for returning users.
    func setUser(id: String) {
        Crashlytics.crashlytics().setUserID(id)
    }

    /// Clears the user ID (call on sign-out).
    func clearUser() {
        Crashlytics.crashlytics().setUserID("")
    }

    // MARK: - Non-Fatal Errors

    /// Records a non-fatal error with optional context string.
    func record(_ error: Error, context: String? = nil) {
        var userInfo: [String: Any] = [:]
        if let context {
            userInfo[NSLocalizedDescriptionKey] = context
        }
        let wrapped = error as NSError
        let annotated = NSError(domain: wrapped.domain, code: wrapped.code, userInfo: userInfo.merging(wrapped.userInfo) { new, _ in new })
        Crashlytics.crashlytics().record(error: annotated)
    }

    /// Records a message as a non-fatal error under the "AiQo" domain.
    func record(message: String, context: String? = nil) {
        let userInfo: [String: String] = context.map { [NSLocalizedDescriptionKey: $0] } ?? [:]
        let error = NSError(domain: "com.aiqo.app", code: -1, userInfo: userInfo)
        Crashlytics.crashlytics().log(message)
        Crashlytics.crashlytics().record(error: error)
    }

    // MARK: - Breadcrumb Logging

    /// Appends a line to the Crashlytics log visible in the crash report.
    func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    // MARK: - Custom Keys

    /// Attaches a string key-value pair to all subsequent crash reports.
    func setKey(_ key: String, value: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    /// Attaches a boolean key-value pair to all subsequent crash reports.
    func setKey(_ key: String, value: Bool) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }
}
