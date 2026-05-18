import Foundation

/// Bridges the embedding-RAG `MemoryRetriever` into the LIVE chat prompt.
///
/// The synchronous lexical path (`CaptainCognitivePipeline.buildWorkingMemorySummary`)
/// only does `String.contains` token overlap, so it misses paraphrased and
/// cross-lingual recall: a fact stored last week as "ركبته اليسار تعورها" is not
/// retrieved when today the user says "خل أسوي تمرين أرجل قوي" — zero shared
/// tokens. The semantic retriever (`MemoryRetriever`) was only wired to the
/// proactive notification path, never to conversation. This enricher runs it
/// alongside the existing lexical summary and appends a deduped
/// `[recalled_memory]` block so the Captain actually recalls what it stored.
///
/// Hybrid by design: lexical stays the always-on base (and the only path on
/// free tier, where `TierGate.maxMemoryRetrievalDepth == 0` makes the retriever
/// return an empty bundle — this enricher then no-ops and returns the base
/// unchanged, so free tier is never regressed).
struct ChatMemoryEnricher: Sendable {

    func enrich(
        baseSummary: String,
        userMessage: String,
        screenContext: ScreenContext,
        sessionRecap: String? = nil
    ) async -> String {
        let recap = Self.recapBlock(from: sessionRecap)

        // Continuity (`[conversation_so_far]`) is ALWAYS prepended when
        // present, on every return path and every tier — it is basic
        // conversational competence, not a paid recall feature. When there is
        // no recap this collapses to the exact original behavior (zero
        // regression for short conversations).
        func compose(_ memoryPart: String) -> String {
            let trimmed = memoryPart.trimmingCharacters(in: .whitespacesAndNewlines)
            let memoryEmpty = trimmed.isEmpty
                || trimmed.contains("No high-signal long-term memories")
            if recap.isEmpty { return memoryPart }
            return memoryEmpty ? recap : recap + "\n\n" + memoryPart
        }

        let query = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        // Very short messages ("هلا", "ok") carry no retrieval signal.
        guard query.count >= 3 else { return compose(baseSummary) }

        let bundle = await MemoryRetriever.shared.retrieve(query: query)
        guard !bundle.isEmpty else { return compose(baseSummary) }

        let lines = recalledLines(from: bundle, excluding: baseSummary)
        guard !lines.isEmpty else { return compose(baseSummary) }

        let recalled = """
        [recalled_memory]
        \(lines.joined(separator: "\n"))
        هاي معلومات استرجعتها من ذاكرتك الطويلة لأنها مرتبطة بسياق هالرسالة. استعملها بطبيعية إذا تخدم الرد، ولا تعدّدها، ولا تكول "أتذكر".
        """

        let trimmedBase = baseSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBase.isEmpty || trimmedBase.contains("No high-signal long-term memories") {
            return compose(recalled)
        }
        return compose(baseSummary + "\n\n" + recalled)
    }

    /// Frames the pre-window session digest. Placed FIRST in working memory:
    /// it is the most immediate context (what we were just talking about),
    /// ahead of durable profile memory and semantic recall.
    private static func recapBlock(from recap: String?) -> String {
        guard let recap = recap?.trimmingCharacters(in: .whitespacesAndNewlines),
              !recap.isEmpty else { return "" }
        return """
        [conversation_so_far]
        المستخدم حچا وياك سابقاً بنفس هالمحادثة (مرتب من الأقدم لأحدث):
        \(recap)
        ابنِ على هذا الخيط: لا تنسى شنو طلب أو ذكر قبل، لا تعيد تسأله عن شي قاله، وخل ردك يكمّل المحادثة مو يبدأ من الصفر.
        """
    }

    // MARK: - Formatting

    /// Highest-signal first: durable facts, then strong behavioral patterns,
    /// then an unresolved emotional thread. Episodes are intentionally omitted —
    /// recent turns are already covered by Brain V2 `recentInteractions`, and
    /// weak on-device Arabic embeddings make episode recall low-precision.
    private func recalledLines(from bundle: MemoryBundle, excluding base: String) -> [String] {
        let normalizedBase = Self.normalize(base)
        var lines: [String] = []
        var seen: Set<String> = []

        func add(_ raw: String) {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 4 else { return }
            let key = Self.normalize(text)
            guard !seen.contains(key) else { return }
            // Skip anything the lexical base already surfaced (avoid duplication
            // in an already-large prompt). Prefix match catches near-dupes.
            let probe = String(key.prefix(24))
            if !probe.isEmpty, normalizedBase.contains(probe) { return }
            seen.insert(key)
            lines.append("- \(text)")
        }

        for fact in bundle.facts
        where !fact.isPII && !fact.userHidden && !fact.content.isEmpty {
            add(fact.content)
            if lines.count >= 6 { break }
        }

        for pattern in bundle.patterns
        where pattern.strength >= 0.5 && !pattern.patternDescription.isEmpty {
            add(pattern.patternDescription)
            if lines.count >= 7 { break }
        }

        if lines.count < 7,
           let emotion = bundle.emotions.first(where: { !$0.resolved && $0.intensity >= 0.5 }),
           !emotion.trigger.isEmpty {
            add("شعور ما انحل بعد مرتبط بـ: \(emotion.trigger)")
        }

        return Array(lines.prefix(7))
    }

    private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "ـ", with: "")
            .lowercased()
    }
}
