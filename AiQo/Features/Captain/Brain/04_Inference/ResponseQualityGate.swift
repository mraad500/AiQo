// ===============================================
// File: ResponseQualityGate.swift
// Brain Refactor §41 — Post-Generation Quality Gate
//
// Runs deterministic checks on Gemini's reply *before* it reaches the user.
// Catches the failure modes that the prompt rules tried to prevent but the
// model still produced — e.g. suggesting walking after the avoid-list named
// walking, closing with a vague "what do you want?", or never referencing
// a just-finished workout.
//
// The gate is the empirical receipt for everything we promised in layers
// §33–§40. Without it, prompt rules are aspirational; with it, we measure.
//
// Pure deterministic checks. No second LLM call (regeneration, when enabled,
// is a separate code path that re-issues the cloud request once with a
// corrective prefix).
// ===============================================

import Foundation

// MARK: - Score

/// Brain §50 Round 5 Fix ζ — distinguishes the *intent strength* the user
/// expressed when adding a family to the avoid-list.
enum AvoidSeverity: String, Sendable {
    /// User explicitly refused ("ما أبي ركض"). Suggestion of this family
    /// is a hard failure — equal weight to dialect drift.
    case hard
    /// User just completed it. Suggestion is still a failure (anti-repeat),
    /// but a milder telemetry signal — the model didn't *defy* a user
    /// decision, it just didn't read the freshness cue.
    case soft
}

/// Categorised reasons a draft reply failed the gate. Each carries enough
/// evidence that telemetry can later reconstruct what went wrong without
/// shipping the full reply text off-device.
enum QualityViolationKind: Sendable {
    /// Reply names a family the avoid-list explicitly forbade.
    /// `severity` distinguishes:
    ///  • `.hard` — user explicitly refused the family. Always critical.
    ///  • `.soft` — user just completed it. Critical for the *current*
    ///    suggestion turn, but prefix-corrected (not a hard re-throw)
    ///    if the model surfaces it as context for tomorrow.
    case usedAvoidedFamily(RecentActivityFamily, severity: AvoidSeverity)
    /// `recentActivity.veryFresh` but the reply never names the family —
    /// missed the most concrete observation Captain had.
    case missedFreshActivityReference(RecentActivityFamily)
    /// Reply closes with a vague open question ("what do you want to do?")
    /// when the brief contained a non-factual angle.
    case vagueClose
    /// Bio-state had data and the brief listed callbacks, but the reply
    /// contains no specific number — i.e. fully generic.
    case noSpecificNumber
    /// Reply length exceeds the persona's stated cap (≤ 5 sentences).
    case excessiveLength(sentenceCount: Int)
    /// Arabic mode but reply is dominantly English.
    case dialectDrift(englishRatio: Double)
    /// Arabic mode but reply has slipped into Modern Standard Arabic — i.e.
    /// it's Arabic, just not *Iraqi*. Caught by §48 dialect scorer.
    case msaDriftInArabicMode(iraqiRatio: Double)
    /// §50 — reply contradicts the brief's angle. The reasoner picked
    /// `expected` (e.g. `.gentle` for a stressed user) but the model
    /// produced text that reads like a different angle (e.g. pushing
    /// hard). The associated value is the angle the reasoner asked for.
    case angleViolation(expected: ReasoningAngle)

    var isCritical: Bool {
        switch self {
        case .dialectDrift, .msaDriftInArabicMode:
            return true
        case .usedAvoidedFamily(_, let severity):
            // §50 Round 5 — hard avoidances are user-protection (critical);
            // soft ones are anti-repeat warnings (telemetry only).
            return severity == .hard
        case .angleViolation(let expected):
            // Repair / grounding violations are critical — these are the
            // user-protection branches. Other angle drifts are warnings.
            return expected == .repair || expected == .grounding
        case .missedFreshActivityReference, .vagueClose,
             .noSpecificNumber, .excessiveLength:
            return false
        }
    }

    /// Stable string for analytics. Don't include free-form text — keep
    /// telemetry low-cardinality.
    var analyticsCode: String {
        switch self {
        case .usedAvoidedFamily(let family, let severity):
            return "used_avoided_family_\(severity.rawValue):\(family.rawValue)"
        case .missedFreshActivityReference(let family):
            return "missed_fresh_activity:\(family.rawValue)"
        case .vagueClose:
            return "vague_close"
        case .noSpecificNumber:
            return "no_specific_number"
        case .excessiveLength:
            return "excessive_length"
        case .dialectDrift:
            return "dialect_drift"
        case .msaDriftInArabicMode:
            return "msa_drift_in_arabic_mode"
        case .angleViolation(let expected):
            return "angle_violation:\(expected.rawValue)"
        }
    }
}

/// The gate's verdict — score in [0,1] where 1.0 means "no violations" and
/// each violation subtracts a weight proportional to its severity.
struct QualityScore: Sendable {
    let score: Double
    let violations: [QualityViolationKind]

    var hasCriticalViolation: Bool {
        violations.contains(where: \.isCritical)
    }

    /// Was this reply good enough to ship without intervention? Threshold
    /// is intentionally lenient — we don't want to over-block. Critical
    /// violations always fail this regardless of score.
    var isAcceptable: Bool {
        !hasCriticalViolation && score >= 0.6
    }

    /// Iraqi-Arabic prefix the orchestrator can prepend to the system prompt
    /// when regenerating, listing the specific failures so the model can
    /// avoid them on the second pass. English mirror produced when needed.
    ///
    /// §50 Round 3 — accepts the brief's `thesis` so the corrective prompt
    /// carries the *why*, not just the *what*. Without the thesis the model
    /// re-tries without knowing the intent (e.g. "user has elevated HR
    /// without effort context") and may slip again on the same axis.
    func correctivePromptPrefix(
        language: AppLanguage,
        thesis: String? = nil
    ) -> String {
        guard hasCriticalViolation else { return "" }
        let isArabic = language == .arabic
        let codes = violations.filter(\.isCritical).map(\.analyticsCode).joined(separator: ", ")
        let thesisLine: String = {
            guard let thesis, !thesis.isEmpty else { return "" }
            return isArabic
                ? "\nالسبب الأعلى لأسلوب الرد: \(thesis)"
                : "\nUpstream cause for the angle: \(thesis)"
        }()
        return isArabic
            ? """
            === تصحيح فوري (Brain §41) ===
            مسودتك السابقة فشلت بـ: \(codes).\(thesisLine)
            أعد كتابة الرد بحيث يحترم القواعد الموجودة بالأعلى. لا تكرر نفس الخطأ.
            """
            : """
            === IMMEDIATE CORRECTION (Brain §41) ===
            Your previous draft failed: \(codes).\(thesisLine)
            Rewrite the reply so it respects the rules above. Do not repeat the same mistake.
            """
    }
}

// MARK: - Gate

/// Stateless evaluator. Doesn't own the conversation — every call gets the
/// fully-built request + the reply text and returns a fresh score.
@MainActor
struct ResponseQualityGate {

    /// Sentence ceiling enforced by the persona. Must stay in sync with the
    /// "≤ 5 sentences" rule in the identity layer.
    static let hardSentenceCeiling: Int = 6   // 5 + 1 grace

    /// English-character ratio above which we flag dialect drift in Arabic
    /// mode. The cleanReply step in the ViewModel uses 0.4; we use 0.5 here
    /// to avoid double-flagging — the gate is a backstop, not a duplicate.
    static let arabicEnglishDriftCeiling: Double = 0.5

    func evaluate(
        replyMessage: String,
        request: HybridBrainRequest
    ) -> QualityScore {
        var hits: [QualityViolationKind] = []
        let trimmed = replyMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // Empty replies are caught upstream — no need to score them here.
            return QualityScore(score: 1.0, violations: [])
        }
        let normalized = Self.normalize(trimmed)

        // 1) Avoid-list violation — severity comes from the source intent.
        if let hit = detectAvoidedFamilyHit(
            normalized: normalized,
            tags: request.contextData.coherenceTags
        ) {
            hits.append(.usedAvoidedFamily(hit.family, severity: hit.severity))
        }

        // 2) Missed fresh-activity reference. Only fires when the activity
        //    is veryFresh AND the reply doesn't name the family.
        if let activity = request.contextData.recentActivity,
           activity.freshness == .veryFresh,
           !mentionsFamily(normalized: normalized, family: activity.family) {
            hits.append(.missedFreshActivityReference(activity.family))
        }

        // 3) Vague-close detector.
        if endsWithVagueQuestion(trimmed: trimmed),
           !isFactualAngle(brief: request.contextData.reasoningBrief) {
            hits.append(.vagueClose)
        }

        // 4) No specific number when context had data.
        // §50 Round 3 — skip the check on ultra-short replies (≤ 5 words),
        // which are typically greetings / acknowledgments where a number
        // would feel out of place. We don't want to flag a perfectly fine
        // "أهلاً يا محمد" just because the user has 5,000 steps today.
        let wordCount = trimmed.split { $0.isWhitespace || $0.isNewline }.count
        if wordCount > 5,
           shouldHaveNumber(request: request),
           !containsAnyDigit(trimmed) {
            hits.append(.noSpecificNumber)
        }

        // 5) Excessive length.
        let sentences = Self.sentenceCount(in: trimmed)
        if sentences > Self.hardSentenceCeiling {
            hits.append(.excessiveLength(sentenceCount: sentences))
        }

        // 6) Dialect drift (Arabic mode only).
        if request.language == .arabic {
            let englishRatio = Self.englishCharRatio(in: trimmed)
            if englishRatio >= Self.arabicEnglishDriftCeiling {
                hits.append(.dialectDrift(englishRatio: englishRatio))
            }

            // 7) §48 — Iraqi-vs-MSA dialect score. Only fire when the reply
            //    has enough dialect-bearing tokens to give a reliable read.
            let dialectScore = IraqiDialectScorer.score(reply: trimmed)
            if dialectScore.totalDialectTokens >= DialectScore.lowConfidenceTokenFloor,
               dialectScore.iraqiRatio < DialectScore.acceptableIraqiRatio {
                hits.append(.msaDriftInArabicMode(iraqiRatio: dialectScore.iraqiRatio))
            }
        }

        // 8) §50 — angle adherence. The reasoner picked an angle; if the
        //    reply contradicts it (e.g. brief said `.gentle` but the text
        //    reads like `.pushForward`), surface the mismatch. Repair and
        //    grounding are critical because they're the user-protection
        //    branches — failing them means we ignored a vulnerable user.
        if let expectedAngle = request.contextData.reasoningBrief?.angle,
           !Self.textAdheresToAngle(trimmed: trimmed, angle: expectedAngle, language: request.language) {
            hits.append(.angleViolation(expected: expectedAngle))
        }

        return QualityScore(
            score: Self.computeScore(violations: hits),
            violations: hits
        )
    }
}

// MARK: - Detection helpers (private)

private extension ResponseQualityGate {

    /// Compares the avoid-list with the reply text. Each family has Arabic
    /// + English labels we already maintain in `RecentActivityFamily`; we
    /// also include common verb forms ("نمشي", "let's walk") to catch the
    /// model rephrasing the suggestion.
    ///
    /// §50 Round 5 — returns the *severity* alongside the family. Hard
    /// (refusals) take priority over soft (just-completed) when the same
    /// family lives on both lists; we want the strongest categorization to
    /// drive the gate's critical-or-not decision.
    func detectAvoidedFamilyHit(
        normalized: String,
        tags: ConversationContextTags?
    ) -> (family: RecentActivityFamily, severity: AvoidSeverity)? {
        guard let tags else { return nil }

        let hardSet = Set(tags.hardAvoidances)
        let softSet = Set(tags.softAvoidances)
        let allAvoid = hardSet.union(softSet)
        guard !allAvoid.isEmpty else { return nil }

        for family in allAvoid {
            let probes = Self.familyProbes(for: family)
            for probe in probes where normalized.contains(probe) {
                let severity: AvoidSeverity = hardSet.contains(family) ? .hard : .soft
                return (family, severity)
            }
        }
        return nil
    }

    /// Did the reply mention the family by any probe term?
    func mentionsFamily(normalized: String, family: RecentActivityFamily) -> Bool {
        Self.familyProbes(for: family).contains { normalized.contains($0) }
    }

    /// Quick noun + verb probes per family. Conservative — false negatives
    /// are fine (we just won't flag), false positives would over-block.
    static func familyProbes(for family: RecentActivityFamily) -> [String] {
        switch family {
        case .walking:
            return ["مشي", "مشية", "نمشي", "تمشي", "walk", "walking"]
        case .running:
            return ["ركض", "جري", "نركض", "run ", "running", "jog"]
        case .cycling:
            return ["دراج", "نركب الدراجة", "cycl", "bike"]
        case .swimming:
            return ["سباح", "نسبح", "swim"]
        case .strength:
            return ["تمارين قوة", "حديد", "مقاوم", "strength", "weights", "lift"]
        case .hiit:
            return ["hiit", "هايت"]
        case .yoga:
            return ["يوغا", "yoga"]
        case .pilates:
            return ["بيلاتس", "pilates"]
        case .boxing:
            return ["ملاكم", "نلاكم", "box"]
        case .martialArts:
            return ["فنون قتال", "martial"]
        case .calisthenics:
            return ["وزن الجسم", "calisthen"]
        case .sport:
            return ["كرة قدم", "كرة سلة", "بادل", "تنس", "football", "basketball", "padel", "tennis"]
        case .jumpRope:
            return ["نط حبل", "jump rope", "rope"]
        case .stairs:
            return ["درج", "stair"]
        case .elliptical:
            return ["إليبتكال", "elliptical"]
        case .equestrian:
            return ["فروسي", "equest"]
        case .gratitude:
            return ["جلسة امتنان", "امتنان", "gratitude"]
        case .cinematic:
            return ["سينماتك", "ويا الكابتن", "cinematic"]
        case .other:
            return []
        }
    }

    /// Does the reply close with one of the canned vague questions? Match on
    /// the *trailing* fragment so mid-sentence questions aren't penalised.
    func endsWithVagueQuestion(trimmed: String) -> Bool {
        let suffixProbes = [
            "شنو تحب تسوي؟", "شنو تحب نسوي؟", "شنو تريد؟", "شرايك؟",
            "شنو رايك؟", "كيف تحب؟", "شنو هدفك اليوم؟",
            "what do you want to do?", "what would you like?",
            "what's your goal?", "how can I help?"
        ]
        let lowered = trimmed.lowercased()
        return suffixProbes.contains { probe in
            lowered.hasSuffix(probe.lowercased())
        }
    }

    /// Treat factual-angle replies more leniently — direct factual answers
    /// can legitimately end with "anything else?" without being vague.
    func isFactualAngle(brief: ReasoningBrief?) -> Bool {
        brief?.angle == .factual
    }

    /// We expect a number in the reply when the brief has callbacks, the
    /// recent activity is fresh, OR the bio-state had non-trivial metrics.
    /// If none of those signals apply, the absence of a number is fine.
    ///
    /// §50 Round 4 Fix α — question-aware. Even with rich data signals, a
    /// "شلونك؟" / "hi" greeting from the user doesn't warrant a numeric
    /// reply. We suppress the check when the latest user turn is purely a
    /// greeting / pleasantry.
    func shouldHaveNumber(request: HybridBrainRequest) -> Bool {
        guard !latestUserTurnIsPureGreeting(request: request) else { return false }

        let brief = request.contextData.reasoningBrief
        let hasCallbacks = !(brief?.smartCallbacks.isEmpty ?? true)
        let hasFreshActivity = request.contextData.recentActivity?.freshness != .stale
            && request.contextData.recentActivity != nil
        let hasNotableSteps = request.contextData.steps >= 3000
        let hasMicroInsights = !(brief?.microInsights.isEmpty ?? true)
        return hasCallbacks || hasFreshActivity || hasNotableSteps || hasMicroInsights
    }

    /// True when the latest user message is a short greeting / pleasantry
    /// with no informational content. Conservative — biased toward false
    /// negatives (we'd rather demand a number where appropriate than
    /// false-suppress).
    func latestUserTurnIsPureGreeting(request: HybridBrainRequest) -> Bool {
        guard let latest = request.conversation.last(where: { $0.role == .user })?.content
        else { return false }
        let trimmed = latest.trimmingCharacters(in: .whitespacesAndNewlines)
        // Length cap — anything > 30 chars is too substantive to be pure
        // greeting territory.
        guard trimmed.count <= 30 else { return false }
        let lowered = trimmed.lowercased()
        let greetings = [
            "اهلا", "أهلا", "هلا", "السلام", "صباح", "مساء", "مرحب",
            "شلونك", "كيفك", "اشلونك",
            "hi", "hello", "hey", "yo", "good morning", "good evening",
            "how are you", "how r u"
        ]
        return greetings.contains { lowered.contains($0) }
    }

    func containsAnyDigit(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            // Cover Arabic-Indic, Eastern Arabic-Indic, and ASCII digits.
            ("0"..."9").contains(scalar)
                || ("\u{0660}"..."\u{0669}").contains(scalar)
                || ("\u{06F0}"..."\u{06F9}").contains(scalar)
        }
    }
}

// MARK: - Static utilities

private extension ResponseQualityGate {

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "ـ", with: "")
            .lowercased()
    }

    /// Counts sentences by terminal punctuation. Arabic full-stop "۔" and
    /// "؟" are included alongside Latin "." "!" "?".
    static func sentenceCount(in text: String) -> Int {
        let terminals = CharacterSet(charactersIn: ".!?؟۔")
        let parts = text.components(separatedBy: terminals)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return max(1, parts.count)
    }

    /// Crude English-character ratio — a-z chars / total alpha chars.
    /// Used only as a backstop; the upstream `cleanAssistantReplyMessage`
    /// has its own (stricter) version that triggers fallbacks earlier.
    static func englishCharRatio(in text: String) -> Double {
        var english = 0
        var totalAlpha = 0
        for scalar in text.unicodeScalars {
            if CharacterSet.letters.contains(scalar) {
                totalAlpha += 1
                if scalar.value < 0x80 { english += 1 }
            }
        }
        guard totalAlpha > 0 else { return 0 }
        return Double(english) / Double(totalAlpha)
    }

    /// Each violation subtracts a weight; weights tuned so a single critical
    /// hit drops below 0.6 (the acceptance floor).
    static func computeScore(violations: [QualityViolationKind]) -> Double {
        var score = 1.0
        for violation in violations {
            switch violation {
            case .dialectDrift, .msaDriftInArabicMode:
                score -= 0.5
            case .usedAvoidedFamily(_, let severity):
                // §50 Round 5 — hard avoidances are critical (-0.5),
                // soft are warnings (-0.25). The score still drops below
                // 0.6 acceptance for a single hard hit; soft hits need
                // to compound with another violation to fail acceptance.
                score -= severity == .hard ? 0.5 : 0.25
            case .angleViolation(let expected):
                // Repair/grounding are user-protection — heavy penalty.
                // Other angle slips are warnings.
                score -= (expected == .repair || expected == .grounding) ? 0.5 : 0.20
            case .missedFreshActivityReference:
                score -= 0.25
            case .vagueClose, .noSpecificNumber:
                score -= 0.15
            case .excessiveLength:
                score -= 0.10
            }
        }
        return max(0, score)
    }
}

// MARK: - Angle adherence (Brain §50)
//
// Cheap heuristic check: does the reply *read* like the angle the reasoner
// asked for? Pure deterministic — looks for telltale fragments. False-
// negative friendly (we'd rather miss a violation than over-block), so
// we only flag clearly-wrong cases.

private extension ResponseQualityGate {

    /// Token signatures that indicate "pushing the user" — celebratory or
    /// instructional language with action verbs. Captain should not be
    /// using these when the brief asked for a gentle / grounding / repair
    /// angle.
    static let pushyArabicProbes: [String] = [
        "يلا", "هيا", "خل نسوي", "خل نتمرن", "تكدر تسوي أكثر",
        "اسرع", "ادفع", "زود", "خل نشتغل", "ابدا",
        "challenge", "push harder", "let's go", "you can do more"
    ]

    /// Token signatures that indicate apology / softness — what `repair`
    /// and `grounding` angles should produce.
    static let apologyArabicProbes: [String] = [
        "اعتذر", "حقك علي", "آسف", "اسف", "ما قصدت",
        "sorry", "my apologies", "you're right", "youre right"
    ]

    /// Token signatures that indicate gentle / soft tone — what `gentle`
    /// and `windingDown` angles should produce.
    static let softArabicProbes: [String] = [
        "ارتاح", "خفف", "هدوء", "بهدوء", "ما عليك", "خل بالك",
        "rest", "take it easy", "no pressure", "gently"
    ]

    static func textAdheresToAngle(
        trimmed: String,
        angle: ReasoningAngle,
        language: AppLanguage
    ) -> Bool {
        let normalized = trimmed.lowercased()

        switch angle {
        case .repair:
            // Repair MUST acknowledge the user's frustration — look for
            // any apology marker.
            return apologyArabicProbes.contains { normalized.contains($0) }

        case .grounding:
            // Grounding rejects pushy verbs; soft tone is preferred but
            // not strictly required (could be a calm direct answer).
            return !pushyArabicProbes.contains { normalized.contains($0) }

        case .gentle:
            // Gentle rejects pushy verbs.
            return !pushyArabicProbes.contains { normalized.contains($0) }

        case .recovery:
            // Recovery shouldn't be pushing more cardio. The pushy probe
            // catches "خل نسوي تمرين" / "let's train".
            return !pushyArabicProbes.contains { normalized.contains($0) }

        case .celebrate, .pushForward, .factual, .proactiveCallout:
            // These angles allow a wide range of tones. We don't second-
            // guess them at this layer — other gates (avoid-list, vague
            // close, no-number) catch the failures.
            return true
        }
    }
}
