import SwiftUI
import UIKit
internal import Combine

struct TribeView: View {
    @StateObject private var viewModel = TribeViewModel()
    @State private var selectedUserID: String?
    @State private var isProfilePresented = false

    private var selectedUser: TribeLeaderboardUser? {
        guard let selectedUserID else { return nil }
        return viewModel.user(withID: selectedUserID)
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 22) {
                    header

                    leaderboardSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 132)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .aiqoProfileSheet(isPresented: $isProfilePresented)
        .task {
            viewModel.refreshCurrentUser()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userProfileDidChange)) { _ in
            viewModel.refreshCurrentUser()
        }
        .onReceive(NotificationCenter.default.publisher(for: .levelStoreDidChange)) { _ in
            viewModel.refreshCurrentUser()
        }
        .onChange(of: isProfilePresented) { _, isPresented in
            if !isPresented {
                viewModel.refreshCurrentUser()
            }
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
                    .presentationBackground(Color.white)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("القبيلة")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(TribeLeaderboardPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            AiQoProfileButton {
                isProfilePresented = true
            }
            .scaleEffect(0.84)
        }
        .environment(\.layoutDirection, .leftToRight)
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
}

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
        if user.isCurrentUser {
            return user.isProfilePublic ? TribeLeaderboardPalette.mint : TribeLeaderboardPalette.sand
        }

        return user.isProfilePublic
        ? TribeLeaderboardPalette.mint.opacity(0.94)
        : TribeLeaderboardPalette.sand.opacity(0.94)
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
                            tint.opacity(0.38),
                            tint.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(tint.opacity(0.42), lineWidth: 0.9)
                }
        }
    }
}

private struct TribeUserDetailSheet: View {
    let user: TribeLeaderboardUser

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

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
        .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        isProfilePublic ? TribeLeaderboardPalette.mint.opacity(0.32) : TribeLeaderboardPalette.sand.opacity(0.34)
    }

    private var strokeTint: Color {
        isProfilePublic ? TribeLeaderboardPalette.mint.opacity(0.44) : TribeLeaderboardPalette.sand.opacity(0.46)
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
                        .foregroundStyle(TribeLeaderboardPalette.textPrimary.opacity(0.72))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.24, weight: .semibold))
                        .foregroundStyle(TribeLeaderboardPalette.textPrimary.opacity(0.34))
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(TribeLeaderboardPalette.cardStroke, lineWidth: 1)
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
            ? TribeLeaderboardPalette.mint.opacity(0.26)
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
                    .fill(TribeLeaderboardPalette.cardSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        tint.opacity(0.16),
                                        tint.opacity(0.06)
                                    ],
                                    startPoint: .topTrailing,
                                    endPoint: .bottomLeading
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(TribeLeaderboardPalette.cardStroke, lineWidth: 1)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.74), lineWidth: 0.8)
                            .padding(1)
                    }
            }
            .shadow(color: TribeLeaderboardPalette.shadow, radius: 18, x: 0, y: 9)
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
    static let mint = Color(hex: "A8D7BE")
    static let sand = Color(hex: "DFC086")
    static let cardSurface = Color(hex: "F4F4F1")
    static let cardSurfaceRaised = Color(hex: "EFEFEA")
    static let placeholderSurface = Color(hex: "ECE7DE")
    static let textPrimary = Color.black.opacity(0.88)
    static let textSecondary = Color.black.opacity(0.56)
    static let textTertiary = Color.black.opacity(0.36)
    static let cardStroke = Color.black.opacity(0.055)
    static let shadow = Color.black.opacity(0.04)
}

#Preview {
    NavigationStack {
        TribeScreen()
    }
}
