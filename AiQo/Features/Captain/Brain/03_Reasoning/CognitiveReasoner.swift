// ===============================================
// File: CognitiveReasoner.swift
// Brain Refactor §37 — Executive Function Layer
//
// Synthesises a *reasoning brief* from the existing context (HealthKit,
// trends, recent activity, conversation tags) and hands the LLM a ready
// thesis instead of forcing it to re-derive one each turn.
//
// Without this, Gemini receives ~25 separate facts (steps, sleep, HR,
// trends, recent workout, coherence tags…) and is expected to compose them
// into coherent guidance every time. That's where shallow, generic replies
// come from. The reasoner does the synthesis once, deterministically, and
// gives the model a one-paragraph "thesis + 2 callbacks + angle" to write
// against.
//
// All logic is local — no LLM call, no network. Runs in <2ms on MainActor.
// ===============================================

import Foundation

// MARK: - Brief

/// The angle the next reply should lead with. Picked deterministically from
/// context — the model is told to *honour* the angle, not invent its own.
enum ReasoningAngle: String, Sendable {
    /// User just finished a workout (within 1h) — recovery, hydration, food.
    case recovery
    /// User hit a personal best or completed a streak day — celebrate briefly,
    /// don't dwell.
    case celebrate
    /// User has clear capacity to push and is behind on a goal — encourage
    /// action with a specific micro-step.
    case pushForward
    /// Low energy / poor sleep / accumulated load — gentle tone, easy step.
    case gentle
    /// Frustration directed at the Captain itself — apology + reset, never
    /// double down on the previous suggestion.
    case repair
    /// Stressed / overwhelmed — grounding, single small step, no plan.
    case grounding
    /// User asked a direct factual question — answer it, then one tiny hook.
    case factual
    /// Nothing acute — surface a pattern the user might not have noticed.
    case proactiveCallout
}

/// Multi-day pattern surfaced to the prompt as a specific, quotable insight.
/// The reasoner converts each one into a *ready-made callback phrase* so the
/// model's reply feels observed, not generic.
enum ObservedPattern: Sendable {
    /// N consecutive days under 6h sleep.
    case lowSleepStreak(days: Int, lastNightHours: Double)
    /// N consecutive days with at least one workout — risk of overtraining.
    case workoutLoadStreak(days: Int)
    /// Same activity family logged on N straight days — risk of monotony.
    case activityMonotony(family: RecentActivityFamily, days: Int)
    /// Resting heart rate trending up while sleep trending down — accumulating
    /// fatigue signal.
    case fatigueAccumulation
    /// Today's steps already above the 7-day max.
    case stepsPersonalBest(today: Int, prior7DayMax: Int)
    /// Today's steps notably below the 7-day average and it's late.
    case fallingBehindOnSteps(today: Int, average: Int, hour: Int)
    /// Streak is intact but at risk — late in the day with no activity.
    case streakAtRisk(streakDays: Int, hour: Int)
    /// Consistency score crossed an upward threshold — the *trend* itself
    /// is now noteworthy.
    case consistencyImproving(scorePct: Int)
}

/// The structured brief the prompt layer renders into the system prompt.
/// Empty briefs (`thesis.isEmpty && observedPatterns.isEmpty`) are dropped
/// from the prompt so we don't pay tokens for nothing.
struct ReasoningBrief: Sendable {
    /// One-sentence synthesis the model uses as scaffolding. Iraqi-friendly.
    let thesis: String
    let angle: ReasoningAngle
    let observedPatterns: [ObservedPattern]
    /// Pre-formatted callback phrases ready to drop into the reply ("توك مشيت
    /// 3.1 كم — هاي أعلى مسافة بآخر 7 أيام"). The model picks 0–2.
    let smartCallbacks: [String]
    /// Optional opening line guidance — a *type* of opener, not a literal one.
    let openingHook: String?
    /// Optional trade-off note for tomorrow if today's session implies one.
    let nextDayHint: String?
    /// Mirrors `ConversationContextTags.familiesToAvoid` rendered as labels.
    let avoidances: [String]
    // §38–§40 additions — make the Captain feel like it knows the user.
    /// Recurring rhythm patterns (training days, time-of-day preference,
    /// family preference, sleep regularity). Confidence-filtered to ≥ 0.6.
    let habitPatterns: [HabitPattern]
    /// Demographic-aware coaching directive (age bracket + experience + goal).
    /// One sentence. Empty when no profile data is available.
    let profileDirective: String
    /// Today-specific micro-observations (first-after-rest, best sleep, etc.).
    /// Max 2 to keep the brief compact.
    let microInsights: [MicroInsight]
    // §42 addition — communication style mirroring.
    /// One-paragraph directive telling the model how to *write* (length,
    /// formality, emoji, opening). Empty when sample size is too small.
    let styleDirective: String
    // §43 addition — causal reasoning narrative.
    /// 2–3 hop chain through the causal graph (activity → state → intention)
    /// the model uses to construct *explanations*, not just suggestions.
    /// Nil when no activity is fresh enough to anchor a chain.
    let causalChain: CausalChain?
    // §44 addition — Transtheoretical Model stage of behaviour change.
    /// Detected stage + the matching coaching playbook directive. Suppressed
    /// when confidence is too low.
    let behavioralStage: BehavioralStageReading?
    // §45 addition — anticipated follow-up question.
    /// One-line priming hint so the reply naturally sets up the *next*
    /// likely question without pre-empting it. Nil when confidence too low.
    let predictedFollowUp: PredictedFollowUp?
    // §46 addition — long-term recall from prior sessions.
    /// "Echoes from before" — high-salience episodes fetched at brief-build
    /// time. `.empty` when no salient episodes exist within look-back.
    let episodicRecall: EpisodicRecall
    // §47 addition — domain-specialist sub-reasoner output.
    /// Domain-specific guidance (workout / nutrition / sleep) that fires
    /// only when the user's intent matches that domain. Supplements — does
    /// not replace — the general brief. Nil when no specialist activates.
    let specialistGuidance: SpecialistGuidance?
    // §49 addition — physiological mood from live HR.
    /// Real-time mood inferred from heart rate elevation above resting,
    /// crossed with recent activity context. Drives the *tone* of the reply
    /// so Captain speaks calmly to a stressed body and matches energy to
    /// an excited one. `.unknown` reading when no HR data is available.
    let hrMood: HRMoodReading

    /// Brain §50 (Round 2 Fix A) — `isEmpty` must consult *every* signal-
    /// bearing field; otherwise the prompt composer's `.filter { !$0.isEmpty }`
    /// drops a brief that contains a meaningful signal in one of the
    /// previously-unchecked fields (hrMood, stage, specialist, causal chain,
    /// coherence avoidances, style, predictedFollowUp). The brief is only
    /// truly empty when no layer wants to say anything to the model.
    var isEmpty: Bool {
        thesis.isEmpty
            && observedPatterns.isEmpty
            && smartCallbacks.isEmpty
            && habitPatterns.isEmpty
            && microInsights.isEmpty
            && profileDirective.isEmpty
            && styleDirective.isEmpty
            && episodicRecall.isEmpty
            && avoidances.isEmpty
            && openingHook == nil
            && nextDayHint == nil
            && causalChain == nil
            && behavioralStage == nil
            && predictedFollowUp == nil
            && specialistGuidance == nil
            && !hrMood.hasSignal
    }

    static let empty = ReasoningBrief(
        thesis: "",
        angle: .factual,
        observedPatterns: [],
        smartCallbacks: [],
        openingHook: nil,
        nextDayHint: nil,
        avoidances: [],
        habitPatterns: [],
        profileDirective: "",
        microInsights: [],
        styleDirective: "",
        causalChain: nil,
        behavioralStage: nil,
        predictedFollowUp: nil,
        episodicRecall: .empty,
        specialistGuidance: nil,
        hrMood: .unknown
    )

    // MARK: - Invariants (Brain §50 Round 3 Fix V)
    //
    // Cross-layer contradictions can compile cleanly and ship silently —
    // e.g. a `.gentle` angle that ships with a workout-specialist
    // recommendation of `.hard` intensity. The validator runs in DEBUG to
    // catch such drift the moment it slips through, and logs (without
    // asserting) in RELEASE so production telemetry can flag regressions.

    /// Returns the list of broken invariants. Empty array = brief is
    /// internally consistent. Caller decides whether to assert / log.
    func brokenInvariants() -> [String] {
        var broken: [String] = []

        // 1. A user-protection angle must not be paired with hard/maximal
        //    specialist intensity. §50 Round 2 Fix B already clamps; this
        //    guards against a future regression that bypasses the clamp.
        if let guidance = specialistGuidance {
            switch guidance {
            case .workout(let plan):
                let userProtectionAngles: Set<ReasoningAngle> = [.repair, .grounding]
                if userProtectionAngles.contains(angle),
                   plan.intensity == .hard || plan.intensity == .maximal {
                    broken.append("specialist_intensity_violates_protection_angle")
                }
                if angle == .gentle, plan.intensity == .maximal {
                    broken.append("specialist_maximal_under_gentle_angle")
                }
            }
        }

        // 2. Avoidances must not appear in smartCallbacks. The callbacks
        //    section is "ready phrases the model may quote." If walking is
        //    avoided, the callback "you walked 3.1km" is fine (it references
        //    the past) but a callback that *suggests* walking would be bad.
        //    Our callback builder doesn't currently produce suggestions, so
        //    this is a future-proofing check that's currently always green.
        for avoid in avoidances {
            for callback in smartCallbacks {
                let lowered = callback.lowercased()
                if lowered.contains("خل نسوي \(avoid.lowercased())")
                    || lowered.contains("let's do \(avoid.lowercased())") {
                    broken.append("callback_suggests_avoided:\(avoid)")
                }
            }
        }

        // 3. HR mood `.stressed` must NOT pair with `.pushForward` or
        //    `.celebrate`. Body says backoff; angle would say push.
        if hrMood.hasSignal, hrMood.confidence >= 0.7,
           hrMood.mood == .stressed,
           angle == .pushForward || angle == .celebrate {
            broken.append("stressed_hr_paired_with_push_or_celebrate")
        }

        // 4. Behavioural-stage `.relapse` must NOT pair with `.pushForward`
        //    or `.celebrate`. Returning users need gentle, not hype.
        if let stage = behavioralStage,
           stage.confidence >= 0.6,
           stage.stage == .relapse,
           angle == .pushForward || angle == .celebrate {
            broken.append("relapse_stage_paired_with_push_or_celebrate")
        }

        // 5. §50 Round 4 — HR mood `.postEffort` should pair with
        //    `.recovery` angle. Anything else (factual, push, celebrate)
        //    means the body's recovery signal got ignored.
        if hrMood.hasSignal, hrMood.confidence >= 0.7,
           hrMood.mood == .postEffort,
           angle != .recovery {
            broken.append("post_effort_hr_not_recovery_angle")
        }

        // 6. §50 Round 4 — `.contemplation` stage must NOT pair with
        //    `.pushForward`. Exploring users need open questions, not
        //    pressure.
        if let stage = behavioralStage,
           stage.confidence >= 0.6,
           stage.stage == .contemplation,
           angle == .pushForward {
            broken.append("contemplation_stage_paired_with_push")
        }

        // 7. §50 Round 4 — fresh activity (veryFresh) but angle is push /
        //    celebrate without a personal-best pattern. Likely the angle
        //    cascade missed the recovery branch.
        if specialistGuidance != nil,
           angle == .pushForward,
           hasPersonalBestPattern == false {
            // Soft check — only flag when patterns clearly don't justify
            // push. Personal-best is the legitimate path to push from
            // fresh activity context.
            broken.append("push_angle_without_personal_best_evidence")
        }

        return broken
    }

    /// Helper for invariant 7 — does the brief carry a `stepsPersonalBest`
    /// pattern? `pickAngle` only returns `.pushForward` when it makes sense
    /// to do so, but the invariant catches future regressions.
    private var hasPersonalBestPattern: Bool {
        observedPatterns.contains { pattern in
            if case .stepsPersonalBest = pattern { return true }
            return false
        }
    }

    /// Asserts in DEBUG when invariants are broken. No-op in RELEASE so we
    /// never crash a user's session over a brain inconsistency — telemetry
    /// would catch repeated occurrences.
    func enforceInvariantsInDebug() {
        #if DEBUG
        let broken = brokenInvariants()
        if !broken.isEmpty {
            assertionFailure(
                "ReasoningBrief invariants broken: \(broken.joined(separator: ", "))"
            )
        }
        #endif
    }
}

// MARK: - Inputs

/// Everything the reasoner needs to produce a brief. Bundling them into a
/// dedicated input struct keeps the call site (CaptainContextBuilder) terse
/// and makes the reasoner trivially testable with synthetic inputs.
struct ReasonerInput: Sendable {
    let language: AppLanguage
    let hour: Int
    let steps: Int
    let calories: Int
    let sleepHoursLastNight: Double
    let restingHeartRate: Int?
    let level: Int
    let bioPhase: BioTimePhase
    let trend: TrendSnapshot?
    let recentActivity: RecentActivitySnapshot?
    let coherence: ConversationContextTags?
    let dailyPoints: [DailyHealthPoint]   // ascending by date, may be empty
    let recentWorkouts: [WorkoutHistoryEntry]   // newest first, max 7
    /// §39 — demographic-aware lens (nil falls back to neutral thresholds).
    let profileLens: UserProfileLens?
    /// §38 — current streak, used by §40 to fire milestone insights.
    let currentStreak: Int
    /// §42 — full conversation passed through so the personality analyzer
    /// can compute its style vector. Empty array → analyzer falls back to
    /// neutral defaults and the brief skips the style directive.
    let conversation: [CaptainConversationMessage]
    /// §46 — pre-fetched long-term recall. The CaptainContextBuilder pulls
    /// this async from `EpisodicStore` before instantiating the reasoner so
    /// `reason()` itself stays sync.
    let episodicRecall: EpisodicRecall
    /// §49 — pre-computed HR mood. Builder fetches live + resting HR
    /// async, runs the reader, and hands the result here.
    let hrMood: HRMoodReading
}

// MARK: - Reasoner

@MainActor
final class CognitiveReasoner {
    static let shared = CognitiveReasoner()
    private init() {}

    /// Produces a brief synchronously from a fully-built input.
    ///
    /// Brain §50 ordering invariant — compute the behavioural stage *before*
    /// picking the angle. `pickAngle` consults the stage at level 4 of the
    /// authority chain; if we computed the stage later we'd silently drop
    /// that signal from angle selection. Other slow-moving signals (HR mood,
    /// coherence tags, recent activity) arrive pre-built in `ReasonerInput`,
    /// so the only reorder-sensitive piece is the stage detector.
    func reason(input: ReasonerInput) -> ReasoningBrief {
        let isArabic = input.language == .arabic
        let patterns = detectPatterns(input: input)

        // §44 stage — moved up so §50 angle picker can consult it.
        let behavioralStage = BehavioralStageDetector.detect(
            currentStreak: input.currentStreak,
            dailyPoints: input.dailyPoints,
            recentWorkouts: input.recentWorkouts,
            coherence: input.coherence,
            conversation: input.conversation
        )

        let angle = pickAngle(
            input: input,
            patterns: patterns,
            behavioralStage: behavioralStage
        )

        let avoidances = (input.coherence?.familiesToAvoid ?? []).map {
            isArabic ? $0.arabicLabel : $0.englishLabel
        }

        let callbacks = buildCallbacks(
            input: input,
            patterns: patterns,
            isArabic: isArabic
        )

        let thesis = composeThesis(
            input: input,
            angle: angle,
            patterns: patterns,
            isArabic: isArabic,
            behavioralStage: behavioralStage
        )

        let openingHook = composeOpeningHook(
            angle: angle,
            patterns: patterns,
            input: input,
            isArabic: isArabic
        )

        let nextDayHint = composeNextDayHint(
            angle: angle,
            input: input,
            isArabic: isArabic
        )

        // §38 — recurring rhythm patterns (training days, sleep regularity,
        // family preference). Confidence-filtered, max 3.
        // §50 — profileLens flows through so age-aware thresholds (e.g.
        // earlier no-rest warning for established/senior users) apply.
        // §50 Round 6 — behavioralStage flows through so relapse /
        // contemplation users see at most 1 pattern.
        let habitPatterns = HabitDetector.detect(
            dailyPoints: input.dailyPoints,
            recentWorkouts: input.recentWorkouts,
            profileLens: input.profileLens,
            behavioralStage: behavioralStage
        )

        // §39 — demographic-aware coaching directive. Empty when no profile.
        let profileDirective: String = {
            guard let lens = input.profileLens else { return "" }
            return isArabic ? lens.coachingDirectiveArabic : lens.coachingDirectiveEnglish
        }()

        // §40 — today-specific micro-observations. Max 2.
        let microInsights = MicroInsightGenerator.generate(
            steps: input.steps,
            sleepHoursLastNight: input.sleepHoursLastNight,
            recentActivity: input.recentActivity,
            dailyPoints: input.dailyPoints,
            recentWorkouts: input.recentWorkouts,
            hour: input.hour,
            currentStreak: input.currentStreak
        )

        // §42 — communication-style fingerprint. Empty when the conversation
        // window is too small to produce a stable signal.
        let style = PersonalityAnalyzer.analyze(conversation: input.conversation)
        let styleDirective = isArabic ? style.directiveArabic : style.directiveEnglish

        // §50 Round 6 — intent + emotion are detected once here so they're
        // available to BOTH the causal-chain skip check (Fix ν, below) and
        // the predictor / specialist (used later). Previously intent was
        // computed lower in the function which made Fix ν reference an
        // undeclared variable.
        let latestUserMessage = input.conversation
            .last { $0.role == .user }?.content ?? ""
        let currentIntent = CaptainMessageIntent.detect(
            message: latestUserMessage,
            screenContext: .mainChat
        )
        // §50 Round 3 — emotion is read from `coherence.latestEmotion`
        // instead of re-detecting from the message string. Coherence has
        // already done that detection upstream; calling it again would
        // be redundant work and a divergence risk if either implementation
        // ever drifts. Falls back to `.neutral` when coherence didn't run.
        let currentEmotion = input.coherence?.latestEmotion ?? .neutral

        // §43 — causal chain (activity → state → intention) so the model
        // *explains* its suggestion instead of asserting it.
        // §50 Round 4 — stage flows in to constrain chain depth for
        // relapse / contemplation users.
        // §50 Round 6 Fix ν — when the workout specialist is going to fire
        // (intent == .workout AND there's a fresh activity to anchor on),
        // skip the causal chain. The specialist already explains its
        // recommendation in `reasoningArabic/English`, so adding the chain
        // produces overlapping explanations the model has to reconcile.
        // The brief stays leaner; explanation lives in one canonical place.
        let willHaveSpecialist = currentIntent == .workout
            && input.recentActivity != nil
        let causalChain: CausalChain? = willHaveSpecialist ? nil : CausalChainBuilder.derive(
            recentActivity: input.recentActivity,
            sleepHoursLastNight: input.sleepHoursLastNight,
            hour: input.hour,
            behavioralStage: behavioralStage
        )

        // §45 — anticipate the user's next likely question and prime the
        // reply with a one-line hook. Re-uses the intent + emotion
        // classifiers detected above.
        // §50 — hrMood flows into the predictor so physiological state can
        // short-circuit plan-flavoured predictions when the body needs rest.
        let predictedFollowUp = PredictiveIntentEngine.anticipate(
            currentIntent: currentIntent,
            emotionalSignal: currentEmotion,
            recentActivity: input.recentActivity,
            sleepHoursLastNight: input.sleepHoursLastNight,
            hour: input.hour,
            coherence: input.coherence,
            behavioralStage: behavioralStage,
            hrMood: input.hrMood
        )

        // §47 — domain-specialist activation. Only the workout specialist
        // ships in Phase 12; nutrition + sleep specialists are reserved
        // slots in `SpecialistGuidance`. The specialist's output is
        // supplemental — the general brief above still applies.
        // §50 — `briefAngle: angle` lets the specialist defer its intensity
        // ceiling to the angle picker's already-resolved authority.
        let specialistGuidance: SpecialistGuidance?
        if let workout = WorkoutSpecialistReasoner.recommend(
            intent: currentIntent,
            recentActivity: input.recentActivity,
            recentWorkouts: input.recentWorkouts,
            sleepHoursLastNight: input.sleepHoursLastNight,
            restingHeartRate: input.restingHeartRate,
            profileLens: input.profileLens,
            coherence: input.coherence,
            hour: input.hour,
            briefAngle: angle
        ) {
            specialistGuidance = .workout(workout)
        } else {
            specialistGuidance = nil
        }

        let brief = ReasoningBrief(
            thesis: thesis,
            angle: angle,
            observedPatterns: patterns,
            smartCallbacks: callbacks,
            openingHook: openingHook,
            nextDayHint: nextDayHint,
            avoidances: avoidances,
            habitPatterns: habitPatterns,
            profileDirective: profileDirective,
            microInsights: microInsights,
            styleDirective: styleDirective,
            causalChain: causalChain,
            behavioralStage: behavioralStage,
            predictedFollowUp: predictedFollowUp,
            // §46 — pre-fetched in CaptainContextBuilder so the reasoner
            // stays sync. Falls back to .empty when no signal.
            episodicRecall: input.episodicRecall,
            specialistGuidance: specialistGuidance,
            // §49 — hand the live HR mood through unmodified. The brief
            // layer renders the tone directive; the reasoner doesn't
            // override its own angle picker based on HR (yet).
            hrMood: input.hrMood
        )

        // §50 Round 3 Fix V — assert internal consistency in DEBUG. Catches
        // future regressions where two layers ship contradictory directives
        // (e.g. specialist=.hard with angle=.grounding). No-op in RELEASE.
        brief.enforceInvariantsInDebug()
        return brief
    }
}

// MARK: - Pattern Detection

private extension CognitiveReasoner {

    /// Walks the daily-point buffer + recent-workout list and returns every
    /// pattern that crosses its salience threshold. Order matches priority —
    /// the prompt renders them as bullets and the model picks the most
    /// relevant one or two. Hard-cap of 4 patterns to keep token cost bounded.
    func detectPatterns(input: ReasonerInput) -> [ObservedPattern] {
        var hits: [ObservedPattern] = []

        // 1) Sleep deficit streak — last 3+ days under threshold.
        //    §39: older users feel deficits at higher thresholds; the lens
        //    bumps the line to 6.5h for 40+ ages.
        let sleepThreshold = input.profileLens?.lowSleepThresholdHours ?? 6.0
        if let sleepStreak = consecutiveDaysUnderSleep(input.dailyPoints, threshold: sleepThreshold),
           sleepStreak >= 3 {
            hits.append(.lowSleepStreak(days: sleepStreak, lastNightHours: input.sleepHoursLastNight))
        }

        // 2) Workout load streak — 4+ days in a row with any workout.
        if let trainStreak = consecutiveDaysWithWorkouts(input.dailyPoints), trainStreak >= 4 {
            hits.append(.workoutLoadStreak(days: trainStreak))
        }

        // 3) Activity monotony — same family 5+ days running.
        if let monotony = monotonousFamily(workouts: input.recentWorkouts, minDays: 5) {
            hits.append(.activityMonotony(family: monotony.family, days: monotony.days))
        }

        // 4) Fatigue accumulation — RHR trending up + sleep trending down.
        if let trend = input.trend,
           trend.heartRateTrend == .declining || trend.heartRateChangePct >= 5,
           trend.sleepTrend == .declining {
            hits.append(.fatigueAccumulation)
        }

        // 5) Steps personal best — today already above the 7-day max.
        //    §39: the floor scales with the user's profile lens so we don't
        //    "celebrate" 1,500 steps for a 25-year-old advanced user nor
        //    fail to celebrate 4,500 for a 60-year-old beginner.
        let pbFloor = input.profileLens?.stepsPersonalBestFloor ?? 1_500
        if let priorMax = stepsMaxExcludingToday(input.dailyPoints, today: input.steps),
           input.steps > priorMax,
           input.steps >= pbFloor {
            hits.append(.stepsPersonalBest(today: input.steps, prior7DayMax: priorMax))
        }

        // 6) Falling behind on steps — late hour and below 7-day average.
        if input.hour >= 17,
           let avg = stepsAverageExcludingToday(input.dailyPoints),
           avg >= 4000,
           input.steps < Int(Double(avg) * 0.6) {
            hits.append(.fallingBehindOnSteps(today: input.steps, average: avg, hour: input.hour))
        }

        // 7) Streak at risk — momentum says "holding" but it's late + low steps.
        if let trend = input.trend,
           trend.streakMomentum == .holding || trend.streakMomentum == .building,
           input.hour >= 19,
           input.steps < 3000 {
            hits.append(.streakAtRisk(streakDays: trend.workoutsThisWeek, hour: input.hour))
        }

        // 8) Consistency improving — newly ≥ 75% over last 7 days.
        if let trend = input.trend, trend.consistencyScore >= 0.75 {
            hits.append(.consistencyImproving(scorePct: Int(trend.consistencyScore * 100)))
        }

        // Clamp at 4 — beyond this is noise in the prompt.
        return Array(hits.prefix(4))
    }

    func consecutiveDaysUnderSleep(_ points: [DailyHealthPoint], threshold: Double) -> Int? {
        guard !points.isEmpty else { return nil }
        var count = 0
        for point in points.reversed() {
            // Skip days with no recorded sleep (0 = unknown, not 0h slept).
            guard point.sleepHours > 0 else { break }
            if point.sleepHours < threshold {
                count += 1
            } else {
                break
            }
        }
        return count > 0 ? count : nil
    }

    func consecutiveDaysWithWorkouts(_ points: [DailyHealthPoint]) -> Int? {
        guard !points.isEmpty else { return nil }
        var count = 0
        for point in points.reversed() {
            if point.workoutCount > 0 {
                count += 1
            } else {
                break
            }
        }
        return count > 0 ? count : nil
    }

    /// Returns the dominant family + days if the user has done the same
    /// activity for the last `minDays` workouts in a row (newest first).
    func monotonousFamily(
        workouts: [WorkoutHistoryEntry],
        minDays: Int
    ) -> (family: RecentActivityFamily, days: Int)? {
        guard workouts.count >= minDays else { return nil }
        let firstFamily = RecentActivityFamily.classify(title: workouts[0].title)
        guard firstFamily != .other else { return nil }

        var streak = 1
        for entry in workouts.dropFirst() {
            let family = RecentActivityFamily.classify(title: entry.title)
            if family == firstFamily {
                streak += 1
            } else {
                break
            }
        }
        return streak >= minDays ? (firstFamily, streak) : nil
    }

    func stepsMaxExcludingToday(_ points: [DailyHealthPoint], today: Int) -> Int? {
        let prior = points.dropLast()  // last buffer is today
        guard !prior.isEmpty else { return nil }
        return prior.map(\.steps).max()
    }

    func stepsAverageExcludingToday(_ points: [DailyHealthPoint]) -> Int? {
        let prior = points.dropLast()
        guard !prior.isEmpty else { return nil }
        let total = prior.reduce(0) { $0 + $1.steps }
        return total / prior.count
    }
}

// MARK: - Angle Selection
//
// AUTHORITY CHAIN (Brain Refactor §50 — the resolution rule):
//
// When two signals disagree about what the next angle should be, we resolve
// in this fixed order. Higher = stronger authority. Document any new branch
// you add against this hierarchy.
//
//   1. EXPLICIT USER FEEDBACK (`coherence.userIsFrustratedWithCaptain`)
//        — direct, specific, addresses the bot itself. Always wins.
//   2. PHYSIOLOGY (`hrMood`)
//        — body data outranks text-based emotion guessing. A stressed
//          heart beats a "بخير" message every time.
//   3. RECENT ACTIVITY (`recentActivity.freshness == .veryFresh`)
//        — fresh workout context drives recovery angle even with no HR.
//   4. BEHAVIOURAL STAGE (`behavioralStage`)
//        — relapse / contemplation reshape the playbook regardless of
//          today's metric noise. Stage is slow-moving truth.
//   5. ACUTE PATTERNS (low sleep streak, fatigue accumulation)
//        — multi-day signals. Override one-shot text emotion.
//   6. TEXT EMOTION (`coherence.latestEmotion`)
//        — single-turn signal, weakest of the override family.
//   7. POSITIVE PATTERNS (personal best, streak at risk)
//        — celebration / push triggers.
//   8. RHYTHM PATTERNS (monotony, consistency, load streak)
//        — proactive callouts when nothing acute is happening.
//   9. DEFAULT — `.factual`.
//
// The first match wins. Each branch documents which level it is.

private extension CognitiveReasoner {

    /// Picks the next-reply angle from the authority chain above. Each branch
    /// is annotated with its level (1–9) so future maintainers can reason
    /// about ordering without re-deriving it.
    func pickAngle(
        input: ReasonerInput,
        patterns: [ObservedPattern],
        behavioralStage: BehavioralStageReading?
    ) -> ReasoningAngle {
        // Level 1 — Explicit user feedback. Always wins.
        if input.coherence?.userIsFrustratedWithCaptain == true {
            return .repair
        }

        // Level 2 — Physiology. HR mood overrides text-based emotion when
        // confidence is at least medium. Stressed body → grounding even if
        // the user typed "بخير". Post-effort → recovery (mirrors level 3).
        //
        // §50 Round 3 — full enumeration. The previous version dropped 4 of
        // 7 mood cases silently. `excited` + opportunity → push (matches
        // motivated-text behaviour but with body confirmation). `relaxed`
        // / `focused` BIAS toward proactiveCallout when patterns exist —
        // calm space is exactly when to surface a non-urgent observation.
        // Unmapped cases fall through to lower levels.
        if input.hrMood.hasSignal, input.hrMood.confidence >= 0.7 {
            switch input.hrMood.mood {
            case .postEffort:    return .recovery
            case .stressed:      return .grounding
            case .windingDown:   return .gentle
            case .excited:
                // Body says high arousal + positive. Only escalates to push
                // when there's something to push toward (avoids manic vibes).
                let hasOpportunity = patterns.contains { pattern in
                    if case .fallingBehindOnSteps = pattern { return true }
                    if case .streakAtRisk = pattern         { return true }
                    return false
                }
                if hasOpportunity { return .pushForward }
            case .relaxed, .focused:
                // Body is calm — perfect window for a proactive callout if
                // any rhythm pattern is worth surfacing. Without a pattern,
                // we let later cascade levels lead.
                let hasRhythmPattern = patterns.contains { pattern in
                    if case .activityMonotony = pattern    { return true }
                    if case .consistencyImproving = pattern { return true }
                    if case .workoutLoadStreak = pattern    { return true }
                    return false
                }
                if hasRhythmPattern { return .proactiveCallout }
            case .unknown:
                break
            }
        }

        // Level 3 — Fresh workout. Recovery wins over patterns/emotion.
        if input.recentActivity?.freshness == .veryFresh {
            return .recovery
        }

        // Level 4 — Behavioural stage. Relapse and contemplation reshape
        // the playbook even when other signals look benign.
        if let stage = behavioralStage, stage.confidence >= 0.6 {
            switch stage.stage {
            case .relapse:
                // Returning user — gentle wins over any "celebrate the
                // first step" instinct, which can read as patronising.
                return .gentle
            case .contemplation:
                // Exploring user — factual + open questions. Don't push.
                return .factual
            case .preparation, .action, .maintenance:
                break  // fall through; these stages let other signals lead
            }
        }

        // Level 5 — Acute multi-day patterns. These outrank single-turn text.
        if patterns.contains(where: { pattern in
            if case .fatigueAccumulation = pattern { return true }
            if case .lowSleepStreak = pattern      { return true }
            return false
        }) {
            return .gentle
        }

        // Level 6 — Text emotion. Last of the override family.
        switch input.coherence?.latestEmotion {
        case .stressed:
            return .grounding
        case .tired:
            return .gentle
        case .frustrated:
            return .repair
        case .motivated:
            // Motivated user + capacity → push. But only if there's a
            // clear lever (steps behind, streak at risk).
            if patterns.contains(where: { pattern in
                if case .fallingBehindOnSteps = pattern { return true }
                if case .streakAtRisk = pattern         { return true }
                return false
            }) {
                return .pushForward
            }
        case .neutral, .none:
            break
        }

        // Level 7a — Personal best (positive pattern).
        if patterns.contains(where: { pattern in
            if case .stepsPersonalBest = pattern { return true }
            return false
        }) {
            return .celebrate
        }

        // Level 7b — Streak at risk.
        if patterns.contains(where: { pattern in
            if case .streakAtRisk = pattern { return true }
            return false
        }) {
            return .pushForward
        }

        // Level 8 — Rhythm patterns.
        if patterns.contains(where: { pattern in
            if case .activityMonotony = pattern     { return true }
            if case .consistencyImproving = pattern { return true }
            if case .workoutLoadStreak = pattern    { return true }
            return false
        }) {
            return .proactiveCallout
        }

        // Level 9 — Default.
        return .factual
    }
}

// MARK: - Callback Phrasing

private extension CognitiveReasoner {

    /// Renders patterns + raw numbers into ready-to-paste Iraqi/English
    /// phrases. Cap at 3 — the model should pick at most 1–2 in its reply.
    func buildCallbacks(
        input: ReasonerInput,
        patterns: [ObservedPattern],
        isArabic: Bool
    ) -> [String] {
        var lines: [String] = []

        // Tracked-workout callback — one of the highest-value, always when fresh.
        if let activity = input.recentActivity, activity.freshness != .stale {
            if isArabic {
                var pieces: [String] = ["توه خلّص \(activity.family.arabicLabel) \(activity.durationMinutes) دقيقة"]
                if activity.activeCalories > 0 {
                    pieces.append("\(activity.activeCalories) سعرة")
                }
                if let km = activity.distanceKm {
                    pieces.append(String(format: "%.2f كم", km))
                }
                lines.append(pieces.joined(separator: " — "))
            } else {
                var pieces: [String] = ["just finished \(activity.family.englishLabel) for \(activity.durationMinutes) min"]
                if activity.activeCalories > 0 { pieces.append("\(activity.activeCalories) kcal") }
                if let km = activity.distanceKm {
                    pieces.append(String(format: "%.2f km", km))
                }
                lines.append(pieces.joined(separator: " — "))
            }
        }

        for pattern in patterns {
            switch pattern {
            case let .lowSleepStreak(days, lastNight):
                lines.append(
                    isArabic
                        ? "نومه \(days) أيام تحت 6 ساعات (آخر ليلة \(String(format: "%.1f", lastNight))س)"
                        : "\(days) days of sleep under 6h (last night \(String(format: "%.1f", lastNight))h)"
                )
            case let .stepsPersonalBest(today, priorMax):
                lines.append(
                    isArabic
                        ? "اليوم \(today) خطوة — أعلى من أي يوم بآخر 7 أيام (\(priorMax))"
                        : "\(today) steps today — above the 7-day max (\(priorMax))"
                )
            case let .fallingBehindOnSteps(today, average, _):
                lines.append(
                    isArabic
                        ? "اليوم \(today) خطوة، معدله \(average) — قل عن المعتاد"
                        : "\(today) steps today vs \(average) average — under pace"
                )
            case let .activityMonotony(family, days):
                lines.append(
                    isArabic
                        ? "\(days) أيام متتالية \(family.arabicLabel) — نوّع شوية"
                        : "\(days) days in a row of \(family.englishLabel) — vary the stimulus"
                )
            case let .workoutLoadStreak(days):
                lines.append(
                    isArabic
                        ? "\(days) أيام تمرين متواصل — الجسم يحتاج إشارة استشفاء"
                        : "\(days) consecutive training days — body needs a recovery cue"
                )
            case .fatigueAccumulation:
                lines.append(
                    isArabic
                        ? "نبض الراحة طالع + النوم نازل — علامة إجهاد متراكم"
                        : "Resting HR up + sleep down — accumulated fatigue"
                )
            case let .streakAtRisk(streakDays, hour):
                lines.append(
                    isArabic
                        ? "الساعة \(hour) والـ streak (\(streakDays)) ينحجي على نشاط بسيط اليوم"
                        : "It's \(hour):00 and the \(streakDays)-day streak needs activity today"
                )
            case let .consistencyImproving(scorePct):
                lines.append(
                    isArabic
                        ? "الالتزام \(scorePct)% خلال آخر 7 أيام — بزخم"
                        : "\(scorePct)% consistency over the last 7 days — momentum"
                )
            }
        }

        return Array(lines.prefix(3))
    }
}

// MARK: - Thesis + Hooks

private extension CognitiveReasoner {

    /// One-sentence synthesis the model leans on. Always includes the angle
    /// + the strongest signal that justifies it.
    ///
    /// Brain §50 (Round 2 Fix C) — when the angle was driven by HR mood or
    /// behavioural stage rather than by patterns/text, the thesis now names
    /// that *upstream cause* explicitly. This keeps the model's own
    /// rendering aligned with the reasoner's actual decision path instead
    /// of producing a generic "user is stressed" line.
    func composeThesis(
        input: ReasonerInput,
        angle: ReasoningAngle,
        patterns: [ObservedPattern],
        isArabic: Bool,
        behavioralStage: BehavioralStageReading?
    ) -> String {
        // §50 — surface the upstream cause for tone-driven angles.
        let causeFragment = upstreamCauseFragment(
            angle: angle,
            input: input,
            behavioralStage: behavioralStage,
            isArabic: isArabic
        )

        switch angle {
        case .repair:
            return isArabic
                ? "المستخدم محبط منك — اعتذر بصدق وقصير، اعترف بالغلطة، ثم خطوة جديدة مختلفة."
                : "User is frustrated with you — short genuine apology, acknowledge the mistake, then a different next step."

        case .recovery:
            guard let activity = input.recentActivity else {
                return isArabic
                    ? "نشاط حديث محتمل\(causeFragment) — مل للاستشفاء والترطيب."
                    : "Likely recent effort\(causeFragment) — bias toward recovery and hydration."
            }
            return isArabic
                ? "خلّص \(activity.family.arabicLabel) \(activity.durationMinutes) دقيقة\(causeFragment) — اربط الرد بالاستشفاء (إطالة، ماء، بروتين، نوم)."
                : "Just finished \(activity.family.englishLabel) (\(activity.durationMinutes)m)\(causeFragment) — anchor the reply on recovery (stretch, water, protein, sleep)."

        case .celebrate:
            return isArabic
                ? "إنجاز قابل للملاحظة اليوم — احتفل بكلمة قصيرة ثم خطوة بناءة، لا تطوّل بالمدح."
                : "Notable win today — celebrate briefly, then build forward. Don't dwell on praise."

        case .pushForward:
            return isArabic
                ? "عنده طاقة أو مساحة\(causeFragment) — اقترح خطوة محددة صغيرة (≤ 15د) تنقل الإبرة، لا خطة كاملة."
                : "User has capacity\(causeFragment) — propose one specific small step (≤ 15min) that moves the needle."

        case .gentle:
            let sleepNote: String? = {
                if case let .lowSleepStreak(days, _) = patterns.first(where: { pattern in
                    if case .lowSleepStreak = pattern { return true } else { return false }
                }) {
                    return isArabic ? "(\(days) أيام نوم ضعيف)" : "(\(days) days of low sleep)"
                }
                return nil
            }()
            return isArabic
                ? "إجهاد متراكم \(sleepNote ?? "")\(causeFragment) — نبرة هادئة، اقتراح بسيط واحد فقط (مشي خفيف، ماء، نوم مبكر)."
                : "Accumulated fatigue \(sleepNote ?? "")\(causeFragment) — gentle tone, one tiny suggestion only (easy walk, water, early bed)."

        case .grounding:
            return isArabic
                ? "المستخدم متوتر\(causeFragment) — جملة دافئة، خطوة صغيرة جداً (نَفَس عميق، 2د امتنان)، لا خطط."
                : "User is stressed\(causeFragment) — warm acknowledgment, micro-step only (deep breath, 2-min gratitude). No plans."

        case .factual:
            return isArabic
                ? "سؤال مباشر\(causeFragment) — جاوب على السؤال بدقة، ثم خطاف صغير اختياري في النهاية."
                : "Direct question\(causeFragment) — answer it precisely, then optional small hook at the end."

        case .proactiveCallout:
            return isArabic
                ? "اكو نمط يستحق الإشارة\(causeFragment) — اذكره طبيعي بدون محاضرة، واربطه بخطوة عملية."
                : "There's a pattern worth surfacing\(causeFragment) — mention it naturally (no lecture) and tie it to one practical step."
        }
    }

    /// §50 — names the upstream cause when an angle is tone-driven (HR mood
    /// or stage). Returns " (السبب: …)" / " (cause: …)" or empty when no
    /// specific upstream signal explains the angle.
    ///
    /// §50 Round 5 Fix κ — coverage extended to `pushForward` and
    /// `proactiveCallout` so HR-driven escalations also carry their
    /// reason, plus `contemplation` stage explanations for the factual
    /// branch. The thesis composer only injects fragments for tone-shifted
    /// angles where the WHY is non-obvious; pushForward / proactive paths
    /// land via `composeThesis(.pushForward / .proactiveCallout)` which
    /// already returns generic strings — adding a fragment makes them
    /// concrete.
    func upstreamCauseFragment(
        angle: ReasoningAngle,
        input: ReasonerInput,
        behavioralStage: BehavioralStageReading?,
        isArabic: Bool
    ) -> String {
        guard [.gentle, .grounding, .recovery, .pushForward, .proactiveCallout, .factual].contains(angle) else { return "" }

        // HR-mood-driven? Most authoritative for tone-driven angles.
        if input.hrMood.hasSignal, input.hrMood.confidence >= 0.7 {
            switch input.hrMood.mood {
            case .stressed where angle == .grounding:
                return isArabic ? " (السبب: نبض مرتفع بدون مبرر تمرين)" : " (cause: elevated HR without effort context)"
            case .windingDown where angle == .gentle:
                return isArabic ? " (السبب: نبض هابط بوقت متأخر)" : " (cause: dropping HR late in the day)"
            case .postEffort where angle == .recovery:
                return isArabic ? " (السبب: نبض بعد جهد)" : " (cause: post-effort HR)"
            case .excited where angle == .pushForward:
                return isArabic ? " (السبب: نبض عالي + طاقة إيجابية)" : " (cause: elevated HR + positive arousal)"
            case .relaxed where angle == .proactiveCallout,
                 .focused where angle == .proactiveCallout:
                return isArabic ? " (السبب: نبض هادي + نمط لافت)" : " (cause: calm HR + a pattern worth surfacing)"
            default: break
            }
        }

        // Stage-driven?
        if let stage = behavioralStage, stage.confidence >= 0.6 {
            switch (stage.stage, angle) {
            case (.relapse, .gentle):
                return isArabic ? " (السبب: عودة بعد انقطاع)" : " (cause: returning after a gap)"
            case (.contemplation, .factual):
                return isArabic ? " (السبب: مرحلة استكشاف — لا تضغط)" : " (cause: contemplation stage — don't push)"
            default: break
            }
        }

        return ""
    }

    /// §50 Round 3 — gentle / grounding hooks now reflect *which* upstream
    /// signal drove the angle, so the opening is concrete instead of
    /// generic. HR-driven openers reference the body; coherence-driven
    /// openers reference what the user said.
    func composeOpeningHook(
        angle: ReasoningAngle,
        patterns: [ObservedPattern],
        input: ReasonerInput,
        isArabic: Bool
    ) -> String? {
        switch angle {
        case .repair:
            return isArabic ? "ابدأ باعتذار صادق قصير، لا تكرر الاقتراح السابق." : "Open with a short genuine apology — don't repeat the prior suggestion."
        case .recovery:
            return isArabic ? "افتح بإشارة لتمرينه (الفئة + المدة) قبل أي اقتراح." : "Open by referencing the just-finished session (family + duration) before any suggestion."
        case .celebrate:
            return isArabic ? "افتح بملاحظة الإنجاز برقم محدد، لا تكون عام." : "Open with a specific number that names the win."
        case .pushForward:
            return isArabic ? "افتح بسطر قصير يحدد التحدي ثم اقترح الخطوة." : "Open with one line that names the gap, then propose the step."
        case .gentle, .grounding:
            return causeSpecificGentleHook(angle: angle, input: input, isArabic: isArabic)
        case .proactiveCallout:
            return isArabic ? "افتح بالنمط الملاحظ مباشرة (\"لاحظت…\")، بدون مقدمة." : "Open with the observed pattern directly (\"I noticed…\"), no preamble."
        case .factual:
            return nil
        }
    }

    /// Specialised opener for tone-driven angles. Differentiates HR-driven
    /// (acknowledge the body) from text-driven (acknowledge what was said).
    ///
    /// §50 Round 5 Fix ι — priority reordered. Explicit user feedback
    /// ("ما تفهم", "غبي") is the most specific signal we ever get; it
    /// must win over physiological inference. The previous order had HR
    /// firing first, which would mask a clear "user is frustrated with
    /// the Captain" cue when the body also happened to be activated.
    func causeSpecificGentleHook(
        angle: ReasoningAngle,
        input: ReasonerInput,
        isArabic: Bool
    ) -> String {
        // §50 — explicit user feedback wins over physiology. If the user
        // told us they're upset with the bot, that's the opener context,
        // not their heart rate.
        if input.coherence?.userIsFrustratedWithCaptain == true {
            return isArabic
                ? "افتح بسؤاله صراحة عما يضايقه قبل أي اقتراح."
                : "Open by asking what's bothering them before any suggestion."
        }

        // Physiology second.
        if input.hrMood.hasSignal, input.hrMood.confidence >= 0.7 {
            switch input.hrMood.mood {
            case .stressed:
                return isArabic
                    ? "افتح بالاعتراف إن جسمه مشدود اليوم (دون ذكر النبض كرقم)، ثم خطوة صغيرة."
                    : "Open by acknowledging the body feels tense today (without quoting HR), then one tiny step."
            case .windingDown:
                return isArabic
                    ? "افتح بإشارة لطيفة لإن وقت متأخر والجسم يستعد للنوم."
                    : "Open with a gentle nod that it's late and the body is winding down."
            default: break
            }
        }

        // Text emotion fallback.
        if input.coherence?.latestEmotion == .tired {
            return isArabic
                ? "افتح باعتراف بتعبه ثم سؤال خفيف عن سبب التعب."
                : "Open by acknowledging the fatigue, then a light question about its source."
        }

        // Generic fallback.
        return isArabic
            ? "افتح باعتراف بحالته قبل أي توجيه."
            : "Open by acknowledging their state before any direction."
    }

    /// When today's session implies an obvious tomorrow trade-off, surface it
    /// so the model can mention it naturally instead of leaving it implicit.
    func composeNextDayHint(
        angle: ReasoningAngle,
        input: ReasonerInput,
        isArabic: Bool
    ) -> String? {
        guard angle == .recovery, let activity = input.recentActivity else { return nil }

        switch activity.family {
        case .strength, .hiit, .boxing, .martialArts:
            return isArabic
                ? "إذا ذكرت بكرة، اقترح يوم خفيف (مشي زون 2 أو إطالة)."
                : "If tomorrow comes up, suggest an easy day (zone-2 walk or mobility)."
        case .running, .cycling, .swimming:
            guard activity.durationMinutes >= 45 else { return nil }
            return isArabic
                ? "إذا ذكرت بكرة، اقترح كاردو خفيف أو راحة نشطة."
                : "If tomorrow comes up, suggest light cardio or active rest."
        default:
            return nil
        }
    }
}
