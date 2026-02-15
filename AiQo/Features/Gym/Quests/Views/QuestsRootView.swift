import SwiftUI

struct QuestsRootView: View {
    @ObservedObject var questsStore: QuestsStore

    var body: some View {
        NavigationStack {
            QuestsListView(questsStore: questsStore)
        }
        .sheet(item: activeRewardBinding) { reward in
            ChallengeRewardSheet(reward: reward) {
                questsStore.claimActiveReward()
            }
            .presentationDetents([.fraction(0.46)])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(true)
        }
    }

    private var activeRewardBinding: Binding<PendingChallengeReward?> {
        Binding(
            get: { questsStore.activeReward },
            set: { _ in }
        )
    }
}

struct QuestsListView: View {
    @ObservedObject var questsStore: QuestsStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(questsStore.challenges) { challenge in
                    NavigationLink {
                        ChallengeDetailView(challenge: challenge, questsStore: questsStore)
                    } label: {
                        QuestChallengeCard(challenge: challenge, questsStore: questsStore)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .onAppear {
            questsStore.refreshOnAppear()
        }
    }
}

private struct QuestChallengeCard: View {
    let challenge: Challenge
    @ObservedObject var questsStore: QuestsStore

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(challenge.awardImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)
                .scaleEffect(2.05)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(challenge.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    statusBadge
                }

                Text(challenge.subtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(challenge.description)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(questsStore.progressText(for: challenge))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.35))

                            Capsule()
                                .fill(challengeTint)
                                .frame(width: geometry.size.width * questsStore.progressFraction(for: challenge))
                        }
                    }
                    .frame(height: 7)
                }
                .padding(.top, 4)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .padding(14)
        .background(cardBackground)
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.16), in: Capsule())
    }

    private var statusText: String {
        if questsStore.isCompleted(challenge) {
            return L10n.t("quests.status.completed")
        }
        if questsStore.isTracking(challenge) {
            return L10n.t("quests.status.tracking")
        }
        return L10n.t("quests.status.ready")
    }

    private var statusColor: Color {
        if questsStore.isCompleted(challenge) {
            return Color.green
        }
        if questsStore.isTracking(challenge) {
            return Color.orange
        }
        return Color.blue
    }

    private var challengeTint: Color {
        switch challenge.metricType {
        case .steps:
            return GymTheme.mint
        case .plankSeconds:
            return GymTheme.beige
        case .pushups:
            return Color(red: 1.0, green: 0.72, blue: 0.54)
        case .sleepHours:
            return Color(red: 0.74, green: 0.80, blue: 1.0)
        case .activeCalories:
            return Color(red: 0.98, green: 0.64, blue: 0.52)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(challengeTint.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.34), lineWidth: 0.6)
            )
            .shadow(color: challengeTint.opacity(0.16), radius: 10, x: 0, y: 6)
    }
}
