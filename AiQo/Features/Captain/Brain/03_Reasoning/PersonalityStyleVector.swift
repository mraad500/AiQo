// ===============================================
// File: PersonalityStyleVector.swift
// Brain Refactor §42 — Communication Style Mirroring
//
// Most chatbots speak with a flat, brand-defined voice. The user adapts to
// the bot. World-class coaching reverses that: the *coach* mirrors the
// athlete's communication style — terse user gets terse coach, expressive
// user gets expressive coach. This is the foundation of rapport.
//
// The analyzer extracts six measurable style dimensions from the user's
// recent turns and renders them into a directive the brief surfaces to
// Gemini. The model is told HOW to write, not just WHAT to write.
//
// Pure local analysis, no LLM call, runs in <1ms.
// ===============================================

import Foundation

// MARK: - Style Vector

/// Six-dimensional style fingerprint extracted from the user's recent turns.
/// Each dimension is normalised so the prompt directive can use simple
/// "low/medium/high" buckets without leaking raw numbers to the model.
struct PersonalityStyleVector: Sendable {
    /// Mean word count per user message in the window.
    let avgWordsPerMessage: Double
    /// Emojis per message (any unicode emoji range). 0 = never, ≥1 = often.
    let emojiPerMessage: Double
    /// Trailing-bang/question density — counts of "!", "?", "؟" per message.
    let punctuationIntensity: Double
    /// 0–1 score: 1 = highly formal (Modern Standard Arabic), 0 = casual /
    /// pure dialect / slang. Computed by counting MSA tells like "إنه",
    /// "أود", "حضرتك", "لكن" without dialectal alternatives.
    let formalityScore: Double
    /// Fraction of user messages that end with a question mark.
    let questionDensity: Double
    /// How the user typically opens messages (first-token classification).
    let preferredOpening: PreferredOpening
    /// Number of user messages the vector was computed from. < 2 → low
    /// confidence; the brief skips style mirroring and uses defaults.
    let sampleSize: Int

    var hasEnoughSignal: Bool { sampleSize >= 2 }

    /// One-paragraph directive the prompt renders. Iraqi-Arabic version.
    /// Empty when sample size is too small — keeps the brief focused.
    var directiveArabic: String {
        guard hasEnoughSignal else { return "" }
        var pieces: [String] = []

        // Length bucket — directly drives reply length.
        switch avgWordsPerMessage {
        case ..<6:
            pieces.append("مختصر بطبعه (متوسط 5 كلمات/رسالة) — رد بجملة وحدة قصيرة، ممنوع فقرات")
        case 6..<14:
            pieces.append("متوسط الإسهاب — رد بجملتين-ثلاث، احتفظ بالكثافة")
        default:
            pieces.append("معبّر ومسهب — تكدر تكتب 3-4 جمل، بس بدون حشو")
        }

        // Emoji presence — mirror the warmth signal.
        if emojiPerMessage >= 0.5 {
            pieces.append("يستخدم الإيموجي — تكدر تستخدم إيموجي خفيف بالأماكن المناسبة")
        } else if emojiPerMessage <= 0.05 {
            pieces.append("ما يستخدم إيموجي — تجنب الإيموجي تماماً")
        }

        // Formality bucket — drives word choice.
        if formalityScore >= 0.6 {
            pieces.append("أسلوبه رسمي — قلل السخرية والكلمات الثقيلة بالشارع")
        } else if formalityScore <= 0.2 {
            pieces.append("أسلوبه عامي بحت — استخدم الكلام الدارج، تجنب أي كلمة فصحى")
        }

        // Punctuation intensity — driver of energy match.
        if punctuationIntensity >= 1.5 {
            pieces.append("يستخدم علامات تعجب وأسئلة كثيرة — حافظ على نفس مستوى الطاقة")
        }

        // Opening style — mirror back.
        switch preferredOpening {
        case .greeting:
            pieces.append("يبدأ بتحية — رد بتحية قصيرة قبل الموضوع")
        case .direct:
            pieces.append("يدخل بالموضوع مباشرة — تجاوز التحيات")
        case .question:
            pieces.append("يبدأ بسؤال — جاوب على السؤال أول، بعدها فكر بالمتابعة")
        case .unknown:
            break
        }

        return pieces.joined(separator: " · ")
    }

    var directiveEnglish: String {
        guard hasEnoughSignal else { return "" }
        var pieces: [String] = []

        switch avgWordsPerMessage {
        case ..<6:
            pieces.append("Terse style (~5 words/msg) — reply in one short sentence, no paragraphs")
        case 6..<14:
            pieces.append("Medium verbosity — 2–3 sentences, keep density high")
        default:
            pieces.append("Expressive — 3–4 sentences are OK, no filler")
        }

        if emojiPerMessage >= 0.5 {
            pieces.append("Uses emoji — light emoji where it fits is welcome")
        } else if emojiPerMessage <= 0.05 {
            pieces.append("No emoji — avoid emoji entirely")
        }

        if formalityScore >= 0.6 {
            pieces.append("Formal register — dial down sarcasm, lean professional")
        } else if formalityScore <= 0.2 {
            pieces.append("Very casual register — match colloquial tone")
        }

        if punctuationIntensity >= 1.5 {
            pieces.append("High punctuation energy — match the energy")
        }

        switch preferredOpening {
        case .greeting:
            pieces.append("Opens with a greeting — return one before content")
        case .direct:
            pieces.append("Opens directly — skip pleasantries")
        case .question:
            pieces.append("Opens with a question — answer it first, then follow-up")
        case .unknown:
            break
        }

        return pieces.joined(separator: " · ")
    }

    static let defaults = PersonalityStyleVector(
        avgWordsPerMessage: 10,
        emojiPerMessage: 0.1,
        punctuationIntensity: 0.5,
        formalityScore: 0.3,
        questionDensity: 0.4,
        preferredOpening: .unknown,
        sampleSize: 0
    )
}

enum PreferredOpening: Sendable {
    case greeting   // "أهلا", "هلا", "السلام", "Hi", "Hello"
    case question   // first sentence ends with ? or ؟
    case direct     // anything else
    case unknown
}

// MARK: - Analyzer

@MainActor
enum PersonalityAnalyzer {

    /// How many of the most recent user turns to fold into the vector.
    /// Larger windows are more stable but slower to adapt to a style shift —
    /// 8 is a good compromise for typical multi-turn coaching sessions.
    static let windowSize: Int = 8

    static func analyze(
        conversation: [CaptainConversationMessage]
    ) -> PersonalityStyleVector {
        let userMessages = conversation
            .filter { $0.role == .user }
            .suffix(windowSize)
        guard !userMessages.isEmpty else { return .defaults }

        var totalWords = 0
        var totalEmojis = 0
        var totalBangsAndQs = 0
        var formalityHits = 0
        var formalityChecks = 0
        var questionTerminators = 0
        var openingCounts: [PreferredOpening: Int] = [:]

        for message in userMessages {
            let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // 1) Word count
            let words = trimmed.split { $0.isWhitespace || $0.isNewline }
            totalWords += words.count

            // 2) Emoji count
            for scalar in trimmed.unicodeScalars where Self.isEmoji(scalar) {
                totalEmojis += 1
            }

            // 3) Punctuation intensity
            for char in trimmed {
                if char == "!" || char == "?" || char == "؟" {
                    totalBangsAndQs += 1
                }
            }

            // 4) Formality — look for MSA fragments without dialect alternatives.
            //    Each present fragment is one "hit"; max one hit per message
            //    so a single formal user doesn't dominate the score.
            if Self.containsAnyFormalTell(trimmed) {
                formalityHits += 1
            }
            formalityChecks += 1

            // 5) Question terminators
            if let last = trimmed.last, last == "?" || last == "؟" {
                questionTerminators += 1
            }

            // 6) Opening style
            let opening = Self.classifyOpening(trimmed)
            openingCounts[opening, default: 0] += 1
        }

        let n = max(1, userMessages.count)
        let avgWords = Double(totalWords) / Double(n)
        let emojiPer = Double(totalEmojis) / Double(n)
        let bangsPer = Double(totalBangsAndQs) / Double(n)
        let formality = formalityChecks > 0
            ? Double(formalityHits) / Double(formalityChecks)
            : 0.3
        let questionPer = Double(questionTerminators) / Double(n)
        let dominantOpening = openingCounts
            .max(by: { $0.value < $1.value })?
            .key ?? .unknown

        return PersonalityStyleVector(
            avgWordsPerMessage: avgWords,
            emojiPerMessage: emojiPer,
            punctuationIntensity: bangsPer,
            formalityScore: formality,
            questionDensity: questionPer,
            preferredOpening: dominantOpening,
            sampleSize: userMessages.count
        )
    }
}

// MARK: - Detection helpers

private extension PersonalityAnalyzer {

    /// Reasonably-correct emoji range check. Covers the main pictographic
    /// blocks; we don't need pixel-perfect classification, just a count.
    static func isEmoji(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x1F300...0x1F5FF:   return true   // misc symbols + pictographs
        case 0x1F600...0x1F64F:   return true   // emoticons
        case 0x1F680...0x1F6FF:   return true   // transport
        case 0x1F900...0x1F9FF:   return true   // supplemental symbols
        case 0x1FA70...0x1FAFF:   return true   // extended symbols
        case 0x2600...0x26FF:     return true   // misc symbols
        case 0x2700...0x27BF:     return true   // dingbats
        default:                  return false
        }
    }

    /// MSA-only tells that don't have a common dialect alternative. Each one
    /// found is evidence of formal register. The list is conservative — we'd
    /// rather miss formality than over-fire.
    static func containsAnyFormalTell(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let tells = [
            "إنه ", "إنها ", "أود أن", "حضرتك", "لكنّه", "غير أنّ",
            "بالإضافة إلى", "علاوة على", "نظراً ل", "بناءً على",
            "أرغب في", "أتمنى أن", "هل بإمكانك"
        ]
        return tells.contains { lowered.contains($0) }
    }

    /// First-word classifier — checks the leading token against known
    /// greeting / question patterns.
    static func classifyOpening(_ text: String) -> PreferredOpening {
        let lowered = text.lowercased()
        let greetings = [
            "اهلا", "أهلا", "هلا", "السلام", "صباح", "مساء", "مرحب",
            "hi", "hello", "hey", "yo"
        ]
        for greeting in greetings where lowered.hasPrefix(greeting) {
            return .greeting
        }
        // First terminal punctuation in the message — if it's a "?" before
        // any other terminal, the user opened with a question.
        for char in text {
            if char == "?" || char == "؟" { return .question }
            if char == "." || char == "!" { break }
        }
        return .direct
    }
}
