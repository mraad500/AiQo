import Foundation

enum IntentKind: String, Sendable, Codable {
    case greeting         // "hi", "سلام عليكم"
    case question         // "how many steps today?"
    case goal             // "I want to lose weight"
    case venting          // "I'm so exhausted and nothing works"
    case crisis           // self-harm, suicidal ideation
    case social           // references a person: "my mom", "my friend"
    case request          // "give me a workout plan"
    case unknown
}

struct IntentReading: Sendable {
    let primary: IntentKind
    let confidence: Double
    let flags: [String]
    let mentionedNames: [String]
}

/// Heuristic intent classifier. No LLM, no network.
/// Crisis detection is intentionally conservative: false positives are acceptable, false negatives are not.
enum IntentClassifier {

    // Crisis keywords — checked first, highest priority. APPEND-ONLY.
    nonisolated private static let crisisMarkers: [String] = [
        "kill myself", "end it all", "no reason to live",
        "want to die", "hurt myself", "suicide", "suicidal",
        "أنتحر", "ما أبي أعيش", "أموت", "أنهي حياتي", "أذي نفسي"
    ]

    nonisolated private static let greetingMarkers: [String] = [
        "hi ", "hi!", "hello", "hey ", "good morning", "good evening",
        "سلام", "أهلا", "هلا", "مرحبا", "صباح الخير", "مساء الخير"
    ]

    nonisolated private static let goalMarkers: [String] = [
        "i want to", "my goal", "trying to", "plan to",
        "أبي", "أبغى", "هدفي", "أخطط"
    ]

    nonisolated private static let ventingMarkers: [String] = [
        "exhausted", "tired of", "nothing works", "fed up", "frustrated",
        "مبسوط مو", "زهقت", "تعبت", "ما أقدر أكمّل"
    ]

    nonisolated private static let requestMarkers: [String] = [
        "give me", "show me", "make a", "plan for", "recommend",
        "اعطني", "سوي", "أعطيني", "اقترح"
    ]

    nonisolated private static let questionStarts: [String] = [
        "what ", "how ", "why ", "when ", "where ", "who ",
        "شنو", "كيف", "ليش", "متى", "وين", "منو"
    ]

    nonisolated private static let familyMarkers: [String] = [
        "my mom", "my dad", "my sister", "my brother", "my wife", "my husband",
        "my friend", "my kid", "my son", "my daughter",
        "أمي", "أبوي", "أختي", "أخوي", "زوجتي", "زوجي",
        "صديقي", "ابني", "بنتي", "أطفالي"
    ]

    nonisolated static func classify(_ text: String) -> IntentReading {
        let lowered = text.lowercased()
        var flags: [String] = []

        // 1. Crisis — first check, highest confidence
        if crisisMarkers.first(where: { lowered.contains($0) }) != nil {
            flags.append("crisis_language_detected")
            return IntentReading(
                primary: .crisis,
                confidence: 0.95,
                flags: flags,
                mentionedNames: []
            )
        }

        // 2. Social reference — family/friend markers
        if familyMarkers.contains(where: { lowered.contains($0) }) {
            flags.append("family_reference")
            return IntentReading(
                primary: .social,
                confidence: 0.75,
                flags: flags,
                mentionedNames: extractNames(from: text)
            )
        }

        // 3. Question — ends with ? or starts with question word
        if lowered.hasSuffix("?") || lowered.hasSuffix("؟") ||
           hasQuestionStart(lowered) {
            return IntentReading(
                primary: .question,
                confidence: 0.85,
                flags: flags,
                mentionedNames: extractNames(from: text)
            )
        }

        // 4. Greeting — short + greeting marker
        if text.count < 30 && greetingMarkers.contains(where: { lowered.contains($0) }) {
            return IntentReading(primary: .greeting, confidence: 0.9, flags: flags, mentionedNames: [])
        }

        // 5. Request — imperative with action words
        if requestMarkers.contains(where: { lowered.contains($0) }) {
            return IntentReading(primary: .request, confidence: 0.8, flags: flags, mentionedNames: [])
        }

        // 6. Goal
        if goalMarkers.contains(where: { lowered.contains($0) }) {
            return IntentReading(primary: .goal, confidence: 0.75, flags: flags, mentionedNames: [])
        }

        // 7. Venting — emotional markers
        if ventingMarkers.contains(where: { lowered.contains($0) }) {
            flags.append("venting_language")
            return IntentReading(primary: .venting, confidence: 0.7, flags: flags, mentionedNames: [])
        }

        // 8. Social via extracted proper nouns (fallback)
        let names = extractNames(from: text)
        if !names.isEmpty {
            return IntentReading(primary: .social, confidence: 0.6, flags: flags, mentionedNames: names)
        }

        // 9. Unknown
        return IntentReading(primary: .unknown, confidence: 0.3, flags: flags, mentionedNames: [])
    }

    // MARK: - Helpers

    nonisolated private static func hasQuestionStart(_ text: String) -> Bool {
        questionStarts.contains(where: { text.hasPrefix($0) })
    }

    /// Extract capitalized words that look like names (simple heuristic).
    nonisolated private static func extractNames(from text: String) -> [String] {
        let skip: Set<String> = ["I", "The", "A", "An", "But", "And", "Or", "So", "My", "Your", "His", "Her"]
        let words = text.split(separator: " ")
        var names: [String] = []
        for word in words {
            let str = String(word).trimmingCharacters(in: .punctuationCharacters)
            guard str.count >= 3 else { continue }
            guard let first = str.first, first.isUppercase, str.allSatisfy({ $0.isLetter }) else { continue }
            if skip.contains(str) { continue }
            names.append(str)
        }
        return Array(Set(names)).sorted()
    }
}
