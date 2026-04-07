import Foundation
import HealthKit
import os.log

#if canImport(FoundationModels)
import FoundationModels
#endif

enum CaptainOnDeviceChatError: LocalizedError {
    case foundationModelsUnavailable
    case modelUnavailable
    case unsupportedLanguageOrLocale
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .foundationModelsUnavailable:
            return "Foundation Models are unavailable on this OS/runtime."
        case .modelUnavailable:
            return "Apple Intelligence on-device model is unavailable on this device."
        case .unsupportedLanguageOrLocale:
            return "The current device language or locale is unsupported by the on-device model."
        case .emptyResponse:
            return "The on-device model returned an empty response."
        }
    }
}

actor CaptainOnDeviceChatEngine {
    private struct LiveHealthContext: Sendable {
        let currentSteps: Int
        let currentHeartRateBPM: Int
        let currentCalories: Int
        let currentSleepHours: Double
        let currentWaterLiters: Double
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CaptainOnDeviceChat"
    )
    private let healthService: HealthKitService

    init(
        healthService: HealthKitService = .shared
    ) {
        self.healthService = healthService
    }

    func respond(to userInput: String) async throws -> String {
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return "" }

#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.availability == .available else {
                throw CaptainOnDeviceChatError.modelUnavailable
            }

            let liveContext = await fetchLiveHealthContext()
            let instructions = buildDynamicSystemPrompt(with: liveContext)

            #if DEBUG
            Swift.print("--- AIQO DEBUG: Live Data - Steps: \(liveContext.currentSteps) ---")
            Swift.print("--- AIQO DEBUG: Live Data - HR: \(liveContext.currentHeartRateBPM) Calories: \(liveContext.currentCalories) ---")
            #endif
            logger.notice("captain_on_device_started")

            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: trimmedInput)
                let rawResponse = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanText = rawResponse.replacingOccurrences(of: "*", with: "")
                let finalText = enforceStrictIraqiDialect(
                    in: cleanText
                )

                guard !finalText.isEmpty else {
                    throw CaptainOnDeviceChatError.emptyResponse
                }

                logger.notice("captain_on_device_succeeded")
                return finalText
            } catch let generationError as LanguageModelSession.GenerationError {
                switch generationError {
                case .unsupportedLanguageOrLocale:
                    throw CaptainOnDeviceChatError.unsupportedLanguageOrLocale
                default:
                    logger.error(
                        "captain_on_device_generation_failed category=\(String(describing: generationError), privacy: .public)"
                    )
                    throw generationError
                }
            } catch {
                logger.error("captain_on_device_failed error=\(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
#endif

        throw CaptainOnDeviceChatError.foundationModelsUnavailable
    }

    private func buildDynamicSystemPrompt(with context: LiveHealthContext) -> String {
        return """
        You are Captain Hammoudi, the elite Iraqi AI guide inside 'AiQo'.

        IDENTITY:
        - You are the spiritual + tactical guide of a Bio-Digital OS (real-life RPG).
        - You are grounded, calm, and deeply integrated into the app's actual features.

        AiQo UNIVERSE (ACTUAL CAPABILITIES - ONLY CLAIM THESE):
        - General: AiQo is a Bio-Digital OS. Core philosophy is "Ego-Reset" and shifting from "I" to "We".
        - The Gym (النادي): Focuses on Zone 2 cardio, live pacing, hands-free coaching, and structured training sessions.
        - My Vibe (الصوتيات/الترددات): The audio state-management layer (Awakening, Ego-Death/Zen, Focus) using AiQo sounds or Spotify.
        - The Kitchen (المطبخ): Meal planning, tracking fridge inventory locally, and organizing clean eating (Do NOT claim autonomous AI camera vision yet).
        - The Tribe (القبيلة): Shared energy, sparks, and galaxy metaphors. No toxic leaderboards.

        DIALECT RULES (CRITICAL):
        - Speak ONLY in pure, natural Iraqi Arabic (masculine).
        - Allowed words: شلونك، يا بطل، هسه، عوف، هيج، عاشت ايدك، يمعود.
        - Forbidden: أتم مستوى، نهاديك، عزيزي، إيه، زي، فصحى رسمية.

        RESPONSE CONTRACT:
        - Default: 2–4 short lines.
        - End with ONE direct question to keep the flow.
        - NEVER invent stats. Use ONLY the live data provided.
        - DO NOT repeat phrases like "ما واصلني" repeatedly.

        --- LIVE USER DATA ---
        Steps: \(context.currentSteps)
        Heart Rate: \(context.currentHeartRateBPM) bpm
        Calories: \(context.currentCalories) kcal
        Sleep: \(String(format: "%.1f", context.currentSleepHours)) h
        Water: \(String(format: "%.1f", context.currentWaterLiters)) L

        FEW-SHOT EXAMPLES (IMITATE EXACTLY):
        User: هلاو
        Captain: هلا يا بطل. شلونك هسه؟ نريد اليوم Ego-Reset بـ My Vibe لو نمشي Zone 2 بهدوء؟ شنو هدفك؟

        User: شنو هو تطبيق ايكو؟
        Captain: ايكو مو تطبيق عادي، هذا Bio-Digital OS لجسمك وروحك. نسوي Ego-Reset، نمشي Zone 2 بالنادي، ونبني طاقة القبيلة. منين تحب نبدي؟

        User: مطبخ
        Captain: عاشت ايدك. المطبخ جاهز حتى نرتب خطة وجباتك ونتابع الثلاجة خطوة بخطوة. تحب نضيف وجبة جديدة هسه؟

        User: خطواتي شكد؟
        Captain: دا اشوفك واصل \(context.currentSteps) خطوة، ونبضك \(context.currentHeartRateBPM) — ممتاز جداً. تريد أطلعلك هدف خطوات لهاليوم لو نسوي تنفّس دقيقتين؟
        """
    }

    private func fetchLiveHealthContext() async -> LiveHealthContext {
        let hasAuthorization = await ensureHealthAuthorization()
        guard hasAuthorization else {
            return LiveHealthContext(
                currentSteps: 0,
                currentHeartRateBPM: 0,
                currentCalories: 0,
                currentSleepHours: 0.0,
                currentWaterLiters: 0.0
            )
        }

        async let summaryTask = fetchTodaySummary()
        async let heartRateTask = fetchCurrentHeartRateBPM()

        let summary = await summaryTask
        let heartRate = await heartRateTask
        let waterLiters = summary.waterML > 20 ? (summary.waterML / 1000.0) : summary.waterML

        return LiveHealthContext(
            currentSteps: max(0, Int(summary.steps.rounded())),
            currentHeartRateBPM: heartRate,
            currentCalories: max(0, Int(summary.activeKcal.rounded())),
            currentSleepHours: max(0, summary.sleepHours),
            currentWaterLiters: max(0, waterLiters)
        )
    }

    private func ensureHealthAuthorization() async -> Bool {
        do {
            return try await healthService.requestAuthorization()
        } catch {
            logger.error("captain_live_authorization_failed error=\(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func fetchTodaySummary() async -> TodaySummary {
        do {
            return try await healthService.fetchTodaySummary()
        } catch {
            logger.error("captain_live_summary_failed error=\(error.localizedDescription, privacy: .public)")
            return await .zero
        }
    }

    private func fetchCurrentHeartRateBPM() async -> Int {
        do {
            guard let sample = try await healthService.fetchMostRecentQuantitySample(for: .heartRate) else {
                return 0
            }

            let unit = HKUnit.count().unitDivided(by: .minute())
            let bpm = sample.quantity.doubleValue(for: unit)
            return max(0, Int(bpm.rounded()))
        } catch {
            logger.error("captain_live_heart_rate_failed error=\(error.localizedDescription, privacy: .public)")
            return 0
        }
    }

    private func enforceStrictIraqiDialect(in text: String) -> String {
        let replacements = [
            ("إيه", "اي"),
            ("ايه", "اي"),
            ("زي", "مثل"),
            ("عشان", "حتى"),
            ("دي", "هاي"),
            ("كده", "هيج"),
            ("هلأ", "هسه"),
            ("بدي", "أريد")
        ]

        return replacements.reduce(text) { partial, pair in
            replaceWholeWord(pair.0, with: pair.1, in: partial)
        }
    }

    private func replaceWholeWord(_ word: String, with replacement: String, in text: String) -> String {
        let pattern = "(?<!\\p{L})\(NSRegularExpression.escapedPattern(for: word))(?!\\p{L})"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }
}
