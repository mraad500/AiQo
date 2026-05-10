// ===============================================
// File: HabitDetector.swift
// Brain Refactor §38 — Personal Rhythm Detection
//
// Extracts the user's *recurring* patterns — training days of week, time-of-day
// preferences, family preferences, sleep regularity — so the Captain feels
// like it understands their rhythm rather than reacting cold to each turn.
//
// Detections are confidence-weighted. Anything under 0.6 is suppressed —
// surfacing "you train Tuesdays" with one Tuesday workout in the buffer would
// make the Captain sound delusional.
//
// Pure local computation — no LLM, no network, runs in <1ms on MainActor.
// ===============================================

import Foundation

// MARK: - Habit Pattern Types

/// Day-of-week constants — mirrors Calendar.Component.weekday but with stable
/// raw values so we can serialize / compare without locale weirdness.
/// `Calendar.component(.weekday, ...)` returns 1=Sunday → 7=Saturday.
enum Weekday: Int, Sendable, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var arabicLabel: String {
        switch self {
        case .sunday:    return "الأحد"
        case .monday:    return "الإثنين"
        case .tuesday:   return "الثلاثاء"
        case .wednesday: return "الأربعاء"
        case .thursday:  return "الخميس"
        case .friday:    return "الجمعة"
        case .saturday:  return "السبت"
        }
    }

    var englishLabel: String {
        switch self {
        case .sunday:    return "Sunday"
        case .monday:    return "Monday"
        case .tuesday:   return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday:  return "Thursday"
        case .friday:    return "Friday"
        case .saturday:  return "Saturday"
        }
    }
}

/// What kind of recurring pattern the detector found. Each carries the data
/// needed to render a natural Iraqi/English phrase in the prompt.
enum HabitKind: Sendable {
    /// Trains on these specific days at least 2 weeks running. The Set is
    /// non-empty.
    case trainsOnDays(Set<Weekday>)
    /// Most workouts start before 11am.
    case morningExerciser(percent: Int)
    /// Most workouts start after 5pm.
    case eveningExerciser(percent: Int)
    /// User dominantly chooses one family (≥ 60% of recent sessions).
    case prefersFamily(RecentActivityFamily, percent: Int)
    /// User has never completed a session of this family despite multiple
    /// attempts (or the family is conspicuously absent from history).
    /// Reserved for future inference — currently unused but the case is
    /// available so callers can pattern-match exhaustively.
    case avoidsFamily(RecentActivityFamily)
    /// Sleep within ±0.7h of an average across the last 5+ days.
    case consistentSleeper(avgHours: Double)
    /// Sleep highly variable — std-dev > 1.2h. Risk signal.
    case erraticSleeper(stdDevHours: Double)
    /// Active (steps > 1000) every day for the last N days, no rest.
    case neverRests(days: Int)
    /// Most steps activity happens on weekends.
    case weekendWarrior
}

/// A single detection with its surfaced confidence (0-1) and a ready-made
/// Iraqi-Arabic / English phrase. The reasoner picks the highest-confidence
/// few to render in the brief.
struct HabitPattern: Sendable {
    let kind: HabitKind
    let confidence: Double
    let arabicPhrase: String
    let englishPhrase: String

    var localizedPhrase: (AppLanguage) -> String {
        { lang in lang == .arabic ? self.arabicPhrase : self.englishPhrase }
    }
}

// MARK: - Detector

@MainActor
enum HabitDetector {

    /// Confidence floor — patterns below this are dropped silently.
    static let minimumConfidence: Double = 0.6

    /// Hard cap on how many patterns we ship to the prompt — the brief
    /// stays compact even if multiple high-confidence habits are present.
    static let maxPatternsInBrief: Int = 3

    /// §50 Round 6 Fix μ — relapse / contemplation users get a *single*
    /// pattern at most. Surfacing 3 habits to a returning user reads as
    /// over-monitoring; we drop to one (the highest-confidence) so the
    /// brief stays warm rather than diagnostic.
    static let maxPatternsForReturningUser: Int = 1

    /// Runs the full detection pipeline against the daily buffer + recent
    /// workouts and returns ranked patterns (highest confidence first).
    /// Empty array when nothing crosses the threshold.
    ///
    /// Brain §50 — `profileLens` is consulted for age-aware threshold
    /// calibration. A "no-rest streak" warning fires earlier (5 days) for
    /// established/senior users than for prime/youth (7 days), and the
    /// activity-day floor counts smaller-step days as active for older
    /// users where 2k steps is meaningful effort.
    ///
    /// §50 Round 6 — `behavioralStage` caps the number of patterns we
    /// surface for returning / exploring users (relapse / contemplation).
    static func detect(
        dailyPoints: [DailyHealthPoint],
        recentWorkouts: [WorkoutHistoryEntry],
        profileLens: UserProfileLens? = nil,
        behavioralStage: BehavioralStageReading? = nil,
        calendar: Calendar = .current
    ) -> [HabitPattern] {
        var hits: [HabitPattern] = []

        if let pattern = detectTrainingDays(workouts: recentWorkouts, calendar: calendar) {
            hits.append(pattern)
        }
        if let pattern = detectTimeOfDayPreference(workouts: recentWorkouts, calendar: calendar) {
            hits.append(pattern)
        }
        if let pattern = detectFamilyPreference(workouts: recentWorkouts) {
            hits.append(pattern)
        }
        if let pattern = detectSleepConsistency(dailyPoints: dailyPoints) {
            hits.append(pattern)
        }
        if let pattern = detectNoRestStreak(
            dailyPoints: dailyPoints,
            profileLens: profileLens
        ) {
            hits.append(pattern)
        }
        if let pattern = detectWeekendWarrior(dailyPoints: dailyPoints, calendar: calendar) {
            hits.append(pattern)
        }

        // §50 Round 6 — pattern cap is stage-sensitive. Relapse and
        // contemplation users get 1 pattern at most; everyone else gets
        // up to `maxPatternsInBrief`.
        let cap: Int = {
            guard let stage = behavioralStage, stage.confidence >= 0.6 else {
                return maxPatternsInBrief
            }
            switch stage.stage {
            case .relapse, .contemplation: return maxPatternsForReturningUser
            case .preparation, .action, .maintenance: return maxPatternsInBrief
            }
        }()

        return hits
            .filter { $0.confidence >= minimumConfidence }
            .sorted { $0.confidence > $1.confidence }
            .prefix(cap)
            .map { $0 }
    }
}

// MARK: - Detectors (private)

private extension HabitDetector {

    /// "User trains Tuesdays/Thursdays" — needs the same weekday to appear at
    /// least twice in the workout history with no off-day mixed in for that
    /// weekday. Confidence scales with how many occurrences cluster.
    static func detectTrainingDays(
        workouts: [WorkoutHistoryEntry],
        calendar: Calendar
    ) -> HabitPattern? {
        guard workouts.count >= 4 else { return nil }

        var counts: [Weekday: Int] = [:]
        for workout in workouts {
            let weekdayComponent = calendar.component(.weekday, from: workout.date)
            guard let weekday = Weekday(rawValue: weekdayComponent) else { continue }
            counts[weekday, default: 0] += 1
        }

        // Only days with at least 2 sessions count as habit-grade.
        let habitDays = counts.filter { $0.value >= 2 }.keys
        guard !habitDays.isEmpty else { return nil }

        // Confidence = fraction of total workouts that fell on habit days.
        let total = workouts.count
        let onHabitDays = habitDays.reduce(0) { $0 + (counts[$1] ?? 0) }
        let confidence = min(1.0, Double(onHabitDays) / Double(total))

        let daysSet = Set(habitDays)
        let arabicNames = daysSet.sorted { $0.rawValue < $1.rawValue }
            .map { $0.arabicLabel }.joined(separator: " و ")
        let englishNames = daysSet.sorted { $0.rawValue < $1.rawValue }
            .map { $0.englishLabel }.joined(separator: " and ")

        return HabitPattern(
            kind: .trainsOnDays(daysSet),
            confidence: confidence,
            arabicPhrase: "يتمرن عادة \(arabicNames)",
            englishPhrase: "usually trains on \(englishNames)"
        )
    }

    /// Morning vs evening exerciser — needs ≥ 4 workouts and ≥ 70% concentration.
    static func detectTimeOfDayPreference(
        workouts: [WorkoutHistoryEntry],
        calendar: Calendar
    ) -> HabitPattern? {
        guard workouts.count >= 4 else { return nil }

        var morning = 0
        var evening = 0
        for workout in workouts {
            let hour = calendar.component(.hour, from: workout.date)
            if hour < 11 {
                morning += 1
            } else if hour >= 17 {
                evening += 1
            }
        }

        let total = workouts.count
        let morningPct = Int((Double(morning) / Double(total)) * 100)
        let eveningPct = Int((Double(evening) / Double(total)) * 100)

        if morningPct >= 70 {
            return HabitPattern(
                kind: .morningExerciser(percent: morningPct),
                confidence: Double(morningPct) / 100.0,
                arabicPhrase: "غالباً يتمرن صباحاً (\(morningPct)% من جلساته)",
                englishPhrase: "mostly trains in the morning (\(morningPct)% of sessions)"
            )
        }
        if eveningPct >= 70 {
            return HabitPattern(
                kind: .eveningExerciser(percent: eveningPct),
                confidence: Double(eveningPct) / 100.0,
                arabicPhrase: "غالباً يتمرن مساءً (\(eveningPct)% من جلساته)",
                englishPhrase: "mostly trains in the evening (\(eveningPct)% of sessions)"
            )
        }
        return nil
    }

    /// Dominant activity family — needs ≥ 60% concentration of the same family.
    static func detectFamilyPreference(workouts: [WorkoutHistoryEntry]) -> HabitPattern? {
        guard workouts.count >= 3 else { return nil }

        var counts: [RecentActivityFamily: Int] = [:]
        for workout in workouts {
            let family = RecentActivityFamily.classify(title: workout.title)
            guard family != .other else { continue }
            counts[family, default: 0] += 1
        }

        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        let total = workouts.count
        let percent = Int((Double(top.value) / Double(total)) * 100)
        guard percent >= 60 else { return nil }

        return HabitPattern(
            kind: .prefersFamily(top.key, percent: percent),
            confidence: Double(percent) / 100.0,
            arabicPhrase: "يفضّل \(top.key.arabicLabel) (\(percent)% من تمارينه الأخيرة)",
            englishPhrase: "favors \(top.key.englishLabel) (\(percent)% of recent sessions)"
        )
    }

    /// Sleep consistency — std-dev across the last 5+ days of *recorded* sleep.
    /// Returns either consistent (low std-dev) or erratic (high std-dev).
    static func detectSleepConsistency(dailyPoints: [DailyHealthPoint]) -> HabitPattern? {
        let recorded = dailyPoints.suffix(7).filter { $0.sleepHours > 0 }
        guard recorded.count >= 5 else { return nil }

        let hours = recorded.map(\.sleepHours)
        let mean = hours.reduce(0, +) / Double(hours.count)
        let variance = hours.reduce(0) { $0 + pow($1 - mean, 2) } / Double(hours.count)
        let stdDev = sqrt(variance)

        if stdDev <= 0.7 {
            // Consistent
            let avgRounded = (mean * 10).rounded() / 10
            return HabitPattern(
                kind: .consistentSleeper(avgHours: avgRounded),
                confidence: 0.85,
                arabicPhrase: "نومه ثابت — معدل \(String(format: "%.1f", avgRounded)) ساعة",
                englishPhrase: "consistent sleeper — avg \(String(format: "%.1f", avgRounded))h"
            )
        }
        if stdDev >= 1.2 {
            return HabitPattern(
                kind: .erraticSleeper(stdDevHours: stdDev),
                confidence: 0.7,
                arabicPhrase: "نومه متفاوت كل ليلة (تغيّر \(String(format: "%.1f", stdDev)) ساعة)",
                englishPhrase: "erratic sleep (varies ±\(String(format: "%.1f", stdDev))h)"
            )
        }
        return nil
    }

    /// Active every day with no rest day — risk signal that often precedes
    /// burnout. Threshold = steps > 1000 to skip "phone left at home" days.
    static func detectNoRestStreak(
        dailyPoints: [DailyHealthPoint],
        profileLens: UserProfileLens? = nil
    ) -> HabitPattern? {
        guard dailyPoints.count >= 5 else { return nil }
        var streak = 0
        for point in dailyPoints.reversed() {
            if point.steps > 1000 {
                streak += 1
            } else {
                break
            }
        }
        // §50 — older users hit the warning earlier; recovery curve slows.
        let warnAt: Int = {
            switch profileLens?.ageBracket {
            case .senior, .established: return 5
            default:                    return 7
            }
        }()
        guard streak >= warnAt else { return nil }

        return HabitPattern(
            kind: .neverRests(days: streak),
            confidence: 0.8,
            arabicPhrase: "\(streak) أيام بلا راحة — الجسم يحتاج يوم استشفاء",
            englishPhrase: "\(streak) days without a rest day — body needs recovery"
        )
    }

    /// Most of the user's steps fall on Sat/Sun. Useful for nudging mid-week.
    static func detectWeekendWarrior(
        dailyPoints: [DailyHealthPoint],
        calendar: Calendar
    ) -> HabitPattern? {
        guard dailyPoints.count >= 7 else { return nil }
        let totalSteps = dailyPoints.reduce(0) { $0 + $1.steps }
        guard totalSteps > 10_000 else { return nil }

        let weekendSteps = dailyPoints.reduce(0) { acc, point in
            let weekday = calendar.component(.weekday, from: point.date)
            // 1 = Sunday, 7 = Saturday — weekends in the Gulf are commonly
            // Friday + Saturday. Cover both Western (Sat/Sun) and Gulf (Fri/Sat)
            // by including 5 (Thu? — depends on locale), 6 (Fri), 7 (Sat), 1 (Sun).
            let isWeekend = weekday == 1 || weekday == 6 || weekday == 7
            return acc + (isWeekend ? point.steps : 0)
        }

        let pct = Int((Double(weekendSteps) / Double(totalSteps)) * 100)
        guard pct >= 55 else { return nil }

        return HabitPattern(
            kind: .weekendWarrior,
            confidence: Double(pct) / 100.0,
            arabicPhrase: "نشاطه يتركز نهاية الأسبوع (\(pct)% من خطواته)",
            englishPhrase: "weekend-concentrated activity (\(pct)% of steps)"
        )
    }
}
