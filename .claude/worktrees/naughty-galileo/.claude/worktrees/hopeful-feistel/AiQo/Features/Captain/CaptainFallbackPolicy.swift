import Foundation

enum CaptainFallbackPolicy {
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

    static func englishOnDeviceFallback(for rawMessage: String) -> String {
        let normalized = normalizedText(rawMessage)

        if containsAny(["hungry", "food", "meal", "diet"], in: normalized) {
            return "On-device coaching is temporarily unavailable. Keep it simple and safe: have water now and prep the easiest protein-first meal you can make in 10 minutes. What food do you already have ready?"
        }

        if containsAny(["tired", "stress", "stressed", "overwhelmed", "burned out"], in: normalized) {
            return "On-device coaching is temporarily unavailable. Take a calm 3-minute reset, loosen your shoulders, and slow your breathing. Do you need recovery, focus, or a quick energy lift?"
        }

        if containsAny(["workout", "cardio", "run", "gym", "training"], in: normalized) {
            return "On-device coaching is temporarily unavailable. Start with a safe 5-minute warm-up and keep the first block easy. Do you want cardio, strength, or mobility?"
        }

        return "On-device coaching is temporarily unavailable. Do one safe reset now: water plus a 5-minute walk. What do you want to optimize first: food, training, or recovery?"
    }

    static func arabicOnDeviceFallback(
        for rawMessage: String,
        translatedFallback: String?
    ) -> String {
        let normalizedTranslation = translatedFallback?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let normalizedTranslation, !normalizedTranslation.isEmpty {
            return normalizedTranslation
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
