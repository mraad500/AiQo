import SwiftUI

struct ChallengeRewardSheet: View {
    let reward: PendingChallengeReward
    let onAddToWins: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 52, height: 5)
                .padding(.top, 8)

            Image(reward.challenge.awardImageName)
                .resizable()
                .scaledToFit()
                .frame(height: 150)

            Text(L10n.t("quests.reward.completed"))
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)

            Text(reward.challenge.title)
                .font(.system(size: 17, weight: .bold, design: .rounded))

            Text(reward.proofValue)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Button(action: onAddToWins) {
                Text(L10n.t("quests.reward.add_to_wins"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(GymTheme.beige, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [GymTheme.mint.opacity(0.14), Color.white.opacity(0.05), GymTheme.beige.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}
