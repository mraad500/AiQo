import Foundation

/// Culturally rooted reflections used sparingly for the right moments.
enum WisdomLibrary {

    struct Wisdom: Sendable {
        let text: String
        let attribution: String?
        let kind: Kind

        enum Kind: String, Sendable {
            case arabicProverb
            case iraqi
            case gulf
            case hadith
            case modern
        }
    }

    nonisolated static func appropriate(
        emotion: EmotionalReading,
        cultural: CulturalContextEngine.State
    ) -> Wisdom? {
        if emotion.primary == .grief {
            return nil
        }
        if emotion.intensity > 0.8 {
            return nil
        }

        if cultural.isJumuah && cultural.timeOfDay == .midday {
            return bank.randomElement { $0.kind == .arabicProverb || $0.kind == .iraqi }
        }

        if emotion.trend == .declining {
            return bank.randomElement { $0.kind == .iraqi || $0.kind == .modern }
        }

        if Int.random(in: 1...10) == 1 {
            return bank.randomElement { $0.kind == .arabicProverb || $0.kind == .modern }
        }

        return nil
    }

    nonisolated private static let bank: [Wisdom] = [
        Wisdom(
            text: "الصبر مفتاح الفرج",
            attribution: "مثل عربي",
            kind: .arabicProverb
        ),
        Wisdom(
            text: "اللي يطول باله على سكرة، يشوف حلاها",
            attribution: "مثل عراقي",
            kind: .iraqi
        ),
        Wisdom(
            text: "الوقت من ذهب",
            attribution: "مثل عربي",
            kind: .arabicProverb
        ),
        Wisdom(
            text: "خطوة صغيرة اليوم، مسافة طويلة بعد سنة",
            attribution: nil,
            kind: .modern
        ),
        Wisdom(
            text: "اللي يصبر، ينول",
            attribution: "مثل عراقي",
            kind: .iraqi
        ),
        Wisdom(
            text: "الراحة نصف العلاج",
            attribution: nil,
            kind: .modern
        ),
        Wisdom(
            text: "الجبال ما تتحرك بيوم، بس تبدأ بخطوة",
            attribution: nil,
            kind: .modern
        ),
        Wisdom(
            text: "تمهل تدرك ما تطلبه",
            attribution: "مثل عربي",
            kind: .arabicProverb
        )
    ]
}

private extension Array {
    nonisolated func randomElement(where predicate: (Element) -> Bool) -> Element? {
        let matches = filter(predicate)
        return matches.randomElement()
    }
}
