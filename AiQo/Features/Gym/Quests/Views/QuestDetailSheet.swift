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

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let progress = engine.getProgress(for: quest)
        let cardProgress = engine.cardProgress(for: quest)

        ScrollView(showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 20) {

                // Badge image — centered, large
                Image(quest.rewardImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
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
            }
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
        case "s1q2":
            return localizedContent(prefix: "gym.quest.s1q2")
        case "s1q3":
            return localizedContent(prefix: "gym.quest.s1q3")
        case "s1q4":
            return localizedContent(prefix: "gym.quest.s1q4")
        case "s1q5":
            return localizedContent(prefix: "gym.quest.s1q5")
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
