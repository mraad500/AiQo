import SwiftUI
import AVFoundation
internal import Combine

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
                Text(quest.title)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "1A1A1A"))

                // Source badge
                Text(sourceText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "666666"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color(hex: "F5F5F5"))
                    )

                // التحدي section
                VStack(alignment: .trailing, spacing: 8) {
                    Text("التحدي")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "1A1A1A"))

                    Text(content.explanation)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(hex: "444444"))
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(6)
                }

                // الفائدة section
                VStack(alignment: .trailing, spacing: 8) {
                    Text("الفائدة")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "1A1A1A"))

                    ForEach(content.benefits, id: \.self) { benefit in
                        HStack(spacing: 8) {
                            Text(benefit)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color(hex: "444444"))
                                .multilineTextAlignment(.trailing)

                            Circle()
                                .fill(Color(hex: "B7E5D2"))
                                .frame(width: 6, height: 6)
                        }
                    }
                }

                // شلون تنجزه section
                VStack(alignment: .trailing, spacing: 8) {
                    Text("شلون تنجزه؟")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "1A1A1A"))

                    ForEach(Array(content.howTo.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: 8) {
                            Text(step)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color(hex: "444444"))
                                .multilineTextAlignment(.trailing)

                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
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

                        Text("مركزك الحالي")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                    }

                    Text(questProgressText(for: quest, progress: cardProgress))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "1A1A1A"))
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
        .alert("لا يمكن الوصول للكاميرا", isPresented: $cameraPermissionDenied) {
            Button("افتح الإعدادات") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("التطبيق يحتاج إذن الكاميرا لإكمال هذا التحدي. افتح الإعدادات وفعّل الكاميرا.")
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
                        format: L10n.t("quests.share.message.format"),
                        locale: Locale.current,
                        quest.title
                    ),
                    String(
                        format: L10n.t("quests.share.stage_quest.format"),
                        locale: Locale.current,
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
        .alert("تعذّر فتح تطبيق الصحة", isPresented: $showHealthSetupAlert) {
            Button("حسنًا", role: .cancel) {}
        } message: {
            Text(healthSetupAlertMessage)
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private func actionButton(progress: QuestProgressRecord, cardProgress: QuestCardProgressModel) -> some View {
        let isCompleted = quest.isStageOneBooleanQuest ? progress.isCompleted : (progress.currentTier >= 3)

        if isCompleted {
            // Already completed
            HStack(spacing: 8) {
                Text("تم الإنجاز")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "B7E5D2"))
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
                // HealthKit: auto-tracking UI
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(Color(hex: "B7E5D2"))
                        Text("يتتبع تلقائياً من Apple Health")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "666666"))
                    }

                    // Progress bar
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
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .monospacedDigit()

                    if !engine.isHealthAuthorized {
                        Button(action: { handleHealthKitCTA(progress: progress) }) {
                            Text("اربط هيلث كِت")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "1A1A1A"))
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
                                Text("تحديث")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(Color(hex: "1A1A1A"))
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
                // Camera button
                Button(action: { handleCameraCTA(progress: progress) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                        Text(progress.isStarted ? "انهاء" : "افتح الكاميرا")
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "EBCF97"))
                    )
                }

            case .water:
                Button(action: { showWaterEntry = true }) {
                    Text("فتح إدخال الماء")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "EBCF97"))
                        )
                }

            case .timer:
                Button(action: { handleTimerCTA(progress: progress) }) {
                    Text(progress.isStarted ? "انهاء الجلسة" : "ابدأ الجلسة")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "EBCF97"))
                        )
                }

            case .workout:
                Button(action: { showWorkoutEntry = true }) {
                    Text("سجل جلسة كارديو")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "EBCF97"))
                        )
                }

            case .social:
                Button(action: { handleSocialCTA() }) {
                    Text("سجّل تفاعل")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "EBCF97"))
                        )
                }

            case .kitchen:
                Button(action: { handleKitchenCTA(progress: progress) }) {
                    Text(quest.isStageOneBooleanQuest && progress.isCompleted ? "تم" : "فتح المطبخ")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
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
                    Text("مشاركة الإنجاز")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "EBCF97"))
                        )
                }

            case .manual:
                Button(action: { handleManualCTA(progress: progress) }) {
                    Text("أكد الإنجاز")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
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
            Text("زمن الجلسة")
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
                        healthMessage = wasAuthorized ? "تم تحديث التقدم." : "تم ربط هيلث كِت وتحديث التقدم."
                    }
                }
            } else {
                await MainActor.run {
                    healthMessage = "تم رفض صلاحية هيلث كيت. يمكنك تفعيلها من الإعدادات."
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
        MainTabRouter.shared.navigate(to: .kitchen)
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
        if quest.stageIndex == 1 {
            return questStageOneSourceBadgeText(for: quest)
        }

        switch quest.source {
        case .healthkit:
            return "المصدر: Apple Health"
        case .camera:
            return "المصدر: كاميرا الرؤية"
        case .water:
            return "المصدر: إدخال الماء"
        case .timer:
            return "المصدر: مؤقت الجلسة"
        case .workout:
            return "المصدر: سجل الكارديو"
        case .manual:
            return "المصدر: تأكيد المستخدم"
        case .social:
            return "المصدر: الساحة"
        case .kitchen:
            return "المصدر: المطبخ"
        case .share:
            return "المصدر: مشاركة"
        }
    }

    private func statusText(progress: QuestProgressRecord) -> String {
        if quest.isStageOneBooleanQuest {
            return progress.isCompleted ? "مكتمل" : "غير مكتمل"
        }
        return progress.currentTier >= 3 ? "مكتمل" : "غير مكتمل"
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
        // Stage 1
        case "s1q1":
            return .init(
                explanation: "مهمة بداية لمرة واحدة: فعل خير بسيط يوقّفك على نية واضحة ويشغّل الاستيقاظ من الداخل.",
                benefits: [
                    "يرفع صفاء النفس ويخفف ضغط اليوم.",
                    "يقوّي النية والانضباط السلوكي من أول مرحلة.",
                    "يبني توازنًا داخليًا ينعكس على قراراتك."
                ],
                howTo: [
                    "اختَر مساعدة واحدة مباشرة اليوم.",
                    "أكمل الفعل فعليًا بدون تأجيل.",
                    "ارجع واضغط \"أكد الإنجاز\"."
                ]
            )
        case "s1q2":
            return .init(
                explanation: "مهمة يومية لترطيب جسمك اليوم بنفس اليوم، وترقيتك تكون حسب مركزك من 3 إلى 1.",
                benefits: [
                    "ترطيب أفضل يعني طاقة وثبات أعلى خلال اليوم.",
                    "يدعم التركيز وصفاء الذهن في الشغل والتمرين.",
                    "يحسن نضارة الجلد وأداء الجسم العام."
                ],
                howTo: [
                    "قسّم شرب الماء على فترات بدل دفعة واحدة.",
                    "سجّل كل كمية تشربها من زر الإدخال.",
                    "استهدف 2.0ل ثم ارفعها إلى 2.5ل ثم 3.0ل."
                ]
            )
        case "s1q3":
            return .init(
                explanation: "مهمة نوم يومية من نافذة الليل الماضية، وتقييمها بالمراكز حسب عدد ساعات النوم.",
                benefits: [
                    "يسرّع التعافي العضلي والعصبي.",
                    "يساعد توازن الهرمونات وتنظيم الشهية.",
                    "يرفع التركيز وجودة الأداء الذهني."
                ],
                howTo: [
                    "اربط Apple Health حتى يقرأ ساعات النوم تلقائيًا.",
                    "استهدف 7.0س ثم 7.5س ثم 8.0س.",
                    "استخدم زر \"تحديث\" بعد الاستيقاظ."
                ]
            )
        case "s1q4":
            return .init(
                explanation: "مهمة تراكمية لزون 2 داخل المرحلة 1، وكل ما زادت الدقائق يرتفع مركزك حتى المركز 1.",
                benefits: [
                    "يعزّز حرق الدهون بكفاءة على المدى الطويل.",
                    "يقوي القلب والتحمل بدون إجهاد مفرط.",
                    "يدعم الهدوء العصبي وتنظيم التوتر."
                ],
                howTo: [
                    "سجّل جلسات زون 2 بشكل منتظم.",
                    "ابدأ بـ 20د ثم ارفعها إلى 30د ثم 40د.",
                    "حدّث الدقائق من زر تسجيل الجلسة."
                ]
            )
        case "s1q5":
            return .init(
                explanation: "مهمة تأسيس لمرة واحدة: حفظ خطة المطبخ يثبت نظامك الغذائي من البداية.",
                benefits: [
                    "يثبّت السلوك اليومي ويقلل العشوائية.",
                    "يعطيك تحكمًا أفضل في اختيارات الأكل.",
                    "يقلل تعب القرارات اليومية حول الوجبات."
                ],
                howTo: [
                    "افتح شاشة المطبخ من الزر.",
                    "أنشئ/احفظ خطة وجباتك.",
                    "تكتمل المهمة تلقائيًا بعد حفظ الخطة."
                ]
            )

        // Stage 2
        case "s2q1":
            return .init(
                explanation: "تحدي كاميرا لقياس دقة أداء الضغط عبر الرؤية الحاسوبية.",
                benefits: [
                    "يبني قوة الجزء العلوي من الجسم.",
                    "يحسن دقة الأداء والتحكم الحركي.",
                    "يعزز الثقة بالنفس من خلال التقدم المرئي."
                ],
                howTo: [
                    "افتح الكاميرا من الزر.",
                    "أدِّ تمارين الضغط أمام الكاميرا.",
                    "حقق العدد المطلوب بالدقة المحددة."
                ]
            )
        case "s2q2":
            return .init(
                explanation: "مهمة يومية لقطع مسافة معينة مشياً أو جرياً.",
                benefits: [
                    "يحسن صحة القلب والأوعية الدموية.",
                    "يعزز حرق السعرات الحرارية.",
                    "يرفع مستوى الطاقة والنشاط اليومي."
                ],
                howTo: [
                    "امشِ أو اجرِ خلال يومك.",
                    "تتبع المسافة تلقائياً من Apple Health.",
                    "استهدف 3كم ثم 5كم ثم 6كم."
                ]
            )
        case "s2q3":
            return .init(
                explanation: "تحدي تراكمي لزيادة وقت البلانك تدريجياً.",
                benefits: [
                    "يقوي عضلات الجذع والبطن.",
                    "يحسن الثبات والتوازن.",
                    "يدعم صحة الظهر والعمود الفقري."
                ],
                howTo: [
                    "ابدأ المؤقت عند بدء البلانك.",
                    "حافظ على الوضعية الصحيحة.",
                    "أوقف المؤقت عند الانتهاء."
                ]
            )
        case "s2q4":
            return .init(
                explanation: "جلسة امتنان يومية لتعزيز الصحة النفسية.",
                benefits: [
                    "يقلل التوتر والقلق.",
                    "يحسن جودة النوم.",
                    "يعزز الشعور بالرضا والسعادة."
                ],
                howTo: [
                    "ابدأ جلسة الامتنان من المؤقت.",
                    "تأمل فيما أنت ممتن له.",
                    "استهدف 2د ثم 3د ثم 5د."
                ]
            )
        case "s2q5":
            return .init(
                explanation: "سلسلة يومية لشرب الماء بانتظام.",
                benefits: [
                    "يبني عادة ترطيب مستدامة.",
                    "يحسن الأداء البدني والذهني.",
                    "يعزز الانضباط اليومي."
                ],
                howTo: [
                    "اشرب الحد الأدنى من الماء يومياً.",
                    "سجّل الكمية كل يوم.",
                    "حافظ على السلسلة بدون انقطاع."
                ]
            )

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
            Text("إدخال الماء")
                .font(.system(size: 24, weight: .heavy, design: .rounded))

            Text("أضف 0.25 لتر الآن لتحديث المهمة فوراً")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Button("+0.25ل") {
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
            Text("سجّل جلسة")
                .font(.system(size: 24, weight: .heavy, design: .rounded))

            if !quickOptions.isEmpty {
                HStack(spacing: 10) {
                    ForEach(quickOptions, id: \.self) { option in
                        Button("\(Int(option))د") {
                            minutes = option
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Stepper("\(Int(minutes)) دقيقة", value: $minutes, in: 5...180, step: 5)
                .font(.system(size: 17, weight: .bold, design: .rounded))

            Button("حفظ") {
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
