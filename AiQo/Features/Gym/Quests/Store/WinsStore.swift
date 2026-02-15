import Foundation
internal import Combine

@MainActor
final class WinsStore: ObservableObject {
    @Published private(set) var wins: [ChallengeWin] = []

    private let defaults: UserDefaults
    private let storageKey = "aiqo.gym.quests.wins.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func addWin(challenge: Challenge, completedAt: Date, proofValue: String) {
        if hasWin(for: challenge.id, on: completedAt) {
            return
        }

        let win = ChallengeWin(
            challengeId: challenge.id,
            title: challenge.title,
            completedAt: completedAt,
            proofValue: proofValue,
            awardImageName: challenge.awardImageName
        )

        wins.insert(win, at: 0)
        wins.sort { $0.completedAt > $1.completedAt }
        save()

        Task {
            await uploadWinToSupabaseIfNeeded(win)
        }
    }

    func hasWin(for challengeId: String, on date: Date) -> Bool {
        wins.contains {
            $0.challengeId == challengeId && Calendar.current.isDate($0.completedAt, inSameDayAs: date)
        }
    }

    // Optional future sync path. Local save remains the source of truth.
    func uploadWinToSupabaseIfNeeded(_ win: ChallengeWin) async {
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
            wins = try JSONDecoder().decode([ChallengeWin].self, from: data)
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
}
