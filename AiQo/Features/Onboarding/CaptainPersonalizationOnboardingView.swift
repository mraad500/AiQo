import SwiftUI
import UIKit
import UserNotifications

struct CaptainPersonalizationOnboardingView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var selectedGoal: CaptainPrimaryGoal?
    @State private var selectedSport: CaptainSportPreference?
    @State private var selectedWorkoutTime: CaptainWorkoutTimePreference?
    @State private var bedtime: Date
    @State private var wakeTime: Date
    @State private var currentStep: CaptainPersonalizationStep = .preferences
    @State private var appeared = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    @StateObject private var sleepViewModel: SmartWakeViewModel

    init() {
        let existing = CaptainPersonalizationStore.shared.currentSnapshot()
        let defaultBedtime = existing?.bedtime ?? Self.defaultTime(hour: 22, minute: 30)
        let defaultWake = existing?.wakeTime ?? Self.defaultTime(hour: 6, minute: 30)

        _selectedGoal = State(initialValue: existing?.primaryGoal)
        _selectedSport = State(initialValue: existing?.favoriteSport)
        _selectedWorkoutTime = State(initialValue: existing?.preferredWorkoutTime)
        _bedtime = State(initialValue: defaultBedtime)
        _wakeTime = State(initialValue: defaultWake)
        _sleepViewModel = StateObject(
            wrappedValue: SmartWakeViewModel(
                initialBedtime: defaultBedtime,
                initialLatestWakeTime: defaultWake,
                initialMode: .fromWakeTime
            )
        )
    }

    private var selectedRecommendation: SmartWakeRecommendation? {
        sleepViewModel.selectedRecommendation ?? sleepViewModel.featuredRecommendation
    }

    private var isRTL: Bool {
        layoutDirection == .rightToLeft
    }

    private var canAdvanceToSleep: Bool {
        selectedGoal != nil
            && selectedSport != nil
            && selectedWorkoutTime != nil
    }

    private var isFormValid: Bool {
        canAdvanceToSleep && selectedRecommendation != nil
    }

    var body: some View {
        ZStack {
            AuthFlowBackground()

            VStack(spacing: 0) {
                AuthFlowBrandHeader()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerCard
                        progressCard
                        formCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 28)
                    .scaleEffect(appeared ? 1 : 0.97)
                }
            }
        }
        .alert(localized("captainPersonalization.errorTitle", fallback: "تعذر الحفظ"), isPresented: errorBinding) {
            Button(localized("common.ok", fallback: "حسناً"), role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .environment(\.layoutDirection, AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.84)) {
                appeared = true
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AuthFlowTheme.mint.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: currentStep.headerIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AuthFlowTheme.mint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentStep.title(view: self))
                        .font(.aiqoDisplay(28))
                        .foregroundStyle(.primary)

                    Text(currentStep.subtitle(view: self))
                        .font(.aiqoBody(15))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(currentStep.helper(view: self))
                .font(.aiqoBody(14))
                .foregroundStyle(Color.primary.opacity(0.72))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AuthFlowTheme.sand.opacity(0.22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AuthFlowTheme.sand.opacity(0.35), lineWidth: 1)
                        )
                )
        }
        .padding(24)
        .glassCard(cornerRadius: 28)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        String(
                            format: localized(
                                "captainPersonalization.stepCounter",
                                arabicFallback: "الخطوة %d من %d",
                                englishFallback: "Step %d of %d"
                            ),
                            currentStep.position,
                            CaptainPersonalizationStep.allCases.count
                        )
                    )
                    .font(.aiqoLabel(13))
                    .foregroundStyle(.primary)

                    Text(currentStep.progressLabel(view: self))
                        .font(.aiqoBody(13))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    ForEach(CaptainPersonalizationStep.allCases, id: \.self) { step in
                        Capsule()
                            .fill(step == currentStep ? AuthFlowTheme.mint : Color.black.opacity(0.08))
                            .frame(width: step == currentStep ? 34 : 12, height: 8)
                    }
                }
            }

            HStack(spacing: 10) {
                ForEach(CaptainPersonalizationStep.allCases, id: \.self) { step in
                    let isEnabled = step == .preferences || canAdvanceToSleep || currentStep == .sleep

                    Button {
                        guard isEnabled else { return }
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                            currentStep = step
                        }
                    } label: {
                        Text(step.progressLabel(view: self))
                            .font(.aiqoBody(13))
                            .foregroundStyle(step == currentStep ? Color(hex: "0E3A2B") : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(step == currentStep ? AuthFlowTheme.mint.opacity(0.22) : Color.white.opacity(0.78))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(
                                                step == currentStep ? AuthFlowTheme.mint.opacity(0.9) : Color.black.opacity(0.08),
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isEnabled)
                    .opacity(isEnabled ? 1 : 0.55)
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            if currentStep == .preferences {
                preferencesStepContent
            } else {
                sleepStepContent
            }
        }
        .padding(24)
        .glassCard(cornerRadius: 28)
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: currentStep)
    }

    private var preferencesStepContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            optionSection(
                title: localized("captainPersonalization.primaryGoalTitle", fallback: "الهدف الأساسي"),
                subtitle: localized("captainPersonalization.primaryGoalSubtitle", fallback: "وش أكثر شيء تحب AiQo يركز عليه معك؟")
            ) {
                choiceGrid {
                    ForEach(CaptainPrimaryGoal.allCases) { goal in
                        selectionChip(
                            title: goal.localizedTitle,
                            icon: icon(for: goal),
                            isSelected: selectedGoal == goal
                        ) {
                            selectedGoal = goal
                        }
                    }
                }
            }

            optionSection(
                title: localized("captainPersonalization.favoriteSportTitle", fallback: "الرياضة المفضلة"),
                subtitle: localized("captainPersonalization.favoriteSportSubtitle", fallback: "نستخدمها لصوت التوجيه، الحماس، والتنبيهات اليومية.")
            ) {
                choiceGrid {
                    ForEach(CaptainSportPreference.allCases) { sport in
                        selectionChip(
                            title: sport.localizedTitle,
                            icon: icon(for: sport),
                            isSelected: selectedSport == sport
                        ) {
                            selectedSport = sport
                        }
                    }
                }
            }

            optionSection(
                title: localized("captainPersonalization.workoutTimeTitle", fallback: "أي وقت تفضّل التمرين"),
                subtitle: localized("captainPersonalization.workoutTimeSubtitle", fallback: "نربط هذا بوقت تذكير التمرين اليومي عندك.")
            ) {
                choiceGrid {
                    ForEach(CaptainWorkoutTimePreference.allCases) { workoutTime in
                        selectionChip(
                            title: workoutTime.localizedTitle,
                            icon: icon(for: workoutTime),
                            isSelected: selectedWorkoutTime == workoutTime
                        ) {
                            selectedWorkoutTime = workoutTime
                        }
                    }
                }
            }

            AuthPrimaryButton(
                title: localized(
                    "captainPersonalization.next",
                    arabicFallback: "التالي",
                    englishFallback: "Next"
                ),
                isEnabled: canAdvanceToSleep && !isSaving,
                action: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        currentStep = .sleep
                    }
                },
                icon: isRTL ? "arrow.left" : "arrow.right"
            )
        }
    }

    private var sleepStepContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            optionSection(
                title: localized("captainPersonalization.sleepTitle", fallback: "وقت النوم / وقت الاستيقاظ"),
                subtitle: localized("captainPersonalization.sleepSubtitle", fallback: "اختر وقتك الطبيعي، وAiQo يقترح لك استيقاظاً أهدأ ونهاية دورة نوم أذكى.")
            ) {
                VStack(spacing: 12) {
                    timePickerCard(
                        title: localized("captainPersonalization.bedtime", fallback: "وقت النوم"),
                        icon: "moon.stars.fill",
                        selection: bedtimeBinding
                    )

                    timePickerCard(
                        title: localized("captainPersonalization.wakeTime", fallback: "وقت الاستيقاظ"),
                        icon: "sunrise.fill",
                        selection: wakeTimeBinding
                    )

                    if let recommendation = selectedRecommendation {
                        recommendationSection(recommendation)
                    }
                }
            }

            VStack(spacing: 12) {
                secondaryActionButton(
                    title: localized(
                        "captainPersonalization.back",
                        arabicFallback: "رجوع",
                        englishFallback: "Back"
                    ),
                    icon: isRTL ? "arrow.right" : "arrow.left",
                    action: {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                            currentStep = .preferences
                        }
                    }
                )

                AuthPrimaryButton(
                    title: localized(
                        "captainPersonalization.finish",
                        arabicFallback: "حفظ ومتابعة",
                        englishFallback: "Save & Continue"
                    ),
                    isEnabled: isFormValid && !isSaving,
                    action: continueTapped,
                    icon: isRTL ? "arrow.left" : "arrow.right"
                )
            }
        }
    }

    private func secondaryActionButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color(hex: "18313D"))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.84))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func recommendationSection(_ recommendation: SmartWakeRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(localized("captainPersonalization.smartWakeTitle", fallback: "اقتراح النوم الذكي"))
                    .font(.aiqoHeading(18))
                    .foregroundStyle(.primary)

                Text(localized("captainPersonalization.smartWakeSubtitle", fallback: "هذا الوقت مبني على وقت نومك وآخر وقت تحب تصحى بيه. تقدر تختار البديل الأنسب لك."))
                    .font(.aiqoBody(13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(CaptainPersonalizationTimeFormatter.localizedString(recommendation.wakeDate))
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "123042"))

                        Text(recommendation.explanation)
                            .font(.aiqoBody(13))
                            .foregroundStyle(Color(hex: "365566"))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Text(recommendation.badge)
                        .font(.aiqoLabel(12))
                        .foregroundStyle(Color(hex: "18313D"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.58), in: Capsule())
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    recommendationMetric(
                        title: localized("smartwake.cycles", fallback: "عدد الدورات"),
                        value: "\(recommendation.cycleCount)"
                    )
                    recommendationMetric(
                        title: localized("smartwake.expectedDuration", fallback: "مدة النوم المتوقعة"),
                        value: recommendation.estimatedSleepDuration.formattedSleepDuration
                    )
                    recommendationMetric(
                        title: localized("smartwake.confidence", fallback: "مستوى الثقة"),
                        value: recommendation.confidenceLabel
                    )
                    recommendationMetric(
                        title: localized("smartwake.latestAllowed", fallback: "آخر وقت مسموح"),
                        value: CaptainPersonalizationTimeFormatter.localizedString(wakeTime)
                    )
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "E8FFF4"),
                                Color(hex: "EEF6FF"),
                                Color(hex: "FFF6E8")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.78), lineWidth: 1)
                    )
            )

            if !sleepViewModel.alternateRecommendations.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(localized("captainPersonalization.altWakeOptions", fallback: "بدائل قريبة"))
                        .font(.aiqoLabel(14))
                        .foregroundStyle(.primary)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(sleepViewModel.allRecommendations) { option in
                            Button {
                                sleepViewModel.selectRecommendation(option)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(CaptainPersonalizationTimeFormatter.localizedString(option.wakeDate))
                                        .font(.aiqoHeading(18))
                                        .foregroundStyle(.primary)

                                    Text(String(format: localized("smartwake.cyclesFormat", fallback: "%d دورات"), option.cycleCount))
                                        .font(.aiqoBody(12))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(selectedRecommendation?.id == option.id ? AuthFlowTheme.mint.opacity(0.22) : Color.white.opacity(0.7))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(
                                                    selectedRecommendation?.id == option.id
                                                    ? AuthFlowTheme.mint.opacity(0.9)
                                                    : Color.black.opacity(0.07),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if let selectedRecommendation {
                AlarmSetupCardView(
                    recommendation: selectedRecommendation,
                    saveState: sleepViewModel.alarmSaveState,
                    onSave: {
                        Task {
                            await sleepViewModel.saveSelectedAlarm()
                        }
                    },
                    onOpenSettings: {
                        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(settingsURL)
                    }
                )
            }
        }
    }

    private func optionSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.aiqoHeading(18))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.aiqoBody(13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
        }
    }

    private func choiceGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            alignment: .leading,
            spacing: 10
        ) {
            content()
        }
    }

    private func selectionChip(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color(hex: "0E3A2B") : AuthFlowTheme.sand)

                Text(title)
                    .font(.aiqoBody(14))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? AuthFlowTheme.mint.opacity(0.22) : Color.white.opacity(0.82))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isSelected ? AuthFlowTheme.mint.opacity(0.9) : Color.black.opacity(0.08),
                                lineWidth: isSelected ? 1.3 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func timePickerCard(
        title: String,
        icon: String,
        selection: Binding<Date>
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AuthFlowTheme.mint.opacity(0.14))
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AuthFlowTheme.mint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.aiqoLabel(14))
                    .foregroundStyle(.primary)

                Text(CaptainPersonalizationTimeFormatter.localizedString(selection.wrappedValue))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "123042"))
            }

            Spacer(minLength: 0)

            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.76))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func recommendationMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.aiqoLabel(11))
                .foregroundStyle(Color(hex: "4E6876"))

            Text(value)
                .font(.aiqoBody(13))
                .foregroundStyle(Color(hex: "13232D"))
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var bedtimeBinding: Binding<Date> {
        Binding(
            get: { bedtime },
            set: { newValue in
                bedtime = newValue
                sleepViewModel.setBedtime(newValue)
            }
        )
    }

    private var wakeTimeBinding: Binding<Date> {
        Binding(
            get: { wakeTime },
            set: { newValue in
                wakeTime = newValue
                sleepViewModel.setLatestWakeTime(newValue)
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    saveErrorMessage = nil
                }
            }
        )
    }

    private func continueTapped() {
        guard let selectedGoal,
              let selectedSport,
              let selectedWorkoutTime,
              let selectedRecommendation else {
            return
        }

        isSaving = true

        let snapshot = CaptainPersonalizationSnapshot(
            primaryGoal: selectedGoal,
            favoriteSport: selectedSport,
            preferredWorkoutTime: selectedWorkoutTime,
            bedtime: bedtime,
            wakeTime: wakeTime,
            recommendedWakeTime: selectedRecommendation.wakeDate,
            isAlarmSaved: sleepViewModel.alarmSaveState.isSaved
        )

        guard CaptainPersonalizationStore.shared.save(snapshot) else {
            saveErrorMessage = localized("captainPersonalization.saveError", fallback: "صار خطأ أثناء حفظ تفضيلاتك. حاول مرة ثانية.")
            isSaving = false
            return
        }

        var profile = UserProfileStore.shared.current
        profile.goalText = selectedGoal.canonicalGoalText
        UserProfileStore.shared.current = profile

        MemoryStore.shared.set(
            "goal",
            value: selectedGoal.canonicalGoalText,
            category: "goal",
            source: "user_explicit",
            confidence: 1.0
        )
        MemoryStore.shared.set(
            "preferred_workout",
            value: selectedSport.canonicalValue,
            category: "preference",
            source: "user_explicit",
            confidence: 1.0
        )
        MemoryStore.shared.set(
            "preferred_training_time",
            value: selectedWorkoutTime.canonicalValue,
            category: "preference",
            source: "user_explicit",
            confidence: 1.0
        )
        MemoryStore.shared.set(
            "bedtime_preference",
            value: CaptainPersonalizationTimeFormatter.memoryString(bedtime),
            category: "sleep",
            source: "user_explicit",
            confidence: 1.0
        )
        MemoryStore.shared.set(
            "wake_time_preference",
            value: CaptainPersonalizationTimeFormatter.memoryString(wakeTime),
            category: "sleep",
            source: "user_explicit",
            confidence: 1.0
        )
        MemoryStore.shared.set(
            "smart_wake_recommended_time",
            value: CaptainPersonalizationTimeFormatter.memoryString(selectedRecommendation.wakeDate),
            category: "sleep",
            source: "user_explicit",
            confidence: 1.0
        )

        Task {
            await refreshNotificationsIfAuthorized()
        }

        isSaving = false
        AppFlowController.shared.didCompleteCaptainPersonalization()
    }

    private func refreshNotificationsIfAuthorized() async {
        let settings = await withCheckedContinuation { (continuation: CheckedContinuation<UNNotificationSettings, Never>) in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            SmartNotificationScheduler.shared.refreshAutomationState()
        default:
            break
        }
    }

    fileprivate func localized(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
    }

    fileprivate func localized(
        _ key: String,
        arabicFallback: String,
        englishFallback: String
    ) -> String {
        let fallback = AppSettingsStore.shared.appLanguage == .arabic ? arabicFallback : englishFallback
        let value = NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
        return value == key ? fallback : value
    }

    private static func defaultTime(hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func icon(for goal: CaptainPrimaryGoal) -> String {
        switch goal {
        case .loseWeight:
            return "figure.walk.motion"
        case .gainWeight:
            return "arrow.up.forward.circle.fill"
        case .cutFat:
            return "flame.fill"
        case .buildMuscle:
            return "dumbbell.fill"
        case .improveFitness:
            return "heart.circle.fill"
        }
    }

    private func icon(for sport: CaptainSportPreference) -> String {
        switch sport {
        case .walking:
            return "figure.walk"
        case .running:
            return "figure.run"
        case .gymResistance:
            return "dumbbell.fill"
        case .football:
            return "soccerball"
        case .swimming:
            return "figure.pool.swim"
        case .cycling:
            return "figure.outdoor.cycle"
        case .boxing:
            return "figure.boxing"
        case .yoga:
            return "figure.cooldown"
        }
    }

    private func icon(for workoutTime: CaptainWorkoutTimePreference) -> String {
        switch workoutTime {
        case .earlyMorning:
            return "sun.and.horizon.fill"
        case .morning:
            return "sun.max.fill"
        case .afternoon:
            return "sun.min.fill"
        case .evening:
            return "sunset.fill"
        case .night:
            return "moon.fill"
        }
    }
}

private enum CaptainPersonalizationStep: Int, CaseIterable {
    case preferences
    case sleep

    var position: Int {
        rawValue + 1
    }

    var headerIcon: String {
        switch self {
        case .preferences:
            return "person.crop.circle.badge.checkmark"
        case .sleep:
            return "moon.stars.fill"
        }
    }

    func title(view: CaptainPersonalizationOnboardingView) -> String {
        switch self {
        case .preferences:
            return view.localized(
                "captainPersonalization.title",
                fallback: "خلّ الكابتن يعرفك أكثر"
            )
        case .sleep:
            return view.localized(
                "captainPersonalization.sleepStepTitle",
                arabicFallback: "اضبط نومك الذكي",
                englishFallback: "Set Up Smart Sleep"
            )
        }
    }

    func subtitle(view: CaptainPersonalizationOnboardingView) -> String {
        switch self {
        case .preferences:
            return view.localized(
                "captainPersonalization.subtitle",
                fallback: "جوابك هنا يساعد Captain Hamoudi يرتّب التمارين والتنبيهات والنوم على مزاجك الحقيقي."
            )
        case .sleep:
            return view.localized(
                "captainPersonalization.sleepStepSubtitle",
                arabicFallback: "ثبت وقت النوم والاستيقاظ حتى يقترح AiQo أفضل نافذة تصحى بيها ويحفظلك المنبه.",
                englishFallback: "Set your bedtime and wake time so AiQo can recommend the best wake window and save your alarm."
            )
        }
    }

    func helper(view: CaptainPersonalizationOnboardingView) -> String {
        switch self {
        case .preferences:
            return view.localized(
                "captainPersonalization.helper",
                fallback: "كل شيء تقدر تعدله لاحقاً، لكن هذي البداية تخلي التجربة أذكى من أول يوم."
            )
        case .sleep:
            return view.localized(
                "captainPersonalization.sleepStepHelper",
                arabicFallback: "كل ما تضبط نومك من البداية، يصير الكابتن أدق بالتذكيرات والتعافي والتنبيهات الصباحية.",
                englishFallback: "The earlier you set your sleep rhythm, the smarter Captain becomes with recovery, reminders, and morning nudges."
            )
        }
    }

    func progressLabel(view: CaptainPersonalizationOnboardingView) -> String {
        switch self {
        case .preferences:
            return view.localized(
                "captainPersonalization.progress.preferences",
                arabicFallback: "الأهداف والتفضيلات",
                englishFallback: "Goals & Preferences"
            )
        case .sleep:
            return view.localized(
                "captainPersonalization.progress.sleep",
                arabicFallback: "النوم والمنبه",
                englishFallback: "Sleep & Alarm"
            )
        }
    }
}

private extension TimeInterval {
    var formattedSleepDuration: String {
        let totalMinutes = max(Int((self / 60).rounded()), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let isArabic = AppSettingsStore.shared.appLanguage == .arabic
        let locale = Locale(identifier: isArabic ? "ar" : "en_US")

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .none

        func localizedNumber(_ value: Int) -> String {
            formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }

        if hours > 0 && minutes > 0 {
            return isArabic
                ? "\(localizedNumber(hours)) س \(localizedNumber(minutes)) د"
                : "\(localizedNumber(hours))h \(localizedNumber(minutes))m"
        }

        if hours > 0 {
            return isArabic
                ? "\(localizedNumber(hours)) س"
                : "\(localizedNumber(hours))h"
        }

        return isArabic
            ? "\(localizedNumber(minutes)) د"
            : "\(localizedNumber(minutes))m"
    }
}
