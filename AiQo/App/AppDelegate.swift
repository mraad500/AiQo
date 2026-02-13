import UIKit
import UserNotifications
import FamilyControls
import WatchConnectivity
import AppIntents
import HealthKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        _ = PhoneConnectivityManager.shared

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        LocalizationManager.shared.applySavedLanguage()
        NotificationService.shared.requestPermissions()

        application.registerForRemoteNotifications()

        ActivityNotificationEngine.shared.registerNotificationCategories()
        CaptainSmartNotificationService.shared.registerNotificationCategories()

        if AppSettingsStore.shared.notificationsEnabled {
            scheduleAngelNotifications()
        }
        
        if #available(iOS 16.0, *) {
            AiQoWorkoutShortcuts.updateAppShortcutParameters()
        }

        return true
    }

    private func scheduleAngelNotifications() {
        let genderString = UserDefaults.standard.string(forKey: "user_gender") ?? "male"
        let gender: ActivityNotificationGender = genderString == "female" ? .female : .male

        let appLanguage = AppSettingsStore.shared.appLanguage
        let language: ActivityNotificationLanguage = appLanguage == .english ? .english : .arabic

        ActivityNotificationEngine.shared.scheduleAngelNumberNotifications(
            gender: gender,
            language: language
        )

        #if DEBUG
        ActivityNotificationEngine.shared.printPendingNotifications()
        #endif
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        clearAppBadge()

        Task {
            await CaptainSmartNotificationService.shared.evaluateInactivityAndNotifyIfNeeded()
        }

        if CaptainNotificationHandler.shared.hasPendingMessage() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                CaptainNavigationHelper.shared.navigateToCaptainScreen()
            }
        }
    }

    private func clearAppBadge() {
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        SupabaseService.shared.updateDeviceToken(token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        NotificationService.shared.handleRemoteNotification(userInfo: userInfo)
        completionHandler(.newData)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let source = userInfo["source"] as? String, source == "captain_hamoudi" {
            CaptainNotificationHandler.shared.handleIncomingNotification(userInfo: userInfo)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                CaptainNavigationHelper.shared.navigateToCaptainScreen()
            }
        } else {
            NotificationService.shared.handle(response: response)
        }

        completionHandler()
    }
}

// MARK: - Siri Workout Intents

@available(iOS 16.0, *)
enum SiriWorkoutType: String, AppEnum {
    case running
    case walking
    case cycling
    case strength
    case hiit
    case swimming
    case yoga

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout")

    static var caseDisplayRepresentations: [SiriWorkoutType : DisplayRepresentation] = [
        .running: "Running",
        .walking: "Walking",
        .cycling: "Cycling",
        .strength: "Strength",
        .hiit: "HIIT",
        .swimming: "Swimming",
        .yoga: "Yoga"
    ]

    var activityType: HKWorkoutActivityType {
        switch self {
        case .running: return .running
        case .walking: return .walking
        case .cycling: return .cycling
        case .strength: return .traditionalStrengthTraining
        case .hiit: return .highIntensityIntervalTraining
        case .swimming: return .swimming
        case .yoga: return .yoga
        }
    }
}

@available(iOS 16.0, *)
enum SiriWorkoutLocation: String, AppEnum {
    case indoor
    case outdoor

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Location")

    static var caseDisplayRepresentations: [SiriWorkoutLocation : DisplayRepresentation] = [
        .indoor: "Indoor",
        .outdoor: "Outdoor"
    ]

    var hkLocation: HKWorkoutSessionLocationType {
        switch self {
        case .indoor: return .indoor
        case .outdoor: return .outdoor
        }
    }
}

@available(iOS 16.0, *)
struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Workout"
    static let description = IntentDescription("Start an Apple Watch workout from Siri.")
    static let openAppWhenRun = false

    @Parameter(title: "Workout", default: .running)
    var workout: SiriWorkoutType

    @Parameter(title: "Location", default: .outdoor)
    var location: SiriWorkoutLocation

    init() {}

    init(workout: SiriWorkoutType, location: SiriWorkoutLocation = .outdoor) {
        self.workout = workout
        self.location = location
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let workoutType = HKObjectType.workoutType()
        let status = HKHealthStore().authorizationStatus(for: workoutType)

        if status == .sharingDenied {
            return .result(dialog: "رجاءً فعّل صلاحية Health للتمارين داخل إعدادات AiQo أولاً.")
        }

        if status == .notDetermined {
            let granted = await requestHealthAuthorization()
            if !granted {
                return .result(dialog: "ما قدرت أحصل صلاحية Health. افتح AiQo مرة وحدة ووافق على الصلاحيات ثم جرّب من جديد.")
            }
        }

        let success = await startWatchWorkout(
            activityType: workout.activityType,
            locationType: location.hkLocation
        )

        if success {
            return .result(dialog: "تمام، بدينا تمرين \(workout.rawValue) على Apple Watch.")
        } else {
            return .result(dialog: "ما كدرت أبدي التمرين. تأكد Apple Watch قريبة ومفتوحة.")
        }
    }

    @MainActor
    private func requestHealthAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            HealthKitManager.shared.requestAuthorization { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    @MainActor
    private func startWatchWorkout(
        activityType: HKWorkoutActivityType,
        locationType: HKWorkoutSessionLocationType
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            HealthKitManager.shared.startWatchWorkout(
                activityType: activityType,
                locationType: locationType
            ) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}

@available(iOS 16.0, *)
struct AiQoWorkoutShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(workout: .running, location: .outdoor),
            phrases: [
                "Start workout with \(.applicationName)",
                "Start running workout with \(.applicationName)",
                "ابدأ تمرين في \(.applicationName)",
                "ابدأ تمرين جري في \(.applicationName)"
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.run"
        )
        AppShortcut(
            intent: StartWorkoutIntent(workout: .walking, location: .outdoor),
            phrases: [
                "Start walking workout with \(.applicationName)",
                "ابدأ تمرين مشي في \(.applicationName)"
            ],
            shortTitle: "Start Walk",
            systemImageName: "figure.walk"
        )
    }
}
