import Foundation
import SwiftUI
internal import Combine
import os.log
import Supabase

struct Match: Codable, Identifiable, Sendable {
    let id: Int64
    let home_team: String
    let away_team: String
    let home_team_logo: String?
    let away_team_logo: String?
    let home_score: Int?
    let away_score: Int?
    let status: String
    let utc_date: Date
    let league: String

    enum CodingKeys: String, CodingKey {
        case id
        case home_team
        case away_team
        case home_team_logo
        case away_team_logo
        case home_score
        case away_score
        case status
        case utc_date
        case league
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        home_team = try container.decode(String.self, forKey: .home_team)
        away_team = try container.decode(String.self, forKey: .away_team)
        home_team_logo = try container.decodeIfPresent(String.self, forKey: .home_team_logo)
        away_team_logo = try container.decodeIfPresent(String.self, forKey: .away_team_logo)
        home_score = try container.decodeIfPresent(Int.self, forKey: .home_score)
        away_score = try container.decodeIfPresent(Int.self, forKey: .away_score)
        status = try container.decode(String.self, forKey: .status)
        league = try container.decode(String.self, forKey: .league)

        if let date = try? container.decode(Date.self, forKey: .utc_date) {
            utc_date = date
        } else {
            let value = try container.decode(String.self, forKey: .utc_date)
            guard let parsed = Self.iso8601WithFractional.date(from: value) ?? Self.iso8601.date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .utc_date,
                    in: container,
                    debugDescription: "Invalid utc_date: \(value)"
                )
            }
            utc_date = parsed
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(home_team, forKey: .home_team)
        try container.encode(away_team, forKey: .away_team)
        try container.encodeIfPresent(home_team_logo, forKey: .home_team_logo)
        try container.encodeIfPresent(away_team_logo, forKey: .away_team_logo)
        try container.encodeIfPresent(home_score, forKey: .home_score)
        try container.encodeIfPresent(away_score, forKey: .away_score)
        try container.encode(status, forKey: .status)
        try container.encode(Self.iso8601WithFractional.string(from: utc_date), forKey: .utc_date)
        try container.encode(league, forKey: .league)
    }

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

actor MatchPrefetchManager {
    static let shared = MatchPrefetchManager()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "MatchPrefetchManager"
    )
    private let cacheTTL: TimeInterval = 180

    private var cachedMatches: [Match] = []
    private var lastFetchAt: Date?
    private var inFlightFetch: Task<[Match], Error>?

    func snapshot() -> [Match] {
        cachedMatches
    }

    func prefetchIfNeeded() async {
        do {
            _ = try await loadMatches(forceRefresh: false)
        } catch {
            logger.error("Silent prefetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadMatches(forceRefresh: Bool) async throws -> [Match] {
        if !forceRefresh, shouldUseCachedMatches {
            return cachedMatches
        }

        if let inFlightFetch {
            return try await inFlightFetch.value
        }

        let task = Task(priority: .utility) {
            try await Self.fetchRemoteMatches()
        }
        inFlightFetch = task

        defer {
            inFlightFetch = nil
        }

        let fetchedMatches = try await task.value
        cachedMatches = fetchedMatches
        lastFetchAt = Date()

        let logoURLs = Self.logoURLs(from: fetchedMatches)
        Task(priority: .utility) {
            await MatchImagePipeline.prefetch(urls: logoURLs)
        }

        return fetchedMatches
    }

    private var shouldUseCachedMatches: Bool {
        guard !cachedMatches.isEmpty, let lastFetchAt else { return false }
        return Date().timeIntervalSince(lastFetchAt) < cacheTTL
    }

    private static func fetchRemoteMatches() async throws -> [Match] {
        let response = try await SupabaseService.shared.client
            .from("matches")
            .select()
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rawMatches = try decoder.decode([Match].self, from: response.data)
        return rawMatches.sorted(by: globalSort)
    }

    private static func logoURLs(from matches: [Match]) -> [URL] {
        matches
            .flatMap { [$0.home_team_logo, $0.away_team_logo] }
            .compactMap { $0 }
            .compactMap(URL.init(string:))
    }

    private static func globalSort(_ lhs: Match, _ rhs: Match) -> Bool {
        let lStatus = lhs.status.uppercased()
        let rStatus = rhs.status.uppercased()
        if lStatus != rStatus {
            return rankForGlobal(lStatus) < rankForGlobal(rStatus)
        }
        if lStatus == "SCHEDULED" {
            return lhs.utc_date < rhs.utc_date
        }
        return lhs.utc_date > rhs.utc_date
    }

    private static func rankForGlobal(_ status: String) -> Int {
        switch status {
        case "LIVE": return 0
        case "SCHEDULED": return 1
        case "FINISHED": return 2
        default: return 3
        }
    }
}

@MainActor
final class MatchesViewModel: ObservableObject {
    private static let sectionLimit = 6

    @Published private(set) var matches: [Match] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let prefetchManager: MatchPrefetchManager
    private var hasLoaded = false

    init(prefetchManager: MatchPrefetchManager = .shared) {
        self.prefetchManager = prefetchManager
    }

    var showsSkeleton: Bool {
        isLoading && matches.isEmpty
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await loadMatches()
    }

    func refresh() async {
        await loadMatches(forceRefresh: true)
    }

    func loadMatches(forceRefresh: Bool = false) async {
        let cachedSnapshot = await prefetchManager.snapshot()

        if !cachedSnapshot.isEmpty {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                matches = cachedSnapshot
            }
            errorMessage = nil
        }

        isLoading = matches.isEmpty

        do {
            let freshMatches = try await prefetchManager.loadMatches(
                forceRefresh: forceRefresh || !cachedSnapshot.isEmpty
            )
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                matches = freshMatches
            }
            errorMessage = nil
        } catch {
            if matches.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    var topMatches: [Match] {
        Array(
            matches
                .filter { $0.status.uppercased() == "LIVE" || $0.status.uppercased() == "FINISHED" }
                .sorted {
                    if $0.utc_date != $1.utc_date {
                        return $0.utc_date > $1.utc_date
                    }
                    return Self.rankForTop($0.status) < Self.rankForTop($1.status)
                }
                .prefix(Self.sectionLimit)
        )
    }

    var upcomingMatches: [Match] {
        Array(
            matches
                .filter { $0.status.uppercased() == "SCHEDULED" }
                .sorted { $0.utc_date < $1.utc_date }
                .prefix(Self.sectionLimit)
        )
    }

    static func globalSort(_ lhs: Match, _ rhs: Match) -> Bool {
        let lStatus = lhs.status.uppercased()
        let rStatus = rhs.status.uppercased()
        if lStatus != rStatus {
            return rankForGlobal(lStatus) < rankForGlobal(rStatus)
        }
        if lStatus == "SCHEDULED" {
            return lhs.utc_date < rhs.utc_date
        }
        return lhs.utc_date > rhs.utc_date
    }

    private static func rankForGlobal(_ status: String) -> Int {
        switch status {
        case "LIVE": return 0
        case "SCHEDULED": return 1
        case "FINISHED": return 2
        default: return 3
        }
    }

    private static func rankForTop(_ status: String) -> Int {
        status.uppercased() == "LIVE" ? 0 : 1
    }
}
