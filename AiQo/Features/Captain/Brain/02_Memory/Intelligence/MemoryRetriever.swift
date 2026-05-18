import Foundation

/// Unified RAG: pulls the most relevant memories across all 5 stores for a query.
/// Tier-aware depth via `TierGate.maxMemoryRetrievalDepth`.
actor MemoryRetriever {
    static let shared = MemoryRetriever()

    private init() {}

    /// Retrieve the most relevant memories for `query` given the user's current bio state.
    /// Budget split: facts 40%, episodes 25%, patterns 15%, emotions 10%, relationships 10%.
    func retrieve(
        query: String,
        bioContext: BioSnapshot? = nil,
        tier: SubscriptionTier? = nil,
        customLimit: Int? = nil
    ) async -> MemoryBundle {
        let resolvedTier = tier ?? TierGate.shared.currentTier
        let totalBudget = customLimit ?? TierGate.shared.maxMemoryRetrievalDepth

        guard totalBudget > 0 else {
            diag.info("MemoryRetriever: zero budget (tier=\(resolvedTier))")
            return MemoryBundle()
        }

        let queryEmbedding = await EmbeddingIndex.shared.embed(query)

        let factBudget = max(1, Int(Double(totalBudget) * 0.40))
        let episodeBudget = max(1, Int(Double(totalBudget) * 0.25))
        let patternBudget = max(1, Int(Double(totalBudget) * 0.15))
        let emotionBudget = max(1, Int(Double(totalBudget) * 0.10))
        let relationshipBudget = max(1, Int(Double(totalBudget) * 0.10))

        async let factsTask = fetchFacts(query: query, queryEmbedding: queryEmbedding, limit: factBudget)
        async let episodesTask = fetchEpisodes(query: query, queryEmbedding: queryEmbedding, limit: episodeBudget)
        async let patternsTask = fetchPatterns(limit: patternBudget)
        async let emotionsTask = fetchEmotions(limit: emotionBudget)
        async let relationshipsTask = fetchRelationships(in: query, limit: relationshipBudget)

        let facts = await factsTask
        let episodes = await episodesTask
        let patterns = await patternsTask
        let emotions = await emotionsTask
        let relationships = await relationshipsTask

        let bundle = MemoryBundle(
            facts: facts,
            episodes: episodes,
            patterns: patterns,
            emotions: emotions,
            relationships: relationships
        )

        diag.info(
            "MemoryRetriever: tier=\(resolvedTier) total=\(bundle.totalItems) " +
            "facts=\(bundle.facts.count) ep=\(bundle.episodes.count) " +
            "pat=\(bundle.patterns.count) emo=\(bundle.emotions.count) rel=\(bundle.relationships.count)"
        )

        return bundle
    }

    // MARK: - Private fetch helpers

    private func fetchFacts(
        query: String,
        queryEmbedding: [Double]?,
        limit: Int
    ) async -> [SemanticFactSnapshot] {
        let candidates = await SemanticStore.shared.all(limit: limit * 4)
        guard !candidates.isEmpty else { return [] }

        let queryTokens = CaptainCognitiveTextAnalyzer.tokens(from: query)

        var scored: [(snapshot: SemanticFactSnapshot, score: Double)] = []
        for fact in candidates {
            var similarity = 0.0
            if let qEmb = queryEmbedding {
                // Prefer the embedding persisted at write time; only compute
                // on the fly for legacy facts stored before persistence (the
                // EmbeddingIndex text cache still covers those).
                let factEmb: [Double]?
                if let data = fact.embeddingJSON,
                   let stored = try? JSONDecoder().decode([Double].self, from: data) {
                    factEmb = stored
                } else {
                    factEmb = await EmbeddingIndex.shared.embed(fact.content)
                }
                if let factEmb {
                    similarity = EmbeddingIndex.cosine(qEmb, factEmb)
                }
            }
            // Lexical overlap is the robustness floor. Apple ships no Arabic
            // word vectors on many devices (embedding nil), and an Arabic
            // query vs an English-stored fact lives in a different vector
            // space (cosine ≈ 0). Without this term, retrieval silently
            // collapsed to confidence+recency — semantic recall in name only.
            let lexical = Self.lexicalOverlap(queryTokens: queryTokens, content: fact.content)
            let recencyBoost = Self.recencyScore(for: fact.lastConfirmedAt)
            let score = similarity * 0.5
                + lexical * 0.30
                + fact.confidence * 0.15
                + recencyBoost * 0.05
            scored.append((fact, score))
        }
        return scored.sorted { $0.score > $1.score }.prefix(limit).map { $0.snapshot }
    }

    private func fetchEpisodes(
        query: String,
        queryEmbedding: [Double]?,
        limit: Int
    ) async -> [EpisodicEntrySnapshot] {
        let candidates = await EpisodicStore.shared.recentEntries(limit: limit * 4)
        guard !candidates.isEmpty else { return [] }

        let queryTokens = CaptainCognitiveTextAnalyzer.tokens(from: query)

        var scored: [(snapshot: EpisodicEntrySnapshot, score: Double)] = []
        for ep in candidates {
            var similarity = 0.0
            if let qEmb = queryEmbedding,
               let epEmb = await EmbeddingIndex.shared.embed(ep.userMessage) {
                similarity = EmbeddingIndex.cosine(qEmb, epEmb)
            }
            // Lexical floor — see fetchFacts. Keeps episode recall alive when
            // on-device embeddings are unavailable or cross-lingual.
            let lexical = Self.lexicalOverlap(queryTokens: queryTokens, content: ep.userMessage)
            let recencyBoost = Self.recencyScore(for: ep.timestamp)
            let score = similarity * 0.4
                + lexical * 0.25
                + recencyBoost * 0.2
                + ep.salienceScore * 0.15
            scored.append((ep, score))
        }
        return scored.sorted { $0.score > $1.score }.prefix(limit).map { $0.snapshot }
    }

    private func fetchPatterns(limit: Int) async -> [ProceduralPatternSnapshot] {
        let patterns = await ProceduralStore.shared.patterns(minStrength: 0.5, limit: limit)
        return Array(patterns.prefix(limit))
    }

    private func fetchEmotions(limit: Int) async -> [EmotionalMemorySnapshot] {
        let unresolved = await EmotionalStore.shared.unresolvedEmotions(
            olderThan: 3,
            minIntensity: 0.5,
            limit: limit
        )
        return Array(unresolved.prefix(limit))
    }

    private func fetchRelationships(
        in query: String,
        limit: Int
    ) async -> [RelationshipSnapshot] {
        let mentioned = await RelationshipStore.shared.recentlyMentioned(in: query, within: 90)
        return Array(mentioned.prefix(limit))
    }

    /// Fraction of query tokens that also appear in the candidate content
    /// (0...1). Uses the same tokenizer/stopwords as the lexical ranker so
    /// Arabic↔Arabic recall stays consistent app-wide.
    private nonisolated static func lexicalOverlap(
        queryTokens: Set<String>,
        content: String
    ) -> Double {
        guard !queryTokens.isEmpty else { return 0 }
        let contentTokens = CaptainCognitiveTextAnalyzer.tokens(from: content)
        guard !contentTokens.isEmpty else { return 0 }
        let overlap = queryTokens.intersection(contentTokens).count
        return Double(overlap) / Double(queryTokens.count)
    }

    /// Exponential decay with 30-day half-life. Today = 1.0, six months ~ 0.
    private nonisolated static func recencyScore(for date: Date) -> Double {
        let hoursAgo = max(0, Date().timeIntervalSince(date) / 3600)
        let halfLifeHours = 720.0
        return exp(-hoursAgo / halfLifeHours)
    }
}
