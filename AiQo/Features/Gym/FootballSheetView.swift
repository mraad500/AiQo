import SwiftUI

struct FootballSheetView: View {
    @StateObject private var viewModel = MatchesViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 20) {
                header

                if let errorMessage = viewModel.errorMessage, viewModel.matches.isEmpty {
                    MatchBanner(
                        message: String(format: L10n.t("football.error.refresh"), errorMessage),
                        tint: GymTheme.punchyPink
                    )
                }

                MatchSection(
                    title: L10n.t("football.results"),
                    matches: viewModel.topMatches,
                    emptyMessage: L10n.t("football.empty.results"),
                    style: .result,
                    showsSkeleton: viewModel.showsSkeleton
                )

                MatchSection(
                    title: L10n.t("football.upcoming"),
                    matches: viewModel.upcomingMatches,
                    emptyMessage: L10n.t("football.empty.upcoming"),
                    style: .upcoming,
                    showsSkeleton: viewModel.showsSkeleton
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 34)
        }
        .background(footballBackground.ignoresSafeArea())
        .task {
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: L10n.t("football.title"))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)

            Text(verbatim: L10n.t("football.subtitle"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var footballBackground: some View {
        ZStack {
            Color.clear

            RadialGradient(
                colors: [
                    GymTheme.mint.opacity(0.24),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 40,
                endRadius: 280
            )
            .offset(x: -40, y: -60)

            RadialGradient(
                colors: [
                    GymTheme.brandLavender.opacity(0.18),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 260
            )
            .offset(x: 50, y: 80)
        }
    }
}

private struct MatchSection: View {
    let title: String
    let matches: [Match]
    let emptyMessage: String
    let style: MatchCardStyle
    let showsSkeleton: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: style == .result ? 18 : 28, weight: .bold, design: .rounded))
                .foregroundStyle(style == .result ? .secondary : .primary)

            if showsSkeleton {
                VStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { _ in
                        MatchSkeletonCard(compact: style == .upcoming)
                    }
                }
            } else if matches.isEmpty {
                EmptyStateCard(message: emptyMessage)
            } else {
                VStack(spacing: 12) {
                    ForEach(matches) { match in
                        switch style {
                        case .result:
                            ResultMatchCard(match: match)
                        case .upcoming:
                            UpcomingMatchCard(match: match)
                        }
                    }
                }
            }
        }
    }
}

private enum MatchCardStyle {
    case result
    case upcoming

    var accent: [Color] {
        switch self {
        case .result:
            return [GymTheme.mint.opacity(0.30), Color.white.opacity(0.06)]
        case .upcoming:
            return [GymTheme.brandLemon.opacity(0.26), Color.white.opacity(0.06)]
        }
    }
}

private struct ResultMatchCard: View {
    let match: Match

    var body: some View {
        MatchGlassCard(style: .result) {
            VStack(spacing: 12) {
                HStack {
                    Text(match.league)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Spacer()

                    MatchStatusPill(
                        title: match.status.uppercased() == "LIVE"
                            ? L10n.t("football.status.live")
                            : L10n.t("football.status.ft"),
                        accent: match.status.uppercased() == "LIVE" ? GymTheme.intenseTeal : GymTheme.warmOrange
                    )
                }

                HStack(spacing: 14) {
                    TeamBadgeView(
                        shortName: shortCode(match.home_team),
                        logoURL: match.home_team_logo,
                        teamName: match.home_team,
                        alignment: .leading
                    )

                    VStack(spacing: 4) {
                        Text(scoreText(match: match))
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)

                        Text(verbatim: L10n.t("football.status.final"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 88)

                    TeamBadgeView(
                        shortName: shortCode(match.away_team),
                        logoURL: match.away_team_logo,
                        teamName: match.away_team,
                        alignment: .trailing
                    )
                }
            }
        }
    }
}

private struct UpcomingMatchCard: View {
    let match: Match

    var body: some View {
        MatchGlassCard(style: .upcoming) {
            VStack(spacing: 12) {
                HStack {
                    Text(match.league)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Spacer()

                    MatchStatusPill(
                        title: L10n.t("football.label.scheduled"),
                        accent: GymTheme.gold
                    )
                }

                HStack(spacing: 14) {
                    TeamBadgeView(
                        shortName: shortCode(match.home_team),
                        logoURL: match.home_team_logo,
                        teamName: match.home_team,
                        alignment: .leading
                    )

                    VStack(spacing: 6) {
                        Text(verbatim: L10n.t("football.vs"))
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)

                        Text(formattedKickoff(match.utc_date))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(minWidth: 88)

                    TeamBadgeView(
                        shortName: shortCode(match.away_team),
                        logoURL: match.away_team_logo,
                        teamName: match.away_team,
                        alignment: .trailing
                    )
                }
            }
        }
    }
}

private struct MatchGlassCard<Content: View>: View {
    let style: MatchCardStyle
    let content: Content

    init(
        style: MatchCardStyle,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: style.accent,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 12)
    }
}

private struct MatchStatusPill: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(accent.opacity(0.22))
                    )
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.24), lineWidth: 0.7)
            )
    }
}

private struct TeamBadgeView: View {
    let shortName: String
    let logoURL: String?
    let teamName: String
    let alignment: Alignment

    private var parsedURL: URL? {
        guard let logoURL,
              let url = URL(string: logoURL) else {
            return nil
        }
        return url
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.55))

                if let parsedURL {
                    CachedAsyncImage(url: parsedURL) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    } placeholder: {
                        fallbackBadge
                    }
                } else {
                    fallbackBadge
                }
            }
            .frame(width: 46, height: 46)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
            )

            VStack(spacing: 2) {
                Text(shortName)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(teamName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 92)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var fallbackBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            GymTheme.mint.opacity(0.42),
                            Color.white.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(shortName)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(4)
    }
}

private struct EmptyStateCard: View {
    let message: String

    var body: some View {
        MatchGlassCard(style: .upcoming) {
            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

private struct MatchBanner: View {
    let message: String
    let tint: Color

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(tint.opacity(0.18))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.7)
            )
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
        prefix = L10n.t("football.date.today")
    } else if calendar.isDateInTomorrow(date) {
        prefix = L10n.t("football.date.tomorrow")
    } else {
        prefix = date.formatted(.dateTime.weekday(.abbreviated))
    }

    let time = date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
    return "\(prefix) \(time)"
}

#Preview {
    FootballSheetView()
}
