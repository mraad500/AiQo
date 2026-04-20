import Foundation

/// Persists the answers from the mandatory pre-onboarding health screening.
///
/// Two concerns live together here because they collect at the same prompt and
/// drive the same downstream behaviour:
///   1. **Age.** Users under 18 are blocked from the app entirely — AiQo is a
///      wellness/fitness coach, not a children's product, and Apple's
///      Guideline 1.4.1 does not let us ship physical-activity prescriptions
///      to minors without parental consent.
///   2. **Condition flags.** Pregnancy, cardiovascular/BP conditions, and
///      recent surgery (≤6 months) do not block the app, but they flow into
///      Captain's system prompt so AI replies avoid high-intensity
///      recommendations without a "see your doctor first" caveat.
///
/// The stored flags are local-only (UserDefaults). They are wiped on
/// `AppFlowController.logout()` via the onboarding-key reset.
public struct HealthScreeningAnswers: Codable, Equatable, Sendable {
    public var birthYear: Int
    public var isPregnant: Bool
    public var hasHeartOrBloodPressureCondition: Bool
    public var hadRecentSurgery: Bool

    public init(
        birthYear: Int,
        isPregnant: Bool,
        hasHeartOrBloodPressureCondition: Bool,
        hadRecentSurgery: Bool
    ) {
        self.birthYear = birthYear
        self.isPregnant = isPregnant
        self.hasHeartOrBloodPressureCondition = hasHeartOrBloodPressureCondition
        self.hadRecentSurgery = hadRecentSurgery
    }

    public var ageNow: Int {
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        return max(0, currentYear - birthYear)
    }

    public var hasAnyCondition: Bool {
        isPregnant || hasHeartOrBloodPressureCondition || hadRecentSurgery
    }

    /// Short, prompt-ready description used by Captain's system prompt so the
    /// AI tailors its suggestions. Empty string if no flags set.
    public nonisolated var captainContextLine: String {
        var parts: [String] = []
        if isPregnant { parts.append("المستخدم حامل حالياً") }
        if hasHeartOrBloodPressureCondition { parts.append("عنده حالة قلب/ضغط دم") }
        if hadRecentSurgery { parts.append("أجرى عملية جراحية في آخر 6 أشهر") }
        guard !parts.isEmpty else { return "" }
        return "تحذير صحي: " + parts.joined(separator: "، ")
            + ". تجنّب التوصية بتمارين عالية الشدة أو حميات صارمة؛ وجّه المستخدم لاستشارة طبيبه قبل أي نشاط مكثّف."
    }
}

public enum HealthScreeningStore {
    private static let answersKey = "aiqo.healthScreening.answers.v1"
    public static let minimumAge = 18

    public static func save(_ answers: HealthScreeningAnswers) {
        guard let data = try? JSONEncoder().encode(answers) else { return }
        UserDefaults.standard.set(data, forKey: answersKey)
    }

    public static func load() -> HealthScreeningAnswers? {
        guard let data = UserDefaults.standard.data(forKey: answersKey) else { return nil }
        return try? JSONDecoder().decode(HealthScreeningAnswers.self, from: data)
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: answersKey)
    }
}
