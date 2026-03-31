import SwiftUI
import Combine

struct LevelCardView: View {
    @State private var snapshot = LevelCardSnapshot.load()
    @State private var shieldScale: CGFloat = 1
    @State private var scoreScale: CGFloat = 1

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: LevelSystem.getShieldIconName(for: snapshot.level))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(shieldColor)
                        .frame(width: 22, height: 22)
                        .scaleEffect(shieldScale)

                    Text(NSLocalizedString("level", value: "Level", comment: ""))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.aiqoSub.opacity(0.95))

                    Text("\(snapshot.level)")
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(Color.aiqoText)
                        .offset(y: -4)
                }

                Spacer(minLength: 12)

                LevelScorePillView(
                    title: NSLocalizedString("line_score", value: "Line Score", comment: ""),
                    value: formattedScore(snapshot.lineScore),
                    scale: scoreScale
                )
            }

            GeometryReader { geometry in
                let barWidth = geometry.size.width
                let clamped = snapshot.clampedProgress
                let fillWidth = max(0, barWidth * clamped)
                let indicatorOffset = max(7, min(fillWidth, barWidth - 7)) - 7

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.black.opacity(0.06))

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.aiqoSand.opacity(clamped > 0.02 ? 0.35 : 0))
                        .frame(width: fillWidth)
                        .blur(radius: 2)

                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.aiqoSand)
                        .frame(width: fillWidth)

                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .frame(width: 14, height: 14)
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                        .offset(x: indicatorOffset)
                        .opacity(clamped > 0.02 ? 1 : 0)
                }
                .animation(
                    .spring(response: 0.32, dampingFraction: 0.9),
                    value: snapshot.clampedProgress
                )
            }
            .frame(height: 16)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(cardBackground)
        .shadow(color: Color.black.opacity(0.12), radius: 22, x: 0, y: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(snapshot.level), Line Score \(formattedScore(snapshot.lineScore))")
        .onAppear {
            reloadFromStorage(animated: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("XPUpdated"))) { _ in
            reloadFromStorage(animated: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .levelStoreDidChange)) { _ in
            reloadFromStorage(animated: true)
        }
    }

    private var shieldColor: Color {
        LevelSystem.getShield(for: snapshot.level).color
    }

    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

        return shape
            .fill(Color(Colors.card))
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.55),
                        Color.aiqoSand.opacity(0.18),
                        Color(Colors.card)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
            )
            .overlay(
                shape
                    .fill(.ultraThinMaterial)
                    .opacity(0.95)
            )
            .overlay(
                shape
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
    }

    private func reloadFromStorage(animated: Bool) {
        let newSnapshot = LevelCardSnapshot.load()
        let oldSnapshot = snapshot

        if animated {
            withAnimation(.easeInOut(duration: 0.16)) {
                snapshot = newSnapshot
            }
        } else {
            snapshot = newSnapshot
        }

        if newSnapshot.level != oldSnapshot.level {
            pulseShield()
        }
        if newSnapshot.lineScore != oldSnapshot.lineScore {
            pulseScore()
        }
    }

    private func pulseShield() {
        withAnimation(.easeOut(duration: 0.2)) {
            shieldScale = 1.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                shieldScale = 1
            }
        }
    }

    private func pulseScore() {
        withAnimation(.easeOut(duration: 0.1)) {
            scoreScale = 1.03
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.14)) {
                scoreScale = 1
            }
        }
    }

    private func formattedScore(_ value: Int) -> String {
        Self.numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        return formatter
    }()
}

private struct LevelScorePillView: View {
    let title: String
    let value: String
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.aiqoText.opacity(0.9))

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.aiqoSub)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.aiqoText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 14, x: 0, y: 8)
        .scaleEffect(scale)
    }
}

private struct LevelCardSnapshot: Equatable {
    let level: Int
    let progress: CGFloat
    let lineScore: Int

    var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    static func load() -> LevelCardSnapshot {
        let store = LevelStore.shared
        let storedLevel = max(store.currentLevel, 1)
        let xpForNextLevel = max(store.xpForNextLevel, 1)
        let storedProgress = Double(max(store.currentXP, 0)) / Double(xpForNextLevel)
        let storedScore = max(store.totalXP, 0)

        return LevelCardSnapshot(
            level: storedLevel,
            progress: CGFloat(min(max(storedProgress, 0), 1)),
            lineScore: storedScore
        )
    }
}

enum LevelStorageKeys {
    static let currentLevel = "aiqo.currentLevel"
    static let currentLevelProgress = "aiqo.currentLevelProgress"
    static let legacyTotalPoints = "aiqo.legacyTotalPoints"
}

#Preview {
    LevelCardView()
        .padding()
}
