import BackgroundTasks
import Foundation
import UserNotifications
import os.log

/// Unified orchestration layer for all automated local notifications.
final class SmartNotificationScheduler {
    static let shared = SmartNotificationScheduler()

    static let backgroundRefreshIdentifier = "aiqo.notifications.refresh"
    static let inactivityProcessingTaskIdentifier = "aiqo.notifications.inactivity-check"
    static let quietHoursStartHour = 23
    static let quietHoursEndHour = 7

    private struct HealthContext: Sendable {
        let steps: Int
        let sleepHours: Double
        let heartRate: Int?
    }

    private struct PendingLocalNotification {
        let title: String
        let body: String
    }

    private enum SchedulerError: LocalizedError {
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

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let captainIntelligenceManager: CaptainIntelligenceManager
    private let notificationComposer: CaptainBackgroundNotificationComposer
    private let middlewareTranslator: any CoachBrainTranslating
    private let pendingDeveloperNotificationLock = NSLock()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "SmartNotificationScheduler"
    )

    private let coachLanguageKey = "notificationLanguage"
    private let notificationThreadIdentifier = "aiqo.captain.coach-nudges"
    private let translationSystemPrompt = "Translate this to a friendly, motivational Iraqi Arabic dialect. You are Captain Hamoudi, a smart and caring fitness coach."
    private let defaultEnglishMessage = "Captain Hamoudi says: start with one strong move now and build momentum before the day runs away from you."
    private let defaultArabicMessage = "هلا بطل، خلي هسه حركة صغيرة تعطي يومك روح. قوم وامش دقيقتين وخليها بداية قوية."
    private let developerNudgeDelay: TimeInterval = 5
    private let backgroundInactivityCooldown: TimeInterval = 3 * 60 * 60
    private let lastBackgroundInactivitySentAtKey = "aiqo.notifications.background.lastInactivitySentAt"

    private var pendingDeveloperNotification: PendingLocalNotification?

    private init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        captainIntelligenceManager: CaptainIntelligenceManager = .shared,
        notificationComposer: CaptainBackgroundNotificationComposer? = nil,
        middlewareTranslator: (any CoachBrainTranslating)? = nil
    ) {
        self.center = center
        self.defaults = defaults
        self.calendar = calendar
        self.captainIntelligenceManager = captainIntelligenceManager
        self.notificationComposer = notificationComposer ?? CaptainBackgroundNotificationComposer()
        self.middlewareTranslator = middlewareTranslator ?? CoachBrainLLMTranslator()
    }

    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundRefreshIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self, let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            self.handleBackgroundRefresh(task: refreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.inactivityProcessingTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self, let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }

            self.handleInactivityProcessing(task: processingTask)
        }
    }

    func refreshAutomationState() {
        Task {
            let granted = await requestPermission()
            guard granted else { return }

            if AppSettingsStore.shared.notificationsEnabled {
                scheduleRecurringNotifications()
                scheduleBackgroundTasksIfNeeded()
            } else {
                cancelAllAutomatedNotifications()
                cancelScheduledBackgroundTasks()
            }
        }
    }

    func scheduleSmartNotifications() {
        refreshAutomationState()
    }

    func cancelAllSmartNotifications() {
        cancelRecurringNotifications()
    }

    func scheduleBackgroundTasksIfNeeded() {
        scheduleNextBackgroundRefresh()
        scheduleNextInactivityProcessing()
    }

    func cancelScheduledBackgroundTasks() {
        cancelPendingBackgroundRefresh()
        cancelPendingInactivityProcessing()
    }

    func queueDeveloperTestCoachNudge() async -> Bool {
        storePendingDeveloperNotification(nil)

        guard await NotificationService.shared.ensureAuthorizationIfNeeded() else {
            return false
        }

        let englishMessage = englishCoachMessage(for: loadDummyHealthContext())
        guard !Task.isCancelled else { return false }

        let finalBody: String

        do {
            finalBody = try await translateToFriendlyIraqiArabic(englishText: englishMessage)
        } catch {
            logger.error("developer_nudge_translation_failed error=\(error.localizedDescription, privacy: .public)")
            finalBody = defaultArabicMessage
        }

        guard !Task.isCancelled else { return false }

        storePendingDeveloperNotification(
            PendingLocalNotification(
                title: "كابتن حمودي",
                body: finalBody
            )
        )
        return true
    }

    func scheduleQueuedDeveloperNudgeIfNeeded() {
        guard let pendingNotification = consumePendingDeveloperNotification() else { return }

        let request = makeLocalNotificationRequest(
            title: pendingNotification.title,
            body: pendingNotification.body,
            timeInterval: developerNudgeDelay,
            notificationType: "coach_nudge_test"
        )

        center.add(request) { [self] error in
            if let error {
                self.logger.error("developer_nudge_schedule_failed error=\(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func canSendAutomatedNotificationNow(at date: Date = Date()) -> Bool {
        !Self.isWithinQuietHours(date: date, calendar: calendar)
    }

    func adjustedAutomationDate(for date: Date) -> Date {
        Self.nextAllowedDate(after: date, calendar: calendar)
    }

    static func isWithinQuietHours(
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= Self.quietHoursStartHour || hour < Self.quietHoursEndHour
    }

    static func nextAllowedDate(
        after date: Date,
        calendar: Calendar = .current
    ) -> Date {
        guard isWithinQuietHours(date: date, calendar: calendar) else {
            return date
        }

        let startOfDay = calendar.startOfDay(for: date)
        let nextMorning = calendar.date(
            bySettingHour: Self.quietHoursEndHour,
            minute: 0,
            second: 0,
            of: startOfDay
        ) ?? date

        if calendar.component(.hour, from: date) < Self.quietHoursEndHour {
            return nextMorning
        }

        return calendar.date(byAdding: .day, value: 1, to: nextMorning) ?? date
    }

    private func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("notification_permission_request_failed error=\(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func scheduleRecurringNotifications() {
        scheduleWaterReminders()
        scheduleWorkoutMotivation()
        scheduleSleepReminder()
        scheduleStreakProtection()
        scheduleWeeklyReportReminder()
    }

    private func cancelRecurringNotifications() {
        [
            "water_reminder",
            "workout_motivation",
            "sleep_reminder",
            "streak_protection",
            "weekly_report"
        ].forEach(cancelCategory)
    }

    private func cancelAllAutomatedNotifications() {
        cancelRecurringNotifications()
        let identifiers = [
            PremiumExpiryNotifier.twoDaysBeforeIdentifier,
            PremiumExpiryNotifier.oneDayBeforeIdentifier,
            PremiumExpiryNotifier.expiredIdentifier
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func scheduleWaterReminders() {
        cancelCategory("water_reminder")

        let messages = [
            "\(UserProfileStore.shared.current.name)! جسمك يحتاج ماء 💧 اشرب كوب الحين",
            "وقت الماء! 💧 خلّي جسمك رطب",
            "كابتن حمّودي يقول: اشرب ماي يا بطل 💧",
            "هيدريشن تايم! 💧 كوب ماء وكمّل يومك",
            "ما تنسى الماء! جسمك يشكرك 💧",
        ]

        let hours = [10, 12, 14, 16, 18, 20]
        for (index, hour) in hours.enumerated() {
            scheduleRecurringRequest(
                identifier: "water_reminder_\(hour)",
                title: "💧 وقت الماء",
                body: messages[index % messages.count],
                categoryIdentifier: "water_reminder",
                threadIdentifier: "aiqo.hydration",
                hour: hour,
                minute: 0
            )
        }
    }

    private func scheduleWorkoutMotivation() {
        cancelCategory("workout_motivation")

        let reminderTime = CaptainPersonalizationStore.shared.workoutReminderTime()
            ?? CaptainWorkoutTimePreference.evening.reminderTime

        let messages = [
            "يلا يا بطل! وقت التمرين 💪 جسمك ينتظرك",
            "كابتن حمّودي جاهز! يلا نتمرن 🔥",
            "30 دقيقة بس وبتحس بفرق هائل 💪",
            "التمرين اليوم يبني جسم الغد 🏋️",
            "ما في عذر اليوم! يلا قوم 🔥",
            "جسمك يستاهل أحسن نسخة منك 💪",
            "كابتن حمّودي يقول: يلا نشغّل المحرك! 🚀"
        ]

        scheduleRecurringRequest(
            identifier: "workout_motivation_daily",
            title: "💪 وقت التمرين!",
            body: messages.randomElement() ?? messages[0],
            categoryIdentifier: "workout_motivation",
            threadIdentifier: "aiqo.workout",
            hour: reminderTime.hour,
            minute: reminderTime.minute
        )
    }

    private func scheduleSleepReminder() {
        cancelCategory("sleep_reminder")

        let reminderTime = CaptainPersonalizationStore.shared.sleepReminderTime(calendar: calendar)
            ?? CaptainReminderTime(hour: 22, minute: 30)

        scheduleRecurringRequest(
            identifier: "sleep_reminder_nightly",
            title: "😴 وقت النوم",
            body: "كابتن حمّودي يقول: النوم أهم من التمرين! خلّي جسمك ينتعش الليلة. تصبح على خير 🌙",
            categoryIdentifier: "sleep_reminder",
            threadIdentifier: "aiqo.sleep",
            hour: reminderTime.hour,
            minute: reminderTime.minute
        )
    }

    private func scheduleStreakProtection() {
        cancelCategory("streak_protection")

        scheduleRecurringRequest(
            identifier: "streak_protection_evening",
            title: "🔥 الـ Streak بخطر!",
            body: "لسه ما حققت هدفك اليوم! مشي سريع 15 دقيقة يكفي. لا تخلي الـ streak ينكسر 💪",
            categoryIdentifier: "streak_protection",
            threadIdentifier: "aiqo.streak",
            hour: 20,
            minute: 0,
            interruptionLevel: .timeSensitive
        )
    }

    private func scheduleWeeklyReportReminder() {
        cancelCategory("weekly_report")

        scheduleRecurringRequest(
            identifier: "weekly_report_friday",
            title: "📊 تقريرك الأسبوعي جاهز!",
            body: "كابتن حمّودي حضّر ملخص أسبوعك. تعال شوف شلون كان أداءك! 🏆",
            categoryIdentifier: "weekly_report",
            threadIdentifier: "aiqo.report",
            hour: 10,
            minute: 0,
            weekday: 6
        )
    }

    private func scheduleRecurringRequest(
        identifier: String,
        title: String,
        body: String,
        categoryIdentifier: String,
        threadIdentifier: String,
        hour: Int,
        minute: Int,
        weekday: Int? = nil,
        interruptionLevel: UNNotificationInterruptionLevel? = nil
    ) {
        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = adjustedHourForQuietHours(hour)
        dateComponents.minute = dateComponents.hour == Self.quietHoursEndHour && isQuietHour(hour) ? 0 : minute

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.threadIdentifier = threadIdentifier
        if #available(iOS 15.0, *), let interruptionLevel {
            content.interruptionLevel = interruptionLevel
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    private func adjustedHourForQuietHours(_ hour: Int) -> Int {
        isQuietHour(hour) ? Self.quietHoursEndHour : hour
    }

    private func isQuietHour(_ hour: Int) -> Bool {
        hour >= Self.quietHoursStartHour || hour < Self.quietHoursEndHour
    }

    private func cancelCategory(_ category: String) {
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.content.categoryIdentifier == category }
                .map(\.identifier)
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func scheduleNextBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundRefreshIdentifier)
        request.earliestBeginDate = nextPreferredRefreshDate(after: Date())

        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundRefreshIdentifier)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("background_refresh_submit_failed error=\(error.localizedDescription, privacy: .public)")
        }
    }

    private func cancelPendingBackgroundRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundRefreshIdentifier)
    }

    private func scheduleNextInactivityProcessing() {
        let request = BGProcessingTaskRequest(identifier: Self.inactivityProcessingTaskIdentifier)
        request.earliestBeginDate = nextPreferredInactivityCheckDate(after: Date())
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.inactivityProcessingTaskIdentifier)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("background_inactivity_submit_failed error=\(error.localizedDescription, privacy: .public)")
        }
    }

    private func cancelPendingInactivityProcessing() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.inactivityProcessingTaskIdentifier)
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        if AppSettingsStore.shared.notificationsEnabled {
            scheduleNextBackgroundRefresh()
        } else {
            cancelPendingBackgroundRefresh()
        }

        let operation = Task(priority: .background) { [weak self] in
            guard let self else { return false }
            return await self.generateAndScheduleCoachNudge()
        }

        task.expirationHandler = {
            operation.cancel()
        }

        Task {
            let success = await operation.value
            task.setTaskCompleted(success: success)
        }
    }

    private func handleInactivityProcessing(task: BGProcessingTask) {
        if AppSettingsStore.shared.notificationsEnabled {
            scheduleNextInactivityProcessing()
        } else {
            cancelPendingInactivityProcessing()
        }

        let operation = Task(priority: .background) { [weak self] in
            guard let self else { return false }
            return await self.performInactivityCheckAndNotifyIfNeeded()
        }

        task.expirationHandler = {
            operation.cancel()
        }

        Task {
            let success = await operation.value
            task.setTaskCompleted(success: success)
        }
    }

    private func generateAndScheduleCoachNudge() async -> Bool {
        guard AppSettingsStore.shared.notificationsEnabled else { return true }
        guard await hasNotificationAuthorization() else { return true }
        guard canSendAutomatedNotificationNow() else { return true }

        let englishMessage = await simulatedCoachContext()
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
                logger.error("coach_nudge_translation_failed error=\(error.localizedDescription, privacy: .public)")
                finalBody = defaultArabicMessage
            }
        }

        guard !Task.isCancelled else { return false }

        do {
            try await scheduleLocalNotification(
                title: preferredLanguage == .arabic ? "كابتن حمودي" : "Captain Hamoudi",
                body: finalBody,
                timeInterval: 2,
                notificationType: "coach_nudge"
            )
            return true
        } catch {
            logger.error("coach_nudge_schedule_failed error=\(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func simulatedCoachContext() async -> String {
        let context = await loadHealthContext()
        return englishCoachMessage(for: context)
    }

    private func englishCoachMessage(for context: HealthContext) -> String {
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

    private func performInactivityCheckAndNotifyIfNeeded(
        now: Date = Date()
    ) async -> Bool {
        guard AppSettingsStore.shared.notificationsEnabled else { return true }
        guard !Task.isCancelled else { return false }
        guard canSendAutomatedNotificationNow(at: now) else { return true }

        let hour = calendar.component(.hour, from: now)
        guard hour >= 14 else { return true }
        guard canSendBackgroundInactivityNotification(now: now) else { return true }

        let metrics: CaptainDailyHealthMetrics
        do {
            metrics = try await captainIntelligenceManager.fetchTodayEssentialMetrics()
        } catch {
            logger.error("background_inactivity_metrics_failed error=\(error.localizedDescription, privacy: .public)")
            return true
        }

        guard metrics.stepCount < 3_000 else { return true }
        guard !Task.isCancelled else { return false }

        let body = await notificationComposer.composeInactivityNotification(
            metrics: metrics,
            now: now,
            language: .arabic,
            level: await MainActor.run { max(LevelStore.shared.level, 1) }
        )

        do {
            try await scheduleLocalNotification(
                title: "كابتن حمودي",
                body: body,
                timeInterval: 1,
                notificationType: "midday_inactivity"
            )
            defaults.set(now, forKey: lastBackgroundInactivitySentAtKey)
            return true
        } catch {
            logger.error("background_inactivity_schedule_failed error=\(error.localizedDescription, privacy: .public)")
            return false
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
            logger.error("coach_context_fallback error=\(error.localizedDescription, privacy: .public)")
            return HealthContext(steps: 0, sleepHours: 0, heartRate: nil)
        }
    }

    private func loadDummyHealthContext() -> HealthContext {
        HealthContext(steps: 1320, sleepHours: 5.4, heartRate: 98)
    }

    private func preferredCoachLanguage() -> CoachNotificationLanguage {
        CoachNotificationLanguage(preferenceValue: defaults.string(forKey: coachLanguageKey))
    }

    private func nextPreferredRefreshDate(after date: Date) -> Date {
        let morning = calendar.date(bySettingHour: 7, minute: 15, second: 0, of: date) ?? date.addingTimeInterval(60 * 60)
        let sunset = calendar.date(bySettingHour: 17, minute: 30, second: 0, of: date) ?? date.addingTimeInterval(6 * 60 * 60)

        if date < morning {
            return morning
        }

        if date < sunset {
            return sunset
        }

        return calendar.date(byAdding: .day, value: 1, to: morning) ?? date.addingTimeInterval(12 * 60 * 60)
    }

    private func nextPreferredInactivityCheckDate(after date: Date) -> Date {
        let afternoonStart = calendar.date(bySettingHour: 14, minute: 5, second: 0, of: date) ?? date.addingTimeInterval(60 * 60)
        let eveningCutoff = calendar.date(bySettingHour: 20, minute: 30, second: 0, of: date) ?? date.addingTimeInterval(8 * 60 * 60)

        if date < afternoonStart {
            return afternoonStart
        }

        if date < eveningCutoff {
            return date.addingTimeInterval(2 * 60 * 60)
        }

        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: afternoonStart) ?? date.addingTimeInterval(18 * 60 * 60)
        return adjustedAutomationDate(for: tomorrowStart)
    }

    private func hasNotificationAuthorization() async -> Bool {
        let settings: UNNotificationSettings = await withCheckedContinuation {
            (continuation: CheckedContinuation<UNNotificationSettings, Never>) in
            center.getNotificationSettings { settings in
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
            throw SchedulerError.emptyTranslation
        }

        return normalizedTranslation
    }

    private func scheduleLocalNotification(
        title: String,
        body: String,
        timeInterval: TimeInterval,
        notificationType: String
    ) async throws {
        let request = makeLocalNotificationRequest(
            title: title,
            body: body,
            timeInterval: timeInterval,
            notificationType: notificationType
        )

        do {
            let _: Void = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                center.add(request) { error in
                    if let error {
                        continuation.resume(throwing: SchedulerError.notificationSchedulingFailed(error))
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        } catch let error as SchedulerError {
            throw error
        } catch {
            throw SchedulerError.notificationSchedulingFailed(error)
        }
    }

    private func makeLocalNotificationRequest(
        title: String,
        body: String,
        timeInterval: TimeInterval,
        notificationType: String
    ) -> UNNotificationRequest {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalBody = trimmedBody.isEmpty ? defaultEnglishMessage : trimmedBody
        let desiredDate = Date().addingTimeInterval(max(1, timeInterval))
        let fireDate = adjustedAutomationDate(for: desiredDate)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = finalBody
        content.sound = .default
        content.categoryIdentifier = CaptainSmartNotificationService.categoryIdentifier
        content.threadIdentifier = notificationThreadIdentifier
        content.userInfo = [
            "notification_type": notificationType,
            "source": "captain_hamoudi",
            "messageText": finalBody,
            "deepLink": "aiqo://captain"
        ]

        return UNNotificationRequest(
            identifier: "\(notificationThreadIdentifier).\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, fireDate.timeIntervalSinceNow),
                repeats: false
            )
        )
    }

    private func canSendBackgroundInactivityNotification(now: Date) -> Bool {
        guard let lastSentAt = defaults.object(forKey: lastBackgroundInactivitySentAtKey) as? Date else {
            return true
        }

        return now.timeIntervalSince(lastSentAt) >= backgroundInactivityCooldown
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
