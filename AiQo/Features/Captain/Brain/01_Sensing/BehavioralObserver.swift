import Foundation

/// Observes user behavioral signals (app opens, chat sessions, workouts, sleep, notifications)
/// and periodically mines them into `ProceduralPattern` nominations.
///
/// Not a store — it reads buffered events plus recent episodic history,
/// and writes nominations through `ProceduralStore.upsert(...)`.
actor BehavioralObserver {
    static let shared = BehavioralObserver()

    enum Event: Sendable {
        case appOpened
        case captainChatStarted
        case captainChatEnded(durationSeconds: Int)
        case workoutStarted(kind: String)
        case workoutEnded(kind: String, durationMinutes: Int)
        case sleepRecorded(hours: Double)
        case notificationOpened(kind: String)
        case notificationDismissed(kind: String)
    }

    private struct TimedEvent: Sendable {
        let event: Event
        let timestamp: Date
    }

    private var recentEvents: [TimedEvent] = []
    private let maxEventBuffer: Int

    init(maxEventBuffer: Int = 500) {
        self.maxEventBuffer = maxEventBuffer
    }

    /// Append a new event to the in-memory buffer. Drops oldest when capacity is exceeded.
    func record(_ event: Event) {
        recentEvents.append(TimedEvent(event: event, timestamp: Date()))
        if recentEvents.count > maxEventBuffer {
            recentEvents.removeFirst(recentEvents.count - maxEventBuffer)
        }
    }

    /// Pattern-mining entry point for the nightly BGTask.
    /// Returns the number of patterns nominated to `ProceduralStore`.
    @discardableResult
    func mineAndNominate() async -> Int {
        let tier = TierGate.shared.currentTier
        let windowDays = TierGate.shared.patternMiningWindowDays
        guard windowDays > 0 else {
            diag.info("BehavioralObserver: tier=\(tier) has zero mining window — skipping")
            return 0
        }

        diag.info("BehavioralObserver: mining window=\(windowDays)d tier=\(tier) events=\(recentEvents.count)")
        var nominated = 0

        if let description = analyzeWorkoutTiming() {
            _ = await ProceduralStore.shared.upsert(
                kind: .workoutTime,
                description: description,
                observation: PatternObservation(timestamp: Date())
            )
            nominated += 1
        }

        if let description = analyzeSleepSchedule() {
            _ = await ProceduralStore.shared.upsert(
                kind: .sleepSchedule,
                description: description,
                observation: PatternObservation(timestamp: Date())
            )
            nominated += 1
        }

        if let description = analyzeDisengagementCycle() {
            _ = await ProceduralStore.shared.upsert(
                kind: .disengagementCycle,
                description: description,
                observation: PatternObservation(timestamp: Date())
            )
            nominated += 1
        }

        diag.info("BehavioralObserver: nominated \(nominated) patterns")
        return nominated
    }

    /// Exposes the current in-memory event count for ContextSensor aggregation.
    func bufferedEventCount() -> Int { recentEvents.count }

    // MARK: - Pattern Analysis (heuristic)

    private func analyzeWorkoutTiming() -> String? {
        let workoutStarts = recentEvents.compactMap { timed -> Date? in
            if case .workoutStarted = timed.event { return timed.timestamp }
            return nil
        }
        guard workoutStarts.count >= 3 else { return nil }
        let hours = workoutStarts.map { Calendar.current.component(.hour, from: $0) }
        let avgHour = hours.reduce(0, +) / hours.count
        return "يتمرّن غالباً حوالي الساعة \(avgHour) — \(workoutStarts.count) مرات مؤخراً"
    }

    private func analyzeSleepSchedule() -> String? {
        let sleepHours = recentEvents.compactMap { timed -> Double? in
            if case .sleepRecorded(let hours) = timed.event { return hours }
            return nil
        }
        guard sleepHours.count >= 3 else { return nil }
        let avg = sleepHours.reduce(0, +) / Double(sleepHours.count)
        return "متوسط النوم \(String(format: "%.1f", avg)) ساعة على \(sleepHours.count) ليالي"
    }

    private func analyzeDisengagementCycle() -> String? {
        let opens = recentEvents.compactMap { timed -> Date? in
            if case .appOpened = timed.event { return timed.timestamp }
            return nil
        }
        guard opens.count >= 5 else { return nil }

        var longGaps = 0
        for index in 1..<opens.count {
            let gap = opens[index].timeIntervalSince(opens[index - 1])
            if gap > 3 * 86400 { longGaps += 1 }
        }
        guard longGaps > 0 else { return nil }
        return "ميل للانقطاع \(longGaps) مرات لأكثر من 3 أيام خلال الفترة الأخيرة"
    }
}
