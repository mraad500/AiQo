import SwiftUI
import HealthKit
import UIKit
internal import Combine

struct LegacyCalculationScreenView: View {
    @StateObject private var viewModel = LegacyCalculationViewModel()

    private var layoutDirection: LayoutDirection {
        AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight
    }

    var body: some View {
        ZStack {
            AuthFlowBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    AuthFlowBrandHeader(
                        subtitle: localized("legacy.brand.subtitle", fallback: "Performance Calibration")
                    )

                    AuthFlowCard {
                        VStack(spacing: 18) {
                            switch viewModel.state {
                            case .intro:
                                introSection
                            case .loading:
                                loadingSection
                            case .result(let model):
                                resultSection(model)
                            }

                            AuthPrimaryButton(
                                title: viewModel.primaryButtonTitle,
                                isEnabled: viewModel.isPrimaryButtonEnabled,
                                action: viewModel.primaryButtonTapped
                            )
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
        }
        .environment(\.layoutDirection, layoutDirection)
        .preferredColorScheme(.dark)
    }

    private var introSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(AuthFlowTheme.mint)

            Text(localized("onboarding.intro.title", fallback: "نحسب مستواك الحالي"))
                .font(.aiqoDisplay(31))
                .foregroundStyle(AuthFlowTheme.text)
                .multilineTextAlignment(.center)

            Text(localized(
                "onboarding.intro.subtitle",
                fallback: "رح نقرأ نشاطك الصحي من HealthKit حتى نحدد مستوى البداية بدقة."
            ))
            .font(.aiqoBody(15))
            .foregroundStyle(AuthFlowTheme.subtext)
            .multilineTextAlignment(.center)
        }
    }

    private var loadingSection: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AuthFlowTheme.mint)
                .scaleEffect(1.2)

            Text(localized("onboarding.loading.title", fallback: "جاري التحليل"))
                .font(.aiqoDisplay(27))
                .foregroundStyle(AuthFlowTheme.text)

            Text(localized("onboarding.loading.subtitle", fallback: "نحلل نشاطك... لحظة"))
                .font(.aiqoBody(15))
                .foregroundStyle(AuthFlowTheme.subtext)
        }
        .padding(.vertical, 18)
    }

    private func resultSection(_ model: LegacyCalculationViewModel.ResultModel) -> some View {
        VStack(spacing: 14) {
            Text(model.hasHealthData ? model.levelName : localized("level_name_starter", fallback: "Starter"))
                .font(.aiqoDisplay(27))
                .foregroundStyle(AuthFlowTheme.text)

            Text("LVL \(model.hasHealthData ? model.level : 1)")
                .font(.aiqoDisplay(40))
                .foregroundStyle(AuthFlowTheme.mint)

            ProgressView(value: model.levelProgress)
                .tint(AuthFlowTheme.mint)

            Text(model.displayMessage)
                .font(.aiqoBody(15))
                .foregroundStyle(AuthFlowTheme.subtext)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                ForEach(model.rows) { row in
                    AuthMetricRow(
                        symbol: row.symbol,
                        title: row.title,
                        value: row.value,
                        points: row.points
                    )
                }
            }
            .padding(.top, 2)
        }
    }

    private func localized(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
    }
}

final class LegacyCalculationViewModel: ObservableObject {
    struct PointsRow: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let points: Int
        let symbol: String
    }

    struct ResultModel {
        let levelName: String
        let totalPoints: Int
        let level: Int
        let levelProgress: Double
        let message: String
        let hasHealthData: Bool
        let rows: [PointsRow]

        var displayMessage: String {
            if hasHealthData {
                let totalLabel = NSLocalizedString(
                    "onboarding.result.total",
                    tableName: "Localizable",
                    bundle: .main,
                    value: "المجموع",
                    comment: ""
                )
                let pointsLabel = NSLocalizedString(
                    "onboarding.result.pointsUnit",
                    tableName: "Localizable",
                    bundle: .main,
                    value: "نقطة",
                    comment: ""
                )
                return "\(message)\n\(totalLabel): \(totalPoints) \(pointsLabel)"
            }
            return NSLocalizedString(
                "onboarding.result.noHistory",
                tableName: "Localizable",
                bundle: .main,
                value: "ماكو تاريخ صحي حالياً. ابدأ من اليوم ومستواك راح يرتفع بسرعة.",
                comment: ""
            )
        }
    }

    enum State {
        case intro
        case loading
        case result(ResultModel)
    }

    @Published var state: State = .intro

    private let healthStore = HKHealthStore()

    var primaryButtonTitle: String {
        switch state {
        case .intro:
            return NSLocalizedString(
                "onboarding.button.start",
                tableName: "Localizable",
                bundle: .main,
                value: "ابدأ التحليل",
                comment: ""
            )
        case .loading:
            return NSLocalizedString(
                "onboarding.button.loading",
                tableName: "Localizable",
                bundle: .main,
                value: "جاري التحليل...",
                comment: ""
            )
        case .result:
            return NSLocalizedString(
                "onboarding.button.goHome",
                tableName: "Localizable",
                bundle: .main,
                value: "الذهاب إلى الرئيسية",
                comment: ""
            )
        }
    }

    var isPrimaryButtonEnabled: Bool {
        if case .loading = state { return false }
        return true
    }

    func primaryButtonTapped() {
        switch state {
        case .intro:
            state = .loading
            Task { await startCalculationFlow() }

        case .loading:
            break

        case .result:
            UIApplication.activeSceneDelegate()?.onboardingFinished()
        }
    }

    private func startCalculationFlow() async {
        let startedAt = Date()

        let authorized = await requestHealthAuthorizationIfNeeded()
        let resultModel: ResultModel

        if authorized {
            let totals = await fetchHealthTotals()
            resultModel = buildResultModel(
                steps: totals.steps,
                calories: totals.calories,
                distanceKm: totals.distanceKm,
                sleepHours: totals.sleepHours
            )
        } else {
            resultModel = fallbackResultModel()
        }

        let elapsed = Date().timeIntervalSince(startedAt)
        if elapsed < 1.0 {
            let wait = UInt64((1.0 - elapsed) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: wait)
        }

        await MainActor.run {
            self.state = .result(resultModel)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

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

    private func fallbackResultModel() -> ResultModel {
        let starter = NSLocalizedString(
            "level_name_starter",
            tableName: "Localizable",
            bundle: .main,
            value: "Starter",
            comment: ""
        )

        return ResultModel(
            levelName: starter,
            totalPoints: 0,
            level: 1,
            levelProgress: 0,
            message: NSLocalizedString(
                "msg_level_starter",
                tableName: "Localizable",
                bundle: .main,
                value: "جاهز للبداية",
                comment: ""
            ),
            hasHealthData: false,
            rows: [
                PointsRow(title: localized("onboarding.row.steps", fallback: "الخطوات"), value: "0", points: 0, symbol: "figure.walk"),
                PointsRow(title: localized("onboarding.row.calories", fallback: "السعرات"), value: "0", points: 0, symbol: "flame.fill"),
                PointsRow(title: localized("onboarding.row.distance", fallback: "المسافة"), value: "0", points: 0, symbol: "location.fill"),
                PointsRow(title: localized("onboarding.row.sleep", fallback: "النوم"), value: "0", points: 0, symbol: "moon.zzz.fill")
            ]
        )
    }

    private func buildResultModel(steps: Double, calories: Double, distanceKm: Double, sleepHours: Double) -> ResultModel {
        let stepsPoints = Int(steps / 1_000.0)
        let caloriesPoints = Int(calories / 100.0)
        let distancePoints = Int(distanceKm * 5.0)
        let sleepPoints = Int(sleepHours / 8.0) * 20

        let totalPoints = max(0, stepsPoints + caloriesPoints + distancePoints + sleepPoints)
        let levelInfo = calculateLevel(from: totalPoints)

        UserDefaults.standard.set(levelInfo.level, forKey: LevelStorageKeys.currentLevel)
        UserDefaults.standard.set(levelInfo.progress, forKey: LevelStorageKeys.currentLevelProgress)
        UserDefaults.standard.set(totalPoints, forKey: LevelStorageKeys.legacyTotalPoints)

        let hasHealthData = steps > 0 || calories > 0 || distanceKm > 0 || sleepHours > 0

        let levelName: String
        let message: String

        switch totalPoints {
        case 0..<150:
            levelName = localized("level_name_starter", fallback: "Starter")
            message = localized("msg_level_starter", fallback: "جاهز للبداية")
        case 150..<400:
            levelName = localized("level_name_riser", fallback: "Riser")
            message = localized("msg_level_riser", fallback: "مستواك يرتفع")
        case 400..<800:
            levelName = localized("level_name_fighter", fallback: "Fighter")
            message = localized("msg_level_fighter", fallback: "تقدّم قوي")
        default:
            levelName = localized("level_name_legend", fallback: "Legend")
            message = localized("msg_level_legend", fallback: "مستوى أسطوري")
        }

        let rows = makeRows(
            steps: steps,
            stepsPoints: stepsPoints,
            calories: calories,
            caloriesPoints: caloriesPoints,
            distanceKm: distanceKm,
            distancePoints: distancePoints,
            sleepHours: sleepHours,
            sleepPoints: sleepPoints
        )

        return ResultModel(
            levelName: levelName,
            totalPoints: totalPoints,
            level: levelInfo.level,
            levelProgress: levelInfo.progress,
            message: message,
            hasHealthData: hasHealthData,
            rows: rows
        )
    }

    private func makeRows(
        steps: Double,
        stepsPoints: Int,
        calories: Double,
        caloriesPoints: Int,
        distanceKm: Double,
        distancePoints: Int,
        sleepHours: Double,
        sleepPoints: Int
    ) -> [PointsRow] {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.locale = .current

        let stepsText = nf.string(from: NSNumber(value: steps)) ?? "\(Int(steps))"
        let caloriesText = nf.string(from: NSNumber(value: calories)) ?? "\(Int(calories))"
        let distanceText = String(format: "%.1f %@", distanceKm, localized("onboarding.unit.km", fallback: "كم"))
        let sleepText = String(format: "%.1f %@", sleepHours, localized("onboarding.unit.hours", fallback: "س"))

        return [
            PointsRow(title: localized("onboarding.row.steps", fallback: "الخطوات"), value: stepsText, points: stepsPoints, symbol: "figure.walk"),
            PointsRow(title: localized("onboarding.row.calories", fallback: "السعرات"), value: caloriesText, points: caloriesPoints, symbol: "flame.fill"),
            PointsRow(title: localized("onboarding.row.distance", fallback: "المسافة"), value: distanceText, points: distancePoints, symbol: "location.fill"),
            PointsRow(title: localized("onboarding.row.sleep", fallback: "النوم"), value: sleepText, points: sleepPoints, symbol: "moon.zzz.fill")
        ]
    }

    private func calculateLevel(from totalPoints: Int) -> (level: Int, progress: Double) {
        let baseRequirement = 500
        let increment = 200

        var remaining = max(totalPoints, 0)
        var level = 1
        var requirement = baseRequirement

        while remaining >= requirement {
            remaining -= requirement
            level += 1
            requirement += increment
        }

        let progress = requirement > 0 ? Double(remaining) / Double(requirement) : 0
        return (max(level, 1), min(max(progress, 0), 1))
    }

    private func localized(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
    }
}
