import Foundation
import HealthKit
import UserNotifications

// MARK: - Workout Summary Notifier

@MainActor
final class WorkoutSummaryNotifier {
    static let shared = WorkoutSummaryNotifier()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let healthStore = HKHealthStore()

    private init() {}

    func handleWorkoutEnded(_ workout: HKWorkout) async {
        // 1. Wait 30 seconds (allows HealthKit to finalize metrics)
        try? await Task.sleep(nanoseconds: UInt64(BriefingRules.workoutSummaryDelaySeconds * 1_000_000_000))

        // 2. Check setting
        guard BriefingSettingsStore.shared.settings.workoutSummaryEnabled else { return }

        // 3. Build context from live stores
        let context = await CaptainBriefingScheduler.shared.buildBriefingContext()

        // 4. Generate Captain summary
        let content = await BriefingContentGenerator.shared.generate(for: .workoutSummary, context: context)

        // 5. Build notification
        let workoutType = AIWorkoutSummaryService.workoutTitle(for: workout.workoutActivityType)

        let notifContent = UNMutableNotificationContent()
        notifContent.title = content.title
        notifContent.body = content.body
        notifContent.sound = .default
        notifContent.categoryIdentifier = "WORKOUT_SUMMARY"
        notifContent.userInfo = [
            "slot": BriefingSlot.workoutSummary.rawValue,
            "source": "captain_hamoudi",
            "messageText": content.body,
            "deepLink": "aiqo://captain",
            "notification_type": "workout_summary",
            "workoutType": workoutType,
            "durationMinutes": Int((workout.duration / 60).rounded()),
            "calories": Int(totalActiveCalories(for: workout).rounded()),
            "averageHR": Int((await averageHeartRate(for: workout)).rounded()),
            "distanceKm": (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000.0
        ]

        let request = UNNotificationRequest(
            identifier: "\(BriefingSlot.workoutSummary.identifier).\(UUID().uuidString)",
            content: notifContent,
            trigger: nil
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("[WorkoutSummaryNotifier] Failed to schedule: \(error.localizedDescription)")
        }
    }

    // MARK: - Dynamic Category Registration

    func refreshCategoryForCurrentLanguage() {
        let language = BriefingLanguage.from(AppSettingsStore.shared.appLanguage)
        let categories = Self.buildCategories(for: language)
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }

    static func registerCategories() {
        let language = BriefingLanguage.from(AppSettingsStore.shared.appLanguage)
        let categories = buildCategories(for: language)
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }

    private static func buildCategories(for language: BriefingLanguage) -> Set<UNNotificationCategory> {
        let actionTitle = language == .arabic ? "افتح الملخص الكامل" : "Open Full Summary"
        let openAction = UNNotificationAction(
            identifier: "OPEN_WORKOUT_SUMMARY",
            title: actionTitle,
            options: [.foreground]
        )

        let briefingCategory = UNNotificationCategory(
            identifier: "CAPTAIN_BRIEFING",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let workoutCategory = UNNotificationCategory(
            identifier: "WORKOUT_SUMMARY",
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        return [briefingCategory, workoutCategory]
    }

    // MARK: - Metrics

    private func totalActiveCalories(for workout: HKWorkout) -> Double {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let sumQuantity = workout.statistics(for: energyType)?.sumQuantity() else {
            return 0
        }
        return sumQuantity.doubleValue(for: .kilocalorie())
    }

    private func averageHeartRate(for workout: HKWorkout) async -> Double {
        let unit = HKUnit.count().unitDivided(by: .minute())

        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
           let avgQuantity = workout.statistics(for: heartRateType)?.averageQuantity() {
            return avgQuantity.doubleValue(for: unit)
        }

        return 0
    }
}
