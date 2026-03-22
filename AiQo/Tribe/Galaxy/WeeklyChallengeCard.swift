import SwiftUI

struct WeeklyChallengeCard: View {
    let challenge: ArenaWeeklyChallenge?
    let userTribe: ArenaTribe?
    let isParticipating: Bool
    let userTribeScore: Double
    let leadingScore: Double
    var onJoinChallenge: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // العنوان
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.aiqoSand)
                Text("تحدي الأسبوع")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(TribePalette.textPrimary)
            }

            if let challenge = challenge {
                // اسم التحدي
                Text(challenge.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(TribePalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                // المؤقت — capsule style
                CountdownTimerView(endDate: challenge.endDate)
                    .frame(maxWidth: .infinity)

                // Progress bar
                if userTribe != nil, isParticipating {
                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { geo in
                            let fraction = leadingScore > 0 ? min(userTribeScore / leadingScore, 1.0) : 0
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(TribePalette.progressTrack)
                                    .frame(height: 8)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.aiqoMint.opacity(0.9), Color.aiqoMint.opacity(0.6)],
                                            startPoint: .trailing,
                                            endPoint: .leading
                                        )
                                    )
                                    .frame(width: max(8, geo.size.width * fraction), height: 8)
                            }
                        }
                        .frame(height: 8)

                        Text("\(Int(userTribeScore))% — قبيلتك")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(TribePalette.textSecondary)
                    }
                }

                // المعيار
                HStack(spacing: 6) {
                    Image(systemName: challenge.metric.icon)
                        .font(.system(size: 13))
                        .symbolRenderingMode(.hierarchical)
                    Text("المعيار: \(challenge.metric.displayName)")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                }
                .foregroundStyle(TribePalette.textTertiary)

                // CTA
                if let tribe = userTribe {
                    if isParticipating {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.aiqoMint.opacity(0.8))
                            Text("قبيلتك مشاركة")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(TribePalette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.aiqoMint.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.aiqoMint.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                    } else {
                        Button(action: onJoinChallenge) {
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                    .symbolRenderingMode(.hierarchical)
                                Text("شارك \(tribe.name)")
                            }
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(hex: "2D6B4A"))
                            )
                            .shadow(color: Color(hex: "2D6B4A").opacity(0.25), radius: 8, y: 4)
                        }
                    }
                } else {
                    Text("أنشئ قبيلتك مع الاشتراك العائلي أو انضم لقبيلة صديقك")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(TribePalette.textTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(TribePalette.textTertiary)
                    Text("لا يوجد تحدي حالياً — ترقبوا الأسبوع القادم!")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(TribePalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.aiqoMint.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
        }
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}
