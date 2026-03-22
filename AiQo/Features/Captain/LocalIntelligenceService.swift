import Foundation

enum LocalIntelligenceServiceError: LocalizedError {
    case invalidStructuredResponse

    var errorDescription: String? {
        switch self {
        case .invalidStructuredResponse:
            return "Local intelligence produced invalid structured JSON."
        }
    }
}

private struct LocalSleepAnalysisSnapshot: Sendable {
    let totalSleep: TimeInterval
    let deepSleep: TimeInterval
    let remSleep: TimeInterval
    let coreSleep: TimeInterval
    let awakeTime: TimeInterval
}

struct LocalIntelligenceService: Sendable {
    private let healthManager: HealthKitManager
    private let sleepAgent: AppleIntelligenceSleepAgent

    init(
        healthManager: HealthKitManager = .shared,
        sleepAgent: AppleIntelligenceSleepAgent = AppleIntelligenceSleepAgent()
    ) {
        self.healthManager = healthManager
        self.sleepAgent = sleepAgent
    }

    func generateReply(request: HybridBrainRequest) async throws -> HybridBrainServiceReply {
        let response = try await structuredResponse(for: request)
        let rawText = try encode(response)

        return HybridBrainServiceReply(
            message: CaptainPersonaBuilder.sanitizeResponse(response.message),
            quickReplies: response.quickReplies,
            workoutPlan: response.workoutPlan,
            mealPlan: response.mealPlan,
            spotifyRecommendation: response.spotifyRecommendation,
            rawText: rawText
        )
    }
}

private extension LocalIntelligenceService {
    func structuredResponse(for request: HybridBrainRequest) async throws -> CaptainStructuredResponse {
        switch request.screenContext {
        case .sleepAnalysis:
            return try await makeSleepAnalysisResponse()
        case .myVibe:
            return CaptainStructuredResponse(
                message: localizedMessage(
                    language: request.language,
                    arabic: "مودك يحتاج تثبيت هادئ. خذ نفس عميق، مي، وخمس دقايق حركة خفيفة.",
                    english: "Your state needs a calmer baseline. Take a deep breath, water, and five minutes of light movement."
                )
            )
        case .mainChat:
            return CaptainStructuredResponse(
                message: localizedMessage(
                    language: request.language,
                    arabic: "هسه نمشيها ببساطة: ثبت خطوتك الجاية حسب طاقتك الحالية \(request.contextData.steps) خطوة و\(request.contextData.calories) سعرة فعالة.",
                    english: "Keep the next move simple: anchor it to your current output of \(request.contextData.steps) steps and \(request.contextData.calories) active calories."
                )
            )
        case .gym, .kitchen, .peaks:
            return CaptainStructuredResponse(
                message: localizedMessage(
                    language: request.language,
                    arabic: "هذا الطلب بقى محلياً حفاظاً على الخصوصية. إذا تريد خطة أوسع، أرسل طلب عام بدون تفاصيل شخصية.",
                    english: "This request stayed on-device for privacy. If you want a broader plan, send a generic prompt without personal details."
                )
            )
        }
    }

    func makeSleepAnalysisResponse() async throws -> CaptainStructuredResponse {
        _ = try await healthManager.requestSleepAuthorizationIfNeeded()
        let stages = try await healthManager.fetchSleepStagesForLastNight()

        guard let snapshot = sleepSnapshot(from: stages) else {
            return CaptainStructuredResponse(message: missingSleepDataMessage())
        }

        return CaptainStructuredResponse(
            message: try await sleepAgent.analyze(
                session: SleepSession(
                    totalSleep: snapshot.totalSleep,
                    deepSleep: snapshot.deepSleep,
                    remSleep: snapshot.remSleep,
                    coreSleep: snapshot.coreSleep,
                    awake: snapshot.awakeTime
                )
            )
        )
    }

    func encode(_ response: CaptainStructuredResponse) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(response)

        guard let rawText = String(data: data, encoding: .utf8) else {
            throw LocalIntelligenceServiceError.invalidStructuredResponse
        }

        return rawText
    }

    func sleepSnapshot(from stages: [SleepStageData]) -> LocalSleepAnalysisSnapshot? {
        guard !stages.isEmpty else {
            return nil
        }

        var deepSleep: TimeInterval = 0
        var remSleep: TimeInterval = 0
        var coreSleep: TimeInterval = 0
        var awakeTime: TimeInterval = 0

        for stage in stages {
            switch stage.stage {
            case .deep:
                deepSleep += stage.duration
            case .rem:
                remSleep += stage.duration
            case .core:
                coreSleep += stage.duration
            case .awake:
                awakeTime += stage.duration
            }
        }

        let totalSleep = deepSleep + remSleep + coreSleep
        guard totalSleep > 0 else { return nil }

        return LocalSleepAnalysisSnapshot(
            totalSleep: totalSleep,
            deepSleep: deepSleep,
            remSleep: remSleep,
            coreSleep: coreSleep,
            awakeTime: awakeTime
        )
    }

    func missingSleepDataMessage() -> String {
        [
            "هلا بطل.. حاولت أقرا نومك البارحة بس ما لكيت بيانات مراحل نوم كافية.",
            "",
            "نصيحتي اليوم: خذ شمس أول ما تكعد، اشرب مي، وثبّت وقت نومك الليلة حتى أطلعلك تحليل أدق."
        ].joined(separator: "\n")
    }

    func localizedMessage(language: AppLanguage, arabic: String, english: String) -> String {
        language == .english ? english : arabic
    }
}
