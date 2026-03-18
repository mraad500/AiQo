import Foundation

// MARK: - Legendary Challenge Record

struct LegendaryRecord: Identifiable, Codable, Hashable {
    let id: String
    let titleAr: String
    let targetValue: Double
    let unit: String
    let recordHolderAr: String
    let country: String
    let year: Int
    let category: ChallengeCategory
    let difficulty: ChallengeDifficulty
    let estimatedWeeks: Int
    let storyAr: String
    let requirementsAr: [String]
    let iconName: String
}

// MARK: - Category

enum ChallengeCategory: String, Codable, CaseIterable {
    case strength = "قوة"
    case cardio = "كارديو"
    case endurance = "تحمّل"
    case clarity = "صفاء"
}

// MARK: - Difficulty

enum ChallengeDifficulty: Int, Codable {
    case beginner = 1
    case advanced = 2
    case legendary = 3

    var labelAr: String {
        switch self {
        case .beginner: return "مبتدئ"
        case .advanced: return "متقدم"
        case .legendary: return "أسطوري"
        }
    }
}

// MARK: - Seed Data

extension LegendaryRecord {
    static let seedRecords: [LegendaryRecord] = [
        LegendaryRecord(
            id: "pushup_1min",
            titleAr: "أكثر ضغط بدقيقة",
            targetValue: 152,
            unit: "مرة",
            recordHolderAr: "كوجي إيتشيهارا",
            country: "🇯🇵",
            year: 2024,
            category: .strength,
            difficulty: .legendary,
            estimatedWeeks: 16,
            storyAr: "سجّل كوجي إيتشيهارا هذا الرقم القياسي بتنفيذ 152 تمرين ضغط كامل خلال 60 ثانية فقط. يتطلب سرعة انفجارية وتحمّل عضلي استثنائي.",
            requirementsAr: ["لا تحتاج معدات", "مؤقت دقيقة واحدة", "سطح مستوٍ"],
            iconName: "figure.strengthtraining.traditional"
        ),
        LegendaryRecord(
            id: "plank_hold",
            titleAr: "أطول بلانك متواصل",
            targetValue: 9.5,
            unit: "ساعة",
            recordHolderAr: "دانيال سكالي",
            country: "🇨🇿",
            year: 2024,
            category: .endurance,
            difficulty: .legendary,
            estimatedWeeks: 24,
            storyAr: "دانيال سكالي ثبت بوضعية البلانك لمدة تجاوزت 9 ساعات ونصف. تحدّي يتطلب قوة جذع خارقة وتركيز ذهني عميق.",
            requirementsAr: ["لا تحتاج معدات", "سطح مريح", "ساعة Apple Watch مُفضّلة"],
            iconName: "figure.core.training"
        ),
        LegendaryRecord(
            id: "squats_1min",
            titleAr: "أكثر سكوات بدقيقة",
            targetValue: 70,
            unit: "مرة",
            recordHolderAr: "سلطان المرشدي",
            country: "🇰🇼",
            year: 2023,
            category: .strength,
            difficulty: .advanced,
            estimatedWeeks: 10,
            storyAr: "رقم قياسي عربي مسجّل بـ70 سكوات كاملة بدقيقة واحدة. يحتاج تناسق بين السرعة والعمق.",
            requirementsAr: ["لا تحتاج معدات", "مؤقت دقيقة واحدة"],
            iconName: "figure.squat"
        ),
        LegendaryRecord(
            id: "walk_24h",
            titleAr: "أطول مسافة مشي بـ24 ساعة",
            targetValue: 228.93,
            unit: "كم",
            recordHolderAr: "جيسي كاستاندا",
            country: "🇺🇸",
            year: 2024,
            category: .cardio,
            difficulty: .legendary,
            estimatedWeeks: 20,
            storyAr: "جيسي كاستاندا مشى أكثر من 228 كيلومتر خلال 24 ساعة متواصلة. يحتاج بناء قاعدة تحمّل ضخمة وتغذية مدروسة أثناء المشي.",
            requirementsAr: ["حذاء مشي مريح", "Apple Watch", "خطة تغذية"],
            iconName: "figure.walk"
        ),
        LegendaryRecord(
            id: "burpees_1min",
            titleAr: "أكثر بيربي بدقيقة",
            targetValue: 48,
            unit: "مرة",
            recordHolderAr: "نيك أناستاسيو",
            country: "🇺🇸",
            year: 2023,
            category: .cardio,
            difficulty: .advanced,
            estimatedWeeks: 12,
            storyAr: "48 بيربي كاملة بدقيقة واحدة — كل واحدة تشمل نزول، ضغطة، قفز، وتصفيقة فوق الرأس. اختبار حقيقي لللياقة الشاملة.",
            requirementsAr: ["لا تحتاج معدات", "مساحة واسعة", "مؤقت"],
            iconName: "figure.highintensity.intervaltraining"
        ),
        LegendaryRecord(
            id: "pullups_1min",
            titleAr: "أكثر عقلة بدقيقة",
            targetValue: 62,
            unit: "مرة",
            recordHolderAr: "مايكل إيكارد",
            country: "🇺🇸",
            year: 2023,
            category: .strength,
            difficulty: .legendary,
            estimatedWeeks: 16,
            storyAr: "62 عقلة كاملة بقبضة عادية خلال 60 ثانية. يحتاج قوة ظهر وذراعين استثنائية مع إيقاع سريع ومنضبط.",
            requirementsAr: ["بار عقلة", "مؤقت"],
            iconName: "figure.climbing"
        ),
        LegendaryRecord(
            id: "breath_hold",
            titleAr: "أطول حبس نَفَس تحت الماء",
            targetValue: 24.37,
            unit: "دقيقة",
            recordHolderAr: "بوديمير شوبات",
            country: "🇭🇷",
            year: 2021,
            category: .clarity,
            difficulty: .legendary,
            estimatedWeeks: 12,
            storyAr: "بوديمير شوبات حبس نفسه لأكثر من 24 دقيقة تحت الماء. تحدّي يعتمد على تمارين التنفس العميق والتأمّل والتحكم بنبض القلب.",
            requirementsAr: ["تمارين التنفس يومياً", "إشراف متخصص مُوصى به"],
            iconName: "wind"
        ),
        LegendaryRecord(
            id: "steps_24h",
            titleAr: "أكثر خطوات بـ24 ساعة",
            targetValue: 210_000,
            unit: "خطوة",
            recordHolderAr: "ستيفن واتكينز",
            country: "🇬🇧",
            year: 2023,
            category: .cardio,
            difficulty: .legendary,
            estimatedWeeks: 16,
            storyAr: "أكثر من 210 ألف خطوة خلال 24 ساعة — يعني تقريباً 150 كيلومتر مشي متواصل. يتطلب بناء قاعدة مشي قوية على مدى أشهر.",
            requirementsAr: ["Apple Watch", "حذاء مريح", "خطة تغذية وترطيب"],
            iconName: "shoeprints.fill"
        ),
    ]

    /// Formatted target value for display (e.g. "152" or "9.5" or "210,000")
    var formattedTarget: String {
        if targetValue == targetValue.rounded() && targetValue < 1_000 {
            return String(format: "%.0f", targetValue)
        } else if targetValue >= 1_000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = Locale(identifier: "ar")
            return formatter.string(from: NSNumber(value: targetValue)) ?? "\(targetValue)"
        } else {
            return String(format: "%.1f", targetValue)
        }
    }
}
