// ===============================================
// File: BehavioralStageEngine.swift
// Brain Refactor §44 — Stages-of-Change Detection
//
// Implements the Transtheoretical Model (Prochaska & DiClemente, 1983) for
// behaviour change. The model is the empirical backbone of professional
// health coaching — every certified coach calibrates their tactics to the
// athlete's stage. A "what time should we train?" answer to a person who is
// ambivalent about training at all is malpractice.
//
// Five stages we detect:
//   1. Contemplation  — using the app but not yet committing to action
//   2. Preparation    — small recent activity, ready to commit, needs a plan
//   3. Action         — actively training, building consistency
//   4. Maintenance    — consistent ≥ 30 days, stage of optimization
//   5. Relapse        — was active, long gap, just coming back
//
// Each stage maps to a *radically different* coaching playbook. The stage
// reading is rendered as a one-line directive in the reasoning brief.
//
// Pure local, runs in <1ms.
// ===============================================

import Foundation

// MARK: - Stages

enum BehavioralStage: String, Sendable {
    /// User is using the app but not yet committed to behaviour change.
    /// Tactics: motivational interviewing — open questions, affirmations,
    /// reflective listening. Avoid prescribing.
    case contemplation
    /// User has shown small recent activity and is mentally ready to commit.
    /// Tactics: tiny-step commitments, scaffold a plan.
    case preparation
    /// User is actively training, building a streak, in execution mode.
    /// Tactics: accountability, intensity-management, prevent overtraining.
    case action
    /// User has 30+ days of consistency. Boredom and plateau become risks.
    /// Tactics: introduce variety, optimization, long-horizon goals.
    case maintenance
    /// User had a gap (≥ 10 days) and is now returning. Most fragile state.
    /// Tactics: no shame, welcome back, propose *smaller* than before.
    case relapse
}

struct BehavioralStageReading: Sendable {
    let stage: BehavioralStage
    /// 0–1 confidence based on signal strength. Below 0.5 the engine
    /// suppresses the directive (we'd rather stay quiet than mislabel).
    let confidence: Double

    var directiveArabic: String {
        switch stage {
        case .contemplation:
            return "المستخدم بمرحلة التأمّل (يستكشف، ما التزم بعد) — استخدم أسئلة مفتوحة، اعترف بترددّه، تجنب أوامر مباشرة"
        case .preparation:
            return "المستخدم بمرحلة التحضير (مستعد يبدي) — اقترح خطوة وحدة صغيرة جداً (≤ 10 دقايق)، اطلب منه يلتزم بيها فقط"
        case .action:
            return "المستخدم بمرحلة الفعل (يتمرن بانتظام) — كن مدرب تنفيذ، احتفل بالاستمرارية، احذره من الإفراط"
        case .maintenance:
            return "المستخدم بمرحلة الصيانة (ثبات طويل) — اعرض تنويع، تحديات أعلى، اقتراحات للحفاظ على الحماس"
        case .relapse:
            return "المستخدم برجع بعد انقطاع — لا توبيخ أبداً، رحّب بيه، اقترح أصغر من اللي كان يسوي"
        }
    }

    var directiveEnglish: String {
        switch stage {
        case .contemplation:
            return "User is in CONTEMPLATION (exploring, not committed) — use open questions, validate ambivalence, avoid prescribing"
        case .preparation:
            return "User is in PREPARATION (ready to start) — propose ONE tiny step (≤ 10 min), ask for that one commitment only"
        case .action:
            return "User is in ACTION (training consistently) — execution coach mode, celebrate consistency, watch for overtraining"
        case .maintenance:
            return "User is in MAINTENANCE (30+ days of consistency) — introduce variety, harder challenges, prevent plateau boredom"
        case .relapse:
            return "User is RETURNING from a gap — no judgment, welcome them back, suggest *smaller* than they used to do"
        }
    }
}

// MARK: - Detector

@MainActor
enum BehavioralStageDetector {

    /// Cascading detection — strongest signal wins. Returns `nil` when
    /// confidence is too low; the brief skips the stage layer rather than
    /// guess.
    static func detect(
        currentStreak: Int,
        dailyPoints: [DailyHealthPoint],
        recentWorkouts: [WorkoutHistoryEntry],
        coherence: ConversationContextTags?,
        conversation: [CaptainConversationMessage],
        calendar: Calendar = .current
    ) -> BehavioralStageReading? {

        // 1) RELAPSE — was active before, then a long gap, now back.
        //    Detect by scanning the daily points for a ≥ 10-day inactive
        //    block immediately preceding today's activity.
        if let relapse = detectRelapse(dailyPoints: dailyPoints) {
            return relapse
        }

        // 2) MAINTENANCE — streak ≥ 30 + most days have a workout.
        if currentStreak >= 30 {
            let workoutsLast14 = countWorkouts(in: recentWorkouts, days: 14, calendar: calendar)
            if workoutsLast14 >= 5 {
                return BehavioralStageReading(stage: .maintenance, confidence: 0.85)
            }
        }

        // 3) ACTION — streak ≥ 5 + recent workout cadence is healthy.
        if currentStreak >= 5 {
            let workoutsLast7 = countWorkouts(in: recentWorkouts, days: 7, calendar: calendar)
            if workoutsLast7 >= 3 {
                let confidence: Double = currentStreak >= 14 ? 0.9 : 0.7
                return BehavioralStageReading(stage: .action, confidence: confidence)
            }
        }

        // 4) PREPARATION — small recent activity OR explicit commitment
        //    language in the conversation, but no streak yet.
        if currentStreak >= 1 || hasRecentLightActivity(dailyPoints: dailyPoints) {
            if hasCommitmentLanguage(conversation: conversation) || currentStreak >= 1 {
                return BehavioralStageReading(stage: .preparation, confidence: 0.6)
            }
        }

        // 5) CONTEMPLATION — using app, no streak, no recent activity, has
        //    been chatting (asking questions). Default for new/lapsed users.
        if userIsActive(conversation: conversation) {
            return BehavioralStageReading(stage: .contemplation, confidence: 0.55)
        }

        return nil
    }
}

// MARK: - Detectors (private)

private extension BehavioralStageDetector {

    /// Looks for a window where the user was active, then went inactive for
    /// ≥ 10 days, then became active again today.
    static func detectRelapse(dailyPoints: [DailyHealthPoint]) -> BehavioralStageReading? {
        // Need enough buffer to even consider a 10-day gap.
        guard dailyPoints.count >= 12 else { return nil }
        // Today must be active.
        guard let today = dailyPoints.last, today.steps >= 1500 else { return nil }

        // Walk back from the day before today.
        let prior = Array(dailyPoints.dropLast())
        var consecutiveInactive = 0
        var hadActivePriorToGap = false

        for point in prior.reversed() {
            if point.steps < 1500 && point.workoutCount == 0 {
                consecutiveInactive += 1
                if consecutiveInactive >= 10 {
                    // Look further back — was there meaningful activity
                    // *before* the gap?
                    let beforeGapIndex = prior.count - consecutiveInactive - 1
                    if beforeGapIndex >= 0 {
                        let earlier = prior[...beforeGapIndex]
                        if earlier.contains(where: { $0.steps >= 4000 || $0.workoutCount > 0 }) {
                            hadActivePriorToGap = true
                        }
                    }
                    break
                }
            } else {
                break
            }
        }

        guard consecutiveInactive >= 10, hadActivePriorToGap else { return nil }
        return BehavioralStageReading(
            stage: .relapse,
            confidence: min(1.0, 0.6 + Double(consecutiveInactive - 10) * 0.04)
        )
    }

    static func countWorkouts(
        in workouts: [WorkoutHistoryEntry],
        days: Int,
        calendar: Calendar
    ) -> Int {
        let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return workouts.filter { $0.date >= cutoff }.count
    }

    static func hasRecentLightActivity(dailyPoints: [DailyHealthPoint]) -> Bool {
        // At least one of the last 3 days has a meaningful step count.
        dailyPoints.suffix(3).contains { $0.steps >= 2_500 }
    }

    /// Looks for explicit commitment / readiness language in the user turns.
    /// Iraqi-Arabic + English. Conservative — these phrases must signal
    /// *intent*, not preference.
    static func hasCommitmentLanguage(conversation: [CaptainConversationMessage]) -> Bool {
        let userTurns = conversation.filter { $0.role == .user }.suffix(5)
        guard !userTurns.isEmpty else { return false }

        let phrases: [String] = [
            "أبدي", "أبدأ", "ابدي", "ابدا",
            "متى نبدي", "خل نبدي",
            "راح أتمرن", "بدأت", "أريد أتمرن",
            "i'll start", "let's start", "i want to start",
            "i'm ready", "im ready", "ready to begin",
            "starting today", "starting tomorrow"
        ]
        return userTurns.contains { turn in
            let lowered = turn.content.lowercased()
            return phrases.contains { lowered.contains($0) }
        }
    }

    /// Has the user *engaged* in this session? At least one user turn means
    /// "active", which lets us land them on contemplation rather than
    /// returning nothing.
    static func userIsActive(conversation: [CaptainConversationMessage]) -> Bool {
        conversation.contains { $0.role == .user }
    }
}
