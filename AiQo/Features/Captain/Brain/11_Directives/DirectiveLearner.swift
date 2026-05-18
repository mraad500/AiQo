import Foundation

/// On-device parser that turns a natural-language standing instruction into a
/// structured `LearnedDirectiveDraft`. No LLM, no network — deterministic and
/// instant, so it works in the chat path without adding latency or cost.
///
/// It is intentionally conservative: it only produces a draft when the message
/// carries BOTH a recurrence/standing signal ("after every", "بعد كل", "دائماً",
/// "from now on", "كل مرة") AND a recognizable trigger domain AND an action
/// verb. A one-off "حلل تمريني" (analyze my workout *now*) must NOT create a
/// standing rule — only "بعد كل تمرين حلل تمريني" does.
enum DirectiveLearner {

    // MARK: - Markers (APPEND-ONLY)

    /// Recurrence / "make this a standing rule" framing.
    nonisolated private static let recurrenceMarkers: [String] = [
        // Arabic / Iraqi
        "بعد كل", "كل ما", "كل مره", "كل مرة", "كلما", "دائما", "دوما",
        "من اليوم", "من اليوم وجاي", "من الان", "من الان وجاي", "من هسه",
        "صارت عاده", "خليها عاده", "اريدك دائما", "تذكر دائما", "لا تنسه",
        "لا تنسى", "ثبتها", "خليها قاعده", "اعتمدها",
        // English
        "after every", "after each", "every time", "each time", "everytime",
        "always", "from now on", "whenever", "make it a habit", "remember to",
        "going forward", "from today"
    ]

    /// Workout / training domain → `.afterWorkout`.
    nonisolated private static let workoutMarkers: [String] = [
        "تمرين", "تمريني", "اتمرن", "تمرن", "تمارين", "رياضه", "رياضة",
        "جيم", "كارديو", "ركض", "جري", "مشي", "سباحه", "سباحة", "ملاكمه",
        "workout", "training", "exercise", "gym", "cardio", "run", "session"
    ]

    /// Bedtime domain → `.beforeBedtime`.
    nonisolated private static let bedtimeMarkers: [String] = [
        "قبل النوم", "وقت النوم", "قبل ما انام", "before bed", "before sleep", "bedtime"
    ]

    /// Poor-sleep domain → `.afterPoorSleep`.
    nonisolated private static let poorSleepMarkers: [String] = [
        "نوم قليل", "ما نمت زين", "نومي قليل", "قلة نوم", "poor sleep", "bad sleep", "slept badly"
    ]

    /// Morning domain → `.everyMorning`.
    nonisolated private static let morningMarkers: [String] = [
        "كل صباح", "بالصبح", "الصبح", "كل يوم الصبح", "every morning", "each morning", "in the morning"
    ]

    /// Weekly domain → `.weeklyReview`.
    nonisolated private static let weeklyMarkers: [String] = [
        "كل اسبوع", "نهايه الاسبوع", "نهاية الاسبوع", "مراجعه اسبوعيه", "every week", "weekly", "end of week"
    ]

    /// Analyze + compare-to-previous → `.analyzeAndCompareWorkout`.
    nonisolated private static let analyzeCompareMarkers: [String] = [
        "حلل", "تحليل", "حللي", "قارن", "قارنه", "قارني", "مقارنه", "مقارنة",
        "الي قبله", "اللي قبله", "السابق", "بالسابق", "الماضي", "السابقه",
        "analyze", "analyse", "compare", "comparison", "versus", "vs", "against", "previous", "last one"
    ]

    /// Notify / remind verbs (any reminder, when there's no analyze+compare).
    nonisolated private static let notifyMarkers: [String] = [
        "دزلي", "دز لي", "ابعتلي", "ابعث لي", "ذكرني", "تذكير", "اشعار", "نبهني", "خبرني",
        "notify", "remind", "send me", "ping me", "alert me", "message me"
    ]

    // MARK: - Public API

    /// Returns a draft if `message` teaches a standing instruction, else nil.
    nonisolated static func detect(from message: String) -> LearnedDirectiveDraft? {
        let raw = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.count >= 8 else { return nil }

        let norm = normalize(raw)

        // 1. Must be framed as a standing/recurring rule.
        guard containsAny(norm, recurrenceMarkers) else { return nil }

        // 2. Must carry an explicit action (notify/remind or analyze/compare).
        let wantsAnalyzeCompare = containsAny(norm, analyzeCompareMarkers)
        let wantsNotify = containsAny(norm, notifyMarkers)
        guard wantsAnalyzeCompare || wantsNotify else { return nil }

        // 3. Resolve the trigger domain.
        guard let trigger = resolveTrigger(norm) else { return nil }

        let localeCode = containsArabic(raw) ? "ar" : "en"

        // 4. Resolve the action. Analyze+compare only makes sense for workouts;
        //    it takes precedence over a plain notify when both are present.
        let action: DirectiveAction
        var params: [String: String] = [:]
        if wantsAnalyzeCompare && trigger == .afterWorkout {
            action = .analyzeAndCompareWorkout
        } else {
            action = .notify
            params["text"] = raw
        }

        return LearnedDirectiveDraft(
            rawInstruction: raw,
            trigger: trigger,
            action: action,
            params: params,
            localeCode: localeCode
        )
    }

    // MARK: - Trigger resolution

    nonisolated private static func resolveTrigger(_ norm: String) -> DirectiveTrigger? {
        // Most specific first.
        if containsAny(norm, poorSleepMarkers) { return .afterPoorSleep }
        if containsAny(norm, bedtimeMarkers) { return .beforeBedtime }
        if containsAny(norm, weeklyMarkers) { return .weeklyReview }
        if containsAny(norm, workoutMarkers) { return .afterWorkout }
        if containsAny(norm, morningMarkers) { return .everyMorning }
        return nil
    }

    // MARK: - Text helpers

    /// Diacritic-insensitive, Arabic-form-normalized lowercasing. Mirrors the
    /// normalization used elsewhere (e.g. `SpotifyRecommendation.normalizedSignal`)
    /// so "أ/إ/آ"→"ا" and "ة"→"ه" variants all match.
    nonisolated private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ة", with: "ه")
            .replacingOccurrences(of: "ـ", with: "")
            .replacingOccurrences(of: "ى", with: "ي")
    }

    nonisolated private static func containsAny(_ text: String, _ markers: [String]) -> Bool {
        markers.contains { marker in
            text.contains(
                marker.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            )
        }
    }

    nonisolated private static func containsArabic(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0600...0x06FF, 0x0750...0x077F, 0x08A0...0x08FF, 0xFB50...0xFDFF, 0xFE70...0xFEFF:
                return true
            default:
                return false
            }
        }
    }
}
