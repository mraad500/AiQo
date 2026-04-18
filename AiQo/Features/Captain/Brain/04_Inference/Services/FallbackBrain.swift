import Foundation

/// Fallback policy for when all AI services (cloud + local) fail.
///
/// Returns context-aware, localized responses based on intent detection.
/// Supports Arabic (Iraqi dialect) and English.
enum CaptainFallbackPolicy {

    // MARK: - Translation Unavailable (Arabic)

    static func translationUnavailableArabic(for rawMessage: String) -> String {
        let profile = triageProfile(for: rawMessage)

        return """
        الترجمة حالياً مو متاحة، فخلّيني أمشي وياك بخطة سريعة وآمنة.
        \(profile.question)
        خيارات سريعة:
        1) \(profile.options[0])
        2) \(profile.options[1])
        3) \(profile.options[2])
        """
    }

    // MARK: - English On-Device Fallback

    static func englishOnDeviceFallback(for rawMessage: String) -> String {
        let normalized = normalizedText(rawMessage)

        if containsAny(["hungry", "food", "meal", "diet"], in: normalized) {
            return NSLocalizedString(
                "captain.fallback.food",
                value: "On-device coaching is temporarily unavailable. Keep it simple: have water now and prep the easiest protein-first meal you can make in 10 minutes. What food do you have ready?",
                comment: ""
            )
        }

        if containsAny(["tired", "stress", "stressed", "overwhelmed", "burned out"], in: normalized) {
            return NSLocalizedString(
                "captain.fallback.stress",
                value: "On-device coaching is temporarily unavailable. Take a calm 3-minute reset, loosen your shoulders, and slow your breathing. Do you need recovery, focus, or a quick energy lift?",
                comment: ""
            )
        }

        if containsAny(["workout", "cardio", "run", "gym", "training"], in: normalized) {
            return NSLocalizedString(
                "captain.fallback.workout",
                value: "On-device coaching is temporarily unavailable. Start with a safe 5-minute warm-up and keep the first block easy. Do you want cardio, strength, or mobility?",
                comment: ""
            )
        }

        return NSLocalizedString(
            "captain.fallback.generic",
            value: "On-device coaching is temporarily unavailable. Do one safe reset now: water plus a 5-minute walk. What do you want to optimize first: food, training, or recovery?",
            comment: ""
        )
    }

    // MARK: - Arabic On-Device Fallback

    static func arabicOnDeviceFallback(
        for rawMessage: String,
        translatedFallback: String?
    ) -> String {
        if let translated = translatedFallback?.trimmingCharacters(in: .whitespacesAndNewlines),
           !translated.isEmpty {
            return translated
        }

        let profile = triageProfile(for: rawMessage)

        return """
        الذكاء على الجهاز مو متاح هسه، فراح أمشي وياك بخطوة آمنة وسريعة.
        \(profile.question)
        خيارات سريعة:
        1) \(profile.options[0])
        2) \(profile.options[1])
        3) \(profile.options[2])
        """
    }

    // MARK: - Network / Cloud Offline Messages

    /// Returned when BOTH cloud AND Apple Intelligence are unavailable.
    /// Written in colloquial Iraqi Arabic — warm, never robotic, never scary.
    static func networkErrorArabic() -> String {
        let options = [
            "عذراً! الشبكة عندي بيها مشكلة هسه وما كاعد اكدر اتصل بعقلي السحابي. جرّب مرة ثانية بعد شوية!",
            "أووف! يبدو الاتصال انقطع هسه. تحقق من النت وجرّب مرة ثانية، أكيد رح ارجع.",
            "ما وصلت للسيرفر هسه — الأرجح الشبكة متقطعة. تفقد اتصالك وكلمني ثانية!"
        ]
        return options.randomElement() ?? options[0]
    }

    /// English equivalent for users with the app language set to English.
    static func networkErrorEnglish() -> String {
        let options = [
            "Looks like I can't reach my cloud brain right now. Check your connection and try again in a moment!",
            "Network seems down — I couldn't connect to the server. Give it another shot when you're back online.",
            "Connection lost. Check your internet and try again — I'll be ready when you are."
        ]
        return options.randomElement() ?? options[0]
    }

    // MARK: - Generic Fallbacks (Final Safety Net)

    static func genericArabicFallback() -> String {
        let options = [
            "هلا! شنو تحتاج اليوم؟ تمرين، أكل، ولّا نحلل نومك؟",
            "حاضر. قوللي شنو هدفك وأساعدك.",
            "أنا هنا. شنو نسوّي اليوم؟",
            "أهلاً. شنو اللي يشغل بالك هسه؟",
            "يلا. قوللي شنو محتاج ونبدأ."
        ]
        return options.randomElement() ?? options[0]
    }

    static func genericEnglishFallback() -> String {
        let options = [
            "Hey! What's the goal today? Workout, meal plan, or sleep analysis?",
            "I'm here. Tell me what you need.",
            "Ready when you are. What are we working on?",
            "What's on your mind? I can help with training, food, or recovery.",
            "Talk to me. What do you want to tackle today?"
        ]
        return options.randomElement() ?? options[0]
    }

    // MARK: - Intent-Based Triage

    private static func triageProfile(for rawMessage: String) -> (question: String, options: [String]) {
        let normalized = normalizedText(rawMessage)
        let isHungry = containsAny(
            ["جوع", "جوعان", "أكل", "اكل", "وجبة", "hungry", "food", "meal", "diet"],
            in: normalized
        )
        let isTired = containsAny(
            ["تعبان", "مرهق", "نعسان", "tired", "exhausted", "sleepy"],
            in: normalized
        )
        let isStressed = containsAny(
            ["توتر", "مضغوط", "قلق", "stress", "stressed", "overwhelmed"],
            in: normalized
        )
        let isWorkout = containsAny(
            ["تمرين", "جيم", "كارديو", "workout", "cardio", "run", "gym"],
            in: normalized
        )

        if isHungry && isTired {
            return (
                "شنو متوفر يمك هسه؟ وكم دقيقة عندك؟",
                [
                    "سناك سريع جاهز + كوب مي",
                    "راحة 10 دقايق وبعدين وجبة خفيفة",
                    "قهوة خفيفة وبعدها نرتب أول وجبة"
                ]
            )
        }

        if isHungry {
            return (
                "شنو موجود بالمطبخ هسه: بروتين، خبز، لو فواكه؟",
                [
                    "سناك سريع من الموجود",
                    "وجبة خفيفة خلال 10 دقايق",
                    "مي أولاً وبعدها نحدد الوجبة"
                ]
            )
        }

        if isTired || isStressed {
            return (
                "تريد نركز على هدوء سريع لو طاقة خفيفة ترجعك للمود؟",
                [
                    "تنفّس + مي + جلوس هادئ",
                    "مشي خفيف 5 دقايق",
                    "تمطيط بسيط للرقبة والكتف"
                ]
            )
        }

        if isWorkout {
            return (
                "عندك 10 دقايق لو 20؟ وتريد كارديو لو قوة؟",
                [
                    "إحماء سريع + كارديو خفيف",
                    "إحماء + جولة جسم كامل",
                    "موبيلتي 5 دقايق وبعدين نقرر"
                ]
            )
        }

        return (
            "شنو أولويّتك هسه: أكل، طاقة، لو حركة؟",
            [
                "خطة سريعة للأكل",
                "استرجاع طاقة هادئ",
                "حركة خفيفة نبدأ بيها"
            ]
        )
    }

    private static func normalizedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func containsAny(_ terms: [String], in text: String) -> Bool {
        terms.contains { text.contains($0) }
    }
}
