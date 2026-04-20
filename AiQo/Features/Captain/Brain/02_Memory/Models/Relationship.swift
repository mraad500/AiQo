import Foundation
import SwiftData

enum RelationshipKind: String, Codable {
    case mother
    case father
    case spouse
    case child
    case sibling
    case friend
    case colleague
    case mentor
    case coach
    case other
}

@Model
final class Relationship {
    @Attribute(.unique) var id: UUID
    var name: String
    var displayName: String
    var kindRaw: String
    var mentionedEntryIdsJSON: Data?
    var emotionalWeight: Double
    var lastMentionedAt: Date
    var contextTagsJSON: Data?
    var sentiment: Double

    init(
        id: UUID = UUID(),
        name: String,
        kind: RelationshipKind,
        emotionalWeight: Double = 0.5,
        lastMentionedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.displayName = name
        self.kindRaw = kind.rawValue
        self.emotionalWeight = emotionalWeight
        self.lastMentionedAt = lastMentionedAt
        self.sentiment = 0
    }

    var kind: RelationshipKind {
        RelationshipKind(rawValue: kindRaw) ?? .other
    }

    var mentionedEntryIDs: [UUID] {
        guard let mentionedEntryIdsJSON,
              let ids = try? JSONDecoder().decode([UUID].self, from: mentionedEntryIdsJSON) else {
            return []
        }
        return ids
    }

    var contextTags: [String] {
        guard let contextTagsJSON,
              let tags = try? JSONDecoder().decode([String].self, from: contextTagsJSON) else {
            return []
        }
        return tags
    }

    func setMentionedEntryIDs(_ ids: [UUID]) {
        mentionedEntryIdsJSON = try? JSONEncoder().encode(ids)
    }

    func setContextTags(_ tags: [String]) {
        contextTagsJSON = try? JSONEncoder().encode(tags)
    }
}
