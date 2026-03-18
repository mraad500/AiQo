import SwiftUI
import HealthKit
import UIKit
internal import Combine

struct LegacyCalculationScreenView: View {
    @StateObject private var viewModel = LegacyCalculationViewModel()
    @State private var introAppeared = false
    @State private var resultAppeared = false

    private var layoutDirection: LayoutDirection {
        AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight
    }

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
        .environment(\.layoutDirection, layoutDirection)
    }

    // MARK: - Intro (Screen 3)

    private var introView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)

            VStack(spacing: 24) {
                // Logo
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(AuthFlowTheme.mint)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                    Text("AiQo")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                }

                // Main text with username
                VStack(spacing: 12) {
                    Text("\(viewModel.userName)، AiQo يحدد مستواك اعتماداً على تاريخك الصحي الكامل المسجّل على جهازك... كل خطوة مشيتها، كل ساعة نمتها، وكل جهد بذلته عبر السنين الماضية.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary.opacity(0.85))
                        .lineSpacing(6)

                    Text("إنت مو شخص يبدأ من صفر... إنت جاي ويا تاريخ.")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AuthFlowTheme.mint)
                        .multilineTextAlignment(.center)
                }

                // Continue
                AuthPrimaryButton(
                    title: "متابعة",
                    isEnabled: true,
                    action: { viewModel.primaryButtonTapped() }
                )

                // Skip
                AuthSecondaryButton(title: "ليس الآن") {
                    viewModel.skipToHome()
                }
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
            AnalysisLoadingView()
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
                    // Level (left)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("المستوى")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("\(model.level)")
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundColor(AuthFlowTheme.mint)
                    }

                    Spacer()

                    // Title + Description (right)
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(model.title)
                            .font(.system(size: 28, weight: .black, design: .rounded))

                        Text("\(viewModel.userName)، \(model.description)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
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
                            .fill(AuthFlowTheme.mint)
                            .frame(width: geo.size.width * min(Double(model.level) / 50.0, 1.0))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .frame(height: 6)

                // Total
                HStack {
                    Spacer()
                    Text("المجموع: \(model.totalPoints.formatted()) نقطة")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }

                // Stat rows
                VStack(spacing: 10) {
                    AuthMetricRow(
                        symbol: "figure.walk",
                        title: "الخطوات",
                        value: model.totalSteps.formatted(),
                        points: model.stepsPoints,
                        color: AuthFlowTheme.mint
                    )
                    AuthMetricRow(
                        symbol: "flame.fill",
                        title: "السعرات",
                        value: model.totalCalories.formatted(),
                        points: model.caloriesPoints,
                        color: AuthFlowTheme.sand
                    )
                    AuthMetricRow(
                        symbol: "location.fill",
                        title: "المسافة",
                        value: "\(String(format: "%.1f", model.totalDistanceKM)) كم",
                        points: model.distancePoints,
                        color: AuthFlowTheme.mint
                    )
                    AuthMetricRow(
                        symbol: "moon.fill",
                        title: "النوم",
                        value: "\(String(format: "%.1f", model.totalSleepHours)) س",
                        points: model.sleepPoints,
                        color: AuthFlowTheme.sand
                    )

                    Divider()

                    AuthMetricRow(
                        symbol: "sparkles",
                        title: "المجموع",
                        value: "—",
                        points: model.totalPoints,
                        color: AuthFlowTheme.mint
                    )
                }

                // Go home button
                AuthPrimaryButton(
                    title: "الذهاب إلى الرئيسية",
                    isEnabled: true,
                    action: { viewModel.goHome() }, icon: "house.fill"
                )
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

    let userName: String = UserProfileStore.shared.current.name
    private let healthStore = HKHealthStore()
    private var didPresentResult = false

    // MARK: - Actions

    func primaryButtonTapped() {
        guard case .intro = state else { return }
        state = .loading
        Task { await startCalculationFlow() }
    }

    func skipToHome() {
        AppFlowController.shared.onboardingFinished()
    }

    func goHome() {
        AppFlowController.shared.onboardingFinished()
    }

    // MARK: - Flow

    private func startCalculationFlow() async {
        let startedAt = Date()

        let authorized = await requestHealthAuthorizationIfNeeded()
        let levelResult: LevelResult

        if authorized {
            let totals = await fetchHealthTotalsWithTimeout()
            levelResult = calculateLevel(
                steps: totals.steps,
                calories: totals.calories,
                distanceKM: totals.distanceKm,
                sleepHours: totals.sleepHours
            )
        } else {
            levelResult = calculateLevel(steps: 0, calories: 0, distanceKM: 0, sleepHours: 0)
        }

        // Store level
        UserDefaults.standard.set(levelResult.level, forKey: LevelStorageKeys.currentLevel)
        let progress = min(Double(levelResult.level) / 50.0, 1.0)
        UserDefaults.standard.set(progress, forKey: LevelStorageKeys.currentLevelProgress)
        UserDefaults.standard.set(levelResult.totalPoints, forKey: LevelStorageKeys.legacyTotalPoints)

        // Ensure minimum display time for loading
        let elapsed = Date().timeIntervalSince(startedAt)
        if elapsed < 1.5 {
            let wait = UInt64((1.5 - elapsed) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: wait)
        }

        await presentResult(levelResult)
    }

    @MainActor
    private func presentResult(_ result: LevelResult) {
        guard !didPresentResult else { return }
        didPresentResult = true
        self.state = .result(result)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - HealthKit Authorization

    private func requestHealthAuthorizationIfNeeded() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(
                toShare: nil,
                read: [stepType, energyType, distanceType, sleepType]
            ) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    // MARK: - Fetch Data with Timeout

    private func fetchHealthTotalsWithTimeout() async -> (steps: Double, calories: Double, distanceKm: Double, sleepHours: Double) {
        // Race between actual fetch and 15-second timeout
        return await withTaskGroup(of: (steps: Double, calories: Double, distanceKm: Double, sleepHours: Double)?.self) { group in
            // Actual fetch task
            group.addTask {
                return await self.fetchHealthTotals()
            }

            // Timeout task
            group.addTask {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                return nil // signals timeout
            }

            // Return first completed result
            for await result in group {
                if let result = result {
                    group.cancelAll()
                    return result
                }
            }

            // If timeout won, return zeros
            group.cancelAll()
            print("⚠️ HealthKit timeout — presenting with zero data")
            return (steps: 0, calories: 0, distanceKm: 0, sleepHours: 0)
        }
    }

    private func fetchHealthTotals() async -> (steps: Double, calories: Double, distanceKm: Double, sleepHours: Double) {
        async let steps = fetchCumulativeQuantity(for: .stepCount, unit: .count())
        async let calories = fetchCumulativeQuantity(for: .activeEnergyBurned, unit: .kilocalorie())
        async let distanceMeters = fetchCumulativeQuantity(for: .distanceWalkingRunning, unit: .meter())
        async let sleepHours = fetchSleepHours()

        let resolvedDistanceKm = (await distanceMeters) / 1000.0

        return (
            steps: await steps,
            calories: await calories,
            distanceKm: resolvedDistanceKm,
            sleepHours: await sleepHours
        )
    }

    private func fetchCumulativeQuantity(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }

        let predicate = HKQuery.predicateForSamples(withStart: .distantPast, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                // Always resume — even if stats is nil, return 0
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            self.healthStore.execute(query)
        }
    }

    private func fetchSleepHours() async -> Double {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }

        let predicate = HKQuery.predicateForSamples(withStart: .distantPast, end: Date(), options: .strictStartDate)
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    continuation.resume(returning: 0)
                    return
                }

                var totalSeconds: TimeInterval = 0
                for sample in sleepSamples where asleepValues.contains(sample.value) {
                    totalSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                }

                continuation.resume(returning: totalSeconds / 3600.0)
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Scoring System (Updated Multipliers)

    func calculateLevel(steps: Double, calories: Double, distanceKM: Double, sleepHours: Double) -> LevelResult {
        // Updated generous multipliers — target level ~40 for strong data
        let stepsPoints = Int(steps / 150.0)
        let caloriesPoints = Int(calories / 18.0)
        let distancePoints = Int(distanceKM * 15.0)
        let sleepPoints = Int(sleepHours * 8.0)

        let totalPoints = stepsPoints + caloriesPoints + distancePoints + sleepPoints

        // Level table — progressive
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

        // Titles
        let title: String
        let description: String
        switch level {
        case 1...5:
            title = "البداية"
            description = "كل رحلة تبدأ بخطوة. AiQo معك من هنا."
        case 6...10:
            title = "المتحرّك"
            description = "بدأت تتحرك وتبني عادات. استمر!"
        case 11...15:
            title = "النشيط"
            description = "جسمك يشكرك. مستواك يرتفع بثبات."
        case 16...20:
            title = "المنضبط"
            description = "التزامك واضح. أنت فوق المعدّل."
        case 21...25:
            title = "القوي"
            description = "بيانات قوية. جسمك يتكلم وأنت تسمع."
        case 26...30:
            title = "المحارب"
            description = "قليلين يوصلون هنا. أنت محارب حقيقي."
        case 31...35:
            title = "البطل"
            description = "أرقامك تتكلم عنك. بطل بكل المقاييس."
        case 36...40:
            title = "الأسطورة الرياضية"
            description = "أرقامك تبيّن إنك ماخذ صحتك بجدية عالية. AiQo صار شريكك الرسمي."
        case 41...45:
            title = "الخارق"
            description = "مستوى لا يُصدَّق. أنت تتحدى الحدود."
        case 46...50:
            title = "الأسطورة الحيّة"
            description = "أنت في القمة المطلقة. تاريخك الصحي استثنائي."
        default:
            title = "المبتدئ"
            description = "يلا نبدأ!"
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
