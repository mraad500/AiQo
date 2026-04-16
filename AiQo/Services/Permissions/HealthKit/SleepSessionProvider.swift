import Foundation
import HealthKit

// MARK: - Unified Sleep Session

/// Represents sleep calculated the same way Apple Health's "Time Asleep" shows it:
/// 1. Samples are grouped into sessions (gap > 1 hour = new session)
/// 2. Per session: Time Asleep = session envelope - awake duration
///    (short gaps within a session count as sleep; long waking gaps do not)
/// 3. Total = sum of all sessions' Time Asleep values
struct UnifiedSleepSession: Sendable, Equatable {
    let startDate: Date
    let endDate: Date
    let totalAsleepSeconds: TimeInterval
    let stages: [SleepStageData]
    let chosenSourceName: String
    let chosenSourceBundleID: String

    nonisolated var totalAsleepHours: Double { totalAsleepSeconds / 3600.0 }
    nonisolated var isEmpty: Bool { totalAsleepSeconds < 60 }

    nonisolated static func makeEmpty() -> UnifiedSleepSession {
        UnifiedSleepSession(
            startDate: .distantPast,
            endDate: .distantPast,
            totalAsleepSeconds: 0,
            stages: [],
            chosenSourceName: "",
            chosenSourceBundleID: ""
        )
    }
}

// MARK: - Provider (single source of truth for sleep data)

/// Apple Health "Time Asleep" algorithm:
/// 1. Query sleep window: 6 PM previous day → now (includes naps)
/// 2. Pick best source: Apple Watch > iPhone > third-party
/// 3. Detect session boundaries (gap > 1 hour between samples = new session)
/// 4. Per session: Time Asleep = envelope - awake duration
/// 5. Total = sum across all sessions (main sleep + naps)
actor SleepSessionProvider {
    static let shared = SleepSessionProvider()

    private let healthStore = HKHealthStore()
    private var cache: (session: UnifiedSleepSession, capturedAt: Date)?
    private let cacheLifetime: TimeInterval = 120

    private init() {}

    
    // MARK: - Public API

    func lastNightSession(forceRefresh: Bool = false) async -> UnifiedSleepSession {
        if !forceRefresh,
           let cached = cache,
           Date().timeIntervalSince(cached.capturedAt) < cacheLifetime {
            return cached.session
        }

        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return .makeEmpty()
        }

        let (windowStart, windowEnd) = Self.sleepWindow(referenceDate: Date())

        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart,
            end: windowEnd,
            options: []
        )

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(query)
        }

        let session = Self.buildSessionAppleWay(
            from: samples,
            windowStart: windowStart,
            windowEnd: windowEnd
        )
        cache = (session, Date())

        #if DEBUG
        print("🛌 AiQo Sleep Session updated")
        #endif

        return session
    }

    func invalidateCache() {
        cache = nil
    }

    // MARK: - Sleep window: 6 PM previous day → now (includes naps)

    nonisolated static func sleepWindow(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> (Date, Date) {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        // 6 PM previous day — captures late-night sleepers
        let windowStart = calendar.date(byAdding: .hour, value: -6, to: startOfToday)
            ?? startOfToday.addingTimeInterval(-21_600)
        // End at current time — includes afternoon naps (matches Apple Health's "today" chart)
        let windowEnd = referenceDate
        return (windowStart, windowEnd)
    }

    // MARK: - Multi-session envelope-minus-awake algorithm

    nonisolated static func buildSessionAppleWay(
        from samples: [HKCategorySample],
        windowStart: Date,
        windowEnd: Date
    ) -> UnifiedSleepSession {
        guard !samples.isEmpty else { return .makeEmpty() }

        let asleepValues = asleepRawValues
        let awakeValue = HKCategoryValueSleepAnalysis.awake.rawValue
        let inBedValue = HKCategoryValueSleepAnalysis.inBed.rawValue

        // --- Source selection ---
        let grouped = Dictionary(grouping: samples) {
            $0.sourceRevision.source.bundleIdentifier
        }

        let scored: [(bundleID: String,
                       samples: [HKCategorySample],
                       trackedDuration: TimeInterval,
                       priority: Int,
                       sourceName: String)] = grouped.map { bundleID, srcSamples in
            let tracked = srcSamples
                .filter { asleepValues.contains($0.value) || $0.value == awakeValue }
                .reduce(0.0) { acc, s in
                    acc + s.endDate.timeIntervalSince(s.startDate)
                }
            let name = srcSamples.first?.sourceRevision.source.name ?? bundleID
            return (bundleID, srcSamples, tracked, sourcePriority(bundleID), name)
        }

        guard let winner = scored
            .filter({ $0.trackedDuration > 0 })
            .sorted(by: { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.trackedDuration > rhs.trackedDuration
            })
            .first
        else {
            return .makeEmpty()
        }

        // --- Clamp relevant samples to window, sorted by start ---
        let relevant: [(start: Date, end: Date, value: Int)] = winner.samples
            .filter { asleepValues.contains($0.value) || $0.value == awakeValue || $0.value == inBedValue }
            .compactMap {
                let s = max($0.startDate, windowStart)
                let e = min($0.endDate, windowEnd)
                guard s < e else { return nil }
                return (s, e, $0.value)
            }
            .sorted { $0.start < $1.start }

        guard !relevant.isEmpty else { return .makeEmpty() }

        // --- Detect session boundaries (gap > 1 hour = new session) ---
        let sessionBreakThreshold: TimeInterval = 60 * 60

        var sessions: [[(start: Date, end: Date, value: Int)]] = []
        var currentSession: [(start: Date, end: Date, value: Int)] = [relevant[0]]
        var currentSessionEnd = relevant[0].end

        for i in 1..<relevant.count {
            let sample = relevant[i]
            let gap = sample.start.timeIntervalSince(currentSessionEnd)

            if gap > sessionBreakThreshold {
                sessions.append(currentSession)
                currentSession = [sample]
                currentSessionEnd = sample.end
            } else {
                currentSession.append(sample)
                currentSessionEnd = max(currentSessionEnd, sample.end)
            }
        }
        sessions.append(currentSession)

        // --- Per-session: envelope minus awake, then sum ---
        var totalTimeAsleep: TimeInterval = 0
        var overallStart: Date?
        var overallEnd: Date?

        for session in sessions {
            guard let sStart = session.map(\.start).min(),
                  let sEnd = session.map(\.end).max() else { continue }

            let hasAsleep = session.contains { asleepValues.contains($0.value) }
            guard hasAsleep else { continue }

            let sessionEnvelope = sEnd.timeIntervalSince(sStart)
            let awakeIntervals = session
                .filter { $0.value == awakeValue }
                .map { (start: $0.start, end: $0.end) }
            let awakeInSession = unionDuration(of: awakeIntervals)
            let sessionAsleep = max(0, sessionEnvelope - awakeInSession)

            totalTimeAsleep += sessionAsleep

            if overallStart == nil || sStart < overallStart! { overallStart = sStart }
            if overallEnd == nil || sEnd > overallEnd! { overallEnd = sEnd }
        }

        guard let finalStart = overallStart, let finalEnd = overallEnd, totalTimeAsleep > 0 else {
            return .makeEmpty()
        }

        // --- Build stage array for UI (unchanged) ---
        let stages: [SleepStageData] = winner.samples.compactMap { sample in
            guard let stage = stageFromHKValue(sample.value) else { return nil }
            let start = max(sample.startDate, windowStart)
            let end = min(sample.endDate, windowEnd)
            guard start < end else { return nil }
            return SleepStageData(stage: stage, startDate: start, endDate: end)
        }.sorted { $0.startDate < $1.startDate }

        #if DEBUG
        print("🛌 Sleep session candidates processed")
        #endif

        return UnifiedSleepSession(
            startDate: finalStart,
            endDate: finalEnd,
            totalAsleepSeconds: totalTimeAsleep,
            stages: stages,
            chosenSourceName: winner.sourceName,
            chosenSourceBundleID: winner.bundleID
        )
    }

    // MARK: - Interval Union

    nonisolated static func unionDuration(of intervals: [(start: Date, end: Date)]) -> TimeInterval {
        guard !intervals.isEmpty else { return 0 }
        let sorted = intervals.sorted { $0.start < $1.start }
        var total: TimeInterval = 0
        var currentStart = sorted[0].start
        var currentEnd = sorted[0].end

        for i in 1..<sorted.count {
            let next = sorted[i]
            if next.start <= currentEnd {
                currentEnd = max(currentEnd, next.end)
            } else {
                total += currentEnd.timeIntervalSince(currentStart)
                currentStart = next.start
                currentEnd = next.end
            }
        }
        total += currentEnd.timeIntervalSince(currentStart)
        return total
    }

    // MARK: - Source Priority

    private nonisolated static func sourcePriority(_ bundleID: String) -> Int {
        if bundleID.contains("com.apple.health") { return 100 }
        if bundleID.contains("com.apple.shortcuts") { return 90 }
        if bundleID.hasPrefix("com.apple.") { return 80 }
        return 10
    }

    // MARK: - Asleep Raw Values

    private nonisolated static var asleepRawValues: Set<Int> {
        if #available(iOS 16.0, *) {
            return [
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
            ]
        } else {
            return [HKCategoryValueSleepAnalysis.asleep.rawValue]
        }
    }

    // MARK: - Stage Mapping

    private nonisolated static func stageFromHKValue(_ rawValue: Int) -> SleepStageData.Stage? {
        if #available(iOS 16.0, *) {
            switch HKCategoryValueSleepAnalysis(rawValue: rawValue) {
            case .asleepCore?: return .core
            case .asleepDeep?: return .deep
            case .asleepREM?: return .rem
            case .asleepUnspecified?: return .core
            case .awake?: return .awake
            default: return nil
            }
        } else {
            switch HKCategoryValueSleepAnalysis(rawValue: rawValue) {
            case .awake?: return .awake
            case .asleep?: return .core
            default: return nil
            }
        }
    }
}
