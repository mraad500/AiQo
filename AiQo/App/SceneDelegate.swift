import SwiftUI
import SwiftData
import Supabase
import Auth
import HealthKit
import Combine

enum OnboardingKeys {
    static let didCompleteLegacyCalculation = "didCompleteLegacyCalculation"
    static let didCompleteCaptainPersonalization = "didCompleteCaptainPersonalization"
    static let didCompleteFeatureIntro = "didCompleteFeatureIntro"
    static let didShowFirstAuthScreen = "didShowFirstAuthScreen"
    static let didCompleteDatingProfile = "didCompleteDatingProfile"
    static let didSelectLanguage = "didSelectLanguage"
}

@MainActor
final class AppFlowController: ObservableObject {
    static let shared = AppFlowController()

    enum RootScreen {
        case languageSelection
        case login
        case profileSetup
        case legacy
        case captainPersonalization
        case featureIntro
        case main
    }

    @Published private(set) var currentScreen: RootScreen
    @Published private(set) var refreshID = UUID()

    private let protectionModel = ProtectionModel.shared

    private init() {
        QuestPersistenceController.shared.installQuestPersistence()
        currentScreen = Self.resolveCurrentScreen()
    }

    func didSelectLanguage() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didSelectLanguage)
        transition(to: .login)
    }

    func didLoginSuccessfully() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didShowFirstAuthScreen)
        if let userID = SupabaseService.shared.currentUserID {
            CrashReportingService.shared.setUser(id: userID)
        }
        transition(to: Self.nextScreenAfterLogin())
    }

    func didCompleteProfileSetup() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteDatingProfile)
        transition(to: .legacy)
    }

    func didCompleteDatingProfile() {
        didCompleteProfileSetup()
    }

    func finishOnboardingWithoutAdditionalPermissions() {
        Task { @MainActor in
            // User chose to skip — don't prompt for FamilyControls or HealthKit permissions
            finalizeLegacyStep()
        }
    }

    func finishOnboardingRequestingPermissions() {
        Task { @MainActor in
            HealthKitService.permissionFlowEnabled = true
            await requestFullHealthKitPermissions()
            requestNotificationAuthorizationIfNeeded()
            await protectionModel.requestAuthorization()
            finalizeLegacyStep()

            // Start HealthKit-dependent services now that onboarding is complete
            // and permissions have been granted (deferred from AppDelegate for new users).
            UIApplication.shared.registerForRemoteNotifications()
            MorningHabitOrchestrator.shared.start()
            SleepSessionObserver.shared.start()
            Task {
                await AIWorkoutSummaryService.shared.startMonitoringWorkoutEnds()
            }
        }
    }

    func onboardingFinished() {
        finishOnboardingRequestingPermissions()
    }

    private func finalizeLegacyStep() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteLegacyCalculation)
        FreeTrialManager.shared.startTrialIfNeeded()
        transition(to: .captainPersonalization)
    }

    func didCompleteCaptainPersonalization() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteCaptainPersonalization)
        transition(to: .featureIntro)
    }

    func didCompleteFeatureIntro() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteFeatureIntro)
        MainTabRouter.shared.navigate(to: .home)
        transition(to: .main)
    }

    private func requestFullHealthKitPermissions() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let healthStore = HKHealthStore()

        let allReadTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.walkingHeartRateAverage),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.vo2Max),
            HKQuantityType(.bodyMass),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.appleStandTime),
            HKCategoryType(.sleepAnalysis),
            HKObjectType.activitySummaryType(),
            HKObjectType.workoutType()
        ]

        let allWriteTypes: Set<HKSampleType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.vo2Max),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.bodyMass),
            HKObjectType.workoutType()
        ]

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            healthStore.requestAuthorization(toShare: allWriteTypes, read: allReadTypes) { _, _ in
                continuation.resume()
            }
        }
    }

    func logout() {
        Task { @MainActor in
            try? await SupabaseService.shared.client.auth.signOut()

            UserDefaults.standard.set(false, forKey: OnboardingKeys.didCompleteLegacyCalculation)
            UserDefaults.standard.set(false, forKey: OnboardingKeys.didCompleteCaptainPersonalization)
            UserDefaults.standard.set(false, forKey: OnboardingKeys.didCompleteFeatureIntro)
            UserDefaults.standard.set(false, forKey: OnboardingKeys.didCompleteDatingProfile)
            UserDefaults.standard.set(false, forKey: OnboardingKeys.didShowFirstAuthScreen)

            MainTabRouter.shared.navigate(to: .home)
            transition(to: .login)
        }
    }

    func reloadCurrentScreen() {
        currentScreen = Self.resolveCurrentScreen()
        refreshID = UUID()
    }

    private func transition(to screen: RootScreen) {
        withAnimation(.easeInOut(duration: 0.4)) {
            currentScreen = screen
            refreshID = UUID()
        }
    }

    private static func resolveCurrentScreen() -> RootScreen {
        #if DEBUG
        if ScreenshotMode.isActive { return .main }
        #endif

        let didSelectLanguage = UserDefaults.standard.bool(forKey: OnboardingKeys.didSelectLanguage)
        let didShowFirstAuthScreen = UserDefaults.standard.bool(forKey: OnboardingKeys.didShowFirstAuthScreen)
        let didCompleteDatingProfile = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteDatingProfile)
        let didCompleteLegacyCalculation = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteLegacyCalculation)
        let didCompleteFeatureIntro = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteFeatureIntro)
        let didCompleteCaptainPersonalization = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteCaptainPersonalization)
            || didCompleteFeatureIntro

        // Check Supabase session — attempt to recover expired sessions before falling back to login
        let isLoggedIn: Bool = {
            if SupabaseService.shared.client.auth.currentUser != nil { return true }
            // If user completed full onboarding but session expired, let them through
            // to main screen. Supabase will refresh the token on next API call.
            if didCompleteLegacyCalculation && didCompleteDatingProfile && didShowFirstAuthScreen {
                return true
            }
            return false
        }()

        guard didSelectLanguage else { return .languageSelection }
        guard didShowFirstAuthScreen else { return .login }
        guard isLoggedIn else { return .login }

        if !didCompleteDatingProfile {
            return .profileSetup
        }

        if !didCompleteLegacyCalculation {
            return .legacy
        }

        if !didCompleteCaptainPersonalization {
            return .captainPersonalization
        }

        if !didCompleteFeatureIntro {
            return .featureIntro
        }

        return .main
    }

    private static func nextScreenAfterLogin() -> RootScreen {
        let didCompleteDatingProfile = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteDatingProfile)
        let didCompleteLegacyCalculation = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteLegacyCalculation)
        let didCompleteFeatureIntro = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteFeatureIntro)
        let didCompleteCaptainPersonalization = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteCaptainPersonalization)
            || didCompleteFeatureIntro

        if !didCompleteDatingProfile {
            return .profileSetup
        }

        if !didCompleteLegacyCalculation {
            return .legacy
        }

        if !didCompleteCaptainPersonalization {
            return .captainPersonalization
        }

        if !didCompleteFeatureIntro {
            return .featureIntro
        }

        return .main
    }

    private func requestNotificationAuthorizationIfNeeded() {
        NotificationService.shared.requestPermissions()
    }
}

struct AppRootView: View {
    @StateObject private var flow = AppFlowController.shared
    @EnvironmentObject private var globalBrain: CaptainViewModel
    @Environment(\.scenePhase) private var scenePhase

    private var currentDirection: LayoutDirection {
        AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight
    }

    var body: some View {
        ZStack {
            rootScreen
                .id(flow.refreshID)
        }
        .environment(\.layoutDirection, currentDirection)
        .environment(\.locale, Locale(identifier: AppSettingsStore.shared.appLanguage.rawValue))
        .withOfflineBanner()
        .animation(.easeInOut(duration: 0.4), value: flow.currentScreen)
        .modelContainer(QuestPersistenceController.shared.container)
        .onReceive(NotificationCenter.default.publisher(for: .appLanguageDidChange)) { _ in
            flow.reloadCurrentScreen()
        }
        .onChange(of: scenePhase) { _, newPhase in
            globalBrain.handleScenePhaseTransition(newPhase)
        }
    }

    @ViewBuilder
    private var rootScreen: some View {
        switch flow.currentScreen {
        case .languageSelection:
            LanguageSelectionView {
                flow.didSelectLanguage()
            }
            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading)))
        case .login:
            LoginScreenView()
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
        case .profileSetup:
            ProfileSetupView()
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
        case .legacy:
            LegacyCalculationScreenView()
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
        case .captainPersonalization:
            CaptainPersonalizationOnboardingView()
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
        case .featureIntro:
            FeatureIntroView {
                flow.didCompleteFeatureIntro()
            }
            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading)))
        case .main:
            MainTabScreen()
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
        }
    }
}
