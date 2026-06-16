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
/// Design notes (hard-won):
/// - **Memory is native.** Multi-turn context is kept by reusing ONE
///   `LanguageModelSession` per conversation and letting the framework own the
///   transcript. We do NOT stuff a hand-built "User:/Captain:" transcript into
///   the prompt — the small on-device model treats that as a script to *continue*
///   and starts emitting role labels + the user's side of the turn.
/// - **The prompt has no dialogue examples** for the same reason; dialect comes
///   from explicit rules + isolated style phrases, never completable turns.
/// - **Output is sanitized.** `OnDeviceReplySanitizer` deterministically strips
///   any leaked role label and collapses repetition loops, so even a derailed
///   generation can't reach the user as garbage.
/// - **Grounded.** Today's live HealthKit metrics are injected and
///   `CaptainFactGuard` rewrites any number that contradicts the device.
actor CaptainOnDeviceChatEngine {

    /// Who the Captain is talking to. Threaded in from the ViewModel.
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

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CaptainOnDeviceChat"
    )
    private let healthService: HealthKitService
    private let sanitizer = OnDeviceReplySanitizer()

    /// The live chat's session, kept alive so the model remembers earlier turns
    /// natively. Type-erased because `LanguageModelSession` is iOS 26+ only.
    /// `nil` until the first turn of a conversation; cleared by `resetConversation`.
    private var conversationSessionBox: AnyObject?

    init(
        healthService: HealthKitService = .shared
    ) {
        self.healthService = healthService
    }

    // MARK: - Conversation lifecycle

    /// Drop the live chat session so the next turn starts a fresh conversation
    /// (call on "new chat"). Cheap and safe to call anytime.
    func resetConversation() {
        conversationSessionBox = nil
    }

    // MARK: - Public API

    /// STATEFUL chat reply — reuses the conversation session so the Captain
    /// remembers what was said earlier in this chat. Used by the chat ViewModel.
    func respondInConversation(to userInput: String, persona: Persona = .neutral) async throws -> String {
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return "" }

#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureModelAvailable()
            let context = await fetchLiveHealthContext()
            let screening = await MainActor.run { HealthScreeningStore.load() }

            let session = conversationSession(persona: persona, context: context, screening: screening)
            logger.notice("captain_on_device_conversation_turn")

            do {
                let final = try await generate(on: session, prompt: trimmedInput, context: context)
                guard !final.isEmpty else { throw CaptainOnDeviceChatError.emptyResponse }
                return final
            } catch let generationError as LanguageModelSession.GenerationError {
                if case .unsupportedLanguageOrLocale = generationError {
                    throw CaptainOnDeviceChatError.unsupportedLanguageOrLocale
                }
                // Busy session / context overflow / transient decode: reset the
                // conversation and recover with a clean one-off generation rather
                // than failing the reply. (Memory for this single turn is lost.)
                logger.error("captain_on_device_conv_failed_recovering category=\(String(describing: generationError), privacy: .public)")
                resetConversation()
                if let recovered = try? await statelessReply(to: trimmedInput, persona: persona),
                   !recovered.isEmpty {
                    return recovered
                }
                throw generationError
            }
        }
#endif
        throw CaptainOnDeviceChatError.foundationModelsUnavailable
    }

    /// STATELESS one-off reply — a fresh session every call, no memory. Used by
    /// notification generation and the on-device lab, where cross-turn context
    /// would be wrong.
    func respond(to userInput: String, persona: Persona = .neutral) async throws -> String {
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return "" }

#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureModelAvailable()
            let final = try await statelessReply(to: trimmedInput, persona: persona)
            guard !final.isEmpty else { throw CaptainOnDeviceChatError.emptyResponse }
            return final
        }
#endif
        throw CaptainOnDeviceChatError.foundationModelsUnavailable
    }

    /// A live, on-device session-opening greeting — warm, time-aware, names the
    /// user, honors their tone, weaves in today's REAL steps. Seeds the
    /// conversation session so the chat continues naturally from the greeting.
    func welcome(persona: Persona = .neutral) async throws -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureModelAvailable()
            resetConversation()

            let context = await fetchLiveHealthContext()
            let screening = await MainActor.run { HealthScreeningStore.load() }

            let name = (persona.userName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            // Natural opening turns (not a bracketed meta-instruction, which the
            // on-device model sometimes refuses). Whichever yields non-empty first
            // wins, and that opener becomes turn 1 of the live session.
            let openers = name.isEmpty
                ? ["هلاو كابتن، شخباري اليوم بالخطوات؟", "هلاو"]
                : ["هلاو كابتن، آني \(name). شخباري اليوم بالخطوات؟", "هلاو"]

            for opener in openers {
                let session = conversationSession(persona: persona, context: context, screening: screening)
                if let greeting = try? await generate(on: session, prompt: opener, context: context),
                   !greeting.isEmpty {
                    return greeting
                }
                // Empty/failed opener — clear the polluted session before retrying.
                resetConversation()
            }
            throw CaptainOnDeviceChatError.emptyResponse
        }
#endif
        throw CaptainOnDeviceChatError.foundationModelsUnavailable
    }

    // MARK: - Generation

#if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func ensureModelAvailable() throws {
        guard SystemLanguageModel.default.availability == .available else {
            throw CaptainOnDeviceChatError.modelUnavailable
        }
    }

    /// Returns the live conversation session, creating + storing it on first use.
    @available(iOS 26.0, *)
    private func conversationSession(
        persona: Persona,
        context: LiveHealthContext,
        screening: HealthScreeningAnswers?
    ) -> LanguageModelSession {
        if let existing = conversationSessionBox as? LanguageModelSession {
            return existing
        }
        let session = LanguageModelSession(
            instructions: buildSystemPrompt(
                with: context,
                healthScreening: screening,
                persona: persona,
                allowUpgradeHint: true
            )
        )
        conversationSessionBox = session
        return session
    }

    /// One stateless generation pass on a brand-new throwaway session.
    @available(iOS 26.0, *)
    private func statelessReply(to prompt: String, persona: Persona) async throws -> String {
        let context = await fetchLiveHealthContext()
        let screening = await MainActor.run { HealthScreeningStore.load() }
        let session = LanguageModelSession(
            instructions: buildSystemPrompt(with: context, healthScreening: screening, persona: persona)
        )
        return try await generate(on: session, prompt: prompt, context: context)
    }

    /// Runs one turn on the given session with tuned options, then finalizes.
    @available(iOS 26.0, *)
    private func generate(
        on session: LanguageModelSession,
        prompt: String,
        context: LiveHealthContext
    ) async throws -> String {
        // Lower temperature = steadier dialect + far less likely to derail into a
        // repetition loop. A tight token cap bounds the 2–4 line contract and the
        // damage if it ever does loop.
        let options = GenerationOptions(
            sampling: nil,
            temperature: 0.6,
            maximumResponseTokens: 200
        )
        let response = try await session.respond(to: prompt, options: options)
        return finalize(response.content, context: context)
    }
#endif

    /// Sanitize structure → enforce Iraqi dialect → fact-guard the numbers.
    private func finalize(_ raw: String, context: LiveHealthContext) -> String {
        let cleaned = sanitizer.clean(raw)
        let dialect = enforceStrictIraqiDialect(in: cleaned)

        let facts = CaptainFactGuard.Facts(
            steps: context.currentSteps > 0 ? context.currentSteps : nil,
            activeCalories: context.currentCalories > 0 ? context.currentCalories : nil,
            heartRate: context.currentHeartRateBPM > 0 ? context.currentHeartRateBPM : nil
        )
        let guarded = CaptainFactGuard().corrected(dialect, facts: facts)
        return guarded.message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Prompt (NO dialogue examples — see type doc)

    /// Bounded, honest "what Max adds" awareness — injected ONLY into the live
    /// chat (never notifications). The free Captain may, RARELY and only when the
    /// user genuinely bumps its ceiling, note its limit + that Max goes deeper. It
    /// is told never to nag, repeat, block, or mention prices — matching AiQo's
    /// "depth not caps, no resentment" stance.
    private static let upgradeAwarenessBlock = """

        UPGRADE AWARENESS (use RARELY — only when genuinely relevant, never pushy):
        - You are the FREE on-device Captain: you remember ONLY this chat and reset between sessions; you don't build multi-week tracked plans or use the premium voice.
        - ONLY IF the user references something from an earlier session you clearly can't recall, OR asks for an ongoing tracked plan or deep long-term analysis: add ONE short, warm Iraqi line noting your limit and that AiQo Max remembers them across the days and coaches deeper. Then drop it.
        - Otherwise NEVER mention subscriptions. NEVER repeat the offer, never nag, never block, never mention prices.
        """

    private func buildSystemPrompt(
        with context: LiveHealthContext,
        healthScreening: HealthScreeningAnswers?,
        persona: Persona,
        allowUpgradeHint: Bool = false
    ) -> String {
        let healthContextLine = healthScreening?.captainContextLine ?? ""
        let healthBlock = healthContextLine.isEmpty
            ? ""
            : "\n        --- USER HEALTH CONTEXT (MANDATORY) ---\n        \(healthContextLine)\n"

        let personaBlock = buildPersonaBlock(persona)
        let upgradeBlock = allowUpgradeHint ? Self.upgradeAwarenessBlock : ""
        let timeOfDay = currentTimeOfDayArabic()

        return """
        You are Captain Hammoudi, the elite Iraqi AI guide inside 'AiQo'.

        IDENTITY:
        - You are the spiritual + tactical guide of a Bio-Digital OS (real-life RPG).
        - You are grounded, calm, and deeply integrated into the app's actual features.
        \(personaBlock)
        AiQo UNIVERSE (ACTUAL CAPABILITIES - ONLY CLAIM THESE):
        - General: AiQo is a Bio-Digital OS. Core philosophy is "Ego-Reset" and shifting from "I" to "We".
        - The Gym (النادي): Zone 2 cardio, live pacing, hands-free coaching, structured training.
        - My Vibe (الصوتيات/الترددات): audio state-management (Awakening, Ego-Death/Zen, Focus) using AiQo sounds or Spotify.
        - The Kitchen (المطبخ): meal planning + local fridge inventory + clean eating (NOT autonomous camera vision yet).
        - The Tribe (القبيلة): shared energy, sparks, galaxy metaphors. No toxic leaderboards.

        DIALECT RULES (CRITICAL):
        - Speak ONLY in pure, natural Iraqi Arabic (masculine).
        - Allowed words: شلونك، يا بطل، هسه، عوف، هيج، عاشت ايدك، يمعود.
        - Forbidden: أتم مستوى، نهاديك، عزيزي، إيه، زي، فصحى رسمية، مصري، شامي.

        HOW YOU REPLY (CRITICAL — READ CAREFULLY):
        - You are ONLY the Captain. Write ONLY the Captain's own words, nothing else.
        - NEVER write a speaker label such as "Captain:", "User:", "المستخدم:" or "كابتن:".
        - NEVER write the user's side of the conversation, and NEVER imagine their reply.
        - NEVER repeat a letter, a word, or a sentence to fill space.
        - Keep it to 2–4 short lines and end with ONE direct question.
        - Use ONLY the real numbers below; never invent a statistic.
        \(healthBlock)\(upgradeBlock)
        --- LIVE USER DATA (today, real) ---
        Time of day: \(timeOfDay)
        Steps: \(context.currentSteps)
        Heart Rate: \(context.currentHeartRateBPM) bpm
        Calories: \(context.currentCalories) kcal
        Sleep: \(String(format: "%.1f", context.currentSleepHours)) h
        Water: \(String(format: "%.1f", context.currentWaterLiters)) L

        STYLE (inspiration only — write your OWN sentence, do NOT copy these):
        نبرة دافئة عراقية مثل: "هلا يا بطل"، "شلونك هسه"، "عاشت ايدك"، "دا اشوفك واصل خطواتك زينة".
        """
    }

    /// "Who you're talking to" block — empty-safe.
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

    private func currentTimeOfDayArabic() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "صباح"
        case 12..<17: return "ظهر/عصر"
        case 17..<22: return "مساء"
        default: return "ليل متأخر"
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
        // mapped to their Iraqi equivalents, matched on letter boundaries.
        let replacements = [
            ("إيه", "اي"), ("ايه", "اي"), ("ايوه", "اي"), ("ايوة", "اي"),
            ("زي", "مثل"), ("عشان", "حتى"), ("علشان", "حتى"),
            ("دي", "هاي"), ("ده", "هذا"), ("كده", "هيج"),
            ("هلأ", "هسه"), ("دلوقتي", "هسه"), ("بدي", "أريد"),
            ("عايز", "أريد"), ("مش", "مو"), ("ليه", "ليش"), ("ازيك", "شلونك")
        ]
        return replacements.reduce(text) { partial, pair in
            replaceWholeWord(pair.0, with: pair.1, in: partial)
        }
    }

    private func replaceWholeWord(_ word: String, with replacement: String, in text: String) -> String {
        let pattern = "(?<!\\p{L})\(NSRegularExpression.escapedPattern(for: word))(?!\\p{L})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }
}
