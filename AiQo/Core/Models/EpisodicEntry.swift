import Foundation
import SwiftData

@Model
final class EpisodicEntry {
    #Index<EpisodicEntry>([\.sessionID], [\.timestamp])

    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var timestamp: Date
    var captainResponseTimestamp: Date?
    var userMessageID: UUID
    var captainResponseMessageID: UUID?
    var userMessage: String
    var captainResponse: String
    var captainSpotifyRecommendationData: Data?
    var emotionalContextJSON: Data?
    var bioContextJSON: Data?
    var extractedFactIdsJSON: Data?
    var extractedEmotionIdsJSON: Data?
    var salienceScore: Double
    var accessCount: Int
    var lastAccessedAt: Date?
    var isConsolidated: Bool
    var consolidationDigest: String?

    init(
        id: UUID = UUID(),
        sessionID: UUID = UUID(),
        timestamp: Date = Date(),
        captainResponseTimestamp: Date? = nil,
        userMessageID: UUID = UUID(),
        captainResponseMessageID: UUID? = nil,
        userMessage: String,
        captainResponse: String,
        captainSpotifyRecommendation: SpotifyRecommendation? = nil,
        emotionalContext: EmotionalSnapshot? = nil,
        bioContext: BioSnapshot? = nil,
        salienceScore: Double = 0.5,
        accessCount: Int = 0,
        isConsolidated: Bool = false
    ) {
        self.id = id
        self.sessionID = sessionID
        self.timestamp = timestamp
        self.captainResponseTimestamp = captainResponseTimestamp
        self.userMessageID = userMessageID
        self.captainResponseMessageID = captainResponseMessageID
        self.userMessage = userMessage
        self.captainResponse = captainResponse
        self.salienceScore = salienceScore
        self.accessCount = accessCount
        self.isConsolidated = isConsolidated

        if let emotionalContext {
            emotionalContextJSON = try? JSONEncoder().encode(emotionalContext)
        }
        if let bioContext {
            bioContextJSON = try? JSONEncoder().encode(bioContext)
        }
        if let captainSpotifyRecommendation {
            captainSpotifyRecommendationData = try? JSONEncoder().encode(captainSpotifyRecommendation)
        }
    }

    var emotionalContext: EmotionalSnapshot? {
        guard let emotionalContextJSON else { return nil }
        return try? JSONDecoder().decode(EmotionalSnapshot.self, from: emotionalContextJSON)
    }

    var bioContext: BioSnapshot? {
        guard let bioContextJSON else { return nil }
        return try? JSONDecoder().decode(BioSnapshot.self, from: bioContextJSON)
    }

    var extractedFactIDs: [UUID] {
        guard let extractedFactIdsJSON,
              let ids = try? JSONDecoder().decode([UUID].self, from: extractedFactIdsJSON) else {
            return []
        }
        return ids
    }

    var extractedEmotionIDs: [UUID] {
        guard let extractedEmotionIdsJSON,
              let ids = try? JSONDecoder().decode([UUID].self, from: extractedEmotionIdsJSON) else {
            return []
        }
        return ids
    }

    var captainSpotifyRecommendation: SpotifyRecommendation? {
        guard let captainSpotifyRecommendationData else { return nil }
        return try? JSONDecoder().decode(SpotifyRecommendation.self, from: captainSpotifyRecommendationData)
    }

    func setExtractedFactIDs(_ ids: [UUID]) {
        extractedFactIdsJSON = try? JSONEncoder().encode(ids)
    }

    func setExtractedEmotionIDs(_ ids: [UUID]) {
        extractedEmotionIdsJSON = try? JSONEncoder().encode(ids)
    }

    func setCaptainSpotifyRecommendation(_ recommendation: SpotifyRecommendation?) {
        captainSpotifyRecommendationData = recommendation.flatMap { try? JSONEncoder().encode($0) }
    }
}
