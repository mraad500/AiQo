import SwiftUI
import SwiftData
import UIKit
import UserNotifications
import BackgroundTasks
import WatchConnectivity
import AppIntents
import HealthKit
import WidgetKit

@main
struct AiQoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var globalBrain = CaptainViewModel()
    private let captainContainer: ModelContainer

    init() {
        DevOverride.warnIfActive()

        captainContainer = Self.makeCaptainContainer()

        // ربط الـ stores بالـ container
        MemoryStore.shared.configure(container: captainContainer, storageMode: Self.captainStorageMode)
        if MemoryV4Gate.isOn {
            let v4Container = captainContainer
            Task {
                await EpisodicStore.shared.configure(container: v4Container)
                await SemanticStore.shared.configure(container: v4Container)
                await ProceduralStore.shared.configure(container: v4Container)
                await EmotionalStore.shared.configure(container: v4Container)
                await RelationshipStore.shared.configure(container: v4Container)
                // 11_Directives — user-taught standing instructions.
                await DirectiveStore.shared.configure(container: v4Container)
                // Re-surface every still-active standing order into the prompt
                // mirror so it survives relaunch and the Captain never forgets.
                await DirectiveCoordinator.shared.hydratePromptMirror()
            }
            BackgroundCoordinator.shared.registerTasks()
            BackgroundCoordinator.shared.scheduleNextNightly()

            Task {
                await TriggerEvaluator.shared.registerAll([
                    SleepDebtTrigger(),
                    InactivityTrigger(),
                    PRTrigger(),
                    RecoveryTrigger(),
                    StreakRiskTrigger(),
                    DisengagementTrigger(),
                    EngagementMomentumTrigger(),
                    MemoryCallbackTrigger(),
                    EmotionalFollowUpTrigger(),
                    MoodShiftTrigger(),
                    RelationshipCheckInTrigger(),
                    MorningKickoffTrigger(),
                    CircadianNudgeTrigger(),
                    CulturalTrigger(),
                    TrialDayTrigger()
                ])
            }
        }

        // Observability subscribes to BrainBus so directive-lifecycle signals
        // (learned / fired / workout-seen) are auditable instead of silently
        // dropped. Unconditional + single call site (see BrainBusObserver).
        Task { await BrainBusObserver.start() }

        CaptainPersonalizationStore.shared.configure(container: captainContainer)
        RecordProjectManager.shared.configure(container: captainContainer)
        WeeklyMetricsBufferStore.shared.configure(container: captainContainer)
        WeeklyMemoryConsolidator.shared.configure(container: captainContainer)
        ConversationThreadManager.shared.configure(modelContext: captainContainer.mainContext)
        ConversationThreadManager.shared.pruneOldEntries()

        schedulePostLaunchWarmup()
    }

    private static var captainStorageMode: MemoryStore.StorageMode {
        MemoryV4Gate.storageMode
    }

    private static func makeCaptainContainer() -> ModelContainer {
        if !MemoryV4Gate.isOn {
            return makeCaptainContainerV3()
        }

        return makeCaptainContainerV4()
    }

    private static func captainStoreURL() throws -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appending(path: "captain_memory.store")
    }

    private static func makeCaptainContainerV3() -> ModelContainer {
        let schema = Schema(versionedSchema: CaptainSchemaV3.self)

        do {
            let config = ModelConfiguration(
                "CaptainMemoryStore",
                schema: schema,
                url: try captainStoreURL()
            )
            return try ModelContainer(
                for: schema,
                migrationPlan: CaptainSchemaMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            #if DEBUG
            print("[AppDelegate] Failed to create V3 CaptainMemory ModelContainer: \(error). Falling back to in-memory store.")
            #endif
            CrashReporter.shared.recordError(error, context: "captain_container_v3_failed")
            return makeInMemoryCaptainContainer(schema: schema)
        }
    }

    private static func makeCaptainContainerV4() -> ModelContainer {
        // Target the latest versioned schema (V5 adds LearnedDirective).
        // The migration plan carries the full V1→…→V5 chain, so existing
        // V3/V4 stores migrate forward via the lightweight V4→V5 stage.
        let schema = Schema(versionedSchema: MemorySchemaV5.self)

        do {
            let config = ModelConfiguration(
                "CaptainMemoryStore",
                schema: schema,
                url: try captainStoreURL()
            )
            return try ModelContainer(
                for: schema,
                migrationPlan: CaptainSchemaMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            // V4 container init failed (most commonly a migration error). Trip the
            // local fallback flag so subsequent launches use V3 directly, then load
            // V3 right now so this user keeps their data instead of dropping into
            // an in-memory store that loses everything on next launch.
            MemoryV4Gate.recordMigrationFailure(error, context: "captain_container_v4_failed")
            return makeCaptainContainerV3()
        }
    }

    private static func makeInMemoryCaptainContainer(schema: Schema) -> ModelContainer {
        do {
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [memoryConfig])
        } catch {
            // Even an in-memory container failed — effectively "SwiftData is
            // broken on this device". This last resort previously had NO
            // telemetry (unlike the V3 path) and a bare fatalError. Record it,
            // retry once with an isolated config, then keep a controlled,
            // REPORTED failure rather than a silent crash.
            CrashReporter.shared.recordError(error, context: "captain_in_memory_container_failed")
            if let retry = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            ) {
                return retry
            }
            CrashReporter.shared.recordError(error, context: "captain_container_unrecoverable")
            preconditionFailure("Captain memory container unrecoverable even in-memory: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(globalBrain)
                .onOpenURL { url in
                    if !DeepLinkRouter.shared.handle(url: url) {
                        _ = SpotifyVibeManager.shared.handleURL(url)
                    }
                }
        }
        .modelContainer(for: [
            AiQoDailyRecord.self,
            WorkoutTask.self,
            ArenaTribe.self,
            ArenaTribeMember.self,
            ArenaWeeklyChallenge.self,
            ArenaTribeParticipation.self,
            ArenaEmirateLeaders.self,
            ArenaHallOfFameEntry.self,
        ])
    }
}

final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Crashlytics must be configured before any other Firebase call.
        CrashReportingService.shared.configure()

        // Bind user ID for returning users who are already signed in.
        if let userID = SupabaseService.shared.currentUserID {
            CrashReportingService.shared.setUser(id: userID)
        }

        _ = PhoneConnectivityManager.shared

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Core services initialization
        _ = CrashReporter.shared
        _ = NetworkMonitor.shared
        AnalyticsService.shared.track(.appLaunched)
        _ = FreeTrialManager.shared

        // Remote kill switches. Fire-and-forget; cached UserDefaults value is what
        // the gate reads synchronously. Changes propagate to the next cold launch.
        Task.detached(priority: .utility) {
            await RemoteFlags.shared.refresh()
        }

        // Subscribe NotificationBrain to XP / streak events so proactive Captain
        // notifications can fire. Gated by both the Memory V4 cascade AND its own
        // Info.plist flag so we can dark-launch independently.
        if FeatureFlags.notificationBrainEnabled {
            Task {
                await NotificationBrain.shared.subscribe()
            }
        }

        // Register CrisisDetector when the flag is on. Previously declared but unread
        // (dead flag pre-v1.0.4). The singleton init is sufficient — CrisisDetector
        // listens passively to emotional patterns + bio signals via its dependencies.
        if FeatureFlags.crisisDetectorEnabled {
            _ = CrisisDetector.shared
        }

        LocalizationManager.shared.applySavedLanguage()

        #if DEBUG
        if ScreenshotMode.isActive {
            return true
        }
        #endif

        NotificationCategoryManager.shared.registerAllCategories()
        SmartNotificationScheduler.shared.registerBackgroundTasks()
        Task { @MainActor in
            PurchaseManager.shared.start()
        }
        let didCompleteOnboarding = UserDefaults.standard.bool(forKey: "didSelectLanguage")
            && UserDefaults.standard.bool(forKey: "didShowFirstAuthScreen")
            && UserDefaults.standard.bool(forKey: "didCompleteDatingProfile")
            && UserDefaults.standard.bool(forKey: "didCompleteLegacyCalculation")
            && UserDefaults.standard.bool(forKey: "didCompleteAIConsent")
            && UserDefaults.standard.bool(forKey: "didAcknowledgeMedicalDisclaimer")
            && (UserDefaults.standard.bool(forKey: "didCompleteCaptainPersonalization")
                || UserDefaults.standard.bool(forKey: "didCompleteFeatureIntro"))
            && UserDefaults.standard.bool(forKey: "didCompleteFeatureIntro")
        if didCompleteOnboarding {
            HealthKitService.permissionFlowEnabled = true
            NotificationService.shared.requestPermissions()
            application.registerForRemoteNotifications()
            MorningHabitOrchestrator.shared.start()
            TrialJourneyOrchestrator.shared.start()
            SleepSessionObserver.shared.start()

            Task {
                await AIWorkoutSummaryService.shared.startMonitoringWorkoutEnds()
            }

            if AppSettingsStore.shared.notificationsEnabled {
                SmartNotificationScheduler.shared.refreshAutomationState()
            } else {
                SmartNotificationScheduler.shared.cancelScheduledBackgroundTasks()
            }
        }

        if #available(iOS 16.0, *) {
            AiQoWorkoutShortcuts.updateAppShortcutParameters()
        }

        Task { @MainActor in
            await Task.yield()
            SiriShortcutsManager.shared.donateAllShortcuts()
            StreakManager.shared.checkStreakContinuity()
        }

        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return SiriShortcutsManager.shared.handle(activity: userActivity)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AnalyticsService.shared.track(.appBecameActive)
        PhoneConnectivityManager.shared.refreshFromCompanionApplicationContext()
        reloadWidgetTimelines()
        clearAppBadge()

        // Only start HealthKit-dependent services for users who completed ALL onboarding steps.
        let allOnboardingDone = UserDefaults.standard.bool(forKey: "didSelectLanguage")
            && UserDefaults.standard.bool(forKey: "didShowFirstAuthScreen")
            && UserDefaults.standard.bool(forKey: "didCompleteDatingProfile")
            && UserDefaults.standard.bool(forKey: "didCompleteLegacyCalculation")
            && UserDefaults.standard.bool(forKey: "didCompleteAIConsent")
            && UserDefaults.standard.bool(forKey: "didAcknowledgeMedicalDisclaimer")
            && (UserDefaults.standard.bool(forKey: "didCompleteCaptainPersonalization")
                || UserDefaults.standard.bool(forKey: "didCompleteFeatureIntro"))
            && UserDefaults.standard.bool(forKey: "didCompleteFeatureIntro")
        if allOnboardingDone {
            HealthKitService.permissionFlowEnabled = true
            MorningHabitOrchestrator.shared.start()
            SleepSessionObserver.shared.start()

            Task {
                await AIWorkoutSummaryService.shared.startMonitoringWorkoutEnds()
                await MorningHabitOrchestrator.shared.refreshMonitoringState()
                await CaptainSmartNotificationService.shared.evaluateInactivityAndNotifyIfNeeded()
            }
        }

        if CaptainNotificationHandler.shared.hasPendingMessage() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                CaptainNavigationHelper.shared.navigateToCaptainScreen()
            }
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        PhoneConnectivityManager.shared.refreshFromCompanionApplicationContext()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        AnalyticsService.shared.track(.appEnteredBackground)
        SmartNotificationScheduler.shared.scheduleQueuedDeveloperNudgeIfNeeded()

        if AppSettingsStore.shared.notificationsEnabled {
            SmartNotificationScheduler.shared.scheduleBackgroundTasksIfNeeded()
        } else {
            SmartNotificationScheduler.shared.cancelScheduledBackgroundTasks()
        }
    }

    private func clearAppBadge() {
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    private func reloadWidgetTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: "AiQoWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "AiQoRingsFaceWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "AiQoWatchFaceWidget")
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
        let content = response.notification.request.content
        let userInfo = content.userInfo
        let notifType = (userInfo["source"] as? String) ?? response.notification.request.identifier
        AnalyticsService.shared.track(.notificationTapped(type: notifType))

        if let trialKind = userInfo["trialKind"] as? String {
            AnalyticsService.shared.track(.trialNotificationOpened(kind: trialKind))
        }

        CaptainNotificationHandler.shared.handleIncomingNotification(
            userInfo: userInfo,
            fallbackBody: content.body
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            CaptainNavigationHelper.shared.navigateToCaptainScreen()
        }

        completionHandler()
    }
}

private extension AiQoApp {
    func schedulePostLaunchWarmup() {
        Task(priority: .utility) { @MainActor in
            await Task.yield()

            // Cleanup can touch a large local store, so defer until the first frame is shown.
            MemoryStore.shared.removeStale()

            // Health sync is useful but not required for the very first screen render.
            if UserDefaults.standard.bool(forKey: "didCompleteLegacyCalculation") {
                await HealthKitMemoryBridge.syncHealthDataToMemory()
            }
        }
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
    static let description = IntentDescription("Start a workout session.")
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
            return .result(dialog: "تمام، بدأنا تمرين \(workout.rawValue).")
        } else {
            return .result(dialog: "ما كدرت أبدي التمرين. تأكد أن الجهاز القابل للارتداء قريب ومتاح.")
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
