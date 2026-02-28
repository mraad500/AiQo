import Foundation

@MainActor
protocol QuestProgressStore {
    func load() -> [String: QuestProgressRecord]
    func save(_ records: [String: QuestProgressRecord])
}

@MainActor
final class UserDefaultsQuestProgressStore: QuestProgressStore {
    private let defaults: UserDefaults
    private let storageKey = "aiqo.quest.progress.records.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [String: QuestProgressRecord] {
        guard let data = defaults.data(forKey: storageKey) else {
            return [:]
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let decoded = try? decoder.decode([String: QuestProgressRecord].self, from: data) {
            return decoded
        }

        return [:]
    }

    func save(_ records: [String: QuestProgressRecord]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(records) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }
}

struct QuestDateKeyFactory {
    var calendar: Calendar

    private var isoWeekCalendar: Calendar {
        var iso = calendar
        iso.firstWeekday = 2
        iso.minimumDaysInFirstWeek = 4
        return iso
    }

    func dailyKey(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    func weeklyKey(for date: Date) -> String {
        let comps = isoWeekCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let y = comps.yearForWeekOfYear ?? 0
        let w = comps.weekOfYear ?? 0
        return String(format: "%04d-W%02d", y, w)
    }

    func startOfWeek(for date: Date) -> Date {
        let components = isoWeekCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return isoWeekCalendar.date(from: components) ?? calendar.startOfDay(for: date)
    }
}
