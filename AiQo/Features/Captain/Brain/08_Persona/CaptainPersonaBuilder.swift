import Foundation

/// Single source of truth for Captain Hamoudi's persona constraints.
/// Used across cloud, local, and fallback paths.
enum CaptainPersonaBuilder {

    // MARK: - Banned Phrases

    static let bannedPhrases = [
        "بالتأكيد",
        "بكل سرور",
        "كمساعد ذكاء اصطناعي",
        "لا أستطيع",
        "يسعدني مساعدتك",
        "هل يمكنني مساعدتك",
        "كيف يمكنني مساعدتك اليوم",
        "بصفتي نموذج لغوي",
        "As an AI",
        "I'm happy to help",
        "How can I assist you",
        "Certainly!",
        "Of course!",
        "I'd be happy to"
    ]

    /// Strips banned phrases from a Captain response.
    ///
    /// **Fix (2026-04-08):** Replaced `while result.contains("  ")` loop with a single
    /// regex pass. The old loop was O(n²) — each iteration scanned the full string then
    /// allocated a new copy. On long replies with many double-spaces it could spin for
    /// hundreds of iterations, spiking the CPU and blocking the Main Thread.
    /// A single `\s{2,}` regex is O(n) and handles all whitespace variants (including
    /// non-breaking spaces that the old loop missed entirely).
    static func sanitizeResponse(_ text: String) -> String {
        var result = text
        for phrase in bannedPhrases {
            result = result.replacingOccurrences(of: phrase, with: "")
        }
        // Single O(n) pass to collapse any run of 2+ whitespace characters (including \u{00A0})
        result = result.replacingOccurrences(
            of: #"[\s\u{00A0}]{2,}"#,
            with: " ",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Prompt Fragments

    static func bannedPhrasesDirective() -> String {
        let joined = bannedPhrases.map { "「\($0)」" }.joined(separator: ", ")
        return """
        === STRICTLY BANNED PHRASES ===
        You must NEVER use any of these phrases or close variants:
        \(joined)
        These are generic AI filler. Captain Hamoudi speaks like a real person, not a chatbot.
        """
    }

    static func responseLengthRules() -> String {
        """
        === RESPONSE LENGTH RULES ===
        - Simple question → 1-2 sentences max. No padding.
        - Workout/meal plan request → structured plan with clear bullet points
        - Emotional support → one warm sentence then a follow-up question
        - NEVER ramble without reason. Brevity is strength.
        - Max 3 actionable points per response. Never a list of 10.
        - NEVER repeat the same sentence, idea, or phrase within the same reply.
        - If a reply exceeds 4 sentences for a simple question, cut it down.
        - Do NOT open with health stats — open with the direct answer or a human reaction.
        """
    }

    static func buildInstructions() -> String {
        """
        \(bannedPhrasesDirective())

        \(responseLengthRules())
        """
    }
}
