import Foundation

struct QuestEarnedAchievement: Codable, Identifiable {
    let id: UUID
    let questId: String
    let questName: String
    let badgeImageName: String
    let stageNumber: Int
    let earnedDate: Date

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: earnedDate)
    }
}

enum QuestAchievementStore {
    private static let storageKey = "aiqo.quest.earned_achievements"

    static func load() -> [QuestEarnedAchievement] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let achievements = try? JSONDecoder().decode([QuestEarnedAchievement].self, from: data)
        else { return [] }
        return achievements
    }

    static func save(_ achievements: [QuestEarnedAchievement]) {
        if let data = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    static func hasAchievement(for questId: String) -> Bool {
        load().contains(where: { $0.questId == questId })
    }
}
