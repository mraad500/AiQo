import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

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
#if canImport(FirebaseCore) && canImport(FirebaseCrashlytics)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
#else
        #if DEBUG
        print("[CrashReporting] Firebase SDK not linked. Crash reporting is disabled for this build.")
        #endif
#endif
    }

    // MARK: - User Identity

    /// Binds a Supabase user ID to all subsequent crash reports.
    /// Call after sign-in and on every app launch for returning users.
    func setUser(id: String) {
#if canImport(FirebaseCore) && canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(id)
#endif
    }

    /// Clears the user ID (call on sign-out).
    func clearUser() {
#if canImport(FirebaseCore) && canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID("")
#endif
    }

    // MARK: - Non-Fatal Errors

    /// Records a non-fatal error with optional context string.
    func record(_ error: Error, context: String? = nil) {
#if canImport(FirebaseCore) && canImport(FirebaseCrashlytics)
        var userInfo: [String: Any] = [:]
        if let context {
            userInfo[NSLocalizedDescriptionKey] = context
        }
        let wrapped = error as NSError
        let annotated = NSError(domain: wrapped.domain, code: wrapped.code, userInfo: userInfo.merging(wrapped.userInfo) { new, _ in new })
        Crashlytics.crashlytics().record(error: annotated)
#endif
    }

    /// Records a message as a non-fatal error under the "AiQo" domain.
    func record(message: String, context: String? = nil) {
#if canImport(FirebaseCore) && canImport(FirebaseCrashlytics)
        let userInfo: [String: String] = context.map { [NSLocalizedDescriptionKey: $0] } ?? [:]
        let error = NSError(domain: "com.aiqo.app", code: -1, userInfo: userInfo)
        Crashlytics.crashlytics().log(message)
        Crashlytics.crashlytics().record(error: error)
#endif
    }

    // MARK: - Breadcrumb Logging

    /// Appends a line to the Crashlytics log visible in the crash report.
    func log(_ message: String) {
#if canImport(FirebaseCore) && canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
#endif
    }

    // MARK: - Custom Keys

    /// Attaches a string key-value pair to all subsequent crash reports.
    func setKey(_ key: String, value: String) {
#if canImport(FirebaseCore) && canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
#endif
    }

    /// Attaches a boolean key-value pair to all subsequent crash reports.
    func setKey(_ key: String, value: Bool) {
#if canImport(FirebaseCore) && canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
#endif
    }
}
