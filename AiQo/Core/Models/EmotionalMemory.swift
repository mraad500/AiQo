import Foundation
import SwiftData

enum EmotionKind: String, Codable, CaseIterable, Sendable {
    case grief
    case joy
    case anxiety
    case pride
    case shame
    case gratitude
    case frustration
    case fear
    case peace
    case longing
    case guilt
    case hope
    case anger
    case love
    case relief
    case contentment
}

@Model
final class EmotionalMemory {
    @Attribute(.unique) var id: UUID
    var trigger: String
    var emotionRaw: String
    var intensity: Double
    var date: Date
    var contextSnapshot: String
    var resolved: Bool
    var resolutionDate: Date?
    var associatedFactIdsJSON: Data?
    var bioContextJSON: Data?

    init(
        id: UUID = UUID(),
        trigger: String,
        emotion: EmotionKind,
        intensity: Double,
        date: Date = Date(),
        contextSnapshot: String = "",
        resolved: Bool = false
    ) {
        self.id = id
        self.trigger = trigger
        self.emotionRaw = emotion.rawValue
        self.intensity = intensity
        self.date = date
        self.contextSnapshot = contextSnapshot
        self.resolved = resolved
    }

    var emotion: EmotionKind {
        EmotionKind(rawValue: emotionRaw) ?? .peace
    }

    var associatedFactIDs: [UUID] {
        guard let associatedFactIdsJSON,
              let ids = try? JSONDecoder().decode([UUID].self, from: associatedFactIdsJSON) else {
            return []
        }
        return ids
    }

    var bioContext: BioSnapshot? {
        guard let bioContextJSON else { return nil }
        return try? JSONDecoder().decode(BioSnapshot.self, from: bioContextJSON)
    }

    func setAssociatedFactIDs(_ ids: [UUID]) {
        associatedFactIdsJSON = try? JSONEncoder().encode(ids)
    }

    func setBioContext(_ snapshot: BioSnapshot?) {
        bioContextJSON = snapshot.flatMap { try? JSONEncoder().encode($0) }
    }
}
