import SwiftUI

struct ChallengeDetailView: View {
    let challenge: Challenge
    @ObservedObject var questsStore: QuestDailyStore

    @State private var openRunView = false
    @State private var showAutoTrackingNote = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                rewardBlock

                detailRow(title: L10n.t("quests.detail.goal"), value: challenge.goalText)
                detailRow(title: L10n.t("quests.detail.verify"), value: challenge.verifyText)

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("quests.detail.reward"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))

                    HStack(spacing: 12) {
                        Image(challenge.awardImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 126, height: 126)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(challenge.title)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text(L10n.t("quests.detail.reward.hint"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(14)
                .background(detailCardTint.opacity(0.2), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button(action: onStartTapped) {
                    Text(primaryButtonTitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(GymTheme.beige, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(isPrimaryButtonDisabled)
                .opacity(isPrimaryButtonDisabled ? 0.55 : 1)

                if showAutoTrackingNote && challenge.isHealthKitBacked {
                    Text(L10n.t("quests.detail.tracking_note"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Text("\(L10n.t("quests.run.progress")): \(questsStore.progressText(for: challenge))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .navigationTitle(challenge.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $openRunView) {
            ChallengeRunView(challenge: challenge, questsStore: questsStore)
        }
        .onAppear {
            questsStore.refreshOnAppear()
        }
    }

    private var rewardBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(challenge.title)
                .font(.system(size: 30, weight: .heavy, design: .rounded))

            Text(challenge.subtitle)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(challenge.description)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Image(challenge.awardImageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 190, alignment: .top)
                .scaleEffect(1.38, anchor: .top)
                .offset(y: -28)
                .clipped()
                .padding(.top, 6)
                .padding(.bottom, 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(detailCardTint.opacity(0.24))
                )
        )
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(detailCardTint.opacity(0.16))
                )
        )
    }

    private var primaryButtonTitle: String {
        if questsStore.isCompleted(challenge) {
            return L10n.t("quests.detail.completed_today")
        }

        if challenge.isAutomatic && questsStore.isTracking(challenge) {
            return L10n.t("quests.detail.tracking_active")
        }

        return L10n.t("quests.detail.start")
    }

    private var isPrimaryButtonDisabled: Bool {
        questsStore.isCompleted(challenge)
    }

    private func onStartTapped() {
        questsStore.startChallenge(challenge)

        if challenge.isAutomatic {
            showAutoTrackingNote = challenge.isHealthKitBacked
            questsStore.refreshOnAppear()
        } else {
            openRunView = true
        }
    }

    private var detailCardTint: Color {
        switch challenge.metricType {
        case .steps, .kindnessActs:
            return GymTheme.mint
        case .plankSeconds:
            return GymTheme.beige
        case .pushups:
            return Color(red: 1.0, green: 0.72, blue: 0.54)
        case .sleepHours, .sleepStreakDays:
            return Color(red: 0.74, green: 0.80, blue: 1.0)
        case .activeCalories:
            return Color(red: 0.98, green: 0.64, blue: 0.52)
        case .distanceKilometers:
            return Color(red: 0.64, green: 0.86, blue: 0.98)
        case .questCompletions:
            return GymTheme.gold
        case .zone2Minutes:
            return Color(red: 0.45, green: 0.80, blue: 0.62)
        case .mindfulnessSessions:
            return Color(red: 0.64, green: 0.78, blue: 0.94)
        }
    }
}
