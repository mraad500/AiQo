import SwiftUI
import UIKit

@MainActor
struct TribeScreen: View {
    @State private var selection = 0
    @State private var progress: CGFloat = 0
    @State private var isGalaxyScreenPresented = false

    private let topTitles = ["القبيلة", "الارينا", "العالمي"]

    private let arenaChallenges: [ArenaChallengePlaceholder] = [
        ArenaChallengePlaceholder(title: "تحدي 50K خطوة", subtitle: "أسبوعي - كل القبيلة", progress: 0.64, participants: 18),
        ArenaChallengePlaceholder(title: "أرينا الثبات", subtitle: "3 أيام بدون انقطاع", progress: 0.42, participants: 11),
        ArenaChallengePlaceholder(title: "حرق 20K كالوري", subtitle: "تعاون جماعي", progress: 0.77, participants: 23),
        ArenaChallengePlaceholder(title: "زون 2 ماراثون", subtitle: "120 دقيقة لكل عضو", progress: 0.29, participants: 9)
    ]

    init(allowsPreviewAccess _: Bool = false) {}

    var body: some View {
        ZStack {
            TribeGlassBackground()

            InteractivePagerView(
                pageCount: topTitles.count,
                selection: $selection,
                progress: $progress
            ) { index in
                pageContent(for: index)
                    .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.bottom, 8)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            TribeTopChrome(
                titles: topTitles,
                selection: $selection,
                progress: progress,
                onGalaxyTap: { isGalaxyScreenPresented = true }
            )
            .padding(.horizontal, 8)
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $isGalaxyScreenPresented) {
            TribeGalaxyScreen {
                isGalaxyScreenPresented = false
            }
        }
    }

    @ViewBuilder
    private func pageContent(for index: Int) -> some View {
        switch index {
        case 0:
            InnerTribeView()
        case 1:
            ArenaBoardView(challenges: arenaChallenges)
        default:
            GlobalLegacyView()
        }
    }
}

extension TribeScreen {
    enum Palette {
        static let mint = Color(red: 0.64, green: 0.89, blue: 0.84)
        static let mintStrong = Color(red: 0.32, green: 0.79, blue: 0.70)
        static let sand = Color(red: 0.95, green: 0.90, blue: 0.80)
        static let sandStrong = Color(red: 0.83, green: 0.74, blue: 0.59)
        static let textPrimary = Color(red: 0.15, green: 0.23, blue: 0.25)
        static let textSecondary = Color(red: 0.30, green: 0.39, blue: 0.41)
        static let ringRed = Color(red: 0.99, green: 0.35, blue: 0.42)
        static let ringGreen = Color(red: 0.50, green: 0.89, blue: 0.44)
        static let ringBlue = Color(red: 0.35, green: 0.68, blue: 1.00)
    }

    struct TribeMemberSnapshot: Identifiable {
        let id: UUID = UUID()
        let name: String
        let initials: String
        let move: Double
        let exercise: Double
        let stand: Double
        let level: Int
    }

    struct ArenaChallengePlaceholder: Identifiable {
        let id: UUID = UUID()
        let title: String
        let subtitle: String
        let progress: Double
        let participants: Int
    }

    struct GlobalLeaderboardEntry: Identifiable {
        let id: UUID = UUID()
        let rank: Int
        let name: String
        let level: Int
        let streakDays: Int
    }
}

extension TribeScreen {
    struct TribeTopChrome: View {
        let titles: [String]
        @Binding var selection: Int
        let progress: CGFloat
        let onGalaxyTap: () -> Void

        var body: some View {
            ZStack(alignment: .trailing) {
                TopPillSegmentedControl(
                    titles: titles,
                    selection: $selection,
                    progress: progress,
                    trailingReservedWidth: 60
                )
                .frame(maxWidth: .infinity)

                GalaxyLauncherButton(size: 50, action: onGalaxyTap)
                    .padding(.trailing, 4)
            }
        }
    }

    struct TribeGlassBackground: View {
        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.99, blue: 0.98),
                        Color(red: 0.98, green: 0.96, blue: 0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Palette.mint.opacity(0.50))
                    .frame(width: 320, height: 320)
                    .blur(radius: 60)
                    .offset(x: -120, y: -250)

                Circle()
                    .fill(Palette.sand.opacity(0.62))
                    .frame(width: 360, height: 360)
                    .blur(radius: 72)
                    .offset(x: 120, y: -210)

                Circle()
                    .fill(Palette.mint.opacity(0.30))
                    .frame(width: 300, height: 300)
                    .blur(radius: 62)
                    .offset(x: 160, y: 250)
            }
        }
    }

    struct GlassPanel<Content: View>: View {
        private let cornerRadius: CGFloat
        private let content: Content

        init(cornerRadius: CGFloat = 24, @ViewBuilder content: () -> Content) {
            self.cornerRadius = cornerRadius
            self.content = content()
        }

        var body: some View {
            content
                .padding(16)
                .background(TribeNativeGlassCardBackground(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.58), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 9)
                .shadow(color: Color.white.opacity(0.35), radius: 2, x: 0, y: 1)
        }
    }

    struct TribeNativeGlassCardBackground: UIViewRepresentable {
        let cornerRadius: CGFloat

        func makeUIView(context _: Context) -> UIVisualEffectView {
            let view = UIVisualEffectView(effect: makeEffect())
            view.clipsToBounds = true
            view.layer.cornerCurve = .continuous
            view.contentView.backgroundColor = UIColor.white.withAlphaComponent(0.02)
            return view
        }

        func updateUIView(_ uiView: UIVisualEffectView, context _: Context) {
            uiView.effect = makeEffect()
            uiView.layer.cornerRadius = cornerRadius
        }

        private func makeEffect() -> UIVisualEffect {
            if #available(iOS 26.0, *) {
                let effect = UIGlassEffect()
                effect.tintColor = UIColor.white.withAlphaComponent(0.10)
                return effect
            }
            return UIBlurEffect(style: .systemUltraThinMaterial)
        }
    }

    struct GalaxyLauncherButton: View {
        var size: CGFloat = 50
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: size, height: size)
                        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)

                    Image("Galaxy_icon")
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                }
            }
            .buttonStyle(TribeFloatingPressStyle())
        }
    }

    struct TribeGalaxyScreen: View {
        let onClose: () -> Void

        var body: some View {
            ZStack {
                TribeGlassBackground()

                VStack(spacing: 16) {
                    HStack {
                        Button(action: onClose) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Palette.textPrimary)
                            }
                            .frame(width: 42, height: 42)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("المجرة")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.textPrimary)

                        Spacer()

                        Color.clear
                            .frame(width: 42, height: 42)
                    }

                    GalaxyNetworkPlaceholder()

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

extension TribeScreen {
    struct GalaxyNetworkPlaceholder: View {
        private let nodeTitles: [String] = [
            "قائد",
            "صانع عادات",
            "محفّز",
            "ثابت",
            "مقاتل",
            "رافع مستوى"
        ]

        var body: some View {
            GlassPanel(cornerRadius: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("شبكة القبيلة")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)

                    Text("مصدر واحد يربط كل العقد. جاهزة للـ Canvas + Haptics.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)

                    GeometryReader { geometry in
                        let side = min(geometry.size.width, geometry.size.height)
                        let radius = side * 0.34
                        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

                        ZStack {
                            Circle()
                                .fill(Palette.mint.opacity(0.18))
                                .frame(width: side * 0.88, height: side * 0.88)
                                .blur(radius: 14)

                            ForEach(Array(nodeTitles.enumerated()), id: \.offset) { index, title in
                                let angle = (Double(index) / Double(nodeTitles.count)) * Double.pi * 2
                                let nodePoint = CGPoint(
                                    x: center.x + CGFloat(cos(angle)) * radius,
                                    y: center.y + CGFloat(sin(angle)) * radius
                                )

                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.white.opacity(0.88))
                                        .frame(width: 15, height: 15)
                                        .overlay(Circle().stroke(Palette.mintStrong.opacity(0.8), lineWidth: 2))

                                    Text(title)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Palette.textSecondary)
                                }
                                .position(nodePoint)
                            }

                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Palette.mintStrong.opacity(0.95),
                                            Palette.mint.opacity(0.45)
                                        ],
                                        center: .center,
                                        startRadius: 5,
                                        endRadius: 70
                                    )
                                )
                                .frame(width: 110, height: 110)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.65), lineWidth: 1)
                                )
                                .shadow(color: Palette.mintStrong.opacity(0.45), radius: 26, x: 0, y: 0)

                            VStack(spacing: 2) {
                                Text("Source")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.white)
                                Text("المصدر")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.88))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: 360)
                }
            }
        }
    }

    struct ArenaBoardView: View {
        let challenges: [ArenaChallengePlaceholder]

        private var totalParticipants: Int {
            challenges.reduce(0) { $0 + $1.participants }
        }

        private var averageProgressPercent: Int {
            let avg = challenges.reduce(0.0) { $0 + $1.progress } / Double(max(challenges.count, 1))
            return Int((avg * 100).rounded())
        }

        var body: some View {
            ScrollView {
                VStack(spacing: 12) {
                    GlassPanel(cornerRadius: 28) {
                        HStack(spacing: 10) {
                            ArenaSummaryItem(title: "التحديات", value: "\(challenges.count)")
                            ArenaSummaryItem(title: "المشاركين", value: "\(totalParticipants)")
                            ArenaSummaryItem(title: "المتوسط", value: "\(averageProgressPercent)%")
                        }
                    }

                    ForEach(challenges) { challenge in
                        GlassPanel {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label(challenge.title, systemImage: "bolt.circle.fill")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(Palette.textPrimary)
                                        .labelStyle(.titleAndIcon)

                                    Spacer(minLength: 0)

                                    Text("\(challenge.participants) عضو")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Palette.textPrimary.opacity(0.82))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Color.white.opacity(0.55)))
                                }

                                Text(challenge.subtitle)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Palette.textSecondary)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule(style: .continuous)
                                            .fill(Color.black.opacity(0.08))
                                            .frame(height: 8)

                                        Capsule(style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Palette.mintStrong, Palette.sandStrong],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(
                                                width: max(10, geo.size.width * challenge.progress.clampedToProgressRange),
                                                height: 8
                                            )
                                    }
                                }
                                .frame(height: 8)

                                HStack {
                                    Text("\(Int((challenge.progress * 100).rounded()))% مكتمل")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Palette.textSecondary)
                                    Spacer(minLength: 0)
                                    Text("تحديث لحظي")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(Palette.mintStrong.opacity(0.85))
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    struct ArenaSummaryItem: View {
        let title: String
        let value: String

        var body: some View {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

extension TribeScreen {
    struct InnerTribeView: View {
        private let collectiveProgress: Double = 0.73
        private let members: [TribeMemberSnapshot] = [
            TribeMemberSnapshot(name: "محمد", initials: "م", move: 0.88, exercise: 0.72, stand: 0.92, level: 17),
            TribeMemberSnapshot(name: "سارة", initials: "س", move: 0.74, exercise: 0.66, stand: 0.91, level: 15),
            TribeMemberSnapshot(name: "أمير", initials: "أ", move: 0.69, exercise: 0.58, stand: 0.83, level: 14),
            TribeMemberSnapshot(name: "ليلى", initials: "ل", move: 0.82, exercise: 0.76, stand: 0.95, level: 16),
            TribeMemberSnapshot(name: "نور", initials: "ن", move: 0.61, exercise: 0.49, stand: 0.80, level: 13)
        ]
        private let memberCardBorderColors: [Color] = [
            Color(red: 0.98, green: 0.94, blue: 0.08), // Yellow
            Color(red: 0.66, green: 0.54, blue: 0.95), // Purple
            Color(red: 0.55, green: 0.91, blue: 0.82), // Mint
            Color(red: 0.09, green: 0.40, blue: 0.98), // Blue
            Color(red: 0.93, green: 0.84, blue: 0.67) // Beige
        ]

        private var teamEnergy: Int {
            let value = members.reduce(0.0) { $0 + $1.move } / Double(max(members.count, 1))
            return Int((value * 100).rounded())
        }

        private var activeMembers: Int {
            members.filter { $0.move > 0.7 }.count
        }

        var body: some View {
            ScrollView {
                VStack(spacing: 14) {
                    GlassPanel(cornerRadius: 30) {
                        VStack(spacing: 16) {
                            TribeActivityRing()


                            Text("هدف القبيلة المشترك")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(Palette.textPrimary)

                            Text("\(Int((collectiveProgress * 100).rounded()))% من هدف 5 أعضاء")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    HStack(spacing: 10) {
                        InnerStatChip(title: "طاقة الفريق", value: "\(teamEnergy)%")
                        InnerStatChip(title: "الأعضاء النشطين", value: "\(activeMembers)/5")
                        InnerStatChip(title: "الهدف", value: "يومي")
                    }

                    VStack(spacing: 12) {
                        ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                            TribeMemberRow(
                                member: member,
                                borderColor: memberCardBorderColors[index % memberCardBorderColors.count]
                            )
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    struct InnerStatChip: View {
        let title: String
        let value: String

        var body: some View {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(TribeNativeGlassCardBackground(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.56), lineWidth: 1)
            )
        }
    }

    struct TribeActivityRing: View {
        var body: some View {
            Image("Tribe-Ring")
                .resizable()
                .scaledToFit()
                .frame(width: 252, height: 252)
                .shadow(color: Palette.mintStrong.opacity(0.30), radius: 14, x: 0, y: 6)
                .padding(.top, 4)
                .padding(.bottom, 4)
        }
    }


    struct TribeMemberRow: View {
        let member: TribeMemberSnapshot
        let borderColor: Color

        var body: some View {
            GlassPanel {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Palette.sandStrong, Palette.mintStrong],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)

                        Text(member.initials)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.textPrimary)

                        Text("AiQo Level \(member.level)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.textSecondary)
                    }

                    Spacer(minLength: 0)

                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(borderColor.opacity(0.94), lineWidth: 2.8)
            )
            .shadow(color: borderColor.opacity(0.22), radius: 8, x: 0, y: 2)
        }
    }
}

extension TribeScreen {
    struct GlobalLegacyView: View {
        private let entries: [GlobalLeaderboardEntry] = [
            GlobalLeaderboardEntry(rank: 1, name: "Mazen Alpha", level: 21, streakDays: 124),
            GlobalLeaderboardEntry(rank: 2, name: "Noor Prime", level: 19, streakDays: 91),
            GlobalLeaderboardEntry(rank: 3, name: "Hamoudi", level: 17, streakDays: 80),
            GlobalLeaderboardEntry(rank: 4, name: "Layla Boost", level: 15, streakDays: 64),
            GlobalLeaderboardEntry(rank: 5, name: "Ameer Zero", level: 14, streakDays: 53),
            GlobalLeaderboardEntry(rank: 6, name: "Sara Flux", level: 13, streakDays: 45)
        ]

        private var topThree: [GlobalLeaderboardEntry] {
            Array(entries.prefix(3))
        }

        private var others: [GlobalLeaderboardEntry] {
            Array(entries.dropFirst(3))
        }

        var body: some View {
            ScrollView {
                VStack(spacing: 12) {
                    GlassPanel(cornerRadius: 28) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Legacy Global")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.textSecondary)

                            Text("إنت مو شخص يبدأ من صفر ... إنت جاي ويا تاريخ")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(Palette.textPrimary)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 10) {
                        ForEach(topThree) { entry in
                            GlobalTopCard(entry: entry)
                        }
                    }

                    ForEach(others) { entry in
                        GlassPanel {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Palette.mint.opacity(0.36))
                                    Text("#\(entry.rank)")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(Palette.textPrimary)
                                }
                                .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.name)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(Palette.textPrimary)
                                    Text("Streak \(entry.streakDays) days")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Palette.textSecondary)
                                }

                                Spacer(minLength: 0)

                                Text("Level \(entry.level)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Palette.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(Color.white.opacity(0.60)))
                            }
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    struct GlobalTopCard: View {
        let entry: GlobalLeaderboardEntry

        var body: some View {
            GlassPanel(cornerRadius: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("#\(entry.rank)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                    Text(entry.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(Palette.textPrimary)
                    Text("Level \(entry.level)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.mintStrong.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private extension Double {
    var clampedToProgressRange: CGFloat {
        CGFloat(min(max(self, 0), 1))
    }
}

private struct TribeFloatingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.snappy(duration: 0.25, extraBounce: 0.06), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        TribeScreen(allowsPreviewAccess: true)
    }
    .environment(\.layoutDirection, .rightToLeft)
}
