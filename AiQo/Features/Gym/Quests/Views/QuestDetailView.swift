import SwiftUI
import UIKit
import Combine

struct QuestDetailView: View {
    let quest: QuestDefinition
    @ObservedObject var engine: QuestEngine

    @Environment(\.dismiss) private var dismiss

    @State private var showCameraPermission = false
    @State private var showPushupChallenge = false
    @State private var showWaterEntry = false
    @State private var showWorkoutEntry = false
    @State private var showShareSheet = false
    @State private var healthMessage: String?

    @State private var timerNow = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let progress = engine.getProgress(for: quest)
        let cardProgress = engine.cardProgress(for: quest)

        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerBlock(progress: cardProgress)

                    progressBlock(progress: progress, cardProgress: cardProgress)

                    if quest.source == .healthkit {
                        healthBlock
                    }

                    if quest.source == .timer, progress.isStarted {
                        timerBlock
                    }

                    ctaButton(progress: progress)

                    if let healthMessage {
                        Text(healthMessage)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(LocalizedStringKey("quests.detail.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showCameraPermission) {
            QuestCameraPermissionGateView {
                engine.startQuestSession(questId: quest.id)
                showPushupChallenge = true
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showPushupChallenge) {
            QuestPushupChallengeView(
                quest: quest,
                onComplete: { reps, accuracy in
                    engine.finishQuestSession(
                        questId: quest.id,
                        sessionResult: .cameraFinished(reps: reps, accuracy: accuracy)
                    )
                },
                onCancel: {
                    engine.cancelQuestSession(questId: quest.id)
                }
            )
        }
        .sheet(isPresented: $showWaterEntry) {
            QuestWaterEntrySheet { liters in
                Task {
                    await engine.logWaterAndApply(questId: quest.id, liters: liters)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWorkoutEntry) {
            QuestWorkoutEntrySheet(
                quickOptions: quest.id == "s1q4" ? [20, 30, 40] : []
            ) { minutes in
                engine.finishQuestSession(questId: quest.id, sessionResult: .workoutLogged(minutes: minutes))
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSheet) {
            QuestShareSheet(
                items: [
                    String(
                        format: questLocalizedText("quests.share.message.format"),
                        locale: questAppLocale(),
                        questLocalizedText(quest.localizedTitleKey)
                    ),
                    String(
                        format: questLocalizedText("quests.share.stage_quest.format"),
                        locale: questAppLocale(),
                        quest.stageIndex,
                        quest.questIndex
                    )
                ]
            ) {
                engine.finishQuestSession(questId: quest.id, sessionResult: .shared)
            }
        }
        .onReceive(timer) { value in
            timerNow = value
        }
        .onDisappear {
            timerNow = Date()
        }
        .task(id: quest.id) {
            guard quest.source == .healthkit else { return }
            await engine.refreshNow(reason: .manualPull)
            if quest.id == "s1q3", engine.isHealthAuthorized, !engine.hasSleepDataInOvernightWindow {
                healthMessage = questLocalizedText("gym.quest.noSleepData")
            }
        }
    }

    private func headerBlock(progress: QuestCardProgressModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(questLocalizedText(quest.localizedTitleKey))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary)

            Text(questLevelsText(for: quest))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.secondary)

            Text(
                String(
                    format: questLocalizedText("quests.common.tier_format"),
                    locale: questAppLocale(),
                    progress.tier
                )
            )
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
        }
    }

    private func progressBlock(progress: QuestProgressRecord, cardProgress: QuestCardProgressModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(questLocalizedText("gym.quest.progress"))
                .font(.system(size: 17, weight: .bold, design: .rounded))

            Text(progressSummaryText(for: cardProgress))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()

            ProgressView(value: min(cardProgress.completionFraction, 1))
                .tint(Color(red: 0.31, green: 0.42, blue: 0.97))
                .scaleEffect(y: 1.4)

            if progress.isStarted {
                Text(questLocalizedText("gym.quest.sessionRunning"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.10, green: 0.35, blue: 0.90))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
                )
        )
    }

    private var healthBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(questLocalizedText("quests.detail.healthkit_title"))
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Text(questLocalizedText("quests.detail.healthkit_description"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            if quest.id == "s1q3", engine.isHealthAuthorized, !engine.hasSleepDataInOvernightWindow {
                Text(questLocalizedText("gym.quest.noSleepData"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Button(questLocalizedText("gym.quest.openSettings")) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
        }
    }

    private var timerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(questLocalizedText("gym.quest.sessionTime"))
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Text(formattedElapsed())
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
    }

    private func ctaButton(progress: QuestProgressRecord) -> some View {
        let isCompleted = isActionCompleted(progress: progress)
        return Button(action: { handleCTA(progress: progress) }) {
            Text(ctaTitle(progress: progress))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(isCompleted ? Color.secondary : Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red: 0.98, green: 0.86, blue: 0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(isCompleted)
        .opacity(isCompleted ? 0.82 : 1)
    }

    private func ctaTitle(progress: QuestProgressRecord) -> String {
        switch quest.source {
        case .manual:
            return isActionCompleted(progress: progress) ? questLocalizedText("gym.quest.done") : questLocalizedText("gym.quest.confirmAchievement")
        case .water:
            return questLocalizedText("gym.quest.openWaterEntry")
        case .healthkit:
            return engine.isHealthAuthorized ? questLocalizedText("gym.quest.refresh") : questLocalizedText("gym.quest.linkHealthKit")
        case .timer:
            return progress.isStarted ? questLocalizedText("gym.quest.endSession") : questLocalizedText("gym.quest.startSession")
        case .camera:
            return progress.isStarted ? questLocalizedText("gym.quest.endSession") : questLocalizedText("gym.quest.startPushupChallenge")
        case .workout:
            return questLocalizedText("gym.quest.logCardioSession")
        case .social:
            return questLocalizedText("gym.quest.logInteraction")
        case .kitchen:
            return isActionCompleted(progress: progress) ? questLocalizedText("gym.quest.done") : questLocalizedText("gym.quest.openKitchen")
        case .share:
            return questLocalizedText("gym.quest.shareAchievement")
        }
    }

    private func handleCTA(progress: QuestProgressRecord) {
        guard !isActionCompleted(progress: progress) else { return }

        switch quest.source {
        case .manual:
            engine.finishQuestSession(questId: quest.id, sessionResult: .manualConfirmed(count: 1))

        case .water:
            showWaterEntry = true

        case .healthkit:
            Task {
                let wasAuthorized = engine.isHealthAuthorized
                let granted: Bool
                if engine.isHealthAuthorized {
                    await engine.refreshNow(reason: .manualPull)
                    granted = true
                } else {
                    granted = await engine.requestHealthAuthorization()
                }

                await MainActor.run {
                    if granted {
                        if (quest.id == "s1q3" || quest.id == "s6q5"), !engine.hasSleepDataInOvernightWindow {
                            healthMessage = questLocalizedText("gym.quest.noSleepData")
                        } else {
                            healthMessage = wasAuthorized ? questLocalizedText("gym.quest.progressUpdated") : questLocalizedText("gym.quest.healthKitLinked")
                        }
                    } else {
                        healthMessage = questLocalizedText("gym.quest.healthKitDenied")
                    }
                }
            }

        case .timer:
            if progress.isStarted {
                let elapsed = engine.finishTimerSessionIfRunning(for: quest.id)
                engine.finishQuestSession(questId: quest.id, sessionResult: .timerFinished(seconds: elapsed))
            } else {
                engine.startQuestSession(questId: quest.id)
            }

        case .camera:
            if progress.isStarted {
                engine.cancelQuestSession(questId: quest.id)
            } else {
                showCameraPermission = true
            }

        case .workout:
            showWorkoutEntry = true

        case .social:
            engine.finishQuestSession(questId: quest.id, sessionResult: .socialInteraction(count: 1))
            if quest.deepLinkAction == .openArena {
                MainTabRouter.shared.navigate(to: .captain)
                dismiss()
            }

        case .kitchen:
            MainTabRouter.shared.openKitchen()
            dismiss()

        case .share:
            showShareSheet = true
        }
    }

    private func progressSummaryText(for cardProgress: QuestCardProgressModel) -> String {
        questProgressText(for: quest, progress: cardProgress)
    }

    private func formattedElapsed() -> String {
        guard let start = engine.activeTimerSessionStart(for: quest.id) else {
            return "00:00"
        }

        let seconds = Int(max(0, timerNow.timeIntervalSince(start)))
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }

    private func isActionCompleted(progress: QuestProgressRecord) -> Bool {
        quest.isStageOneBooleanQuest && progress.isCompleted
    }
}

struct StageOneQuestSheet: View {
    let quest: QuestDefinition
    @ObservedObject var engine: QuestEngine

    @Environment(\.dismiss) private var dismiss

    @State private var showWaterEntry = false
    @State private var showWorkoutEntry = false
    @State private var healthMessage: String?
    @State private var currentTime = Date()
    @State private var isSleepRefreshLoading = false
    @State private var showHealthSetupAlert = false
    @State private var healthSetupAlertMessage = ""

    private let minuteTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let progress = engine.getProgress(for: quest)
        let cardProgress = engine.cardProgress(for: quest)
        let isSleepQuest = quest.id == "s1q3"
        let hasSleepData = engine.hasSleepDataInOvernightWindow

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(questLocalizedText(quest.localizedTitleKey))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary)

                Text(questStageOneSourceBadgeText(for: quest))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.82))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(uiColor: .tertiarySystemFill), in: Capsule())

                sectionTitle(questLocalizedText("gym.quest.challenge"))
                Text(content.explanation)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.9))

                sectionTitle(questLocalizedText("gym.quest.benefit"))
                bulletList(content.benefits)

                sectionTitle(questLocalizedText("gym.quest.howToComplete"))
                bulletList(content.howTo)

                HStack(spacing: 8) {
                    Text(questLocalizedText("gym.quest.currentCenter"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)

                    Text(questStageOneCenterPillText(for: cardProgress))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                }

                Text(questProgressText(for: quest, progress: cardProgress))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.76))
                    .monospacedDigit()

                if let nextTarget = questStageOneNextTargetText(for: quest, progress: cardProgress) {
                    Text(nextTarget)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary)
                }

                if let context = questStageOneContextText(for: quest, now: currentTime) {
                    Text(context)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.9))
                        .lineLimit(isSleepQuest ? 1 : nil)
                }

                if isSleepQuest, !hasSleepData {
                    sleepDataSetupCard
                }

                if let healthMessage {
                    Text(healthMessage)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Button(action: { handleCTA(progress: progress) }) {
                    HStack(spacing: 8) {
                        if isSleepQuest, isSleepRefreshLoading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.black.opacity(0.9))
                        }

                        Text(ctaTitle(progress: progress))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(isBooleanQuestCompleted(progress: progress) ? Color.secondary : Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        Color(red: 0.98, green: 0.86, blue: 0.45),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .disabled(isBooleanQuestCompleted(progress: progress) || isSleepRefreshLoading)
                .opacity((isBooleanQuestCompleted(progress: progress) || isSleepRefreshLoading) ? 0.82 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .background(Color.clear)
        .sheet(isPresented: $showWaterEntry) {
            QuestWaterEntrySheet { liters in
                Task {
                    await engine.logWaterAndApply(questId: quest.id, liters: liters)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWorkoutEntry) {
            QuestWorkoutEntrySheet(quickOptions: [20, 30, 40]) { minutes in
                engine.finishQuestSession(questId: quest.id, sessionResult: .workoutLogged(minutes: minutes))
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .task(id: quest.id) {
            guard quest.id == "s1q3" else { return }
            await engine.refreshNow(reason: .manualPull)
            await MainActor.run {
                healthMessage = nil
            }
        }
        .onReceive(minuteTicker) { value in
            currentTime = value
        }
        .alert(questLocalizedText("gym.quest.cantOpenHealth"), isPresented: $showHealthSetupAlert) {
            Button(questLocalizedText("gym.quest.ok"), role: .cancel) {}
        } message: {
            Text(healthSetupAlertMessage)
        }
    }

    private var content: StageOneSheetContent {
        switch quest.id {
        case "s1q1":
            return .init(
                explanation: questLocalizedText("gym.quest.s1q1.explanation"),
                benefits: [
                    questLocalizedText("gym.quest.s1q1.benefit1"),
                    questLocalizedText("gym.quest.s1q1.benefit2"),
                    questLocalizedText("gym.quest.s1q1.benefit3")
                ],
                howTo: [
                    questLocalizedText("gym.quest.s1q1.howTo1"),
                    questLocalizedText("gym.quest.s1q1.howTo2"),
                    questLocalizedText("gym.quest.s1q1.howTo3")
                ]
            )
        case "s1q2":
            return .init(
                explanation: questLocalizedText("gym.quest.s1q2.explanation"),
                benefits: [
                    questLocalizedText("gym.quest.s1q2.benefit1"),
                    questLocalizedText("gym.quest.s1q2.benefit2"),
                    questLocalizedText("gym.quest.s1q2.benefit3")
                ],
                howTo: [
                    questLocalizedText("gym.quest.s1q2.howTo1"),
                    questLocalizedText("gym.quest.s1q2.howTo2"),
                    questLocalizedText("gym.quest.s1q2.howTo3")
                ]
            )
        case "s1q3":
            return .init(
                explanation: questLocalizedText("gym.quest.s1q3.explanation"),
                benefits: [
                    questLocalizedText("gym.quest.s1q3.benefit1"),
                    questLocalizedText("gym.quest.s1q3.benefit2"),
                    questLocalizedText("gym.quest.s1q3.benefit3")
                ],
                howTo: [
                    questLocalizedText("gym.quest.s1q3.howTo1"),
                    questLocalizedText("gym.quest.s1q3.howTo2"),
                    questLocalizedText("gym.quest.s1q3.howTo3")
                ]
            )
        case "s1q4":
            return .init(
                explanation: questLocalizedText("gym.quest.s1q4.explanation"),
                benefits: [
                    questLocalizedText("gym.quest.s1q4.benefit1"),
                    questLocalizedText("gym.quest.s1q4.benefit2"),
                    questLocalizedText("gym.quest.s1q4.benefit3")
                ],
                howTo: [
                    questLocalizedText("gym.quest.s1q4.howTo1"),
                    questLocalizedText("gym.quest.s1q4.howTo2"),
                    questLocalizedText("gym.quest.s1q4.howTo3")
                ]
            )
        case "s1q5":
            return .init(
                explanation: questLocalizedText("gym.quest.s1q5.explanation"),
                benefits: [
                    questLocalizedText("gym.quest.s1q5.benefit1"),
                    questLocalizedText("gym.quest.s1q5.benefit2"),
                    questLocalizedText("gym.quest.s1q5.benefit3")
                ],
                howTo: [
                    questLocalizedText("gym.quest.s1q5.howTo1"),
                    questLocalizedText("gym.quest.s1q5.howTo2"),
                    questLocalizedText("gym.quest.s1q5.howTo3")
                ]
            )
        default:
            return .init(
                explanation: "",
                benefits: [],
                howTo: []
            )
        }
    }

    @ViewBuilder
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Color.primary)
    }

    @ViewBuilder
    private func bulletList(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.76))
                    Text(line)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func ctaTitle(progress: QuestProgressRecord) -> String {
        switch quest.id {
        case "s1q1":
            return isBooleanQuestCompleted(progress: progress) ? questLocalizedText("gym.quest.done") : questLocalizedText("gym.quest.confirmAchievement")
        case "s1q2":
            return questLocalizedText("gym.quest.openWaterEntry")
        case "s1q3":
            return engine.isHealthAuthorized ? questLocalizedText("gym.quest.refresh") : questLocalizedText("gym.quest.linkHealthKit")
        case "s1q4":
            return questLocalizedText("gym.quest.logCardioSession")
        case "s1q5":
            return isBooleanQuestCompleted(progress: progress) ? questLocalizedText("gym.quest.done") : questLocalizedText("gym.quest.openKitchen")
        default:
            return questLocalizedText("gym.quest.refresh")
        }
    }

    private func handleCTA(progress: QuestProgressRecord) {
        guard !isBooleanQuestCompleted(progress: progress) else { return }

        switch quest.id {
        case "s1q1":
            engine.finishQuestSession(questId: quest.id, sessionResult: .manualConfirmed(count: 1))
        case "s1q2":
            showWaterEntry = true
        case "s1q3":
            Task {
                let wasAuthorized = engine.isHealthAuthorized
                await MainActor.run {
                    isSleepRefreshLoading = true
                    healthMessage = nil
                }

                var granted = engine.isHealthAuthorized
                if !engine.isHealthAuthorized {
                    granted = await engine.requestHealthAuthorization()
                }
                await MainActor.run {
                    if !granted {
                        healthMessage = questLocalizedText("gym.quest.healthKitDenied")
                    }
                }

                if granted {
                    await engine.refreshNow(reason: .manualPull)
                    await MainActor.run {
                        // Single source of truth: engine.hasSleepDataInOvernightWindow
                        if engine.hasSleepDataInOvernightWindow {
                            healthMessage = wasAuthorized ? questLocalizedText("gym.quest.progressUpdated") : questLocalizedText("gym.quest.healthKitLinked")
                        } else {
                            healthMessage = nil
                        }
                    }
                }

                await MainActor.run {
                    isSleepRefreshLoading = false
                }
            }
        case "s1q4":
            showWorkoutEntry = true
        case "s1q5":
            MainTabRouter.shared.openKitchen()
            dismiss()
        default:
            break
        }
    }

    private func isBooleanQuestCompleted(progress: QuestProgressRecord) -> Bool {
        quest.isStageOneBooleanQuest && progress.isCompleted
    }

    @ViewBuilder
    private var sleepDataSetupCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(questLocalizedText("gym.quest.noSleepData"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.82))

            Text(questLocalizedText("gym.quest.noSleepQuestion"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)

            VStack(alignment: .leading, spacing: 5) {
                Text(questLocalizedText("gym.quest.sleepStep1"))
                Text(questLocalizedText("gym.quest.sleepStep2"))
                Text(questLocalizedText("gym.quest.sleepStep3"))
                Text(questLocalizedText("gym.quest.sleepStep4"))
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.primary.opacity(0.84))
            .fixedSize(horizontal: false, vertical: true)

            Button(action: openAppleHealthApp) {
                Text(questLocalizedText("gym.quest.openHealthApp"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Color(red: 0.98, green: 0.86, blue: 0.45),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
            .buttonStyle(.plain)

            Button(action: { openAppSettings(showAlertOnFailure: true) }) {
                Text(questLocalizedText("gym.quest.openSettings"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .underline()
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(uiColor: .separator).opacity(0.28), lineWidth: 1)
                )
        )
    }

    private func openAppleHealthApp() {
        let healthURLStrings = [
            "x-apple-health://",
            "x-apple-health://summary",
            "x-apple-health://browse"
        ]
        openHealthURL(from: healthURLStrings, index: 0)
    }

    private func openHealthURL(from candidates: [String], index: Int) {
        guard candidates.indices.contains(index), let url = URL(string: candidates[index]) else {
            openAppSettings(showAlertOnFailure: true)
            return
        }

        UIApplication.shared.open(url, options: [:]) { opened in
            if !opened {
                openHealthURL(from: candidates, index: index + 1)
            }
        }
    }

    private func openAppSettings(showAlertOnFailure: Bool) {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            if showAlertOnFailure {
                presentHealthSetupAlert()
            }
            return
        }

        UIApplication.shared.open(settingsURL, options: [:]) { opened in
            if !opened, showAlertOnFailure {
                presentHealthSetupAlert()
            }
        }
    }

    private func presentHealthSetupAlert() {
        healthSetupAlertMessage = questLocalizedText("gym.quest.openHealthManual")
        showHealthSetupAlert = true
    }
}

private struct StageOneSheetContent {
    let explanation: String
    let benefits: [String]
    let howTo: [String]
}

private struct QuestWaterEntrySheet: View {
    let onAddWater: (Double) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text(questLocalizedText("gym.quest.waterEntry"))
                .font(.system(size: 24, weight: .heavy, design: .rounded))

            Text(questLocalizedText("gym.quest.waterAdd"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Button(questLocalizedText("gym.quest.waterButton")) {
                onAddWater(0.25)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.blue)
        }
        .padding(20)
    }
}

private struct QuestWorkoutEntrySheet: View {
    let quickOptions: [Double]
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var minutes: Double = 20

    var body: some View {
        VStack(spacing: 16) {
            Text(questLocalizedText("gym.quest.logSession"))
                .font(.system(size: 24, weight: .heavy, design: .rounded))

            if !quickOptions.isEmpty {
                HStack(spacing: 10) {
                    ForEach(quickOptions, id: \.self) { option in
                        Button("\(Int(option))\(questLocalizedText("gym.quest.minuteUnit"))") {
                            minutes = option
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Stepper(String(format: questLocalizedText("gym.quest.minuteLabel"), Int(minutes)), value: $minutes, in: 5...180, step: 5)
                .font(.system(size: 17, weight: .bold, design: .rounded))

            Button(questLocalizedText("gym.quest.save")) {
                onSave(minutes)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }
}

private struct QuestShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                onComplete()
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
