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
    case arabicAPIConfigurationMissing
    case arabicAPIBadResponse(statusCode: Int)
    case arabicAPIInvalidResponse
    case arabicAPILocalNetworkDenied
    case arabicAPINetworkUnavailable
    case arabicAPIEmptyResponse

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
        case .arabicAPIConfigurationMissing:
            return "Captain Arabic API is not configured."
        case let .arabicAPIBadResponse(statusCode):
            return "Captain Arabic API returned status code \(statusCode)."
        case .arabicAPIInvalidResponse:
            return "Captain Arabic API returned an invalid JSON response."
        case .arabicAPILocalNetworkDenied:
            return "Captain Arabic API cannot be reached because Local Network access is denied."
        case .arabicAPINetworkUnavailable:
            return "Captain Arabic API cannot be reached because network is unavailable."
        case .arabicAPIEmptyResponse:
            return "Captain Arabic API returned an empty response."
        }
    }
}

enum CaptainResponseRoute {
    case automatic
    case arabicAPI
    case onDevice
}

/// Privacy-first manager for Captain Hamoudi:
/// - Reads HealthKit data on-device
/// - Uses external API only for Arabic responses and sends user message text only
/// - Uses Apple on-device language model for non-Arabic responses
final class CaptainIntelligenceManager {
    static let shared = CaptainIntelligenceManager()

    private let healthStore: HKHealthStore
    private let calendar: Calendar
    private let session: URLSession
    private let sanitizer = PrivacySanitizer()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CaptainIntelligenceManager"
    )
    private let stateQueue = DispatchQueue(label: "AiQo.CaptainIntelligenceManager.state")
    private var hasLoggedModelUnavailable = false
    private var lastNetworkFailureLogAt: Date?

    private let captainInstructions = CaptainPersonaBuilder.buildInstructions()

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        calendar: Calendar = .current,
        session: URLSession = .shared
    ) {
        self.healthStore = healthStore
        self.calendar = calendar
        self.session = session
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

    /// Builds private context from local health data + user text, then runs route-aware generation.
    func generateCaptainResponse(for userInput: String) async throws -> String {
        try await generateCaptainResponse(
            for: userInput,
            forcedRoute: .automatic,
            contextOverride: nil
        )
    }

    /// Route-aware generation path used by Kitchen module.
    func generateCaptainResponse(
        for userInput: String,
        forcedRoute: CaptainResponseRoute,
        contextOverride: String? = nil
    ) async throws -> String {
        let cleanedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedInput.isEmpty else { return "" }
        let detectedLanguage = textContainsArabic(cleanedInput) ? "arabic" : "non_arabic"
        let routeLabel: String
        switch forcedRoute {
        case .automatic:
            routeLabel = "automatic"
        case .arabicAPI:
            routeLabel = "arabic_api"
        case .onDevice:
            routeLabel = "on_device"
        }
        logger.notice(
            "input_language_detected value=\(detectedLanguage, privacy: .public) route=\(routeLabel, privacy: .public)"
        )

        switch forcedRoute {
        case .automatic:
            if textContainsArabic(cleanedInput) {
                return try await generateArabicResponseWithFallback(for: cleanedInput)
            }
            return try await generateOnDeviceResponseWithFallback(
                for: cleanedInput,
                contextOverride: contextOverride
            )

        case .arabicAPI:
            return try await generateArabicResponseWithFallback(for: cleanedInput)

        case .onDevice:
            return try await generateOnDeviceResponseWithFallback(
                for: cleanedInput,
                contextOverride: contextOverride
            )
        }
    }

    private func generateArabicResponseWithFallback(for cleanedInput: String) async throws -> String {
        do {
            return try await generateArabicAPIReply(for: cleanedInput)
        } catch {
            printGenerationFailure(error)
            return localFallbackResponse(for: cleanedInput, error: error)
        }
    }

    private func generateOnDeviceResponseWithFallback(
        for cleanedInput: String,
        contextOverride: String?
    ) async throws -> String {
        if let override = contextOverride?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            do {
                return try await generateOnDeviceReply(prompt: override)
            } catch {
                printGenerationFailure(error)
                return localFallbackResponse(for: cleanedInput, error: error)
            }
        }

        if let preflightError = preflightOnDeviceModelError() {
            printGenerationFailure(preflightError)
            return localFallbackResponse(for: cleanedInput, error: preflightError)
        }

        let contextualPrompt: String
        do {
            let metrics = try await fetchTodayEssentialMetrics()
            contextualPrompt = await buildContextPrompt(userInput: cleanedInput, metrics: metrics)
        } catch {
            if shouldContinueWithoutHealthContext(error) {
                logger.notice("health_context_unavailable using=minimal")
                contextualPrompt = await buildContextPromptWithoutHealthData(userInput: cleanedInput)
            } else {
                printGenerationFailure(error)
                return localFallbackResponse(for: cleanedInput, error: error)
            }
        }

        do {
            return try await generateOnDeviceReply(prompt: contextualPrompt)
        } catch {
            printGenerationFailure(error)
            return localFallbackResponse(for: cleanedInput, error: error)
        }
    }

    // MARK: - Arabic API

    private struct CaptainArabicAPIConfiguration {
        let endpointURL: URL
    }

    private struct CaptainArabicAPIRequest: Encodable {
        let text: String
    }

    private struct CaptainArabicAPIResponse: Decodable {
        let reply: String

        private enum CodingKeys: String, CodingKey {
            case reply
        }
    }

    private func generateArabicAPIReply(for userInput: String) async throws -> String {
        try await AICloudConsentGate.requireConsent()

        let configuration = try arabicAPIConfiguration()

        let sanitizedText = sanitizer.sanitizeText(
            userInput,
            knownUserName: arabicAPIUserFirstName()
        )

        var request = URLRequest(url: configuration.endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CaptainArabicAPIRequest(text: sanitizedText))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if isLocalNetworkDenied(error) {
                throw CaptainIntelligenceError.arabicAPILocalNetworkDenied
            }
            if isNetworkUnavailable(error) {
                throw CaptainIntelligenceError.arabicAPINetworkUnavailable
            }
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CaptainIntelligenceError.arabicAPIBadResponse(statusCode: -1)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            logger.error(
                "arabic_api_failed category=bad_status code=\(httpResponse.statusCode, privacy: .public)"
            )
            throw CaptainIntelligenceError.arabicAPIBadResponse(statusCode: httpResponse.statusCode)
        }

        let reply = try decodeCaptainArabicAPIResponse(from: data)
        guard !reply.isEmpty else { throw CaptainIntelligenceError.arabicAPIEmptyResponse }
        return reply
    }

    private func arabicAPIUserFirstName() -> String? {
        let raw = UserProfileStore.shared.current.name
            .components(separatedBy: " ")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return raw
    }

    private func arabicAPIConfiguration() throws -> CaptainArabicAPIConfiguration {
        let info = Bundle.main.infoDictionary ?? [:]

        if let explicitURLString = configValue(for: "CAPTAIN_ARABIC_API_URL", in: info),
           let explicitURL = validHTTPURL(from: explicitURLString) {
            return CaptainArabicAPIConfiguration(endpointURL: explicitURL)
        }

#if targetEnvironment(simulator)
        guard let simulatorURL = URL(string: "http://localhost:3000/captain-ar") else {
            throw CaptainIntelligenceError.arabicAPIConfigurationMissing
        }
        return CaptainArabicAPIConfiguration(endpointURL: simulatorURL)
#else
        if let deviceURLString = configValue(for: "CAPTAIN_ARABIC_API_DEVICE_URL", in: info),
           let deviceURL = validHTTPURL(from: deviceURLString) {
            return CaptainArabicAPIConfiguration(endpointURL: deviceURL)
        }
        throw CaptainIntelligenceError.arabicAPIConfigurationMissing
#endif
    }

    private func configValue(for key: String, in info: [String: Any]) -> String? {
        let environment = ProcessInfo.processInfo.environment
        if let fromEnvironment = normalizedConfigValue(environment[key]) {
            return fromEnvironment
        }

        return nonEmptyInfoValue(for: key, in: info)
    }

    private func nonEmptyInfoValue(for key: String, in info: [String: Any]) -> String? {
        normalizedConfigValue(info[key] as? String)
    }

    private func normalizedConfigValue(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        guard !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) else { return nil }
        guard !trimmed.lowercased().hasPrefix("curl ") else { return nil }
        return trimmed
    }

    private func validHTTPURL(from value: String) -> URL? {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return nil
        }
        return url
    }

    private func decodeCaptainArabicAPIResponse(from data: Data) throws -> String {
        do {
            let decoded = try JSONDecoder().decode(CaptainArabicAPIResponse.self, from: data)
            let trimmed = decoded.reply.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                logger.error("arabic_api_failed category=empty_reply")
                throw CaptainIntelligenceError.arabicAPIEmptyResponse
            }
            return trimmed
        } catch {
            if let captainError = error as? CaptainIntelligenceError {
                throw captainError
            }

            logger.error("arabic_api_failed category=invalid_json")
            throw CaptainIntelligenceError.arabicAPIInvalidResponse
        }
    }

    private func isLocalNetworkDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        let lowercasedDescription = nsError.localizedDescription.lowercased()
        if lowercasedDescription.contains("local network prohibited") {
            return true
        }

        let pathKey = "_NSURLErrorNWPathKey"
        if let pathValue = nsError.userInfo[pathKey] {
            let pathDescription = String(describing: pathValue).lowercased()
            if pathDescription.contains("local network prohibited") {
                return true
            }
        }

        if let failureReason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String,
           failureReason.lowercased().contains("local network prohibited") {
            return true
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isLocalNetworkDenied(underlying)
        }

        return false
    }

    private func isNetworkUnavailable(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorTimedOut,
                 NSURLErrorNetworkConnectionLost:
                return true
            default:
                break
            }
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isNetworkUnavailable(underlying)
        }

        return false
    }

    // MARK: - Context Builder

    private func buildContextPrompt(
        userInput: String,
        metrics: CaptainDailyHealthMetrics
    ) async -> String {
        let heartRateText = metrics.averageOrCurrentHeartRateBPM.map { "\($0) bpm" } ?? "Not available"
        let sleepText = String(format: "%.1f", metrics.sleepHours)
        let runtimeContext = await runtimeContextSummary()

        return """
        \(runtimeContext)

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

    private func buildContextPromptWithoutHealthData(userInput: String) async -> String {
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

    private func shouldContinueWithoutHealthContext(_ error: Error) -> Bool {
        if let captainError = error as? CaptainIntelligenceError {
            switch captainError {
            case .healthKitUnavailable, .healthAuthorizationDenied, .missingHealthType:
                return true
            default:
                break
            }
        }

        let nsError = error as NSError
        if nsError.domain == HKErrorDomain {
            return true
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return shouldContinueWithoutHealthContext(underlying)
        }

        return false
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

    private func printGenerationFailure(_ error: Error) {
        if isNetworkUnavailable(error) {
            guard consumeNetworkFailureLogPermit() else { return }
            logger.error("generation_failed category=network")
            return
        }

        if let captainError = error as? CaptainIntelligenceError {
            switch captainError {
            case .onDeviceModelUnavailable, .foundationModelsUnavailable, .unsupportedDeviceLanguage:
                guard consumeModelUnavailableLogPermit() else { return }
            default:
                break
            }
        }

        let category = self.generationErrorCategory(error)
        logger.error("generation_failed category=\(category, privacy: .public)")
    }

    private func consumeNetworkFailureLogPermit() -> Bool {
        stateQueue.sync {
            let now = Date()
            if let last = lastNetworkFailureLogAt, now.timeIntervalSince(last) < 20 {
                return false
            }
            lastNetworkFailureLogAt = now
            return true
        }
    }

    private func localFallbackResponse(for userInput: String, error: Error?) -> String {
        let prefersArabic = textContainsArabic(userInput)

        if let captainError = error as? CaptainIntelligenceError {
            switch captainError {
            case .healthAuthorizationDenied:
                return prefersArabic
                    ? CaptainFallbackPolicy.arabicOnDeviceFallback(for: userInput, translatedFallback: nil)
                    : CaptainFallbackPolicy.englishOnDeviceFallback(for: userInput)
            case .unsupportedDeviceLanguage:
                return prefersArabic
                    ? CaptainFallbackPolicy.arabicOnDeviceFallback(for: userInput, translatedFallback: nil)
                    : CaptainFallbackPolicy.englishOnDeviceFallback(for: userInput)
            case .onDeviceModelUnavailable, .foundationModelsUnavailable, .emptyModelResponse:
                return prefersArabic
                    ? CaptainFallbackPolicy.arabicOnDeviceFallback(for: userInput, translatedFallback: nil)
                    : CaptainFallbackPolicy.englishOnDeviceFallback(for: userInput)
            case .arabicAPIConfigurationMissing:
                return prefersArabic
                    ? "ضبط Captain API للعربي مو كامل. على المحاكي استخدم localhost، وعلى الجهاز الحقيقي حدد CAPTAIN_ARABIC_API_URL بعنوان Mac."
                    : "Captain Arabic API is not configured. Use localhost on Simulator and set CAPTAIN_ARABIC_API_URL to your Mac LAN URL on device."
            case let .arabicAPIBadResponse(statusCode):
                return prefersArabic
                    ? "خادم كابتن العربي ما رد بشكل صحيح (خطأ \(statusCode)). جرّب بعد شوي."
                    : "Captain Arabic API returned an invalid response (\(statusCode)). Please try again shortly."
            case .arabicAPIInvalidResponse:
                return prefersArabic
                    ? "وصل رد غير متوقع من خادم كابتن العربي. تأكد من أن الاستجابة بصيغة JSON وتحتوي reply."
                    : "Captain Arabic API returned unexpected JSON. Ensure response includes a `reply` field."
            case .arabicAPILocalNetworkDenied:
                return prefersArabic
                    ? "ما أقدر أوصل لخادم الكابتن لأن صلاحية الشبكة المحلية مقفولة. افتح: Settings > Privacy & Security > Local Network وفعّل AiQo."
                    : "Captain backend is blocked by Local Network permission. Open Settings > Privacy & Security > Local Network and enable AiQo."
            case .arabicAPINetworkUnavailable:
                return prefersArabic
                    ? "الاتصال بالشبكة غير متوفر حالياً، فما قدرت أوصل لخادم الكابتن. تأكد من نفس Wi-Fi وجرب مرة ثانية."
                    : "Network is unavailable, so Captain backend could not be reached. Make sure both devices are on the same Wi-Fi and try again."
            case .arabicAPIEmptyResponse:
                return prefersArabic
                    ? "وصل رد فارغ من Captain API. اكتبلي رسالتك مرة ثانية."
                    : "Captain API returned an empty reply. Please send your message again."
            default:
                break
            }
        }

        return prefersArabic
            ? CaptainFallbackPolicy.arabicOnDeviceFallback(for: userInput, translatedFallback: nil)
            : CaptainFallbackPolicy.englishOnDeviceFallback(for: userInput)
    }

    private func textContainsArabic(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0600...0x06FF,
                 0x0750...0x077F,
                 0x0870...0x089F,
                 0x08A0...0x08FF,
                 0xFB50...0xFDFF,
                 0xFE70...0xFEFF:
                return true
            default:
                return false
            }
        }
    }

    private func preflightOnDeviceModelError() -> CaptainIntelligenceError? {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            if model.availability != .available {
                if consumeModelUnavailableLogPermit() {
                    logger.error(
                        "on_device_model_unavailable availability=\(String(describing: model.availability), privacy: .public) locale=\(Locale.current.identifier, privacy: .public)"
                    )
                }
                return .onDeviceModelUnavailable
            }
            if !isCurrentLanguageSupported(by: model) {
                return .unsupportedDeviceLanguage
            }
            return nil
        }
#endif
        return .foundationModelsUnavailable
    }

    private func consumeModelUnavailableLogPermit() -> Bool {
        stateQueue.sync {
            if hasLoggedModelUnavailable {
                return false
            }
            hasLoggedModelUnavailable = true
            return true
        }
    }

    // MARK: - On-Device AI

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

    private func generateOnDeviceReply(prompt: String) async throws -> String {
        try await generateOnDeviceReply(
            prompt: prompt,
            instructions: captainInstructions
        )
    }

    private func generationErrorCategory(_ error: Error) -> String {
        if let captainError = error as? CaptainIntelligenceError {
            switch captainError {
            case .healthKitUnavailable:
                return "healthkit_unavailable"
            case .healthAuthorizationDenied:
                return "health_permission_denied"
            case .missingHealthType:
                return "missing_health_type"
            case .foundationModelsUnavailable:
                return "foundation_models_unavailable"
            case .onDeviceModelUnavailable:
                return "model_unavailable"
            case .unsupportedDeviceLanguage:
                return "unsupported_language"
            case .emptyModelResponse:
                return "empty_model_response"
            case .arabicAPIConfigurationMissing:
                return "arabic_api_configuration_missing"
            case .arabicAPIBadResponse:
                return "arabic_api_bad_status"
            case .arabicAPIInvalidResponse:
                return "arabic_api_invalid_response"
            case .arabicAPILocalNetworkDenied:
                return "arabic_api_local_network_denied"
            case .arabicAPINetworkUnavailable:
                return "arabic_api_network_unavailable"
            case .arabicAPIEmptyResponse:
                return "arabic_api_empty_response"
            }
        }

        if error is URLError {
            return "network"
        }

        return "other"
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
#endif

#if canImport(FoundationModels)
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

    /// Maximum time to wait for a single HealthKit query before returning a default or throwing.
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

    private func dayBounds(for date: Date) -> (Date, Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return (start, end)
    }
}
