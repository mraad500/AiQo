import Foundation
import UserNotifications
import HealthKit
import UIKit
import Combine

// MARK: - Briefing Slot Definitions

enum BriefingSlot: String, CaseIterable, Codable {
    case morningHero       // Slot 1: Dynamic, after wake + 40 steps
    case middayPulse       // Slot 2: 14:22, skip if daily ring >= 100%
    case eveningReflection // Slot 3: 17:55, skip if daily ring >= 100%
    case windDown          // Slot 4: 22:10, always (unless user muted)
    case workoutSummary    // Slot 5: Event-based, 30s after HKWorkoutSession ends

    var identifier: String { "aiqo.briefing.\(rawValue)" }

    func displayName(language: BriefingLanguage) -> String {
        switch (self, language) {
        case (.morningHero, .arabic):       return "صباح الأبطال"
        case (.morningHero, .english):      return "Morning Briefing"
        case (.middayPulse, .arabic):       return "شحنة الظهر"
        case (.middayPulse, .english):      return "Midday Pulse"
        case (.eveningReflection, .arabic): return "لحظة المساء"
        case (.eveningReflection, .english):return "Evening Reflection"
        case (.windDown, .arabic):          return "استعداد النوم"
        case (.windDown, .english):         return "Wind Down"
        case (.workoutSummary, .arabic):    return "ملخص التمرين"
        case (.workoutSummary, .english):   return "Workout Summary"
        }
    }

    func description(language: BriefingLanguage) -> String {
        switch (self, language) {
        case (.morningHero, .arabic):       return "رسالة تحفيزية بعد استيقاظك"
        case (.morningHero, .english):      return "Motivational message after waking up"
        case (.middayPulse, .arabic):       return "تشجيع منتصف اليوم"
        case (.middayPulse, .english):      return "Midday encouragement"
        case (.eveningReflection, .arabic): return "تقييم يومك"
        case (.eveningReflection, .english):return "Review your day"
        case (.windDown, .arabic):          return "تذكير بالراحة والنوم"
        case (.windDown, .english):         return "Rest and sleep reminder"
        case (.workoutSummary, .arabic):    return "ملخص بعد كل تمرين"
        case (.workoutSummary, .english):   return "Summary after each workout"
        }
    }

    func timeLabel(language: BriefingLanguage) -> String {
        switch (self, language) {
        case (.morningHero, .arabic):       return "بعد استيقاظك"
        case (.morningHero, .english):      return "After waking up"
        case (.middayPulse, .arabic):       return "٢:٢٢ مساءً"
        case (.middayPulse, .english):      return "2:22 PM"
        case (.eveningReflection, .arabic): return "٥:٥٥ مساءً"
        case (.eveningReflection, .english):return "5:55 PM"
        case (.windDown, .arabic):          return "١٠:١٠ مساءً"
        case (.windDown, .english):         return "10:10 PM"
        case (.workoutSummary, .arabic):    return "بعد التمرين"
        case (.workoutSummary, .english):   return "After workout"
        }
    }

    var fixedTime: DateComponents? {
        switch self {
        case .middayPulse:       return DateComponents(hour: 14, minute: 22)
        case .eveningReflection: return DateComponents(hour: 17, minute: 55)
        case .windDown:          return DateComponents(hour: 22, minute: 10)
        default:                 return nil
        }
    }
}

// MARK: - Hard Rules

enum BriefingRules {
    static let quietHoursStart = 23   // 23:00
    static let quietHoursEnd   = 5    // 05:00
    static let appOpenSuppressionMinutes = 60
    static let morningStepThreshold = 40
    static let morningWindowStart = 5     // 05:00
    static let morningWindowEnd = 11      // 11:00
    static let workoutSummaryDelaySeconds: TimeInterval = 30
    static let dailyRingCompleteThreshold: Double = 1.0  // 100%
}

// MARK: - Captain Briefing Scheduler

@MainActor
final class CaptainBriefingScheduler: ObservableObject {
    static let shared = CaptainBriefingScheduler()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    private var stepObserverQuery: HKObserverQuery?
    private var hasStartedStepObserver = false

    private init() {}

    // MARK: - Authorization

    func requestAuthorizationIfNeeded() async {
        let settings = await notificationCenter.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    await MainActor.run {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            } catch {
                print("[CaptainBriefingScheduler] Authorization request failed: \(error.localizedDescription)")
            }
        case .authorized, .provisional, .ephemeral:
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        case .denied:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Schedule All

    func rescheduleAll() async {
        let settings = BriefingSettingsStore.shared.settings
        let language = currentLanguage()

        // Cancel all existing briefing notifications
        cancelAll()

        // Slot 2: Midday Pulse (fixed time)
        if settings.middayPulseEnabled, let time = BriefingSlot.middayPulse.fixedTime {
            scheduleFixedTime(slot: .middayPulse, time: time, language: language)
        }

        // Slot 3: Evening Reflection (fixed time)
        if settings.eveningReflectionEnabled, let time = BriefingSlot.eveningReflection.fixedTime {
            scheduleFixedTime(slot: .eveningReflection, time: time, language: language)
        }

        // Slot 4: Wind Down (fixed time)
        if settings.windDownEnabled, let time = BriefingSlot.windDown.fixedTime {
            scheduleFixedTime(slot: .windDown, time: time, language: language)
        }

        // Slot 1: Morning Hero — NOT pre-scheduled (step-triggered)
        if settings.morningHeroEnabled {
            await startMorningStepObservation()
        }

        // Slot 5: Workout Summary — event-based, handled by WorkoutSummaryNotifier
    }

    // MARK: - App Lifecycle

    func handleAppDidBecomeActive() {
        BriefingSettingsStore.shared.recordAppOpen()
    }

    // MARK: - Morning Step Trigger (Slot 1)

    func handleHealthKitStepUpdate(_ steps: Int, since wakeTime: Date) async {
        let settings = BriefingSettingsStore.shared.settings
        guard settings.morningHeroEnabled else { return }

        let now = Date()
        let hour = calendar.component(.hour, from: now)
        guard hour >= BriefingRules.morningWindowStart && hour < BriefingRules.morningWindowEnd else { return }
        guard steps >= BriefingRules.morningStepThreshold else { return }

        // Check if already fired today
        if let lastFire = settings.lastMorningFireDate,
           calendar.isDateInToday(lastFire) {
            return
        }

        // Generate and fire immediately
        let context = await buildBriefingContext()
        let content = await BriefingContentGenerator.shared.generate(for: .morningHero, context: context)

        let notifContent = UNMutableNotificationContent()
        notifContent.title = content.title
        notifContent.body = content.body
        notifContent.sound = .default
        notifContent.categoryIdentifier = content.categoryIdentifier
        notifContent.userInfo = briefingUserInfo(for: .morningHero, body: content.body)

        let request = UNNotificationRequest(
            identifier: BriefingSlot.morningHero.identifier,
            content: notifContent,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        do {
            try await notificationCenter.add(request)
            BriefingSettingsStore.shared.recordMorningFire()
        } catch {
            print("[CaptainBriefingScheduler] Morning briefing failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Workout Summary (Slot 5)

    func handleWorkoutDidEnd(_ workout: HKWorkout) async {
        await WorkoutSummaryNotifier.shared.handleWorkoutEnded(workout)
    }

    // MARK: - Cancel

    func cancelAll() {
        let identifiers = BriefingSlot.allCases.map(\.identifier)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func cancel(slot: BriefingSlot) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [slot.identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [slot.identifier])
    }

    // MARK: - Helpers

    func currentLanguage() -> BriefingLanguage {
        BriefingLanguage.from(AppSettingsStore.shared.appLanguage)
    }

    // MARK: - Private: Fixed-Time Scheduling

    private func scheduleFixedTime(slot: BriefingSlot, time: DateComponents, language: BriefingLanguage) {
        let content = UNMutableNotificationContent()
        content.title = slot.displayName(language: language)
        content.body = language == .arabic ? "جاري التحضير..." : "Preparing..."
        content.sound = .default
        content.categoryIdentifier = "CAPTAIN_BRIEFING"
        content.userInfo = [
            "slot": slot.rawValue,
            "source": "captain_hamoudi",
            "needsContentGeneration": true
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)

        let request = UNNotificationRequest(
            identifier: slot.identifier,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error {
                print("[CaptainBriefingScheduler] Failed to schedule \(slot.rawValue): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private: Morning Step Observation

    private func startMorningStepObservation() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard !hasStartedStepObserver else { return }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self else {
                completionHandler()
                return
            }

            if let error {
                print("[CaptainBriefingScheduler] Step observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }

            Task { @MainActor [weak self] in
                defer { completionHandler() }
                guard let self else { return }

                let wakeTime = MorningHabitOrchestrator.shared.scheduledWakeDate ?? Calendar.current.startOfDay(for: Date())
                let now = Date()
                guard now > wakeTime else { return }

                let steps = await self.fetchStepsSinceWake(from: wakeTime, to: now)
                await self.handleHealthKitStepUpdate(steps, since: wakeTime)
            }
        }

        stepObserverQuery = query
        healthStore.execute(query)
        hasStartedStepObserver = true
    }

    private func fetchStepsSinceWake(from startDate: Date, to endDate: Date) async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if error != nil {
                    continuation.resume(returning: 0)
                    return
                }
                let count = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(count.rounded()))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Build Context

    func buildBriefingContext() async -> BriefingContext {
        let metrics: CaptainDailyHealthMetrics
        do {
            metrics = try await CaptainIntelligenceManager.shared.fetchTodayEssentialMetrics()
        } catch {
            metrics = CaptainDailyHealthMetrics(
                stepCount: 0,
                activeEnergyKilocalories: 0,
                averageOrCurrentHeartRateBPM: nil,
                sleepHours: 0
            )
        }

        let goals = GoalsStore.shared.current
        let stepsGoal = max(1, goals.steps)
        let dailyRingProgress = Double(metrics.stepCount) / Double(stepsGoal)

        let userName = UserProfileStore.shared.current.name ?? (currentLanguage() == .arabic ? "بطل" : "Champ")
        let language = currentLanguage()
        let gender = BriefingGender.from(UserProfileStore.shared.current.gender)

        return BriefingContext(
            stepsToday: metrics.stepCount,
            stepsGoal: stepsGoal,
            activeCaloriesToday: Double(metrics.activeEnergyKilocalories),
            sleepHoursLastNight: metrics.sleepHours > 0 ? metrics.sleepHours : nil,
            dailyRingProgress: dailyRingProgress,
            userFirstName: userName,
            language: language,
            gender: gender,
            userTier: EntitlementStore.shared.currentTier
        )
    }

    // MARK: - Private: UserInfo Builder

    private func briefingUserInfo(for slot: BriefingSlot, body: String) -> [String: Any] {
        [
            "slot": slot.rawValue,
            "source": "captain_hamoudi",
            "messageText": body,
            "deepLink": "aiqo://captain",
            "notification_type": "captain_briefing"
        ]
    }
}
