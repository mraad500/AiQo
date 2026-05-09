import Foundation

/// Local, deterministic phrase pool for hydration reminders.
/// No cloud calls — phrases are safe, short, non-medical, non-prescriptive.
/// Routes through the Captain dialect system (DialectLibrary.Dialect) so
/// hydration reminders speak in the same voice as the rest of the Captain persona.
enum HydrationPhrases {

    struct Phrase: Sendable {
        let title: String
        let body: String
    }

    /// Resolve a hydration reminder phrase for the user's current language + dialect.
    /// English ignores `dialect`. Arabic branches on `dialect` to match the
    /// Captain's Iraqi / Gulf / Levantine / MSA voice.
    static func phrase(
        for intensity: HydrationReminderIntensity,
        language: AppLanguage,
        dialect: DialectLibrary.Dialect = .iraqi
    ) -> Phrase {
        switch language {
        case .english:
            return englishPhrase(for: intensity)
        case .arabic:
            return arabicPhrase(for: intensity, dialect: dialect)
        }
    }

    private static func englishPhrase(for intensity: HydrationReminderIntensity) -> Phrase {
        switch intensity {
        case .gentle:
            return Phrase(title: "Water break", body: "Take a small sip now.")
        case .stronger:
            return Phrase(title: "Time to drink", body: "Grab some water now.")
        }
    }

    private static func arabicPhrase(
        for intensity: HydrationReminderIntensity,
        dialect: DialectLibrary.Dialect
    ) -> Phrase {
        switch (intensity, dialect) {
        case (.gentle, .iraqi):
            return Phrase(title: "شربة ماي", body: "خذ شوية ماي هسه — بسيطة.")
        case (.stronger, .iraqi):
            return Phrase(title: "جسمك يدز إشارة", body: "خذ شربة ماي الحين.")

        case (.gentle, .gulf):
            return Phrase(title: "وقت الماي", body: "خذ شوية ماي الحين — بسيطة.")
        case (.stronger, .gulf):
            return Phrase(title: "جسمك يبي ماي", body: "خذ شربة ماي الحين.")

        case (.gentle, .levantine):
            return Phrase(title: "وقت المي", body: "خود شوي مي هلق.")
        case (.stronger, .levantine):
            return Phrase(title: "جسمك بدو مي", body: "خود شربة مي هلق.")

        case (.gentle, .msa):
            return Phrase(title: "وقت الماء", body: "تناول بعض الماء الآن.")
        case (.stronger, .msa):
            return Phrase(title: "جسمك بحاجة للماء", body: "اشرب الماء الآن.")
        }
    }

    static func paceLabel(
        _ status: HydrationPaceStatus,
        language: AppLanguage
    ) -> String {
        switch (status, language) {
        case (.ahead, .arabic):      return "متقدم"
        case (.onTrack, .arabic):    return "ضمن المسار"
        case (.behind, .arabic):     return "متأخر"
        case (.veryBehind, .arabic): return "متأخر هواية"
        case (.ahead, .english):     return "Ahead"
        case (.onTrack, .english):   return "On track"
        case (.behind, .english):    return "Behind"
        case (.veryBehind, .english):return "Very behind"
        }
    }

    static func sourceLabel(
        _ source: HydrationSource,
        language: AppLanguage
    ) -> String {
        switch (source, language) {
        case (.manual, .arabic):       return "يدوي"
        case (.appleHealth, .arabic):  return "Apple Health"
        case (.manual, .english):      return "Manual"
        case (.appleHealth, .english): return "Apple Health"
        }
    }
}
