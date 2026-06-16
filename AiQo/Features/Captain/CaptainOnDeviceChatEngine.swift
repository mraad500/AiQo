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

/// The FREE-tier Captain. Every reply is generated fully ON-DEVICE via Apple
/// Intelligence (Foundation Models) — no cloud, no server cost, uncapped.
///
/// What makes the free Captain feel premium (not a stripped-down stub):
/// - **Multi-turn memory** — the recent conversation is folded into the prompt
///   so the Captain remembers what was just said (name, goal, the last answer)
///   instead of resetting every message.
/// - **Personalization** — it addresses the user by name and honors the tone
///   they picked (practical / caring / strict).
/// - **Grounded in REAL data** — today's live HealthKit metrics are injected,
///   and `CaptainFactGuard` rewrites any number the model invents so it can
///   never contradict the device's real readings.
/// - **Pure dynamic generation** — no templates, no canned lines; the model
///   writes fresh Iraqi Arabic each turn (proven on-device, see the Lab).
actor CaptainOnDeviceChatEngine {

    /// Who the Captain is talking to. Threaded in from the ViewModel's
    /// `customization` + resolved user name so on-device replies are personal,
    /// not generic.
    struct Persona: Sendable {
        let userName: String?
        let tone: CaptainTone
        let age: String?

        static let neutral = Persona(userName: nil, tone: .practical, age: nil)
    }

    private struct LiveHealthContext: Sendable {
        let currentSteps: Int
        let currentHeartRateBPM: Int
        let currentCalories: Int
        let currentSleepHours: Double
        let currentWaterLiters: Double
    }

    /// Most recent turns we fold back into the prompt. Small enough to stay well
    /// inside the on-device context window and keep latency low; large enough for
    /// real conversational continuity (≈3 exchanges).
    private static let historyTurnLimit = 6

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

    // MARK: - Public API

    /// One fully dynamic, on-device reply to `userInput`, continuing the prior
    /// `history` and styled for `persona`. The reply is dialect-normalized and
    /// fact-guarded before it returns.
    func respond(
        to userInput: String,
        history: [CaptainConversationMessage] = [],
        persona: Persona = .neutral
    ) async throws -> String {
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return "" }

#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.availability == .available else {
                throw CaptainOnDeviceChatError.modelUnavailable
            }

            let liveContext = await fetchLiveHealthContext()
            let healthScreening = await MainActor.run { HealthScreeningStore.load() }
            let instructions = buildDynamicSystemPrompt(
                with: liveContext,
                healthScreening: healthScreening,
                persona: persona,
                history: history
            )

            logger.notice("captain_on_device_started history=\(history.count)")

            do {
                let finalText = try await generate(
                    instructions: instructions,
                    prompt: trimmedInput,
                    context: liveContext
                )
                guard !finalText.isEmpty else {
                    throw CaptainOnDeviceChatError.emptyResponse
                }
                logger.notice("captain_on_device_succeeded")
                return finalText
            } catch let generationError as LanguageModelSession.GenerationError {
                if case .unsupportedLanguageOrLocale = generationError {
                    throw CaptainOnDeviceChatError.unsupportedLanguageOrLocale
                }

                // Resilience: a long history can overflow the small on-device
                // context window. Rather than failing the whole reply, retry once
                // with the history dropped (single-turn) before giving up.
                if !history.isEmpty {
                    let slimInstructions = buildDynamicSystemPrompt(
                        with: liveContext,
                        healthScreening: healthScreening,
                        persona: persona,
                        history: []
                    )
                    if let retry = try? await generate(
                        instructions: slimInstructions,
                        prompt: trimmedInput,
                        context: liveContext
                    ), !retry.isEmpty {
                        logger.notice("captain_on_device_succeeded_history_free_retry")
                        return retry
                    }
                }

                logger.error(
                    "captain_on_device_generation_failed category=\(String(describing: generationError), privacy: .public)"
                )
                throw generationError
            } catch {
                logger.error("captain_on_device_failed error=\(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
#endif

        throw CaptainOnDeviceChatError.foundationModelsUnavailable
    }

    /// A live, on-device session-opening greeting for the FREE Captain — warm,
    /// time-aware, names the user, honors their tone, and weaves in today's REAL
    /// metrics (steps) like the cloud welcome, but generated fully on-device.
    /// Pure dynamic generation: no templates, no canned lines.
    func welcome(persona: Persona = .neutral) async throws -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.availability == .available else {
                throw CaptainOnDeviceChatError.modelUnavailable
            }

            let liveContext = await fetchLiveHealthContext()
            let healthScreening = await MainActor.run { HealthScreeningStore.load() }
            let instructions = buildDynamicSystemPrompt(
                with: liveContext,
                healthScreening: healthScreening,
                persona: persona,
                history: []
            )

            let name = (persona.userName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            // Natural opening turns — NOT a bracketed meta-instruction, which the
            // on-device model sometimes refuses or answers empty. "شخباري اليوم
            // بالخطوات؟" reliably elicits a warm greeting that cites today's real
            // steps (already injected in the system prompt). Bare "هلاو" is the
            // safety net; whichever yields non-empty first wins.
            let openers = name.isEmpty
                ? ["هلاو كابتن، شخباري اليوم بالخطوات؟", "هلاو"]
                : ["هلاو كابتن، آني \(name). شخباري اليوم بالخطوات؟", "هلاو"]

            for opener in openers {
                if let finalText = try? await generate(
                    instructions: instructions,
                    prompt: opener,
                    context: liveContext
                ), !finalText.isEmpty {
                    return finalText
                }
            }
            throw CaptainOnDeviceChatError.emptyResponse
        }
#endif
        throw CaptainOnDeviceChatError.foundationModelsUnavailable
    }

    // MARK: - Generation

#if canImport(FoundationModels)
    /// One on-device generation pass: tuned options → strip markdown → enforce
    /// Iraqi dialect → fact-guard the numbers. Returns the finished, trimmed text.
    @available(iOS 26.0, *)
    private func generate(
        instructions: String,
        prompt: String,
        context: LiveHealthContext
    ) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        // Slightly below default temperature: keeps the Iraqi voice warm and
        // varied while improving grounding (fewer invented facts) and dialect
        // consistency. The token cap keeps replies to the 2–4 line contract and
        // shaves latency on a phone.
        let options = GenerationOptions(
            sampling: nil,
            temperature: 0.7,
            maximumResponseTokens: 320
        )
        let response = try await session.respond(to: prompt, options: options)
        return finalize(response.content, context: context)
    }
#endif

    /// Cleanup pipeline applied to every raw model reply: drop markdown asterisks,
    /// normalize stray non-Iraqi words, then run the deterministic fact-guard so a
    /// hallucinated health number can never contradict the device's real reading.
    private func finalize(_ raw: String, context: LiveHealthContext) -> String {
        let stripped = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "*", with: "")
        let dialect = enforceStrictIraqiDialect(in: stripped)

        let facts = CaptainFactGuard.Facts(
            steps: context.currentSteps > 0 ? context.currentSteps : nil,
            activeCalories: context.currentCalories > 0 ? context.currentCalories : nil,
            heartRate: context.currentHeartRateBPM > 0 ? context.currentHeartRateBPM : nil
        )
        let guarded = CaptainFactGuard().corrected(dialect, facts: facts)
        return guarded.message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Prompt

    private func buildDynamicSystemPrompt(
        with context: LiveHealthContext,
        healthScreening: HealthScreeningAnswers?,
        persona: Persona,
        history: [CaptainConversationMessage]
    ) -> String {
        let healthContextLine = healthScreening?.captainContextLine ?? ""
        let healthBlock = healthContextLine.isEmpty
            ? ""
            : "\n        --- USER HEALTH CONTEXT (MANDATORY) ---\n        \(healthContextLine)\n"

        let personaBlock = buildPersonaBlock(persona)
        let historyBlock = buildHistoryBlock(history)
        let timeOfDay = currentTimeOfDayArabic()

        return """
        You are Captain Hammoudi, the elite Iraqi AI guide inside 'AiQo'.

        IDENTITY:
        - You are the spiritual + tactical guide of a Bio-Digital OS (real-life RPG).
        - You are grounded, calm, and deeply integrated into the app's actual features.
        \(personaBlock)
        AiQo UNIVERSE (ACTUAL CAPABILITIES - ONLY CLAIM THESE):
        - General: AiQo is a Bio-Digital OS. Core philosophy is "Ego-Reset" and shifting from "I" to "We".
        - The Gym (النادي): Focuses on Zone 2 cardio, live pacing, hands-free coaching, and structured training sessions.
        - My Vibe (الصوتيات/الترددات): The audio state-management layer (Awakening, Ego-Death/Zen, Focus) using AiQo sounds or Spotify.
        - The Kitchen (المطبخ): Meal planning, tracking fridge inventory locally, and organizing clean eating (Do NOT claim autonomous AI camera vision yet).
        - The Tribe (القبيلة): Shared energy, sparks, and galaxy metaphors. No toxic leaderboards.

        DIALECT RULES (CRITICAL):
        - Speak ONLY in pure, natural Iraqi Arabic (masculine).
        - Allowed words: شلونك، يا بطل، هسه، عوف، هيج، عاشت ايدك، يمعود.
        - Forbidden: أتم مستوى، نهاديك، عزيزي، إيه، زي، فصحى رسمية، مصري، شامي.

        RESPONSE CONTRACT:
        - Default: 2–4 short lines.
        - End with ONE direct question to keep the flow.
        - Continue the SAME conversation below — do NOT re-greet or restart every message.
        - Do NOT repeat a sentence or a question you already said in a previous turn.
        - NEVER invent stats. Use ONLY the live data provided.
        \(healthBlock)
        --- LIVE USER DATA (today, real) ---
        Time of day: \(timeOfDay)
        Steps: \(context.currentSteps)
        Heart Rate: \(context.currentHeartRateBPM) bpm
        Calories: \(context.currentCalories) kcal
        Sleep: \(String(format: "%.1f", context.currentSleepHours)) h
        Water: \(String(format: "%.1f", context.currentWaterLiters)) L

        FEW-SHOT STYLE EXAMPLES (imitate the VOICE only, never the content):
        User: هلاو
        Captain: هلا يا بطل. شلونك هسه؟ نريد اليوم Ego-Reset بـ My Vibe لو نمشي Zone 2 بهدوء؟ شنو هدفك؟

        User: شنو هو تطبيق ايكو؟
        Captain: ايكو مو تطبيق عادي، هذا Bio-Digital OS لجسمك وروحك. نسوي Ego-Reset، نمشي Zone 2 بالنادي، ونبني طاقة القبيلة. منين تحب نبدي؟

        User: مطبخ
        Captain: عاشت ايدك. المطبخ جاهز حتى نرتب خطة وجباتك ونتابع الثلاجة خطوة بخطوة. تحب نضيف وجبة جديدة هسه؟

        User: خطواتي شكد؟
        Captain: دا اشوفك واصل \(context.currentSteps) خطوة، ونبضك \(context.currentHeartRateBPM) — ممتاز جداً. تريد أطلعلك هدف خطوات لهاليوم لو نسوي تنفّس دقيقتين؟
        \(historyBlock)
        """
    }

    /// "Who you're talking to" block: name to address, optional age, and a tone
    /// directive mapped from the user's chosen Captain tone. Empty-safe — fields
    /// the user never filled in are simply omitted.
    private func buildPersonaBlock(_ persona: Persona) -> String {
        var lines: [String] = []

        let name = (persona.userName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            lines.append("- اسم المستخدم: \(name) — ناديه باسمه بين فترة وفترة، بدون تكلّف.")
        }

        let age = (persona.age ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !age.isEmpty {
            lines.append("- العمر: \(age).")
        }

        lines.append("- \(toneDirective(persona.tone))")

        guard !lines.isEmpty else { return "" }
        return "\n        WHO YOU'RE TALKING TO:\n        \(lines.joined(separator: "\n        "))\n"
    }

    /// Iraqi tone directive for the user's chosen Captain personality.
    private func toneDirective(_ tone: CaptainTone) -> String {
        switch tone {
        case .practical:
            return "النبرة: عملية ومباشرة — حلول واضحة بدون لف ودوران."
        case .caring:
            return "النبرة: حنونة وداعمة — شجّعه وخفّف عليه، كن سند مو ضاغط."
        case .strict:
            return "النبرة: صارمة ومحفّزة — ادفعه وما تقبل الأعذار، بس بدون قسوة جارحة."
        }
    }

    /// Renders the recent turns as a clearly-delimited "current conversation"
    /// block the model is told to CONTINUE. This is what gives the free Captain
    /// its within-session memory: a fresh session each call, but seeded with what
    /// was just said. Capped at `historyTurnLimit` to protect latency + context.
    private func buildHistoryBlock(_ history: [CaptainConversationMessage]) -> String {
        let recent = history
            .filter { $0.role == .user || $0.role == .assistant }
            .suffix(Self.historyTurnLimit)
        guard !recent.isEmpty else { return "" }

        let rendered = recent.map { message -> String in
            let speaker = message.role == .user ? "المستخدم" : "كابتن"
            let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(speaker): \(text)"
        }.joined(separator: "\n        ")

        return """

                --- المحادثة الجارية (كمّل عليها، لا تعيد التحية) ---
                \(rendered)
        """
    }

    private func currentTimeOfDayArabic() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "صباح"
        case 12..<17:
            return "ظهر/عصر"
        case 17..<22:
            return "مساء"
        default:
            return "ليل متأخر"
        }
    }

    // MARK: - Live health

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

    // MARK: - Dialect

    private func enforceStrictIraqiDialect(in text: String) -> String {
        // Conservative whole-word swaps: high-frequency Egyptian/Levantine words
        // that leak into on-device output, mapped to their Iraqi equivalents. Each
        // is matched on letter boundaries so it never corrupts a longer word.
        let replacements = [
            ("إيه", "اي"),
            ("ايه", "اي"),
            ("ايوه", "اي"),
            ("ايوة", "اي"),
            ("زي", "مثل"),
            ("عشان", "حتى"),
            ("علشان", "حتى"),
            ("دي", "هاي"),
            ("ده", "هذا"),
            ("كده", "هيج"),
            ("هلأ", "هسه"),
            ("دلوقتي", "هسه"),
            ("بدي", "أريد"),
            ("عايز", "أريد"),
            ("مش", "مو"),
            ("ليه", "ليش"),
            ("ازيك", "شلونك")
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
