import SwiftUI

struct EmirateLeadersBanner: View {
    let leaders: ArenaEmirateLeaders?
    let winningTribe: ArenaTribe?
    let challengeTitle: String?

    @State private var appeared = false

    init(leaders: ArenaEmirateLeaders?, winningTribe: ArenaTribe? = nil, challengeTitle: String? = nil) {
        self.leaders = leaders
        self.winningTribe = winningTribe
        self.challengeTitle = challengeTitle
    }

    var body: some View {
        VStack(spacing: 16) {
            // العنوان
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.aiqoSand)
                Text("قادة الإمارة")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(TribePalette.textPrimary)
                Image(systemName: "crown.fill")
                    .font(.system(size: 18))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.aiqoSand)
            }

            if let tribe = winningTribe, leaders != nil {
                VStack(spacing: 12) {
                    // اسم القبيلة
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.aiqoSand)
                        Text(tribe.name)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(TribePalette.textPrimary)
                    }

                    // صف الأعضاء — overlapping
                    HStack(spacing: -8) {
                        ForEach(tribe.members.prefix(5)) { member in
                            MemberInitialsCircle(initials: member.initials, size: 40)
                        }
                    }

                    if let title = challengeTitle {
                        VStack(spacing: 4) {
                            Text("فازوا بتحدي: \"\(title)\"")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(TribePalette.textSecondary)
                            Text("الأسبوع الماضي")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(TribePalette.textTertiary)
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "crown")
                        .font(.system(size: 32))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(TribePalette.textTertiary)
                    Text("العرش شاغر — أول تحدي يبدي قريب")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(TribePalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.aiqoSand.opacity(0.15),
                            Color.aiqoMint.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.aiqoSand.opacity(0.4), lineWidth: 1)
                )
        }
        .shadow(color: Color.aiqoSand.opacity(0.15), radius: 16, y: 6)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -12)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

// MARK: - دائرة الأحرف الأولى للعضو

struct MemberInitialsCircle: View {
    let initials: String
    var size: CGFloat = 40

    private let colors: [Color] = [
        Color(hex: "B7E5D2"),
        Color(hex: "EBCF97"),
        Color(hex: "C5B8E8"),
        Color(hex: "F5C6AA"),
        Color(hex: "A8D8EA"),
    ]

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(colors[abs(initials.hashValue) % colors.count])
            )
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2.5)
            )
            .clipShape(Circle())
    }
}
