// Supabase hook: replace the view-model callbacks passed into these cards with live
// mutations once Tribe actions are persisted remotely.
import SwiftUI

struct GalaxySelectionCard: View {
    let node: GalaxyNode
    let tribeName: String
    let onSpark: () -> Void
    let onTogglePreview: () -> Void

    var body: some View {
        TribeGlassCard(cornerRadius: 24, padding: 16, tint: Color.white.opacity(0.02)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tribeName)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("\(node.title) • المستوى \(node.member.level.arabicFormatted)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.66))
                    }

                    Spacer(minLength: 12)

                    if let visibleEnergy = node.visibleEnergy {
                        Text("طاقة اليوم +\(visibleEnergy)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
                                    )
                            )
                    } else {
                        Text("خصوصية مفعلة")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }

                HStack(spacing: 10) {
                    Button(action: onSpark) {
                        Text("شرارة")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hue: node.hue, saturation: 0.38, brightness: 0.92).opacity(0.44),
                                                Color(hue: node.hue, saturation: 0.30, brightness: 0.88).opacity(0.26)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onTogglePreview) {
                        Text("وضع العرض")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.84))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct GalaxyChallengeMiniCard: View {
    let challenge: TribeChallenge
    let isActive: Bool
    let onTap: () -> Void
    let onContribute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: challenge.goalType.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.06))
                    )

                Text(challenge.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Text(challenge.scope.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.64))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.05))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hue: challenge.goalType.accentHue, saturation: 0.34, brightness: 0.92).opacity(0.55),
                                    Color.white.opacity(0.22)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * challenge.progress)
                }
            }
            .frame(height: 8)

            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(challenge.remainingText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))

                    Text(challenge.timeRemainingText())
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.52))
                }

                Spacer(minLength: 8)

                Button(action: onContribute) {
                    Text(challenge.progressValue == 0 ? "ابدأ" : "ساهم")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(isActive ? 0.08 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(isActive ? 0.12 : 0.06), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(perform: onTap)
    }
}

struct GalaxyToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}
