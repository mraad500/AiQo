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
        let prompt = """
        اكتب نص إشعار محلي قصير باللهجة العراقية، جملة أو جملتين فقط، بدون إيموجي.
        المستخدم تحرك بعد الاستيقاظ.
        وقت الاستيقاظ: \(wakeDate.ISO8601Format())
        الخطوات بعد الاستيقاظ: \(stepsSinceWake)
        حلل آخر نوم مسجل وادعُ المستخدم يفتح Captain Hamoudi.
        """

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
        let prompt = """
        اكتب نص إشعار محلي قصير باللهجة العراقية، جملة أو جملتين فقط، بدون إيموجي.
        انتهت جلسة النوم للتو.
        وقت نهاية النوم: \(sessionEndedAt.ISO8601Format())
        حلل آخر نوم مسجل وادعُ المستخدم يفتح Captain Hamoudi لتحليل أعمق.
        """

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
        let prompt = """
        اكتب إشعاراً محلياً قصيراً جداً باللهجة العراقية، سطر واحد فقط، بدون إيموجي.
        الوقت الحالي \(hour):\(String(format: "%02d", minute)).
        المستخدم متوقف بمنتصف اليوم وخطواته \(metrics.stepCount).
        اذكر فعل واحد واضح يسويه الآن حتى يرجع للزخم.
        """

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
        LocalBrainRequest(
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
            userProfileSummary: "Background notification",
            hasAttachedImage: false
        )
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
