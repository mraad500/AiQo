import Foundation
import HealthKit

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

/// Privacy-first, fully local manager for Captain Hamoudi:
/// - Reads HealthKit data on-device
/// - Generates coaching text with Apple on-device language models
/// - Never performs network requests
final class CaptainIntelligenceManager {
    static let shared = CaptainIntelligenceManager()

    private let healthStore: HKHealthStore
    private let calendar: Calendar

    private let captainInstructions = """
    You are Captain Hamoudi, an Iraqi VIP fitness coach.
    Speak with a motivational, practical, and slightly youthful tone.
    Give concise, actionable next steps.
    Keep advice safe and avoid diagnosis, prescriptions, or claims of medical certainty.
    Reply in the same language as the user's message when possible.
    """

    init(healthStore: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
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
    func fetchTodayEssentialMetrics() async throws -> CaptainDailyHealthMetrics {
        try await requestHealthPermissions()

        let todayInterval = todayDateInterval()

        async let stepsValue = fetchCumulativeQuantity(
            .stepCount,
            unit: .count(),
            interval: todayInterval
        )
        async let activeEnergyValue = fetchCumulativeQuantity(
            .activeEnergyBurned,
            unit: .kilocalorie(),
            interval: todayInterval
        )
        async let heartRateValue = fetchAverageOrCurrentHeartRate(interval: todayInterval)
        async let sleepValue = fetchSleepHoursAttributedToToday()

        return try await CaptainDailyHealthMetrics(
            stepCount: max(0, Int(stepsValue.rounded())),
            activeEnergyKilocalories: max(0, Int(activeEnergyValue.rounded())),
            averageOrCurrentHeartRateBPM: heartRateValue.map { max(0, Int($0.rounded())) },
            sleepHours: max(0, sleepValue)
        )
    }

    /// Builds private context from local health data + user text, then runs on-device generation.
    func generateCaptainResponse(for userInput: String) async throws -> String {
        let cleanedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedInput.isEmpty else { return "" }

        let metrics = try await fetchTodayEssentialMetrics()
        let contextualPrompt = buildContextPrompt(userInput: cleanedInput, metrics: metrics)
        return try await generateOnDeviceReply(prompt: contextualPrompt)
    }

    // MARK: - Context Builder

    private func buildContextPrompt(
        userInput: String,
        metrics: CaptainDailyHealthMetrics
    ) -> String {
        let heartRateText = metrics.averageOrCurrentHeartRateBPM.map { "\($0) bpm" } ?? "Not available"
        let sleepText = String(format: "%.1f", metrics.sleepHours)

        return """
        User health snapshot from Apple Health (today, fully local on-device):
        - Step Count: \(metrics.stepCount)
        - Active Energy Burned: \(metrics.activeEnergyKilocalories) kcal
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

    // MARK: - On-Device AI

    private func generateOnDeviceReply(prompt: String) async throws -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try validateOnDeviceModelAvailability()

            let session = LanguageModelSession(instructions: captainInstructions)
            let response = try await session.respond(to: prompt)
            let finalText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !finalText.isEmpty else {
                throw CaptainIntelligenceError.emptyModelResponse
            }
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

        if !model.supportedLanguages.contains(Locale.current.language) {
            throw CaptainIntelligenceError.unsupportedDeviceLanguage
        }
    }
#endif

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
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw CaptainIntelligenceError.missingHealthType(HKCategoryTypeIdentifier.sleepAnalysis.rawValue)
        }

        let (dayStart, dayEnd) = dayBounds(for: Date())

        let extendedStart = calendar.date(byAdding: .hour, value: -18, to: dayStart) ?? dayStart
        let extendedEnd = calendar.date(byAdding: .hour, value: 6, to: dayEnd) ?? dayEnd

        let predicate = HKQuery.predicateForSamples(
            withStart: extendedStart,
            end: extendedEnd,
            options: []
        )

        let rawSamples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }

            healthStore.execute(query)
        }

        let asleepSamples = rawSamples.filter { isAsleepSample($0) }
        let seconds = asleepSamples.reduce(0.0) { partial, sample in
            let clampedStart = max(sample.startDate, dayStart)
            let clampedEnd = min(sample.endDate, dayEnd)
            guard clampedEnd > clampedStart else { return partial }
            return partial + clampedEnd.timeIntervalSince(clampedStart)
        }

        return seconds / 3600.0
    }

    private func isAsleepSample(_ sample: HKCategorySample) -> Bool {
        if #available(iOS 16.0, *) {
            return sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        } else {
            return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
        }
    }

    private func todayDateInterval(now: Date = Date()) -> DateInterval {
        let dayStart = calendar.startOfDay(for: now)
        return DateInterval(start: dayStart, end: max(now, dayStart.addingTimeInterval(1)))
    }

    private func dayBounds(for date: Date) -> (Date, Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return (start, end)
    }
}
