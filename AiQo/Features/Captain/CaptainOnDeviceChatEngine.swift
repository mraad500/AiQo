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

    /// Who the FREE Captain is talking to. Free tier = name only: it addresses
    /// the user warmly but has NO style customization (that's a Max/Pro feature)
    /// and speaks in one simple fixed voice.
    struct Persona: Sendable {
        let userName: String?

        static let neutral = Persona(userName: nil)
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

    /// A live, on-device session-opening greeting — one warm, time-aware line that
    /// names the user and weaves in today's REAL steps. Seeds the conversation
    /// session so the chat continues naturally from the greeting.
    func welcome(persona: Persona = .neutral) async throws -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureModelAvailable()
            resetConversation()

            let context = await fetchLiveHealthContext()
            let screening = await MainActor.run { HealthScreeningStore.load() }

            let name = (persona.userName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            // A fresh, data-aware opener each session — mirrors the paid welcome's
            // intent (varied phrasing, real-time aware, weaves in ONE live metric)
            // but delivered as a natural Iraqi turn the on-device model follows.
            // "هلاو" is the safety net if the rich opener returns empty. Whichever
            // yields non-empty first wins and becomes turn 1 of the live session.
            for opener in buildWelcomeOpeners(name: name, context: context) {
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

    /// Welcome opener(s): a rich, VARIED, data-aware request first (the focus
    /// metric + the phrasing both change each session, so the greeting is fresh
    /// every open), then a plain greeting as the safety net. The actual values +
    /// exact clock live in the system prompt; the opener just nudges which live
    /// metric to spotlight and that it must be time-aware and never repeat.
    private func buildWelcomeOpeners(name: String, context: LiveHealthContext) -> [String] {
        let namePart = name.isEmpty ? "" : " نادني باسمي \(name)،"

        // Spotlight ONE *available* live metric, chosen at random so the focus
        // changes each open (the real numbers are already in the system prompt).
        var hooks: [String] = []
        if context.currentSteps > 0 { hooks.append("خطواتي اليوم") }
        if context.currentSleepHours > 0 { hooks.append("نومي") }
        if context.currentWaterLiters > 0 { hooks.append("شربي للماي اليوم") }
        if context.currentCalories > 0 { hooks.append("سعراتي المحروقة اليوم") }
        let hookPart = hooks.randomElement().map { " واذكر بشكل طبيعي وخفيف \($0) من بياناتي الحقيقية،" } ?? ""

        // A few request phrasings so the opener itself varies too.
        let frames = [
            "افتح المحادثة بترحيب عراقي قصير وطازج ومختلف عن أي مرة (سطر-سطرين بس).\(namePart) كون واعي بالوقت الحقيقي الحين،\(hookPart) واختم بسؤال ودود واحد عن هدفي اليوم.",
            "رحّب بيّ ترحيب قصير وحلو يناسب الوقت الحين بالضبط.\(namePart)\(hookPart) خلّيه مختلف عن المرات السابقة، وانتهي بسؤال خفيف عن شنو أحب أسوي هسة.",
            "ابدأ بجملة ترحيب عراقية دافئة وقصيرة تناسب الساعة الحين.\(namePart)\(hookPart) نوّع كلامك كل مرة ولا تكرر، واسألني سؤال ودود واحد."
        ]
        let rich = frames.randomElement() ?? frames[0]
        let simple = name.isEmpty ? "هلاو" : "هلاو، آني \(name)."
        return [rich, simple]
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

    /// The "taste + honest invitation" behavior for the FREE chat (injected only
    /// into chat, never notifications). On a BIG ask the free Captain gives one
    /// genuine quick tip, then warmly notes the full tracked/remembered plan is a
    /// Max thing — converting on value felt, not a refusal wall. Never naggy,
    /// never a fixed line, never prices — matching AiQo's "depth not caps,
    /// no resentment" stance.
    private static let upgradeAwarenessBlock = """

        BIG ASKS (a full workout PROGRAM, a full meal/nutrition PLAN, or a deep long-term analysis):
        - First give ONE short, genuine taste — a single useful tip in your own words. NEVER write out the full program/plan.
        - Then, in ONE warm Iraqi line, say honestly that the COMPLETE personalized plan that you track with him and remember across the days is part of AiQo Max, and invite him to it.
        - Say it ONCE, warmly, never pushy, never mention prices, and vary your wording (never a fixed sentence).
        - For SIMPLE questions just answer normally and short — do NOT bring up Max.
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
        let clock = currentClockText()

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
        - Speak ONLY in pure, natural Iraqi Arabic (masculine) — the everyday casual register, like texting a friend, never formal MSA.
        - Forbidden: أتم مستوى، نهاديك، عزيزي، إيه، زي، فصحى رسمية، مصري، شامي.
        - NEVER list, recite, or stack vocabulary words — speak in full natural sentences.

        HOW YOU REPLY (CRITICAL — READ CAREFULLY):
        - You are the FREE Captain: a quick, friendly helper for simple things.
        - You are ONLY the Captain. Write ONLY the Captain's own words, nothing else.
        - NEVER write a speaker label ("Captain:", "User:", "المستخدم:", "كابتن:"), and NEVER write the user's side.
        - NEVER repeat a letter, word, phrase, or expression — do not say the same thing twice in one reply.
        - Keep replies SHORT and SIMPLE: 1–2 lines, easy everyday words, like a quick text. End with ONE short question only if it genuinely fits — otherwise none.
        - Use ONLY the real numbers below; never invent a statistic.
        \(healthBlock)\(upgradeBlock)
        --- LIVE USER DATA (today, real — these are his ACTUAL numbers right now) ---
        Current time: \(clock) — period: \(timeOfDay)
        Steps today: \(context.currentSteps)
        Heart rate: \(context.currentHeartRateBPM) bpm
        Active calories: \(context.currentCalories) kcal
        Sleep last night: \(String(format: "%.1f", context.currentSleepHours)) h
        Water today: \(String(format: "%.1f", context.currentWaterLiters)) L

        TONE: warm and relaxed, like texting a buddy who's got your back — natural and friendly, never formal, never a recited word list.
        """
    }

    /// "Who you're talking to" block — just the name (free tier has no style).
    private func buildPersonaBlock(_ persona: Persona) -> String {
        let name = (persona.userName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "" }
        return "\n        WHO YOU'RE TALKING TO:\n        - اسم المستخدم: \(name) — ناديه باسمه بين فترة وفترة، بدون تكلّف.\n"
    }

    private func currentTimeOfDayArabic() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 3..<6:   return "فجر"
        case 6..<12:  return "صباح"
        case 12..<15: return "ظهر"
        case 15..<18: return "عصر"
        case 18..<22: return "مساء"
        default:      return "ليل متأخر"
        }
    }

    /// The exact wall-clock now ("HH:mm") so the Captain is aware of the REAL
    /// current time, not just the coarse period.
    private func currentClockText() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
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
