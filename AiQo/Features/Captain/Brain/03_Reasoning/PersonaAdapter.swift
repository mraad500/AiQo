import Foundation

/// Compiles PersonaDirective from emotional + cultural state.
/// Pure: same inputs always produce same output. No side effects.
actor PersonaAdapter {
    static let shared = PersonaAdapter()

    private init() {}

    func directive(
        emotion: EmotionalReading,
        cultural: CulturalContextEngine.State,
        userDialect: String = "iraqi"
    ) -> PersonaDirective {
        let tone = selectTone(emotion: emotion, cultural: cultural)
        let humorAllowed = allowsHumor(emotion: emotion, cultural: cultural)
        let avoidTopics = computeAvoidTopics(cultural: cultural, emotion: emotion)
        let hints = computeHints(cultural: cultural)
        let emoContext = summarize(emotion: emotion)

        return PersonaDirective(
            tone: tone,
            dialect: userDialect,
            humorAllowed: humorAllowed,
            avoidTopics: avoidTopics,
            culturalHints: hints,
            emotionalContext: emoContext
        )
    }

    // MARK: - Selection logic

    private func selectTone(
        emotion: EmotionalReading,
        cultural: CulturalContextEngine.State
    ) -> PersonaDirective.Tone {
        // Severe low mood → gentle
        if emotion.primary == .grief {
            return .gentle
        }
        if emotion.intensity > 0.8 &&
           (emotion.primary == .frustration || emotion.primary == .shame) {
            return .gentle
        }

        // Declining trend → encouraging
        if emotion.trend == .declining { return .encouraging }

        // High positive energy → celebratory
        if emotion.primary == .joy && emotion.intensity > 0.6 { return .celebratory }

        // Cultural moments → reflective on Jumu'ah, evening Ramadan
        if cultural.isJumuah || (cultural.isRamadan && cultural.timeOfDay == .evening) {
            return .reflective
        }

        return .warm
    }

    private func allowsHumor(
        emotion: EmotionalReading,
        cultural: CulturalContextEngine.State
    ) -> Bool {
        // Eid celebrations allow humor even if otherwise suppressed
        if cultural.isEid == .eidFitr || cultural.isEid == .eidAdha { return true }

        // Heavy emotional intensity → no humor (unless it's joy)
        if emotion.intensity > 0.7 && emotion.primary != .joy { return false }

        // Serious during fasting hour
        if cultural.isFastingHour { return false }

        return true
    }

    private func computeAvoidTopics(
        cultural: CulturalContextEngine.State,
        emotion: EmotionalReading
    ) -> [String] {
        var topics: [String] = []
        if cultural.isFastingHour {
            topics.append("food")
            topics.append("meal suggestions")
            topics.append("caloric intake")
        }
        if emotion.trend == .declining || emotion.intensity > 0.7 {
            topics.append("pressuring language")
            topics.append("goal failures")
        }
        return topics
    }

    private func computeHints(cultural: CulturalContextEngine.State) -> [String] {
        var hints: [String] = []
        hints.append(cultural.promptSummary)
        if cultural.timeOfDay == .dawn {
            hints.append("user just woke up")
        }
        if cultural.timeOfDay == .lateNight {
            hints.append("late night — encourage rest")
        }
        return hints
    }

    private func summarize(emotion: EmotionalReading) -> String {
        let level = emotion.intensity > 0.6 ? "high" :
                    emotion.intensity > 0.3 ? "moderate" : "low"
        return "\(emotion.primary.rawValue) (\(level), trend: \(emotion.trend.rawValue))"
    }
}

extension PersonaAdapter {

    /// Rich directive that composes stable identity + humor + wisdom for outbound copy.
    func richDirective(
        emotion: EmotionalReading,
        cultural: CulturalContextEngine.State,
        userDialect: String = "iraqi"
    ) -> RichDirective {
        let base = directive(emotion: emotion, cultural: cultural, userDialect: userDialect)
        let humor = HumorEngine.intensity(emotion: emotion, cultural: cultural)
        let wisdom = WisdomLibrary.appropriate(emotion: emotion, cultural: cultural)

        return RichDirective(
            base: base,
            humorIntensity: humor,
            wisdomCandidate: wisdom,
            systemPrompt: CaptainIdentity.systemPrompt(
                dialect: userDialect,
                emotion: emotion,
                cultural: cultural
            )
        )
    }
}

struct RichDirective: Sendable {
    let base: PersonaDirective
    let humorIntensity: HumorEngine.Intensity
    let wisdomCandidate: WisdomLibrary.Wisdom?
    let systemPrompt: String
}
