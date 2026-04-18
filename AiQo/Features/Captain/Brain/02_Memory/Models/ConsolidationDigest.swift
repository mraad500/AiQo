import Foundation
import SwiftData

@Model
final class ConsolidationDigest {
    @Attribute(.unique) var id: UUID
    var weekStart: Date
    var weekEnd: Date
    var summary: String
    var episodeCount: Int
    var factsExtracted: Int
    var emotionsDetected: Int
    var createdAt: Date

    init(
        weekStart: Date,
        weekEnd: Date,
        summary: String,
        episodeCount: Int,
        factsExtracted: Int,
        emotionsDetected: Int
    ) {
        id = UUID()
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.summary = summary
        self.episodeCount = episodeCount
        self.factsExtracted = factsExtracted
        self.emotionsDetected = emotionsDetected
        self.createdAt = Date()
    }
}
