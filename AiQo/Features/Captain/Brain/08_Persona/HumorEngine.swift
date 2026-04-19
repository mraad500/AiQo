import Foundation

/// Decides when humor is appropriate and how playful the Captain can be.
/// Rule: warmth always wins over wit.
enum HumorEngine {

    enum Intensity: String, Sendable {
        case off
        case subtle
        case light
        case playful
    }

    static func intensity(
        emotion: EmotionalReading,
        cultural: CulturalContextEngine.State
    ) -> Intensity {
        if emotion.primary == .grief || emotion.primary == .shame {
            return .off
        }
        if emotion.intensity > 0.7 && emotion.trend == .declining {
            return .off
        }

        if cultural.isFastingHour {
            return .subtle
        }
        if cultural.isEid == .eidFitr || cultural.isEid == .eidAdha {
            return .playful
        }

        if emotion.primary == .joy && emotion.intensity > 0.6 {
            return .playful
        }
        if emotion.trend == .stable {
            return .light
        }

        return .subtle
    }

    static func playfulFlourish(dialect: DialectLibrary.Dialect = .iraqi) -> String? {
        let bank: [String]
        switch dialect {
        case .iraqi:
            bank = ["هاي شلون هالقوة؟", "مو طبيعي هالإنجاز", "قلبتها صح"]
        case .gulf:
            bank = ["يا وحش", "كفو عليك", "ما شاء الله عليك"]
        case .levantine:
            bank = ["يا زلمة شو هالطاقة", "برافو عليك", "يا وحش"]
        case .msa:
            bank = ["أحسنت", "رائع", "أداء جميل"]
        }
        return bank.randomElement()
    }
}
