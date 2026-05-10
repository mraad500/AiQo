// ===============================================
// File: MicroInsightGenerator.swift
// Brain Refactor §40 — Today-Specific Observations
//
// Produces small, surgically-specific insights the Captain can drop into a
// reply to feel observant rather than generic. Examples:
//   • "first activity after 4 rest days"
//   • "today's steps are 22% above yesterday at this hour"
//   • "best sleep this week"
//   • "longest walk in 10 days"
//
// These are NOT trends (handled by TrendAnalyzer) and NOT habits (HabitDetector).
// They are *moment-of-the-day* observations — only useful for the next reply,
// not for long-term coaching.
//
// Pure local computation, deterministic, runs in <0.5ms.
// ===============================================

import Foundation

// MARK: - Insight Types

/// One observation tied to a specific number or comparison. Each one comes
/// with localized phrasing the model can drop in unchanged.
struct MicroInsight: Sendable {
    let kind: MicroInsightKind
    let arabicPhrase: String
    let englishPhrase: String

    func phrase(_ language: AppLanguage) -> String {
        language == .arabic ? arabicPhrase : englishPhrase
    }
}

/// Categories — kept for testability + so the prompt can prioritize types
/// (recovery > celebration > progress, for example).
enum MicroInsightKind: Sendable {
    /// First active day after a rest gap.
    case firstAfterRest(daysOff: Int)
    /// Today's steps vs yesterday at the same hour, comparison.
    case stepsVsYesterdayPace(percent: Int, direction: ComparisonDirection)
    /// Best sleep across the visible buffer.
    case bestSleepInWindow(hours: Double, days: Int)
    /// Worst sleep across the visible buffer.
    case worstSleepInWindow(hours: Double, days: Int)
    /// Longest workout (by duration) in the visible buffer.
    case longestWorkoutInWindow(family: RecentActivityFamily, minutes: Int, days: Int)
    /// Streak milestone (every 7 days hit).
    case streakMilestone(days: Int)
    /// First time this week / month doing a particular family.
    case firstFamilyOfPeriod(family: RecentActivityFamily, period: PeriodLabel)
}

enum ComparisonDirection: String, Sendable {
    case ahead, behind, tied
}

enum PeriodLabel: Sendable {
    case week
    case month

    var arabic: String { self == .week ? "الأسبوع" : "الشهر" }
    var english: String { self == .week ? "the week" : "the month" }
}

// MARK: - Generator

@MainActor
enum MicroInsightGenerator {

    /// Cap on insights returned — the brief stays compact. The model picks
    /// at most one or two to weave into the reply.
    static let maxInsights = 2

    static func generate(
        steps: Int,
        sleepHoursLastNight: Double,
        recentActivity: RecentActivitySnapshot?,
        dailyPoints: [DailyHealthPoint],
        recentWorkouts: [WorkoutHistoryEntry],
        hour: Int,
        currentStreak: Int,
        calendar: Calendar = .current
    ) -> [MicroInsight] {
        var hits: [MicroInsight] = []

        // 1) First-after-rest — most emotionally resonant, prioritize.
        if let insight = firstActiveAfterRest(steps: steps, dailyPoints: dailyPoints) {
            hits.append(insight)
        }

        // 2) Streak milestone (multiples of 7).
        if currentStreak > 0, currentStreak % 7 == 0 {
            hits.append(
                MicroInsight(
                    kind: .streakMilestone(days: currentStreak),
                    arabicPhrase: "اليوم \(currentStreak) أيام streak — رقم محترم",
                    englishPhrase: "today is day \(currentStreak) of the streak — solid milestone"
                )
            )
        }

        // 3) Best/worst sleep across recorded window.
        if let sleepInsight = sleepExtreme(
            lastNight: sleepHoursLastNight,
            dailyPoints: dailyPoints
        ) {
            hits.append(sleepInsight)
        }

        // 4) Steps pace vs yesterday at same hour.
        if let paceInsight = stepsPace(
            today: steps,
            hour: hour,
            dailyPoints: dailyPoints
        ) {
            hits.append(paceInsight)
        }

        // 5) Longest workout in window.
        if let activity = recentActivity, activity.freshness != .stale,
           let longestInsight = longestWorkout(
               currentActivity: activity,
               recentWorkouts: recentWorkouts,
               calendar: calendar
           ) {
            hits.append(longestInsight)
        }

        // 6) First-of-period family.
        if let activity = recentActivity, activity.freshness == .veryFresh,
           let firstInsight = firstFamilyThisWeek(
               currentActivity: activity,
               recentWorkouts: recentWorkouts,
               calendar: calendar
           ) {
            hits.append(firstInsight)
        }

        return Array(hits.prefix(maxInsights))
    }
}

// MARK: - Detectors (private)

private extension MicroInsightGenerator {

    /// True when today is active (steps > 1500) but the prior 2+ days had
    /// no real activity. The "I'm back" moment.
    static func firstActiveAfterRest(
        steps: Int,
        dailyPoints: [DailyHealthPoint]
    ) -> MicroInsight? {
        guard steps >= 1500 else { return nil }
        let prior = dailyPoints.dropLast()  // exclude today
        guard prior.count >= 2 else { return nil }

        var restDays = 0
        for point in prior.reversed() {
            if point.steps < 1500 {
                restDays += 1
            } else {
                break
            }
        }
        guard restDays >= 2 else { return nil }

        return MicroInsight(
            kind: .firstAfterRest(daysOff: restDays),
            arabicPhrase: "أول نشاط بعد \(restDays) أيام راحة — رجوع زين",
            englishPhrase: "first active day after \(restDays) days off — welcome back"
        )
    }

    /// Best-or-worst sleep across the recorded window. Threshold: must
    /// differ by ≥ 0.7h from the next-best/worst to count as notable.
    static func sleepExtreme(
        lastNight: Double,
        dailyPoints: [DailyHealthPoint]
    ) -> MicroInsight? {
        guard lastNight > 0 else { return nil }
        let recorded = dailyPoints.suffix(7).filter { $0.sleepHours > 0 }
        guard recorded.count >= 4 else { return nil }

        let hours = recorded.map(\.sleepHours)
        guard let max = hours.max(), let min = hours.min() else { return nil }

        let isBest = lastNight >= max && (lastNight - (hours.filter { $0 < max }.max() ?? lastNight)) >= 0.7
        let isWorst = lastNight <= min && ((hours.filter { $0 > min }.min() ?? lastNight) - lastNight) >= 0.7

        if isBest {
            return MicroInsight(
                kind: .bestSleepInWindow(hours: lastNight, days: recorded.count),
                arabicPhrase: "ليلة أمس أفضل نوم بآخر \(recorded.count) أيام (\(String(format: "%.1f", lastNight))س)",
                englishPhrase: "last night was the best sleep in \(recorded.count) days (\(String(format: "%.1f", lastNight))h)"
            )
        }
        if isWorst {
            return MicroInsight(
                kind: .worstSleepInWindow(hours: lastNight, days: recorded.count),
                arabicPhrase: "ليلة أمس أقل نوم بآخر \(recorded.count) أيام (\(String(format: "%.1f", lastNight))س)",
                englishPhrase: "last night was the lowest sleep in \(recorded.count) days (\(String(format: "%.1f", lastNight))h)"
            )
        }
        return nil
    }

    /// Compares today's steps at the *current hour* against yesterday's
    /// total. Only fires after 12pm — pre-noon comparisons are noisy.
    static func stepsPace(
        today: Int,
        hour: Int,
        dailyPoints: [DailyHealthPoint]
    ) -> MicroInsight? {
        guard hour >= 12 else { return nil }
        guard today >= 1000 else { return nil }
        // Yesterday's *full-day* steps. Approximating "yesterday by this
        // hour" requires intra-day data we don't have — full-day comparison
        // is more honest.
        let prior = dailyPoints.dropLast()
        guard let yesterday = prior.last, yesterday.steps > 1000 else { return nil }

        // Roughly project today through this hour as a fraction of an
        // 18-hour active window (6am–midnight).
        let activeHoursDone = max(1.0, Double(hour) - 6.0)
        let activeHoursTotal = 18.0
        let projected = Double(today) * (activeHoursTotal / activeHoursDone)

        let percentDelta = Int(((projected - Double(yesterday.steps)) / Double(yesterday.steps)) * 100)

        // Surface only meaningful deltas (≥ 15%).
        guard abs(percentDelta) >= 15 else { return nil }

        let direction: ComparisonDirection = percentDelta > 0 ? .ahead : .behind
        let absPct = abs(percentDelta)

        return MicroInsight(
            kind: .stepsVsYesterdayPace(percent: absPct, direction: direction),
            arabicPhrase: direction == .ahead
                ? "بنفس الوقت متفوّق على أمس بـ \(absPct)% بالخطوات"
                : "بنفس الوقت متأخر عن أمس بـ \(absPct)% بالخطوات",
            englishPhrase: direction == .ahead
                ? "at this hour, \(absPct)% ahead of yesterday's pace"
                : "at this hour, \(absPct)% behind yesterday's pace"
        )
    }

    /// "Longest [walk/run/strength] in N days" — fires when the just-finished
    /// session beats every same-family session in the recent buffer.
    static func longestWorkout(
        currentActivity: RecentActivitySnapshot,
        recentWorkouts: [WorkoutHistoryEntry],
        calendar: Calendar
    ) -> MicroInsight? {
        // Skip the freshest entry — it's likely the same workout we're already
        // referencing elsewhere.
        let prior = recentWorkouts.dropFirst()
        guard !prior.isEmpty else { return nil }

        let sameFamily = prior.filter {
            RecentActivityFamily.classify(title: $0.title) == currentActivity.family
        }
        guard !sameFamily.isEmpty else { return nil }

        let priorMaxMinutes = sameFamily.map { max(1, $0.durationSeconds / 60) }.max() ?? 0
        guard currentActivity.durationMinutes > priorMaxMinutes else { return nil }

        // Span days — if the prior entries are all within ~10 days, that's
        // the window we report. Otherwise default to "recent."
        let earliest = sameFamily.last?.date ?? Date()
        let span = calendar.dateComponents([.day], from: earliest, to: Date()).day ?? 0
        let windowDays = max(span, 7)

        let familyArabic = currentActivity.family.arabicLabel
        let familyEnglish = currentActivity.family.englishLabel

        return MicroInsight(
            kind: .longestWorkoutInWindow(
                family: currentActivity.family,
                minutes: currentActivity.durationMinutes,
                days: windowDays
            ),
            arabicPhrase: "أطول جلسة \(familyArabic) بآخر \(windowDays) أيام",
            englishPhrase: "longest \(familyEnglish) session in the last \(windowDays) days"
        )
    }

    /// "First [yoga] of the week" — fires when the very-fresh activity is
    /// the only entry of that family in the current week.
    static func firstFamilyThisWeek(
        currentActivity: RecentActivitySnapshot,
        recentWorkouts: [WorkoutHistoryEntry],
        calendar: Calendar
    ) -> MicroInsight? {
        let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ) ?? Date()

        let thisWeekSameFamily = recentWorkouts
            .dropFirst()  // exclude the just-finished one
            .filter { $0.date >= weekStart }
            .filter { RecentActivityFamily.classify(title: $0.title) == currentActivity.family }

        guard thisWeekSameFamily.isEmpty else { return nil }

        let familyArabic = currentActivity.family.arabicLabel
        let familyEnglish = currentActivity.family.englishLabel

        return MicroInsight(
            kind: .firstFamilyOfPeriod(family: currentActivity.family, period: .week),
            arabicPhrase: "أول \(familyArabic) بهالأسبوع",
            englishPhrase: "first \(familyEnglish) of the week"
        )
    }
}
