import Foundation

/// Turns INDEPENDENT per-metric trends into CORRELATED, speakable insights.
///
/// `TrendAnalyzer` computes steps / sleep / workout / heart-rate trends in
/// isolation, and `PromptComposer.layerBioState` dumps them as separate lines.
/// Gemini is then left to infer correlation from scattered numbers and usually
/// doesn't ("connect the dots" was the explicit ask). This synthesizer runs a
/// few deterministic on-device rules over the snapshot + emotional state and
/// emits at most two natural-language "this is linked to that" lines that the
/// Captain can weave into the reply.
///
/// Lines are internal coaching directives (same spirit as the emotional block
/// already in `layerBioState`): the model uses the *connection*, never quotes
/// the raw percentages.
struct TrendInsightSynthesizer: Sendable {

    static func insights(
        from trend: TrendSnapshot,
        emotional: EmotionalState?,
        language: AppLanguage
    ) -> [String] {
        let ar = language != .english
        var out: [String] = []

        // 1) Sleep ↓ + training ↓ — strongest actionable correlation. Fixing
        //    sleep tends to pull training back up, so anchor on sleep.
        if trend.sleepTrend == .declining && trend.workoutFrequencyTrend == .declining {
            out.append(ar
                ? "النوم والتمرين الاثنين نازلين نفس الفترة — مترابطين. ركّز على إرجاع النوم أول، التمرين راح يلحقه. لا تعطيه خطة ثقيلة هسة."
                : "Sleep and training are both down in the same window — they're linked. Anchor on restoring sleep first; training tends to follow. Don't pitch a heavy plan now.")
        }
        // 2) Sleep ↓ + steps ↓ (and not already covered by rule 1) — fatigue loop.
        else if trend.sleepTrend == .declining && trend.stepsTrend == .declining {
            out.append(ar
                ? "النوم والحركة الاثنين نازلين — دورة تعب تغذّي نفسها. اقترح رافعة وحدة صغيرة (نوم أبكر ربع ساعة) تكسر الدورة، مو تغيير شامل."
                : "Sleep and movement are both sliding — a self-feeding fatigue loop. Suggest one small lever (15 min earlier sleep) to break it, not a full overhaul.")
        }

        // 3) Stress + sleep ↓ — this is a recovery window, not a push window.
        if let mood = emotional?.estimatedMood,
           mood == .stressed,
           trend.sleepTrend == .declining {
            out.append(ar
                ? "ضغط نفسي مع نوم نازل — هسة وقت استشفاء مو وقت ضغط. ليّن الشدّة بالرد وخفّف أي مطالبة كبيرة."
                : "Stress alongside declining sleep — this is a recovery window, not a push window. Soften intensity and avoid any big ask.")
        }

        // 4) Training ↑ + resting HR improving — real adaptation worth naming.
        if trend.workoutFrequencyTrend == .improving && trend.heartRateTrend == .improving {
            out.append(ar
                ? "التمرين كاعد ينطي ثمرة فعلية — نبض الراحة يتحسّن مع زيادة التمرين. اربط التحسّن بمجهوده عشان يثبت العادة."
                : "Training is producing real adaptation — resting heart rate is improving as workouts rise. Tie the gain back to their effort so the habit sticks.")
        }

        // 5) Low consistency + broken/breaking streak — momentum at risk.
        if trend.consistencyScore < 0.4 &&
            (trend.streakMomentum == .breaking || trend.streakMomentum == .broken) {
            out.append(ar
                ? "الالتزام ضعيف والسلسلة تكسّرت — لا تعرض خطة كبيرة، فقط فعل صغير واحد اليوم يرجّع الزخم."
                : "Consistency is low and the streak broke — don't offer a big plan, just one small action today to restart momentum.")
        }

        return Array(out.prefix(2))
    }
}
