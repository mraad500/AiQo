import Foundation

/// Pure decision logic that maps a detected signal into an intervention type.
enum InterventionPolicy {

    enum Decision: Sendable, Equatable {
        case doNothing
        case gentleCheckIn
        case reflectiveMessage(text: String)
        case professionalReferral(urgency: Urgency)

        enum Urgency: String, Sendable {
            case informational
            case suggested
            case immediate
        }
    }

    nonisolated static func decide(
        signal: CrisisDetector.Signal,
        recentHistory: [CrisisDetector.Signal],
        language: AppLanguage
    ) -> Decision {
        switch signal.severity {
        case .noConcern:
            return .doNothing

        case .watchful:
            return .gentleCheckIn

        case .concerning:
            let cutoff = signal.detectedAt.addingTimeInterval(-7 * 24 * 60 * 60)
            let recentConcerning = recentHistory.filter {
                $0.severity >= .concerning && $0.detectedAt >= cutoff
            }

            if recentConcerning.count >= 2 {
                return .professionalReferral(urgency: .suggested)
            }

            return .reflectiveMessage(text: reflectiveMessage(language: language))

        case .acute:
            return .professionalReferral(urgency: .immediate)
        }
    }

    nonisolated private static func reflectiveMessage(language: AppLanguage) -> String {
        switch language {
        case .arabic:
            let arabicOptions = [
                "لاحظت إنك تمر بوقت صعب. أنا هنا لو تبي تحكي.",
                "يوم صعب؟ خذ نفس عميق. مو لازم تكون قوي كل وقت.",
                "بعض الأيام أثقل من غيرها. واحنا معاك."
            ]
            return arabicOptions.randomElement() ?? arabicOptions[0]

        case .english:
            let englishOptions = [
                "It sounds like you're going through a really hard moment. I'm here with you.",
                "Some days are heavier than others. You do not have to carry it alone.",
                "Take one slow breath with me. We can go one step at a time."
            ]
            return englishOptions.randomElement() ?? englishOptions[0]
        }
    }
}
