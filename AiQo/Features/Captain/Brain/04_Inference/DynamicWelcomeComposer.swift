import Foundation
import os.log

/// Builds the hyper-personalized opening line of a fresh Captain chat session.
///
/// The static "هلا! أنا كابتن حمّودي." string is replaced by an LLM-composed
/// greeting that ingests:
///   - Time of day + precise wall-clock from `BioStateEngine.shared.current()`
///   - Live steps, calories & heart rate (when available) from the same snapshot
///   - Water intake from `HydrationService`
///   - User profile (name, gender, goal) from `UserProfileStore`
///   - User's preferred language from `AppSettingsStore`
///
/// The composer hits the cloud via `BrainOrchestrator` so the full 7-layer
/// system prompt (profile, bio, circadian tone) flows in automatically. The
/// synthetic "user" turn just instructs the model to produce a welcome — the
/// orchestrator's standard JSON output contract carries it back as `message`.
///
/// On any error (offline, consent declined, tier-gate, timeout, empty reply)
/// the caller is expected to fall back to the static greeting. This composer
/// never throws upward — the failure mode is `nil`.
@MainActor
struct DynamicWelcomeComposer {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "DynamicWelcomeComposer"
    )

    /// Wall-clock budget for the cloud call. Beyond this we drop the
    /// dynamic greeting and let the caller render the static fallback.
    private static let timeoutSeconds: TimeInterval = 7.0

    /// Returns the personalized welcome message, or `nil` if anything goes
    /// wrong (offline mode, consent missing, tier-gate, network failure,
    /// timeout, empty reply). The caller renders a static fallback in that
    /// case so the chat is never blank.
    ///
    /// `orchestrator` is captured by the caller so the same instance the
    /// `CaptainViewModel` is already holding flows through here — keeps the
    /// in-flight cloud sessions consistent and avoids re-instantiating the
    /// MainActor-isolated services the default initializer would build.
    static func compose(orchestrator: BrainOrchestrator) async -> String? {
        await compose(orchestrator: orchestrator, contextBuilder: .shared)
    }

    static func compose(
        orchestrator: BrainOrchestrator,
        contextBuilder: CaptainContextBuilder
    ) async -> String? {
        let start = Date()

        if AIDataConsentManager.shared.isInOfflineOnlyMode {
            CaptainMetricsCounter.shared.record(event: "welcome_dynamic", reason: "offline")
            logger.info("dynamic_welcome_skipped reason=offline")
            return nil
        }
        if !AIDataConsentManager.shared.hasUserConsented {
            CaptainMetricsCounter.shared.record(event: "welcome_dynamic", reason: "no_consent")
            logger.info("dynamic_welcome_skipped reason=no_consent")
            return nil
        }
        if !DevOverride.unlockAllFeatures, !TierGate.shared.canAccess(.captainChat) {
            CaptainMetricsCounter.shared.record(event: "welcome_dynamic", reason: "tier_blocked")
            logger.info("dynamic_welcome_skipped reason=tier_blocked")
            return nil
        }

        let language = AppSettingsStore.shared.appLanguage
        let profile = UserProfileStore.shared.current
        let bio = await BioStateEngine.shared.current()
        let waterML = await currentWaterMillilitres()
        let userName = preferredName(profile: profile)

        let promptText = buildInstruction(
            language: language,
            profile: profile,
            bio: bio,
            waterML: waterML,
            userName: userName
        )

        let contextData = await contextBuilder.buildContextData()
        let request = HybridBrainRequest(
            conversation: [
                CaptainConversationMessage(role: .user, content: promptText)
            ],
            screenContext: .mainChat,
            language: language,
            contextData: contextData,
            userProfileSummary: shortProfileSummary(profile: profile, preferredName: userName),
            intentSummary: "dynamic_session_welcome",
            workingMemorySummary: "",
            attachedImageData: nil
        )

        do {
            let reply = try await withTimeout(seconds: timeoutSeconds) {
                try await orchestrator.processMessage(request: request, userName: userName)
            }
            let cleaned = reply.message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                CaptainMetricsCounter.shared.record(event: "welcome_dynamic", reason: "empty")
                logger.info("dynamic_welcome_dropped reason=empty_reply")
                return nil
            }
            let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
            CaptainMetricsCounter.shared.record(
                event: "welcome_dynamic",
                reason: "succeeded",
                latencyMs: elapsedMs
            )
            return cleaned
        } catch is DynamicWelcomeTimeout {
            let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
            CaptainMetricsCounter.shared.record(
                event: "welcome_dynamic",
                reason: "timeout",
                latencyMs: elapsedMs
            )
            logger.info("dynamic_welcome_failed reason=timeout")
            return nil
        } catch {
            CaptainMetricsCounter.shared.record(event: "welcome_dynamic", reason: "error")
            logger.info("dynamic_welcome_failed error=\(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Context Helpers

    private static func currentWaterMillilitres() async -> Int {
        await HydrationService.shared.refreshState()
        return Int(HydrationService.shared.state.consumedML.rounded())
    }

    private static func preferredName(profile: UserProfile) -> String? {
        let candidates = [profile.name, profile.username]
        for raw in candidates {
            guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { continue }
            if value.hasPrefix("@") {
                value.removeFirst()
                value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let lowered = value.lowercased()
            if lowered == "captain" || lowered == "kaptain" { continue }
            return value
        }
        return nil
    }

    private static func shortProfileSummary(profile: UserProfile, preferredName: String?) -> String {
        var lines: [String] = []
        if let preferredName, !preferredName.isEmpty {
            lines.append("- Preferred name: \(preferredName)")
        }
        if let gender = profile.gender {
            lines.append("- Gender: \(gender.rawValue)")
        }
        if !profile.goalText.isEmpty {
            lines.append("- Goal: \(profile.goalText)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Prompt

    private static func buildInstruction(
        language: AppLanguage,
        profile: UserProfile,
        bio: BioSnapshot,
        waterML: Int,
        userName: String?
    ) -> String {
        let timeLabel = timeOfDayLabel(bio.timeOfDay, language: language)
        let clock = clockText(bio.timestamp)
        let waterText = formatLiters(waterML: waterML, language: language)
        let stepsText = formatSteps(bio.stepsBucketed, language: language)
        let caloriesText = formatCalories(bio.caloriesBucketed, language: language)
        let heartRateText = formatHeartRate(bio.heartRateBucketed, language: language)
        let nameText = userName ?? (language == .arabic ? "البطل" : "champion")
        let genderHint = genderInstruction(for: profile.gender, language: language)

        if language == .arabic {
            var metrics = [
                "خطوات اليوم \(stepsText)",
                "السعرات النشطة \(caloriesText)",
                "الماء المشروب اليوم \(waterText)"
            ]
            if let heartRateText { metrics.append("نبض القلب \(heartRateText)") }
            let metricsList = metrics.joined(separator: "، ")
            return """
            [تعليمات داخلية — هذي بداية جلسة محادثة جديدة، ولا توجد رسائل سابقة. مهمتك تولّد رسالة افتتاحية قصيرة جداً (سطر أو سطرين بحد أقصى) بصوت كابتن حمّودي العراقي، وتطلع ممتعة ومختلفة كل مرّة:
            • نادي المستخدم باسمه «\(nameText)» مرّة وحدة على الأقل، طبيعي مثل صديق مو رسمي.
            • \(genderHint)
            • الوقت الحين بالضبط \(clock) — الفترة: \(timeLabel). كون واعي بالوقت فعلياً وخلِّ النبرة والكلام يطابقون الفترة:
              - فجر: صوت هادئ وواطي، بداية يوم ونَفَس وطمأنينة — لا تصيح ولا تشحن طاقة.
              - صباح: طاقة متفائلة خفيفة وانطلاقة لليوم.
              - ظهر: نص اليوم، شحنة سريعة وخفيفة دم.
              - عصر: دفعة همّة، اليوم بعده ما خلص.
              - مساء: دفء واسترخاء وحصاد شغل اليوم.
              - ليل: تهدئة وراحة وتحضير للنوم.
              - منتصف الليل: صوت واطي جداً وطمأنينة، اسأل بلطف ليش صاحي بدون ما تشحنه طاقة هالوقت.
              مرّات اذكر الوقت أو الفترة صريح (مثل «نص الليل وأنت صاحي» أو «صبحك خير»)، ومرّات خلِّه يبيّن بالنبرة بس — نوّع كل مرّة.
            • اذكر بشكل طبيعي وفكاهي مؤشّر حيّ واحد فقط من المتوفر، اختر الأنسب للوقت ولا تذكرهم كلهم: \(metricsList).
            • اختم بسؤال تحفيزي ودود واحد عن هدف اليوم أو شنو يحب يسوي هسة.
            • لهجة عراقية لطيفة خفيفة دم، فيها روح ودعابة بسيطة — ممتعة مو معلّبة. ممنوع أي تنبيه طبي أو إيموجي.
            • أرجِع الناتج بصيغة JSON القياسية (message + quickReplies اختيارية + باقي الحقول null). محتوى message فقط هو نص الترحيب — لا تكتب التعليمات نفسها داخل الرد.]
            """
        }

        var metrics = [
            "steps today \(stepsText)",
            "active calories \(caloriesText)",
            "water today \(waterText)"
        ]
        if let heartRateText { metrics.append("heart rate \(heartRateText)") }
        let metricsList = metrics.joined(separator: ", ")
        return """
        [INTERNAL INSTRUCTION — this is the very first message of a brand-new chat session; there is no prior history. Generate a single short opening line (1–2 sentences max) in Captain Hamoudi's voice, and make it fun and different every time:
        • Address the user as "\(nameText)" at least once — naturally, like a friend, never formal.
        • \(genderHint)
        • Exact time now is \(clock) — period: \(timeLabel). Be genuinely time-aware and match tone + wording to the period:
          - dawn: calm and low, a breath and reassurance — never loud or hyped.
          - morning: light optimistic energy, a kickoff to the day.
          - midday: mid-day, a quick light recharge with wit.
          - afternoon: a lift, the day isn't over yet.
          - evening: warm, winding down, the harvest of the day's work.
          - night: soothing, easing toward sleep.
          - late night / midnight: very low and reassuring, gently ask why they're up — do NOT hype them at this hour.
          Sometimes name the time or period explicitly (e.g. "up at midnight?" or "morning"), sometimes let only the tone show it — vary it every time.
        • Casually and wittily mention exactly ONE available live metric — pick the one that fits the moment, do NOT list them all: \(metricsList).
        • Close with one friendly motivating question about today's goal or what they want to do now.
        • Lighthearted, fun, a little Iraqi wit — enjoyable, never canned. No medical disclaimers. No emoji.
        • Return JSON in the standard contract (message + optional quickReplies + other fields null). The message field contains the greeting itself — do NOT echo this instruction inside it.]
        """
    }

    private static func timeOfDayLabel(
        _ timeOfDay: BioSnapshot.TimeOfDay,
        language: AppLanguage
    ) -> String {
        if language == .arabic {
            switch timeOfDay {
            case .dawn:      return "فجر"
            case .morning:   return "صباح"
            case .midday:    return "ظهر"
            case .afternoon: return "عصر"
            case .evening:   return "مساء"
            case .night:     return "ليل"
            case .lateNight: return "منتصف الليل"
            }
        }
        switch timeOfDay {
        case .dawn:      return "dawn"
        case .morning:   return "morning"
        case .midday:    return "noon"
        case .afternoon: return "afternoon"
        case .evening:   return "evening"
        case .night:     return "night"
        case .lateNight: return "late night / midnight"
        }
    }

    private static func genderInstruction(
        for gender: ActivityNotificationGender?,
        language: AppLanguage
    ) -> String {
        guard let gender else {
            return language == .arabic
                ? "خلّ الصياغة محايدة بين المذكر والمؤنث."
                : "Keep grammar gender-neutral."
        }
        if language == .arabic {
            switch gender {
            case .male:
                return "المستخدم ذكر — استخدم الصياغة المذكّرة (مثل: «جاهز»، «شلونك»، «خلّيك»)."
            case .female:
                return "المستخدمة أنثى — استخدم الصياغة المؤنّثة (مثل: «جاهزة»، «شلونچ» أو «شلونِك»، «خلّيچ» أو «خلّيكِ»)."
            }
        }
        switch gender {
        case .male:   return "User is male — phrase masculine where the language allows."
        case .female: return "User is female — phrase feminine where the language allows."
        }
    }

    private static func formatLiters(waterML: Int, language: AppLanguage) -> String {
        let liters = Double(waterML) / 1000.0
        let valueString = String(format: "%.1f", liters)
        return language == .arabic ? "\(valueString) لتر" : "\(valueString) L"
    }

    private static func formatSteps(_ steps: Int, language: AppLanguage) -> String {
        language == .arabic ? "\(steps) خطوة" : "\(steps) steps"
    }

    private static func formatCalories(_ calories: Int, language: AppLanguage) -> String {
        language == .arabic ? "\(calories) سعرة" : "\(calories) kcal"
    }

    /// `nil` when HealthKit has no heart-rate sample yet, so the prompt
    /// simply omits it instead of inviting the model to fabricate a number.
    private static func formatHeartRate(_ bpm: Int?, language: AppLanguage) -> String? {
        guard let bpm, bpm > 0 else { return nil }
        return language == .arabic ? "\(bpm)" : "\(bpm) bpm"
    }

    /// Local wall-clock in 24h form (e.g. "02:30", "14:05"). POSIX locale
    /// keeps it stable regardless of the device's 12/24h setting — this
    /// string only feeds the model's reasoning, it is never spoken.
    private static func clockText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Timeout

    private static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw DynamicWelcomeTimeout()
            }
            guard let result = try await group.next() else {
                throw DynamicWelcomeTimeout()
            }
            group.cancelAll()
            return result
        }
    }
}

private struct DynamicWelcomeTimeout: LocalizedError {
    var errorDescription: String? { "Dynamic welcome generation timed out." }
}
