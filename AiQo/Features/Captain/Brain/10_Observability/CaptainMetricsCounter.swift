import Foundation

/// Lightweight on-device counter for Captain pipeline observability.
///
/// Bridges the gap between "logger.info shipped to Console.app" and a real
/// telemetry pipeline. Counts how often dynamic-welcome and workout-analysis
/// reach each terminal state (success, timeout, offline, no-consent,
/// tier-blocked, empty, error). Lets us spot regressions on TestFlight
/// without rolling Supabase event tables yet.
///
/// UserDefaults-backed for v1; the migration target is Supabase
/// `captain_metrics` with the same `(event, reason)` schema, so call sites
/// don't need to change when the backend ships.
///
/// Privacy contract — non-negotiable: stores ONLY event names + reason codes.
/// Never user content. Never PII. Never prompt or response text. Never user
/// identifiers. Pure counters and millisecond totals only.
@MainActor
final class CaptainMetricsCounter {
    static let shared = CaptainMetricsCounter()

    private init() {}

    private let defaults = UserDefaults.standard
    private let prefix = "aiqo.captain.metrics."

    /// Increment a counter at `event.reason` and (optionally) accumulate a
    /// latency total at `event.latency_ms_total`. Reason defaults to `"ok"`
    /// for the rare call site that just wants a hit-count without branching.
    func record(event: String, reason: String? = nil, latencyMs: Int? = nil) {
        let reasonKey = reason ?? "ok"
        let key = "\(prefix)\(event).\(reasonKey)"
        let count = defaults.integer(forKey: key) + 1
        defaults.set(count, forKey: key)

        if let ms = latencyMs {
            let latencyKey = "\(prefix)\(event).latency_ms_total"
            let total = defaults.integer(forKey: latencyKey) + ms
            defaults.set(total, forKey: latencyKey)
        }
    }

    /// Snapshot of every counter under the namespace. Strips the namespace
    /// prefix so callers see clean keys like `"workout_analysis.succeeded"`.
    func snapshot() -> [String: Int] {
        var out: [String: Int] = [:]
        for (key, value) in defaults.dictionaryRepresentation() {
            guard key.hasPrefix(prefix), let intValue = value as? Int else { continue }
            out[String(key.dropFirst(prefix.count))] = intValue
        }
        return out
    }

    #if DEBUG
    /// Wipe every counter in the namespace. Debug-only — never call on prod
    /// devices, since we'd lose the rolling baseline we use to spot regressions.
    func reset() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }
    #endif
}
