import Foundation
import os.log

/// Builds the hyper-personalized opening line of a fresh Captain chat session.
///
/// The static "هلا! أنا كابتن حمّودي." string is replaced by an LLM-composed
/// greeting that ingests:
///   - Time of day from `BioStateEngine.shared.current()`
///   - Live steps & calories from the same bio snapshot
///   - Water intake from `HydrationService`
///   - User profile (name, gender) from `UserProfileStore`
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
        let waterText = formatLiters(waterML: waterML, language: language)
        let stepsText = formatSteps(bio.stepsBucketed, language: language)
        let caloriesText = formatCalories(bio.caloriesBucketed, language: language)
        let nameText = userName ?? (language == .arabic ? "البطل" : "champion")
        let genderHint = genderInstruction(for: profile.gender, language: language)

        if language == .arabic {
            return """
            [تعليمات داخلية — هذي بداية جلسة محادثة جديدة، ولا توجد رسائل سابقة. مهمتك أن تولّد رسالة افتتاحية قصيرة جداً (سطر أو سطرين بحد أقصى) بصوت كابتن حمّودي العراقي:
            • نادي على المستخدم باسمه «\(nameText)» مرّة بداية الجملة على الأقل، ولو طبيعي مرّة ثانية بهية.
            • \(genderHint)
            • وقت اليوم الحالي: \(timeLabel). خلِّ النبرة تطابق الوقت (صباح = طاقة هادية ولطيفة، الظهر = خفيف، عصر = حماس، مغرب/ليل = دفء، فجر/منتصف ليل = هدوء وطمأنينة).
            • اذكر بشكل طبيعي وفكاهي مؤشّر حيّ واحد فقط من هذي: خطوات اليوم \(stepsText)، السعرات النشطة \(caloriesText)، أو الماء المشروب اليوم \(waterText). اختر الأنسب للوقت ولا تذكرهم كلهم.
            • اختم بسؤال تحفيزي ودود واحد عن هدف اليوم.
            • لهجة عراقية لطيفة، خفيفة دم، بدون رسميات. ممنوع أي تنبيه طبي أو إيموجي زائد.
            • أرجِع الناتج بصيغة JSON القياسية (message + quickReplies اختيارية + باقي الحقول null). محتوى message فقط هو نص الترحيب — لا تكتب التعليمات نفسها داخل الرد.]
            """
        }

        return """
        [INTERNAL INSTRUCTION — this is the very first message of a brand-new chat session; there is no prior history. Generate a single short opening line (1–2 sentences max) in Captain Hamoudi's voice:
        • Address the user as "\(nameText)" at least once — naturally, like a friend.
        • \(genderHint)
        • Current time of day: \(timeLabel). Match the tone (morning = soft energy, midday = light, afternoon = lift, evening/night = warm, dawn/late-night = calm).
        • Casually mention exactly ONE of these live metrics — pick the one that fits the moment, do NOT list all three: steps today \(stepsText), active calories \(caloriesText), water today \(waterText).
        • Close with one friendly motivating question about today's goal.
        • Lighthearted, fun, never formal. No medical disclaimers. No emoji spam.
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
