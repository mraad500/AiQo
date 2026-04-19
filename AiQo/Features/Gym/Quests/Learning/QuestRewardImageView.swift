import SwiftUI
import UIKit

/// Renders a quest's reward badge. Always uses the configured asset for the learning
/// quest so the purple generic fallback never appears. For other quest sources the view
/// falls back to a source-appropriate SF Symbol if the asset happens to be missing.
struct QuestRewardImageView: View {
    let quest: QuestDefinition
    var size: CGFloat = 100

    var body: some View {
        if quest.source == .learning {
            // Learning quest always renders its configured asset — no SF Symbol fallback.
            Image(quest.rewardImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else if UIImage(named: quest.rewardImageName) != nil {
            Image(quest.rewardImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            fallback
        }
    }

    @ViewBuilder
    private var fallback: some View {
        let symbolName = symbolName(for: quest.source)
        let tint = fallbackTint(for: quest.source)
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.85), tint.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: symbolName)
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .frame(width: size, height: size)
        .shadow(color: tint.opacity(0.18), radius: 8, x: 0, y: 4)
    }

    private func symbolName(for source: QuestSource) -> String {
        switch source {
        case .healthkit: return "heart.fill"
        case .water: return "drop.fill"
        case .workout: return "figure.run"
        case .camera: return "camera.fill"
        case .timer: return "stopwatch.fill"
        case .social: return "person.2.fill"
        case .kitchen: return "fork.knife"
        case .share: return "square.and.arrow.up.fill"
        case .manual: return "checkmark.seal.fill"
        case .learning: return "questionmark" // Unreachable — learning uses asset path above.
        }
    }

    private func fallbackTint(for source: QuestSource) -> Color {
        switch source {
        case .healthkit: return Color(red: 0.95, green: 0.45, blue: 0.55)
        case .water: return Color(red: 0.35, green: 0.55, blue: 0.95)
        case .workout: return Color(red: 0.35, green: 0.72, blue: 0.55)
        case .camera: return Color(red: 0.92, green: 0.62, blue: 0.35)
        case .timer: return Color(red: 0.55, green: 0.55, blue: 0.62)
        case .social: return Color(red: 0.95, green: 0.55, blue: 0.72)
        case .kitchen: return Color(red: 0.85, green: 0.55, blue: 0.35)
        case .share: return Color(red: 0.55, green: 0.72, blue: 0.95)
        case .manual: return Color(red: 0.92, green: 0.78, blue: 0.45)
        case .learning: return Color.gray // Unreachable — learning uses asset path above.
        }
    }
}
