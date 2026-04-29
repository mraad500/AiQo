import Foundation

/// Pure, deterministic hydration logic. No side effects, no I/O.
/// Computes expected intake by the current time of day and classifies pace.
enum HydrationEvaluator {

    /// Fraction of the wake window elapsed at `now`.
    /// Returns 0 before the window starts, 1 after it ends.
    static func wakeWindowProgress(
        now: Date,
        settings: HydrationSettings,
        calendar: Calendar = .current
    ) -> Double {
        let startOfDay = calendar.startOfDay(for: now)
        guard
            let wakeStart = calendar.date(
                byAdding: .hour, value: settings.wakeStartHour, to: startOfDay
            ),
            let wakeEnd = calendar.date(
                byAdding: .hour, value: max(settings.wakeEndHour, settings.wakeStartHour + 1),
                to: startOfDay
            )
        else {
            return 0
        }

        if now <= wakeStart { return 0 }
        if now >= wakeEnd { return 1 }

        let total = wakeEnd.timeIntervalSince(wakeStart)
        guard total > 0 else { return 0 }
        return now.timeIntervalSince(wakeStart) / total
    }

    /// Expected intake (mL) by the given time, under a linear ramp across the wake window.
    static func expectedByNowML(
        now: Date,
        settings: HydrationSettings,
        calendar: Calendar = .current
    ) -> Double {
        let progress = wakeWindowProgress(now: now, settings: settings, calendar: calendar)
        return settings.goalML * progress
    }

    /// Classify pace by ratio of consumed / expected.
    static func paceStatus(
        consumedML: Double,
        expectedByNowML: Double
    ) -> HydrationPaceStatus {
        // Before wake window starts, expectedByNowML is 0 → treat as onTrack.
        guard expectedByNowML > 0 else { return .onTrack }

        let ratio = consumedML / expectedByNowML
        if ratio >= 1.1 { return .ahead }
        if ratio >= 0.9 { return .onTrack }
        if ratio >= 0.6 { return .behind }
        return .veryBehind
    }

    /// True when `now` falls inside the quiet window (inclusive of start, exclusive of end).
    /// Handles overnight windows (start > end).
    static func isQuietHours(
        now: Date,
        settings: HydrationSettings,
        calendar: Calendar = .current
    ) -> Bool {
        let hour = calendar.component(.hour, from: now)
        let start = settings.quietStartHour
        let end = settings.quietEndHour
        if start == end { return false }
        if start > end {
            return hour >= start || hour < end
        }
        return hour >= start && hour < end
    }

    /// True when `now` is between wake start and wake end.
    static func isInsideWakeWindow(
        now: Date,
        settings: HydrationSettings,
        calendar: Calendar = .current
    ) -> Bool {
        let hour = calendar.component(.hour, from: now)
        let start = settings.wakeStartHour
        let end = settings.wakeEndHour
        if end > start {
            return hour >= start && hour < end
        }
        // end == 24 case (end-of-day)
        return hour >= start
    }

    /// Build the full daily state snapshot (consumed, goal, pace, etc.).
    static func dailyState(
        consumedML: Double,
        lastDrinkDate: Date?,
        lastDrinkSource: HydrationSource?,
        now: Date,
        settings: HydrationSettings,
        calendar: Calendar = .current
    ) -> HydrationDailyState {
        let expected = expectedByNowML(now: now, settings: settings, calendar: calendar)
        let pace = paceStatus(consumedML: consumedML, expectedByNowML: expected)
        return HydrationDailyState(
            goalML: settings.goalML,
            consumedML: consumedML,
            expectedByNowML: expected,
            lastDrinkDate: lastDrinkDate,
            lastDrinkSource: lastDrinkSource,
            paceStatus: pace
        )
    }

    /// Decide whether to remind the user, suppress, or escalate.
    /// Honors wake window, quiet hours, recent-drink cooldown, and pace.
    static func evaluate(
        state: HydrationDailyState,
        now: Date,
        settings: HydrationSettings,
        calendar: Calendar = .current
    ) -> HydrationEvaluation {
        if !settings.smartTrackingEnabled {
            return .suppress(reason: .trackingDisabled)
        }

        let hour = calendar.component(.hour, from: now)
        let start = settings.wakeStartHour
        let end = settings.wakeEndHour
        if end > start {
            if hour < start { return .suppress(reason: .beforeWakeWindow) }
            if hour >= end { return .suppress(reason: .afterWakeWindow) }
        } else {
            if hour < start { return .suppress(reason: .beforeWakeWindow) }
        }

        if isQuietHours(now: now, settings: settings, calendar: calendar) {
            return .suppress(reason: .quietHours)
        }

        if let last = state.lastDrinkDate {
            let elapsed = now.timeIntervalSince(last) / 60.0
            if elapsed < Double(settings.cooldownMinutes) {
                return .suppress(reason: .recentDrink)
            }
        }

        switch state.paceStatus {
        case .ahead, .onTrack:
            return .suppress(reason: .paceOK)
        case .behind:
            return .remind(intensity: .gentle)
        case .veryBehind:
            return .remind(intensity: .stronger)
        }
    }
}
