import SwiftUI

// MARK: - Card Color Theme

private enum CardColorTheme: CaseIterable {
    case mint, sand, lavender, peach, sky, rose

    var background: Color {
        switch self {
        case .mint:      return Color(hex: "E8F7F0")
        case .sand:      return Color(hex: "F5E8CD")
        case .lavender:  return Color(hex: "EDE8F5")
        case .peach:     return Color(hex: "FBE8DB")
        case .sky:       return Color(hex: "DFF0F7")
        case .rose:      return Color(hex: "F5E0E0")
        }
    }

    var accent: Color {
        switch self {
        case .mint:      return Color(hex: "B7E5D2")
        case .sand:      return Color(hex: "EBCF97")
        case .lavender:  return Color(hex: "D4C8E8")
        case .peach:     return Color(hex: "F5CDB6")
        case .sky:       return Color(hex: "B5D8E8")
        case .rose:      return Color(hex: "E8C4C4")
        }
    }

    static func forIndex(_ index: Int) -> CardColorTheme {
        allCases[index % allCases.count]
    }
}

// MARK: - Leaderboard Entry

private struct LeaderboardEntry: Identifiable {
    let id: String
    let rank: Int
    let name: String
    let username: String
    let level: Int
    let points: Int
    let initials: String
    let isPrivate: Bool
    let avatarURL: URL?
}

// MARK: - Filter

private enum TimeFilter: String, CaseIterable {
    case allTime = "كل الوقت"
    case monthly = "شهري"
    case weekly = "أسبوعي"
}

// MARK: - TribeLeaderboardView

struct TribeLeaderboardView: View {
    @ObservedObject private var store = TribeStore.shared
    @State private var selectedFilter: TimeFilter = .allTime
    @State private var appeared = false
    @State private var crownFloat = false
    @State private var selectedUser: LeaderboardEntry?

    // Brand colors
    private let mint = Color(hex: "B7E5D2")
    private let mintLight = Color(hex: "E8F7F0")
    private let mintDark = Color(hex: "8BCDB5")
    private let sand = Color(hex: "EBCF97")
    private let sandLight = Color(hex: "F5E8CD")
    private let sandDark = Color(hex: "D4B574")
    private let lavender = Color(hex: "D4C8E8")
    private let lavenderLight = Color(hex: "EDE8F5")
    private let sky = Color(hex: "B5D8E8")
    private let skyLight = Color(hex: "DFF0F7")
    private let pageBG = Color(hex: "F6F4EF")

    private var entries: [LeaderboardEntry] {
        store.members
            .sorted { $0.energyContributionToday > $1.energyContributionToday }
            .enumerated()
            .map { index, member in
                LeaderboardEntry(
                    id: member.id,
                    rank: index + 1,
                    name: member.visibleDisplayName,
                    username: "@\(member.displayName)",
                    level: member.level,
                    points: member.energyContributionToday,
                    initials: member.resolvedInitials,
                    isPrivate: member.privacyMode == .private,
                    avatarURL: member.avatarURL.flatMap { URL(string: $0) }
                )
            }
    }

    private var myEntry: LeaderboardEntry? {
        let userId = store.actionMemberId
        return entries.first { $0.id == userId }
    }

    var body: some View {
        ZStack {
            backgroundView
            mainContent
        }
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(item: $selectedUser) { user in
            UserDetailSheet(entry: user, sandDark: sandDark)
                .environment(\.layoutDirection, .rightToLeft)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
            crownFloat = true
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: mintLight.opacity(0.4), location: 0),
                    .init(color: pageBG, location: 0.3),
                    .init(color: pageBG, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [mint.opacity(0.13), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .offset(x: 60, y: -80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [sand.opacity(0.09), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .offset(x: -40, y: -40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            headerView
            filterPills
            scrollContent
        }
        .safeAreaInset(edge: .bottom) {
            if let my = myEntry {
                pinnedMyRankBar(entry: my)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("إمارة")
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(Color(hex: "1A1A1A"))

            Spacer()

            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.7))
                )
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "999999"))
                )
                .frame(width: 46, height: 46)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        HStack(spacing: 8) {
            ForEach(TimeFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue)
                    .font(.system(size: 13, weight: filter == selectedFilter ? .bold : .medium))
                    .foregroundColor(filter == selectedFilter ? Color(hex: "1A1A1A") : Color(hex: "999999"))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background {
                        if filter == selectedFilter {
                            LinearGradient(
                                colors: [sandLight, sand.opacity(0.53)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(sand, lineWidth: 1.5)
                            )
                        } else {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(Color.white.opacity(0.6))
                                )
                        }
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = filter
                        }
                    }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                podiumView
                    .padding(.top, 28)

                // Divider
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.06), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 16)

                // Rank #4+ cards
                LazyVStack(spacing: 10) {
                    ForEach(Array(entries.dropFirst(3).enumerated()), id: \.element.id) { index, entry in
                        rankCard(entry: entry, colorIndex: index)
                            .opacity(appeared ? 1 : 0)
                            .offset(x: appeared ? 0 : -20)
                            .animation(
                                .easeOut(duration: 0.4).delay(Double(index) * 0.05),
                                value: appeared
                            )
                            .onTapGesture {
                                selectedUser = entry
                            }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 130)
            }
        }
    }

    // MARK: - Podium

    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // #2 — Left in RTL (lavender)
            if entries.count > 1 {
                podiumSlot(entry: entries[1], index: 1)
                    .frame(maxWidth: .infinity)
            }

            // #1 — Center (sand)
            if let first = entries.first {
                podiumSlot(entry: first, index: 0)
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
            }

            // #3 — Right in RTL (sky)
            if entries.count > 2 {
                podiumSlot(entry: entries[2], index: 2)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
    }

    private func podiumSlot(entry: LeaderboardEntry, index: Int) -> some View {
        let isFirst = index == 0
        let avatarSize: CGFloat = isFirst ? 72 : 56
        let pillarHeight: CGFloat = isFirst ? 115 : (index == 1 ? 88 : 72)
        let accentColor = index == 0 ? sand : (index == 1 ? lavender : sky)
        let lightColor = index == 0 ? sandLight : (index == 1 ? lavenderLight : skyLight)
        let badgeSize: CGFloat = 24
        let borderWidth: CGFloat = isFirst ? 2.5 : 2

        return VStack(spacing: 8) {
            // Avatar + Crown
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    if isFirst {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                            .foregroundColor(sandDark)
                            .offset(y: crownFloat ? -4 : 0)
                            .animation(
                                .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                                value: crownFloat
                            )
                            .padding(.bottom, 2)
                    }

                    avatarCircle(
                        initials: entry.initials,
                        size: avatarSize,
                        gradient: LinearGradient(
                            colors: [lightColor, accentColor],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        borderColor: accentColor,
                        borderWidth: borderWidth,
                        shadowColor: accentColor.opacity(isFirst ? 0.33 : 0.2),
                        shadowRadius: isFirst ? 12 : 6,
                        shadowY: isFirst ? 6 : 3,
                        fontSize: isFirst ? 22 : 16
                    )
                }

                // Rank badge
                Circle()
                    .fill(accentColor)
                    .frame(width: badgeSize, height: badgeSize)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2.5)
                    )
                    .overlay(
                        Text("\(entry.rank)")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                    .offset(y: badgeSize / 2)
            }
            .padding(.bottom, badgeSize / 2)

            // Name
            Text(entry.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
                .lineLimit(1)
                .frame(maxWidth: 105)

            // Points
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                Text("\(entry.points)")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(Color(hex: "777777"))

            // Pillar
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 18,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [accentColor.opacity(0.33), accentColor.opacity(0.13)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .top) {
                // Shiny line at top
                LinearGradient(
                    colors: [.clear, accentColor.opacity(0.53), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
            }
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 18,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 18,
                    style: .continuous
                )
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
            )
            .frame(height: pillarHeight)
            .overlay {
                VStack(spacing: 4) {
                    Text("المستوى")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "999999"))
                    Text("\(entry.level)")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(Color(hex: "1A1A1A"))
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(
            .easeOut(duration: 0.6).delay(Double(index) * 0.15),
            value: appeared
        )
    }

    // MARK: - Rank Card

    private func rankCard(entry: LeaderboardEntry, colorIndex: Int) -> some View {
        let theme = CardColorTheme.forIndex(colorIndex)

        return HStack(spacing: 0) {
            // Rank number
            Text("#\(entry.rank)")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(Color(hex: "1A1A1A"))
                .frame(minWidth: 36, alignment: .center)
                .padding(.trailing, 10)

            // Avatar
            avatarCircle(
                initials: entry.initials,
                size: 44,
                gradient: LinearGradient(
                    colors: [.white, theme.accent.opacity(0.33)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                borderColor: theme.accent.opacity(0.4),
                borderWidth: 1.5,
                fontSize: 14
            )
            .padding(.trailing, 12)

            // Name + Username
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .lineLimit(1)

                    if entry.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "AAAAAA"))
                    }
                }
                Text(entry.username)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "AAAAAA"))
            }

            Spacer()

            // Points badge
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                Text("\(entry.points)")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(Color(hex: "1A1A1A"))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(theme.accent.opacity(0.33))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Level badge
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                Text("\(entry.level)")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(Color(hex: "777777"))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.leading, 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    theme.background.opacity(0.8),
                    theme.background.opacity(0.33)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.accent.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Pinned My Rank Bar

    private func pinnedMyRankBar(entry: LeaderboardEntry) -> some View {
        HStack(spacing: 0) {
            // Rank
            Text("#\(entry.rank)")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(sandDark)
                .frame(minWidth: 36, alignment: .center)
                .padding(.trailing, 10)

            // Avatar
            avatarCircle(
                initials: entry.initials,
                size: 44,
                gradient: LinearGradient(
                    colors: [sandLight, sand],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                borderColor: sand,
                borderWidth: 2,
                fontSize: 14
            )
            .padding(.trailing, 12)

            // "أنت" + progress badge
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("أنت")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))

                    // +3 badge
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .bold))
                        Text("+3")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "4CAF50"))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color(hex: "E8F5E9"))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Text(entry.username)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "AAAAAA"))
            }

            Spacer()

            // Points badge
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11))
                Text("\(entry.points)")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(Color(hex: "1A1A1A"))
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(sand.opacity(0.27))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.92), Color.white.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(sand.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: -2)
        .shadow(color: sand.opacity(0.09), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: pageBG.opacity(0.94), location: 0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blur(radius: 16)
            .ignoresSafeArea()
        )
    }

    // MARK: - Avatar Helper

    private func avatarCircle(
        initials: String,
        size: CGFloat,
        gradient: LinearGradient,
        borderColor: Color,
        borderWidth: CGFloat,
        shadowColor: Color = .clear,
        shadowRadius: CGFloat = 0,
        shadowY: CGFloat = 0,
        fontSize: CGFloat = 16
    ) -> some View {
        Circle()
            .fill(gradient)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))
            )
            .overlay(
                Circle().stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }
}

// MARK: - User Detail Sheet

private struct UserDetailSheet: View {
    let entry: LeaderboardEntry
    let sandDark: Color

    private var accentColor: Color {
        switch entry.rank {
        case 1: return Color(hex: "EBCF97")
        case 2: return Color(hex: "D4C8E8")
        case 3: return Color(hex: "B5D8E8")
        default: return CardColorTheme.forIndex(entry.rank - 4).accent
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Large avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.3), accentColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Text(entry.initials)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                )
                .overlay(
                    Circle().stroke(accentColor, lineWidth: 3)
                )
                .shadow(color: accentColor.opacity(0.2), radius: 12, y: 6)
                .padding(.top, 24)

            // Name
            VStack(spacing: 4) {
                Text(entry.name)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Text(entry.username)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "AAAAAA"))
            }

            // Stats grid
            HStack(spacing: 12) {
                statCard(label: "الترتيب", value: "#\(entry.rank)", bg: Color(hex: "FBE8DB"))
                statCard(label: "المستوى", value: "\(entry.level)", bg: Color(hex: "E8F7F0"))
                statCard(label: "النقاط", value: formattedPoints, bg: Color(hex: "F5E8CD"))
            }
            .padding(.horizontal, 24)

            // Status row
            HStack(spacing: 6) {
                Text("عالمي")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "888888"))

                Circle()
                    .fill(Color(hex: "CCCCCC"))
                    .frame(width: 3, height: 3)

                Text(entry.isPrivate ? "حساب خاص 🔒" : "حساب عام")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "888888"))
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "EDE8F5").opacity(0.53),
                        Color(hex: "DFF0F7").opacity(0.53)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var formattedPoints: String {
        if entry.points >= 1000 {
            return String(format: "%.1fK", Double(entry.points) / 1000.0)
        }
        return "\(entry.points)"
    }

    private func statCard(label: String, value: String, bg: Color) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "999999"))
            Text(value)
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(Color(hex: "1A1A1A"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    TribeLeaderboardView()
}
