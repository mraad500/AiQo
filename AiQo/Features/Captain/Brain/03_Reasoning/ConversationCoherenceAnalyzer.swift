// ===============================================
// File: ConversationCoherenceAnalyzer.swift
// Brain Refactor §34 — Conversation Coherence
//
// Extracts *structured tags* from the last few user turns so the prompt can
// hard-encode constraints like "user just said they walked 45 min — don't
// suggest walking" or "user complained about tired legs — don't push HIIT."
//
// This complements RecentActivitySnapshot (which reads `WorkoutHistoryStore`
// — the *tracked* workouts). Many activities are mentioned in chat without
// being tracked ("رحت مشيت بالحديقة"); this analyzer catches those too.
//
// All detection is deterministic keyword/pattern matching — no LLM call,
// runs on MainActor in <1ms for typical conversation windows.
// ===============================================

import Foundation

// MARK: - Tags

/// User explicitly stated they completed an activity in this conversation —
/// either as a *claim* ("مشيت 45 دقيقة") or as a *reference* ("بعد المشي").
/// Anti-repeat rule: do not suggest the same family in the next reply.
struct CompletedActivityClaim: Sendable {
    let family: RecentActivityFamily
    /// First ~80 chars of the user message that triggered the match — useful
    /// for the prompt to *quote* the user back ("توك گلت: 'مشيت 45 د'").
    let userQuote: String
}

/// User explicitly refused or complained about an activity. Subtler than a
/// completion claim — captures things like "ما أريد ركض اليوم" or "تعبت من
/// التمارين القوية." Suppresses suggestions in that family.
struct ActivityRefusal: Sendable {
    /// `nil` when the refusal is generic ("ما عندي خلق أتمرن") — in that case
    /// the layer drops *all* effort-heavy suggestions.
    let family: RecentActivityFamily?
    let userQuote: String
}

/// The result of analyzing the conversation window. Empty (`isEmpty == true`)
/// when no actionable signal is found — the prompt layer skips itself.
struct ConversationContextTags: Sendable {
    let completedClaims: [CompletedActivityClaim]
    let refusals: [ActivityRefusal]
    /// Strongest emotional signal found in the *most recent* user turn. Used
    /// to override the time-of-day tone when the user is clearly tired or
    /// frustrated even at peak hours.
    let latestEmotion: CaptainEmotionalSignal?
    /// `true` when the latest user turn shows frustration directed *at the
    /// Captain* itself (e.g. "ليش هيج؟", "شبيك؟", "ما فهمت"). Triggers an
    /// apology + recovery directive in the prompt.
    let userIsFrustratedWithCaptain: Bool

    var isEmpty: Bool {
        completedClaims.isEmpty
            && refusals.isEmpty
            && latestEmotion == nil
            && !userIsFrustratedWithCaptain
    }

    /// Distinct activity families the next reply must NOT suggest — union of
    /// completed claims + targeted refusals. Caller-friendly.
    var familiesToAvoid: [RecentActivityFamily] {
        var seen: Set<RecentActivityFamily> = []
        var out: [RecentActivityFamily] = []
        for claim in completedClaims where seen.insert(claim.family).inserted {
            out.append(claim.family)
        }
        for refusal in refusals {
            if let family = refusal.family, seen.insert(family).inserted {
                out.append(family)
            }
        }
        return out
    }

    /// §50 Round 4 Fix β — split avoidances by intent strength.
    ///
    /// "Just completed" is a *soft* avoid: don't suggest doing it again
    /// right now. Comes back online tomorrow.
    ///
    /// "Explicitly refused" is a *hard* avoid: the user said no. Don't
    /// resurface for the rest of this session at minimum.
    ///
    /// The prompt layer renders these with different language so the model
    /// understands why each family is on the list — and the user gets a
    /// reply that respects refusal absolutely while still being open to
    /// suggesting a recently-completed activity *tomorrow*.
    var hardAvoidances: [RecentActivityFamily] {
        var seen: Set<RecentActivityFamily> = []
        return refusals.compactMap { refusal in
            guard let family = refusal.family,
                  seen.insert(family).inserted else { return nil }
            return family
        }
    }

    var softAvoidances: [RecentActivityFamily] {
        let hard = Set(hardAvoidances)
        var seen: Set<RecentActivityFamily> = []
        return completedClaims.compactMap { claim in
            guard seen.insert(claim.family).inserted,
                  !hard.contains(claim.family) else { return nil }
            return claim.family
        }
    }

    static let empty = ConversationContextTags(
        completedClaims: [],
        refusals: [],
        latestEmotion: nil,
        userIsFrustratedWithCaptain: false
    )
}

// MARK: - Analyzer

@MainActor
final class ConversationCoherenceAnalyzer {
    static let shared = ConversationCoherenceAnalyzer()

    /// How many of the most recent user turns to scan. Larger windows catch
    /// "I walked 4 messages ago" but cost more matching time. 5 is enough to
    /// span a typical 1-screen exchange.
    private let userTurnLookback: Int = 5

    private init() {}

    /// Produces a fresh tag set from the conversation. `recentActivity` is the
    /// authoritative `WorkoutHistoryStore` snapshot — when present, it is
    /// folded into `completedClaims` so the prompt has a single source of
    /// truth for "what to avoid."
    func analyze(
        conversation: [CaptainConversationMessage],
        recentActivity: RecentActivitySnapshot?
    ) -> ConversationContextTags {
        let userTurns = conversation
            .filter { $0.role == .user }
            .suffix(userTurnLookback)

        guard !userTurns.isEmpty || recentActivity != nil else {
            return .empty
        }

        var completed: [CompletedActivityClaim] = []
        var refusals: [ActivityRefusal] = []
        var latestEmotion: CaptainEmotionalSignal?
        var captainFrustration = false

        // Fold the tracked workout in first — it's the most authoritative
        // signal and we want it at index 0 in the avoid-list. Only when fresh
        // enough to still constrain the next reply.
        if let activity = recentActivity, activity.freshness != .stale {
            let quote = "آخر تمرين مسجّل: \(activity.title) — \(activity.durationMinutes) دقيقة"
            completed.append(
                CompletedActivityClaim(family: activity.family, userQuote: quote)
            )
        }

        // Scan user turns oldest → newest so `latestEmotion` ends up as the
        // signal from the most recent turn (the one we care about).
        for (index, turn) in userTurns.enumerated() {
            let normalized = Self.normalize(turn.content)

            // 1) Completed-activity claims
            if let family = Self.detectCompletedActivity(normalized: normalized) {
                let alreadyTracked = completed.contains { $0.family == family }
                if !alreadyTracked {
                    completed.append(
                        CompletedActivityClaim(
                            family: family,
                            userQuote: Self.truncate(turn.content, to: 80)
                        )
                    )
                }
            }

            // 2) Refusals / complaints
            if let refusal = Self.detectRefusal(normalized: normalized) {
                refusals.append(
                    ActivityRefusal(
                        family: refusal,
                        userQuote: Self.truncate(turn.content, to: 80)
                    )
                )
            } else if Self.detectsGenericRefusal(normalized: normalized) {
                refusals.append(
                    ActivityRefusal(
                        family: nil,
                        userQuote: Self.truncate(turn.content, to: 80)
                    )
                )
            }

            // 3) Emotional signal — only the latest turn matters
            let isLatestTurn = index == userTurns.count - 1
            if isLatestTurn {
                let signal = CaptainEmotionalSignal.detect(message: turn.content)
                if signal != .neutral {
                    latestEmotion = signal
                }
                captainFrustration = Self.detectsCaptainFrustration(normalized: normalized)
            }
        }

        return ConversationContextTags(
            completedClaims: completed,
            refusals: refusals,
            latestEmotion: latestEmotion,
            userIsFrustratedWithCaptain: captainFrustration
        )
    }
}

// MARK: - Detectors (private)

private extension ConversationCoherenceAnalyzer {

    /// Same normalization the rest of the cognitive pipeline uses — strip
    /// diacritics, fold case, drop tatweel.
    static func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "ـ", with: "")
            .lowercased()
    }

    static func truncate(_ text: String, to max: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > max else { return trimmed }
        return String(trimmed.prefix(max)) + "…"
    }

    /// Returns the activity family the user *claims* to have completed. Looks
    /// for past-tense verb patterns paired with activity tokens. Iraqi past
    /// tense lacks a single particle, so we rely on verb stems + activity
    /// noun co-occurrence.
    static func detectCompletedActivity(normalized: String) -> RecentActivityFamily? {
        // Iraqi/MSA past-tense markers we look for in the same window as an
        // activity noun. "خلصت", "سويت", "رحت", "كملت", "مشيت", "ركضت",
        // "تمرنت", "لعبت", plus English "just/already X-ed".
        let pastMarkers = [
            "خلصت", "سويت", "رحت", "كملت", "انتهيت", "صار", "توه",
            "هسة", "هسه", "قبل شوي", "قبل شوية", "هلگ", "هلاگ",
            "just did", "just finished", "i did", "i went", "already",
            "completed", "finished"
        ]
        let hasPastMarker = pastMarkers.contains { normalized.contains($0) }

        // Direct past-tense verbs that imply completion without needing a
        // separate marker. "مشيت" alone is enough.
        struct VerbHit { let token: String; let family: RecentActivityFamily }
        let directVerbs: [VerbHit] = [
            VerbHit(token: "مشيت", family: .walking),
            VerbHit(token: "تمشيت", family: .walking),
            VerbHit(token: "ركضت", family: .running),
            VerbHit(token: "جريت", family: .running),
            VerbHit(token: "سبحت", family: .swimming),
            VerbHit(token: "تمرنت", family: .strength),
            VerbHit(token: "رفعت حديد", family: .strength),
            VerbHit(token: "لاكمت", family: .boxing),
            VerbHit(token: "نطيت حبل", family: .jumpRope),
            VerbHit(token: "i walked", family: .walking),
            VerbHit(token: "i ran", family: .running),
            VerbHit(token: "i swam", family: .swimming),
            VerbHit(token: "i lifted", family: .strength),
            VerbHit(token: "i trained", family: .strength),
            VerbHit(token: "i biked", family: .cycling),
            VerbHit(token: "i cycled", family: .cycling)
        ]
        for verb in directVerbs where normalized.contains(verb.token) {
            return verb.family
        }

        // Past marker + activity noun in the same window (rough heuristic —
        // close enough for natural Iraqi chat).
        struct NounHit { let token: String; let family: RecentActivityFamily }
        let activityNouns: [NounHit] = [
            NounHit(token: "مشي",       family: .walking),
            NounHit(token: "ركض",       family: .running),
            NounHit(token: "جري",       family: .running),
            NounHit(token: "كارديو",    family: .cinematic),
            NounHit(token: "حديد",      family: .strength),
            NounHit(token: "قوة",       family: .strength),
            NounHit(token: "مقاوم",     family: .strength),
            NounHit(token: "يوغا",      family: .yoga),
            NounHit(token: "بيلاتس",    family: .pilates),
            NounHit(token: "سباح",      family: .swimming),
            NounHit(token: "دراج",      family: .cycling),
            NounHit(token: "ملاكم",     family: .boxing),
            NounHit(token: "كرة",       family: .sport),
            NounHit(token: "بادل",      family: .sport),
            NounHit(token: "تنس",       family: .sport),
            NounHit(token: "نط حبل",    family: .jumpRope),
            NounHit(token: "درج",       family: .stairs),
            NounHit(token: "إليبتكال",  family: .elliptical),
            NounHit(token: "امتنان",    family: .gratitude),
            NounHit(token: "walk",      family: .walking),
            NounHit(token: "run",       family: .running),
            NounHit(token: "cardio",    family: .cinematic),
            NounHit(token: "lift",      family: .strength),
            NounHit(token: "yoga",      family: .yoga),
            NounHit(token: "pilates",   family: .pilates),
            NounHit(token: "swim",      family: .swimming),
            NounHit(token: "cycl",      family: .cycling),
            NounHit(token: "box",       family: .boxing),
            NounHit(token: "gratitude", family: .gratitude)
        ]
        if hasPastMarker {
            for noun in activityNouns where normalized.contains(noun.token) {
                return noun.family
            }
        }

        return nil
    }

    /// Returns the family the user is refusing/complaining about, e.g.
    /// "ما أريد أمشي" → .walking. `nil` here means no targeted refusal — the
    /// caller falls through to `detectsGenericRefusal`.
    static func detectRefusal(normalized: String) -> RecentActivityFamily? {
        let refusalMarkers = [
            "ما أريد", "ما اريد", "ما ابي", "ما أبي", "ماني ودي", "مالي خلق",
            "ما يصير", "كرهت", "تعبت من", "زهقت من", "ملّيت من", "ملّيت",
            "ما أحب", "ما احب",
            "i don't want", "dont want", "i hate", "tired of", "bored of",
            "no more", "stop suggesting", "not "
        ]
        let hasRefusal = refusalMarkers.contains { normalized.contains($0) }
        guard hasRefusal else { return nil }

        // Reuse the noun list from completed-activity detection — same surface.
        struct NounHit { let token: String; let family: RecentActivityFamily }
        let activityNouns: [NounHit] = [
            NounHit(token: "مشي",     family: .walking),
            NounHit(token: "ركض",     family: .running),
            NounHit(token: "جري",     family: .running),
            NounHit(token: "كارديو",  family: .cinematic),
            NounHit(token: "حديد",    family: .strength),
            NounHit(token: "قوة",     family: .strength),
            NounHit(token: "يوغا",    family: .yoga),
            NounHit(token: "سباح",    family: .swimming),
            NounHit(token: "دراج",    family: .cycling),
            NounHit(token: "ملاكم",   family: .boxing),
            NounHit(token: "كرة",     family: .sport),
            NounHit(token: "walk",    family: .walking),
            NounHit(token: "run",     family: .running),
            NounHit(token: "cardio",  family: .cinematic),
            NounHit(token: "lift",    family: .strength),
            NounHit(token: "yoga",    family: .yoga),
            NounHit(token: "swim",    family: .swimming),
            NounHit(token: "cycl",    family: .cycling),
            NounHit(token: "box",     family: .boxing)
        ]
        for noun in activityNouns where normalized.contains(noun.token) {
            return noun.family
        }
        return nil
    }

    /// Generic "I don't want to do anything" — no specific family attached.
    /// The layer treats this as a soft "lower the intensity" hint rather than
    /// a hard avoid-list entry.
    static func detectsGenericRefusal(normalized: String) -> Bool {
        let phrases = [
            "ما عندي خلق",  "مالي خلق", "تعبان كلش", "ميت من التعب",
            "ما أگدر", "ما اقدر", "خلص ما أريد",
            "i can't", "im exhausted", "i'm exhausted", "no energy"
        ]
        return phrases.contains { normalized.contains($0) }
    }

    /// Detects when the user is angry *at the Captain* (not at their day or
    /// their body). Distinct from generic frustration — triggers a sincere
    /// apology + reset directive.
    static func detectsCaptainFrustration(normalized: String) -> Bool {
        let phrases = [
            "ليش هيج", "شبيك", "شبيكك", "ما فهمت", "غبي", "ما تفهم",
            "كذا مرة", "كرر", "نفس الكلام", "ليش تكرر",
            "why are you", "youre dumb", "you're dumb", "you don't understand",
            "you keep", "stop saying"
        ]
        return phrases.contains { normalized.contains($0) }
    }
}
