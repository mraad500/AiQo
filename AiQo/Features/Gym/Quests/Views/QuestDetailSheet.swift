import SwiftUI
import AVFoundation
import Combine

struct QuestDetailSheet: View {
    let quest: QuestDefinition
    @ObservedObject var engine: QuestEngine
    let onComplete: (QuestDefinition) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var cameraPermissionDenied = false
    @State private var showCameraPermission = false
    @State private var showPushupChallenge = false
    @State private var showWaterEntry = false
    @State private var showWorkoutEntry = false
    @State private var showShareSheet = false
    @State private var healthMessage: String?
    @State private var isSleepRefreshLoading = false
    @State private var showHealthSetupAlert = false
    @State private var healthSetupAlertMessage = ""
    @State private var timerNow = Date()
    @State private var showLearningProof = false
    @State private var showLearningOptions = false

    @ObservedObject private var learningProofStore = LearningProofStore.shared

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let progress = engine.getProgress(for: quest)
        let cardProgress = engine.cardProgress(for: quest)

        ScrollView(showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 20) {

                // Badge image — centered, large
                QuestRewardImageView(quest: quest, size: 100)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                // Quest name
                Text(questLocalizedText(quest.localizedTitleKey))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "1A1A1A"))

                // Source badge
                Text(sourceText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "666666"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color(hex: "F5F5F5"))
                    )

                // XP reward hint — shown only when the quest has a product-decided
                // XP value in `QuestXPRewards`. Positioned between the source badge
                // and the "Challenge" section so the user sees the reward up front.
                if let xp = QuestXPRewards.xp(for: quest) {
                    rewardXPPill(xp: xp)
                }

                // Challenge section
                VStack(alignment: .trailing, spacing: 8) {
                    Text(questLocalizedText("gym.quest.challenge"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "1A1A1A"))

                    Text(content.explanation)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color(hex: "444444"))
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(6)
                }

                // Benefit section
                VStack(alignment: .trailing, spacing: 8) {
                    Text(questLocalizedText("gym.quest.benefit"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "1A1A1A"))

                    ForEach(content.benefits, id: \.self) { benefit in
                        HStack(spacing: 8) {
                            Text(benefit)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(hex: "444444"))
                                .multilineTextAlignment(.trailing)

                            Circle()
                                .fill(Color(hex: "B7E5D2"))
                                .frame(width: 6, height: 6)
                        }
                    }
                }

                // How to complete section
                VStack(alignment: .trailing, spacing: 8) {
                    Text(questLocalizedText("gym.quest.howToComplete"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "1A1A1A"))

                    ForEach(Array(content.howTo.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: 8) {
                            Text(step)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(hex: "444444"))
                                .multilineTextAlignment(.trailing)

                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Color(hex: "EBCF97")))
                        }
                    }
                }

                // Current progress
                VStack(alignment: .trailing, spacing: 8) {
                    HStack {
                        Text(statusText(progress: progress))
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(
                                    progress.currentTier >= 3
                                        ? Color(hex: "B7E5D2").opacity(0.3)
                                        : Color(hex: "F5F5F5")
                                )
                            )

                        Spacer()

                        Text(questLocalizedText("gym.quest.currentProgress"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "1A1A1A"))
                    }

                    Text(questProgressText(for: quest, progress: cardProgress))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                        .monospacedDigit()
                }

                if quest.source == .timer, progress.isStarted {
                    timerBlock
                }

                if let healthMessage {
                    Text(healthMessage)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 20)

                // Action button
                actionButton(progress: progress, cardProgress: cardProgress)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
        .alert(questLocalizedText("quests.vision.camera.denied.title"), isPresented: $cameraPermissionDenied) {
            Button(questLocalizedText("quests.vision.camera.open_settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(questLocalizedText("gym.quest.cancel"), role: .cancel) {}
        } message: {
            Text(questLocalizedText("quests.vision.camera.denied.message"))
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
                    onComplete(quest)
                },
                onCancel: {
                    engine.cancelQuestSession(questId: quest.id)
                }
            )
        }
        .sheet(isPresented: $showWaterEntry) {
            QuestWaterEntrySheetInternal { liters in
                Task {
                    await engine.logWaterAndApply(questId: quest.id, liters: liters)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWorkoutEntry) {
            QuestWorkoutEntrySheetInternal(
                quickOptions: quest.metricAKey == .zone2Minutes ? [20, 30, 40] : []
            ) { minutes in
                engine.finishQuestSession(questId: quest.id, sessionResult: .workoutLogged(minutes: minutes))
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSheet) {
            QuestShareSheetInternal(
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
                onComplete(quest)
            }
        }
        .onReceive(timer) { value in
            timerNow = value
        }
        .task(id: quest.id) {
            guard quest.source == .healthkit else { return }
            await engine.refreshNow(reason: .manualPull)
        }
        .alert(questLocalizedText("gym.quest.cantOpenHealth"), isPresented: $showHealthSetupAlert) {
            Button(questLocalizedText("gym.quest.ok"), role: .cancel) {}
        } message: {
            Text(healthSetupAlertMessage)
        }
    }

    // MARK: - Reward XP Pill

    /// Sand-toned capsule that makes the XP reward explicit before the user reads the
    /// challenge details. Matches the celebration-sheet XP pill visual so the user
    /// sees a consistent "this much XP" token both before and after completion.
    @ViewBuilder
    private func rewardXPPill(xp: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
            Text(String(
                format: questLocalizedText("gym.quest.detail.reward_xp.format"),
                locale: questAppLocale(),
                xp
            ))
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .monospacedDigit()
        }
        .foregroundStyle(Color(hex: "6B5B2E"))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color(hex: "F5E4B4")))
        .overlay(Capsule().stroke(Color(hex: "EBCF97"), lineWidth: 0.8))
    }

    // MARK: - Action Button

    @ViewBuilder
    private func actionButton(progress: QuestProgressRecord, cardProgress: QuestCardProgressModel) -> some View {
        let isCompleted = quest.isStageOneBooleanQuest ? progress.isCompleted : (progress.currentTier >= 3)

        if isCompleted {
            HStack(spacing: 8) {
                Text(questCompletionStatusText(isCompleted: true))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: "1A1A1A"))
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "B7E5D2"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "B7E5D2").opacity(0.3))
            )
        } else {
            switch quest.source {
            case .healthkit:
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Color(hex: "B7E5D2"))
                        Text(questLocalizedText("gym.quest.autoTrackingAppleHealth"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "666666"))
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: "F5F5F5"))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: "B7E5D2"))
                                .frame(width: geo.size.width * min(cardProgress.completionFraction, 1), height: 8)
                        }
                    }
                    .frame(height: 8)

                    Text(questProgressText(for: quest, progress: cardProgress))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                        .monospacedDigit()

                    if !engine.isHealthAuthorized {
                        Button(action: { handleHealthKitCTA(progress: progress) }) {
                            Text(questLocalizedText("gym.quest.linkHealthKit"))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "1A1A1A"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(hex: "EBCF97"))
                                )
                        }
                    } else {
                        Button(action: { handleHealthKitCTA(progress: progress) }) {
                            HStack(spacing: 6) {
                                if isSleepRefreshLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.black.opacity(0.9))
                                }
                                Text(questLocalizedText("gym.quest.refresh"))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(Color(hex: "1A1A1A"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(hex: "EBCF97").opacity(0.6))
                            )
                        }
                        .disabled(isSleepRefreshLoading)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "B7E5D2").opacity(0.15))
                )

            case .camera:
                Button(action: { handleCameraCTA(progress: progress) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                        Text(progress.isStarted ? questLocalizedText("gym.quest.endSession") : questLocalizedText("gym.camera.startChallenge"))
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: "1A1A1A"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "EBCF97"))
                    )
                }

            case .water:
                Button(action: { showWaterEntry = true }) {
                    Text(questLocalizedText("gym.quest.openWaterEntry"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "EBCF97"))
                        )
                }

            case .timer:
                Button(action: { handleTimerCTA(progress: progress) }) {
                    Text(progress.isStarted ? questLocalizedText("gym.quest.endSession") : questLocalizedText("gym.quest.startSession"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "EBCF97"))
                        )
                }

            case .workout:
                Button(action: { showWorkoutEntry = true }) {
                    Text(questLocalizedText("gym.quest.logCardioSession"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "EBCF97"))
                        )
                }

            case .social:
                Button(action: { handleSocialCTA() }) {
                    Text(questLocalizedText("gym.quest.logInteraction"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "EBCF97"))
                        )
                }

            case .kitchen:
                Button(action: { handleKitchenCTA(progress: progress) }) {
                    Text(
                        quest.isStageOneBooleanQuest && progress.isCompleted
                            ? questLocalizedText("gym.quest.done")
                            : questLocalizedText("gym.quest.openKitchen")
                    )
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "EBCF97"))
                        )
                }
                .disabled(quest.isStageOneBooleanQuest && progress.isCompleted)

            case .share:
                Button(action: { showShareSheet = true }) {
                    Text(questLocalizedText("gym.quest.shareAchievement"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "EBCF97"))
                        )
                }

            case .manual:
                Button(action: { handleManualCTA(progress: progress) }) {
                    Text(questLocalizedText("gym.quest.confirmAchievement"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "EBCF97"))
                        )
                }

            case .learning:
                learningActionStack(progress: progress)
            }
        }
    }

    // MARK: - Learning Action Stack

    @ViewBuilder
    private func learningActionStack(progress: QuestProgressRecord) -> some View {
        let config = LearningChallengeRegistry.config(for: quest.id)
        let record = learningProofStore.record(for: quest.id)
        let selectedOption = config.option(withId: record.selectedCourseOptionId)
        let status = record.lastResult.status

        VStack(spacing: 10) {
            // State A — no course selected: show only "استعرض الكورسات".
            if selectedOption == nil {
                exploreCoursesButton
            }

            // State B/C/D/E — a course is selected; layout depends on status.
            if let selectedOption {
                selectedCoursePill(option: selectedOption)

                switch status {
                case .pending:
                    // State C — verification in progress.
                    verifyingPill
                case .verified:
                    // State E — handled by the surrounding `isCompleted` branch which
                    // renders the common "Completed" card. We still expose the success
                    // Captain message to let the user read it.
                    if let message = record.lastResult.notes {
                        captainMessageCard(text: message, tint: Color(hex: "B7E5D2"))
                    }
                case .needsReview:
                    // State D — needs review. Retry button re-runs the verifier using
                    // the already-uploaded image stored on disk.
                    needsReviewRow(record: record, option: selectedOption)
                case .rejected, .notSubmitted:
                    // State B — ready to submit proof. Also re-entry from a rejection.
                    submitProofButton
                    if status == .rejected, let reason = record.lastResult.rejectionReason {
                        Text(reason)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: "B24545"))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: status)
        .animation(.easeInOut(duration: 0.25), value: record.selectedCourseOptionId)
        .sheet(isPresented: $showLearningOptions) {
            LearningCourseOptionsSheet(
                quest: quest,
                config: config,
                proofStore: learningProofStore
            )
        }
        .sheet(isPresented: $showLearningProof) {
            if let option = selectedOption {
                LearningProofSubmissionView(
                    quest: quest,
                    option: option,
                    onVerified: {
                        engine.finishQuestSession(
                            questId: quest.id,
                            sessionResult: .manualConfirmed(count: 1)
                        )
                        onComplete(quest)
                    },
                    proofStore: learningProofStore
                )
            }
        }
    }

    // MARK: - Learning Sub-Views (5 states)

    /// State A — nothing selected. Single primary CTA opens the internal options sheet.
    private var exploreCoursesButton: some View {
        Button(action: { showLearningOptions = true }) {
            HStack(spacing: 8) {
                Image(systemName: "book.closed.fill")
                Text(questLocalizedText("gym.quest.learning.exploreCourses"))
            }
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: "1A1A1A"))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "EBCF97"))
            )
        }
    }

    /// Pill showing the currently selected course + a "تغيير" link to re-open the
    /// options sheet. Always rendered on States B/C/D/E.
    @ViewBuilder
    private func selectedCoursePill(option: LearningCourseOption) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: "1A1A1A"))
            Text(option.title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "1A1A1A"))
                .lineLimit(1)
            Spacer()
            Button(action: { showLearningOptions = true }) {
                Text(questLocalizedText("gym.quest.learning.change"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "1A1A1A").opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "F5F5F5"))
        )
    }

    /// State B — ready to submit proof.
    private var submitProofButton: some View {
        Button(action: { showLearningProof = true }) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                Text(questLocalizedText("gym.quest.learning.submitProof"))
            }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: "1A1A1A"))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "B7E5D2"))
            )
        }
    }

    /// State C — verification in progress. Disabled pill.
    private var verifyingPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "1A1A1A"))
            Text(questLocalizedText("gym.quest.learning.verifying"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "1A1A1A"))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "FDE2A7").opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "1A1A1A").opacity(0.08), lineWidth: 0.6)
        )
    }

    /// State D — needs review; retry button re-runs verify() using the stored image.
    @ViewBuilder
    private func needsReviewRow(record: LearningProofRecord, option: LearningCourseOption) -> some View {
        if let message = record.lastResult.notes {
            captainMessageCard(text: message, tint: Color(hex: "FDE2A7"))
        }

        Button(action: {
            retryLearningVerification(record: record, option: option)
        }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                Text(questLocalizedText("gym.quest.learning.proof.retryVerification"))
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: "1A1A1A"))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "EBCF97"))
            )
        }
    }

    /// Small Captain-voiced message card. Used for State D/E + post-rejection copy.
    @ViewBuilder
    private func captainMessageCard(text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "1A1A1A"))
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "1A1A1A"))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.35))
        )
    }

    /// Re-runs the on-device verifier using the already-stored certificate image,
    /// without forcing the user back into the submission sheet. Useful after an iOS
    /// upgrade that newly exposes Apple Intelligence.
    private func retryLearningVerification(record: LearningProofRecord, option: LearningCourseOption) {
        guard let image = learningProofStore.loadCertificateImage(record.certificateImageRelativePath) else {
            showLearningProof = true
            return
        }

        var pending = record
        pending.lastResult = LearningProofVerificationResult(
            status: .pending,
            confidence: nil,
            extractedName: nil,
            extractedCourseTitle: nil,
            extractedProvider: nil,
            extractedCertificateURL: record.certificateURL,
            rejectionReason: nil,
            notes: nil
        )
        learningProofStore.updateRecord(pending)

        let firstName = Self.resolveFirstName()
        Task {
            let verdict = await CertificateVerifier.shared.verify(
                image: image,
                course: option.course,
                userFirstName: firstName,
                questId: quest.id
            )
            await MainActor.run {
                applyRetryVerdict(verdict, questId: quest.id, certificateURL: record.certificateURL ?? "")
            }
        }
    }

    private func applyRetryVerdict(_ verdict: CertificateVerifier.Result, questId: String, certificateURL: String) {
        switch verdict {
        case let .verified(confidence, message):
            let result = LearningProofVerificationResult(
                status: .verified,
                confidence: confidence,
                extractedName: nil,
                extractedCourseTitle: nil,
                extractedProvider: nil,
                extractedCertificateURL: certificateURL,
                rejectionReason: nil,
                notes: message
            )
            learningProofStore.applyVerificationResult(questId: questId, result: result)
            engine.finishQuestSession(
                questId: questId,
                sessionResult: .manualConfirmed(count: 1)
            )
            onComplete(quest)
        case let .needsReview(reason, message):
            let result = LearningProofVerificationResult(
                status: .needsReview,
                confidence: nil,
                extractedName: nil,
                extractedCourseTitle: nil,
                extractedProvider: nil,
                extractedCertificateURL: certificateURL,
                rejectionReason: reason,
                notes: message
            )
            learningProofStore.applyVerificationResult(questId: questId, result: result)
        case let .rejected(reason, message):
            let result = LearningProofVerificationResult(
                status: .rejected,
                confidence: nil,
                extractedName: nil,
                extractedCourseTitle: nil,
                extractedProvider: nil,
                extractedCertificateURL: certificateURL,
                rejectionReason: reason,
                notes: message
            )
            learningProofStore.applyVerificationResult(questId: questId, result: result)
        }
    }

    private static func resolveFirstName() -> String {
        let profile = UserProfileStore.shared.current
        let trimmed = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return String(trimmed.split(separator: " ").first ?? Substring(trimmed))
        }
        let username = (profile.username ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return String(username.split(separator: " ").first ?? Substring(username))
    }

    @ViewBuilder
    private func learningStatusRow(status: LearningProofVerificationStatus) -> some View {
        HStack {
            Spacer()
            Text(learningStatusText(status))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(learningStatusTint(status)))
                .foregroundStyle(Color(hex: "1A1A1A"))
        }
    }

    private func learningStatusText(_ status: LearningProofVerificationStatus) -> String {
        switch status {
        case .notSubmitted:
            return questLocalizedText("gym.quest.learning.status.notSubmitted")
        case .pending:
            return questLocalizedText("gym.quest.learning.status.pending")
        case .verified:
            return questLocalizedText("gym.quest.learning.status.verified")
        case .rejected:
            return questLocalizedText("gym.quest.learning.status.rejected")
        case .needsReview:
            return questLocalizedText("gym.quest.learning.status.needsReview")
        }
    }

    private func learningStatusTint(_ status: LearningProofVerificationStatus) -> Color {
        switch status {
        case .notSubmitted: return Color(hex: "F5F5F5")
        case .pending: return Color(hex: "FDE2A7").opacity(0.9)
        case .verified: return Color(hex: "B7E5D2")
        case .rejected: return Color(hex: "F7C7C7")
        case .needsReview: return Color(hex: "F6C77A").opacity(0.9)
        }
    }

    // MARK: - Timer Block

    private var timerBlock: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text(questLocalizedText("gym.quest.sessionTime"))
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Text(formattedElapsed())
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
    }

    // MARK: - CTA Handlers

    private func handleManualCTA(progress: QuestProgressRecord) {
        guard !(quest.isStageOneBooleanQuest && progress.isCompleted) else { return }
        engine.finishQuestSession(questId: quest.id, sessionResult: .manualConfirmed(count: 1))
        onComplete(quest)
    }

    private func handleCameraCTA(progress: QuestProgressRecord) {
        if progress.isStarted {
            engine.cancelQuestSession(questId: quest.id)
        } else {
            requestCameraAndProceed()
        }
    }

    private func handleTimerCTA(progress: QuestProgressRecord) {
        if progress.isStarted {
            let elapsed = engine.finishTimerSessionIfRunning(for: quest.id)
            engine.finishQuestSession(questId: quest.id, sessionResult: .timerFinished(seconds: elapsed))
        } else {
            engine.startQuestSession(questId: quest.id)
        }
    }

    private func handleHealthKitCTA(progress: QuestProgressRecord) {
        Task {
            let wasAuthorized = engine.isHealthAuthorized
            await MainActor.run {
                isSleepRefreshLoading = true
                healthMessage = nil
            }

            var granted = engine.isHealthAuthorized
            if !granted {
                granted = await engine.requestHealthAuthorization()
            }

            if granted {
                await engine.refreshNow(reason: .manualPull)
                await MainActor.run {
                    if quest.metricAKey == .sleepHours, !engine.hasSleepDataInOvernightWindow {
                        healthMessage = nil
                    } else {
                        healthMessage = wasAuthorized
                            ? questLocalizedText("gym.quest.progressUpdated")
                            : questLocalizedText("gym.quest.healthKitLinked")
                    }
                }
            } else {
                await MainActor.run {
                    healthMessage = questLocalizedText("gym.quest.healthKitDenied")
                }
            }

            await MainActor.run {
                isSleepRefreshLoading = false
            }
        }
    }

    private func handleSocialCTA() {
        engine.finishQuestSession(questId: quest.id, sessionResult: .socialInteraction(count: 1))
        if quest.deepLinkAction == .openArena {
            MainTabRouter.shared.navigate(to: .captain)
            dismiss()
        }
    }

    private func handleKitchenCTA(progress: QuestProgressRecord) {
        guard !(quest.isStageOneBooleanQuest && progress.isCompleted) else { return }
        MainTabRouter.shared.openKitchen()
        dismiss()
    }

    // MARK: - Camera Permission

    private func requestCameraAndProceed() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCameraPermission = true

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCameraPermission = true
                    } else {
                        cameraPermissionDenied = true
                    }
                }
            }

        case .denied, .restricted:
            cameraPermissionDenied = true

        @unknown default:
            cameraPermissionDenied = true
        }
    }

    // MARK: - Helpers

    private var sourceText: String {
        questSourceBadgeText(for: quest)
    }

    private func statusText(progress: QuestProgressRecord) -> String {
        let isCompleted = quest.isStageOneBooleanQuest ? progress.isCompleted : (progress.currentTier >= 3)
        return questCompletionStatusText(isCompleted: isCompleted)
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

    // MARK: - Content

    private var content: QuestSheetContent {
        QuestSheetContentProvider.content(for: quest)
    }
}

// MARK: - Quest Sheet Content

struct QuestSheetContent {
    let explanation: String
    let benefits: [String]
    let howTo: [String]
}

enum QuestSheetContentProvider {
    static func content(for quest: QuestDefinition) -> QuestSheetContent {
        switch quest.id {
        case "s1q1":
            return localizedContent(prefix: "gym.quest.s1q1")
        case QuestDefinition.learningSparkQuestID,
             QuestDefinition.learningSparkStage2QuestID:
            // Stage 2 Learning Spark reuses Stage 1's explanation/benefits/howTo
            // strings — the thematic intent is identical (complete a course to
            // build the learning habit). Per approved design decision 2026-04-19.
            return localizedContent(prefix: "gym.quest.s1qLearn")
        case "s1q2":
            return localizedContent(prefix: "gym.quest.s1q2")
        case "s1q3":
            return localizedContent(prefix: "gym.quest.s1q3")
        case "s1q4":
            return localizedContent(prefix: "gym.quest.s1q4")
        case "s2q1":
            return localizedContent(prefix: "gym.quest.s2q1")
        case "s2q2":
            return localizedContent(prefix: "gym.quest.s2q2")
        case "s2q3":
            return localizedContent(prefix: "gym.quest.s2q3")
        case "s2q4":
            return localizedContent(prefix: "gym.quest.s2q4")
        case "s2q5":
            return localizedContent(prefix: "gym.quest.s2q5")

        // Stage 3
        case "s3q1":
            return .init(
                explanation: "تحقيق نسبة معينة من هدف الحركة اليومي.",
                benefits: [
                    "يحفز النشاط اليومي المنتظم.",
                    "يدعم إغلاق حلقة الحركة.",
                    "يعزز اللياقة البدنية العامة."
                ],
                howTo: [
                    "تتبع تلقائياً من Apple Health.",
                    "حافظ على نشاطك خلال اليوم.",
                    "استهدف 70% ثم 90% ثم 100%."
                ]
            )
        case "s3q2":
            return .init(
                explanation: "تحدي تراكمي لبناء قوة الضغط.",
                benefits: [
                    "يبني قوة الجزء العلوي.",
                    "يحسن التحمل العضلي.",
                    "يعزز الثقة بالأداء البدني."
                ],
                howTo: [
                    "أدِّ تمارين الضغط يومياً.",
                    "سجّل العدد بعد كل جلسة.",
                    "استهدف 20 ثم 40 ثم 50 تكرار."
                ]
            )
        case "s3q3":
            return .init(
                explanation: "تحدي تراكمي لتمارين زون 2 الهوائية.",
                benefits: [
                    "يعزز حرق الدهون بكفاءة.",
                    "يقوي القلب والتحمل.",
                    "يدعم التعافي والهدوء العصبي."
                ],
                howTo: [
                    "سجّل جلسات زون 2.",
                    "استهدف 30د ثم 45د ثم 60د.",
                    "حافظ على الانتظام."
                ]
            )
        case "s3q4":
            return .init(
                explanation: "سلسلة نوم يومية لتحقيق ساعات نوم كافية.",
                benefits: [
                    "يحسن جودة التعافي.",
                    "يعزز التركيز والأداء.",
                    "يدعم توازن الهرمونات."
                ],
                howTo: [
                    "نم 7 ساعات على الأقل.",
                    "تتبع تلقائياً من Apple Health.",
                    "حافظ على السلسلة."
                ]
            )
        case "s3q5":
            return .init(
                explanation: "مهمة أسبوعية لمساعدة شخصين.",
                benefits: [
                    "يعزز التواصل الإنساني.",
                    "يرفع صفاء النفس.",
                    "يبني عادة العطاء."
                ],
                howTo: [
                    "ساعد شخصين خلال الأسبوع.",
                    "أكد كل مساعدة.",
                    "استمر في بناء عادة الخير."
                ]
            )

        // Default for stages 4-10
        default:
            return defaultContent(for: quest)
        }
    }

    private static func localizedContent(prefix: String) -> QuestSheetContent {
        QuestSheetContent(
            explanation: questLocalizedText("\(prefix).explanation"),
            benefits: [
                questLocalizedText("\(prefix).benefit1"),
                questLocalizedText("\(prefix).benefit2"),
                questLocalizedText("\(prefix).benefit3")
            ],
            howTo: [
                questLocalizedText("\(prefix).howTo1"),
                questLocalizedText("\(prefix).howTo2"),
                questLocalizedText("\(prefix).howTo3")
            ]
        )
    }

    private static func defaultContent(for quest: QuestDefinition) -> QuestSheetContent {
        let explanation: String
        let benefits: [String]
        let howTo: [String]

        switch quest.source {
        case .healthkit:
            explanation = "مهمة تتبع تلقائياً من Apple Health حسب نشاطك اليومي."
            benefits = [
                "يحفز النشاط اليومي المنتظم.",
                "يدعم تحقيق أهدافك الصحية.",
                "يعزز اللياقة البدنية العامة."
            ]
            howTo = [
                "اربط Apple Health.",
                "حافظ على نشاطك اليومي.",
                "تحقق من تقدمك بانتظام."
            ]
        case .camera:
            explanation = "تحدي كاميرا يقيس دقة أدائك عبر الرؤية الحاسوبية."
            benefits = [
                "يبني القوة البدنية.",
                "يحسن دقة الأداء.",
                "يعزز التقدم المرئي."
            ]
            howTo = [
                "افتح الكاميرا من الزر.",
                "أدِّ التمرين أمام الكاميرا.",
                "حقق الهدف المطلوب."
            ]
        case .water:
            explanation = "مهمة ترطيب لبناء عادة شرب الماء بانتظام."
            benefits = [
                "يحسن الترطيب والطاقة.",
                "يدعم الأداء البدني والذهني.",
                "يعزز الانضباط اليومي."
            ]
            howTo = [
                "اشرب الحد المطلوب يومياً.",
                "سجّل الكمية من الزر.",
                "حافظ على الانتظام."
            ]
        case .timer:
            explanation = "تحدي مؤقت لبناء التحمل والصبر."
            benefits = [
                "يعزز التحمل والثبات.",
                "يحسن التركيز.",
                "يبني الانضباط الذاتي."
            ]
            howTo = [
                "ابدأ المؤقت من الزر.",
                "أكمل الجلسة.",
                "أوقف المؤقت عند الانتهاء."
            ]
        case .workout:
            explanation = "تحدي تمرين لتسجيل جلسات الكارديو."
            benefits = [
                "يقوي القلب والتحمل.",
                "يعزز حرق الدهون.",
                "يدعم اللياقة العامة."
            ]
            howTo = [
                "أدِّ جلسة كارديو.",
                "سجّل الدقائق من الزر.",
                "استهدف الهدف المطلوب."
            ]
        case .manual:
            explanation = "مهمة تأكيد يدوي لإنجاز محدد."
            benefits = [
                "يعزز الالتزام الشخصي.",
                "يبني عادات إيجابية.",
                "يرفع الحس بالمسؤولية."
            ]
            howTo = [
                "أكمل المهمة المطلوبة.",
                "ارجع للتطبيق.",
                "اضغط \"أكد الإنجاز\"."
            ]
        case .social:
            explanation = "مهمة تفاعل اجتماعي في الساحة."
            benefits = [
                "يعزز التواصل مع المجتمع.",
                "يبني علاقات إيجابية.",
                "يحفز المشاركة الفعالة."
            ]
            howTo = [
                "افتح الساحة.",
                "تفاعل مع الأعضاء.",
                "سجّل التفاعل."
            ]
        case .kitchen:
            explanation = "مهمة تأسيس المطبخ وتخطيط الوجبات."
            benefits = [
                "يثبّت النظام الغذائي.",
                "يقلل العشوائية في الأكل.",
                "يدعم الأهداف الصحية."
            ]
            howTo = [
                "افتح المطبخ.",
                "أنشئ خطة وجبات.",
                "احفظ الخطة."
            ]
        case .share:
            explanation = "مهمة مشاركة إنجاز داخل التطبيق."
            benefits = [
                "يحفز الآخرين.",
                "يعزز الفخر بالإنجاز.",
                "يبني مجتمع داعم."
            ]
            howTo = [
                "اختَر إنجازاً لمشاركته.",
                "اضغط زر المشاركة.",
                "شارك مع المجتمع."
            ]
        case .learning:
            explanation = questLocalizedText("gym.quest.s1qLearn.explanation")
            benefits = [
                questLocalizedText("gym.quest.s1qLearn.benefit1"),
                questLocalizedText("gym.quest.s1qLearn.benefit2"),
                questLocalizedText("gym.quest.s1qLearn.benefit3")
            ]
            howTo = [
                questLocalizedText("gym.quest.s1qLearn.howTo1"),
                questLocalizedText("gym.quest.s1qLearn.howTo2"),
                questLocalizedText("gym.quest.s1qLearn.howTo3")
            ]
        }

        return QuestSheetContent(explanation: explanation, benefits: benefits, howTo: howTo)
    }
}

// MARK: - Internal Sheet Views

private struct QuestWaterEntrySheetInternal: View {
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

private struct QuestWorkoutEntrySheetInternal: View {
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

            Stepper(
                String(
                    format: questLocalizedText("gym.quest.minuteLabel"),
                    locale: questAppLocale(),
                    Int(minutes)
                ),
                value: $minutes,
                in: 5...180,
                step: 5
            )
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

private struct QuestShareSheetInternal: UIViewControllerRepresentable {
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
