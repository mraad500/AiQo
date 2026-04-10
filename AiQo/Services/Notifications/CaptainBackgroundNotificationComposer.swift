import Foundation

struct CaptainBackgroundNotificationComposer: Sendable {
    enum Prompt: String {
        case sleepNotification = "background.sleep_notification"
        case inactivityNotification = "background.inactivity_notification"
    }

    private let localBrainService: LocalBrainService

    init(
        localBrainService: LocalBrainService = LocalBrainService()
    ) {
        self.localBrainService = localBrainService
    }

    func composeMorningSleepNotification(
        wakeDate: Date,
        stepsSinceWake: Int,
        language: AppLanguage,
        level: Int
    ) async -> String {
        let prompt = String(
            format: localizedNotificationString(
                "notification.background.sleep.morning.prompt",
                language: language,
                fallback: """
                Write a short local notification in English, one or two sentences only, no emoji.
                The user moved after waking up.
                Wake time: %@
                Steps after waking: %d
                Analyze the latest recorded sleep and invite the user to open Captain Hamoudi.
                """
            ),
            wakeDate.ISO8601Format(),
            stepsSinceWake
        )

        let request = makeRequest(
            prompt: prompt,
            systemPrompt: Prompt.sleepNotification,
            screenContext: .sleepAnalysis,
            language: language,
            contextData: CaptainContextData(
                steps: max(stepsSinceWake, 0),
                calories: 0,
                vibe: "Awakening",
                level: max(level, 1)
            )
        )

        return await generateBody(
            request: request,
            fallback: SmartNotificationManager.shared.morningSleepNotificationBody(language: language)
        )
    }

    func composeSleepCompletionNotification(
        sessionEndedAt: Date,
        language: AppLanguage,
        level: Int
    ) async -> String {
        let prompt = String(
            format: localizedNotificationString(
                "notification.background.sleep.completed.prompt",
                language: language,
                fallback: """
                Write a short local notification in English, one or two sentences only, no emoji.
                The sleep session just ended.
                Sleep end time: %@
                Analyze the latest recorded sleep and invite the user to open Captain Hamoudi for deeper insight.
                """
            ),
            sessionEndedAt.ISO8601Format()
        )

        let request = makeRequest(
            prompt: prompt,
            systemPrompt: Prompt.sleepNotification,
            screenContext: .sleepAnalysis,
            language: language,
            contextData: CaptainContextData(
                steps: 0,
                calories: 0,
                vibe: "Recovery",
                level: max(level, 1)
            )
        )

        return await generateBody(
            request: request,
            fallback: SmartNotificationManager.shared.morningSleepNotificationBody(language: language)
        )
    }

    func composeInactivityNotification(
        metrics: CaptainDailyHealthMetrics,
        now: Date = Date(),
        language: AppLanguage = .arabic,
        level: Int
    ) async -> String {
        let hour = Calendar.current.component(.hour, from: now)
        let minute = Calendar.current.component(.minute, from: now)
        let prompt = String(
            format: localizedNotificationString(
                "notification.background.inactivity.prompt",
                language: language,
                fallback: """
                Write a very short local notification in English, one line only, no emoji.
                Current time: %02d:%02d.
                The user has slowed down in the middle of the day and has %d steps.
                Mention one clear action they can do right now to regain momentum.
                """
            ),
            hour,
            minute,
            metrics.stepCount
        )

        let request = makeRequest(
            prompt: prompt,
            systemPrompt: Prompt.inactivityNotification,
            screenContext: .mainChat,
            language: language,
            contextData: CaptainContextData(
                steps: max(metrics.stepCount, 0),
                calories: max(metrics.activeEnergyKilocalories, 0),
                vibe: hour >= 14 ? "Momentum" : "Awakening",
                level: max(level, 1)
            )
        )

        return await generateBody(
            request: request,
            fallback: SmartNotificationManager.shared.inactivityNotificationBody(
                currentSteps: metrics.stepCount,
                language: language
            )
        )
    }
}

private extension CaptainBackgroundNotificationComposer {
    func makeRequest(
        prompt: String,
        systemPrompt: Prompt,
        screenContext: ScreenContext,
        language: AppLanguage,
        contextData: CaptainContextData
    ) -> LocalBrainRequest {
        let baseSummary = localizedNotificationString(
            "notification.background.profile.summary",
            language: language,
            fallback: "Background notification"
        )

        // Enrich with personalization context from CaptainPersonalizationStore
        let personalizationPreamble = Self.buildPersonalizationPreamble()
        let enrichedSummary = personalizationPreamble.isEmpty
            ? baseSummary
            : baseSummary + "\n" + personalizationPreamble

        return LocalBrainRequest(
            conversation: [
                LocalConversationMessage(
                    role: .user,
                    content: prompt
                )
            ],
            screenContext: screenContext,
            language: language,
            systemPrompt: systemPrompt.rawValue,
            contextData: contextData,
            userProfileSummary: enrichedSummary,
            hasAttachedImage: false
        )
    }

    static func buildPersonalizationPreamble() -> String {
        guard let snapshot = CaptainPersonalizationStore.shared.currentSnapshot() else { return "" }

        var lines: [String] = ["User personalization context:"]
        lines.append("- Primary goal: \(snapshot.primaryGoal.localizedTitle)")
        lines.append("- Favorite sport: \(snapshot.favoriteSport.localizedTitle)")
        lines.append("- Preferred workout time: \(snapshot.preferredWorkoutTime.localizedTitle)")

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let bedtimeStr = timeFormatter.string(from: snapshot.bedtime)
        let wakeStr = timeFormatter.string(from: snapshot.wakeTime)
        lines.append("- Sleep window: \(bedtimeStr) to \(wakeStr)")

        return lines.joined(separator: "\n")
    }

    func generateBody(
        request: LocalBrainRequest,
        fallback: String
    ) async -> String {
        do {
            let reply = try await localBrainService.generateReply(request: request)
            let normalized = sanitize(reply.message)
            return normalized.isEmpty ? fallback : normalized
        } catch {
            return fallback
        }
    }

    func sanitize(_ text: String) -> String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard compact.count > 160 else { return compact }
        let index = compact.index(compact.startIndex, offsetBy: 160)
        return String(compact[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}
