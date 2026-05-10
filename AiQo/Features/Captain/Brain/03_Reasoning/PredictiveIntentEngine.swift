// ===============================================
// File: PredictiveIntentEngine.swift
// Brain Refactor §45 — Anticipating the Next Question
//
// World-class coaches stay one step ahead — when an athlete asks "how was my
// session?", the coach already knows the next two questions ("should I eat?"
// "what about tomorrow?") and primes the answer to set them up. This file
// gives the Captain the same skill.
//
// Given the *current* turn's intent + emotion + activity context, we predict
// the most likely follow-up topic and emit a one-line *priming hint* the
// brief renders. The model is told "if your reply naturally sets up Z, add
// a hook for it — but don't answer Z now."
//
// Predictions are conservative — wrong predictions feel weird. We only fire
// when the signal is strong (≥ 0.65 confidence).
// ===============================================

import Foundation

// MARK: - Topics

/// What the user is most likely to ask next. Each topic carries its own
/// priming hint that the brief surfaces.
enum PredictedTopic: String, Sendable {
    /// "What should I do now / next?" — fires after a fresh workout.
    case nextStepGuidance
    /// "Is this enough?" / "Am I on track?" — fires for goal-progress turns.
    case progressAssessment
    /// "What should I eat?" — fires after a calorie-heavy session.
    case nutritionAfterEffort
    /// "Should I sleep more / earlier?" — fires when fatigue signals are up.
    case sleepConcern
    /// "What's tomorrow look like?" — fires after a heavy or end-of-day turn.
    case planTomorrow
    /// "Am I doing it right?" — fires for technique / form questions.
    case formCorrection
    /// "How long until I hit X?" — fires for active-project turns.
    case timelineEstimate
}

struct PredictedFollowUp: Sendable {
    let topic: PredictedTopic
    let confidence: Double
    let primingHintArabic: String
    let primingHintEnglish: String

    func primingHint(language: AppLanguage) -> String {
        language == .arabic ? primingHintArabic : primingHintEnglish
    }
}

// MARK: - Engine

@MainActor
enum PredictiveIntentEngine {

    /// Confidence floor — predictions below this are dropped to avoid
    /// pre-empting questions the user wasn't going to ask.
    static let minimumConfidence: Double = 0.65

    /// Walks a small priority cascade. The first rule whose preconditions
    /// match wins. Returns `nil` when nothing scores high enough.
    ///
    /// Brain §50 — `hrMood` participates in the cascade so a stressed body
    /// short-circuits the planning predictions ("what's tomorrow?" is wrong
    /// when the user needs grounding). Stays additive — no removed branches.
    static func anticipate(
        currentIntent: CaptainMessageIntent,
        emotionalSignal: CaptainEmotionalSignal,
        recentActivity: RecentActivitySnapshot?,
        sleepHoursLastNight: Double,
        hour: Int,
        coherence: ConversationContextTags?,
        behavioralStage: BehavioralStageReading?,
        hrMood: HRMoodReading = .unknown
    ) -> PredictedFollowUp? {

        // §50 priority — physiological stress shifts the predicted follow-up
        // toward sleep/recovery rather than planning. Only when HR confidence
        // is decent so we don't over-fire on missing data.
        if hrMood.hasSignal, hrMood.confidence >= 0.7 {
            switch hrMood.mood {
            case .stressed:
                return PredictedFollowUp(
                    topic: .sleepConcern,
                    confidence: 0.8,
                    primingHintArabic: "النبض مرتفع والسياق توتر — السؤال القادم على الأرجح عن النوم/الراحة. هيّئ ردك بإشارة هادية بدل خطة طويلة",
                    primingHintEnglish: "Elevated HR with stress signature — next question likely about rest/sleep. Prime with a calming cue, not a long plan"
                )
            case .windingDown:
                return PredictedFollowUp(
                    topic: .sleepConcern,
                    confidence: 0.75,
                    primingHintArabic: "النبض هابط ووقت متأخر — السؤال القادم عن النوم. اختم باقتراح روتين قبل النوم",
                    primingHintEnglish: "Dropping HR + late hour — next question about sleep. End with a wind-down cue"
                )
            case .postEffort:
                return PredictedFollowUp(
                    topic: .nutritionAfterEffort,
                    confidence: 0.85,
                    primingHintArabic: "نبضه مرفوع بعد جهد — أكيد جاي يسأل عن الأكل/الترطيب. تكدر تختم بإشارة سريعة",
                    primingHintEnglish: "Post-effort elevated HR — food/hydration question is next. Prime with a quick cue"
                )
            case .relaxed, .focused, .excited, .unknown:
                break  // fall through to text-based cascade
            }
        }

        // 1) Fresh activity → user almost always asks "what next?" or
        //    "what about food?" within a few turns. Pick the more likely
        //    of the two based on activity intensity (longer/harder ⇒ food).
        if let activity = recentActivity, activity.freshness == .veryFresh {
            let isHighIntensity = activity.activeCalories >= 250
                || activity.durationMinutes >= 40
            if isHighIntensity {
                return PredictedFollowUp(
                    topic: .nutritionAfterEffort,
                    confidence: 0.8,
                    primingHintArabic: "بعد التمرين القوي عادة المستخدم يسأل عن الأكل — لو ردك ما زال قصير، تكدر تختمه بإشارة سريعة لتعويض البروتين/الكاربس",
                    primingHintEnglish: "Users often ask about food after a hard session — if your reply has room, end with a brief protein/carb cue"
                )
            } else {
                return PredictedFollowUp(
                    topic: .nextStepGuidance,
                    confidence: 0.75,
                    primingHintArabic: "بعد جلسة خفيفة عادة يسأل 'شنو نسوي بعد' — تكدر تختمه باقتراح مكمل (إطالة، ماء)",
                    primingHintEnglish: "After a light session users ask 'what next' — end with a complementary cue (stretch, water)"
                )
            }
        }

        // 2) Tired emotion + late hour → next question is usually about sleep.
        if emotionalSignal == .tired, hour >= 19 {
            return PredictedFollowUp(
                topic: .sleepConcern,
                confidence: 0.75,
                primingHintArabic: "عادة بعد 'تعبت' بساعات الليل يجي سؤال عن النوم — لو ناسب، اختم بحدّ نوم مبكر",
                primingHintEnglish: "After fatigue late in the day, users ask about sleep — if it fits, end with an early-bed cue"
            )
        }

        // 3) Low recent sleep + morning → user is likely to ask about energy
        //    or training. Prime a "today should be lighter" hook.
        if sleepHoursLastNight > 0, sleepHoursLastNight < 6.0, hour < 12 {
            return PredictedFollowUp(
                topic: .planTomorrow,
                confidence: 0.7,
                primingHintArabic: "نومه أمس قليل — عادة الصباح يسأل عن خطة اليوم. مَيِّل لاقتراح يوم أخف من المعتاد",
                primingHintEnglish: "Low sleep last night — they often ask about the day's plan. Bias toward a lighter day than usual"
            )
        }

        // 4) Active record project → frequent "how long until..." questions.
        if currentIntent == .challenge {
            return PredictedFollowUp(
                topic: .timelineEstimate,
                confidence: 0.7,
                primingHintArabic: "بمحادثات التحديات يكثر سؤال 'متى أوصل' — جاوب اللحين، وإذا ناسب اختم بإشارة عن الجدول الأسبوعي",
                primingHintEnglish: "Challenge conversations often surface 'when will I get there' — answer now, optionally end with a weekly-cadence cue"
            )
        }

        // 5) Workout intent + no fresh activity = setup question. Next is
        //    almost always "am I doing it right?" or "set count details."
        if currentIntent == .workout, recentActivity == nil {
            return PredictedFollowUp(
                topic: .formCorrection,
                confidence: 0.65,
                primingHintArabic: "أسئلة التمرين بلا تمرين توّه عادة تتبعها أسئلة عن الأداء/الدقة — رد بدقة عددية إذا نفع",
                primingHintEnglish: "Workout questions with no fresh session often lead to form/accuracy follow-ups — answer with concrete numbers when possible"
            )
        }

        // 6) Preparation stage → frequent "is this enough?" check-ins.
        if behavioralStage?.stage == .preparation {
            return PredictedFollowUp(
                topic: .progressAssessment,
                confidence: 0.65,
                primingHintArabic: "بمرحلة التحضير المستخدم يسأل كثير 'هذا كافي؟' — أكّد إن أي بداية كافية، ولا تشد عليه",
                primingHintEnglish: "Preparation-stage users often ask 'is this enough?' — affirm that any start counts; don't push"
            )
        }

        return nil
    }
}
