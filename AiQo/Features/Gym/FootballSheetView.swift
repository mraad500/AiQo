import SwiftUI
import Supabase
import SDWebImageSwiftUI
internal import Combine

private let supabase = SupabaseService.shared.client

struct Match: Codable, Identifiable {
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

@MainActor
final class MatchesViewModel: ObservableObject {
    @Published private(set) var matches: [Match] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchMatches() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await supabase
                .from("matches")
                .select()
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let rawMatches = try decoder.decode([Match].self, from: response.data)
            matches = rawMatches.sorted(by: Self.globalSort)
        } catch {
            matches = []
            errorMessage = error.localizedDescription
        }
    }

    var topMatches: [Match] {
        matches
            .filter { $0.status.uppercased() == "LIVE" || $0.status.uppercased() == "FINISHED" }
            .sorted {
                if $0.status.uppercased() != $1.status.uppercased() {
                    return Self.rankForTop($0.status) < Self.rankForTop($1.status)
                }
                return $0.utc_date > $1.utc_date
            }
    }

    var upcomingMatches: [Match] {
        matches
            .filter { $0.status.uppercased() == "SCHEDULED" }
            .sorted { $0.utc_date < $1.utc_date }
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

    private static func rankForTop(_ status: String) -> Int {
        status.uppercased() == "LIVE" ? 0 : 1
    }
}

struct FootballSheetView: View {
    @StateObject private var viewModel = MatchesViewModel()

    private let mintGreen = Color(red: 192.0 / 255.0, green: 232.0 / 255.0, blue: 213.0 / 255.0) // #C0E8D5
    private let peachBeige = Color(red: 245.0 / 255.0, green: 230.0 / 255.0, blue: 202.0 / 255.0) // #F5E6CA

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Top Matches")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

                if viewModel.isLoading {
                    ProgressView("Loading matches...")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 18)
                }

                if let error = viewModel.errorMessage, !viewModel.isLoading {
                    Text("Failed to load matches: \(error)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 18)
                }

                Text("Results")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)

                if !viewModel.isLoading && viewModel.topMatches.isEmpty {
                    EmptyStateCard(message: "No finished or live matches.", tint: mintGreen)
                        .padding(.horizontal, 18)
                } else {
                    VStack(spacing: 12) {
                        ForEach(viewModel.topMatches) { match in
                            ResultMatchCard(match: match, tint: mintGreen)
                        }
                    }
                    .padding(.horizontal, 18)
                }

                Text("Upcoming Matches")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                if !viewModel.isLoading && viewModel.upcomingMatches.isEmpty {
                    EmptyStateCard(message: "No upcoming matches.", tint: peachBeige)
                        .padding(.horizontal, 18)
                } else {
                    VStack(spacing: 12) {
                        ForEach(viewModel.upcomingMatches) { match in
                            UpcomingMatchCard(match: match, tint: peachBeige)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
            .padding(.bottom, 30)
        }
        .task {
            await viewModel.fetchMatches()
        }
    }
}

private struct ResultMatchCard: View {
    let match: Match
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(tint)
            .frame(height: 112)
            .overlay {
                VStack(spacing: 8) {
                    HStack {
                        Text(match.league)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.6))
                        Spacer()
                        Text(match.status.uppercased() == "LIVE" ? "LIVE" : "FT")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.6), in: Capsule())
                    }

                    HStack {
                        TeamBadgeView(
                            shortName: shortCode(match.home_team),
                            logoURL: match.home_team_logo,
                            alignment: .leading
                        )
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(scoreText(match: match))
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .frame(minWidth: 90)

                        TeamBadgeView(
                            shortName: shortCode(match.away_team),
                            logoURL: match.away_team_logo,
                            alignment: .trailing
                        )
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 16)
            }
    }
}

private struct UpcomingMatchCard: View {
    let match: Match
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(tint)
            .frame(height: 108)
            .overlay {
                HStack(spacing: 12) {
                    TeamBadgeView(
                        shortName: shortCode(match.home_team),
                        logoURL: match.home_team_logo,
                        alignment: .leading
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 4) {
                        Text("VS")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                        Text(match.league)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.55))
                    }

                    TeamBadgeView(
                        shortName: shortCode(match.away_team),
                        logoURL: match.away_team_logo,
                        alignment: .trailing
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 16)
            }
            .overlay(alignment: .bottomTrailing) {
                Text(formattedKickoff(match.utc_date))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.65))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
    }
}

private struct TeamBadgeView: View {
    let shortName: String
    let logoURL: String?
    let alignment: Alignment

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.35))

                WebImage(url: URL(string: logoURL ?? ""))
                    .resizable()
                    .indicator(.activity)
                    .transition(.fade(duration: 0.5))
                    .scaledToFit()
                    .padding(4)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            Text(shortName)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }
}

private struct EmptyStateCard: View {
    let message: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(tint.opacity(0.65))
            .frame(height: 82)
            .overlay {
                Text(message)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
    }
}

private func shortCode(_ team: String) -> String {
    let words = team.split(whereSeparator: \.isWhitespace).filter { !$0.isEmpty }
    if words.count >= 2 {
        return String(words.prefix(2).compactMap(\.first)).uppercased()
    }
    return String(team.prefix(3)).uppercased()
}

private func scoreText(match: Match) -> String {
    let home = match.home_score.map(String.init) ?? "-"
    let away = match.away_score.map(String.init) ?? "-"
    return "\(home) - \(away)"
}

private func formattedKickoff(_ date: Date) -> String {
    let calendar = Calendar.current
    let prefix: String
    if calendar.isDateInToday(date) {
        prefix = "Today"
    } else if calendar.isDateInTomorrow(date) {
        prefix = "Tomorrow"
    } else {
        prefix = date.formatted(.dateTime.weekday(.abbreviated))
    }
    let time = date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
    return "\(prefix) \(time)"
}

#Preview {
    FootballSheetView()
}
