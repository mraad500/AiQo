import Foundation

/// On-device rate limiter for certificate verification attempts. 3 per hour.
///
/// Backed by a single UserDefaults key holding a rotating array of attempt
/// timestamps (max 10 entries to bound growth). Trims old entries on every call.
/// Deterministic, testable via the `now:` parameter.
enum VerificationRateLimiter {
    // All static constants `nonisolated` so the `nonisolated` methods below can read
    // them without MainActor hops under Swift 6 strict concurrency.
    nonisolated static let key = "aiqo.learningSpark.verificationAttempts"
    nonisolated static let windowSeconds: TimeInterval = 3600   // 1 hour
    nonisolated static let maxAttempts = 3
    nonisolated static let storageRingSize = 10

    /// Returns `true` when the user is under the per-hour limit.
    ///
    /// `nonisolated` so `CertificateVerifier` (an `actor`) can call it without hopping
    /// to MainActor. Reads/writes use thread-safe `UserDefaults.standard`.
    nonisolated static func canAttempt(now: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        let recent = recentAttempts(now: now, defaults: defaults)
        return recent.count < maxAttempts
    }

    /// Records a verification attempt. Idempotent — caller should invoke ONCE per
    /// user-initiated submit.
    nonisolated static func recordAttempt(now: Date = Date(), defaults: UserDefaults = .standard) {
        var attempts = loadAttempts(defaults: defaults)
        attempts.append(now.timeIntervalSince1970)

        // Trim to the ring size — cheaper than rolling windows on every read.
        if attempts.count > storageRingSize {
            attempts = Array(attempts.suffix(storageRingSize))
        }
        defaults.set(attempts, forKey: key)
    }

    /// Seconds until the oldest in-window attempt ages out — used for "try again in X"
    /// messaging.
    nonisolated static func retryAfterSeconds(now: Date = Date(), defaults: UserDefaults = .standard) -> TimeInterval {
        let recent = recentAttempts(now: now, defaults: defaults).sorted()
        guard let oldest = recent.first else { return 0 }
        let secondsSinceOldest = now.timeIntervalSince1970 - oldest
        return max(0, windowSeconds - secondsSinceOldest)
    }

    // MARK: - Internals

    nonisolated private static func loadAttempts(defaults: UserDefaults) -> [TimeInterval] {
        defaults.array(forKey: key) as? [TimeInterval] ?? []
    }

    nonisolated private static func recentAttempts(now: Date, defaults: UserDefaults) -> [TimeInterval] {
        let cutoff = now.timeIntervalSince1970 - windowSeconds
        return loadAttempts(defaults: defaults).filter { $0 >= cutoff }
    }

    #if DEBUG
    nonisolated static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
    #endif
}
