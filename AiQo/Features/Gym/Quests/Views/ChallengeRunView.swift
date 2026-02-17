import SwiftUI

struct ChallengeRunView: View {
    let challenge: Challenge
    @ObservedObject var questsStore: QuestDailyStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text(challenge.title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))

                progressCard

                switch challenge.metricType {
                case .plankSeconds:
                    plankControls
                default:
                    if challenge.metricType.supportsManualCounter {
                        manualCounterControls
                    } else {
                        Text(L10n.t("quests.run.automatic"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                if questsStore.isCompleted(challenge) {
                    Text(L10n.t("quests.run.completed_today"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.green)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .navigationTitle(L10n.t("quests.run.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            questsStore.startChallenge(challenge)
            questsStore.refreshOnAppear()
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("quests.run.progress"))
                .font(.system(size: 17, weight: .bold, design: .rounded))

            Text(questsStore.progressText(for: challenge))
                .font(.system(size: 24, weight: .heavy, design: .rounded))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.35))

                    Capsule()
                        .fill(GymTheme.mint)
                        .frame(width: geometry.size.width * questsStore.progressFraction(for: challenge))
                }
            }
            .frame(height: 10)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(GymTheme.mint.opacity(0.18))
                )
        )
    }

    private var plankControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.t("quests.run.plank_session"))
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Picker(L10n.t("quests.run.preset"), selection: $questsStore.selectedPlankPresetSeconds) {
                Text("30\(L10n.t("quests.unit.sec"))").tag(30)
                Text("60\(L10n.t("quests.unit.sec"))").tag(60)
            }
            .pickerStyle(.segmented)

            Text("\(L10n.t("quests.run.preset_target")): \(questsStore.selectedPlankPresetSeconds)\(L10n.t("quests.unit.sec"))")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text("\(L10n.t("quests.run.current_set")): \(questsStore.currentPlankSetSeconds)\(L10n.t("quests.unit.sec"))")
                .font(.system(size: 15, weight: .bold, design: .rounded))

            HStack(spacing: 10) {
                Button {
                    questsStore.startPlankTimer(for: challenge)
                } label: {
                    Text(
                        questsStore.isPlankTimerRunning(for: challenge)
                        ? L10n.t("quests.run.timer_running")
                        : L10n.t("quests.run.start_timer")
                    )
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(GymTheme.beige, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.black)
                }
                .disabled(questsStore.isPlankTimerRunning || questsStore.isCompleted(challenge))

                Button {
                    questsStore.finishPlankSet(for: challenge)
                } label: {
                    Text(L10n.t("quests.run.finish_set"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.primary)
                }
                .disabled(!questsStore.isPlankTimerRunning(for: challenge) || questsStore.isCompleted(challenge))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(GymTheme.beige.opacity(0.20))
                )
        )
    }

    private var manualCounterControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(counterTitle)
                .font(.system(size: 18, weight: .bold, design: .rounded))

            HStack(spacing: 10) {
                ForEach(challenge.metricType.manualIncrementOptions, id: \.self) { increment in
                    incrementButton(label: "+\(increment)", value: increment)
                }
            }

            Button {
                questsStore.undoLastManualProgress(for: challenge)
            } label: {
                Text(L10n.t("quests.run.undo"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.primary)
            }
            .disabled(!questsStore.canUndoManualProgress(for: challenge) || questsStore.isCompleted(challenge))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(manualCounterTint.opacity(0.20))
                )
        )
    }

    private func incrementButton(label: String, value: Int) -> some View {
        Button {
            questsStore.addManualProgress(value, for: challenge)
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(GymTheme.beige, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.black)
        }
        .disabled(questsStore.isCompleted(challenge))
    }

    private var counterTitle: String {
        if challenge.metricType == .pushups {
            return L10n.t("quests.run.pushups_counter")
        }
        return L10n.t("quests.run.manual_counter")
    }

    private var manualCounterTint: Color {
        switch challenge.metricType {
        case .pushups:
            return Color(red: 1.0, green: 0.72, blue: 0.54)
        case .zone2Minutes:
            return Color(red: 0.45, green: 0.80, blue: 0.62)
        case .kindnessActs:
            return GymTheme.mint
        case .mindfulnessSessions:
            return Color(red: 0.64, green: 0.78, blue: 0.94)
        case .sleepStreakDays:
            return Color(red: 0.74, green: 0.80, blue: 1.0)
        case .steps, .plankSeconds, .sleepHours, .activeCalories, .distanceKilometers, .questCompletions:
            return GymTheme.beige
        }
    }
}
