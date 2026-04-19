import Foundation

/// Compiled directive consumed by PromptComposer + NotificationBrain.
/// Tells the downstream writer: what tone, what vocabulary, what to avoid.
struct PersonaDirective: Sendable, Codable {
    let tone: Tone
    let dialect: String                  // "iraqi", "gulf", "levantine", "msa"
    let humorAllowed: Bool
    let avoidTopics: [String]            // e.g., "food" during fasting hour
    let culturalHints: [String]          // e.g., "Ramadan evening"
    let emotionalContext: String         // summary for prompt

    enum Tone: String, Sendable, Codable {
        case warm           // default — Captain's baseline
        case gentle         // user upset, low energy, sleep-deprived
        case celebratory    // PR, milestone, streak win
        case concerned      // crisis candidate, severe distress
        case reflective     // evening wind-down, weekly review
        case encouraging    // disengagement, slipping
    }

    /// Render as a short system-prompt suffix.
    func promptSuffix() -> String {
        var parts: [String] = []
        parts.append("Tone: \(tone.rawValue).")
        parts.append("Dialect: \(dialect).")
        if !humorAllowed {
            parts.append("Avoid humor in this reply.")
        }
        if !avoidTopics.isEmpty {
            parts.append("Avoid topics: \(avoidTopics.joined(separator: ", ")).")
        }
        if !culturalHints.isEmpty {
            parts.append("Cultural context: \(culturalHints.joined(separator: "; ")).")
        }
        parts.append("Emotional context: \(emotionalContext).")
        return parts.joined(separator: " ")
    }
}
