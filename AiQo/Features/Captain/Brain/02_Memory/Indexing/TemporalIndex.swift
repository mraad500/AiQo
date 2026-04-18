import Foundation

/// Fast time-window lookups with a TTL cache so repeated
/// "what happened today" queries don't re-scan the DB.
public actor TemporalIndex {
    public static let shared = TemporalIndex()

    public enum Window: Hashable, Sendable {
        case today
        case lastNDays(Int)
        case lastNWeeks(Int)

        public var dateRange: (start: Date, end: Date) {
            let now = Date()
            let cal = Calendar.current
            switch self {
            case .today:
                let start = cal.startOfDay(for: now)
                return (start, now)
            case .lastNDays(let n):
                let start = cal.date(byAdding: .day, value: -max(0, n), to: now) ?? now
                return (start, now)
            case .lastNWeeks(let n):
                let start = cal.date(byAdding: .weekOfYear, value: -max(0, n), to: now) ?? now
                return (start, now)
            }
        }
    }

    private struct CacheEntry {
        let evaluatedAt: Date
        let entryIDs: [UUID]
    }

    private var cache: [Window: CacheEntry] = [:]
    private let cacheTTLSeconds: TimeInterval = 300

    private init() {}

    /// Returns entry IDs for the given window.
    /// `resolver` is invoked to compute fresh results when cache is stale.
    public func entryIDs(
        in window: Window,
        resolver: () async -> [UUID]
    ) async -> [UUID] {
        if let cached = cache[window],
           Date().timeIntervalSince(cached.evaluatedAt) < cacheTTLSeconds {
            return cached.entryIDs
        }
        let fresh = await resolver()
        cache[window] = CacheEntry(evaluatedAt: Date(), entryIDs: fresh)
        return fresh
    }

    public func invalidate(_ window: Window? = nil) {
        if let window {
            cache.removeValue(forKey: window)
        } else {
            cache.removeAll()
        }
    }

    #if DEBUG
    public func _cacheSize() -> Int { cache.count }
    #endif
}
