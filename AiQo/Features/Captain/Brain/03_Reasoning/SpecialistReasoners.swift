// ===============================================
// File: SpecialistReasoners.swift
// Brain Refactor §47 — Domain-Specialist Sub-reasoners
//
// The general CognitiveReasoner produces a strong brief for any turn, but
// when the user's intent is *specifically* about workout planning, nutrition,
// or sleep, world-class coaching demands deeper domain logic — load
// management, macro alignment, sleep-stage targeting. This file establishes
// the specialist pattern (one type taxonomy + one workout specialist as the
// flagship implementation) and lets us add Nutrition/Sleep specialists later
// without re-architecting.
//
// The specialist activates only when intent matches its domain. Its output
// supplements the main brief — never replaces it. The model gets *both*
// the general reasoning brief AND the specialist's structured output, so
// the existing safety nets (avoid-list, coherence, persona) still apply.
// ===============================================

import Foundation

// MARK: - Domain Taxonomy

/// One of the three domains where deeper specialist logic earns its tokens.
enum SpecialistDomain: String, Sendable {
    case workout
    case nutrition
    case sleep
}

/// Intensity bucket the specialist recommends for the *next* session. The
/// model lands one of these and the prompt layer renders it with concrete
/// duration + family constraints.
enum SpecialistIntensity: String, Sendable {
    case rest         // active recovery only
    case light        // zone-1 walking, mobility
    case moderate     // zone-2, base building
    case hard         // threshold work, heavy strength
    case maximal      // peaking sessions only

    var arabicLabel: String {
        switch self {
        case .rest:     return "راحة نشطة"
        case .light:    return "خفيف"
        case .moderate: return "متوسط"
        case .hard:     return "قوي"
        case .maximal:  return "ذروة"
        }
    }

    var englishLabel: String {
        switch self {
        case .rest:     return "active rest"
        case .light:    return "light"
        case .moderate: return "moderate"
        case .hard:     return "hard"
        case .maximal:  return "max"
        }
    }
}

/// Structured workout guidance the specialist produces. The prompt layer
/// renders this so the model has concrete targets instead of vibes.
struct WorkoutGuidance: Sendable {
    /// Activity family the specialist recommends *as the primary focus*.
    /// Captain may suggest the user pick a different one — but if they do,
    /// they should explain why this one was the data-driven recommendation.
    let recommendedFamily: RecentActivityFamily
    let intensity: SpecialistIntensity
    /// Acceptable duration window in minutes (clamped at 5–120).
    let durationMinutesRange: ClosedRange<Int>
    /// Other families the specialist is steering *away* from due to load,
    /// recovery, or recency. Distinct from the coherence avoid-list.
    let cautionFamilies: [RecentActivityFamily]
    /// One-sentence Iraqi-Arabic justification + English mirror. The model
    /// can paraphrase but must convey the substance.
    let reasoningArabic: String
    let reasoningEnglish: String
}

/// Sum-type the brief carries — Phase 12 ships only `.workout`; the other
/// two cases reserve their slot in the type system so adding them is a
/// non-breaking change.
enum SpecialistGuidance: Sendable {
    case workout(WorkoutGuidance)
    // Reserved for future phases:
    // case nutrition(NutritionGuidance)
    // case sleep(SleepGuidance)
}

// MARK: - Workout Specialist

/// Activates when the user is asking for a workout / training plan. Reads
/// recent training load, sleep, RHR, and recommends the next session with
/// load-management + recovery-aware logic the general reasoner doesn't do.
@MainActor
enum WorkoutSpecialistReasoner {

    /// Returns nil unless the latest user turn is workout-intent. Caller
    /// should still respect the general brief in parallel.
    ///
    /// Brain §50 (Round 2 Fix B) — `briefAngle` lets the angle picker
    /// constrain the specialist's intensity. When the reasoner has decided
    /// the angle is `.gentle` / `.grounding` / `.repair` (recovery /
    /// stress / apology), the specialist must NOT recommend hard / maximal
    /// intensity even if its own load signals would otherwise allow it.
    /// Conflict resolution: the brief angle is upstream authority.
    static func recommend(
        intent: CaptainMessageIntent,
        recentActivity: RecentActivitySnapshot?,
        recentWorkouts: [WorkoutHistoryEntry],
        sleepHoursLastNight: Double,
        restingHeartRate: Int?,
        profileLens: UserProfileLens?,
        coherence: ConversationContextTags?,
        hour: Int,
        briefAngle: ReasoningAngle? = nil,
        calendar: Calendar = .current
    ) -> WorkoutGuidance? {
        guard intent == .workout else { return nil }

        // Compute load signals. The specialist refuses to recommend "hard"
        // when any of the recovery flags are tripped.
        let signals = computeLoadSignals(
            recentActivity: recentActivity,
            recentWorkouts: recentWorkouts,
            sleepHoursLastNight: sleepHoursLastNight,
            restingHeartRate: restingHeartRate,
            profileLens: profileLens,
            calendar: calendar
        )

        // 1) Pick intensity based on recovery readiness, then clamp by
        //    the brief's angle (§50 inter-layer authority).
        let intensity = clampIntensityToAngle(
            pickIntensity(signals: signals, profileLens: profileLens),
            briefAngle: briefAngle
        )

        // 2) Pick recommended family based on load history (avoid monotony,
        //    avoid same family two days in a row for high-impact work).
        let recommendation = pickFamily(
            intensity: intensity,
            signals: signals,
            recentWorkouts: recentWorkouts,
            profileLens: profileLens,
            coherence: coherence
        )

        // 3) Duration window scales with intensity + age bracket.
        let durationRange = durationRange(
            intensity: intensity,
            ageBracket: profileLens?.ageBracket
        )

        // 4) Caution families derive from recent saturation.
        let cautionFamilies = cautionFamilies(
            recentWorkouts: recentWorkouts,
            calendar: calendar
        )

        let reasoningArabic = composeReasoningArabic(
            intensity: intensity,
            recommendedFamily: recommendation,
            signals: signals
        )
        let reasoningEnglish = composeReasoningEnglish(
            intensity: intensity,
            recommendedFamily: recommendation,
            signals: signals
        )

        return WorkoutGuidance(
            recommendedFamily: recommendation,
            intensity: intensity,
            durationMinutesRange: durationRange,
            cautionFamilies: cautionFamilies,
            reasoningArabic: reasoningArabic,
            reasoningEnglish: reasoningEnglish
        )
    }
}

// MARK: - Load Signals

private extension WorkoutSpecialistReasoner {

    /// Bundle of binary readiness flags the intensity picker reads. Derived
    /// once so the picker doesn't re-traverse data.
    struct LoadSignals {
        let consecutiveTrainingDays: Int
        let highIntensityYesterday: Bool
        let elevatedRestingHR: Bool      // RHR elevated above baseline guess
        let lowSleep: Bool
        let veryFreshActivity: Bool      // <60 min ago — never re-train
    }

    static func computeLoadSignals(
        recentActivity: RecentActivitySnapshot?,
        recentWorkouts: [WorkoutHistoryEntry],
        sleepHoursLastNight: Double,
        restingHeartRate: Int?,
        profileLens: UserProfileLens?,
        calendar: Calendar
    ) -> LoadSignals {
        // Consecutive-training-days — count back from today.
        var streak = 0
        let today = calendar.startOfDay(for: Date())
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            let dayHasWorkout = recentWorkouts.contains { entry in
                calendar.isDate(entry.date, inSameDayAs: day)
            }
            if dayHasWorkout {
                streak += 1
            } else {
                break
            }
        }

        // High intensity yesterday — proxy = workout >= 35 min OR strength.
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let yesterdayWorkouts = recentWorkouts.filter {
            calendar.isDate($0.date, inSameDayAs: yesterdayStart)
        }
        let highIntensityYesterday = yesterdayWorkouts.contains { entry in
            let durationMinutes = entry.durationSeconds / 60
            let family = RecentActivityFamily.classify(title: entry.title)
            return durationMinutes >= 35 || family == .strength || family == .hiit
        }

        // RHR elevation — if we have a number above 70, treat as elevated.
        // We don't have a baseline here; Phase 13+ could read TrendSnapshot.
        let elevatedRestingHR = (restingHeartRate ?? 0) >= 72

        // Low sleep — uses lens-aware threshold.
        let lowSleep = sleepHoursLastNight > 0
            && sleepHoursLastNight < (profileLens?.lowSleepThresholdHours ?? 6.0)

        // Very fresh activity — under 60 min means user just finished.
        let veryFresh = recentActivity?.freshness == .veryFresh

        return LoadSignals(
            consecutiveTrainingDays: streak,
            highIntensityYesterday: highIntensityYesterday,
            elevatedRestingHR: elevatedRestingHR,
            lowSleep: lowSleep,
            veryFreshActivity: veryFresh
        )
    }
}

// MARK: - Intensity Picker

private extension WorkoutSpecialistReasoner {

    /// §50 — caps the specialist's chosen intensity at whatever the brief's
    /// angle allows. The angle picker has already considered HR mood,
    /// behavioural stage, sleep streak, and other cross-layer signals; the
    /// specialist must not contradict that resolution. Idempotent for
    /// non-restrictive angles.
    static func clampIntensityToAngle(
        _ intensity: SpecialistIntensity,
        briefAngle: ReasoningAngle?
    ) -> SpecialistIntensity {
        switch briefAngle {
        case .repair, .grounding:
            // User-protection angles — the body / mind needs space.
            // Cap at light regardless of signals.
            return [.rest, .light].contains(intensity) ? intensity : .light
        case .gentle:
            // §50 Round 5 Fix θ — softer downgrade. The previous version
            // collapsed hard/maximal straight to light, which over-clamped
            // motivated users with capacity for moderate work. The chain
            // is now: maximal → moderate (one step), hard → moderate
            // (also one step), and we leave moderate / light / rest alone.
            // For users on a real recovery curve, the load signals inside
            // `pickIntensity` already pre-empt anything above moderate.
            switch intensity {
            case .hard, .maximal: return .moderate
            default:              return intensity
            }
        case .recovery:
            // Already covered by the LoadSignals.veryFreshActivity check
            // (returns .rest), but defensively clamp anything above light.
            switch intensity {
            case .moderate, .hard, .maximal: return .light
            default:                          return intensity
            }
        case .celebrate, .pushForward, .factual,
             .proactiveCallout, .none:
            // No cap — specialist's choice stands.
            return intensity
        }
    }

    static func pickIntensity(
        signals: LoadSignals,
        profileLens: UserProfileLens?
    ) -> SpecialistIntensity {
        // Just-finished workout always means "rest now" — anti-double-up.
        if signals.veryFreshActivity { return .rest }

        // Two compounding recovery flags → light only.
        let recoveryFlagCount = [
            signals.elevatedRestingHR,
            signals.lowSleep,
            signals.consecutiveTrainingDays >= 5
        ].filter { $0 }.count
        if recoveryFlagCount >= 2 { return .light }

        // Single flag + high yesterday → moderate cap.
        if signals.highIntensityYesterday && recoveryFlagCount >= 1 {
            return .moderate
        }

        // Single recovery flag alone → moderate (don't push).
        if recoveryFlagCount == 1 { return .moderate }

        // High yesterday alone → moderate today.
        if signals.highIntensityYesterday { return .moderate }

        // Five+ training days even without flags → moderate (deload-ish).
        if signals.consecutiveTrainingDays >= 5 { return .moderate }

        // Default = hard for advanced users, moderate otherwise.
        if profileLens?.experience == .advanced { return .hard }
        return .moderate
    }
}

// MARK: - Family Picker

private extension WorkoutSpecialistReasoner {

    static func pickFamily(
        intensity: SpecialistIntensity,
        signals: LoadSignals,
        recentWorkouts: [WorkoutHistoryEntry],
        profileLens: UserProfileLens?,
        coherence: ConversationContextTags?
    ) -> RecentActivityFamily {
        // Rest → walking is the safe active-recovery default.
        if intensity == .rest { return .walking }

        // Avoid families on the coherence avoid-list outright.
        let avoid = Set(coherence?.familiesToAvoid ?? [])

        // Avoid the family done yesterday (rotation principle).
        let yesterdayFamily: RecentActivityFamily? = recentWorkouts.first.map {
            RecentActivityFamily.classify(title: $0.title)
        }

        // Candidate families ordered by intensity fit.
        let candidates: [RecentActivityFamily]
        switch intensity {
        case .light:
            candidates = [.walking, .yoga, .pilates, .gratitude]
        case .moderate:
            candidates = [.walking, .cycling, .swimming, .strength, .pilates, .yoga]
        case .hard:
            candidates = [.strength, .running, .cycling, .hiit, .boxing]
        case .maximal:
            candidates = [.hiit, .running, .strength]
        case .rest:
            candidates = [.walking]
        }

        for candidate in candidates {
            if avoid.contains(candidate) { continue }
            if candidate == yesterdayFamily, intensity != .light { continue }
            return candidate
        }
        // Fallback when everything is avoided — pick walking.
        return .walking
    }
}

// MARK: - Duration + Caution

private extension WorkoutSpecialistReasoner {

    static func durationRange(
        intensity: SpecialistIntensity,
        ageBracket: AgeBracket?
    ) -> ClosedRange<Int> {
        let baseRange: ClosedRange<Int>
        switch intensity {
        case .rest:     baseRange = 10...20
        case .light:    baseRange = 20...30
        case .moderate: baseRange = 30...45
        case .hard:     baseRange = 30...60
        case .maximal:  baseRange = 25...45
        }
        // Senior bracket trims hard sessions.
        if ageBracket == .senior, intensity == .hard {
            return 20...40
        }
        return baseRange
    }

    /// Families to flag as "be careful with" because they appeared in the
    /// last 48h. Helps the prompt suggest variety even when the recommended
    /// family is something else.
    static func cautionFamilies(
        recentWorkouts: [WorkoutHistoryEntry],
        calendar: Calendar
    ) -> [RecentActivityFamily] {
        let cutoff = calendar.date(byAdding: .hour, value: -48, to: Date()) ?? Date()
        var seen: Set<RecentActivityFamily> = []
        var out: [RecentActivityFamily] = []
        for entry in recentWorkouts where entry.date >= cutoff {
            let family = RecentActivityFamily.classify(title: entry.title)
            guard family != .other, seen.insert(family).inserted else { continue }
            out.append(family)
        }
        return out
    }
}

// MARK: - Reasoning Narrative

private extension WorkoutSpecialistReasoner {

    static func composeReasoningArabic(
        intensity: SpecialistIntensity,
        recommendedFamily: RecentActivityFamily,
        signals: LoadSignals
    ) -> String {
        var parts: [String] = []
        if signals.veryFreshActivity {
            parts.append("توه خلّص جلسة، الجسم يحتاج راحة")
        } else if signals.elevatedRestingHR && signals.lowSleep {
            parts.append("النبض مرتفع والنوم قليل، نحتاج جلسة استشفاء")
        } else if signals.consecutiveTrainingDays >= 5 {
            parts.append("\(signals.consecutiveTrainingDays) أيام تمرين متواصل، يجي وقت deload")
        } else if signals.highIntensityYesterday {
            parts.append("أمس كان قوي، اليوم نتوسط الشدة")
        } else {
            parts.append("الإشارات زينة، نشتغل بشدة \(intensity.arabicLabel)")
        }
        parts.append("اقترح \(recommendedFamily.arabicLabel) كخيار رئيسي")
        return parts.joined(separator: "؛ ")
    }

    static func composeReasoningEnglish(
        intensity: SpecialistIntensity,
        recommendedFamily: RecentActivityFamily,
        signals: LoadSignals
    ) -> String {
        var parts: [String] = []
        if signals.veryFreshActivity {
            parts.append("Just finished a session, body needs recovery")
        } else if signals.elevatedRestingHR && signals.lowSleep {
            parts.append("Elevated RHR + low sleep — recovery session warranted")
        } else if signals.consecutiveTrainingDays >= 5 {
            parts.append("\(signals.consecutiveTrainingDays) consecutive training days — deload territory")
        } else if signals.highIntensityYesterday {
            parts.append("Yesterday was high — today moderates")
        } else {
            parts.append("Signals are green — \(intensity.englishLabel) intensity")
        }
        parts.append("recommend \(recommendedFamily.englishLabel) as primary")
        return parts.joined(separator: "; ")
    }
}
