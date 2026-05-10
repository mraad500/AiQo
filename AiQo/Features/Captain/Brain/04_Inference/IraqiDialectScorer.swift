// ===============================================
// File: IraqiDialectScorer.swift
// Brain Refactor §48 — Iraqi Dialect Quality Scoring
//
// Phase 6's QualityGate catches dialect *drift* (English creeping into an
// Arabic reply). This file goes one layer deeper: even when the reply IS
// Arabic, is it actually *Iraqi* — the dialect Hamoudi is supposed to
// speak — or has the model fallen back to Modern Standard Arabic ("إن
// هذا يعد...") because it's the LLM's safer default?
//
// We score by counting Iraqi-dialect "tells" against MSA tells. The gate
// fires when the ratio drops below a configured floor. This is what makes
// Hamoudi's voice consistent across thousands of turns.
//
// Pure local check, no LLM, runs in <0.5ms.
// ===============================================

import Foundation

// MARK: - Score

struct DialectScore: Sendable {
    /// Number of Iraqi-dialect tokens detected.
    let iraqiTokens: Int
    /// Number of Modern Standard Arabic tokens detected.
    let msaTokens: Int
    /// Iraqi share of dialect-bearing tokens. 1.0 = pure Iraqi, 0.0 = pure
    /// MSA. When neither is present, falls back to 0.5 (no signal).
    let iraqiRatio: Double
    /// Total dialect-bearing tokens detected. < 3 → low confidence; the
    /// gate uses this to suppress flags on very short replies where one
    /// MSA word would skew the ratio.
    var totalDialectTokens: Int { iraqiTokens + msaTokens }

    /// Below this ratio + meaningful sample size = flag the reply as
    /// dialect-degraded (MSA creep).
    static let acceptableIraqiRatio: Double = 0.4

    /// Reply is short enough that ratio noise dominates — gate stays quiet.
    static let lowConfidenceTokenFloor: Int = 3
}

// MARK: - Scorer

@MainActor
enum IraqiDialectScorer {

    /// Iraqi-dialect tokens. Curated for high precision — every entry is a
    /// word/particle native Iraqi speakers use that MSA does not have an
    /// identical surface form for. False-positive risk is low.
    static let iraqiTells: [String] = [
        // Iraqi pronouns + interrogatives
        "هسة", "هسه", "هلگ", "هلاگ", "هلكد", "اشكد",
        "شلون", "شكو", "شلونك", "شصار", "شدا", "شو",
        "اشكثر", "اشكد", "اشلون", "هاي", "هاذا", "هذولا",
        // Iraqi negation + tense markers
        "ماكو", "ميكو", "مو", "موش", "گاع", "حدا",
        // Iraqi verb starters / common Iraqi verbs
        "گال", "گلت", "اگدر", "اكدر", "تگدر", "تكدر", "گاعد",
        "خل", "خله", "خلي", "خلصت", "گدر", "گلتلك",
        "صار", "يصير", "أبي", "ابي", "تبي", "اريد",
        "روح", "تعال", "خوش", "خوش رجال",
        // Common Iraqi expressions
        "كلش", "هواية", "شويه", "شوية", "ولك", "ولچ", "ولج",
        "حيل", "ابدا", "اكيد", "ميصير", "مش", "وين",
        "توه", "توك", "توني", "توها",
        // Iraqi connectors
        "وياك", "ويا", "بيه", "بيها", "اله", "الها",
        "علمود", "لان", "مال", "لامن", "لمن",
        // Iraqi-only food/wellness
        "عافية", "عاش", "عاشت", "عاشت إيدك", "عاشت ايدك"
    ]

    /// MSA-only tokens — words/structures that signal the model fell back
    /// to formal Arabic. Each one is unambiguous (no dialectal homonym).
    /// Shorter list because MSA has many variants; we focus on high-impact
    /// markers that drag a reply away from the persona.
    static let msaTells: [String] = [
        // Formal pronouns / structures
        "إنّ ", "إنه ", "إنها ", "إنك ", "أنتَ", "أنتِ",
        "حضرتك", "سيادتك", "جنابك",
        // Formal connectors
        "بالإضافة إلى", "علاوة على", "نظراً ل", "بناءً على",
        "غير أنّ", "بيد أنّ", "كما أنّ", "إذ إنّ",
        // Formal verbs / particles
        "أرغب في", "أتمنى أن", "أود أن", "يُعدّ", "يُعتبر",
        "هل بإمكانك", "هل لديك", "هلّا تكرّمت",
        // Formal phrasing
        "إنه لمن", "تجدر الإشارة", "من الجدير بالذكر",
        "بكل تأكيد", "بلا شك", "لا شك في",
        // Quranic/literary register
        "حقاً", "بلا منازع", "كلّياً"
    ]

    /// Returns a `DialectScore` for the given Arabic reply. Caller is
    /// expected to have already filtered by language (`AppLanguage.arabic`)
    /// before invoking; the scorer doesn't validate language.
    static func score(reply: String) -> DialectScore {
        let normalized = normalize(reply)
        var iraqi = 0
        var msa = 0

        for token in iraqiTells where normalized.contains(token) {
            iraqi += 1
        }
        for token in msaTells where normalized.contains(token) {
            msa += 1
        }

        let total = iraqi + msa
        let ratio: Double = total > 0
            ? Double(iraqi) / Double(total)
            : 0.5  // no signal — neutral

        return DialectScore(
            iraqiTokens: iraqi,
            msaTokens: msa,
            iraqiRatio: ratio
        )
    }

    /// Convenience — does this reply pass the dialect gate? Returns `true`
    /// when there's not enough signal to judge OR when the Iraqi ratio is
    /// above the floor.
    static func passes(reply: String) -> Bool {
        let score = score(reply: reply)
        guard score.totalDialectTokens >= DialectScore.lowConfidenceTokenFloor else {
            return true
        }
        return score.iraqiRatio >= DialectScore.acceptableIraqiRatio
    }

    /// Normalisation mirrors what other detectors use — strip diacritics,
    /// fold case, drop tatweel — so token matching is forgiving.
    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "ـ", with: "")
            .lowercased()
    }
}
