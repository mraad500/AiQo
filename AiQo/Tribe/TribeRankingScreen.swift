import SwiftUI

// MARK: - Model
struct TribeMember: Identifiable, Hashable {
    let id: UUID
    var name: String
    var points: Int
    var countryFlag: String
    var region: String
    var avatarLetter: String

    var displayName: String { name }

    /// UUID ثابت يعتمد على الاسم حتى ما يصير تبديل/قفزات بالـ layout
    static func stableID(for name: String) -> UUID {
        let data = Array(name.utf8)
        var bytes = [UInt8](repeating: 0, count: 16)
        for (i, b) in data.enumerated() {
            bytes[i % 16] = bytes[i % 16] &+ b
        }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                           bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11],
                           bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

// MARK: - Screen
struct TribeRankingScreen: View {

    @Environment(\.dismiss) private var dismiss

    @State private var members: [TribeMember] = []
    @State private var selected: TribeMember?

    var body: some View {
        ZStack {
            // Background (خفيف)
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 12) {

                header

                HStack {
                    pill(text: "Weekly Reset · New Season Coming", systemImage: "calendar")
                    Spacer()
                }
                .padding(.horizontal, 16)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {

                        // استخدام indices أحسن من enumerated للأداء
                        ForEach(members.indices, id: \.self) { i in
                            let m = members[i]
                            TribeRow(
                                member: m,
                                rank: i + 1,
                                isTop: i < 3
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { selected = m }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await refreshDemo()
                }
            }
            .padding(.top, 8)
        }
        .onAppear {
            if members.isEmpty { seedDemo() }
        }
        .sheet(item: $selected) { member in
            TribeMemberSheet(member: member)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Global Tribe Ranking")
                    .font(.system(size: 24, weight: .black))
                Text("Top AiQo athletes worldwide")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .glassCard(corner: 22, shadow: .light)
        .padding(.horizontal, 16)
    }

    // MARK: - UI helpers
    private func pill(text: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(text).lineLimit(1)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
    }

    // MARK: - Demo Data (ثابت + مرتب)
    private func seedDemo() {
        let base: [(String, String, String, Int)] = [
            ("Hamoodi", "🇮🇶", "Middle East",   2198),
            ("Jon",     "🇺🇸", "North America", 1872),
            ("Liam",    "🇬🇧", "Europe",        1855),
            ("Kenji",   "🇯🇵", "Asia",          1845),
            ("Aisha",   "🇦🇪", "Middle East",   1747),
            ("Sofia",   "🇪🇸", "Europe",        1647),
            ("Maya",    "🇮🇳", "Asia",          1597),
            ("Luca",    "🇮🇹", "Europe",        1275)
        ]

        var arr: [TribeMember] = base.map { name, flag, region, points in
            TribeMember(
                id: TribeMember.stableID(for: name),
                name: name,
                points: points,
                countryFlag: flag,
                region: region,
                avatarLetter: String(name.prefix(1)).uppercased()
            )
        }

        arr.sort { $0.points > $1.points }
        members = arr
    }

    private func bumpDemoScores() {
        guard !members.isEmpty else { return }
        var copy = members

        // تغييرات بسيطة بدون عشوائية كبيرة
        for i in copy.indices {
            if i == 0 { continue } // خلي الأول غالباً ثابت حتى ما “يرجف” الترتيب
            if (i % 3) == 0 { copy[i].points += 10 }
        }

        copy.sort { $0.points > $1.points }
        members = copy
    }

    private func refreshDemo() async {
        try? await Task.sleep(nanoseconds: 300_000_000)
        bumpDemoScores()
    }
}

// MARK: - Row (Equatable لتقليل إعادة الرسم)
private struct TribeRow: View, Equatable {
    let member: TribeMember
    let rank: Int
    let isTop: Bool

    static func == (lhs: TribeRow, rhs: TribeRow) -> Bool {
        lhs.member == rhs.member && lhs.rank == rhs.rank && lhs.isTop == rhs.isTop
    }

    var body: some View {
        HStack(spacing: 12) {

            rankBadge

            avatarCircle

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(.system(size: 17, weight: .bold))

                Text("\(member.countryFlag)  \(member.region)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(member.points)")
                    .font(.system(size: 20, weight: .black))
                Text("Tribe Points")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(corner: 18, shadow: .none) // بدون shadow ثقيلة لكل رو
        .overlay(topBorder)
    }

    // ✅ صار نفس البقية 100%: لا شي فوق ولا خلف
    private var rankBadge: some View {
        Text("\(rank)")
            .font(.system(size: 18, weight: .black))
            .frame(width: 34, height: 34)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .frame(width: 40)
    }

    private var avatarCircle: some View {
        Text(member.avatarLetter)
            .font(.system(size: 16, weight: .black))
            .frame(width: 34, height: 34)
            .background(Color.white.opacity(0.7), in: Circle())
            .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
    }

    private var topBorder: some View {
        Group {
            if isTop {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(rank == 1 ? 0.42 : 0.26),
                            lineWidth: rank == 1 ? 1.5 : 1.1)
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - Member Sheet (خفيف)
private struct TribeMemberSheet: View {
    let member: TribeMember

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 14) {

                VStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.system(size: 26, weight: .black))
                    Text("\(member.countryFlag)  \(member.region)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                HStack(spacing: 10) {
                    statCard(title: "Tribe Points", value: "\(member.points)", icon: "bolt.fill")
                    statCard(title: "Consistency", value: "High", icon: "flame.fill")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("How they earned it")
                        .font(.system(size: 16, weight: .bold))

                    Text("Movement-based progress. No shortcuts. In AiQo, rank is earned through real actions.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .glassCard(corner: 20, shadow: .light)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                Spacer()
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 22, weight: .black))

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(corner: 20, shadow: .none)
    }
}

// MARK: - Glass Modifier (محسّن)
private enum GlassShadow {
    case none
    case light
}

private extension View {
    func glassCard(corner: CGFloat, shadow: GlassShadow) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            )
            .modifier(GlassShadowModifier(shadow: shadow))
    }
}

private struct GlassShadowModifier: ViewModifier {
    let shadow: GlassShadow

    func body(content: Content) -> some View {
        switch shadow {
        case .none:
            content
        case .light:
            content.shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
        }
    }
}
