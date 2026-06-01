import Foundation

/// The "genius coach" layer. A reactive bot answers the literal question; a
/// genius coach first forms a THESIS: given the user's stated goal vs. their
/// current reality (trends + mood + what they're asking), what is the ONE
/// thing that actually matters right now?
///
/// `TrendInsightSynthesizer` connects metric↔metric ("sleep ↓ + training ↓").
/// This connects GOAL↔reality and emits a single strategic directive the
/// Captain leads with — so the reply feels like a coach who sees the whole
/// picture, not a Q&A endpoint. Deterministic, on-device, one line max.
struct CoachingThesisSynthesizer: Sendable {

    enum CoachGoal {
        case loseWeight, gainWeight, cutFat, buildMuscle, improveFitness

        /// Parses the canonical English goal text written into the profile
        /// summary by `CognitivePipeline` (`CaptainPrimaryGoal.canonicalGoalText`).
        static func parse(_ text: String?) -> CoachGoal? {
            guard let t = text?.lowercased() else { return nil }
            if t.contains("cut fat") { return .cutFat }
            if t.contains("lose weight") { return .loseWeight }
            if t.contains("gain weight") { return .gainWeight }
            if t.contains("build muscle") { return .buildMuscle }
            if t.contains("improve fitness") { return .improveFitness }
            return nil
        }

        func label(arabic: Bool) -> String {
            switch self {
            case .loseWeight:     return arabic ? "تنزيل الوزن" : "weight loss"
            case .gainWeight:     return arabic ? "زيادة الوزن" : "weight gain"
            case .cutFat:         return arabic ? "تنشيف الدهون" : "fat loss"
            case .buildMuscle:    return arabic ? "بناء العضل" : "muscle gain"
            case .improveFitness: return arabic ? "رفع اللياقة" : "fitness"
            }
        }
    }

    static func thesis(
        goalText: String?,
        trend: TrendSnapshot?,
        emotional: EmotionalState?,
        intentSummary: String,
        language: AppLanguage
    ) -> String? {
        let ar = language != .english
        let goal = CoachGoal.parse(goalText)

        // 1) Human state first: stress overrides goal-chasing.
        if emotional?.estimatedMood == .stressed {
            let g = goal?.label(arabic: ar)
            if ar {
                return "حالته مضغوطة" + (g.map { " وهدفه \($0)" } ?? "")
                    + " — لا تحمّله خطة كبيرة اليوم. فعل واحد صغير يخدم الهدف ويخفّف الضغط، ونبرة هادئة."
            }
            return "User is stressed" + (g.map { " (goal: \($0))" } ?? "")
                + " — don't load a big plan today. One small goal-serving action and a calm tone."
        }

        guard let goal else {
            // No declared goal and no stress signal → nothing high-signal.
            return nil
        }

        let sleepDown = trend?.sleepTrend == .declining
        let workoutDown = trend?.workoutFrequencyTrend == .declining
        let stepsDown = trend?.stepsTrend == .declining
        let workoutUp = trend?.workoutFrequencyTrend == .improving
        let hrUp = trend?.heartRateTrend == .improving
        let intentNutrition = intentSummary.contains("nutrition_guidance")

        // 2) Fat-loss / weight-loss but training is slipping → the honest
        //    lever is consistency, not a fancier program.
        if (goal == .cutFat || goal == .loseWeight) && workoutDown {
            return ar
                ? "هدفه \(goal.label(arabic: true)) بس تكرار تمرينه نازل — الرافعة الحقيقية الالتزام والثبات، مو خطة أعقد. وجّهه بمحاسبة لطيفة على الاستمرارية."
                : "Goal is \(goal.label(arabic: false)) but training frequency is dropping — the real lever is consistency, not a more complex plan. Nudge gentle accountability."
        }

        // 3) Muscle / weight gain but sleep is slipping → growth is in recovery.
        if (goal == .buildMuscle || goal == .gainWeight) && sleepDown {
            return ar
                ? "هدفه \(goal.label(arabic: true)) بس النوم نازل — العضلة تُبنى بالاستشفاء مو بالتمرين بروحه. وجّهه للنوم بدون ما تلح أو تحاضر."
                : "Goal is \(goal.label(arabic: false)) but sleep is declining — muscle is built in recovery, not training alone. Steer toward sleep without nagging."
        }

        // 4) Fat-loss, movement down, asking about food → nutrition is now the
        //    dominant lever (deficit can't lean on activity this week).
        if (goal == .cutFat || goal == .loseWeight) && stepsDown && intentNutrition {
            return ar
                ? "هدفه \(goal.label(arabic: true)) وحركته نازلة، فالعجز هاأسبوع يعتمد على الأكل أكثر من الحركة — خل نصيحته الغذائية دقيقة وحاسمة."
                : "Goal is \(goal.label(arabic: false)) and movement is down, so this week's deficit leans on food more than activity — make the nutrition guidance precise and decisive."
        }

        // 5) Fitness goal and it's genuinely working → reinforce the identity.
        if goal == .improveFitness && workoutUp && hrUp {
            return ar
                ? "لياقته تتحسّن فعلياً (تمرين أكثر ونبض راحة ينزل) — اربط التحسّن بمجهوده بثقة، هذا وقت ترسيخ الهوية مو وقت تغيير."
                : "Fitness is genuinely improving (more training, resting HR dropping) — tie the gain to their effort confidently; this is a moment to cement identity, not change course."
        }

        // 6) Goal known, no strong trend signal → still always anchor to it.
        return ar
            ? "هدفه الأساسي \(goal.label(arabic: true)) — خل ردك يخدم هالهدف ولو السؤال جانبي، واربط الجواب بالهدف بسطر واحد طبيعي."
            : "Primary goal is \(goal.label(arabic: false)) — make the reply serve it even if the question is tangential; tie the answer back to the goal in one natural line."
    }
}
