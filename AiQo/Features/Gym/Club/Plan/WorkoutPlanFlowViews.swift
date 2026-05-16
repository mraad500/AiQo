import SwiftData
import SwiftUI

// MARK: - Plan Dashboard

struct WorkoutPlanDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var globalBrain: CaptainViewModel

    @State private var todayRecord: AiQoDailyRecord?
    @State private var weeklyDays: [DayProgress] = []
    @State private var historyPlans: [WorkoutPlanDailySnapshot] = []
    @State private var weeklyStats: PlanWeeklyStats?
    @State private var detailExercise: Exercise?
    @State private var showRunner: Bool = false
    @State private var runnerPlan: WorkoutPlan?
    @State private var pendingTemplate: WorkoutTemplate?
    @State private var pinError: String?

    private var language: AppLanguage { AppSettingsStore.shared.appLanguage }
    private var isArabic: Bool { language == .arabic }

    private var captainPlan: WorkoutPlan? {
        // When the current in-memory plan is multi-day, prefer it so the day
        // picker stays visible. Pinned-today reconstruction is a flat task list
        // that loses the day structure.
        if let inMemory = globalBrain.currentWorkoutPlan, inMemory.days?.isEmpty == false {
            return inMemory
        }
        if let pinned = pinnedPlanForToday() {
            return pinned
        }
        return globalBrain.currentWorkoutPlan
    }

    private var hasPinnedPlan: Bool { todayRecord?.workouts.isEmpty == false }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                heroSection

                // Primary content: the plan itself takes priority. If the
                // user has no plan yet, the empty-state card replaces it so
                // there is always one anchor card under the hero.
                if hasPinnedPlan, let captainPlan {
                    ActivePlanCard(
                        plan: captainPlan,
                        language: language,
                        completionByIndex: completionByIndex(),
                        onToggleCompletion: toggleCompletion(at:),
                        onTapExercise: { detailExercise = $0 },
                        onStartWorkout: { dayPlan in
                            runnerPlan = dayPlan
                            showRunner = true
                        },
                        onRefresh: refreshPlanWithCaptain,
                        onShare: sharePlan
                    )
                } else if captainPlan == nil {
                    emptyStateSection
                }

                // Secondary glanceable widgets: weekly calendar + stats.
                WeeklyProgressStrip(days: weeklyDays, language: language)

                if let weeklyStats, weeklyStats.totalSessions > 0 {
                    PlanWeeklyStatsHero(stats: weeklyStats, language: language)
                }

                // Quick alternatives.
                QuickStartTemplatesStrip(language: language) { template in
                    pendingTemplate = template
                }

                if !historyPlans.isEmpty {
                    historySection
                }

                // Footer: the compliance disclaimer is required by Apple
                // 5.1.1 for health-adjacent guidance. Keeping it at the end
                // — visible without crowding the primary content.
                HealthComplianceCard(compact: true)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .background(dashboardBackground.ignoresSafeArea())
        .navigationTitle(L10n.t("gym.plan.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reloadData)
        .onReceive(NotificationCenter.default.publisher(for: .aiqoWorkoutPlanSaved)) { _ in
            reloadData()
        }
        .sheet(item: $detailExercise) { exercise in
            ExerciseDetailSheet(exercise: exercise, language: language)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showRunner) {
            if let plan = runnerPlan ?? captainPlan {
                PlanWorkoutRunner(
                    plan: plan,
                    language: language,
                    onCompleteAll: markAllExercisesComplete
                )
            }
        }
        .alert(
            isArabic ? "ثبّت هاي الخطة؟" : "Pin this template?",
            isPresented: pendingTemplateBinding,
            presenting: pendingTemplate
        ) { template in
            Button(isArabic ? "ثبّت" : "Pin", role: .none) {
                pinTemplate(template)
            }
            Button(isArabic ? "إلغاء" : "Cancel", role: .cancel) {
                pendingTemplate = nil
            }
        } message: { template in
            Text(String(format: isArabic
                        ? "%@ — %d دقيقة، %d تمارين."
                        : "%@ — %d minutes, %d exercises.",
                        template.displayTitle(language: language),
                        template.durationMinutes,
                        template.exercisesAr.count))
        }
        .alert(isArabic ? "تعذر تثبيت الخطة" : "Couldn't pin plan", isPresented: pinErrorBinding) {
            Button(isArabic ? "حسناً" : "OK", role: .cancel) {
                pinError = nil
            }
        } message: {
            Text(pinError ?? "")
        }
    }

    private var pendingTemplateBinding: Binding<Bool> {
        Binding(
            get: { pendingTemplate != nil },
            set: { newValue in if !newValue { pendingTemplate = nil } }
        )
    }

    private var pinErrorBinding: Binding<Bool> {
        Binding(
            get: { pinError != nil },
            set: { newValue in if !newValue { pinError = nil } }
        )
    }

    // MARK: - Sections

    private var heroSection: some View {
        NavigationLink {
            CaptainPlanChatView()
        } label: {
            heroContent
        }
        .buttonStyle(.plain)
    }

    private var heroContent: some View {
        HStack(spacing: 14) {
            Image("Hammoudi5")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 150, alignment: .bottom)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 8) {
                if hasPinnedPlan {
                    Text(isArabic ? "خطّتك جاهزة 🎯" : "Your plan is ready 🎯")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(isArabic ? "افتح المحادثة لتعديل الخطة أو طلب وحدة جديدة" : "Open chat to refine or request a new plan")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.7))
                        .lineLimit(2)
                } else {
                    Text(L10n.t("gym.plan.createWithCaptain"))
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(isArabic ? "خطة شخصية بناءً على هدفك ومستواك" : "A personal plan built from your goal and level")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.7))
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Text(L10n.t("gym.plan.pressAndStart"))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.primary.opacity(0.78))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.42))
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 175)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: hasPinnedPlan
                                ? [PlanPalette.mint.opacity(0.55), PlanPalette.lemon.opacity(0.45)]
                                : [PlanPalette.mint.opacity(0.45), PlanPalette.sand.opacity(0.42)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
        )
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.t("gym.plan.dailyPlans"))
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(historyPlans.count)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous).fill(Color.white.opacity(0.5))
                    )
            }
            .padding(.top, 4)

            LazyVStack(spacing: 10) {
                ForEach(historyPlans) { snapshot in
                    historyRow(snapshot)
                }
            }
        }
    }

    private func historyRow(_ snapshot: WorkoutPlanDailySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(snapshot.formattedDate)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
                Text("\(snapshot.completedCount)/\(snapshot.workouts.count)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(snapshot.completedCount == snapshot.workouts.count
                                     ? PlanPalette.mintDeep
                                     : .primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(snapshot.completedCount == snapshot.workouts.count
                                  ? PlanPalette.mint.opacity(0.55)
                                  : PlanPalette.surfaceTint)
                    )
            }

            if let suggestion = snapshot.suggestion, !suggestion.isEmpty {
                Text(suggestion)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            ForEach(Array(snapshot.workouts.prefix(3).enumerated()), id: \.offset) { _, workout in
                HStack(spacing: 8) {
                    Image(systemName: workout.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(workout.isCompleted ? PlanPalette.mintDeep : .secondary)
                    Text(workout.title)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .strikethrough(workout.isCompleted, color: .secondary)
                        .lineLimit(1)
                }
            }

            if snapshot.workouts.count > 3 {
                Text(String(format: isArabic ? "+%d تمرين" : "+%d more", snapshot.workouts.count - 3))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(PlanPalette.hairline, lineWidth: 1)
                )
        )
    }

    private var emptyStateSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isArabic ? "شنو رح تنحصل" : "What you'll get")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(emptyStateFeatures, id: \.title) { feature in
                emptyFeatureRow(feature)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(PlanPalette.hairline, lineWidth: 1)
                )
        )
    }

    private func emptyFeatureRow(_ feature: EmptyFeature) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(feature.family.pastel.opacity(0.55))
                Image(systemName: feature.icon)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(feature.family.ink)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                Text(feature.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var emptyStateFeatures: [EmptyFeature] {
        if isArabic {
            return [
                EmptyFeature(
                    icon: "target",
                    title: "تخصيص ذكي",
                    subtitle: "خطّة بناءً على هدفك، مستواك، وقتك، ومعدّاتك",
                    family: .mint
                ),
                EmptyFeature(
                    icon: "list.bullet.rectangle.portrait.fill",
                    title: "تمارين واضحة بمجاميع وعدّات",
                    subtitle: "كل تمرين عليه شرح فورم، بدائل، وزمن تقريبي",
                    family: .sand
                ),
                EmptyFeature(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "تتبّع تقدّمك",
                    subtitle: "علم على التمارين المكتملة وتابع سلسلة أيامك",
                    family: .lavender
                ),
                EmptyFeature(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "محادثة عربية بلهجة عراقية",
                    subtitle: "كابتن حمّودي يفهمك ويرد عليك بأسلوب احترافي",
                    family: .lemon
                )
            ]
        }
        return [
            EmptyFeature(
                icon: "target",
                title: "Smart personalization",
                subtitle: "Plans built from your goal, level, time, and equipment",
                family: .mint
            ),
            EmptyFeature(
                icon: "list.bullet.rectangle.portrait.fill",
                title: "Clean exercises with sets & reps",
                subtitle: "Each move ships with form cues, alternatives, and pacing",
                family: .sand
            ),
            EmptyFeature(
                icon: "chart.line.uptrend.xyaxis",
                title: "Track your progress",
                subtitle: "Tick off completed work and grow a daily streak",
                family: .lavender
            ),
            EmptyFeature(
                icon: "bubble.left.and.bubble.right.fill",
                title: "Captain Hamoudi at your side",
                subtitle: "Refine the plan in plain language anytime",
                family: .lemon
            )
        ]
    }

    private var dashboardBackground: some View {
        LinearGradient(
            colors: [
                PlanPalette.mint.opacity(0.32),
                Color(.systemBackground),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Data loading & mutation

    private func reloadData() {
        let store = WorkoutPlanMemoryStore.self
        todayRecord = store.fetchTodayRecord(modelContext: modelContext)
        weeklyDays = store.fetchWeeklyProgress(modelContext: modelContext, language: language)
        historyPlans = store.fetchSavedPlans(modelContext: modelContext)
        weeklyStats = store.fetchWeeklyStats(modelContext: modelContext, language: language)
    }

    private func markAllExercisesComplete() {
        guard let record = todayRecord else { return }
        for task in record.workouts {
            task.isCompleted = true
        }
        try? modelContext.save()
        reloadData()
    }

    private func pinTemplate(_ template: WorkoutTemplate) {
        let plan = template.plan(language: language)
        do {
            try WorkoutPlanMemoryStore.savePlan(workoutPlan: plan, modelContext: modelContext)
            NotificationCenter.default.post(name: .aiqoWorkoutPlanSaved, object: nil)
            globalBrain.currentWorkoutPlan = plan
            pendingTemplate = nil
            reloadData()
        } catch {
            pinError = isArabic ? "تعذّر تثبيت القالب. حاول مرة ثانية." : "Couldn't pin the template. Try again."
        }
    }

    private func pinnedPlanForToday() -> WorkoutPlan? {
        guard let record = todayRecord, !record.workouts.isEmpty else { return nil }
        let exercises = record.workouts.compactMap { task -> Exercise? in
            ExerciseSerialization.parse(taskTitle: task.title)
        }
        guard !exercises.isEmpty else { return nil }
        let title = record.captainDailySuggestion.isEmpty
            ? (isArabic ? "خطة الكابتن" : "Captain's plan")
            : record.captainDailySuggestion
        return WorkoutPlan(title: title, exercises: exercises)
    }

    private func completionByIndex() -> [Int: Bool] {
        guard let record = todayRecord else { return [:] }
        var map: [Int: Bool] = [:]
        for (index, task) in record.workouts.enumerated() {
            map[index] = task.isCompleted
        }
        return map
    }

    private func toggleCompletion(at index: Int) {
        guard let record = todayRecord, index < record.workouts.count else { return }
        let task = record.workouts[index]
        task.isCompleted.toggle()
        try? modelContext.save()
        reloadData()
    }

    private func refreshPlanWithCaptain() {
        // Just reset the in-progress plan and let the user open chat to ask for a new one.
        globalBrain.currentWorkoutPlan = nil
    }

    private func sharePlan() {
        guard let plan = captainPlan else { return }
        let text = plan.shareableText(language: language)
        UIPasteboard.general.string = text
    }

    // MARK: - Empty feature data type

    private struct EmptyFeature {
        let icon: String
        let title: String
        let subtitle: String
        let family: PlanPalette.Family
    }
}

// MARK: - Captain Plan Chat View

struct CaptainPlanChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var globalBrain: CaptainViewModel

    @State private var isSavingPlan = false
    @State private var showSuccessState = false
    @State private var errorMessage: String?
    @State private var intakeSelection = PlanIntakeSelection()
    @State private var detailExercise: Exercise?
    @State private var showBodyPhotoConsent = false
    @FocusState private var inputFieldFocused: Bool

    private let chatBottomID = "captain-plan-chat-bottom"
    private var language: AppLanguage { AppSettingsStore.shared.appLanguage }
    private var isArabic: Bool { language == .arabic }
    private var hasUserMessages: Bool { globalBrain.messages.contains(where: \.isUser) }

    var body: some View {
        ZStack {
            chatBackground.ignoresSafeArea()

            if showIntakeChips {
                intakeScroll
            } else {
                conversationStack
            }
        }
        .navigationTitle(L10n.t("gym.plan.captainChat"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            inputBar
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 10)
                .background(Color.clear)
        }
        .task {
            bootstrapPlanChatIfNeeded()
        }
        .sheet(item: $detailExercise) { exercise in
            ExerciseDetailSheet(exercise: exercise, language: language)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBodyPhotoConsent) {
            BodyPhotoConsentSheet(onGranted: dispatchIntake)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    private var showIntakeChips: Bool {
        !hasUserMessages
            && globalBrain.currentWorkoutPlan == nil
            && !globalBrain.isLoading
    }

    // First-run: the intake form is the only content. It lives in its own
    // ScrollView so the tall card scrolls inside the safe area instead of
    // overflowing under the nav bar / status bar (the cluttered-overlap bug).
    private var intakeScroll: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                PlanIntakeChipsView(
                    selection: $intakeSelection,
                    language: language,
                    onSubmit: submitIntake
                )

                HealthComplianceCard(compact: true)

                if let errorMessage {
                    errorCard(errorMessage)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // Conversation mode: messages thread + plan refinement + pin.
    private var conversationStack: some View {
        VStack(spacing: 12) {
            messagesSection

            if let workoutPlan = globalBrain.currentWorkoutPlan {
                refinementChips(for: workoutPlan)
                pinPlanButton(for: workoutPlan)
            }

            HealthComplianceCard(compact: true)

            if showSuccessState {
                successCard
            }

            if let errorMessage {
                errorCard(errorMessage)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    // MARK: - Messages

    private var messagesSection: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(globalBrain.messages) { message in
                        messageRow(message)
                            .id(message.id)
                    }

                    if let workoutPlan = globalBrain.currentWorkoutPlan {
                        HStack {
                            PendingPlanPreviewCard(
                                plan: workoutPlan,
                                language: language,
                                onTapExercise: { detailExercise = $0 }
                            )
                            Spacer(minLength: 28)
                        }
                        .id("captain-plan-preview")
                    }

                    if globalBrain.isLoading {
                        typingIndicatorRow
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(chatBottomID)
                }
                .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 7)
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: globalBrain.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: globalBrain.isLoading) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: globalBrain.currentWorkoutPlan != nil) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 36) }

            Text(message.text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(message.isUser ? PlanPalette.mint.opacity(0.6) : PlanPalette.sand.opacity(0.5))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PlanPalette.hairline, lineWidth: 1)
                )

            if !message.isUser { Spacer(minLength: 36) }
        }
    }

    private var typingIndicatorRow: some View {
        HStack {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.t("gym.plan.captainTyping"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(PlanPalette.sand.opacity(0.5))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PlanPalette.hairline, lineWidth: 1)
            )

            Spacer(minLength: 36)
        }
    }

    // MARK: - Refinement chips

    private func refinementChips(for plan: WorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isArabic ? "صقّل الخطة بضغطة" : "Refine in a tap")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            FlowLayout(spacing: 7) {
                refinementChip(text: isArabic ? "اقصرها" : "Shorter") {
                    sendRefinement(isArabic
                                   ? "خلّيها أقصر، ركّز على الأساسيات بنفس الجودة."
                                   : "Make it shorter — keep the essentials at the same quality.")
                }
                refinementChip(text: isArabic ? "صعّبها" : "Harder") {
                    sendRefinement(isArabic
                                   ? "صعّبها شوية، زِد المجاميع أو شدّة التمارين."
                                   : "Push intensity up — add a set or harder variations.")
                }
                refinementChip(text: isArabic ? "سهّلها" : "Easier") {
                    sendRefinement(isArabic
                                   ? "خفّفها واعطني نسخة مبتدئ مع نفس الأهداف."
                                   : "Tone it down to a beginner-friendly version of the same plan.")
                }
                refinementChip(text: isArabic ? "بدائل" : "Swap moves") {
                    sendRefinement(isArabic
                                   ? "اقترح بدائل لكل تمرين بنفس الفعالية."
                                   : "Swap each exercise for an equivalent alternative.")
                }
                refinementChip(text: isArabic ? "بدون معدّات" : "No gear") {
                    sendRefinement(isArabic
                                   ? "اعطني نفس الخطة بس بدون أي معدّات (وزن جسم بس)."
                                   : "Same plan but bodyweight only — no equipment.")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(PlanPalette.hairline, lineWidth: 1)
                )
        )
    }

    private func refinementChip(text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .foregroundStyle(PlanPalette.mintDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(PlanPalette.mint.opacity(0.55))
                )
        }
        .buttonStyle(.plain)
        .disabled(globalBrain.isLoading || isSavingPlan)
    }

    // MARK: - Input bar / pin / cards

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(L10n.t("gym.plan.placeholder"), text: $globalBrain.inputText)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .focused($inputFieldFocused)
                .onSubmit { sendCurrentMessage() }

            Button {
                sendCurrentMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(PlanPalette.mintDeep)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(PlanPalette.mint)
                    )
            }
            .buttonStyle(.plain)
            .disabled(trimmedInput.isEmpty || isSavingPlan || globalBrain.isLoading)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PlanPalette.hairline, lineWidth: 1)
        )
    }

    private func pinPlanButton(for workoutPlan: WorkoutPlan) -> some View {
        Button {
            pinPlan(workoutPlan)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 14, weight: .heavy))
                Text(L10n.t("gym.plan.pinPlan"))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.black.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                PlanPalette.lemon,
                                PlanPalette.sand
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isSavingPlan)
        .opacity(isSavingPlan ? 0.6 : 1)
    }

    private var successCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .bold))
            Text(L10n.t("gym.plan.pinSuccess"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.green)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(PlanPalette.mint.opacity(0.55))
        )
    }

    private func errorCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.red)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(PlanPalette.sand.opacity(0.55))
            )
    }

    private var chatBackground: some View {
        LinearGradient(
            colors: [
                PlanPalette.mint.opacity(0.32),
                Color(.systemBackground),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Actions

    private func submitIntake() {
        // Body photo path: dedicated consent gate (Apple 5.1.2(II)). If a
        // photo is attached but the user has not granted consent yet, present
        // the dedicated sheet and let the user re-confirm in `dispatchIntake`.
        if intakeSelection.hasBodyImage,
           !BodyPhotoConsent.shared.isGranted {
            showBodyPhotoConsent = true
            return
        }
        dispatchIntake()
    }

    private func dispatchIntake() {
        let composed = intakeSelection.composedMessage(language: language)
        showSuccessState = false
        errorMessage = nil

        // The image is consumed once — clear it from the intake state to
        // avoid re-sending on a refinement message.
        let image = intakeSelection.bodyImage
        intakeSelection.bodyImage = nil

        globalBrain.sendMessage(text: composed, image: image, context: .gym)
    }

    private func sendRefinement(_ text: String) {
        showSuccessState = false
        errorMessage = nil
        globalBrain.sendMessage(text, context: .gym)
    }

    private func sendCurrentMessage() {
        let message = trimmedInput
        guard !message.isEmpty else { return }
        showSuccessState = false
        errorMessage = nil
        globalBrain.sendMessage(message, context: .gym)
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        let action = { proxy.scrollTo(chatBottomID, anchor: .bottom) }
        if animated {
            withAnimation(.easeOut(duration: 0.22)) { action() }
        } else {
            action()
        }
    }

    private func pinPlan(_ workoutPlan: WorkoutPlan) {
        guard !isSavingPlan else { return }
        isSavingPlan = true
        errorMessage = nil

        do {
            try WorkoutPlanMemoryStore.savePlan(
                workoutPlan: workoutPlan,
                modelContext: modelContext
            )

            NotificationCenter.default.post(name: .aiqoWorkoutPlanSaved, object: nil)
            showSuccessState = true
            inputFieldFocused = false
            globalBrain.messages.append(
                ChatMessage(
                    text: String(format: L10n.t("gym.plan.pinConfirm"), workoutPlan.title),
                    isUser: false
                )
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                dismiss()
            }
        } catch {
            errorMessage = L10n.t("gym.plan.pinError")
        }

        isSavingPlan = false
    }

    private var trimmedInput: String {
        globalBrain.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func bootstrapPlanChatIfNeeded() {
        guard globalBrain.currentWorkoutPlan == nil else { return }
        guard !globalBrain.isLoading else { return }

        let kickoffPrompt = L10n.t("gym.plan.kickoff")
        guard !globalBrain.messages.contains(where: { $0.text == kickoffPrompt }) else { return }
        guard !hasUserMessages else { return }

        globalBrain.messages.append(
            ChatMessage(text: kickoffPrompt, isUser: false)
        )
    }
}

// MARK: - Snapshot used by the dashboard history list

struct WorkoutPlanDailySnapshot: Identifiable {
    let id: String
    let date: Date
    let suggestion: String?
    let workouts: [WorkoutPlanDailyWorkout]

    var formattedDate: String {
        WorkoutPlanMemoryStore.dateLabelFormatter.string(from: date)
    }

    var completedCount: Int {
        workouts.filter(\.isCompleted).count
    }
}

struct WorkoutPlanDailyWorkout: Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
}

// MARK: - Persistence helpers

enum WorkoutPlanMemoryStore {
    static let dateLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// Must be byte-for-byte identical to how `AiQoDailyRecord` stamps its
    /// own `id` — otherwise a record saved under one string can never be
    /// fetched again (the pinned-plan-disappears-after-relaunch bug).
    /// Both now share `AiQoDailyRecord.dayIDFormatter` (en_US_POSIX +
    /// Gregorian), so a save and a later fetch always agree.
    private static var recordIDFormatter: DateFormatter { AiQoDailyRecord.dayIDFormatter }

    static func savePlan(
        workoutPlan: WorkoutPlan,
        modelContext: ModelContext
    ) throws {
        let now = Date()
        let todayID = recordIDFormatter.string(from: now)

        let descriptor = FetchDescriptor<AiQoDailyRecord>(
            predicate: #Predicate { record in
                record.id == todayID
            }
        )

        let record: AiQoDailyRecord
        if let existing = try modelContext.fetch(descriptor).first {
            record = existing
        } else {
            let created = AiQoDailyRecord(date: now)
            modelContext.insert(created)
            record = created
        }

        for task in record.workouts {
            modelContext.delete(task)
        }
        record.workouts = []

        let workouts = workoutPlan.exercises.map { exercise in
            let workout = WorkoutTask(title: exercise.serializedTaskTitle, isCompleted: false)
            workout.dailyRecord = record
            modelContext.insert(workout)
            return workout
        }

        record.workouts = workouts
        record.captainDailySuggestion = workoutPlan.title

        try modelContext.save()
    }

    static func fetchTodayRecord(modelContext: ModelContext) -> AiQoDailyRecord? {
        let todayID = recordIDFormatter.string(from: Date())
        let descriptor = FetchDescriptor<AiQoDailyRecord>(
            predicate: #Predicate { record in record.id == todayID }
        )
        return try? modelContext.fetch(descriptor).first
    }

    static func fetchSavedPlans(modelContext: ModelContext) -> [WorkoutPlanDailySnapshot] {
        let descriptor = FetchDescriptor<AiQoDailyRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []

        return records
            .filter { !$0.workouts.isEmpty }
            .prefix(20)
            .map { record in
                WorkoutPlanDailySnapshot(
                    id: record.id,
                    date: record.date,
                    suggestion: record.captainDailySuggestion.isEmpty ? nil : record.captainDailySuggestion,
                    workouts: record.workouts.map { task in
                        WorkoutPlanDailyWorkout(
                            id: task.id,
                            title: ExerciseSerialization.displayTitle(taskTitle: task.title),
                            isCompleted: task.isCompleted
                        )
                    }
                )
            }
    }

    static func fetchWeeklyProgress(modelContext: ModelContext, language: AppLanguage) -> [DayProgress] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == .arabic ? "ar" : "en")
        formatter.dateFormat = "EEE"

        // Week starts on Saturday for Arabic locale, Sunday for default — we'll show
        // the trailing 7 days ending today either way to keep the strip honest.
        let descriptor = FetchDescriptor<AiQoDailyRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []

        var byID: [String: AiQoDailyRecord] = [:]
        for record in records {
            byID[record.id] = record
        }

        let isoFormatter = recordIDFormatter
        var days: [DayProgress] = []
        // Show trailing 7 days, oldest → newest, ending today.
        for offset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let id = isoFormatter.string(from: date)
            let isToday = calendar.isDate(date, inSameDayAs: today)
            let isUpcoming = false // we never show future days here

            let label = formatter.string(from: date)

            if let record = byID[id], !record.workouts.isEmpty {
                let total = record.workouts.count
                let done = record.workouts.filter(\.isCompleted).count
                let ratio = Double(done) / Double(total)
                days.append(
                    DayProgress(
                        id: id,
                        shortLabel: label,
                        date: date,
                        completionRatio: ratio,
                        isToday: isToday,
                        isUpcoming: isUpcoming
                    )
                )
            } else {
                days.append(
                    DayProgress(
                        id: id,
                        shortLabel: label,
                        date: date,
                        completionRatio: 0,
                        isToday: isToday,
                        isUpcoming: isUpcoming
                    )
                )
            }
        }
        return days
    }
}

// MARK: - Exercise serialization (round-trip via WorkoutTask.title)

enum ExerciseSerialization {
    /// Format used to persist plan exercises into `WorkoutTask.title`. The leading
    /// magic prefix lets us round-trip the structured fields when we re-render the
    /// pinned plan later. Falls back to a human-readable string if the prefix is
    /// missing (legacy data).
    private static let magic = "AIQEX1"
    private static let separator = "‖"

    static func displayTitle(taskTitle: String) -> String {
        if let exercise = parse(taskTitle: taskTitle) {
            return "\(exercise.name) — \(exercise.sets) × \(exercise.repsOrDuration)"
        }
        return taskTitle
    }

    static func parse(taskTitle: String) -> Exercise? {
        guard taskTitle.hasPrefix(magic + separator) else {
            return parseLegacyTitle(taskTitle)
        }
        let body = String(taskTitle.dropFirst((magic + separator).count))
        let parts = body.components(separatedBy: separator)
        guard parts.count == 3 else { return parseLegacyTitle(taskTitle) }
        let name = parts[0]
        let sets = Int(parts[1]) ?? 1
        let reps = parts[2]
        guard !name.isEmpty, sets > 0, !reps.isEmpty else { return nil }
        return Exercise(name: name, sets: sets, repsOrDuration: reps)
    }

    static func encode(exercise: Exercise) -> String {
        "\(magic)\(separator)\(exercise.name)\(separator)\(exercise.sets)\(separator)\(exercise.repsOrDuration)"
    }

    /// Best-effort parsing for legacy `name - X sets - reps/duration` strings.
    private static func parseLegacyTitle(_ title: String) -> Exercise? {
        let separators = [" - ", " — ", " – "]
        var working = title
        for sep in separators {
            let parts = working.components(separatedBy: sep)
            if parts.count == 3 {
                let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                // middle part is "N sets" or "N مجاميع/جولات"
                let middle = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let digits = middle.compactMap { $0.isNumber ? $0 : nil }
                let setsValue = Int(String(digits)) ?? 0
                let reps = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty, setsValue > 0, !reps.isEmpty {
                    return Exercise(name: name, sets: setsValue, repsOrDuration: reps)
                }
            }
            working = title
        }
        return nil
    }
}

private extension Exercise {
    var serializedTaskTitle: String { ExerciseSerialization.encode(exercise: self) }
}

extension WorkoutPlan {
    func shareableText(language: AppLanguage) -> String {
        let isArabic = language == .arabic
        var lines: [String] = []
        lines.append("🎯 \(title)")

        if let weeks = durationWeeks, weeks > 0 {
            lines.append(isArabic ? "📅 المدة: \(weeks) أسبوع" : "📅 Length: \(weeks) week\(weeks == 1 ? "" : "s")")
        }

        if let days = days, !days.isEmpty {
            for day in days {
                lines.append("")
                lines.append("— \(day.name)")
                if let focus = day.focus, !focus.isEmpty {
                    lines.append("  \(focus)")
                }
                for (index, exercise) in day.exercises.enumerated() {
                    lines.append("\(index + 1). \(exercise.name) — \(exercise.sets) × \(exercise.repsOrDuration)")
                }
            }
        } else {
            for (index, exercise) in exercises.enumerated() {
                lines.append("\(index + 1). \(exercise.name) — \(exercise.sets) × \(exercise.repsOrDuration)")
            }
        }

        lines.append("")
        lines.append(isArabic ? "— خطة من كابتن حمّودي على AiQo" : "— Plan by Captain Hamoudi on AiQo")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Notification

extension Notification.Name {
    static let aiqoWorkoutPlanSaved = Notification.Name("aiqo.workout.plan.saved")
}
