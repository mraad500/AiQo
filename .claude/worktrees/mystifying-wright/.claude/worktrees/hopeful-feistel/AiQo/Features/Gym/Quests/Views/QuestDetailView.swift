import SwiftUI
import UIKit
internal import Combine

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
                healthMessage = "لا توجد بيانات نوم في Apple Health"
            }
        }
    }

    private func headerBlock(progress: QuestCardProgressModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(quest.title)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary)

            Text(questLevelsText(for: quest))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.secondary)

            Text(
                String(
                    format: L10n.t("quests.common.tier_format"),
                    locale: Locale.current,
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
            Text("التقدم")
                .font(.system(size: 17, weight: .bold, design: .rounded))

            Text(progressSummaryText(for: cardProgress))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()

            ProgressView(value: min(cardProgress.completionFraction, 1))
                .tint(Color(red: 0.31, green: 0.42, blue: 0.97))
                .scaleEffect(y: 1.4)

            if progress.isStarted {
                Text("الحالة: الجلسة قيد التشغيل")
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
                Text("لا توجد بيانات نوم في Apple Health")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Button("فتح الإعدادات") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
        }
    }

    private var timerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("زمن الجلسة")
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
            return isActionCompleted(progress: progress) ? "تم" : "أكد الإنجاز"
        case .water:
            return "فتح إدخال الماء"
        case .healthkit:
            return engine.isHealthAuthorized ? "تحديث" : "اربط هيلث كِت"
        case .timer:
            return progress.isStarted ? "انهاء" : "ابدأ الجلسة"
        case .camera:
            return progress.isStarted ? "انهاء" : "ابدأ تحدي الشناوو"
        case .workout:
            return "سجل جلسة كارديو"
        case .social:
            return "سجّل تفاعل"
        case .kitchen:
            return isActionCompleted(progress: progress) ? "تم" : "فتح المطبخ"
        case .share:
            return "مشاركة الإنجاز"
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
                            healthMessage = "لا توجد بيانات نوم في Apple Health"
                        } else {
                            healthMessage = wasAuthorized ? "تم تحديث التقدم." : "تم ربط هيلث كيت وتحديث التقدم."
                        }
                    } else {
                        healthMessage = "تم رفض صلاحية هيلث كيت. يمكنك تفعيلها من الإعدادات."
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
            MainTabRouter.shared.navigate(to: .kitchen)
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
                Text(quest.title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary)

                Text(questStageOneSourceBadgeText(for: quest))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.82))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(uiColor: .tertiarySystemFill), in: Capsule())

                sectionTitle("التحدي")
                Text(content.explanation)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.9))

                sectionTitle("الفائدة")
                bulletList(content.benefits)

                sectionTitle("شلون تنجزه؟")
                bulletList(content.howTo)

                HStack(spacing: 8) {
                    Text("مركزك الحالي")
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
        .alert("تعذّر فتح تطبيق الصحة", isPresented: $showHealthSetupAlert) {
            Button("حسنًا", role: .cancel) {}
        } message: {
            Text(healthSetupAlertMessage)
        }
    }

    private var content: StageOneSheetContent {
        switch quest.id {
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
            return isBooleanQuestCompleted(progress: progress) ? "تم" : "أكد الإنجاز"
        case "s1q2":
            return "فتح إدخال الماء"
        case "s1q3":
            return engine.isHealthAuthorized ? "تحديث" : "اربط هيلث كِت"
        case "s1q4":
            return "سجّل جلسة كارديو"
        case "s1q5":
            return isBooleanQuestCompleted(progress: progress) ? "تم" : "فتح المطبخ"
        default:
            return "تحديث"
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
                        healthMessage = "تم رفض صلاحية هيلث كيت. يمكنك تفعيلها من الإعدادات."
                    }
                }

                if granted {
                    await engine.refreshNow(reason: .manualPull)
                    await MainActor.run {
                        // Single source of truth: engine.hasSleepDataInOvernightWindow
                        if engine.hasSleepDataInOvernightWindow {
                            healthMessage = wasAuthorized ? "تم تحديث التقدم." : "تم ربط هيلث كِت وتحديث التقدم."
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
            MainTabRouter.shared.navigate(to: .kitchen)
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
            Text("لا توجد بيانات نوم في Apple Health")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.82))

            Text("ماكو بيانات نوم؟")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)

            VStack(alignment: .leading, spacing: 5) {
                Text("1) افتح تطبيق الصحة (Apple Health)")
                Text("2) روح إلى Sleep / النوم")
                Text("3) فعّل Sleep Schedule أو تتبّع النوم")
                Text("4) إذا عندك Apple Watch، فعّل تتبّع النوم عليها")
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.primary.opacity(0.84))
            .fixedSize(horizontal: false, vertical: true)

            Button(action: openAppleHealthApp) {
                Text("افتح تطبيق الصحة")
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
                Text("فتح الإعدادات")
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
        healthSetupAlertMessage = "افتح Apple Health يدويًا من الجهاز، وفعّل بيانات النوم ثم ارجع واضغط تحديث."
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

private struct QuestWorkoutEntrySheet: View {
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
