import SwiftUI
import UserNotifications

/// Single-screen onboarding that consolidates the previous Health Screening +
/// Captain Personalization (Goals + Sleep) flows into one fast scroll. Smart
/// defaults pre-fill the workout time and sleep window so the user can finish
/// in a few taps. Health condition toggles are hidden behind a disclosure to
/// keep the surface light for the common case.
struct QuickStartOnboardingView: View {
    let onContinue: () -> Void

    @State private var selectedGoal: CaptainPrimaryGoal?
    @State private var selectedSport: CaptainSportPreference?
    @State private var selectedWorkoutTime: CaptainWorkoutTimePreference = .evening
    @State private var birthYearText: String = ""
    @State private var isHealthDisclosureExpanded = false
    @State private var isPregnant = false
    @State private var hasHeartCondition = false
    @State private var hadRecentSurgery = false
    @State private var bedtime: Date
    @State private var wakeTime: Date
    @State private var showUnderAgeBlock = false
    @State private var appeared = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    @StateObject private var sleepViewModel: SmartWakeViewModel

    @FocusState private var birthYearFocused: Bool

    private let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())

    init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue

        let existing = CaptainPersonalizationStore.shared.currentSnapshot()
        let defaultBedtime = existing?.bedtime ?? Self.defaultTime(hour: 22, minute: 30)
        let defaultWake = existing?.wakeTime ?? Self.defaultTime(hour: 6, minute: 30)

        _selectedGoal = State(initialValue: existing?.primaryGoal)
        _selectedSport = State(initialValue: existing?.favoriteSport)
        _selectedWorkoutTime = State(initialValue: existing?.preferredWorkoutTime ?? .evening)
        _bedtime = State(initialValue: defaultBedtime)
        _wakeTime = State(initialValue: defaultWake)
        _sleepViewModel = StateObject(
            wrappedValue: SmartWakeViewModel(
                initialBedtime: defaultBedtime,
                initialLatestWakeTime: defaultWake,
                initialMode: .fromWakeTime
            )
        )

        if let answers = HealthScreeningStore.load() {
            _birthYearText = State(initialValue: String(answers.birthYear))
            _isPregnant = State(initialValue: answers.isPregnant)
            _hasHeartCondition = State(initialValue: answers.hasHeartOrBloodPressureCondition)
            _hadRecentSurgery = State(initialValue: answers.hadRecentSurgery)
            _isHealthDisclosureExpanded = State(initialValue: answers.hasAnyCondition)
        }
    }

    private var parsedYear: Int? {
        let digits = Self.normalizeToWesternDigits(birthYearText)
            .trimmingCharacters(in: .whitespaces)
        guard let year = Int(digits), year > 1900, year <= currentYear else { return nil }
        return year
    }

    private var canContinue: Bool {
        selectedGoal != nil && selectedSport != nil && parsedYear != nil && !isSaving
    }

    private var featuredRecommendation: SmartWakeRecommendation? {
        sleepViewModel.featuredRecommendation
    }

    var body: some View {
        ZStack {
            AuthFlowBackground()

            if showUnderAgeBlock {
                underAgeBlock
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                form
                    .transition(.opacity)
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
        .interactiveDismissDisabled(true)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.84)) {
                appeared = true
            }
        }
    }

    private var form: some View {
        VStack(spacing: 0) {
            AuthFlowBrandHeader()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    goalCard
                    sportCard
                    workoutTimeCard
                    ageAndHealthCard
                    sleepCard
                    privacyFootnote
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 28)
            }

            continueButton
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AuthFlowTheme.mint.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AuthFlowTheme.mint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(localized("quickStart.title", fallback: "خلّ الكابتن يعرفك"))
                    .font(.aiqoDisplay(24))
                    .foregroundStyle(.primary)
                Text(localized("quickStart.subtitle", fallback: "دقيقتين بس قبل ما نبدأ — كل شي تقدر تعدله لاحقاً."))
                    .font(.aiqoBody(14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    private var goalCard: some View {
        sectionCard(
            title: localized("quickStart.goalSection", fallback: "وش هدفك؟")
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
    }

    private var sportCard: some View {
        sectionCard(
            title: localized("quickStart.sportSection", fallback: "وش رياضتك المفضلة؟")
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
    }

    private var workoutTimeCard: some View {
        sectionCard(
            title: localized("quickStart.timeSection", fallback: "متى تحب تتمرن؟")
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
    }

    private var ageAndHealthCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("quickStart.birthYear.label", fallback: "سنة ميلادك"))
                .font(.aiqoHeading(16))
                .foregroundStyle(.primary)

            TextField(
                localized("quickStart.birthYear.placeholder", fallback: "مثلاً 1995"),
                text: $birthYearText
            )
            .keyboardType(.numberPad)
            .font(.aiqoDisplay(20))
            .foregroundStyle(.primary)
            .tint(AuthFlowTheme.mint)
            .focused($birthYearFocused)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )

            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    isHealthDisclosureExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isHealthDisclosureExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AuthFlowTheme.mint)
                    Text(localized("quickStart.healthDisclosure.toggle", fallback: "هل عندك حالة صحية؟"))
                        .font(.aiqoBody(14).weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("quick-start-health-disclosure")

            if isHealthDisclosureExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text(localized(
                        "quickStart.healthDisclosure.hint",
                        fallback: "اختياري — يساعد الكابتن يخفّف التوصيات الشدّة."
                    ))
                    .font(.aiqoCaption(12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    conditionToggle(
                        titleKey: "onboarding.healthScreening.condition.pregnant",
                        fallback: "حامل حالياً",
                        isOn: $isPregnant
                    )
                    conditionToggle(
                        titleKey: "onboarding.healthScreening.condition.heart",
                        fallback: "عندي مرض قلب أو ضغط",
                        isOn: $hasHeartCondition
                    )
                    conditionToggle(
                        titleKey: "onboarding.healthScreening.condition.surgery",
                        fallback: "مريت بعملية جراحية خلال آخر 6 أشهر",
                        isOn: $hadRecentSurgery
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("quickStart.sleepSection", fallback: "وقت نومك"))
                .font(.aiqoHeading(16))
                .foregroundStyle(.primary)

            HStack(spacing: 10) {
                timePill(
                    title: localized("captainPersonalization.bedtime", fallback: "وقت النوم"),
                    icon: "moon.stars.fill",
                    selection: bedtimeBinding
                )
                timePill(
                    title: localized("captainPersonalization.wakeTime", fallback: "وقت الاستيقاظ"),
                    icon: "sunrise.fill",
                    selection: wakeTimeBinding
                )
            }

            if let recommendation = featuredRecommendation {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AuthFlowTheme.mint)
                    Text(String(
                        format: localized(
                            "quickStart.smartWake.inline",
                            fallback: "AiQo بيقترح تصحى الساعة %@"
                        ),
                        CaptainPersonalizationTimeFormatter.localizedString(recommendation.wakeDate)
                    ))
                    .font(.aiqoBody(13))
                    .foregroundStyle(Color(hex: "18313D"))
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AuthFlowTheme.mint.opacity(0.18))
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    private var privacyFootnote: some View {
        Text(localized(
            "quickStart.privacy",
            fallback: "كل الإجابات تبقى على جهازك. AiQo ما يشخّص ولا يعالج الحالات الطبية."
        ))
        .font(.aiqoCaption(12))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var continueButton: some View {
        Button {
            handleContinue()
        } label: {
            Text(localized("quickStart.continue", fallback: "ابدأ مع الكابتن"))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AuthFlowTheme.mint)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canContinue)
        .opacity(canContinue ? 1 : 0.5)
        .accessibilityIdentifier("quick-start-continue")
    }

    private var underAgeBlock: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 24)
            ZStack {
                Circle()
                    .fill(AuthFlowTheme.mint.opacity(0.18))
                    .frame(width: 112, height: 112)
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(AuthFlowTheme.mint)
            }
            Text(localized("onboarding.healthScreening.underAge.title", fallback: "AiQo للكبار فوق 18"))
                .font(.aiqoDisplay(26))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(localized(
                "onboarding.healthScreening.underAge.body",
                fallback: "AiQo يقدّم تدريب لياقة وعافية عامّة مخصصة للكبار. ما نكدر نعطيك خطة شخصية حالياً."
            ))
            .font(.aiqoBody(15))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .fixedSize(horizontal: false, vertical: true)
            Text(localized(
                "onboarding.healthScreening.underAge.support",
                fallback: "إذا تعتقد هذا غلط، تواصل معنا: support@aiqo.app."
            ))
            .font(.aiqoCaption(12))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(28)
    }

    // MARK: - Helpers

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.aiqoHeading(16))
                .foregroundStyle(.primary)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
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

    private func conditionToggle(
        titleKey: String,
        fallback: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            Text(localized(titleKey, fallback: fallback))
                .font(.aiqoBody(14))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .toggleStyle(SwitchToggleStyle(tint: AuthFlowTheme.mint))
    }

    private func timePill(
        title: String,
        icon: String,
        selection: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AuthFlowTheme.mint)
                Text(title)
                    .font(.aiqoLabel(13))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        )
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

    private func handleContinue() {
        birthYearFocused = false
        guard let goal = selectedGoal,
              let sport = selectedSport,
              let year = parsedYear else { return }

        let answers = HealthScreeningAnswers(
            birthYear: year,
            isPregnant: isPregnant,
            hasHeartOrBloodPressureCondition: hasHeartCondition,
            hadRecentSurgery: hadRecentSurgery
        )
        if answers.ageNow < HealthScreeningStore.minimumAge {
            withAnimation(.easeInOut(duration: 0.35)) {
                showUnderAgeBlock = true
            }
            return
        }
        HealthScreeningStore.save(answers)

        isSaving = true

        let recommendation = featuredRecommendation
        let snapshot = CaptainPersonalizationSnapshot(
            primaryGoal: goal,
            favoriteSport: sport,
            preferredWorkoutTime: selectedWorkoutTime,
            bedtime: bedtime,
            wakeTime: wakeTime,
            recommendedWakeTime: recommendation?.wakeDate ?? wakeTime,
            isAlarmSaved: false
        )

        guard CaptainPersonalizationStore.shared.save(snapshot) else {
            saveErrorMessage = localized(
                "captainPersonalization.saveError",
                fallback: "صار خطأ أثناء حفظ تفضيلاتك. حاول مرة ثانية."
            )
            isSaving = false
            return
        }

        var profile = UserProfileStore.shared.current
        profile.goalText = goal.canonicalGoalText
        UserProfileStore.shared.current = profile

        MemoryStore.shared.set(
            "goal",
            value: goal.canonicalGoalText,
            category: "goal",
            source: "user_explicit",
            confidence: 1.0
        )
        MemoryStore.shared.set(
            "preferred_workout",
            value: sport.canonicalValue,
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
        if let recommendation {
            MemoryStore.shared.set(
                "smart_wake_recommended_time",
                value: CaptainPersonalizationTimeFormatter.memoryString(recommendation.wakeDate),
                category: "sleep",
                source: "user_explicit",
                confidence: 1.0
            )
        }

        Task { await refreshNotificationsIfAuthorized() }

        isSaving = false
        onContinue()
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

    private func localized(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
    }

    private static func defaultTime(hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private static func normalizeToWesternDigits(_ input: String) -> String {
        let map: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
            "۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4",
            "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9"
        ]
        return String(input.map { map[$0] ?? $0 })
    }

    private func icon(for goal: CaptainPrimaryGoal) -> String {
        switch goal {
        case .loseWeight: return "figure.walk.motion"
        case .gainWeight: return "arrow.up.forward.circle.fill"
        case .cutFat: return "flame.fill"
        case .buildMuscle: return "dumbbell.fill"
        case .improveFitness: return "heart.circle.fill"
        }
    }

    private func icon(for sport: CaptainSportPreference) -> String {
        switch sport {
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        case .gymResistance: return "dumbbell.fill"
        case .football: return "soccerball"
        case .swimming: return "figure.pool.swim"
        case .cycling: return "figure.outdoor.cycle"
        case .boxing: return "figure.boxing"
        case .yoga: return "figure.cooldown"
        }
    }

    private func icon(for workoutTime: CaptainWorkoutTimePreference) -> String {
        switch workoutTime {
        case .earlyMorning: return "sun.and.horizon.fill"
        case .morning: return "sun.max.fill"
        case .afternoon: return "sun.min.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.fill"
        }
    }
}
