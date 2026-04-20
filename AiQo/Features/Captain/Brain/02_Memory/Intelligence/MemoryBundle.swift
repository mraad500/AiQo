import Foundation

/// Result of a unified memory retrieval — what the Captain pulls into context.
struct MemoryBundle: Sendable {
    let facts: [SemanticFactSnapshot]
    let episodes: [EpisodicEntrySnapshot]
    let patterns: [ProceduralPatternSnapshot]
    let emotions: [EmotionalMemorySnapshot]
    let relationships: [RelationshipSnapshot]
    let retrievedAt: Date

    nonisolated init(
        facts: [SemanticFactSnapshot] = [],
        episodes: [EpisodicEntrySnapshot] = [],
        patterns: [ProceduralPatternSnapshot] = [],
        emotions: [EmotionalMemorySnapshot] = [],
        relationships: [RelationshipSnapshot] = [],
        retrievedAt: Date = Date()
    ) {
        self.facts = facts
        self.episodes = episodes
        self.patterns = patterns
        self.emotions = emotions
        self.relationships = relationships
        self.retrievedAt = retrievedAt
    }

    nonisolated var totalItems: Int {
        facts.count + episodes.count + patterns.count + emotions.count + relationships.count
    }

    nonisolated var isEmpty: Bool { totalItems == 0 }
}
