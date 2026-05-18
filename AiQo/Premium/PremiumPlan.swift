import Foundation

enum PremiumPlan: String, CaseIterable, Identifiable {
    case core
    case intelligencePro

    var id: String { rawValue }

    var canonicalProductID: String {
        switch self {
        case .core:
            return SubscriptionProductIDs.coreMonthly
        case .intelligencePro:
            return SubscriptionProductIDs.intelligenceProMonthly
        }
    }

    var title: String {
        switch self {
        case .core:
            return "AiQo Max"
        case .intelligencePro:
            return "AiQo Intelligence Pro"
        }
    }

    var description: String {
        switch self {
        case .core:
            return localized(
                ar: "الأساس اليومي في AiQo: سرعة أعلى، الكابتن الأساسي، Gym، Kitchen، My Vibe، التحديات، والتتبع الكامل.",
                en: "The daily AiQo foundation: faster responses, basic Captain, Gym, Kitchen, My Vibe, challenges, and full lifestyle tracking."
            )
        case .intelligencePro:
            return localized(
                ar: "كل ما في AiQo Max مع القمم، ذاكرة ممتدة للكابتن، وتوجيه AI تحليلي أعمق.",
                en: "Everything in AiQo Max plus Peaks, expanded Captain memory, and deeper analytical AI guidance."
            )
        }
    }

    static func fromStoredValue(_ value: String) -> PremiumPlan? {
        switch value {
        case "standard", "core", "individual":
            return .core
        case "pro":
            return .intelligencePro
        case "intelligencePro", "intelligence", "family":
            return .intelligencePro
        default:
            return PremiumPlan(rawValue: value)
        }
    }

    private func localized(ar: String, en: String) -> String {
        let isArabic = Locale.current.language.languageCode?.identifier == "ar"
        return isArabic ? ar : en
    }
}
