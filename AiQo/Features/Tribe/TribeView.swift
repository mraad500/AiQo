import SwiftUI
import UIKit
internal import Combine

// MARK: - Emara Tab Enum

private enum EmaraTab: String, CaseIterable, Identifiable {
    case global
    case arena
    case tribe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .global: return "العالمية"
        case .arena: return "الارينا"
        case .tribe: return "القبيلة"
        }
    }
}

// MARK: - Tribe Ring Member

private struct EmaraTribeMember: Identifiable {
    let id = UUID()
    let name: String
    let username: String
    let points: Int
    let level: Int
    let colorIndex: Int
    let initials: String

    static let tribeColors: [Color] = [
        Color(hex: "B7E5D2"), // Mint
        Color(hex: "EBCF97"), // Sand
        Color(hex: "C5B8E8"), // Lavender
        Color(hex: "F5C6AA"), // Peach
        Color(hex: "A8D8EA")  // Sky
    ]

    static let mockMembers: [EmaraTribeMember] = [
        EmaraTribeMember(name: "حمودي", username: "@mohammed", points: 38620, level: 18, colorIndex: 0, initials: "حم"),
        EmaraTribeMember(name: "شُرى خالد", username: "@sora.world", points: 9420, level: 28, colorIndex: 1, initials: "شُخ"),
        EmaraTribeMember(name: "سمر نادر", username: "@samar.n", points: 8980, level: 26, colorIndex: 2, initials: "سن"),
        EmaraTribeMember(name: "Noah Reed", username: "@noah.reed", points: 8760, level: 25, colorIndex: 3, initials: "NR"),
        EmaraTribeMember(name: "جود منصور", username: "@joud.rank", points: 8340, level: 24, colorIndex: 4, initials: "جم"),
    ]
}

// MARK: - TribeView

struct TribeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TribeViewModel()
    @State private var selectedTab: EmaraTab = .global
    @State private var selectedUserID: String?

    private var selectedUser: TribeLeaderboardUser? {
        guard let selectedUserID else { return nil }
        return viewModel.user(withID: selectedUserID)
    }

    var body: some View {
        ZStack {
            tribeBackground

            VStack(spacing: 0) {
                screenTitle
                    .padding(.top, 12)

                topBar
                    .padding(.top, 10)

                tabContent
                    .padding(.top, 8)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .task {
            viewModel.refreshCurrentUser()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userProfileDidChange)) { _ in
            viewModel.refreshCurrentUser()
        }
        .onReceive(NotificationCenter.default.publisher(for: .levelStoreDidChange)) { _ in
            viewModel.refreshCurrentUser()
        }
        .sheet(
            isPresented: Binding(
                get: { selectedUser != nil },
                set: { if !$0 { selectedUserID = nil } }
            )
        ) {
            if let selectedUser {
                TribeUserDetailSheet(user: selectedUser)
                    .presentationDetents([.height(310), .medium])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
                    .presentationBackground(TribeLeaderboardPalette.sheetBackground)
            }
        }
    }

    // MARK: - Screen Title

    private var screenTitle: some View {
        Text("إمارة")
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .foregroundStyle(TribeLeaderboardPalette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 20)
    }

    // MARK: - Top Bar (Back Button + Picker)

    private var topBar: some View {
        HStack(spacing: 12) {
            // Back button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TribeLeaderboardPalette.textPrimary)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Circle()
                                    .fill(Color.white.opacity(0.7))
                            }
                            .overlay {
                                Circle()
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            }
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            // Native segmented picker
            Picker("", selection: $selectedTab) {
                Text("العالمية").tag(EmaraTab.global)
                Text("الارينا").tag(EmaraTab.arena)
                Text("القبيلة").tag(EmaraTab.tribe)
            }
            .pickerStyle(.segmented)
            .scaleEffect(y: 1.35)
            .frame(height: 44)
            .onAppear {
                UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color(hex: "EBCF97"))
                UISegmentedControl.appearance().setTitleTextAttributes([
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold)
                ], for: .selected)
                UISegmentedControl.appearance().setTitleTextAttributes([
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium)
                ], for: .normal)
            }
        }
        .padding(.horizontal, 16)
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .global:
            globalLeaderboardContent
        case .arena:
            arenaPlaceholderContent
        case .tribe:
            tribeRingContent
        }
    }

    // MARK: - Global Leaderboard (Existing)

    private var globalLeaderboardContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 22) {
                leaderboardSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 132)
        }
    }

    private var leaderboardSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, user in
                Button {
                    selectedUserID = user.id
                } label: {
                    TribeUserRowCard(
                        rank: index + 1,
                        user: user
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Arena Placeholder

    private var arenaPlaceholderContent: some View {
        VStack {
            Spacer()
            Text("قريباً")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(TribeLeaderboardPalette.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tribe Ring Content

    private var tribeRingContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                EmaraTribeRingView(members: EmaraTribeMember.mockMembers)
                    .padding(.top, 20)

                tribeRingMemberCards
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 132)
        }
    }

    private var tribeRingMemberCards: some View {
        LazyVStack(spacing: 12) {
            ForEach(EmaraTribeMember.mockMembers) { member in
                TribeRingMemberCard(member: member)
            }
        }
    }

    // MARK: - Background

    private var tribeBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    TribeLeaderboardPalette.backgroundTop,
                    TribeLeaderboardPalette.backgroundMiddle,
                    TribeLeaderboardPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(TribeLeaderboardPalette.glowMint)
                .frame(width: 320, height: 320)
                .blur(radius: 78)
                .offset(x: -118, y: -260)

            Circle()
                .fill(TribeLeaderboardPalette.glowSand)
                .frame(width: 300, height: 300)
                .blur(radius: 84)
                .offset(x: 136, y: -52)

            Circle()
                .fill(TribeLeaderboardPalette.glowSky)
                .frame(width: 320, height: 320)
                .blur(radius: 96)
                .offset(x: 42, y: 344)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Tribe Ring View

private struct EmaraTribeRingView: View {
    let members: [EmaraTribeMember]

    private let ringDiameter: CGFloat = 220
    private let ringStroke: CGFloat = 18
    private let segmentCount = 5
    private let gapAngle: Double = 4

    var body: some View {
        ZStack {
            // Ring segments
            ForEach(0..<segmentCount, id: \.self) { index in
                ringSegment(index: index)
            }

            // Center avatars in pentagon layout
            ForEach(Array(members.prefix(segmentCount).enumerated()), id: \.element.id) { index, member in
                let angle = pentagonAngle(for: index)
                let radius: CGFloat = 48

                EmaraRingAvatar(
                    initials: member.initials,
                    color: EmaraTribeMember.tribeColors[member.colorIndex]
                )
                .offset(
                    x: cos(angle) * radius,
                    y: sin(angle) * radius
                )
            }
        }
        .frame(width: ringDiameter, height: ringDiameter)
        .frame(maxWidth: .infinity)
    }

    private func ringSegment(index: Int) -> some View {
        let segmentAngle = 360.0 / Double(segmentCount)
        let startAngle = Double(index) * segmentAngle + gapAngle / 2 - 90
        let endAngle = startAngle + segmentAngle - gapAngle

        return Circle()
            .trim(
                from: CGFloat(startAngle / 360.0),
                to: CGFloat(endAngle / 360.0)
            )
            .stroke(
                EmaraTribeMember.tribeColors[index],
                style: StrokeStyle(lineWidth: ringStroke, lineCap: .round)
            )
            .frame(width: ringDiameter, height: ringDiameter)
    }

    private func pentagonAngle(for index: Int) -> Double {
        let baseAngle = -Double.pi / 2 // Start from top
        return baseAngle + Double(index) * (2 * .pi / Double(segmentCount))
    }
}

private struct EmaraRingAvatar: View {
    let initials: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))

            Text(initials)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(TribeLeaderboardPalette.textPrimary)
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(color, lineWidth: 2.5)
        }
    }
}

// MARK: - Tribe Ring Member Card

private struct TribeRingMemberCard: View {
    let member: EmaraTribeMember
    private var memberColor: Color {
        EmaraTribeMember.tribeColors[member.colorIndex]
    }

    var body: some View {
        TribeCardSurface(
            tint: memberColor,
            padding: 16,
            cornerRadius: 20
        ) {
            HStack(spacing: 14) {
                // Color dot
                Circle()
                    .fill(memberColor)
                    .frame(width: 10, height: 10)

                // Avatar
                ZStack {
                    Circle()
                        .fill(memberColor.opacity(0.3))
                    Text(member.initials)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(TribeLeaderboardPalette.textPrimary)
                }
                .frame(width: 42, height: 42)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(memberColor, lineWidth: 2)
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Text(member.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(TribeLeaderboardPalette.textPrimary)
                        .lineLimit(1)

                    Text(member.username)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(TribeLeaderboardPalette.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(member.points.formatted(.number.locale(.autoupdatingCurrent)))")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(TribeLeaderboardPalette.textPrimary)

                    Text("المستوى \(member.level.formatted(.number.locale(.autoupdatingCurrent)))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(TribeLeaderboardPalette.textTertiary)
                }
            }
        }
    }
}

// MARK: - Existing Components (Unchanged)

private struct TribeUserRowCard: View {
    let rank: Int
    let user: TribeLeaderboardUser

    var body: some View {
        TribeCardSurface(
            tint: surfaceTint,
            padding: 16,
            cornerRadius: 32
        ) {
            HStack(spacing: 14) {
                AvatarView(user: user, size: 56)

                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 8) {
                        labelChip(
                            icon: "sparkles",
                            text: "المستوى \(user.level.formatted(.number.locale(.autoupdatingCurrent)))",
                            tint: TribeLeaderboardPalette.sand
                        )
                        labelChip(
                            icon: "bolt.fill",
                            text: "\(user.points.formatted(.number.locale(.autoupdatingCurrent))) نقطة",
                            tint: TribeLeaderboardPalette.mint
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    HStack(spacing: 8) {
                        Text(user.displayName)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(TribeLeaderboardPalette.textPrimary)
                            .lineLimit(1)

                        if user.isCurrentUser {
                            ProfileVisibilityBadge(
                                isProfilePublic: user.isProfilePublic,
                                isCurrentUser: true
                            )
                        } else if !user.isProfilePublic {
                            ProfileVisibilityBadge(
                                isProfilePublic: false,
                                isCurrentUser: false
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    Text("@\(user.username)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(TribeLeaderboardPalette.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    Text("#\(rank.formatted(.number.locale(.autoupdatingCurrent)))")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(TribeLeaderboardPalette.textPrimary)
                        .monospacedDigit()

                    Text("عالمي")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(TribeLeaderboardPalette.textTertiary)
                }
            }
        }
    }

    private var surfaceTint: Color {
        user.isProfilePublic ? TribeLeaderboardPalette.mint : TribeLeaderboardPalette.sand
    }

    private func labelChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(TribeLeaderboardPalette.textPrimary)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.78),
                            tint.opacity(0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(tint.opacity(0.62), lineWidth: 1)
                }
        }
    }
}

private struct TribeUserDetailSheet: View {
    let user: TribeLeaderboardUser

    var body: some View {
        ZStack {
            TribeLeaderboardPalette.sheetBackground.ignoresSafeArea()

            VStack {
                Spacer(minLength: 12)

                TribeCardSurface(
                    tint: user.isProfilePublic ? TribeLeaderboardPalette.mint : TribeLeaderboardPalette.sand,
                    padding: 22,
                    cornerRadius: 28
                ) {
                    VStack(spacing: 16) {
                        AvatarView(user: user, size: 82, showsPrivateCaption: true)

                        VStack(spacing: 6) {
                            Text(user.displayName)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(TribeLeaderboardPalette.textPrimary)

                            Text("@\(user.username)")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(TribeLeaderboardPalette.textSecondary)
                        }

                        HStack(spacing: 10) {
                            detailMetric(title: "المستوى", value: user.level.formatted(.number.locale(.autoupdatingCurrent)), tint: TribeLeaderboardPalette.sand)
                            detailMetric(title: "النقاط", value: user.points.formatted(.number.locale(.autoupdatingCurrent)), tint: TribeLeaderboardPalette.mint)
                        }

                        if user.isCurrentUser || !user.isProfilePublic {
                            ProfileVisibilityBadge(
                                isProfilePublic: user.isProfilePublic,
                                isCurrentUser: user.isCurrentUser
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
    }

    private func detailMetric(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(TribeLeaderboardPalette.textTertiary)

            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(TribeLeaderboardPalette.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.30),
                            tint.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.34), lineWidth: 0.9)
                }
        }
    }
}

private struct ProfileVisibilityBadge: View {
    let isProfilePublic: Bool
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isProfilePublic ? "eye.fill" : "lock.fill")
                .font(.system(size: 10, weight: .bold))

            Text(label)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(TribeLeaderboardPalette.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundTint, in: Capsule())
        .overlay {
            Capsule()
                .stroke(strokeTint, lineWidth: 0.8)
        }
    }

    private var label: String {
        if isCurrentUser {
            return isProfilePublic ? "ملف عام" : "ملف خاص"
        }
        return isProfilePublic ? "عام" : "حساب خاص"
    }

    private var backgroundTint: Color {
        isProfilePublic ? TribeLeaderboardPalette.mint.opacity(0.42) : TribeLeaderboardPalette.sand.opacity(0.44)
    }

    private var strokeTint: Color {
        isProfilePublic ? TribeLeaderboardPalette.mint.opacity(0.72) : TribeLeaderboardPalette.sand.opacity(0.74)
    }
}

private struct AvatarView: View {
    let user: TribeLeaderboardUser
    let size: CGFloat
    var showsPrivateCaption = false

    var body: some View {
        VStack(spacing: showsPrivateCaption ? 8 : 0) {
            ZStack {
                Circle()
                    .fill(backgroundTint)

                if let image = user.visibleProfileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if user.isProfilePublic {
                    Text(user.initials)
                        .font(.system(size: max(14, size * 0.24), weight: .bold, design: .rounded))
                        .foregroundStyle(TribeLeaderboardPalette.textPrimary.opacity(0.82))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.24, weight: .semibold))
                        .foregroundStyle(TribeLeaderboardPalette.textPrimary.opacity(0.48))
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(TribeLeaderboardPalette.avatarStroke, lineWidth: 1.2)
            }

            if showsPrivateCaption && !user.isProfilePublic {
                Text("حساب خاص")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(TribeLeaderboardPalette.textSecondary)
            }
        }
    }

    private var backgroundTint: Color {
        if user.isProfilePublic {
            return user.profileImage == nil
            ? TribeLeaderboardPalette.mint.opacity(0.40)
            : TribeLeaderboardPalette.cardSurfaceRaised
        }

        return TribeLeaderboardPalette.placeholderSurface
    }
}

private struct TribeCardSurface<Content: View>: View {
    let tint: Color
    let padding: CGFloat
    let cornerRadius: CGFloat
    @ViewBuilder let content: Content

    init(
        tint: Color,
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 24,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                TribeLeaderboardPalette.cardSurface,
                                TribeLeaderboardPalette.cardSurfaceRaised
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        tint.opacity(0.30),
                                        tint.opacity(0.14),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomLeading
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.46),
                                        Color.white.opacity(0.08),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(TribeLeaderboardPalette.cardStroke, lineWidth: 1.05)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.88), lineWidth: 0.9)
                            .padding(1)
                    }
            }
            .shadow(color: TribeLeaderboardPalette.shadow, radius: 22, x: 0, y: 12)
    }
}

@MainActor
private final class TribeViewModel: ObservableObject {
    @Published private(set) var currentUser: TribeLeaderboardUser

    private let leaderboardSeed: [TribeLeaderboardUser]

    init() {
        self.currentUser = TribeViewModel.makeCurrentUser()
        self.leaderboardSeed = TribeViewModel.makeGlobalSeed()
    }

    var leaderboard: [TribeLeaderboardUser] {
        (leaderboardSeed + [currentUser])
            .sorted { lhs, rhs in
                if lhs.points == rhs.points {
                    return lhs.displayName < rhs.displayName
                }
                return lhs.points > rhs.points
            }
    }

    func user(withID id: String) -> TribeLeaderboardUser? {
        (leaderboardSeed + [currentUser]).first(where: { $0.id == id })
    }

    func refreshCurrentUser() {
        currentUser = TribeViewModel.makeCurrentUser()
    }

    private static func makeCurrentUser() -> TribeLeaderboardUser {
        let profile = UserProfileStore.shared.current
        let displayName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? "أنت"
        : profile.name
        let rawUsername = profile.username?.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentLevel = max(LevelStore.shared.level, 1)
        let currentPoints = max(LevelStore.shared.totalXP, 6_120 + (currentLevel * 38))

        return TribeLeaderboardUser(
            id: "tribe-current-user",
            displayName: displayName,
            username: rawUsername?.isEmpty == false ? rawUsername! : "aiqo.me",
            level: currentLevel,
            points: currentPoints,
            isProfilePublic: UserProfileStore.shared.tribePrivacyMode == .public,
            profileImage: UserProfileStore.shared.loadAvatar(),
            isCurrentUser: true
        )
    }

    private static func makeGlobalSeed() -> [TribeLeaderboardUser] {
        [
            TribeLeaderboardUser(
                id: "global-sora",
                displayName: "سُرى خالد",
                username: "sora.world",
                level: 28,
                points: 9_420,
                isProfilePublic: true,
                profileImage: nil,
                isCurrentUser: false
            ),
            TribeLeaderboardUser(
                id: "global-omar",
                displayName: "Omar Bell",
                username: "omar.bell",
                level: 27,
                points: 9_180,
                isProfilePublic: false,
                profileImage: nil,
                isCurrentUser: false
            ),
            TribeLeaderboardUser(
                id: "global-samar",
                displayName: "سمر نادر",
                username: "samar.n",
                level: 26,
                points: 8_980,
                isProfilePublic: true,
                profileImage: nil,
                isCurrentUser: false
            ),
            TribeLeaderboardUser(
                id: "global-noah",
                displayName: "Noah Reed",
                username: "noah.reed",
                level: 25,
                points: 8_760,
                isProfilePublic: true,
                profileImage: nil,
                isCurrentUser: false
            ),
            TribeLeaderboardUser(
                id: "global-joud",
                displayName: "جود منصور",
                username: "joud.rank",
                level: 24,
                points: 8_340,
                isProfilePublic: false,
                profileImage: nil,
                isCurrentUser: false
            ),
            TribeLeaderboardUser(
                id: "global-ella",
                displayName: "Ella Moss",
                username: "ella.moss",
                level: 23,
                points: 8_120,
                isProfilePublic: true,
                profileImage: nil,
                isCurrentUser: false
            )
        ]
    }
}

private struct TribeLeaderboardUser: Identifiable {
    let id: String
    var displayName: String
    var username: String
    var level: Int
    var points: Int
    var isProfilePublic: Bool
    var profileImage: UIImage?
    var isCurrentUser: Bool

    var visibleProfileImage: UIImage? {
        isProfilePublic ? profileImage : nil
    }

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

private enum TribeLeaderboardPalette {
    static let backgroundTop = Color(hex: "F7FBF8")
    static let backgroundMiddle = Color(hex: "EFF7F2")
    static let backgroundBottom = Color(hex: "FAF1E3")

    static let glowMint = Color(hex: "73D6B1").opacity(0.42)
    static let glowSand = Color(hex: "F0B760").opacity(0.34)
    static let glowSky = Color(hex: "96C8F0").opacity(0.26)

    static let mint = Color(hex: "6FD7B4")
    static let sand = Color(hex: "EDB45D")

    static let cardSurface = Color(hex: "FFFDF8")
    static let cardSurfaceRaised = Color(hex: "F6F3EA")
    static let placeholderSurface = Color(hex: "EADFCB")
    static let sheetBackground = Color(hex: "FBF7EF")

    static let textPrimary = Color(hex: "162026")
    static let textSecondary = Color(hex: "56636D")
    static let textTertiary = Color(hex: "75808A")

    static let cardStroke = Color.black.opacity(0.10)
    static let avatarStroke = Color.black.opacity(0.12)
    static let shadow = Color.black.opacity(0.09)
}

#Preview {
    NavigationStack {
        TribeScreen()
    }
}
