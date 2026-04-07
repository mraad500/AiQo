import Foundation
import os.log

#if canImport(FoundationModels)
import FoundationModels
#endif

struct SleepSession: Sendable {
    let totalSleep: TimeInterval
    let deepSleep: TimeInterval
    let remSleep: TimeInterval
    let coreSleep: TimeInterval
    let awake: TimeInterval

    var totalMinutes: Int {
        roundedMinutes(for: totalSleep)
    }

    var deepMinutes: Int {
        roundedMinutes(for: deepSleep)
    }

    var remMinutes: Int {
        roundedMinutes(for: remSleep)
    }

    var coreMinutes: Int {
        roundedMinutes(for: coreSleep)
    }

    var awakeMinutes: Int {
        roundedMinutes(for: awake)
    }

    var deepPercentage: Double {
        percentage(for: deepSleep)
    }

    var remPercentage: Double {
        percentage(for: remSleep)
    }

    private func percentage(for duration: TimeInterval) -> Double {
        guard totalSleep > 0 else { return 0 }
        return (duration / totalSleep) * 100
    }

    private func roundedMinutes(for duration: TimeInterval) -> Int {
        max(Int((duration / 60).rounded()), 0)
    }
}

enum AppleIntelligenceSleepAgentError: LocalizedError {
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "The on-device sleep agent returned an empty response."
        }
    }
}

struct AppleIntelligenceSleepAgent: Sendable {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "AppleIntelligenceSleepAgent"
    )

    func analyze(session sleepSession: SleepSession) async throws -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default

            switch model.availability {
            case .available:
                break
            case .unavailable(let reason):
                logger.notice("sleep_agent_unavailable reason=\(String(describing: reason), privacy: .public)")
                return availabilityFallback(
                    for: sleepSession,
                    reasonDescription: String(describing: reason)
                )
            }

            let instructions = buildSystemPrompt(for: sleepSession)
            let options = GenerationOptions(
                sampling: nil,
                temperature: 1.2,
                maximumResponseTokens: 140
            )

            do {
                let modelSession = LanguageModelSession(
                    model: model,
                    instructions: instructions
                )
                let response = try await modelSession.respond(
                    to: generationTriggerPrompt,
                    options: options
                )
                let generated = sanitize(response.content)

                guard !generated.isEmpty else {
                    throw AppleIntelligenceSleepAgentError.emptyResponse
                }

                logger.notice("sleep_agent_succeeded")
                return generated
            } catch let generationError as LanguageModelSession.GenerationError {
                if case .unsupportedLanguageOrLocale = generationError {
                    logger.notice("sleep_agent_unsupported_locale")
                    return availabilityFallback(
                        for: sleepSession,
                        reasonDescription: "unsupported_language_or_locale"
                    )
                }

                logger.error(
                    "sleep_agent_generation_failed error=\(generationError.localizedDescription, privacy: .public)"
                )
                throw generationError
            } catch {
                logger.error("sleep_agent_failed error=\(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
#endif

        return availabilityFallback(
            for: sleepSession,
            reasonDescription: "foundation_models_unavailable"
        )
    }
}

private extension AppleIntelligenceSleepAgent {
    var generationTriggerPrompt: String {
        "Generate today's sleep analysis now."
    }

    func buildSystemPrompt(for session: SleepSession) -> String {
        """
        You are Hamoudi, an elite, highly intelligent, and encouraging Iraqi AI coach.

        Analyze the following sleep data:
        - Total sleep: \(session.totalMinutes) minutes
        - Deep sleep: \(session.deepMinutes) minutes (\(formattedPercentage(session.deepPercentage)) of total)
        - REM sleep: \(session.remMinutes) minutes (\(formattedPercentage(session.remPercentage)) of total)
        - Core sleep: \(session.coreMinutes) minutes
        - Awake time: \(session.awakeMinutes) minutes

        Clinical reference ranges:
        - Deep sleep is usually healthiest around 15% to 25% of total sleep.
        - REM sleep is usually healthiest around 20% to 25% of total sleep.

        Instruction:
        You are Hamoudi, an elite, highly intelligent, and encouraging Iraqi AI coach. Analyze the following sleep data: Total \(session.totalMinutes) minutes, Deep \(session.deepMinutes) minutes, REM \(session.remMinutes) minutes. Write a short, empathetic, and scientifically sound 2-sentence analysis in a natural Iraqi Arabic dialect. Focus on muscle recovery if Deep is low or high, and mental sharpness if REM is low or high. The second sentence must naturally invite the user to start "جلسة الامتنان" this morning. NEVER use canned phrases, NEVER reuse templates, NEVER sound robotic, and generate a completely unique conversational response every time.

        Output contract:
        - Exactly 2 sentences.
        - Natural Iraqi Arabic only.
        - No bullet points.
        - No emojis.
        - Mention the user's sleep quality directly and conversationally.
        - End with a natural invitation to start جلسة الامتنان.
        """
    }

    func sanitize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
    }

    func formattedPercentage(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    func availabilityFallback(
        for session: SleepSession,
        reasonDescription: String
    ) -> String {
        "حمّودي حاضر، بس Apple Intelligence المحلي مو متاح هسه على هذا الجهاز (\(reasonDescription)). نومك الكلي \(session.totalMinutes) دقيقة، وإذا تريد نكمل الجو الصباحي افتح جلسة الامتنان."
    }
}
