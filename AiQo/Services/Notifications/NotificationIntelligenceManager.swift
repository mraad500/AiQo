import BackgroundTasks
import Foundation
import UserNotifications

final class NotificationIntelligenceManager {
    static let shared = NotificationIntelligenceManager()

    static let backgroundTaskIdentifier = "aiqo.captain.spiritual-whispers.refresh"

    private struct HealthContext: Sendable {
        let steps: Int
        let sleepHours: Double
        let heartRate: Int?
    }

    private struct PendingLocalNotification {
        let title: String
        let body: String
    }

    private enum NotificationIntelligenceError: LocalizedError {
        case emptyTranslation
        case notificationSchedulingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .emptyTranslation:
                return "The translation API returned an empty translation."
            case let .notificationSchedulingFailed(error):
                return "Scheduling the local notification failed: \(error.localizedDescription)"
            }
        }
    }

    private let defaults: UserDefaults
    private let notificationCenter: UNUserNotificationCenter
    private let captainIntelligenceManager: CaptainIntelligenceManager
    private let calendar: Calendar
    private let middlewareTranslator: any CoachBrainTranslating
    private let pendingDeveloperNotificationLock = NSLock()

    private let coachLanguageKey = "notificationLanguage"
    private let notificationThreadIdentifier = "aiqo.captain.spiritual-whispers"
    private let translationSystemPrompt = "Translate this to a friendly, motivational Iraqi Arabic dialect. You are Captain Hamoudi, a smart and caring fitness coach."
    private let defaultEnglishMessage = "Captain Hamoudi says: start with one strong move now and build momentum before the day runs away from you."
    private let defaultArabicMessage = "هلا بطل، خلي هسه حركة صغيرة تعطي يومك روح. قوم وامش دقيقتين وخليها بداية قوية."
    private let developerWhisperDelay: TimeInterval = 5

    private var pendingDeveloperNotification: PendingLocalNotification?

    private init(
        defaults: UserDefaults = .standard,
        notificationCenter: UNUserNotificationCenter = .current(),
        captainIntelligenceManager: CaptainIntelligenceManager = .shared,
        calendar: Calendar = .current,
        middlewareTranslator: (any CoachBrainTranslating)? = nil
    ) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
        self.captainIntelligenceManager = captainIntelligenceManager
        self.calendar = calendar
        self.middlewareTranslator = middlewareTranslator ?? CoachBrainLLMTranslator()
    }

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self, let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            self.handleBackgroundRefresh(task: refreshTask)
        }
    }

    func scheduleNextBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = nextPreferredRefreshDate(after: Date())

        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundTaskIdentifier)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("🔔 [NotificationIntelligenceManager] Failed to submit BG refresh: \(error.localizedDescription)")
        }
    }

    func cancelPendingBackgroundRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundTaskIdentifier)
    }

    func queueDeveloperTestSpiritualWhisper() async -> Bool {
        storePendingDeveloperNotification(nil)

        guard await NotificationService.shared.ensureAuthorizationIfNeeded() else {
            return false
        }

        let englishMessage = englishWhisperMessage(for: loadDummyHealthContext())
        guard !Task.isCancelled else { return false }

        let finalBody: String

        do {
            finalBody = try await translateToFriendlyIraqiArabic(englishText: englishMessage)
        } catch {
            print("🔔 [NotificationIntelligenceManager] Test translation failed: \(error.localizedDescription)")
            finalBody = defaultArabicMessage
        }

        guard !Task.isCancelled else { return false }

        storePendingDeveloperNotification(
            PendingLocalNotification(
                title: "همسة كابتن حمودي",
                body: finalBody
            )
        )
        return true
    }

    func scheduleQueuedDeveloperWhisperIfNeeded() {
        guard let pendingNotification = consumePendingDeveloperNotification() else { return }

        let request = makeLocalNotificationRequest(
            title: pendingNotification.title,
            body: pendingNotification.body,
            timeInterval: developerWhisperDelay
        )

        notificationCenter.add(request) { error in
            if let error {
                print("🔔 [NotificationIntelligenceManager] Failed to schedule queued developer whisper: \(error.localizedDescription)")
            }
        }
    }

    func generateAndScheduleSpiritualWhisper() async -> Bool {
        guard AppSettingsStore.shared.notificationsEnabled else { return true }
        guard await hasNotificationAuthorization() else { return true }

        let englishMessage = await simulateAppleIntelligenceContext()
        guard !Task.isCancelled else { return false }

        let preferredLanguage = preferredCoachLanguage()
        let finalBody: String

        switch preferredLanguage {
        case .english:
            finalBody = englishMessage

        case .arabic:
            do {
                finalBody = try await translateToFriendlyIraqiArabic(englishText: englishMessage)
            } catch {
                print("🔔 [NotificationIntelligenceManager] Translation failed: \(error.localizedDescription)")
                finalBody = defaultArabicMessage
            }
        }

        guard !Task.isCancelled else { return false }

        do {
            try await scheduleLocalNotification(
                title: preferredLanguage == .arabic ? "همسة كابتن حمودي" : "Captain Hamoudi",
                body: finalBody,
                timeInterval: 2
            )
            return true
        } catch {
            print("🔔 [NotificationIntelligenceManager] Notification scheduling failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Placeholder for future Apple Intelligence integration.
    /// Right now this builds a context-aware English whisper from local Health data.
    func simulateAppleIntelligenceContext() async -> String {
        let context = await loadHealthContext()
        return englishWhisperMessage(for: context)
    }

    private func englishWhisperMessage(for context: HealthContext) -> String {
        let sleepText = String(format: "%.1f", context.sleepHours)

        if context.steps < 1500 && context.sleepHours < 6 {
            return "You slept \(sleepText) hours and only logged \(context.steps) steps so far. Start soft with a 7-minute walk and wake your engine up."
        }

        if context.steps < 4000 {
            if let heartRate = context.heartRate, heartRate > 95 {
                return "Your heart rate is sitting around \(heartRate) bpm and you're at \(context.steps) steps. Reset your rhythm with slow breathing, then walk 5 minutes."
            }

            return "You're only at \(context.steps) steps today. Stack a quick 10-minute walk now and give your body the spark it needs."
        }

        if context.steps >= 9000 {
            return "You already earned \(context.steps) steps today. Finish strong with one more focused push before sunset and lock the win in."
        }

        if context.sleepHours >= 7.5 {
            return "You recovered for \(sleepText) hours and your body is ready. Use that advantage and turn the next 15 minutes into clean momentum."
        }

        return "You're building momentum with \(context.steps) steps today. Keep it moving with one deliberate burst before the evening slows you down."
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        if AppSettingsStore.shared.notificationsEnabled {
            scheduleNextBackgroundRefresh()
        } else {
            cancelPendingBackgroundRefresh()
        }

        let operation = Task(priority: .background) { [weak self] in
            guard let self else { return false }
            return await self.generateAndScheduleSpiritualWhisper()
        }

        task.expirationHandler = {
            operation.cancel()
        }

        Task {
            let success = await operation.value
            task.setTaskCompleted(success: success)
        }
    }

    private func loadHealthContext() async -> HealthContext {
        do {
            let metrics = try await captainIntelligenceManager.fetchTodayEssentialMetrics()
            return HealthContext(
                steps: max(0, metrics.stepCount),
                sleepHours: max(0, metrics.sleepHours),
                heartRate: metrics.averageOrCurrentHeartRateBPM
            )
        } catch {
            print("🔔 [NotificationIntelligenceManager] Falling back to default health context: \(error.localizedDescription)")
            return HealthContext(steps: 0, sleepHours: 0, heartRate: nil)
        }
    }

    private func loadDummyHealthContext() -> HealthContext {
        HealthContext(
            steps: 1320,
            sleepHours: 5.4,
            heartRate: 98
        )
    }

    private func preferredCoachLanguage() -> CoachNotificationLanguage {
        CoachNotificationLanguage(preferenceValue: defaults.string(forKey: coachLanguageKey))
    }

    private func nextPreferredRefreshDate(after date: Date) -> Date {
        let morning = calendar.date(
            bySettingHour: 6,
            minute: 15,
            second: 0,
            of: date
        ) ?? date.addingTimeInterval(60 * 60)
        let sunset = calendar.date(
            bySettingHour: 17,
            minute: 30,
            second: 0,
            of: date
        ) ?? date.addingTimeInterval(6 * 60 * 60)

        if date < morning {
            return morning
        }

        if date < sunset {
            return sunset
        }

        return calendar.date(byAdding: .day, value: 1, to: morning) ?? date.addingTimeInterval(12 * 60 * 60)
    }

    private func hasNotificationAuthorization() async -> Bool {
        let settings: UNNotificationSettings = await withCheckedContinuation {
            (continuation: CheckedContinuation<UNNotificationSettings, Never>) in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }

        switch settings.authorizationStatus {
        case .authorized, .ephemeral, .provisional:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    private func translateToFriendlyIraqiArabic(englishText: String) async throws -> String {
        let payload = englishText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else {
            return defaultArabicMessage
        }

        let translated = try await middlewareTranslator.translate(
            payload,
            systemPrompt: translationSystemPrompt
        )

        let normalizedTranslation = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTranslation.isEmpty else {
            throw NotificationIntelligenceError.emptyTranslation
        }

        return normalizedTranslation
    }

    private func scheduleLocalNotification(
        title: String,
        body: String,
        timeInterval: TimeInterval
    ) async throws {
        let request = makeLocalNotificationRequest(
            title: title,
            body: body,
            timeInterval: timeInterval
        )

        do {
            let _: Void = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                notificationCenter.add(request) { error in
                    if let error {
                        continuation.resume(throwing: NotificationIntelligenceError.notificationSchedulingFailed(error))
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        } catch let error as NotificationIntelligenceError {
            throw error
        } catch {
            throw NotificationIntelligenceError.notificationSchedulingFailed(error)
        }
    }

    private func makeLocalNotificationRequest(
        title: String,
        body: String,
        timeInterval: TimeInterval
    ) -> UNNotificationRequest {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalBody = trimmedBody.isEmpty ? defaultEnglishMessage : trimmedBody

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = finalBody
        content.sound = .default
        content.categoryIdentifier = CaptainSmartNotificationService.categoryIdentifier
        content.threadIdentifier = notificationThreadIdentifier
        content.userInfo = [
            "notification_type": "spiritual_whisper",
            "source": "captain_hamoudi",
            "messageText": finalBody,
            "deepLink": "aiqo://captain"
        ]

        return UNNotificationRequest(
            identifier: "\(notificationThreadIdentifier).\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, timeInterval),
                repeats: false
            )
        )
    }

    private func storePendingDeveloperNotification(_ notification: PendingLocalNotification?) {
        pendingDeveloperNotificationLock.lock()
        pendingDeveloperNotification = notification
        pendingDeveloperNotificationLock.unlock()
    }

    private func consumePendingDeveloperNotification() -> PendingLocalNotification? {
        pendingDeveloperNotificationLock.lock()
        defer { pendingDeveloperNotificationLock.unlock() }

        let notification = pendingDeveloperNotification
        pendingDeveloperNotification = nil
        return notification
    }
}
