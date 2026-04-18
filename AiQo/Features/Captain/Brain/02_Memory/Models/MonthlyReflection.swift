import Foundation
import SwiftData

@Model
final class MonthlyReflection {
    @Attribute(.unique) var id: UUID
    var monthStart: Date
    var generatedAt: Date
    var letterContent: String
    var topThemesJSON: Data?
    var topPatternsJSON: Data?
    var isRead: Bool
    var readAt: Date?

    init(
        monthStart: Date,
        letterContent: String,
        generatedAt: Date = Date()
    ) {
        id = UUID()
        self.monthStart = monthStart
        self.generatedAt = generatedAt
        self.letterContent = letterContent
        self.isRead = false
    }

    var topThemes: [String] {
        guard let topThemesJSON,
              let themes = try? JSONDecoder().decode([String].self, from: topThemesJSON) else {
            return []
        }
        return themes
    }

    var topPatterns: [String] {
        guard let topPatternsJSON,
              let patterns = try? JSONDecoder().decode([String].self, from: topPatternsJSON) else {
            return []
        }
        return patterns
    }

    func setTopThemes(_ themes: [String]) {
        topThemesJSON = try? JSONEncoder().encode(themes)
    }

    func setTopPatterns(_ patterns: [String]) {
        topPatternsJSON = try? JSONEncoder().encode(patterns)
    }
}
