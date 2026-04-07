import SwiftUI

struct BattleLeaderboard: View {
    let participations: [LeaderboardRow]
    let userTribeName: String?

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // العنوان
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.aiqoSand)
                Text("لوحة المعركة")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(TribePalette.textPrimary)
            }

            let maxScore = participations.map(\.score).max() ?? 100

            VStack(spacing: 6) {
                ForEach(Array(participations.enumerated()), id: \.element.id) { index, entry in
                    BattleLeaderboardRow(
                        rank: entry.rank,
                        tribeName: entry.tribeName,
                        score: entry.score,
                        maxScore: maxScore,
                        isUserTribe: entry.tribeName == userTribeName
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : -20)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(Double(index) * 0.06),
                        value: appeared
                    )
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
        }
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .onAppear {
            appeared = true
        }
    }
}

// MARK: - Pinned Bar لترتيب قبيلتك

struct YourTribeRankBar: View {
    let tribeName: String
    let rank: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 14))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.aiqoSand)
            Text("قبيلتك: #\(rank) — \(tribeName)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(TribePalette.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(.ultraThickMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.white.opacity(0.3)),
            alignment: .top
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
    }
}
