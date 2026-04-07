import Foundation
internal import Combine

@MainActor
final class WinsStore: ObservableObject {
    @Published private(set) var wins: [WinRecord] = []

    private let defaults: UserDefaults
    private let storageKey = "aiqo.gym.quests.wins.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func addWin(
        challenge: Challenge,
        completedAt: Date,
        completedDayKey: String,
        proofValue: String,
        isBoss: Bool = false
    ) {
        if hasWin(for: challenge.id, dayKey: completedDayKey) {
            return
        }

        let win = WinRecord(
            challengeId: challenge.id,
            title: challenge.title,
            completedAt: completedAt,
            completedDayKey: completedDayKey,
            proofValue: proofValue,
            awardImageName: challenge.awardImageName,
            isBoss: isBoss
        )

        wins.insert(win, at: 0)
        wins.sort { $0.completedAt > $1.completedAt }
        save()

        Task {
            await uploadWinToSupabaseIfNeeded(win)
        }
    }

    func hasWin(for challengeId: String, dayKey: String) -> Bool {
        wins.contains {
            $0.challengeId == challengeId && $0.completedDayKey == dayKey
        }
    }

    func hasWin(for challengeId: String, on date: Date) -> Bool {
        hasWin(for: challengeId, dayKey: Self.dayKey(for: date))
    }

    // Optional future sync path. Local save remains the source of truth.
    func uploadWinToSupabaseIfNeeded(_ win: WinRecord) async {
        _ = win
        // Example future implementation:
        // try? await SupabaseService.shared.client
        //     .from("quest_wins")
        //     .insert(win)
        //     .execute()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            wins = []
            return
        }

        do {
            wins = try JSONDecoder().decode([WinRecord].self, from: data)
            wins.sort { $0.completedAt > $1.completedAt }
        } catch {
            wins = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(wins)
            defaults.set(data, forKey: storageKey)
        } catch {
            // Keep app running even if persistence fails.
        }
    }

    private static func dayKey(for date: Date) -> String {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: startOfDay)
    }
}
