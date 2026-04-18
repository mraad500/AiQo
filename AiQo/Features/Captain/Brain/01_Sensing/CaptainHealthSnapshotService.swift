import Foundation
import HealthKit
import os.log

#if canImport(FoundationModels)
import FoundationModels
#endif

struct CaptainDailyHealthMetrics: Sendable, Equatable {
    let stepCount: Int
    let activeEnergyKilocalories: Int
    let averageOrCurrentHeartRateBPM: Int?
    let sleepHours: Double
}

enum CaptainIntelligenceError: LocalizedError {
    case healthKitUnavailable
    case healthAuthorizationDenied
    case missingHealthType(String)
    case foundationModelsUnavailable
    case onDeviceModelUnavailable
    case unsupportedDeviceLanguage
    case emptyModelResponse

    var errorDescription: String? {
        switch self {
        case .healthKitUnavailable:
            return "HealthKit is unavailable on this device."
        case .healthAuthorizationDenied:
            return "Health access was denied. Please allow Health permissions for Captain."
        case let .missingHealthType(identifier):
            return "A required Health type is unavailable: \(identifier)."
        case .foundationModelsUnavailable:
            return "Foundation Models are unavailable on this OS/runtime."
        case .onDeviceModelUnavailable:
            return "Apple Intelligence on-device model is unavailable on this device."
        case .unsupportedDeviceLanguage:
            return "The current device language is not supported by the on-device model."
        case .emptyModelResponse:
            return "The on-device model returned an empty response."
        }
    }
}

/// Privacy-first helper that reads HealthKit metrics on-device and exposes an
/// on-device Apple Intelligence reply generator.
/// No cloud transport lives in this class. Cloud flows go through `BrainOrchestrator`.
final class CaptainHealthSnapshotService {
    static let shared = CaptainHealthSnapshotService()

    private let healthStore: HKHealthStore
    private let calendar: Calendar
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CaptainIntelligenceManager"
    )

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        calendar: Calendar = .current
    ) {
        self.healthStore = healthStore
        self.calendar = calendar
    }

    // MARK: - Public API

    /// Requests only the required HealthKit read permissions for Captain chat.
    func requestHealthPermissions() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw CaptainIntelligenceError.healthKitUnavailable
        }

        let readTypes = try requiredReadTypes()
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)

        let hasAnyAuthorizedType = readTypes.contains {
            healthStore.authorizationStatus(for: $0) == .sharingAuthorized
        }
        guard hasAnyAuthorizedType else {
            throw CaptainIntelligenceError.healthAuthorizationDenied
        }
    }

    /// Fetches today's essential HealthKit metrics locally.
    /// Each individual query is guarded by a 2-second timeout to prevent hanging continuations.
    func fetchTodayEssentialMetrics() async throws -> CaptainDailyHealthMetrics {
        try await requestHealthPermissions()

        let todayInterval = todayDateInterval()

        async let stepsValue = withHealthKitTimeout(fallback: 0.0) { [self] in
            try await fetchCumulativeQuantity(
                .stepCount,
                unit: .count(),
                interval: todayInterval
            )
        }
        async let activeEnergyValue = withHealthKitTimeout(fallback: 0.0) { [self] in
            try await fetchCumulativeQuantity(
                .activeEnergyBurned,
                unit: .kilocalorie(),
                interval: todayInterval
            )
        }
        async let heartRateValue = withHealthKitTimeout(fallback: nil as Double?) { [self] in
            try await fetchAverageOrCurrentHeartRate(interval: todayInterval)
        }
        async let sleepValue = withHealthKitTimeout(fallback: 0.0) { [self] in
            try await fetchSleepHoursAttributedToToday()
        }

        return await CaptainDailyHealthMetrics(
            stepCount: max(0, Int(stepsValue.rounded())),
            activeEnergyKilocalories: max(0, Int(activeEnergyValue.rounded())),
            averageOrCurrentHeartRateBPM: heartRateValue.map { max(0, Int($0.rounded())) },
            sleepHours: max(0, sleepValue)
        )
    }

    // MARK: - Context Builder (defensive: all vitals bucketed before interpolation)

    func buildContextPrompt(
        userInput: String,
        metrics: CaptainDailyHealthMetrics
    ) async -> String {
        let heartRateText = bucketedHeartRate(metrics.averageOrCurrentHeartRateBPM)
        let sleepText = bucketedSleep(metrics.sleepHours)
        let runtimeContext = await runtimeContextSummary()

        return """
        \(runtimeContext)

        User health snapshot from Apple Health (today, fully local on-device):
        - Step Count: \(bucketed(steps: metrics.stepCount))
        - Active Energy Burned: \(bucketed(calories: metrics.activeEnergyKilocalories)) kcal
        - Heart Rate (average/current): \(heartRateText)
        - Sleep Analysis (today): \(sleepText) hours

        User asks: "\(userInput)"

        Respond as Captain Hamoudi with:
        1) A short motivational opener.
        2) 2-4 practical next actions for the next few hours.
        3) A simple measurable checkpoint to follow up on today.
        Keep it concise and specific.
        """
    }

    func buildContextPromptWithoutHealthData(userInput: String) async -> String {
        let runtimeContext = await runtimeContextSummary()

        return """
        \(runtimeContext)

        User health snapshot from Apple Health is currently unavailable for this request.

        User asks: "\(userInput)"

        Respond as Captain Hamoudi with:
        1) A short motivational opener.
        2) 2-4 practical next actions for the next few hours.
        3) A simple measurable checkpoint to follow up on today.
        Keep it concise and specific.
        """
    }

    private func runtimeContextSummary() async -> String {
        let systemContext = await CaptainContextBuilder.shared.buildSystemContext()

        return """
        AiQo runtime telemetry:
        - Stage: \(systemContext.stageNumber) (\(systemContext.stageTitle))
        - Time of day: \(systemContext.timeOfDay)
        - My Vibe: \(systemContext.vibeTitle)
        """
    }

    private func bucketed(steps: Int) -> Int { (max(0, steps) / 500) * 500 }
    private func bucketed(calories: Int) -> Int { (max(0, calories) / 10) * 10 }
    private func bucketedHeartRate(_ heartRate: Int?) -> String {
        guard let hr = heartRate else { return "Not available" }
        return "\((max(0, hr) / 5) * 5) bpm"
    }
    private func bucketedSleep(_ hours: Double) -> String {
        let clamped = max(0, hours)
        return String(format: "%.1f", ((clamped * 2).rounded() / 2))
    }

    // MARK: - On-Device AI (used by HandsFreeZone2Manager)

    func generateOnDeviceReply(prompt: String, instructions: String) async throws -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try validateOnDeviceModelAvailability()
            logger.notice("on_device_model_started")

            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let finalText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !finalText.isEmpty else {
                throw CaptainIntelligenceError.emptyModelResponse
            }
            logger.notice("on_device_model_succeeded")
            return finalText
        }
#endif
        throw CaptainIntelligenceError.foundationModelsUnavailable
    }

#if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func validateOnDeviceModelAvailability() throws {
        let model = SystemLanguageModel.default

        guard model.availability == .available else {
            throw CaptainIntelligenceError.onDeviceModelUnavailable
        }

        if !isCurrentLanguageSupported(by: model) {
            throw CaptainIntelligenceError.unsupportedDeviceLanguage
        }
    }

    @available(iOS 26.0, *)
    private func isCurrentLanguageSupported(by model: SystemLanguageModel) -> Bool {
        let currentLanguage = Locale.current.language
        if model.supportedLanguages.contains(currentLanguage) {
            return true
        }

        guard let currentLanguageCode = currentLanguage.languageCode?.identifier.lowercased() else {
            return false
        }

        return model.supportedLanguages.contains { supported in
            supported.languageCode?.identifier.lowercased() == currentLanguageCode
        }
    }
#endif

    // MARK: - HealthKit Timeout Helper

    private static let healthKitQueryTimeout: TimeInterval = 2

    /// Races a HealthKit async operation against a strict timeout. Returns the fallback on timeout.
    private func withHealthKitTimeout<T: Sendable>(
        fallback: T,
        operation: @escaping @Sendable () async throws -> T
    ) async -> T {
        do {
            return try await withThrowingTaskGroup(of: T.self) { group in
                group.addTask {
                    try await operation()
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(Self.healthKitQueryTimeout * 1_000_000_000))
                    return fallback
                }

                guard let result = try await group.next() else {
                    return fallback
                }
                group.cancelAll()
                return result
            }
        } catch {
            return fallback
        }
    }

    // MARK: - HealthKit Query Helpers

    private func requiredReadTypes() throws -> Set<HKObjectType> {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw CaptainIntelligenceError.missingHealthType(HKQuantityTypeIdentifier.stepCount.rawValue)
        }
        guard let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw CaptainIntelligenceError.missingHealthType(HKQuantityTypeIdentifier.activeEnergyBurned.rawValue)
        }
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw CaptainIntelligenceError.missingHealthType(HKQuantityTypeIdentifier.heartRate.rawValue)
        }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw CaptainIntelligenceError.missingHealthType(HKCategoryTypeIdentifier.sleepAnalysis.rawValue)
        }

        return [stepType, activeEnergyType, heartRateType, sleepType]
    }

    private func fetchCumulativeQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        interval: DateInterval
    ) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw CaptainIntelligenceError.missingHealthType(identifier.rawValue)
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    private func fetchAverageOrCurrentHeartRate(interval: DateInterval) async throws -> Double? {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw CaptainIntelligenceError.missingHealthType(HKQuantityTypeIdentifier.heartRate.rawValue)
        }

        let unit = HKUnit.count().unitDivided(by: .minute())
        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: .strictStartDate
        )

        let average: Double? = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Double?, Error>) in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let averageValue = statistics?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: averageValue)
            }
            healthStore.execute(query)
        }

        if let average, average > 0 {
            return average
        }

        return try await fetchLatestHeartRate(unit: unit, interval: interval)
    }

    private func fetchLatestHeartRate(unit: HKUnit, interval: DateInterval) async throws -> Double? {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw CaptainIntelligenceError.missingHealthType(HKQuantityTypeIdentifier.heartRate.rawValue)
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: .strictStartDate
        )

        let sortDescriptors = [
            NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        ]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let sample = (samples as? [HKQuantitySample])?.first
                continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
            }

            healthStore.execute(query)
        }
    }

    private func fetchSleepHoursAttributedToToday() async throws -> Double {
        await SleepSessionProvider.shared.lastNightSession().totalAsleepHours
    }

    private func todayDateInterval(now: Date = Date()) -> DateInterval {
        let dayStart = calendar.startOfDay(for: now)
        return DateInterval(start: dayStart, end: max(now, dayStart.addingTimeInterval(1)))
    }
}
