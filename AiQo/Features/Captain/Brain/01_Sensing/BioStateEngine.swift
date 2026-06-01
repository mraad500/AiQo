import Foundation

/// Unified read-only bio state API.
/// All HealthKit reads funnel through here; other Brain/ components should never query HKHealthStore directly.
///
/// Caches the latest snapshot for a short freshness window so that rapid-fire calls
/// (retriever → prompt builder → context sensor) don't hammer HealthKit.
actor BioStateEngine {
    static let shared = BioStateEngine()

    typealias MetricsFetcher = @Sendable () async throws -> CaptainDailyHealthMetrics

    private let fetchMetrics: MetricsFetcher
    private let clock: @Sendable () -> Date
    private let freshnessWindow: TimeInterval
    private var lastSnapshot: BioSnapshot?
    private var lastSnapshotAt: Date?

    init(
        fetchMetrics: @escaping MetricsFetcher = { try await CaptainHealthSnapshotService.shared.fetchTodayEssentialMetrics() },
        clock: @escaping @Sendable () -> Date = Date.init,
        freshnessWindow: TimeInterval = 180
    ) {
        self.fetchMetrics = fetchMetrics
        self.clock = clock
        self.freshnessWindow = freshnessWindow
    }

    /// Returns a fresh bio snapshot, re-fetching HealthKit if the cached one is stale.
    func current() async -> BioSnapshot {
        if let cached = lastSnapshot,
           let fetchedAt = lastSnapshotAt,
           clock().timeIntervalSince(fetchedAt) < freshnessWindow {
            return cached
        }
        return await refresh()
    }

    /// Force refresh, ignoring cache. Use for critical moments (crisis, trigger eval).
    @discardableResult
    func refresh() async -> BioSnapshot {
        let fresh = await buildSnapshot()
        lastSnapshot = fresh
        lastSnapshotAt = clock()
        return fresh
    }

    /// True when bio state indicates recovery is needed: low HRV or short sleep.
    func needsRecovery() async -> Bool {
        let snap = await current()
        if let hrv = snap.hrvBucketed, hrv < 30 { return true }
        if let sleep = snap.sleepHoursBucketed, sleep < 6.0 { return true }
        return false
    }

    /// True when in a detected fasting window. Honors whatever `buildSnapshot()` decided.
    func isFasting() async -> Bool {
        await current().isFasting
    }

    // MARK: - Private

    private func buildSnapshot() async -> BioSnapshot {
        let metrics: CaptainDailyHealthMetrics
        do {
            metrics = try await fetchMetrics()
        } catch {
            diag.warning("BioStateEngine: metrics fetch failed (\(error.localizedDescription)) — returning zeros")
            metrics = CaptainDailyHealthMetrics(
                stepCount: 0,
                activeEnergyKilocalories: 0,
                averageOrCurrentHeartRateBPM: nil,
                sleepHours: 0
            )
        }

        // Vitals are stored EXACT. The field names keep their `Bucketed` suffix
        // only to preserve BioSnapshot's Codable on-disk contract (episodic /
        // procedural memory persisted on device); no coarsening is applied, so
        // the Captain reasons on — and reports — the user's real numbers.
        return BioSnapshot(
            timestamp: clock(),
            stepsBucketed: max(0, metrics.stepCount),
            heartRateBucketed: metrics.averageOrCurrentHeartRateBPM.map { max(0, $0) },
            hrvBucketed: nil,
            sleepHoursBucketed: metrics.sleepHours > 0 ? max(0, metrics.sleepHours) : nil,
            caloriesBucketed: max(0, metrics.activeEnergyKilocalories),
            timeOfDay: BioSnapshot.TimeOfDay.current(clock: clock),
            dayOfWeek: Calendar.current.component(.weekday, from: clock()),
            isFasting: false
        )
    }
}

// MARK: - TimeOfDay.current helper

extension BioSnapshot.TimeOfDay {
    /// Maps the current local hour into a coarse time-of-day bucket.
    nonisolated static func current(clock: @Sendable () -> Date = Date.init) -> Self {
        let hour = Calendar.current.component(.hour, from: clock())
        switch hour {
        case 4..<7:   return .dawn
        case 7..<11:  return .morning
        case 11..<14: return .midday
        case 14..<17: return .afternoon
        case 17..<21: return .evening
        case 21..<24: return .night
        default:      return .lateNight
        }
    }
}
