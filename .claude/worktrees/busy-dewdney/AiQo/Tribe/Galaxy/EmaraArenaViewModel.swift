import SwiftUI
import SwiftData
import os.log

/// Lightweight value type for leaderboard rows — avoids tuple in `@Published`.
struct LeaderboardRow: Identifiable {
    let id = UUID()
    let tribeName: String
    let score: Double
    let rank: Int
}

/// Value type for global user leaderboard entries fetched from Supabase.
struct GlobalUserRow: Identifiable, Sendable {
    let id: String
    let displayName: String
    let username: String
    let level: Int
    let points: Int
    let isProfilePublic: Bool
    let rank: Int

    var initials: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "AQ" }
        let words = trimmed.split(separator: " ").prefix(2)
        if words.count > 1 {
            return words.compactMap(\.first).map(String.init).joined()
        }
        return String(trimmed.prefix(2))
    }
}

/// Single source of truth for Arena & Tribe state across the Emara tab.
/// Bridges `SupabaseArenaService` to the UI layer via observable properties.
@MainActor
@Observable
final class EmaraArenaViewModel {

    // MARK: - State

    private(set) var myTribe: ArenaTribe?
    private(set) var tribeMembers: [ArenaTribeMember] = []
    private(set) var leaderboard: [LeaderboardRow] = []
    private(set) var hallOfFame: [ArenaHallOfFameEntry] = []
    private(set) var globalUsers: [GlobalUserRow] = []
    private(set) var currentChallenge: ArenaWeeklyChallenge?
    private(set) var isLoading = false
    var errorMessage: String?

    private let service = SupabaseArenaService.shared
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "EmaraArenaVM"
    )

    // MARK: - Load My Tribe

    func loadMyTribe(context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let tribe = try await service.fetchMyTribeDetails(context: context)
            myTribe = tribe
            tribeMembers = tribe?.members ?? []
        } catch {
            handleError(error, context: "loadMyTribe")
        }
    }

    // MARK: - Load Leaderboard

    func loadLeaderboard(context: ModelContext) async {
        do {
            try await service.fetchGlobalLeaderboard(context: context)

            let descriptor = FetchDescriptor<ArenaTribeParticipation>(
                sortBy: [SortDescriptor(\.currentScore, order: .reverse)]
            )
            let participations = (try? context.fetch(descriptor)) ?? []

            leaderboard = participations.compactMap { p in
                guard let name = p.tribe?.name else { return nil }
                return LeaderboardRow(tribeName: name, score: p.currentScore, rank: p.rank)
            }
        } catch {
            handleError(error, context: "loadLeaderboard")
        }
    }

    // MARK: - Load Hall of Fame

    func loadHallOfFame(context: ModelContext) async {
        do {
            try await service.fetchHallOfFame(context: context)

            let descriptor = FetchDescriptor<ArenaHallOfFameEntry>(
                sortBy: [SortDescriptor(\.weekNumber, order: .reverse)]
            )
            hallOfFame = (try? context.fetch(descriptor)) ?? []
        } catch {
            handleError(error, context: "loadHallOfFame")
        }
    }

    // MARK: - Load Global User Leaderboard

    func loadGlobalUsers() async {
        do {
            globalUsers = try await service.fetchGlobalUserLeaderboard()
        } catch {
            handleError(error, context: "loadGlobalUsers")
        }
    }

    // MARK: - Load Current Challenge

    func loadCurrentChallenge(context: ModelContext) async {
        do {
            let challenge = try await service.fetchCurrentChallenge(context: context)
            if let challenge {
                currentChallenge = challenge
            } else {
                // No active challenge — create a default one
                currentChallenge = try await service.createDefaultChallenge(context: context)
            }
        } catch {
            handleError(error, context: "loadCurrentChallenge")
        }
    }

    // MARK: - Create Tribe

    func submitTribeCreation(name: String, context: ModelContext) async -> ArenaTribe? {
        do {
            let tribe = try await service.createTribe(name: name, context: context)
            myTribe = tribe
            tribeMembers = tribe.members
            return tribe
        } catch {
            handleError(error, context: "createTribe")
            return nil
        }
    }

    // MARK: - Join Tribe

    func submitTribeJoin(code: String, context: ModelContext) async -> ArenaTribe? {
        do {
            let tribe = try await service.joinTribe(inviteCode: code, context: context)
            myTribe = tribe
            tribeMembers = tribe.members
            return tribe
        } catch {
            handleError(error, context: "joinTribe")
            return nil
        }
    }

    // MARK: - Leave Tribe

    func leaveTribe(context: ModelContext) async -> Bool {
        do {
            try await service.leaveTribe(context: context)
            myTribe = nil
            tribeMembers = []
            return true
        } catch {
            handleError(error, context: "leaveTribe")
            return false
        }
    }

    // MARK: - Load All

    func loadAll(context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        async let tribeTask: () = loadMyTribe(context: context)
        async let leaderboardTask: () = loadLeaderboard(context: context)
        async let hofTask: () = loadHallOfFame(context: context)
        async let usersTask: () = loadGlobalUsers()
        async let challengeTask: () = loadCurrentChallenge(context: context)
        _ = await (tribeTask, leaderboardTask, hofTask, usersTask, challengeTask)
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error, context: String) {
        let aiqoError = AiQoError.from(error)
        errorMessage = aiqoError.errorDescription
        logger.error("\(context) failed: \(aiqoError.localizedDescription)")

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if errorMessage == aiqoError.errorDescription {
                errorMessage = nil
            }
        }
    }
}
