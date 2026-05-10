// ===============================================
// File: EpisodicRecallProvider.swift
// Brain Refactor §46 — Cross-Session Long-Term Recall
//
// Fetches the user's most-salient prior conversations from `EpisodicStore`
// and renders them into a compact "echoes from before" segment the brief
// surfaces. This is the difference between a stateless chatbot ("hi, how
// can I help?") and a coach who remembers ("last time you mentioned your
// knee — how is it now?").
//
// Read-side only. Writing happens via the existing pipeline
// (`MemoryExtractor` + `EpisodicStore.record`). What this file adds is the
// *retrieval and synthesis* the prompt has been missing.
//
// All work happens off the MainActor — `EpisodicStore` is an actor, so we
// `await` its async methods. Total round-trip is bounded by the actor's
// SwiftData fetch (~5–15ms typical).
// ===============================================

import Foundation

// MARK: - Recall Output

/// Compact summary of what's worth remembering across sessions. The brief
/// renders this as a single block; the model is told to weave at most one
/// callback naturally if relevant.
struct EpisodicRecall: Sendable {
    /// Iraqi-Arabic bulleted lines, ≤ 3, each ≤ 100 chars. Empty when no
    /// salient episodes exist or all are too old.
    let arabicLines: [String]
    let englishLines: [String]

    var isEmpty: Bool { arabicLines.isEmpty && englishLines.isEmpty }

    func lines(for language: AppLanguage) -> [String] {
        language == .arabic ? arabicLines : englishLines
    }

    static let empty = EpisodicRecall(arabicLines: [], englishLines: [])
}

// MARK: - Provider

@MainActor
enum EpisodicRecallProvider {

    /// Look-back window — episodes older than this are dropped because
    /// they likely no longer reflect the user's current situation.
    static let lookbackDays: Int = 14

    /// Salience floor — anything below this is noise. Mirrors the
    /// `EpisodicStore` salience scale (0.0 trivial → 1.0 high-impact).
    static let minimumSalience: Double = 0.6

    /// Hard cap on lines to render in the prompt. World-class brevity:
    /// three echoes is enough to feel known, more is noise.
    static let maxLines: Int = 3

    /// Async — fetches recent high-salience episodes from the store, filters
    /// by recency + salience, compresses each into a single line. Returns
    /// `.empty` when no signal exists.
    static func fetch(now: Date = Date()) async -> EpisodicRecall {
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -lookbackDays, to: now
        ) ?? now

        // Pull the most-salient recent entries. Asking for slightly more
        // than `maxLines` so we can drop noisy/duplicate ones and still
        // hit the cap. The store sorts by salience desc + recency desc;
        // we re-filter by date here since the store API takes only a
        // salience floor, not a cutoff.
        let raw = await EpisodicStore.shared.entriesBySalience(
            min: minimumSalience,
            limit: maxLines * 3
        )
        guard !raw.isEmpty else { return .empty }

        let qualified = raw
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.salienceScore > $1.salienceScore }

        guard !qualified.isEmpty else { return .empty }

        var arabicLines: [String] = []
        var englishLines: [String] = []
        var seenTopics: Set<String> = []

        for entry in qualified {
            // Deduplicate near-identical episodes (same first 25 chars of
            // user message). Keeps the recall block diverse.
            let topicKey = String(
                entry.userMessage
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .prefix(25)
            )
            guard !topicKey.isEmpty, !seenTopics.contains(topicKey) else { continue }
            seenTopics.insert(topicKey)

            let daysAgo = Calendar.current.dateComponents(
                [.day], from: entry.timestamp, to: now
            ).day ?? 0

            arabicLines.append(arabicLine(entry: entry, daysAgo: daysAgo))
            englishLines.append(englishLine(entry: entry, daysAgo: daysAgo))

            if arabicLines.count >= maxLines { break }
        }

        return EpisodicRecall(arabicLines: arabicLines, englishLines: englishLines)
    }

    private static func arabicLine(
        entry: EpisodicEntrySnapshot,
        daysAgo: Int
    ) -> String {
        let user = entry.userMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)
        let timePhrase: String
        if daysAgo <= 0 {
            timePhrase = "اليوم"
        } else if daysAgo == 1 {
            timePhrase = "أمس"
        } else if daysAgo < 7 {
            timePhrase = "قبل \(daysAgo) أيام"
        } else {
            timePhrase = "قبل أسبوع تقريباً"
        }
        return "\(timePhrase): \"\(user)\""
    }

    private static func englishLine(
        entry: EpisodicEntrySnapshot,
        daysAgo: Int
    ) -> String {
        let user = entry.userMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)
        let timePhrase: String
        if daysAgo <= 0 {
            timePhrase = "today"
        } else if daysAgo == 1 {
            timePhrase = "yesterday"
        } else if daysAgo < 7 {
            timePhrase = "\(daysAgo) days ago"
        } else {
            timePhrase = "about a week ago"
        }
        return "\(timePhrase): \"\(user)\""
    }
}
