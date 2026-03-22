import SwiftUI

struct BattleLeaderboardRow: View {
    let rank: Int
    let tribeName: String
    let score: Double
    let maxScore: Double
    let isUserTribe: Bool

    @State private var animateProgress = false

    var body: some View {
        HStack(spacing: 12) {
            // الترتيب
            Group {
                if rank <= 3 {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(medalColor)
                } else {
                    Text("#\(rank)")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(TribePalette.textTertiary)
                }
            }
            .frame(width: 32)

            // اسم القبيلة
            Text(tribeName)
                .font(.system(.subheadline, design: .rounded, weight: isUserTribe ? .bold : .semibold))
                .foregroundStyle(TribePalette.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 4)

            // Progress bar + النسبة
            HStack(spacing: 8) {
                GeometryReader { geo in
                    let fraction = maxScore > 0 ? min(score / maxScore, 1.0) : 0
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(TribePalette.progressTrack)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.aiqoMint.opacity(0.85), Color.aiqoMint.opacity(0.55)],
                                    startPoint: .trailing,
                                    endPoint: .leading
                                )
                            )
                            .frame(width: animateProgress ? max(4, geo.size.width * fraction) : 4)
                    }
                }
                .frame(width: 80, height: 8)

                Text("\(Int(score))%")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(TribePalette.textSecondary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(rowBackground)
                .overlay(
                    isUserTribe
                        ? RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.aiqoMint.opacity(0.45), lineWidth: 1.5)
                        : nil
                )
        }
        .shadow(color: isUserTribe ? Color.aiqoMint.opacity(0.1) : .clear, radius: 8, y: 2)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateProgress = true
            }
        }
    }

    private var rowBackground: Color {
        if isUserTribe {
            return Color.aiqoMint.opacity(0.1)
        }
        return rank.isMultiple(of: 2) ? Color.aiqoSand.opacity(0.05) : Color.aiqoMint.opacity(0.03)
    }

    private var medalColor: Color {
        switch rank {
        case 1: return Color(hex: "FFD700")
        case 2: return Color(hex: "C0C0C0")
        case 3: return Color(hex: "CD7F32")
        default: return TribePalette.textTertiary
        }
    }
}
