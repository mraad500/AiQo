import UserNotifications
import UIKit
import Foundation
import HealthKit

final class NotificationService {
    static let shared = NotificationService()
    private let defaults = UserDefaults.standard
    private let notificationPromptedKey = "aiqo.notifications.didPromptPermission"

    private init() {}

    func requestPermissions() {
        Task {
            _ = await ensureAuthorizationIfNeeded()
        }
    }

    func ensureAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        configureCategories()

        let settings: UNNotificationSettings = await withCheckedContinuation {
            (continuation: CheckedContinuation<UNNotificationSettings, Never>) in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return true
        case .notDetermined:
            defaults.set(true, forKey: notificationPromptedKey)

            let granted: Bool = await withCheckedContinuation {
                (continuation: CheckedContinuation<Bool, Never>) in
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error {
                        print("❌ Permission error: \(error)")
                    }

                    continuation.resume(returning: granted)
                }
            }

            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }

            return granted
        case .denied:
            print("🔔 Notifications are disabled. The app will not prompt again automatically.")
            return false
        @unknown default:
            return false
        }
    }

    func configureCategories() {
        NotificationCategoryManager.shared.registerAllCategories()
    }

    func sendImmediateNotification(body: String, type: String) {
        let fireDate = SmartNotificationScheduler.shared.adjustedAutomationDate(for: Date().addingTimeInterval(1))
        let content = UNMutableNotificationContent()
        content.title = "AiQo"
        content.body = body
        content.sound = .default
        content.userInfo = ["notification_type": type]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, fireDate.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    // دالة جديدة لمعالجة البيانات القادمة من الخلفية (اختياري)
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        // إذا كنت تريد تنفيذ شيء معين عند وصول إشعار صامت
        print("Handling remote data: \(userInfo)")
    }

    func handle(response: UNNotificationResponse) {
        guard
            let typeRaw = response.notification.request.content.userInfo["notification_type"] as? String,
            let type = NotificationType(rawValue: typeRaw)
        else { return }
        routeFromNotification(type: type)
    }

    private func routeFromNotification(type: NotificationType) {
        Task { @MainActor in
            switch type {
            case .dailyStepsReminder, .workoutReminder, .stepGoalProgress:
                MainTabRouter.shared.navigate(to: .gym)
            case .waterReminder, .mealTimeReminder:
                MainTabRouter.shared.openKitchen()
            case .checkInReminder, .sleepReminder:
                MainTabRouter.shared.navigate(to: .home)
            }
        }
    }
}

// MARK: - Captain Smart Notifications

struct WorkoutCoachingSummary {
    let duration: TimeInterval
    let calories: Double
    let averageHeartRate: Double
    let distanceMeters: Double
    let estimatedSteps: Int
    let workoutType: String

    init(
        duration: TimeInterval,
        calories: Double,
        averageHeartRate: Double,
        distanceMeters: Double,
        estimatedSteps: Int,
        workoutType: String = "Workout"
    ) {
        self.duration = duration
        self.calories = calories
        self.averageHeartRate = averageHeartRate
        self.distanceMeters = distanceMeters
        self.estimatedSteps = estimatedSteps
        self.workoutType = workoutType
    }
}

final class CaptainSmartNotificationService {
    static let shared = CaptainSmartNotificationService()

    static let categoryIdentifier = "aiqo.captain.smart"
    static var notificationCategory: UNNotificationCategory {
        let openAction = UNNotificationAction(
            identifier: "OPEN_CAPTAIN",
            title: NSLocalizedString(
                "notification.captain.openAction",
                value: "Open Captain",
                comment: ""
            ),
            options: [.foreground]
        )
        return UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }
    private let intelligenceManager = CaptainIntelligenceManager.shared
    private let defaults = UserDefaults.standard
    private let lastInactivitySentAtKey = "aiqo.captain.lastInactivitySentAt"
    private let inactivityCooldownSeconds: TimeInterval = 45 * 60

    private init() {}

    func registerNotificationCategories() {
        NotificationCategoryManager.shared.registerAllCategories()
    }

    func evaluateInactivityAndNotifyIfNeeded() async {
        guard AppSettingsStore.shared.notificationsEnabled else { return }

        let inactivityMinutes = InactivityTracker.shared.currentInactivityMinutes
        guard inactivityMinutes >= 45 else { return }
        guard canSendInactivityNow() else { return }

        let language = resolvedCoachNotificationLanguage(defaults: defaults)
        let currentSteps = HealthKitManager.shared.todaySteps
        let message = await generateInactivityMessage(
            currentSteps: currentSteps,
            language: language
        )

        sendCaptainNotification(
            title: localizedNotificationString(
                "notification.captain.title",
                language: language,
                fallback: "Captain Hamoudi"
            ),
            body: message,
            type: "inactivity",
            messageText: message
        )
        defaults.set(Date(), forKey: lastInactivitySentAtKey)
    }

    func handleWorkoutCompleted(summary: WorkoutCoachingSummary) async {
        await AIWorkoutSummaryService.shared.handleWorkoutEnded(
            workoutType: summary.workoutType,
            duration: summary.duration,
            keyMetrics: [
                "calories": summary.calories,
                "averageHeartRate": summary.averageHeartRate,
                "distanceKm": summary.distanceMeters / 1000.0,
                "estimatedSteps": Double(summary.estimatedSteps)
            ],
            endedAt: Date()
        )
    }

    private func canSendInactivityNow() -> Bool {
        guard let last = defaults.object(forKey: lastInactivitySentAtKey) as? Date else { return true }
        return Date().timeIntervalSince(last) >= inactivityCooldownSeconds
    }

    private func sendCaptainNotification(title: String, body: String, type: String, messageText: String) {
        let fireDate = SmartNotificationScheduler.shared.adjustedAutomationDate(for: Date().addingTimeInterval(1))
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = [
            "notification_type": type,
            "source": "captain_hamoudi",
            "messageText": messageText,
            "deepLink": "aiqo://captain"
        ]

        let request = UNNotificationRequest(
            identifier: "aiqo.captain.smart.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, fireDate.timeIntervalSinceNow),
                repeats: false
            )
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Water Reminder

    func evaluateWaterAndNotifyIfNeeded(currentLiters: Double, targetLiters: Double) {
        guard AppSettingsStore.shared.notificationsEnabled else { return }
        guard currentLiters < targetLiters * 0.5 else { return }

        let currentHour = Calendar.current.component(.hour, from: Date())
        guard (9...21).contains(currentHour) else { return }
        guard canSendWaterReminderNow() else { return }

        let language = resolvedCoachNotificationLanguage(defaults: defaults)
        let remaining = targetLiters - currentLiters
        let body = String(
            format: localizedNotificationString(
                "notification.water.body",
                language: language,
                fallback: "Had water yet? You still need %@ liters to reach your goal. 💧"
            ),
            String(format: "%.1f", remaining)
        )

        sendCaptainNotification(
            title: localizedNotificationString(
                "notification.captain.title",
                language: language,
                fallback: "Captain Hamoudi"
            ),
            body: body,
            type: "waterReminder",
            messageText: body
        )
        defaults.set(Date(), forKey: lastWaterReminderSentAtKey)
    }

    // MARK: - Meal Time Reminder

    func evaluateMealTimeAndNotifyIfNeeded() {
        guard AppSettingsStore.shared.notificationsEnabled else { return }

        let currentHour = Calendar.current.component(.hour, from: Date())
        let language = resolvedCoachNotificationLanguage(defaults: defaults)
        let mealInfo: (nameKey: String, type: String)?

        switch currentHour {
        case 7...9:
            mealInfo = ("notification.meal.breakfast", "breakfast")
        case 12...14:
            mealInfo = ("notification.meal.lunch", "lunch")
        case 18...20:
            mealInfo = ("notification.meal.dinner", "dinner")
        default:
            mealInfo = nil
        }

        guard let meal = mealInfo else { return }
        guard canSendMealReminderNow(meal: meal.type) else { return }

        let mealName = localizedNotificationString(
            meal.nameKey,
            language: language,
            fallback: meal.type
        )
        let body = String(
            format: localizedNotificationString(
                "notification.meal.body",
                language: language,
                fallback: "It’s %@ time. Let’s eat well. 🍽️"
            ),
            mealName
        )

        sendCaptainNotification(
            title: localizedNotificationString(
                "notification.captain.title",
                language: language,
                fallback: "Captain Hamoudi"
            ),
            body: body,
            type: "mealTimeReminder",
            messageText: body
        )
        defaults.set(Date(), forKey: "\(lastMealReminderSentAtKeyPrefix).\(meal.type)")
    }

    // MARK: - Step Goal Progress

    func evaluateStepGoalAndNotifyIfNeeded(currentSteps: Int, targetSteps: Int) {
        guard AppSettingsStore.shared.notificationsEnabled else { return }
        guard targetSteps > 0 else { return }

        let progress = Double(currentSteps) / Double(targetSteps)
        let milestone: Int?

        if progress >= 0.9 && progress < 1.0 {
            milestone = 90
        } else if progress >= 0.75 && progress < 0.9 {
            milestone = 75
        } else if progress >= 0.5 && progress < 0.75 {
            milestone = 50
        } else {
            milestone = nil
        }

        guard let milestone else { return }
        guard canSendStepGoalNow(milestone: milestone) else { return }

        let language = resolvedCoachNotificationLanguage(defaults: defaults)
        let remaining = targetSteps - currentSteps
        let body: String
        switch milestone {
        case 90:
            body = String(
                format: localizedNotificationString(
                    "notification.step.body.90",
                    language: language,
                    fallback: "Only %@ steps left. Finish strong! 🔥"
                ),
                "\(remaining)"
            )
        case 75:
            body = localizedNotificationString(
                "notification.step.body.75",
                language: language,
                fallback: "You’ve reached 75% of your goal. Keep going! 💪"
            )
        default:
            body = String(
                format: localizedNotificationString(
                    "notification.step.body.50",
                    language: language,
                    fallback: "Halfway there. %@ steps so far, keep moving."
                ),
                "\(currentSteps)"
            )
        }

        sendCaptainNotification(
            title: localizedNotificationString(
                "notification.captain.title",
                language: language,
                fallback: "Captain Hamoudi"
            ),
            body: body,
            type: "stepGoalProgress",
            messageText: body
        )
        defaults.set(Date(), forKey: "\(lastStepGoalSentAtKeyPrefix).\(milestone)")
    }

    // MARK: - Sleep Reminder

    func evaluateSleepTimeAndNotifyIfNeeded(targetBedtimeHour: Int) {
        guard AppSettingsStore.shared.notificationsEnabled else { return }

        let now = Date()
        let currentHour = Calendar.current.component(.hour, from: now)
        let currentMinute = Calendar.current.component(.minute, from: now)

        // Notify 30 minutes before target bedtime
        let isApproaching = (currentHour == targetBedtimeHour - 1 && currentMinute >= 30) ||
                            (currentHour == targetBedtimeHour && currentMinute == 0)

        guard isApproaching else { return }
        guard canSendSleepReminderNow() else { return }

        let language = resolvedCoachNotificationLanguage(defaults: defaults)
        let body = localizedNotificationString(
            "notification.sleep.body",
            language: language,
            fallback: "Bedtime is close. Get ready to sleep. Your body needs rest so tomorrow feels better. 🌙"
        )

        sendCaptainNotification(
            title: localizedNotificationString(
                "notification.captain.title",
                language: language,
                fallback: "Captain Hamoudi"
            ),
            body: body,
            type: "sleepReminder",
            messageText: body
        )
        defaults.set(Date(), forKey: lastSleepReminderSentAtKey)
    }

    // MARK: - Cooldown Keys

    private let lastWaterReminderSentAtKey = "aiqo.captain.lastWaterReminderSentAt"
    private let lastMealReminderSentAtKeyPrefix = "aiqo.captain.lastMealReminderSentAt"
    private let lastStepGoalSentAtKeyPrefix = "aiqo.captain.lastStepGoalSentAt"
    private let lastSleepReminderSentAtKey = "aiqo.captain.lastSleepReminderSentAt"

    private let waterReminderCooldownSeconds: TimeInterval = 2 * 60 * 60  // 2 hours
    private let mealReminderCooldownSeconds: TimeInterval = 4 * 60 * 60   // 4 hours
    private let stepGoalCooldownSeconds: TimeInterval = 60 * 60           // 1 hour
    private let sleepReminderCooldownSeconds: TimeInterval = 20 * 60 * 60 // 20 hours

    private func canSendWaterReminderNow() -> Bool {
        guard let last = defaults.object(forKey: lastWaterReminderSentAtKey) as? Date else { return true }
        return Date().timeIntervalSince(last) >= waterReminderCooldownSeconds
    }

    private func canSendMealReminderNow(meal: String) -> Bool {
        let key = "\(lastMealReminderSentAtKeyPrefix).\(meal)"
        guard let last = defaults.object(forKey: key) as? Date else { return true }
        return Date().timeIntervalSince(last) >= mealReminderCooldownSeconds
    }

    private func canSendStepGoalNow(milestone: Int) -> Bool {
        let key = "\(lastStepGoalSentAtKeyPrefix).\(milestone)"
        guard let last = defaults.object(forKey: key) as? Date else { return true }
        return Date().timeIntervalSince(last) >= stepGoalCooldownSeconds
    }

    private func canSendSleepReminderNow() -> Bool {
        guard let last = defaults.object(forKey: lastSleepReminderSentAtKey) as? Date else { return true }
        return Date().timeIntervalSince(last) >= sleepReminderCooldownSeconds
    }

    private func generateInactivityMessage(
        currentSteps: Int,
        language: CoachNotificationLanguage
    ) async -> String {
        let prompt = String(
            format: localizedNotificationString(
                "notification.inactivity.prompt",
                language: language,
                fallback: """
                User inactivity alert context:
                - Current steps today: %d
                - The user has been inactive for at least 45 minutes.
                Provide one short English motivational line (max 14 words) with one concrete next action.
                """
            ),
            max(0, currentSteps)
        )

        do {
            let message = try await intelligenceManager.generateCaptainResponse(for: prompt)
            let compact = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if !compact.isEmpty {
                return compact
            }
        } catch {
            // Fall back to deterministic local text.
        }

        if currentSteps < 2000 {
            return localizedNotificationString(
                "notification.inactivity.fallback.low",
                language: language,
                fallback: "Get up and claim your first thousand steps today."
            )
        } else if currentSteps < 6000 {
            return localizedNotificationString(
                "notification.inactivity.fallback.mid",
                language: language,
                fallback: "Great start. Keep the momentum going and add a little more."
            )
        } else {
            return localizedNotificationString(
                "notification.inactivity.fallback.high",
                language: language,
                fallback: "Strong progress today. Stay consistent and keep the habit alive."
            )
        }
    }
}

enum CoachNotificationLanguage: String, CaseIterable {
    case arabic = "ar"
    case english = "en"

    init(preferenceValue: String?) {
        let normalized = preferenceValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        switch normalized {
        case "en", "english":
            self = .english
        case "ar", "arabic":
            self = .arabic
        default:
            self = .arabic
        }
    }
}

@MainActor
final class AIWorkoutSummaryService {
    static let shared = AIWorkoutSummaryService()

    private let healthStore = HKHealthStore()
    private let notificationCenter = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let intelligenceManager = CaptainIntelligenceManager.shared

    private let workoutAnchorKey = "aiqo.ai.workout.anchor"
    private let processedWorkoutIDsKey = "aiqo.ai.workout.processed.ids"
    private let processedWorkoutLimit = 220
    private let fingerprintWindowSeconds: TimeInterval = 180
    private let fingerprintLimit = 40
    private let initialSyncLookbackSeconds: TimeInterval = 2 * 60 * 60

    private var workoutObserverQuery: HKObserverQuery?
    private var workoutAnchor: HKQueryAnchor?
    private var processedWorkoutIDs: [String] = []
    private var recentFingerprints: [String: Date] = [:]
    private var isMonitoring = false
    private var isSyncing = false
    private var pendingSync = false

    private init() {
        processedWorkoutIDs = defaults.stringArray(forKey: processedWorkoutIDsKey) ?? []
        trimProcessedWorkouts()
        workoutAnchor = loadPersistedAnchor()
    }

    // MARK: - Public API

    func startMonitoringWorkoutEnds() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard await ensureAuthorization() else { return }

        await enableBackgroundDelivery()
        await installWorkoutObserverIfNeeded()
        await syncNewWorkouts()
    }

    func handleWorkoutEnded(
        workoutType: String,
        duration: TimeInterval,
        keyMetrics: [String: Double],
        endedAt: Date,
        workoutID: String? = nil
    ) async {
        guard AppSettingsStore.shared.notificationsEnabled else { return }

        if let workoutID {
            guard !processedWorkoutIDs.contains(workoutID) else { return }
            markProcessedWorkout(id: workoutID)
        }

        let fingerprint = buildFingerprint(
            workoutType: workoutType,
            duration: duration,
            keyMetrics: keyMetrics,
            endedAt: endedAt
        )
        guard !shouldSkipFingerprint(fingerprint, endedAt: endedAt) else { return }

        let language = preferredLanguage()
        let prompt = buildPrompt(
            language: language,
            workoutType: workoutType,
            duration: duration,
            keyMetrics: keyMetrics
        )

        let rawMessage: String
        do {
            rawMessage = try await intelligenceManager.generateCaptainResponse(for: prompt)
        } catch {
            rawMessage = fallbackMessage(
                language: language,
                workoutType: workoutType,
                duration: duration,
                keyMetrics: keyMetrics
            )
        }

        let finalMessage = normalizedToTwentyWords(
            rawMessage,
            language: language,
            workoutType: workoutType,
            duration: duration,
            keyMetrics: keyMetrics
        )

        scheduleWorkoutSummaryNotification(message: finalMessage)
    }

    // MARK: - Workout Monitoring

    private func installWorkoutObserverIfNeeded() async {
        guard !isMonitoring else { return }

        let type = HKObjectType.workoutType()
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
            guard let self else {
                completion()
                return
            }

            Task {
                await self.syncNewWorkouts()
                completion()
            }
        }

        workoutObserverQuery = query
        healthStore.execute(query)
        isMonitoring = true
    }

    private func syncNewWorkouts() async {
        if isSyncing {
            pendingSync = true
            return
        }
        isSyncing = true

        repeat {
            pendingSync = false

            let isBootstrapSync = workoutAnchor == nil
            let (workouts, newAnchor) = await fetchAnchoredWorkouts(anchor: workoutAnchor)
            if let newAnchor {
                workoutAnchor = newAnchor
                persistAnchor(newAnchor)
            }

            let sorted = workouts.sorted { $0.endDate < $1.endDate }
            let workoutsToProcess: [HKWorkout]
            if isBootstrapSync {
                let cutoff = Date().addingTimeInterval(-initialSyncLookbackSeconds)
                workoutsToProcess = sorted.filter { $0.endDate >= cutoff }
                let skippedCount = max(0, sorted.count - workoutsToProcess.count)
                if skippedCount > 0 {
                    print("🤖 [AIWorkoutSummaryService] Bootstrap sync skipped \(skippedCount) historical workouts.")
                }
            } else {
                workoutsToProcess = sorted
            }

            for workout in workoutsToProcess {
                let keyMetrics = await buildKeyMetrics(for: workout)
                await handleWorkoutEnded(
                    workoutType: Self.workoutTitle(for: workout.workoutActivityType),
                    duration: workout.duration,
                    keyMetrics: keyMetrics,
                    endedAt: workout.endDate,
                    workoutID: workout.uuid.uuidString
                )
            }
        } while pendingSync

        isSyncing = false
    }

    private func fetchAnchoredWorkouts(anchor: HKQueryAnchor?) async -> ([HKWorkout], HKQueryAnchor?) {
        await withCheckedContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: HKObjectType.workoutType(),
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, newAnchor, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: (workouts, newAnchor))
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Metrics & Prompting

    private func buildKeyMetrics(for workout: HKWorkout) async -> [String: Double] {
        let calories = totalActiveCalories(for: workout)
        let distanceKm = (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000.0
        let samples = await fetchHeartRateSamples(start: workout.startDate, end: workout.endDate)
        let zoneBounds = resolveZoneBounds()

        var belowSeconds = 0.0
        var zone2Seconds = 0.0
        var peakSeconds = 0.0

        if samples.isEmpty {
            let avg = averageHeartRate(for: workout, samples: [])
            let safeDuration = max(workout.duration, 1)
            if avg < zoneBounds.lower {
                belowSeconds = safeDuration
            } else if avg <= zoneBounds.upper {
                zone2Seconds = safeDuration
            } else {
                peakSeconds = safeDuration
            }
        } else {
            let sorted = samples.sorted { $0.startDate < $1.startDate }
            for index in sorted.indices {
                let sample = sorted[index]
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                let nextDate = index < sorted.count - 1 ? sorted[index + 1].startDate : workout.endDate
                let segmentSeconds = max(1, min(nextDate.timeIntervalSince(sample.startDate), 20))

                if bpm < zoneBounds.lower {
                    belowSeconds += segmentSeconds
                } else if bpm <= zoneBounds.upper {
                    zone2Seconds += segmentSeconds
                } else {
                    peakSeconds += segmentSeconds
                }
            }
        }

        let trackedSeconds = max(1, belowSeconds + zone2Seconds + peakSeconds)
        let averageHR = averageHeartRate(for: workout, samples: samples)

        return [
            "calories": calories,
            "distanceKm": distanceKm,
            "averageHeartRate": averageHR,
            "belowPercent": (belowSeconds / trackedSeconds) * 100,
            "zone2Percent": (zone2Seconds / trackedSeconds) * 100,
            "peakPercent": (peakSeconds / trackedSeconds) * 100,
            "belowMinutes": belowSeconds / 60,
            "zone2Minutes": zone2Seconds / 60,
            "peakMinutes": peakSeconds / 60
        ]
    }

    private func totalActiveCalories(for workout: HKWorkout) -> Double {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let sumQuantity = workout.statistics(for: energyType)?.sumQuantity() else {
            return 0
        }
        return sumQuantity.doubleValue(for: .kilocalorie())
    }

    private func averageHeartRate(for workout: HKWorkout, samples: [HKQuantitySample]) -> Double {
        let unit = HKUnit.count().unitDivided(by: .minute())
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
           let avgQuantity = workout.statistics(for: heartRateType)?.averageQuantity() {
            return avgQuantity.doubleValue(for: unit)
        }

        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(0.0) { partial, sample in
            partial + sample.quantity.doubleValue(for: unit)
        }
        return sum / Double(samples.count)
    }

    private func fetchHeartRateSamples(start: Date, end: Date) async -> [HKQuantitySample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func resolveZoneBounds() -> (lower: Double, upper: Double) {
        var age = UserProfileStore.shared.current.age
        if !(13...100).contains(age), let birthDate = UserProfileStore.shared.current.birthDate {
            age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 30
        }
        if !(13...100).contains(age) {
            age = 30
        }

        let maxHeartRate = max(100, 220 - age)
        let lower = Double(maxHeartRate) * 0.60
        let upper = Double(maxHeartRate) * 0.70
        return (lower, upper)
    }

    private func buildPrompt(
        language: CoachNotificationLanguage,
        workoutType: String,
        duration: TimeInterval,
        keyMetrics: [String: Double]
    ) -> String {
        let minutes = max(1, Int((duration / 60).rounded()))
        let calories = Int((keyMetrics["calories"] ?? 0).rounded())
        let averageHR = Int((keyMetrics["averageHeartRate"] ?? 0).rounded())
        let zone2 = Int((keyMetrics["zone2Percent"] ?? 0).rounded())
        let below = Int((keyMetrics["belowPercent"] ?? 0).rounded())
        let peak = Int((keyMetrics["peakPercent"] ?? 0).rounded())
        let distance = String(format: "%.2f", keyMetrics["distanceKm"] ?? 0)

        if language == .arabic {
            let direction: String
            if zone2 >= 55 {
                direction = "إذا قضى معظم الوقت في Zone 2 امدحه."
            } else if peak >= 35 {
                direction = "إذا دفع النبض فوق الحد كثيراً شجعه يهدّي الإيقاع."
            } else {
                direction = "شجعه يثبت الإيقاع ويرفع الجودة بالحصة الجاية."
            }

            return """
            أنت كابتن حمودي. اكتب ملخص تحفيزي باللهجة العراقية من 20 كلمة بالضبط، جملة واحدة فقط.
            بيانات التمرين:
            النوع: \(workoutType)
            المدة: \(minutes) دقيقة
            السعرات: \(calories)
            معدل النبض: \(averageHR) bpm
            المسافة: \(distance) كم
            توزيع النبض: تحت \(below)% | زون2 \(zone2)% | فوق/بيك \(peak)%
            \(direction)
            ممنوع الهاشتاك والإيموجي.
            """
        }

        let direction: String
        if zone2 >= 55 {
            direction = "Praise their pacing because they stayed mostly in Zone 2."
        } else if peak >= 35 {
            direction = "Encourage better control because they pushed too hard for too long."
        } else {
            direction = "Encourage steady progression and cleaner pacing next session."
        }

        return """
        You are Captain Hamoudi. Write exactly 20 words in English, one sentence only.
        Workout data:
        Type: \(workoutType)
        Duration: \(minutes) minutes
        Calories: \(calories)
        Average HR: \(averageHR) bpm
        Distance: \(distance) km
        HR zones: Below \(below)% | Zone2 \(zone2)% | Peak/Above \(peak)%
        \(direction)
        No hashtags and no emoji.
        """
    }

    private func fallbackMessage(
        language: CoachNotificationLanguage,
        workoutType: String,
        duration: TimeInterval,
        keyMetrics: [String: Double]
    ) -> String {
        let minutes = max(1, Int((duration / 60).rounded()))
        let zone2 = keyMetrics["zone2Percent"] ?? 0
        let peak = keyMetrics["peakPercent"] ?? 0

        if language == .arabic {
            if zone2 >= 55 {
                return "عفية بطل، تمرين \(workoutType) لمدة \(minutes) دقيقة كان موزون جداً بالزون تو، كمل بنفس الثبات والنتائج راح تصعد بسرعة."
            }
            if peak >= 35 {
                return "قوي يا بطل، تمرين \(workoutType) \(minutes) دقيقة كان حماسي، المرة الجاية هدي النفس شوي حتى تحافظ على جودة أعلى."
            }
            return "ممتاز يا بطل، تمرين \(workoutType) \(minutes) دقيقة نظيف، استمر بنفس الإيقاع وزيد الجودة تدريجياً وبذكاء بالحصة الجاية."
        }

        if zone2 >= 55 {
            return "Strong work on \(workoutType), \(minutes) minutes with excellent Zone 2 control. Keep this rhythm and your engine gets stronger."
        }
        if peak >= 35 {
            return "Powerful \(workoutType) session for \(minutes) minutes. Next round, control surges better so intensity stays productive and recovery improves faster."
        }
        return "Solid \(workoutType) effort for \(minutes) minutes. Stay consistent, pace smartly, and stack quality sessions to unlock bigger performance gains."
    }

    private func normalizedToTwentyWords(
        _ text: String,
        language: CoachNotificationLanguage,
        workoutType: String,
        duration: TimeInterval,
        keyMetrics: [String: Double]
    ) -> String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var words = compact.split(whereSeparator: \.isWhitespace).map(String.init)
        if words.count < 8 {
            words = fallbackMessage(
                language: language,
                workoutType: workoutType,
                duration: duration,
                keyMetrics: keyMetrics
            ).split(whereSeparator: \.isWhitespace).map(String.init)
        }

        if words.count > 20 {
            words = Array(words.prefix(20))
        } else if words.count < 20 {
            let fillers = language == .arabic
                ? ["عفية", "استمر", "بثبات", "وتنفس", "أقوى"]
                : ["keep", "steady", "strong", "and", "focused"]
            var index = 0
            while words.count < 20 {
                words.append(fillers[index % fillers.count])
                index += 1
            }
        }

        return words.joined(separator: " ")
    }

    private func scheduleWorkoutSummaryNotification(message: String) {
        let language = preferredLanguage()
        let content = UNMutableNotificationContent()
        content.title = localizedNotificationString(
            "notification.captain.workout.title",
            language: language,
            fallback: "Captain Hamoudi 🫡"
        )
        content.body = message
        content.sound = .default
        content.categoryIdentifier = CaptainSmartNotificationService.categoryIdentifier
        content.userInfo = [
            "notification_type": "workout_complete",
            "source": "captain_hamoudi",
            "messageText": message,
            "deepLink": "aiqo://captain"
        ]

        let request = UNNotificationRequest(
            identifier: "aiqo.captain.workout.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        notificationCenter.add(request)
    }

    // MARK: - Dedup

    private func markProcessedWorkout(id: String) {
        guard !processedWorkoutIDs.contains(id) else { return }
        processedWorkoutIDs.append(id)
        trimProcessedWorkouts()
        defaults.set(processedWorkoutIDs, forKey: processedWorkoutIDsKey)
    }

    private func trimProcessedWorkouts() {
        if processedWorkoutIDs.count > processedWorkoutLimit {
            processedWorkoutIDs = Array(processedWorkoutIDs.suffix(processedWorkoutLimit))
        }
    }

    private func buildFingerprint(
        workoutType: String,
        duration: TimeInterval,
        keyMetrics: [String: Double],
        endedAt: Date
    ) -> String {
        let minuteBucket = Int(endedAt.timeIntervalSince1970 / 60)
        let calories = Int((keyMetrics["calories"] ?? 0).rounded())
        let avgHR = Int((keyMetrics["averageHeartRate"] ?? 0).rounded())
        let zone2 = Int((keyMetrics["zone2Percent"] ?? 0).rounded())
        let peak = Int((keyMetrics["peakPercent"] ?? 0).rounded())
        let seconds = Int(duration.rounded())
        return "\(workoutType.lowercased())|\(seconds)|\(calories)|\(avgHR)|\(zone2)|\(peak)|\(minuteBucket)"
    }

    private func shouldSkipFingerprint(_ fingerprint: String, endedAt: Date) -> Bool {
        recentFingerprints = recentFingerprints.filter {
            abs(endedAt.timeIntervalSince($0.value)) <= fingerprintWindowSeconds
        }

        if let last = recentFingerprints[fingerprint],
           abs(endedAt.timeIntervalSince(last)) <= fingerprintWindowSeconds {
            return true
        }

        recentFingerprints[fingerprint] = endedAt
        if recentFingerprints.count > fingerprintLimit {
            let sorted = recentFingerprints.sorted { $0.value > $1.value }
            recentFingerprints = Dictionary(
                uniqueKeysWithValues: sorted.prefix(fingerprintLimit).map { ($0.key, $0.value) }
            )
        }
        return false
    }

    // MARK: - Auth & Background

    private func ensureAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return false
        }

        let readTypes: Set<HKObjectType> = [HKObjectType.workoutType(), heartRateType]
        do {
            try await healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: readTypes)
            return true
        } catch {
            return false
        }
    }

    private func enableBackgroundDelivery() async {
        await withCheckedContinuation { continuation in
            healthStore.enableBackgroundDelivery(
                for: HKObjectType.workoutType(),
                frequency: .immediate
            ) { _, _ in
                continuation.resume(returning: ())
            }
        }
    }

    // MARK: - Persistence

    private func persistAnchor(_ anchor: HKQueryAnchor) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else {
            return
        }
        defaults.set(data, forKey: workoutAnchorKey)
    }

    private func loadPersistedAnchor() -> HKQueryAnchor? {
        guard let data = defaults.data(forKey: workoutAnchorKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    // MARK: - Utilities

    private func preferredLanguage() -> CoachNotificationLanguage {
        resolvedCoachNotificationLanguage(defaults: defaults)
    }

    private static func workoutTitle(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .traditionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Functional Strength"
        case .coreTraining: return "Core"
        default: return "Workout"
        }
    }
}
