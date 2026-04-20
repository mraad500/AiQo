import SwiftUI
import UIKit

/// Celebration sheet shown after a quest reaches its completed state. Presented
/// as a medium-detent `.sheet` over `.ultraThinMaterial` (see `QuestsView` →
/// `.sheet(item: $completedQuestForCelebration)`).
///
/// Layout is designed to fit comfortably in the medium detent (~half screen) —
/// badge, congrats text, XP pill, earned time, and dismiss button.
struct QuestCompletionCelebration: View {
    let quest: QuestDefinition
    let onDismiss: () -> Void

    // Captured at init so the displayed time matches the user's "moment of completion"
    // even if the sheet lingers before dismiss. Also feeds the persisted
    // `QuestEarnedAchievement.earnedDate` on dismiss.
    private let earnedAt = Date()

    @State private var badgeScale: CGFloat = 0.3
    @State private var badgeOpacity: Double = 0
    @State private var contentOpacity: Double = 0

    private var xpAwarded: Int? { QuestXPRewards.xp(for: quest) }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 4)

            // Badge — bounces in on appear.
            Image(quest.rewardImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .scaleEffect(badgeScale)
                .opacity(badgeOpacity)
                .shadow(color: Color(hex: "EBCF97").opacity(0.45), radius: 24, y: 8)

            VStack(spacing: 6) {
                Text(questLocalizedText("gym.quest.congrats"))
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "1A1A1A"))

                Text(
                    String(
                        format: questLocalizedText("gym.quest.completedChallenge"),
                        questLocalizedText(quest.localizedTitleKey)
                    )
                )
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "444444"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            }
            .opacity(contentOpacity)

            // XP pill — only rendered when the quest has a product-decided XP value.
            if let xp = xpAwarded {
                xpPill(xp: xp)
                    .opacity(contentOpacity)
            }

            // Earned-at timestamp — warm "today at HH:mm" line.
            Text(earnedAtDisplay)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "666666"))
                .opacity(contentOpacity)

            Text(questLocalizedText("gym.quest.rewardSaved"))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color(hex: "777777"))
                .opacity(contentOpacity)

            Spacer(minLength: 4)

            Button(action: onDismiss) {
                Text(questLocalizedText("gym.quest.okay"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "1A1A1A"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(hex: "EBCF97"))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.bottom, 10)
            .opacity(contentOpacity)
        }
        .padding(.top, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: playEntranceAnimation)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func xpPill(xp: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
            Text(String(format: "+%d XP", locale: questAppLocale(), xp))
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(Color(hex: "6B5B2E"))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(Color(hex: "F5E4B4"))
        )
        .overlay(
            Capsule().stroke(Color(hex: "EBCF97"), lineWidth: 0.8)
        )
    }

    // MARK: - Formatting

    private var earnedAtDisplay: String {
        let formatter = DateFormatter()
        formatter.locale = questAppLocale()
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: earnedAt)
        return String(
            format: questLocalizedText("gym.quest.celebration.today_at.format"),
            locale: questAppLocale(),
            time
        )
    }

    // MARK: - Animation

    private func playEntranceAnimation() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.55, blendDuration: 0)) {
            badgeScale = 1.0
            badgeOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.28)) {
            contentOpacity = 1.0
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// Helper kept for any remaining `fullScreenCover` usages that need a clear
/// background. Not used by `QuestCompletionCelebration` anymore (the sheet's
/// `.presentationBackground(.ultraThinMaterial)` handles transparency now).
struct ClearBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
