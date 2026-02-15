import SwiftUI

struct QuestsView: View {
    @ObservedObject var questsStore: QuestDailyStore
    @State private var selectedStageNumber = 1

    private let stages = ChallengeStage.all

    var body: some View {
        let stageChallenges = questsStore.challenges(forStage: selectedStageNumber)

        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    StageSelectorBar(stages: stages, selectedStageNumber: $selectedStageNumber)

                    if !stageChallenges.isEmpty {
                        ForEach(stageChallenges) { challenge in
                            NavigationLink {
                                ChallengeDetailView(challenge: challenge, questsStore: questsStore)
                            } label: {
                                ChallengeCard(challenge: challenge, questsStore: questsStore)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        ForEach(0..<Challenge.stage1.count, id: \.self) { index in
                            ChallengePlaceholderCard(stageNumber: selectedStageNumber, index: index)
                        }
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
