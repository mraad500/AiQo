import SwiftUI

struct QuestsView: View {
    @ObservedObject var questsStore: QuestDailyStore
    @State private var selectedStageNumber = 1
    @State private var visionCoachChallenge: Challenge?
    @State private var helpStrangersChallenge: Challenge?

    var body: some View {
        let stages = questsStore.availableStageNumbers.map { ChallengeStage(number: $0) }
        let stageChallenges = questsStore.challenges(forStage: selectedStageNumber)

        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    StageSelectorBar(stages: stages, selectedStageNumber: $selectedStageNumber)

                    if !stageChallenges.isEmpty {
                        ForEach(stageChallenges) { challenge in
                            let state = questsStore.cardState(for: challenge)

                            if state == .locked {
                                QuestCardView(challenge: challenge, state: state, questsStore: questsStore)
                            } else if challenge.id == "s1_help_3_strangers", state != .completed {
                                Button {
                                    helpStrangersChallenge = challenge
                                } label: {
                                    QuestCardView(challenge: challenge, state: state, questsStore: questsStore)
                                }
                                .buttonStyle(.plain)
                            } else if challenge.opensVisionCoach {
                                Button {
                                    visionCoachChallenge = challenge
                                } label: {
                                    QuestCardView(challenge: challenge, state: state, questsStore: questsStore)
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    ChallengeDetailView(challenge: challenge, questsStore: questsStore)
                                } label: {
                                    QuestCardView(challenge: challenge, state: state, questsStore: questsStore)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        ChallengePlaceholderCard(stageNumber: selectedStageNumber)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
            .onAppear {
                if !stages.map(\.number).contains(selectedStageNumber) {
                    selectedStageNumber = stages.first?.number ?? 1
                }
                questsStore.refreshOnAppear()
            }
        }
        .sheet(item: activeRewardBinding) { reward in
            ChallengeRewardSheet(reward: reward) {
                questsStore.claimActiveReward()
            }
            .presentationDetents([.fraction(0.46)])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(true)
        }
        .sheet(item: $helpStrangersChallenge) { challenge in
            HelpStrangersBottomSheet {
                completeHelpStrangersQuest(challenge)
            }
            .presentationDetents([.fraction(0.88), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .fullScreenCover(item: $visionCoachChallenge) { challenge in
            VisionCoachView(challenge: challenge, questsStore: questsStore)
        }
    }

    private var activeRewardBinding: Binding<PendingChallengeReward?> {
        Binding(
            get: { questsStore.activeReward },
            set: { _ in }
        )
    }

    private func completeHelpStrangersQuest(_ challenge: Challenge) {
        questsStore.startChallenge(challenge)

        let goal = Int(challenge.goalValue.rounded(.down))
        let current = Int(questsStore.progress(for: challenge).rounded(.down))
        let remaining = max(goal - current, 0)

        guard remaining > 0 else { return }
        questsStore.addManualProgress(remaining, for: challenge)
    }
}
