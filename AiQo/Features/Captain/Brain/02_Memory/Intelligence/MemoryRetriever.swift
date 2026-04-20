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

        async let factsTask = fetchFacts(queryEmbedding: queryEmbedding, limit: factBudget)
        async let episodesTask = fetchEpisodes(queryEmbedding: queryEmbedding, limit: episodeBudget)
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
        queryEmbedding: [Double]?,
        limit: Int
    ) async -> [SemanticFactSnapshot] {
        let candidates = await SemanticStore.shared.all(limit: limit * 4)

        guard let qEmb = queryEmbedding else {
            return candidates
                .sorted { $0.lastConfirmedAt > $1.lastConfirmedAt }
                .prefix(limit)
                .map { $0 }
        }

        var scored: [(snapshot: SemanticFactSnapshot, score: Double)] = []
        for fact in candidates {
            var similarity = 0.0
            if let factEmb = await EmbeddingIndex.shared.embed(fact.content) {
                similarity = EmbeddingIndex.cosine(qEmb, factEmb)
            }
            let recencyBoost = Self.recencyScore(for: fact.lastConfirmedAt)
            let score = similarity * 0.6 + fact.confidence * 0.3 + recencyBoost * 0.1
            scored.append((fact, score))
        }
        return scored.sorted { $0.score > $1.score }.prefix(limit).map { $0.snapshot }
    }

    private func fetchEpisodes(
        queryEmbedding: [Double]?,
        limit: Int
    ) async -> [EpisodicEntrySnapshot] {
        let candidates = await EpisodicStore.shared.recentEntries(limit: limit * 4)

        guard let qEmb = queryEmbedding else {
            return Array(candidates.prefix(limit))
        }

        var scored: [(snapshot: EpisodicEntrySnapshot, score: Double)] = []
        for ep in candidates {
            var similarity = 0.0
            if let epEmb = await EmbeddingIndex.shared.embed(ep.userMessage) {
                similarity = EmbeddingIndex.cosine(qEmb, epEmb)
            }
            let recencyBoost = Self.recencyScore(for: ep.timestamp)
            let score = similarity * 0.5 + recencyBoost * 0.3 + ep.salienceScore * 0.2
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

    /// Exponential decay with 30-day half-life. Today = 1.0, six months ~ 0.
    private nonisolated static func recencyScore(for date: Date) -> Double {
        let hoursAgo = max(0, Date().timeIntervalSince(date) / 3600)
        let halfLifeHours = 720.0
        return exp(-hoursAgo / halfLifeHours)
    }
}
