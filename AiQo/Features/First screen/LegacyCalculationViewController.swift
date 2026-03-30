import SwiftUI
import HealthKit
import UIKit
import Combine

struct LegacyCalculationScreenView: View {
    @StateObject private var viewModel = LegacyCalculationViewModel()
    @State private var introAppeared = false
    @State private var resultAppeared = false
    @State private var hasGrantedPermissions = false
    @State private var isRequestingPermissions = false

    var body: some View {
        ZStack {
            AuthFlowBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    switch viewModel.state {
                    case .intro:
                        introView
                    case .loading:
                        loadingView
                    case .result(let model):
                        resultView(model)
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Intro (Screen 3)

    private var introView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)

            VStack(spacing: 24) {
                // Logo
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AuthFlowTheme.mint)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                    Text("AiQo")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                }

                VStack(spacing: 12) {
                    Text(String(format: NSLocalizedString("legacy.intro.body", value: "%@، AiQo يحدد مستواك اعتماداً على تاريخك الصحي الكامل المسجّل على جهازك... كل خطوة مشيتها، كل ساعة نمتها، وكل جهد بذلته عبر السنين الماضية.", comment: ""), viewModel.userName))
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineSpacing(6)

                    Text(NSLocalizedString("legacy.intro.tagline", value: "إنت مو شخص يبدأ من صفر... إنت جاي ويا تاريخ.", comment: ""))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "C6EFDB"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(hex: "F7D7A7"), lineWidth: 1.5)
                        )
                }

                // Permission Card
                Button {
                    guard !isRequestingPermissions && !hasGrantedPermissions else { return }
                    isRequestingPermissions = true
                    Task { @MainActor in
                        HealthKitService.permissionFlowEnabled = true
                        _ = try? await HealthKitService.shared.requestAuthorization()
                        _ = await NotificationService.shared.ensureAuthorizationIfNeeded()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            hasGrantedPermissions = true
                            isRequestingPermissions = false
                        }
                    }
                } label: {
                    HStack(spacing: AiQoSpacing.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AiQoRadius.control)
                                .fill(AuthFlowTheme.mint.opacity(0.12))
                                .frame(width: 44, height: 44)

                            if hasGrantedPermissions {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(AuthFlowTheme.mint)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                HStack(spacing: 2) {
                                    Image(systemName: "heart.text.square.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(AuthFlowTheme.mint)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(hasGrantedPermissions
                                 ? NSLocalizedString("legacy.permissions.granted", value: "تم منح الصلاحيات", comment: "")
                                 : NSLocalizedString("legacy.permissions.title", value: "منح صلاحيات الصحة والإشعارات", comment: ""))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)

                            if !hasGrantedPermissions {
                                Text(NSLocalizedString("legacy.permissions.subtitle", value: "مطلوب للمتابعة", comment: ""))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if isRequestingPermissions {
                            ProgressView()
                                .tint(AuthFlowTheme.mint)
                        } else if !hasGrantedPermissions {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(AiQoSpacing.md)
                    .background {
                        RoundedRectangle(cornerRadius: AiQoRadius.card)
                            .fill(hasGrantedPermissions
                                  ? AuthFlowTheme.mint.opacity(0.08)
                                  : Color.primary.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: AiQoRadius.card)
                                    .strokeBorder(hasGrantedPermissions
                                                  ? AuthFlowTheme.mint.opacity(0.3)
                                                  : Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    }
                }
                .buttonStyle(AiQoPressButtonStyle())
                .disabled(isRequestingPermissions || hasGrantedPermissions)
                .accessibilityLabel(NSLocalizedString("legacy.permissions.a11y", value: "منح صلاحيات الصحة والإشعارات", comment: ""))

                Button { viewModel.primaryButtonTapped() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                        Text(NSLocalizedString("legacy.continue", value: "متابعة", comment: ""))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "C6EFDB"))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!hasGrantedPermissions)
                .opacity(hasGrantedPermissions ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.3), value: hasGrantedPermissions)

                Button { viewModel.skipToHome() } label: {
                    Text(NSLocalizedString("legacy.skip", value: "ليس الآن", comment: ""))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "F7D7A7").opacity(0.4))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .glassCard()
            .padding(.horizontal, 24)
            .opacity(introAppeared ? 1 : 0)
            .offset(y: introAppeared ? 0 : 30)
            .scaleEffect(introAppeared ? 1 : 0.96)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                    introAppeared = true
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 120)
            AnalysisLoadingView(
                title: viewModel.loadingTitle,
                subtitle: viewModel.loadingSubtitle
            )
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Result (Screen 4)

    private func resultView(_ model: LegacyCalculationViewModel.LevelResult) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 30)

            VStack(spacing: 24) {
                // Title + Level
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("legacy.result.level", value: "المستوى", comment: ""))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("\(model.level)")
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "C6EFDB"))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Text(model.title)
                            .font(.system(size: 28, weight: .black, design: .rounded))

                        Text("\(viewModel.userName)، \(model.description)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .lineSpacing(4)
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .trailing) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.12))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "C6EFDB"))
                            .frame(width: geo.size.width * min(Double(model.level) / 50.0, 1.0))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .frame(height: 6)

                // Total
                HStack {
                    Spacer()
                    Text(String(format: NSLocalizedString("legacy.result.total", value: "المجموع: %@ نقطة", comment: ""), model.totalPoints.formatted()))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }

                // Stat rows
                VStack(spacing: 10) {
                    AuthMetricRow(
                        symbol: "figure.walk",
                        title: NSLocalizedString("legacy.metric.steps", value: "الخطوات", comment: ""),
                        value: model.totalSteps.formatted(),
                        points: model.stepsPoints,
                        color: Color(hex: "C6EFDB")
                    )
                    AuthMetricRow(
                        symbol: "flame.fill",
                        title: NSLocalizedString("legacy.metric.calories", value: "السعرات", comment: ""),
                        value: model.totalCalories.formatted(),
                        points: model.caloriesPoints,
                        color: Color(hex: "F7D7A7")
                    )
                    AuthMetricRow(
                        symbol: "location.fill",
                        title: NSLocalizedString("legacy.metric.distance", value: "المسافة", comment: ""),
                        value: "\(String(format: "%.1f", model.totalDistanceKM)) \(NSLocalizedString("unit.km", value: "كم", comment: ""))",
                        points: model.distancePoints,
                        color: Color(hex: "C6EFDB")
                    )
                    AuthMetricRow(
                        symbol: "moon.fill",
                        title: NSLocalizedString("legacy.metric.sleep", value: "النوم", comment: ""),
                        value: "\(String(format: "%.1f", model.totalSleepHours)) \(NSLocalizedString("unit.hours.short", value: "س", comment: ""))",
                        points: model.sleepPoints,
                        color: Color(hex: "F7D7A7")
                    )

                    Divider()

                    AuthMetricRow(
                        symbol: "sparkles",
                        title: NSLocalizedString("legacy.metric.total", value: "المجموع", comment: ""),
                        value: "—",
                        points: model.totalPoints,
                        color: Color(hex: "C6EFDB")
                    )
                }

                // Go home button
                Button { viewModel.goHome() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "house.fill")
                        Text(NSLocalizedString("legacy.goHome", value: "الذهاب إلى الرئيسية", comment: ""))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "C6EFDB"))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .glassCard()
            .padding(.horizontal, 24)
            .opacity(resultAppeared ? 1 : 0)
            .offset(y: resultAppeared ? 0 : 30)
            .scaleEffect(resultAppeared ? 1 : 0.96)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                    resultAppeared = true
                }
            }
        }
    }
}

// MARK: - ViewModel

final class LegacyCalculationViewModel: ObservableObject {
    private enum LoadingPhase {
        case permissions
        case locatingHistory
        case aggregating
        case finalizing
        case timeout
        case unauthorized
    }

    // MARK: - LevelResult

    struct LevelResult {
        let level: Int
        let title: String
        let description: String
        let totalPoints: Int
        let stepsPoints: Int
        let caloriesPoints: Int
        let distancePoints: Int
        let sleepPoints: Int
        let totalSteps: Double
        let totalCalories: Double
        let totalDistanceKM: Double
        let totalSleepHours: Double
    }

    enum State {
        case intro
        case loading
        case result(LevelResult)
    }

    @Published var state: State = .intro
    @Published var loadingTitle = NSLocalizedString("legacy.loading.permissions.title", value: "نطلب Apple Health", comment: "")
    @Published var loadingSubtitle = NSLocalizedString("legacy.loading.permissions.subtitle", value: "مرّة واحدة فقط للوصول إلى تاريخك الصحي الكامل", comment: "")

    let userName: String = {
        let profile = UserProfileStore.shared.current
        let trimmedName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }

        let trimmedUsername = (profile.username ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedUsername.isEmpty {
            return trimmedUsername
        }

        return NSLocalizedString("legacy.fallbackName", value: "أنت", comment: "Fallback when no name set")
    }()
    private let healthStore = HKHealthStore()
    private let syncEngine = HistoricalHealthSyncEngine()
    private var didPresentResult = false

    // MARK: - Actions

    func primaryButtonTapped() {
        guard case .intro = state else { return }
        // Request HealthKit authorization WHILE STILL ON THE INTRO SCREEN.
        // This ensures the permission sheet presents over a stable view hierarchy
        // (fixes "whose view is not in the window hierarchy" error).
        // Only AFTER auth completes (or times out) do we transition to .loading.
        Task(priority: .userInitiated) { @MainActor in
            print("▶️ primaryButtonTapped — requesting auth on intro screen")
            let authorized = await requestHealthAuthorizationIfNeeded()
            print("▶️ auth returned: \(authorized)")

            // NOW transition to loading and start data fetch
            state = .loading
            await startCalculationFlow(authorized: authorized)
        }
    }

    func skipToHome() {
        AppFlowController.shared.finishOnboardingWithoutAdditionalPermissions()
    }

    func goHome() {
        AppFlowController.shared.finishOnboardingRequestingPermissions()
    }

    // MARK: - Flow

    @MainActor
    private func startCalculationFlow(authorized: Bool) async {
        let startedAt = Date()

        let syncResult: HistoricalHealthSyncResult

        if authorized {
            setLoadingPhase(.aggregating)
            print("▶️ starting fetchWithTimeout")
            syncResult = await fetchWithTimeout()
            print("▶️ fetchWithTimeout returned")
        } else {
            setLoadingPhase(.unauthorized)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            syncResult = Self.emptySyncResult
        }

        // Build the display-ready LevelResult from the sync aggregates
        let levelResult = buildLevelResult(from: syncResult)

        // ZDP: Only save the 4 aggregate numbers + computed XP & Level — no raw samples
        UserDefaults.standard.set(levelResult.level, forKey: LevelStorageKeys.currentLevel)
        let progress = min(Double(levelResult.level) / 50.0, 1.0)
        UserDefaults.standard.set(progress, forKey: LevelStorageKeys.currentLevelProgress)
        UserDefaults.standard.set(levelResult.totalPoints, forKey: LevelStorageKeys.legacyTotalPoints)

        // Apply XP to the central LevelStore
        if syncResult.aiqoPoints > 0 {
            syncEngine.applyToLevelStore(syncResult)
        }

        // Ensure minimum display time for loading
        let elapsed = Date().timeIntervalSince(startedAt)
        if elapsed < 1.5 {
            let wait = UInt64((1.5 - elapsed) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: wait)
        }

        setLoadingPhase(.finalizing)
        presentResult(levelResult)
    }

    /// Empty result constant — used for timeouts and unauthorized states
    private static let emptySyncResult = HistoricalHealthSyncResult(
        totalSteps: 0, totalActiveCalories: 0,
        totalDistanceKm: 0, totalSleepHours: 0,
        aiqoPoints: 0, startingLevel: 1,
        shieldTier: .wood, hasRealData: false
    )

    /// Races syncEngine.sync() against a 12-second timeout.
    /// CRITICAL: Does NOT use `withTaskGroup` because task groups wait for ALL
    /// child tasks to complete — even after cancelAll(). If a HealthKit query
    /// never calls its completion handler, the group hangs forever.
    /// Instead, we use `withCheckedContinuation` + two fire-and-forget Tasks,
    /// guarded by an actor to ensure the continuation is resumed exactly once.
    private func fetchWithTimeout() async -> HistoricalHealthSyncResult {
        let engine = syncEngine

        return await withCheckedContinuation { continuation in
            let guard_ = ContinuationGuard(continuation: continuation)

            // Work task — fire and forget
            Task {
                let result = await engine.sync()
                print("▶️ syncEngine.sync() completed")
                await guard_.resumeIfFirst(with: result)
            }

            // Timeout task — fire and forget
            Task {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                print("⏱️ sync timed out (12s)")
                await guard_.resumeIfFirst(with: Self.emptySyncResult)
            }
        }
    }

    @MainActor
    private func presentResult(_ result: LevelResult) {
        guard !didPresentResult else { return }
        didPresentResult = true
        self.state = .result(result)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - HealthKit Authorization

    /// Requests HealthKit authorization with a 5-second safety timeout.
    /// CRITICAL: Does NOT use `withTaskGroup` because task groups wait for ALL
    /// child tasks — even after cancelAll(). If HealthKit auth hangs (can't present
    /// permission sheet, already granted, etc.), the group blocks forever.
    /// Instead uses `withCheckedContinuation` + fire-and-forget Tasks with ContinuationGuard.
    private func requestHealthAuthorizationIfNeeded() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("⚠️ HealthKit not available on this device")
            return false
        }

        let store = healthStore

        // Build type sets synchronously BEFORE the continuation — no concurrency issues
        var readTypes = Set<HKObjectType>()
        let quantityReadIDs: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .distanceWalkingRunning,
            .distanceCycling, .heartRate, .restingHeartRate,
            .heartRateVariabilitySDNN, .walkingHeartRateAverage,
            .oxygenSaturation, .vo2Max, .bodyMass, .dietaryWater,
            .appleStandTime
        ]
        for id in quantityReadIDs {
            if let t = HKObjectType.quantityType(forIdentifier: id) { readTypes.insert(t) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleep)
        }
        readTypes.insert(HKObjectType.workoutType())
        readTypes.insert(HKObjectType.activitySummaryType())

        var writeTypes = Set<HKSampleType>()
        for id: HKQuantityTypeIdentifier in [
            .heartRate, .heartRateVariabilitySDNN, .restingHeartRate,
            .vo2Max, .distanceWalkingRunning, .dietaryWater, .bodyMass
        ] {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { writeTypes.insert(t) }
        }
        writeTypes.insert(HKObjectType.workoutType())

        return await withCheckedContinuation { continuation in
            let guard_ = ContinuationGuard(continuation: continuation)

            // Auth task — runs on @MainActor so HealthKit can present its permission sheet
            // in the window hierarchy. Uses `Task` (NOT `Task.detached`) to inherit the
            // main actor context from the caller (startCalculationFlow is @MainActor).
            // The native async `requestAuthorization` SUSPENDS (does not block) the main
            // actor, so HealthKit can still present its UI.
            Task { @MainActor in
                do {
                    print("🔐 Requesting HealthKit authorization...")
                    try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
                    print("✅ HealthKit authorization completed")
                    await guard_.resumeIfFirst(with: true)
                } catch {
                    print("❌ HealthKit authorization error: \(error.localizedDescription)")
                    await guard_.resumeIfFirst(with: false)
                }
            }

            // Timeout task — fire and forget (15s to give user time to interact with the sheet)
            Task {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                print("⏱️ HealthKit authorization timed out (15s) — proceeding optimistically")
                await guard_.resumeIfFirst(with: true)
            }
        }
    }

    @MainActor
    private func setLoadingPhase(_ phase: LoadingPhase) {
        switch phase {
        case .permissions:
            loadingTitle = NSLocalizedString("legacy.loading.permissions.title", value: "نطلب Apple Health", comment: "")
            loadingSubtitle = NSLocalizedString("legacy.loading.permissions.subtitle", value: "مرّة واحدة فقط للوصول إلى تاريخك الصحي الكامل", comment: "")
        case .locatingHistory:
            loadingTitle = NSLocalizedString("legacy.loading.locating.title", value: "نحدد أول سجل", comment: "")
            loadingSubtitle = NSLocalizedString("legacy.loading.locating.subtitle", value: "نبحث عن أقدم بياناتك الصحية المتاحة على جهازك", comment: "")
        case .aggregating:
            loadingTitle = NSLocalizedString("legacy.loading.aggregating.title", value: "نجمع تاريخك الكامل", comment: "")
            loadingSubtitle = NSLocalizedString("legacy.loading.aggregating.subtitle", value: "خطواتك، سعراتك، المسافة والنوم من أول يوم متاح", comment: "")
        case .finalizing:
            loadingTitle = NSLocalizedString("legacy.loading.finalizing.title", value: "نشكّل مستواك", comment: "")
            loadingSubtitle = NSLocalizedString("legacy.loading.finalizing.subtitle", value: "نحوّل هذا التاريخ الصحي إلى مستوى واضح وشخصي", comment: "")
        case .timeout:
            loadingTitle = NSLocalizedString("legacy.loading.timeout.title", value: "أخذت البيانات وقتاً أطول", comment: "")
            loadingSubtitle = NSLocalizedString("legacy.loading.timeout.subtitle", value: "سنكمل بالبيانات المتاحة حتى لا تبقى الشاشة معلّقة", comment: "")
        case .unauthorized:
            loadingTitle = NSLocalizedString("legacy.loading.unauthorized.title", value: "لم تُمنح الصلاحية", comment: "")
            loadingSubtitle = NSLocalizedString("legacy.loading.unauthorized.subtitle", value: "يمكنك تفعيل Apple Health لاحقاً من الإعدادات", comment: "")
        }
    }

    // MARK: - ContinuationGuard

    /// Thread-safe actor that ensures a `CheckedContinuation` is resumed exactly once.
    /// Used to race two fire-and-forget Tasks (work vs timeout) without `withTaskGroup`,
    /// which hangs forever if any child task never completes.
    private actor ContinuationGuard<T> {
        private var continuation: CheckedContinuation<T, Never>?

        init(continuation: CheckedContinuation<T, Never>) {
            self.continuation = continuation
        }

        func resumeIfFirst(with value: T) {
            guard let c = continuation else { return }
            continuation = nil
            c.resume(returning: value)
        }
    }

    // MARK: - Build LevelResult from Sync Aggregates

    /// Converts the 4 aggregate numbers from HistoricalHealthSyncEngine into a
    /// display-ready LevelResult with weighted scoring and Arabic titles.
    /// Formula: steps/200 + calories/25 + distance*10 + sleep*5 → totalXP
    /// Level = lookup table (progressive thresholds up to Level 50)
    private func buildLevelResult(from sync: HistoricalHealthSyncResult) -> LevelResult {
        let steps = Double(sync.totalSteps)
        let calories = Double(sync.totalActiveCalories)
        let distanceKM = sync.totalDistanceKm
        let sleepHours = sync.totalSleepHours

        let stepsPoints = Int(steps / 200.0)
        let caloriesPoints = Int(calories / 25.0)
        let distancePoints = Int(distanceKM * 10.0)
        let sleepPoints = Int(sleepHours * 5.0)

        let totalPoints = stepsPoints + caloriesPoints + distancePoints + sleepPoints

        // Level table — progressive thresholds
        let level: Int
        switch totalPoints {
        case 0..<200:           level = 1
        case 200..<500:         level = 2
        case 500..<1000:        level = 3
        case 1000..<1800:       level = 4
        case 1800..<2800:       level = 5
        case 2800..<4000:       level = 6
        case 4000..<5500:       level = 7
        case 5500..<7500:       level = 8
        case 7500..<10000:      level = 9
        case 10000..<13000:     level = 10
        case 13000..<16500:     level = 11
        case 16500..<20500:     level = 12
        case 20500..<25000:     level = 13
        case 25000..<30000:     level = 14
        case 30000..<36000:     level = 15
        case 36000..<42500:     level = 16
        case 42500..<50000:     level = 17
        case 50000..<58000:     level = 18
        case 58000..<66500:     level = 19
        case 66500..<76000:     level = 20
        case 76000..<86000:     level = 21
        case 86000..<97000:     level = 22
        case 97000..<109000:    level = 23
        case 109000..<122000:   level = 24
        case 122000..<136000:   level = 25
        case 136000..<151000:   level = 26
        case 151000..<167000:   level = 27
        case 167000..<184000:   level = 28
        case 184000..<202000:   level = 29
        case 202000..<222000:   level = 30
        case 222000..<244000:   level = 31
        case 244000..<268000:   level = 32
        case 268000..<294000:   level = 33
        case 294000..<322000:   level = 34
        case 322000..<352000:   level = 35
        case 352000..<385000:   level = 36
        case 385000..<420000:   level = 37
        case 420000..<458000:   level = 38
        case 458000..<500000:   level = 39
        case 500000..<545000:   level = 40
        case 545000..<594000:   level = 41
        case 594000..<647000:   level = 42
        case 647000..<705000:   level = 43
        case 705000..<768000:   level = 44
        case 768000..<837000:   level = 45
        case 837000..<912000:   level = 46
        case 912000..<994000:   level = 47
        case 994000..<1084000:  level = 48
        case 1084000..<1183000: level = 49
        default:                level = 50
        }

        // Level titles — localized
        let title: String
        let description: String
        switch level {
        case 1...5:
            title = NSLocalizedString("legacy.rank.1.title", value: "البداية", comment: "")
            description = NSLocalizedString("legacy.rank.1.desc", value: "كل رحلة تبدأ بخطوة. AiQo معك من هنا.", comment: "")
        case 6...10:
            title = NSLocalizedString("legacy.rank.2.title", value: "المتحرّك", comment: "")
            description = NSLocalizedString("legacy.rank.2.desc", value: "بدأت تتحرك وتبني عادات. استمر!", comment: "")
        case 11...15:
            title = NSLocalizedString("legacy.rank.3.title", value: "النشيط", comment: "")
            description = NSLocalizedString("legacy.rank.3.desc", value: "جسمك يشكرك. مستواك يرتفع بثبات.", comment: "")
        case 16...20:
            title = NSLocalizedString("legacy.rank.4.title", value: "المنضبط", comment: "")
            description = NSLocalizedString("legacy.rank.4.desc", value: "التزامك واضح. أنت فوق المعدّل.", comment: "")
        case 21...25:
            title = NSLocalizedString("legacy.rank.5.title", value: "القوي", comment: "")
            description = NSLocalizedString("legacy.rank.5.desc", value: "بيانات قوية. جسمك يتكلم وأنت تسمع.", comment: "")
        case 26...30:
            title = NSLocalizedString("legacy.rank.6.title", value: "المحارب", comment: "")
            description = NSLocalizedString("legacy.rank.6.desc", value: "قليلين يوصلون هنا. أنت محارب حقيقي.", comment: "")
        case 31...35:
            title = NSLocalizedString("legacy.rank.7.title", value: "البطل", comment: "")
            description = NSLocalizedString("legacy.rank.7.desc", value: "أرقامك تتكلم عنك. بطل بكل المقاييس.", comment: "")
        case 36...40:
            title = NSLocalizedString("legacy.rank.8.title", value: "الأسطورة الرياضية", comment: "")
            description = NSLocalizedString("legacy.rank.8.desc", value: "أرقامك تبيّن إنك ماخذ صحتك بجدية عالية. AiQo صار شريكك الرسمي.", comment: "")
        case 41...45:
            title = NSLocalizedString("legacy.rank.9.title", value: "الخارق", comment: "")
            description = NSLocalizedString("legacy.rank.9.desc", value: "مستوى لا يُصدَّق. أنت تتحدى الحدود.", comment: "")
        case 46...50:
            title = NSLocalizedString("legacy.rank.10.title", value: "الأسطورة الحيّة", comment: "")
            description = NSLocalizedString("legacy.rank.10.desc", value: "أنت في القمة المطلقة. تاريخك الصحي استثنائي.", comment: "")
        default:
            title = NSLocalizedString("legacy.rank.0.title", value: "المبتدئ", comment: "")
            description = NSLocalizedString("legacy.rank.0.desc", value: "يلا نبدأ!", comment: "")
        }

        return LevelResult(
            level: level,
            title: title,
            description: description,
            totalPoints: totalPoints,
            stepsPoints: stepsPoints,
            caloriesPoints: caloriesPoints,
            distancePoints: distancePoints,
            sleepPoints: sleepPoints,
            totalSteps: steps,
            totalCalories: calories,
            totalDistanceKM: distanceKM,
            totalSleepHours: sleepHours
        )
    }
}
