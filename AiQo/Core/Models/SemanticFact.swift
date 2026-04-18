import Foundation
import SwiftData

enum FactCategory: String, Codable, CaseIterable, Sendable {
    case health
    case preference
    case goal
    case relationship
    case work
    case habit
    case aspiration
    case fear
    case accomplishment
    case other
}

enum FactSource: String, Codable, Sendable {
    case extracted
    case explicit
    case inferred
}

@Model
final class SemanticFact {
    #Index<SemanticFact>([\.categoryRaw], [\.storageKey])

    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var storageKey: String
    var content: String
    var categoryRaw: String
    var confidence: Double
    var salience: Double
    var sourceRaw: String
    var firstMentionedAt: Date
    var lastConfirmedAt: Date
    var lastReferencedAt: Date?
    var mentionCount: Int
    var referenceCount: Int
    var relatedEntryIdsJSON: Data?
    var isPII: Bool
    var isSensitive: Bool
    var userHidden: Bool
    var embeddingJSON: Data?

    init(
        id: UUID = UUID(),
        storageKey: String = UUID().uuidString,
        content: String,
        category: FactCategory,
        categoryRawOverride: String? = nil,
        confidence: Double,
        salience: Double = 0.5,
        source: FactSource,
        sourceRawOverride: String? = nil,
        firstMentionedAt: Date = Date(),
        lastConfirmedAt: Date? = nil,
        mentionCount: Int = 1,
        referenceCount: Int = 0,
        isPII: Bool = false,
        isSensitive: Bool = false
    ) {
        self.id = id
        self.storageKey = storageKey
        self.content = content
        self.categoryRaw = categoryRawOverride ?? category.rawValue
        self.confidence = confidence
        self.salience = salience
        self.sourceRaw = sourceRawOverride ?? source.rawValue
        self.firstMentionedAt = firstMentionedAt
        self.lastConfirmedAt = lastConfirmedAt ?? firstMentionedAt
        self.lastReferencedAt = nil
        self.mentionCount = mentionCount
        self.referenceCount = referenceCount
        self.isPII = isPII
        self.isSensitive = isSensitive
        self.userHidden = false
    }

    var category: FactCategory {
        FactCategory(rawValue: categoryRaw) ?? .other
    }

    var source: FactSource {
        FactSource(rawValue: sourceRaw) ?? .extracted
    }

    var effectiveConfidence: Double {
        let months = Date().timeIntervalSince(lastConfirmedAt) / (30 * 86_400)
        return confidence * pow(0.9, months)
    }

    var isCloudSafe: Bool {
        !isPII && !isSensitive
    }

    var relatedEntryIDs: [UUID] {
        guard let relatedEntryIdsJSON,
              let ids = try? JSONDecoder().decode([UUID].self, from: relatedEntryIdsJSON) else {
            return []
        }
        return ids
    }

    func setRelatedEntryIDs(_ ids: [UUID]) {
        relatedEntryIdsJSON = try? JSONEncoder().encode(ids)
    }
}
